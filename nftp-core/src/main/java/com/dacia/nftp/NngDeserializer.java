package com.dacia.nftp;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Decoder for NNG's compact binary serialisation format.
 * Used to parse QueryInfo response payloads.
 */
public class NngDeserializer {

    private final byte[] data;
    private int pos;

    public NngDeserializer(byte[] data) {
        this(data, 0);
    }

    public NngDeserializer(byte[] data, int offset) {
        this.data = data;
        this.pos = offset;
    }

    public int getPos() { return pos; }
    public boolean hasMore() { return pos < data.length; }

    public Object readValue() {
        if (pos >= data.length) return null;
        int rawTag = data[pos++] & 0xFF;
        boolean modifier = (rawTag & 0x80) != 0;
        int tag = rawTag & 0x3F; // bits 0-5
        switch (tag) {
            case NngSerializer.TAG_UNDEF: return null;
            case NngSerializer.TAG_INT32: return readInt32();
            case NngSerializer.TAG_UINT64: return readUInt64();
            case NngSerializer.TAG_STRING:
                // The head unit sends null-terminated strings regardless of modifier bit.
                // Use null-terminated for both 0x03 and 0x83.
                return modifier ? readNullTerminatedString() : readStringAuto();
            case 4: return modifier ? readNullTerminatedString() : readString(); // I18NString
            case NngSerializer.TAG_DOUBLE: return readDouble();
            case NngSerializer.TAG_TUPLE: return readTupleFixed();
            case NngSerializer.TAG_DICT: return readDictFixed();
            case NngSerializer.TAG_ID_INT: return "@" + readInt32();
            case NngSerializer.TAG_ID_STRING:
                // Both 0x0d and 0x8d use null-terminated strings in practice.
                // The head unit sends 0x0d with null-terminated (not VLU-length-prefixed).
                return "@" + readNullTerminatedString();
            case 14: return readInt32(); // GenericHandle
            case 15: return "@" + readInt32(); // ObjectHandle (treat as int)
            case NngSerializer.TAG_ID_SYMBOL: return "@symbol:" + readInt32();
            case 25: { readVlu(); return null; } // Simple Failure — consume error code, treat as null
            case NngSerializer.TAG_INT32_VLI: return (int) readVli();
            case NngSerializer.TAG_INT64_VLI: return readVli();
            case NngSerializer.TAG_ID_INT_VLI: return "@" + readVli();
            case NngSerializer.TAG_ID_SYMBOL_VLI: return "@symbol:" + readVli();
            case NngSerializer.TAG_TUPLE_VLI_LEN: return readTupleVli();
            case NngSerializer.TAG_ARRAY_VLI_LEN: return readTupleVli(); // arrays as Object[]
            case NngSerializer.TAG_DICT_VLI_LEN: return readDictVli();
            case 21: return readByteStream(); // ByteStream
            case 33: return readFailureVli(); // FailureVLILen
            default:
                return "[unknown tag=0x" + Integer.toHexString(rawTag) + " at pos=" + (pos - 1) + "]";
        }
    }

    private int readInt32() {
        int v = (data[pos] & 0xFF) | ((data[pos+1] & 0xFF) << 8)
              | ((data[pos+2] & 0xFF) << 16) | ((data[pos+3] & 0xFF) << 24);
        pos += 4;
        return v;
    }

    private long readUInt64() {
        long v = 0;
        for (int i = 0; i < 8; i++) v |= ((long)(data[pos+i] & 0xFF)) << (i * 8);
        pos += 8;
        return v;
    }

    private double readDouble() {
        long bits = readUInt64();
        return Double.longBitsToDouble(bits);
    }

    private String readString() {
        int len = (int) readVlu();
        String s = new String(data, pos, len, StandardCharsets.UTF_8);
        pos += len;
        return s;
    }

    /**
     * Read a string that may be VLU-length-prefixed or null-terminated.
     * The head unit sends null-terminated strings even for tag 0x03 (no modifier).
     * Heuristic: if the first byte is a printable ASCII char (0x20-0x7E) or the
     * VLU-decoded length exceeds remaining data, treat as null-terminated.
     */
    private String readStringAuto() {
        int savedPos = pos;
        int firstByte = data[pos] & 0xFF;
        // If first byte looks like a printable char, it's null-terminated
        if (firstByte >= 0x20 && firstByte <= 0x7E) {
            return readNullTerminatedString();
        }
        // Try VLU length
        int len = (int) readVlu();
        if (len < 0 || pos + len > data.length) {
            // VLU length is bogus, fall back to null-terminated
            pos = savedPos;
            return readNullTerminatedString();
        }
        String s = new String(data, pos, len, StandardCharsets.UTF_8);
        pos += len;
        return s;
    }

    /** Read a null-terminated UTF-8 string (used when modifier bit is set). */
    private String readNullTerminatedString() {
        int start = pos;
        while (pos < data.length && data[pos] != 0) pos++;
        String s = new String(data, start, pos - start, StandardCharsets.UTF_8);
        if (pos < data.length) pos++; // skip null terminator
        return s;
    }

    private byte[] readByteStream() {
        int len = (int) readVlu();
        byte[] b = new byte[len];
        System.arraycopy(data, pos, b, 0, len);
        pos += len;
        return b;
    }

    private long readVlu() {
        long result = 0;
        int shift = 0;
        int b;
        do {
            b = data[pos++] & 0xFF;
            result |= (long)(b & 0x7F) << shift;
            shift += 7;
        } while ((b & 0x80) != 0);
        return result;
    }

    /** Zigzag decode. */
    private long readVli() {
        long v = readVlu();
        return (v >>> 1) ^ -(v & 1);
    }

    private Object[] readTupleFixed() {
        int count = readInt32();
        return readNValues(count);
    }

    private Object[] readTupleVli() {
        int count = (int) readVlu();
        return readNValues(count);
    }

    private Object[] readNValues(int count) {
        if (count < 0 || count > 10000) {
            throw new IllegalStateException("Unreasonable count=" + count
                    + " at pos=" + pos + ", data.length=" + data.length
                    + ", context: " + NftpProbe.hex(data, Math.min(data.length, 64)));
        }
        Object[] items = new Object[count];
        for (int i = 0; i < count; i++) {
            items[i] = readValue();
        }
        return items;
    }

    private Map<String, Object> readDictFixed() {
        int count = readInt32();
        return readNPairs(count);
    }

    private Map<String, Object> readDictVli() {
        int count = (int) readVlu();
        return readNPairs(count);
    }

    /** Read a Failure value — same structure as a dict with VLU count. */
    private Map<String, Object> readFailureVli() {
        int count = (int) readVlu();
        Map<String, Object> failure = readNPairs(count);
        failure.put("@_failure", true);
        return failure;
    }

    private Map<String, Object> readNPairs(int count) {
        if (count < 0 || count > 10000) {
            throw new IllegalStateException("Unreasonable dict count=" + count
                    + " at pos=" + pos + ", data.length=" + data.length
                    + ", context: " + NftpProbe.hex(data, Math.min(data.length, 64)));
        }
        Map<String, Object> map = new LinkedHashMap<>();
        for (int i = 0; i < count; i++) {
            Object key = readValue();
            Object val = readValue();
            map.put(String.valueOf(key), val);
        }
        return map;
    }

    /** Convenience: decode a full byte array from offset 0. */
    public static Object decode(byte[] data) {
        return new NngDeserializer(data).readValue();
    }

    /** Convenience: decode from a specific offset. */
    public static Object decode(byte[] data, int offset) {
        return new NngDeserializer(data, offset).readValue();
    }
}
