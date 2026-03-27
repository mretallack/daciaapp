package com.dacia.nftp;

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
    public void testEncodeIdentifierString() {
        NngSerializer s = new NngSerializer();
        s.writeIdentifierString("device");
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_ID_STRING, b[0] & 0xFF);
        assertEquals(6, b[1] & 0xFF); // VLU length
        assertEquals('d', b[2]);
    }

    @Test
    public void testEncodeTupleOfIdentifiers() {
        NngSerializer s = new NngSerializer();
        s.writeTuple("@device", "@brand");
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_TUPLE_VLI_LEN, b[0] & 0xFF);
        assertEquals(2, b[1] & 0xFF); // VLU count
        assertEquals(NngSerializer.TAG_ID_STRING, b[2] & 0xFF); // first item
    }

    @Test
    public void testEncodeTupleMixedTypes() {
        NngSerializer s = new NngSerializer();
        s.writeTuple("@ls", "content");
        byte[] b = s.toBytes();
        assertEquals(NngSerializer.TAG_TUPLE_VLI_LEN, b[0] & 0xFF);
        assertEquals(2, b[1] & 0xFF);
        // first item: identifier string "ls"
        assertEquals(NngSerializer.TAG_ID_STRING, b[2] & 0xFF);
        // second item somewhere after: plain string "content"
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
}
