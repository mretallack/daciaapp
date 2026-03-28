import * as objc from "system://objc"?

const NSURL = objc.class.NSURL;
const NSMutDict = objc.class.NSMutableDictionary;
const UIApplication = objc.class.UIApplication;
const PushConfigBuilder = objc.getClass("MarketingCloudSDK.PushConfigBuilder");
const SFMCSdk = objc.getClass("SFMCSDK.SFMCSdk");
const ConfigBuilder = objc.getClass("SFMCSDK.ConfigBuilder");

object data {
    status = @none; // @none, @error, @inited @inProgress
}

export isInited() {
    return data.status == @inited;
}

export async init(marketingCloudConfig) {
    data.status = @inProgress;
    console.log("[MarketingCloud] Init");
    const appId = marketingCloudConfig?.applicationId;
    const accessToken = marketingCloudConfig?.accessToken;
    const appEndpoint = marketingCloudConfig?.serverUrl;
    const mid = marketingCloudConfig?.mid;
    if (!appId || !accessToken || !appEndpoint || !mid) {
        data.status = @none;
        UIApplication.sharedApplication.unregisterForRemoteNotifications();
        console.warn("[MarketingCloud] Not a valid configuration.");
        return false;
    }

    return new Promise((resolve) => {
        const completionHandler = objc.makeBlock("v@?i", (result) => {
            if (result == OperationResult.Success) {
                console.log("[MarketingCloud] Init success");
                UIApplication.sharedApplication.registerForRemoteNotifications();
                data.status = @inited;
                resolve(true);
            } else {
                console.log("[MarketingCloud] Init failed");
                data.status = @error;
                resolve(false);
            }
        });
        const pushBuilder = PushConfigBuilder.alloc().initWithAppId(appId);
        pushBuilder.setAccessToken(accessToken);
        pushBuilder.setMarketingCloudServerUrl(NSURL.initWithString(appEndpoint));
        pushBuilder.setMid(mid);
        pushBuilder.setAnalyticsEnabled(true);
        const mobilePushConfiguration = pushBuilder.build;
        const cb = ConfigBuilder.alloc().init();
        const config = cb.setPushWithConfig(mobilePushConfiguration, completionHandler).build;
        SFMCSdk.initializeSdk(config);
    });
}

export async isPushEnabled() {
    SFMCSdk.mp.pushEnabled
}

export enablePush() {
    SFMCSdk.mp.setPushEnabled(true);
}

export disablePush() {
    SFMCSdk.mp.setPushEnabled(false);
}

export async getPushToken() {
    SFMCSdk.mp.deviceToken
}

export async setContactKey(id) {
    // Set contact key for all modules
    SFMCSdk.identity.setProfileId(id);
    // OR set contact key only for the Mobile Push module
    // SFMCSdk.identity.setProfileId([ModuleName.push: "user@mycompany.com"])
}

export async getContactKey() {
    SFMCSdk.mp.contactKey
}

export async setProfileAttribute(key, value) {
    const d = new NSMutDict;
    d.setObject(value, key);
    const success = SFMCSdk.identity.setProfileAttributes(d);
    return success; // TODO: check result why undef
}

export async clearProfileAttribute(key) {
    SFMCSdk.identity.clearProfileAttributeWithKey(key)
}

export async getProfileAttribute(key) {
    const attributes = getProfileAttributes();
    return attributes[key];
}

export async getProfileAttributes(key) {
    const attrs = {};
    const attributes = SFMCSdk.mp.attributes;
    for (const i in attributes) {
        attrs[i] = attributes[i];
    }
    return attrs;
}

export async addTags(...tags) {
    let success = true;
    for (const tag in tags) {
        const res = SFMCSdk.mp.addTag(tag);
        success &&= res;
    }
    return success;
}

export async removeTags(...tags) {
    let success = true;
    for (const tag in tags) {
        const res = SFMCSdk.mp.removeTag(tag);
        success &&= res;
    }
    return success;
}

export async getTags() {
    SFMCSdk.mp.tags
}

export async getDeviceId() {
    SFMCSdk.mp.deviceIdentifier
}

enum OperationResult {
  Cancelled = 0,
  Error = 1,
  Success = 2,
  Timeout = 3,
}
