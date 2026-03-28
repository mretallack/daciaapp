# NFTP Probe

> **License**: MIT — see [LICENSE](LICENSE)

> **⚠️ DISCLAIMER**: Use this software entirely at your own risk. Connecting to your head unit with unofficial tools could potentially brick, corrupt, or void the warranty of your media unit. The authors accept no responsibility for any damage to your vehicle, head unit, phone, or any other equipment. This is an experimental tool — if you are not comfortable with the risks, do not use it.

Android app that connects to a MediaNav 4 head unit over USB AOA, performs an NFTP Init handshake, reads `device.nng`, and provides a tabbed explorer interface for browsing the head unit's filesystem. Read-only — no files are written, deleted, or modified.

## Top-Level Goal

Get the **original Dacia Map Update app** to connect to our Python emulator instead of the real head unit. This would let us:
1. Capture the exact NFTP packets the real app sends (including correct symbol IDs)
2. Understand the full QueryInfo protocol by observing real traffic
3. Reverse-engineer the symbol ID assignments
4. Eventually replicate the full protocol in our Java implementation

### Current Progress

| Step | Status | Notes |
|------|--------|-------|
| Python emulator (TCP) | ✅ Done | Handles Init, GetFile, QueryInfo, CheckSum |
| Emulator listens on port 9876 | ✅ Done | Same port as iOS YellowBox listener |
| Firewall open on server | ✅ Done | Port 9876/tcp open |
| Phone can reach server | ✅ Verified | Ping and TCP from phone to 10.0.0.78 works |
| Our Java app connects to emulator | ✅ Working | Java NFTP probe connects, gets device.nng, QueryInfo with strings |
| NNG SDK `.so` libs load | ✅ Working | `liblib_nng_sdk.so` + base + memmgr |
| NNG SDK engine starts | ✅ Working | Engine reaches RUNNING state |
| NNG SDK asyncEval | ✅ Working | System.import works; can access socket, serialization, fs, os modules |
| NNG SDK boot script | ❌ Not working | Boot scripts never execute despite correct config |
| NNG compact serialisation | ✅ Solved | Symbols are 0x8d + null-terminated string, NOT integer IDs |
| Full YellowBox `.xs` scripts bundled | ✅ Done | Bundled as assets, project system loads with skin=yellowbox |
| Real NNG code connects to emulator | ✅ Working | sock.connect + DataWriter/DataReader work via asyncEval |
| QueryInfo format correct | ✅ Done | Serialiser updated to use 0x8d compact identifiers |
| QueryInfo tested on head unit | ❌ Not yet | Need to test with real head unit |

### Approaches to Get the Real App Talking to Our Emulator

The "real app" means running the actual NNG SDK code (`.so` libs + decompiled `.xs` scripts) inside our probe app, with the full YellowBox module chain loaded.

**Current approach: Bundle the full YellowBox `.xs` scripts**

The real app's data directory (`xs_extract/data/`) contains:
- `yellowbox/project.ini` — SDK project config (`skin=yellowbox`)
- `yellowbox/src/main.xs` → `connections.xs` → imports socket + NFTP modules
- `xs_modules/core/nftp.xs` — NFTP protocol implementation
- `yellowbox/fonts/` (7.8MB), `yellowbox/res/` (30MB) — UI assets (may not be needed)

The `.xs` scripts total ~2MB. The SDK loads `main.xs` which imports `connections.xs` which initialises the socket and NFTP modules. On iOS, it starts a TCP listener on port 9876. On Android, it uses USB AOA.

**Plan:**
1. Bundle the full `xs_extract/data/` directory (or just the `.xs` scripts) as app assets
2. Modify `connections.xs` to also start the TCP listener on Android (currently iOS-only)
3. Point the SDK at this data directory (no boot script — use the project system)
4. The SDK loads the full module chain, including socket and NFTP
5. Our emulator connects to the TCP listener (or the app connects outbound)
6. Capture the real QueryInfo packets with correct symbol IDs

**Key challenge:** The SDK needs the full module chain to load. Many modules import UI components, fonts, Android services, etc. The UI will fail but the NFTP/socket code should still initialise since `connections.xs` is imported with `import {} from` (side-effect import).

**What we've learned about the SDK so far:**
- `asyncEval` is sandboxed — no imports, no modules, no globals bridge (error -14)
- Boot scripts run but are isolated from asyncEval
- The SDK DOES start successfully and reaches RUNNING state
- The project system (`project.ini`) needs the correct directory structure
- Console output from `.xs` scripts needs `log_2="logcat:console:3"` in project.ini

### NNG SDK Integration Attempts

See [NNG_SDK_INTEGRATION.md](NNG_SDK_INTEGRATION.md) for the full investigation into using the NNG SDK's native library directly. Summary: asyncEval is too sandboxed to access the socket or serialization modules.

## Features

- **Probe tab** — Init handshake + device.nng retrieval, TCP emulator connection
- **Device tab** — Server name/version, device.nng size and hex preview
- **Explorer tab** — Browse head unit filesystem using hardcoded file mapping paths
- **Log tab** — Full protocol-level log with hex dumps
- **CheckSum** — Compute MD5/SHA1 of remote files
- **File detail dialog** — View file path, download, compute checksums

### Known Limitations

- **QueryInfo untested against real head unit** — the serialisation format has been corrected (0x8d compact identifiers confirmed from real NNG SDK), but needs testing against the actual head unit
- **No dynamic directory listing** — the explorer uses hardcoded paths from the default file mapping instead of `@ls` queries
- **No parsed device info** — device.nng is shown as raw hex; parsing the binary format is not yet implemented

## How It Works

1. Phone connects to head unit via USB
2. Head unit initiates AOA handshake (manufacturer: `NNG`, model: `YellowBox`)
3. App sends NFTP Init (identifying as `YellowBox/1.8.13+e14eabb8`) → receives server name and version
4. App sends GetFile for `license/device.nng` → receives device info binary
5. App sends CheckSum for `license/device.nng` → receives MD5/SHA1 hash
6. Results displayed across tabbed interface

## Prerequisites

- Java 11+
- Android SDK (API 36) — configured in `local.properties`
- Python 3.11+ (for the emulator)
- Android phone with USB debugging enabled
- `adb` on your PATH

## Project Structure

```
nftp-probe/
├── nftp-core/          Pure Java library — protocol, serialisation, explorer API
│   └── src/
│       ├── main/java/com/dacia/nftp/
│       │   ├── VluCodec.java           Variable-length unsigned int codec
│       │   ├── NftpPacket.java         Packet framing, fragmentation, reassembly
│       │   ├── NftpConnection.java     Request/response with transaction IDs
│       │   ├── NftpProbe.java          Init + GetFile + CheckSum probe
│       │   ├── NngSerializer.java      NNG compact binary encoder
│       │   ├── NngDeserializer.java    NNG compact binary decoder
│       │   ├── HeadUnitExplorer.java   High-level explorer API
│       │   └── HexDump.java           Hex dump utility
│       └── test/java/com/dacia/nftp/
│           ├── VluCodecTest.java
│           ├── NftpPacketTest.java
│           ├── NftpConnectionTest.java
│           ├── NftpProbeTest.java
│           ├── NngSerializerTest.java
│           ├── NngDeserializerTest.java
│           ├── NftpCheckSumTest.java
│           ├── HexDumpTest.java
│           └── HeadUnitExplorerTest.java
├── nftp-app/           Android app — tabbed UI with USB AOA + TCP
│   └── src/main/
│       ├── java/com/dacia/nftpprobe/
│       │   ├── MainActivity.java       Tab management, connection handling
│       │   └── ExplorerAdapter.java    RecyclerView adapter for file entries
│       └── res/layout/
│           ├── activity_main.xml       Tab bar + content frame
│           ├── fragment_probe.xml      Emulator IP + connect button
│           ├── fragment_device.xml     Device info display
│           ├── fragment_explorer.xml   File browser with RecyclerView
│           ├── fragment_log.xml        Protocol log
│           ├── dialog_file_detail.xml  File actions (checksum, download, save)
│           └── item_file_entry.xml     File/folder row
└── emulator/           Python head unit emulator for testing
    ├── emulator.py
    └── test_emulator.py
```

## Building

```bash
./gradlew :nftp-app:assembleDebug
```

## Installing

```bash
adb install -r nftp-app/build/outputs/apk/debug/nftp-app-debug.apk
```

## Running Tests

```bash
# Java unit tests (9 test classes)
./gradlew :nftp-core:test

# Python emulator tests (10 tests)
python3 -m pytest emulator/ -v
```

## Emulator

```bash
python3 emulator/emulator.py --port 9876 --verbose
```

Serves fake device.nng, license files, and supports CheckSum (MD5/SHA1). Connect from the app's Probe tab using the PC's IP address.

## Testing Against the Real Head Unit

1. Install the app on the phone
2. Plug the phone into the head unit via USB
3. On the head unit: Navigation → Menu → Map Update → Options → Update with Phone
4. Grant USB permission on the phone when prompted
5. The app runs the probe automatically

### Confirmed working (Jogger, firmware 6.0.12.2)

- Server: `YellowTool/1.18.1+15418192 v1`
- GetFile `license/device.nng`: 268 bytes ✓
- CheckSum MD5/SHA1: working ✓
- QueryInfo: blocked (symbol IDs unknown)

## Safety

- All operations are read-only (Init, GetFile, CheckSum)
- No PushFile, DeleteFile, RenameFile, or any write operations
- No PrepareForTransfer or TransferFinished commands

## Protocol Details

See [nftp.md](nftp.md) for the full NFTP protocol documentation including:
- Packet framing format
- All 14 command types
- NNG compact serialisation format
- QueryInfo symbol ID investigation
- Ghidra decompilation findings

## Acknowledgements

Built on the reverse-engineering work by [goncalomb](https://goncalomb.com/blog/2024/01/30/f57cf19b-how-i-also-hacked-my-car) and [mn4-tools](https://github.com/goncalomb/mn4-tools).
