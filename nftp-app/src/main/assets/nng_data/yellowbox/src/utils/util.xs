import {CancellationTokenSource, observe} from "system://core.observe"
import { dispose, typeof } from "system://core"
import { @disposeNull } from "core/dispose.xs"
import * as os from "system://os"
import { startActivity, ACTION_VIEW } from "android://intents"?
import { from } from "system://list.transforms"
import { filter, find } from "system://itertools";
import {richFmt} from "fmt/formatProvider.xs"
import {UIApplication, NSURL} from "uie/ios/UiKit.xs"
import {Reader, xmlNode} from "core/web/xml.xs"

export async raceAndCancel( promise, delay ) {
	const ts = new CancellationTokenSource();
	const win = await.race( promise, Chrono.delay( delay, ts.token ) );
	ts.cancel();
	return win;
}

export async condition(obsFunc) {
    return new Promise(res =>
        observe(obsFunc).subscribe((s, cond) => {
            if(cond) {
                s.cancel();
                res(cond);
                dispose(s);
            }
        })
    );
}

export async runUntil( promise, maxDelay, minDelay=0s) {
	const ts = new CancellationTokenSource();
	const win = Promise.race([promise(ts.token), Chrono.delay( maxDelay, ts.token )]);
    const res = await Promise.all([win, Chrono.delay(minDelay)]);
	ts.cancel();
	return res[0];
}

export formatSize(size) {
	if ( size >= (1024*1024*1024)) return "" + (int(size/(1024.0*1024.0*1024.0)*100))/100.0 + " GB";
	else if ( size >= (1024*1024)) return "" + (int(size/(1024.0*1024.0)*10))/10.0 + " MB";
	else return "" + int(size/1024.0) + " KB";
}

export stripExt(str) {
	const p = str.lastIndexOf('.');
	p < 0 ? str : str.substring(0,p);
}

export splitFileAndExt(str) {
	const p = str.lastIndexOf('.');
	if (p < 0) return str, "";
	return str.substring(0,p), str.substring(p+1);
}

export openUrl(url, options) {
	if (os.platform == "win32") {
		os.open(url);
	} else if (os.platform == "android"){
		startActivity(#{
			action: ACTION_VIEW,
			data: url
		})
	} else if (os.platform == "ios") {
		// calling openURL:options:witCompletionHandler:
		UIApplication.sharedApplication.openURL_options(NSURL.initWithString(url), undef)
	} else {
		console.log(`Please open the following link in your browser ${options?.message ?? ""}`);
		console.log(url);
	}
}

export fmtTuple(text) {
    typeof(text) == @tuple ? richFmt(...text) : text
}

export transformOnChange( options ) {
	return new OnChangeTransformer( options );
}

export contentGrouping( contents, prios, resultFunc ){
	let groupingTerm;
	for( const firstMatch in prios ){
		if( find( contents ?? [], e => {e?.contentTypeCode == firstMatch }) ){
			groupingTerm = firstMatch;
			break;
		}
	}
	const retVal = ??resultFunc( contents, groupingTerm );
	return retVal;
}

export eliminateHtmlTags( fromText = "" ) {
	const r = Reader( fromText );
	let res = "";
	do {
		if ( let t = r.text(@preserve))
    		res += t; 
	} while( r.toEndTagSkipText() || r.toNextNode());
	return res;
}

class OnChangeTransformer {
	@disposeNull #inputList;
	@disposeNull #sorterFn;
	@disposeNull #filterFn;
	@dispose #listSubscription;
	@disposeNull list; 

	/**
	* inputList{ iterable } the list that will be transformed
	* observeFn{ function } the method of wich return value can be observed to trigger the transform
	* sorterFn{ function } the sorter function the inputList will be sorted according to it
	* filterFn{ function } the filter function the inputList will be filtered according to it
	*/
	constructor( options ) {
		this.#inputList = options.inputList;
		this.#sorterFn = options?.sorterFn;
		this.#filterFn = options?.filterFn;
		this.#listSubscription = observe( options.observeFn ).subscribe( s => {
			this.#makelist();
		});
	}

	#makelist() {
		let lst = this.#inputList;
		if ( this.#filterFn )
			lst = filter( this.#inputList, this.#filterFn ).toArray();

		if ( this.#sorterFn )
			lst = lst.toSorted( ...Iter.seq( this.#sorterFn) );

		this.list = lst;
	}

	// Changes the sorter function and applies it
	changeSorter( sorterFn ) {
		this.#sorterFn = sorterFn;
		this.#makelist();
	}

	// Changes the filter function and applies it
	changeFilter( filterFn ){
		this.#filterFn = filterFn;
		this.#makelist();
	}
}

export class DelayedExecutor {
    #value;
    #t;
    #callback;
    constructor(delay, callback, value) {
        this.#value = value;
        this.#t = Chrono.schedule(delay, ()=>callback(this.#value));
    }
    get value() { this.#value; }
    set value(newValue) { 
        this.#value = newValue;
        this.#t.restart();
    }
}

export class Progress {
	// title = "";
	value = 0;
	total = 0;
	text = "";
}

export class TimerProgress {
	#timer;
	#progress;

	/// Timer utility which continuously increase the `progress` to the `total` value.\
	/// using const t = new TimerProgress(progress, "", 10s);
	/// @param {dict} progress The Progress
	/// @param {Unit} total Total time in Unit value
	constructor(progress, total) {
		const fine = 2.0; // hardcoded. Count twice in every seconds
		const delay = 1s / fine;
		this.#progress = progress;
		this.#progress.value = 0L;
		this.#progress.total = total.reduce((r, v,u)=> v) * fine;
		this.#timer = Chrono.schedule(delay, delay, ()=>{ 
			if (this.#progress.value < this.#progress.total - 1) // never reach 100%, dispose will set completed state
				++this.#progress.value; 
		});
	}

	[Symbol.dispose]() {
		this.#timer.stop();
		this.#progress.value = this.#progress.total;
	}
}
