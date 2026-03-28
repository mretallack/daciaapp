import inputFocus from "uie/input/inputFocus.xs"
import * as os from "system://os"
import {onChange} from "core://observe"
import {dispose} from "system://core"
import { abs } from "system://math"
import {windowInsetsChanged} from "uie/android/windowInsetsEvent.xs"

resizeWinOnInputFocusEvent(evt) {
    const win = evt.target.window;
    if (!win) return;

    const hasKeyboard = evt.target != win;
    const wPx = win.wPx;
    async do {
        await Chrono.delay(0.3s);
        // if (hasKeyboard) win.setSize(wPx, 700);
        // else win.setSize(wPx, 800);
        // windowInsetsChanged.trigger( win );
    }
}

class MockKeyboard {
    @dispose(w => w?.removeEventListener(@inputFocusChanged, resizeWinOnInputFocusEvent, false)) 
    #win;

    init(window) {
        if (os.platform == "win32") {
            this.#win = window;
            window.addEventListener(@inputFocusChanged, resizeWinOnInputFocusEvent, false );
        }
    }
}

@dispose
export MockKeyboard mockKeyboard;

export class InputFocusScroll {
    @dispose #subsInput;
    @dispose #subsSize;
    #scrollWidget;

    constructor(scrollWidget) {
        this.#scrollWidget = scrollWidget;
        dispose(this.#subsSize);
        this.#scrollWidget.addEventListener(@inputFocusChanged, (evt) => {
            if (evt.target?.displayId == undef) 
                evt.currentTarget.scrollToItem(evt.target, 50%, @center)
        });
        this.#subsSize = onChange(()=> { this.#scrollWidget.h }).subscribe(this.onResize.bind(this));
    }

    async onResize(height) {
        const input = inputFocus.getInputFocus(this.#scrollWidget.window);
        this.#scrollToCenter(input);
    }

    onInputFocusEvent(name, arg) {
        if (name == @InputFocusRequested) {
            this.#scrollToCenter(arg);
        }
    }

    #scrollToCenter(input) {
        if (input) {
            this.#scrollWidget.scrollToItem(input, 50%, @center); // centers item (only) if it is not visible
        }
    }
}
