# Tasks: Emulator Full NFTP Protocol

## Task 1: Implement EmulatorFS class
- [x] Create `EmulatorFS` class with `files: dict[str, bytes]` and `dirs: set[str]`
- [x] Implement `_populate_defaults()` to seed the initial filesystem from current `FAKE_FS`/`FAKE_FILES`
- [x] Implement `get_file(path, offset, length)`, `put_file(path, data, offset, truncate)`, `delete(path, recursive)`, `rename(src, dst)`, `mkdir(path)`, `link(src, dst)`, `exists()`, `is_file()`, `is_dir()`, `file_size()`, `file_mtime()`
- [x] Implement `list_dir(path)` that builds the nested tree structure needed by `@ls`
- [x] Replace all references to `FAKE_FILES` and `FAKE_FS` globals with an `EmulatorFS` instance passed to handlers
- [x] Update `build_ls_response()` and `build_query_info_response()` to use `EmulatorFS`
- [x] Update `@diskInfo` and `@freeSpace` responses to reflect actual filesystem state

## Task 2: Implement PushFile (cmd 1)
- [x] Parse PushFile body: path (null-terminated), extra_len (u8), options (VLU if extra_len > 0), resume_offset (VLU if UsePartFile), then file content (remaining bytes)
- [x] Implement option flags: TruncateFile (0x01), UsePartFile (0x02), OverwriteOriginal (0x04), TrimToWritten (0x08), OnlyIfExists (0x10)
- [x] Store file via `fs.put_file()`, handle `.part` rename on success
- [x] Return Success (0) or Failed (1)

## Task 3: Implement DeleteFile (cmd 6)
- [x] Parse body: path (null-terminated), recursive flag (u8)
- [x] Call `fs.delete(path, recursive)`, return Success or Failed

## Task 4: Implement RenameFile (cmd 7)
- [x] Parse body: source path (null-terminated), destination path (null-terminated)
- [x] Call `fs.rename(src, dst)`, return Success or Failed

## Task 5: Implement LinkFile (cmd 8)
- [x] Parse body: original path (null-terminated), new path (null-terminated), hardlink flag (u8)
- [x] Call `fs.link(src, dst)`, return Success or Failed

## Task 6: Implement Mkdir (cmd 12)
- [x] Parse body: path (null-terminated)
- [x] Call `fs.mkdir(path)`, return Success or Failed (if path is an existing file)

## Task 7: Implement Chmod (cmd 13)
- [x] Parse body: path (null-terminated), skip remaining bytes
- [x] Return Success (0) unconditionally

## Task 8: Implement control message handling
- [x] Detect control packets (`id_field == 0xC000`) in the connection handler
- [x] Parse control type (u8) and stream_id (u16) from body
- [x] Log in verbose mode, do NOT send a response

## Task 9: Add transfer state tracking
- [x] Add `transfer_active` boolean to connection handler state
- [x] PrepareForTransfer (cmd 10) sets it to True
- [x] TransferFinished (cmd 11) sets it to False
- [x] Log state transitions in verbose mode

## Task 10: Write tests
- [x] Add tests: `test_pushfile_basic`, `test_pushfile_truncate`, `test_pushfile_partfile`, `test_pushfile_only_if_exists`
- [x] Add tests: `test_deletefile`, `test_deletefile_recursive`, `test_deletefile_nonexistent`
- [x] Add tests: `test_renamefile`, `test_renamefile_nonexistent`
- [x] Add tests: `test_linkfile`
- [x] Add tests: `test_mkdir`, `test_mkdir_exists`
- [x] Add tests: `test_chmod`, `test_prepare_transfer_finished`
- [x] Add test: `test_control_message`
- [x] Add test: `test_full_update_flow` (Init → Prepare → Push → CheckSum → Rename → Finished → verify)
- [x] Verify all existing 19 tests still pass
