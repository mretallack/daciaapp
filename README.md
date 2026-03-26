# NFTP Probe

> **License**: MIT — see [LICENSE](LICENSE)

> **⚠️ DISCLAIMER**: Use this software entirely at your own risk. Connecting to your head unit with unofficial tools could potentially brick, corrupt, or void the warranty of your media unit. The authors accept no responsibility for any damage to your vehicle, head unit, phone, or any other equipment. This is an experimental tool — if you are not comfortable with the risks, do not use it.

Minimal Android app that connects to a MediaNav 4 head unit over USB AOA, performs an NFTP Init handshake, and reads `device.nng` to confirm the protocol works. No files are written, deleted, or modified on the head unit — this is purely read-only.

## How It Works

1. Phone connects to head unit via USB
2. Head unit initiates AOA handshake (manufacturer: `NNG`, model: `YellowBox`)
3. App sends NFTP Init → receives server name and version
4. App sends GetFile for `device.nng` → receives device info (SWID, VIN, iGo version)
5. Results displayed in a scrolling log view

## Prerequisites

- Java 11+
- Android SDK (API 36) — configured in `local.properties`
- Python 3.11+ (for the emulator)
- Android phone with USB debugging enabled
- `adb` on your PATH

## Project Structure

```
nftp-probe/
├── nftp-core/          Pure Java library — packet framing, connection, probe logic
│   └── src/
│       ├── main/java/com/dacia/nftp/
│       │   ├── VluCodec.java         Variable-length unsigned int codec
│       │   ├── NftpPacket.java       Packet framing, fragmentation, reassembly
│       │   ├── NftpConnection.java   Request/response with transaction IDs
│       │   └── NftpProbe.java        Init + GetFile probe sequence
│       └── test/java/com/dacia/nftp/
│           ├── VluCodecTest.java
│           ├── NftpPacketTest.java
│           ├── NftpConnectionTest.java
│           └── NftpProbeTest.java
├── nftp-app/           Android app — USB AOA + TCP fallback
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/dacia/nftpprobe/MainActivity.java
│       └── res/
│           ├── layout/activity_main.xml
│           └── xml/accessory_filter.xml
└── emulator/           Python head unit emulator for testing
    ├── emulator.py
    └── test_emulator.py
```

## Building the App

```bash
cd nftp-probe
./gradlew :nftp-app:assembleDebug
```

APK output: `nftp-app/build/outputs/apk/debug/nftp-app-debug.apk`

## Installing on Phone

```bash
adb install nftp-app/build/outputs/apk/debug/nftp-app-debug.apk
```

## Running Unit Tests

```bash
./gradlew :nftp-core:test
```

20 tests across 4 classes covering VLU encoding, packet framing, connection management, and the full probe sequence with a fake server.

## Running the Emulator

The Python emulator fakes a head unit NFTP server over TCP for testing without a real car.

```bash
python3 emulator/emulator.py --port 9876 --verbose
```

### Emulator Tests

```bash
python3 -m pytest emulator/test_emulator.py -v
```

## Testing Against the Emulator

### Via adb intent

```bash
adb shell am start -n com.dacia.nftpprobe/.MainActivity \
    --es emulator_host <PC_IP>
```

### Via the app UI

Open the app, type the PC's IP address into the text field, tap Connect.

### Expected output

```
Connecting to <PC_IP>:9876...
Sending Init...
Connected: FakeHeadUnit v1
Requesting device.nng...
Got device.nng: 65 bytes
Probe complete
```

## Testing Against the Real Head Unit

1. Install the app on the phone
2. Plug the phone into the head unit via USB
3. On the head unit: Navigation → Menu → Map Update → Options → Update with Phone
4. Grant USB permission on the phone when prompted
5. The head unit should show "Phone connected!"
6. The app runs the probe automatically and displays results
7. Tap "Exit update" on the head unit when done

## Safety

- Only Init and GetFile (read-only) commands are used
- No PushFile, DeleteFile, RenameFile, or any write operations
- If anything fails, the app logs the error and stops
- Tap "Exit update" on the head unit to close the session at any time

## Protocol Details

See [nftp.md](../nftp.md) for the full NFTP protocol documentation.
