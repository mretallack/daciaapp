import * as objc from "system://objc"?
import {PermissionType} from "uie/android/permissions.xs"

const iosNotificationCenter = objc?.class.UNUserNotificationCenter.currentNotificationCenter;
const UIApplication = objc.class.UIApplication;
const NSURL = objc.class.NSURL;
const ATTrackingManager = objc.class.ATTrackingManager;

export async requestPermission(permissionType) {
    let granted = false;
    let shouldShowRationale = false;
    await waitUntilAppInForeground();
    if (permissionType == PermissionType.NOTIFICATION) {
        granted = await requestNotificationPermission();
    }
    if (permissionType == PermissionType.TRACKING) {
        granted = await requestTrackingPermission();
    }
    if (!granted) {
        shouldShowRationale = await getShouldShowRationale(permissionType);
    }
    return #{ granted, shouldShowRationale };
}

/// @returns {bool}
export async isPermissionGranted(permissionType) {
    if (permissionType == PermissionType.NOTIFICATION) {
        const authorizationStatus = await getNotificationAuthorizationStatus();
        return authorizationStatus == AuthorizationStatus.Authorized;
    }
    if (permissionType == PermissionType.TRACKING) {
        const authorizationStatus = ATTrackingManager.trackingAuthorizationStatus;
        return authorizationStatus == ATTrackingManagerAuthorizationStatus.Authorized;
    }
    return false;
}

async requestNotificationPermission() {
    return new Promise((resolve) => {
        const options = AuthorizationOptions.Sound + AuthorizationOptions.Alert;
        const askPermissionHandler = objc.makeBlock("v@?B@", (granted, error) => {
            if (error) console.warn(error.localizedDescription.UTF8String);
            resolve(granted);
        });
        iosNotificationCenter.requestAuthorizationWithOptions(options, askPermissionHandler);
    });
}

async getNotificationAuthorizationStatus() {
    return new Promise((resolve) => {
        const getNotificationHandler = objc.makeBlock("v@?@", (settings) => {
            resolve(settings.authorizationStatus);
        });
        iosNotificationCenter.getNotificationSettingsWithCompletionHandler(getNotificationHandler);
    });
}

/// A boolean if the user has declined the permission in the past and UI should be shown.
async getShouldShowRationale(permissionType) {
    if (permissionType == PermissionType.NOTIFICATION) {
        const authorizationStatus = await getNotificationAuthorizationStatus();
        return authorizationStatus == AuthorizationStatus.Denied;
    }
    if (permissionType == PermissionType.TRACKING) {
        const authorizationStatus = ATTrackingManager.trackingAuthorizationStatus;
        return authorizationStatus == ATTrackingManagerAuthorizationStatus.Denied;
    }
    return true;
}

async requestTrackingPermission() {
    return new Promise((resolve) => {
        const askPermissionHandler = objc.makeBlock("v@?I", (status) => {
            const granted = status == ATTrackingManagerAuthorizationStatus.Authorized;
            resolve(granted);
        });
        ATTrackingManager.requestTrackingAuthorizationWithCompletionHandler(askPermissionHandler);
    });
}

export openSettings(permissionType) {
    UIApplication.sharedApplication.openURL_options(NSURL.initWithString("app-settings:"), undef)
}

async waitUntilAppInForeground() {
    while (true) {
        const state = UIApplication.sharedApplication.applicationState;
        if (state == UIApplicationState.Active) {
            return;
        }
        await Chrono.delay(100ms);
    }
}

enum UIApplicationState {
    Active = 0,
    Inactive = 1,
    Background = 2,
}

enum AuthorizationOptions {
    Badge = 1,
    Sound = 2,
    Alert = 4,
}

enum AuthorizationStatus {
    NotDetermined   = 0,
    Denied          = 1,
    Authorized      = 2,
    Provisional     = 3,
    Ephemeral       = 4,
}

enum ATTrackingManagerAuthorizationStatus {
    NotDetermined   = 0,
    Restricted      = 1,
    Denied          = 2,
    Authorized      = 3,
}
