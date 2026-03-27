package com.dacia.nftp;

import org.junit.Test;
import java.io.*;
import java.util.List;
import static org.junit.Assert.*;

public class HeadUnitExplorerTest {

    /** Fake server that handles Init, GetFile, and CheckSum. */
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
            // Extract path from body[1..] up to null
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
                r.write(0x01); // Failed
                r.write("EACCESS".getBytes());
            }
            sendResponse(id, r.toByteArray());
        }

        void handleCheckSum(int id, byte[] body) throws IOException {
            int method = body[1] & 0xFF;
            ByteArrayOutputStream r = new ByteArrayOutputStream();
            r.write(0x00);
            // Fake hash: 16 bytes for MD5, 20 for SHA1
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
        assertEquals(32, md5.length()); // 16 bytes = 32 hex chars
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
