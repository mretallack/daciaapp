package uk.org.retallack.nftp;

import org.junit.Test;
import java.io.*;
import java.util.List;
import static org.junit.Assert.*;

public class NftpConnectionTest {

    @Test
    public void testSendRequest() throws Exception {
        PipedInputStream clientReads = new PipedInputStream();
        PipedOutputStream serverWrites = new PipedOutputStream(clientReads);
        PipedInputStream serverReads = new PipedInputStream();
        PipedOutputStream clientWrites = new PipedOutputStream(serverReads);

        NftpConnection conn = new NftpConnection(clientReads, clientWrites);

        byte[] body = {0x00, 0x01, 0x02};
        int id = conn.sendRequest(body);
        assertEquals(1, id);

        // Read what was sent from the server side
        NftpPacket pkt = NftpPacket.read(serverReads);
        assertFalse(pkt.isResponse);
        assertEquals(1, pkt.id);
        assertArrayEquals(body, pkt.data);
    }

    @Test
    public void testReadResponse() throws Exception {
        PipedInputStream clientReads = new PipedInputStream();
        PipedOutputStream serverWrites = new PipedOutputStream(clientReads);

        NftpConnection conn = new NftpConnection(clientReads, new ByteArrayOutputStream());

        // Server sends a response
        byte[] respData = {0x00, 0x41, 0x42};
        NftpPacket resp = new NftpPacket(false, true, false, 1, respData);
        resp.write(serverWrites);

        byte[] payload = conn.readResponse();
        assertArrayEquals(respData, payload);
    }

    @Test
    public void testReadFragmentedResponse() throws Exception {
        PipedInputStream clientReads = new PipedInputStream(65536);
        PipedOutputStream serverWrites = new PipedOutputStream(clientReads);

        NftpConnection conn = new NftpConnection(clientReads, new ByteArrayOutputStream());

        // Build a large response and fragment it
        byte[] big = new byte[NftpPacket.MAX_PAYLOAD + 500];
        for (int i = 0; i < big.length; i++) big[i] = (byte) (i & 0xFF);

        List<NftpPacket> packets = NftpPacket.fragment(true, 1, big);
        for (NftpPacket p : packets) p.write(serverWrites);

        byte[] payload = conn.readResponse();
        assertArrayEquals(big, payload);
    }

    @Test
    public void testTransactionIdIncrements() throws Exception {
        NftpConnection conn = new NftpConnection(
            new ByteArrayInputStream(new byte[0]),
            new ByteArrayOutputStream()
        );

        assertEquals(1, conn.getNextId());
        conn.sendRequest(new byte[]{0x00});
        assertEquals(2, conn.getNextId());
        conn.sendRequest(new byte[]{0x00});
        assertEquals(3, conn.getNextId());
    }

    @Test
    public void testErrorResponse() throws Exception {
        PipedInputStream clientReads = new PipedInputStream();
        PipedOutputStream serverWrites = new PipedOutputStream(clientReads);

        NftpConnection conn = new NftpConnection(clientReads, new ByteArrayOutputStream());

        // Server sends error response (status byte != 0)
        byte[] errData = {0x01, 0x45, 0x52, 0x52};
        NftpPacket resp = new NftpPacket(false, true, false, 1, errData);
        resp.write(serverWrites);

        byte[] payload = conn.readResponse();
        assertEquals(0x01, payload[0] & 0xFF); // error status
    }
}
