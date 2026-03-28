import { ident } from "system://core"
import { frLab, labSettings } from "./lab.ui"?
import { frApplication, frNotification, frToasts } from "./app.ui"
import { frOnboarding } from "./onboarding.ui"
import { frDetails } from "./details.ui"
import { frBasket } from "./basket.ui"
import { frShop } from "./shop.ui"
import { frUserProfile, frCars, frSettings, frCarSettings, settingsProperties } from "./profile/userProfile.ui"
import { filter } from "system://list.transforms"
import { frProfile } from "./maps.ui"
import { state, controller, list, Map, array } from "system://core.types"
import { unique, from } from "system://itertools"
import { Storage } from "system://core.types"
import * as androidApp from "android://app"?
import { frForm, formHandler, frForgotPassword, formCar, currentUser, frSignInOrRegister } from "./profile/user.ui"
import {frDropDownFragment} from "./components/dropMenu.ui"
import { frHelpMain, frHelpShop, frHelpConnect, frHelpTransfer, frHelpOsUpdate } from "./profile/help.ui"
import { st_ListRestorerHolder } from "uie/util/listState.xs"
import { i18n } from "system://i18n"
import { getBanner } from "./components/banner.xs"
import { trackEvent, setUserId } from "analytics/analytics.xs"
import {} from "uie/util/refreshTextOnLangChange.xs"?
import { formRedeem, frRedeem, frVoucher, frScratchCoose, frScratchClaim, frScratchRedeemed } from "./profile/redeem.xs"
import * as marketingCloud from "./service/marketingCloud.xs"
import { PermissionType, requestPermission, isPermissionGranted} from "uie/android/permissions.xs"
import { Messagebox, Button, frMessageboxWithCheckbox } from "./components/messageboxes.xs"
import { brandTexts } from "~/brands/brandTexts.xs"
import {basket} from "./basket.xs"
import * as os from "system://os"

export const config = getConfig(); 

getConfig(){
    const brand = SysConfig.get("yellowbox", "brand", "dacia_ulc");
    const configFile = "~/brands/" + brand + ".json";
    return System.import( configFile, { with: {type: @json }} ).default ?? 
        #{  links: #{default: "https://naviextras.com"}, 
            device: #{ channel: "naviextras.com", brand: "", model: "" },
            defaultTheme: "naviextras"
        };
}

class YellowStorage {
    #storage = new Storage("yellowbox");
    #lastUse;
    #permanentlyDeleted = false;
    #wifiOnly;
    #langCode;
    #savedRedeemCodes;
    #serverLangCode = "en";
    #notiPermissionAsked;
    pushNotiEnabled;
    get lastUse(){ this.#lastUse };
    
    constructor(){
        this.#lastUse = this.#storage.getItem("lastUseDate") ?? 0L;
        this.#wifiOnly = this.#storage.getItem("wifiOnly") ?? false;
        this.#langCode = this.#storage.getItem("langCode") ?? SysConfig.get("yellowbox", "language", undef);
        this.#savedRedeemCodes = this.#storage.getItem("redeemCodes") ?? new Map;
        this.#notiPermissionAsked = this.#storage.getItem("notiPermissionAsked") ?? false;
        this.pushNotiEnabled = this.#storage.getItem("pushNotiEnabled") ?? false;
        this.saveLastUseDate();
        console.log( "[App] Last usage: ", new Uiml.date( this.#lastUse ).tostring() );
        console.log( "[App] Lang: ", this.#langCode );
    }

    clear() {
        this.#storage.clear();
        this.#permanentlyDeleted = true;
    }

    saveLastUseDate(){
        if (!this.#permanentlyDeleted) {
            const unixTimestamp = Uiml.date.now();
            this.#storage.setItem( "lastUseDate", unixTimestamp );
        }
    }

    isOnboardingFinished(){ return this.#storage.getItem("onboarding_finished") ?? false }
    async onOnboardingFinished( finishParams ){ 
        this.#storage.setItem("onboarding_finished", true);
        this.#storage.setItem("notiPermissionAsked", true);
        const pushEnabled = finishParams.pushEnabled;
        if (pushEnabled){
            await requestSFPermissions();
        }
        this.pushNotiEnabled = pushEnabled;
    }
    getLastUser(){ return this.#storage.getItem("lastUsedUsername") ?? "" }
    setLastUsedUsername( name ){ 
        if(name) {
            this.#storage.setItem("lastUsedUsername", name) };
            console.log( "[App] Set last user name to ", name );
        }
    getUserAccessToken() { this.#storage.getItem("accessToken") ?? undef }
    setUserAccessToken(token) { this.#storage.setItem("accessToken", token) }
    getUserSalesforceKey(email) { this.#storage.getItem(`salesforceKey@${email}`) ?? undef }
    setUserSalesforceKey(email, key) { this.#storage.setItem(`salesforceKey@${email}`, key) }

    get otherServer(){ this.#storage.getItem("otherServerUrl") ?? "" }
    set otherServer( serverUrl ){ this.#storage.setItem("otherServerUrl", serverUrl) }
    get selectedServer(){ this.#storage.getItem("selectedServer") ?? undef }
    set selectedServer( server ){ this.#storage.setItem("selectedServer", server ) }
    get wifiOnly(){ return this.#wifiOnly }
    set wifiOnly( newVal ){ 
        this.#wifiOnly=newVal; this.#storage.setItem("wifiOnly", newVal);
        console.log( "[App] Set wifiOnly to ", newVal );
        trackEvent("settings", { id: "wifiOnly", value: newVal });
    }
    get langCode(){ return this.#langCode }
    set langCode( newVal ){ 
        this.#langCode=newVal; 
        this.#storage.setItem("langCode", newVal);
        console.log( "[App] Set langcode to ", newVal );
        trackEvent("settings", { id: "langCode", value: newVal });
    }
    get serverLangCode(){ return this.#serverLangCode }
    set serverLangCode( newVal ){ this.#serverLangCode=newVal; this.#storage.setItem("serverLangCode", newVal) }
    get showHowToUpdateMessagebox(){ this.#storage.getItem("showHowToUpdateMessagebox") ?? true }
    set showHowToUpdateMessagebox(newVal) { this.#storage.setItem("showHowToUpdateMessagebox", newVal); }
    set notiPermissionAsked( newVal ){ this.#storage.setItem("notiPermissionAsked", newVal) }
    get notiPermissionAsked(){ return this.#storage.getItem("notiPermissionAsked") ?? false }
    onChange pushNotiEnabled( isEnabled, wasEnabled){
        if (wasEnabled == undef) return;
        this.#storage.setItem("pushNotiEnabled", isEnabled);
        trackEvent("settings", { id: "pushNotiEnabled", value: isEnabled });
        currentUser.setPushNotificationEnabled(isEnabled);
        const pushServerId = SysConfig.get("yellowBox", "pushServer", defaultPushServer);
        const brand = SysConfig.get("yellowbox", "brand", "dacia_ulc");
        marketingCloud.initMarketingCloud(pushServerId, isEnabled, brand);
    }
    getRedeemCodes( email, deviceSwid ){
        let res = [];
        if ( email && deviceSwid )
            res = res.concat( this.#savedRedeemCodes.get((email, deviceSwid)) ?? []); 
        if ( email && email != @none )
            res = res.concat( this.#savedRedeemCodes.get((email, @none)) ?? []);
        if ( deviceSwid && deviceSwid != @none )
            res = res.concat( this.#savedRedeemCodes.get((@none, deviceSwid)) ?? []);
        // no email, no device
        res = res.concat(this.#savedRedeemCodes.get((@none, @none)) ?? []);  

        return list.from( unique(res.sort())); 
    }

    addRedeemCode( code, email = @none, deviceSwid = @none ){
        const codes = this.#savedRedeemCodes.get((email, deviceSwid)) ?? [];
        if (code)
            codes.push( code );
        this.#savedRedeemCodes.set( (email, deviceSwid), codes );
        this.#storage.setItem( "redeemCodes", this.#savedRedeemCodes );
        this.#storage.markDirty();
        return this.getRedeemCodes( email, deviceSwid );
    }

    removeRedeemCode( code, email = @none, deviceSwid = @none ){
        const removeCodeFromList = ( code, email, deviceSwid ) => {
            const l = this.#savedRedeemCodes.get((email, deviceSwid)) ?? [];
            const idx = l.findIndex( e=>e==code );
            if ( idx < 0 ) return;
            l.remove( idx );
            this.#savedRedeemCodes.set( (email, deviceSwid), l );
        };     
        if ( code ) {
            if ( email && deviceSwid ) removeCodeFromList( code, email, deviceSwid );
            if ( email )  removeCodeFromList( code, email, @none );
            if ( deviceSwid ) removeCodeFromList( code, @none, deviceSwid );
            removeCodeFromList( code, @none, @none );
            this.#storage.setItem( "redeemCodes", this.#savedRedeemCodes );
            this.#storage.markDirty();            
        }
        return this.getRedeemCodes( email, deviceSwid );
    }
}

export YellowStorage yellowStorage;

class Selection {
    package;
    subscription = undef;
    reset(){
        this.package = undef;
        this.subscription = undef;
    }
}

export Selection selection;

state stBase{
    currentScreen;
    screenIdx;
    backVisible;
    /**
    * custom back action on a state
    * @returns: bool, true: the default back procedure will run after the function, false: only this action runs
    */
    backAction;
}

state stShop extends stBase{
    filter = "";
    backAction() {
        if ( this.backVisible ) {
            this.filter = "";
            return false,
        }
        return true;
    }
}

state stForm extends stBase{
    formKey;
    formFields = [];

    enter( controller ) {
        ??getBanner( this?.banner ).hide(); 
        if ( this.formKey )
            this.formFields = formHandler.getFormFields( this.formKey );
    }
}

state stCarSettings extends stForm {
   exit() {
        formCar.saveCarSettings();
        formCar.clear();
    }
}

class App {
    appController = new controller();
    contentController = new controller();

    lMenu = list[ // list of screens, show on the bottom menu
            odict{ menu=true; id=@Shop;    icon="shop.svg"; title=i18n`shop` },
            odict{ menu=true; id=@Cart;    icon="basket.svg"; title =i18n`cart` },
            odict{ menu=true; id=@Maps; icon="map.svg"; title=i18n`maps` },
            odict{ menu=true; id=@UserProfile; icon="profile.svg"; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=(labSettings?.labActive.val); id=@Lab;    icon="lab.svg"; title="Lab" },
            odict{ menu=false; id=@CarList; icon="profile.svg"; title= i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@CarSettings; icon="profile.svg"; title= i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@Settings; icon="profile.svg"; title= i18n`Settings`; parent=@UserProfile },
            odict{ menu=false; id=@UserRegAddressEdit; icon="profile.svg"; title= i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@AddressEdit; icon="profile.svg"; title= i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@UserEdit; icon="profile.svg"; title= i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@ChangePassword; icon="profile.svg"; title= i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@Details; icon="home.svg"; title=i18n`shop`; parent=@Shop },
            odict{ menu=false; id=@UserReg; icon="home.svg"; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@UserSignIn; icon="home.svg"; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@ForgotPassword; icon="home.svg"; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@Help; icon=""; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@HelpShop; icon=""; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@HelpConnect; icon=""; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@HelpTransfer; icon=""; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@HelpOsUpdate; icon=""; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@CheckoutConfirm; icon=""; title=i18n`cart`; parent=@Cart },
            odict{ menu=false; id=@Redeem; icon=""; title=i18n`profile`; parent=@UserProfile },
            odict{ menu=false; id=@Voucher; icon=""; title=i18n`profile`; parent=@Redeem },
            odict{ menu=false; id=@ScratchCode; icon=""; title=i18n`profile`; parent=@Redeem },
            odict{ menu=false; id=@ScratchClaim; icon=""; title=i18n`profile`; parent=@ScratchCode },
            odict{ menu=false; id=@ScratchRedeemed; icon=""; title=i18n`profile`; parent=@UserProfile },
        ];

	states = {
		Lab : ( frLab ? new state( { extends: (new stBase), dname:"Lab", use : frLab } ) : undef),
        Shop : (new state( { extends: ((new stShop), st_ListRestorerHolder), use : frShop, dname:"Shop"} )),
        Details: (new state( { extends: (new stBase), use: frDetails, dname: "Details", exit(controller){ selection.reset() } })),
        Cart : state _ extends (new stBase){ use = (frBasket, @new, frSignInOrRegister); dname = "Cart"; banner = @cart; signInVisible := {basket.size }},
        Maps : (new state( { extends: (new stBase), use : frProfile, dname: "Maps", banner: @purchase, done(){
            getBanner( @purchase ).hide();
            getBanner( @outDatedPackages ).hide();
        }})),
        UserProfile : (new state( { extends: (new stBase), use : (frUserProfile, @new, frSignInOrRegister), dname: "UserProfile" })),
        CarList : (new state( { extends: (new stBase), use : frCars, dname: "CarList" })),
        CarSettings : (new state( { extends: (new stCarSettings), use : frCarSettings,  formKey: @carSettings, dname: "CarSettings" })),
        Settings : (new state( { extends: (new stBase), use : frSettings, dname: "Settings" })),
        Help: (new state( { extends: (new stBase), use : frHelpMain, dname: "Help" } )),
        HelpShop: (new state( { extends: (new stBase), use : frHelpShop, dname: "HelpShop" } )),
        HelpConnect: (new state( { extends: (new stBase), use : frHelpConnect, dname: "HelpConnect" } )),
        HelpTransfer: (new state( { extends: (new stBase), use : frHelpTransfer, dname: "HelpTransfer" } )),
        HelpOsUpdate: (new state( { extends: (new stBase), use : frHelpOsUpdate, dname: "HelpOsUpdate" } )),
        Redeem : (new state( { extends: (new stForm), use : ( @new, frRedeem, frSignInOrRegister ), formKey: @redeem, dname: "Redeem", banner: @redeem,
            init(){ formRedeem.init() },
            exit(){ formRedeem.clear() },    
        })),
        Voucher : (new state( { extends: (new stBase), use : frVoucher, dname: "VoucherAdded" } )),
        ScratchCode : (new state( { extends: (new stBase), use : frScratchCoose, dname: "ScratchCodeChooser" } )),
        ScratchClaim : (new state( { extends: (new stBase), use : frScratchClaim, dname: "ScratchCodeClaim", done(){ formRedeem.redeemCodeError = undef } } )),
        ScratchRedeemed : (new state( { extends: (new stBase), use : frScratchRedeemed, dname: "ScratchCodeRedeem", backAction() { app.selectScreenById(@UserProfile); return false } } )),
        UserSignIn : (new state( { extends: (new stForm), dname: "SignIn",
            use: ( @new, frForm ),
            formKey: @signIn,
            banner: @signIn,
            backAction() {
                formHandler.erasePasswordFields();
                return true;
            }
        } )),
        UserReg : (new state( { extends: (new stForm), dname: "UserReg",
            use: ( @new, frForm ),
            formKey: @register,
            banner: @userReg,
        } )),
        ForgotPassword : (new state( { extends: (new stForm), use : frForgotPassword, dname: "ForgotPassword",
            formKey: @forgotPassword,
            banner: @forgotPassword,
        } )),
        UserRegAddressEdit : (new state( { extends: (new stForm), dname: "UserReg Address",
            use: ( @new, frForm ),
            formKey: @billing,
            banner: @userReg
        })),
        AddressEdit : (new state( { extends: (new stForm), dname: "AddressEdit",
            use: ( @new, frForm ),
            formKey: @editBilling,
            banner: @userEdit,
        })),
        UserEdit: ((new state( { extends: (new stForm), dname: "UserEdit",
            use: ( @new, frForm ),
            formKey: @editUser,
            banner: @userEdit,
        } ))),
        ChangePassword: ((new state( { extends: (new stForm), dname: "ChangePassword",
            use: ( @new, frForm ),
            formKey: @changePassword,
            banner: @changePassword,
        } ))),
        CheckoutConfirm: ((new state( { extends: (new stForm), dname: "CheckOutConfirm",
            use: ( @new, frForm ),
            formKey: @checkoutConfirm,
            banner: @checkoutConfirm,
        } ))),
	}

    appStates = {
        Onboarding : (new state( { use : frOnboarding, dname: "Onboarding" } )),
        Application : (new state( { 
            use : (frApplication, frNotification, frToasts, frDropDownFragment ),
            dname: "Application",
             enter(){
                enterApplication();
             }
        } )),
    }

    constructor(){
        console.log("[App] Application started.");
        // NOTE: in the past we've set userId for analytics based on the last user who is or was logged in, like `const email = yellowStorage.getLastUser();``
        //       this setUserId call will happen only after we retrive the user's credential based on the access token
        trackEvent("startUp");
        this.selectScreenById(@Shop);
    }

    setAppState( id, type = @set ) {
        id = ident(id);
        if ( let state = (this.appStates[id] ?? false) ) {
            this.currentAppState = id;
            if ( type == @set ) {
                this.appController.state = state;
                console.log( "[App] Set app state to ", state?.dname )
            }
            else {
                this.appController.next( state );
                console.log( "[App] Next to the app state ", state?.dname )
            }
            trackEvent("screen_view", {screen_name: state?.dname, type});
        }
    }

    next( id ){
        id = ident(id);
        if ( ??this.appStates[id] )
            this.setAppState( id, @next );
        else if ( ??this.states[id] )
            this.selectScreenById( id, @next );
        else{ // todo error handling
        }
    }

    back() {
        if ( this.appController.current == this.appStates.Application && (this.contentController.queue.size > 1 || this.contentController?.current?.backAction ) ) {
            let needDefaultBack = true;
            if ( this.contentController?.current?.backAction )
               needDefaultBack = this.contentController.current.backAction();
            
            if ( needDefaultBack && this.contentController.queue.size > 1 ) {
                this.contentController.prev();
                console.log( "[App] Back to the state ", this.contentController.current?.dname );
                trackEvent("screen_view", {screen_name: this.contentController.current?.dname, type: "back"});
            }
        }
        else if ( this.appController.queue.size > 1) {
            this.appController.prev();
            console.log( "[App] Back to the state ", this.appController.current?.dname );
            trackEvent("screen_view", {screen_name: this.appController.current?.dname, type: "back"});
        }
        else {
            console.log( "[App] Android Back" );
            trackEvent("screen_view", {screen_name: "moveToBack", type: "back"});
            androidApp?.moveToBack?.();
        }
    }

    backTo( state ){
        const idx = this.contentController.queue.indexOf(state);
        if (  idx>= 0 )
            this.contentController.prev( idx );
        else 
            this.back();
    }

    currentScreen := (??this.contentController.current.screen);
    currentAppState = @Application;
    screenIdx := (this.contentController.current.idx ?? -1);
    
    selectScreenById(id, type = @set) {
        id = ident(id);
        if ( this.contentController?.current?.screen?.id == id )
            return;
        if ( let state = (this.states[id] ?? false) ) {
            state.screen = this.lMenu.find(item => item.id == id);
            state.idx = this.lMenu.findIndex( m => state.screen?.parent == m.id || state.screen.id == m.id );
            if ( type == @set ) {    
                this.contentController.clear();
                this.contentController.state = new state;
                console.log( "[App] Set state to ", state?.dname );
            }
            else {
                this.contentController.next( new state );
                console.log( "[App] Next to the state ", state?.dname );
            }
            trackEvent("screen_view", {screen_name: state?.dname, type});
        }
    }

    selectScreen(screen, type){
        this.selectScreenById( screen.id, ??type );
    }
}

export App app;

async enterApplication() {
    if( !yellowStorage.notiPermissionAsked){
        const brandNotiText = brandTexts[SysConfig.get("yellowbox", "brand")].notificationText ?? 
            { line1: i18n`The app wants to send you notifications.`,
                line2: i18n`Don't miss out on exclusive promotions and navigation updates. We respect your privacy, so we won't overwhelm you!`};
        let data = object{ text= i18n`Do not show this message again`; val=false }; 
        const noti = new Messagebox;
        noti.data = data;
        noti.setFirstLineStyle(@msgboxFirstLineWithSeparator);
        noti.setSecondLineStyle(@secondLine);
        noti.separatorVisible = true;
        noti.addLine( brandNotiText.line1 )
        .addLine(  brandNotiText.line2 )
        .addIcon( "notification_bell.svg")
        .setLayout(frMessageboxWithCheckbox)
        .addButton( new Button({
            text:i18n`Allow`,
            action: _=> { 
                async do{
                    await requestSFPermissions();
                    yellowStorage.notiPermissionAsked = true;
                    yellowStorage.pushNotiEnabled = true;
                    }
            }
        })) 
        .addButton( new Button({ 
            text:i18n`Later`,
            style:@info,
            action: _=> { 
                yellowStorage.pushNotiEnabled = false;
                yellowStorage.notiPermissionAsked = data.val;
            }
        }));
        noti.show();
    }
    //subscribe to app forground.
    settingsProperties.init()
}

// SF: SalesForce
export async requestSFPermissions (){
    const resNotification = await requestPermission( PermissionType.NOTIFICATION );
    if (os.platform == "ios") {
        const resTracking = await requestPermission( PermissionType.TRACKING );
        return #{
            granted: resNotification.granted && resTracking.granted,
            shouldShowRationale: resNotification.shouldShowRationale || resTracking.shouldShowRationale
        }
    }
    return resNotification;
}

export async getSalesforcePermissions() {
    const notification = await isPermissionGranted( PermissionType.NOTIFICATION );
    const tracking = await marketingCloud.isTrackingEnabled();
    return #{notification, tracking};
}

export const defaultPushServer = "production";
