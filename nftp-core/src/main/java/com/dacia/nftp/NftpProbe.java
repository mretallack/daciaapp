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
            log.log("Sending Init...");
            byte[] initBody = buildInit();
            byte[] initResp = conn.sendAndReceive(initBody);

            if (initResp.length == 0 || initResp[0] != 0x00) {
                int status = initResp.length > 0 ? (initResp[0] & 0xFF) : -1;
                log.log("Init failed: status=" + status);
                return Result.failure("Init failed: status=" + status);
            }

            ByteArrayInputStream respIn = new ByteArrayInputStream(initResp, 1, initResp.length - 1);
            int serverVersion = (int) VluCodec.decode(respIn);
            String serverName = readNullTermString(respIn);
            log.log("Connected: " + serverName + " v" + serverVersion);

            // GetFile device.nng
            log.log("Requesting device.nng...");
            byte[] getBody = buildGetFile("device.nng");
            byte[] getResp = conn.sendAndReceive(getBody);

            if (getResp.length == 0 || getResp[0] != 0x00) {
                int status = getResp.length > 0 ? (getResp[0] & 0xFF) : -1;
                log.log("GetFile failed: status=" + status);
                return Result.failure("GetFile failed: status=" + status);
            }

            byte[] fileData = new byte[getResp.length - 1];
            System.arraycopy(getResp, 1, fileData, 0, fileData.length);
            log.log("Got device.nng: " + fileData.length + " bytes");
            log.log("Probe complete");

            return Result.success(serverName, serverVersion, fileData);

        } catch (IOException e) {
            log.log("Error: " + e.getMessage());
            return Result.failure(e.getMessage());
        }
    }

    /** Build Init message: [0x00][vlu:1][string:"NftpProbe\0"] */
    static byte[] buildInit() {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        buf.write(0x00); // command type
        byte[] version = VluCodec.encode(1);
        buf.write(version, 0, version.length);
        byte[] name = "NftpProbe\0".getBytes();
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

    private static String readNullTermString(InputStream in) throws IOException {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        int b;
        while ((b = in.read()) > 0) {
            buf.write(b);
        }
        return buf.toString("ASCII");
    }
}
