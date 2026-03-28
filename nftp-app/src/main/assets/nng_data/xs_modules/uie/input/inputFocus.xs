import {filter} from "system://itertools"
import { EventEmitter } from "system://core.observe"
import {defineEvent, dispatchEvent, CustomEvent} from "system://ui.core"
import {WeakMap} from "system://core.types"

/*
* Input focus handling per window.
* Input focus is diffrent from focus: 
*  * focus is usually a visually designated element in focus
*  * input focus is the element currently receiving key input events (like an input control)
* The two may be the same, but most of the time focus handling is disabled, while inputfocus is always active.
*/

/*
* Containing all related information and member function for window instances
*/
class ParametricWindow {
    #window;
    #inputFocus = undef;
    #autofocusList = [];
    nativeData = undef;
    setInputFocus(obj) {
        if (this.#inputFocus == obj) return;

        if (!obj) {
            // check list of objects registered for 'auto focus'. when input focus is lost
            //    this list is consulted and the candidate with the greatest weight will be selected
            let candidateWeight;
            for (const candidate, weight in this.#autofocusList) {
                if (candidate?.visible && (!obj || candidateWeight < weight)) {
                    obj = candidate;
                    candidateWeight = weight;
                }
            }
        }
        if (this.#inputFocus == obj) return;

        const evt = CustomEvent(@inputFocusChanged, #{relatedTarget: this.#inputFocus});
        const window = (obj || this.#inputFocus).window;
        const target = obj || window;
        window.inputFocus = obj;
        this.#inputFocus = weak(obj);
        dispatchEvent(evt, target, evt.relatedTarget);
    }
    get inputFocus() { return this.#inputFocus; }
    get window() { return this.#window; }
    set window(win) { this.#window = win;}
    
    registerForAutoFocus(obj, weigth) {
        const idx = this.#autofocusList.findIndex(item => item[0] == obj);
        obj = weak(obj);
        if (idx >= 0)
            this.#autofocusList[idx] = (obj, weigth);
        else this.#autofocusList.push((obj, weigth));
        if (!this.#inputFocus)
            this.setInputFocus(obj)
    }
   
}

WeakMap windowData;
/*
* Handler for manage the focus between all instance of input component without reference to windows
* Only one instance is available
*/
class Handler {
    #emitter = new EventEmitter;

    getEvent() {
        return this.#emitter.event;
    }

    getWindowData(window) {
        if (!window) return undef;
        let data = windowData?.[window];
        if (data)
            return data;
        // not found, create window data on demand
        data = new ParametricWindow(window);
        windowData.set(window, data);
        data;
    }
    
    getInputFocus(window) {
        // Note: getInputFocus could be observed, therefore data should be created on query since WeakMap is not observable (yet)
        this.getWindowData(window)?.inputFocus
    }

    setInputFocus(obj, window = undef) {   // todo: obj=@auto to initialize focus
        if (obj && window && obj.window != window) {
            error_handler.raise("target window should match obj's window");
        }
        var data = this.getWindowData(window ?? obj.window);
        this.#emitter.next(@InputFocusRequested, obj, data.inputFocus, data.nativeData);
        data.setInputFocus(obj);
        const realFocus = data.inputFocus;
        if (realFocus != obj)
            this.#emitter.next(@InputFocusRequested, realFocus, obj, data.nativeData);
    }
    setNativeData(window, nativeData) {
        if (window) 
            this.getWindowData(window).nativeData = nativeData
    }
    setNativeDataForInput(input, nativeData) {
        if (!input)
            return;
        if (const data = windowData?.[input.window]) {
            if (data.inputFocus == input)
                data.nativeData = nativeData
        }
    }
    releaseFocusInside(obj) {
        const data =  windowData?.[obj?.window];
        if (!data?.inputFocus)
            return;
        for(var anc = data.inputFocus; anc && anc != screen; anc = anc.parent) {
            if (anc == obj)
                return this.setInputFocus(undef, obj.window)
        }
    }
    
    /// @param {int} weight the greater the weight the more chance has the obj for getting the input focus
    ///                     when no inputfocus is present in the window
    registerForAutoFocus(obj, weigth) {
        this.getWindowData(obj.window).registerForAutoFocus(obj, weigth)
    }
}

export default Handler inputFocusHandler;

@onLoad load() {
    defineEvent(@inputFocusChanged);
}
