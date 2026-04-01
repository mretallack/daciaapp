# Requirements: App Full Protocol Support

## Overview

Update the NFTP Probe Android app and nftp-core library to use the validated
NNG compact serialisation format (0x8d identifiers) for all QueryInfo queries,
and implement dynamic directory browsing, device info, disk info, and file
mapping — replacing the hardcoded workarounds with real protocol queries.

The emulator already supports all 14 NFTP commands and returns correct NNG
compact responses. The app needs to consume these.

## User Stories

### US-1: QueryInfo with 0x8d Compact Identifiers

As a developer, I want the app to send QueryInfo requests using the validated
0x8d compact identifier format so that the emulator (and eventually the real
head unit) returns actual data.

**Acceptance Criteria:**
- WHEN the app sends QueryInfo THE SYSTEM SHALL encode identifiers as 0x8d + null-terminated string
- WHEN the app receives a QueryInfo response THE SYSTEM SHALL deserialise it using NngDeserializer
- WHEN the response contains nested dicts/tuples THE SYSTEM SHALL parse them into Java Maps/arrays

### US-2: Device Info via QueryInfo

As a user, I want to see device information (SWID, VIN, iGo version, brand)
on the Device tab so that I can identify the connected head unit.

**Acceptance Criteria:**
- WHEN connected THE SYSTEM SHALL send QueryInfo(@device, @brand) after Init
- WHEN the response is received THE SYSTEM SHALL parse swid, vin, igoVersion, appcid from @device
- WHEN the response is received THE SYSTEM SHALL parse agentBrand, modelName, brandName from @brand
- WHEN the Device tab is shown THE SYSTEM SHALL display all parsed fields
- WHEN QueryInfo fails THE SYSTEM SHALL fall back to showing device.nng raw data

### US-3: Disk Info via QueryInfo

As a user, I want to see disk space information (total, available, percentage)
on the Device tab so that I know how much space is available.

**Acceptance Criteria:**
- WHEN connected THE SYSTEM SHALL send QueryInfo(@diskInfo) after Init
- WHEN the response is received THE SYSTEM SHALL parse available and size fields
- WHEN the Device tab is shown THE SYSTEM SHALL display total size, available space, and percentage used
- WHEN QueryInfo fails THE SYSTEM SHALL show "Disk info unavailable"

### US-4: File Mapping via QueryInfo

As a developer, I want the app to query the real file mapping from the server
so that file paths are resolved correctly.

**Acceptance Criteria:**
- WHEN connected THE SYSTEM SHALL send QueryInfo(@fileMapping) after Init
- WHEN the response is received THE SYSTEM SHALL parse the extension-to-path mapping dict
- WHEN the file mapping is available THE SYSTEM SHALL use it for all file operations
- WHEN QueryInfo fails THE SYSTEM SHALL fall back to the hardcoded default mapping

### US-5: Dynamic Directory Listing via @ls

As a user, I want to browse the head unit filesystem dynamically on the
Explorer tab so that I can see actual files and directories.

**Acceptance Criteria:**
- WHEN the Explorer tab is shown THE SYSTEM SHALL send QueryInfo(@ls, path, #{fields: (@name, @size, @isFile)})
- WHEN the response is received THE SYSTEM SHALL parse the recursive tuple structure into FileEntry objects
- WHEN a directory is tapped THE SYSTEM SHALL send a new @ls query for that path
- WHEN a file is tapped THE SYSTEM SHALL show the file detail dialog
- WHEN @ls fails THE SYSTEM SHALL fall back to the hardcoded directory tree
- WHEN navigating directories THE SYSTEM SHALL show a back button to go up

### US-6: File Detail Actions with Active Connection

As a user, I want the file detail dialog buttons (MD5, SHA1, Download) to
actually work using the active connection.

**Acceptance Criteria:**
- WHEN "Get MD5" is tapped THE SYSTEM SHALL call getChecksum(path, 0) and display the result
- WHEN "Get SHA1" is tapped THE SYSTEM SHALL call getChecksum(path, 1) and display the result
- WHEN "Download" is tapped THE SYSTEM SHALL call readFile(path) and display a hex dump
- WHEN "Save" is tapped after download THE SYSTEM SHALL save the file to phone Downloads
- WHEN the connection is not active THE SYSTEM SHALL show "Not connected" instead of attempting the operation

### US-7: Connection Lifecycle

As a user, I want the connection to persist across tab switches so that I can
browse files, check device info, and compute checksums without reconnecting.

**Acceptance Criteria:**
- WHEN connected via TCP or USB THE SYSTEM SHALL store the HeadUnitExplorer instance
- WHEN switching tabs THE SYSTEM SHALL retain the connection
- WHEN the connection drops THE SYSTEM SHALL update all tabs to show disconnected state
- WHEN reconnecting THE SYSTEM SHALL re-run the Init + QueryInfo sequence
