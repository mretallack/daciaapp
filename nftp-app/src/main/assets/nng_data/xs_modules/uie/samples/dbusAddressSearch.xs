import { create as createNDSProvider } from "system://nng.places.OnboardProviderFactory"
import { create as createHEREProvider } from "ifw://nng.places.HereProviderFactory"
import * as NavigationSystemProvider from "ifw://nng.navigation_system.Provider"
import * as regionalManager from "system://nng.RegionalManager"

import { makeInterfaceT, ObjectWrapper, makeInterface } from "dbus/dbusCommunicator.xs"
import {map} from "system://itertools"
import {observe, ChangeObserver} from "system://core.observe"
import {firstValueFrom, filter as filteredObserve} from "core/observe.xs"
import {dispose} from "system://core"
import * as Async from "xtest/AsyncTesting.xs"

enum SearchProviders {
    NDS = 0,
    Here = 1
}

const providers = [ createNDSProvider(), createHEREProvider()];

async getCurrentPosition() {
    let ctrl = NavigationSystemProvider.get();
    await ctrl.start();
    let positionStack = ctrl.navigationInformation.systemPositionStack;
    return positionStack.lastValidPosition;
}

const languageStrategy = regionalManager.createDefaultLanguageStrategy();
const language = regionalManager.uiLanguage;

startSearch( provider, filter, center, maxResults = 20 ){
	let query = {
		filter: filter ?? "",
		center,
		maxResults,
		languageStrategy,
		searchLanguages: [ language ],
	};
	provider.poiSearch( query );
}


export class AddressSearch {
    static interface = makeInterfaceT[{
        name: "com.nng.navi.address.Search",
        methods : {
            Start: ("provider:byte, filter:string, listener:(busAddr:string, path:string)", "uint"), 
        }
    }];
    
    #bus;
    
    constructor(dbusConnection) {
        this.#bus = weak(dbusConnection);
    }
    
    Start(provider, filter, listener) {
        console.log("Searching for: ", filter);
        console.log(`Updating '${listener[1]}' with results`);
        // todo: search center later
        const listener = new SearchListener(this.#bus, listener[0], listener[1]);
        return this.launch(providers[provider], filter, listener);
    }
    
    async launch(provider, filter, listener) {
        const currentPos = await getCurrentPosition();
        const res =  startSearch(provider, filter, currentPos);
        
        const resultsObserver = new ChangeObserver( _=> {
            listener.OnResults(res.results);
        });
        resultsObserver.observe(res.results);
        // todo: later could use: 
        // await observeChanges(()=> res.state) |> filteredObserve(status => status == 2, ^)  |> firstValueFrom(^);
        await Async.condition(()=> res.state == 2);
        
        listener.OnComplete();
        return res.results.length;
    }
}

const SearchListenerInterface = {
    name: "com.nng.navi.address.search.Listener",
    methods: {
        OnResults:  ("results:(name:string, distance:double, pos:(lat:double, lon:double))[]", ""),
        OnComplete: ("", "")
    }
};

class SearchListener {
    listener;
    constructor(bus, addr, path) {
        this.listener = bus.createProxyObject(addr, path, makeInterface(SearchListenerInterface));
    }
    
    OnResults(results) { this.listener.OnResults(map(results, res => (res.name, res.distance, (res.position.latitude, res.position.longitude)))) }
    OnComplete() { this.listener.OnComplete() }
}


