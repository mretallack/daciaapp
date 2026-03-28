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

**Decompiled symbol_intern (`FUN_00af8b08`):**
```c
uint32_t symbol_intern(char *name) {
    SymbolTable *table = get_global_symbol_table();  // DAT_01eb0358, lazy-init
    if (name == NULL || *name == '\0') return 0;
    
    uint32_t next_id = table->counter;  // at table + 0xf8
    HashResult result = hash_lookup(table, name);
    
    if (result.is_new) {
        table->counter++;              // increment for next symbol
        result.entry->name = name;     // store the string
        register_symbol(table, next_id, name);  // FUN_00af7d6c
    }
    return result.entry->id;           // existing or newly assigned
}
```

**Registration pattern — lazy via `__cxa_guard_acquire`:**
All 977 call sites use the same pattern:
```c
if ((guard_var & 1) == 0) {
    if (__cxa_guard_acquire(&guard_var) != 0) {
        global_slot = FUN_00af8b08("symbolName", strlen);
        __cxa_guard_release(&guard_var);
    }
}
// use global_slot as the symbol ID
```
This means symbols are registered **on first use**, not at init time. The ID assigned depends on which code path executes first. The guard variable ensures each symbol is only registered once (thread-safe singleton pattern).

**399 symbol slots extracted** (via `DAT_xxx = FUN_00af8b08(...)` pattern):
Each symbol's ID is stored in a global variable (DAT_xxx). The remaining ~337 of the 736 symbols use patterns the regex didn't match (e.g. indirect calls, different decompiler output).

**Well-known symbols** (hardcoded in Java `WellKnownSymbol.java`, IDs 0–13):
These are NOT registered via `FUN_00af8b08`. They have fixed IDs in both the Java SDK and native runtime:

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

The counter at `symbolTable + 0xf8` likely starts at 14 (after the well-known symbols).

**SDK-level symbols** (736 unique extracted from all `FUN_00af8b08` call sites):
- Registered lazily when their containing function is first called
- Include symbols for: UI widgets, D-Bus, filesystem, networking, crypto, serialisation, CSS, XML, math, locale, etc.
- The registration ORDER (and therefore the IDs) depends on which native modules initialise first
- 303 distinct functions register symbols; the top registrars are module init functions

**Why we can't determine the IDs statically:**
1. The lazy `__cxa_guard_acquire` pattern means IDs are assigned at runtime on first use
2. The call order depends on which `.xs` scripts load first and which native modules they trigger
3. The phone app and head unit run different `.xs` scripts (YellowBox vs YellowTool)
4. Both share the same `liblib_nng_sdk.so`, so the native symbols get the same IDs IF the same code paths execute in the same order
5. The `.xs` script parser also calls `FUN_00af8b08` for every `@symbol` it encounters — these interleave with the native registrations

**App-level symbols** (NOT in the native binary):
- `device`, `brand`, `fileMapping`, `freeSpace`, `diskInfo`, `ls`, `swid`, `appcid`, `igoVersion`, `imei`, `vin`, `firstUse`, `agentBrand`, `modelName`, `brandName`, `brandFiles`
- These are defined in the `.xs` scripts and assigned IDs at runtime when scripts are loaded
- IDs depend on the full module load order (native init + `.xs` script parsing)
- Both the phone app and head unit must assign the same IDs because they load the same NNG SDK + same `.xs` scripts

#### Two Separate Symbol ID Spaces (from Ghidra decompilation)

The symbol table has TWO independent counters, suggesting two separate ID allocation mechanisms:

**Counter 1: `.xs` parser symbols** (`symbolTable + 0xf8`):
- Used by `FUN_00af8b08` (single symbol intern, called from `.xs` parser and native lazy init)
- Sequential, order-dependent — fragile across versions
- Used for `@symbol` tokens encountered during `.xs` script parsing

**Counter 2: Batch-allocated module symbols** (`symbolTable + 0x134`):
- Used by `FUN_00af874c` (batch allocator, called via `ifapi_token_alloc_symbol_range`)
- Allocates a contiguous range of IDs for an array of names
- Called from the public C API `ifapi_token_alloc_symbol_range(count, names_array)`
- Returns `(count << 32) | first_id` — the first ID and count of the allocated range
- Deterministic: the caller provides a fixed array of names, always gets the same range

**Decompiled `ifapi_token_alloc_symbol_range`:**
```c
uint64_t ifapi_token_alloc_symbol_range(uint32_t count, char** names_array) {
    SymbolTable* table = get_global_symbol_table();
    uint32_t first_id = table->batch_counter;  // at table + 0x134
    table->batch_counter += count;
    for (int i = 0; i < count; i++) {
        // Store names[i] into table's name array at table + 0x138
        table->names[table->name_count++] = names_array[i] ?? "<empty>";
    }
    return ((uint64_t)count << 32) | first_id;
}
```

**Decompiled `FUN_00af8340` (id_to_token / reverse lookup):**
```c
char* id_to_token(SymbolTable* table, uint32_t id) {
    if ((int)(id + 0xC0000000) >= 0) return "<number>";  // top 2 bits = 01
    if (id >> 30 > 2) return "<symbol>";                  // top 2 bits = 11
    if (id == 0) return "";
    // Binary search in range table at table + 0x60
    // Each range entry is 0x20 bytes: {start_id, names_ptr, count, ...}
    // Returns names_ptr[id - start_id]
}
```

**Symbol ID type tags** (top 2 bits of 32-bit ID):
- `00` = regular interned symbol (from `.xs` parser or batch alloc)
- `01` = number literal
- `10` = (unknown)
- `11` = special symbol

**Key insight**: The batch allocator (`ifapi_token_alloc_symbol_range`) is the mechanism that ensures deterministic symbol IDs across different runtimes. External modules (like the Java SDK bindings) register their symbols in bulk with a fixed name array, getting a predictable contiguous range. The `.xs` parser's lazy intern is for internal use where order doesn't matter (both sides parse the same scripts).

**Remaining question**: Which mechanism does the `.xs` runtime use for `@device`, `@brand`, etc.? If these are registered via batch alloc (from a module's symbol table), the IDs would be deterministic. If they're interned lazily during script parsing, the IDs depend on parse order — but since both sides parse the same `core/nftp.xs` and shared modules, the order would still match.

#### CRITICAL FINDING: .xs Parser Counter Starts at 100,000

From decompiling `FUN_00af7860` (symbol_table_init2):
```c
*(uint32_t*)(symbolTable + 0xf8) = 100000;  // lazy intern counter starts at 100000
```

This means:
- **Well-known symbols**: IDs 0–13 (hardcoded)
- **Batch-allocated symbols**: IDs from counter at `+0x134` (starts at 0, for native module registration)
- **`.xs` parser symbols**: IDs starting at **100,000** (counter at `+0xf8`)

**Our scan of 0–5000 was in the completely wrong ID space!** We were scanning batch-allocated IDs, but `.xs` symbols like `@device`, `@brand`, `@fileMapping`, `@ls` are all at IDs >= 100,000.

The `module_register` function (`FUN_010efa00`) also reveals:
- When registering a module, it calls BOTH `FUN_00af874c` (batch alloc) AND `FUN_00af81dc` (lazy intern) for each name
- The batch alloc assigns IDs from the `+0x134` counter (0, 1, 2, ...)
- The lazy intern assigns IDs from the `+0xf8` counter (100000, 100001, ...)
- The init function iterates a linked list at `DAT_01eb1728` of pre-registered symbol tables

**Next step**: Scan symbol IDs 100000–101000 against the real head unit. The `.xs` symbols should be in this range.

#### Phone-Side Symbol IDs (from parsing YellowBox .xs scripts)

Parsed 108 `.xs` files starting from `yellowbox/src/main.xs` in import order, extracting `@symbol` tokens in order of first encounter. IDs assigned starting from 100000:

**Key NFTP symbols (phone-side YellowBox):**

| Symbol | ID | Source file |
|--------|----|-------------|
| `@md5` | 100175 | core/nftp.xs |
| `@sha1` | 100176 | core/nftp.xs |
| `@compact` | 100185 | core/nftp.xs |
| `@error` | 100186 | core/nftp.xs |
| `@children` | 100187 | core/nftp.xs |
| `@size` | 100188 | core/nftp.xs |
| `@ls` | 100189 | core/nftp.xs |
| `@path` | 100190 | core/nftp.xs |
| `@freeSpace` | 100199 | connections.xs |
| `@diskInfo` | 100200 | connections.xs |
| `@fileMapping` | 100318 | connections.xs |
| `@device` | 100323 | connections.xs |
| `@brand` | 100324 | connections.xs |

Total: 371 unique `.xs` symbols, IDs 100000–100370.

**CRITICAL**: These are the PHONE-SIDE (YellowBox) IDs. The head unit runs YellowTool, which has its own `.xs` scripts parsed in a different order. The head unit's IDs for `@device`, `@brand`, etc. will be DIFFERENT because:
1. YellowTool loads different modules than YellowBox
2. The import order determines which `@symbol` gets which ID
3. Only `core/nftp.xs` is shared — but symbols from earlier imports get lower IDs

The scan of 100000–101000 against the head unit returned all "unknown" — confirming the head unit assigns different IDs.

**To find the head unit's IDs, we need to either:**
1. Extract the YellowTool `.xs` scripts from the head unit firmware
2. USB-sniff the official app's traffic to see the actual IDs on the wire
3. Try sending symbol IDs by NAME instead of by integer (if the protocol supports it)

#### BREAKTHROUGH: Real Symbol IDs from NNG Runtime (on phone)

Loaded `liblib_nng_sdk.so` on the phone, called `InitializeNative`, then called the internal
`symbol_intern` function (`FUN_00af8b08` at real offset `0x9f8b08`, Ghidra shows `0xaf8b08` due to
`0x100000` image base). Results:

**SDK built-in symbols** (pre-registered during `InitializeNative`, IDs 1–~1870):

| Symbol | ID |
|--------|----|
| `@call` | 1 |
| `@WHICH` | 2 |
| `@length` | 3 |
| `@serialize` | 4 |
| `@size` | 6 |
| `@splice` | 70 |
| `@get` | 94 |
| `@list` | 87 |
| `@name` | 199 |
| `@constructor` | 220 |
| `@iterator` | 224 |
| `@path` | 370 |
| `@error` | 393 |
| `@control` | 436 |
| `@remoteConfig` | 452 |
| `@asyncIterator` | 453 |
| `@dispose` | 454 |
| `@asyncDispose` | 455 |
| `@children` | 787 |
| `@getItem` | 1230 |
| `@compact` | 1341 |
| `@request` | 1866 |
| `@response` | 1867 |
| `@md5` | 1868 |
| `@sha1` | 1869 |

**NOTE**: The Java `WellKnownSymbol` IDs (0–13) do NOT match the native runtime IDs!
The Java SDK maps its own ID space to the native IDs via `ifapi_token_from_identifier`.

**`.xs` parser symbols** (first-encounter order, starting at 100000):

| Symbol | ID |
|--------|----|
| `@proto` | 100000 |
| `@ls` | 100001 |
| `@device` | 100002 |
| `@brand` | 100003 |
| `@fileMapping` | 100004 |
| `@freeSpace` | 100005 |
| `@diskInfo` | 100006 |

`@proto` was the first symbol interned that wasn't already in the SDK's built-in table.
`@ls`, `@device`, `@brand`, `@fileMapping`, `@freeSpace`, `@diskInfo` were interned next
because they weren't encountered during `InitializeNative`.

**Key finding**: The SDK pre-registers ~1870 symbols during init. Common symbols like `@name`,
`@size`, `@path`, `@error`, `@children`, `@md5`, `@sha1`, `@compact`, `@request`, `@response`
are ALL SDK built-ins with fixed IDs. Only app-specific symbols like `@device`, `@brand`,
`@fileMapping`, `@ls` get `.xs` parser IDs (100000+).

**The head unit uses the same `liblib_nng_sdk.so`**, so the SDK built-in IDs (1–~1870) will be
IDENTICAL. The `.xs` parser IDs (100000+) depend on which scripts run, but since both sides
share `core/nftp.xs`, the NFTP-specific symbols should get the same IDs IF they're the first
non-built-in symbols encountered.

**Ghidra address correction**: Ghidra uses image base `0x100000`. Real file offsets are
`ghidra_addr - 0x100000`. E.g. `FUN_00af8b08` → real offset `0x9f8b08`.

#### String Identifiers (TAG_ID_STRING) vs Symbol IDs

The NNG serialisation format supports two ways to encode identifiers:
- `TAG_ID_SYMBOL_VLI` (29): integer symbol ID — requires matching symbol tables
- `TAG_ID_STRING` (13): string name — resolved by the receiver's runtime

Since the phone (YellowBox 1.8.13) and head unit (YellowTool 1.18.1) have different NNG SDK
versions with different built-in symbol tables, integer symbol IDs don't match.

**Test result**: Sending QueryInfo with `TAG_ID_STRING` identifiers to the head unit returns
`status=0` (success) with empty array payload (`1f 00`). This means:
1. String identifiers ARE parsed correctly by the head unit
2. The QueryInfo handler IS running and returning success
3. But the keys (`@device`, `@brand`, `@ls`, etc.) aren't registered in the head unit's lookup table

The QueryInfo handler on YellowTool (head unit) expects keys to be registered by the app's
initialization code. Since we're just sending raw NFTP requests without running the full
YellowTool app context, the lookup table is empty.

**However, this doesn't matter for our use case**: GetFile works perfectly, and `device.nng`
contains all the device info we need (SWID, VIN, iGo version, APPCID). QueryInfo is only
needed for dynamic queries like directory listings, which we can also do via GetFile if needed.

**The core problem**: Symbol IDs are assigned sequentially at runtime. The phone app's NNG runtime and the head unit's NNG runtime both load the same SDK and `.xs` scripts, so they get the same IDs. But our custom Java app is NOT an NNG runtime — we don't know the IDs. We need to either:
1. Discover the IDs by brute-force scanning (in progress, range 700–1500)
2. Intercept the official app's wire traffic to capture the actual IDs
3. Replicate the NNG runtime's symbol assignment order by tracing the `.xs` module load chain

#### Architecture: Native vs Script Layers (from Ghidra decompilation)

The NFTP implementation is split across two layers:

**Native layer** (`system://yellow.nftp` module, in `liblib_nng_sdk.so`):
- Source: `engine/mod_scripting/src/system/nftp/nftp_fd.cpp`
- Provides: socket/fd transport, D-Bus-style remoting, connection lifecycle, authentication
- Exposes to `.xs` scripts: `sendRaw`, `sendMessage`, `setHandler`, `sendMethodCall`
- Also registers symbols: `tryAnonymous`, `identity`, `cookieSha1`, `serial`, `type`, `flags`, `noReply`
- Does NOT implement the NFTP protocol commands (Init, GetFile, QueryInfo, etc.)
- The message processor (`FUN_006bf478`) is a **D-Bus message dispatcher**, not an NFTP command handler

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

#### Native Call Chain (from Ghidra decompilation of liblib_nng_sdk.so)

Traced from the USB/fd entry point through the full connection lifecycle:

```
FUN_00683b04  "createFromFd" — Module init, registers createFromFd as .xs callable
  │  Creates object with vtable PTR_FUN_01d7ac08
  │  Registers symbol "createFromFd" via FUN_00af8b08
  │  Binds FUN_006cfd58 as the implementation
  │  Called by: .xs scripts via nftp.createFromFd(fd, handler)
  │
  ▼
FUN_006ba938  "connection handler" — Called when createFromFd is invoked
  │  Called by: FUN_006ba6e8
  │  Extracts fd and handler args from .xs runtime
  │  Calls FUN_0067c258() to get event loop
  │  On failure: throws "failed to connect"
  │  On success: allocates 0x80-byte session object
  │  Calls FUN_006bac00 to initialise the session
  │
  ▼
FUN_006bac00  "session creation" — Initialises NFTP session
  │  Called by: FUN_006ba938
  │  Sets vtable to PTR_FUN_01d79238 (pre-auth session)
  │  Registers symbols: "tryAnonymous", "identity", "cookieSha1"
  │  Iterates handler options from .xs (auth methods)
  │  Stores fd, event loop ref, handler callback
  │
  ▼
FUN_006bb5e0  "auth handler" — vtable[4] of pre-auth session (PTR_FUN_01d79238)
  │  Handles authentication handshake
  │  On auth failure: calls FUN_00690ec4 with "authentication failed"
  │  On success: allocates 0x90-byte post-auth session
  │  Sets vtable to PTR_FUN_01d793b8 (post-auth session)
  │  Calls FUN_006be6a0 to set up message handling
  │
  ▼
FUN_006be6a0  "post-auth setup" — Initialises the authenticated session
  │  Called by: FUN_006bb5e0
  │  Copies auth state to new session object
  │  Sets up message read/write buffers
  │  6101 chars decompiled — complex initialisation
  │
  ▼
FUN_006bec54  ".xs method dispatcher" — vtable[5] of post-auth session
  │  Called by: .xs scripts when they call methods on the connection object
  │  17096 chars decompiled — the largest function in the NFTP module
  │  Registers symbols: "sendRaw", "sendMessage", "setHandler", "sendMethodCall"
  │  Dispatches based on which .xs method was called:
  │    sendRaw(data)        → sends raw bytes on the wire
  │    sendMessage(msg)     → FUN_0067ac88 (D-Bus message framing)
  │    sendMethodCall(msg)  → FUN_0067ac88 (same, with reply flag)
  │    setHandler(fn)       → stores .xs callback for incoming messages
  │  References "dbus_socket_has_been_closed" error string
  │
  ▼
FUN_006bf0e0  "message reader" — vtable[12] of post-auth session
  │  Called by: FUN_006bf45c (event loop callback)
  │  Reads data from fd into buffer
  │  Parses D-Bus message framing (16-byte header: magic, length, serial, type)
  │  Handles byte order (checks for 'B' = big-endian)
  │  For each complete message: calls FUN_006bf478
  │
  ▼
FUN_006bf478  "message processor" — Processes individual D-Bus messages
  │  Called by: FUN_006bf0e0 (twice — for buffered and streaming paths)
  │  Registers symbols: "serial", "type", "flags", "noReply"
  │  Parses D-Bus header fields from the message
  │  Looks up registered handler (set via setHandler from .xs)
  │  Dispatches message to the .xs handler callback
  │  This is where control passes from native → .xs script
  │  The .xs handler (nftp.xs msgHandler) then parses NFTP commands
```

**Key insight**: The native module is a generic D-Bus-over-fd transport. It knows nothing about NFTP commands (Init=0, GetFile=3, QueryInfo=4, etc.). All NFTP protocol logic lives in the `.xs` scripts. The native module:
1. Opens the fd
2. Handles authentication (tryAnonymous/identity/cookieSha1)
3. Frames messages using D-Bus wire format (not NFTP packet format)
4. Dispatches received messages to the `.xs` handler callback

The NFTP packet framing (4-byte header with length/continuation/transaction ID) is implemented in `core/nftp.xs`, layered on top of the D-Bus transport.

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
