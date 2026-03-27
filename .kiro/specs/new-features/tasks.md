# NFTP Probe — Explorer Features Tasks

## 1. NNG Compact Serialisation — Encoder

- [ ] Create `NngSerializer.java` in `nftp-core`
- [ ] Implement `writeTag(int tag)` — single byte
- [ ] Implement `writeVlu(long value)` — variable-length unsigned (reuse VluCodec)
- [ ] Implement `writeVli(long value)` — variable-length signed (zigzag encoding)
- [ ] Implement `writeString(String s)` — tag 3 + VLU length + UTF-8 bytes
- [ ] Implement `writeIdentifierString(String name)` — tag 13 + VLU length + UTF-8 bytes
- [ ] Implement `writeTuple(Object... items)` — tag 30 (TupleVLILen) + VLU count + serialised items
- [ ] Implement `toBytes()` — return the serialised byte array
- [ ] Write `NngSerializerTest`
  - [ ] Encode a single string
  - [ ] Encode an identifier string
  - [ ] Encode a tuple of identifier strings
  - [ ] Encode a tuple with mixed types (identifier + string)

## 2. NNG Compact Serialisation — Decoder

- [ ] Create `NngDeserializer.java` in `nftp-core`
- [ ] Implement `readValue(byte[] data, int offset)` — returns parsed value + new offset
- [ ] Handle tag 0 (Undef) → `null`
- [ ] Handle tag 1 (Int32) → `Integer` (4 bytes LE)
- [ ] Handle tag 2 (UInt64) → `Long` (8 bytes LE)
- [ ] Handle tag 3 (String) → `String` (VLU length + UTF-8)
- [ ] Handle tag 5 (Double) → `Double` (8 bytes LE)
- [ ] Handle tag 6/30 (Tuple/TupleVLILen) → `Object[]`
- [ ] Handle tag 7/32 (Dict/DictVLILen) → `Map<String, Object>`
- [ ] Handle tag 12/28 (IdentifierInt/IdIntVLI) → `String` (prefixed with `@`)
- [ ] Handle tag 13 (IdentifierString) → `String` (prefixed with `@`)
- [ ] Handle tag 24/29 (IdentifierSymbol/IdSymbolVLI) → `String` (`@symbol:<id>`)
- [ ] Handle tag 26 (Int32VLI) → `Integer` (VLI decoded)
- [ ] Handle tag 27 (Int64VLI) → `Long` (VLI decoded)
- [ ] Handle tag 31 (ArrayVLILen) → `Object[]`
- [ ] Handle unknown tags gracefully — log and skip
- [ ] Write `NngDeserializerTest`
  - [ ] Decode each supported type
  - [ ] Decode a nested tuple
  - [ ] Decode a dict
  - [ ] Round-trip: encode then decode

## 3. QueryInfo Support

- [ ] Add `buildQueryInfo(String... keys)` to `NftpProbe` — builds `[0x04][serialised tuple of identifier strings]`
- [ ] Add `parseQueryInfoResponse(byte[] resp)` — strips status byte, deserialises response
- [ ] Test with string-based identifiers against real head unit
- [ ] If string identifiers fail, investigate symbol ID approach (capture official app traffic)
- [ ] Write `NftpQueryInfoTest` with fake server
  - [ ] Single key query
  - [ ] Multi-key query
  - [ ] Error response handling

## 4. CheckSum Support

- [ ] Add `buildCheckSum(String path, int method)` to `NftpProbe` — builds `[0x05][method][path\0][vlu:0]`
- [ ] Add `parseCheckSumResponse(byte[] resp)` — returns hex string of checksum bytes
- [ ] Write `NftpCheckSumTest` with fake server
  - [ ] MD5 request and response
  - [ ] SHA1 request and response
  - [ ] Error response

## 5. GetFile Enhancement

- [ ] Refactor existing `buildGetFile` to accept any path (already done, just verify)
- [ ] Add hex dump utility for displaying binary file content
- [ ] Add option to save downloaded file to phone storage

## 6. High-Level Explorer API

- [ ] Create `HeadUnitExplorer.java` in `nftp-core`
- [ ] `connect(InputStream, OutputStream)` — Init handshake + query fileMapping
- [ ] `getDeviceInfo()` — QueryInfo `@device`, `@brand` → returns parsed `DeviceInfo` object
- [ ] `getDiskInfo()` — QueryInfo `@freeSpace`, `@diskInfo` → returns `DiskInfo` object
- [ ] `listDirectory(String path)` — QueryInfo `@ls` → returns `List<FileEntry>`
- [ ] `readFile(String path)` — GetFile → returns `byte[]`
- [ ] `getChecksum(String path, int method)` — CheckSum → returns hex string
- [ ] `FileEntry` data class: name, path, size, isFile, mtimeMs
- [ ] `DeviceInfo` data class: appcid, igoVersion, swid, sku, firstUse, imei, vin, agentBrand, modelName, brandName
- [ ] `DiskInfo` data class: totalSize, freeSpace
- [ ] Write `HeadUnitExplorerTest` with fake server

## 7. UI — Tab Layout

- [ ] Replace single-activity layout with tab-based navigation
- [ ] Add `TabLayout` + `ViewPager` (or manual `FrameLayout` switching) to `activity_main.xml`
- [ ] Create 4 fragments: ProbeFragment, DeviceFragment, ExplorerFragment, LogFragment
- [ ] Move existing probe logic into ProbeFragment
- [ ] Move log TextView into LogFragment
- [ ] Share `HeadUnitExplorer` instance across fragments via Activity

## 8. UI — Device Tab

- [ ] Create `fragment_device.xml` — list of key-value pairs
- [ ] DeviceFragment queries `getDeviceInfo()` after connection
- [ ] Display: SWID, VIN, iGo version, model name, brand, appcid, SKU, first use date
- [ ] Display: disk total size, free space, percentage used
- [ ] Show "Not connected" state when no connection

## 9. UI — Explorer Tab

- [ ] Create `fragment_explorer.xml` — breadcrumb bar + RecyclerView
- [ ] Create `item_file_entry.xml` — row layout: icon, name, size, date
- [ ] Create `ExplorerAdapter` — RecyclerView.Adapter for `List<FileEntry>`
- [ ] Breadcrumb bar shows current path, tappable segments to navigate up
- [ ] Tap folder → call `listDirectory(path)` → update adapter
- [ ] Tap file → show file detail dialog/sheet
- [ ] Back button navigates up one directory level
- [ ] Show loading spinner during directory queries
- [ ] Handle empty directories
- [ ] Handle errors (EACCESS, connection lost)

## 10. UI — File Detail Dialog

- [ ] Create `dialog_file_detail.xml` — path, size, modified date, action buttons
- [ ] "Get MD5" button → calls `getChecksum(path, 0)` → displays result
- [ ] "Get SHA1" button → calls `getChecksum(path, 1)` → displays result
- [ ] "Download" button → calls `readFile(path)` → shows hex dump for binary, text for text files
- [ ] "Save to phone" button → saves downloaded bytes to phone Downloads folder
- [ ] Show file size warning for large files (>1MB)

## 11. UI — Log Tab

- [ ] Create `fragment_log.xml` — ScrollView + TextView (same as current main screen)
- [ ] All protocol-level log messages route here
- [ ] "Clear" button to reset log
- [ ] Auto-scroll to bottom on new messages

## 12. Emulator Updates

- [ ] Add QueryInfo handler to Python emulator
  - [ ] Handle `@device` — return fake device info
  - [ ] Handle `@brand` — return fake brand info
  - [ ] Handle `@fileMapping` — return default mapping
  - [ ] Handle `@freeSpace` — return fake value
  - [ ] Handle `@diskInfo` — return fake size + available
  - [ ] Handle `@ls` — return fake directory listing
- [ ] Add CheckSum handler to emulator — return MD5/SHA1 of served files
- [ ] Write emulator tests for new handlers

## 13. Integration Testing

- [ ] Test QueryInfo against real head unit — verify string identifiers work
- [ ] Test `@ls` directory browsing on real head unit
- [ ] Test GetFile for various paths (config files, .xs scripts, license files)
- [ ] Test CheckSum against real head unit
- [ ] Test Explorer UI end-to-end with emulator
- [ ] Test Explorer UI end-to-end with real head unit
- [ ] Document results and any protocol findings

## 14. Documentation

- [ ] Update `README.md` with new features and usage
- [ ] Update `nftp.md` with QueryInfo serialisation details
- [ ] Update `nftp.md` with CheckSum wire format
- [ ] Add screenshots of Explorer UI to README
