@declare {
    logoH: 13;
    onboardingPadding: 40;
    declare fontType {
        default: @DaciaBlock;
        defaultbd: @DaciaBlock_Bold;
        read: @FontRead_Regular;
        readbd: @FontRead_Bold;
        readlight: @FontRead_Light;
    }
    declare colors {
        themeColor: #646C53;
        alert: #ff671b;
        border: #cccccc;
        buttonSec: #000;
        buttonSecAlt: #fff;
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
	img: (LinearGradient(0deg,#000,18%,#000,22%,0x00ffffff, 100%, 0x00ffffff));
}

text.onboarding {
    color: const(colors.white);
}

button {
    textTransform: @uppercase;
}

text#alertText.warning {
	color: const(colors.black);
}

sprite#alertIcon.warning, sprite#closeAction.warning {
	params: ({ color: colors.black });
}

switch {
    checkedBackground: const(colors.black) !important;
}

switch.onboardingSwitch {
    checkedBackground: const(colors.themeColor) !important;
}