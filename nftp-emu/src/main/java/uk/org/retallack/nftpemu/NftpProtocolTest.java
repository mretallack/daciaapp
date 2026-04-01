package uk.org.retallack.nftpemu;

import java.io.*;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

import uk.org.retallack.nftp.*;

/**
 * Exercises the full NFTP protocol against the Python emulator.
 * Validates Init, QueryInfo, @ls, GetFile, CheckSum, PushFile,
 * DeleteFile, Mkdir, and the full update flow.
 */
public class NftpProtocolTest {

    private static final int HEADER_SIZE = 4;
    private Socket sock;
    private OutputStream out;
    private InputStream in;
    private int nextId = 1;
    private int passed, failed;

    public static void main(String[] args) throws Exception {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 9876;
        new NftpProtocolTest().run(port);
    }

    public void run(int port) {
        System.out.println("=== NFTP Protocol Test against emulator on :" + port + " ===\n");
        try {
            testInit(port);
            testQueryInfoDevice(port);
            testQueryInfoMultiKey(port);
            testLsDirectory(port);
            testGetFile(port);
            testGetFilePartial(port);
            testCheckSum(port);
            testPushFile(port);
            testCommit(port);
            testDeleteFile(port);
            testMkdir(port);
            testFullUpdateFlow(port);
        } catch (Exception e) {
            System.out.println("FATAL: " + e.getMessage());
            e.printStackTrace();
        }
        System.out.println("\n=== Results: " + passed + " passed, " + failed + " failed ===");
    }

    // --- Individual tests ---

    private void testInit(int port) throws Exception {
        connect(port);
        try {
            byte[] resp = doInit();
            check("Init handshake", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
            String product = parseInitProduct(resp);
            check("Init product string", product.contains("FakeHeadUnit"), "got: " + product);
        } finally { close(); }
    }

    private void testQueryInfoDevice(int port) throws Exception {
        connect(port); doInit();
        try {
            byte[] resp = doQueryInfo("@device");
            check("QueryInfo @device status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
            Object parsed = NngDeserializer.decode(resp, 1);
            check("QueryInfo @device is map", parsed instanceof Map, "type=" + parsed.getClass());
            @SuppressWarnings("unchecked")
            Map<String, Object> m = (Map<String, Object>) parsed;
            // Real fields
            check("@device has modelName", "DaciaAutomotiveDeviceCY20_ULC4dot5".equals(m.get("@modelName")),
                    "got: " + m.get("@modelName"));
            // Tag 25 failures → null
            check("@device swid is null (failure)", m.get("@swid") == null, "got: " + m.get("@swid"));
            check("@device vin is null (failure)", m.get("@vin") == null, "got: " + m.get("@vin"));
            // Tag 33 failure → map with @_failure
            Object appcid = m.get("@appcid");
            check("@device appcid is failure map", appcid instanceof Map, "type=" + (appcid == null ? "null" : appcid.getClass()));
        } finally { close(); }
    }

    private void testQueryInfoMultiKey(int port) throws Exception {
        connect(port); doInit();
        try {
            byte[] resp = doQueryInfo("@device", "@brand", "@diskInfo", "@fileMapping");
            check("QueryInfo multi status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
            Object parsed = NngDeserializer.decode(resp, 1);
            check("QueryInfo multi is tuple", parsed instanceof Object[], "type=" + parsed.getClass());
            Object[] tuple = (Object[]) parsed;
            check("QueryInfo multi has 4 items", tuple.length == 4, "len=" + tuple.length);
        } finally { close(); }
    }

    private void testLsDirectory(int port) throws Exception {
        connect(port); doInit();
        try {
            // Build @ls query: tuple(@ls, "content", dict(fields -> tuple(@name, @size, @isFile)))
            NngSerializer s = new NngSerializer();
            s.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
            s.writeVlu(3);
            s.writeIdentifier("ls");
            s.writeString("content");
            s.writeDict("@fields", new Object[]{"@name", "@size", "@isFile"});
            byte[] qBody = s.toBytes();

            byte[] cmdBody = new byte[1 + qBody.length];
            cmdBody[0] = 0x04; // QueryInfo
            System.arraycopy(qBody, 0, cmdBody, 1, qBody.length);
            byte[] resp = sendAndReceive(cmdBody);

            check("@ls content status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
            Object parsed = NngDeserializer.decode(resp, 1);
            check("@ls content is tuple", parsed instanceof Object[], "type=" + parsed.getClass());
            System.out.println("    @ls parsed: " + summarize(parsed));
        } finally { close(); }
    }

    private void testGetFile(int port) throws Exception {
        connect(port); doInit();
        try {
            byte[] resp = doGetFile("license/device.nng", 0, 0);
            check("GetFile device.nng status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
            String content = new String(resp, 1, resp.length - 1, StandardCharsets.UTF_8);
            check("GetFile device.nng has SWID", content.contains("SWID"), "content=" + content.substring(0, Math.min(50, content.length())));
        } finally { close(); }
    }

    private void testGetFilePartial(int port) throws Exception {
        connect(port); doInit();
        try {
            byte[] resp = doGetFile("license/device.nng", 0, 10);
            check("GetFile partial status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
            check("GetFile partial length", resp.length - 1 == 10, "got " + (resp.length - 1) + " bytes");
        } finally { close(); }
    }

    private void testCheckSum(int port) throws Exception {
        connect(port); doInit();
        try {
            // MD5
            byte[] resp = doCheckSum("license/device.nng", 0);
            check("CheckSum MD5 status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
            check("CheckSum MD5 length", resp.length - 1 == 16, "got " + (resp.length - 1) + " bytes");

            // Verify against local hash of the file content
            byte[] fileResp = doGetFile("license/device.nng", 0, 0);
            byte[] fileData = new byte[fileResp.length - 1];
            System.arraycopy(fileResp, 1, fileData, 0, fileData.length);
            byte[] localMd5 = MessageDigest.getInstance("MD5").digest(fileData);
            byte[] remoteMd5 = new byte[16];
            System.arraycopy(resp, 1, remoteMd5, 0, 16);
            check("CheckSum MD5 matches GetFile", java.util.Arrays.equals(localMd5, remoteMd5),
                    "local=" + hex(localMd5) + " remote=" + hex(remoteMd5));
        } finally { close(); }
    }

    private void testPushFile(int port) throws Exception {
        connect(port); doInit();
        try {
            byte[] content = "hello from nftp-emu".getBytes(StandardCharsets.UTF_8);
            byte[] resp = doPushFile("test/pushed.txt", content, 0x01); // truncate
            check("PushFile status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));

            // Verify via GetFile
            byte[] getResp = doGetFile("test/pushed.txt", 0, 0);
            check("PushFile verify status", getResp[0] == 0x00, "status=" + (getResp[0] & 0xFF));
            String got = new String(getResp, 1, getResp.length - 1, StandardCharsets.UTF_8);
            check("PushFile verify content", got.equals("hello from nftp-emu"), "got: " + got);
        } finally { close(); }
    }


    private void testCommit(int port) throws Exception {
        connect(port); doInit();
        try {
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            b.write(0x02); // Commit
            b.write("test/committed.txt".getBytes(StandardCharsets.US_ASCII));
            b.write(0x00);
            byte[] resp = sendAndReceive(b.toByteArray());
            check("Commit status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
        } finally { close(); }
    }

    private void testDeleteFile(int port) throws Exception {
        connect(port); doInit();
        try {
            // Push a file, then delete it
            doPushFile("test/todelete.txt", "delete me".getBytes(), 0x01);
            byte[] resp = doDeleteFile("test/todelete.txt");
            check("DeleteFile status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));

            // Verify it's gone
            byte[] getResp = doGetFile("test/todelete.txt", 0, 0);
            check("DeleteFile verify gone", getResp[0] != 0x00, "file still exists");
        } finally { close(); }
    }

    private void testMkdir(int port) throws Exception {
        connect(port); doInit();
        try {
            byte[] resp = doMkdir("test/newdir");
            check("Mkdir status", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));
        } finally { close(); }
    }

    private void testFullUpdateFlow(int port) throws Exception {
        connect(port); doInit();
        try {
            // 1. PrepareForTransfer
            byte[] resp = sendAndReceive(new byte[]{0x0A}); // cmd 10
            check("PrepareForTransfer", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));

            // 2. Push a file
            byte[] mapData = "FAKE-MAP-UPDATE-DATA".getBytes();
            doPushFile("content/map/update.fbl", mapData, 0x01);

            // 3. CheckSum to verify
            byte[] csResp = doCheckSum("content/map/update.fbl", 0);
            check("Update CheckSum status", csResp[0] == 0x00, "status=" + (csResp[0] & 0xFF));

            // 4. TransferFinished
            resp = sendAndReceive(new byte[]{0x0B}); // cmd 11
            check("TransferFinished", resp[0] == 0x00, "status=" + (resp[0] & 0xFF));

            // 5. Verify file persists
            byte[] getResp = doGetFile("content/map/update.fbl", 0, 0);
            check("Update file persists", getResp[0] == 0x00, "status=" + (getResp[0] & 0xFF));
            String got = new String(getResp, 1, getResp.length - 1, StandardCharsets.UTF_8);
            check("Update file content", got.equals("FAKE-MAP-UPDATE-DATA"), "got: " + got);
        } finally { close(); }
    }

    // --- Protocol helpers ---

    private void connect(int port) throws Exception {
        sock = new Socket();
        sock.connect(new InetSocketAddress("127.0.0.1", port), 2000);
        sock.setSoTimeout(5000);
        out = sock.getOutputStream();
        in = sock.getInputStream();
        nextId = 1;
    }

    private void close() {
        try { if (sock != null) sock.close(); } catch (Exception e) {}
    }

    private byte[] doInit() throws Exception {
        byte[] body = new byte[]{0x00, 0x01, 'N','f','t','p','E','m','u','/','1','.','0','\0'};
        return sendAndReceive(body);
    }

    private String parseInitProduct(byte[] resp) {
        int pos = 1;
        while (pos < resp.length && (resp[pos] & 0x80) != 0) pos++;
        pos++;
        return new String(resp, pos, resp.length - pos, StandardCharsets.UTF_8).replace("\0", "");
    }

    private byte[] doQueryInfo(String... keys) throws Exception {
        NngSerializer s = new NngSerializer();
        s.writeTuple((Object[]) keys);
        byte[] qBody = s.toBytes();
        byte[] cmdBody = new byte[1 + qBody.length];
        cmdBody[0] = 0x04;
        System.arraycopy(qBody, 0, cmdBody, 1, qBody.length);
        return sendAndReceive(cmdBody);
    }

    private byte[] doGetFile(String path, int offset, int length) throws Exception {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        b.write(0x03);
        b.write(path.getBytes(StandardCharsets.US_ASCII));
        b.write(0x00);
        b.write(VluCodec.encode(offset));
        if (length > 0) b.write(VluCodec.encode(length));
        return sendAndReceive(b.toByteArray());
    }

    private byte[] doCheckSum(String path, int method) throws Exception {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        b.write(0x05);
        b.write(method);
        b.write(path.getBytes(StandardCharsets.US_ASCII));
        b.write(0x00);
        return sendAndReceive(b.toByteArray());
    }

    private byte[] doPushFile(String path, byte[] content, int options) throws Exception {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        b.write(0x01);
        b.write(path.getBytes(StandardCharsets.US_ASCII));
        b.write(0x00);
        b.write(0x01); // extra_len = 1 (options follows)
        b.write(VluCodec.encode(options));
        b.write(content);
        return sendAndReceive(b.toByteArray());
    }

    private byte[] doDeleteFile(String path) throws Exception {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        b.write(0x06);
        b.write(path.getBytes(StandardCharsets.US_ASCII));
        b.write(0x00);
        b.write(0x00); // non-recursive
        return sendAndReceive(b.toByteArray());
    }

    private byte[] doMkdir(String path) throws Exception {
        ByteArrayOutputStream b = new ByteArrayOutputStream();
        b.write(0x0C);
        b.write(path.getBytes(StandardCharsets.US_ASCII));
        b.write(0x00);
        return sendAndReceive(b.toByteArray());
    }

    private byte[] sendAndReceive(byte[] body) throws Exception {
        int id = nextId++;
        sendPacket(id, body);
        return readResponse();
    }

    private void sendPacket(int pktId, byte[] body) throws Exception {
        int totalLen = HEADER_SIZE + body.length;
        int w0 = totalLen & 0x7FFF;
        int w1 = pktId & 0x3FFF;
        byte[] frame = new byte[HEADER_SIZE + body.length];
        frame[0] = (byte)(w0 & 0xFF); frame[1] = (byte)((w0 >> 8) & 0xFF);
        frame[2] = (byte)(w1 & 0xFF); frame[3] = (byte)((w1 >> 8) & 0xFF);
        System.arraycopy(body, 0, frame, HEADER_SIZE, body.length);
        out.write(frame);
        out.flush();
    }

    private byte[] readResponse() throws Exception {
        ByteArrayOutputStream parts = new ByteArrayOutputStream();
        boolean more;
        do {
            byte[] hdr = readExact(HEADER_SIZE);
            int w0 = (hdr[0] & 0xFF) | ((hdr[1] & 0xFF) << 8);
            more = (w0 & 0x8000) != 0;
            int len = (w0 & 0x7FFF) - HEADER_SIZE;
            if (len > 0) parts.write(readExact(len));
        } while (more);
        return parts.toByteArray();
    }

    private byte[] readExact(int n) throws Exception {
        byte[] buf = new byte[n];
        int off = 0;
        while (off < n) {
            int r = in.read(buf, off, n - off);
            if (r < 0) throw new IOException("Connection closed");
            off += r;
        }
        return buf;
    }

    // --- Helpers ---

    private void check(String name, boolean condition, String detail) {
        if (condition) {
            System.out.println("  ✓ " + name);
            passed++;
        } else {
            System.out.println("  ✗ " + name + " — " + detail);
            failed++;
        }
    }

    private static String hex(byte[] data) {
        StringBuilder sb = new StringBuilder();
        for (byte b : data) sb.append(String.format("%02x", b & 0xFF));
        return sb.toString();
    }

    private static String summarize(Object obj) {
        if (obj instanceof Object[]) {
            Object[] arr = (Object[]) obj;
            return "tuple[" + arr.length + "]";
        } else if (obj instanceof Map) {
            return "dict[" + ((Map<?,?>) obj).size() + "]";
        }
        return String.valueOf(obj);
    }
}
