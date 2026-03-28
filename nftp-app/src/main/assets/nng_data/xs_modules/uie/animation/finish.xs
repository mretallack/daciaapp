import { curry, reduce } from "system://functional"

decorator @curry { @wrap(curry) }

*children(parent) {
    for(let c = parent.firstChild; c; c = c.nextSibling)
        yield c;
}

@curry
any(func, iterable) {
    reduce((a,b) => {b=func(b); if(b) return @reduced, b; return b }, undef, iterable )
}
export anyAnimInChildList(children) {
    return (parent, target) => 
                (!target || parent != target.parent) && // if there is a target check if 
                any(Animation.getNumAnimsFor(?), children);
}
export anyAnimInChildren(...children) { anyAnimInChildList(children); }

export anyAnimInCurrentChildren(parent) {
    anyAnimInChildList([...children(parent)]);
}

export hasAnimOnDirectChild(parent, target) {
    if (target && parent != target.parent) // if there is a target check if 
        return true;
    for(let c = parent.firstChild; c; c = c.nextSibling) {
        if (Animation.getNumAnimsFor(c))
            return true;
    }
    return false;
}

export allAnimFinishedOfCurrentChildren(parent) {
    allChildAnimFinished(parent, anyAnimInCurrentChildren(parent))
}

export allChildAnimFinished(parent, hasAnim = hasAnimOnDirectChild) {
    return new Promise(async (fullfilled,r)=> {
        await 0; // ensure that animation are checked after class, pseudo class related expression can refrehs
        parent.window.updateStyles();
        if (!hasAnim(parent, undef))
        {
            fullfilled();
            return;
        }
        let reg;
        reg = weak(parent.addEventListener(@animationFinished, _ => {
            if (!event.target || hasAnim(parent, event.target) )
                return;
            parent.removeEventListener(@animationFinished, reg);
            reg = undef;
            fullfilled();
        }));
    });

}
