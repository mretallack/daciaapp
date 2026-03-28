import { allChildAnimFinished } from "uie/animation/finish.xs"
import {CancellationTokenSource} from "system://core.observe"
import {Map} from "system://core.types"
import { formInput } from "~/src/components/formInput.ui"
import {typeof} from "system://core"
import { seq } from "system://itertools"
import {@registerStyle} from "uie/styles.xs"
import { i18n } from "system://i18n"
import {fmt} from "fmt/formatProvider.xs"
import {mediaQuery} from "~/src/mediaQuery.xs"

export class MsgboxInputData{
	inputVal;
	required = true;
	type = @standard;
	title;
	errorText = "";
	maxLength = 50;
}

export class Messagebox {
	id;	// for testing
	lines = [];
	buttons = [];
	data;
	progress;
	action;
	layout;
	overlay = true;
	icon;
	separatorVisible = false;
	iconClass = ();
	firstLineStyle = ();
	secondLineStyle = ();
	thirdLineStyle = ();
	
	addLine( line ) {
		this.lines.push( line );
		return this;
	}
	addButton( button ){
		this.buttons.push( button );
		return this;
	}
	setAction( action ){
		this.action = action;
		return this;
	}
	setOverlay(){
		this.overlay = true;
		return this;
	}
	setId( id ) {
		this.id = id;
		return this;
	}
	setLayout(layout) {
		this.layout = layout;
		return this;
	}
	setFirstLineStyle( ...style ){
		this.firstLineStyle = (...style,) ?? undef;
		return this;
	}	
	setSecondLineStyle( ...style ){
		this.secondLineStyle = (...style,) ?? undef;
		return this;
	}
	setThirdLineStyle( ...style ){
		this.thirdLineStyle = (...style,) ?? undef;
		return this;
	}
	/// "alma.svg" or {name: "alma.svg", class:@red}
	addIcon( icon ){
		if (typeof(icon) == @string) {
			this.icon = icon;
			this.iconClass = ();
		} else {
			this.icon = icon.name;
			this.iconClass = icon?.class;
		}
		return this;
	}
	show() {
		messageboxHandler.show(this);
	}

	hide() {
		messageboxHandler.hide(this);
	}
}

export class Button {
	text;
	action;
	style = @standard;
	enabled = true;
	closeMsgboxWhenPressed = true;
	constructor( params ){
		if (params?.text) this.text = params.text;
		if (params?.action) this.action = params.action;
		if (params?.style) this.style = params.style;
		this.closeMsgboxWhenPressed = params?.closeMsgboxWhenPressed ?? true;
	}
}

state stMessagebox {
    
}


export controller messageBoxController {
};

class MessageboxHandler {
	activeMessagebox;
	activeMessageboxId; // NOTE: using messagebox id's, so the same messagebox object may be queued multiple times
	#queue = [];
	#uiActive = false;
	#msgBoxId = 1;
	#pending = new Map;
	state = @none; // @showing, @shown, @hiding, @none
	get transitionState() {
		(this.state == @showing || this.state == @shown) ? @shown : undef
	}
	
	show( msgBox ){
		const id = this.#msgBoxId++;
		const resultPromise = new Promise((resolve, reject) => {
			this.#pending.set(id, { resolver: resolve, buttonIdx: undef });
		});
		this.#queue.push((msgBox, id));
		if (!this.#uiActive) {
			this.#nextMessageBox();
			this.#presentMessageboxUi( msgBox );
		}
		return resultPromise;
	}

	// todo: create a new remove/hide interface
	hide( msgBox, buttonIdx) {
		if (this.activeMessagebox == msgBox) {
			this.closeActiveMessagebox(buttonIdx);
		} else {
			// remove from the queue, if not active
			const idx = this.#queue.findIndex(i => i[0]==msgBox);
			if (idx < 0) return;
			const deletedItem = this.#queue.splice(idx, 1);
			this.#messageBoxFinished(deletedItem[1]);
		}
	}
	
	#nextMessageBox() {
		const active = this.#queue.shift();
		this.activeMessagebox = active[0];
		this.activeMessageboxId = active[1];
	}
	
	#presentMessageboxUi( msgBox ) {
		this.#uiActive = true;
		let state = new stMessagebox;
		let fragments = [];
		if (this.activeMessagebox.overlay)
			fragments.push( frMsgBoxOverlay );

		if (msgBox.progress) {
			fragments.push(frMessageboxWithProgress);
		} else if (msgBox.layout) {
			fragments.push(msgBox.layout);
		} else {
			fragments.push(frMessagebox);
		}
		state.use = fragments; 
		messageBoxController.next(state);
		this.state = @showing; // this will start show transition
	}
	
	closeActiveMessagebox(buttonIdx) {
		const msgBoxState = this.#pending.get(this.activeMessageboxId);
		msgBoxState.buttonIdx = buttonIdx;
		this.state = @hiding;
		// this will start hide transition
	}
	
	animFinished() {
		// depending on transitionState either a messagebox was shown or hidden
		if (this.state == @hiding) {
			// messagebox hidden
			this.#messageBoxFinished(this.activeMessageboxId);
			this.activeMessagebox = undef;
			this.activeMessageboxId = undef;
			messageBoxController.prev(); // drop messagebox ui
			if (this.#queue.length == 0) {
				this.state = @none;
				this.#uiActive = false;
			} else {
				this.#nextMessageBox();
				this.#presentMessageboxUi( this.activeMessagebox );
				this.state = @showing;
			}
		} else {
			// messagebox shown
			this.state = @shown;
		}
	}
	
	#messageBoxFinished(id) {
		const state = this.#pending.getAndRemove(id) ?? undef;
		// resolve promise with the index of the button pressed
		state.resolver(state.buttonIdx);
	}
}

export MessageboxHandler messageboxHandler;

<fragment frMsgBoxOverlay class=(@fill, messageboxHandler.transitionState) >
	<sprite class=fill, bg, fade/>
</fragment>

export <fragment frMessagebox class=(@main, @flexible, @vertical, @mainContentPadding, messageboxHandler.transitionState) 
		  valign=@center paddingTop=(mediaQuery.headerPadding) paddingBottom=(mediaQuery.footerPadding)
		  onAnimationFinished() { messageboxHandler.animFinished(); }>
	own {
		let msgBox = (messageboxHandler?.activeMessagebox);
		let useChildWidgets = false;
		buttonPressed(idx) {
			// only handle button presses when the messagebox is progress of showing or is shown
			if (messageboxHandler.state != @showing && messageboxHandler.state != @shown)
				return;
			const button = msgBox.buttons[idx];
			button.action?.( button );
			if ( button.closeMsgboxWhenPressed )
				messageboxHandler.closeActiveMessagebox(idx);
		}
	}
	<group class=flexible, vertical, msgboxContent visible=(msgBox)>
		<sprite class=bg, msgbox/>
		<group class=flexible, vertical, msgBoxIcon visible=(!useChildWidgets && msgBox?.icon) >
			<sprite class=msgboxIconBg align=@center valign=@center />
			<sprite class=(@msgboxIcon,...seq(msgBox?.iconClass)) img=(msgBox.icon ?? "") />
		</group>
		<group class=flexible, vertical, msgBoxLines, scrollable visible=(!useChildWidgets)>
			<text class=(@msgbox, @msgboxFirstLinePaddings, ...seq(msgBox?.firstLineStyle)) text=(??msgBox.lines[0])/>
			<sprite class=separator, mainPaddingY visible:={msgBox.separatorVisible} />
			<text class=(@msgbox,@msgboxSecondLinePaddings,...seq(msgBox?.secondLineStyle)) text=(??msgBox.lines[1]) visible=(??msgBox.lines[1])/>
			<text class=(@msgbox,@msgboxThirdLinePaddings,...seq(msgBox?.thirdLineStyle)) text=(??msgBox.lines[2]) visible=(??msgBox.lines[2])/>
			<wheel/>
			<scroll>
		</group>
		<includeChildren />
		<group class=flexible, vertical, msgboxButtons  visible=(msgBox.buttons.length && !useChildWidgets ?? false)>
			<button class=(@msgbox, @detailMarginY, msgBox.buttons?.[0]?.style==@info ? @secondary : @action) text=( msgBox.buttons[0].text ?? "" ) enable=(msgBox.buttons[0].enabled ?? true) onRelease() { buttonPressed(0); } visible=(??msgBox.buttons[0])/>
			<button class=(@msgbox, @detailMarginY, msgBox.buttons?.[1]?.style==@info ? @secondary : @action) text=( msgBox.buttons[1].text ?? "" ) enable=(msgBox.buttons[1].enabled ?? true) onRelease() { buttonPressed(1); } visible=(??msgBox.buttons[1])/>
		</group>
	</group>
</fragment>

export <fragment frMessageboxWithInput extends=frMessagebox>
	own{
		let inputData = (msgBox?.data ?? {inputVal:""});
	}
	<formInput class=msgBox, extraLargePaddingX
		value <=> inputData.inputVal
		valid = ( inputData?.required ? inputData.inputVal.length : true ) 
		title=(inputData?.title) 
		errorText = (inputData?.errorText) 
		maxLength = (inputData?.maxLength) 
	/>
</fragment>

export <fragment frMessageboxLarge class=(@main, @flexible, @vertical, @mainContentPadding, messageboxHandler.transitionState) 
		  valign=@center onAnimationFinished() { messageboxHandler.animFinished(); } >
	own {
		<template tMsgboxText class=flexible, vertical, smallPaddingY, mainPaddingX>
			<text class=(item?.type == @title ? @msgbox : @paragraph) text=(item?.text) />
		</template>
		<template tChkbox class=flexible, horizontal, smallPaddingY, mainPaddingX  checked<=>val
                onRelease() {
                    invert(val);
                    ??item.onCheck( val );
                }>
			own{ let val = false }
            <sprite chk />
            <text class=small text=( item?.text )/>
		</template>

		let msgBox = (messageboxHandler?.activeMessagebox);
		buttonPressed(idx) {
			// only handle button presses when the messagebox is progress of showing or is shown
			if (messageboxHandler.state != @showing && messageboxHandler.state != @shown)
				return;
			const button = msgBox.buttons[idx];
			button.action?.( button );
			if ( button.closeMsgboxWhenPressed )
				messageboxHandler.closeActiveMessagebox(idx);
		}
	}
	<group class=flexible, vertical, msgboxContent, mainMarginY visible=(msgBox)>
		<sprite class=bg, msgbox/>
		<group class=flexible, vertical, scrollable >
			<lister model=(msgBox.lines) template=tMsgboxText templateType(){ if (item.type == @checkbox) return tChkbox; else return @default }/>
			<wheel />  
            <scroll />
		</group>
		<includeChildren />
		<spacer class=horizontal, medium>
		<group class=flexible, horizontal, msgboxButtons, mainPaddingY  visible=(msgBox.buttons.length ?? false)>
			<button class=(@msgbox, @smallMarginX, msgBox.buttons?.[0]?.style==@info ? @secondary : @action) flex=1 text=( msgBox.buttons[0].text ?? "" ) enable=(msgBox.buttons[0].enabled ?? true) onRelease() { buttonPressed(0); }/>
			<button class=(@msgbox, @smallMarginX, msgBox.buttons?.[1]?.style==@info ? @secondary : @action) flex=1 text=( msgBox.buttons[1].text ?? "" ) enable=(msgBox.buttons[1].enabled ?? true) onRelease() { buttonPressed(1); } visible=(??msgBox.buttons[1])/>
		</group>
	</group>
</fragment>

<fragment frMessageboxWithProgress extends=frMessagebox>
	own{
		let progress = (msgBox.progress ?? {text: "", value:0, total:0});
		let completed = (progress.value >= progress.total || progress.total == 0);
		let useChildWidgets = (completed);
	}

	// completed widgets
	<group class=flexible, vertical, msgBoxIcon visible=(completed)>
		<sprite class=msgboxIconBg align=@center valign=@center/>
		<sprite class=(@msgboxIcon) img="Check.svg" visible=(msgBox?.icon)>
	</group>
	<group class=flexible, vertical, msgBoxLines visible=(completed)>
		<text class=msgbox text=(??msgBox.lines[0])/>
		<text class=msgbox text=(??msgBox.lines[1]) visible=(??msgBox.lines[1])/>
	</group>

	<sprite class=separator, form>
	// progress
	<group class=flexible, horizontal, msgboxButtons>
		<text class=paragraph,theme,mainMarginX text=(progress.text) />
		<spacer flex=1 />
		<text class=h2,mainMarginX minW=50 text=(fmt(i18n`{0}%`, int(progress.value*100L/progress.total ?? 100))) align=@center />
		<spacer flex=1 visible=(!progress.text) />
	</group>
	<progress progressBar class=msgbox,extraLargeMarginX max=(progress.total ?? 0 ) progress=(progress.value ?? 0) />

	// completed button
	<group class=flexible, horizontal, msgboxButtons visible=(completed)>
		<button class=msgbox,smallMarginX,secondary flex=1 text=( i18n`Ok` ) onRelease() { 
			messageboxHandler.closeActiveMessagebox(0);
		}/>
	</group>
</fragment>


export class MsgboxChkBoxData{
	text;
	val;
}

export <fragment frMessageboxWithCheckbox extends=frMessagebox>
	own {
		let data = (msgBox?.data ?? {text:"", val:false});
	}
	<sprite class=separator, mainPaddingY />
	<group tChkbox class=flexible, horizontal checked<=>data.val onRelease() { invert(data.val); } >
		<sprite chk />
		<text class=messageboxCheckbox text=( data.text )/>
	</group>
</fragment>


@registerStyle
style messagebox {
	@declare {
		msgboxBg: {
			borderRadius: 6,
			img: (colors.white)
		}; 
		msgboxIconBg: {
			borderRadius: 48,
			img: (colors.backgroundGrey)
		}                   
		msgboxAnimTime: 400ms;
		msgboxFirstLinePadding: 46;
		msgboxSecondLinePadding: 24;
		msgboxIconBgSize: 96;
		msgboxIconSize: 48;
	}	

	sprite.bg.fade {
		opaque: 1; 
		img: const(colors.fade);
	}

	#frMsgBoxOverlay {
		transition: (@alpha, 400ms);
		alpha: 0;
	}

	#frMsgBoxOverlay.shown {
		alpha: 24;
	}	

	#frMessagebox, #frMessageboxWithInput, #frMessageboxLarge{
		transition: [[@top, msgboxAnimTime], [@bottom, msgboxAnimTime]];
		top: 100%;
	}

	#frMessagebox.shown, #frMessageboxWithInput.shown, #frMessageboxLarge.shown {
		top: 0;
	}

	#frMsgBoxOverlay  >>> *{
		alpha: @inherit;
	}

	formInput.msgBox {
		paddingTop: 0;
		paddingBottom: const(paddings.extraLarge);
	}

	text.msgbox {
		font: const(fontType.defaultbd);
		fontSize: const(fontSizes.h2);
		color: const(colors.darkGrey);
		align: @center;
	}

	text.msgbox.secondLine{
		font: const(fontType.read);
		fontSize: const(fontSizes.medium);
		color: const(colors.black);
	}

	text.msgbox.secondLinePaddings{
		paddingTop: const(paddings.large);
	}

	text.msgbox.thirdLine{
		font: const(fontType.read);
		fontSize: const(fontSizes.medium);
		color: const(colors.black);
		paddingTop: const(paddings.large);
	}

	.msgboxLinePadding{
		paddingTop: const(paddings.large);
	}

	sprite.bg.msgbox {
		img: msgboxBg;
	}

	group.msgBoxLines {
		marginTop: const( paddings.extraLarge );
		marginBottom: const( paddings.extraLarge );
	}

	text.msgboxFirstLinePaddings{
		marginLeft: msgboxFirstLinePadding;
		marginRight: msgboxFirstLinePadding;
	}

	text.msgboxFirstLineWithSeparator {
		paddingBottom: const(paddings.medium);
	}

	text.msgboxSecondLinePaddings, text.msgboxThirdLinePaddings{
		marginLeft: msgboxSecondLinePadding;
		marginRight: msgboxSecondLinePadding;
	}

	group.msgboxButtons {
		boxAlign: @stretch !important;
		marginLeft: const( paddings.large );
		marginRight: const( paddings.large );
	}

	group.flexible.horizontal.msgboxButtons > * {
		boxAlign: @bottom;
		valign: @center;
	}

	group.flexible.vertical.msgboxContent > * {
		boxAlign: @center;
		valign: @center;
	}

	button.msgbox {
		desiredH: buttonH;
	}

	group.msgboxContent {
		paddingTop: const(paddings.extraLarge);
		paddingBottom: const(paddings.extraLarge); 
		boxAlign: @stretch;
	}

	group.msgBoxIcon {
		desiredH: msgboxIconBgSize;
		desiredW: msgboxIconBgSize;
		boxAlign: @center;
	}

	sprite.msgboxIconBg {
		position: @absolute;
		imageW: msgboxIconBgSize;
		imageH: msgboxIconBgSize;
		img: msgboxIconBg;
	}

	sprite.msgboxIcon {
		imageW: msgboxIconSize;
		imageH: msgboxIconSize;
		align: @center;
	}

	sprite#chk {
        img: "checkbox.svg";
        params: ({ color: colors.lightGrey });
        desiredW: const(iconSize.small);
        desiredH: const(iconSize.small);
        marginRight: const( paddings.medium );
    }

    #tChkbox:checked > sprite#chk {
        img: "checkbox-checked.svg";
        params: ({ color: colors.black })
    }

	progress#progressBar {
		desiredH: 4;
		progressImg: const(colors.progress);
		progressBg: const(colors.lightGrey);
		marginTop: const(paddings.main);
		marginBottom: const(paddings.extraLarge);
	}

	#frMessageboxWithProgress > sprite.separator, #frMessagebox sprite.separator {
		alpha: 30%;
	}

}
