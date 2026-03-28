import {typeByName}  from "android://reflect"?
import {random, or, and} from "system://math"
import {sha1} from "system://digest"
import {Uint8Array} from "system://core.types"
import {fmt} from "fmt/formatProvider.xs"

generateUUID() {
    let d = Uiml.date.now();
    let d2 = 0; // microseconds not supported
    let r;
    let uuid = "";
    for (const c in "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx") {
        if (c != "x" && c != "y"){
            uuid += c;
            continue;
        }
        r = random(16);
        if(d > 0) {
            //Use timestamp until depleted
            r =  or((d + r) % 16, 0);
            d = d / 16; // don't need floor, due to d > 0
        } else {
            //Use microseconds since page-load if supported
            r = or((d2 + r) % 16, 0);
            //  microseconds not supported
            // d2 = int64(floor(d2 / 16.0));
        }
        uuid += fmt("{:01x}", (c == "x" ? r : (or(and(r, 0x3), 0x8))));
    }
    return uuid;
}

// uuid type5
export nameToUUID(name) {
	const u32 = sha1(name);
	const u8 = Uint8Array.view(u32, 0, 16);
	//set high-nibble to 5 to indicate type 5
	u8[6] = and(u8[6], 0x0F);
	u8[6] = or(u8[6], 0x50);
	//set upper two bits to "10"
	u8[8] = and(u8[8], 0x3F);
	u8[8] = or(u8[8], 0x80);

	const p1 = Uint8Array.view(u8, 0, 4).hexstr();
	const p2 = Uint8Array.view(u8, 4, 6).hexstr();
	const p3 = Uint8Array.view(u8, 6, 8).hexstr();
	const p4 = Uint8Array.view(u8, 8, 10).hexstr();
	const p5 = Uint8Array.view(u8, 10, 16).hexstr();
	return `${p1}-${p2}-${p3}-${p4}-${p5}`;
}

export randomUUID() {
	return typeByName?.("java.util.UUID")(67L, 76L).randomUUID().toString() ?? generateUUID();
}
