package com.dacia.nftp;

import org.junit.Test;
import java.io.*;
import java.util.List;
import java.util.Map;
import static org.junit.Assert.*;

public class HeadUnitExplorerTest {

    /** Fake server that handles Init, GetFile, CheckSum, and QueryInfo. */
    static class FakeServer implements Runnable {
        final InputStream in;
        final OutputStream out;

        FakeServer(InputStream in, OutputStream out) { this.in = in; this.out = out; }

        @Override
        public void run() {
            try {
                while (true) {
                    Object[] msg = NftpPacket.readMessage(in);
                    NftpPacket req = (NftpPacket) msg[0];
                    byte[] body = (byte[]) msg[1];
                    if (body.length == 0) { sendResponse(req.id, new byte[]{0x7F}); continue; }

                    int cmd = body[0] & 0xFF;
                    switch (cmd) {
                        case 0x00: handleInit(req.id); break;
                        case 0x03: handleGetFile(req.id, body); break;
                        case 0x04: handleQueryInfo(req.id, body); break;
                        case 0x05: handleCheckSum(req.id, body); break;
                        default: sendResponse(req.id, new byte[]{0x7F}); break;
                    }
                }
            } catch (IOException e) { /* closed */ }
        }

        void handleInit(int id) throws IOException {
            ByteArrayOutputStream r = new ByteArrayOutputStream();
            r.write(0x00);
            r.write(VluCodec.encode(1));
            r.write("FakeHeadUnit\0".getBytes());
            sendResponse(id, r.toByteArray());
        }

        void handleGetFile(int id, byte[] body) throws IOException {
            int end = 1;
            while (end < body.length && body[end] != 0) end++;
            String path = new String(body, 1, end - 1, "ASCII");

            ByteArrayOutputStream r = new ByteArrayOutputStream();
            if ("license/device.nng".equals(path)) {
                r.write(0x00);
                r.write("FAKE-DEVICE-NNG-DATA".getBytes());
            } else if ("license/test.lyc".equals(path)) {
                r.write(0x00);
                r.write(new byte[]{0x01, 0x02, 0x03, 0x04});
            } else {
                r.write(0x01);
                r.write("EACCESS".getBytes());
            }
            sendResponse(id, r.toByteArray());
        }

        void handleQueryInfo(int id, byte[] body) throws IOException {
            // Parse the query to figure out what's being asked
            NngDeserializer des = new NngDeserializer(body, 1);
            Object query = des.readValue();

            ByteArrayOutputStream r = new ByteArrayOutputStream();
            r.write(0x00); // success

            // Check if it's an @ls query (tuple starting with @ls)
            if (query instanceof Object[]) {
                Object[] tuple = (Object[]) query;
                if (tuple.length >= 1 && "@ls".equals(tuple[0])) {
                    // Return a fake @ls response: (name, size, isFile, child1, child2)
                    NngSerializer ser = new NngSerializer();
                    // Root tuple: ("root", 0, false, ("file1.txt", 100, true), ("subdir", 0, false))
                    ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN);
                    ser.writeVlu(5); // name, size, isFile, child1, child2
                    ser.writeString("root");
                    ser.writeTag(NngSerializer.TAG_INT32_VLI); ser.writeVli(0);
                    ser.writeTag(NngSerializer.TAG_INT32_VLI); ser.writeVli(0); // isFile=false
                    // child1: file
                    ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN); ser.writeVlu(3);
                    ser.writeString("file1.txt");
                    ser.writeTag(NngSerializer.TAG_INT32_VLI); ser.writeVli(100);
                    ser.writeTag(NngSerializer.TAG_INT32_VLI); ser.writeVli(1); // isFile=true
                    // child2: dir
                    ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN); ser.writeVlu(3);
                    ser.writeString("subdir");
                    ser.writeTag(NngSerializer.TAG_INT32_VLI); ser.writeVli(0);
                    ser.writeTag(NngSerializer.TAG_INT32_VLI); ser.writeVli(0); // isFile=false
                    r.write(ser.toBytes());
                    sendResponse(id, r.toByteArray());
                    return;
                }

                // Multi-key query — check for known keys
                boolean hasDevice = false, hasBrand = false;
                for (Object item : tuple) {
                    String s = String.valueOf(item);
                    if ("@device".equals(s)) hasDevice = true;
                    if ("@brand".equals(s)) hasBrand = true;
                }
                if (hasDevice && hasBrand) {
                    NngSerializer ser = new NngSerializer();
                    ser.writeTag(NngSerializer.TAG_TUPLE_VLI_LEN); ser.writeVlu(2);
                    // @device dict
                    ser.writeDict("@swid", "TEST-SWID", "@vin", "TEST-VIN",
                                  "@igoVersion", "1.2.3", "@appcid", "TEST-APP");
                    // @brand dict
                    ser.writeDict("@agentBrand", "TestBrand", "@modelName", "TestModel",
                                  "@brandName", "TestBrandName");
                    r.write(ser.toBytes());
                    sendResponse(id, r.toByteArray());
                    return;
                }

                // Single key queries
                for (Object item : tuple) {
                    String s = String.valueOf(item);
                    if ("@fileMapping".equals(s)) {
                        NngSerializer ser = new NngSerializer();
                        ser.writeDict("device.nng", "license/", ".fbl", "content/map/");
                        r.write(ser.toBytes());
                        sendResponse(id, r.toByteArray());
                        return;
                    }
                    if ("@diskInfo".equals(s)) {
                        NngSerializer ser = new NngSerializer();
                        ser.writeDict("@available", 4000000000L, "@size", 8000000000L);
                        r.write(ser.toBytes());
                        sendResponse(id, r.toByteArray());
                        return;
                    }
                }
            }

            // Unknown query — return undef
            r.write(0x00); // TAG_UNDEF
            sendResponse(id, r.toByteArray());
        }

        void handleCheckSum(int id, byte[] body) throws IOException {
            int method = body[1] & 0xFF;
            ByteArrayOutputStream r = new ByteArrayOutputStream();
            r.write(0x00);
            int len = method == 0 ? 16 : 20;
            for (int i = 0; i < len; i++) r.write(0xAA + i);
            sendResponse(id, r.toByteArray());
        }

        void sendResponse(int id, byte[] data) throws IOException {
            for (NftpPacket p : NftpPacket.fragment(true, id, data)) p.write(out);
        }
    }

    private HeadUnitExplorer connectToFake() throws Exception {
        PipedInputStream clientIn = new PipedInputStream(65536);
        PipedOutputStream serverOut = new PipedOutputStream(clientIn);
        PipedInputStream serverIn = new PipedInputStream(65536);
        PipedOutputStream clientOut = new PipedOutputStream(serverIn);

        Thread t = new Thread(new FakeServer(serverIn, serverOut));
        t.setDaemon(true);
        t.start();

        HeadUnitExplorer explorer = new HeadUnitExplorer();
        explorer.connect(clientIn, clientOut, msg -> {});
        return explorer;
    }

    @Test
    public void testConnectAndInit() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        assertTrue(explorer.isConnected());
        assertEquals("FakeHeadUnit", explorer.getServerName());
        assertEquals(1, explorer.getServerVersion());
        assertNotNull(explorer.getDeviceNng());
    }

    @Test
    public void testDeviceInfo() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        HeadUnitExplorer.DeviceInfo info = explorer.getDeviceInfo();
        assertNotNull(info);
        assertEquals("TEST-SWID", info.swid);
        assertEquals("TEST-VIN", info.vin);
        assertEquals("1.2.3", info.igoVersion);
        assertEquals("TEST-APP", info.appcid);
        assertEquals("TestBrand", info.agentBrand);
        assertEquals("TestModel", info.modelName);
    }

    @Test
    public void testDiskInfo() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        HeadUnitExplorer.DiskInfo di = explorer.getDiskInfo();
        assertNotNull(di);
        assertEquals(4000000000L, di.available);
        assertEquals(8000000000L, di.size);
    }

    @Test
    public void testFileMapping() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        Map<String, String> fm = explorer.getFileMapping();
        assertNotNull(fm);
        assertEquals("license/", fm.get("device.nng"));
        assertEquals("content/map/", fm.get(".fbl"));
    }

    @Test
    public void testListDirectory() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        List<HeadUnitExplorer.FileEntry> entries = explorer.listDirectory("/");
        assertNotNull(entries);
        assertEquals(2, entries.size());
        // file1.txt
        HeadUnitExplorer.FileEntry f = entries.get(0);
        assertEquals("file1.txt", f.name);
        assertFalse(f.isDir);
        assertEquals(100, f.size);
        // subdir
        HeadUnitExplorer.FileEntry d = entries.get(1);
        assertEquals("subdir", d.name);
        assertTrue(d.isDir);
    }

    @Test
    public void testReadFile() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        byte[] data = explorer.readFile("license/test.lyc");
        assertArrayEquals(new byte[]{0x01, 0x02, 0x03, 0x04}, data);
    }

    @Test
    public void testReadFileError() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        try {
            explorer.readFile("nonexistent/file.txt");
            fail("Expected IOException");
        } catch (IOException e) {
            assertTrue(e.getMessage().contains("EACCESS"));
        }
    }

    @Test
    public void testGetChecksum() throws Exception {
        HeadUnitExplorer explorer = connectToFake();
        String md5 = explorer.getChecksum("license/device.nng", 0);
        assertNotNull(md5);
        assertEquals(32, md5.length());
    }

    @Test
    public void testNotConnected() {
        HeadUnitExplorer explorer = new HeadUnitExplorer();
        assertFalse(explorer.isConnected());
        try {
            explorer.readFile("test");
            fail("Expected IOException");
        } catch (IOException e) {
            assertTrue(e.getMessage().contains("Not connected"));
        }
    }

    @Test
    public void testDirectoryTree() {
        List<HeadUnitExplorer.FileEntry> tree = HeadUnitExplorer.getDirectoryTree();
        assertTrue(tree.size() >= 5);
        assertTrue(tree.get(0).isDir);
        assertEquals("license", tree.get(0).name);
    }

    @Test
    public void testDefaultFileMapping() {
        var map = HeadUnitExplorer.getDefaultFileMapping();
        assertEquals("license/", map.get("device.nng"));
        assertEquals("content/map/", map.get(".fbl"));
        assertEquals("content/poi/", map.get(".poi"));
    }
}
