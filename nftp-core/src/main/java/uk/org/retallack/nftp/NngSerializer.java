package uk.org.retallack.nftp;

import java.io.ByteArrayOutputStream;

/**
 * Encoder for NNG's compact binary serialisation format.
 * Used to build QueryInfo request payloads.
 *
 * Wire format: each value is [tag byte][payload].
 * Tag byte: bits 0-5 = type, bit 6 = unused, bit 7 = modifier.
 *
 * The native NNG runtime's Stream(@compact) serialises @symbols as
 * IdentifierString with modifier (0x8d) + null-terminated UTF-8 name.
 * This was confirmed by capturing bytes from the real NNG SDK on Android
 * via System.import('system://serialization').Stream(@compact).
 *
 * Previous attempts used TAG_ID_STRING (0x0d) with VLU-length prefix,
 * or TAG_ID_SYMBOL_VLI (0x1d) with integer IDs — both failed because
 * the head unit's deserialiser expects the compact format.
 */
public class NngSerializer {

    public static final int TAG_UNDEF = 0;
    public static final int TAG_INT32 = 1;
    public static final int TAG_UINT64 = 2;
    public static final int TAG_STRING = 3;
    public static final int TAG_DOUBLE = 5;
    public static final int TAG_TUPLE = 6;
    public static final int TAG_DICT = 7;
    public static final int TAG_ID_INT = 12;
    public static final int TAG_ID_STRING = 13;
    public static final int TAG_ID_SYMBOL = 24;
    public static final int TAG_INT32_VLI = 26;
    public static final int TAG_INT64_VLI = 27;
    public static final int TAG_ID_INT_VLI = 28;
    public static final int TAG_ID_SYMBOL_VLI = 29;
    public static final int TAG_TUPLE_VLI_LEN = 30;
    public static final int TAG_ARRAY_VLI_LEN = 31;
    public static final int TAG_DICT_VLI_LEN = 32;

    /** Modifier bit — set in bit 7 of the tag byte. */
    public static final int MODIFIER = 0x80;

    private final ByteArrayOutputStream buf = new ByteArrayOutputStream();

    public NngSerializer writeTag(int tag) {
        buf.write(tag & 0xFF);
        return this;
    }

    public NngSerializer writeVlu(long value) {
        byte[] encoded = VluCodec.encode(value);
        buf.write(encoded, 0, encoded.length);
        return this;
    }

    /** Zigzag encode then VLU. */
    public NngSerializer writeVli(long value) {
        return writeVlu((value << 1) ^ (value >> 63));
    }

    public NngSerializer writeString(String s) {
        writeTag(TAG_STRING);
        byte[] bytes = s.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        writeVlu(bytes.length);
        buf.write(bytes, 0, bytes.length);
        return this;
    }

    /**
     * Write an NNG identifier/symbol using the compact format.
     * Format: 0x8d (TAG_ID_STRING | MODIFIER) + null-terminated UTF-8 name.
     *
     * This matches what the native NNG runtime produces via
     * Stream(@compact).add(@symbolName).transfer().
     */
    public NngSerializer writeIdentifier(String name) {
        writeTag(TAG_ID_STRING | MODIFIER);
        byte[] bytes = name.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        buf.write(bytes, 0, bytes.length);
        buf.write(0x00); // null terminator
        return this;
    }

    /**
     * @deprecated Use {@link #writeIdentifier(String)} instead.
     * This method used VLU-length-prefixed encoding which doesn't match
     * the native NNG compact format.
     */
    @Deprecated
    public NngSerializer writeIdentifierString(String name) {
        return writeIdentifier(name);
    }

    /** Write a tuple of items using compact VLI-length encoding. */
    public NngSerializer writeTuple(Object... items) {
        writeTag(TAG_TUPLE_VLI_LEN);
        writeVlu(items.length);
        for (Object item : items) {
            writeItem(item);
        }
        return this;
    }

    /** Write an array of items using compact VLI-length encoding. */
    public NngSerializer writeArray(Object... items) {
        writeTag(TAG_ARRAY_VLI_LEN);
        writeVlu(items.length);
        for (Object item : items) {
            writeItem(item);
        }
        return this;
    }

    /** Write a dict (record) with key-value pairs. */
    public NngSerializer writeDict(Object... keysAndValues) {
        if (keysAndValues.length % 2 != 0) {
            throw new IllegalArgumentException("Dict requires even number of args (key-value pairs)");
        }
        writeTag(TAG_DICT_VLI_LEN);
        writeVlu(keysAndValues.length / 2);
        for (Object item : keysAndValues) {
            writeItem(item);
        }
        return this;
    }

    /** Auto-serialise an item based on its Java type. */
    private void writeItem(Object item) {
        if (item == null) {
            writeTag(TAG_UNDEF);
        } else if (item instanceof String) {
            String s = (String) item;
            if (s.startsWith("@")) {
                writeIdentifier(s.substring(1));
            } else {
                writeString(s);
            }
        } else if (item instanceof Integer) {
            writeTag(TAG_INT32_VLI);
            writeVli((int) item);
        } else if (item instanceof Long) {
            writeTag(TAG_INT64_VLI);
            writeVli((long) item);
        } else if (item instanceof Object[]) {
            writeTuple((Object[]) item);
        } else {
            throw new IllegalArgumentException("Unsupported type: " + item.getClass());
        }
    }

    public byte[] toBytes() {
        return buf.toByteArray();
    }
}
