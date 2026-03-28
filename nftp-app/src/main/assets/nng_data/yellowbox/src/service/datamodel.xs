import { Image } from "../utils/imageCache.xs"
import { reduce, map } from "system://functional"
import { yellowStorage } from "../app.xs"
import JSON from "system://web.JSON"
import {isCallable, hasProp} from "system://core"
import { i18n } from "system://i18n"
import {Set} from "system://core.types"
import * as locale from "system://regional.locale"
import {richFmt} from "fmt/formatProvider.xs"
import { any } from "system://itertools"
import {toLowerCase} from "system://string.normalize"

export class Device {
	channelName; 	// string	deprecated
	brandName;		// string	!mandatory
	modelName;		// string	!mandatory
	swid;			// string	!mandatory
	imei;			// string
	igoVersion;		// string	!mandatory
	firstUse;		// int64
	appcid;			// int64
	vin;			// string
	uniqId;			// string
	hrCode;			// string
}

export class RegisterDeviceRet {
	credentials;	//DeviceCredentials inst.  !mandatory
	licenseInfo;	// licenseInfo inst.
	channelName;	// !mandatory
}

export class DeviceCredentials {
	name;		// string
	code;		// int64
	secret;		// int64
}

class CacheableRef {
	version;	//int32
	constructor( data ) {
		if ( data )
			this.version = data?.version;
	}
}

class Cacheable extends CacheableRef {
	maxAge;	//int32
	constructor( data ) {
		super( data );
		if ( data )
			this.maxAge = data?.maxAge;
	}
}

export class LicenseInfo extends Cacheable {
	licenseRefs; 		// licenseRef[]
	activationCodes;	// string[]
	swids;				// string[]
}

export class UploadLicenseArg {
	deviceName;		// string	!mandatory
	licenses;		// byte[]
	swids;			// string[]
	licenseNames;	//string[]
}

export class UploadLicenseRet {
	credentials;	// DeviceCredentials
	licenseInfo;	// LicenseInfo
}

export class LicenseParam {
	licenseCode;	// string	!mandatory
	fileName;		// string	!mandatory
	binaryLicense;	// byte
	expiration;		// int32
	rightCode;		// int64	!mandatory
	snapshotCode;	// int64	!mandatory
}

export class GetLicensesArg {
	deviceName;		// string	!mandatory
}

export class GetLicensesRet {
	licenses = [];	// LicenseParam[]
}

export class Description {
	longDescription;	// string
	shortDescription;	// string
	title;				// string
	descriptionId;		// int64	!mandatory
	timestamp;			// int64	!mandatory
	constructor( data ){
		if ( data ) {
			this.longDescription = data?.longDescription;
			this.shortDescription = data?.shortDescription;
			this.title = data?.title;
			this.descriptionId = data.descriptionId ?? 0;
			this.timestamp = data.timestamp ?? 0;
		}
	}
}

class AbstractParamArg {
	deviceName; 	// string
	modelName;		// string
	channel;		// string deprecated
	lang;			// string
	filterAreaAlpha3s = []	//list of area. area: string
	filterContentTypes = []	// list of contentType. contentType: string enum: [MAP, POI, SPEEDCAM]
}

class PackageArg extends AbstractParamArg {
	filterFree = false	//bool
	filterOutOsm = false	//bool
	userToken;	//string
	codes = [];	//string[]

}

export class Package {
	salesPackage = [];	// SalesPackage[]
	locale;			// Description
	packageCode;	// int64		!mandatory
	snapshot;		// snapShot
	scratchErrors;	//error[]	error: { code: string, error:enum }
	voucherErrors;	//error[]	error: { code: string, error:enum }
	unknownCodes;	// string[]
	contents;
	contentStatus = @empty;
	isFree = ( this.free || reduce( (acc, e) => { acc = (acc || e.actualPrice.net == 0); acc }, false, this.salesPackage ));
	// temp. definition of new: newer than the last use of the app
	isNew = ( yellowStorage.lastUse < (this.snapshot.buildTimestamp ?? 0L) );
	discount := any( this?.salesPackage ?? [], e=>e.actualPrice.net < e.basePrice.net);
	purchased = false;
	inBasket = false;
	validUntil;
	tags;

	constructor( data ) {
		if ( data ) {
			this.packageCode = data.packageCode;
			this.salesPackage = map( item => { new SalesPackage( item ) }, data.salesPackage );
			this.locale = new Description( data.locale );
			this.snapshot = new Snapshot( data.snapshot );
			this.scratchErrors = data?.scratchErrors;
			this.voucherErrors = data?.voucherErrors;
			this.unknownCodes = data?.unknownCodes;
		}
	}
}

export enum ContentTypeCodes {
	Map = 1,
	Voice = 3,
	Poi = 4,
	Lang = 10,
	Tmc = 12,
	OsUpdate = 26,
	Speedcam = 30,
	Dummy = 31,
	GlobalCfg = 55,
	DealerPoi = 70,
	Dummy2 = 71,
}

// List containing all package types that aren't available for purchase
export const filteredMimes = Set.of(
	"x-firmware/os-update",
);

export class Snapshot {
	buildTimestamp;				//int64		!mandatory
	contentRelease;				// string
	contentTypeDescription;		// Description
	contentTypeMime;			// string
	description;				// Description
	snapshotCode;				// int64	!mandatory
	// osm snapshotcodes:  weu: 1226025, eeu: 1226035
	supplierNames = []; 
	isOSM;
	#image;				        // Image
	get image() {
		this.#image?.img;
	}
	get imageId() { 
		this.#image?.id ?? ""; 
	}

	constructor( data ) {
		this.buildTimestamp = data.buildTimestamp;
		this.contentRelease = data?.contentRelease;
		this.contentTypeDescription = new Description( data?.contentTypeDescription);
		this.contentTypeMime = data?.contentTypeMime;
		this.description = new Description( data?.description );
		this.snapshotCode = data.snapshotCode;
		if ( data?.supplierNames && data.supplierNames.length ) {
			this.supplierNames = map( e=>e.toLowerCase(), data.supplierNames);
			this.isOSM = this.supplierNames.includes("openstreetmap.org");
		}
		else {
			console.log( "[packages] Warning! The 'supplierNames' field isn't filled for the snapshot! snapshotCode: ", data.snapshotCode ); 	
		}
		if (const url = data?.image ?? data?.imagePromise) 
			Promise.joinFast(url, url => {this.#image = new Image(url, url)})
	}
}

export class SalesPackage {
	actualPrice;		//Price
	basePrice;			//Price
	dealTypeCode;		//int64			!mandatory
	dealTypeLocale;		//Description
	salesPackageCode;	// int64		!mandatory
	usedScratchCode;	//string
	usedVoucherCode;	//string


	constructor( data ){
		this.actualPrice = new Price( data?.actualPrice );
		this.basePrice = new Price( data?.basePrice );
		this.dealTypeCode = data.dealTypeCode;
		this.dealTypeLocale = new Description( data?.dealTypeLocale );
		this.salesPackageCode = data.salesPackageCode;
		this.usedScratchCode = data?.usedScratchCode;
		this.usedVoucherCode = data?.usedVoucherCode;
	}
}

export class Price {
	currency;	// string
	net;		// float
	vat;		// float
	constructor( data ){
		if ( data ) {
			this.currency = data?.currency;
			this.net = data?.net;
			this.vat = data?.vat;
		}
	}
}

class ContentsBySnapshotCodesArg extends AbstractParamArg {
	snapshotCodes = []		// package sapshot codes. int64
}

export class Content extends CacheableRef {
	packageCode;			//int64		!mandatory
	additionalInfo;			// string
	md5;					// string
	size;					// int64	!mandatory
	buildTimestamp;			// int64	!mandatory
	releaseReasonTitle; 	// string
	contentTypeCode;		// int64	!mandatory
	contentTypeLocalized;	// string
	contentTypeMime;		// string
	country;				// string  (ISO-2)
	igoCountryCode;
	downloadLocation;		// string	!mandatory
	fileName;				// string
	filePath;				// string
	supplierCode;			// int64	
	supplierName;			// string
	isOSM;
	versionString;			// string
	contentIds;				// int64[]


	constructor( data ){
		super( data );
		if ( data ) {
			this.packageCode = data.packageCode;
			this.additionalInfo = data?.additionalInfo;
			this.md5 = data?.md5;
			this.size = data.size;
			this.buildTimestamp = data.buildTimestamp;
			this.releaseReasonTitle = data?.releaseReasonTitle;
			this.contentTypeCode = data.contentTypeCode;
			this.contentTypeLocalized = data?.contentTypeLocalized;
			this.contentTypeMime = data?.contentTypeMime;
			this.country = data?.country;
			this.igoCountryCode = locale.isoToIgoCountry( this.country ) ?? undef; 
			this.downloadLocation = data.downloadLocation;
			this.fileName = data?.fileName;
			this.filePath = data?.filePath;
			this.supplierCode = data?.supplierCode;
			this.supplierName = data?.supplierName ? data.supplierName.toLowerCase() : undef;
			this.isOSM = this.supplierName == "openstreetmap.org";
			this.versionString = data?.versionString;
			this.contentIds = data.contentIds ?? [];
		}
	}
}

export class Right {
	description;		// Description
	free;				// bool
	rightCode;			// int64
	snapshotCode;		// int64
	packageCode;		// int32
	dealTypeLocale;		// Description
	collective;			// bool
	licenseRequired;	// bool
	transactionId;		// string
	creationTime;		// int32
	expire;				// int32
	supplierNames = []; 
	isOSM;
	additionalInfo;

	constructor( data ){
		this.description = new Description( data?.description);	
		this.free = data.free;
		this.rightCode = data.rightCode;
		this.snapshotCode = data.snapshotCode;
		this.packageCode = data?.packageCode;
		this.dealTypeLocale = new Description( data?.dealTypeLocale );
		this.collective = data.collective;
		this.licenseRequired = data.licenseRequired;
		this.transactionId = data?.transactionId;
		this.creationTime = data?.creationTime;
		this.expire = data.expire ?? 0;
		this.additionalInfo = data?.additionalInfo;
		if ( data?.supplierNames && data.supplierNames.length ) {
			this.supplierNames = map( e=>e.toLowerCase(), data.supplierNames);
			this.isOSM = this.supplierNames.includes("openstreetmap.org");
		}
		else {
			console.warn( "[packages] Warning! The 'supplierNames' field isn't filled for the right! snapshotCode: ", data.snapshotCode ); 	
		}	
	}
}

export class ListRightsArg extends AbstractParamArg {}

export class ListRightsRet {
	rights = [];		// Right[]
}

export class ClaimFreeSalesPackagesArg extends AbstractParamArg {
	userToken;					// string
	salesPackageCodes = []; 	// int64[]
}

export class ClaimFreeSalesPackagesRet {
	rights = [];		// Right[]
}

export enum RedeemCodes {
	Scratch = "SCRATCH", 
	Voucher = "VOUCHER", 
	Unknown = "UNKNOWN",
}

export enum RedeemCodeError {
	AlreadyUsed = "ALREADY_USED", 
	AlreadyExpired = "ALREADY_EXPIRED", 
	Invalid = "INVALID",
	Other = "OTHER"
}

// ERROR ENUM values from the server
export const ErrorMessages = {
	CLIENT: {
		UNSUPPORTED_CLIENT_VERSION: i18n`Client version is unupported!`,
		INVALID_USER_AGENT: undef,
		INVALID_CLIENT_NAME: i18n`Client name is invalid!`,
		INVALID_CLIENT_VERSION: i18n`Client version is invalid!`
	},
	DEVICE: {
		VALIDATION_PROBLEM: i18n`Problem occured during validation!`,
		DEVICE_NOT_FOUND: i18n`Device can't be found!`,
		INVALID_SNAPSHOT: i18n`Snapshot is invalid!`,
		INVALID_DEVICE: i18n`Device is invalid!`,
		MISSING_DEVICE_MODEL: i18n`Device model is missing!`,
		UNRECOGNIZABLE_DEVICE_MODEL: i18n`Device model can't be recognized!`,
		INVALID_SALES_PACKAGE: i18n`Sales package is invalid!`,
		INVALID_USER: i18n`User is invalid!`
	},
	USER: {
		VALIDATION_PROBLEM: i18n`Some validation problem occured!`,
		INVALID_USER: i18n`User is invalid!`,
		USER_NAME_ALREADY_EXISTS: i18n`the given user name already exists!`,
		EMAIL_ALREADY_EXISTS: i18n`The given email already exists!`,
		EMAIL_IS_NOT_CONFIRMED: i18n`Confirm your email address or tap here to resend the confirmation email!`,
		EMAIL_EXISTS_IN_ANOTHER_INTEGRATION: undef,
		INVALID_USER_CREDENTIALS: i18n`Invalid user credentials!`,
		CHANNEL_NOT_FOUND: undef,
		USER_NOT_FOUND: i18n`User can't be found!`
	},
	PURCHASE: {
		VALIDATION_PROBLEM: i18n`Some validation problem occured!`,
		INVALID_DEVICE: i18n`Device is invalid!`,
		INVALID_SALES: undef,
		MISSING_SALE: undef,
	},
	REDEEM: {
		ALREADY_USED: i18n`You’ve been already redeemed this code!`,
		ALREADY_EXPIRED: i18n`This code is already expired!`,
		INVALID: i18n`Invalid code!`,
		OTHER: i18n`An error occured. Please try again later.`
	}
};

export enum ErrorType {
	UnsupportedClientVersion = "UNSUPPORTED_CLIENT_VERSION",
	InvalidUserAgent = "INVALID_USER_AGENT",
	InvalidClientName = "INVALID_CLIENT_NAME",
	InvalidClientVersion = "INVALID_CLIENT_VERSION",
	// todo: add all other error codes
}

export enum NetworkErrors {
	NOERR = i18n`No error`,
	NETWORK_CONNECT_NOT_FOUND = i18n`No network connection`,
	NETWORK_CONNECT_TIMEOUT = i18n`Host is unreachable`,
	NETWORK_CONNECT_OTHER = i18n`Connection error`,
	NETWORK_OTHER = i18n`Unexpected communication error`,
	NETWORK_TIMEOUT = i18n`Response timed out`,
	PROTOCOL = i18n`Non-parsable data received`,
	CANCELLED = i18n`Request canceled`,
	OTHER = i18n`Oops, something went wrong!`
}

getErrorText(result) {
	const fallbackText=i18n`Internal error when communicating with the backend. Contact the support if the problem persist. Code: {0}`;
	return ErrorMessages[result.errorCategory][result.errorType] || richFmt(fallbackText, ( result ? `${result.errorCategory}/${result.errorType}` : '500'));
}

export apiResult(data) {
	return { data, success: true, message: i18n`Success` };
}

export apiFailure( response, body ) {
	let message = response.status == 0 ? NetworkErrors[ nng.networking.http.Error.getNameOf( response.error ) ?? @OTHER] :  getErrorText( body );
	return { data: body, success: false, message };
}

/// @params: list of request-specific parameters
export processRes(request, response, params) {
	debugLog(request, response, params);
	const data = JSON.parse(response.body ?? "") ?? undef;
	if (response && response.status >= 200 && response.status <= 299)
		return apiResult(data);

	return apiFailure( response, data );
}

const apiDebug = SysConfig.get("yellowBox", "apiDebug", false);

export debugLog(request, response, params) {
	if (!request || !response){
		console.warn( "[logging] debugLog called without a request or response!");
		return;
	}
	if (!apiDebug) {
		console.log( "[updateAPI]" + JSON.stringify( params ));
		if ( response?.status == 200 )
			console.log( " Success!");
		else 
			console.warn(" Failed! status: ", (response.status ?? "unknown"), " details: ", JSON.stringify(response?.body) );
	} else {
		console.log(`API: ${request.host}${request.path}`);
		console.log(request.body);
		const body = response.body || "---";
		console.log(#{status: response.status, statusText: response.statusText, body: JSON.parseImmutable(body) ?? body, headers: response.headers.entries });
	}
}
