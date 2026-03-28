@import "~/src/theme/common.nss"
@import "~/src/theme/dacia.nss"  if (System.import("uie/themes/theme_manager.xs").default.current.name == "dacia");
@import "~/src/theme/naviextras.nss" if (System.import("uie/themes/theme_manager.xs").default.current.name == "naviextras");
@import "~/src/theme/saic.nss" if (System.import("uie/themes/theme_manager.xs").default.current.name == "saic");
@import "~/src/theme/renault.nss" if (System.import("uie/themes/theme_manager.xs").default.current.name == "renault");

.fill {
    top: 0;
    bottom: 0;
    left: 0;
    right: 0;
}

// use for fragments inside main controller
.main {
    paddingLeft: 0;
    paddingRight: 0;
    paddingBottom: 0;
    paddingTop: 0;
}

.mainContentPadding {
    paddingLeft: const(paddings.extraLarge);
    paddingRight: const(paddings.extraLarge);
}

.footer {
    desiredH: 64; 
}

// ---------- common text styles ----------------

// new text styles
text.h0 {
    fontSize: const( fontSizes.h0);
    font: const(fontType.defaultbd);
}

text.h1 {
    fontSize: const( fontSizes.h1);
    font: const(fontType.default);    
}

text.h2 {
    fontSize: const( fontSizes.h2);
    font: const(fontType.defaultbd);    
}

text.h3 {
    fontSize: const( fontSizes.h3);
    font: const(fontType.default);    
}

text.paragraph {
    fontSize: const( fontSizes.paragraph);
    font: const(fontType.read);    
}

text.button {
    fontSize: const( fontSizes.h3);
    font: const(fontType.defaultbd);     
}

// input small in the design
text.small {
    font: const(fontType.read);     
    fontSize: const( fontSizes.h3);    
}

text.label {
    fontSize: const( fontSizes.label); 
    font: const(fontType.defaultbd);    
}

text.theme {
    color: const( colors.theme );
}

text.darkgrey {
    color: const( colors.darkGrey );
}

text.lightgrey {
    color: const( colors.lightGrey );
}

text.owned, text.purchased {
   color: const( colors.theme ); 
}

text.free, text.discountPrice {
   color: const( colors.success ); 
}

text.new {
   color: const( colors.alert ); 
}

text.osm, text.discount, text.update {
    color: const( colors.white );
}


// old text styles
text.detail {
    font: const(fontType.read);
    fontSize: const(fontSizes.hint);
}

text.dropdown {
    font: const(fontType.read);
    fontSize: const(fontSizes.main);    
}

text.title {
	font: const(fontType.readbd);
	fontBold: true;
	fontSize: const(fontSizes.small);
}

text.mianTitle {
   textTransform: @uppercase;
}

text.medium, text.messageboxCheckbox {
    font: const(fontType.read);
    fontSize: const(fontSizes.medium);
}

// todo: duplicate "text.label"
text.label {
    font: const(fontType.read);
    fontSize: const(fontSizes.small);
    color: const(colors.label);
    marginBottom: 3;
}

text.threeline {
    wordWrap: 3;
}

text.twoline {
    wordWrap: 2;
}

text.oneline {
    wordWrap: 1;
}

text.underline {
    underline: 1; 
}

text.linkBlue {
    color: const(colors.blue);
}

text.subtitle {
	font: const(fontType.read);
	fontSize: const(fontSizes.hint);
    color: const( colors.details );
    paddingBottom: const(paddings.small);
}

text.hint {
    color: const(colors.hint);
    fontSize: const(fontSizes.hint);
    font: const(fontType.read);
    underline: 1; 
}

text.link {
    color: const(colors.black);
    fontSize: const(fontSizes.small);
    font: const(fontType.read);
}

text.error {
    color: const(colors.error);
    fontSize: const(fontSizes.small);
    font: const(fontType.read);
}

text.right {
    boxAlign: @right !important;
}

text.center {
    boxAlign: @center !important;
}

text.vcenter {
    valign: @center !important;
}

text.top {
    boxAlign: @top !important;
}

text.bd {
    fontWeight: @bold;
}

//------------- paddings ------------------------------

.smallPaddingX {
    paddingLeft: const(paddings.small);
    paddingRight: const(paddings.small);
}

.smallPaddingY {
    paddingTop: const(paddings.small);
    paddingBottom: const(paddings.small);
}

.smallPadding {
    paddingLeft: const(paddings.small);
    paddingRight: const(paddings.small);
    paddingTop: const(paddings.small);
    paddingBottom: const(paddings.small);        
}

.detailPaddingY{
    paddingTop: const(paddings.detail);
    paddingBottom: const(paddings.detail); 
}

.xsPadding {
    paddingLeft: const(paddings.xs);
    paddingRight: const(paddings.xs);
    paddingTop: const(paddings.xs);
    paddingBottom: const(paddings.xs);        
}

.xsPaddingY {
    paddingTop: const(paddings.xs);
    paddingBottom: const(paddings.xs);        
}

.mainPaddingX {
    paddingLeft: const(paddings.main);
    paddingRight: const(paddings.main);
}

.mainPaddingY {
    paddingTop: const(paddings.main);
    paddingBottom: const(paddings.main);
}

.mainPadding {
    paddingLeft: const(paddings.main);
    paddingRight: const(paddings.main);
    paddingTop: const(paddings.main);
    paddingBottom: const(paddings.main);
}

.tenPaddingX {
    paddingLeft: const(paddings.ten);
    paddingRight: const(paddings.ten);
}

.mediumPaddingX {
    paddingLeft: const(paddings.medium);
    paddingRight: const(paddings.medium);
}

.mediumPaddingY {
    paddingTop: const(paddings.medium);
    paddingBottom: const(paddings.medium);
}

.largePadding{
    paddingLeft: const(paddings.large);
    paddingRight: const(paddings.large);
    paddingTop: const(paddings.large);
    paddingBottom: const(paddings.large);
}

.largePaddingX{
    paddingLeft: const(paddings.large);
    paddingRight: const(paddings.large);   
}

.largePaddingY {
    paddingTop: const(paddings.large);
    paddingBottom: const(paddings.large);
}

.extraLargePadding {
    paddingLeft: const(paddings.extraLarge);
    paddingRight: const(paddings.extraLarge);
    paddingTop: const(paddings.extraLarge);
    paddingBottom: const(paddings.extraLarge);
}

.extraLargePaddingX {
    paddingLeft: const(paddings.extraLarge);
    paddingRight: const(paddings.extraLarge);
}

.extraLargePaddingY {
    paddingTop: const(paddings.extraLarge);
    paddingBottom: const(paddings.extraLarge);
}

.extraHugePaddingX {
    paddingLeft: const(paddings.extraHuge);
    paddingRight: const(paddings.extraHuge);
}

.extraHugePaddingY {
    paddingTop: const(paddings.extraHuge);
    paddingBottom: const(paddings.extraHuge);
}

.extraHugePadding {
    paddingLeft: const(paddings.extraHuge);
    paddingRight: const(paddings.extraHuge);
    paddingTop: const(paddings.extraHuge);
    paddingBottom: const(paddings.extraHuge);
}

//------------ margin ---------------------------------

.smallMarginX {
    marginLeft: const(paddings.small);
    marginRight: const(paddings.small);
}

.smallMarginY {
    marginTop: const(paddings.small);
    marginBottom: const(paddings.small);
}

.smallMargin {
    marginLeft: const(paddings.small);
    marginRight: const(paddings.small);
    marginTop: const(paddings.small);
    marginBottom: const(paddings.small);        
}

.detailMarginY {
    marginTop: const(paddings.detail);
    marginBottom: const(paddings.detail);
}

.mainMarginX {
    marginLeft: const(paddings.main);
    marginRight: const(paddings.main);
}

.mainMarginY {
    marginTop: const(paddings.main);
    marginBottom: const(paddings.main);
}

.mainMargin {
    marginLeft: const(paddings.main);
    marginRight: const(paddings.main);
    marginTop: const(paddings.main);
    marginBottom: const(paddings.main);
}

.mediumMarginX {
    marginLeft: const(paddings.medium);
	marginRight: const(paddings.medium);
}

.largeMarginX {
    marginLeft: const(paddings.large);
    marginRight: const(paddings.large);
}

.largeMarginY {
    marginTop: const(paddings.large);
    marginBottom: const(paddings.large);
}

.extraLargeMarginX {
    marginLeft: const(paddings.extraLarge);
    marginRight: const(paddings.extraLarge);
}

.extraLargeMarginY {
    marginTop: const(paddings.extraLarge);
    marginBottom: const(paddings.extraLarge);
}

.smallMarginRight {
    marginRight: const(paddings.small);
}

//------------------icons--------------------------------

.icon.small {
    imageW: const(iconSize.small);
    imageH: const(iconSize.small);
}

.icon.normal {
    imageW: const(iconSize.normal);
    imageH: const(iconSize.normal);
}

.icon.big {
    imageW: const(iconSize.big);
    imageH: const(iconSize.big);
}

.icon.large {
    imageW: const(iconSize.large);
    imageH: const(iconSize.large);
}

.icon.extraLarge {
    imageW: const(iconSize.extraLarge);
    imageH: const(iconSize.extraLarge);
}

//-------------spacer---------------
spacer.horizontal.medium {
    desiredW: const( paddings.medium );
}

window {
    color: const(colors.text);
    minAspect: 1.0;
    wordWrap: 0;
    fontSize: const( fontSizes.small );
}

button {
    bg: buttonBg;
    color: const(colors.buttonText);
    canShrink: false;
}

button.pri, button.primary {
    bg: const(colors.black);
}

button.sec, button.secondary {
    bg: secondaryButtonBg;
    color: const(colors.buttonSec);
}

button.secAlt, button.secondaryAlt{
    bg: secondaryAltButtonBg;
    color: const(colors.buttonSecAlt);
}

button:active {
    bg: const(colors.pressed);
}

button.sec:active, button.secondary:active, button.secAlt:active, button.secondaryAlt:active {
    bg: activeButtonBorderBg;
    color: const(colors.pressedSecondary);
}

*:disabled {
    disabledColorEffect: "none";
}

button:disabled {
    bgOpacity: 20%;
    opacity: disabledButtonTextOpacity;
}

button.sec:disabled, button.secondary:disabled, button.secAlt:disabled, button.secondaryAlt:disabled {
    opacity: 20%;
}

template:disabled {
    opacity: 70%;
}

button > .icon {
    params: ({ color: colors.buttonText });
}

button text {
    font: const(fontType.defaultbd);
	fontSize: const(fontSizes.h3);
    color: const(colors.buttonText);
}

button.standard {
    paddingLeft: const(paddings.medium); paddingRight: const(paddings.medium);
	paddingTop: const(paddings.main); paddingBottom: const(paddings.main);
}

.main > #bg {
    img: const(colors.background);
}

.main {
    w: 100%;
    h: 100%;
    layout: @flex;
    orientation: @vertical;
    //perspective: 1300;
}

.main > group {
    boxAlign: @stretch;
}

.flexible.vertical {
    layout=@flex;
    orientation=@vertical;
    valign: @top;
}

.flexible.vertical > * {
    boxAlign: @stretch;
}

.flexible.vertical .hint, .flexible.vertical .link {
    boxAlign: @right;
}

/*.flexible.vertical button {
    boxAlign: @center;
}*/

.flexible.vertical > button.form {
    boxAlign: @stretch;
}

.flexible.horizontal {
    layout=@flex;
    orientation=@horizontal;
}

.flexible.horizontal > * {
    boxAlign: @center;
}

.flexible.horizontal > button.form {
    flex: 1;
}

.flex {
    flex: 1;
}

.scrollable {
    scrollable: 1;
    overflow: @hidden;
    zroot: 1;
}

.dropdownList {
    left: 10%;
    w: 80%; 
    top: 30%; 
    h: 40%;
}

listView > scroll, .favorites  scroll, .scrollable > scroll {
    sliderImg: ({img: colors.text, borderRadius: 4});
    opacity: 30%;
    scroll: (this.parent.scroll);
    position:@fixed;
    minSize: 40;
    w: 4;
    paddingRight: 0;
}

listView.content > scroll {
    paddingTop: 10;
}


.scrollable > wheel, listView > wheel {
    scroll:(this.parent.scroll);
    position:@fixed;
    delayClick:0;
    opposite: undef;
    deceleration: 2.0;

    left:0;
    right: 0;
    top: 0;
    bottom: 0;
}

sprite.bg {
    position: @absolute;
    top: 0;
    left: 0;
    w: 100%;
    h: 100%;
    img: const(colors.background);
}

sprite.bg.faded {
    img: const(colors.fade);
    alpha: 24;
    // opacity: 90%;
}

sprite.bg.panel {
    img: const( colors.mainBg);
}

sprite.bg.rounded{
    img: { img:#fff, borderRadius:12 }
}

sprite.bgSelected {
    position: @absolute;
    top: 0;
    left: 0;
    w: 100%;
    h: 100%;
    img: const(colors.backgroundGrey);
}

sprite.icon.white {
    params: ({ color: colors.white });
}

sprite.bg.tag {
    img: const(colors.white);
}

sprite.bg.tag.osm {
    img: const(colors.osm);
}

sprite.bg.tag.discount, sprite.bg.tag.update {
    img: const(colors.success);
}

sprite.icon.close {
    params: ({ color: colors.black });
}


sprite.icon.osm, sprite.icon.discount, sprite.icon.update {
    params: ({ color: colors.white });
}

// input styles
input {
    fontSize: const( fontSizes.h2 );
    font: const(fontType.read);
    bg: #fff;
    emptyColor: const(colors.darkGrey);
    color: const(colors.black);
    caretColor: const(colors.cursor)
    touchEvents: @box;
}

input:disabled {
    color: const(colors.darkGrey);
}

input.search {
    desiredH: 48;
    activateOnShow: false;
}

input.search.error {
    bg: inputErrorBg;
}

sprite.input {
    imageW: inputIconW;
    imageH: inputIconH;
    boxAlign: @center;
    align: @right;
    params: ({ color: colors.border });
}

sprite.input.black {
    params: ({ color: colors.black });
}

.noResults {
    align: @center;
    boxAlign: @center;		
}

sprite.noResults {
    paddingBottom: const( paddings.extraLarge );
    params: ({ color: colors.darkGrey });
}

sprite.bg.topShadow {
    boxShadow: ( 0, -4, 8, 0, #0D000000, @shallow );
}

sprite.bg.topLine {
    img: borderAtTop;
}

sprite.lightShadow {
    boxShadow: ( 0, 2, 10, 0, #23000000, @shallow );
}

// progress
sprite.progress.indeterminate {
    transition: @transformRotate, 0.6s, @linear;
    transformRotate: -360;
    onAnimationFinished: function() {
        if (this.visible)
            this.transformRotate -= 360;
    };
    onShow: function() { this.transformRotate -= 360; };
    onHide: function() { this.transformRotate = 0; };
}

sprite.image {
    zoom: "ASPECT_FILL";
    preserveAspectRatio: 1;
}

button >>> text {
    font: const(fontType.defaultbd);
    minAspect: 0.75;
}

sprite.contentImage{
    boxAlign: @top;
    zoom: "ASPECT_WITHIN";
    preserveAspectRatio: 1;
    //paddingTop:const(paddings.small); paddingBottom:const(paddings.small); 
    paddingLeft:const(paddings.xs); paddingRight: const(paddings.xs);
    imageH: 142;
}


// system props
.key {
    desiredW: 120;
}

.value {
    fontSize: 18;
}

button.action {
    paddingLeft: const(paddings.small);
    paddingRight: const(paddings.small);
    paddingTop: const(paddings.main);
    paddingBottom: const(paddings.main); 
}

button.infoButton {
    paddingLeft: const(paddings.large);
    paddingRight: const(paddings.large);
    paddingTop: const(paddings.main);
    paddingBottom: const(paddings.main);

}

button.large {
    //paddingLeft: const(2*paddings.large); paddingRight: const(2*paddings.large);
    paddingTop: const(paddings.button); paddingBottom: const(paddings.button);    
    boxAlign: @stretch; 
}

button.add {
    marginBottom: const(paddings.extraLarge);
    marginTop: const(paddings.main);
    minH: buttonH;
}

button.infoButton {
    bg: addedButtonBg;
}

button.infoButton >>> text {
    color: const( colors.theme );
}

button.added {
    text: "ADDED";
    bg: addedButtonBg;
    color: const( colors.themeColor );
}

button.footer {
    desiredH: buttonH;
}

button.form {
    desiredH: buttonH;
    marginBottom: const(paddings.main);
    marginTop: const(paddings.main);
}

button.form.gap {
    marginRight: const(paddings.main);
}

progress.upload {
    desiredH:20;
    marginTop:10;
    marginBottom:10;
}

progress.disk {
    desiredH:5;
    marginBottom:20;
}

text.upload {
    fontSize:0.7em;
    marginBottom:10;
    align: @center;
}

#frOverlay {
    transition: (@alpha, 400ms);
    alpha: 0;
}

#frOverlay.shown {
    alpha: 24;
}

#frOverlay > sprite {
    alpha: @inherit;
}

switch {
    checkedBackground: const(colors.themeColor);
    knobBorderWidth: 2;
    switchW: 52;
    switchH: 32;
    switchShrink: false
}

.switchPadding{
    marginBottom: const( paddings.main );
}

