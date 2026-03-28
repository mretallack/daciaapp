# Requirements: Emulator Full NFTP Protocol

## User Stories

### US-1: Mutable Filesystem

As a developer testing the NFTP protocol, I want the emulator to maintain a mutable in-memory filesystem so that write operations (PushFile, DeleteFile, RenameFile, Mkdir) modify state and subsequent reads reflect those changes.

**Acceptance Criteria:**
- WHEN a file is pushed via PushFile THE SYSTEM SHALL store the data and make it available to GetFile, CheckSum, and @ls queries
- WHEN a file is deleted via DeleteFile THE SYSTEM SHALL remove it from the filesystem and subsequent GetFile/CheckSum/ls SHALL NOT include it
- WHEN a file is renamed via RenameFile THE SYSTEM SHALL move the file to the new path atomically
- WHEN a directory is created via Mkdir THE SYSTEM SHALL create it in the filesystem tree and it SHALL appear in @ls results
- WHEN the emulator starts THE SYSTEM SHALL populate the filesystem with the default fake files (license/, content/ trees)

### US-2: PushFile (cmd 1)

As a developer testing map updates, I want the emulator to handle PushFile with all option flags so that I can test the full upload flow.

**Acceptance Criteria:**
- WHEN a PushFile request is received THE SYSTEM SHALL parse the path, options bitmask, and file content from the request body
- WHEN TruncateFile (0x01) is set THE SYSTEM SHALL truncate the file before writing
- WHEN UsePartFile (0x02) is set THE SYSTEM SHALL write to `<path>.part` and rename to `<path>` on successful completion
- WHEN OverwriteOriginal (0x04) is set with UsePartFile THE SYSTEM SHALL rename the original file to `.part` before writing
- WHEN TrimToWritten (0x08) is set THE SYSTEM SHALL trim the file to the written length on completion
- WHEN OnlyIfExists (0x10) is set AND the file does not exist THE SYSTEM SHALL return Failed (1)
- WHEN the options byte is 0 (None) THE SYSTEM SHALL append to the file (or create it)
- WHEN PushFile includes a resume offset (UsePartFile with VLU offset) THE SYSTEM SHALL append from that offset

### US-3: DeleteFile (cmd 6)

As a developer testing content removal, I want the emulator to handle DeleteFile so that files and directories can be removed.

**Acceptance Criteria:**
- WHEN a DeleteFile request is received THE SYSTEM SHALL parse the path and recursive flag
- WHEN the file exists THE SYSTEM SHALL remove it and return Success (0)
- WHEN the recursive flag is set AND the path is a directory THE SYSTEM SHALL remove the directory and all contents
- WHEN the file does not exist THE SYSTEM SHALL return Failed (1)

### US-4: RenameFile (cmd 7)

As a developer testing atomic updates, I want the emulator to handle RenameFile so that `.part` files can be renamed to their final paths.

**Acceptance Criteria:**
- WHEN a RenameFile request is received THE SYSTEM SHALL parse the source path (in the command) and destination path (null-terminated string following)
- WHEN the source file exists THE SYSTEM SHALL move it to the destination path and return Success (0)
- WHEN the source file does not exist THE SYSTEM SHALL return Failed (1)
- WHEN the destination already exists THE SYSTEM SHALL overwrite it

### US-5: LinkFile (cmd 8)

As a developer, I want the emulator to handle LinkFile so that symlink/hardlink operations don't cause errors.

**Acceptance Criteria:**
- WHEN a LinkFile request is received THE SYSTEM SHALL parse the original path, new path, and hardlink boolean
- WHEN the original file exists THE SYSTEM SHALL create a copy at the new path (emulating a link) and return Success (0)
- WHEN the original file does not exist THE SYSTEM SHALL return Failed (1)

### US-6: Mkdir (cmd 12)

As a developer, I want the emulator to handle Mkdir so that directory creation works during update flows.

**Acceptance Criteria:**
- WHEN a Mkdir request is received THE SYSTEM SHALL parse the path
- WHEN the path does not exist THE SYSTEM SHALL create the directory (and parent directories) and return Success (0)
- WHEN the path already exists as a directory THE SYSTEM SHALL return Success (0)
- WHEN the path already exists as a file THE SYSTEM SHALL return Failed (1)

### US-7: Chmod (cmd 13)

As a developer, I want the emulator to accept Chmod without error so that permission changes don't break the update flow.

**Acceptance Criteria:**
- WHEN a Chmod request is received THE SYSTEM SHALL parse the path and mode
- THE SYSTEM SHALL return Success (0) regardless (no permission tracking needed)

### US-8: PrepareForTransfer / TransferFinished (cmd 10, 11)

As a developer testing the update lifecycle, I want the emulator to track transfer state so that the update flow can be validated.

**Acceptance Criteria:**
- WHEN PrepareForTransfer is received THE SYSTEM SHALL set an internal "transfer in progress" flag and return Success (0)
- WHEN TransferFinished is received THE SYSTEM SHALL clear the flag and return Success (0)
- WHEN verbose mode is enabled THE SYSTEM SHALL log transfer state transitions

### US-9: Control Messages (StopStream, PauseStream, ResumeStream)

As a developer testing streaming transfers, I want the emulator to handle control messages so that flow control doesn't cause errors.

**Acceptance Criteria:**
- WHEN a control packet (id=0xC000) is received THE SYSTEM SHALL parse the control type byte
- WHEN StopStream (0) is received THE SYSTEM SHALL log it and take no further action
- WHEN PauseStream (1) is received THE SYSTEM SHALL log it and take no further action
- WHEN ResumeStream (2) is received THE SYSTEM SHALL log it and take no further action
- THE SYSTEM SHALL NOT send a response to control messages (they are fire-and-forget)

### US-10: Multi-Packet Message Reassembly for PushFile

As a developer testing large file uploads, I want the emulator to correctly reassemble multi-packet PushFile messages so that files larger than ~32KB can be uploaded.

**Acceptance Criteria:**
- WHEN a request packet has the continuation flag set (bit 15 of word 0) THE SYSTEM SHALL buffer the data and wait for more packets with the same transaction ID
- WHEN the final packet (continuation=0) is received THE SYSTEM SHALL concatenate all buffered data and process the complete message
- THE SYSTEM SHALL support messages up to at least 100MB (typical map file size)

### US-11: Improved NNG Deserializer Robustness

As a developer, I want the emulator's NNG deserializer to handle all encoding variants so that both our Java probe and the real NNG SDK can communicate with it.

**Acceptance Criteria:**
- WHEN a string (tag 0x03) is received THE SYSTEM SHALL handle both VLU-length-prefixed and null-terminated encodings
- WHEN an identifier (tag 0x0d) is received THE SYSTEM SHALL handle both VLU-length-prefixed and null-terminated encodings
- WHEN a compact identifier (tag 0x8d) is received THE SYSTEM SHALL handle null-terminated encoding
- WHEN a dict (tag 0xa0, modifier set) is received THE SYSTEM SHALL parse it correctly
- WHEN an unknown tag is encountered THE SYSTEM SHALL skip it gracefully and log a warning
