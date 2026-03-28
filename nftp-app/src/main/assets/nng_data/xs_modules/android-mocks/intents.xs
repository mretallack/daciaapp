/// [module] android://intents
import {nullSubscription} from "core://observe"
decorator @deprecated(msg) {}
export const ACTION_VIEW = "";

export intentFrom(source) { source }
// creates ActivityOptions from given source, it can be dict specifying properties to be set on top of basic options
// If given an ActivityOptions it is returned as is
export activityOptionsFrom(source) { source}
// starts activity, intent created via intentFrom, activityOptions created via activityOptionsFrom can be undef
export startActivity(intentSource, activityOptSource=undef) { }
export startActivityOn(startCtx, intentSource, activityOpts=undef) {}
// send broadcast intent, using the provided context or activitycontext or global context
export sendBroadcast(intentSource, startCtx=undef) {}

export startService(intentSource) { }
export startForegroundService(intentSource) { }
export async bindService(intentSource) { }
/// @returns the last intent received by the given activity, when undef it will return the last intent received by the main activity
export activityIntent(activity = undef) {}

export class IntentType {
    action;
    componentClass;
    componentPackage;
    component/* string */;
    data;
    extra/* {} */;
    flagClearTop;
}
export class IntentFilterType { // java IntentFilter class
    static [Symbol.call](...args) { new this(...args);}
}
export class BroadcastReceiver {
    subscribe(f) { return nullSubscription}; // f will be called with intent
}
export broadcastReceiver(intentFilter) { new BroadcastReceiver}
export asyncBroadcastReceiver(intentFilter) {new BroadcastReceiver}

@deprecated("use onIntentReceived and/or activityIntent instead")
/// either get the last intent received by the main activity, or subscribe to any new intent received by it
/// DEPRECATED: can't specify target activity, nor will the handler receive the activity for which the intent was dispatched  
export object lastIntent {
    get() {}
    subscribe(handler) { }
};

/// Create an observable which tracks the intents received by a target activity or all activities in the app
/// @param target the target activity whose intents we're intrested in. When set to undef or @all all intents will be observed
//                when set to @main, the intents for the main activity will be observed
/// @param opt    (optional) when @emitCurrent or @emitCurrentValue is used the last (current) intent will be emitted on subscription for all the relevant targets 
/// @returns an observable on which subscribe may be called with a listener (see core.observe module)
export onIntentReceived(target, opt) {}

// see https://developer.android.com/reference/android/app/ActivityOptions
// created via makeBasic but properties are set from initializers
export class ActivityOptionsType {

}