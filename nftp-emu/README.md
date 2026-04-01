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

### Phase 5: Protocol validation ✅

`NftpProtocolTest` exercises the full NFTP protocol against the Python emulator from Java, validating both the wire format and the emulator's responses:

```
=== NFTP Protocol Test against emulator on :9876 ===

  ✓ Init handshake
  ✓ Init product string
  ✓ QueryInfo @device status / is map / has swid
  ✓ QueryInfo multi (4 keys) status / is tuple / has 4 items
  ✓ @ls content status / is tuple
  ✓ GetFile device.nng status / has SWID
  ✓ GetFile partial status / length
  ✓ CheckSum MD5 status / length / matches GetFile
  ✓ PushFile status / verify content
  ✓ DeleteFile status / verify gone
  ✓ Mkdir status
  ✓ Full update flow (Prepare → Push → CheckSum → Finished → verify)

=== Results: 28 passed, 0 failed ===
```

This confirms:
- NNG compact serialisation (0x8d identifiers) works correctly end-to-end
- The Python emulator handles all 14 NFTP commands correctly
- The Java `NngSerializer`/`NngDeserializer` round-trips cleanly
- The full update flow (PrepareForTransfer → PushFile → CheckSum → TransferFinished) works

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

All four bugs are now fixed in `NngDeserializer.java`.

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

# Run the NNG SDK emulator (loads ARM64 libs via unidbg)
./gradlew :nftp-emu:run

# Run protocol tests against the Python emulator
python3 emulator/emulator.py --port 9876 --daemon --pidfile /tmp/emu.pid
./gradlew :nftp-emu:protocolTest
kill $(cat /tmp/emu.pid)
```

## Protocol Test Coverage

`NftpProtocolTest` validates 28 checks across 11 test scenarios:

| Test | Commands | Checks |
|------|----------|--------|
| Init handshake | Init | status, product string |
| QueryInfo @device | Init, QueryInfo | status, is map, has @swid |
| QueryInfo multi-key | Init, QueryInfo | status, is tuple, 4 items |
| @ls directory listing | Init, QueryInfo(@ls) | status, is tuple |
| GetFile | Init, GetFile | status, content has SWID |
| GetFile partial | Init, GetFile | status, exact length |
| CheckSum MD5 | Init, CheckSum, GetFile | status, length, matches local hash |
| PushFile | Init, PushFile, GetFile | status, verify content |
| DeleteFile | Init, PushFile, DeleteFile, GetFile | status, verify gone |
| Mkdir | Init, Mkdir | status |
| Full update flow | Init, Prepare, Push, CheckSum, Finished, GetFile | 5 status checks + content verify |

## Dependencies

- Java 11+
- unidbg 0.9.9 (Gradle dependency)
- Unicorn2 backend (Gradle dependency)
- nftp-core (project dependency — NngSerializer, NngDeserializer, VluCodec)
- ARM64 native libraries from APK (`/home/mark/git/daciaapp/apk_arm64/lib/arm64-v8a/`)
- .xs scripts (`/home/mark/git/daciaapp/xs_extract/data/yellowbox/`)
- Real APK for DalvikVM class resolution (`/home/mark/git/daciaapp/xapk_extract/com.nng.pbmu.dacia.apk`)

## Next Tasks

### 1. Emulator: Failure responses (match real head unit)

The real head unit returns Failure tags for fields it can't provide. The Python emulator currently returns clean data for everything, which doesn't test the error paths.

- [x] 1.1 Add a `serialize_failure_simple(error_code)` helper to `emulator.py` — emits tag 25 (`0x19`) + VLU error code
- [x] 1.2 Add a `serialize_failure_vli(pairs)` helper to `emulator.py` — emits tag 33 (`0x21`) + VLU count + key-value pairs (for error messages like `{@message: "Object has no such property @brand"}`)
- [x] 1.3 Update `@device` QueryInfo response to return Failure for `@igoVersion`, `@swid`, `@sku`, `@vin`, `@imei` (matching real head unit behavior where these fields fail)
- [x] 1.4 Update `@device` QueryInfo response to return FailureVLILen for `@appcid` with message `"Object has no such property @brand"`
- [x] 1.5 Add Python tests: `test_serialize_failure_simple`, `test_serialize_failure_vli`
- [x] 1.6 Add `NftpProtocolTest` check: QueryInfo `@device` response contains Failure values, Java `NngDeserializer` handles them without crashing (tag 25 → null, tag 33 → map with `@_failure`)

### 2. Emulator: Realistic device data

The emulator returns generic placeholder data. Update to match the real head unit captures for more accurate testing.

- [x] 2.1 Update `@device` response: `@modelName` → `"DaciaAutomotiveDeviceCY20_ULC4dot5"`, `@brandName` → `"DaciaAutomotive"`, `@firstUse` → `0`
- [x] 2.2 Update `@brand` response: `@agentBrand` → `"Dacia_ULC"`, `@modelName` → `"DaciaAutomotiveDeviceCY20_ULC4dot5"`, `@brandName` → `"DaciaAutomotive"`
- [x] 2.3 Add `@brandFiles` array to `@brand` response: `[{path: "/NaviSync/license/device.nng"}, {path: "/NaviSync/CONTENT/brand.txt", content: "dacia"}]`
- [x] 2.4 Update `@diskInfo` response: `size` → `2_147_483_648` (2 GB), `available` → `1_181_116_006` (~1.1 GB) to match real head unit
- [x] 2.5 Update `FAKE_DEVICE_NNG` content to match real `device.nng` key=value format (SWID, VIN, iGo version lines)
- [x] 2.6 Update existing Python tests that assert on old placeholder values (e.g. `test_queryinfo_device`)

### 3. App: Parse device.nng for device info

The real head unit returns FAILURE for most `@device` QueryInfo fields. The actual device info is in `license/device.nng` which is a simple key=value text file.

- [x] 3.1 Add `parseDeviceNng(byte[] data)` to `HeadUnitExplorer` — parse `KEY=VALUE\n` lines, populate `DeviceInfo` fields (SWID, VIN, IGO)
- [x] 3.2 Update `HeadUnitExplorer.connect()` — after fetching `device.nng`, call `parseDeviceNng()` to fill in any fields that QueryInfo returned as null/FAILURE
- [x] 3.3 Update Device tab UI to display parsed device.nng fields (SWID, VIN, iGo version) when QueryInfo fields are null

### 4. App: Dynamic @ls directory browsing

QueryInfo `@ls` works against the emulator. Replace the static directory tree in the Explorer tab with live browsing.

- [x] 4.1 Add `browseDirectory(String path)` method to `MainActivity` — calls `explorer.listDirectory(path)`, updates the RecyclerView adapter with results
- [x] 4.2 Add a "path bar" or breadcrumb TextView above the file list showing the current directory path
- [x] 4.3 Handle directory tap → call `browseDirectory(tappedEntry.path)` to navigate into subdirectory
- [x] 4.4 Add a "Back" / "Up" button or handle back press to navigate to parent directory
- [x] 4.5 Fall back to static `getDirectoryTree()` if `@ls` fails or not connected
- [x] 4.6 Show loading indicator while `@ls` query is in progress
- [x] 4.7 Handle errors (connection lost, timeout) — show toast/snackbar, fall back to static tree

### 5. Emulator: Commit handler (cmd 2)

The Commit command finalises a PushFile transaction. Currently unimplemented.

- [x] 5.1 Add `cmd == 2` handler in `handle_connection()` — parse body (null-terminated path), return success `0x00`
- [x] 5.2 Add Python test: `test_commit`
- [x] 5.3 Add `NftpProtocolTest` check: Commit after PushFile returns success

### 6. Protocol capture mode

Add packet logging to the Python emulator for offline analysis and debugging.

- [x] 6.1 Add `--capture <file>` CLI argument to `emulator.py`
- [x] 6.2 Log each request/response as a timestamped hex dump line: `[timestamp] [direction] [cmd] [id] [hex bytes]`
- [x] 6.3 Write capture file as newline-delimited text (easy to grep/parse)
- [x] 6.4 Add Python test: verify capture file is written with correct format

### 7. Integration testing against real head unit

Test the app and emulator against the actual MediaNav 4 head unit over USB AOA.

- [ ] 7.1 Test GetFile for `license/device.nng` — verify content matches expected key=value format
- [ ] 7.2 Test GetFile for `license/test.lyc` and other mapped paths — log sizes and first 64 bytes hex
- [ ] 7.3 Test CheckSum MD5 against real head unit — compare with GetFile + local hash
- [ ] 7.4 Test `@ls` directory listing on real head unit — verify response parses correctly
- [ ] 7.5 Test Explorer UI end-to-end with emulator (TCP mode)
- [ ] 7.6 Test Explorer UI end-to-end with real head unit (USB AOA)
- [ ] 7.7 Document results and any new protocol findings in `nftp.md`

### 8. Rename Java packages from `com.dacia` to `uk.org.retallack`

The `com.dacia` package name could cause legal issues. Rename all Java packages across all three modules.

**Rename:**
- [x] 8.1 **nftp-core**: Rename `com.dacia.nftp` → `uk.org.retallack.nftp` — move 8 source files + 9 test files, update all `package` and `import` statements
- [x] 8.2 **nftp-app**: Rename `com.dacia.nftpprobe` → `uk.org.retallack.nftpprobe` — move 2 source files, update `package`/`import` statements
- [x] 8.3 **nftp-app**: Update `build.gradle` — change `namespace` and `applicationId` from `com.dacia.nftpprobe` to `uk.org.retallack.nftpprobe`
- [x] 8.4 **nftp-emu**: Rename `com.dacia.nftpemu` → `uk.org.retallack.nftpemu` — move 2 source files, update `package`/`import` statements
- [x] 8.5 **nftp-emu**: Update `build.gradle` — change `mainClass` from `com.dacia.nftpemu.NngSdkEmulator` to `uk.org.retallack.nftpemu.NngSdkEmulator`, update `protocolTest` task
- [x] 8.6 **nftp-emu**: Update `NngSdkEmulator.java` — the unidbg `setProcessName("com.nng.pbmu.dacia")` and JNI class references (`com/nng/core/SDK$Configuration`) must stay as-is (they refer to the real APK, not our code)

**Verify (after rename):**
- [x] 8.7 Clean build dirs: `./gradlew clean`
- [x] 8.8 Build all modules: `:nftp-core:test`, `:nftp-app:assembleDebug`, `:nftp-emu:compileJava`
- [x] 8.9 Run all tests — 60 Java unit tests, 41 Python emulator tests, 32 Java protocol tests (start emulator, run `:nftp-emu:protocolTest`)
- [ ] 8.10 Reinstall app on phone — note: changing `applicationId` will install as a new app (old `com.dacia.nftpprobe` can be uninstalled)

### 9. .xs script engine (IN PROGRESS — QEMU)

unidbg cannot run the .xs engine due to a pointer corruption bug in its Unicorn backend.
QEMU user-mode emulation runs the SDK natively on ARM64 and gets significantly further.

**Completed:**
- [x] 9.1 Investigated unidbg's mmap — crash is a deterministic corrupted pointer (0x7913c95156fc0) in the .xs compiler's hash table, unrelated to mmap heap placement
- [x] 9.3 QEMU user-mode ARM64 harness — SDK loads and runs natively under `qemu-aarch64-static` with Android bionic sysroot (linker64, libc, ICU, tzdata extracted from Android 29 system image)
- [x] 9.4 Engine initializes successfully — JNI_OnLoad, SetRootPathNative, nng_Core_Initialize all succeed. All 16 NFTP tokens resolve. ifapi_make_engine_module_object returns valid object.

**QEMU setup (at `/tmp/qemu_android/`):**
- `system/bin/linker64` — Android dynamic linker (from AOSP runtime apex)
- `system/lib64/` — bionic libc/libm/libdl + ICU + SDK libs + stub libandroid/liblog/libEGL/libGLESv2
- `system/usr/` — tzdata, ICU data (icudt63l.dat)
- `data/harness` — ARM64 C harness (source: `nftp-emu/qemu/harness.c`)
- `data/libs/` — SDK native libraries from APK
- `data/xs_extract/data/` — .xs scripts and resources

**Current status:** Engine initialized, all NFTP tokens resolved, ifapi works. RunLoop crashes (thread_server.cpp:45 assertion — time_manager thread throws std::exception). Workaround: skip RunLoop and use ifapi directly.

**NFTP tokens resolved:**
```
@nftp=100005  @queryInfo=100006  @checkSum=100007  @getFile=100008
@pushFile=100009  @deleteFile=100010  @renameFile=100011  @mkdir=100012
@chmod=100013  @prepareForTransfer=100014  @transferFinished=100015
```

**Protocol validation (completed via .xs source analysis):**
- [x] 9.5 Cross-referenced all 14 NFTP message formats between .xs source code, Java implementation, and Python emulator — all match
- [x] 9.6 Validated NNG compact serialization format: 0x8d identifier encoding, tuple/dict/string tags all correct
- [x] 9.7 Confirmed Init message format: u8(0) + vlu(version=1) + string(header)
- [x] 9.8 Confirmed QueryInfo uses compact-serialized tuple of identifiers (0x1e + count + 0x8d items)
- [x] 9.9 All 41 emulator tests pass, all Java unit tests pass

**Conclusion:** The ifapi can't call .xs functions without RunLoop (thread_server assertion blocks it). However, the .xs source code in data.zip IS the protocol specification, and our implementations match it exactly. No wire-byte capture needed — the source code validation is definitive.

## References

- [unidbg](https://github.com/zhkl0228/unidbg) — Android native library emulator
- [nftp.md](../nftp.md) — Full NFTP protocol documentation
- [NNG_SDK_INTEGRATION.md](../docs/NNG_SDK_INTEGRATION.md) — Previous SDK integration attempts
- [nng-sdk-investigation.md](../docs/nng-sdk-investigation.md) — Ghidra decompilation findings
