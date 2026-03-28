import * as androidPermissions  from "android://permissions"?
import * as objc from "system://objc"?
import * as iosPermissions from "uie/ios/iosPermissions.xs"

interface PermissionResult {
    granted;
    shouldShowRationale;
}

export enum PermissionType {
    NOTIFICATION = "NOTIFICATION",
    LOCATION_FINE = "LOCATION_FINE",
    LOCATION_COARSE = "LOCATION_COARSE",
    STORAGE = "STORAGE",
    TRACKING = "TRACKING",  // ios only
}

/// @returns {PermissionResult}
export async requestPermission(permissionType) { 
    let res = #{ granted: false, shouldShowRationale: false };
    if (androidPermissions){
        res = await androidPermissions.requestPermission(permissionType);
    } else if (objc) {
        res = await iosPermissions.requestPermission(permissionType);
    }
    console.log(`[Permissions] Type: ${permissionType}, granted: ${res?.granted}, shouldShowRationale: ${res?.shouldShowRationale}`);
    return res;
}

/// @returns {bool}
export async isPermissionGranted(permissionType) {
    if (androidPermissions)
        return androidPermissions.isPermissionGranted(permissionType);
    if (objc)
        return iosPermissions.isPermissionGranted(permissionType);
    return false;
}

export openSettings(permissionType) {
    if (androidPermissions)
        return androidPermissions?.openSettings(permissionType);
    if (objc)
        return iosPermissions.openSettings(permissionType);
}
