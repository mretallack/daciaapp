# NFTP Probe — Explorer Features Tasks

## Logging Guidelines

All new code must log extensively to aid debugging, especially for protocol-level operations where the wire format is partially reverse-engineered. Every log message goes through the `Logger` interface so it appears both in Android logcat and the app's Log tab.

- **Serialisation**: Log raw hex bytes for every encode/decode operation
- **Protocol requests**: Log command type, parameters, and raw request bytes
- **Protocol responses**: Log status code, raw response bytes (first 128), and parsed values
- **Errors**: Log full context — operation name, path/key, status code, raw hex, exception message
- **Explorer navigation**: Log every directory change, file selection, and action
- **Unknown/unexpected data**: Log the raw hex and tag values so we can diagnose format issues

## 1. NNG Compact Serialisation — Encoder

- [x] Create `NngSerializer.java` in `nftp-core`
- [x] Implement `writeTag(int tag)` — single byte
- [x] Implement `writeVlu(long value)` — variable-length unsigned (reuse VluCodec)
- [x] Implement `writeVli(long value)` — variable-length signed (zigzag encoding)
- [x] Implement `writeString(String s)` — tag 3 + VLU length + UTF-8 bytes
- [x] Implement `writeIdentifierString(String name)` — tag 13 + VLU length + UTF-8 bytes
- [x] Implement `writeTuple(Object... items)` — tag 30 (TupleVLILen) + VLU count + serialised items
- [x] Implement `toBytes()` — return the serialised byte array
- [x] Log encoded bytes as hex after every `toBytes()` call (e.g. `"NngSerializer: encoded 14 bytes: 1e 02 0d 06 ..."`)
- [x] Write `NngSerializerTest`
  - [x] Encode a single string
  - [x] Encode an identifier string
  - [x] Encode a tuple of identifier strings
  - [x] Encode a tuple with mixed types (identifier + string)

## 2. NNG Compact Serialisation — Decoder

- [x] Create `NngDeserializer.java` in `nftp-core`
- [x] Implement `readValue(byte[] data, int offset)` — returns parsed value + new offset
- [x] Handle tag 0 (Undef) → `null`
- [x] Handle tag 1 (Int32) → `Integer` (4 bytes LE)
- [x] Handle tag 2 (UInt64) → `Long` (8 bytes LE)
- [x] Handle tag 3 (String) → `String` (VLU length + UTF-8)
- [x] Handle tag 5 (Double) → `Double` (8 bytes LE)
- [x] Handle tag 6/30 (Tuple/TupleVLILen) → `Object[]`
- [x] Handle tag 7/32 (Dict/DictVLILen) → `Map<String, Object>`
- [x] Handle tag 12/28 (IdentifierInt/IdIntVLI) → `String` (prefixed with `@`)
- [x] Handle tag 13 (IdentifierString) → `String` (prefixed with `@`)
- [x] Handle tag 24/29 (IdentifierSymbol/IdSymbolVLI) → `String` (`@symbol:<id>`)
- [x] Handle tag 26 (Int32VLI) → `Integer` (VLI decoded)
- [x] Handle tag 27 (Int64VLI) → `Long` (VLI decoded)
- [x] Handle tag 31 (ArrayVLILen) → `Object[]`
- [x] Handle unknown tags gracefully — log tag value and hex context, then skip
- [x] Log every decoded value with type and content (e.g. `"NngDeserializer: tag=3 String 'device'"`, `"NngDeserializer: tag=26 Int32VLI 42"`)
- [x] Log raw hex of input data at start of decode (first 64 bytes)
- [x] Write `NngDeserializerTest`
  - [x] Decode each supported type
  - [x] Decode a nested tuple
  - [x] Decode a dict
  - [x] Round-trip: encode then decode

## 3. QueryInfo Support — SKIPPED (symbol IDs unknown)

- [x] Add `buildQueryInfo(String... keys)` to `NftpProbe` — builds `[0x04][serialised tuple of identifier strings]`
- [x] Log the keys being queried (e.g. `"QueryInfo: requesting [@device, @brand]"`)
- [x] Log the raw request bytes as hex
- [x] Add `parseQueryInfoResponse(byte[] resp)` — strips status byte, deserialises response
- [x] Log raw response bytes as hex (first 128 bytes)
- [x] Log parsed response structure (type and value of each field)
- [x] Log error responses with status code and any error string
- [x] Test with string-based identifiers against real head unit
  - String identifiers are accepted (status=0) but return empty results — server doesn't match them
  - Server expects integer symbol IDs (IdentifierSymbol/IdSymbolVLI), not string identifiers
- [~] Discover symbol IDs for @device, @brand, @fileMapping, @freeSpace, @diskInfo, @ls — SKIPPED: brute-force scan of 0–5000 all returned @unknown, sparse scan pending
- [~] If string identifiers fail, log the exact error and raw response for debugging — DONE: root cause is type mismatch in NNGIdentifier.equals()
- [~] If string identifiers fail, investigate symbol ID approach (capture official app traffic) — SKIPPED for now
- [x] Write `NftpQueryInfoTest` with fake server
  - [x] Single key query
  - [x] Multi-key query
  - [x] Error response handling

## 4. CheckSum Support

- [x] Add `buildCheckSum(String path, int method)` to `NftpProbe` — builds `[0x05][method][path\0][vlu:0]`
- [x] Log request: method name (MD5/SHA1), path, raw request bytes
- [x] Add `parseCheckSumResponse(byte[] resp)` — returns hex string of checksum bytes
- [x] Log response: status, raw checksum bytes, formatted hex string
- [x] Log errors with status code and any error message
- [x] Write `NftpCheckSumTest` with fake server
  - [x] MD5 request and response
  - [x] SHA1 request and response
  - [x] Error response

## 5. GetFile Enhancement

- [x] Refactor existing `buildGetFile` to accept any path (already done, just verify)
- [x] Add hex dump utility for displaying binary file content
- [x] Add option to save downloaded file to phone storage
- [x] Write `HexDumpTest`
  - [x] Dump short binary data
  - [x] Dump data with printable and non-printable bytes
  - [x] Dump empty data

## 6. High-Level Explorer API

- [ ] Create `HeadUnitExplorer.java` in `nftp-core`
- [ ] Accept a `Logger` interface (same as NftpProbe) for all logging
- [ ] `connect(InputStream, OutputStream)` — Init handshake + load default file mapping
  - [ ] Log: server name, version, file mapping (hardcoded default)
- [~] `getDeviceInfo()` — SKIPPED: QueryInfo `@device`, `@brand` blocked. Workaround: parse device.nng
- [~] `getDiskInfo()` — SKIPPED: QueryInfo `@freeSpace`, `@diskInfo` blocked
- [~] `listDirectory(String path)` — SKIPPED: QueryInfo `@ls` blocked. Workaround: use hardcoded file mapping tree
- [x] `readFile(String path)` — GetFile → returns `byte[]`
  - [x] Log: path, response size, first 64 bytes as hex
- [x] `getChecksum(String path, int method)` — CheckSum → returns hex string
  - [x] Log: path, method, result hex string
- [x] Log all errors with full context: operation name, path, status code, raw response hex
- [x] `FileEntry` data class: name, path, isDir
- [~] `DeviceInfo` data class — SKIPPED until QueryInfo works or device.nng parsing implemented
- [~] `DiskInfo` data class — SKIPPED until QueryInfo works
- [x] `getDefaultFileMapping()` — returns hardcoded mapping from v1.8.13 app
- [x] `getDirectoryTree()` — returns fixed directory structure
- [x] Write `HeadUnitExplorerTest` with fake server
  - [x] Connect and Init
  - [~] getDeviceInfo returns parsed fields — SKIPPED
  - [~] getDiskInfo returns size and free space — SKIPPED
  - [~] listDirectory returns file entries — SKIPPED
  - [x] readFile returns file bytes
  - [x] getChecksum returns hex string
  - [x] Error handling — query after disconnect

## 7. UI — Tab Layout

- [x] Replace single-activity layout with tab-based navigation
- [x] Add tab bar with Probe, Device, Explorer, Log buttons
- [x] Create 4 views: probe, device, explorer, log
- [x] Manual view switching via FrameLayout
- [x] Share state across views via Activity fields

## 8. UI — Device Tab

- [x] Create `fragment_device.xml` — list of key-value pairs
- [~] DeviceFragment queries `getDeviceInfo()` after connection — SKIPPED: QueryInfo blocked. Show device.nng raw info instead
- [x] Display: connection status, server name/version
- [x] Display: device.nng file size and raw hex preview
- [~] Display: SWID, VIN, iGo version, model name, brand, appcid, SKU, first use date — SKIPPED until device.nng parsing or QueryInfo works
- [~] Display: disk total size, free space, percentage used — SKIPPED until QueryInfo works
- [x] Show "Not connected" state when no connection

## 9. UI — Explorer Tab

- [x] Create `fragment_explorer.xml` — list of known paths from hardcoded file mapping
- [x] Create `item_file_entry.xml` — row layout: icon, name, path
- [x] Create `ExplorerAdapter` — RecyclerView.Adapter for `List<FileEntry>`
- [x] Show fixed directory tree from default file mapping
- [x] Tap file → show file detail dialog/sheet
- [~] Dynamic directory browsing via `@ls` — SKIPPED: QueryInfo blocked
- [~] Breadcrumb navigation — SKIPPED: no dynamic browsing
- [ ] Handle errors (EACCESS, connection lost) — log full error, show user-friendly message

## 10. UI — File Detail Dialog

- [x] Basic AlertDialog with file detail layout
- [x] "Get MD5" button → calls `getChecksum(path, 0)` → displays result
- [x] "Get SHA1" button → calls `getChecksum(path, 1)` → displays result
- [x] "Download" button → calls `readFile(path)` → shows hex dump
- [x] "Save to phone" button → saves downloaded bytes to phone Downloads folder
- [ ] Show file size warning for large files (>1MB)

## 11. UI — Log Tab

- [x] Create `fragment_log.xml` — ScrollView + TextView
- [x] All protocol-level log messages route here
- [x] "Clear" button to reset log
- [x] Auto-scroll to bottom on new messages

## 12. Emulator Updates

- [~] Add QueryInfo handler to Python emulator — SKIPPED: QueryInfo blocked on real device
- [x] Add CheckSum handler to emulator — return MD5/SHA1 of served files
- [x] Add multiple test files to emulator for explorer testing
- [x] Write emulator tests for CheckSum handler
  - [x] CheckSum MD5 returns correct hash
  - [x] CheckSum SHA1 returns correct hash
  - [x] CheckSum for unknown file returns error

## 13. Integration Testing

- [~] Test QueryInfo against real head unit — SKIPPED: symbol IDs unknown
- [~] Test `@ls` directory browsing on real head unit — SKIPPED: symbol IDs unknown
- [ ] Test GetFile for various mapped paths (license/device.nng, etc.)
  - [ ] Log file sizes and first 64 bytes hex for each
- [ ] Test CheckSum against real head unit
  - [ ] Log checksum results and compare with GetFile + local hash
- [ ] Test Explorer UI end-to-end with emulator
- [ ] Test Explorer UI end-to-end with real head unit (hardcoded paths)
- [ ] Document results and any protocol findings
- [ ] Review all logs from real head unit tests — capture any unexpected responses or errors

## 14. Documentation

- [x] Update `README.md` with new features and usage
- [x] Update `nftp.md` with QueryInfo serialisation details
- [x] Update `nftp.md` with CheckSum wire format
- [ ] Add screenshots of Explorer UI to README
