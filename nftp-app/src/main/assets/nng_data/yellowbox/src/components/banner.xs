import {@registerStyle} from "uie/styles.xs"

export <component banner class=flexible, horizontal useVisibleArea=1 >
    own {
        export let banner;
        bannerOnRelease() {
            if ( banner?.onRelease ) {
                ??banner.onRelease();
                banner.hide();
            }
        }
    }
    <alert text=(banner.text) icon=(banner?.icon) level=(banner?.level) visible=(banner.active) onRelease=bannerOnRelease>
        <sprite closeAction class=(@alertAction,@icon,@normal,banner?.level) img=( "close.svg" ) onRelease() { ??banner.closeAction(); banner.hide(); } />
    </alert>
</component>

export getBanner(id) {
    allBanners[id] || emptyBanner;
}

Banner emptyBanner;
dict allBanners{
    cart = new Banner;
    userReg = new Banner;
    userEdit = new Banner;
    signIn = new Banner;
    forgotPassword = new Banner;
    changePassword = new Banner;
    meteredConnectionInDownload = new Banner;
};

export class Banner {
    active = false;
    text = "";
    icon;
    level;
    onRelease;
    closeAction;

    constructor(text="", params={}) {
        this.init(text, params);
    }

    show (text, params) {
        this.active = true;
        this.init(text, params);
        return this;
    }

    init(text, params) {
        this.text = text;
        this.icon = params?.icon;
        this.level = params?.level;
        this.onRelease = params.onRelease ?? undef;
        this.closeAction = params.closeAction ?? undef;
        if (params?.active) this.active = params.active;
    }

    activate() {
        this.active = true;
        return this;
    }

    hide() {
        this.active = false;
        return this;
    }
}

@registerStyle
style bannerStyle {
    sprite#closeAction {
        params = ({color: #000})
    }

    sprite#closeAction.success, sprite#closeAction.error, sprite#closeAction.warning {
        params = ({color: #FFF});
    }
}
