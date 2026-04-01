package uk.org.retallack.nftp;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.ByteArrayOutputStream;
import java.util.List;

/**
 * NFTP request/response connection over any InputStream/OutputStream pair.
 * Handles transaction ID management, fragmentation, and buffered reads.
 *
 * USB AOA delivers data in bulk transfers — you can't request exact byte counts.
 * This class buffers incoming data and parses NFTP packets from the buffer,
 * matching how the official app's nftp.xs msgExtractor works.
 */
public class NftpConnection {

    private final InputStream in;
    private final OutputStream out;
    private int nextId = 1;

    // Read buffer for USB bulk transfers
    private byte[] readBuf = new byte[64 * 1024];
    private int readPos = 0;
    private int readLen = 0;

    public NftpConnection(InputStream in, OutputStream out) {
        this.in = in;
        this.out = out;
    }

    /** Send a request, returns the transaction ID used. */
    public synchronized int sendRequest(byte[] body) throws IOException {
        int id = nextId;
        nextId = (nextId >= NftpPacket.MAX_TXN_ID) ? 1 : nextId + 1;
        List<NftpPacket> packets = NftpPacket.fragment(false, id, body);
        for (NftpPacket pkt : packets) {
            pkt.write(out);
        }
        return id;
    }

    /** Read the next packet from the buffered stream. */
    private NftpPacket readPacket() throws IOException {
        while (true) {
            // Try to parse a packet from what we have
            if (readLen - readPos >= NftpPacket.HEADER_SIZE) {
                int word0 = (readBuf[readPos] & 0xFF) | ((readBuf[readPos + 1] & 0xFF) << 8);
                int pktLen = word0 & 0x7FFF;
                if (readLen - readPos >= pktLen) {
                    // Full packet available — parse it
                    int word1 = (readBuf[readPos + 2] & 0xFF) | ((readBuf[readPos + 3] & 0xFF) << 8);
                    boolean continuation = (word0 & 0x8000) != 0;
                    boolean isResponse;
                    boolean aborted;
                    int id;
                    if (word1 == NftpPacket.CONTROL_ID) {
                        isResponse = false;
                        aborted = false;
                        id = NftpPacket.CONTROL_ID;
                    } else {
                        isResponse = (word1 & 0x8000) != 0;
                        aborted = (word1 & 0x4000) != 0;
                        id = word1 & NftpPacket.MAX_TXN_ID;
                    }
                    int dataLen = pktLen - NftpPacket.HEADER_SIZE;
                    byte[] data = new byte[dataLen];
                    System.arraycopy(readBuf, readPos + NftpPacket.HEADER_SIZE, data, 0, dataLen);
                    readPos += pktLen;
                    // Compact buffer
                    if (readPos > 0) {
                        System.arraycopy(readBuf, readPos, readBuf, 0, readLen - readPos);
                        readLen -= readPos;
                        readPos = 0;
                    }
                    return new NftpPacket(continuation, isResponse, aborted, id, data);
                }
            }
            // Need more data — read a chunk from USB
            int space = readBuf.length - readLen;
            if (space == 0) throw new IOException("Read buffer full — packet too large");
            int n = in.read(readBuf, readLen, space);
            if (n < 0) throw new IOException("Unexpected end of stream");
            readLen += n;
        }
    }

    /** Read the next response, reassembling fragments. Returns the full payload. */
    public byte[] readResponse() throws IOException {
        ByteArrayOutputStream buf = null;
        NftpPacket first = null;
        while (true) {
            NftpPacket pkt = readPacket();
            if (first == null) {
                first = pkt;
                if (!first.isResponse) {
                    throw new IOException("Expected response but got request (id=" + first.id + ")");
                }
                if (!pkt.continuation) return pkt.data;
                buf = new ByteArrayOutputStream();
            }
            buf.write(pkt.data);
            if (!pkt.continuation) return buf.toByteArray();
        }
    }

    /** Send a request and read the response. Returns the full response payload. */
    public byte[] sendAndReceive(byte[] body) throws IOException {
        sendRequest(body);
        return readResponse();
    }

    public int getNextId() {
        return nextId;
    }
}
