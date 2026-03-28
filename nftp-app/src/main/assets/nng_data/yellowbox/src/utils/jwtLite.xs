import JSON from "system://web.JSON"
import {decode} from "system://web.Base64"
import {date} from "system://core.types"
// This module implements basic JWT functionality for clients (users of tokens)
// it can decode the payload, check expiration and so on

export decodePayload(token) {
    const payloadStart = token.indexOf(".") + 1;
    const payloadEnd = token.indexOf(".", payloadStart);
    
    return JSON.parse(
        decode(token.substring(payloadStart, payloadEnd))
    );
}

/// Chcks if a jwt is already expired (when current date is past, or will soon pass in deltaSeconds
/// the time in the ext field)
/// @returns whether the token is expired or not
export checkExpired(jwtPayload, deltaSeconds = 5) {
    (jwtPayload.exp - deltaSeconds) * 1000L - date.now() < 0
}