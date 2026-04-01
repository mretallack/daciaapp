# NNG SDK Investigation — How We Discovered the 0x8d Compact Format

## Summary

We bundled the real NNG SDK native libraries and YellowBox `.xs` scripts into
the NFTP Probe app to discover how the NNG compact serialisation format encodes
symbol identifiers on the wire. This investigation revealed that identifiers are
encoded as `0x8d` + null-terminated string — not integer symbol IDs as we
originally assumed from decompiling the Java SDK.

The NNG SDK files have been removed from the app since they are no longer needed.
Our Java NFTP implementation now uses the validated `0x8d` format directly.

## What We Bundled

### Native Libraries (`nftp-app/src/main/jniLibs/arm64-v8a/`)

| File | Size | Purpose |
|------|------|---------|
| `liblib_nng_sdk.so` | 30MB | NNG SDK — .xs script interpreter, serialisation, socket, crypto |
| `liblib_base.so` | 6.6KB | Base support library |
| `liblib_memmgr.so` | 53KB | Memory manager |
| `libc++_shared.so` | 955KB | C++ standard library |

These were extracted from the official Dacia Map Update APK (`com.nng.pbmu.dacia`
v1.8.13, `config.arm64_v8a.apk` split).

### Java SDK Stubs (`nftp-app/libs/`)

| File | Size | Purpose |
|------|------|---------|
| `nng-sdk-stubs.jar` | 2.2MB | Java API stubs for `com.nng.core.SDK`, `com.nng.uie.api.*` |

Extracted from the APK's `classes.dex` — provides the Java interface to the
native SDK (`SDK.Start()`, `asyncEval()`, `Configuration`, etc.).

### YellowBox Scripts (`nftp-app/src/main/assets/nng_data/`)

The full `.xs` script bundle from the Dacia app's `resources/data.zip`:

- `yellowbox/project.ini` — SDK project config (`skin=yellowbox`)
- `yellowbox/src/main.xs` → entry point, imports `connections.xs`
- `yellowbox/src/toolbox/connections.xs` — socket + NFTP module init
- `xs_modules/core/nftp.xs` — NFTP protocol implementation (shared with head unit)
- `xs_modules/core/*.xs` — core modules (dispose, functional, observe, etc.)
- `xs_modules/uie/` — UI engine modules (components, themes, samples)
- `xs_modules/fmt/` — formatting modules
- `xs_modules/analytics/` — analytics modules

Total: 139 `.xs` files, ~2.1MB.

### JNI Bridge (`nftp-app/src/main/cpp/`)

- `nng_probe.c` — JNI function `NngProbe_probeSymbols()` that called the native
  `symbol_intern` function to look up symbol IDs

### Java Wrappers (`nftp-app/src/main/java/com/dacia/nftpprobe/`)

- `NngEngine.java` — extended `com.nng.core.SDK`, handled engine init, asset
  extraction, `asyncEval()` calls, TCP connection via NNG socket module
- `NngProbe.java` — JNI wrapper for `probeSymbols()` native call
- `NoOpConsumer.java` — utility for SDK callbacks

### Build Config

- `CMakeLists.txt` — built `libnng_probe.so` from `nng_probe.c`
- `build.gradle` — NDK config, Kotlin coroutines deps (for SDK async API),
  `fileTree(dir: 'libs')` for the stubs jar

## What Worked

1. **Loading the native libraries** — `liblib_nng_sdk.so` loaded successfully on
   arm64 Android devices
2. **Starting the SDK engine** — `SDK.Start()` returned SUCCESS, engine reached
   RUNNING state
3. **asyncEval with simple expressions** — `'hello'`, `1+1`, string operations
4. **Boot script execution** — scripts placed at `rootPath/boot.xs` ran at startup
5. **Project system** — `project.ini` with `skin=yellowbox` was recognised
6. **System.import in asyncEval** — could import `system://socket`,
   `system://serialization`, `system://core.types`, `system://math`
7. **TCP connection from .xs** — `sock.connect(#{host:'10.0.0.78', port:9876})`
   connected to our emulator
8. **Real NNG serialisation** — `ser.Stream(@compact).add(@symbol).transfer()`
   produced the actual wire bytes, revealing the `0x8d` format

## What Didn't Work

1. **asyncEval isolation** — `import` statements returned error -14 (EFAULT).
   asyncEval is a sandbox that cannot load modules via `import ... from`
2. **Boot script ↔ asyncEval bridge** — variables set in boot scripts were not
   visible to asyncEval (completely separate scopes)
3. **Full module chain loading** — the YellowBox module chain depends on UI
   components, fonts, Android services etc. that we couldn't provide
4. **Boot script file I/O** — `import {openSync} from "system://fs"` failed
   silently in boot script context
5. **console.log from boot scripts** — output didn't appear in logcat without
   the full project system active
6. **Getting the real app's NNG code to connect** — the full YellowBox module
   chain never fully initialised due to missing UI/service dependencies

## The Breakthrough

Despite asyncEval's limitations, we found that `System.import()` (dynamic import)
DID work within asyncEval for system modules. This let us:

1. Import `system://serialization` to get the native `Stream` class
2. Create a `Stream(@compact)` — the same serialiser the real app uses
3. Call `.add(@symbol)` for each symbol we cared about
4. Call `.transfer()` to get the raw bytes as an `ArrayBuffer`
5. Send those bytes over a TCP socket to a capture server
6. Hex-dump the bytes to see the exact wire encoding

Every symbol came back as: `0x8d` + null-terminated UTF-8 string name.

This meant the entire symbol ID investigation (Ghidra decompilation, brute-force
scanning, two separate ID counters, etc.) was solving the wrong problem. The
compact serialisation format doesn't use integer IDs at all — it sends the
symbol name as a string.

## Key Insight

The Java SDK's `Serializer.java` uses `IdSymbolVLI` (integer IDs) because it
operates in the Java bridge layer which maps symbols to integers. But the native
`.xs` runtime's `Stream(@compact)` uses `TAG_ID_STRING | MODIFIER` (0x8d) with
null-terminated strings. The NFTP protocol always uses `@compact` mode, so the
wire format is always strings.

## Where the Files Came From

- **APK**: Downloaded from Google Play (`com.nng.pbmu.dacia` v1.8.13)
- **Native libs**: Extracted from `config.arm64_v8a.apk` split APK
- **Java stubs**: Decompiled from `classes.dex` using jadx
- **.xs scripts**: Extracted from `assets/resources.zip` → `resources/data.zip`
- **Ghidra analysis**: Decompiled `liblib_nng_sdk.so` (31MB) to understand
  `symbol_intern`, `ifapi_token_alloc_symbol_range`, and the symbol table
  structure — see `docs/all-736-symbols.txt` and `docs/native-symbol-slots.txt`

## References

- `nftp.md` — "BREAKTHROUGH: NNG Compact Serialisation" section has the full
  hex dumps and analysis
- `NNG_SDK_INTEGRATION.md` — detailed log of all integration attempts and failures
- `docs/all-736-symbols.txt` — 736 SDK built-in symbols extracted via Ghidra
- `docs/native-symbol-slots.txt` — native symbol slot assignments from decompilation
