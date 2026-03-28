import { Storage, Map, date, Set } from "system://core.types"
import { registerDevice, bindDevice, uploadLicense, listRights, recognizeDeviceModel } from "app://yellowbox.updateApi"
import { headUnit, selectDevice } from "./connections.xs"
import { packageList } from "../service/packages.xs"
import { ContentCacheHU } from "./headUnitContentCache.xs"
import { downloadLicenses, getLicensesFromBox } from "../utils/box.xs"
import { entries, string, hasProp, failure } from "system://core"
import { decodeContentId, countryCodeOf, commentToRegionVerPkg, isOSMContent } from "./db/contentId.xs"
import * as path from "system://fs.path"
import { getSmallFile, queryFilesFlat, queryChecksum, ChecksumMethod} from "core/nftp.xs"
import { raceAndCancel, stripExt, runUntil, TimerProgress, Progress, openUrl } from "../utils/util.xs"
import {md5} from "system://digest"
import * as networkStatus from "./networkStatus.xs"
import {mapFileToPath} from "./fileMapping.xs"
import { @disposeNull } from "core/dispose.xs"
import { i18n } from "system://i18n"
import { Messagebox, Button, MsgboxInputData, frMessagebox, frMessageboxWithInput, frMessageboxWithCheckbox, MsgboxChkBoxData } from "../components/messageboxes.xs"
import {bindProperty, unbindProperty} from "core://observe"
import {fmt} from "fmt/formatProvider.xs"
import * as iter from "system://itertools";
import { config, yellowStorage, app } from "../app.xs"
import re from "system://regexp"
import { currentUser, isAccessTokenValid, LinkStyle } from "../profile/user.ui"
import {@registerStyle} from "uie/styles.xs"
import {removeFilesFromDevice, refreshFreeSpaceOnHeadUnit} from "./contentManagament.xs"
import { basket } from "../basket.xs"

export const deviceStorage = new Storage("device");
export event carRegistered;

// poi, map, tmc, spc, hnr, spc, fbl, fda, fds, fpa, fjw, fjv, fsp, ftr
const contentExtRe = re`[.]((?i)poi|map|tmc|spc|hnr|f(bl|d[as]|pa|j[wv]|sp|tr))$`;

const hasContentIdByExt = contentExtRe.test(?);

export class Device {
	@disposeNull
	#deviceStorage;

	synchedWithHU := (this.appcid != undef && this.modelName && this.brandName && this.igoVersion && this.imei && this.swid && this.firstUse != undef && this.skus && 
		this.agentBrand && this.brandFiles?.length);
	registering = false;
	loadingRights = false;
	registered := (this.credentials ?? false);

	appcid;
	modelName;
	brandName;
	agentBrand;
	brandFiles;
	igoVersion;
	imei;
	swid;
	swids;
	skus;
	firstUse;
	vin;
	customName;
	uniqId;
	hrCode;
	channelName;
	hasOSM;
	onCarContentList = list[];
	#ongoingQuerys;
	licensesAreUploaded;
	lastSyncDate;
	credentials;
	licenseInfo;
	#rightsPromise; /// will be used while loading rights
	#retryRegisterAfter = 0;
	rights;
	registerDevIfInternet;

	@disposeNull
	fileDB;
	
	/// unique name returned by server after registration
	get name() { this.credentials?.name; }
	// todo: temporary uuid until replace it
	get uuid() { this.swid; }

	set customName( newVal ){
		this.customName = newVal; 
		this.#deviceStorage.setItem( `customName(${this.swid})`, newVal);
	}

	onChange hasOSM( newVal ){
		console.log( "[device] device OSM status changed to ", newVal );
		if ( !newVal || SysConfig.get("yellowBox", "enableOSM", true) ) return;
		let noti = new Messagebox;
		noti.addLine(i18n`Your navigation is using OSM+ maps and this application unable to manage them yet.\nUse toolbox instead.`)
		.setOverlay()
		.addIcon( "msgbox_warning.svg" )
		.addButton( new Button({ text : i18n`Ok`}) );
		noti.show();		

	}

	/// @param {string} swid Input string for normalization
	/// @param {dict} params {justConnected: false}
	constructor( swid, params ){
		console.log("[device] Initialize device");
		this.#deviceStorage = params.deviceStorage ?? deviceStorage;
		this.swid = swid;
		this.fileDB = new ContentCacheHU( this.swid, params?.cacheStorage );
		this.#ongoingQuerys = new Map();
		this.loadDeviceData( !params?.justConnected );
		if ( this.synchedWithHU ) {
			console.log( "[device] Device has already registered with the HU. ");
			if ( !this.registered ) 
				this.registerDev();
			else if (!this.licensesAreUploaded)
				this.uploadLicenses();
			else
				this.getRights();			
		} else {
			console.log( "[device] Device not found!");
		}
	}

	saveDataFromDevice(){
		let data = {
				appcid: this.appcid,
				modelName: this.modelName,
				brandName: this.brandName,
				agentBrand: this.agentBrand,
				brandFiles: this.brandFiles,
				igoVersion: this.igoVersion,
				imei: this.imei,
				
				swids: this.swids,
				skus: this.skus,
				firstUse: this.firstUse,
				vin: this.vin,
				uniqId: this.uniqId,
				hrCode: this.hrCode,
				lastSyncDate: this.lastSyncDate,
				channelName: this.channelName,
				hasOSM: this.hasOSM
		};
		this.#deviceStorage.setItem( this.swid, data);
		console.log("[device] Device data saved successfully.");
	}

	loadDeviceData( loadDeviceContents ){
		let saved = ??this.#deviceStorage.getItem( this.swid );
		if ( saved ){
			this.appcid = saved.appcid;
			this.modelName = saved.modelName ?? undef;
			this.brandName = saved.brandName ?? undef;
			this.agentBrand = saved.agentBrand ?? 0;
			this.brandFiles = saved.brandFiles ?? [];
			this.igoVersion = saved.igoVersion;
			this.imei = saved.imei;
			this.customName = this.#deviceStorage.getItem( `customName(${this.swid})` ) ?? "";
			
			this.swids = saved.swids ?? [saved.swid];
			this.skus = saved.skus ?? 0;
			this.firstUse = saved.firstUse;
			this.vin = saved.vin;
			this.uniqId = saved.uniqId;
			this.hrCode = saved.hrCode;
			this.lastSyncDate = saved.lastSyncDate ?? undef;
			this.channelName = saved?.channelName;
			this.hasOSM = saved.hasOSM ?? undef;
			console.log( "[device] Saved device data has been successfully loaded. swid: ", this.swid);
		}

		this.credentials = this.#deviceStorage.getItem( `credentials(${this.swid})` ) ?? undef;
		this.licenseInfo = this.#deviceStorage.getItem( `licenseInfo(${this.swid})` ) ?? undef;	// todo meggyozodni arrol hogy tenyleg perzisztalhato
		this.licensesAreUploaded = this.#deviceStorage.getItem( `licensesAreUploaded(${this.swid})` ) ?? false;
		if ( loadDeviceContents ) {
			this.#checkHasOSM();
			this.#fillOnCarContentList();
		}
	}

	saveDeviceRegResponse( res ){
		this.credentials = res?.credentials;
		this.licenseInfo = res?.licenseInfo;
		this.channelName = res?.channelName;
		// console.log(res?.channelName);
		this.#deviceStorage.setItem( `credentials(${this.swid})`, this.credentials );
		this.#deviceStorage.setItem( `licenseInfo(${this.swid})`, this.licenseInfo );
	}

	syncDevice(hu){
		this.appcid = hu.appcid;
		this.igoVersion = hu.igoVersion;
		this.swid = hu.swid;
		this.swids = hu?.swids ?? [hu.swid];
		this.modelName = hu.modelName;
		this.brandName = hu.brandName;
		this.skus = hu.skus;
		this.firstUse = hu.firstUse;
		this.imei = hu.imei;
		this.vin = hu.vin;
		this.agentBrand = hu.agentBrand;
		this.brandFiles = hu.brandFiles;
		this.lastSyncDate = new date();
		this.saveDataFromDevice();
		console.log( "[device] Sync with te HU finished. Device swid: ", this.swid);
	}

	#deviceModel() {
		const files = [];
		for (const f in this.brandFiles) {
			if (hasProp(f, @content)) {
				files.push({nameWithPath: f.path, md5: md5(f.content).hexstr()});
			} else {
				files.push({nameWithPath: f.path});
			}
		}
		return #{
			agentBrand: this.agentBrand,
			appcid: this.appcid,
			skus: this.skus,
			files,
			// brandMD5: brandMD5, // from device.nng
		};
	}

	async registerDev(){
		if (!this.synchedWithHU || this.registering || this.registered){
			return;
		}
		this.registering = true;
		const timeoutRecognize = 5s;
		const timeoutRegister = 5s;
		const progress = Progress{ };
		using const t = new TimerProgress(progress, timeoutRecognize+timeoutRegister);
		deviceProgressDialog.show([i18n`Registering device`], progress);
		const brandAndModel = await runUntil(recognizeDeviceModel(this.#deviceModel(), ?), timeoutRecognize);
		if (brandAndModel) {
			let brandMatch = false;
			if (config.device?.brandMatch) {
				brandMatch = re(config.device.brandMatch).test(brandAndModel.brandName);
			} else {
				// todo a model is szamit, vagy eleg ha a brand stimmel?
				brandMatch = brandAndModel.brandName == config.device.brand /* && brandAndModel.modelName == config.device.model*/;
			}
			const exactBrandMatch = SysConfig.get("yellowBox", "exactBrandMatch", true);
			if (exactBrandMatch && !brandMatch) {
				if (config.device?.brandMatch)
					console.warn("[device] device brand mismatch! Expected match: ", config.device.brandMatch, ". Got ", brandAndModel.brandName );
				else 
					console.warn("[device] device brand mismatch! Expected: ", config.device.brand, ". Got ", brandAndModel.brandName );
				return this.notifyRecognizeDeviceMismatch();
			}
			this.brandName = brandAndModel.brandName;
			this.modelName = brandAndModel.modelName;
			this.saveDataFromDevice();
		} else 
			console.warn("[device] recognizeDeviceModel failed, try fallback");
		let args = {
			appcid: this.appcid, 
			brandName: this.brandName,
			modelName: this.modelName,
			igoVersion: this.igoVersion, 
			imei: this.imei, 
			swid: this.swid,
			firstUse: this.firstUse,
		};
		//Ez itt szandekos, Saicnal ha felkuldod uresen gond lesz.
		if( this.vin )
			args.vin = this.vin;
		let res = await runUntil(registerDevice(args, ?), timeoutRegister, this.#retryRegisterAfter);
		this.#retryRegisterAfter = this.#retryRegisterAfter ? this.#retryRegisterAfter*2 : 100;	//ms
		if ( res ){
			this.saveDeviceRegResponse( res );
			if ( currentUser.token && isAccessTokenValid( currentUser.token ) ){
				// trying to bind the device
				const bindDevRes = ?? await bindDevice( this, currentUser.token ); 
				if ( !bindDevRes.success )
					console.log( "[device] BindDevice failed!" );
				else 
					console.log( "[device] Device successfully binded to the user." );
			}
			packageList.fillPackageList();
			await this.uploadLicenses();
			carRegistered.trigger( this );
		}
		this.registering = false;
		this.notifyRegisterDevResult(progress);
		this.registerDevAgain();
	}

	notifyRegisterDevResult(progress) {
		if (this.registered) 
			this.notifyRegisterDevSuccess();
		else {
			console.log("[device] Can't register the device");
			let text = [i18n`Can't register the device, try again later!`];
			deviceProgressDialog.show(text, progress);
		}
	}

	notifyRecognizeDeviceMismatch(){
		let noti = new Messagebox;
		noti.addLine(i18n`Your device is not compatible with this application.`)
		.setOverlay()
		.addIcon( "msgbox_warning.svg" )
		.addButton( new Button({ text : i18n`Ok`}) );
		noti.show();
	}

	notifyRegisterDevSuccess(){
		deviceProgressDialog.hide(); // will show another msgBox
		let currDeviceName = "";
		if ( this.swid ) currDeviceName += "(" + this.swid + ")";
		let noti = new Messagebox;
		let inputData = MsgboxInputData{ title=fmt("{0:s}*", i18n`Car name`); inputVal=currDeviceName; errorText=i18n`Name is required` };
		let action = ( button ) => { 
				if (inputData.inputVal) {
					this.customName = inputData.inputVal; 
					refreshKnownDevices();
					console.log("[device] device name has been saved: ", this.customName );
				}
		}; 
		noti.data = inputData;
		let button = Button{
			text = i18n`Save`;
			enabled := inputData.inputVal;
			action = action;			
		};
		noti.addLine(i18n`You just connected to a new car`)
		.setOverlay()
		.setId(@newCarRegistered)
		.setLayout(frMessageboxWithInput)
		.addIcon( "simple_car.svg" )
		.addButton( button );
		noti.show();
	}

	registerDevAgain() {
		if (this.registered) {
			this.registerDevIfInternet = undef;
		} else {
			console.log( "[device] Cannot register device. Wait for the internet connection. Swid: ", this.swid);
			this.registerDevIfInternet = networkStatus.subscribe((status) => {
				if (status?.internet) {
					console.log("[device] Internet is available, trying to register the device again. Swid: ", this.swid );
					this.registerDev();
				}
			});
		}
	}

	async getRights(){
		if (this.loadingRights)
			return this.#rightsPromise;
		this.loadingRights = true;
		this.#rightsPromise = raceAndCancel( listRights( this ), 10s ) ;
		this.#rightsPromise
			.then(res => this.rights = res)
			.finally(()=>{
				this.loadingRights = false;
				this.#rightsPromise = undef;
			});
		return this.#rightsPromise;
	}
	
	// add new rights to the list of current rights 
	async addRights(newRights) {
		if (this.loadingRights) {
			console.error("Try to add new rights while loading list of rights");
			return;
		}
		if (!this.rights)
			this.rights = [];
		this.rights.push(...newRights);
	}

	async uploadLicenses(){
		let res = await raceAndCancel( uploadLicense(this, getLicensesFromBox(this) ), 10s );	// todo
		if (res) {
			this.licensesAreUploaded = true;
			this.#deviceStorage.setItem( `licensesAreUploaded(${this.swid})`, this.licensesAreUploaded );
			await downloadLicenses(this);
			await this.getRights();
		}
	}
	
	/// call this method when this device was connected
	connected() {
		this.#deviceStorage.setItem("lastConnected", this.swid);
	}

	async refreshFreeSpace() {
		return refreshFreeSpaceOnHeadUnit();
	}
	
	async getContentsFromHU() {
		console.log( "[device] Getting contents from the HU");
		if (!headUnit.connected)
			return;
		const progress = Progress { };
		let onHU = ?? await queryFilesFlat(headUnit.messenger, "content", {fields: (@name, @size,  @isFile, @mtimeMs)} );
		let onHULic = ?? await queryFilesFlat(headUnit.messenger, "license", {fields: (@name, @size,  @isFile, @mtimeMs)} );
		if (onHULic) {
			onHU.push(...onHULic);
		}
		if ( !onHU ) {
			console.log( "[device] No content found on HU!");
			return;
		}

		this.fileDB.update( onHU );
		const tasks = [];
		progress.value = 0;
		for (let element in onHU) {
			if (!element.name || !element.isFile || !hasContentIdByExt(element.name))
				continue;

			const cache = this.fileDB.get(element.path) ?? undef;
			if (cache?.contentInfo && element.size == cache?.size && element.mtimeMs == cache?.mtimeMs)
				continue;

			tasks.push(async do {
				const buf = await getSmallFile(headUnit.messenger, element.path, 0, 4096);
				++progress.value;
				if (buf) {
					if (const contentInfo = decodeContentId(buf)) {
						return #{ ...element, contentInfo };
					}
				}
			})
		}
		progress.total = tasks.length;
		progress.text = "";
		deviceProgressDialog.show([""+i18n`Sync with HU`+"...", i18n`Please stay connected to your car!`], progress);
		const res = await.all tasks;
		deviceProgressDialog.show([i18n`Sync completed!`], progress);
		this.fileDB.update(res, {removeMissing:false});

		this.#checkHasOSM();
		this.saveDataFromDevice();	//update the storage;
		refreshKnownDevices();
		this.#fillOnCarContentList();
		console.log("[device] Getting contents from the HU has been completed successfully")
	}

	async removePartFilesFromHU(){
		const partFiles = this.fileDB.getPartFiles();
		if ( partFiles.length ) {
			await removeFilesFromDevice( partFiles);
			for ( const p in partFiles )
				this.fileDB.remove( p.path, false );	
			this.fileDB.save();
		}
		return partFiles.length;
	}

	#checkHasOSM() {
		for (const filePath in this.fileDB.keys) {
			const cache = this.fileDB.get(filePath) ?? undef;
			if (cache?.contentInfo && isOSMContent(cache.contentInfo, path.basename(filePath))) {
				this.hasOSM = true;
				return;
			}
		}
		this.hasOSM = false;
	}

	#entryIsOSM(entry) {
		for (const c in entry.contents) {
			if (isOSMContent( c.cinfo, path.basename(c.path))) return true;
		}
		return false;
	}

	#fillOnCarContentList(){
		this.onCarContentList.clear();
		let res = [];
		const infos = Map();

		const entryOnDemand = () => { return { contents: [], contentTypes:[], size: 0}; };
		const updateEntry = (entry, cinfo, size, cPath) => { 
			const type = path.dirname(cPath) |> path.basename(^);
			if ( !entry.contentTypes.includes( type ))	entry.contentTypes.push (type);
			entry.contents.push(#{cinfo, path: cPath}); 
			entry.size += size; 
		};

		// region code can be county(_HUN), state/subregion (_uks, _i17) or region code (~FEU - Full Europe) - see https://confluence.nng.com/display/MAPDB/Content+header+comments
		for (const filePath in this.fileDB.keys) {
			const item = this.fileDB.get(filePath);
			if (!item?.contentInfo)
				continue;
			const region, ver = commentToRegionVerPkg(item.contentInfo);
			if (region)
				infos.emplace(region, entryOnDemand) |> updateEntry(^, item.contentInfo, item.size, filePath);
		}

		
		for ( let country in infos.keys ) {
			//basemap musn't be deleted
			if ( country != "~BAS") {
				const tags = [];
				if (this.#entryIsOSM(infos[country])) tags.push(@osm);
				res.push({ name: country, contents: infos[country].contentTypes.join(", "), files: infos[country].contents,  size: infos[country].size, tags});
			}
		}

		this.onCarContentList.push( sort( (a,b)=>{ string.cmp(a.name, b.name) }, ...res ) );
	}

	async checkContentMd5(filename, size) {
		const filePath = mapFileToPath(filename, headUnit.fileMapping);
		if (!filePath) return;
		const onCar = this.fileDB.get( filePath ) ?? undef;
		if (!onCar) return;
		if (!onCar?.md5 && onCar?.size == size && !this.#ongoingQuerys.has(filename)) {
			this.#ongoingQuerys.set(filename, true);
			const csum = await queryChecksum(headUnit.messenger, filePath, ChecksumMethod.MD5);
			onCar.md5 = csum.hexstr() ?? undef;
			this.#ongoingQuerys.remove(filename);
		}
	}
}

/// @param {string} swid Input string for normalization
/// @param {dict} params {justConnected: false}
/// @returns {Device}
export getDeviceBySwid(swid, options) {
	return new Device(swid, options);
}

export getLastConnectedDevice() {
	const lastConnectedSwid = deviceStorage.getItem("lastConnected") ?? undef;
	return lastConnectedSwid ? new Device(lastConnectedSwid) : undef;
}

export checkHasDevice(){
	const dev = headUnit.device ?? headUnit.lastConnectedDevice;
	if ( !dev && yellowStorage.showHowToUpdateMessagebox )
		showHowToUpdateMessagebox();
}


@registerStyle
style selectorStyles {
	group#tChkbox {
		boxAlign: @center;
		marginLeft: const(paddings.extraLarge);
		marginRight: const(paddings.extraLarge);
		marginBottom: const( paddings.extraLarge );
	}
}

showHowToUpdateMessagebox(){
	let data = MsgboxChkBoxData{ text= i18n`Do not show this message again`; val=false }; 
	const noti = new Messagebox;
	noti.data = data;
	noti.addLine(i18n`You need to update your navigation device before using this application.`)
	.setOverlay()
	.setLayout(frMessageboxWithCheckbox)
	.addIcon( "msgbox_warning.svg" )
	.addButton( new Button({
		text:i18n`How?`, 
		action: _ => { yellowStorage.showHowToUpdateMessagebox = !data.val; app.next( @HelpOsUpdate); } 
	}))
	.show();
}

export async setDevice( swid ) {
	if ( headUnit.connected ) {
		return failure("HeadUnit is already connected to a device.");
	}
	if ( deviceStorage.getItem( swid ) ) {
		let device = new Device( swid );
		selectDevice( device );
		deviceStorage.setItem("lastConnected", swid );
		await device.getRights();
		console.log( "[device] New device has been selected. swid: ", swid );
		basket.clear();
	}
	else {
		return failure("the given swid does not exist.");
	}
}

export renameDevice( swid, newName ){
	if ( swid == headUnit?.device?.swid )
		headUnit.device.customName = newName;
	else if ( swid == headUnit?.lastConnectedDevice?.swid )
		headUnit.lastConnectedDevice.customName = newName;
	deviceStorage.setItem( `customName(${swid})`, newName );
	console.log("[device] Device renamed to ", newName, ". swid: ", swid);
	refreshKnownDevices();
}

getKnownDevices(){
	let res = [];
	for ( let element in deviceStorage ){
		if ( element[1]?.swids && element[1]?.lastSyncDate )
			res.push({ 	swid: element[0], 
						name: deviceStorage.getItem(`customName(${element[0]})`) ?? element[0],
						lastConnected: element[1].lastSyncDate,
						vin: element[1].vin,
						hasOSM: element[1].hasOSM ?? undef,
					})
	}
	return res;
}

export refreshKnownDevices() {
	knownDevices.list = getKnownDevices();
}

export object knownDevices {
	list = do{ getKnownDevices() };
}

class ProgressDialog {
	#dialog;
	#pendingShow = undef;

	constructor() {
		this.#dialog = new Messagebox; this.#dialog
		.addLine(""+i18n`Sync with HU`+"...")
		.addIcon({ name: "loading.svg", class:("loadingProgress", "animated")})
		.setId(@deviceProgress)
		.setOverlay();
	}

	async show(title, progress) {
		if (progress.total == 0) 
			return;
		this.#dialog.lines = title;
		this.#dialog.progress = progress;
		if (this.#pendingShow != undef)
			return this.#pendingShow;
		this.#pendingShow = this.#dialog.show();
		const res = await this.#pendingShow;
		this.#pendingShow = undef;
		return res;
	}

	hide() {
		this.#dialog.hide();
	}
}

export ProgressDialog deviceProgressDialog;
