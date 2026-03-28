fragment.keyboard{
	layout: @flex;
}

fragment.keyboard sprite.bg {
    position: @absolute;
    top: 0;
    left: 0;
    w: 100%;
    h: 100%;
}

component#keyboard > vbox {
	paddingTop: (attributes.padding);
    paddingBottom: (attributes.padding);
    paddingLeft: (attributes.padding);
    paddingRight: (attributes.padding);
}


.keyButton {
    font: "default"; 
	fontSize: (param.attr.fontSize);
	color: (param.attr.fontColor); 
    bgPaddingLeft: (param.attr.padding);
    bgPaddingRight: (param.attr.padding);
    boxAlign: @center;
	desiredH: (param.attr.fontSize + 6*param.attr.padding);
	flex: (this.desiredW != -1 ? @unset : 1);
}

.keyButton.space {
	flex: (this.desiredW != -1 ? @unset : 4);
}

.keyButton.space {
    fontSize=18;
}

template#keyRow {
    paddingBottom: (param.attr.padding);
	paddingTop: (param.attr.padding);
}

.keyButton.keyboard {
    fontSize: 18;
    font: "defaultbd"; 
}

template.horizontal{
	orientation:@horizontal;
}

button.keyButton {
    bg: ( param.attr.buttonBg );
}

button.keyButton > sprite.icon {
    boxAlign: @center;
}

button.keyButton > sprite.icon:disabled {
    opacity: 0.5;
}

template#keyBtn, template#backspaceBtn, template#specBtn, template#shiftBtn, template#spaceBtn {
	desiredH: (param.attr.keybuttonH ? param.attr.keybuttonH : param.attr.fontSize + 5*param.attr.padding);
	layout: @flex; 
}
