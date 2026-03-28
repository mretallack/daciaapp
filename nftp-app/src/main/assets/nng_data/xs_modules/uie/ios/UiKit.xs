import * as objc from "system://objc"?
import {asRgb} from "system://ui.color"


export const UIApplication = objc?.class.UIApplication;
export const NSURL = objc?.class.NSURL;
export const UIColor = objc?.class.UIColor;
export uicolort(r,g,b,a=1.0) { // TODO overload support for uicolor, make a helper accepting multiple functions
    UIColor.initWithRed(r,g,b,a); // initWithRed:green:blue:alpha:
}
export uicolor(col) {
    UIColor.initWithRed(asRgb(col, @float));
}
@onLoad
initUiKit() {
    if (const UIView = objc?.class?.UIView) {
        objc.setCallOnMain(UIView, @addSubview);
        objc.setCallOnMain(UIView, @removeFromSuperview);
        objc.setCallOnMain(UIView, @bringSubviewToFront);
    }
    if (!objc || !UIApplication)
        return;
    objc.promisify(UIApplication, "openURL_options_completionHandler_", 'B');
    objc.setCallOnMain(UIApplication, @setIdleTimerDisabled);
    // todo: for later
    // objc.promisify(UIApplication, "openURL_options", sig(@bool),  @rename, "open");
}
