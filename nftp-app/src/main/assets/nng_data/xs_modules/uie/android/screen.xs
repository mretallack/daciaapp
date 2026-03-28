import * as os from "system://os";

// for values please check android sdk: http://developer.android.com/reference/android/R.attr.html#screenOrientation
export enum Orientations {
    Auto = -1,
    Landscape = 0,
    Portrait = 1,
    Sensor = 4,
    SensorLandscape = 6,
    SensorPortrait = 7,
    ReverseLandscape = 8,
    ReversePortrait = 9
}

const runningOnAndroid = os.platform == "android";

/// Request that the activity associated with the given window to change to the requested orientation value.
///
/// From the android documentation:
/// Change the desired orientation of this activity. If the activity is currently in the foreground or otherwise impacting 
/// the screen orientation, the screen will immediately be changed (possibly causing the activity to be restarted). 
/// Otherwise, this will be used the next time the activity is visible.
export requestOrientation(window, orientation = Orientations.Auto) {
    if (!runningOnAndroid)
        return; // ignore request on non-android platforms
    const activity = window.nativeWindow.context; // assuming that the context of NNGSurfaceView is an activity 
    activity.requestedOrientation = orientation;
}