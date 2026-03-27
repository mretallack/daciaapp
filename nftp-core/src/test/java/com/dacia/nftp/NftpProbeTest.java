package com.dacia.nftp;

import org.junit.Test;
import java.io.*;
import java.util.List;
import static org.junit.Assert.*;

public class NftpProbeTest {

    /**
     * Fake NFTP server that handles Init and GetFile on a background thread.
     */
    static class FakeServer implements Runnable {
        final InputStream in;
        final OutputStream out;
        boolean failInit = false;
        boolean failGetFile = false;

        FakeServer(InputStream in, OutputStream out) {
            this.in = in;
            this.out = out;
        }

        @Override
        public void run() {
            try {
                // Read Init request
                Object[] msg = NftpPacket.readMessage(in);
                NftpPacket req = (NftpPacket) msg[0];
                byte[] body = (byte[]) msg[1];

                if (failInit) {
                    sendResponse(req.id, new byte[]{0x01}); // error
                    return;
                }

                // Reply to Init: success + version 1 + "FakeHeadUnit"
                ByteArrayOutputStream initResp = new ByteArrayOutputStream();
                initResp.write(0x00); // success
                initResp.write(VluCodec.encode(1)); // version
                initResp.write("FakeHeadUnit\0".getBytes());
                sendResponse(req.id, initResp.toByteArray());

                // Read GetFile request
                msg = NftpPacket.readMessage(in);
                req = (NftpPacket) msg[0];

                if (failGetFile) {
                    sendResponse(req.id, new byte[]{0x01}); // error
                    return;
                }

                // Reply with fake device.nng
                ByteArrayOutputStream getResp = new ByteArrayOutputStream();
                getResp.write(0x00); // success
                getResp.write("SWID=CK-TEST-FAKE-0000\n".getBytes());
                sendResponse(req.id, getResp.toByteArray());

                // Handle remaining requests (QueryInfo etc) — reply success with empty serialised data
                for (int i = 0; i < 3; i++) {
                    try {
                        msg = NftpPacket.readMessage(in);
                        req = (NftpPacket) msg[0];
                        // Success + empty tuple
                        NngSerializer ser = new NngSerializer();
                        ser.writeTuple();
                        ByteArrayOutputStream qResp = new ByteArrayOutputStream();
                        qResp.write(0x00);
                        byte[] payload = ser.toBytes();
                        qResp.write(payload, 0, payload.length);
                        sendResponse(req.id, qResp.toByteArray());
                    } catch (IOException e) {
                        break;
                    }
                }

            } catch (IOException e) {
                // Connection closed
            }
        }

        private void sendResponse(int id, byte[] data) throws IOException {
            List<NftpPacket> packets = NftpPacket.fragment(true, id, data);
            for (NftpPacket p : packets) p.write(out);
        }
    }

    @Test
    public void testSuccessfulInit() throws Exception {
        PipedInputStream clientIn = new PipedInputStream(65536);
        PipedOutputStream serverOut = new PipedOutputStream(clientIn);
        PipedInputStream serverIn = new PipedInputStream(65536);
        PipedOutputStream clientOut = new PipedOutputStream(serverIn);

        FakeServer server = new FakeServer(serverIn, serverOut);
        Thread t = new Thread(server);
        t.start();

        StringBuilder logBuf = new StringBuilder();
        NftpProbe.Result result = NftpProbe.run(clientIn, clientOut, msg -> logBuf.append(msg).append("\n"));
        t.join(2000);

        assertTrue(result.isSuccess());
        assertEquals("FakeHeadUnit", result.serverName);
        assertEquals(1, result.serverVersion);
    }

    @Test
    public void testSuccessfulGetFile() throws Exception {
        PipedInputStream clientIn = new PipedInputStream(65536);
        PipedOutputStream serverOut = new PipedOutputStream(clientIn);
        PipedInputStream serverIn = new PipedInputStream(65536);
        PipedOutputStream clientOut = new PipedOutputStream(serverIn);

        FakeServer server = new FakeServer(serverIn, serverOut);
        Thread t = new Thread(server);
        t.start();

        NftpProbe.Result result = NftpProbe.run(clientIn, clientOut, msg -> {});
        t.join(2000);

        assertTrue(result.isSuccess());
        assertNotNull(result.deviceNng);
        assertTrue(new String(result.deviceNng).contains("SWID=CK-TEST-FAKE-0000"));
    }

    @Test
    public void testGetFileError() throws Exception {
        PipedInputStream clientIn = new PipedInputStream(65536);
        PipedOutputStream serverOut = new PipedOutputStream(clientIn);
        PipedInputStream serverIn = new PipedInputStream(65536);
        PipedOutputStream clientOut = new PipedOutputStream(serverIn);

        FakeServer server = new FakeServer(serverIn, serverOut);
        server.failGetFile = true;
        Thread t = new Thread(server);
        t.start();

        NftpProbe.Result result = NftpProbe.run(clientIn, clientOut, msg -> {});
        t.join(2000);

        assertFalse(result.isSuccess());
        assertTrue(result.error.contains("GetFile failed"));
    }

    @Test
    public void testInitError() throws Exception {
        PipedInputStream clientIn = new PipedInputStream(65536);
        PipedOutputStream serverOut = new PipedOutputStream(clientIn);
        PipedInputStream serverIn = new PipedInputStream(65536);
        PipedOutputStream clientOut = new PipedOutputStream(serverIn);

        FakeServer server = new FakeServer(serverIn, serverOut);
        server.failInit = true;
        Thread t = new Thread(server);
        t.start();

        NftpProbe.Result result = NftpProbe.run(clientIn, clientOut, msg -> {});
        t.join(2000);

        assertFalse(result.isSuccess());
        assertTrue(result.error.contains("Init failed"));
    }

    @Test
    public void testFullSequence() throws Exception {
        PipedInputStream clientIn = new PipedInputStream(65536);
        PipedOutputStream serverOut = new PipedOutputStream(clientIn);
        PipedInputStream serverIn = new PipedInputStream(65536);
        PipedOutputStream clientOut = new PipedOutputStream(serverIn);

        FakeServer server = new FakeServer(serverIn, serverOut);
        Thread t = new Thread(server);
        t.start();

        StringBuilder logBuf = new StringBuilder();
        NftpProbe.Result result = NftpProbe.run(clientIn, clientOut, msg -> logBuf.append(msg).append("\n"));
        t.join(2000);

        assertTrue(result.isSuccess());
        String log = logBuf.toString();
        assertTrue(log.contains("Sending Init"));
        assertTrue(log.contains("Connected: FakeHeadUnit v1"));
        assertTrue(log.contains("Sending GetFile"));
        assertTrue(log.contains("Probe complete"));
    }
}
