import { Package, filteredMimes } from "./datamodel.xs"
import { headUnit } from "~/src/toolbox/connections.xs"
import {languages} from "~/src/utils/languages.xs"
import { currentUser } from "../profile/user.ui"
import { runUntil, condition } from "../utils/util.xs"
import {config} from "../app.xs"
import { getPackages } from "app://yellowbox.updateApi"
import * as iter from "system://itertools"
import { basket, basketStorage, isBasketStorageValid } from "../basket.xs"
import {packageManager} from "../toolbox/packages/packageModel.xs"

export event packagesChangedEvent;

export class Packages {
	list = [];
	#onlyFree = (SysConfig.get("yellowbox", "freeContentsOnly", 0));
	status = @init;	// @init|@loading|@ready|@error
	errorDetails; // when status is @error, details can be found here 
	errorMessage; // when status is error error message in this field
	@dispose #deviceChangeSubs;
	@dispose #langChangeSubs;
	#redeemCodes = [];
	get redeemCodes(){ this.#redeemCodes }

	constructor() {
		if (isBasketStorageValid()) {
			this.#redeemCodes = basketStorage.getItem("redeemCodes") ?? [];
		}
		this.#langChangeSubs = languages.subscribeLangChange( ( lang ) => {this.fillPackageList( lang ) });
		this.#deviceChangeSubs = headUnit.deviceChangeEvent.subscribe( _ => {
			this.fillPackageList();
		} );
		this.fillPackageList();
	}

	addRedeemCode( type, codes ) {	//accepts a sequence or a single value
		codes  = Iter.seq(codes);
		const toAdd = [];
		for ( const code in codes ){
			if ( !this.#redeemCodes.find( e => e == code ) )
				toAdd.push( code );
		}
		if ( toAdd.length ) {
			this.#redeemCodes.push( ...toAdd );
			if ( type == @voucher )
				basketStorage.setItem("redeemCodes", this.#redeemCodes);
			this.list.clear();
			this.fillPackageList();
		}
		return toAdd.length;
	}

	removeRedeemCode( code ){
		if ( let idx = this.#redeemCodes.findIndex( code); idx >= 0 ){
			this.#redeemCodes.remove( idx );
			basketStorage.setItem("redeemCodes", this.#redeemCodes);
			this.list.clear();
			this.fillPackageList();
		} else 
			console.log("[packages] Trying to remove an invalid redeem code: ", code );
	}

	async fillPackageList(lang) {
		this.status=@loading;
		let res = await runUntil(this.#getPackages(lang || languages.langCode, ?), 12s);
		if ( res?.success ) {
			this.list = res.data.packages;
			this.errorDetails = this.errorMessage = undef;
			this.setPackageListProperties();
			this.status=@ready;
			packagesChangedEvent.trigger();
		} else {
			this.errorDetails = res?.data; // res is an apiFailure obj or undef in case of timeout
			this.errorMessage = res?.message;
			this.status=@error;
		}
	}

	async getPackageByCode( code ) {
		await condition( _ => this.status == @ready );
		return this.list.find( e=>e.packageCode == code );
	}

	async getPackageAndSalesPackageByCode( packageCode, salesPackageCode ) {
		await condition( _ => this.status == @ready );
		const pack = this.list.find( e=>e.packageCode == packageCode );
		let salesPack;
		if ( pack )
			salesPack = pack.salesPackage.find( e=>e.salesPackageCode == salesPackageCode );
		return pack, salesPack;
	}

	setPackageListProperties() {
    	for ( let element in this.list )	{
			element.inBasket =  ( basket.list.find( e => e.package.packageCode == element.packageCode ) ? true : false );
			const device = headUnit.device ?? headUnit.lastConnectedDevice;
			if ( !device )
				element.purchased = false;
			else if ( let purchased =packageManager.packages.find (e=>e.package.snapshot.snapshotCode == element.snapshot.snapshotCode) ){
				element.purchased = true;
				element.validUntil = purchased.package?.validUntil;
			}
			else 
				element.purchased = false;
			element.tags = this.fillTags( element );
    	}
	}

	fillTags( item ){
		let tags = [];
		if ( item.isNew ) tags.push(@new);
		if ( item.isFree ) tags.push(@free);
		if ( item.inBasket ) tags.push(@inBasket);
		if ( item.purchased ) tags.push(@purchased);  
		if ( item?.snapshot?.isOSM ) tags.push(@osm);
		if ( item.discount ) tags.push(@discount);
		return tags;  
	}

	async #getPackages(lang, ctoken) {
		const attrs = {	lang, filterOutOsm: true };
		if ( SysConfig.get("yellowBox", "enableOSM", true) )
			attrs.filterOutOsm = false;
		if ( SysConfig.get("yellowBox", "onlyEU", 1) )
			attrs.filterAreaAlpha3s = ["AAB"]; 
		const device = headUnit.device ?? headUnit.lastConnectedDevice;
		if ( device?.credentials ) {
			attrs.filterFree = this.#onlyFree;
			attrs.deviceName = device.credentials.name;
		}
		else {
			attrs.filterFree = false;
			attrs.brandName = config.device.brand;
			attrs.modelName = config.device.model;
		}
		if ( currentUser?.token )
			attrs.userToken = currentUser.token;
		if ( this.#redeemCodes && this.#redeemCodes.length ) {
			attrs.codes = this.#redeemCodes;
		}
		const res = await getPackages( attrs, ctoken );
		if ( res.success ) {
			res.data.packages = this.#parsePackages( res.data.packages );
		}
		return res;		
	}

	#parsePackages( allPackages ) {
		// todo: filtering the results here won't help when we need to process the OS update package
		//       probably filtering should move to the shop
		return iter.filter(allPackages, item => !filteredMimes.has(item.snapshot.contentTypeMime))
										.map( item => { new Package( item ) })
										.toArray();
	}

	reset(){
		this.list.clear();
		this.#redeemCodes.clear();
		basketStorage.setItem("redeemCodes", this.#redeemCodes);
		this.fillPackageList();
	}
}

@dispose
export Packages packageList;