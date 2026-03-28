# Design: App Full Protocol Support

## Overview

Replace the hardcoded workarounds in HeadUnitExplorer and the UI with real
QueryInfo queries using the validated 0x8d compact serialisation format.
The emulator already returns correct responses for all queries.

## Validated Serialisation Method

Confirmed by capturing bytes from the real NNG SDK on Android (see nftp.md
"BREAKTHROUGH" section):

- Identifiers are encoded as `0x8d` + null-terminated UTF-8 string
- `NngSerializer.writeIdentifier(name)` already produces this format
- `NngDeserializer` already handles tag `0x8d` (modifier bit + TAG_ID_STRING)
- `NftpProbe.buildQueryInfo(keys...)` wraps keys in a tuple with `@` prefix
- `NftpProbe.queryInfo(conn, log, keys...)` sends and parses the response

No serialisation changes needed — the codec is correct. The work is in
HeadUnitExplorer (adding query methods) and the UI (consuming the data).

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   MainActivity                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │ Probe Tab│ │Device Tab│ │Explorer  │ │Log Tab │ │
│  │          │ │          │ │   Tab    │ │        │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────────┘ │
│       │             │            │                   │
│       └─────────────┼────────────┘                   │
│                     ▼                                │
│            HeadUnitExplorer (shared instance)         │
│            ┌────────────────────────────┐            │
│            │ connect()     → Init + queries          │
│            │ getDeviceInfo()  → @device, @brand      │
│            │ getDiskInfo()    → @diskInfo             │
│            │ getFileMapping() → @fileMapping          │
│            │ listDirectory()  → @ls                   │
│            │ readFile()       → GetFile               │
│            │ getChecksum()    → CheckSum              │
│            └──────────┬─────────────────┘            │
│                       ▼                              │
│              NftpProbe (static methods)               │
│              NftpConnection (transport)                │
└─────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. HeadUnitExplorer as Shared Connection

MainActivity holds a single `HeadUnitExplorer` instance. All tabs use it.
On connect, it runs the full Init + QueryInfo sequence:

```
Init → QueryInfo(@fileMapping) → QueryInfo(@device, @brand) → QueryInfo(@diskInfo) → GetFile device.nng
```

This matches the official app's connection sequence (see nftp.md).

### 2. Data Classes

```java
public static class DeviceInfo {
    public String swid, vin, igoVersion, appcid;
    public String agentBrand, modelName, brandName;
}

public static class DiskInfo {
    public long available, size;
}

public static class FileEntry {
    public String name, path;
    public boolean isDir;
    public long size;
}
```

### 3. QueryInfo Response Parsing

`NftpProbe.queryInfo()` returns a deserialized `Object` — either a `Map` (dict),
`Object[]` (tuple), or primitive. HeadUnitExplorer methods cast and extract fields:

```java
// @device returns a dict: {swid: "...", vin: "...", ...}
Object result = NftpProbe.queryInfo(conn, log, "device");
Map<String, Object> device = (Map<String, Object>) result;
info.swid = (String) device.get("@swid");
```

Note: dict keys come back as `"@swid"` (with `@` prefix) because the emulator
serialises them as identifiers. The parser needs to handle both `"@swid"` and
`"swid"` key formats.

### 4. @ls Response Parsing

The @ls response is a recursive tuple structure:
```
(name, size, isFile, child1, child2, ...)
```
Where each child is also a tuple with the same structure. Fields are in the
order requested. Children follow after the requested fields.

```java
// Parse @ls response tuple into FileEntry list
Object[] root = (Object[]) result;  // (name, size, isFile, child1, child2, ...)
int fieldCount = requestedFields.length;  // e.g. 3 for (name, size, isFile)
List<FileEntry> entries = new ArrayList<>();
for (int i = fieldCount; i < root.length; i++) {
    Object[] child = (Object[]) root[i];
    entries.add(parseFileEntry(child, requestedFields));
}
```

### 5. Explorer Navigation

The Explorer tab maintains a path stack for navigation:
- Root shows top-level dirs from @ls "/"
- Tapping a dir pushes to the stack and queries @ls for that path
- Back button pops the stack
- Files show the detail dialog

### 6. Connection Lifecycle

```
TCP/USB connect
  → HeadUnitExplorer.connect(in, out, logger)
    → Init handshake
    → queryFileMapping()   → stores Map<String,String>
    → queryDeviceInfo()    → stores DeviceInfo
    → queryDiskInfo()      → stores DiskInfo
    → GetFile device.nng   → stores byte[]
  → Update all tabs with new data

Tab switch
  → Read from stored HeadUnitExplorer fields (no new queries)

Explorer navigate
  → listDirectory(path)   → new @ls query each time

Disconnect / error
  → explorer = null
  → All tabs show "Not connected"
```

### 7. File Detail Dialog

Wire up the existing dialog buttons to the shared HeadUnitExplorer:
- MD5/SHA1: call `explorer.getChecksum(path, method)`, display hex result
- Download: call `explorer.readFile(path)`, display hex dump
- Save: write downloaded bytes to Downloads folder

### 8. Error Handling

All QueryInfo calls can fail (status != 0 or parse error). Each method
returns null on failure and logs the error. The UI shows fallback content:
- Device info: show raw device.nng hex
- Disk info: show "unavailable"
- File mapping: use hardcoded default
- @ls: use hardcoded directory tree

## Sequence Diagram: Full Connection

```
App                          Emulator
 │                              │
 │──── Init ───────────────────▶│
 │◀─── OK + server name ───────│
 │                              │
 │──── QueryInfo(@fileMapping)─▶│
 │◀─── {".lyc":"license/",...} ─│
 │                              │
 │──── QueryInfo(@device,@brand)▶│
 │◀─── ({swid,vin,...},{brand})─│
 │                              │
 │──── QueryInfo(@diskInfo) ───▶│
 │◀─── {available,size} ───────│
 │                              │
 │──── GetFile device.nng ─────▶│
 │◀─── [bytes] ────────────────│
 │                              │
 │  ── User browses Explorer ── │
 │                              │
 │──── QueryInfo(@ls,"content",│
 │     #{fields:(@name,@size,  │
 │       @isFile)}) ───────────▶│
 │◀─── (name,size,isFile,      │
 │      child1,child2,...) ─────│
```

## Files to Modify

### nftp-core
- `HeadUnitExplorer.java` — add queryDeviceInfo, queryDiskInfo, queryFileMapping, listDirectory; add DeviceInfo, DiskInfo classes; update connect() sequence; update FileEntry with size field
- `NftpProbe.java` — add buildLsQueryCompact() using writeIdentifier (the existing buildLsQuery uses deprecated writeIdentifierString)

### nftp-app
- `MainActivity.java` — store shared HeadUnitExplorer; update Device tab to show parsed fields; update Explorer tab for dynamic @ls; wire file detail dialog to real connection
- `ExplorerAdapter.java` — add size display, dir/file icons, back entry

### No changes needed
- `NngSerializer.java` — writeIdentifier() already correct
- `NngDeserializer.java` — already handles all tag types
- `emulator/` — already complete
