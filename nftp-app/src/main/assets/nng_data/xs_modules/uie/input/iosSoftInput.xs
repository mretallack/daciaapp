import inputFocusHandler from "uie/input/inputFocus.xs"
import * as objc from "system://objc"?
import {@objcProto} from "uie/darwin/objc_support.xs"
import {dispose} from "system://core"
import {UIApplication, uicolor} from "uie/ios/UiKit.xs"
import {setExternalPasteHandler} from "uie/components/inputComponent.ui"

const InputConnDesc = objc.ClassDesc()
    // UIKeyInput protocol
    .addMethod("insertText:", "v@:@")
    .addMethod("deleteBackward", "v@:", @delete)
    // paste
    .addMethod("pasteItemProviders:", "v@:@", @paste)
    .addMethod("canPasteItemProviders:", "B@:@", @canPaste)
    // UIInputTraits protocol
    .setProperty("keyboardType", "i")
    .setProperty("returnKeyType", "i")
    .build();


const IOSInputView = objc.class.NNGInputView;

const UIPasteControl = objc?.class?.UIPasteControl; // no objc if this module is import on non darwin platforms
const nngViewController = objc.class.nngViewController; // for safeFrame: create a CGRect offseted with safeArea
const UIPasteControlConfiguration = objc.class.UIPasteControlConfiguration;
enum UIPasteControlDisplayMode {
    IconAndLabel = 0,
    IconOnly =1,
    LabelOnly = 2
}

@preload
export object iosKeyboardManager {
    @dispose activeConnection; // the active input connection
    @dispose #inputFocusSubs;
    
    static {
        this.#inputFocusSubs = inputFocusHandler.getEvent().subscribe((name, obj, oldFocused, myData) => {
        	if (name == @InputFocusRequested) {
            	this.setInput(obj);
        	}
		});
    }
    
    async setInput(inp) {
        if (this.activeConnection?.activeInput == inp)
            return;
        const oldConnection = this.activeConnection; 
        if (!inp) { // no new input connection, we should close the old keyboard, otherwise we will just remove the old inputView
            this.activeConnection = undef;
            oldConnection?.close();            
        } else {
            this.activeConnection = new InputConnection(inp);
            await this.activeConnection.init();  
        }
        dispose(oldConnection);
    }
    
    // used for debugging, quickly setting input
    setInputToInputFocus() {
        this.setInput( inputFocusHandler.getInputFocus(screen.root))
    }
    createPasteCtrl(conf, x, y, w=80, h=40) {
        const inp = this.activeConnection?.iosInputView;
        if (!inp)
            return undef;

        const paste = UIPasteControl.initWithConfiguration(conf);
        nngViewController.safeFrame(paste, x, y, w, h);
        paste.target = inp;
        inp.addSubview(paste);
        return paste;
    }

    showPasteAt(x,y) {
        const conf = new UIPasteControlConfiguration;
        conf.baseForegroundColor = uicolor(#000);
        conf.baseBackgroundColor = uicolor(#e0e0e0);
        conf.displayMode = UIPasteControlDisplayMode.LabelOnly;
        const paste = this.createPasteCtrl(conf, x, y);
        paste;
    }
}

decorator @disposeView() {
    @dispose(view=>view?.removeFromSuperview())
}

@objcProto(InputConnDesc)
class InputConnection {
    activeInput;
    @disposeView iosInputView; // the associated NNGInputView with the current input
    
    static {
        objc.setCallOnMain(IOSInputView, "activateKeyboard", "closeKeyboard", "+withConnection");
    }

    constructor(input) {
        this.activeInput = input;
        // disable internal input compositon on ios
        // (because there is an external smarter one :D)
        input.context.ime.use_decompose=false;
        
        this.keyboardType = inputTypeToKeyboardType[input.type] ?? UIKeyboardType.UIKeyboardTypeDefault;
        this.returnKeyType = actionHintToReturnKeyType[input.actionHint] ?? UIReturnKeyType.UIReturnKeyDefault;
        
        // this.init();
    }
    
    async init() {
        this.iosInputView = await IOSInputView.withConnection(this);
        // add the fake inputView to the view tree
        UIApplication.sharedApplication.delegate.viewController.view.callOnMain(@addSubview, this.iosInputView);
        this.iosInputView.activateKeyboard(); // calls becomeFirstResponder
    }
    
    close() {
        this.iosInputView.closeKeyboard();
    }
        
    // input connection interface
    keyboardType;
    returnKeyType;
    
    insertText(text) {
        if (text == "\n") // action key pressed
            Events.simulateRawKey(screen.root, 13, 3); // simulate enter keypress (down and up)
        else this.activeInput?.context.ime.insert(text);
    }
    
    delete() {
        // simulate backspace keypress
        this.activeInput?.keyPressed("\x08");
    }
    async paste(provs) {
        iosPasteHandler.ctrl.onPaste();
        /*console.log("called paste");*/
    }
    canPaste(provs) {
        for(const p in provs) {
            if(p.hasItemConformingToTypeIdentifier("public.plain-text"))
                return true;
        }
        return false;
    }
}

@dispose @preload
object iosPasteHandler {
    ctrl;
    @disposeView pasteBtn;

    showAt(x,y, ctrl, w) {
        this.finish();
        if (!objc.class.UIPasteboard.generalPasteboard.hasStrings)
            return true;
        this.pasteBtn = iosKeyboardManager.showPasteAt(x,y, w);
        // ctrl.installCapture();
        this.ctrl = ctrl;
        return false;
    }
    finish() {
        this.pasteBtn?.removeFromSuperview();
        this.pasteBtn = undef;
        this.ctrl = undef;
    }
    static {
        if (UIPasteControl && UIPasteControlConfiguration) // only on ios16
            setExternalPasteHandler(iosPasteHandler);
    }
}

enum UIKeyboardType {
    UIKeyboardTypeDefault, //Specifies the default keyboard for the current input method.
    UIKeyboardTypeASCIICapable, //Specifies a keyboard that displays standard ASCII characters.
    UIKeyboardTypeNumbersAndPunctuation, //Specifies the numbers and punctuation keyboard.
    UIKeyboardTypeURL, // Specifies a keyboard for URL entry.
    UIKeyboardTypeNumberPad, //Specifies a numeric keypad for PIN entry.
    UIKeyboardTypePhonePad, // Specifies a keypad for entering telephone numbers.
    UIKeyboardTypeNamePhonePad, // Specifies a keypad for entering a person’s name or phone number.
    UIKeyboardTypeEmailAddress, // Specifies a keyboard for entering email addresses.
    UIKeyboardTypeDecimalPad, // Specifies a keyboard with numbers and a decimal point.
    UIKeyboardTypeTwitter, // Specifies a keyboard for Twitter text entry, with easy access to the at (“@”) and hash (“#”) characters.
    UIKeyboardTypeWebSearch, //Specifies a keyboard for web search terms and URL entry.
    UIKeyboardTypeASCIICapableNumberPad, //Specifies a number pad that outputs only ASCII digits.
    UIKeyboardTypeAlphabet
}


enum UIReturnKeyType {
    UIReturnKeyDefault, // Specifies that the visible title of the Return key is return.
    UIReturnKeyGo,      // Specifies that the visible title of the Return key is Go.
    UIReturnKeyGoogle,  // Specifies that the visible title of the Return key is Google.
    UIReturnKeyJoin,    // Specifies that the visible title of the Return key is Join.
    UIReturnKeyNext,    // Specifies that the visible title of the Return key is Next.
    UIReturnKeyRoute,   // Specifies that the visible title of the Return key is Route.
    UIReturnKeySearch,  // Specifies that the visible title of the Return key is Search.
    UIReturnKeySend,    // Specifies that the visible title of the Return key is Send.
    UIReturnKeyYahoo,   // Specifies that the visible title of the Return key is Yahoo.
    UIReturnKeyDone,    // Specifies that the visible title of the Return key is Done.
    UIReturnKeyEmergencyCall, // Specifies that the visible title of the Return key is Emergency Call.
    UIReturnKeyContinue, // Specifies that the visible title of the Return key is Continue.
}

const inputTypeToKeyboardType = {
    text : UIKeyboardType.UIKeyboardTypeDefault, 
    number: UIKeyboardType.UIKeyboardTypeNumberPad, 
    email: UIKeyboardType.UIKeyboardTypeEmailAddress, 
    address: UIKeyboardType.UIKeyboardTypeNamePhonePad, 
    uri: UIKeyboardType.UIKeyboardTypeURL, 
    name: UIKeyboardType.UIKeyboardTypeDefault    
};

const actionHintToReturnKeyType = {
    next: UIReturnKeyType.UIReturnKeyNext,
    prev: UIReturnKeyType.UIReturnKeyDefault, // not available on iOS
    go: UIReturnKeyType.UIReturnKeyGo,
    search: UIReturnKeyType.UIReturnKeySearch,
    send: UIReturnKeyType.UIReturnKeySend,
    done: UIReturnKeyType.UIReturnKeyDone,
    none: UIReturnKeyType.UIReturnKeyDefault // not available on iOS    
};
