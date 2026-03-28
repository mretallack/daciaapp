/// [module] android://marketingCloud

export isInited() {}
export async init(marketingCloudConfig) {}

/// For debugging
export async getPushToken() {}

/// Set Contact Key. 
/// Registration delayed until a contact key is set by the application.
export async setContactKey(id) {}
export async getContactKey() {}

export async isPushEnabled() {}
/// Call it after the user has accepted the permission to display notifications you will need to notify the SDK.
export enablePush() {}
export disablePush() {}

/// Before you can use attributes, create them in your MobilePush account. Attributes may only be set or cleared by the SDK.
export async setProfileAttribute(key, value) {}
export async clearProfileAttribute(key) {}
export async getProfileAttribute(key) {}
export async getProfileAttributes() {}

/// Dynamically add and remove tags via the SDK. You don’t have to create tags in Marketing Cloud.
export async addTags(...tags) {}
export async removeTags(...tags) {}
export async getTags() {}

export async getDeviceId() {}
