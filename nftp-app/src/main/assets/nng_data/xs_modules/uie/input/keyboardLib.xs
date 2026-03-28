import { reduce, map, chain, of as iterOf} from "system://itertools"
import { typeof } from "system://core"

// converts from the easy to write row format, to a flattened representation
// where strings are flattened to one character strings inside arrays
flattenRow(row) {
    [...reduce(row, (iter, val) => { iter.chain( (typeof(val) != @string) ? iterOf(val) : val ) }, chain())]
}

class keySets {
    activeKeys;
    constructor() {

    }
}

// keyboards don't store key state, we can use them as descriptors, thus only only one instance is enough from them
export class Keyboard { 
    set = "abcdefghijklmopqrtsuvxyz0123456789+()"; // this could be also a reference from keysets, also we could provide an activeKeys property
                                                   // keySets may also be specified in the keyboard selection list, or we could select them based on keyboard tags
    rows = [];
    idLabel = "ABC"; // this label can be displayed on buttons for switching to this keyboard
    keyboardLabel;
    smallButtons = false;

    constructor() {
        this.rows = [...map(this.rows, flattenRow)]
    }   
}

// class representing a Key, the key property stores the input string which will be sent to the input context
// todo: maybe later it could be extended with codegroup knowledge (see keyboards.xml)
export class Key {
    key;
    constructor(key = "") {
        this.key = key;
    }
}

export class KeyboardRef {
    constructor(keyboard = @base) {
        if ( typeof(keyboard) == @object )
            this.keyboard = weak(keyboard);
        else
            this.keyboard = keyboard;
    }
    keyboard;
}

export class Action {
    action;
    constructor(action = @base) {
        this.action = action;
    }
}

export getKindOfKey(key) {
    var keyType = typeof(key);
    if (keyType == @string) {
        return @key; 
    } else if (keyType == @identifier) {
       return @speckey;
    } else if (key.constructor == Key) { // composite key
        return @composite;
    } else if(key.constructor == Action) {
        return @action;
    } else { 
        return @keyboard;
    }
}

// if the key is a simple button, the key text will be sent to the inputTarget, otherwise
// you can specify the handlers in details as follows:
// - changeKeyboard(keyboard): when an alternative keyboard is chosen this method will be called. keyboard is either a Keyboard or a keyboardref
//                             keyboardrefs for ex. are used for alternative keyboards, where the mainKeyboard can be any compatible keyboard
//                             keyboardrefs can be passed in the details argument, so they can be resolved to a keyboard
// - action(): called when the action button is pressed
export keyPressed(key, details) {
    var inputTarget = details.target;
    if (typeof(key) == @string) {
        inputTarget.keyPressed(key); 
    } else if (typeof(key) == @identifier) {
       inputTarget.keyPressed(key);
    } else if (key.constructor == Key) { // composite key
        for (var c in key.key)
            inputTarget.keyPressed(c); // todo: keypressed should handle strings and specchars
    } else if(key.constructor == Action) {
        details.action(key.action, details.target);
    } else { // keyboard change
        var keyboard = key;
        if (key.constructor == KeyboardRef)
            keyboard = details[key.keyboard] ?? key;
        ??details.changeKeyboard(keyboard);
    }
}

const speckeyLabels = {
    backspace: "<X]",
    space: "<space>",
    shift: "<Shift>"
};

// todo: resolving keyboardrefs could be abstracted better, than passing mainKeyboard as an argument
//      it depends on whether we'll have multiple valid refs
export getLabelFor(key, mainKeyboard, shiftState) {
    if (typeof(key) == @string) {
        return ( shiftState ? key.toUpperCase() : key );
    } else if (typeof(key) == @identifier) {
        return speckeyLabels[key] ?? "<" + key + ">";
    } else if (key.constructor == Key) { // composite key
        return key.key;
    } else if (key.constructor == KeyboardRef){ 
        var kbdRef = key.keyboard;
        return kbdRef == @mainKeyboard ? mainKeyboard.idLabel : "<ref>";
    } else if (key.constructor == Action) {
        return string(key.action);
    } else { // should be a keyboard
        return key.idLabel;
    }
}

class QwertyKeyboard extends Keyboard { 
    idLabel = "ABC";
    keyboardLabel = "English";
    rows = ([
        "qwertyuiop",
        "asdfghjkl",
        [@shift, "zxcvbnm", @backspace],
        [englishAlt, ",", @space, ".", new Action(@changeLanguage), new Action(@hide)] // @action may be enter/send/done etc.
    ]);
}

export QwertyKeyboard qwerty;

class QwertyEmailKeyboard extends QwertyKeyboard { 
    constructor() {
        super();
        // rows[3][1] is the ","
        this.rows[3][1] = "@";
        this.rows[3][3] = new Key(".com");
    }
}

export QwertyEmailKeyboard qwertyEmail;

class EnglishAltKeyboard extends Keyboard { 
    idLabel = "?123";
    rows = ([
        "1234567890",
        "@#$_&-+()/",
        [weak(englishSuperAlt), '*"\x27:;!?', @backspace],
        [new KeyboardRef(@mainKeyboard), ",", @space, ".", new Action(@changeLanguage), new Action(@hide)] // @action may be enter/send/done etc.
    ]);
}

export EnglishAltKeyboard englishAlt;

class EnglishSuperAltKeyboard extends Keyboard { 
    idLabel = "=\<";
    rows = ([
        "~`|1234567", // i'm lazy to type the real chars here
        '123456={}\\',
        [englishAlt, '%2345[]', @backspace],
        [new KeyboardRef(@mainKeyboard), @space, new Action(@changeLanguage), new Action(@hide)] // @action may be enter/send/done etc.
    ]);
}

export EnglishSuperAltKeyboard englishSuperAlt;

class RussianKeyboard extends Keyboard {
    set = "йцукенгшщзхфывапролджэячсмитьбю";
    idLabel = "ABC";
    keyboardLabel = "русский"
    rows = ([
        "йцукенгшщзх",
        "фывапролджэ",
        [@shift, "ячсмитьбю", @backspace],
        [englishAlt, ",", @space, ".", new Action(@changeLanguage), new Action(@hide)] // @action may be enter/send/done etc.
    ]); 
    smallButtons = true;
}

export RussianKeyboard russian;


class ArabicKeyboard extends Keyboard {
    set = "ضصثقفغعهخحجدذشسيبلاتنمكطئءؤرىةوزظ";
    idLabel = "ABC";
    keyboardLabel = "العربية"
    rows = ([
        "ضصثقفغعهخحجدذ",
        "شسيبلاتنمكط",
        [@shift, "ئءؤرىةوزظ", @backspace],
        [englishAlt, ",", @space, ".", new Action(@changeLanguage), new Action(@hide)] // @action may be enter/send/done etc.
    ]);
    smallButtons = true;
}

export ArabicKeyboard arabic;

// todo: create list of keyboards, alternative keyboards shouldn't be present in them