// This module helps creating and testing UI's from xsbook cells.
// Just declare your fragments you want to view, and use the showFragments() method
// It will open a testing window (if it isn't present already) and replace contents with your fragments.
// By default it uses all the styles defined in the application in which the cells will be run (this can be changed with the isolatedStyles setting).
// Use setupTestWindow before showing fragments to change the appearance of the window (size, dpi, title, isolatedStyles )
// And you can manipulate the window directly by calling getTestWindow (this will create the window when needed).
// If you need to define custom styles for your UI, use style blocks in the cell and decorate them with 
// @replaceStyles(styleId, @global/@isolated). replaceStyles will replace this style block with the newest each time the cell is executed.
import {state} from "system://core.types"
import {entries, dispose} from "system://core"

controller testUIController {
    
}

const testWindowTag = @testUiYellow;

*windows() {
    for (let win = screen.firstChild;  win; win = win.nextSibling) {
        yield win
    }
}

object testWindowConfig {
    width = 360
    heigth = 640
    title = "Test your UI!"
    dpi = @unset
    isolatedStyles = false 
}

dict testWindowProps {
    
}

export getTestWindow() {
    // check if there's already a window with this tag
    for (const win in windows()) {
        if (win.tag == testWindowTag) {
            if (testWindowConfig.dpi == testWindowProps.dpi) {
                updateTestWindow(win, testWindowConfig, testWindowProps);
                return win;
            }
            // have to recreate test window, dpi has changed
            win.close();
        }
    }
    const win = screen.createWindow(testWindowConfig.width, testWindowConfig.heigth, testWindowConfig.dpi == @unset ? screen.root.dpi : testWindowConfig.dpi,
                { title: testWindowConfig.title, tag: testWindowTag, styles: testWindowConfig.isolatedStyles ? isolatedBookStyles : undef });
    win.controller = testUIController;
    if (!testWindowConfig.isolatedStyles)
        win.styles.insert(bookStyles);
    for (const k,v in entries(testWindowConfig)) 
        testWindowProps[k] = v;
                    
    return win;
}

updateTestWindow(win, config, props) {
    // NOTE: unfortunately UiWindow can't get some properties like title and size, so effective props are stored here 
    //       in a props object, and we use it to query for changes  
    if (props.width != config.width || props.heigth != config.heigth) {
        win.setSize(config.width, config.heigth);
        props.width = config.width;
        props.heigth = config.heigth;
    }
    
    if (props.title != config.title) {
        win.title = props.title = config.title;
    }
}

/// @param options may be a simple id, like @landscape or @portrait to create a given window
///                or an object with different properties, like width, height, title, dpi and isolatedStyles.
///                By default a portrait test window will be used.
///                When `isolatedStyles` is set the window won't inherit the app styles, but will use its own
///                You can insert styles for it via @replaceStyles   
export setupTestWindow(options) {
    if (options == @portrait) {
        testWindowConfig.width = 360;
        testWindowConfig.heigth = 640;
    } else if (options == @landscape) {
        testWindowConfig.heigth = 360;
        testWindowConfig.width = 640;
    } else {
        for (const k,v in entries(options))
            testWindowConfig[k] = v;
    }
}

export showFragments(...fragments) {
    const testWin = getTestWindow();
    testUIController.setState(new state({use: fragments}));
    debug.screenshot(testWin.displayId);    
}

/// Use this decorator over a style block which has to be reloaded each time a cell with styles is reloaded
/// It requires an id for the style block, based on which this module will store the actual (latest) style block
/// but will remove it when replaceStyles is run again.
/// the styleVisiblity parameter controls whether the isolated style collaction or the standard bookUI style collection should
/// be used (this should be in sync with the isolatedStyles setting fro the test window config)
export decorator @replaceStyles(styleId, styleVisibility = @global) {
    @preload
    @register(sheet => replaceStyles(styleId, sheet, styleVisibility))
}


style bookStyles {
    
}

style isolatedBookStyles { // this style object will be used when isolated styles feature is used
    
}

dict usedStyles {};

// will replace stylesheet with styleId inside bookStyles
replaceStyles(styleId, sheet, styleVisibility) {
    dispose(usedStyles?.[styleId]);
    usedStyles[styleId] = sheet;
    const styleContainer = styleVisibility == @isolated ? isolatedBookStyles : bookStyles;
    styleContainer.insert(sheet);
}
