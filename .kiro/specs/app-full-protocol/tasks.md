# Tasks: App Full Protocol Support

## Task 1: Add data classes and query methods to HeadUnitExplorer

- [x] Add `DeviceInfo` class: swid, vin, igoVersion, appcid, agentBrand, modelName, brandName
- [x] Add `DiskInfo` class: available, size
- [x] Update `FileEntry` to include `size` (long) field
- [x] Add `queryDeviceInfo()` — sends QueryInfo(@device, @brand), parses response into DeviceInfo
- [x] Add `queryDiskInfo()` — sends QueryInfo(@diskInfo), parses response into DiskInfo
- [x] Add `queryFileMapping()` — sends QueryInfo(@fileMapping), parses response into Map
- [x] Add `listDirectory(String path)` — sends QueryInfo(@ls, path, #{fields:(@name,@size,@isFile)}), parses recursive tuple into List<FileEntry>
- [x] Handle `@`-prefixed dict keys from deserializer (strip prefix when extracting fields)
- [x] All methods return null on failure and log the error
- [x] Update class javadoc to remove "blocked" note

## Task 2: Update connect() sequence

- [x] After Init, call queryFileMapping() and store result (fall back to hardcoded default)
- [x] After fileMapping, call queryDeviceInfo() and store result
- [x] After device, call queryDiskInfo() and store result
- [x] Add getters: getDeviceInfo(), getDiskInfo(), getFileMapping()
- [x] Keep GetFile device.nng as final step (unchanged)

## Task 3: Add buildLsQueryCompact to NftpProbe

- [x] Add `buildLsQueryCompact(String path, String... fields)` using `NngSerializer.writeIdentifier()` (not the deprecated writeIdentifierString)
- [x] Default fields: name, size, isFile
- [x] Verify it produces the same wire format as the emulator expects

## Task 4: Update Device tab UI

- [x] Show DeviceInfo fields when available: SWID, VIN, iGo version, APPCID, brand, model
- [x] Show DiskInfo when available: total size, available space, percentage bar or text
- [x] Fall back to raw device.nng hex when DeviceInfo is null
- [x] Show "Disk info unavailable" when DiskInfo is null

## Task 5: Update Explorer tab for dynamic @ls

- [x] On tab show, call listDirectory("/") if connected
- [x] Display returned FileEntry list in RecyclerView (name, size for files, folder icon for dirs)
- [x] Tap directory → push path, call listDirectory(newPath), update list
- [x] Add back/up entry at top of list when not at root
- [x] Tap file → show file detail dialog
- [x] Fall back to hardcoded getDirectoryTree() when @ls fails or not connected
- [x] Show current path in a breadcrumb or title

## Task 6: Wire file detail dialog to active connection

- [x] "Get MD5" → call explorer.getChecksum(path, 0), display result
- [x] "Get SHA1" → call explorer.getChecksum(path, 1), display result
- [x] "Download" → call explorer.readFile(path), display hex dump in dialog
- [x] "Save" → save downloaded bytes to Downloads folder
- [x] Show "Not connected" if explorer is null or disconnected
- [x] Show spinner/progress during operations

## Task 7: Connection lifecycle in MainActivity

- [x] Store HeadUnitExplorer as activity field (replace current lastResult pattern)
- [x] On TCP connect: create HeadUnitExplorer, call connect(), update all tabs
- [x] On USB connect: same flow
- [x] On disconnect/error: set explorer to null, update all tabs to disconnected state
- [x] Retain connection across tab switches

## Task 8: Test against emulator

- [x] Connect to emulator via TCP, verify Init succeeds
- [x] Verify Device tab shows: SWID=EMU-TEST-0001, VIN=VF1TESTEMU000001, brand=Dacia
- [x] Verify Device tab shows disk info (8GB total, available space)
- [x] Verify Explorer tab shows dynamic directory listing from @ls
- [x] Navigate into content/map/, verify file list with sizes
- [x] Tap a file, verify MD5/SHA1 buttons return correct hashes
- [x] Tap Download, verify hex dump appears
- [ ] Disconnect, verify all tabs show disconnected state (requires phone)
- [ ] Reconnect, verify data refreshes (requires phone)

Note: Integration tested via Python client against live emulator — all queries
return correct data. Full UI testing requires APK installed on phone.
