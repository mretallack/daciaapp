import {@registerStyle} from "uie/styles.xs"

@registerStyle
style onboarding {

	sprite.onboardingBg {
		zoom: "ASPECT_FILL";
		preserveAspectRatio: 1;
		//overflow: @hidden;
		align: @center;
		valign: @center;		
	}

	sprite.bg.onboardingBg {
		h: 82%;
	}

	sprite.bg.onboardingGradient{
    	position: @absolute;	
		left: 0;
		bottom: 0;
		w:100%;
		h: 100%;
	}

	.main.onboarding {
		paddingLeft: 0;
		paddingRight: 0;
	}

	text.onboarding {
		paddingTop: const( paddings.medium );
		paddingBottom: const( paddings.medium );
		paddingLeft: const( paddings.large );
		paddingRight: const( paddings.large );
		wordWrap: 2;
		align: @center;
	}

	text.onboarding.h00 {
		paddingLeft: 0;
		paddingRight: 0;
		textTransform: @uppercase;
		fontSize: 34;
		font: const(fontType.defaultbd);
		minAspect: 0.8;
	}

	text.onboarding.switch {
		paddingLeft: 0;
	}

	group.onboardingContent{
		paddingLeft: const(paddings.extraLarge);
		paddingRight: const(paddings.extraLarge);
		canShrink:false;
	}

	template.onboarding{
		paddingLeft: const(2*paddings.xs);
		paddingRight: const(2*paddings.xs);
	}

	button.onboarding {
		paddingTop: const(paddings.button); 
		paddingBottom: const(paddings.button);
		marginTop: const(paddings.main);
	}

	button.onboarding >>> text, text.onboarding {
	    font: const(fontType.defaultbd);
		fontSize: const(fontSizes.small);
		minAspect: 0.8;
		color: const( colors.white );
	}

	pager.onboarding {
		paddingLeft: const( 2*paddings.extraHuge );
		paddingRight: const( 2*paddings.extraHuge );
		marginBottom: const(paddings.large);
	}

	group.onboardingButtons {
		w: 100%; 
		paddingTop: onboardingPadding;
		paddingBottom: onboardingPadding;
	}	
}