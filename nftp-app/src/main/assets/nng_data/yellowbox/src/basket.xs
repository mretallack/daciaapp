import { list, date, timespan } from "system://core.types"
import { reduce, map } from "system://itertools"
import { claimFreeSalesPackages } from "app://yellowbox.updateApi"
import { app } from "./app.xs"
import {downloadLicenses} from "./utils/box.xs"
import {headUnit} from "./toolbox/connections.xs"
import { Messagebox, Button } from "~/src/components/messageboxes.xs"
import {currentUser, isAccessTokenValid, goToSignIn } from "./profile/user.ui"
import {CancellationTokenSource} from "system://core.observe"
import {purchaseHandler} from "./service/purchase.xs"
import {packageManager} from "./toolbox/packages/packageModel.xs"
import { mapsViewModel } from "./maps.ui"
import { ChangeObserver } from "system://core.observe"
import { i18n } from "system://i18n"
import {fmt} from "fmt/formatProvider.xs"
import {getBanner} from "~/src/components/banner.xs"
import {trackEvent} from "analytics/analytics.xs"
import {packageList, packagesChangedEvent} from "./service/packages.xs"
import { Storage } from "system://core.types"
import {condition} from "./utils/util.xs"
import {formRedeem} from "./profile/redeem.xs"
import {gaItem, gaEventPrice} from "./service/googleAnalytics.xs"

export event basketChanged{passEventArg=false};

export class BasketElement {
	package;
	salesPackage;
	downloadLinks;
	constructor(package, salesPackage, links){
		this.package = package;
		this.salesPackage = salesPackage;
		this.downloadLinks = links;
	}
}

export enum PurchaseStatus
{
	Unknown,
	NotFinished,
	Canceled,
	InvalidToken,
	ApiError,
	Success,
}

export const basketStorage = new Storage("basket");
export isBasketStorageValid() {
	let valid = false;
	const saved = basketStorage.getItem( "basketList" ) ?? [];
	if ( !saved.length ) return false;
	if ( const savedDate = ??basketStorage.getItem( "basketDate" )) {
		let basketDate = new date( savedDate );
		let basketAge = new date(date.now()).sub( basketDate );
		const basketExpireHours = SysConfig.get("yellowBox", "basketExpireHours", 72.0);
		valid = basketAge.value <= new timespan( Unit.value(basketExpireHours, @hours) ).value;
	}
	return valid;
}

@dataRoot
class Basket{
	@dispose #changeObs = ChangeObserver{ onChange(){
		dataRoot.subTotal = reduce( (sum, item) => {sum += item.salesPackage.basePrice.net}, 0, dataRoot.list ); 
		dataRoot.total = reduce( (sum, item) => {sum += item.salesPackage.actualPrice.net}, 0, dataRoot.list ); 

		//dataRoot.totalNet = reduce( (sum, item) => {sum += item.salesPackage.actualPrice.net}, 0, dataRoot.list ); 
		//dataRoot.totalTax = reduce( (sum, item) => {sum += item.salesPackage.actualPrice.vat}, 0, dataRoot.list );	
	}}
	phase = @init;	// @init, @loading, @ready
	@dispose #packagesChangedSubs;
	list = new list();
	size := this.list.length ?? undef;
	onChange size(newVal, oldVal) {
		if ( this.phase != @ready ) return;
		if ( newVal || oldVal ) this.#saveBasket();	// to avoid the first trigger from undef to 0
		if (!oldVal && newVal) basketChanged.trigger(@nonEmpty);
		if (oldVal && !newVal) basketChanged.trigger(@empty);
	}
	subTotal = 0;
	total = 0;
	savings := this.subTotal - this.total;
	//totalNet = 0; 
	//totalTax = 0;
	//total := this.totalNet + this.totalTax;
	currency = i18n`USD`; // todo: check
	osmIsEnabled = do { SysConfig.get("yellowBox", "enableOSM", true) };
	device := headUnit.device || headUnit.lastConnectedDevice;
	purchaseEnabled := currentUser.token && this.device && ( this.osmIsEnabled || !this.device.hasOSM);
	@dispose devChangeSubs;

	constructor(){
		this.#changeObs.observe( this.list, Symbol.list );
		this.#packagesChangedSubs = packagesChangedEvent.subscribe( async() => {
			await condition( _=>this.phase != @loading );
			await this.loadAndValidateBasket() 
		} );
		this.devChangeSubs = headUnit.deviceChangeEvent.subscribe( _ => { 
			if( this.size ){
				let noti = new Messagebox;
				noti.addLine(i18n`Your cart has been cleared due to you're connecting to a new device.`)
				.addIcon("msgbox_warning.svg").addButton( new Button({text:i18n`Ok`}) );
				noti.show();
			}
			this.clear();
		});
	}
	format( price, curr = this.currency ){
		return fmt(`{:.1f} {:s}`, price, curr);
	}

	#saveBasket(){
		basketStorage.setItem( "basketDate", date.now() );
		const basketElements = map( this.list, e=>{ {packageCode: e.package.packageCode, salesPackageCode: e.salesPackage.salesPackageCode} }).toArray();
		basketStorage.setItem( "basketList", basketElements );
	}

	async loadAndValidateBasket(){
		this.phase = @loading;
		this.list.clear();
		const saved = basketStorage.getItem( "basketList" ) ?? [];
		console.log( "[basket] saved basket length: ", saved.length );
		if ( !saved.length ) { this.phase = @ready; return;}
		let wasRemoved = false;
		if ( isBasketStorageValid() ){
			console.log( "[basket] restoring basket" );
			for ( const e in saved ){
				const pack, salesPack = await packageList.getPackageAndSalesPackageByCode( e.packageCode, e.salesPackageCode );
				if ( pack && salesPack ) {
					this.add( new BasketElement(pack, salesPack ));
					console.log( "[basket] basket element has been restored, packageCode: ", e.packageCode, " salesPackageCode: ", e.salesPackageCode );
				}
				else{
					wasRemoved = true;
					console.warn( "[basket] unable to restore package element (code: ", e.packageCode, ", salesPackageCode: ", e.salesPackageCode, " ) because it isn't in the packageList.");
				}
			}
		}
		else
			basketChanged.trigger(@empty);	// todo!
		this.phase = @ready;
		if (wasRemoved) {
			this.#saveBasket();
			const noti = new Messagebox; noti
			.addLine(i18n`Your cart has changed.`)
			.addLine(i18n`Some items are no longer available.`)
			.addIcon("msgbox_warning.svg").addButton( new Button({text:i18n`Ok`}) );
			noti.show();
		}
	}

	add( basketElement ){
		this.list.push( basketElement );
		// todo handle potentially different currencies
		this.currency = basketElement.salesPackage.actualPrice.currency;
	}

	remove( basketElement ) {
		trackEvent("remove_from_cart", #{
			...gaEventPrice(basketElement.salesPackage),
			items: [ gaItem(basketElement.package, basketElement.salesPackage) ],
		});
		console.log("[basket] Removing element from the cart: packageCode: ", basketElement.package.packageCode, ", package name: ", basketElement.package.locale.title, ", salesPackageCode: ", basketElement.salesPackage.salesPackageCode );
		let idx = this.list.findIndex( (e) => { e==basketElement });
		if ( idx >= 0 ) {
			this.list.remove( idx );
		}
		return idx >= 0
	}

	async purchaseNonFree(salesPackages, voucherCodes) {
		if (salesPackages.length == 0) return #{status: PurchaseStatus.Success};
		if (!currentUser.hasValidAddress("INVOICE")) {
			// todo: #design
			console.log( "[basket] Unable to purchase without invoice address." );
			let noti = new Messagebox;
			noti.addLine(i18n`Please create an INVOICE address`)
			.addIcon("msgbox_warning.svg").addButton( new Button({text:i18n`Ok`}));
			await noti.show();
			currentUser.copyToForm();
			app.next(@AddressEdit);
			return #{status: PurchaseStatus.NotFinished};
		} else {
			let cTokenSource = new CancellationTokenSource;
			console.log( "[basket] Initiate purchase. Total: ", this.total, ", currency: ", this.currency, "salesPackages: ", ...salesPackages );
			// todo: #design
			let noti = new Messagebox;
			noti.addIcon("basket.svg").addLine(i18n`Initiate purchase...`)
			.addButton( new Button({text:i18n`Abort`, style: @info, action: _ => { 
				console.log("[basket] Payment canceled by the user.Total: ", this.total, ", currency: ", this.currency, "salesPackages: ", ...salesPackages );
				cTokenSource.cancel(); 
			} }));
			noti.show();
			const res = await purchaseHandler.purchase(salesPackages, this.currency, voucherCodes, cTokenSource.token);
			if (res?.success) {
				noti.lines = [i18n`Please complete the payment in your browser!`];
				let result = await purchaseHandler.waitForPurchase(res.primaryInvoiceId, ()=>{
					noti.lines = [i18n`Finalizing purchase`];
					noti.buttons = [];
				});
				let status = PurchaseStatus.Unknown;
				if (result?.toUpperCase() == "SUCCESS") {	
					status = PurchaseStatus.Success;
					formRedeem.removeCodeFromSaved(...voucherCodes);
					// todo: would be better if server would return the newly acquired rights, and we would process those
					//       until that happens, we assume that the purchase was successfull, and after refreshing the rights
					//       we move the user to the maps screen
					// NOTE: licenses will be downloaded from updatePackagesFromRight
					await packageManager.updatePackagesFromRights({refreshRights: true});
				}
				else if (result?.toUpperCase() == "CANCELED") status = PurchaseStatus.Canceled;
				// todo: handle error cases
				console.log( "[basket] Purchase result: ", result);
				noti.hide();
				return #{status, newLicense: true, response: result};
			} else {
				noti.hide();
				const uTisValid = currentUser.tokenIsValidFromResponse(res);
				const status = cTokenSource.token.canceled ? PurchaseStatus.Canceled : ( !uTisValid ? PurchaseStatus.InvalidToken : PurchaseStatus.ApiError);
				return #{status, response: res};
			}
		}
	}

	async purchaseFree(freeSalesPackages) {
		if (freeSalesPackages.length == 0)
			return #{status: PurchaseStatus.Success};
		console.log( "[basket] Purchasing free packages. SalesPackageCodes: ", ...freeSalesPackages );
		const device = headUnit.device ?? headUnit.lastConnectedDevice;
		const response = await claimFreeSalesPackages(device, currentUser.token, freeSalesPackages);
		const status = response?.success ? PurchaseStatus.Success: ( !currentUser.tokenIsValidFromResponse( response ) ? PurchaseStatus.InvalidToken : PurchaseStatus.ApiError);
		const rights = response?.data?.rights;
		const newLicense = this.hasNewLicense(rights?.length ? rights : undef);
		return  #{status, newLicense, response};
	}

	async purchasePackages() {
		const freeSalesPackages = [];
		const toBuySalesPackages = [];
		const voucherCodes = [];
		for (const element in this.list) {
			const sp = element.salesPackage;
			if (sp.actualPrice.net == 0) {
				if (sp.salesPackageCode) freeSalesPackages.push(sp.salesPackageCode);
			} else {
				toBuySalesPackages.push(sp.salesPackageCode);
				if ( sp?.usedVoucherCode )
					voucherCodes.push( sp.usedVoucherCode );
			}
		}
		const result = await this.purchaseNonFree(toBuySalesPackages, voucherCodes);
		if (result.status != PurchaseStatus.Success) return result;
		else if (formRedeem.savedCodes) formRedeem.removeCodeFromSaved(voucherCodes);
		
		const resFree = await this.purchaseFree(freeSalesPackages);
		const newLicense = result?.newLicense || resFree?.newLicense;
		return #{status: resFree.status, newLicense, response: resFree?.repsonse};
	}
	
	hasNewLicense(rights) {
		for (const r in rights ?? [])
			if (r.licenseRequired) return true;
		return false;
	}

	async buy(){
		trackEvent("begin_checkout", #{
			value: this.total, 
			currency: this.currency, 
			items: Iter.map(this.list, e=> gaItem(e.package, e.salesPackage)).toArray() 
		});
		const result = await this.purchasePackages();
		if (result.status == PurchaseStatus.NotFinished){ 
			trackEvent("purchase_failed", {status: "not finished"});
			return result.status;
		}

		if (result.status != PurchaseStatus.Success) {
			if( result.status == PurchaseStatus.InvalidToken ){
				trackEvent("purchase_failed", {status: "invalid token"});
				goToSignIn();
			} else {
				app.next(@Cart, @set);
				if ( result.status == PurchaseStatus.Canceled || result.status == PurchaseStatus.ApiError ) {
					let noti = new Messagebox;
					let text;
					if (result.status == PurchaseStatus.Canceled) text = i18n`Payment canceled!`;
					if (result.status == PurchaseStatus.ApiError) text = result.response?.message ?? text;
					console.warn("[basket] Payment finished with result: ", string( text ));
					trackEvent("purchase_failed", {status: string(text)});
					noti.addLine( text )
					.addIcon( "msgbox_warning.svg")
					.addButton( new Button({text:i18n`Ok`}));
					noti.show();
				} else {
					trackEvent("purchase_failed", {status: "unknown"});
					getBanner(@cart).show( i18n`Payment failed!`, {level: @error });
				}
			}
			return result.status;
		}
		trackEvent("purchase", #{
			value: this.total, 
			currency: this.currency, 
			items: Iter.map(this.list, e=> gaItem(e.package, e.salesPackage)).toArray() 
		});
		// TODO parameter for the map scecreen
		mapsViewModel.selectedTabIndex = 0; //owned tab
		app.selectScreenById(  @Maps, @set );
		this.clear();
		getBanner(@purchase).show(i18n`Payment Successfull`, {level: @success});
		return result.status;
	}

	clear(){
		this.list.clear();
		packageList.setPackageListProperties();
	}
}

@dispose
export Basket basket;

export checkUserAndDevice(){
	getBanner( @cart ).hide();

	if (!basket.size)
		return;
	let device = headUnit.device ?? headUnit.lastConnectedDevice;
	let bannerText = "";

	if ( !isAccessTokenValid( currentUser.token ) )
		bannerText = i18n`Please sign in before purchase!`;
	elsif (!device)
		bannerText = i18n`Purchase is not available until you have registered your device!`;
	elsif (device.hasOSM && !SysConfig.get("yellowBox", "enableOSM", true))
		bannerText = i18n`Your device contains OSM content. That is not supported by this app.`;
	if ( bannerText ) {
		getBanner(@cart).show( bannerText, { level: @error });
	}
}

showNoDeviceNoti(){
	let noti = new Messagebox;
	noti.addLine(i18n`Purchase is not available until`)
	.addLine(i18n`you have registered your device.`)
	.setOverlay()
	.addIcon( "sadface.svg" )
	.addButton( new Button({text:i18n`Ok`, style:@info }) )
	.show();
}
