import {CancellationTokenSource} from "system://core.observe"
import { list, Map } from "system://core.types"
import { @tryDisposeContainer } from "core/dispose.xs"
import { @registerStyle } from "uie/styles.xs"
import {mediaQuery} from "~/src/mediaQuery.xs"

export class Toast {
	id;
	text;
	timeout = 2000;
	#action;
	#cTokenSource;
    #handler;

    constructor( text="", handler = toastHandler ) {
        this.#handler = handler;
        this.text = text;
    }

	setId( id ) {
		this.id = id;
		return this;
	}

	addAction( action ){
		this.#action = action;
		return this;
	}

	addTimeout( timeout ){
		this.timeout = timeout;
		return this;
	}

	show(){
		this.#handler.show( this, this.#action );
        return;
	}
}

state stToast {
	use = frToast;
}

export controller toastController;

// Export only for testing
export class ToastHandler {
	maxToasts = 3; // TODO: config or param
	@tryDisposeContainer toastQueue = [];
	@dispose(
            m => {
                for ( let info in m.values )
                    info?.cTokenSource?.cancel();
        }) toastHelper = new Map;
	@tryDisposeContainer visibleToasts = new list;
	#nextId = 1;
    #controller;

    constructor( controller ) {
        this.#controller = controller ?? toastController;
    }

	#setIdIfNeeded(toast) {
		if (toast.id) return;
		toast.id = `toast${this.#nextId++}`
	}

	show( toast, action ) {
		this.#setIdIfNeeded(toast);
		let alreadyIn = this.visibleToasts.find( t=> t.id == toast.id ) || this.toastQueue.find( t=> t.id == toast.id );

		if ( alreadyIn )
			return;

		if ( !this.visibleToasts.length )
			this.#controller.next( new stToast );

		if ( this.visibleToasts.length < this.maxToasts ) {
			this.visibleToasts.push( toast );
			this.toastHelper.set( toast.id, { state: @showing, cTokenSource: undef, action } );
		}
		else {
			this.toastQueue.push( toast );
			this.toastHelper.set( toast.id, { state: @none, cTokenSource: undef, action } );
		}
	}

	hide( toast ) {
		let toastInfo = this.toastHelper.get( toast.id ) ?? undef;
		toastInfo?.cTokenSource?.cancel();
		??toastInfo.action();
        if ( toastInfo )
		    this.toastHelper.set( toast.id, { state: @hiding, cTokenSource: undef, action: undef } );
	}

	async startTimeoutLogic( toast, action ) {
		let cTokenSource = new CancellationTokenSource;
		this.toastHelper.set( toast.id, { state: @shown, cTokenSource: cTokenSource, action } );
		
		await Chrono.delay( toast.timeout, cTokenSource.token);
		if (!cTokenSource.token.canceled)
			this.hide( toast );
	}

	animFinished( toast, idx ) {
		let toastInfo = this.toastHelper.get( toast.id ) ?? undef;

		// Showing
		if (( toastInfo.state ?? @none ) == @showing ) {
			if ( toast.timeout ) {
				this.startTimeoutLogic( toast, toastInfo.action );
			} else {
				this.toastHelper.set( toast.id, { state: @shown, cTokenSource: undef, action: toastInfo.action } );
			}
		// Hiding
		} elsif (( toastInfo.state ?? @none ) == @hiding ) {
			let wasVisible = this.visibleToasts.find( t=> t.id == toast.id );
			let queueIndex = this.toastQueue.findIndex( t=> t.id == toast.id );

			if ( wasVisible ) {
				this.visibleToasts.remove( idx );
				if (this.toastQueue.length) {
					let newToast = this.toastQueue.shift();
					this.show( newToast );
				}
			} elsif( queueIndex > -1 ) {
				this.toastQueue.remove( queueIndex );
			}
			this.toastHelper.set( toast.id, { state: @none, cTokenSource: undef, action: undef } );

			if ( !this.visibleToasts.length )
				this.#controller.prev();
		// Must not happen, but handling this case
		} else {
			this.toastHelper.set( toast.id, { state: @none, cTokenSource: undef, action: undef } );
		}
	}
}

@dispose 
export ToastHandler toastHandler;

<template t_Toast class=( @flexible, @vertical, toastHandler.toastHelper.get( item.id ).state ?? @none ) onRelease(){ toastHandler.hide( item ) } onAnimationFinished() { toastHandler.animFinished( item, index ); }>
	<sprite class=bg, toast/>
	<text class=toast text=(item.text ?? "")/>
</template>

<fragment frToast class=(@flexible, @vertical, transitionState) paddingTop=(mediaQuery.headerPadding) paddingBottom=(mediaQuery.footerPadding) >
	 <lister model=( toastHandler.visibleToasts ) template=t_Toast />
</fragment>

@registerStyle
style toast {
	@declare {
        toastBg: #{ borderWidth: 2, borderImg: #585858, img: #F2F2F2 };
        toastShadow:  ( 0, 4, 8, 6, #B8B8B8, @shallow );               
		toastAnimTime: 400ms;
		toastH: 60;
		toastPadding: 12;
		toastTextPadding: 18;
		toastBottom: 90;
	}	

	#frToast, #frLabToast {
		paddingLeft: toastPadding;
		paddingRight: toastPadding;
		left: toastPadding;
		right: toastPadding;
		useVisibleArea: 1;
		valign: @bottom;
        bottom: toastBottom;
	}

	template#t_Toast{
		transition:[[ @opacity, 0.5s ]];
		marginBottom: toastPadding;
	}

	template#t_Toast.hiding, template#t_Toast.none{
		opacity: 0;
	}

	template#t_Toast.shown, template#t_Toast.showing {
		opacity: 1;
	}

	text.toast {
		font: const(fontType.read);
		fontSize: const(fontSizes.small);
		color: const(colors.black);
		align: @center;
        paddingTop: toastTextPadding;
		paddingBottom: toastTextPadding;
	}

	sprite.bg.toast {
		img: toastBg;
        boxShadow: ( toastShadow );
    }
}
