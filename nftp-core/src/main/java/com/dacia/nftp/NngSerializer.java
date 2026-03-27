package com.dacia.nftp;

import java.io.ByteArrayOutputStream;

/**
 * Encoder for NNG's compact binary serialisation format.
 * Used to build QueryInfo request payloads.
 *
 * Wire format: each value is [tag byte][payload].
 * Tag byte bits 0-5 = type, bit 7 = modifier.
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

    public NngSerializer writeIdentifierString(String name) {
        writeTag(TAG_ID_STRING);
        byte[] bytes = name.getBytes(java.nio.charset.StandardCharsets.UTF_8);
        writeVlu(bytes.length);
        buf.write(bytes, 0, bytes.length);
        return this;
    }

    /** Write a tuple of items. Each item is serialised by calling writeItem(). */
    public NngSerializer writeTuple(Object... items) {
        writeTag(TAG_TUPLE_VLI_LEN);
        writeVlu(items.length);
        for (Object item : items) {
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
                writeIdentifierString(s.substring(1));
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
