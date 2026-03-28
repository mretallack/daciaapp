export import button from "./button.ui"
export import scroll from "./scroll.ui"
export import progress from "./progress.ui"
export import processing from "./processing.ui"
export import { processingDots } from "./processing.ui"
export import input from "./inputComponent.ui"
export import animSprite from "./animSprite.ui"
export import keyboard from "./keyboard.ui"
export import radio from "./radio.ui"
export import checkbox from "./checkbox.ui"
export import unitText from "./unittext.ui"
export import switch from "./switch.ui"
import {@registerStyle} from "uie/styles.xs"

@registerStyle
style compStyles {
button {
	component: button;
	bg: #1B1C1E;    
	align: @center;
	paddingLeft:5;
	paddingRight:5;
	color: #eee;
}

button:active {
	bg: #686C75;   
}

component#button > #txt {
	boxAlign: @baseline;
}

component#button > * {
	boxAlign: @center;
}

/*-------------------------------------------------------------*/
scroll {
	component: scroll;
	sliderImg: { img: #000, borderRadius :3};
	w: 5;
	h: 100%;
	right: 0;
}

/*------------------------------------------------------------- */

component#scroll > #track {
	flex: 1;
	boxAlign: @stretch;
}

/*------------------------------------------------------------- */

component#progress > #progBg {
	flex: 1;
}

component#progress > #progress {
	left: 0;
	top: 0;
}

progress {
	component: progress;
	progressBg: #d6d6d6;
	progressImg: #00adbc;
	h: 5;
}

/*---------------------------------------------------------------*/
animSprite {
	component: animSprite;
}

/* ------------------------------------------*/
input {
	component: input;
}

/*--------------------------------------------*/
unitText {
	component: unitText;
}

/*--------------------------------------------*/
radio {
	component: radio;
}

/*--------------------------------------------*/
checkbox {
	component: checkbox;
}

/*--------------------------------------------*/
switch {
	component: switch;
}
/*-------------------------------------------*/
processing{
	component: processing;
}

processing.dots{
	component: processingDots;
}

keyboard {
    component: keyboard;
}

@import "./inputComponent.nss"
@import "./keyboard.nss"
@import "./processing.nss"

}