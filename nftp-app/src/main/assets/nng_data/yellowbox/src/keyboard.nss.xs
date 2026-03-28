import {@registerStyle} from "uie/styles.xs"

@registerStyle
style keyboardStyle {
	@declare {
		declare kbdParams {
			maxBtnNumber = 10;
			paddingButton: 3;
			paddingRow: 3;
			bgColor: #222;
			keyBackground:( { /*borderWidth: 1, borderImg:#000,*/ borderRadius: [4], img:(#666) } );
			ctrlKeyBackground:( { /*borderWidth: 1, borderImg:#000,*/ borderRadius: [4], img:(kbdParams.bgColor) } );
			keyButtonW : ( screen.root.w / kbdParams.maxBtnNumber + 1 );
			keyButtonH: 40;
		}
		kbdHeight: ( 4* kbdParams.keyButtonH + 4*2*kbdParams.paddingRow );
	}

template#keyBtn, button.keyButton {
	desiredW: (kbdParams.keyButtonW);
	desiredH: (kbdParams.keyButtonH);
}

template#keyRow {
	paddingTop: const(kbdParams.paddingRow);
	paddingBottom: const(kbdParams.paddingRow);
}

button.keyButton, button.keyboard.keyButton, button.standard.keyButton {
	font: "default";
	fontSize: 16;
	paddingLeft: 0;
	paddingRight: 0;
	paddingTop: 0;
	paddingBottom: 0;
	bgPaddingLeft: const(kbdParams.paddingButton);
	bgPaddingRight: const(kbdParams.paddingButton);
	textTransform: @none;
}

template#backspaceBtn, template#specBtn, template#shiftBtn {
	desiredW: (int( 1.5 * kbdParams.keyButtonW));
}

template#keyBtn.keyboard {
	desiredW: (int( 1.5 * kbdParams.keyButtonW));
}

template#spaceBtn, button.keyButton.space {
	desiredW: (int( 5.3 * kbdParams.keyButtonW ));
}

button.keyButton.backspace, button.keyButton.spec, button.keyButton.shift, button.keyboard.keyButton {
	bg: ( kbdParams.ctrlKeyBackground );
}

button.keyButton.backspace > sprite.icon, button.keyButton.spec > sprite.icon, button.keyButton.shift > sprite.icon {
	marginRight: 0;
}

group.keyboard {
	desiredH: kbdHeight;
	w: 100%;
}

keyboard {
	bg: ( { img: (kbdParams.bgColor) } );
	buttonBg: (kbdParams.keyBackground);
	padding: 0;
	fontColor: (#fff);
	keybuttonH: (kbdParams.keyButtonH);
	align=@center;
}

}
