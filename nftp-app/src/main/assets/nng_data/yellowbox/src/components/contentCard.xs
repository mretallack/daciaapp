import { @registerStyle } from "uie/styles.xs";
import tTag from "../components/tag.ui"

const fallbackHeaderImage = "placeholders/cardHeader.jpg";
export <component contentCard class=flexible,vertical defaults={subtitle: undef, description:"", headerImg:fallbackHeaderImage} >
    own {
        export let expanded = false;
        //export let tags = undef; // list of tags to display in the header
        export let tagAction;
        export let showFooter = false;
        export let showExpander = false;
        export let rounded=true;
    }
    // ## header image
    // todo: attributes={img: headerImg} should work, and should move to default, when headerImg is set to @unset
    <sprite class=( @bg, @lightShadow, rounded? @card : undef ) />
    //<sprite cardHeader img=( #6ff )  >
    <sprite cardHeader img=( attributes.headerImg ?? fallbackHeaderImage )  >
        // - tags
        <group headerTags class=flexible, horizontal >
            <lister model=(attributes.tags ?? []) template=tTag param={ action: tagAction }/>
        </group>
        // todo ez ronda, de nem talaltunk ra jobb megoldast. A lekerekitest meg a maskolo szint legalabb lehetne attribute-bol
        <sprite mask top=-12 bottom=0 left=-12 right=-12 img=({img:#0000, borderWidth:[12,12,0,12], borderRadius:[24,24,0,0], borderImg:#f2f2f2}) visible=(rounded)/>
    </sprite>
    <vbox class=inner> // needed to pad inner area
        // ## card data
        // - title + dropdown
        <hbox titleBox>
            <text title class=h2 attributes={text: title} flex=1  />
            <sprite dropdown visible=(showExpander) checked=(expanded) onRelease(){ invert(expanded) }> 
                <sprite chevronIcon />
            </sprite>
        </hbox>
        // - subtitle (optional)
        <text subTitle class=paragraph, darkgrey attributes={text: subtitle} visible=(attributes.subtitle) />
        // - expire (optional)
        <text expire class=paragraph, darkgrey attributes={text: expire} visible=(attributes?.expire) />
        // - description
        <text description class=paragraph attributes={text: description} visible=(attributes.description) />
        // - alert
        <text alert class=paragraph, error attributes={text: alert} visible=(attributes?.alertVisible) />
        // ## card details (when expanded)
        <vbox details visible=(expanded)>
            <includeChildren filter=".detail"/>
        </vbox>
    </vbox>
     <includeChildren filter=".dividerArea"/>
    // ## footer area, with left and right subareas
    <hbox footer boxAlign=@stretch visible=(showFooter)>
        <sprite class=divider />
        <includeChildren filter=".left.cardFooter"/>
        <spacer flex=1 />
        <includeChildren filter=".right.cardFooter"/>
    </hbox>
</component>

@registerStyle
style cardStyles {
    vbox.inner {
        paddingLeft: 16;
        paddingRight: 16;
        paddingBottom: 8;
        paddingTop: 8;
    }

    component#contentCard sprite#dropdown {
        img: { 
            borderWidth: 1,
            borderImg: #000,
            
            // NOTE: having an image here will size the sprite img: #0fff
        };
        // todo: image should be sized, when has no intrinsic size (like a bordered stuff...)
        //       imageW and imageH should work for sizing
        imageW: 44;
        imageH: 40;
        // canShrink: false;
        desiredW: 44;
        desiredH: 40;
        boxAlign: @center; // otherwise baseLine align will be used (try it out)
        marginLeft: 8;
    }
    
    component#contentCard sprite#dropdown > sprite#chevronIcon {
        img: "chevron_down.svg";
        imageW: 18;
        imageH: 18;
        w: 100%;
        h: 100%;
        align: @center;
        valign: @center;
        transition: @transformRotate, 300ms;
    }
    
    component#contentCard sprite#dropdown:checked > sprite#chevronIcon {
        transformRotate: 180;
    }
    
    sprite#cardHeader {
        boxAlign: @stretch; // full width inside a vbox
        desiredH: 88;       // from the design
        
        overflow: @hidden;
        zoom: "ASPECT_FILL";
        align: @center;
        valign: @center;
    }    
    
    component#contentCard #cardHeader > #headerTags {
        top: 8;
        left: 8;
        right: 8;
    }
    
    .h2 {
        fontWeight: @bold;
        fontSize: 16;
    }
    hbox#titleBox {
        marginBottom: 6;
    }
    component#contentCard text#title {
        boxAlign: @top;
    }
    
    component#contentCard text#description {
        marginTop: 4;
    }
    
    component#contentCard vbox#details {
        paddingTop: 8;
        paddingBottom: 8;
    }
    
    component#contentCard #footer {
        // footer has no left padding, as icon buttons shouldn't be padded, other kinds of elements should be placed with a left margin
        paddingRight: 16;
    }
    
    component#contentCard #footer .cardFooter.leftMargin {
        marginLeft: 16;
    }
    
    // normal buittons have a margin of 8, icon like-buttons, have a margin of 4
    component#contentCard #footer button {
        marginTop: 8;
        marginBottom: 8;
    }
    
    // iconButton is a special clickable sprite, with a well known tap area, and a sized svg icon in the middle
    sprite.iconButton {
        desiredW: 56;
        desiredH: 48;
        imageH:  22;
        align: @center;
        valign: @center;
        touchEvents: @box; // other value is @content
    }
    
    sprite.iconButton:disabled {
        opacity: 0.2;
    }
    
    component#contentCard #footer sprite.iconButton {
        marginTop: 4;
        marginBottom: 4;
    }
    
    sprite.divider {
        top: 0;
        left: 0;
        h: 1;
        w: 100%;
        position: @absolute;
        img: const(colors.backgroundGrey);
    }

    component#contentCard sprite.bg.card {
        img={ img:#fff, borderRadius:12 }
    }
}