// Probe main.xs — connect to emulator using real NNG NFTP code
import {connect} from "system://socket"
import * as nftp from "system://yellow.nftp"
import {NftpMessenger, Message, Version, queryInfo, getSmallFile, queryFilesFlat, queryChecksum} from "core/nftp.xs"
import {failure} from "system://core"

SysConfig.set("probe", "main", "loaded");

const nftpHeader = "YellowBox/1.8.13+e14eabb8";

class probeHandler {
    next(data) { SysConfig.set("probe", "rx", "got " + data.byteLength + " bytes"); }
    error(err) { SysConfig.set("probe", "rx", "error: " + err); }
    complete() { SysConfig.set("probe", "rx", "complete"); }
};

(async () => {
    try {
        SysConfig.set("probe", "status", "connecting");
        const s = await connect(#{host:"10.0.0.78", port:9876});
        SysConfig.set("probe", "status", "tcp_connected");

        const conn = nftp.createFromFd(s.detachFd(@blocking), @close, new probeHandler());
        const messenger = new NftpMessenger(conn, {});
        SysConfig.set("probe", "status", "nftp_created");

        // Init
        const verAndName = ?? await messenger.sendRequest(
            w => w.u8(Message.Init).vlu(Version).string(nftpHeader),
            (r, status) => status == 0 ? (r.vlu(), r.string()) : ?? failure("init failed", status)
        );
        SysConfig.set("probe", "init", "" + verAndName?.[1] + " v" + verAndName?.[0]);

        // QueryInfo @fileMapping
        const fm = ?? await queryInfo(messenger, @fileMapping);
        SysConfig.set("probe", "fileMapping", "" + fm);

        // QueryInfo @device, @brand
        const dev = ?? await queryInfo(messenger, @device, @brand);
        SysConfig.set("probe", "device", "" + dev);

        // QueryInfo @diskInfo
        const disk = ?? await queryInfo(messenger, @diskInfo);
        SysConfig.set("probe", "diskInfo", "" + disk);

        // QueryInfo @freeSpace
        const free = ?? await queryInfo(messenger, @freeSpace);
        SysConfig.set("probe", "freeSpace", "" + free);

        // GetFile device.nng
        const devFile = ?? await getSmallFile(messenger, "license/device.nng");
        SysConfig.set("probe", "getfile", "" + devFile?.byteLength + " bytes");

        // queryFilesFlat "content"
        const contentFiles = ?? await queryFilesFlat(messenger, "content", {fields: (@name, @size)});
        SysConfig.set("probe", "ls_content", "" + contentFiles?.length + " entries");

        // queryFilesFlat "license"
        const licFiles = ?? await queryFilesFlat(messenger, "license", {fields: (@name, @size)});
        SysConfig.set("probe", "ls_license", "" + licFiles?.length + " entries");

        SysConfig.set("probe", "status", "ALL_DONE");
    } catch(e) {
        SysConfig.set("probe", "status", "error: " + e);
    }
})();
