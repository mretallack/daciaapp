import { typeof } from "system://core"

/// use this container to store current application state
/// when app is reloaded instantly, state can be restored from here
export odict appState {

}

/// initialize reload feature.
/// when hotkey is pressed, createUIE will be called with engineName
/// you may rebuild your apps current state based on the appState dictionary
export initReload(engineName, hotkey = "F6") {
    data.engineName = engineName;
    const restartKeyCode = computeKeyCode(hotkey, 0xFA /*F11 key*/);
    
    System.onStart.register(() => {
        data.keyReg = screen.addEventListener("keyDown", () => { 
            if (event.rawkeycode == restartKeyCode) {
                reload();
                event.stopPropagation();
            } 
        });
    });
    System.onClose.register(()=> {
        // unregister from old screen
        data.keyReg = screen.removeEventListener("keyDown", data.keyReg);
    })
}

async reload() {
    await "destroyScreen"; // will continue on next event loop run, when callee is finished   
    System.createUIE( data.engineName, false);
    debug.reloadResources(); // reload all bitmaps/svgs
}

odict data {
    engineName = undef;
    keyReg = undef;
}

computeKeyCode(hotkey, default) {
    let keyCode = 0x70 - 1; // corresponds to F0 (F1-1) 
    if (typeof(hotkey) == @string && hotkey.startsWith("F")) {
        keyCode += hotkey.substr(1); // compute keycode for F key
    } else if (typeof(hotkey) == @int) {
        keyCode = hotkey;
    } else keyCode = default;
}
