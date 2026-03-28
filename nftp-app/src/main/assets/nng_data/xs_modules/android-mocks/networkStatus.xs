/// [module] android://network.status
import {onChange, observeValue, bundleChanges} from "system://core.observe"
import {isCallable} from "system://core"

object currentStatus { 
    available = true;
    internet = true;
    metered = false;
    type = do{ nng.networking.NetworkType.WIFI };
    toDict() { #{available: this.available, internet: this.internet, metered: this.metered, type: this.type}; }
};

export getStatus() {
    return currentStatus.toDict();
}

// each subscribe call creates a new instance to mimim the behaviour of kotlin implementation
export const subscribe = observeValue(()=> currentStatus.toDict()).subscribe(?);

export unsubscribe(eventEmitter) {
    // empty
}

export update(status) {
    bundleChanges( _ => {
        currentStatus.available = status?.available ?? currentStatus.available;
        currentStatus.internet = status?.internet ?? currentStatus.internet;
        currentStatus.metered = status?.metered ?? currentStatus.metered;
        currentStatus.type = status?.type ?? currentStatus.type;
    });
}
