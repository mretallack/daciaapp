import {observeValue, bundleChanges} from "system://core.observe"
import * as objc from "system://objc"?
import * as os from "system://os"

const NetworkPathMonitor = objc?.getClass("NetworkPathMonitor");
class NetworkStatusModule {
    #pathUpdateHandler;
    #pathMonitor;

    start() {
        this.#pathUpdateHandler = objc?.makeBlock("v@?@", this.#onPathUpdate);
        this.#pathMonitor = NetworkPathMonitor.alloc().initWithHandler(this.#pathUpdateHandler);
    }

    #onPathUpdate(status) {
        bundleChanges( _ => {
            currentStatus.available = status?.available ?? currentStatus.available;
            currentStatus.internet = status?.internet ?? currentStatus.internet;
            currentStatus.metered = status?.metered ?? currentStatus.metered;
            currentStatus.type = status?.type ?? currentStatus.type;
        });
    }

    getStatus() {
        return currentStatus.toDict();
    }

    // each subscribe call creates a new instance to mimim the behaviour of kotlin implementation
    subscribe(func) {
        observeValue(()=> currentStatus.toDict()).subscribe(func);
    }

    unsubscribe(eventEmitter) {
        // empty
    }
}

object currentStatus { 
    available = true;
    internet = true;
    metered = false;
    type = do{ nng.networking.NetworkType.WIFI };
    toDict() { #{available: this.available, internet: this.internet, metered: this.metered, type: this.type}; }
};

export NetworkStatusModule networkStatusModule;

@onStart
start() {
    if (os.platform == "ios")
        networkStatusModule.start();
}
