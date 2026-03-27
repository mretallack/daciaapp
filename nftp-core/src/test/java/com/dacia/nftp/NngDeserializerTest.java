package com.dacia.nftp;

import org.junit.Test;
import java.util.Map;
import static org.junit.Assert.*;

public class NngDeserializerTest {

    @Test
    public void testDecodeUndef() {
        byte[] data = {NngSerializer.TAG_UNDEF};
        assertNull(NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeInt32() {
        byte[] data = {NngSerializer.TAG_INT32, 0x2A, 0x00, 0x00, 0x00}; // 42 LE
        assertEquals(42, NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeUInt64() {
        byte[] data = {NngSerializer.TAG_UINT64, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
        assertEquals(1L, NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeString() {
        byte[] data = {NngSerializer.TAG_STRING, 0x05, 'h', 'e', 'l', 'l', 'o'};
        assertEquals("hello", NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeIdentifierString() {
        byte[] data = {NngSerializer.TAG_ID_STRING, 0x06, 'd', 'e', 'v', 'i', 'c', 'e'};
        assertEquals("@device", NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeInt32Vli() {
        // zigzag(42) = 84 = 0x54, fits in one VLU byte
        byte[] data = {NngSerializer.TAG_INT32_VLI, 0x54};
        assertEquals(42, NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeInt32VliNegative() {
        // zigzag(-1) = 1
        byte[] data = {NngSerializer.TAG_INT32_VLI, 0x01};
        assertEquals(-1, NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeTupleVli() {
        // Tuple of 2 items: string "a", int32vli 5
        byte[] data = {
            NngSerializer.TAG_TUPLE_VLI_LEN, 0x02, // count=2
            NngSerializer.TAG_STRING, 0x01, 'a',    // "a"
            NngSerializer.TAG_INT32_VLI, 0x0A        // zigzag(5)=10
        };
        Object[] tuple = (Object[]) NngDeserializer.decode(data);
        assertEquals(2, tuple.length);
        assertEquals("a", tuple[0]);
        assertEquals(5, tuple[1]);
    }

    @Test
    public void testDecodeNestedTuple() {
        // Tuple of 1 item which is itself a tuple of 1 string
        byte[] data = {
            NngSerializer.TAG_TUPLE_VLI_LEN, 0x01,
            NngSerializer.TAG_TUPLE_VLI_LEN, 0x01,
            NngSerializer.TAG_STRING, 0x02, 'h', 'i'
        };
        Object[] outer = (Object[]) NngDeserializer.decode(data);
        Object[] inner = (Object[]) outer[0];
        assertEquals("hi", inner[0]);
    }

    @Test
    public void testDecodeDictVli() {
        // Dict with 1 entry: key=IdString "name", value=String "test"
        byte[] data = {
            NngSerializer.TAG_DICT_VLI_LEN, 0x01,
            NngSerializer.TAG_ID_STRING, 0x04, 'n', 'a', 'm', 'e',
            NngSerializer.TAG_STRING, 0x04, 't', 'e', 's', 't'
        };
        @SuppressWarnings("unchecked")
        Map<String, Object> dict = (Map<String, Object>) NngDeserializer.decode(data);
        assertEquals(1, dict.size());
        assertEquals("test", dict.get("@name"));
    }

    @Test
    public void testDecodeIdSymbolVli() {
        // symbol ID 7 → zigzag(7)=14
        byte[] data = {NngSerializer.TAG_ID_SYMBOL_VLI, 0x0E};
        assertEquals("@symbol:7", NngDeserializer.decode(data));
    }

    @Test
    public void testDecodeUnknownTag() {
        byte[] data = {(byte) 0x3F}; // tag 63 — unknown
        Object result = NngDeserializer.decode(data);
        assertTrue(result.toString().contains("unknown tag"));
    }

    @Test
    public void testRoundTrip() {
        NngSerializer s = new NngSerializer();
        s.writeTuple("@device", "@brand");
        byte[] encoded = s.toBytes();

        Object[] decoded = (Object[]) NngDeserializer.decode(encoded);
        assertEquals(2, decoded.length);
        assertEquals("@device", decoded[0]);
        assertEquals("@brand", decoded[1]);
    }

    @Test
    public void testRoundTripMixed() {
        NngSerializer s = new NngSerializer();
        s.writeTuple("@ls", "content");
        byte[] encoded = s.toBytes();

        Object[] decoded = (Object[]) NngDeserializer.decode(encoded);
        assertEquals(2, decoded.length);
        assertEquals("@ls", decoded[0]);
        assertEquals("content", decoded[1]);
    }
}
