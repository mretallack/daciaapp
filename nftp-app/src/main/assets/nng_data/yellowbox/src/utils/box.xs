import {getLicenses} from "app://yellowbox.updateApi"
import { ensureParentDirSync, writeFileSync, readFileSync } from "system://fs"
import {walkSync} from "core/ioUtils.xs"
import {defaultExts} from "../toolbox/connections.xs"
import { decode as decodeBase64 } from "system://web.Base64"
import {swid} from "system://crypto"
import env from "system://app.env"
import {stripExt} from "./util.xs"
import {Message, responseFailString, queryChecksum, ChecksumMethod, PushOptions, queryFilesFlat} from "core/nftp.xs"
import { i18n } from "system://i18n"
import * as fs from "system://fs";
import {downloadDirectory} from "app://downloadManager"

const licenseFolder = `${downloadDirectory}/license`;
export const backupFolder = `${downloadDirectory}/backup`;

export object mockFolders {
    usableSpace = undef;
}

export getUsableSpace() {
    mockFolders.usableSpace || fs.space(downloadDirectory).available;
}

export saveLicenseToBox(device, fileName, buffer) {
    const path = `${licenseFolder}/${device.swid}/${fileName}`;
    console.log("Save license file:", path);
    ensureParentDirSync(path);
    writeFileSync(path, buffer);
}

export getLicensesFromBox(device) {
    const licenses = [];
    const swids = [];
    const path = `${licenseFolder}/${device.swid}`;
    for (const item in walkSync(path)) {
        if (item.name.endsWith(defaultExts.license)) {
            const content = readFileSync(item.path);
            licenses.push({name: item.name, content, path: item.path, size: item.size});
            let licSwid = getSwidForLicense( item.name );
            if ( licSwid )
                swids.push( licSwid );
        }
    }
    return licenses, swids;
}

export async downloadLicenses(device) {
    const licenses = await getLicenses(device);
    if ( licenses )
        for (const lic in licenses )
            saveLicenseToBox(device, lic.fileName, decodeBase64(lic.binaryLicense, @asBuffer));
}

getSwidForLicense( licName ){
    let name = ?? stripExt(licName);
    let toCrypt;
    if ( name ){
        let parts = name.split("_");
        if ( ??parts[-1] && parts[-1].startsWith("i") && parts[-1].indexOf("@") != -1 )
            toCrypt = parts[-1];
        else if ( ??parts[-2] && parts[-2].startsWith("i") )
            toCrypt = parts[-2] + "@" + parts[-1];
        if ( toCrypt )
            return "CK-" + swid(toCrypt);
    }
    return;
}

// TODO: split into two part
/// Side effect: refresh `item.md5` and `item.mtimeMs`
export async compareChecksum(messenger, item, destPath) {
    const localHash = item?.md5 ?? messenger.conn.md5(item.path).then(res => res.hexstr());
    const targetHash = queryChecksum(messenger, destPath, ChecksumMethod.MD5).then(res => res.hexstr()??res);
    let files = item?.mtimeMs ? undef : queryFilesFlat(messenger, destPath, {fields: (@name, @size, @isFile, @mtimeMs)});
    const res = await.allSettled(localHash, targetHash, files);
    if (res[0].status != @fulfilled || res[1].status != @fulfilled || res[2].status != @fulfilled)
        return false;
    item.md5 = res[0].value;
    if (res[2].value)
        item.mtimeMs = res[2].value[0].mtimeMs;
    return res[0].value == res[1].value;
}

export const tagMapping = {
    @new: i18n`New`,
    @free: i18n`Free`,
    @inBasket: i18n`In Basket`,
    @purchased: i18n`Owned`,
    @osm: i18n`NNG.Maps`,
    @discount: i18n`Discount!`,
    @update: i18n`Update!`
}; 

