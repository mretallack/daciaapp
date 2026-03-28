import {xor,and} from "system://math"
import {Uint32Array, Uint8Array, Uint16Array, DataReader} from "system://core.types"
import { open } from "system://fs"
import { blowfish} from "system://crypto"

export async decodeDevNng(filePath) {
    const f = await open(filePath);
    const buf = Uint8Array(4096);
    const numRead = await f.read(buf);
	numRead && decodeDevNngFrom(buf.subarray(0,numRead));
}

class DevNng
{
    r;
    numDevIds;
    defSwid;
    fflags;
    swids=[];
    id;
    vin;
    osInfo;
    factorySKU;
    appcid;
    igoVersion;
    fudMs;
    sku;
    cipher() {
        blowfish(Uint8Array.view(this.r, 0, 16));
    }
    // r[32..48] platform code hash/ MapInfoMd5 such as EF:F4...
}
decrypt(dev,r, pos, endPos) {
    pos ??= r.pos;
    endPos ??=pos+16;
    dev.cipher().decrypt(r.subarray(pos, endPos)) |> DataReader.view(^);
}

export decodeDevNngFrom(buf) {
    const r = DataReader.view(buf);
    const numDevIds = r[128];
    const numSdIds = r[129];
    const dev = DevNng { r = r; numDevIds = numDevIds; appcid=r.u32At(92)};
    dev.defSwid = decodeSwid(r, 64);
    dev.fudMs = decrypt(dev, r, 96).u32();
    r.pos = 112;
    dev.igoVersion = readIdOfLen(dev, r, 16);
    r.pos = addSwidBlock(dev.swids, r[128], r, 130);
    r.pos = addSwidBlock(dev.swids, r[129], r, r.pos);
    // r
    // TODO add GetPlatformSwid to swid: MapInfoMd5 -> base32
    dev.fflags = r.u32();
    dev.id = readId(dev,r);
    dev.vin = readId(dev,r);
    dev.osInfo = readId(dev,r);
    dev.sku = decrypt(dev, r).u32();
    /* hashcodes (at least one)  and finally brand md5 */
    dev
}

addSwidBlock(swids, n, r, pos) {
    for(;n >0 && r.byteLength - pos > 16; --n) {
        swids.push(decodeSwid(r, pos));
        pos +=16;
    }
    return pos;
}

decodeSwid(r, pos) {
    for(let p = pos; p < pos+16; ++p) {
        r[p] = xor(r[p], p - pos + 0x83);
    }
    let s = r.substr(pos, 16);
    for(let i=12;i>=0; i-=4)
        s = s.substr(i,0, "-");
    s = "CK" + s;
}

roundLen(l) {
    const r = l %16;
    r ? l + 16-r : l;
}
readId(dev, r) {
    readIdOfLen(dev, r, r.u16())
}
readIdOfLen(dev, r, l) {
    const rl = roundLen(l);
    const res = dev.cipher().decrypt(r.subarray(r.pos, r.pos + rl));
    r.pos += rl;
    res.substr(0,l);
}

const TBase32 = "49EKRX3AGPW2BJT1CNZ8Q6M5LD0Y7HVF";
