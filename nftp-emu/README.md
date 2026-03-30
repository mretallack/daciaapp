# nftp-emu — NNG SDK Emulation on x86

Run the real NNG SDK native libraries (`liblib_nng_sdk.so` + `.xs` scripts) on an x86 Linux server using unidbg, with the USB AOA transport redirected to TCP — so we can point it at our Python emulator and capture the exact NFTP wire protocol.

## Goal

The real Dacia Map Update app runs the NNG SDK engine which loads `.xs` scripts that implement the full NFTP protocol. We want to run that same code path on this server, but instead of talking to a real head unit over USB, redirect the connection to our Python emulator on `localhost:9876`.

This gives us:
1. The exact bytes the real NNG code sends for QueryInfo, including correct serialisation
2. Full protocol flow capture (Init → QueryInfo → GetFile → etc.)
3. A way to test our emulator against the real client code
4. Understanding of any protocol details we've missed

## Architecture

```
┌─────────────────────────────────────────────────┐
│              nftp-emu (Java, x86)               │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  unidbg (Unicorn2 ARM64 emulator)        │   │
│  │                                          │   │
│  │  Native libraries:                       │   │
│  │    liblib_nng_sdk.so  (29 MB)            │   │
│  │    liblib_base.so                        │   │
│  │    liblib_memmgr.so                      │   │
│  │    libc++_shared.so (bundled by unidbg)  │   │
│  │                                          │   │
│  │  .xs scripts (from resources/data.zip):  │   │
│  │    src/main.xs → connections.xs          │   │
│  │    xs_modules/core/nftp.xs               │   │
│  │    src/toolbox/device.xs, updater.xs     │   │
│  │                                          │   │
│  │  Hooks:                                  │   │
│  │    eventfd@plt → fake fds (100+)         │   │
│  │    fstat/fstatat/ioctl → return 0        │   │
│  │    /proc/stat, /etc/machine-id → fakes   │   │
│  │    JNI Configuration → full field mock   │   │
│  │    Direct TCP NFTP (bypasses .xs engine)  │   │
│  └──────────────────────────────────────────┘   │
│                         │                        │
│                    TCP :9876                      │
│                         │                        │
└─────────────────────────┼────────────────────────┘
                          ▼
              ┌───────────────────────┐
              │  Python emulator      │
              │  (emulator.py :9876)  │
              └───────────────────────┘
```

## Native Libraries

From the decompiled Dacia Map Update APK v1.8.13:

| Library | Size | Purpose |
|---------|------|---------|
| `liblib_nng_sdk.so` | 29 MB | NNG SDK — .xs engine, serialisation, NFTP native module |
| `liblib_base.so` | ~1 MB | Base utilities |
| `liblib_memmgr.so` | ~100 KB | Memory manager |

Location: `/home/mark/git/daciaapp/apk_arm64/lib/arm64-v8a/`

## .xs Scripts

Extracted from the APK and packed into `resources/data.zip` for the engine to load:

| Script | Purpose |
|--------|---------|
| `src/main.xs` | Entry point, imports connections |
| `src/toolbox/connections.xs` | Socket + NFTP connection setup |
| `xs_modules/core/nftp.xs` | NFTP protocol (framing, commands, serialisation) |
| `src/toolbox/device.xs` | Device identification |
| `src/toolbox/updater.xs` | Update logic |

Location: `/home/mark/git/daciaapp/xs_extract/data/yellowbox/`

The engine expects scripts in `resources/data.zip` — a zip of the yellowbox directory contents (`.xs`, `.json`, `.ini`, `.nss`, `.ui`, `.css`, `.txt` files).

## Status

### Phase 1: Load the SDK ✅

All native libraries load successfully via unidbg + Unicorn2:
- `.init_array` constructors (862 functions) execute
- `JNI_OnLoad` called for all libraries
- Missing `libandroid.so` dependency is non-fatal (UI/window functions not needed)

### Phase 2: Engine initialisation ✅

`nng_Core_Initialize` returns 1 (success). The call sequence:

```
SetRootPathNative("/path/to/yellowbox")     → OK
SetHttpUserAgentNative("NftpProbe/1.0")     → OK
InitializeNative(config)                     → partially fails (jfieldID null)
  └─ but sets up global config object via __cxa_guard at 0x1dc2d70
nng_Core_EnableTesting()                     → OK
nng_Core_Initialize(config_struct)           → returns 1 ✅
```

Key discoveries:
- `nng_Core_Initialize` takes a pointer to a 292-byte C config struct (not void). First 8 bytes = struct size (0x124). Zeroed struct with size field works.
- `InitializeNative` fails because unidbg's `GetFieldID` returns null for the `SDK$Configuration` class fields (cached jfieldIDs at `0x1dc2b58+`). But it still initialises the global config object at `0x1dc2d70` via `__cxa_guard_acquire`.
- The global config is initialised by `FUN_ba72f4` with defaults. `FUN_ba6394` would copy Java config values into it, but that never runs due to the JNI failure. The defaults are sufficient.

### Phase 3: Event loop ✅

`nng_Core_RunLoop` returns 17 (success — ran and exited cleanly).

The engine:
1. Creates 4 eventfds (hooked to return fake fds 100-103)
2. Opens `resources/data.zip` and loads `.xs` scripts
3. Looks for optional files: `ignored_asserts.txt`, `sys.ini`, `sys.txt` (not found, OK)
4. Accesses `save/`, `cache/`, `config/` directories
5. Runs the event loop and exits (no connections to process)

### Phase 4: Direct NFTP over TCP ✅

The nftp-emu connects directly to the Python emulator via TCP and performs the full NFTP protocol:

```
[+] Connected to emulator on :9876
[+] Sent Init (23 bytes)
[+] Emulator identified as: FakeHeadUnit/1.0
[+] Sent QueryInfo (41 bytes)
[+] QueryInfo response (386 bytes):
    00 1e 04 20 04 8d 73 77 69 64 00 03 0d 45 4d 55 ...
```

The QueryInfo response contains device info (`@swid`, `@vin`, `@igoVersion`, `@appcid`), brand info, disk info, and file mapping — all correctly serialized in NNG compact format.

Additional fixes for this phase:
- **JNI_OnLoad** — must be called explicitly via `sdk.callJNI_OnLoad()`. Crashes on ioctl but caches all field IDs before the crash.
- **Pre-register Configuration fields** — `vm.resolveClass("com/nng/core/SDK$Configuration")` + `getFieldID()` for all 15 fields BEFORE loading the SDK.
- **`/etc/machine-id`** — engine reads it during JNI_OnLoad init.

The `.xs` script engine still crashes during `RunLoop` (corrupted pointer from 320MB mmap heap), so the real NNG code can't drive the NFTP conversation. Instead, nftp-emu constructs NFTP packets directly using the correct framing format and NNG compact serialization.

### .xs Script Engine (BLOCKED)

The `.xs` script engine crashes when parsing `data.zip`:
```
Read memory failed: address=0x7913c96407780
```
This is a corrupted pointer from the engine's 320MB mmap heap. The heap address assigned by unidbg doesn't match what the engine's bytecode interpreter expects. Fixing this would require understanding the `.xs` engine's memory layout, which is deeply embedded in the 29MB SDK binary.

## Hooks & Workarounds

| Hook | Why | How |
|------|-----|-----|
| `eventfd@plt` (0x244910) | unidbg doesn't implement `eventfd2` syscall | HookZz replace → return fake fd (100+) |
| `fstat`/`fstatat` in libc | unidbg crashes on `newfstatat` with null path (fake fds) | HookZz replace → return 0 |
| `fstat*` PLTs in SDK | Same issue via SDK's own PLT entries | HookZz replace → return 0 |
| `ioctl` PLT + libc | unidbg crashes on ioctl during JNI_OnLoad | HookZz replace → return 0 |
| `/proc/stat` | Engine reads it for CPU timing | IOResolver → fake file with dummy stats |
| `/etc/machine-id` | Engine reads it during JNI_OnLoad | IOResolver → fake 32-char hex ID |
| `save/`, `cache/`, `config/` dirs | Engine expects them to exist | Created empty dirs in yellowbox |
| `resources/data.zip` | Engine loads .xs scripts from zip | Created zip of .xs/.json/.ini files |

## Key Findings

### ifapi_token_from_identifier works without engine init

The exported C function `ifapi_token_from_identifier` lazily creates the symbol table on first call. Works even when `nng_Core_Initialize` hasn't been called.

```
SDK built-in symbols (deterministic across all devices):
  @compact=1341  @name=199  @size=6  @error=393
  @path=370  @children=787  @md5=1868  @sha1=1869

Parser symbols (assigned sequentially from 100000, order-dependent):
  @device=100000  @brand=100001  @fileMapping=100002
  @diskInfo=100003  @ls=100004
```

Parser symbol IDs depend on call order — the head unit's YellowTool scripts load symbols in a different order than YellowBox. But the wire protocol uses `0x8d` + string identifiers, making integer IDs irrelevant.

### NNG engine internal structure

- Global config object: `0x1dc2d70` (292 bytes, initialised by `FUN_ba72f4`)
- Init-once guard: `0x1dc2ee0` (set by `__cxa_guard_acquire`)
- Symbol table global: `0x1dc2b58+` area (cached jfieldIDs and symbol table pointer)
- `nng_Core_Initialize` tail-calls `FUN_ba6394(global_config, config_struct)` which does the real work
- `FUN_ba6394` sets up C++ streams, reads config fields, creates eventfds, initialises the .xs engine

### Deserializer bugs found (from real head unit testing)

While debugging the emulator, we connected the real app to the head unit and found three deserializer bugs:

1. **Tag 33 (FailureVLILen)** — not handled. Head unit returns this for fields it can't provide (e.g. `@appcid`). Contains key-value pairs like `{@message: "Object has no such property @brand"}`.

2. **Tag 25 (simple Failure)** — not handled. Head unit returns `0x19 0x03` for `@igoVersion`, `@swid`, `@sku`, `@vin`, `@imei`. A failure marker with a VLU error code.

3. **Tag 0x0d (IdentifierString) without modifier** — head unit sends null-terminated strings with tag `0x0d`, but deserializer expected VLU-length-prefixed. Caused `StringIndexOutOfBoundsException` on `@diskInfo` response.

4. **Tag 0x03 (String) without modifier** — same issue. Head unit sends null-terminated strings even without the `0x80` modifier bit. Caused the original 7.7 GB OOM crash.

### Head unit response data (YellowTool/1.18.1+15418192 v1)

```
@fileMapping → empty dict (no custom mapping)
@device → {
  @modelName: "DaciaAutomotiveDeviceCY20_ULC4dot5"
  @brandName: "DaciaAutomotive"
  @appcid: FAILURE("Object has no such property @brand")
  @igoVersion: FAILURE  @swid: FAILURE  @sku: FAILURE
  @vin: FAILURE  @imei: FAILURE  @firstUse: 0
}
@brand → {
  @agentBrand: "Dacia_ULC"
  @modelName: "DaciaAutomotiveDeviceCY20_ULC4dot5"
  @brandName: "DaciaAutomotive"
  @brandFiles: [
    {path: "/NaviSync/license/device.nng"},
    {path: "/NaviSync/CONTENT/brand.txt", content: "dacia"}
  ]
}
@diskInfo → {size: ~2.05 GB, available: ~1.15 GB}
```

## Build & Run

```bash
cd /home/mark/git/daciaapp/nftp-probe
./gradlew :nftp-emu:run
```

## Dependencies

- Java 11+
- unidbg 0.9.9 (Gradle dependency)
- Unicorn2 backend (Gradle dependency)
- ARM64 native libraries from APK (`/home/mark/git/daciaapp/apk_arm64/lib/arm64-v8a/`)
- .xs scripts (`/home/mark/git/daciaapp/xs_extract/data/yellowbox/`)
- Real APK for DalvikVM class resolution (`/home/mark/git/daciaapp/xapk_extract/com.nng.pbmu.dacia.apk`)

## References

- [unidbg](https://github.com/zhkl0228/unidbg) — Android native library emulator
- [nftp.md](../nftp.md) — Full NFTP protocol documentation
- [NNG_SDK_INTEGRATION.md](../docs/NNG_SDK_INTEGRATION.md) — Previous SDK integration attempts
- [nng-sdk-investigation.md](../docs/nng-sdk-investigation.md) — Ghidra decompilation findings
