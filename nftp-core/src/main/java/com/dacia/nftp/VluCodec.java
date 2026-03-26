package com.dacia.nftp;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Variable-Length Unsigned integer codec.
 * 7 bits per byte, MSB = continuation flag (1 = more bytes follow).
 */
public class VluCodec {

    public static byte[] encode(long value) {
        if (value < 0) throw new IllegalArgumentException("VLU value must be non-negative");
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        do {
            int b = (int) (value & 0x7F);
            value >>>= 7;
            if (value != 0) b |= 0x80;
            out.write(b);
        } while (value != 0);
        return out.toByteArray();
    }

    public static long decode(InputStream in) throws IOException {
        long result = 0;
        int shift = 0;
        int b;
        do {
            b = in.read();
            if (b < 0) throw new IOException("Unexpected end of stream in VLU");
            result |= (long) (b & 0x7F) << shift;
            shift += 7;
        } while ((b & 0x80) != 0);
        return result;
    }
}
