import {  CancellationTokenSource } from "system://core.observe"
import { event } from "system://core.types"

export createTokenSource() {
	return new CancellationTokenSource();
}

export createLinkedTokenSource(tokens) {
    return new CancellationTokenSource(...tokens);
}

export getDefaultEventSettings() {
    return { cancellable:false, reentrant:true, passEventArg:false };
}

export createEvent(settings) {
    let cancellable = settings.cancellable ?? false;
    let reentrant = settings.reentrant ?? true;
    let passEventArg = settings.passEventArg ?? false;
    return new event({ cancellable, reentrant, passEventArg});
}
