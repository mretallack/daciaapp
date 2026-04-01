package uk.org.retallack.nftp;

import org.junit.Test;
import static org.junit.Assert.*;

public class HexDumpTest {

    @Test
    public void testShortData() {
        byte[] data = {0x48, 0x65, 0x6c, 0x6c, 0x6f};
        String dump = HexDump.format(data);
        assertTrue(dump.contains("48 65 6c 6c 6f"));
        assertTrue(dump.contains("|Hello|"));
    }

    @Test
    public void testMixedPrintableAndNonPrintable() {
        byte[] data = {0x00, 0x41, 0x42, (byte) 0xFF, 0x0A, 0x43};
        String dump = HexDump.format(data);
        assertTrue(dump.contains("|.AB..C|"));
    }

    @Test
    public void testEmptyData() {
        String dump = HexDump.format(new byte[0]);
        assertEquals("", dump);
    }
}
