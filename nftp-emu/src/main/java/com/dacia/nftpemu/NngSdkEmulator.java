package com.dacia.nftpemu;

import com.github.unidbg.AndroidEmulator;
import com.github.unidbg.Emulator;
import com.github.unidbg.Module;
import com.github.unidbg.arm.HookStatus;
import com.github.unidbg.arm.backend.Unicorn2Factory;
import com.github.unidbg.arm.context.RegisterContext;
import com.github.unidbg.file.FileResult;
import com.github.unidbg.file.IOResolver;
import com.github.unidbg.file.linux.AndroidFileIO;
import com.github.unidbg.hook.ReplaceCallback;
import com.github.unidbg.hook.hookzz.HookZz;
import com.github.unidbg.linux.android.AndroidEmulatorBuilder;
import com.github.unidbg.linux.android.AndroidResolver;
import com.github.unidbg.linux.android.dvm.*;
import com.github.unidbg.linux.android.dvm.wrapper.DvmBoolean;
import com.github.unidbg.linux.file.DirectoryFileIO;
import com.github.unidbg.linux.file.SimpleFileIO;

import java.io.File;
import java.io.IOException;

/**
 * Loads the real NNG SDK (liblib_nng_sdk.so) via unidbg ARM64 emulation
 * and attempts to initialise the engine with the YellowBox .xs scripts.
 */
public class NngSdkEmulator extends AbstractJni implements AutoCloseable, IOResolver<AndroidFileIO> {

    private static final String DEFAULT_LIB_DIR = "/home/mark/git/daciaapp/apk_arm64/lib/arm64-v8a";
    private static final String DEFAULT_XS_DIR = "/home/mark/git/daciaapp/xs_extract/data";

    private final AndroidEmulator emulator;
    private final VM vm;
    private final Module nngSdk;

    public NngSdkEmulator(String libDir) {
        this.emulator = AndroidEmulatorBuilder.for64Bit()
                .addBackendFactory(new Unicorn2Factory(true))
                .setProcessName("com.nng.pbmu.dacia")
                .setRootDir(new File("target/rootfs"))
                .build();
        emulator.getMemory().setLibraryResolver(new AndroidResolver(23));
        emulator.getSyscallHandler().addIOResolver(this);

        // Create DalvikVM with the real APK so it knows about Configuration class fields
        File apk = new File("/home/mark/git/daciaapp/xapk_extract/com.nng.pbmu.dacia.apk");
        if (apk.exists()) {
            this.vm = emulator.createDalvikVM(apk);
            System.out.println("[+] DalvikVM created with APK: " + apk.getName());
        } else {
            this.vm = emulator.createDalvikVM();
            System.out.println("[*] DalvikVM created without APK (no field resolution)");
        }
        vm.setJni(this);
        vm.setVerbose(true);

        // Pre-register the SDK$Configuration class and its fields BEFORE loading the SDK.
        // The .init_array constructors cache jfieldIDs via FindClass+GetFieldID.
        // If the class isn't registered, all cached IDs are null and InitializeNative crashes.
        DvmClass configClass = vm.resolveClass("com/nng/core/SDK$Configuration");
        try {
            java.lang.reflect.Method gfid = DvmClass.class.getDeclaredMethod("getFieldID", String.class, String.class);
            gfid.setAccessible(true);
            for (String[] f : new String[][]{
                    {"rootPath", "Ljava/lang/String;"},
                    {"additionalResources", "Ljava/lang/String;"},
                    {"httpUserAgent", "Ljava/lang/String;"},
                    {"threaded", "Ljava/lang/Boolean;"},
                    {"bootScript", "Lcom/nng/core/SDK$Configuration$BootScript;"},
                    {"onInit", "Ljava/util/function/Consumer;"},
                    {"onEngineStatusChange", "Ljava/util/function/Consumer;"},
                    {"connectivityConfig", "Lcom/nng/core/SDK$Configuration$ConnectivityConfig;"},
                    {"deviceAuth", "Lcom/nng/core/SDK$Configuration$DeviceAuth;"},
                    {"licoilConfig", "Lcom/nng/core/SDK$Configuration$LicoilConfig;"},
                    {"commandLineArguments", "Ljava/util/List;"},
                    {"subPaths", "Ljava/util/List;"},
                    {"vaultConfigs", "Ljava/util/List;"},
                    {"passphraseProvider", "Ljava/util/function/Function;"},
                    {"provideAPIKey", "Ljava/util/function/Function;"},
            }) {
                gfid.invoke(configClass, f[0], f[1]);
            }
            System.out.println("[+] Pre-registered SDK$Configuration fields");
        } catch (Exception e) {
            System.out.println("[-] Failed to pre-register fields: " + e.getMessage());
        }

        // Load dependencies first, then the main SDK
        // callInit=true runs .init_array constructors
        DalvikModule base = vm.loadLibrary(new File(libDir, "liblib_base.so"), true);
        DalvikModule memmgr = vm.loadLibrary(new File(libDir, "liblib_memmgr.so"), true);
        DalvikModule sdk = vm.loadLibrary(new File(libDir, "liblib_nng_sdk.so"), true);

        this.nngSdk = sdk.getModule();
        System.out.println("[+] NNG SDK loaded at base: 0x" + Long.toHexString(nngSdk.base));
        System.out.println("[+] NNG SDK size: " + (nngSdk.size / 1024 / 1024) + " MB");

        // Call JNI_OnLoad to register JNI methods and cache field IDs.
        // It will crash on ioctl but the field IDs should be cached before the crash.
        try {
            sdk.callJNI_OnLoad(emulator);
            System.out.println("[+] JNI_OnLoad succeeded");
        } catch (Exception e) {
            System.out.println("[-] JNI_OnLoad crashed (expected): " + e.getMessage());
        }

        // Check if field IDs were cached despite the crash
        {
            long fieldIdGlobal = nngSdk.base + 0x1dc2b58L;
            com.github.unidbg.pointer.UnidbgPointer fidPtr =
                    com.github.unidbg.pointer.UnidbgPointer.pointer(emulator, fieldIdGlobal);
            long cachedFid = fidPtr.getLong(0);
            System.out.println("[*] Cached jfieldID at 0x1dc2b58 = 0x" + Long.toHexString(cachedFid)
                    + (cachedFid != 0 ? " ✓" : " ✗ (still null)"));
        }

        // Hook eventfd — the engine uses it for the event loop but unidbg doesn't implement it
        // Return a fake fd (100+) for each call
        final int[] nextFakeFd = {100};
        try {
            long eventfdPlt = nngSdk.base + 0x244910L; // eventfd@plt (ELF VA, no image base adj)
            HookZz hookZz = HookZz.getInstance(emulator);
            hookZz.replace(eventfdPlt, new ReplaceCallback() {
                @Override
                public HookStatus onCall(Emulator<?> emu, long originFunction) {
                    int fd = nextFakeFd[0]++;
                    System.out.println("[HOOK] eventfd() -> fake fd " + fd);
                    return HookStatus.LR(emu, fd);
                }
            });
            System.out.println("[+] Hooked eventfd@plt");
        } catch (Exception e) {
            System.out.println("[-] Failed to hook eventfd: " + e.getMessage());
        }

        // Hook fstat in libc — the engine calls fstat on fake eventfds which crashes
        // unidbg's newfstatat syscall handler when path is null
        try {
            HookZz hookZz2 = HookZz.getInstance(emulator);
            ReplaceCallback fstatStub = new ReplaceCallback() {
                @Override
                public HookStatus onCall(Emulator<?> emu, long originFunction) {
                    return HookStatus.LR(emu, 0);
                }
            };
            // Hook all fstat variants in the SDK's PLT
            for (long pltOffset : new long[]{0x244f80L, 0x245200L, 0x2453d0L, 0x2456a0L}) {
                hookZz2.replace(nngSdk.base + pltOffset, fstatStub);
            }
            // Also hook fstatfs64 PLT
            hookZz2.replace(nngSdk.base + 0x245b50L, fstatStub);
            System.out.println("[+] Hooked fstat*/fstatat* PLTs");

            // Hook ioctl — JNI_OnLoad calls ioctl which crashes unidbg
            hookZz2.replace(nngSdk.base + 0x245f20L, fstatStub);
            Module libcMod = emulator.getMemory().findModule("libc.so");
            if (libcMod != null) {
                com.github.unidbg.Symbol ioctlSym = libcMod.findSymbolByName("ioctl");
                if (ioctlSym != null) {
                    hookZz2.replace(ioctlSym.getAddress(), fstatStub);
                }
            }
            System.out.println("[+] Hooked ioctl");

            // Also hook libc fstat/fstatat
            Module libcModule = libcMod;
            if (libcModule != null) {
                // Hook libc's internal fstatat wrapper at offset 0x6a1f4 (the svc entry)
                // Actually, hook the exported fstat symbol in libc
                com.github.unidbg.linux.LinuxSymbol fstatSym =
                        (com.github.unidbg.linux.LinuxSymbol) libcModule.findSymbolByName("fstat");
                if (fstatSym != null) {
                    hookZz2.replace(fstatSym.getAddress(), fstatStub);
                    System.out.println("[+] Hooked libc fstat at 0x" + Long.toHexString(fstatSym.getAddress()));
                }
                // Also hook fstatat
                for (String name : new String[]{"fstatat", "fstatat64", "fstat64"}) {
                    com.github.unidbg.Symbol sym = libcModule.findSymbolByName(name);
                    if (sym != null) {
                        hookZz2.replace(sym.getAddress(), fstatStub);
                        System.out.println("[+] Hooked libc " + name + " at 0x" + Long.toHexString(sym.getAddress()));
                    }
                }
            }
        } catch (Exception e) {
            System.out.println("[-] Failed to hook fstat: " + e.getMessage());
        }
    }

    /**
     * Try multiple approaches to initialise the engine:
     * 1. JNI path (InitializeNative) — most complete
     * 2. C path (nng_Core_Initialize) — simpler but less state setup
     * 3. Direct symbol_intern — if engine won't start
     */
    public void initialize(String xsDir) {
        String rootPath = xsDir + "/yellowbox";

        // --- Approach 1: JNI path ---
        System.out.println("[*] Trying JNI InitializeNative path...");
        try {
            // SetRootPathNative(JNIEnv*, jclass, jstring)
            StringObject rootPathStr = new StringObject(vm, rootPath);
            nngSdk.callFunction(emulator, "Java_com_nng_core_SDK_SetRootPathNative",
                    vm.getJNIEnv(), 0, vm.addLocalObject(rootPathStr));
            System.out.println("[+] SetRootPathNative OK");

            // SetHttpUserAgentNative — may be needed
            StringObject uaStr = new StringObject(vm, "NftpProbe/1.0");
            nngSdk.callFunction(emulator, "Java_com_nng_core_SDK_SetHttpUserAgentNative",
                    vm.getJNIEnv(), 0, vm.addLocalObject(uaStr));
            System.out.println("[+] SetHttpUserAgentNative OK");

            // InitializeNative(JNIEnv*, jclass, jobject config)
            DvmClass configClass = vm.resolveClass("com/nng/core/SDK$Configuration");
            DvmObject<?> config = configClass.newObject(null);
            System.out.println("[*] Calling InitializeNative...");
            nngSdk.callFunction(emulator, "Java_com_nng_core_SDK_InitializeNative",
                    vm.getJNIEnv(), 0, vm.addLocalObject(config));
            System.out.println("[+] InitializeNative returned (may have partially failed)");

            // InitializeNative fails at GetObjectField because cached jfieldIDs are null.
            // But the global config object at 0x1dc2d70 needs to be initialised.
            // The init function is FUN_ba72f4 which is called via __cxa_guard on first use.
            // Since InitializeNative crashed before reaching the guard, we call it manually.
            long configGlobalAddr = nngSdk.base + 0x1dc2d70L;
            long configInitFunc = nngSdk.base + 0xba72f4L;
            long guardAddr = nngSdk.base + 0x1dc2ee0L;

            // Check if guard was already acquired
            com.github.unidbg.pointer.UnidbgPointer guardPtr =
                    com.github.unidbg.pointer.UnidbgPointer.pointer(emulator, guardAddr);
            int guardVal = guardPtr.getByte(0) & 0xFF;
            System.out.println("[*] Guard at 0x1dc2ee0 = " + guardVal + (guardVal != 0 ? " (already init)" : " (not init)"));

            if (guardVal == 0) {
                System.out.println("[*] Calling config init FUN_ba72f4(0x1dc2d70)...");
                try {
                    nngSdk.callFunction(emulator, configInitFunc,
                            com.github.unidbg.pointer.UnidbgPointer.pointer(emulator, configGlobalAddr));
                    // Set the guard to mark as initialised
                    guardPtr.setByte(0, (byte) 1);
                    System.out.println("[+] Config global initialised, guard set");
                } catch (Exception e3) {
                    System.out.println("[-] Config init failed: " + e3.getMessage());
                }
            }

            // Dump the global config struct to understand what nng_Core_Initialize reads
            com.github.unidbg.pointer.UnidbgPointer cfgPtr =
                    com.github.unidbg.pointer.UnidbgPointer.pointer(emulator, configGlobalAddr);
            System.out.println("[*] Global config dump (first 128 bytes):");
            for (int i = 0; i < 128; i += 8) {
                long val = cfgPtr.getLong(i);
                if (val != 0) {
                    System.out.println("    offset " + i + " (0x" + Integer.toHexString(i) + "): 0x" + Long.toHexString(val));
                }
            }

            // Try nng_Core_EnableTesting first — might set up test mode that's simpler
            System.out.println("[*] Calling nng_Core_EnableTesting...");
            try {
                nngSdk.callFunction(emulator, "nng_Core_EnableTesting");
                System.out.println("[+] nng_Core_EnableTesting OK");
            } catch (Exception e2) {
                System.out.println("[-] nng_Core_EnableTesting failed: " + e2.getMessage());
            }

            // Enable tracing to understand what nng_Core_Initialize does
            System.out.println("[*] Calling nng_Core_Initialize (C level)...");
            // nng_Core_Initialize takes a pointer to a C config struct (292 bytes)
            // that InitializeNative was supposed to build from the Java Configuration.
            // Since InitializeNative failed, we build a minimal one ourselves.
            com.github.unidbg.pointer.UnidbgPointer cConfig =
                    emulator.getMemory().malloc(292, true).getPointer(); // zeroed
            // First 8 bytes = struct size (0x124 = 292)
            cConfig.setLong(0, 0x124);
            Number cRet = nngSdk.callFunction(emulator, "nng_Core_Initialize", cConfig);
            System.out.println("[+] nng_Core_Initialize returned: " + cRet);
        } catch (Exception e) {
            System.out.println("[-] JNI path failed: " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }

        // --- Try exported ifapi_token_from_identifier ---
        System.out.println("\n[*] Trying ifapi_token_from_identifier (exported C API)...");
        String[] testSymbols = {"device", "brand", "fileMapping", "diskInfo", "ls", "compact",
                "name", "size", "error", "path", "children", "md5", "sha1"};
        for (String sym : testSymbols) {
            try {
                byte[] symBytes = (sym + "\0").getBytes();
                com.github.unidbg.pointer.UnidbgPointer symPtr =
                        emulator.getMemory().malloc(symBytes.length, false).getPointer();
                symPtr.write(0, symBytes, 0, symBytes.length);
                Number id = nngSdk.callFunction(emulator, "ifapi_token_from_identifier", symPtr);
                long idVal = id.longValue() & 0xFFFFFFFFL;
                System.out.println("    @" + sym + " = " + (idVal == 0xFFFFFFFFL ? "FAILED" : String.valueOf(idVal)));
            } catch (Exception e) {
                System.out.println("    @" + sym + " = ERROR: " + e.getMessage());
                break;
            }
        }

        // --- Phase 3: Start event loop ---
        System.out.println("\n[*] Phase 3: Starting RunLoop...");
        try {
            Number rlRet = nngSdk.callFunction(emulator, "nng_Core_RunLoop");
            System.out.println("[+] nng_Core_RunLoop returned: " + rlRet);
        } catch (Exception e) {
            System.out.println("[-] nng_Core_RunLoop: " + e.getMessage());
        }

        // --- Phase 4: Test direct TCP connection to Python emulator ---
        System.out.println("\n[*] Phase 4: Direct NFTP test against Python emulator...");
        try {
            java.net.Socket sock = new java.net.Socket();
            sock.connect(new java.net.InetSocketAddress("127.0.0.1", 9876), 2000);
            System.out.println("[+] Connected to emulator on :9876");

            java.io.OutputStream out = sock.getOutputStream();
            java.io.InputStream in = sock.getInputStream();

            // NFTP packet framing: [w0:2 LE][w1:2 LE][body]
            // w0 = (HEADER_SIZE + body.length) & 0x7FFF
            // w1 = pkt_id & 0x3FFF (no response/aborted flags for request)
            // Init body: \x00 + VLU(1) + "YellowBox/1.8.13\0"
            byte[] body = new byte[]{0x00, 0x01, 'Y','e','l','l','o','w','B','o','x',
                    '/','1','.','8','.','1','3','\0'};
            int totalLen = 4 + body.length; // HEADER_SIZE=4
            int w0 = totalLen & 0x7FFF;
            int w1 = 1; // pkt_id = 1
            byte[] frame = new byte[4 + body.length];
            frame[0] = (byte)(w0 & 0xFF); frame[1] = (byte)((w0 >> 8) & 0xFF);
            frame[2] = (byte)(w1 & 0xFF); frame[3] = (byte)((w1 >> 8) & 0xFF);
            System.arraycopy(body, 0, frame, 4, body.length);
            out.write(frame);
            out.flush();
            System.out.println("[+] Sent Init (" + frame.length + " bytes)");

            // Read response packet
            sock.setSoTimeout(3000);
            byte[] hdr = new byte[4];
            int nRead = 0;
            while (nRead < 4) nRead += in.read(hdr, nRead, 4 - nRead);
            int rw0 = (hdr[0]&0xFF)|((hdr[1]&0xFF)<<8);
            int rw1 = (hdr[2]&0xFF)|((hdr[3]&0xFF)<<8);
            int rLen = (rw0 & 0x7FFF) - 4;
            boolean isResponse = (rw1 & 0x8000) != 0;
            int rId = rw1 & 0x3FFF;
            byte[] rBody = new byte[rLen];
            nRead = 0;
            while (nRead < rLen) nRead += in.read(rBody, nRead, rLen - nRead);

            System.out.println("[+] Response: id=" + rId + " response=" + isResponse + " len=" + rLen);
            if (rLen > 0 && rBody[0] == 0x00) {
                // Success — parse product string after status + VLU version
                int pos = 1;
                // skip VLU
                while (pos < rLen && (rBody[pos] & 0x80) != 0) pos++;
                pos++; // skip last VLU byte
                String product = new String(rBody, pos, rLen - pos, "ASCII").replace("\0", "");
                System.out.println("[+] Emulator identified as: " + product);
            } else {
                StringBuilder hex = new StringBuilder();
                for (int i = 0; i < Math.min(rLen, 64); i++) hex.append(String.format("%02x ", rBody[i] & 0xFF));
                System.out.println("[+] Response body: " + hex.toString().trim());
            }
            sock.close();

            // --- Phase 4b: Send QueryInfo request ---
            System.out.println("\n[*] Phase 4b: QueryInfo test...");
            sock = new java.net.Socket();
            sock.connect(new java.net.InetSocketAddress("127.0.0.1", 9876), 2000);
            out = sock.getOutputStream();
            in = sock.getInputStream();

            // Init handshake
            sendPacket(out, 1, new byte[]{0x00, 0x01, 'Y','e','l','l','o','w','B','o','x',
                    '/','1','.','8','.','1','3','\0'});
            readPacket(in); // consume Init response

            // QueryInfo request: command 4 (QueryInfo)
            // Format: \x04 + TAG_TUPLE_VLI_LEN(30) + VLU(count) + identifiers
            // Each identifier: 0x8d + name + \0
            java.io.ByteArrayOutputStream qBuf = new java.io.ByteArrayOutputStream();
            qBuf.write(0x04); // command = QueryInfo
            String[] queryKeys = {"device", "brand", "diskInfo", "fileMapping"};
            qBuf.write(30); // TAG_TUPLE_VLI_LEN
            qBuf.write(queryKeys.length); // VLU(4)
            for (String key : queryKeys) {
                qBuf.write(0x8d); // TAG_ID_STRING_COMPACT
                qBuf.write(key.getBytes("ASCII"));
                qBuf.write(0x00);
            }

            byte[] qBody = qBuf.toByteArray();
            sendPacket(out, 2, qBody);
            System.out.println("[+] Sent QueryInfo (" + qBody.length + " bytes)");

            // Read QueryInfo response
            sock.setSoTimeout(5000);
            byte[] qResp = readPacket(in);
            if (qResp != null) {
                StringBuilder hex = new StringBuilder();
                for (int i = 0; i < Math.min(qResp.length, 128); i++) {
                    hex.append(String.format("%02x ", qResp[i] & 0xFF));
                }
                System.out.println("[+] QueryInfo response (" + qResp.length + " bytes):");
                System.out.println("    " + hex.toString().trim());
            }

            sock.close();
        } catch (java.net.ConnectException e) {
            System.out.println("[-] Emulator not running on :9876");
            System.out.println("    Start: python3 emulator/emulator.py --port 9876 --verbose");
        } catch (Exception e) {
            System.out.println("[-] " + e.getClass().getSimpleName() + ": " + e.getMessage());
        }
    }

    // --- NFTP packet helpers ---
    private static void sendPacket(java.io.OutputStream out, int pktId, byte[] body) throws Exception {
        int totalLen = 4 + body.length;
        int w0 = totalLen & 0x7FFF;
        int w1 = pktId & 0x3FFF;
        byte[] frame = new byte[4 + body.length];
        frame[0] = (byte)(w0 & 0xFF); frame[1] = (byte)((w0 >> 8) & 0xFF);
        frame[2] = (byte)(w1 & 0xFF); frame[3] = (byte)((w1 >> 8) & 0xFF);
        System.arraycopy(body, 0, frame, 4, body.length);
        out.write(frame);
        out.flush();
    }

    private static byte[] readPacket(java.io.InputStream in) throws Exception {
        byte[] hdr = new byte[4];
        int n = 0;
        while (n < 4) n += in.read(hdr, n, 4 - n);
        int rw0 = (hdr[0]&0xFF)|((hdr[1]&0xFF)<<8);
        int rLen = (rw0 & 0x7FFF) - 4;
        if (rLen <= 0) return new byte[0];
        byte[] body = new byte[rLen];
        n = 0;
        while (n < rLen) n += in.read(body, n, rLen - n);
        return body;
    }

    // --- JNI mocks ---
    // The native code will call back to Java to read Configuration fields.
    // We intercept those here.

    @Override
    public DvmObject<?> getObjectField(BaseVM vm, DvmObject<?> dvmObject, String signature) {
        System.out.println("[JNI] getObjectField: " + signature);
        switch (signature) {
            case "com/nng/core/SDK$Configuration->bootScript:Lcom/nng/core/SDK$Configuration$BootScript;":
                return null; // no boot script
            case "com/nng/core/SDK$Configuration->onInit:Ljava/util/function/Consumer;":
                return null;
            case "com/nng/core/SDK$Configuration->onEngineStatusChange:Ljava/util/function/Consumer;":
                return null;
            case "com/nng/core/SDK$Configuration->connectivityConfig:Lcom/nng/core/SDK$Configuration$ConnectivityConfig;":
                return null;
            case "com/nng/core/SDK$Configuration->deviceAuth:Lcom/nng/core/SDK$Configuration$DeviceAuth;":
                return null;
            case "com/nng/core/SDK$Configuration->licoilConfig:Lcom/nng/core/SDK$Configuration$LicoilConfig;":
                return null;
            case "com/nng/core/SDK$Configuration->commandLineArguments:Ljava/util/List;":
                return null;
            case "com/nng/core/SDK$Configuration->subPaths:Ljava/util/List;":
                return null;
            case "com/nng/core/SDK$Configuration->vaultConfigs:Ljava/util/List;":
                return null;
            case "com/nng/core/SDK$Configuration->threaded:Ljava/lang/Boolean;":
                return DvmBoolean.valueOf(vm, false); // don't thread
            case "com/nng/core/SDK$Configuration->rootPath:Ljava/lang/String;":
                return new StringObject(vm, DEFAULT_XS_DIR + "/yellowbox");
            case "com/nng/core/SDK$Configuration->additionalResources:Ljava/lang/String;":
                return null;
            case "com/nng/core/SDK$Configuration->httpUserAgent:Ljava/lang/String;":
                return null;
        }
        return super.getObjectField(vm, dvmObject, signature);
    }

    @Override
    public boolean getBooleanField(BaseVM vm, DvmObject<?> dvmObject, String signature) {
        System.out.println("[JNI] getBooleanField: " + signature);
        return false;
    }

    @Override
    public int getIntField(BaseVM vm, DvmObject<?> dvmObject, String signature) {
        System.out.println("[JNI] getIntField: " + signature);
        return 0;
    }

    @Override
    public DvmObject<?> callObjectMethod(BaseVM vm, DvmObject<?> dvmObject, String signature, VarArg varArg) {
        System.out.println("[JNI] callObjectMethod: " + signature);
        switch (signature) {
            case "java/lang/Boolean->booleanValue()Z":
                return null;
            case "java/util/List->size()I":
                return null;
            case "java/util/List->get(I)Ljava/lang/Object;":
                return null;
        }
        return super.callObjectMethod(vm, dvmObject, signature, varArg);
    }

    @Override
    public int callIntMethod(BaseVM vm, DvmObject<?> dvmObject, String signature, VarArg varArg) {
        System.out.println("[JNI] callIntMethod: " + signature);
        switch (signature) {
            case "java/util/List->size()I":
                return 0;
        }
        return super.callIntMethod(vm, dvmObject, signature, varArg);
    }

    @Override
    public boolean callBooleanMethod(BaseVM vm, DvmObject<?> dvmObject, String signature, VarArg varArg) {
        System.out.println("[JNI] callBooleanMethod: " + signature);
        switch (signature) {
            case "java/lang/Boolean->booleanValue()Z":
                return false;
        }
        return super.callBooleanMethod(vm, dvmObject, signature, varArg);
    }

    @Override
    public DvmObject<?> callStaticObjectMethod(BaseVM vm, DvmClass dvmClass, String signature, VarArg varArg) {
        System.out.println("[JNI] callStaticObjectMethod: " + signature);
        return super.callStaticObjectMethod(vm, dvmClass, signature, varArg);
    }

    @Override
    public void callVoidMethod(BaseVM vm, DvmObject<?> dvmObject, String signature, VarArg varArg) {
        System.out.println("[JNI] callVoidMethod: " + signature);
        // Accept/ignore callbacks like onInit, onEngineStatusChange
    }

    @Override
    public void callStaticVoidMethod(BaseVM vm, DvmClass dvmClass, String signature, VarArg varArg) {
        System.out.println("[JNI] callStaticVoidMethod: " + signature);
    }

    public AndroidEmulator getEmulator() { return emulator; }
    public VM getVM() { return vm; }
    public Module getNngSdk() { return nngSdk; }

    @Override
    public FileResult<AndroidFileIO> resolve(Emulator<AndroidFileIO> emulator, String pathname, int oflags) {
        if (pathname == null) return null;
        // Provide fake /proc/stat for CPU timing
        if ("/proc/stat".equals(pathname)) {
            File fake = new File("target/rootfs/proc/stat");
            if (fake.exists()) return FileResult.success(new SimpleFileIO(oflags, fake, pathname));
        }
        // Provide fake /etc/machine-id
        if ("/etc/machine-id".equals(pathname)) {
            File fake = new File("target/rootfs/etc/machine-id");
            if (fake.exists()) return FileResult.success(new SimpleFileIO(oflags, fake, pathname));
        }
        // Let the native code access any real host path
        File file = new File(pathname);
        if (file.exists()) {
            if (pathname.contains("yellowbox") || pathname.contains("data.zip")) {
                System.out.println("[IO] " + pathname + (file.isDirectory() ? " [dir]" : " [" + file.length() + " bytes]"));
            }
            if (file.isDirectory()) {
                // Don't return DirectoryFileIO for save/cache — lseek on dirs crashes unidbg
                if (pathname.endsWith("/save") || pathname.endsWith("/save/")
                        || pathname.endsWith("/cache") || pathname.endsWith("/cache/")) {
                    return null;
                }
                return FileResult.success(new DirectoryFileIO(oflags, pathname, file));
            }
            return FileResult.success(new SimpleFileIO(oflags, file, pathname));
        }
        if (pathname.startsWith(DEFAULT_XS_DIR) || pathname.startsWith("/home/")) {
            System.out.println("[IO] NOT FOUND: " + pathname);
        }
        return null;
    }

    @Override
    public void close() {
        try {
            if (emulator != null) emulator.close();
        } catch (IOException ignored) {}
    }

    public static void main(String[] args) {
        String libDir = args.length > 0 ? args[0] : DEFAULT_LIB_DIR;
        String xsDir = args.length > 1 ? args[1] : DEFAULT_XS_DIR;
        System.out.println("Loading NNG SDK from: " + libDir);
        try (NngSdkEmulator emu = new NngSdkEmulator(libDir)) {
            System.out.println("[+] NNG SDK loaded successfully");
            System.out.println("[*] Attempting engine initialization...");
            emu.initialize(xsDir);
        } catch (Exception e) {
            System.err.println("[-] Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
