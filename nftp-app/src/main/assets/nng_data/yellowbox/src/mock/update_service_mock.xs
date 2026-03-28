/// [module] app://yellowbox.updateApi

import { CommonPackages, PackagesWithVoucher, PackagesWithoutVoucher, PackagesWithScratch, PackagesWithoutScratch, PackagesOSMWithScratch, getMockContents, getMockContentsBySnapshot, getImageBySnapshotCode as imageFinder } from "./content.xs"
import { headUnit } from "../toolbox/connections.xs"
import { filter, reduce } from "system://itertools"
import { Description, apiResult, apiFailure, RedeemCodes, RedeemCodeError } from "../service/datamodel.xs"
import {failure} from "system://core"
import * as networkStatus from "../toolbox/networkStatus.xs"
import { yellowStorage } from "../app.xs"
import {Set} from "system://core.types"
import {labSettings} from "~/src/lab.ui"

/* Errors:
	400	Bad Request
	401 Unauthorized
	404 Not Found
	500 Internal Server Error
	502 Bad Gateway
	504 Gateway Timeout
*/

class UpdateServiceMock {
	healtCheck(){

	}

	registerDevice( device ){		// header param: userAgentHeader: string	device: { device: deviceInstance }
		//post
		// return RegisterDeviceRet
	}

	uploadLicense( uploadLicenseArg ){		
		// post
		// return UploadLicenseRet
	}

	getLicenses( device ){		// device: {deviceName: string}
		//post
		//return { licenses: LicenseParam[] };
	}

}

export async getContentsforPackage( package, purchase ) {
	if (!networkStatus.hasInternet()) 
	{
		package.contentStatus = @error;
		return undef;
	}
	if ( !package.contents ) {
		//For testing
		let testData = package?.additionalInfo?.testDatas;
		if(testData){
			if( testData?.contents )
				package.contents = package?.additionalInfo?.testDatas?.contents ?? [];
			if( testData.mf )
				testData.mf();
		}
		else
			package.contents = getMockContents( package, purchase );
		package.contentStatus = @ready;
	}
	return package.contents;
}

const mockCredentials = {
	name:"test_credential_name",
	code:999999L,
	secret: 0000009L
};


export getPackages( args, ctoken ){
	if (!networkStatus.hasInternet()) return undef;
	let res = CommonPackages.copy();
	let hasVoucher = reduce( (acc, e)=> { acc || redeemCodes.isVoucherCode(e) }, false, args.codes ?? [] ) ;
	let hasScratch = reduce( (acc, e)=> { acc || redeemCodes.isScratchCode(e) }, false, args.codes ?? [] ) ;
	let hasScratchForOSM = reduce( (acc, e)=> { acc || redeemCodes.isScratchCodeForOSM(e) }, false, args.codes ?? [] ) ;
	if ( hasVoucher )
		res.push(...PackagesWithVoucher );
	else 
		res.push( ...PackagesWithoutVoucher );
	if ( hasScratch )
		res.push(...PackagesWithScratch );
	else if ( hasScratchForOSM )
		res.push( ...PackagesOSMWithScratch);
	else 
		res.push( ...PackagesWithoutScratch );	
	if ( args?.filterOutOsm )
		res = [...filter( res, e=>{ !e.snapshot.supplierNames.includes("openstreetmap.org") } )];
	if ( args?.deviceName && args.filterFree )
		res = [...filter( res, e=>{ e.isFree } )];
	return { data: { packages: res }, success:true };	
}

export async registerDevice( ctoken, data ){
	await Chrono.delay( 2s );
	if (!networkStatus.hasInternet()) return undef;
	return {
		credentials: mockCredentials,
		licenseInfo: undef
	};
}

export UpdateServiceMock mock;

export async uploadLicense(device, licenses) {
	if (!networkStatus.hasInternet()) return undef;
	return {
		credentials: mockCredentials,
		licenseInfo: undef
	};
}

export async getLicenses(device) {
	if (!networkStatus.hasInternet()) return undef;
	return [];
}

export async listRights(device) {
	if (!networkStatus.hasInternet()) return undef;
	let rights = [
			{
			rightCode: 4265943570851122L,
			snapshotCode: 999991,
			packageCode: 75953,
			collective: true,
			free: true,
			licenseRequired: true,
			transactionId: undef,
			dealTypeLocale: new Description({ title: "Get the latest map", shortDescription: "Get the latest map" }),
			description: new Description({ title: "WEU MOCK MAPCARE", shortDescription: "<p><p>WEU MOCK MAPCARE</p></p>" }),
			creationTime: 1678969927,
			supplierNames: ["nng", "here"],
			expire: undef
		},
		{
			rightCode: 4265943571851122L,
			snapshotCode: 999998,
			packageCode: 759535,
			collective: true,
			free: true,
			licenseRequired: true,
			transactionId: undef,
			dealTypeLocale: new Description({ title: "OSM Map", shortDescription: "Get the latest map" }),
			description: new Description({ title: "Western Europe - NNG Maps (OSM)", shortDescription: "<p><p>WEU MOCK OSM</p></p>" }),
			creationTime: 1678969938,
			supplierNames: ["nng", "openstreetmap.org"],
			expire: undef
		},
		{
			rightCode: 4265943570851155L,
			snapshotCode: 1190170,
			packageCode: 62138,
			collective: true,
			free: true,
			licenseRequired: true,
			transactionId: undef,
			dealTypeLocale: new Description({ title: "Get the latest map", shortDescription: "Get the latest map" }),
			description: new Description({ title: "Africa mock mapcare", shortDescription: "<p><p>Africa mock mapcare</p></p>" }),
			creationTime: 1679314986,
			supplierNames: ["nng", "here"],
			expire: undef
		},
		{
			rightCode: 4265943570851255L,
			snapshotCode: 999961,
			packageCode: 62121,
			collective: false,
			free: false,
			licenseRequired: true,
			transactionId: undef,
			dealTypeLocale: new Description({ title: "Get the latest map", shortDescription: "Get the latest map" }),
			description: new Description({ title: "Appenine mock right", shortDescription: "<p><p>Appenine mock right - not free</p></p>" }),
			creationTime: 1678717387,
			supplierNames: ["nng", "here"],
			expire: undef
		},
		{
			rightCode: 4265943570851195L,
			snapshotCode: 97179,
			packageCode: 9911,
			collective: false,
			free: false,
			licenseRequired: true,
			transactionId: undef,
			dealTypeLocale: new Description({ title: "Szupeeerrr Kamu Mega package.", shortDescription: "Unicorn package." }),
			description: new Description({ title: "Szupeeerrr Kamu Mega package.", shortDescription: "<p><p>Szupeeerrr Kamu Mega package. - TMC, Lang, POI, speedcam and every kind of fake stuff. </p></p>" }),
			creationTime: 1737943508,
			supplierNames: ["nng", "here"],
			expire: undef
		}
	];
	if( labSettings.mockUpdate )
		rights.push({
			rightCode: 4265943570859999L,
			snapshotCode: 9714179,
			packageCode: 9911,
			collective: false,
			free: false,
			licenseRequired: true,
			transactionId: undef,
			dealTypeLocale: new Description({ title: "Update package.", shortDescription: "Update package." }),
			description: new Description({ title: "Update package.", shortDescription: "<p><p>Update package. - TMC, Lang, POI, speedcam and every kind of fake stuff.</p></p>" }),
			creationTime: 1737943508,
			supplierNames: ["nng", "here"],
			expire: undef
		});
	else
		rights.push({
			rightCode: 4265943570859999L,
			snapshotCode: 9715179,
			packageCode: 9911,
			collective: false,
			free: false,
			licenseRequired: true,
			transactionId: undef,
			dealTypeLocale: new Description({ title: "Update package.", shortDescription: "Update package." }),
			description: new Description({ title: "Update package.", shortDescription: "<p><p>Update package. - TMC, Lang, POI, speedcam and every kind of fake stuff.</p></p>" }),
			creationTime: 1737953508,
			supplierNames: ["nng", "here"],
			expire: undef
		});
	return rights;
}

export async getContentsBySnapshotCodes( snapshotCodes ){
	if (!networkStatus.hasInternet()) return undef;
	const snapshotCode = snapshotCodes[0];
	return { contents: getMockContentsBySnapshot(snapshotCode), snapshotCode };

}

export async claimFreeSalesPackages(device, userToken, salesPackageCodes) {
	if (!networkStatus.hasInternet())
		return {
			message: "Oops, something went wrong!",
			data: undef,
			success: false
		};
	
	return {
		message: "Success",
		success: true,
		data: {
			rigths: [
				{
					rightCode: 4265943570851122L,
					snapshotCode: 999991,
					packageCode: 75953,
					collective: true,
					free: true,
					licenseRequired: true,
					transactionId: undef,
					dealTypeLocale: new Description({ title: "Get the latest map", shortDescription: "Get the latest map" }),
					description: new Description({ title: "WEU MOCK MAPCARE", shortDescription: "<p><p>WEU MOCK MAPCARE</p></p>" }),
					creationTime: 1678969927,
					expire: undef,
					supplierNames: ["navngo", "here"]
				},
			]
		}
	};
}

export async claimFreeSalesPackagesWithScratch (device, userToken, scratchCode, salesPackageCodes) {
	await Chrono.delay(800);
	if (!networkStatus.hasInternet())
		return {
			message: "Oops, something went wrong!",
			data: undef,
			success: false
		};
	redeemCodes.used.add(scratchCode);
	const isOSMCode = scratchCode.startsWithNoCase("osm");
	const basePack = isOSMCode ? PackagesOSMWithScratch : PackagesWithScratch;
	const claimedPack = basePack.find(p => p.salesPackage[0].salesPackageCode == salesPackageCodes[0]);
	if (!claimedPack) {
		return {
			success: false,
			message: "Can't find claimed package",
		}
	}
	return {
		message: "Success",
		success: true,
		data: {
			rights: [
				{
					rightCode: 4265945570_000000L + salesPackageCodes[0],
					snapshotCode: claimedPack.snapshot.snapshotCode,
					packageCode: claimedPack.packageCode,
					collective: true,
					free: true,
					licenseRequired: true,
					transactionId: undef,
					dealTypeLocale: new Description({ title: "Get the latest map", shortDescription: "Get the latest map" }),
					description: claimedPack.locale,
					creationTime: 1678969927,
					expire: undef,
					supplierNames: isOSMCode ? ["navngo", "openstreetmap.org"] : ["navngo", "here"]
				},
			]
		}
	};
}

export async recognizeDeviceModel(deviceModel) {
	if (!networkStatus.hasInternet()) return undef;
	return #{
  		"brandName": "DaciaAutomotive",
  		"displayBrandName": "Dacia",
  		"modelName": "DaciaAutomotiveDeviceCY20_ULC4dot5",
  		"displayModelName": "Media Nav Evolution late 2018"
	};
}

export getImageBySnapshotCode( code ){
	if (!networkStatus.hasInternet()) return undef;
	return imageFinder( code );
}

export async registerUser(device, userData, cred, applicationChannel) {
	user.userCredentials = #{...cred, code:3278290074973158L, channel:undef};
	user.userData = userData;
	return apiResult(#{ ...user.userCredentials, password: undef});
}

export async resendRegistrationEmail(device, email, applicationChannel) {
	return apiResult();
}

export async bindDevice(device, userToken, ctoken) {
	return apiResult();
}

defaultUserData() {
	return {
		language: undef, 
		nick: undef, 
		genderType: "MALE", 
		yearOfBirth: "1985",
		detailedAddresses: [{
			// title:undef, 
			street: undef, 
			region: "Budapest", 
			country: "HUN", 
			lines: [
				"Alma utca 12",
				""
			], 
			addressType: "DEFAULT", 
			postalCode: "1037", 
			city: "Budapest", 
			firstName: "Christian Name", 
			lastName: "Surname", 
			house: undef,
		},
		{
			// title:undef, 
			street: undef, 
			region: "Budapest", 
			country: "HUN", 
			lines: [
				"Alma utca 12",
				""
			],  
			addressType: "INVOICE", 
			postalCode: "1037", 
			city: "Budapest", 
			firstName: "Richárd", 
			lastName: "Zsarnóczai", 
			house: undef,
		}],
	};
}

object user {
	isPushEnabled = do{ yellowStorage.pushNotiEnabled; };
	userData = do { defaultUserData()};
	userCredentials = undef;
	get profile() {
		return {
			name: this.userCredentials?.name ? this.userCredentials?.name : "rzsarnoczai2",
			email: this.userCredentials?.email ? this.userCredentials.email : "rzsarnoczai2@nng.com",
			code: this.userCredentials?.code ? this.userCredentials.code : 3278290074973158L,
			channel: "naviextras.com",
			userData: this.userData,
			userToken: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyNTk2ODQ2MjgwMDU1NjU4IiwiZXhwIjoxNzc4NzI0OTY1fQ.329yPZQbQ51tAO9QyqzXlyyf2vmDOEJNe51g6tuMQoc",
		};
	};
	token = do{ yellowStorage.getUserAccessToken() };
};

export async loginUser(userCredentials) {
	if (userCredentials.email && userCredentials.password && !userCredentials.password.startsWith("bad")) {
		user.userCredentials = #{...userCredentials, code:3278290074973158L, channel:undef};
		user.token = user.profile.userToken;
		return apiResult(user.profile);
	}
	return apiFailure();
}

export async updateUser(userToken, userData, userCredentials) {
	if (!userToken || user.token != userToken) return failure("call without userToken");
	user.userData = userData;
	return apiResult();
}

export async getUser(userToken) {
	if (!userToken || user.token != userToken) return failure("call without userToken");
	return apiResult(user.profile);
}

export async newsLetterOperation( userToken, operation=@subscribe, channel="naviextras.com") {
	if (!userToken || user.token != userToken) return failure("call without userToken");

	let data;
	if ( operation == @isSubscribed )
		data = { subscribed: true };
	
	return apiResult( data );
}

export async pushNotificationOperation(userToken, operation, applicationChannel) {
	if (operation == @isPushNotificationEnabled)
		return apiResult({ enabled: user.isPushEnabled });

	if (operation == @enablePushNotification) {
		user.isPushEnabled = true;
	} else if (operation == @disablePushNotification) {
		user.isPushEnabled = false;
	}
	return apiResult();
}

export async pollSalesforceKey(userToken, ctoken) {
	const synced = labSettings.salesforceSynced.val;
	if (!synced) {
		return { data: undef, success: false, message: "salesforceKey is not available", retryAfter: 2000 };
	}
	return apiResult({ salesforceKey: "003So000003NxsDIAS" });
}

export async changeUserPassword(userToken, oldPassword, newPassword) {
	if (!userToken || user.token != userToken) return failure("call without userToken");
	return apiResult();
}

export async forgotUserPassword(email, applicationChannel) {
	if (email && email.indexOf("@")>0) 
		return apiResult();
	return apiFailure();
}

export async purchase(device, userToken, salesPackageCodes, currency, ctoken) {
	await Chrono.delay(3s, ctoken);
	return apiResult({
		primaryInvoiceId:"DCIA2211171106092546225785472913",
		url: "https://payments-test.worldpay.com/app/hpp/integration/wpg/corporate?OrderKey=NAVIEXTRAS2%5EDCIA2211171106092546225785472913&Ticket=00166911156991202ZgulhN41monlRgc-WnInnA&source=https%3A%2F%2Fsecure-test.worldpay.com",
	});
}

/// enum: [SUCCESS, CANCELED, REJECTED, UNKNOWN]
export async purchasePoll(device, userToken, primaryInvoiceId, ctoken) {
	await Chrono.delay(2s, ctoken);
	return apiResult({saleStatus: "SUCCESS"});
}

object redeemCodes  {
	used = new Set;
	
	isVoucherCode(code) {
		code.startsWithNoCase("aaa") || code.startsWithNoCase("bbb") || code.startsWithNoCase("ccc") || code.startsWithNoCase("aaa")
	}
	
	isScratchCode(code) { // any code starting with "sss"
		code.startsWithNoCase("sss")
	}

	isScratchCodeForOSM(code) { // any code starting with "osm"
		code.startsWithNoCase("osm")
	}
	
	codeType(code) {
		if (this.isVoucherCode(code)) return RedeemCodes.Voucher;
		else if (this.isScratchCode(code)) return RedeemCodes.Scratch;
		else if (this.isScratchCodeForOSM(code)) return RedeemCodes.Scratch;
		else return RedeemCodes.Unknown;
	}
}

export async analyzeCode( code, userToken ){
	const codeType = redeemCodes.codeType(code);
	const analyzeRet = {
		success: true,
		data: {
			code: code,
			type: codeType,
		}
	};
	if (redeemCodes.used.has(code)) {
		analyzeRet.success = false;
		analyzeRet.data.error = RedeemCodeError.AlreadyUsed;
	} 
	if (codeType == RedeemCodes.Voucher) {
		analyzeRet.data.voucher = {
			couponGroupName: "groupName",
			description: "coupon description",
			expirationTime: 0 // todo: add 1year of expiration from now or something similar
		}
	} else if (codeType == RedeemCodes.Scratch) {
		analyzeRet.data.scratch = {};
	}
	return analyzeRet
}
