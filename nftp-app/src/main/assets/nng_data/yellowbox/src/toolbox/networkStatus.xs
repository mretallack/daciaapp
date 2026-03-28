import * as networkStatusModuleAndroid from "android://network.status"?
import { EventEmitter } from "system://core.observe"
import {onChange} from "core://observe"
import { @disposeNull } from "core/dispose.xs"
import * as os from "system://os"
import { connectable} from "system://core.observe"
import { networkStatusModule as iosNetworkStatusModule } from "./platform/iosNetworkStatus.xs"

// From networking\status\src\StatusProvider.xs
class StatusModuleHandlerAndroid {
	@disposeNull
	#event = do { connectable(networkStatusModuleAndroid, @subscribe) }

	async getCurrentStatus()
	{
		return networkStatusModuleAndroid.getStatus();
	}
	
	getStatusObserver() { this.#event }
}

@dispose
const statusModuleHandler = (os.platform == "android") ? new StatusModuleHandlerAndroid() : undef;
const networkStatusModule = (os.platform == "ios") ? iosNetworkStatusModule : networkStatusModuleAndroid;

export subscribe(func) {
    if (statusModuleHandler)
        return statusModuleHandler.getStatusObserver().subscribe(status => {
            console.log("Network status changed:", status);
            func(status);
        });
	
	return networkStatusModule.subscribe(func);
}

export update(status) {
	if (os.platform == "win32")
		networkStatusModule.update(status);
}

export hasInternet() {
	return networkStatusModule.getStatus().internet;
}

export getStatus() {
	return networkStatusModule.getStatus();
}
