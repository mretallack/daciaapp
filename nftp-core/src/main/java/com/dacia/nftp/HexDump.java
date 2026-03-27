package com.dacia.nftp;

/** Hex dump utility for displaying binary data. */
public class HexDump {

    /** Format data as a hex dump with offset, hex bytes, and ASCII. */
    public static String format(byte[] data) {
        return format(data, 0, data.length);
    }

    public static String format(byte[] data, int offset, int length) {
        StringBuilder sb = new StringBuilder();
        int end = Math.min(offset + length, data.length);
        for (int i = offset; i < end; i += 16) {
            sb.append(String.format("%08x  ", i - offset));
            int lineEnd = Math.min(i + 16, end);
            for (int j = i; j < i + 16; j++) {
                if (j < lineEnd) {
                    sb.append(String.format("%02x ", data[j] & 0xFF));
                } else {
                    sb.append("   ");
                }
                if (j == i + 7) sb.append(' ');
            }
            sb.append(" |");
            for (int j = i; j < lineEnd; j++) {
                int b = data[j] & 0xFF;
                sb.append(b >= 32 && b < 127 ? (char) b : '.');
            }
            sb.append("|\n");
        }
        return sb.toString();
    }
}
