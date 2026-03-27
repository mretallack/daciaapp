# NFTP Protocol — MediaNav 4

## Overview

NFTP is a proprietary binary file-transfer protocol used by NNG's "Phone-Based Map Update" (PBMU / YellowTool / YellowBox) feature on MediaNav 4 head units. It is not related to standard FTP.

Officially it exists to transfer navigation map updates from a phone to the head unit. In practice it allows arbitrary file read/write/delete under `/navi` on the head unit, which can be used to gain root access.

## Transport Layer

- **USB side**: Android Open Accessory (AOA) protocol over USB
- **Head unit side**: `aoa2sock` binary bridges USB AOA to a Unix socket pipe
- **On top of the pipe**: NFTP binary framing, then YellowTool commands

The head unit is the USB host. The phone (or RPi, or anything impersonating a phone) is the USB peripheral.

AOA is Google's protocol for accessories to talk to Android devices over USB. The "accessory" (head unit) initiates a handshake, after which the connection becomes a raw data pipe.

## Packet Framing (Low Level)

Each packet has a 4-byte header followed by data:

```
Bytes 0-1 (uint16 LE):
  bits 0-14: packet length (including header), max 0x7FFF (32767)
  bit 15:    continuation flag (1 = more packets follow, 0 = final)

Bytes 2-3 (uint16 LE):
  If 0xC000: control packet (no response expected)
  Otherwise:
    bit 15:    0 = request, 1 = response
    bit 14:    aborted flag
    bits 0-13: transaction ID (1–0x3FFF), links requests to responses
```

Messages larger than ~32KB are split across multiple packets sharing the same transaction ID, with the continuation flag set on all but the last.

## YellowTool Commands (High Level)

Each request starts with a 1-byte command type, followed by command-specific data.

See the "Full Message Types" section below for the complete list from the decompiled v1.8.13 app. The commands originally reverse-engineered by goncalomb are summarised here.

### PUSH_FILE (1)
```
[1 byte]  command type = 0x01
[string]  remote path (null-terminated ASCII)
[1 byte]  options bitmask (see PushFile Options below)
[bytes]   file content
```

### GET_FILE (3)
```
[1 byte]  command type = 0x03
[string]  remote path (null-terminated ASCII)
[vlu]     position (byte offset to start reading from, typically 0)
[vlu]     length (0 = read entire file)
```
Response data contains the file content.

**Note:** goncalomb's `ctrl-proto.py` (reverse-engineered from older firmware) sends position as a single raw byte `0x00` and omits the length field. The decompiled v1.8.13 Dacia app — the authoritative source — sends both fields as VLU-encoded values. The older format may have worked only because the server was lenient. Our nftp-probe follows the official app's format.

### DELETE_FILE (6)
```
[1 byte]  command type = 0x06
[string]  remote path (null-terminated ASCII)
[1 byte]  recursive = 0x00 (not used)
```

### Response Format

The first byte of response data indicates status:
- `0x00` = success (remaining bytes are payload, e.g. file content for GET_FILE)
- Anything else = error (remaining bytes are error details, see Response Codes below)

## Head Unit Side

- The YellowTool/YellowBox component is installed from `yellowtool.ipk` during firmware updates — it's an afterthought, not part of the core OS
- The `.xs` scripts (JavaScript-like, run by a native interpreter) implement the NFTP server side
- `aoa2sock` is the native binary that bridges USB AOA ↔ Unix socket for the scripts
- Files are read/written under `/navi` which is normally mounted read-only, remounted read-write during updates
- The "Update with Phone" UI option triggers YellowTool to start listening

## Phone / Client Side

- The official client is the Android app `com.nng.pbmu.dacia` (Dacia) or equivalent per brand
- The app uses AOA as transport, with NFTP implemented in `.xs` scripts bundled in the APK
- goncalomb reimplemented the client side in Python (`ctrl-proto.py`) to run on a Raspberry Pi in USB gadget mode

## USB Connection Options

### Option A: Raspberry Pi Zero 2 W (proven by goncalomb)

- RPi Zero 2 W in USB gadget mode, connected via OTG port
- Requires a patched Linux kernel module (`f_serial.c`) to change the USB subclass so `aoa2sock` recognises it as AOA
- The RPi is powered from the OTG port
- SSH into the RPi over Wi-Fi to run commands
- Proven to work on firmware 6.0.9.9 → 6.0.10.2
- Skips Init handshake — based on older reverse engineering, may not match the actual protocol
- Uses `socat` to bridge the USB gadget serial port to `ctrl-proto.py`

### Option B: Android Phone over USB (untested on this car)

- Connect an Android phone via USB to the head unit
- The head unit should initiate AOA handshake
- Need to run an NFTP client on the phone — either the official PBMU app, or a custom app/script
- IP-over-USB (RNDIS/NCM) may also be established, which could allow alternative communication paths
- No kernel patching needed since it's a real Android device

### Option C: Linux PC with USB gadget support (theoretical)

- Any Linux device with a USB OTG/peripheral-capable port could impersonate the phone
- Same kernel patch as the RPi approach
- Could use `ctrl-proto.py` directly

### USB Gadget Configuration (from mn4-tools)

The RPi USB gadget is configured with Google's AOA vendor/product IDs so `aoa2sock` on the head unit recognises it:

```
idVendor  = 0x18d1  (Google)
idProduct = 0x2d00  (AOA accessory)
function  = gser.usb0 (generic serial)
```

Communication goes through `/dev/ttyGS0` via `socat` to `ctrl-proto.py`.

## Status on This Car (Jogger, firmware 6.0.12.2.1166_r2)

- YellowTool **is running** and responds to NFTP Init on this firmware
- Server identifies as: `YellowTool/1.18.1+15418192`, NFTP version 1
- The boot-time crash logged below does NOT prevent YellowTool from starting when "Update with Phone" is selected:
  ```
  PBMU module starting up.
  Yellowtool's stdout hung up.
  Didn't start yellow tool.
  Yellowtool's stderr hung up.
  Yellow tool has exited.
  ```
- No Wi-Fi hardware on this head unit, so any root shell must work over USB
- The `autorun_bavn/autorun.sh` backdoor was removed in 6.0.10.2
- The `logfiles_bavn/` USB debug dump still works

### Init Requirements (confirmed 2025-03-27)

- The Init identifier string **must** be `YellowBox/<version>+<hash>` — the head unit silently ignores other identifiers (e.g. `NftpProbe`)
- The working identifier from the v1.8.13 app is: `YellowBox/1.8.13+e14eabb8`
- The head unit responds with: `YellowTool/1.18.1+15418192`

### File Path Mapping (confirmed 2025-03-27)

Files on the head unit are accessed via mapped paths, not bare filenames. Requesting `device.nng` directly returns `EACCESS`. The default file mapping from the v1.8.13 app:

- `device.nng` → `license/device.nng`
- `.lyc` (license files) → `license/`
- `.fbl`, `.hnr`, `.fda` etc (map files) → `content/map/`
- `.poi` → `content/poi/`
- `.spc` → `content/speedcam/`

The official app queries `@fileMapping` via QueryInfo after Init to get the head unit's actual mapping, then uses it for all file operations. The default mapping works as a fallback.

### USB AOA Read Behaviour

USB AOA delivers data in bulk transfers. The standard Java pattern of reading exact byte counts (`read(buf, off, len)` requesting exactly 4 bytes for a header) **does not work** — the read blocks forever. Data must be read in bulk chunks using `read(buf)` and parsed from a buffer, matching how the official app's `nftp.xs` `msgExtractor` works with `DataReader(64*1024)`.

## IP Over USB (2025-03-25)

Connected an Android phone via USB. The phone does not have Android Auto, but the USB connection may have established IP-over-USB (RNDIS or NCM network gadget). This could provide a TCP/IP path to the head unit without needing AOA.

To investigate:
- Check `ip addr` / `ifconfig` on the phone for a new USB network interface (e.g. `usb0`, `rndis0`)
- Check if the head unit has an IP address reachable from the phone (try `192.168.x.x` range)
- Port scan any discovered IP for SSH (22), HTTP (80), AirTunes (7000), or other services
- The head unit is known to have SSH (port 22) and AirTunes (port 7000) open

## Full Message Types (from v1.8.13 app nftp.xs)

The v1.8.13 Dacia Map Update app reveals significantly more commands than goncalomb's reverse engineering found:

| Type | Value | Description |
|------|-------|-------------|
| Init | 0 | Handshake — sends NFTP version + app identifier string |
| PushFile | 1 | Write a file to the head unit |
| Commit | 2 | Handled but not used |
| GetFile | 3 | Read a file from the head unit |
| QueryInfo | 4 | Query device info (supports `@device`, `@brand`, `@fileMapping`, `@ls` for directory listings) |
| CheckSum | 5 | Compute MD5 or SHA1 checksum of a remote file |
| DeleteFile | 6 | Delete a file on the head unit |
| RenameFile | 7 | Rename a file on the head unit |
| LinkFile | 8 | Create symlink (default) or hardlink |
| UpdateSelf | 9 | Not implemented |
| PrepareForTransfer | 10 | Tell YellowTool a file transfer is about to start |
| TransferFinished | 11 | Tell YellowTool it can restart iGo when needed |
| Mkdir | 12 | Create directory |
| Chmod | 13 | Change file permissions |
| Event | 14 | Not handled |

### Control Messages

| Type | Value | Description |
|------|-------|-------------|
| StopStream | 0 | Stop a streaming transfer |
| PauseStream | 1 | Pause a streaming transfer |
| ResumeStream | 2 | Resume a streaming transfer |

### Response Codes

| Code | Value | Meaning |
|------|-------|---------|
| Success | 0 | OK |
| Failed | 1 | General failure |
| BadFilePos | 2 | Invalid file position |
| UnknownParam | 0x7E | e.g. unknown checksum method |
| Unknown | 0x7F | Unknown error |

### PushFile Options (bitmask)

| Flag | Value | Description |
|------|-------|-------------|
| None | 0 | Default |
| TruncateFile | 1 | Truncate file before writing |
| UsePartFile | 2 | Write to file.part, rename on success |
| OverwriteOriginal | 4 | Rename original to .part (with UsePartFile) |
| TrimToWritten | 8 | Trim file to written length when done |
| OnlyIfExists | 0x10 | Don't create if file doesn't exist |

### Init Handshake

The connection starts with an Init message:
```
Client sends:  [0x00] [vlu: NFTP version (1)] [string: app identifier\0]
Server replies: [0x00 success] [vlu: server NFTP version] [string: server app name\0]
```

After Init, the official app queries `@fileMapping` to learn where different file types live on the head unit, then reads `device.nng` to identify the device.

**Note:** goncalomb's `ctrl-proto.py` (reverse-engineered from older firmware) skips Init entirely. The decompiled v1.8.13 Dacia app — the authoritative source — always sends Init first. Our nftp-probe follows the official app's behaviour.

### QueryInfo Capabilities

QueryInfo (type 4) accepts serialised keys and can return:
- `@device` — device info (appcid, igoVersion, swid, sku, firstUse, imei, vin)
- `@brand` — brand info (agentBrand, modelName, brandName, brandFiles)
- `@fileMapping` — maps file extensions to paths on the head unit
- `@ls` with path — directory listing with fields like `@name`, `@size`

### Checksum Methods

| ID | Method |
|----|--------|
| 0 | MD5 |
| 1 | SHA1 |

## AOA Identity (from decompiled v1.8.13 APK)

The head unit identifies the phone/client via AOA with these strings:

```
AOA_MANUFACTURER = "NNG"
AOA_MODEL = "YellowBox"
```

The USB accessory filter in the APK (`res/xml/accessory_filter_usb.xml`) matches these values. The head unit acts as the USB host and initiates the AOA handshake looking for a device advertising manufacturer "NNG" and model "YellowBox".

The Java/Kotlin AOA layer (`com.nng.yellowbox.AOAMod`):
1. Registers a BroadcastReceiver for `USB_ACCESSORY_ATTACHED` and `USB_ACCESSORY_DETACHED`
2. On attach, calls `UsbManager.openAccessory()` to get a `ParcelFileDescriptor`
3. Passes the fd to the `.xs` runtime via `aoaCb.invoke("connected", fd)`
4. The `.xs` side creates an NFTP connection from the fd via `nftp.createFromFd(fd, nftpHandler)`
5. On detach, calls `aoaCb.invoke("disconnected", fd)` and closes the fd

## Official App Connection Sequence

Based on the decompiled v1.8.13 Dacia Map Update app, the full connection sequence is:

1. USB AOA attach → open fd
2. **Init** — send NFTP version (1) + app identifier string → receive server version + name
3. **QueryInfo `@fileMapping`** — learn where file types live on the head unit (maps extensions to paths)
4. **GetFile `device.nng`** — read device info (SWID, VIN, iGo version, etc.)
5. Proceed with map update logic (PushFile, CheckSum, PrepareForTransfer, etc.)

Our nftp-probe implements steps 1–4 (read-only). goncalomb's ctrl-proto.py (based on older reverse engineering) skips steps 2–4 and goes straight to file operations.

### Socket Listener (iOS / alternative path)

On iOS (and potentially other platforms), the app can also listen for NFTP connections on a TCP socket:
```
host: 127.0.0.1
port: 9876
```
This is used for the iOS USB connection path (via `usbmuxd` or similar). The head unit side would need to connect to this port.

## Decompiled App Structure (v1.8.13)

```
com.nng.pbmu.dacia.apk (52MB base APK)
├── classes.dex + classes2.dex — Java/Kotlin code
├── assets/resources.zip
│   ├── resources/resources.zip — shaders, certs, config
│   ├── resources/data.zip — .xs scripts (the app logic)
│   │   ├── xs_modules/core/nftp.xs — NFTP protocol (18KB)
│   │   ├── yellowbox/src/toolbox/connections.xs — connection management
│   │   ├── yellowbox/src/toolbox/android/usbConnectionService.xs
│   │   ├── yellowbox/src/toolbox/device.xs — device identification
│   │   ├── yellowbox/src/toolbox/updater.xs — update logic
│   │   └── ... (138 .xs files total)
│   └── icudt64l.dat — ICU data
└── res/xml/accessory_filter_usb.xml — USB accessory filter (NNG/YellowBox)

config.arm64_v8a.apk (32MB native libs)
├── liblib_nng_sdk.so (31MB) — NNG SDK, runs .xs scripts
├── liblib_base.so
├── liblib_memmgr.so
└── libc++_shared.so
```

Build info: `1.10.0-yellowbox1.8.13.1+222480.21`, git hash `e14eabb8`, NSDK hash `897d4460137`.

## References

- Blog post: https://goncalomb.com/blog/2024/01/30/f57cf19b-how-i-also-hacked-my-car
- mn4-tools repo: https://github.com/goncalomb/mn4-tools
- NFTP Python implementation: https://github.com/goncalomb/mn4-tools/blob/master/mn4-pwned/scripts/ctrl-proto.py
- USB gadget setup: https://github.com/goncalomb/mn4-tools/blob/master/mn4-pwned/scripts/ctrl-gadget.sh
- Android Open Accessory: https://source.android.com/docs/core/interaction/accessories/protocol
- PBMU Android app: https://play.google.com/store/apps/details?id=com.nng.pbmu.dacia
- Linux USB gadget configfs: https://docs.kernel.org/usb/gadget_configfs.html
