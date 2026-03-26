package com.dacia.nftp;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * NFTP packet framing.
 *
 * 4-byte header (little-endian):
 *   bytes 0-1: bits 0-14 = length (incl header), bit 15 = continuation
 *   bytes 2-3: 0xC000 = control; else bit 15 = response, bit 14 = aborted, bits 0-13 = txn ID
 */
public class NftpPacket {

    public static final int HEADER_SIZE = 4;
    public static final int MAX_PACKET_SIZE = 0x7FFF;
    public static final int MAX_PAYLOAD = MAX_PACKET_SIZE - HEADER_SIZE;
    public static final int CONTROL_ID = 0xC000;
    public static final int MAX_TXN_ID = 0x3FFF;

    public final int length;
    public final boolean continuation;
    public final boolean isResponse;
    public final boolean aborted;
    public final int id;
    public final byte[] data;

    public NftpPacket(boolean continuation, boolean isResponse, boolean aborted, int id, byte[] data) {
        this.continuation = continuation;
        this.isResponse = isResponse;
        this.aborted = aborted;
        this.id = id;
        this.data = data;
        this.length = HEADER_SIZE + data.length;
    }

    public boolean isControl() {
        return id == CONTROL_ID;
    }

    public void write(OutputStream out) throws IOException {
        int word0 = length & 0x7FFF;
        if (continuation) word0 |= 0x8000;

        int word1;
        if (isControl()) {
            word1 = CONTROL_ID;
        } else {
            word1 = id & MAX_TXN_ID;
            if (isResponse) word1 |= 0x8000;
            if (aborted) word1 |= 0x4000;
        }

        out.write(word0 & 0xFF);
        out.write((word0 >> 8) & 0xFF);
        out.write(word1 & 0xFF);
        out.write((word1 >> 8) & 0xFF);
        out.write(data);
        out.flush();
    }

    public static NftpPacket read(InputStream in) throws IOException {
        byte[] hdr = readExact(in, HEADER_SIZE);
        int word0 = (hdr[0] & 0xFF) | ((hdr[1] & 0xFF) << 8);
        int word1 = (hdr[2] & 0xFF) | ((hdr[3] & 0xFF) << 8);

        int length = word0 & 0x7FFF;
        boolean continuation = (word0 & 0x8000) != 0;

        boolean isResponse;
        boolean aborted;
        int id;

        if (word1 == CONTROL_ID) {
            isResponse = false;
            aborted = false;
            id = CONTROL_ID;
        } else {
            isResponse = (word1 & 0x8000) != 0;
            aborted = (word1 & 0x4000) != 0;
            id = word1 & MAX_TXN_ID;
        }

        int dataLen = length - HEADER_SIZE;
        byte[] data = (dataLen > 0) ? readExact(in, dataLen) : new byte[0];
        return new NftpPacket(continuation, isResponse, aborted, id, data);
    }

    /** Fragment a payload into one or more packets. */
    public static List<NftpPacket> fragment(boolean isResponse, int id, byte[] payload) {
        List<NftpPacket> packets = new ArrayList<>();
        int offset = 0;
        while (offset < payload.length) {
            int chunkLen = Math.min(MAX_PAYLOAD, payload.length - offset);
            byte[] chunk = new byte[chunkLen];
            System.arraycopy(payload, offset, chunk, 0, chunkLen);
            offset += chunkLen;
            boolean more = offset < payload.length;
            packets.add(new NftpPacket(more, isResponse, false, id, chunk));
        }
        if (packets.isEmpty()) {
            packets.add(new NftpPacket(false, isResponse, false, id, new byte[0]));
        }
        return packets;
    }

    /** Read and reassemble a full message (handling continuation packets). */
    public static byte[] reassemble(InputStream in) throws IOException {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        NftpPacket pkt;
        do {
            pkt = read(in);
            buf.write(pkt.data);
        } while (pkt.continuation);
        return buf.toByteArray();
    }

    /** Read the first packet, then reassemble if continuation. Returns {firstPacket, fullPayload}. */
    public static Object[] readMessage(InputStream in) throws IOException {
        NftpPacket first = read(in);
        if (!first.continuation) {
            return new Object[]{first, first.data};
        }
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(first.data);
        NftpPacket pkt = first;
        while (pkt.continuation) {
            pkt = read(in);
            buf.write(pkt.data);
        }
        return new Object[]{first, buf.toByteArray()};
    }

    private static byte[] readExact(InputStream in, int n) throws IOException {
        byte[] buf = new byte[n];
        int off = 0;
        while (off < n) {
            int r = in.read(buf, off, n - off);
            if (r < 0) throw new IOException("Unexpected end of stream");
            off += r;
        }
        return buf;
    }
}
