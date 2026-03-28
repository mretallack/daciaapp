import {@registerStyle} from "uie/styles.xs"

@registerStyle
style basket {
@declare{
	deleteIconH: 28;
	basketFooter: 68;
}

listGrid.basket{
	paddingBottom: const(paddings.huge);
	templateColumns: [1fr];
	rowGap: 4;
	flex: 1; 
	scrollVisible: 0;
}

#tBasketCard {
	w: 100%;
}

sprite.paymentImage{
    paddingTop:100;
    boxAlign: @stretch;
    zoom: "ASPECT_FILL";
    preserveAspectRatio: 1;
    imageH: 340;
}

text.total {
	font: const(fontType.read);
	fontSize: const(fontSizes.small);
}

text.grandTotal {
	font: const(fontType.readbd);
	fontBold: true;
	fontSize: const(fontSizes.large);
}

group.basketFooter{
	paddingBottom: const(basketFooter);
}

group.checkout{
	minH: 180
}

}