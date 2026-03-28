import {onLangChanged} from "system://i18n"

@preload
const langSubs = onLangChanged.subscribe(()=>{
    for(const w in screen.root.querySelectorAll("text"))
        w.reevaluateText(true);    
});