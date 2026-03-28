import * as aoa from "android://aoa"?
import * as nftp from "system://yellow.nftp"
import { openSync, ensureParentDirSync } from "system://fs"
import { DataWriter, DataReader, Date } from "system://core.types"
import {getFailObject, tryDispose, failure} from "system://core"
import { Message, NftpMessenger, ChecksumMethod, Response, procCheckSumMsg, responseFailString, responseDataOrFail, responseString, readValue, writeValue,
         queryInfo, Version as NftpVersion, queryFiles, getSmallFile, CtrlMessage, flowControl, queryFilesFlat, queryChecksum} from "core/nftp.xs"
import {bindProperty, unbindProperty} from "core://observe"
import * as Iter from "system://itertools"
import {decodeDevNngFrom} from "./db/deviceNng.xs"?
import { getDeviceBySwid, getLastConnectedDevice, checkHasDevice } from "./device.xs"?
import {saveLicenseToBox} from "../utils/box.xs"?
import {packageManager} from "./packages/packageModel.xs"?
import {mapFileToPath, defaultFileMapping} from "./fileMapping.xs"?
import {nftpHeader} from "~/src/appVersion.xs"?
import {trackEvent} from "analytics/analytics.xs"?
import {connect, listen} from "system://socket"
import {} from "./android/usbConnectionService.xs"
import {} from "./ios/usbConnectionKeepAlive.xs"
import * as os from "system://os"
import {showFailedToListen} from "../app.ui"?
import {SysError} from "system://fs"

const debugAoa = SysConfig.get("debug", "aoa");
export list aoaMessages[];

export const defaultExts = {
    map: ".fbl",
    poi: ".poi",
    speedcam: ".spc",
    license: ".lyc",
};

@dispose
export object headUnit {
    connected = false;
    @dispose
    connection = undef;
    messenger = undef;
    connectionInProgress = false;
    // infos
    diskSize = 314572800L;
    freeDiskSize = 0L;
    fileMapping = undef;
    device = undef; //connected device
    @dispose
    lastConnectedDevice = undef;
    @dispose
    listener = undef;
    deviceChangeEvent = event{passEventArg=0};
    
    //For manual device selection without connection
    selectDevice( device ){
        let oldDevice = this.lastConnectedDevice;
        this.device = undef;
        this.lastConnectedDevice = device;
        this.deviceChange(device, oldDevice);
    }

    //For device connection
    deviceConnected( device ){
        let oldDevice = this.lastConnectedDevice;
        this.device = this.lastConnectedDevice = device;
        this.deviceChange(device, oldDevice);
    }

    deviceChange( newDevice, oldDevice){
        if( newDevice?.swid != oldDevice?.swid ){
            this.deviceChangeEvent.trigger({ newDevice, oldDevice });
            console.log(`Device changed! new: ${newDevice?.swid}, old: ${oldDevice?.swid}`);
        }
    }
}

export selectDevice( device ){
    if ( headUnit.connected ) {
        failure( "cannot set device if the headUnit is connected!");
        return;
    }
    headUnit.selectDevice(device);
	packageManager.setDevice(headUnit.lastConnectedDevice);
}

aoaDebugLog(...msg) {
    if (debugAoa)
        aoaMessages.push((Date.now(), ...msg));
    console.log("AOA:", ...msg);
}
defaultMsgRecv(pkt) {
    aoaDebugLog(`recv pkt ${pkt.type} ${pkt.data.byteLength??-1}`);
}

export class nftpHandler {
    fd;
    
    next(pkt) { 
        if (pkt.type == @response)
            headUnit.connection?.cancelSend(pkt.requestId);
        headUnit.messenger?.onReceive(pkt, headUnit.connection)
    }
    error(err) { aoaDebugLog(`Error: ${err}`); this.handleClose() }
    complete() { aoaDebugLog(`NFTP completed`); this.handleClose() }
    handleClose() {
        trackEvent("disconnect");
        tryDispose(headUnit.messenger);
        headUnit.messenger = undef;
        headUnit.connected = false;
        headUnit.connection = undef;
        aoa?.closed(this.fd);
    }
};

mapFilename(fname) { // TODO: consider directory names, or `id` should contain the full path?
    Iter.from(downloadedContents()).find( _ => _.id == fname)?.downloadedPath
}

handleCheckSumMsg(msg, messenger, conn) {
    const m = procCheckSumMsg(msg);
    if (m?.status) // failed
        return m;

    console.time("start_checksum");
    // todo: investigate when is this needed, probably contentDb can be used to get downloaded filename here...s
    let res = conn[m.method]( mapFilename(m.file), m.from, m.len);

    (async () => {
        res = ?? await res;
        console.timeEnd("start_checksum");
        messenger.sendResponse(m.reqId, res ? Response.Success : Response.Failed, w => {
            if (res) w.write(res, @be); // writing in be ensures that hexstr returns correct result
        });
    })();
}

handleEvent(msg, messenger, conn) {
    const r = DataReader(msg.data);
    r.u8();
    const str = r.string();
    console.warn(str);
}

const nftpMsgHandlers = {
//    [Message.PushFile]: handlePushFile,
    [Message.CheckSum] : handleCheckSumMsg,
    [Message.Event] : handleEvent,
    pauseStream(streamId,data, conn) { conn.enableSend(streamId, false); },
    resumeStream(streamId,data, conn) {conn.enableSend(streamId, true); }
};

export responseVersionAndString(r, status) {
    status == 0 ? (r.vlu(), r.string()) : ?? responseAsFail(r, status)
}

export async setupConnection(conn) {
    headUnit.connected = true;
    headUnit.connection = conn;
    headUnit.messenger = new NftpMessenger(conn, nftpMsgHandlers);
    console.log("NFTP created");
    const verAndName = ?? await headUnit.messenger.sendRequest(w=>w.u8(Message.Init).vlu(NftpVersion).string(nftpHeader), responseVersionAndString);
    if (verAndName) {
        console.log("Remote app: ", verAndName[1], "nftp:", verAndName[0]);
        const hu = await headUnitData(); // TODO only swid is needed, use UUID instead

        const info = await queryInfo(headUnit.messenger, @fileMapping);
        headUnit.fileMapping = info[0];
        const device = getDeviceBySwid(hu.swid, #{ justConnected: true});
        await device.getContentsFromHU();
        const licenses = await getHuLicenses();
        for (const lic in licenses) 
            saveLicenseToBox(device, lic.name, lic.content);
        
        if (headUnit.lastConnectedDevice && hu.swid != headUnit.lastConnectedDevice.swid) {
            console.warn("New device attached (different from the last one)");
            // todo: show messagebox before registering new device
        } 
        
        device.connected();
        headUnit.deviceConnected(device);
        await device.refreshFreeSpace();

        device.syncDevice(hu);
        if (device.synchedWithHU && !device.registered) 
            await device.registerDev();
        packageManager.setDevice(device);
        if (headUnit.messenger)
            headUnit.messenger.setupCompleted = true;
        console.log( "[HUConnection] Remote app has been successfully initialized.");
        trackEvent("connect");
    } else
        console.error("Remote app init failed", getFailObject(verAndName)?.message);
}

export createNftpFromSocket(s) {
	nftp.createFromFd(s.detachFd(@blocking), @close, new nftpHandler());
}

acceptNftpConnection(s) {
	headUnit.connection?.close();
	setupConnection(createNftpFromSocket(s));
}

const restartListening=true;

export class NftpSocketListener
{
	@dispose
	sock = undef;
    port = undef;
    sendAcceptBlockMessage = undef;
    constructor(port=undef, sendAcceptBlockMessage) {
        this.sendAcceptBlockMessage = sendAcceptBlockMessage;
        if (port)
            this.startOn(port);
    }
	startOn(port) {
        this.port = port;
		this.sock?.close();
		this.sock = ??listen(port).subscribe(acceptNftpConnection, this.onNftpListenError(?), console.log("nftp listen finished",?));
		if (this.sock) {
    		console.log("Listening for nftp on port ", this.sock.port ?? port);
		} else {
			console.warn("Failed to listen on ", port, this.sock);
			this.sendAcceptBlockMessage?.(port, this.sock);
			this.sock = undef;
		}
	}
	async onNftpListenError(e) {
		console.log("Error in nftp socket listener",??e);
		await 0; // ensure that subscribe returns before failure. TODO: should be handled by the engine
		this.sock = undef;
        // Show a messagebox to the User if cannot listen on the fixed port.
        const shouldNotifyAcceptBlocked = getFailObject(??e)?.reason != SysError.EBADF; // SysError.EADDRINUSE -> address in use
        if (shouldNotifyAcceptBlocked) {
            await this.sendAcceptBlockMessage?.(this.port, e);
        }
        if (restartListening) {
            await Chrono.delay(100ms);
            this.startOn(this.port);
        }
	}
}


aoaEvents(evt, fd) {
    if (evt == "connected" ) {
        headUnit.connection?.close();
        // create nftp connection
        setupConnection(nftp.createFromFd(fd, nftpHandler { fd=fd })); // response not awaited (yet)
        return @connected
    }
    else if (evt == "disconnected") {
        headUnit.connected = false;
        console.log("NFTP closing");
        headUnit.connection?.close();
        headUnit.connection = undef;
    }
}

// saves remote file to local file. Resolve to length of data written.
// Rejected in case of error (e.g. write failed or remote rejected).
// The caller is responsible for remove the file in case of an error
export async saveFile(remoteFile, localFile, opts) {
    const locPos = opts?.locpos ?? opts?.pos;
    ensureParentDirSync(localFile);
    const f = openSync(localFile, {write:true, truncate:opts?.truncate ?? (locPos == undef)});
    if (!f)
        return f;
    if (locPos)
        f.seekSync(locPos, @start);
    new Promise((resolve, reject) => {
        let isFirst = true;
        let subs;
        let recvBytes = 0;
        const closeFile = opts?.trim ? f => {f?.truncate(); f?.close() } : f=> f?.close();
        subs = headUnit.messenger.Request(w=>  w.u8(Message.GetFile).string(remoteFile).vlu(opts?.pos??0).vlu(opts?.len??0))
           .subscribe({
            next(pkt) { // request id should be accessible from subscription or somethint similar
                let data = pkt.data;
                if (isFirst && data[0] != Response.Success) {
                    // TODO in case of failure no more answer is expected maybe messenger should call error
                    closeFile(f);
                    reject(??responseDataOrFail(DataReader.view(data,1)));
                    return subs.cancel();
                }
                if (isFirst)
                    data = data.subarray(1);
                isFirst = false;
                recvBytes += data.byteLength;
                const res = f.writeSync(data);
                if (!res && ??res != 0) {
                    closeFile(f);
                    reject(res);
                    subs.cancel();
                }
                opts?.progressCb?.(data.byteLength);
            },
            complete() { closeFile(f); resolve(recvBytes); },
            error(err) { closeFile(f); reject(??err) },
    })});
}

async getHuLicense(name) {
    const messenger = headUnit.messenger;
    const path = mapFileToPath(name, headUnit.fileMapping );
    return #{name: name, content: await getSmallFile(messenger, path)};
}

export async getHuLicenses() {
    const messenger = headUnit.messenger;
    const ext = defaultExts.license;
    const folder = headUnit.fileMapping[ext] ?? defaultFileMapping[ext];
    const licInfo = ?? await queryFiles(headUnit.messenger, folder, {fields: (@name, @size), exts: (ext)});
    if (!licInfo) return ();
    const licenses = Iter.map(licInfo.children, lic => getHuLicense(lic.name)).toArray();
    return await Promise.all(licenses);
}

export async headUnitData() {
    // TODO: open cached device.nng
    const device = await queryInfo(headUnit.messenger, @device, @brand);
    const path = mapFileToPath("device.nng", headUnit.fileMapping );
    if (const buf = ?? await getSmallFile(headUnit.messenger, path)) {
        const nng = decodeDevNngFrom(buf);
        return #{
            appcid:     nng.appcid,
            igoVersion: nng.igoVersion,
            swid:       nng.defSwid,
            swids:      nng.swids,
            skus:       [nng.sku],
            firstUse:   nng.fudMs,
            imei:       nng.id,
            vin:        nng.vin,
            agentBrand: device[1].agentBrand,
            modelName:  device[1].modelName, // remove?
            brandName:  device[1].brandName, // remove?
            brandFiles: device[1].brandFiles,
        };
    } else { // returns mock data
        return #{
            appcid:     device[0].appcid,
            igoVersion: device[0].igoVersion,
            swid:       device[0].swid,
            swids:      [device[0].swid],
            skus:       [device[0].sku],
            firstUse:   device[0].firstUse,
            imei:       device[0].imei,
            vin:        device[0].vin,
            agentBrand: device[1].agentBrand,
            modelName:  device[1].modelName, // remove?
            brandName:  device[1].brandName, // remove?
            brandFiles: device[1].brandFiles,
        };
    }
}

@onStart
setupAoa(){
    headUnit.lastConnectedDevice = getLastConnectedDevice();
    packageManager.setDevice(headUnit.lastConnectedDevice);
    checkHasDevice();
    aoa?.setCallback(aoaEvents);

    // init AOA debug logging
    if (debugAoa)
        aoaMessages.push("AOA Logs:");
    aoa?.setLogger(aoaDebugLog);
    // ready for communication
    aoa?.ready();
    if (os.platform == "ios" || os.platform == "android") {
        headUnit.listener = new NftpSocketListener(#{host:"0.0.0.0", port:9876}, showFailedToListen);
    }
}

// Force outbound connection to emulator at module load time
(async () => {
    try {
        console.log("[probe] Connecting to emulator at 10.0.0.78:9876...");
        const s = await connect(#{host:"10.0.0.78", port:9876});
        console.log("[probe] TCP connected:", s.remoteAddrStr);
        const conn = createNftpFromSocket(s);
        const messenger = new NftpMessenger(conn, nftpMsgHandlers);
        console.log("[probe] NFTP messenger created, sending Init...");

        const verAndName = ?? await messenger.sendRequest(
            w => w.u8(Message.Init).vlu(NftpVersion).string(nftpHeader),
            responseVersionAndString
        );
        if (verAndName) {
            console.log("[probe] Init OK: ", verAndName[1], "nftp:", verAndName[0]);
        } else {
            console.error("[probe] Init failed:", getFailObject(verAndName)?.message);
            return;
        }

        // QueryInfo @fileMapping
        const fmInfo = ?? await queryInfo(messenger, @fileMapping);
        console.log("[probe] @fileMapping:", fmInfo);

        // QueryInfo @device, @brand
        const devInfo = ?? await queryInfo(messenger, @device, @brand);
        console.log("[probe] @device/@brand:", devInfo);

        // QueryInfo @diskInfo
        const diskInfo = ?? await queryInfo(messenger, @diskInfo);
        console.log("[probe] @diskInfo:", diskInfo);

        // QueryInfo @freeSpace
        const freeInfo = ?? await queryInfo(messenger, @freeSpace);
        console.log("[probe] @freeSpace:", freeInfo);

        // GetFile device.nng
        const fmapping = fmInfo?.[0] ?? #{};
        const devPath = fmapping["device.nng"] ?? "license/device.nng";
        const devFile = ?? await getSmallFile(messenger, devPath);
        console.log("[probe] GetFile", devPath, ":", devFile?.byteLength, "bytes");

        // queryFilesFlat "content"
        const contentFiles = ?? await queryFilesFlat(messenger, "content", {fields: (@name, @size, @isFile, @mtimeMs)});
        console.log("[probe] queryFilesFlat content:", contentFiles?.length, "entries");
        if (contentFiles) {
            for (const f in contentFiles) {
                console.log("[probe]   ", f.path, f.name, f.size, f.isFile);
            }
        }

        // queryFilesFlat "license"
        const licFiles = ?? await queryFilesFlat(messenger, "license", {fields: (@name, @size, @isFile, @mtimeMs)});
        console.log("[probe] queryFilesFlat license:", licFiles?.length, "entries");
        if (licFiles) {
            for (const f in licFiles) {
                console.log("[probe]   ", f.path, f.name, f.size, f.isFile);
            }
        }

        // CheckSum
        const md5 = ?? await queryChecksum(messenger, devPath, @md5);
        console.log("[probe] CheckSum MD5", devPath, ":", md5);

        console.log("[probe] === ALL TESTS COMPLETE ===");
        conn.close?.();
    } catch(e) {
        console.error("[probe] Error:", e);
    }
})();
