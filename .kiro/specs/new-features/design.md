# NFTP Probe — Explorer Features Design

> **⚠️ PARTIALLY OUT OF DATE (2025-03-28):** This design was written when QueryInfo was
> blocked by the symbol ID problem — all `@device`, `@brand`, `@fileMapping`, `@ls` etc.
> queries were marked as blocked/skipped because we couldn't figure out how to encode
> NNG symbol identifiers on the wire. That problem has since been solved: the NNG compact
> serialisation format uses `0x8d` + null-terminated string names, not integer symbol IDs.
> This was discovered by running the real NNG SDK on Android and capturing the bytes it
> produces via `Stream(@compact)`. See the "BREAKTHROUGH: NNG Compact Serialisation"
> section in `nftp.md` for full details. As a result, all the "BLOCKED" and "SKIPPED"
> items in this design (QueryInfo, dynamic `@ls` browsing, device/disk info) are now
> unblocked and can be implemented. The workarounds (hardcoded file mapping, GetFile-only
> explorer) are no longer necessary as the sole approach.

## Goal

Extend the NFTP Probe app from a simple Init+GetFile probe into a head unit explorer that can query device info, browse the filesystem, read files, and compute checksums — all read-only.

## New Features

1. **QueryInfo `@device`** — device info (appcid, igoVersion, swid, sku, firstUse, imei, vin)
2. **QueryInfo `@brand`** — brand info (agentBrand, modelName, brandName, brandFiles)
3. **QueryInfo `@fileMapping`** — file extension → path mapping table
4. **QueryInfo `@freeSpace`** — available disk space
5. **QueryInfo `@diskInfo`** — disk size and available space
6. **QueryInfo `@ls`** — directory listing with name, size, isFile, mtimeMs
7. **GetFile** — read any file under `/navi` by path
8. **CheckSum** — compute MD5 or SHA1 of a remote file

## Architecture

### NNG Compact Serialisation

QueryInfo uses NNG's proprietary binary serialisation format (`Stream(@compact)`). We must implement encode/decode for this format.

From the decompiled `TypeTag` enum and `Serializer.java`, the wire format is:

```
Each value is: [tag byte] [payload]

Tag byte: bits 0-5 = type tag, bit 7 = modifier (noAutoDeref for identifiers)

Key type tags:
  0  = Undef (no payload)
  1  = Int32 (4 bytes LE)
  2  = UInt64 (8 bytes LE)
  3  = String (VLU length + UTF-8 bytes)
  5  = Double (8 bytes LE)
  6  = Tuple (u32 count + N values) 
  7  = Dict (u32 count + N key-value pairs)
  12 = IdentifierInt (4 bytes LE int)
  13 = IdentifierString (VLU length + UTF-8 bytes)
  24 = IdentifierSymbol (4 bytes LE symbol ID)
  26 = Int32VLI (VLI-encoded int, compact form)
  27 = Int64VLI (VLI-encoded long)
  28 = IdIntVLI (VLI-encoded identifier int)
  29 = IdSymbolVLI (VLI-encoded symbol ID)
  30 = TupleVLILen (VLU count + N values)
  31 = ArrayVLILen (VLU count + N values)
  32 = DictVLILen (VLU count + N key-value pairs)

VLI = variable-length signed int (zigzag + VLU)
VLU = variable-length unsigned int (7 bits per byte, MSB = continuation)
```

Symbols (like `@device`, `@brand`, `@fileMapping`, `@ls`) are encoded as `IdentifierSymbol` or `IdSymbolVLI` with an integer symbol ID. The symbol table is maintained by the NNG SDK runtime — we need to discover the mapping.

### Symbol ID Discovery — BLOCKED

The `.xs` scripts use `@device`, `@brand`, `@fileMapping`, `@ls`, `@freeSpace`, `@diskInfo` etc. These are NNG symbols with integer IDs assigned sequentially at runtime by the NNG SDK.

**Status: Symbol IDs are unknown and all discovery approaches have failed so far.**

Investigation (2025-03-27) confirmed:
- **IdentifierString (tag 13) does not work** — the server deserialises it as `NNGIdentifier(String)` which never equals `NNGIdentifier(NngSymbol)` due to Java type mismatch in `equals()`
- **Brute-force scan of IDs 0–5000** returned `@unknown` for every ID
- **Sparse scan of IDs 5000–100000** (pending) — may find them if IDs are larger than expected
- The symbol IDs are assigned sequentially: 736 SDK symbols first, then `.xs` script symbols in module load order
- Both phone app and head unit share the same NNG SDK + `core/nftp.xs`, so IDs should match — but the exact values are unknown

**Impact on features:**
- QueryInfo (`@device`, `@brand`, `@fileMapping`, `@freeSpace`, `@diskInfo`) — **BLOCKED**
- Directory listing (`@ls`) — **BLOCKED**
- Device info tab — **BLOCKED** (partial workaround: parse `device.nng` from GetFile)
- Explorer directory browsing — **BLOCKED** (workaround: use hardcoded file mapping paths)

**Features that work without QueryInfo:**
- GetFile with known/mapped paths
- CheckSum (MD5/SHA1) for known paths
- Tab-based UI layout
- Log tab
- File detail dialog (download, save, checksum)

### Workarounds for Blocked Features

1. **Device info**: Parse `device.nng` binary (already downloaded via GetFile) to extract SWID, VIN, etc. instead of QueryInfo `@device`
2. **Explorer**: Use the hardcoded default file mapping to provide a fixed directory structure (`license/`, `content/map/`, `content/poi/`, `content/speedcam/`) instead of dynamic `@ls` browsing
3. **File mapping**: Use the default mapping from the v1.8.13 app as a fallback since we can't query `@fileMapping`

### CheckSum Request Format (from nftp.xs)

```
[0x05]                          — command type
[0x00 or 0x01]                  — method (0=MD5, 1=SHA1)
[string: filename\0]            — null-terminated path
[vlu: from]                     — byte offset (typically 0)
[vlu: len]                      — length (0 = whole file, optional)
```

Response: `[0x00][checksum bytes]` (16 bytes for MD5, 20 for SHA1)

## UI Design

### Tab-Based Layout

Replace the current single-screen log view with a tabbed interface:

1. **Probe** tab (existing) — Init + GetFile, shows connection status and device.nng
2. **Device** tab — shows parsed device info from QueryInfo `@device` + `@brand`
3. **Explorer** tab — filesystem browser using `@ls`, with ability to:
   - Navigate directories (tap to enter, back to go up)
   - View file details (size, modified time)
   - Download/view small files (GetFile)
   - Compute checksums (CheckSum)
4. **Log** tab — raw protocol log (moved from main screen)

### Explorer Tab Detail

The explorer shows the head unit's filesystem based on the hardcoded file mapping (dynamic `@ls` directory listing is blocked — see Symbol ID Discovery above).

- Fixed directory tree derived from the default file mapping:
  - `license/` — device.nng, license files (.lyc)
  - `content/map/` — map files (.fbl, .hnr, .fda, etc.)
  - `content/poi/` — POI files (.poi)
  - `content/speedcam/` — speed camera files (.spc)
- Tap folder → show known files in that path (via GetFile probing or hardcoded list)
- Tap file → show detail sheet with:
  - Full path, size (from GetFile response length)
  - "Get MD5" button → runs CheckSum
  - "Get SHA1" button → runs CheckSum
  - "Download" button → runs GetFile, shows hex dump + saves to phone storage
- No dynamic directory browsing (requires `@ls` via QueryInfo)

### Connection Flow

On USB attach or manual connect:
1. Init handshake (existing)
2. GetFile `license/device.nng` → parse for device info (SWID, VIN, etc.)
3. Use hardcoded default file mapping (QueryInfo `@fileMapping` blocked)
4. Explorer tab becomes available with fixed directory structure from file mapping
5. ~~QueryInfo `@device`, `@brand` → populate Device tab~~ (BLOCKED — use device.nng instead)
6. ~~QueryInfo `@freeSpace`, `@diskInfo` → show in Device tab~~ (BLOCKED)
## Implementation Plan

### nftp-core changes

1. **NngSerializer.java** — encode values in NNG compact format
   - `encodeTuple(Object... items)` → `byte[]`
   - `encodeIdentifierString(String name)` → writes tag 13 + string
   - `encodeString(String s)` → writes tag 3 + VLU length + bytes
   - Support for nested tuples

2. **NngDeserializer.java** — decode NNG compact format responses
   - `readValue(byte[] data, int offset)` → returns parsed Object + new offset
   - Handle: Undef, Int32, UInt64, String, Double, Tuple, Dict, IdentifierInt, IdentifierString, IdentifierSymbol, VLI variants
   - Return tuples as `Object[]`, dicts as `Map<String, Object>`, identifiers as strings

3. **NftpProbe.java** — add methods:
   - `queryInfo(NftpConnection, String... keys)` → `Object[]`
   - `getFile(NftpConnection, String path)` → `byte[]`
   - `checkSum(NftpConnection, String path, int method)` → `byte[]`
   - `listDir(NftpConnection, String path)` → `List<FileEntry>`

### nftp-app changes

4. **MainActivity.java** — add tab navigation (ViewPager or manual tab switching)
5. **ProbeFragment / DeviceFragment / ExplorerFragment / LogFragment**
6. **ExplorerAdapter** — RecyclerView adapter for directory listings
7. **FileDetailActivity** — shows file info, checksum, download options

## Safety

- All operations are read-only (QueryInfo, GetFile, CheckSum)
- No PushFile, DeleteFile, RenameFile, Mkdir, Chmod, or any write commands
- PrepareForTransfer / TransferFinished are never sent
- Explorer only browses and reads — cannot modify anything

## Key Risks

1. **Symbol IDs — REALIZED** — String identifiers don't work, brute-force scan hasn't found the IDs. QueryInfo, directory listing, and device/disk info are blocked until IDs are discovered. Workarounds in place using GetFile + hardcoded paths.
2. **Large files** — GetFile for big map files (hundreds of MB) needs streaming, not buffering in memory
3. **Connection stability** — USB AOA can disconnect at any time; need graceful handling
4. **device.nng format** — Binary format, partially understood. Need to parse it for device info as a workaround for blocked QueryInfo `@device`.
