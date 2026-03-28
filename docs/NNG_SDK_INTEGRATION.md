# NFTP Probe — NNG SDK Integration Attempts

## Goal

Use the real NNG SDK (`liblib_nng_sdk.so`) from the Dacia Map Update app to:
1. Connect to the emulator/head unit via TCP
2. Send QueryInfo requests with correct symbol IDs
3. Get disk usage info (`@diskInfo`, `@freeSpace`)

## Background

The head unit's QueryInfo command requires NNG symbol IDs (integer identifiers for `@device`, `@brand`, `@diskInfo`, etc.). Our Java NFTP implementation can send GetFile successfully, but QueryInfo fails because:
- The head unit expects symbol IDs encoded as `IdSymbolVLI` (tag 29)
- Symbol IDs are assigned at runtime by the NNG SDK during module loading
- The phone app and head unit share the same SDK, so they get matching IDs
- Our Java app doesn't run the NNG SDK, so we don't know the correct IDs

## What Works

### Java NFTP Implementation (our code)
- ✅ TCP connection to emulator
- ✅ Init handshake (YellowBox/YellowTool)
- ✅ GetFile — reads `license/device.nng` from head unit (SWID, VIN, iGo version)
- ✅ QueryInfo with string identifiers — works against **emulator** (emulator accepts strings)
- ❌ QueryInfo with string identifiers — fails against **real head unit** (returns empty)
- ❌ QueryInfo with symbol IDs — we don't know the correct IDs

### NNG SDK Engine
- ✅ Loading `liblib_nng_sdk.so` (+ `liblib_base.so`, `liblib_memmgr.so`)
- ✅ `nng_Core_Initialize` / `SDK.Start()` — engine starts successfully
- ✅ `asyncEval` with simple expressions — `'hello'`, `1+1` work
- ✅ Boot script runs (no errors in crash logs)
- ✅ `NngProbe.probeSymbols()` — can call `symbol_intern` to get SDK built-in symbol IDs

## What Doesn't Work

### asyncEval Limitations (error -14 / EFAULT)
The `asyncEval` API is an isolated sandbox that does NOT support:
- ❌ `import` statements — always returns error -14
- ❌ `typeof` — error -14
- ❌ `Object.keys()` — "Cannot resolve identifier 'Object'"
- ❌ `JSON.stringify()` — "Cannot resolve identifier 'JSON'"
- ❌ Dynamic `import()` — "Cannot resolve identifier 'Object'"

asyncEval is designed for simple value expressions only. It cannot load modules.

### Boot Script ↔ asyncEval Isolation
- ❌ `globalThis.xxx = ...` in boot script is NOT visible to asyncEval
- ❌ Boot script and asyncEval run in completely separate scopes
- ❌ No bridge mechanism between them

### Boot Script File I/O
- ❌ `import {openSync} from "system://fs"` — fails silently in boot script context
- ❌ Writing files from boot script — no output produced
- ❌ `console.log()` from boot script — doesn't appear in Android logcat (needs `log_2="logcat:console:3"` in project.ini, but project system isn't active when using boot scripts)

### Socket Module
- ❌ `import {connect} from "system://socket"` — fails in asyncEval (error -14)
- ❌ Cannot make TCP connections from the NNG SDK

### Project System (project.ini)
- ❌ Placing `yellowbox/project.ini` in rootPath doesn't auto-load `main.xs`
- ❌ The SDK needs the full app data directory structure (extracted from `resources.zip`)
- ❌ Without the full YellowBox module chain, the project system doesn't initialize

## Architecture Understanding

### How the Real App Works
```
APK → resources.zip → data.zip → .xs scripts
                                    ├── yellowbox/project.ini (skin=yellowbox)
                                    ├── yellowbox/src/main.xs (entry point)
                                    │   └── imports connections.xs
                                    │       └── imports {connect,listen} from "system://socket"
                                    │       └── imports * as nftp from "system://yellow.nftp"
                                    │       └── imports {queryInfo,...} from "core/nftp.xs"
                                    └── xs_modules/core/nftp.xs (NFTP protocol)
```

The SDK loads the full module chain at startup. The socket module, NFTP protocol, and serialization are all available within the engine's runtime. The Java side communicates via:
- `exportModule()` — registers Java-backed modules (e.g., `android://aoa`)
- `RemoteObject.invoke()` — calls from Java into .xs runtime
- Callbacks — .xs runtime calls back to Java

### Why We Can't Replicate This
1. The full module chain requires ALL .xs scripts from the app
2. Many modules depend on UI, fonts, Android services, etc.
3. The `exportModule` / `RemoteObject` API is complex and undocumented
4. asyncEval is intentionally sandboxed — no imports, no globals

## Symbol ID Discovery (Previous Work)

### What We Know
- SDK built-in symbols (IDs 1–~1870): deterministic, same on phone and head unit
- `.xs` parser symbols (IDs 100000+): depend on script load order
- Phone-side IDs for `@device`=100002, `@brand`=100003, etc. — confirmed via `symbol_intern`
- Head unit has DIFFERENT IDs — scan of 100000–101000 returned all "unknown"
- Brute-force scan of 0–5000 also returned "unknown" for all

### The Real Problem
Symbol IDs are assigned sequentially at runtime. The phone app and head unit both load the same `.xs` scripts in the same order, so they get matching IDs. But:
- We can't determine the head unit's load order without its `.xs` scripts
- The head unit runs YellowTool (server), the phone runs YellowBox (client)
- They share `core/nftp.xs` but have different app-level scripts

## Possible Next Steps

### Option A: USB Traffic Capture
Intercept the real Dacia app's USB traffic to the head unit:
- Use a USB protocol analyzer between phone and head unit
- Capture the actual QueryInfo packets with correct symbol IDs
- Decode the wire format to extract the integer IDs

### Option B: Extract YellowTool Scripts from Firmware
Get the head unit's `.xs` scripts to determine its symbol load order:
- Extract from firmware update file
- Parse the script import chain
- Calculate symbol IDs from load order

### Option C: Focus on GetFile
Accept that QueryInfo won't work and extract all needed data via GetFile:
- ✅ `license/device.nng` — SWID, VIN, iGo version (already working)
- Potentially read other files for disk info if paths are known

### Option D: Full App Replication
Bundle the complete YellowBox `.xs` scripts and resources:
- Extract all files from the real app's `resources.zip`
- Set up the full directory structure
- Register required Java modules (AOA, download manager, etc.)
- Very complex, essentially rebuilding the real app

## Emulator

The Python emulator (`emulator/emulator.py`) supports:
- ✅ Init handshake
- ✅ GetFile with fake files
- ✅ QueryInfo with string identifiers (returns fake disk info, device info, etc.)
- ✅ CheckSum (MD5/SHA1)

Run: `python3 emulator/emulator.py --port 9876 --verbose`

Connect from app: enter server IP, tap Connect

## Files

- `nftp-core/` — Java NFTP library (VLU, packets, connection, probe, serializer)
- `nftp-app/` — Android app (USB AOA + TCP emulator support)
- `nftp-app/src/main/jniLibs/` — NNG SDK native libraries
- `nftp-app/src/main/assets/xs_modules/` — .xs scripts for boot
- `emulator/` — Python head unit emulator
- `nftp.md` — Full NFTP protocol documentation
