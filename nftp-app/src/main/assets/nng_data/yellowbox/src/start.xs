import { ACTION_VIEW, onIntentReceived, activityIntent } from "android://intents"?
import {parse} from "system://web.URI"
import { app, yellowStorage as storage } from "./app.xs"
import {initReload} from "uie/appState.xs"
import * as os from "system://os"
import nearestStrategy from "system://uie.focus.search.nearest"
import inputFocus from "uie/input/inputFocus.xs"
import {dropDownController} from "./components/dropMenu.ui"
import {messageBoxController} from "./components/messageboxes.xs"
import {languages} from "./utils/languages.xs"
import {bindWindowInsetsToPadding} from "uie/android/windowInsets.xs"
import {Orientations, requestOrientation} from "uie/android/screen.xs"
import {mcPropertyHandler} from "./service/marketingCloudProperties.xs"
import {mediaQuery} from "./mediaQuery.xs"

@dispose @preload
const onWindowSubs = screen.onWindowCreated.subscribe((evt, win) => {
    console.log(`[Yellowbox] new window with tag:${win.tag}, displayId:${win.displayId}`);
    if ( win == screen.root || win.tag == "") { // this is the main window, or a window with no tag added from android
        win.controller = app.appController;
        requestOrientation(win, Orientations.SensorPortrait);
        mediaQuery.init();
        setupKeyEvents(win);
    }
});

@onLoad
boot() {
    languages.initLanguages(); 
    if (const intent = activityIntent?.()) {
        if (intent.getBooleanExtra('DEBUG_PAUSE', false))
            debug.pause();
        if (const startScreen = intent?.getStringExtra('STATE')) {
            app.selectScreenById(startScreen);
        }
    }
    mcPropertyHandler.init();        
	if ( !storage.isOnboardingFinished() ) {
        app.setAppState( @Onboarding );
    } else {
        app.setAppState( @Application );
    }
    
    if (os.platform == "win32")
        initReload("main.ui")
}

enum KeyCodes {
    AndroidBack = 4,
    Esc = 27
}

enum Direction {
	None = 0,
	Left = 1,
	Right = 2,
	Up = 3,
	Down = 4,
}

const strategy = new nearestStrategy();

setupKeyEvents(window) {
    window.addEventListener("keyDown", evt => {
        const keyCode = evt.rawkeycode;
        if (keyCode == KeyCodes.AndroidBack || keyCode == KeyCodes.Esc) {
            if (messageBoxController.queue.size > 0 && messageBoxController.state?.cancellable) {
                messageBoxController.prev();
            }
            else if (dropDownController.queue.size > 0) {
                dropDownController.prev();
            } else {
                app.back();
            }
            evt.stopPropagation();
        }
        if ((keyCode == 9 || keyCode == 13)) { 
            const current = inputFocus.getInputFocus(screen.root);
            if (!current) return;
            const nextField = strategy.findNext(screen.root, current, Direction.Down, "input");
            inputFocus.setInputFocus(nextField, screen.root); // move to next field or hide keyboard
            evt.stopPropagation();
        }
    });
    // be prepared when keyboard is shown, or app enters splitscreen mode
    bindWindowInsetsToPadding(window);
}

export object urlHandler {
    #listeners = [];
    onNewIntent;
    
    init() {
        this.onNewIntent = onIntentReceived?.(@all, @emitCurrent)?.subscribe(i => this.#processIntent(i));
    }

    registerUrl(path, callback) {
        this.#listeners.push(#{path, callback});
    }

    #processIntent(intent) {
        if (intent.action == ACTION_VIEW && intent.dataString) {
            const url = parse(intent.dataString);
            this.processUrl(url);
        }
    }

    processUrl(url) {
        console.log( "[UrlHandler] ", url.path );
        for (const item in this.#listeners) {
            if (url.path == item.path)
                item.callback(url);
        }
    }
}

@onStart
onStart() {
    urlHandler.registerUrl("/open", openPage);
    urlHandler.init();
}

// for testing
export parseUrl( url ) {
	openPage( parse(url) )
}

openPage(url) {
    const page = url.queryParams?.["page"];
    console.log("Received open: ", page);
    app.selectScreenById(page);
}
