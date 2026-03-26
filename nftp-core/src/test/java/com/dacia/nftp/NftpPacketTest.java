package com.dacia.nftp;

import org.junit.Test;
import java.io.*;
import static org.junit.Assert.*;

public class NftpPacketTest {

    @Test
    public void testWriteAndReadRequest() throws Exception {
        byte[] data = {0x03, 0x41, 0x42, 0x00};
        NftpPacket pkt = new NftpPacket(false, false, false, 1, data);
        assertEquals(8, pkt.length);

        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        pkt.write(bout);
        NftpPacket read = NftpPacket.read(new ByteArrayInputStream(bout.toByteArray()));

        assertFalse(read.continuation);
        assertFalse(read.isResponse);
        assertFalse(read.aborted);
        assertEquals(1, read.id);
        assertArrayEquals(data, read.data);
    }

    @Test
    public void testWriteAndReadResponse() throws Exception {
        byte[] data = {0x00, 0x01, 0x02};
        NftpPacket pkt = new NftpPacket(false, true, false, 5, data);

        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        pkt.write(bout);
        NftpPacket read = NftpPacket.read(new ByteArrayInputStream(bout.toByteArray()));

        assertTrue(read.isResponse);
        assertEquals(5, read.id);
        assertArrayEquals(data, read.data);
    }

    @Test
    public void testControlPacket() throws Exception {
        NftpPacket pkt = new NftpPacket(false, false, false, NftpPacket.CONTROL_ID, new byte[]{0x01});

        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        pkt.write(bout);
        NftpPacket read = NftpPacket.read(new ByteArrayInputStream(bout.toByteArray()));

        assertTrue(read.isControl());
        assertEquals(NftpPacket.CONTROL_ID, read.id);
    }

    @Test
    public void testRoundTrip() throws Exception {
        byte[] data = new byte[100];
        for (int i = 0; i < data.length; i++) data[i] = (byte) i;
        NftpPacket pkt = new NftpPacket(false, false, false, 42, data);

        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        pkt.write(bout);
        NftpPacket read = NftpPacket.read(new ByteArrayInputStream(bout.toByteArray()));

        assertEquals(42, read.id);
        assertArrayEquals(data, read.data);
    }

    @Test
    public void testFragmentation() throws Exception {
        // Payload larger than MAX_PAYLOAD should split
        byte[] big = new byte[NftpPacket.MAX_PAYLOAD + 100];
        for (int i = 0; i < big.length; i++) big[i] = (byte) (i & 0xFF);

        var packets = NftpPacket.fragment(false, 7, big);
        assertEquals(2, packets.size());
        assertTrue(packets.get(0).continuation);
        assertFalse(packets.get(1).continuation);
        assertEquals(NftpPacket.MAX_PAYLOAD, packets.get(0).data.length);
        assertEquals(100, packets.get(1).data.length);
    }

    @Test
    public void testReassembly() throws Exception {
        byte[] big = new byte[NftpPacket.MAX_PAYLOAD + 200];
        for (int i = 0; i < big.length; i++) big[i] = (byte) (i & 0xFF);

        var packets = NftpPacket.fragment(true, 3, big);

        // Write all packets to a stream, then reassemble
        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        for (NftpPacket p : packets) p.write(bout);

        byte[] reassembled = NftpPacket.reassemble(new ByteArrayInputStream(bout.toByteArray()));
        assertArrayEquals(big, reassembled);
    }

    @Test
    public void testTransactionIdWrap() throws Exception {
        // MAX_TXN_ID is 0x3FFF = 16383
        NftpPacket pkt = new NftpPacket(false, false, false, NftpPacket.MAX_TXN_ID, new byte[]{});

        ByteArrayOutputStream bout = new ByteArrayOutputStream();
        pkt.write(bout);
        NftpPacket read = NftpPacket.read(new ByteArrayInputStream(bout.toByteArray()));
        assertEquals(NftpPacket.MAX_TXN_ID, read.id);
    }
}
