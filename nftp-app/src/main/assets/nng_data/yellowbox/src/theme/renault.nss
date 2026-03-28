@declare {
	disabledButtonTextOpacity: 100%;
    declare fontSizes {
        paragraph: 15;
    }
	declare fontType {
		default: @Renault_Regular;
		defaultbd: @Renault_Bold;
		read: @Renault_Regular;
		readbd: @Renault_Bold;
		readlight: @Renault_Light;
	}
	declare colors {
		buttonSec: #000;
		buttonSecAlt: #888B8D;
		buttonText: #000;
		pressed: #F8EB4C;
		pressedSecondary: #000;
		pressedSecondaryActive: #000;
		themeColor: #EFDF00;
		theme: #EFDF00;
		warning: #FFF26E;
		error: #C3261F;
		success: #71C292;
		cursor: #000;
 		label:#8C8C8B;
		fade: #656666;
		darkGrey: #888B8D;
		lightGrey: #D9D9D6;
		trait: #BBBCBC;
		mainBg: #f2f2f2;
		mapIcon: #000;
		knob:#EFDF00;
		downloadProgress: #EFDF00;
		progress: #EFDF00;
		switchBg: #D7D7D5;
		secButtonBorder: #888B8D;
		savingPrice: #71C292;
	}
	declare buttonBg {
		borderWidth: 1;
		borderImg: #EFDF00;
		img: #EFDF00;
	}

	declare activeButtonBorderBg {
		borderWidth: 1;
		borderImg: const(colors.pressedSecondaryActive);
		img: const(colors.pressedSecondaryActive);
	}

	declare primaryActionBg {
		img: const(colors.white);
		borderWidth: 1;
		borderImg: const(colors.black);
	}

	declare primaryActionBgActive {
		img: const(colors.black);
		borderWidth: 1;
		borderImg: const(colors.black);
	}

	declare buttonDisabled {
		img: const(colors.mainBg);
	}

	declare secondaryAltButtonBg {
		borderWidth: 1;
		borderImg: const(colors.secButtonBorder);
		img: const(colors.black);
	}
}

sprite.bg.onboarding1 {
	img: "onboarding1.png";
}

sprite.bg.onboarding2 {
	img: "onboarding2.png";
}

sprite.bg.onboarding3 {
	img: "onboarding3.png";
}

sprite.bg.onboardingGradient{
	img: (LinearGradient(0deg,#000,18%,#000,25%,0x00000000, 50%, 0x00000000));
}

text#alertText.warning {
	color: const(colors.black);
}

sprite#alertIcon.warning {
	params: ({ color: colors.black });
}

button.secondary{
	color: const(colors.buttonSec) !important;
}

button.secondary:active, button.secondaryAlt:active {
	color: const(colors.white) !important;
}

sprite.icon.downloadToPhone {
	params: ({ color: colors.black });
}

button.cardFooter.action {
	bg: buttonBg;
	color: const(colors.buttonText);
}

button.cardFooter.action:active {
	bg: const(colors.pressed);
}

button.cardFooter.action:active sprite {
	params: ({ color: colors.black });
}

button:disabled, button.cardFooter.action:disabled {
	bg: buttonDisabled;
	color: const(colors.lightGrey) !important;
	bgOpacity: 100% !important;
}

button.cardFooter.action:disabled sprite, button:disabled sprite {
	params: ({ color: colors.lightGrey });
}

text#inputLabel {
	color: const(colors.lightGrey);
 }

input {
	emptyColor: const(colors.lightGrey) !important;
}

text.theme {
	color: const( colors.black ) !important;
}

text.savingPrice {
	color: const( colors.savingPrice );
}

sprite.menuKnob.maps {
	params: ({ color: colors.knob });
}

text.mianTitle {
   textTransform: @lowercase !important;
}

text.msgbox {
	fontBold: true;
	color: const(colors.black) !important;
}

text.msgbox.secondLine{
	fontBold: false;
	font: const(fontType.default) !important;
	fontSize: const(fontSizes.paragraph) !important;
}

text.msgbox.thirdLine{
	fontBold: false;
	font: const(fontType.default) !important;
	fontSize: const(fontSizes.paragraph) !important;
}

text.messageboxCheckbox {
	fontBold: false;
    font: const(fontType.default) !important;
    fontSize: const(fontSizes.paragraph) !important;
}

button {
    textTransform: @lowercase;
}

template#tTag > .bg.purchased, .tagBg.purchased,
template#tTagFilter > .bg.purchased, .tagBg.purchased
{
	img:{
		borderRadius: 2,
		img:(CSS.param.colors.black),
	};
}

switch {
    checkedBackground: const(colors.black) !important;
	background: const(colors.switchBg)
}

sprite#closeAction.warning {
	params = ({color: #000});
}

sprite.msgboxIcon {
	params: ({ color: colors.black })
}

text.new, text.discount, text.update, text.free, text.owned, text.purchased, text.inBasket {
	color: const( colors.theme ) !important;
	textTransform: @uppercase;
}

text.discount, text.update {
	color: const( colors.black ) !important;
	textTransform: @uppercase;
}

text.osm {
	color: const( colors.white ) !important;
	textTransform: @uppercase;
}

sprite.bg.tag {
    img: const(colors.black) !important;
}

sprite.bg.tag.discount, sprite.bg.tag.update {
	img: const(colors.theme) !important;
}

sprite.bg.tag.osm{
	img: const(colors.osm) !important;
}

sprite.icon.close, sprite.icon.osm,
sprite.icon.owned, sprite.icon.purchased, sprite.icon.inBasket {
    params: ({ color: colors.white }) !important;
}

sprite.icon.discount, sprite.icon.update {
	params: ({ color: colors.black }) !important;
}

template#tTag > .bg.discount, .tagBg.discount, template#tTag > .bg.update, .tagBg.update,
template#tTag > .bg.osm, .tagBg.osm, template#tTag > .bg.inBasket, .tagBg.inBasket, template#tTag > .bg, .tagBg{
    img:{
        borderRadius: 2,
        img:(CSS.param.colors.black),
    } !important;
}

template#tTag > .bg.osm{
    img:{
        borderRadius: 2,
        img:(CSS.param.colors.osm),
    } !important;
}

template#tTag > .bg.discount, .tagBg.discount, template#tTag > .bg.update, .tagBg.update {
    img:{
        borderRadius: 2,
        img:(CSS.param.colors.theme),
    } !important;
}

text#basePrice {
    font: const(fontType.readbd);
    color: const( colors.black );
}

sprite.strikethrough {
    img: const( colors.black );
}
