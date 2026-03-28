import * as windowInsets from "android_internal://windowInsets"?
import {WeakMap} from "system://core.types"
import {windowInsetsChanged} from "./windowInsetsEvent.xs"

WeakMap subscriptions;

/// When the window's visible bounds change, we want to update the inner size of the window automatically
/// so that the window's content can react to those changes.
export bindVisibleBoundsToInnerSize(window) {
    const listener = ( bounds ) => {
        window.setInnerOffsetPx(bounds.left, bounds.top);
        window.setInnerSizePx(bounds.right - bounds.left, bounds.bottom - bounds.top);
        windowInsetsChanged.trigger( window );
    };    

    if (const view = window?.nativeWindow) {
        const subs = windowInsets?.subscribeVisibleBoundsChanged(view, listener);
        subscriptions.set(window, subs);
    }
}

/// The target SDK 35 or higher on a device running Android 15 or higher, your app is displayed edge-to-edge. 
/// The window spans the entire width and height of the display by drawing behind the system bars. System bars include the status bar, caption bar, and navigation bar.
export bindWindowInsetsToPadding(window) {
    const listener = ( bounds ) => {
        windowInsetsChanged.trigger(window, bounds);
    };    

    if (const view = window?.nativeWindow) {
        const subs = windowInsets?.subscribeWindowInsets(view, listener);
        subscriptions.set(window, subs);
    }
}

export queryWindowInsets(window) {
    if (const view = window?.nativeWindow) {
        const paddings = windowInsets?.getCurrentWindowInsets(view);
        windowInsetsChanged.trigger(window, paddings);
    }
}
