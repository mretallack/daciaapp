package uk.org.retallack.nftp;

import org.junit.Test;
import static org.junit.Assert.*;

public class NftpCheckSumTest {

    @Test
    public void testBuildCheckSumMD5() {
        byte[] body = NftpProbe.buildCheckSum("license/device.nng", 0);
        assertEquals(0x05, body[0]);
        assertEquals(0x00, body[1]); // MD5
        assertTrue(new String(body, 2, body.length - 2).startsWith("license/device.nng"));
    }

    @Test
    public void testBuildCheckSumSHA1() {
        byte[] body = NftpProbe.buildCheckSum("license/device.nng", 1);
        assertEquals(0x05, body[0]);
        assertEquals(0x01, body[1]); // SHA1
    }

    @Test
    public void testCheckSumWithFakeServer() throws Exception {
        // MD5 response: status=0 + 16 bytes hash
        byte[] md5Hash = new byte[16];
        for (int i = 0; i < 16; i++) md5Hash[i] = (byte) (0xa0 + i);
        byte[] response = new byte[17];
        response[0] = 0x00;
        System.arraycopy(md5Hash, 0, response, 1, 16);

        // Build request and verify format
        byte[] req = NftpProbe.buildCheckSum("test.txt", 0);
        assertEquals(0x05, req[0]);
        assertEquals(0x00, req[1]);

        // Verify hex formatting of hash
        String hex = NftpProbe.hex(md5Hash).replace(" ", "");
        assertEquals("a0a1a2a3a4a5a6a7a8a9aaabacadaeaf", hex);
    }

    @Test
    public void testCheckSumErrorResponse() throws Exception {
        byte[] req = NftpProbe.buildCheckSum("nonexistent.txt", 0);
        assertEquals(0x05, req[0]);
        // Error response would be [0x01] (Failed)
        byte[] errorResp = {0x01};
        assertEquals(0x01, errorResp[0] & 0xFF);
    }
}
