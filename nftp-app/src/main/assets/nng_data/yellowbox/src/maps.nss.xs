import {@registerStyle} from "uie/styles.xs"

@registerStyle
style maps { 
    button sprite.icon {
        imageH: const(iconSize.normal);
        marginRight: 20;
        params: ({
            color: (colors.mapIcon)
        });
    }
    
    sprite.icon.downloadToPhone {
        img: "download_to_phone.svg";
    }
      
    sprite.chevron.up {
        img: "chevron_down.svg";
        marginLeft: 5;
        marginRight: 5;
        transformRotate: 180;
    }

    sprite.sortOpaque {
        opacity: 50%;
    }
    
    progress.downloadToPhone {
        desiredH: 5;
	    progressImg: const(colors.downloadProgress);
    }
    
    group.download.area{
        valign: @center;
        marginLeft: const(paddings.large);
    }

    *:checked sprite.chevron.up {
        transformRotate: 0;
    }
    
    #transferElements {
        position: @absolute;
        bottom: 100%;
        left: const(paddings.extraLarge);
        right: const(paddings.extraLarge); // like padding
        // todo: can't see shadow...
        boxShadow:  ( 4, -4, 8, 6, #333, @shallow );       
    }
    
    #transferElements > listView {
        // NOTE: max height: 320
        desiredH: 320;
    }
    
    #tTransferEntry {
        valign: @center;               
    }

    #tTransferEntry:disabled {
        opacity: 0.2;         
    }    
    
    #tOwnedPackage > contentCard, #tOnPhoneCard > contentCard, #tOnCarCard > contentCard {
        marginBottom: const( paddings.main );
    }
   
    group.mapsTagsPadding{
        paddingTop: const( paddings.small );
    }

    text.notEnoughSpace{
        paddingTop: const( paddings.xs);
        paddingBottom: const( paddings.main);
    }

    group.onCarHeader{
        marginBottom: const( paddings.main );
    }
}