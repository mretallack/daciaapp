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

### File Access Restrictions (confirmed 2025-03-27)

GetFile only works for paths that match the file mapping. Attempting to read arbitrary paths returns `EACCESS` (status=1). Tested and blocked:

- `yellowtool/src/main-ulc.xs` — EACCESS
- `main-ulc.xs` — EACCESS
- `src/main-ulc.xs` — EACCESS
- `nngnavi/yellowtool/src/main-ulc.xs` — EACCESS
- `yellowtool/main-ulc.xs` — EACCESS

Only mapped paths work (e.g. `license/device.nng`). The head unit's YellowTool restricts file access to paths within the file mapping, preventing arbitrary filesystem reads.

### QueryInfo Serialisation (investigation 2025-03-27)

QueryInfo (type 4) uses NNG's proprietary compact binary serialisation format. The request body is:

```
[0x04]                          — command type
[compact-serialised tuple]      — keys to query
```

The response is:

```
[0x00]                          — status (success)
[compact-serialised value]      — results (tuple, one per key)
```

#### NNG Compact Serialisation Format

Reverse-engineered from the decompiled `TypeTag.java`, `Serializer.java`, and `Deserializer.java` in the NNG SDK Java bindings (`com.nng.uie.api`):

```
Each value: [tag byte][payload]

Tag byte: bits 0-5 = type tag, bit 7 = modifier flag

Type tags:
  0  = Undef (no payload)
  1  = Int32 (4 bytes LE)
  2  = UInt64 (8 bytes LE)
  3  = String (VLU length + UTF-8 bytes)
  4  = I18NString (same as String)
  5  = Double (8 bytes LE)
  6  = Tuple (u32 count + N values)
  7  = Dict (u32 count + N key-value pairs)
  12 = IdentifierInt (4 bytes LE)
  13 = IdentifierString (VLU length + UTF-8 bytes)
  15 = ObjectHandle
  20 = ObjectHandle (with modifier)
  21 = ByteStream (VLU length + bytes)
  22 = Array (u32 count + N values)
  24 = IdentifierSymbol (4 bytes LE symbol ID)
  26 = Int32VLI (VLI-encoded signed int — zigzag + VLU)
  27 = Int64VLI (VLI-encoded signed long)
  28 = IdIntVLI (VLI-encoded identifier int)
  29 = IdSymbolVLI (VLI-encoded symbol ID)
  30 = TupleVLILen (VLU count + N values)
  31 = ArrayVLILen (VLU count + N values)
  32 = DictVLILen (VLU count + N key-value pairs)
  33 = FailureVLILen

VLI = variable-length signed int (zigzag encoding: (value << 1) ^ (value >> 63), then VLU)
VLU = variable-length unsigned int (7 bits per byte, MSB = continuation)
```

#### QueryInfo Key Encoding — The Symbol ID Problem

The official app's `.xs` scripts send QueryInfo keys as NNG symbols (e.g. `@device`, `@brand`, `@fileMapping`). These are serialised as `IdSymbolVLI` (tag 29) with an integer symbol ID.

**Why IdentifierString (tag 13) doesn't work — confirmed via decompiled Java SDK:**

The `Deserializer.java` handles each tag type differently:
- `IdentifierString` (tag 13) → creates `NNGIdentifier(id=String("device"))`
- `IdSymbolVLI` (tag 29) → creates `NNGIdentifier(id=NngSymbol(742))` (or whatever the integer ID is)

The `NNGIdentifier.equals()` method compares using `Intrinsics.areEqual(this.id, other.id)`. Since `String("device") != NngSymbol(742)` (different Java types), they **never match**. The server deserialises our string identifier correctly, but when its QueryInfo handler compares the received key against its symbol-based keys, the comparison fails due to type mismatch.

**There is no string-based fallback.** The only way to make QueryInfo work is to send the correct integer symbol IDs via `IdSymbolVLI` (tag 29).

**How the official app serialises symbols — confirmed via decompiled Java SDK:**

In `Serializer.writeValue()`, when the value is an `NngSymbol`:
```java
writeTaggedInt(symbol.getId(), TypeTag.IdentifierSymbol, TypeTag.IdSymbolVLI, false);
```
In compact mode (`@compact`), this writes `IdSymbolVLI` (tag 29) + VLI-encoded integer ID. The symbol name is **never** included in the wire format.

**How `writeValue` works in nftp.xs:**
```javascript
export writeValue(writer, val) {
    const stream = Stream(@compact);  // creates Serializer with compactInts=true
    stream.add(val);                  // serialises val using compact encoding
    writer.writeBytes(stream.transfer());
}
```
When `queryInfo(messenger, @device, @brand)` is called, the `keys` tuple `(@device, @brand)` is serialised. Each `@device` and `@brand` is an `NngSymbol` in the `.xs` runtime, so they're written as `IdSymbolVLI(id)`.

**Attempts to send QueryInfo from our app (all failed to return data):**

1. **IdentifierString (tag 13)** — sent keys as strings like `"device"`, `"brand"`, `"fileMapping"`:
   - Server accepts the request (status=0) but returns empty tuple `[1f 00]`
   - Root cause: type mismatch in `NNGIdentifier.equals()` — `String != NngSymbol`

2. **Plain String (tag 3)** — sent `"@device"` as a regular string:
   - Same result: status=0, empty tuple
   - A plain string is not an identifier at all — completely wrong type

3. **IdSymbolVLI (tag 29) with sequential IDs 0–500** — brute-force scan:
   - Every ID returned 12 bytes: `00 1f 01 8d 75 6e 6b 6e 6f 77 6e 00`
   - Decoded: success + array of 1 item + IdentifierString `"unknown"`
   - The server recognises the symbol ID format but these IDs don't map to any known symbols in the head unit's runtime

4. **IdSymbolVLI with IDs 700–1500** — wider scan (pending results):
   - Based on Ghidra analysis showing 736 SDK-level symbols registered before app symbols

#### NNG Symbol System (from Ghidra analysis of liblib_nng_sdk.so)

The NNG SDK uses a symbol interning system. Key findings from decompiling the 31MB native library:

**Symbol intern function** (`FUN_00af8b08` at offset `0x00af8b08`):
- Takes a null-terminated string, returns a 32-bit symbol ID
- Uses a hash table for lookup (function `FUN_00bc73a0`)
- Hash function is **FNV-1a 64-bit** (offset basis `0xcbf29ce484222325`, prime `0x100000001b3`)
- If the symbol is new, assigns the next sequential ID from a counter at `(symbolTable + 0xf8)`
- 977 call sites in the binary — every `@symbol` in `.xs` source goes through this function

**Well-known symbols** (hardcoded in Java `WellKnownSymbol.java`, IDs 0–13):

| ID | Name |
|----|------|
| 0 | call |
| 1 | length |
| 2 | WHICH |
| 3 | serialize |
| 4 | getItem |
| 5 | splice |
| 6 | list |
| 7 | remoteConfig |
| 8 | iterator |
| 9 | constructor |
| 10 | proto |
| 11 | asyncIterator |
| 12 | dispose |
| 13 | asyncDispose |

**SDK-level symbols** (736 extracted via Ghidra decompilation of all `FUN_00af8b08` call sites):
- These are registered when the native SDK initialises, before any `.xs` scripts load
- Include: `name` (430), `size` (not found in filtered list), `isFile` (365), `mtimeMs` (427), etc.
- The index numbers above are sorted alphabetically, NOT the actual symbol IDs

**App-level symbols** (NOT in the native binary):
- `device`, `brand`, `fileMapping`, `freeSpace`, `diskInfo`, `ls`, `swid`, `appcid`, `igoVersion`, `imei`, `vin`, `firstUse`, `agentBrand`, `modelName`, `brandName`, `brandFiles`
- These are defined in the `.xs` scripts and assigned IDs at runtime when scripts are loaded
- IDs depend on the load order of `.xs` modules
- Both the phone app and head unit must assign the same IDs because they load the same NNG SDK + same `.xs` scripts

**The core problem**: Symbol IDs are assigned sequentially at runtime. The phone app's NNG runtime and the head unit's NNG runtime both load the same SDK and `.xs` scripts, so they get the same IDs. But our custom Java app is NOT an NNG runtime — we don't know the IDs. We need to either:
1. Discover the IDs by brute-force scanning (in progress, range 700–1500)
2. Intercept the official app's wire traffic to capture the actual IDs
3. Replicate the NNG runtime's symbol assignment order by tracing the `.xs` module load chain

#### Architecture: Native vs Script Layers (from Ghidra decompilation)

The NFTP implementation is split across two layers:

**Native layer** (`system://yellow.nftp` module, in `liblib_nng_sdk.so`):
- Source: `engine/mod_scripting/src/system/nftp/nftp_fd.cpp`
- Provides: socket/fd transport, connection lifecycle, authentication
- Exposes to `.xs` scripts: `sendRaw`, `sendMessage`, `setHandler`, `sendMethodCall`
- Also registers symbols: `tryAnonymous`, `identity`, `cookieSha1`
- Does NOT implement the NFTP protocol commands (Init, GetFile, QueryInfo, etc.)
- Session vtable at `0x01d79238`, post-auth vtable at `0x01d793b8`

**Script layer** (`core/nftp.xs`, shared between phone and head unit):
- Implements the actual NFTP protocol: message framing, command types, serialisation
- Both the phone app and head unit import from `core/nftp.xs`:
  ```javascript
  // Phone app (connections.xs):
  import * as nftp from "system://yellow.nftp"           // native transport
  import { queryInfo, queryFiles, ... } from "core/nftp.xs"  // protocol logic
  ```
- The `writeValue`/`readValue` functions use `Stream(@compact)` / `Reader` for serialisation
- QueryInfo keys (`@device`, `@brand`, `@fileMapping`) are `.xs` symbols, NOT native symbols

**Why symbol IDs match between phone and head unit:**
1. Both run the same `liblib_nng_sdk.so` → same 736 SDK symbols with same IDs
2. Both load `core/nftp.xs` → same 18 protocol symbols (`@md5`, `@sha1`, `@compact`, `@name`, `@size`, `@ls`, etc.)
3. Both load shared modules in the same order → app-level symbols get the same IDs
4. The official app works, confirming IDs are deterministic and shared

**Symbols in `core/nftp.xs`** (18 unique, in order of first appearance):
`@md5`, `@sha1`, `@stopStream`, `@pauseStream`, `@resumeStream`, `@control`, `@response`, `@request`, `@returns`, `@getAndRemove`, `@get`, `@compact`, `@error`, `@children`, `@name`, `@size`, `@ls`, `@path`

**Symbols NOT in `core/nftp.xs`** (defined in app-level scripts):
`@device`, `@brand`, `@fileMapping`, `@freeSpace`, `@diskInfo` — these are used in `connections.xs`, `contentManagament.xs`, and the head unit's handler scripts. Their IDs depend on the full module load order.

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
- `@freeSpace` — available disk space
- `@diskInfo` — disk size and available space
- `@ls` with path — directory listing with fields like `@name`, `@size`, `@isFile`, `@mtimeMs`

**Status**: QueryInfo is not yet working from our app. The keys must be sent as NNG symbol IDs (IdSymbolVLI, tag 29), but the correct IDs are unknown. See "QueryInfo Serialisation" section above for full details of the investigation.

### Checksum Methods

| ID | Method |
|----|--------|
| 0 | MD5 |
| 1 | SHA1 |

### CheckSum Wire Format

```
Request:
[0x05]              — command type
[0x00 or 0x01]      — method (0=MD5, 1=SHA1)
[string\0]          — null-terminated file path
[vlu: from]         — byte offset (typically 0)
[vlu: len]          — length (0 = whole file, optional)

Response (success):
[0x00]              — status
[16 or 20 bytes]    — checksum (16 for MD5, 20 for SHA1)

Response (error):
[status byte]       — non-zero error code
```

**Status**: CheckSum is implemented in our app but not yet tested against the real head unit.

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
