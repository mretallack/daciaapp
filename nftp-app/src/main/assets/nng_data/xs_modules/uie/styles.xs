import { dispose } from "system://core"

export style moduleStylesLow {}
export style moduleStylesHigh {}

@onLoad()
regStyles(){
    if (??styles) {
        styles.insert(moduleStylesLow, @firstChild);
        styles.insert(moduleStylesHigh, undef);
    }
}
@onUnload() 
unregStyles() {
    dispose(moduleStylesLow, moduleStylesHigh); // will remove from styles or whatever needed
}
export
decorator @registerStyle(parent, where) {
    @preload
    @register(sheet => (parent || moduleStylesLow).insert(sheet, where))
}

//export applyTextStyle(style, ...chunks) { (style, ...chunks); }
export const applyTextStyle = +> (^,)
