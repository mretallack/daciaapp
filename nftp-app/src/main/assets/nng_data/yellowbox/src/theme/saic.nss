@declare {
    logoH: 36;
    onboardingPadding: 20;
    disabledButtonTextOpacity: 50%;

    declare addedButtonBg {
        borderImg: #006FB7;
    }

    declare buttonBg {
        borderWidth: 1;
        borderImg: #000;
        img: #C6EA00;
    }

    declare fontType {
        default : @MG_Regular;
        defaultbd: @MG_Bold;
        read: @MG_Regular; // hiba
        readbd: @MG_Bold; // ok
        readlight: @MG_Light;
    }

    declare colors {
        themeColor: #C6EA00;
        textSec: #ff7d7d7d;
        infoText: #D9D9D9;
        hint: #C6EA00;
        alert: #ff671b;
        pressed: #ffeffc07;
        pressedSecondary: #ffeffc07;
        checked: #FF7548;
        theme: #006FB7;
        fade: #ff7d7d7d;
        selectedMenuItem: #ff707070;
        selectedUpload: #ff41647b;
        checkedBg: #ff5f788a;
        randomBackgrounds: [#ffbccfdb, #ffa2c5dd, #ff7cb0d3];
        buttonSecAlt: #006FB7;
        warning: #C6EA00;
        buttonText: #000;
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

