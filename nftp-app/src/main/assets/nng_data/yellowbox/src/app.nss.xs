import {@registerStyle} from "uie/styles.xs"
import themeManager from "uie/themes/theme_manager.xs"
import { config } from "./app.xs"

@registerStyle
style appStyle {
	@declare {
		headerImageH: 28;
		knobSize: 18;
	}

sprite.selectionMarker {
    img: const( colors.themeColor );
    align: @center;
    w: 100%;
    h: 4;
    imageH: 4;
    bottom: 0;
    visible: 0;
}

:selected > .selectionMarker, :active .selectionMarker {
    visible: 1;
}

:active .selectionMarker {
    img: const( colors.pressed ); // DACIA Orange in design
}

#header {
    // empty
}

.footerMenuItem {
    
    boxAlign:@stretch !important;
    flex:1;
}

sprite.menu{
    align: @center;
    valign: @center;
    params: ({ color: colors.darkGrey });
}

sprite.menuKnob {
    img: "knob.svg";
    imageW: ( knobSize );
    right: (( this.parent.w-iconSize.normal )/2 - knobSize/2 );
    top: (( this.parent.h-iconSize.normal )*6/10 - knobSize/2 );
}

sprite.menuKnob.basket {
    params: ({ color: colors.knob });
}

sprite.menuKnob.maps {
    params: ({ color: colors.success });
}

sprite.loadingProgress {
    align: @center;
    boxAlign: @center;
    img: "loading.svg";
    params: ({ color: colors.black });
}

sprite.loading {
    align: @center;
    boxAlign: @center;
    img: "loading.svg";
    params: ({ color: colors.darkGrey });
}

sprite.loading.animated, sprite.loadingProgress.animated {
    transition: @transformRotate, 2s, @linear;
    transformRotate: -360;
    onAnimationFinished: function() {
        if (this.visible)
            this.transformRotate += 360;
    };
    onShow: function() { this.transformRotate += 360; };
    onHide: function() { this.transformRotate = 0; };			
}

text.loading {
    color: const(colors.infoText);
    font: const(fontType.defaultbd);
    fontSize: const(fontSizes.large);
    align=@center;
    boxAlign: @center;
    paddingBottom: const( paddings.extraLarge );
}

group.emptyResult{
    flex: 1;
    position: @fixed;
    w: 100%;
    h: 100%;
}

#tMenuItem:selected sprite.menu, #tCart:selected sprite.menu, #tMaps:selected sprite.menu {
    params: ({ color: colors.black });
}

#tMenuItem:disabled {
    opacity: 1.0;
}

#header > sprite.headerIcon {
    imageW: const( iconSize.normal);
    img: "";
    touchEvents: @box;
    paddingLeft: const(paddings.extraLarge);
    paddingRight: const(paddings.extraLarge);
    paddingTop: const(paddings.large);
    paddingBottom: const(paddings.large);
}

#header > sprite.headerBack {
    img: "back.svg";
}

#header > sprite.status {
    img: "car_connected.svg";
}

#header > sprite.status.connected {
    params: ({ color: colors.success });
}

#header > sprite.status.disconnected {
    params: ({ color: colors.alert });
}

#header > sprite.lineSeparator {
    img: ( colors.mainBg );
    position: @absolute;
    bottom: 0;
    h: 1;
    w: 100%;
}

}

@onLoad
initThemes() {
    themeManager.addTheme({ name: "dacia", title: "Dacia theme" });
    themeManager.addTheme({ name: "naviextras", title: "Naviextras theme" });
    themeManager.addTheme({ name: "saic", title: "Saic theme" });
    themeManager.addTheme({ name: "renault", title: "Renault theme" });
    const defaultTheme = config.defaultTheme;
    const activeTheme = SysConfig.get("yellowBox", "theme", defaultTheme);
    themeManager.changeTheme(activeTheme);
}