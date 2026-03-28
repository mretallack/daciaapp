@declare {
    logoH: 36;
    onboardingPadding: 40;
    buttonH: 40;
    disabledButtonTextOpacity: 100%;

    declare addedButtonBg {
        borderWidth: 1;
        borderImg: #646C53;
        img: #fafafa;
    }

    declare buttonBg {
        img: #646C53;
    }

    declare secondaryButtonBg {
        borderWidth: 1;
        borderImg: const(colors.buttonSec);
    }

    declare secondaryAltButtonBg {
        borderWidth: 1;
        borderImg: const(colors.buttonSecAlt);
    }

    declare activeButtonBorderBg {
        borderWidth: 1;
        borderImg: const(colors.pressed);
    }

    declare borderAtBottom {
		borderWidth: [0, 0, 1, 0];
		borderImg: const(colors.border);
		img: #fff;
	}
    
    declare borderAtTop {
		borderWidth: [1, 0, 0, 0];
		borderImg: const(colors.mainBg);
		img: const(colors.background);
	}

    declare borderAtBottomActive {
		borderWidth: [0, 0, 1, 0];
		borderImg: #000;
		img: #fff;
	}

    declare borderAtBottomError {
		borderWidth: [0, 0, 1, 0];
		borderImg: const(colors.error);
		img: #fff;
	}
       
    headerH: 40;

    declare fontSizes {
        // old fontsizes
        hint: 12;
        small: 14;
        medium: 16;
        main: 18;
        large: 20;

        // new fontsizes
        label: 12;  //Label
        h3: 14;     //Header3, button, Input small
        h2: 16;     //Header2, Paragraph
        paragraph: 16;
        h1: 26;     //Header1
        h0: 40;     //Header0
    }

    declare fontType {
        default: @default;
        defaultbd: @defaultbd;
        read: @default;
        readbd: @defaultbd;
        readlight: @default;
    }

    declare paddings {
        xs: 2;
        detail: 4;
        small: 6;
        main: 8;
        ten: 10;
        medium: 12;
        button: 14;
        large: 16;
        extraLarge: 24;
        huge: 32;
        extraHuge: 40;
    }

    declare colors {
        themeColor: #646C53;
        /// new colors
        white: #ffffff;
        black: #000;
        theme: #646B52;
        fade: #646B52;
        alert: #ff671b; //This is DACIA ORANGE in the design
        cursor: #ff671b; //This is DACIA ORANGE in the design
        pressed: #ff671b; //This is DACIA ORANGE in the design
        pressedSecondary: #ff671b; //This is DACIA ORANGE in the design
        downloadProgress: #FF671B; //This is DACIA ORANGE in the design
        progress: #ff671b;
        darkGrey: #656666;
        lightGrey: #cccccc;
        trait: #d9d9d9;
        mainBg: #f2f2f2;
        error: #e85252;     // this is Red in the design
        success: #73C366;   // this is Green in the design
        warning: #ffa51c;   // this is Orange in the design
        osm: #009AFE;
        buttonSec: #000;
        buttonSecAlt: #666;
        mapIcon: #fff;

        /// old colors
        knob: #ff671b; // TODO: rename, This is DACIA ORANGE in the design
        label: #656666;
        text: #211A1A;
        textSec: #978B7F;
        infoText: #AEAEAE;
        buttonText: #ffffff;
        hint: #FF671B;
        background: #ffffff;
        
        itemBackground: #fafafa;
        checked: #ff671b;
        border: #cccccc;
        separator: #cccccc;
        details: #777777;
        cardBg: #F2F2F2;
        selectedMenuItem: #646B52;
        selectedUpload: #646B52;
        checkedBg: #646B52;
        randomBackgrounds: [#b1b5a8, #caccc5, #929786];
        messageboxBg: #F2F2F2;
        overlayButtonBg: #F2F2F2;
        overlayButtonBgPressed: #fefefe;
        backgroundGrey: #F1F1F2;

        blue: #009AFE;
        red: #e85252;
        green: #73C366;
    }

    declare iconSize {
        small: 18;
        normal: 24;
        big: 36;
        large: 48;
        extraLarge: 64;
    }

    inputBg: borderAtBottom;
	inputErrorBg: borderAtBottomError;
    inputActiveBg: borderAtBottomActive;
	inputIconW: 24;
	inputIconH: 24;
}

component#switch > sprite.colorAnim {
    transition: undef;
}

sprite.strikethrough {
    top:9;
    right:0;
    position: @absolute;
    img: const( colors.theme );
    h: 1;
}

text#basePrice {
    font: const(fontType.readbd);
    color: const( colors.theme );
}
