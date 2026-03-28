import { bundleChanges } from "system://core.observe"
import { entries, values, dispose, disposeSeq, failure } from "system://core"
import * as remoting from "system://remoting"
import { Set, Map } from "system://core.types"
import { EventEmitter } from "system://core.observe"
import { filter as filterObs, firstValueFrom} from "core://observe"
import {addresses} from "system://dns-sd"

export registerConnection(appId, idToken, details) {
    remoteConnections?.appConnected(appId, idToken, details);
}

export class Connections {
    @dispose
    #networkChangedId; // networkChanged event subscription

    @dispose(c => disposeSeq(values(c)))
    connections = odict {};
    appName; // name and info about our app
    appInfo;
    #pendingConnections = Map {}; // apps currently connecting
    #newConnectionObs = EventEmitter {};
    onNewConnection; // could be also `event { passEventArg=false }`  but EventEmitter better separates trigger end listener parts;

    // NOTE: current app's port can be read from sysconfig or specified in construction time
    //       maybe remoting could provide some info about configuration (listening_port, etc.)
    /// Create a new Connections object
    /// @param appName application name of this app
    /// @param info info about this app (in a dictionary form). format is not fixed
    constructor(appName, info = {}) {
        this.onNewConnection = this.#newConnectionObs.event;
        this.appName ??= appName;
        this.appInfo = info; 
    }

    get myAddress() { let port = remoting.ports(); `localhost:${port}` } // TODO: replace localhost
    
    /// @return an AppConnection if connection succeeds, otherwise the connection error
    async connectTo(host, appId) { 
        // if connection in progress return that promise, otherwise go on
        if (this.#pendingConnections.has(appId))
            return this.#pendingConnections.get(appId);
        if (??this.connections[appId]) // already connected
            return this.connections[appId];

        const connectionProc = this.#connectTo(host, appId);
        this.#pendingConnections.set(appId, connectionProc);
        let res = ??await connectionProc;
        this.#pendingConnections.remove(appId);
        return ??res;
    }

    async #connectTo(host, appId) {
        var s = ??await remoting.connectTo(host);
        if (??s) {
            this.#appConnectedImpl(appId, s);
            // register to the other side
            s.eval('System.import("uie/ipc/appConnection.xs").registerConnection($1, $2, $3)', this.appName, this/*token*/, this.appInfo);
            return this.connections[appId];
        } 
        return ??s; // error
    }

    /// @return @connected/@disconnected or @connecting
    getConnectionStatus(appId) {
        if (this.connections?.[appId]) return @connected;
        if (this.#pendingConnections.has(appId)) return  @connecting;
        return @disconnected;
    }

    appConnected(appName, identifierToken, details) {
        console.log("App connected to us:", appName, "identified by: ", identifierToken, "app info: ", details);
        let s = remoting.getPeerForObject(identifierToken);
        this.#appConnectedImpl(appName, s);
    }

    #appConnectedImpl(appName, s) {
        if (!this.#networkChangedId) {
            this.#networkChangedId = remoting.onNetworkChanged.subscribe(this.#onNetworkChanged.bind(this));
        }
        const conn = this.connections[appName] = new AppConnection(appName, s);
        this.#newConnectionObs.next(conn);
    }

    #onNetworkChanged(action, peer) {
        if (action == @disconnected) {
            for (let app in values(this.connections)) {
                if (app.session == peer) {
                    console.log(app.id, "disconnected!");
                    this.connections.remove(app.id);
                    dispose(app);
                }
            }
        }
    }

    removeConnection(app) {
        if (this.connections?.[app.id] == app)
            this.connections.remove(app.id);
    }

    getExistingConnection(appId) { return this.connections?.[appId]; }

    async appConnectsToUs(appId) {
        if (const con = this.connections?.[appId])
            return con;

        console.log(`Local addresses: `, addresses());
        console.log(`Waiting for ${appId} to connect to us on ${this.myAddress}...`);
        return this.onNewConnection
        |> filterObs(conn => conn.id==appId, ^)
        |> firstValueFrom(^);
    }

    dispose() {
        dispose(this);
    }
}

export Connections remoteConnections;

class AppConnection {
    id; 
    info = {}; // additional info about the app
    @dispose()
    readonly session;

    get connected() { this.session != undef; }

    constructor(appId, session) {
        this.id = appId;
        this.session = session;
    }

    [Symbol.dispose]() {
        remoteConnections.removeConnection(this);
    }

    disconnect() {
        dispose(this);
    }
    eval(...args) {
        if (!this.session)
            return Promise.reject(failure("not connected"));
        this.session.eval(...args); 
    }
    importModule(mod) {
        this.eval('System.import($1)', mod);
    }
}
