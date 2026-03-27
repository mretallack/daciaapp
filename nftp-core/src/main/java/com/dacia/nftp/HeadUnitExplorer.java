package com.dacia.nftp;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * High-level API for exploring a head unit over NFTP.
 * QueryInfo-dependent features (device info, disk info, directory listing) are
 * currently blocked due to unknown symbol IDs. Workarounds use GetFile + hardcoded paths.
 */
public class HeadUnitExplorer {

    public static class FileEntry {
        public final String name;
        public final String path;
        public final boolean isDir;

        public FileEntry(String name, String path, boolean isDir) {
            this.name = name;
            this.path = path;
            this.isDir = isDir;
        }
    }

    private NftpConnection conn;
    private NftpProbe.Logger log;
    private String serverName;
    private int serverVersion;
    private byte[] deviceNng;

    public String getServerName() { return serverName; }
    public int getServerVersion() { return serverVersion; }
    public byte[] getDeviceNng() { return deviceNng; }
    public boolean isConnected() { return conn != null; }

    /** Connect: Init handshake + GetFile device.nng. */
    public void connect(InputStream in, OutputStream out, NftpProbe.Logger logger) throws IOException {
        this.log = logger;
        this.conn = new NftpConnection(in, out);

        // Init
        byte[] initBody = NftpProbe.buildInit();
        log.log("Init (" + initBody.length + " bytes)");
        byte[] initResp = conn.sendAndReceive(initBody);
        if (initResp.length == 0 || initResp[0] != 0x00) {
            conn = null;
            throw new IOException("Init failed: status=" + (initResp.length > 0 ? (initResp[0] & 0xFF) : -1));
        }
        ByteArrayInputStream ris = new ByteArrayInputStream(initResp, 1, initResp.length - 1);
        serverVersion = (int) VluCodec.decode(ris);
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        int b; while ((b = ris.read()) > 0) buf.write(b);
        serverName = buf.toString("ASCII");
        log.log("Connected: " + serverName + " v" + serverVersion);

        // GetFile device.nng
        try {
            deviceNng = readFile("license/device.nng");
            log.log("Got device.nng: " + deviceNng.length + " bytes");
        } catch (IOException e) {
            log.log("device.nng: " + e.getMessage());
        }
    }

    /** Read a file from the head unit. */
    public byte[] readFile(String path) throws IOException {
        checkConnected();
        byte[] body = NftpProbe.buildGetFile(path);
        log.log("GetFile " + path);
        byte[] resp = conn.sendAndReceive(body);
        if (resp.length == 0 || resp[0] != 0x00) {
            int status = resp.length > 0 ? (resp[0] & 0xFF) : -1;
            String err = resp.length > 1 ? new String(resp, 1, resp.length - 1, "UTF-8").trim() : "";
            log.log("GetFile failed: status=" + status + " " + err);
            throw new IOException("GetFile " + path + ": status=" + status + " " + err);
        }
        byte[] data = new byte[resp.length - 1];
        System.arraycopy(resp, 1, data, 0, data.length);
        log.log("GetFile " + path + ": " + data.length + " bytes");
        return data;
    }

    /** Compute checksum of a remote file. Returns hex string. */
    public String getChecksum(String path, int method) throws IOException {
        checkConnected();
        return NftpProbe.checkSum(conn, log, path, method);
    }

    /** Get the default file mapping from the v1.8.13 app. */
    public static Map<String, String> getDefaultFileMapping() {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("device.nng", "license/");
        m.put(".lyc", "license/");
        m.put(".fbl", "content/map/");
        m.put(".hnr", "content/map/");
        m.put(".fda", "content/map/");
        m.put(".fpa", "content/map/");
        m.put(".fsp", "content/map/");
        m.put(".ftr", "content/map/");
        m.put(".poi", "content/poi/");
        m.put(".spc", "content/speedcam/");
        return m;
    }

    /** Get a fixed directory tree from the default file mapping. */
    public static List<FileEntry> getDirectoryTree() {
        List<FileEntry> entries = new ArrayList<>();
        entries.add(new FileEntry("license", "license/", true));
        entries.add(new FileEntry("content", "content/", true));
        entries.add(new FileEntry("content/map", "content/map/", true));
        entries.add(new FileEntry("content/poi", "content/poi/", true));
        entries.add(new FileEntry("content/speedcam", "content/speedcam/", true));
        return entries;
    }

    /** Get known files for a directory path. */
    public static List<FileEntry> getKnownFiles(String dirPath) {
        List<FileEntry> entries = new ArrayList<>();
        if ("license/".equals(dirPath)) {
            entries.add(new FileEntry("device.nng", "license/device.nng", false));
        }
        return entries;
    }

    private void checkConnected() throws IOException {
        if (conn == null) throw new IOException("Not connected");
    }
}
