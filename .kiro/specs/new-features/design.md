# NFTP Probe — Explorer Features Design

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

### Symbol ID Discovery

The `.xs` scripts use `@device`, `@brand`, `@fileMapping`, `@ls`, `@freeSpace`, `@diskInfo` etc. These are NNG symbols with integer IDs assigned at compile time or runtime.

**Approach**: Rather than reverse-engineering the symbol table, we can:
1. Use `IdentifierString` (tag 13) instead of `IdentifierSymbol` — write the key as a string like `"device"`, `"brand"`, `"fileMapping"`. The server-side Reader should accept string identifiers.
2. If string identifiers don't work, capture the wire bytes from the official app to discover the symbol IDs.

From the `nftp.xs` source, `queryInfo` serialises keys as:
```javascript
w.u8(Message.QueryInfo);  // 0x04
writeValue(w, keys)       // Stream(@compact).add(keys) — serialises a tuple of identifiers
```

Where `keys` is a tuple like `(@device, @brand)` or `(@fileMapping)` or `(@ls, "content")`.

### QueryInfo Request Format

```
[0x04]                          — command type
[compact-serialised tuple]      — keys to query
```

The tuple contains identifier symbols. For `@ls`, the second element is a string path.

### QueryInfo Response Format

```
[0x00]                          — status (success)
[compact-serialised value]      — response data (tuple of results, one per key)
```

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

The explorer is the primary new feature. It shows:
- Current path as breadcrumb (e.g. `/` → `content/` → `content/map/`)
- List of entries: icon (folder/file), name, size, modified date
- Tap folder → navigate into it
- Tap file → show detail sheet with:
  - Full path, size, modified time
  - "Get MD5" button → runs CheckSum
  - "Download" button → runs GetFile, shows hex dump + saves to phone storage
- Pull-to-refresh to re-query current directory

### Connection Flow

On USB attach or manual connect:
1. Init handshake (existing)
2. QueryInfo `@fileMapping` → store mapping
3. QueryInfo `@device`, `@brand` → populate Device tab
4. QueryInfo `@freeSpace`, `@diskInfo` → show in Device tab
5. Explorer tab becomes available, starts at root (`""`)

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

### Serialisation Priority

The biggest unknown is whether string-based identifiers work for QueryInfo. The first implementation step should be:
1. Send `queryInfo` with string identifiers
2. If that fails, capture official app traffic to discover symbol IDs
3. Fall back to raw hex if needed

## Safety

- All operations are read-only (QueryInfo, GetFile, CheckSum)
- No PushFile, DeleteFile, RenameFile, Mkdir, Chmod, or any write commands
- PrepareForTransfer / TransferFinished are never sent
- Explorer only browses and reads — cannot modify anything

## Key Risks

1. **NNG serialisation format** — may have undocumented quirks; string identifiers may not work
2. **Large files** — GetFile for big map files (hundreds of MB) needs streaming, not buffering in memory
3. **Symbol IDs** — if string identifiers are rejected, we need to reverse-engineer the symbol table
4. **Connection stability** — USB AOA can disconnect at any time; need graceful handling
