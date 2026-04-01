# Design: Emulator Full NFTP Protocol

## Architecture Overview

The emulator is a single-file Python TCP server (`emulator/emulator.py`) with an accompanying test file (`emulator/test_emulator.py`). The design adds a mutable filesystem layer and implements all missing NFTP commands while keeping the single-file structure.

## Component Diagram

```
┌─────────────────────────────────────────────────┐
│                  emulator.py                     │
│                                                  │
│  ┌──────────────┐   ┌────────────────────────┐  │
│  │ TCP Server    │──▶│ Connection Handler      │  │
│  │ (accept loop) │   │ (per-client thread)     │  │
│  └──────────────┘   └────────┬───────────────┘  │
│                              │                   │
│                    ┌─────────▼─────────┐         │
│                    │ Command Dispatcher │         │
│                    │ cmd 0..14          │         │
│                    └─────────┬─────────┘         │
│                              │                   ��
│         ┌────────────────────┼──────────┐        │
│         ▼                    ▼          ▼        │
│  ┌─────────────┐  ┌──────────────┐ ┌────────┐   │
│  │FS Operations│  │ QueryInfo    │ │Serialize│   │
│  │Push/Get/Del │  │@ls/@device/..│ │Deserial.│   │
│  │Rename/Mkdir │  └──────┬───────┘ └────────┘   │
│  └──────┬──────┘         │                       │
│         │                │                       │
│         ▼                ▼                       │
│  ┌─────────────────────────────┐                 │
│  │     EmulatorFS (mutable)    │                 │
│  │  tree: nested dict          │                 │
│  │  files: {path: bytes}       │                 │
│  └─────────────────────────────┘                 │
└─────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. EmulatorFS Class

Replace the current `FAKE_FS` dict and `FAKE_FILES` dict with a single `EmulatorFS` class that manages both the directory tree and file contents.

```python
class EmulatorFS:
    """Mutable in-memory filesystem for the emulator."""
    
    def __init__(self):
        self.files = {}      # {path: bytes} — file contents
        self.dirs = set()    # set of directory paths
        self._populate_defaults()
    
    def get_file(self, path, offset=0, length=0) -> bytes | None
    def put_file(self, path, data, offset=0, truncate=False) -> bool
    def delete(self, path, recursive=False) -> bool
    def rename(self, src, dst) -> bool
    def mkdir(self, path) -> bool
    def link(self, src, dst) -> bool
    def list_dir(self, path) -> dict | None  # returns tree for @ls
    def exists(self, path) -> bool
    def is_file(self, path) -> bool
    def is_dir(self, path) -> bool
    def file_size(self, path) -> int
    def file_mtime(self, path) -> int
```

The tree structure for `@ls` is derived dynamically from `self.files` and `self.dirs` rather than maintained as a separate nested dict. This avoids sync issues.

### 2. PushFile Implementation

PushFile wire format (from nftp.md and updater.xs):
```
[0x01]                    — command type
[string\0]                — destination path
[u8: extra_len]           — length of additional options data
[extra_len bytes]:
  [vlu: options_bitmask]  — PushOptions flags
  [vlu: resume_offset]    — only if UsePartFile, byte offset to resume from
[remaining bytes]         — file content
```

The handler:
1. Parse path, extra_len, options, and content from the message body
2. Determine the actual write path (append `.part` if UsePartFile)
3. Apply truncate/append/resume semantics
4. Store in EmulatorFS
5. If UsePartFile, rename `.part` → final path on success
6. Return Success (0) or Failed (1)

### 3. DeleteFile Implementation

Wire format:
```
[0x06]           — command type
[string\0]       — path
[u8: recursive]  — 0 or 1
```

Handler: call `fs.delete(path, recursive=bool(flag))`.

### 4. RenameFile Implementation

Wire format (from updater.xs: `writeFsReq(Message.RenameFile, destPath, w=>w.string(originalDestPath))`):
```
[0x07]           — command type
[string\0]       — source path (the file to rename)
[string\0]       — destination path
```

Handler: call `fs.rename(src, dst)`.

### 5. LinkFile Implementation

Wire format:
```
[0x08]           — command type
[string\0]       — original path
[string\0]       — new path
[u8: hardlink]   — 0=symlink (default), 1=hardlink
```

Handler: copy the file content from original to new path (emulating a link in an in-memory FS).

### 6. Mkdir Implementation

Wire format (via `requestFsOperation`):
```
[0x0c]           — command type
[string\0]       — path
```

Handler: call `fs.mkdir(path)`, creating parent dirs as needed.

### 7. Chmod Implementation

Wire format:
```
[0x0d]           — command type
[string\0]       — path
[additional data] — mode (ignored)
```

Handler: return Success (0). No permission tracking.

### 8. Control Messages

Control packets have `id_field == 0xC000`. The body is:
```
[u8: ctrl_type]  — 0=StopStream, 1=PauseStream, 2=ResumeStream
[u16: stream_id] — identifies the stream
```

Handler: log the control type and stream ID. Do not send a response.

### 9. Transfer State

Add a `transfer_active` boolean to the connection handler. PrepareForTransfer sets it, TransferFinished clears it. Logged in verbose mode.

### 10. Multi-Packet Reassembly

The existing `read_message()` already handles multi-packet reassembly via the continuation flag. PushFile messages with large file content will be split across multiple packets by the sender, and `read_message()` concatenates them. No changes needed for reassembly itself.

However, PushFile with streaming (the sender uses `sendWithFile`) may send the header and file content as separate logical writes on the same transaction. The current `read_message()` handles this correctly since it reads until `continuation=0`.

### 11. @ls Integration with Mutable FS

The `build_ls_response()` function currently reads from the static `FAKE_FS` dict. It will be updated to call `fs.list_dir(path)` which dynamically builds the tree from `fs.files` and `fs.dirs`.

### 12. Deserializer Robustness

The deserializer already handles both VLU-length and null-terminated strings via a heuristic fallback. The design formalises this:

- For tag 0x03 (STRING): try VLU-length first. If the decoded length exceeds remaining data or produces invalid UTF-8, fall back to null-terminated.
- For tag 0x0d (ID_STRING): same heuristic.
- For tag 0x8d (ID_STRING | MODIFIER): always null-terminated.
- For tag 0xa0 (DICT | MODIFIER): parse as dict with VLU count (same as 0x20 but modifier is informational).
- Unknown tags: log warning, return marker string, don't advance offset.

## Sequence Diagram: Map Update Flow

```
Phone (YellowBox)              Emulator
      │                            │
      │──── Init ─────────────────▶│
      │◀─── Init OK ──────────────│
      │                            │
      │──── QueryInfo @fileMapping▶│
      │◀─── {mapping dict} ───────│
      │                            │
      │──── QueryInfo @device ────▶│
      │◀─── {device dict} ────────│
      │                            │
      │──── GetFile device.nng ───▶│
      │◀─── [268 bytes] ──────────│
      │                            │
      │──── PrepareForTransfer ───▶│  ← transfer_active = true
      │◀─── OK ───────────────────│
      │                            │
      │──── PushFile europe.fbl ──▶│  ← multi-packet, UsePartFile
      │     (streaming, ~2.5GB)    │     writes to europe.fbl.part
      │◀─── OK ───────────────────│
      │                            │
      │──── CheckSum europe.fbl.part▶│
      │◀─── [MD5 hash] ───────────│
      │                            │
      │──── RenameFile ───────────▶│  ← europe.fbl.part → europe.fbl
      │◀─── OK ───────────────────│
      │                            │
      │──── TransferFinished ─────▶│  ← transfer_active = false
      │◀─── OK ───────────────────│
      │                            │
      │──── QueryInfo @diskInfo ──▶│
      │◀─── {available, size} ────│
```

## Error Handling

- All file operations return Response.Failed (1) if the target doesn't exist (unless creating)
- PushFile with OnlyIfExists returns Failed if file doesn't exist
- DeleteFile on non-existent path returns Failed
- RenameFile with non-existent source returns Failed
- Unknown commands return Response.Unknown (0x7F)
- Malformed packets close the connection gracefully

## Testing Strategy

Each new command gets at least one test in `test_emulator.py`:
- `test_pushfile_basic` — push a file, verify via GetFile
- `test_pushfile_truncate` — push with TruncateFile flag
- `test_pushfile_partfile` — push with UsePartFile, verify .part then final
- `test_pushfile_only_if_exists` — push to non-existent path with OnlyIfExists
- `test_deletefile` — delete a file, verify gone from GetFile and @ls
- `test_deletefile_recursive` — delete a directory recursively
- `test_deletefile_nonexistent` — delete non-existent returns Failed
- `test_renamefile` — rename, verify old gone and new accessible
- `test_renamefile_nonexistent` — rename non-existent returns Failed
- `test_linkfile` — link, verify both paths accessible
- `test_mkdir` — create dir, verify in @ls
- `test_mkdir_exists` — mkdir on existing dir returns Success
- `test_chmod` — always returns Success
- `test_prepare_transfer_finished` — both return Success
- `test_control_message` — send control packet, verify no response
- `test_full_update_flow` — Init → PrepareForTransfer → PushFile → CheckSum → RenameFile → TransferFinished → verify file
