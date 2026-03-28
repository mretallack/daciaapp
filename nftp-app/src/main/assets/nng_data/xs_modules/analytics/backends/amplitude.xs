import * as httpClient from "system://nng.networking.http.Client"
import {map} from "core://functional"
import JSON from "system://web.JSON"

export class AmplitudeBackend {
    readonly needsNetwork = true;
    #apiKey;
    
    constructor(options) {
        this.#apiKey = options.apiKey;
    }
    
    async sendEvents(events) {
       	const request = httpClient.createRequest( "https://api2.amplitude.com/batch" );
        request.method = nng.networking.http.Method.POST;
        request.headers.set("Content-type", "application/json");
        request.headers.set("Accept", "*/*");   
        request.body = JSON.stringify({
            api_key: this.#apiKey,
            events: map(events, evt => #{
                user_id: evt.userId,
                app_version: evt.appVersion,
                device_id: evt.deviceId,
                event_type: evt.type,
                event_properties: evt.props,    
                time: evt.timestamp,
            })
        });
        const serverResponse = await request.fetch();
        console.log("Amplitude server response: ", serverResponse);
        // todo: should handle errors, details: https://www.docs.developers.amplitude.com/analytics/apis/batch-event-upload-api/#responses
        // 400 	Bad Request 	Invalid upload request. Read the error message to fix the request.
        // 413 	Payload Too Large 	Payload size is too big (request size exceeds 20MB). Split your events array payload in half and try again. The limit per batch is 2000 events.
        // 429 	Too Many Requests
    }
}