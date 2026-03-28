import {@registerStyle} from "uie/styles.xs"

@registerStyle
style userProfile {
    @declare{
        helpPadding: 20;
        helpContainerSize: 48;
        helpTemplateH: 60;
        formFieldH: 56;
        helpOSUpdateTitle: 120;
        helpTitlePadding: 14;
    }

    text.title.user {
        paddingLeft: const(paddings.main);
    }

    text.secTitle{
        paddingTop: const(paddings.detail);
    }

    text.createAcc{
        boxAlign: @center !important;
        paddingBottom: const( paddings.main);
    }

    text.empty {
        color: const(colors.infoText);
        font: const(fontType.defaultbd);
        fontSize: const(fontSizes.large);
        align=@center;
        boxAlign: @center;
        paddingBottom: const( paddings.extraLarge );
    }

      text.empty.link {
        paddingRight: const(paddings.medium);
        underline: 1;
    }

    text.withSeparators {
        canShrink: false;
        wordWrap: 1;
    }

    template#tAction, template#tSimpleLink, template#tActionCars {
        desiredH: formFieldH;
        boxAlign: @stretch;
    }

    template#tAction:disabled {
        opacity: 0.2;
    }

    template#tProfile, template#tAction, template#tActionCars {
        paddingBottom: const(paddings.small);
    }

    template#tSwitch {
        desiredH: formFieldH;
    }

    template#tSwitch text {
        paddingRight: const(paddings.large);
    }

    template#tSwitch > *, template#tTextWithLink >> *, template#tSwitchWithLink >> *{
        boxAlign: @stretch;
        valign: @center;
    }

    template#tSwitch > switch > *, template#tSwitchWithLink >> switch > * {
        boxAlign: @center;
    }

    sprite.actionChevron {
        img: "chevron.svg";
        params: ({ color: colors.black });
        rotate: 90;
    }

    sprite.bg.address {
        img: const({ borderWidth: 2, borderImg:( #585858 ), img:( #EFEFEF ) });
        boxShadow: ( 0, 4, 8, 6, #B8B8B8, @shallow );    
    }

    sprite.separator {
        imageH: 1;
        w: 100%;
        img: const( colors.separator );
    }

    sprite.separator.form {
        paddingBottom: const( paddings.main );
    }

    sprite.separator.list {
	    position: @absolute;
        bottom: 0;
        left: 0;
    }

    sprite.closePanel {
        img: "close.svg";
        position: @fixed;
        right: const(paddings.main);
        top: const(paddings.main);
        imageW: 24;
        imageH: 24;
    }

    template.field {
        marginBottom: const(paddings.main);
        paddingRight: const(paddings.small);
    }

    group.userTitle {
        desiredH: formFieldH;
    }

    template.helpTitle {
        paddingLeft: helpTitlePadding;
        paddingTop: const(paddings.small);
    }

    text.helpTitle {
        desiredH: formFieldH;
        h: 100%
    }

    text.helpOSUpdateTitle {
        maxH: helpOSUpdateTitle;
        wordWrap: 4;
    }

    group.dataInfo {
        paddingTop: const(paddings.small);
        // todo: paddingBottom messes up maxScroll calculation somehow
        marginBottom: const(paddings.xs);
    }

    group.form {
        desiredH: formFieldH
        marginBottom: const(paddings.main);
    }

     group.form.formTitle {
        boxAlign: @left;
        valign: @center;
        paddingTop: const( paddings.extraLarge );
        marginBottom: const( paddings.medium );
    }

    group.form > sprite {
        img: borderAtBottom;
    }

    sprite.helpIconContainer {
        imageW: helpContainerSize; 
        imageH: helpContainerSize;
        minW: helpContainerSize;
        h: helpContainerSize;
		img: ({
			borderRadius: ( [ this.h / 2 ] ),
			img: ( colors.backgroundGrey )
		});	   
    }

    .horizontal.flexible > .helpIconContainer {
         boxAlign: @top; 
    }

    sprite.helpIcon {
        left: 50%;
        top: 50%; 
        translateX: -50%; 
        translateY: -50%;
        align: @center;
    }

    sprite.decorLine {
        imageW: 2;
        img: const( colors.lightGrey );
        position: @absolute;
        left: const( helpContainerSize/2 -1);
        top: (index==1 ? ( helpContainerSize/2 + helpPadding ) : 0 );
        h: ( index==param.listSize-1 ? ( helpContainerSize/2 + helpPadding )  : 100%);
    }

    #tHelp {
        paddingTop: helpPadding;
         w: 100%;
    }

    #tHelpMain, #tHelpTitle {
        w: 100%;
    }

    #tHelpOSUpdateTitle {
        paddingTop: helpPadding;
        paddingBottom: helpPadding;
    }

    #tDataField {
        marginTop: const( paddings.small );
        w: 100%;
    }

    #frForgotPassword > group.dataInfo {
        paddingBottom: const( paddings.medium);
    }

    group.carHeader {
        paddingBottom: const( paddings.main );
    }

    spacer.help {
         desiredH: helpPadding; 
    }

    group.actionButtons {
        paddingBottom: const( paddings.button );
    }

    // Checkbox
     checkbox.formCheckBox {
        iconH: const( iconSize.small );
        iconW: const( iconSize.small );
    }

    checkbox.formCheckBox >>> sprite.chkImg {
        img: "checkbox.svg" !important;
        params: const({ color: colors.lightGrey });
        desiredW: const( iconSize.small );
        desiredH: const( iconSize.small );
        marginRight: const( paddings.large );
    }

    checkbox.formCheckBox:checked >>> sprite.chkImg {
        img: "checkbox-checked.svg" !important;
        params: const({ color: colors.black })
    }

    checkbox.formCheckBox.invalid >>> sprite.chkImg {
        params: const({ color: colors.error })
    }

    #tTextWithLink >>> sprite.icon{
        img:"red_close_circle.svg";
        params: ({color: colors.red});
    }

    #tTextWithLink:checked >>> sprite.icon{
        img:"indicator.svg";
        params: ({color: colors.green});
    }
}
