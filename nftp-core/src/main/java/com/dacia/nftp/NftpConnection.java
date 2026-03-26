package com.dacia.nftp;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.List;

/**
 * NFTP request/response connection over any InputStream/OutputStream pair.
 * Handles transaction ID management and fragmentation.
 */
public class NftpConnection {

    private final InputStream in;
    private final OutputStream out;
    private int nextId = 1;

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

    /** Read the next response, reassembling fragments. Returns the full payload. */
    public byte[] readResponse() throws IOException {
        Object[] msg = NftpPacket.readMessage(in);
        NftpPacket first = (NftpPacket) msg[0];
        byte[] payload = (byte[]) msg[1];
        if (!first.isResponse) {
            throw new IOException("Expected response but got request (id=" + first.id + ")");
        }
        return payload;
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
