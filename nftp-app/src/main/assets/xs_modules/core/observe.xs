/// [module] core://observe
import { EventEmitter, eventAndEmitter, impl_obsmap, impl_obstimeout, Observable, subscriptionWithCancel, subscription, nullSubscription, connectable } from "system://core.observe"
import { dispose, failure, getFailObject, toFailure } from "system://core"
import { @curry, objOf, apply, tap, thunk, thunkify, pipe } from "core://functional"
export * from "system://core.observe";

const NotProvided = Symbol();

// return an observable that transforms observable `src`. Uses impl_obsmap to connect to source and handle subscription
// Each values pushed by src is given to function `f` whose return value is pushed towards subscribers.
// `f` might return iterDone in case it wants to complete
obsMapFunc(f, src) {
    objOf(@subscribe, impl_obsmap( f,src, ?)); // Note:doesn't use Observable since impl_obsmap will do the normalization
}

const Done = Util.iterDone();

@curry
export map(f, src) { obsMapFunc(f, src); }
@curry
export filter(f, src) { obsMapFunc( v => f(v) ? v : (:), src); }
@curry
export takeWhile(f, src) { obsMapFunc( v => f(v) ? v : Done, src); }
@curry
export do(f, src) { obsMapFunc( v => {f(v); v }, src); }
// will call the given getMapper upon subscription that should return a mapper. 
// The reason for indirection is that local variables might be needed
tooper(getMapper, src) { objOf(@subscribe, +> impl_obsmap(getMapper(), src, ^))}


@curry
export take(n,src) { tooper(() => { let i=n; return v => { --i; i> 0 ? v : (:v,Done) } }, src )}

impl_obsfrom(iter, listener, token) {
    for(let v in iter) {
        if (token?.cancelled) return;
        listener.next(v);
        if (token?.cancelled || listener?.closed) return;
    }
    if (token?.cancelled) return;
    listener.complete();
    return;
}
export fromGen(gen) { new Observable(+> impl_obsfrom(gen(), ^)); }
export fromIter(iter) { new Observable(impl_obsfrom(iter, ?)); }

impl_asyncobsfrom(iterable, listener, token /*todo*/) {
    async function doit(subs, listener) {
        for await (let v in iterable) {
            if (subs.cancelled) return;
            listener.next(v);
            if (subs.cancelled) return;
        }
        if (!subs.cancelled)
            listener.complete();
    }
    const subs = subscriptionWithCancel();
    doit(subs, listener);
    return subs;
}
export fromAsyncGen(gen) { new Observable(+> impl_asyncobsfrom(gen(), ^)); }
export fromAsync(iter) { new Observable(impl_asyncobsfrom(iter, ?)); }
// TODO: create from that dispatches to fromAsync/fromIter/fromSeq/fromObservable ...

export connect(connector, resetOnDisconnect=true) {
	let event;
    let disconnected = true;
	return objOf(@subscribe, function(...args) {
        if (event && !disconnected)
            return event.subscribe(...args);
		let observable = connector();
		const evt, emitter = eventAndEmitter();
		let r = ?? evt.subscribe(...args);
        if (!(r ?? false))
            return;
        event = evt;
        disconnected = false;
		let subs = observable.subscribe(emitter);
        if (resetOnDisconnect) {
            emitter.onNoMoreListeners = () => {
                subs?.unsubscribe();
                subs = undef;
                disconnected = true; // don't hold ref to event since it would cause circular refs. so we cannot unset it
            }
        }
        return r;
	});
}

export share(obs) { connectable( obs.subscribe(?) ); }

export first() { return src => obsMapFunc( v => { v, Util.iterDone() }, src); } // TODO: is it needed to circumvent reentrancy (obs triggers while dispatching first value)

export firstValueFrom(evt) {
    new Promise((resolve,reject) => {
        let sub;
        sub = evt.subscribe(arg => {
            dispose(sub);
            resolve(arg);
            }, reject, thunk(reject, ?? failure("Empty value")));
    });
}

export lastValueFrom(evt, val=NotProvided) {
    new Promise((resolve,reject) => {
        let sub;
        sub = evt.subscribe(arg => {
            let x = sub; // force sub to be referred
            val = arg;
            }, reject, () => {val != NotProvided ? resolve(val) : reject(failure("Empy value")); } );
    });
}

export timeout(delay, src) {
    objOf(@subscribe, impl_obstimeout( delay,src, ?));
}
// TODO: timeout, and handler with cancellation token

// converts an observable into an async iterator with internal queue of items
export async *asyncQueue(obs) {
    const buffer = [];
    let finished = undef;
    let resolve = undef; // a promise resolver when waiting for observable
    using (const subs = obs.subscribe({
        next(v) { buffer.push(v); resolve?.() },
        complete() { finished=true; resolve?.(); },
        error(e) { finished=toFailure(??e, "observable failed"); resolve?.(); }
    }));
    if (!buffer.size) {
        await new Promise(r => {resolve=r});
    }
    while(true) {
        yield* buffer;
        buffer.clear();
        if (finished != undef)
            return finished;
        await new Promise(r => {resolve=r});
    }
}

// return a new linked cancellation token that is cancelled after the given delay or when the given token is cancelled
export linkAndCancelAfter(delay, origToken)
{
   const tks = CancellationTokenSource(origToken);
   Chrono.delay(delay, origToken).then(()=>tks.cancel());
   return tks.token;
}