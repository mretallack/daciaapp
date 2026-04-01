package uk.org.retallack.nftp;

import org.junit.Test;
import static org.junit.Assert.*;

public class NngSerializerTest {

    @Test
    public void testEncodeString() {
        NngSerializer s = new NngSerializer();
        s.writeString("hello");
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_STRING, b[0] & 0xFF);
        assertEquals(5, b[1] & 0xFF); // VLU length
        assertEquals('h', b[2]);
    }

    @Test
    public void testEncodeIdentifier() {
        NngSerializer s = new NngSerializer();
        s.writeIdentifier("device");
        byte[] b = s.toBytes();
        // Compact format: 0x8d + null-terminated string
        assertEquals(0x8d, b[0] & 0xFF);
        assertEquals('d', b[1]);
        assertEquals('e', b[2]);
        assertEquals(0x00, b[7] & 0xFF); // null terminator after "device"
        assertEquals(8, b.length); // 1 tag + 6 chars + 1 null
    }

    @Test
    public void testEncodeTupleOfIdentifiers() {
        NngSerializer s = new NngSerializer();
        s.writeTuple("@device", "@brand");
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_TUPLE_VLI_LEN, b[0] & 0xFF);
        assertEquals(2, b[1] & 0xFF); // VLU count
        assertEquals(0x8d, b[2] & 0xFF); // first item: compact identifier
    }

    @Test
    public void testEncodeTupleMixedTypes() {
        NngSerializer s = new NngSerializer();
        s.writeTuple("@ls", "content");
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_TUPLE_VLI_LEN, b[0] & 0xFF);
        assertEquals(2, b[1] & 0xFF);
        // first item: compact identifier "ls" (0x8d + "ls" + 0x00)
        assertEquals(0x8d, b[2] & 0xFF);
        // second item: plain string "content"
        boolean foundString = false;
        for (int i = 2; i < b.length; i++) {
            if ((b[i] & 0xFF) == NngSerializer.TAG_STRING) { foundString = true; break; }
        }
        assertTrue("Should contain a plain string tag", foundString);
    }

    @Test
    public void testEncodeInt() {
        NngSerializer s = new NngSerializer();
        s.writeTuple(42);
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_TUPLE_VLI_LEN, b[0] & 0xFF);
        assertEquals(1, b[1] & 0xFF);
        assertEquals(NngSerializer.TAG_INT32_VLI, b[2] & 0xFF);
    }

    @Test
    public void testEncodeNull() {
        NngSerializer s = new NngSerializer();
        s.writeTuple((Object) null);
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_TUPLE_VLI_LEN, b[0] & 0xFF);
        assertEquals(1, b[1] & 0xFF);
        assertEquals(NngSerializer.TAG_UNDEF, b[2] & 0xFF);
    }

    @Test
    public void testIdentifierMatchesCapturedBytes() {
        // Verify our output matches the bytes captured from the real NNG SDK
        NngSerializer s = new NngSerializer();
        s.writeIdentifier("fileMapping");
        byte[] b = s.toBytes();
        // Captured: 8d 66 69 6c 65 4d 61 70 70 69 6e 67 00
        byte[] expected = new byte[] {
            (byte)0x8d, 'f','i','l','e','M','a','p','p','i','n','g', 0x00
        };
        assertArrayEquals(expected, b);
    }

    @Test
    public void testArrayOfIdentifiersMatchesCaptured() {
        // [@fileMapping] captured: 1f 01 8d 66 69 6c 65 4d 61 70 70 69 6e 67 00
        NngSerializer s = new NngSerializer();
        s.writeArray("@fileMapping");
        byte[] b = s.toBytes();
        assertEquals(0x1f, b[0] & 0xFF); // TAG_ARRAY_VLI_LEN
        assertEquals(0x01, b[1] & 0xFF); // 1 element
        assertEquals(0x8d, b[2] & 0xFF); // compact identifier
        assertEquals(0x00, b[b.length - 1] & 0xFF); // null terminator
    }
}
