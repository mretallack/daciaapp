import * as httpClient from "system://nng.networking.http.Client"
import {fmt} from "fmt/formatProvider.xs"
import {failure} from "system://core"
import {encode as encodeBase64} from "system://web.Base64"


/// @param start start Date
/// @param end end Date
/// @param {dict} keys apiKey and secretKey
/// @return buffer or failure
export async exportInterval(start, end, keys) {
    const request = httpClient.createRequest( "https://amplitude.com/api/2/export" );
    request.method = nng.networking.http.Method.GET;
    const credential = "Basic " + encodeBase64(`${keys.apiKey}:${keys.secretKey}`);
    request.headers.set("Authorization", credential);
    request.headers.set("Accept", "application/zip");
    request.queryParameters.start = fmt("{:datetime|%yyyy%MM%DDT%HH}", start);
    request.queryParameters.end   = fmt("{:datetime|%yyyy%MM%DDT%HH}", end);

    const response = await request.fetch();
    if (response.status != 200)
        return failure(response.statusText);
    return response.body;
}
