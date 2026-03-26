package com.dacia.nftp;

import org.junit.Test;
import java.io.ByteArrayInputStream;
import static org.junit.Assert.*;

public class VluCodecTest {

    @Test
    public void testSmallValues() {
        assertRoundTrip(0);
        assertRoundTrip(1);
        assertRoundTrip(127);
        // 0-127 should encode to 1 byte
        assertEquals(1, VluCodec.encode(0).length);
        assertEquals(1, VluCodec.encode(1).length);
        assertEquals(1, VluCodec.encode(127).length);
    }

    @Test
    public void testMultiByteValues() {
        assertRoundTrip(128);
        assertRoundTrip(16383);
        assertRoundTrip(65535);
        // 128 should need 2 bytes
        assertEquals(2, VluCodec.encode(128).length);
        assertEquals(2, VluCodec.encode(16383).length);
        assertEquals(3, VluCodec.encode(65535).length);
    }

    @Test
    public void testRoundTrip() throws Exception {
        long[] values = {0, 1, 63, 64, 127, 128, 255, 256, 16383, 16384, 65535, 100000, Integer.MAX_VALUE};
        for (long v : values) {
            assertRoundTrip(v);
        }
    }

    private void assertRoundTrip(long value) {
        try {
            byte[] encoded = VluCodec.encode(value);
            long decoded = VluCodec.decode(new ByteArrayInputStream(encoded));
            assertEquals("Round-trip failed for " + value, value, decoded);
        } catch (Exception e) {
            fail("Exception for value " + value + ": " + e.getMessage());
        }
    }
}
