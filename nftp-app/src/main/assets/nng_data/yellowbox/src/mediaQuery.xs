import {windowInsetsChanged} from "uie/android/windowInsetsEvent.xs"
import {queryWindowInsets} from "uie/android/windowInsets.xs"

export object mediaQuery {
    headerPadding = 0;
    footerPadding = 0;

    #windowInsetsChangedSubs;
    
    init(){
        console.log("[MediaQuery] start");
        this.#windowInsetsChangedSubs = windowInsetsChanged.subscribe( (win, pad) => {
            this.headerPadding = win.pixelToDp(pad?.top || 0);
            this.footerPadding = win.pixelToDp(pad?.bottom || 0);
        });
        queryWindowInsets(screen.root);
    }
};
