@declare {
    logoH: 36;
    onboardingPadding: 20;

    declare addedButtonBg {
        borderImg: #006FB7;
    }

    declare buttonBg {
        img: #006FB7;
    }

    declare fontType {
        default : @TitilliumWeb_Regular;
        defaultbd: @TitilliumWeb_Bold;
        read: @TitilliumWeb_Regular; // hiba
        readbd: @TitilliumWeb_SemiBold; // ok
        readlight: @TitilliumWeb_Light;
    }

    declare colors {
        themeColor: #006FB7;
        textSec: #ff7d7d7d;
        infoText: #D9D9D9;
        hint: #FF7548;
        alert: #FF7548;
        pressed: #009EE0;
        pressedSecondary: #009EE0;
        checked: #FF7548;
        theme: #006FB7;
        fade: #ff7d7d7d;
        selectedMenuItem: #ff707070;
        selectedUpload: #ff41647b;
        checkedBg: #ff5f788a;
        randomBackgrounds: [#ffbccfdb, #ffa2c5dd, #ff7cb0d3];
        buttonSecAlt: #006FB7;
    }
}

sprite.bg.onboarding1 {
    img: "onboarding_1a.jpg";
}

sprite.bg.onboarding2 {
    img: "onboarding_2a.jpg";
}

sprite.bg.onboarding3 {
    img: "onboarding_3a.jpg";
}

sprite.bg.onboardingGradient{
	img: (LinearGradient(0deg,#fff,18%,#fff,30%,0x00ffffff, 100%, 0x00ffffff));
}

text.onboarding {
    color: const(colors.theme);
}

