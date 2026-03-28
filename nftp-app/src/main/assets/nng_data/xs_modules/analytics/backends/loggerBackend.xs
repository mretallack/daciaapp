import JSON from "system://web.JSON"
export class LoggerBackend {
    readonly needsNetwork = false;
    
    constructor(options) {
        
    }
    
    sendEvents(events) {
        for (const evt in events) {
            const user = evt?.userId ? ` (user: ${evt.userId})` : '';
            const appVersion = evt?.appVersion ? ` (appVersion: ${evt.appVersion})` : '';
            const props = evt?.props ? JSON.stringify(evt.props) : '';
            console.log(`[event] ${evt.type}${user}${appVersion} ${props}`)
        }
    }
}