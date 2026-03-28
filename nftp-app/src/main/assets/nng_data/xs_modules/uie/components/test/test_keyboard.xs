import { TestSuite, EXPECT, Async, @registerSuite, @metadata, @tags } from "xtest.xs"
import { stKeyboard } from "./test_keyboard.ui"
import inputFocus from "uie/input/inputFocus.xs"
import { typeof } from "system://core"

import { qwerty, englishAlt, englishSuperAlt, russian, arabic } from "uie/input/keyboardLib.xs"

class Window {
    window;
	ctrl = controller{};

	constructor( w = 800, h= 480, dpi = 160 ) {
		this.window = screen.createWindow( w, h, dpi, undef );
		this.ctrl.dispatchEvent = ()=>{};
		this.window.controller = this.ctrl;
	}

	close() {
		this.window.close();
	}

}

@metadata({
    description: "Keyboard UI component test",
    owner: @UIEngine,
    feature: (@KeyboardComponent, @UiEngine),
    level: @component,
    type: @functional,
})
@registerSuite
class KeyboardComponentTest extends TestSuite {
	static window;
	qwertyKeys;
	altKeys;
	superAltKeys;
	russianKeys;
	arabicKeys;
	static tags = @opensWindow, @android_exclude;

	constructor() {
		super();
		this.qwertyKeys = this.getKeys( qwerty );
		this.russianKeys = this.getKeys( russian );
		this.arabicKeys = this.getKeys( arabic );
		this.altKeys = this.getKeys( englishAlt );
		this.superAltKeys = this.getKeys( englishSuperAlt );
	}

	done() {
		super.done();
		Chrono.resumeTime();
	}

	static initSuite() {
		if ( KeyboardComponentTest.window == undef ) {
			KeyboardComponentTest.window = new Window();
			KeyboardComponentTest.window.ctrl.next( stKeyboard );
		}
	}

	static doneSuite() {
		KeyboardComponentTest.window.close();
		KeyboardComponentTest.window = undef;
	}

	getKeys( keyboard ) {
		var keys = [];
		for( var row in keyboard.rows ) {
			keys.push(...row);
		}
		return keys;
	}

	checkKeys( keys ) {
		var keyboardButtons = KeyboardComponentTest.window.window.getElementsByTagName( "button" );
		var backspace = keys.indexOf( @backspace );
		for( var i=0; i< len(keys); i++ ) {
			if ( typeof( keys[i] ) == @string ) {
				//Press the key button
				keyboardButtons[i].onRelease();
				EXPECT.EQ( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value, keys[i].toUpperCase() );
				//Press backspace
				KeyboardComponentTest.window.window.getElementsByTagName( "button" )[backspace].onRelease();
				EXPECT.EQ( len( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value ), 0 );
			}
		}
	}

	/*
		Test the default keys
	*/
	test_QwertyButtons() {
		this.checkKeys( this.qwertyKeys );
	}

	/*
		Test alt change functionality 
	*/
	test_AltKeyboard() {
		//change to alt keyboard
		var altPosition = this.qwertyKeys.indexOf( englishAlt );
		var altButton = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[altPosition];
		altButton.onRelease();
		//Check the alt keys
		this.checkKeys( this.altKeys );

		//change to superAlt keyboard
		altPosition = this.altKeys.indexOf( englishSuperAlt );
		altButton = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[altPosition];
		altButton.onRelease();
		this.checkKeys( this.superAltKeys );

		//change back to qwerty
		altButton = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[29];
		altButton.onRelease();
		this.checkKeys( this.qwertyKeys );
	}

	/*
		Test the change keyboard functionality
	*/
	test_ChangeKeyboard() {
		var changeKeyboard = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[32];
		//change keyboard to russian
		changeKeyboard.onRelease();
		this.checkKeys( this.russianKeys );

		//change keyboard to arabic
		changeKeyboard.onRelease();
		this.checkKeys( this.arabicKeys );

		//change back to english
		changeKeyboard.onRelease();
		this.checkKeys( this.qwertyKeys );
	}

	/*
		Test the shift button functionality
	*/
	test_ShiftButton() {
		var shiftButton = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[19];
		var keyButton = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[0];
		var backspace = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[27];
		//First press change to lowercase
		shiftButton.onRelease();
		keyButton.onRelease();
		EXPECT.EQ( 	KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value, "q" );
		//Second press chage to uppercase
		shiftButton.onRelease();
		keyButton.onRelease();
		EXPECT.EQ( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value, "qQ" );

		backspace.onRelease();
		backspace.onRelease();
	}

	/*
		Check the keyboard shift statement operation
	*/
	test_ShiftState() {
		//First char is uppercase
		var backspace = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[27];
		var keyButton = KeyboardComponentTest.window.window.getElementsByTagName( "button" )[0];
		keyButton.onRelease();
		EXPECT.EQ( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value, "Q" );
		//Second char is lowercase
		keyButton.onRelease();
		EXPECT.EQ( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value, "Qq" );
		//After press backspace one time stay lowercase
		backspace.onRelease();
		keyButton.onRelease();
		EXPECT.EQ( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value, "Qq" );
		//After press backspace two times change to uppercase
		backspace.onRelease();
		backspace.onRelease();
		keyButton.onRelease();
		EXPECT.EQ( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0].value, "Q" );
		backspace.onRelease();
	}

	/*
		Check the open/close keyboard functionality
	*/
	async test_OpenCloseKeyboard() {
		EXPECT.TRUE( KeyboardComponentTest.window.window.getElementsByTagName( "keyboard" )[0].firstChild.opacity );
		//Press the close keyboard button
		KeyboardComponentTest.window.window.getElementsByTagName( "button" )[33].onRelease();
		//500 millisec az animacio
		Chrono.pauseTime();
		Chrono.passTime(500);
		await Async.nextFrame();
		EXPECT.FALSE( KeyboardComponentTest.window.window.getElementsByTagName( "keyboard" )[0].firstChild.opacity );

		//set inputfocus to show the keyboard
		inputFocus.setInputFocus( KeyboardComponentTest.window.window.getElementsByTagName( "input" )[0]);
		//500 millisec az animacio
		Chrono.passTime(500);
		await Async.nextFrame();
		EXPECT.TRUE( KeyboardComponentTest.window.window.getElementsByTagName( "keyboard" )[0].firstChild.opacity );
	}

}