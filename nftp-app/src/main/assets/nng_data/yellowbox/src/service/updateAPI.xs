/// [module] app://yellowbox.updateApi

import * as httpClient from "system://nng.networking.http.Client"
import * as iter from "system://itertools";
import { failure } from "system://core"
import JSON from "system://web.JSON"
import { encode as encodeBase64} from "system://web.Base64"
import { Package, Content, processRes, debugLog, Right} from "./datamodel.xs"
import { map } from "system://functional"
import { headUnit } from "~/src/toolbox/connections.xs"
import { runUntil } from "../utils/util.xs"
import {PurchasedContent} from "~/src/toolbox/packages/packageAndContent.xs"
import {userAgent} from "~/src/appVersion.xs"
import {labSettings} from "~/src/lab.ui"?
import {languages} from "~/src/utils/languages.xs"
import {config} from "../app.xs"

odict settings{
	serverUrl := labSettings?.serverUrl ?? "https://stratus.naviextras.com/services/updateservice/1";
}

const endpoints = {
	packages: "/packages",
	contents: "/contentsBySnapshotCodes",
	lic: "/licenses",
	deviceReg: "/registerDevice",
	uploadLicense: "/uploadLicense",
	getLicenses: "/getLicenses",
	listRights: "/listRights",
	claimFreeSalesPackages: "/claimFreeSalesPackages",
	claimFreeSalesPackagesWithScratch: "/claimFreeSalesPackagesWithScratch",
	analyzeCode: "/analyzeCode",
	recognizeDeviceModel: "/recognizeDeviceModel",
	registerUser: "/registerUser",
	resendRegistrationEmail: "/resendRegisterUserConfirmEmail",
	bindDevice: "/bindDevice",
	loginUser: "/loginUser",
	updateUser: "/updateUser",
	getUser: "/getUser",
	changeUserPassword: "/changeUserPassword",
	forgotUserPassword: "/forgotUserPassword",
	purchase: "/purchase",
	purchasePoll: "/purchasePoll",
	subscribe: "/subscribe",
	unsubscribe: "/unsubscribe",
	isSubscribed: "/isSubscribed",
	pollSalesforceKey: "/pollSalesforceKey",
};

setupPostRequest( uri, ctoken ) {
	let request = httpClient.createRequest( uri );
	request.method = nng.networking.http.Method.POST;
	request.headers.set("Content-type", "application/json");
	request.headers.set("User-Agent", userAgent);
	if (ctoken) ctoken.subscribe( () => { request.cancel(); }, @noUnsubscribe);
	return request;
}


export async getPackages( attrs, ctoken ){
	const uri = settings.serverUrl + endpoints.packages;
	const request = setupPostRequest(uri, ctoken);
	request.body = JSON.stringify( attrs );
	const serverResponse = await request.fetch();
	return processRes(request, serverResponse, { call: "getPackages", lang: attrs?.lang });
}


export async getContentsforPackage( package, purchase ){
	if ( package.contents?.length ) {
		console.log("[contents] Warning! no contents for package ", package?.packageCode );
		return;
	}
	const device = headUnit.device ?? headUnit.lastConnectedDevice;
	if ( !device ) {
		console.log("[contents] Trying to get contents without device!");
		package.contentStatus = @error;
		return;
	}
	package.contentStatus = @filling;
	let snapshotCode = package.snapshot.snapshotCode;
	let res = ?? await getContentsBySnapshotCodes([snapshotCode]);
	if (res) {
		let contents = iter.filter(res.contentsBySnapshotCodes[0].contents, item => item.fileName !="dummy.file" ).toArray();
		package.contents = map( item => { purchase ? new PurchasedContent( new Content(item) ) : new Content( item ) }, contents );
		package.contentStatus = @ready;	
	}
	else {
		package.contentStatus = @error;
		return res;
	}
}

export async getContentsBySnapshotCodes( snapshotCodes ){
	if ( snapshotCodes && snapshotCodes.length ){
		let uri = settings.serverUrl + endpoints.contents;
		let request = setupPostRequest( uri );
		const device = headUnit.device ?? headUnit.lastConnectedDevice;
		const filterOutOsm = false;
		let body = { deviceName: device?.name, lang: languages.langCode, filterOutOsm, snapshotCodes }; 
		request.body = JSON.stringify( body );
		let res = await request.fetch();
		debugLog(request, res, { call: "getContentsBySnapshotCodes", snapshotCodes});
		if ( res && res.status == 200 ) {
			return JSON.parse( res.body );	
		} else {
			return failure( {message: res.statusText, code: res.status } );	
		}
	} else 
		console.warn( "[contents] getContentsBySnapshotCodes called without snapshotCodes.");
}

export async registerDevice(deviceData, ctoken){
	//await Chrono.delay(20s, ctoken);	//for testing purposes only
	let uri = settings.serverUrl + endpoints.deviceReg;
	let request = setupPostRequest(uri, ctoken);
	let body = { device: deviceData };
	request.body = JSON.stringify( body );
	let res = await request.fetch();
	debugLog(request, res, {call: "registerDevice", swid: deviceData.swid });
	if (res && res.status==200)
		return JSON.parse( res.body );
}

export async uploadLicense(device, licenses, swids) {
	let request = setupPostRequest(settings.serverUrl + endpoints.uploadLicense);
	let body = { 
		deviceName: device.name,
		swids: swids ?? device.swids,
		licenses: iter.map(licenses, i => encodeBase64(i.content.buffer)).toArray(),
		licenseNames: iter.map(licenses, i => i.name).toArray(),
	};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	debugLog(request, res, {call: "uploadLicense", swid: device?.swid});
	if (res && res.status==200) {
		return JSON.parse( res.body );
	} else
		return false; 
}

export async getLicenses(device) {
	let request = setupPostRequest(settings.serverUrl + endpoints.getLicenses);
	let body = { deviceName: device.name };
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	debugLog(request, res, {call: "getLicenses", swid: device?.swid});
	if (res && res.status==200) {
		const licenses = JSON.parse(res.body).licenses;
		return licenses;
	} 
}

export async listRights(device) {
	let request = setupPostRequest(settings.serverUrl + endpoints.listRights);
	let body = {deviceName: device.name, lang: languages.langCode};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	debugLog(request, res, {call: "listRights", swid: device?.swid});
	if (res && res.status==200) {
		const rights = JSON.parse(res.body).rights;
		return map( item => { new Right( item ) }, rights );
	} 
}

export async claimFreeSalesPackages(device, userToken, salesPackageCodes) {
	let request = setupPostRequest(settings.serverUrl + endpoints.claimFreeSalesPackages);
	let filterOutOsm = true;
	if ( SysConfig.get("yellowBox", "enableOSM", true) )
		filterOutOsm = false;	
	let body = {deviceName: device.name, lang: languages.langCode, userToken, salesPackageCodes, filterOutOsm};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	const logData = {call: "claimFreeSalesPackages", deviceSwid: device?.swid, salesPackageCodes};
	let pRes = processRes(request, res, logData);
	return pRes;
}

export async recognizeDeviceModel(deviceModel, ctoken) {
	let request = setupPostRequest(settings.serverUrl + endpoints.recognizeDeviceModel, ctoken);
	request.body = JSON.stringify(deviceModel);
	let res = await request.fetch();
	debugLog(request, res), {call:"recognizeDeviceModel", appCid: deviceModel.appcid, agentBrand: deviceModel?.agentBrand};
	if (res && res.status==200) {
		const ret = JSON.parse(res.body);
		return ret;
	}
}

export async getImageBySnapshotCode( code ){
	let res = ?? await getContentsBySnapshotCodes([code]);
	if (res) 
		res = res.contentsBySnapshotCodes[0]?.image;
	return res ?? `https://download.naviextras.com/content/yellow/snapshot/${code}.jpg`;
}

export async registerUser(device, userData, userCredentials, applicationChannel) {
	let request = setupPostRequest(settings.serverUrl + endpoints.registerUser);
	let body = {userData, userCredentials};
	if (device?.name) body.deviceName = device.name;
	if (applicationChannel) body.applicationChannel = applicationChannel;
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	const logParams = {call: "registerUser", deviceSwid: device?.swid, userEmail: userData?.email};
	return processRes(request, res, logParams);
}

export async resendRegistrationEmail(device, email, applicationChannel) {
	const request = setupPostRequest(settings.serverUrl + endpoints.resendRegistrationEmail);
	const body = { email, lang: languages.langCode };
	if (applicationChannel) body.applicationChannel = applicationChannel;
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	const logParams = {call: "resendRegistrationEmail", deviceSwid: device?.swid, userEmail: email};
	return processRes(request, res, logParams);
}

export async bindDevice(device, userToken, ctoken) {
	let request = setupPostRequest(settings.serverUrl + endpoints.bindDevice, ctoken);
	let body = {deviceName: device.name, userToken};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	const logParams = {call: "bindDevice", deviceSwid: device?.swid, userToken};
	return processRes(request, res, logParams);
}

export async loginUser(userCredentials) {
	let request = setupPostRequest(settings.serverUrl + endpoints.loginUser);
	let body = {userCredentials};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, {call: "loginUser", username: userCredentials?.email});
}

export async updateUser(userToken, userData, userCredentials) {
	let request = setupPostRequest(settings.serverUrl + endpoints.updateUser);
	let body = {userToken, userData, userCredentials};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, { call: "updateUser", userData});
}

export async getUser(userToken) {
	let request = setupPostRequest(settings.serverUrl + endpoints.getUser);
	let body = {userToken};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, {call: "getUser", userToken});
}

export async newsLetterOperation( userToken, operation=@subscribe, channel=config.device.channel ) {
	let request = setupPostRequest(settings.serverUrl + endpoints[ operation ]);
	let body = {userToken, channel};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, {call: "newsLetterOperation", channel, operation: string(operation), userToken});
}

export async pushNotificationOperation(userToken, operation, applicationChannel) {
	let request = setupPostRequest(settings.serverUrl + "/" + string(operation) );
	let body = {userToken, applicationChannel};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, {call: "pushNotificationOperation", applicationChannel, operation: string(operation), userToken});
}

export async pollSalesforceKey(userToken, ctoken) {
	let request = setupPostRequest(settings.serverUrl + endpoints.pollSalesforceKey, ctoken);
	let body = {userToken};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	let processed = processRes(request, res, {call: "pollSalesforceKey", userToken});
	if ( processed.success ) {
		let retryAfter = ?? res.headers.get("retry-after");
		if (retryAfter)
			processed.retryAfter = (+retryAfter*1000) ?? undef;
	}
	return processed;
}

export async changeUserPassword(userToken, oldPassword, newPassword) {
	let request = setupPostRequest(settings.serverUrl + endpoints.changeUserPassword);
	let body = {userToken, oldPassword, newPassword};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, {call: "changeUserPassword", userToken});
}

export async forgotUserPassword(email, applicationChannel) {
	let request = setupPostRequest(settings.serverUrl + endpoints.forgotUserPassword);
	let body = {email};
	if (applicationChannel) body.applicationChannel = applicationChannel;
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, {call: "forgotUserPassword", email});
}

export async purchase(device, userToken, salesPackageCodes, currency, vouchers=[], ctoken) {
	let request = setupPostRequest(settings.serverUrl + endpoints.purchase, ctoken);
	let filterOutOsm = true;
	if ( SysConfig.get("yellowBox", "enableOSM", true) )
		filterOutOsm = false;	
	let body = {lang: languages.langCode, deviceName: device.name, userToken, salesPackageCodes, currency, vouchers, filterOutOsm};
	body.applicationChannel = config.device.channel;
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	return processRes(request, res, {call:"purchase", deviceSwid: device?.swid, salesPackageCodes, currency, userToken});
}

export async purchasePoll(device, userToken, primaryInvoiceId, ctoken) {
	let request = setupPostRequest(settings.serverUrl + endpoints.purchasePoll, ctoken);
	let body = {deviceName: device.name, userToken, primaryInvoiceId};
	request.body = JSON.stringify(body);
	let res = await request.fetch();
	let processed = processRes(request, res, {call: "purchasePoll", primaryInvoiceId});
	if ( processed.success ) {
		let retryAfter = ?? res.headers.get("Retry-After");
		if (retryAfter)
			processed.retryAfter = (+retryAfter*1000) ?? undef;
	}
	return processed;
}

export async analyzeCode( code, userToken ){
	let request = setupPostRequest(settings.serverUrl + endpoints.analyzeCode);
	let body = { code, userToken };
	request.body = JSON.stringify( body );
	let res = await request.fetch();
	return processRes(request, res, {call: "analyzeCode", code});	
}

export async claimFreeSalesPackagesWithScratch( device, userToken, scratchCode, salesPackageCodes) {
	let request = setupPostRequest(settings.serverUrl + endpoints.claimFreeSalesPackagesWithScratch);
	let attrs = { deviceName: device.name, lang: languages.langCode, userToken, scratchCode, salesPackageCodes, filterOutOsm: true };
	if ( SysConfig.get("yellowBox", "enableOSM", true) )
		attrs.filterOutOsm = false;
	if ( SysConfig.get("yellowBox", "onlyEU", 1) )
		attrs.filterAreaAlpha3s = ["AAB"];
	request.body = JSON.stringify(attrs);
	let res = await request.fetch();
	const logData = {call: "claimFreeSalesPackagesWithScratch", deviceSwid: device?.swid, scratchCode, salesPackageCodes};
	return processRes(request, res, logData);	
}
