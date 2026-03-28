import { analyzeCode, getContentsforPackage, claimFreeSalesPackagesWithScratch, bindDevice } from "app://yellowbox.updateApi"
import { packageList, Packages } from "../service/packages.xs"
import { currentUser, frForm } from "~/src/profile/user.ui"
import { headUnit } from "../toolbox/connections.xs"
import {i18n} from "system://i18n"
import {fmt} from "fmt/formatProvider.xs"
import {getBanner} from "~/src/components/banner.xs"
import { app, yellowStorage } from "../app.xs"
import {tag} from "../components/tag.ui"
import {contentCard} from "~/src/components/contentCard.xs"
import {frListCardBase} from "~/src/app.ui"
import * as ltr from "system://list.transforms"
import {any} from "system://itertools"
import {packageDetails} from "~/src/details.ui"
import {Messagebox, Button} from "~/src/components/messageboxes.xs"
import {list} from "system://core.types"
import {packageManager} from "../toolbox/packages/packageModel.xs"
import { RedeemCodeError, ErrorMessages } from "../service/datamodel.xs"
import { mapsViewModel } from "../maps.ui"
import {urlHandler} from "~/src/start.xs"
import {parse} from "system://web.URI"

@onStart
onStart() {
    urlHandler.registerUrl("/activate-voucher", handleResultUrl);
}

export parseRedeemUrl( url) {
	handleResultUrl( parse(url) )
}

handleResultUrl(url) {
    console.log("[redeem] Result url received: ", url.toString());
    const code = url.queryParams?.["code"];
	app.next(@Redeem);
	formRedeem.insertCode(code);
}

class RedeemHandler {
    code = "";
	lastCode = "";
	type;
	error;
	giftPackages; // package list for the given gift scracth code 
	selectedGift; // the currently selected gift package
	redeemCodeError;
	savedCodes;
	@dispose devChangeSubs;

	constructor(){
		this.devChangeSubs = headUnit.deviceChangeEvent.subscribe( _ => { 
			this.refreshSavedCodes();
		});
	}
	insertCode(code){
		if (!code)
			console.log("[redeem] code is missing from the result url");
		else {
			this.code = this.lastCode = code;
			this.addCodeToSaved( code );
		}
	}

	init(){
		this.checkDevice(); 
		if ( this.lastCode ) this.code = this.lastCode;
		this.refreshSavedCodes();
	}

    async checkCode(){
		getBanner(@redeem).hide();
		const token = currentUser.token;
		const res = await analyzeCode( this.code, token );
		if ( res?.success && !res?.data?.error && res?.data?.type != "UNKNOWN" ) {
			this.type = res.data.type == "VOUCHER" ? @voucher : @scratch;
			console.log("[redeem] new code entered. type: ", this.type );
		} else {
			if ( res?.data )	// we recieved an answer from the server
				this.removeCodeFromSaved( this.code );
			if ( res?.data?.type == "UNKNOWN" ) {
				this.error = RedeemCodeError.Invalid;
				console.log("[redeem] unknown code entered." );
			}
			else {
				this.error = res?.data?.error ?? RedeemCodeError.Other;
				console.log("[redeem] error response when checking the entered code: ", this.error );
			}
			getBanner(@redeem).show( ErrorMessages.REDEEM[this.error] ?? ErrorMessages.REDEEM[RedeemCodeError.Other], {level: @error});
		}
	}
    async useCode(){
		if ( !this.code ) return;
		this.error = undef;
		this.type = undef;
		await this.checkCode();
		this.giftPackages = undef;
		if ( this.error ) return;
		if ( this.type == @voucher ){
			packageList.addRedeemCode( this.type, this.code );
			app.next(@Voucher);
			console.log( "voucher code added");
		} else {
			// next to gift code page
			app.next(@ScratchCode);
			// query packages for this scratch code
			this.giftPackages = new Packages();
			this.giftPackages.addRedeemCode( this.type, this.code );
		}
	} 

    clear(){ 
		this.code = "";
		this.lastCode = "";
		this.error = undef;
		this.type = undef;
		getBanner(@redeem).hide();
		this.redeemCodeError = undef;
	}

	checkDevice(){
		const dev = headUnit.device ?? headUnit.lastConnectedDevice;
		if ( !dev )
			getBanner(@redeem).show(i18n`Please connect your car to redeem a code`, {level: @error});
	}
	
	selectGift(package) {
		console.log("[redeem] gift package selected. PackageCode: ", package.packageCode );
		this.selectedGift = package;
		getContentsforPackage(package);
		app.next(@ScratchClaim);
	}
	
	async claimSelectedGift() {
		this.redeemCodeError = undef;
		const device = headUnit.device ?? headUnit.lastConnectedDevice;
		const confirmMsgBox = new Messagebox();
		confirmMsgBox.setSecondLineStyle("msgboxLinePadding");
		confirmMsgBox.addLine( fmt( i18n`{0} will be added to this car:`, this.selectedGift.locale.title ));
		confirmMsgBox.addLine(device.customName ?? device.swid); 
		confirmMsgBox.addIcon("shop.svg");
		confirmMsgBox.setId( @claimGiftMsgbox );
		confirmMsgBox.addButton(new Button({ text: i18n`Continue`, closeMsgboxWhenPressed: false, action: async ()=> {
			const redeemMsg = i18n`Redeeming code...`;
			confirmMsgBox.lines = [redeemMsg];
			confirmMsgBox.buttons = [];
			const salesPackage = this.selectedGift.salesPackage.find( e=>e.usedScratchCode);
			if ( !device || !salesPackage ) {
				console.warn("[redeem] Trying to claim package with scratch without device or claimable sales package does not found. Package: ", this.selectedGift.packageCode );
				this.redeemCodeError = i18n`An error occured. Please try again later.`;
				return;
			}
			// Trying to bind the device to the user (because there is no api available to check if it is already binded)
			const bindDevRes = await bindDevice( device, currentUser.token );
			if ( !bindDevRes.success && bindDevRes?.data?.errorType != "DEVICE_HAS_ALREADY_BOUND" ) {
				console.warn("[redeem] claim package with scratch: Binding device to the user failed." );
				this.redeemCodeError = i18n`An error occured. Please try again later.`;
				return;				
			}
			const res = await claimFreeSalesPackagesWithScratch( device, currentUser.token, this.code, [salesPackage.salesPackageCode]);		
			if ( res.success ) {
				console.log("[redeem] claiming the gift package suceeded. packageCode: ", this.selectedGift.packageCode );
				device.addRights(res.data.rights);
				await packageManager.updatePackagesFromRights({refreshRights: false});
				this.removeCodeFromSaved( this.code );
				app.next( @ScratchRedeemed );
			} else {
				console.log("[redeem] claiming the gift package failed. packageCode: ", this.selectedGift.packageCode );
				this.redeemCodeError = res.message ?? i18n`An error occured. Please try again later.`;
			}
			confirmMsgBox.hide();
		} }));
		confirmMsgBox.addButton(new Button({ text: i18n`Cancel`, style: @info}));
		
		confirmMsgBox.show();
	}

	refreshSavedCodes(){
		const email = currentUser?.infos?.email ? currentUser.infos.email : undef;
		const device = headUnit.device ?? headUnit.lastConnectedDevice;
		this.savedCodes = yellowStorage.getRedeemCodes( email, device?.swid );
		if ( this.code )
			this.addCodeToSaved( this.code );
	}

	addCodeToSaved( code ){
		const email = currentUser?.infos?.email ? currentUser.infos.email : undef;
		const device = headUnit.device ?? headUnit.lastConnectedDevice;		
		this.savedCodes = yellowStorage.addRedeemCode( code, email, device?.swid);
	}

	removeCodeFromSaved( ...codes ){
		const email = currentUser?.infos?.email ? currentUser.infos.email : undef;
		const device = headUnit.device ?? headUnit.lastConnectedDevice;	
		let changed = false;
		for ( const code in codes ) {
			const idx = this.savedCodes.findIndex( e=> e==code );
			if ( idx >=0 )
				this.savedCodes = yellowStorage.removeRedeemCode( code, email, device?.swid );
		}
	}

}

export RedeemHandler formRedeem;

<template tCode class=flexible, vertical, extraLargePaddingX onRelease(){ formRedeem.code=item }>
	<text class=paragraph, mainMarginY text=(item) />
	<sprite class=separator />
</template>

export <fragment frRedeem extends = frForm>
	own{
		let device := {headUnit.device ?? headUnit.lastConnectedDevice};
		let email := {currentUser?.infos?.email};
		onChange device( newDev, oldDev ){
			if (!oldDev && newDev)
				getBanner(@redeem).hide();
		}
	}
	<group class=flexible, vertical, afterInput, largePaddingY>
		<text class=paragraph, darkgrey text=i18n`Or choose one from the saved list:` visible := { formRedeem.savedCodes.length ?? false } />
		<text class=label, darkgrey text:={ fmt(i18n`E-mail: {0}`, email ) } visible := { (formRedeem.savedCodes.length ?? false) && email } />
		<text class=label, darkgrey text:={ fmt(i18n`Car: {0}`, device?.customName ) } visible := { (formRedeem.savedCodes.length ?? false) && device } />
        <lister model=( formRedeem.savedCodes ) template=( tCode ) />
    </group>
</fragment>

export <fragment frVoucher class=main, flexible, vertical>
	<group class=flexible, vertical, mainContentPadding flex=1 valign=@top>
		<group class=flexible,vertical,form,formTitle >
			<text class=h2 text=i18n`Discount code`/>
		</group>
		<sprite class=separator, form>
		<text class=paragraph text=i18n`You just redeemed a voucher code!` />
		<text class=paragraph text=i18n`Go to the shop and search for the selected contents marked with this label:` />
		<tag boxAlign=@left class=mainMarginY>
	</group>
	<spacer flex=1>
    <group class=flexible, vertical, mainContentPadding, extraLargePaddingY>
        <sprite class=bg, topLine />
        <button class=footer,action,smallMarginX,smallMarginY text=("Shop") onRelease() { app.selectScreenById(@Shop) } />
    </group>	
</fragment>

<template tGiftPackage class=flexible, vertical w=100% onRelease(){ param?.giftClicked?.(item) }>
	own{
		let headerImg =( item.snapshot.image );
	}
	<contentCard class=extraLargeMarginX marginBottom=8 title=(item.locale.title ?? "") subtitle=(item.snapshot.contentRelease ?? "")  headerImg=(headerImg ?? @unset) tags=(item.tags ?? [])/>			
</template>

<template tGiftHeader class=flexible, vertical, mainContentPadding w=100%>
	<group class=flexible,vertical,form,formTitle >
		<text class=h2 text=(item.title)/>
	</group>
	<sprite class=separator, form>
	<text class=paragraph paddingBottom=8 text=(item.text) />
</template>

export <fragment frScratchCoose extends=frListCardBase>
	own {
		let header = { 	type:@header, 
						title: i18n`Gift code`,
						text: i18n`You are eligible to claim for free one of the following contents:`
			};
		let giftPackages := formRedeem.giftPackages;
		let giftList := ltr.from(list.of(header)).concat( ltr.from( giftPackages?.list ?? []).filter(p => p.salesPackage && any( p.salesPackage, e=>e.usedScratchCode))).build();
		let emptyText = i18n`Sorry, no packages can be redeemed with this code`;
		let emptyVisible = ( giftPackages.status==@ready && giftList.length == 1 );
		let emptyImage = "search.svg";
		let loading = ( giftPackages.status==@loading );
	}
	<sprite class=bg, panel visible=(!emptyVisible && !loading) />
	<alert class=mediumMarginX text=(giftPackages?.errorMessage) visible=(giftPackages.status==@error) />
	<listView flex=1 visible=(!emptyVisible && !loading) model=(giftList) template=tGiftPackage 
		param=( { giftClicked: item => formRedeem.selectGift(item) })
		templateType(){
			if (item?.type==@header) return tGiftHeader;
			return @default;
		}>
		<scroll/>
		<wheel/>
	</listView>	
</fragment>

export <fragment frScratchClaim class=vertical, flexible flex=1 >
	<packageDetails packDetails flex=1 package=(formRedeem.selectedGift) codeError=(formRedeem.redeemCodeError) class=scrollable/>
	<group class=flexible, vertical, mainContentPadding, extraLargePaddingY>
		<sprite class=bg, topLine />
		<button class=footer,action,smallMarginX,smallMarginY text=(i18n`Claim`) onRelease() { formRedeem.claimSelectedGift() } />
	</group>
</fragment>

export <fragment frScratchRedeemed extends=frListCardBase>
	own {
		let header = { 	type:@header, 
						title: i18n`Gift code redeemed`,
						text: i18n`The following content has been added to your owned items, it is ready to download and install.`
					};
		let giftList := ltr.from(list.of(header)).concat( list.of( formRedeem.selectedGift ) ).build();
	}
	<sprite class=bg, panel visible=(!emptyVisible && !loading) />
	<listView flex=1 model=(giftList) template=tGiftPackage templateType(){
			if (item?.type==@header) return tGiftHeader;
			return @default;
		}>
		<scroll/>
		<wheel/>
	</listView>
	<group class=flexible, vertical, mainContentPadding, extraLargePaddingY>
		<sprite class=bg, topLine />
		<button class=footer,action,smallMarginX,smallMarginY text=(i18n`Owned Maps`) onRelease() { mapsViewModel.selectedTabIndex=0; app.selectScreenById(@Maps) } />
	</group>	
</fragment>