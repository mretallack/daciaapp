import {reduce, map} from "core://functional"
import {Storage, Map, list, date, Set} from "system://core.types"
import {fmt} from "fmt/formatProvider.xs"
import * as path from "system://fs.path"
import {removeSync} from "system://fs"
import {getImageBySnapshotCode} from "app://yellowbox.updateApi"
import {Snapshot} from "~/src/service/datamodel.xs"
import { i18n } from "system://i18n"
import {DownloadStatus} from "~/src/toolbox/download.xs"
import {any, unique, filter, forEach} from "system://itertools"
import * as locale from "system://regional.locale"
import {ContentTypeCodes} from "~/src/service/datamodel.xs"
import {toLowerCase} from "system://string.normalize"
import {languages} from "../../utils/languages.xs"

export const mimesForSupplierDetection = Set.of( ContentTypeCodes.Map, ContentTypeCodes.Poi, ContentTypeCodes.Speedcam );

/// Represents a package bought for a given device (like maps for Eastern Europe)
export class PurchasedPackage {
	deviceUUID;
	packageCode;
	salesPackageCode;
	name;
	buildTimestamp;
	updated = false;
	snapshot;
	#contents; // list of purchased contents
	right;
	contentStatus;
	additionalInfo;	//{downloadedByUser:true}


	get id() {`${deviceUUID}/${right.rigthCode}`}
	get validUntil() { getValidUntil( this.right.expire ?? 0 ) }
	get subsType() { getSubsTypeText( this.right ) }
	get fullSize() { reduce( (a,b)=>{a=a+b.size}, 0L, this.contents ?? [] )}
	needRefresh() { !this.#contents || any( (this.#contents ?? []), c => c.needRefresh()) }
	get contents() { this.#contents }
	set contents( newVal ){
		console.log( "[packageDB] Set contents for package. PakageCode: ", this.packageCode, ", snapshotCode: ", this.snapshot.snapshotCode );
		this.#contents = newVal;
		this.#checkSuppliers();
	}

	constructor( data ){
		this.right = data.right;
		this.packageCode = data.packageCode;
		this.deviceUUID = data.deviceUUID;
		this.name = data.name;
		this.additionalInfo = data?.additionalInfo ?? {};
		this.snapshot = new Snapshot( data.snapshot );
		this.buildTimestamp = data.snapshot.buildTimestamp;
		this.updated = data?.updated ?? false;
		if (data?.contents) {
			for (const contentData in data.contents) {
				const content = new PurchasedContent(contentData);
				if ( !this.#contents )
					this.#contents = [];
				this.#contents.push(content);
			}
			this.#checkSuppliers(); 
		}
	}

	#checkSuppliers(){
		if (!this.snapshot?.supplierNames) this.snapshot.supplierNames = [];
		if ( this.snapshot.supplierNames.length == 0 && this.#contents && this.#contents.length ){
			this.snapshot.supplierNames = this.#contents |> filter( e=> mimesForSupplierDetection.includes(e.contentTypeCode), ^) |> map(  e=> (e?.supplierName ?? "").toLowerCase(), ^) |> ^.sort() |> unique(^).toArray();
		}
		if ( this.snapshot.supplierNames.includes("openstreetmap.org") ) {
			console.log( "[packageDB] The package is identified to an OSM map. PakageCode: ", this.packageCode, ", snapshotCode: ", this.snapshot.snapshotCode );
			this.snapshot.isOSM = true;
		} else 
			console.log( "[packageDB] The package is identified to a non-OSM map. PakageCode: ", this.packageCode, ", snapshotCode: ", this.snapshot.snapshotCode );

	}
}

export createPackageFromRight( right, device, pDb = packageDb ){
	console.log("[package] Creating package from right. PackageCode: ", right.packageCode, ", snapshotCode: ", right.snapshotCode );
	const existingPackage = pDb.getPackage( device.uuid, right.packageCode );
	// a package is 'updated' if the content list of the package has been refreshed (e.g. new map content is available in a 3 years subscription pack)
	const updated =  existingPackage && (existingPackage?.updated || existingPackage?.snapshot?.snapshotCode != right.snapshotCode);
	const pack = new PurchasedPackage({
		free: right.free,
		locale: right.description,
		right,
		packageCode: right.packageCode,
		updated,
		deviceUUID: device.uuid,
		name: right.description.title,
		additionalInfo: right?.additionalInfo,
		snapshot: {
			buildTimestamp: right?.creationTime,
			description: right.dealTypeLocale,
			snapshotCode: right.snapshotCode,
			contentRelease: right?.creationTime,
			imagePromise: getImageBySnapshotCode( right.snapshotCode ),
			supplierNames: right.supplierNames ?? [],
		}
	});
	if ( existingPackage )
		pDb.refreshPackageData( pack, device );
	return pack;
}

getValidUntil( expire ) {
	if ( expire )
		return fmt(`{:datetime|${languages.dateFormat}}`, new date( expire * 1000L ));
	else
		return "";
}

getSubsTypeText( right ) {
	if ( !right.expire && !right.collective )
		return i18n`Single purchase`;

	if ( !right.expire && right.collective )
		return i18n`Mapcare - free download`;

	if ( right.expire )
		return fmt(i18n`Valid until: {0}`, getValidUntil( right.expire ));
}

export class PackageDb {
	#store; // storage to use for persisting packages, by default it uses packageStore
	#allPurchasedPackages = []; // array storing purchased package data: serializable objects
	packagesByDevice = new Map; // list of purchased packages (purchasedPackage instances) for a given device, index it with deviceUUID
	#currentVersions;
	#expectedVersion = 1002;
	isOutdated(deviceUUID) { (this.#currentVersions[deviceUUID] ?? undef) < this.#expectedVersion }
	
	constructor(store) {
		this.#store = store ?? packageStore;
		this.#currentVersions = this.#store.getItem("versions") ?? {};
		this.#allPurchasedPackages = this.#store.getItem("purchasedPackages") ?? [];
		
		for (const pack in this.#allPurchasedPackages)
			this.#addPackage(new PurchasedPackage(pack));
			// todo refresh contents via api if the information is incomplete (e.g. supplier data)
		console.log("[PackageDB] packageDB is ready" );
	}
	
	#addPackage(pack) {
		const packList = this.packagesByDevice.get(pack.deviceUUID) ?? undef;
		if (packList) packList.push(pack);
		else this.packagesByDevice.set(pack.deviceUUID, list.of(pack))
	}
	
	getPackage(deviceUUID, packageCode ) {
		const packList = this.packagesByDevice.get(deviceUUID) ?? undef;
		if (!packList) return undef;
		return packList.find(p => p.packageCode == packageCode)
	}
	
	clear() {
		this.#allPurchasedPackages = [];
		this.packagesByDevice.clear();
		this.#updateStorage();
		console.log("[PackageDB] packageDB has been cleared" );
	}
	
	/// Used to persist package data
	#packageData(package){
		return {
			packageCode: package.packageCode,
			salesPackageCode: package.salesPackageCode,
			deviceUUID: package.deviceUUID,
			name: package.name,
			right: package.right ? this.#rightData( package.right ) : undef,
			validUntil: package.validUntil,
			updated: package.updated,
			subsType: package.subsType,
			snapshot: this.#snapshotData( package.snapshot ),
			buildTimestamp: package.buildTimestamp,
			additionalInfo: package.additionalInfo,
			contents: map(package.contents ?? [], c => this.#contentData(c))
		};
	}
	
	/// Used for persisting content data
	#contentData( content ) {
		return #{
			downloadLocation: content.downloadLocation,
			md5: content.md5,
			fileName: content.fileName,
			filePath: content.filePath,
			size: content.size,
			igoCountryCode: content.igoCountryCode,
			buildTimestamp: content.buildTimestamp,
			contentIds: content.contentIds,
			contentTypeCode: content.contentTypeCode,
			supplierName: content?.supplierName,	// todo compatibility with the older versions!
			supplierCode: content?.supplierCode,
		};
	}

	#snapshotData( snapshot ) {
		return #{
			buildTimestamp: snapshot.buildTimestamp,			
			contentRelease: snapshot.contentRelease,			
			contentTypeDescription: this.#descriptionData( snapshot.contentTypeDescription ),	
			contentTypeMime: snapshot.contentTypeMime,
			description: this.#descriptionData( snapshot.description ),
			snapshotCode: snapshot.snapshotCode,
			supplierNames: snapshot.supplierNames ?? [],
			// TODO: fujj      
			image: `https://download.naviextras.com/content/yellow/snapshot/${snapshot.snapshotCode}.jpg`,
		};
	}

	#descriptionData( description ) {
		return #{
			longDescription: description.longDescription,
			shortDescription: description.shortDescription,
			title: description.title,
			descriptionId: description.descriptionId,
			timestamp: description.timestamp
		}
	}

	#rightData( right ) {
		return #{
			description: this.#descriptionData( right.description ),
			free: right.free,
			rightCode: right.rightCode,
			snapshotCode: right.snapshotCode,
			packageCode: right.packageCode,
			dealTypeLocale: this.#descriptionData( right.dealTypeLocale ),
			collective: right.collective,
			licenseRequired: right.licenseRequired,
			transactionId: right.transactionId,
			creationTime: right.creationTime,
			expire: right.expire,
			supplierNames: right?.supplierNames, 
		}
	}
	
	#updateStorage() {
		this.#store.setItem("purchasedPackages", this.#allPurchasedPackages);
		this.#store.markDirty(); // NOTE: this is needed because the same array is used for the packages item, and the system
								 //        doesn't consider it changed
	}

	updateVersion( deviceUUID ){
		this.#currentVersions[ deviceUUID ] = this.#expectedVersion;
		this.#store.setItem("versions", this.#currentVersions);
		this.#store.markDirty();
	}
	
	purchasePackage( package, forDevice ) {
		const device = forDevice;
		const existingPackage = this.getPackage( device.uuid, package.packageCode );
		if (existingPackage) {
			console.log("[PackageDB] Already bought this content. PackageCode: ", package.packageCode );
			return;
		} 
		this.#allPurchasedPackages.push(this.#packageData( package ));
		this.#addPackage( package );
		this.#updateStorage();
		console.log( "[PackageDB] purchased package added to the database. PackageCode: ", package.packageCode);
		return package;
	}

	removePackage( package, fromDevice ){
		const pack = this.getPackage( fromDevice.uuid, package.package.packageCode );
		if( pack ){
			let packList = this.packagesByDevice.get(pack.deviceUUID) ?? undef;
			let idx = packList.indexOf( pack );
			if( idx != undef )
				packList.remove( idx );
			let ppIdx = this.#allPurchasedPackages.findIndex( e => e.packageCode == package.package.packageCode );
			if ( ppIdx > -1 )
				this.#allPurchasedPackages.remove( ppIdx );
			this.#updateStorage();
			console.log( "[PackageDB] package removed from the database. PackageCode: ", package.package.packageCode);	
			return pack;
		}
		else{
			console.warn("[PackageDB] Package doesn't exist! Can't remove from Db. packageCode: ", package.package.packageCode );
			return;
		}
	}

	collectOutdatedContents( contents, contDb ){
		const res = [];
		let cDb = contDb ?? contentDb;
		for ( const c in contents ){
			if ( !cDb.getFilePath( c ) ) continue;
			let found = false;
			for ( const p in this.#allPurchasedPackages ) {
				if ( p?.additionalInfo?.downloadedByUser && p.contents.find( e=> e.md5 == c.md5 )) {
					found = true;
					break;
				}
			}
			if ( !found ){
				console.warn( "outdated content found: ", c.fileName );
				res.push( c );
			}
		}
		return res;
	}

	refreshPackageContentsAndGetOutdated( package, device, contentDb ) {
		let pack = this.#allPurchasedPackages.find( e =>{ e.packageCode == package.packageCode } );
		if (pack) {
			const oldContents = pack.contents;
			pack.contents = map(package.contents, c => this.#contentData(c));
			let packList = this.packagesByDevice.get(device.uuid);
			let p = packList.findIndex( e => { e.packageCode == package.packageCode } );
			if( p > -1 ) {
				packList[p].contents = map(package.contents, c => new PurchasedContent(c));
			}
			this.#updateStorage();
			const outdated = this.collectOutdatedContents( oldContents, contentDb );
			return outdated;
		}
	}

	refreshPackageData( package, device ){
		let pack = this.#allPurchasedPackages.find( e =>{ e.packageCode == package.packageCode } );
		if( pack ){
			pack.name = package.name;
			pack.updated = package?.updated;
			pack.additionalInfo = { ...pack.additionalInfo, ...package.additionalInfo};
			pack.right = this.#rightData(package.right);
			pack.snapshot = this.#snapshotData( package.snapshot );
		
			let packList = this.packagesByDevice.get(device.uuid);
			let p = packList.findIndex( e => { e.packageCode == package.packageCode } );
			if( p > -1 ){
				packList[p].name = package.name;
				packList[p].additionalInfo = { ...packList[p].additionalInfo, ...package.additionalInfo};
				packList[p].right = package.right;
				packList[p].snapshot.description = package.snapshot.description;
				packList[p].updated = package?.updated;
			}
			this.#updateStorage();
		}
	}

	save() {
		this.#store.save();
	}
}

export const packageStore = new Storage("packageDb");

export PackageDb packageDb;

/// A content is a file inside a package (like France.fbl)
/// with associated metadata: like size, md5 hash
export class PurchasedContent {
	downloadLocation; // the URL of the content file
	md5;              // this can be used as unique id for the content
	fileName;
	filePath;
	size;
	igoCountryCode;
	buildTimestamp;
	contentIds;
	contentTypeCode;
	supplierName;
	supplierCode;

	get localFileName() { path.join("content", this.filePath, this.fileName); }
	needRefresh() { return this.contentIds==undef; }

	constructor(data) {
		this.downloadLocation = data.downloadLocation;
		this.md5 = data.md5;
		this.fileName = data.fileName;
		this.size = data.size;
		this.igoCountryCode = data?.igoCountryCode ?? locale.isoToIgoCountry( data?.country ) ?? undef;
		this.buildTimestamp = data.buildTimestamp;
		this.contentIds = data?.contentIds;
		this.filePath = data.filePath ?? "";
		this.contentTypeCode = data?.contentTypeCode;
		this.supplierName = data?.supplierName;	// todo compatibility with the older versions!
		this.supplierCode = data?.supplierCode;
	}
}
export const contentStore = new Storage("contentDb");

// stores downloaded contents by md5 checksum
// can answer whether a given content can be found on the disk or not...
export class ContentDb {
	#store;
	#filesByMd5;

	constructor(store) {
		this.#store = store ?? contentStore;
		this.#filesByMd5 = this.#store.getItem("files") ?? new Map;
		console.log( "[ContentDB] Content database is ready");	
	}
	
	getFilePath(content) {
		this.#filesByMd5.get(content.md5) ?? undef
	}

	removeContentByMd5( md5 ){
		const filePath = this.#filesByMd5.getAndRemove(md5) ?? undef;
		if (!filePath) return; // content already removed
		const res = ??removeSync(filePath);
		this.#save();	
		console.log( "[ContentDB] content removed: ", filePath );	
	}
	
	contentDownloaded(content, download) {
		if ( !content.md5 ) content.md5 = download?.localMd5;
		if ( content.md5 && download.status != DownloadStatus.Canceled ) {
			this.#filesByMd5.set( content.md5, download.fileName );
			this.#save();
		}
	}
	
	contentWithMd5Downloaded(download) {
		const md5 = download?.localMd5;
		if ( md5 && download.status != DownloadStatus.Canceled ) {
			this.#filesByMd5.set( md5, download.fileName );
			this.#save();
		}
	}

	clear() {
		this.#filesByMd5.clear();
		this.#save();
		console.log( "[ContentDB] content database has been cleared");
	}
	
	#save() {
		this.#store.setItem("files", this.#filesByMd5);
		this.#store.markDirty(); // notify store as files item hasn't changed only its contents
	}
}

export ContentDb contentDb;