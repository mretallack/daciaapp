# NFTP Probe

> **License**: MIT — see [LICENSE](LICENSE)

> **⚠️ DISCLAIMER**: Use this software entirely at your own risk. Connecting to your head unit with unofficial tools could potentially brick, corrupt, or void the warranty of your media unit. The authors accept no responsibility for any damage to your vehicle, head unit, phone, or any other equipment. This is an experimental tool — if you are not comfortable with the risks, do not use it.

Android app that connects to a MediaNav 4 head unit over USB AOA, performs an NFTP Init handshake, reads `device.nng`, and provides a tabbed explorer interface for browsing the head unit's filesystem. Read-only — no files are written, deleted, or modified.

## Features

- **Probe tab** — Init handshake + device.nng retrieval, TCP emulator connection
- **Device tab** — Server name/version, device.nng size and hex preview
- **Explorer tab** — Browse head unit filesystem using hardcoded file mapping paths
- **Log tab** — Full protocol-level log with hex dumps
- **CheckSum** — Compute MD5/SHA1 of remote files
- **File detail dialog** — View file path, download, compute checksums

### Known Limitations

- **QueryInfo is blocked** — the NNG symbol IDs needed for `@device`, `@brand`, `@fileMapping`, `@ls`, `@freeSpace`, `@diskInfo` are unknown. See [nftp.md](nftp.md) for the full investigation.
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
