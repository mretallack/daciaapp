// values taken from: https://developer.android.com/reference/android/view/HapticFeedbackConstants
// alos you can extend the enum further based on the link above
export enum HapticFeedback {
    LongPress = 0,
    ToggleOn = 21,
    ToggleOff = 22,
    Confirm = 16,
    Reject = 17,
}

/// @param hapticFeedback one of the HapticFeedback constants above
/// for a guide, see: https://developer.android.com/develop/ui/views/haptics/haptic-feedback#view
export performHapticFeedback(onwindow, hapticFeedback) {
    onwindow.nativeWindow?.performHapticFeedback?.(hapticFeedback)    
}

