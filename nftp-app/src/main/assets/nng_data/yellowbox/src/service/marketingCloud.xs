import * as androidMC from "android://marketingCloud"?
import * as iosMC from "./ios/marketingCloud.xs"
import * as objc from "system://objc"?
import Proxy from "system://core.proxy"
import { Map } from "system://core.types"
import JSON from "system://web.JSON"
import {mcPropertyHandler} from "./marketingCloudProperties.xs"
import * as androidFirebase from "android://firebase"?
import * as os from "system://os"
import { PermissionType, isPermissionGranted} from "uie/android/permissions.xs"

export isInited() {
    const res = marketingCloud?.isInited();
    if (!res) console.warn("[MarketingCloud] not inited");
    return res;
}

export async isTrackingEnabled() {
    if (os.platform == "ios") {
        return isPermissionGranted(PermissionType.TRACKING);
    }
    return true;
}

export async initMarketingCloud(pushServerId, pushNotiEnabled, brand){
    const trackingEnabled = await isTrackingEnabled();
    const enabled = pushNotiEnabled && trackingEnabled;
    const config = pushServerMap[pushServerId].config;
    const firebaseConfig = enabled ? (config.firebase?.[brand] ?? #{}) : #{};
    const marketingCloudConfig = enabled ? (config.marketingCloud?.[brand] ?? #{}) : #{};

    androidFirebase?.configure(firebaseConfig);
    const res = await marketingCloud?.init(marketingCloudConfig);
    if (enabled) {
        enablePush();
    } else {
        disablePush();
    }
    mcPropertyHandler.sync();
}

export async isPushEnabled() {
    if (!isInited()) return;
    return marketingCloud?.isPushEnabled();
}

/// Call it when Notification permission is granted
enablePush() {
    if (!isInited()) return;
    console.log("[MarketingCloud] Call enablePush");
    marketingCloud?.enablePush();
}

disablePush() {
    if (!isInited()) return;
    console.log("[MarketingCloud] Call disablePush");
    marketingCloud?.disablePush();
}

export async getPushToken() {
    if (!isInited()) return;
    marketingCloud?.getPushToken()
}

export async setContactKey(id) {
    if (!isInited()) return;
    marketingCloud?.setContactKey(id);
}

export async getContactKey() {
    if (!isInited()) return;
    marketingCloud?.getContactKey()
}

export async setProfileAttribute(key, value) {
    if (!isInited()) return;
    marketingCloud?.setProfileAttribute(key, value);
}

export async clearProfileAttribute(key) {
    if (!isInited()) return;
    marketingCloud?.clearProfileAttribute(key);
}

export async getProfileAttribute(key) {
    if (!isInited()) return;
    marketingCloud?.getProfileAttribute(key);
}

export async getProfileAttributes(key) {
    if (!isInited()) return;
    marketingCloud?.getProfileAttributes(key);
}

export async addTags(...tags) {
    if (!isInited()) return;
    marketingCloud?.addTags(...tags);
}

export async removeTags(...tags) {
    if (!isInited()) return;
    marketingCloud?.removeTags(...tags);
}

export async getTags() {
    if (!isInited()) return;
    marketingCloud?.getTags()
}

export async getDeviceId() {
    if (!isInited()) return;
    marketingCloud?.getDeviceId()
}

// --- END OF MARKETING CLOUD ---

/// Define config values to init Marketing Cloud SDK:
/// https://salesforce-marketingcloud.github.io/MarketingCloudSDK-Android/sdk-implementation/implement-sdk-google.html
/// Firebase initialized without using google-services.json, so we select Firebase projects runtime. The required values used from the google-services.json.
/// https://firebase.google.com/docs/projects/multiprojects#use_multiple_projects_in_your_application
export const pushServerMap = new Map([
    ("none", #{
        id: "none",
        name: "No push notifications",
        config: #{firebase: #{}, marketingCloud: #{}}
    }),
    ("internal", #{
        id: "internal",
        name: "Internal Push Notifications",
        config: #{
            firebase: #{
                dacia_ulc: #{
                    projectId: "yellowbox-internal",
                    applicationId: "1:868787701638:android:d599eb990c620117134e07", 
                    apiKey: "AIzaSyAZ4ZuNRwwxjjBQ-3sSqkNmyWPpjO0zBic",
                },
                renault: #{
                    projectId: "yellowbox-internal",
                    applicationId: "1:868787701638:android:d448d01f758a4092134e07", 
                    apiKey: "AIzaSyAZ4ZuNRwwxjjBQ-3sSqkNmyWPpjO0zBic",
                }
            },
            marketingCloud: #{
                dacia_ulc: #{
                    applicationId: "befe6229-9eb2-4b50-b78b-69b5d4557d17",
                    accessToken: "DJn3RiJEP3B3iLUFf973aZYb",
                    senderId: "868787701638",
                    mid: "10958465",
                    serverUrl: "https://mcrskd1k300wghn62xmkvbgs9l81.device.marketingcloudapis.com/",
                },
                renault: #{
                    applicationId: "befe6229-9eb2-4b50-b78b-69b5d4557d17",
                    accessToken: "DJn3RiJEP3B3iLUFf973aZYb",
                    senderId: "868787701638",
                    mid: "10958465",
                    serverUrl: "https://mcrskd1k300wghn62xmkvbgs9l81.device.marketingcloudapis.com/",
                }
            }
        }
    }),
    ("production", #{
        id: "production",
        name: "Production Push Notifications",
        config: #{
            firebase: #{
                dacia_ulc: #{
                    projectId: "dacia-map-update",
                    applicationId: "1:1095036519096:android:33de9e5d71259c25616a4d", 
                    apiKey: "AIzaSyBy1xOJfZSxJbWruGBGT6NHP3_4O0S1nNI",
                },
                renault: #{
                    projectId: "renault-map-update",
                    applicationId: "1:510550711234:android:7ef3ca7f9e1618aa32545b", 
                    apiKey: "AIzaSyB2A6HgNOHoMb6x_-QOub8OJ3oXOa6-Q5I",
                }
            },
            marketingCloud: #{
                dacia_ulc: #{
                    applicationId: "7a3b1257-503f-4040-af44-d7cfec9c4205",
                    accessToken: "0ZQHKZDvWmQJrm0s5qfX9tmk",
                    senderId: "1095036519096",
                    mid: "10958465",
                    serverUrl: "https://mcrskd1k300wghn62xmkvbgs9l81.device.marketingcloudapis.com/",
                },
                renault: #{
                    applicationId: "4bd2328c-dc3c-4112-b293-3ab923dadfc0",
                    accessToken: "b5ndaOkgDsx1LEKpF9M4CVjq",
                    senderId: "510550711234",
                    mid: "10958465",
                    serverUrl: "https://mcrskd1k300wghn62xmkvbgs9l81.device.marketingcloudapis.com/",
                }
            }
        }
    })
]);

const marketingCloudImpl = androidMC ? androidMC : (objc ? iosMC : mockMarketingCloud);
const marketingCloud = new Proxy({}, new MarketingCloud);
const apiDebug = SysConfig.get("yellowBox", "apiDebug", false);

class MarketingCloud {
    /// @type {(target:object, method:identifier, thisArg:any, ...args:any[])=>any}
    callMethod(target, methodName, thisArg, ...args) {
        if (apiDebug) {
            console.log(`[MarketingCloud] ${methodName} (${JSON.stringify(args)})`);
        }
        marketingCloudImpl?.[methodName]?.(...args);
    }
}

object mockMarketingCloud {
    initialized = false;
    isInited() {
        return this.initialized;
    }
    init(marketingCloudConfig) {
        this.initialized = marketingCloudConfig?.serverUrl != undef;
    }
}
