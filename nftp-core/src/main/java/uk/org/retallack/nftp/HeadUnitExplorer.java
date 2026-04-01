package uk.org.retallack.nftp;

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
 * Uses validated 0x8d compact identifiers for all QueryInfo queries.
 */
public class HeadUnitExplorer {

    public static class FileEntry {
        public final String name;
        public final String path;
        public final boolean isDir;
        public final long size;

        public FileEntry(String name, String path, boolean isDir, long size) {
            this.name = name;
            this.path = path;
            this.isDir = isDir;
            this.size = size;
        }

        public FileEntry(String name, String path, boolean isDir) {
            this(name, path, isDir, 0);
        }
    }

    public static class DeviceInfo {
        public String swid, vin, igoVersion, appcid;
        public String agentBrand, modelName, brandName;
    }

    public static class DiskInfo {
        public long available, size;
    }

    private NftpConnection conn;
    private NftpProbe.Logger log;
    private String serverName;
    private int serverVersion;
    private byte[] deviceNng;
    private DeviceInfo deviceInfo;
    private DiskInfo diskInfo;
    private Map<String, String> fileMapping;

    public String getServerName() { return serverName; }
    public int getServerVersion() { return serverVersion; }
    public byte[] getDeviceNng() { return deviceNng; }
    public DeviceInfo getDeviceInfo() { return deviceInfo; }
    public DiskInfo getDiskInfo() { return diskInfo; }
    public Map<String, String> getFileMapping() { return fileMapping; }
    public boolean isConnected() { return conn != null; }

    /** Connect: Init + QueryInfo(@fileMapping, @device, @brand, @diskInfo) + GetFile device.nng. */
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

        // QueryInfo @fileMapping
        fileMapping = queryFileMapping();
        if (fileMapping == null) {
            fileMapping = getDefaultFileMapping();
            log.log("Using default file mapping");
        }

        // QueryInfo @device, @brand
        deviceInfo = queryDeviceInfo();

        // QueryInfo @diskInfo
        diskInfo = queryDiskInfo();

        // GetFile device.nng
        try {
            deviceNng = readFile("license/device.nng");
            log.log("Got device.nng: " + deviceNng.length + " bytes");
            log.log("device.nng hex: " + NftpProbe.hex(deviceNng, Math.min(deviceNng.length, 128)));
            // Fill in any fields that QueryInfo returned as null/FAILURE
            if (deviceInfo == null) deviceInfo = new DeviceInfo();
            parseDeviceNng(deviceNng, deviceInfo, log);
        } catch (IOException e) {
            log.log("device.nng: " + e.getMessage());
        }
    }

    /** Parse device.nng KEY=VALUE lines into DeviceInfo, filling only null fields. */
    static void parseDeviceNng(byte[] data, DeviceInfo info, NftpProbe.Logger log) {
        String text = new String(data, java.nio.charset.StandardCharsets.UTF_8);
        if (log != null) log.log("device.nng text: " + text.substring(0, Math.min(text.length(), 200)));
        for (String line : text.split("\n")) {
            int eq = line.indexOf('=');
            if (eq < 0) continue;
            String key = line.substring(0, eq).trim();
            String val = line.substring(eq + 1).trim();
            if (val.isEmpty()) continue;
            if (log != null) log.log("device.nng: " + key + "=" + val);
            switch (key) {
                case "SWID": if (info.swid == null) info.swid = val; break;
                case "VIN":  if (info.vin == null) info.vin = val; break;
                case "IGO":  if (info.igoVersion == null) info.igoVersion = val; break;
            }
        }
    }

    /** Query @device and @brand, return DeviceInfo or null. */
    public DeviceInfo queryDeviceInfo() {
        try {
            Object result = NftpProbe.queryInfo(conn, log, "device", "brand");
            if (result == null) return null;
            DeviceInfo info = new DeviceInfo();
            if (result instanceof Object[]) {
                Object[] tuple = (Object[]) result;
                if (tuple.length >= 1 && tuple[0] instanceof Map) {
                    Map<String, Object> dev = (Map<String, Object>) tuple[0];
                    info.swid = getStr(dev, "swid");
                    info.vin = getStr(dev, "vin");
                    info.igoVersion = getStr(dev, "igoVersion");
                    info.appcid = getStr(dev, "appcid");
                }
                if (tuple.length >= 2 && tuple[1] instanceof Map) {
                    Map<String, Object> brand = (Map<String, Object>) tuple[1];
                    info.agentBrand = getStr(brand, "agentBrand");
                    info.modelName = getStr(brand, "modelName");
                    info.brandName = getStr(brand, "brandName");
                }
            } else if (result instanceof Map) {
                // Single key response
                Map<String, Object> dev = (Map<String, Object>) result;
                info.swid = getStr(dev, "swid");
                info.vin = getStr(dev, "vin");
                info.igoVersion = getStr(dev, "igoVersion");
                info.appcid = getStr(dev, "appcid");
            }
            log.log("DeviceInfo: swid=" + info.swid + " vin=" + info.vin);
            return info;
        } catch (Exception e) {
            log.log("queryDeviceInfo error: " + e.getMessage());
            return null;
        }
    }

    /** Query @diskInfo, return DiskInfo or null. */
    public DiskInfo queryDiskInfo() {
        try {
            Object result = NftpProbe.queryInfo(conn, log, "diskInfo");
            if (result == null) return null;
            // Single-key query may return tuple[1](dict) — unwrap
            if (result instanceof Object[]) {
                Object[] arr = (Object[]) result;
                if (arr.length == 1) result = arr[0];
            }
            if (result instanceof Map) {
                Map<String, Object> m = (Map<String, Object>) result;
                DiskInfo di = new DiskInfo();
                di.available = getLong(m, "available");
                di.size = getLong(m, "size");
                log.log("DiskInfo: available=" + di.available + " size=" + di.size);
                return di;
            }
            return null;
        } catch (Exception e) {
            log.log("queryDiskInfo error: " + e.getMessage());
            return null;
        }
    }

    /** Query @fileMapping, return map or null. */
    public Map<String, String> queryFileMapping() {
        try {
            Object result = NftpProbe.queryInfo(conn, log, "fileMapping");
            if (result == null) return null;
            if (result instanceof Map) {
                Map<String, Object> raw = (Map<String, Object>) result;
                Map<String, String> mapping = new LinkedHashMap<>();
                for (Map.Entry<String, Object> e : raw.entrySet()) {
                    String key = stripAt(e.getKey());
                    mapping.put(key, String.valueOf(e.getValue()));
                }
                log.log("FileMapping: " + mapping.size() + " entries");
                return mapping;
            }
            return null;
        } catch (Exception e) {
            log.log("queryFileMapping error: " + e.getMessage());
            return null;
        }
    }

    /** Query @ls for a directory path. Returns list of FileEntry or null. */
    public List<FileEntry> listDirectory(String path) {
        try {
            Object result = NftpProbe.queryLs(conn, log, path);
            if (result == null) return null;
            if (!(result instanceof Object[])) return null;
            Object[] root = (Object[]) result;
            // Fields: name(0), size(1), isFile(2), then children(3+)
            int fieldCount = 3; // name, size, isFile
            List<FileEntry> entries = new ArrayList<>();
            for (int i = fieldCount; i < root.length; i++) {
                if (root[i] instanceof Object[]) {
                    Object[] child = (Object[]) root[i];
                    FileEntry fe = parseLsEntry(child, path);
                    if (fe != null) entries.add(fe);
                }
            }
            log.log("@ls '" + path + "': " + entries.size() + " entries");
            return entries;
        } catch (Exception e) {
            log.log("listDirectory error: " + e.getMessage());
            return null;
        }
    }

    private FileEntry parseLsEntry(Object[] tuple, String parentPath) {
        if (tuple.length < 3) return null;
        String name = String.valueOf(tuple[0]);
        long size = toLong(tuple[1]);
        boolean isFile = isTruthy(tuple[2]);
        // Build path without leading slash — emulator/head unit uses relative paths
        String base = parentPath;
        if (base.startsWith("/")) base = base.substring(1);
        String entryPath;
        if (base.isEmpty()) {
            entryPath = name;
        } else {
            entryPath = base.endsWith("/") ? base + name : base + "/" + name;
        }
        if (!isFile) entryPath += "/";
        // Recurse: children are at index 3+, but we only return immediate children
        return new FileEntry(name, entryPath, !isFile, size);
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

    private void checkConnected() throws IOException {
        if (conn == null) throw new IOException("Not connected");
    }

    /** Get a string from a dict, handling @-prefixed keys. Returns null for failures/non-strings. */
    private static String getStr(Map<String, Object> m, String key) {
        Object v = m.get("@" + key);
        if (v == null) v = m.get(key);
        if (v == null || v instanceof Map) return null; // null or failure map
        return String.valueOf(v);
    }

    /** Get a long from a dict, handling @-prefixed keys. */
    private static long getLong(Map<String, Object> m, String key) {
        Object v = m.get("@" + key);
        if (v == null) v = m.get(key);
        if (v instanceof Number) return ((Number) v).longValue();
        return 0;
    }

    private static String stripAt(String s) {
        return (s != null && s.startsWith("@")) ? s.substring(1) : s;
    }

    private static long toLong(Object v) {
        if (v instanceof Number) return ((Number) v).longValue();
        return 0;
    }

    private static boolean isTruthy(Object v) {
        if (v == null) return false;
        if (v instanceof Number) return ((Number) v).longValue() != 0;
        if (v instanceof Boolean) return (Boolean) v;
        return true;
    }
}
