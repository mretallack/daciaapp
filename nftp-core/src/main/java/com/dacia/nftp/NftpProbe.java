package com.dacia.nftp;

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

            // Sparse scan to find which ID range has valid symbols
            // Previous scans found nothing in 0-5000 or 100000-101000
            // Try: 0-200000 in steps of 1000, then narrow down on hits
            log.log("Sparse scan: 0-200000 step 1000...");
            int foundCount = 0;
            java.util.List<Integer> hitRanges = new java.util.ArrayList<>();
            for (int symId = 0; symId <= 200000; symId += 1000) {
                byte[] qBody = buildQueryInfoBySymbolId(symId);
                byte[] qResp = conn.sendAndReceive(qBody);
                boolean isUnknown = qResp.length == 12;
                if (!isUnknown) {
                    log.log("*** HIT ID " + symId + " len=" + qResp.length + ": " + hex(qResp, 64));
                    hitRanges.add(symId);
                    foundCount++;
                }
                if (symId % 10000 == 0) log.log("  sparse: " + symId);
            }
            log.log("Sparse scan done. Hits: " + foundCount);

            // If we found hits, do a dense scan around each hit range
            for (int base : hitRanges) {
                int from = Math.max(0, base - 1000);
                int to = base + 1000;
                log.log("Dense scan " + from + "-" + to + "...");
                for (int symId = from; symId <= to; symId++) {
                    byte[] qBody = buildQueryInfoBySymbolId(symId);
                    byte[] qResp = conn.sendAndReceive(qBody);
                    if (qResp.length != 12) {
                        log.log("*** HIT ID " + symId + " len=" + qResp.length + ": " + hex(qResp, 128));
                    }
                }
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
