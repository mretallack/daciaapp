package com.dacia.nftpprobe;

public class NngProbe {
    static {
        System.loadLibrary("nng_probe");
    }

    public static native String probeSymbols();
}
