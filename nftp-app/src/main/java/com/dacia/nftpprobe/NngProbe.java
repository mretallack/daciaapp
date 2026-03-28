package com.dacia.nftpprobe;

public class NngProbe {
    static {
        System.loadLibrary("lib_base");
        System.loadLibrary("lib_memmgr");
        System.loadLibrary("lib_nng_sdk");
        System.loadLibrary("nng_probe");
    }

    public static native String probeSymbols(String xsRoot);
}
