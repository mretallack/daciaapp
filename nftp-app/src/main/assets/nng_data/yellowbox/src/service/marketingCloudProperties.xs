import {yellowStorage} from "~/src/app.xs"
import { fmt} from "system://fmt"
import { date, Storage, Map, DisposableStack} from "system://core.types"
import * as marketingCloud from "~/src/service/marketingCloud.xs"
import {signInEvent, currentUser} from "~/src/profile/user.ui"
import {carRegistered} from "~/src/toolbox/device.xs"
import {basketChanged} from "~/src/basket.xs"

formatDate( ndate ){
	fmt("{:datetime|%M/%D/%yyyy}", new date(ndate) );
}
formatTime( ndate ){
	fmt("{:datetime|%M/%D/%yyyy %HH:%mm}", new date(ndate) );
}

export object mcPropertyHandler{
	@dispose #subs = new DisposableStack;
	init() {
		this.#subs.use( signInEvent.subscribe( _ => mcCommunicator.setProperty("FirstSignInDate", date.now()) ) );
		this.#subs.use( carRegistered.subscribe ( _ => mcCommunicator.setProperty("RegisterCarDate", date.now()) ) );
		this.#subs.use( basketChanged.subscribe ( 
			state => {
				if (state == @empty) mcCommunicator.clearProperty("AddItemToCartDate");
				else if (state == @nonEmpty) mcCommunicator.setProperty("AddItemToCartDate", date.now())
			})
		);
		mcCommunicator.init();
	}

	sync() {
		mcCommunicator.sync();
	}

	clearStorage() {
		mcCommunicator.clearStorage();
	}
}


object mcCommunicator {
	#storage = new Storage("MCProperties2");
	#keys = new Map([
		("RegisterCarDate",			{once: true, type: @date}),
		("FirstSignInDate",			{once: true, type: @date}),
		("ApplicationLanguage",		{once: false, getValue() { yellowStorage.langCode } }),
		("AddItemToCartDate",		{once: false, type: @time}),
	]);

	init() {
		this.sync();
	}

	accessor appLanguage {
		onChange( nv, ov ){ this.setProperty("ApplicationLanguage", nv);	}
	} := (yellowStorage.langCode);

	clearProperty(key) {
		const info = this.#keys.get(key) ?? undef;
		if (!info) {
			console.warn(`Trying to set an unexisting key ${key}`);
			return;
		}
		this.#storage.setItem(key, undef);
		marketingCloud.clearProfileAttribute(key);
	}

	setProperty(key, value) {
		const info = this.#keys.get(key) ?? undef;
		if (!info) {
			console.warn(`Trying to set an unexisting key ${key}`);
			return;
		}
		const oldValue = this.#storage.getItem(key) ?? undef;
		if (info.once && oldValue) {
			console.log(`${key} changed, but won't be sent to Marketing Cloud.`);
			return;
		}
		this.#storage.setItem(key, value);
		this.#send(info, key, value);
	}

	#send(info, key, value) {
		if (info?.type == @date && value) value = formatDate(value);
		if (info?.type == @time && value) value = formatTime(value);
		if (value)
			marketingCloud.setProfileAttribute(key, value);
	}

	sync() {
		this.#keys.forEach((key, info) => {
			const value = info?.getValue() ?? this.#storage.getItem(key) ?? undef;
			this.#send(info, key ,value);
		});
		// Contact Key can’t be null and can’t be an empty string
		if (currentUser.salesforceKey)
			marketingCloud.setContactKey(currentUser.salesforceKey);
	}

	clearStorage() {
		this.#storage.clear();
	}
}
