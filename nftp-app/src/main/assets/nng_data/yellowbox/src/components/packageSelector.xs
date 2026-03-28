import * as iter from "system://itertools"
import {fmt} from "fmt/formatProvider.xs"
import { @registerStyle } from "uie/styles.xs";
import { i18n, translate } from "system://i18n"

// todo: use size formatter instead!
export formatSize(size) {
    if (size < 1024) {
        return fmt(i18n`{:d} B`, size)    
    } else if (size < 1000 * 1024) { // less than 1000 KB
        return fmt(i18n`{:d} KB`, size / 1024)    
    } else if (size < 1024 * 1024 * 1000) { // less than 1000 MB
        return fmt(i18n`{:d} MB`, size / (1024 * 1024))
    } else 
        return fmt(i18n`{:.1f} GB`, size / (1024.0 * 1024 * 1024))
}

displaySize(item) {
    return item.downloaded? item.size : (item.failed ? item.downloadedSize : (item.size-item.downloadedSize));
}

<template tSelectVariant class=flexible, horizontal onRelease() { param.itemSelected(item) } 
          checked=(item.selected || disabledAndSelected)
          enable=(!disabledAndSelected && !item.failed) >
    own {
        let disabledAndSelected = (item.downloading || item.queued || (item.mandatory && !item.failed) || (param.selectTransferred && item.transferred ) || (param.selectDownloaded && item.downloaded));
    }
    <sprite checkbox />
    <text name text=(translate(item.name))/>
    <sprite status class=(item.transferred ? @oncar : (item.downloaded ? @onphone : @partial)) visible=(item.transferred || item.downloaded || item.failed) />
    <text size text=( formatSize(displaySize(item)) ) />
</template>

export <template tSelectForRemove extends=tSelectVariant
        checked=(item.selected)
        enable=(!item.mandatory) >
</template>

export <component packageSelector class=flexible,vertical defaults={ entryTemplate: tSelectVariant}>
    own {
        export let packageView;
        export let selectTransferred = false;
        export let selectDownloaded = false;
        export let keepMandatory = false;
        let allSelected := packageView?.areAllEntriesSelected({ skipDownloaded: selectDownloaded, skipTransferred: selectTransferred }); 
        let sumSize := packageView ? iter.reduce(packageView.entries, reduceSize, 0L) : 0;
        let showSelectAll := packageView?.entries.size > 1 && sumSize > 0;
        
        reduceSize(acc, item) {
            if (item.downloading || (item.downloaded && selectDownloaded)) return acc;
            if (item.transferred && selectTransferred) return acc;
            if (item.failed && selectTransferred) return acc;
            return acc + displaySize(item);
        };
                
        itemSelected(item) {
            item.selected = invert(item.selected);
            allSelected = packageView.areAllEntriesSelected({ skipDownloaded: selectDownloaded, skipTransferred: selectTransferred, skipMandatory: keepMandatory });
            if (keepMandatory) packageView.selectMandatory(allSelected);
        }
        
        changeAllSelected() {
            invert(allSelected);
            if (allSelected) {
                packageView.selectAll({ skipDownloaded: selectDownloaded, skipTransferred: selectTransferred })
            } else packageView.deselectAll({ deselectMandatory: keepMandatory })
        }
    }
    <hbox selectAll checked=(allSelected) onRelease() { changeAllSelected() } visible=( showSelectAll ) >
        <sprite checkbox />
        <text name text=i18n`Select all`/>
        <text size text=(formatSize(sumSize))/> 
    </hbox>
    <sprite class=itemDivider visible=( showSelectAll )/>
    <lister model=(packageView.entries) template=(attributes.entryTemplate) param=({itemSelected: itemSelected, selectTransferred, selectDownloaded})/>
</component>

@registerStyle
style selectorStyles {
    template#tSelectVariant, #selectAll {
        fontSize: 16;
        font: const(fontType.read);
        marginTop: 3;
        marginBottom: 3;
    }
    
    template#tSelectVariant:disabled {
        opacity: 0.2;
    }
    template#tSelectVariant > *, #selectAll > * {
        boxAlign: @center;
        canShrink: false;
    }
    template#tSelectVariant > sprite#checkbox, #selectAll > sprite#checkbox {
        img: "checkbox.svg";
        desiredW: 18;
        desiredH: 18;
        marginRight: 8;
    }
    template#tSelectVariant:checked > sprite#checkbox, #selectAll:checked > sprite#checkbox {
        img: "checkbox-checked.svg";
    }
    
    template#tSelectVariant > text#name, #selectAll > text#name {
        marginRight:8;
        flex: 1;
        valign: @center;
    }
    
    template#tSelectVariant sprite#status {
        desiredH: 24;
        desiredW: 24;    
    }
    
    template#tSelectVariant sprite#status.oncar {
        img: "on_car.svg";
    }
    
    template#tSelectVariant sprite#status.onphone {
        img: "phone.svg";
    }

    template#tSelectVariant sprite#status.partial {
        img: "alert.svg";
    }
    
    template#tSelectVariant > text#size, #selectAll > text#size {
        fontWeight: @bold;
        marginLeft: 8;
        minW: 66;
        align: @right;
    }
    
    sprite.itemDivider {
        boxAlign: @stretch;
        desiredH: 1;
        w: 100%;
        img: const(colors.backgroundGrey);
        marginTop: 12;
        marginBottom: 12;
    }

    sprite.itemDivider.alert {
        img: const(colors.error);
        marginBottom: 0;
    }

} 