import { dispose, disposeSeq, values, hasProp, tryDispose } from "system://core"
import { DisposeSet } from "system://core.types"
import { reverse, filter } from "system://itertools"

// general dispose decorators
//dispose all elements of a sequence or a dictionary
export decorator @disposeContainer() { 
	@dispose( disposeSeq ) 
} 

//dispose all elements of a sequence in reverse order
export decorator @disposeStack() {
    @dispose(s => disposeSeq(reverse(s)))
}

//dispose all disposable elements of a sequence
export decorator @tryDisposeContainer() { 
	@dispose( s => { if (s) {
		for(let e in s) { 
			e?.[Symbol.dispose]?.();
		} 
		s.clear(); 
	}})
}

//dispose all disposable elements of a dictionary
export decorator @tryDisposeDict() {
	@dispose( s => { 
		if (s) {
			disposeSeq( filter( values( s ), e => { e && ??hasProp( e, Symbol.dispose ) } ) );
			s.clear();
		}
	})
} 

//calls only the default resource=undef 
export decorator @disposeNull() {
	@dispose( _=> {} )
}
@dispose
DisposeSet objectsToDispose;

export disposeOnUnload( obj ){
	objectsToDispose.add( obj );
}

export decorator @disposeOnUnload() {
	@register( disposeOnUnload )
}

export decorator @disposeIfDisposable() {
	@dispose( tryDispose )
} 