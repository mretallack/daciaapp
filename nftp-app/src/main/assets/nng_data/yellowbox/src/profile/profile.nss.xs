import {@registerStyle} from "uie/styles.xs"

@registerStyle
style profile {
@declare{
	separatorH: 20;
	iconContainerSize: 30;
	downloadingIconH: 26;
	phoneIconH: 22;
	inCloudIconH: 28;
	onCarIconH: 30;
	onCarSelectionIconH: 20;
	countryPadding: 6;
}

card group.action > sprite.bg {
	img: const( colors.cardBg );
}

group.iconContainer {
	minH: iconContainerSize;
	minW: iconContainerSize;
}

group.iconContainer > .icon {
	boxAlign: @right;
	valign: @center;
}

group.iconContainer > .incloud {
	imageH: inCloudIconH;
	img: "downloading.svg";  // todo: cloud icon
}

group.iconContainer > .downloading {
	imageH: downloadingIconH;
	img: "downloading.svg";
}

group.iconContainer > .phone {
	imageH: phoneIconH;
	img: "phone.svg";
}

group.iconContainer > .onCar {
	imageH: phoneIconH;
	img: "onCar.svg";
}

group.iconContainer > .failed {
	imageH: phoneIconH;
	img: "alert.svg"; // todo: new icon
}

#tCard card {
	marginBottom: const(paddings.large);
}

#tOnCar .onCar {
	imageH: onCarIconH;
	img: "onCar.svg";
}

#tOnCar:checked .onCar {
	imageH: onCarSelectionIconH;
	img: "selected.svg";
	params: ({ color: colors.checked }); 
}

group.iconContainer > .uploading {
	imageH: onCarIconH;
	img: "transfer_to_car.svg";
}

progress.download {
    desiredH: 5;
	progressImg: const(colors.theme);
	marginBottom: const(paddings.main);
}

progress.upload {
    desiredH: 16;
	progressImg: const(colors.theme);
	marginBottom: const(paddings.main);
}

text.subtitle.sep {
	paddingBottom: 0;
}

text.subtitle.action {
	color: const( colors.alert );
	paddingLeft: const( paddings.large );
}

#mapsTab {
	desiredH: 48;
}

text.tab {
	color: const( colors.darkGrey );
	paddingBottom: const( paddings.main );
}

text.tab:selected {
	color: const( colors.black );
}

#tTab {
	align: @center;
	boxAlign: @stretch;
	touchEvents: @box;
	valign: @bottom;
}

#tTab > text {
	boxAlign: @center;
}

#tTab:selected text.subtitle.tab {
	color: const( colors.alert );
}

sprite.tab.selectionMarker {
	position: @absolute;
	paddingTop: const( paddings.xs );
}

text.title.action {
	color: const( colors.alert );
}

#tListButton, #tSep {
	w: 100%;
}

#tSep {
	desiredH: separatorH;
}

group.selection {
	visible: 0;
}

group.selection:selected {
	visible: 1;
}

sprite.countries{
	imageH: 12;
	imageW: 12;
}

#tCountry sprite{
	paddingLeft: countryPadding;
	params: { color: #AEAEAE };
	img: "selected.svg";
	//params: ( item.selected ? { color: #ff671b } :{ color: #AEAEAE } ) ;
}

#tCountry sprite.uploadSelection {
	img:"selected.svg";
	paddingRight: countryPadding ;
	imageW: 12;
	imageH: 12;
}

#tCountry sprite.uploadSelection.uploaded {
	img: "on_car.svg";
	paddingRight: 0;
	imageW: 18;
	imageH: 18;
}

#tCountry sprite.downloadSelection {
	paddingLeft: countryPadding;
	img: "selected.svg";
	paddingRight: countryPadding;
	imageW: 12;
	imageH: 12;
}

#tCountry sprite.downloadSelection.downloaded {
	paddingLeft: 3;
	img: "phone.svg";
	paddingRight: 0;
	imageW: 18;
	imageH: 18;
}


#tCountry:checked sprite, #tCountry:checked sprite.downloadSelection.downloaded, #tCountry:checked sprite.uploadSelection.uploaded {
	paddingLeft: countryPadding;
	paddingRight: countryPadding;
	img: "selected.svg";
	imageH: 12;
	imageW: 12;
	params: ({ color: colors.checked });
}

#tUploadCountry sprite.upload{
	params: ( item.selected ? { color: colors.selectedUpload } :{ color: #AEAEAE } );
}

#tCountry > * {
	valign: @center;	
}

.vertical.flexible sprite.retry{
	boxAlign: @center;
}

sprite.retry {
	img: "loading.svg";
	params: ({ color: colors.alert });
	imageW: 18;
	imageH: 18;
	align: @center;
	boxAlign: @center;
}

sprite.retry.anim {
	transition: @transformRotate, 2s, @linear;
	transformRotate: 0;
	onAnimationFinished: function() {
		if (this.visible)
			this.transformRotate += 360;
	};
	onShow: function() { this.transformRotate += 360; };
	onHide: function() { this.transformRotate = 0; };	
}

sprite.mapsHeaderIcon{
	paddingLeft: const(paddings.main);
	boxAlign: @bottom !important;
	canShrink: false;
}

sprite.mapsHeaderIcon:disabled{
	opacity: 50%;
}

sprite.mapsHeaderIcon.sized{
	marginBottom: const(paddings.medium);
}

.headerTemplate{
	paddingTop: const(paddings.medium);
	paddingBottom: const(paddings.medium);
}

#frHelpBase {
	paddingLeft: const(paddings.ten);
	paddingRight: const(paddings.extraLarge)
}
}