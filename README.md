# NFTP Probe

> **License**: MIT — see [LICENSE](LICENSE)

> **⚠️ DISCLAIMER**: Use this software entirely at your own risk. Connecting to your head unit with unofficial tools could potentially brick, corrupt, or void the warranty of your media unit. The authors accept no responsibility for any damage to your vehicle, head unit, phone, or any other equipment. This is an experimental tool — if you are not comfortable with the risks, do not use it.

Android app that connects to a MediaNav 4 head unit over USB AOA, performs an NFTP Init handshake, queries device info, disk space, and file mappings via QueryInfo, browses the filesystem with dynamic directory listings, reads files, and computes checksums. Read-only — no files are written, deleted, or modified.

## Features

- **Probe tab** — Init handshake + device.nng retrieval, TCP emulator connection
- **Device tab** — Parsed device info (SWID, VIN, iGo version, brand, model), disk space (total/available), server name/version
- **Explorer tab** — Dynamic filesystem browsing via QueryInfo `@ls`, with fallback to hardcoded file mapping paths
- **Log tab** — Full protocol-level log with hex dumps
- **QueryInfo** — Query device info (`@device`, `@brand`), disk space (`@diskInfo`), file mapping (`@fileMapping`), and directory listings (`@ls`) using validated NNG compact serialisation (0x8d identifiers)
- **CheckSum** — Compute MD5/SHA1 of remote files
- **File detail dialog** — View file path, download, compute checksums, save to phone

## How It Works

1. Phone connects to head unit via USB
2. Head unit initiates AOA handshake (manufacturer: `NNG`, model: `YellowBox`)
3. App sends NFTP Init (identifying as `YellowBox/1.8.13+e14eabb8`) → receives server name and version
4. App sends QueryInfo `@fileMapping` → learns where file types live on the head unit
5. App sends QueryInfo `@device`, `@brand` → gets SWID, VIN, iGo version, brand info
6. App sends QueryInfo `@diskInfo` → gets total and available disk space
7. App sends GetFile for `license/device.nng` → receives device info binary
8. Explorer tab uses QueryInfo `@ls` for dynamic directory browsing
9. File detail dialog uses GetFile and CheckSum for individual files

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
│       │   ├── NftpProbe.java          Init + GetFile + QueryInfo + CheckSum
│       │   ├── NngSerializer.java      NNG compact binary encoder (0x8d identifiers)
│       │   ├── NngDeserializer.java    NNG compact binary decoder
│       │   ├── HeadUnitExplorer.java   High-level explorer API (connect, query, browse)
│       │   └── HexDump.java           Hex dump utility
│       └── test/java/com/dacia/nftp/  (9 test classes)
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
├── emulator/           Python head unit emulator — all 14 NFTP commands
│   ├── emulator.py     Mutable in-memory filesystem, full protocol support
│   └── test_emulator.py (35 tests)
├── ghidra-scripts/     Ghidra scripts for reverse engineering liblib_nng_sdk.so
├── tools/              Helper scripts (symbol parser)
├── docs/               Investigation notes and symbol dumps
└── nftp.md             Full NFTP protocol documentation
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

# Python emulator tests (35 tests)
python3 -m pytest emulator/ -v
```

## Emulator

The Python emulator implements all 14 NFTP commands with a mutable in-memory filesystem:

```bash
python3 emulator/emulator.py --port 9876 --verbose
```

Supports: Init, PushFile, Commit, GetFile, QueryInfo (`@device`, `@brand`, `@fileMapping`, `@diskInfo`, `@freeSpace`, `@ls`), CheckSum (MD5/SHA1), DeleteFile, RenameFile, LinkFile, PrepareForTransfer, TransferFinished, Mkdir, Chmod, and control messages.

Connect from the app's Probe tab using the server's IP address.

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
- QueryInfo: serialisation format validated (0x8d compact identifiers), awaiting on-device test

## Safety

- All operations are read-only (Init, GetFile, QueryInfo, CheckSum)
- No PushFile, DeleteFile, RenameFile, or any write operations
- No PrepareForTransfer or TransferFinished commands

## Key Technical Details

### NNG Compact Serialisation

QueryInfo uses NNG's proprietary binary serialisation. The breakthrough discovery was that the compact format (`Stream(@compact)`) encodes identifiers as `0x8d` + null-terminated UTF-8 string — not integer symbol IDs. This was confirmed by loading the real NNG SDK on Android and capturing the bytes it produces. See the "BREAKTHROUGH: NNG Compact Serialisation" section in [nftp.md](nftp.md) for full details.

### Connection Sequence

Matches the official Dacia Map Update app (v1.8.13):

```
Init → QueryInfo(@fileMapping) → QueryInfo(@device, @brand) → QueryInfo(@diskInfo) → GetFile device.nng
```

The connection persists across tab switches. Explorer navigation sends additional `@ls` queries as needed.

## Protocol Details

See [nftp.md](nftp.md) for the full NFTP protocol documentation including:
- Packet framing format
- All 14 command types with wire formats
- NNG compact serialisation format
- QueryInfo symbol investigation and resolution
- Ghidra decompilation findings

## Acknowledgements

Built on the reverse-engineering work by [goncalomb](https://goncalomb.com/blog/2024/01/30/f57cf19b-how-i-also-hacked-my-car) and [mn4-tools](https://github.com/goncalomb/mn4-tools).
