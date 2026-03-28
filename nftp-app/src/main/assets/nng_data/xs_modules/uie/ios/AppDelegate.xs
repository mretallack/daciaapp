import * as objc from "system://objc"?;

export const AppDelegateClass = objc?.ClassDesc()
    .addMethod("willResignActive", "v@:")
    .addMethod("didBecomeActive", "v@:")
    .addMethod("openURL:", "v@:@")
    .addMethod("eventsForBackgroundURLSession:completed:", 'v@:@@"(v@?)"', @handleEventsForBackgroundURLSession)
    .addMethod("keyboardOpened:", 'v@:i')
    .addMethod("keyboardClosed", 'v@:')
    .addMethod("didRegisterRemoteNotifications:", 'v@:@')
    .addMethod("didFailToRegisterRemoteNotifications:", 'v@:@')
    .addMethod("didReceiveRemoteNotification:fetchCompletionHandler:", 'v@:@@"(v@?I)"', @handleRemoteNotification)
    .addMethod("didReceiveNotificationResponse:withCompletionHandler:", 'v@:@@"(v@?)"', @handleNotificationResponse)
    .addMethod("didFinishLaunchingWithOptions:", 'v@:@')
