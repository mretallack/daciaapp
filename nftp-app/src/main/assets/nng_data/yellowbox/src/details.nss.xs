import {@registerStyle} from "uie/styles.xs"

@registerStyle
style details {
	@declare {
		addButtonHorPadding = 13;
		addButtonVertPadding = 32;
		radioBg = #F2F2F2;
		checkedBg = {
			borderWidth: 2,
			borderImg: (colors.checkedBg),
			img: #F2F2F2, 
		}
	}

	sprite.back {
		img: "back.svg";
		boxAlign: @left !important;
		imageH: 25;
		paddingBottom: const(paddings.large);
		paddingTop:const(paddings.large);
		paddingRight:const(paddings.large);
	}

	sprite.details {
		zoom: "ASPECT_FILL";
    	preserveAspectRatio: 1;
		boxAlign: @center !important;
		overflow: @hidden;
		align: @center;
		valign: @center;
		maxH: 150;
		w: @unset;
		paddingBottom: const(2*paddings.medium);
	}

	group.tagList {
		position: @fixed;
		top: const(paddings.small);
		left: 0; 	
	}

	group.subs {
		paddingBottom: const(paddings.extraLarge);
	}

	dropMenu.subs {
		paddingTop: const( paddings.main );
		paddingBottom: const( paddings.main );
	}

	.detailTitle{
		paddingTop:const(paddings.large);
		paddingBottom:const(paddings.detail)
	}
}