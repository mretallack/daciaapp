package uk.org.retallack.nftp;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Runs an NFTP probe: Init handshake then GetFile for device.nng.
 */
public class NftpProbe {

    public interface Logger {
        void log(String message);
    }

    public static class Result {
        public final String serverName;
        public final int serverVersion;
        public final byte[] deviceNng;
        public final String error;

        private Result(String serverName, int serverVersion, byte[] deviceNng, String error) {
            this.serverName = serverName;
            this.serverVersion = serverVersion;
            this.deviceNng = deviceNng;
            this.error = error;
        }

        public static Result success(String serverName, int serverVersion, byte[] deviceNng) {
            return new Result(serverName, serverVersion, deviceNng, null);
        }

        public static Result failure(String error) {
            return new Result(null, 0, null, error);
        }

        public boolean isSuccess() { return error == null; }
    }

    public static Result run(InputStream in, OutputStream out, Logger log) {
        NftpConnection conn = new NftpConnection(in, out);
        try {
            // Init handshake
            byte[] initBody = buildInit();
            log.log("Sending Init (" + initBody.length + " bytes): " + hex(initBody));
            byte[] initResp = conn.sendAndReceive(initBody);
            log.log("Init response (" + initResp.length + " bytes): " + hex(initResp));

            if (initResp.length == 0 || initResp[0] != 0x00) {
                int status = initResp.length > 0 ? (initResp[0] & 0xFF) : -1;
                log.log("Init failed: status=" + status);
                return Result.failure("Init failed: status=" + status);
            }

            ByteArrayInputStream respIn = new ByteArrayInputStream(initResp, 1, initResp.length - 1);
            int serverVersion = (int) VluCodec.decode(respIn);
            String serverName = readNullTermString(respIn);
            log.log("Connected: " + serverName + " v" + serverVersion);

            // GetFile device.nng — use known path from fileMapping
            byte[] getBody = buildGetFile("license/device.nng");
            log.log("Sending GetFile (" + getBody.length + " bytes): " + hex(getBody));
            byte[] getResp = conn.sendAndReceive(getBody);
            log.log("GetFile response (" + getResp.length + " bytes): " + hex(getResp, 64));

            if (getResp.length == 0 || getResp[0] != 0x00) {
                int status = getResp.length > 0 ? (getResp[0] & 0xFF) : -1;
                log.log("GetFile failed: status=" + status);
                return Result.failure("GetFile failed: status=" + status);
            }

            byte[] fileData = new byte[getResp.length - 1];
            System.arraycopy(getResp, 1, fileData, 0, fileData.length);
            log.log("Got device.nng: " + fileData.length + " bytes");
            log.log(new String(fileData, "UTF-8").trim());

            // Query with string identifiers (TAG_ID_STRING) — bypasses symbol ID mismatch
            // The head unit's deserialiser will look up the string in its own symbol table
            String[] queryKeys = {
                "device", "brand", "fileMapping", "freeSpace", "diskInfo",
                "ls", "name", "size", "children", "path",
                "md5", "sha1", "compact", "error", "response",
                "request", "control", "get",
            };

            log.log("=== QueryInfo with string identifiers ===");
            for (String key : queryKeys) {
                byte[] qBody = buildQueryInfo(key);
                byte[] qResp = conn.sendAndReceive(qBody);
                int status = qResp.length > 0 ? (qResp[0] & 0xFF) : -1;
                String detail;
                if (status == 0 && qResp.length > 1) {
                    byte[] payload = new byte[qResp.length - 1];
                    System.arraycopy(qResp, 1, payload, 0, payload.length);
                    detail = "OK " + payload.length + "b payload=" + hex(payload, 64);
                    // Try to interpret as UTF-8 string if it looks like text
                    try {
                        String txt = new String(payload, "UTF-8");
                        if (txt.chars().allMatch(c -> c >= 0x20 && c < 0x7F))
                            detail += " text=\"" + txt + "\"";
                    } catch (Exception e) {}
                } else {
                    detail = "status=" + status + " len=" + qResp.length + " raw=" + hex(qResp, 32);
                }
                log.log("@" + key + ": " + detail);
            }

            // Multi-key query
            log.log("=== Multi-key: device,brand ===");
            byte[] multiBody = buildQueryInfo("device", "brand");
            byte[] multiResp = conn.sendAndReceive(multiBody);
            int mStatus = multiResp.length > 0 ? (multiResp[0] & 0xFF) : -1;
            log.log("status=" + mStatus + " len=" + multiResp.length + " raw=" + hex(multiResp, 128));

            // Try @ls query with path — this is how queryFiles works
            log.log("=== QueryInfo: @ls / ===");
            byte[] lsBody = buildLsQuery("/");
            byte[] lsResp = conn.sendAndReceive(lsBody);
            int lsStatus = lsResp.length > 0 ? (lsResp[0] & 0xFF) : -1;
            log.log("status=" + lsStatus + " len=" + lsResp.length + " raw=" + hex(lsResp, 256));

            // Try @device query as the real app does
            log.log("=== QueryInfo: @device (single symbol) ===");
            byte[] devBody = buildQueryInfoSingleSymbol("device");
            byte[] devResp = conn.sendAndReceive(devBody);
            int devStatus = devResp.length > 0 ? (devResp[0] & 0xFF) : -1;
            log.log("status=" + devStatus + " len=" + devResp.length + " raw=" + hex(devResp, 256));

            // queryFiles sends: queryInfo(@ls, path, #{fields})
            // Let's try listing "content" and "license" directories
            log.log("=== queryFiles: content ===");
            byte[] contentLs = buildQueryFiles("content");
            log.log("packet: " + hex(contentLs));
            byte[] contentResp = conn.sendAndReceive(contentLs);
            int contentStatus = contentResp.length > 0 ? (contentResp[0] & 0xFF) : -1;
            log.log("status=" + contentStatus + " len=" + contentResp.length);
            if (contentResp.length > 1) {
                log.log("raw: " + hex(contentResp, 512));
            }

            // Try GetFile on various paths to explore the filesystem
            log.log("=== Exploring filesystem via GetFile ===");
            String[] paths = {
                "license/device.nng",
                "license/license.nng",
                "content/content.nng",
                "save/settings.nng",
                "config/config.nng",
                "map/map.nng",
                "sys/version.txt",
                "version.txt",
                "info.txt",
            };
            for (String path : paths) {
                byte[] body = buildGetFile(path);
                byte[] resp = conn.sendAndReceive(body);
                int status = resp.length > 0 ? (resp[0] & 0xFF) : -1;
                if (status == 0 && resp.length > 1) {
                    log.log(path + ": OK " + (resp.length - 1) + " bytes");
                    // Show first 64 bytes of content
                    byte[] content = new byte[Math.min(64, resp.length - 1)];
                    System.arraycopy(resp, 1, content, 0, content.length);
                    log.log("  " + hex(content));
                } else {
                    log.log(path + ": status=" + status);
                }
            }

            log.log("=== queryFiles: license ===");
            byte[] licenseLs = buildQueryFiles("license");
            byte[] licenseResp = conn.sendAndReceive(licenseLs);
            int licenseStatus = licenseResp.length > 0 ? (licenseResp[0] & 0xFF) : -1;
            log.log("status=" + licenseStatus + " len=" + licenseResp.length);
            if (licenseResp.length > 1) {
                log.log("raw: " + hex(licenseResp, 512));
            }

            log.log("=== queryFiles: / (root) ===");
            byte[] rootLs = buildQueryFiles("/");
            byte[] rootResp = conn.sendAndReceive(rootLs);
            int rootStatus = rootResp.length > 0 ? (rootResp[0] & 0xFF) : -1;
            log.log("status=" + rootStatus + " len=" + rootResp.length);
            if (rootResp.length > 1) {
                log.log("raw: " + hex(rootResp, 512));
            }

            log.log("Probe complete");

            return Result.success(serverName, serverVersion, fileData);

        } catch (IOException e) {
            log.log("Error: " + e.getClass().getName() + ": " + e.getMessage());
            return Result.failure(e.getMessage());
        }
    }

    public static String hex(byte[] data) { return hex(data, data.length); }

    public static String hex(byte[] data, int max) {
        StringBuilder sb = new StringBuilder();
        int len = Math.min(data.length, max);
        for (int i = 0; i < len; i++) {
            if (i > 0) sb.append(' ');
            sb.append(String.format("%02x", data[i] & 0xFF));
        }
        if (len < data.length) sb.append("...");
        return sb.toString();
    }

    /** Build Init message: [0x00][vlu:1][string:"YellowBox/1.8.13+e14eabb8\0"] */
    static byte[] buildInit() {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x00); // command type
        byte[] version = VluCodec.encode(1);
        buf.write(version, 0, version.length);
        byte[] name = "YellowBox/1.8.13+e14eabb8\0".getBytes();
        buf.write(name, 0, name.length);
        return buf.toByteArray();
    }

    /** Build GetFile message: [0x03][string:filename\0][vlu:0][vlu:0] */
    static byte[] buildGetFile(String filename) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x03); // command type
        byte[] fname = (filename + "\0").getBytes();
        buf.write(fname, 0, fname.length);
        byte[] zero = VluCodec.encode(0);
        buf.write(zero, 0, zero.length);
        buf.write(zero, 0, zero.length);
        return buf.toByteArray();
    }

    /** Build QueryInfo with a raw string key (not identifier). */
    static byte[] buildRawQueryInfo(String key) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x04);
        NngSerializer ser = new NngSerializer();
        // Try as a plain tuple with a single string
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(1);
        ser.writeString(key);
        byte[] payload = ser.toBytes();
        buf.write(payload, 0, payload.length);
        return buf.toByteArray();
    }

    /** Build QueryInfo with a single symbol ID. */
    static byte[] buildQueryInfoBySymbolId(int symbolId) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x04); // command type
        NngSerializer ser = new NngSerializer();
        // Write tuple of 1 item: IdSymbolVLI
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(1);
        ser.writeTag(NngSerializer.TAG_ID_SYMBOL_VLI);
        ser.writeVli(symbolId);
        byte[] payload = ser.toBytes();
        buf.write(payload, 0, payload.length);
        return buf.toByteArray();
    }

    /** Build QueryInfo message: [0x04][serialised tuple of identifier strings] */
    static byte[] buildQueryInfo(String... keys) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x04); // command type
        NngSerializer ser = new NngSerializer();
        Object[] items = new Object[keys.length];
        for (int i = 0; i < keys.length; i++) {
            items[i] = "@" + keys[i];
        }
        ser.writeTuple(items);
        byte[] payload = ser.toBytes();
        buf.write(payload, 0, payload.length);
        return buf.toByteArray();
    }

    /** Build QueryInfo for @ls query: (@ls, path, #{fields: (@name, @size)}) */
    static byte[] buildLsQuery(String path) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x04); // QueryInfo command
        NngSerializer ser = new NngSerializer();
        // Tuple: (@ls, path, #{fields: (@name, @size)})
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(3); // 3 items
        ser.writeIdentifierString("ls");
        ser.writeString(path);
        // Record: #{fields: (@name, @size)}
        ser.writeTag(NngSerializer.TAG_DICT_VLI_LEN);
        ser.writeVlu(1); // 1 key-value pair
        ser.writeIdentifierString("fields");
        // Tuple of field names
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(2);
        ser.writeIdentifierString("name");
        ser.writeIdentifierString("size");
        byte[] payload = ser.toBytes();
        buf.write(payload, 0, payload.length);
        return buf.toByteArray();
    }

    /** Build QueryInfo with single symbol identifier */
    static byte[] buildQueryInfoSingleSymbol(String name) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x04); // QueryInfo command
        NngSerializer ser = new NngSerializer();
        // Just the identifier, not wrapped in tuple
        ser.writeIdentifierString(name);
        byte[] payload = ser.toBytes();
        buf.write(payload, 0, payload.length);
        return buf.toByteArray();
    }

    /** Build queryFiles query: queryInfo(@ls, path, #{fields: (@name, @size)}) */
    static byte[] buildQueryFiles(String path) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x04); // QueryInfo command
        NngSerializer ser = new NngSerializer();
        // Outer tuple: (@ls, path, #{fields})
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(3); // 3 items
        ser.writeIdentifierString("ls");  // @ls
        ser.writeString(path);             // path string
        // Record: #{fields: (@name, @size)}
        ser.writeTag(NngSerializer.TAG_DICT_VLI_LEN);
        ser.writeVlu(1); // 1 key-value pair
        ser.writeIdentifierString("fields");
        // Tuple of field identifiers
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(2);
        ser.writeIdentifierString("name");
        ser.writeIdentifierString("size");
        byte[] payload = ser.toBytes();
        buf.write(payload, 0, payload.length);
        return buf.toByteArray();
    }

    /** Build @ls query using compact 0x8d identifiers: (@ls, path, #{fields: (@name, @size, @isFile)}) */
    static byte[] buildLsQueryCompact(String path, String... fields) {
        if (fields.length == 0) fields = new String[]{"name", "size", "isFile"};
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x04);
        NngSerializer ser = new NngSerializer();
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(3);
        ser.writeIdentifier("ls");
        ser.writeString(path);
        ser.writeTag(NngSerializer.TAG_DICT_VLI_LEN);
        ser.writeVlu(1);
        ser.writeIdentifier("fields");
        ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
        ser.writeVlu(fields.length);
        for (String f : fields) ser.writeIdentifier(f);
        byte[] payload = ser.toBytes();
        buf.write(payload, 0, payload.length);
        return buf.toByteArray();
    }

    /** Send QueryInfo and parse response. Returns deserialised result or null on error. */
    public static Object queryInfo(NftpConnection conn, Logger log, String... keys) throws IOException {
        byte[] body = buildQueryInfo(keys);
        log.log("QueryInfo [" + String.join(", ", keys) + "] (" + body.length + " bytes): " + hex(body));
        byte[] resp = conn.sendAndReceive(body);
        log.log("QueryInfo response (" + resp.length + " bytes): " + hex(resp, 128));
        if (resp.length == 0 || resp[0] != 0x00) {
            int status = resp.length > 0 ? (resp[0] & 0xFF) : -1;
            String errMsg = resp.length > 1 ? new String(resp, 1, resp.length - 1, "UTF-8").trim() : "unknown";
            log.log("QueryInfo failed: status=" + status + " error=" + errMsg);
            return null;
        }
        if (resp.length <= 1) {
            log.log("QueryInfo: empty response");
            return null;
        }
        try {
            Object result = NngDeserializer.decode(resp, 1);
            log.log("QueryInfo parsed: " + describeValue(result));
            return result;
        } catch (Exception e) {
            log.log("QueryInfo parse error: " + e.getClass().getName() + ": " + e.getMessage());
            log.log("QueryInfo raw payload: " + hex(resp, resp.length));
            return null;
        }
    }

    /** Send @ls QueryInfo and parse response. Returns deserialised result or null on error. */
    public static Object queryLs(NftpConnection conn, Logger log, String path) throws IOException {
        byte[] body = buildLsQueryCompact(path);
        log.log("QueryInfo @ls '" + path + "' (" + body.length + " bytes): " + hex(body));
        byte[] resp = conn.sendAndReceive(body);
        log.log("@ls response (" + resp.length + " bytes): " + hex(resp, 128));
        if (resp.length == 0 || resp[0] != 0x00) {
            int status = resp.length > 0 ? (resp[0] & 0xFF) : -1;
            log.log("@ls failed: status=" + status);
            return null;
        }
        if (resp.length <= 1) {
            log.log("@ls: empty response");
            return null;
        }
        try {
            Object result = NngDeserializer.decode(resp, 1);
            log.log("@ls parsed: " + describeValue(result));
            return result;
        } catch (Exception e) {
            log.log("@ls parse error: " + e.getMessage());
            return null;
        }
    }

    /** Build CheckSum message: [0x05][method][path\0][vlu:0] */
    static byte[] buildCheckSum(String path, int method) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x05); // command type
        buf.write(method & 0xFF);
        byte[] fname = (path + "\0").getBytes();
        buf.write(fname, 0, fname.length);
        byte[] zero = VluCodec.encode(0);
        buf.write(zero, 0, zero.length);
        return buf.toByteArray();
    }

    /** Send CheckSum request. Returns hex string or null on error. */
    public static String checkSum(NftpConnection conn, Logger log, String path, int method) throws IOException {
        String methodName = method == 0 ? "MD5" : "SHA1";
        byte[] body = buildCheckSum(path, method);
        log.log("CheckSum " + methodName + " " + path + " (" + body.length + " bytes): " + hex(body));
        byte[] resp = conn.sendAndReceive(body);
        log.log("CheckSum response (" + resp.length + " bytes): " + hex(resp, 64));
        if (resp.length == 0 || resp[0] != 0x00) {
            int status = resp.length > 0 ? (resp[0] & 0xFF) : -1;
            log.log("CheckSum failed: status=" + status);
            return null;
        }
        byte[] hash = new byte[resp.length - 1];
        System.arraycopy(resp, 1, hash, 0, hash.length);
        String hexStr = hex(hash).replace(" ", "");
        log.log("CheckSum " + methodName + " result: " + hexStr);
        return hexStr;
    }

    /** Describe a deserialised value for logging. */
    static String describeValue(Object val) {
        if (val == null) return "null";
        if (val instanceof Object[]) {
            Object[] arr = (Object[]) val;
            StringBuilder sb = new StringBuilder("tuple[" + arr.length + "](");
            for (int i = 0; i < arr.length; i++) {
                if (i > 0) sb.append(", ");
                sb.append(describeValue(arr[i]));
                if (i >= 5) { sb.append(", ..."); break; }
            }
            sb.append(")");
            return sb.toString();
        }
        if (val instanceof java.util.Map) {
            java.util.Map<?, ?> map = (java.util.Map<?, ?>) val;
            return "dict[" + map.size() + "]" + map.keySet();
        }
        if (val instanceof byte[]) return "bytes[" + ((byte[]) val).length + "]";
        return val.getClass().getSimpleName() + "(" + val + ")";
    }

    private static String readNullTermString(InputStream in) throws IOException {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        int b;
        while ((b = in.read()) > 0) {
            buf.write(b);
        }
        return buf.toString("ASCII");
    }
}
