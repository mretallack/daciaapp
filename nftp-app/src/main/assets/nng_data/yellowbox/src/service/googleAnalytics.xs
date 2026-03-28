import JSON from "system://web.JSON"
import * as androidModule from "android://googleAnalytics"?

const apiDebug = SysConfig.get("yellowBox", "apiDebug", false);

export class GoogleAnalyticsBackend {
    readonly needsNetwork = true;
    userId = @unset; // using @unset, so when first event contains undef, we will call setUserId(undef)
                     // this can be important in edge cases, when the user quits after signOut and the setUserId call would be sent only with the next event
    
    constructor(options) {}
    
    sendEvents(events) {
        for (const evt in events) {
            if (this.userId != evt.userId) {
                this.userId = evt.userId;
                androidModule?.setUserId(this.userId);
            }
            androidModule?.logCustomEvent(evt.type, evt?.props ?? #{});
            if (apiDebug) {
                const user = evt?.userId ? ` (user: ${evt.userId})` : '';
                const appVersion = evt?.appVersion ? ` (appVersion: ${evt.appVersion})` : '';
                const props = evt?.props ? JSON.stringify(evt.props) : '';
                console.log(`[event] ${evt.type}${user}${appVersion} ${props}`);
            }
        }
    }
}

export gaItem(package, salesPackage) {
	let item = {item_id: package.packageCode, item_name: package.locale.title};
	if (salesPackage) {
		item.price = salesPackage.actualPrice.net;
		item.salesPackageCode = salesPackage.salesPackageCode;
		if (salesPackage?.usedVoucherCode) {
			item.coupon = salesPackage.usedVoucherCode;
		}
	}
	return item;
}

export gaEventPrice(salesPackage) {
	#{
		value: salesPackage.actualPrice.net,
		currency: salesPackage.actualPrice.currency,
	};
}

export gaEntries(entries) {
    Iter.map(entries, i => i.name).toArray()
}

export gaSelectedEntries(entries) {
    gaEntries(Iter.filter(entries, e=>e.selected))
}
