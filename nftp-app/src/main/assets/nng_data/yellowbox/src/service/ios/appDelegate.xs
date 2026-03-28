import {AppDelegateClass} from "uie/ios/AppDelegate.xs"
import {@objcProto} from "uie/darwin/objc_support.xs"
import * as objc from "system://objc"?
import { EventEmitter } from "system://core.observe"
import {windowInsetsChanged} from "uie/android/windowInsetsEvent.xs"
import inputFocus from "uie/input/inputFocus.xs"
import {handleResultUrlStr} from "../purchase.xs"
import {urlHandler} from "../../start.xs"
import {parse} from "system://web.URI"

const SFMCSdk = objc.getClass("SFMCSDK.SFMCSdk");

@objcProto(AppDelegateClass)
class YellowBoxAppDelegate {
    bgCompletionHandler;
    #emitter = new EventEmitter;

    getEvent() {
        return this.#emitter.event;
    }

    openURL(url) {
        // todo: should check scheme and domain + path before and dispatch accordinggly
        //  like the android handler does
        handleResultUrlStr(url);
    }
    
    willResignActive() {
        console.log("[AppDelegate] Yellowbox will go to background");
        inputFocus.setInputFocus(undef, screen.root);
        this.#emitter.next(@AppGoToBackground);
    }
    
    didBecomeActive() {
        console.log("[AppDelegate] Yellowbox is in foreground");
        this.#emitter.next(@AppGoToForeground);
    }

    handleEventsForBackgroundURLSession(sessionId, completionHandler) {
        this.bgCompletionHandler = completionHandler;
        console.log("[AppDelegate] Handle events for backround downloads: ", sessionId)
    }
    
    keyboardOpened(bottomOffs) {
        console.log(`[AppDelegate] keyboardOpened with size: ${bottomOffs}`);
        const win = screen.root;
        win.setInnerSizePx(win.wPx, win.outerHeightPx - bottomOffs);
        windowInsetsChanged.trigger( win );
    }
    
    keyboardClosed() {
        const win = screen.root;
        win.setInnerSizePx(win.outerWidthPx, win.outerHeightPx);
        windowInsetsChanged.trigger( win );
    }

    async didRegisterRemoteNotifications(token) {
        console.log("[AppDelegate] registered for remote notifications");
        await 0;
        SFMCSdk.mp.setDeviceToken(token);
    }

    didFailToRegisterRemoteNotifications(error) {
        console.warn("[AppDelegate]", error);
    }

    async handleRemoteNotification(userInfo, completionHandler) {
        console.log("[AppDelegate] handle remote notification");
        await 0;
        SFMCSdk.mp.setNotificationUserInfo(userInfo);
        await 0;
        completionHandler(0); // todo: UIBackgroundFetchResultNewData
    }

    async handleNotificationResponse(response, completionHandler) {
        console.log("[AppDelegate] notification selected");
        await 0;
        SFMCSdk.mp.setNotificationRequest(response.notification.request);
        await 0;
        const userInfo = response.notification.request.content.userInfo;
        this.processUserInfo(userInfo);
        completionHandler();
    }

    // SFMC has already inited
    async didFinishLaunchingWithOptions(userInfo) {
        console.log("[AppDelegate] launched with options");
        await 0;
        this.processUserInfo(userInfo);
        SFMCSdk.mp.setNotificationUserInfo(userInfo);
    }

    processUserInfo(userInfo) {
        console.log("[AppDelegate] process user info: ", userInfo?.["_sid"]);
        const urlStr = userInfo?.["_od"];
        if (userInfo?.["_sid"] == "SFMC" && urlStr) {
            urlHandler.processUrl(parse(urlStr));
        }
    }
}

export YellowBoxAppDelegate yellowBoxAppDelegate;
