#!/usr/bin/env python3
"""MN4 Head Unit Emulator — NFTP server over TCP."""

import argparse
import hashlib
import os
import socket
import struct
import sys
import threading
import time

HEADER_SIZE = 4
MAX_PACKET_SIZE = 0x7FFF
MAX_PAYLOAD = MAX_PACKET_SIZE - HEADER_SIZE
CONTROL_ID = 0xC000
MAX_TXN_ID = 0x3FFF

FAKE_DEVICE_NNG = (
    b"SWID=CK-TEST-FAKE-0000\n"
    b"VIN=UU1TESTVIN0000000\n"
    b"IGO=9.12.179.000000\n"
)

# ---------------------------------------------------------------------------
# Fake filesystem — mirrors a real MediaNav 4 head unit layout
# Each entry: (name, size, is_file, mtime_ms)
# Directories have is_file=False, size=0
# ---------------------------------------------------------------------------

_NOW_MS = int(time.time() * 1000)
_DAY_MS = 86400000

FAKE_FS = {
    "license": {
        "device.nng": (len(FAKE_DEVICE_NNG), True, _NOW_MS - 30 * _DAY_MS),
        "test.lyc": (8, True, _NOW_MS - 10 * _DAY_MS),
        "nav_eur.lyc": (1024, True, _NOW_MS - 5 * _DAY_MS),
    },
    "content": {
        "map": {
            "test.fbl": (270, True, _NOW_MS - 20 * _DAY_MS),
            "europe.fbl": (2_500_000_000, True, _NOW_MS - 15 * _DAY_MS),
            "europe.hnr": (150_000_000, True, _NOW_MS - 15 * _DAY_MS),
            "europe.fda": (80_000_000, True, _NOW_MS - 15 * _DAY_MS),
            "europe.ftr": (45_000_000, True, _NOW_MS - 15 * _DAY_MS),
            "europe.fsp": (12_000_000, True, _NOW_MS - 15 * _DAY_MS),
        },
        "poi": {
            "poi_eur.poi": (5_000_000, True, _NOW_MS - 15 * _DAY_MS),
        },
        "speedcam": {
            "speedcam.spc": (2_000_000, True, _NOW_MS - 7 * _DAY_MS),
        },
    },
}

def _build_fake_files():
    """Build FAKE_FILES dict from FAKE_FS, generating content for known files."""
    files = {
        "license/device.nng": FAKE_DEVICE_NNG,
        "license/test.lyc": b"\x01\x02\x03\x04\x05\x06\x07\x08",
        "license/nav_eur.lyc": b"\x4c\x59\x43" + b"\x00" * 1021,  # LYC header
        "content/map/test.fbl": b"FAKE-MAP-DATA-" + bytes(range(256)),
    }
    # Generate stub content for files not explicitly defined
    def walk(tree, prefix=""):
        for name, val in tree.items():
            path = f"{prefix}{name}" if not prefix else f"{prefix}/{name}"
            if isinstance(val, dict):
                walk(val, path)
            else:
                if path not in files:
                    size = val[0]
                    # Generate a small header — real app reads first 4096 bytes
                    files[path] = (name.encode("utf-8") + b"\x00" * 16)[:min(size, 4096)]
    walk(FAKE_FS)
    return files

FAKE_FILES = _build_fake_files()


# ---------------------------------------------------------------------------
# Mutable in-memory filesystem
# ---------------------------------------------------------------------------

class EmulatorFS:
    """Mutable in-memory filesystem for the emulator."""

    def __init__(self):
        self.files = {}       # {path: bytes}
        self.dirs = set()     # set of directory paths
        self._populate_defaults()

    def _populate_defaults(self):
        """Seed from FAKE_FS/FAKE_FILES."""
        for path, data in FAKE_FILES.items():
            self.files[path] = data
            # Register parent dirs
            parts = path.split("/")
            for i in range(1, len(parts)):
                self.dirs.add("/".join(parts[:i]))
        # Register dirs from FAKE_FS tree
        def walk(tree, prefix=""):
            for name, val in tree.items():
                p = f"{prefix}/{name}" if prefix else name
                if isinstance(val, dict):
                    self.dirs.add(p)
                    walk(val, p)
        walk(FAKE_FS)

    def exists(self, path):
        return path in self.files or path in self.dirs

    def is_file(self, path):
        return path in self.files

    def is_dir(self, path):
        return path in self.dirs

    def file_size(self, path):
        return len(self.files[path]) if path in self.files else 0

    def file_mtime(self, path):
        # Check FAKE_FS for original mtime, otherwise return now
        node = self._lookup_fs_node(path)
        if node and not isinstance(node, dict):
            return node[2]
        return int(time.time() * 1000)

    def _lookup_fs_node(self, path):
        """Look up a path in FAKE_FS metadata (for mtime/size of original files)."""
        parts = path.strip("/").split("/")
        node = FAKE_FS
        for part in parts:
            if not isinstance(node, dict) or part not in node:
                return None
            node = node[part]
        return node

    def get_file(self, path, offset=0, length=0):
        if path not in self.files:
            return None
        data = self.files[path]
        if offset > 0:
            data = data[offset:]
        if length > 0:
            data = data[:length]
        return data

    def put_file(self, path, data, offset=0, truncate=False):
        # Ensure parent dirs exist
        parts = path.split("/")
        for i in range(1, len(parts)):
            self.dirs.add("/".join(parts[:i]))
        if truncate or path not in self.files:
            self.files[path] = b""
        existing = self.files[path]
        if offset > 0:
            # Pad if needed
            if offset > len(existing):
                existing = existing + b"\x00" * (offset - len(existing))
            self.files[path] = existing[:offset] + data
        else:
            self.files[path] = data
        return True

    def delete(self, path, recursive=False):
        if path in self.files:
            del self.files[path]
            return True
        if path in self.dirs:
            if recursive:
                prefix = path + "/"
                to_del = [p for p in self.files if p.startswith(prefix)]
                for p in to_del:
                    del self.files[p]
                to_del_dirs = [d for d in self.dirs if d == path or d.startswith(prefix)]
                for d in to_del_dirs:
                    self.dirs.discard(d)
                return True
            # Non-recursive on dir — only if empty
            prefix = path + "/"
            if any(p.startswith(prefix) for p in self.files):
                return False
            self.dirs.discard(path)
            return True
        return False

    def rename(self, src, dst):
        if src in self.files:
            self.files[dst] = self.files.pop(src)
            # Ensure parent dirs of dst
            parts = dst.split("/")
            for i in range(1, len(parts)):
                self.dirs.add("/".join(parts[:i]))
            return True
        return False

    def mkdir(self, path):
        if path in self.files:
            return False  # Can't mkdir over a file
        # Create path and parents
        parts = path.split("/")
        for i in range(1, len(parts) + 1):
            self.dirs.add("/".join(parts[:i]))
        return True

    def link(self, src, dst):
        if src not in self.files:
            return False
        self.files[dst] = self.files[src]
        parts = dst.split("/")
        for i in range(1, len(parts)):
            self.dirs.add("/".join(parts[:i]))
        return True

    def list_dir(self, path):
        """Return dict of {name: entry} for immediate children of path.
        entry is either a nested dict (subdir) or (size, is_file, mtime) tuple."""
        path = path.strip("/")
        if path and path not in self.dirs:
            return None
        prefix = (path + "/") if path else ""
        result = {}
        seen_dirs = set()
        for fpath, data in sorted(self.files.items()):
            if not fpath.startswith(prefix):
                continue
            rest = fpath[len(prefix):]
            if "/" in rest:
                # Child is a subdirectory
                child_dir = rest.split("/")[0]
                if child_dir not in seen_dirs:
                    seen_dirs.add(child_dir)
                    result[child_dir] = self._build_subtree(prefix + child_dir)
            else:
                # Direct child file
                mtime = self.file_mtime(fpath)
                result[rest] = (len(data), True, mtime)
        # Also include empty dirs
        for d in sorted(self.dirs):
            if not d.startswith(prefix):
                continue
            rest = d[len(prefix):]
            if rest and "/" not in rest and rest not in result:
                result[rest] = {}
        return result

    def _build_subtree(self, dir_path):
        """Recursively build a subtree dict for a directory."""
        children = self.list_dir(dir_path)
        return children if children else {}

    def total_size(self):
        return sum(len(d) for d in self.files.values())


# ---------------------------------------------------------------------------
# VLU codec
# ---------------------------------------------------------------------------

def encode_vlu(value):
    out = bytearray()
    while True:
        b = value & 0x7F
        value >>= 7
        if value:
            b |= 0x80
        out.append(b)
        if not value:
            break
    return bytes(out)


def decode_vlu(data, offset=0):
    result = 0
    shift = 0
    while True:
        b = data[offset]
        offset += 1
        result |= (b & 0x7F) << shift
        shift += 7
        if not (b & 0x80):
            break
    return result, offset


def decode_vli(data, offset=0):
    v, offset = decode_vlu(data, offset)
    return (v >> 1) ^ -(v & 1), offset


# ---------------------------------------------------------------------------
# Packet framing
# ---------------------------------------------------------------------------

def read_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("Connection closed")
        buf += chunk
    return buf


def read_packet(sock):
    hdr = read_exact(sock, HEADER_SIZE)
    w0, w1 = struct.unpack("<HH", hdr)
    length = w0 & 0x7FFF
    continuation = bool(w0 & 0x8000)
    if w1 == CONTROL_ID:
        is_response = False
        aborted = False
        pkt_id = CONTROL_ID
    else:
        is_response = bool(w1 & 0x8000)
        aborted = bool(w1 & 0x4000)
        pkt_id = w1 & MAX_TXN_ID
    data_len = length - HEADER_SIZE
    data = read_exact(sock, data_len) if data_len > 0 else b""
    return {
        "continuation": continuation,
        "is_response": is_response,
        "aborted": aborted,
        "id": pkt_id,
        "data": data,
    }


def write_packet(sock, continuation, is_response, pkt_id, data):
    length = HEADER_SIZE + len(data)
    w0 = length & 0x7FFF
    if continuation:
        w0 |= 0x8000
    if pkt_id == CONTROL_ID:
        w1 = CONTROL_ID
    else:
        w1 = pkt_id & MAX_TXN_ID
        if is_response:
            w1 |= 0x8000
    sock.sendall(struct.pack("<HH", w0, w1) + data)


def send_response(sock, pkt_id, body):
    offset = 0
    while offset < len(body):
        chunk = body[offset : offset + MAX_PAYLOAD]
        offset += len(chunk)
        more = offset < len(body)
        write_packet(sock, more, True, pkt_id, chunk)
    if not body:
        write_packet(sock, False, True, pkt_id, b"")


def read_message(sock):
    pkt = read_packet(sock)
    if not pkt["continuation"]:
        return pkt["id"], pkt["data"]
    parts = [pkt["data"]]
    pkt_id = pkt["id"]
    while pkt["continuation"]:
        pkt = read_packet(sock)
        parts.append(pkt["data"])
    return pkt_id, b"".join(parts)


def parse_null_string(data, offset):
    end = data.index(0, offset)
    return data[offset:end].decode("ascii"), end + 1


# ---------------------------------------------------------------------------
# NNG serialization
# ---------------------------------------------------------------------------

TAG_UNDEF = 0
TAG_INT32 = 1
TAG_STRING = 3
TAG_DOUBLE = 5
TAG_ID_STRING = 13
TAG_ID_STRING_COMPACT = 13 | 0x80  # 0x8d
TAG_ID_SYMBOL_VLI = 29
TAG_INT32_VLI = 26
TAG_INT64_VLI = 27
TAG_TUPLE_VLI_LEN = 30
TAG_ARRAY_VLI_LEN = 31
TAG_DICT_VLI_LEN = 32
TAG_BOOL_TRUE = 0x80 | 1   # modifier + int32 tag, used for true
TAG_BOOL_FALSE = 0x80 | 0  # modifier + undef tag, used for false


def serialize_string(s):
    data = s.encode("utf-8")
    return bytes([TAG_STRING]) + encode_vlu(len(data)) + data


def serialize_int(value):
    return bytes([TAG_INT32]) + struct.pack("<i", value & 0xFFFFFFFF)


def serialize_int_vli(value):
    """Serialize as INT32_VLI (zigzag + VLU)."""
    zigzag = (value << 1) ^ (value >> 63)
    return bytes([TAG_INT32_VLI]) + encode_vlu(zigzag)


def serialize_int64_vli(value):
    """Serialize as INT64_VLI for large values."""
    zigzag = (value << 1) ^ (value >> 63)
    return bytes([TAG_INT64_VLI]) + encode_vlu(zigzag)


def serialize_bool(value):
    """Serialize a boolean. true = int 1, false = undef."""
    if value:
        return serialize_int_vli(1)
    return bytes([TAG_UNDEF])


def serialize_identifier(name):
    """Serialize an identifier using NNG compact format: 0x8d + null-terminated string."""
    data = name.encode("utf-8")
    return bytes([TAG_ID_STRING_COMPACT]) + data + b"\x00"


def serialize_dict(items):
    """Serialize a dict/record as TAG_DICT_VLI_LEN."""
    body = b""
    for key, value in items:
        body += serialize_identifier(key)
        body += value
    return bytes([TAG_DICT_VLI_LEN]) + encode_vlu(len(items)) + body


def serialize_tuple(items):
    """Serialize a tuple as TAG_TUPLE_VLI_LEN."""
    body = b"".join(items)
    return bytes([TAG_TUPLE_VLI_LEN]) + encode_vlu(len(items)) + body


# Keep old name as alias
serialize_identifier_string = serialize_identifier


# ---------------------------------------------------------------------------
# NNG deserialization (for parsing QueryInfo request bodies)
# ---------------------------------------------------------------------------

def deserialize_value(data, offset):
    """Deserialize one NNG value from data at offset. Returns (value, new_offset)."""
    if offset >= len(data):
        return None, offset
    raw_tag = data[offset]
    offset += 1
    modifier = bool(raw_tag & 0x80)
    tag = raw_tag & 0x3F

    if tag == TAG_UNDEF:
        return None, offset
    elif tag == TAG_INT32:
        v = struct.unpack_from("<i", data, offset)[0]
        return v, offset + 4
    elif tag == TAG_STRING:
        if modifier:
            end = data.index(0, offset)
            return data[offset:end].decode("utf-8"), end + 1
        # Compact mode may use null-terminated strings even without modifier.
        # Heuristic: if VLU length > remaining data, treat as null-terminated.
        length, new_off = decode_vlu(data, offset)
        if length <= len(data) - new_off:
            try:
                return data[new_off:new_off+length].decode("utf-8"), new_off + length
            except UnicodeDecodeError:
                pass
        # Fall back to null-terminated
        end = data.index(0, offset)
        return data[offset:end].decode("utf-8"), end + 1
    elif tag == TAG_ID_STRING:
        if modifier:
            end = data.index(0, offset)
            return ("@" + data[offset:end].decode("utf-8")), end + 1
        # Without modifier: try VLU-length first, fall back to null-terminated
        length, new_off = decode_vlu(data, offset)
        if length <= len(data) - new_off:
            try:
                return ("@" + data[new_off:new_off+length].decode("utf-8")), new_off + length
            except UnicodeDecodeError:
                pass
        end = data.index(0, offset)
        return ("@" + data[offset:end].decode("utf-8")), end + 1
    elif tag == TAG_INT32_VLI:
        v, offset = decode_vli(data, offset)
        return int(v), offset
    elif tag == TAG_INT64_VLI:
        v, offset = decode_vli(data, offset)
        return int(v), offset
    elif tag == TAG_ID_SYMBOL_VLI:
        v, offset = decode_vli(data, offset)
        return f"@symbol:{v}", offset
    elif tag == TAG_TUPLE_VLI_LEN or tag == TAG_ARRAY_VLI_LEN:
        count, offset = decode_vlu(data, offset)
        items = []
        for _ in range(count):
            val, offset = deserialize_value(data, offset)
            items.append(val)
        return tuple(items), offset
    elif tag == TAG_DICT_VLI_LEN:
        count, offset = decode_vlu(data, offset)
        d = {}
        for _ in range(count):
            key, offset = deserialize_value(data, offset)
            val, offset = deserialize_value(data, offset)
            # Strip @ prefix from identifier keys
            k = key[1:] if isinstance(key, str) and key.startswith("@") else str(key)
            d[k] = val
        return d, offset
    elif tag == TAG_DOUBLE:
        v = struct.unpack_from("<d", data, offset)[0]
        return v, offset + 8
    else:
        # Unknown — return marker and don't advance (best effort)
        return f"[tag=0x{raw_tag:02x}]", offset


def deserialize_query_body(data):
    """Deserialize the full QueryInfo body (after the 0x04 command byte)."""
    val, _ = deserialize_value(data, 0)
    return val


# ---------------------------------------------------------------------------
# @ls directory listing
# ---------------------------------------------------------------------------

def resolve_fs_path(fs, path):
    """Look up a path in the EmulatorFS. Returns the subtree dict or None."""
    return fs.list_dir(path)


def serialize_ls_entry(name, node, fields):
    """
    Serialize a directory entry as a flat tuple matching the requested fields.
    
    The @ls response format (from mapLsEntry in nftp.xs):
      Each entry is a tuple: (field1_val, field2_val, ..., child1, child2, ...)
      Fields are in the order requested. Children (subdirs) follow after fields.
      mapLsEntry zips fields with values, then maps remaining items as @children.
    """
    items = []
    is_dir = isinstance(node, dict)

    for field in fields:
        if field == "name":
            items.append(serialize_string(name))
        elif field == "size":
            if is_dir:
                items.append(serialize_int_vli(0))
            else:
                size = node[0]
                if size > 0x7FFFFFFF:
                    items.append(serialize_int64_vli(size))
                else:
                    items.append(serialize_int_vli(size))
        elif field == "isFile":
            items.append(serialize_bool(not is_dir))
        elif field == "mtimeMs":
            if is_dir:
                items.append(serialize_int64_vli(0))
            else:
                items.append(serialize_int64_vli(node[2]))
        else:
            items.append(bytes([TAG_UNDEF]))

    # Append children for directories
    if is_dir:
        for child_name in sorted(node.keys()):
            child_node = node[child_name]
            items.append(serialize_ls_entry(child_name, child_node, fields))

    return serialize_tuple(items)


def build_ls_response(fs, path, opts, verbose=False):
    """Build the @ls QueryInfo response."""
    # Extract fields from opts
    fields = []
    if isinstance(opts, dict) and "fields" in opts:
        f = opts["fields"]
        if isinstance(f, tuple):
            for item in f:
                if isinstance(item, str) and item.startswith("@"):
                    fields.append(item[1:])
                elif isinstance(item, str):
                    fields.append(item)
        elif isinstance(f, str):
            fields.append(f[1:] if f.startswith("@") else f)
    if not fields:
        fields = ["name", "size"]

    if verbose:
        print(f"    @ls path='{path}' fields={fields}")

    node = resolve_fs_path(fs, path)
    if node is None:
        if verbose:
            print(f"    @ls -> path not found")
        return b"\x01"  # Failed

    if not isinstance(node, dict):
        if verbose:
            print(f"    @ls -> not a directory")
        return b"\x01"  # Failed — not a directory

    # Build the root entry
    dir_name = path.strip("/").split("/")[-1] if path.strip("/") else ""
    result = serialize_ls_entry(dir_name or path, node, fields)

    if verbose:
        print(f"    @ls -> {len(node)} entries, {len(result)} bytes")

    return b"\x00" + result


# ---------------------------------------------------------------------------
# QueryInfo handler
# ---------------------------------------------------------------------------

def build_query_info_response(fs, query_body, verbose=False):
    """Build a QueryInfo response based on the query."""
    parsed = deserialize_query_body(query_body)
    if verbose:
        print(f"    Parsed query: {parsed}")

    # Check if this is an @ls query: tuple starting with @ls
    if isinstance(parsed, tuple) and len(parsed) >= 2:
        first = parsed[0]
        if first == "@ls":
            path = parsed[1] if len(parsed) > 1 else "/"
            opts = parsed[2] if len(parsed) > 2 else {}
            return build_ls_response(fs, path, opts, verbose)

    # Otherwise it's a simple key query — extract keys
    keys = []
    if isinstance(parsed, tuple):
        for item in parsed:
            if isinstance(item, str) and item.startswith("@"):
                keys.append(item[1:])
            elif isinstance(item, str):
                keys.append(item)
    elif isinstance(parsed, str):
        keys.append(parsed[1:] if parsed.startswith("@") else parsed)

    if verbose:
        print(f"    Keys: {keys}")

    results = []
    for key in keys:
        if key in ("diskInfo", "symbol:100001"):
            total = 8 * 1024 * 1024 * 1024
            used = fs.total_size()
            results.append(serialize_dict([
                ("available", serialize_int64_vli(total - used)),
                ("size", serialize_int64_vli(total)),
            ]))
            if verbose:
                print(f"    {key} -> diskInfo")
        elif key in ("freeSpace", "symbol:100000"):
            total = 8 * 1024 * 1024 * 1024
            used = fs.total_size()
            results.append(serialize_int64_vli(total - used))
            if verbose:
                print(f"    {key} -> freeSpace")
        elif key in ("device", "symbol:100002"):
            results.append(serialize_dict([
                ("swid", serialize_string("EMU-TEST-0001")),
                ("vin", serialize_string("VF1TESTEMU000001")),
                ("igoVersion", serialize_string("9.99.999.000000")),
                ("appcid", serialize_string("EMULATOR")),
            ]))
            if verbose:
                print(f"    {key} -> device")
        elif key in ("brand", "symbol:100003"):
            results.append(serialize_dict([
                ("agentBrand", serialize_string("Dacia")),
                ("modelName", serialize_string("Emulator")),
                ("brandName", serialize_string("TestBrand")),
            ]))
            if verbose:
                print(f"    {key} -> brand")
        elif key in ("fileMapping", "symbol:100004"):
            results.append(serialize_dict([
                ("device.nng", serialize_string("license/device.nng")),
                (".lyc", serialize_string("license/")),
                (".fbl", serialize_string("content/map/")),
                (".hnr", serialize_string("content/map/")),
                (".fda", serialize_string("content/map/")),
                (".ftr", serialize_string("content/map/")),
                (".fsp", serialize_string("content/map/")),
                (".poi", serialize_string("content/poi/")),
                (".spc", serialize_string("content/speedcam/")),
            ]))
            if verbose:
                print(f"    {key} -> fileMapping")
        else:
            results.append(bytes([TAG_UNDEF]))
            if verbose:
                print(f"    {key} -> undef")

    if len(results) == 1:
        return b"\x00" + results[0]
    return b"\x00" + serialize_tuple(results)


# ---------------------------------------------------------------------------
# Connection handler
# ---------------------------------------------------------------------------

def handle_connection(conn, addr, verbose):
    if verbose:
        print(f"Connection from {addr}")
    fs = EmulatorFS()
    transfer_active = False
    try:
        while True:
            try:
                pkt_id, body = read_message(conn)
            except ConnectionError:
                break
            if not body:
                break
            cmd = body[0]
            if verbose:
                print(f"  cmd={cmd} id={pkt_id} len={len(body)}")

            # Control messages — no response
            if pkt_id == CONTROL_ID:
                ctrl_type = body[0] if len(body) > 0 else -1
                stream_id = struct.unpack_from("<H", body, 1)[0] if len(body) >= 3 else 0
                ctrl_names = {0: "StopStream", 1: "PauseStream", 2: "ResumeStream"}
                if verbose:
                    print(f"  Control: {ctrl_names.get(ctrl_type, f'unknown({ctrl_type})')} stream={stream_id}")
                continue

            if cmd == 0:  # Init
                name, _ = parse_null_string(body, 2)  # skip cmd + vlu
                resp = b"\x00" + encode_vlu(1) + b"FakeHeadUnit/1.0\x00"
                send_response(conn, pkt_id, resp)
                if verbose:
                    print(f"  Init from '{name}' -> OK")

            elif cmd == 3:  # GetFile
                fname, off = parse_null_string(body, 1)
                # Parse position and length
                position, off = decode_vlu(body, off)
                file_len = 0
                if off < len(body):
                    file_len, off = decode_vlu(body, off)
                file_data = fs.get_file(fname, position, file_len)
                if file_data is not None:
                    send_response(conn, pkt_id, b"\x00" + file_data)
                    if verbose:
                        print(f"  GetFile '{fname}' pos={position} len={file_len} -> {len(file_data)} bytes")
                else:
                    send_response(conn, pkt_id, b"\x01EACCESS")
                    if verbose:
                        print(f"  GetFile '{fname}' -> EACCESS")

            elif cmd == 4:  # QueryInfo
                if verbose:
                    print(f"  QueryInfo body: {body[1:].hex()}")
                resp = build_query_info_response(fs, body[1:], verbose)
                send_response(conn, pkt_id, resp)

            elif cmd == 5:  # CheckSum
                method = body[1]
                fname, offset = parse_null_string(body, 2)
                file_data = fs.get_file(fname)
                if file_data is not None:
                    h = hashlib.md5(file_data).digest() if method == 0 else hashlib.sha1(file_data).digest()
                    send_response(conn, pkt_id, b"\x00" + h)
                    if verbose:
                        mname = "MD5" if method == 0 else "SHA1"
                        print(f"  CheckSum {mname} '{fname}' -> {h.hex()}")
                else:
                    send_response(conn, pkt_id, b"\x01")
                    if verbose:
                        print(f"  CheckSum '{fname}' -> not found")

            elif cmd == 1:  # PushFile
                fname, off = parse_null_string(body, 1)
                extra_len = body[off] if off < len(body) else 0
                off += 1
                options = 0
                resume_offset = 0
                if extra_len > 0:
                    options, off = decode_vlu(body, off)
                    if options & 0x02:  # UsePartFile
                        resume_offset, off = decode_vlu(body, off)
                content = body[off:]
                truncate = bool(options & 0x01)
                use_part = bool(options & 0x02)
                only_if_exists = bool(options & 0x10)
                target = fname + ".part" if use_part else fname
                if only_if_exists and not fs.is_file(fname):
                    send_response(conn, pkt_id, b"\x01")
                    if verbose:
                        print(f"  PushFile '{fname}' -> Failed (OnlyIfExists)")
                else:
                    fs.put_file(target, content, offset=resume_offset, truncate=truncate)
                    if use_part:
                        fs.rename(target, fname)
                    if options & 0x08:  # TrimToWritten
                        pass  # already exact size from put_file
                    send_response(conn, pkt_id, b"\x00")
                    if verbose:
                        print(f"  PushFile '{fname}' opts=0x{options:02x} -> OK ({len(content)} bytes)")

            elif cmd == 6:  # DeleteFile
                fname, off = parse_null_string(body, 1)
                recursive = body[off] if off < len(body) else 0
                if fs.delete(fname, recursive=bool(recursive)):
                    send_response(conn, pkt_id, b"\x00")
                    if verbose:
                        print(f"  DeleteFile '{fname}' recursive={recursive} -> OK")
                else:
                    send_response(conn, pkt_id, b"\x01")
                    if verbose:
                        print(f"  DeleteFile '{fname}' -> Failed")

            elif cmd == 7:  # RenameFile
                src, off = parse_null_string(body, 1)
                dst, off = parse_null_string(body, off)
                if fs.rename(src, dst):
                    send_response(conn, pkt_id, b"\x00")
                    if verbose:
                        print(f"  RenameFile '{src}' -> '{dst}' OK")
                else:
                    send_response(conn, pkt_id, b"\x01")
                    if verbose:
                        print(f"  RenameFile '{src}' -> Failed")

            elif cmd == 8:  # LinkFile
                orig, off = parse_null_string(body, 1)
                new_path, off = parse_null_string(body, off)
                # hardlink flag at off, ignored — we just copy
                if fs.link(orig, new_path):
                    send_response(conn, pkt_id, b"\x00")
                    if verbose:
                        print(f"  LinkFile '{orig}' -> '{new_path}' OK")
                else:
                    send_response(conn, pkt_id, b"\x01")
                    if verbose:
                        print(f"  LinkFile '{orig}' -> Failed")

            elif cmd == 10:  # PrepareForTransfer
                transfer_active = True
                send_response(conn, pkt_id, b"\x00")
                if verbose:
                    print(f"  PrepareForTransfer -> OK (transfer_active=True)")

            elif cmd == 11:  # TransferFinished
                transfer_active = False
                send_response(conn, pkt_id, b"\x00")
                if verbose:
                    print(f"  TransferFinished -> OK (transfer_active=False)")

            elif cmd == 12:  # Mkdir
                dname, off = parse_null_string(body, 1)
                if fs.mkdir(dname):
                    send_response(conn, pkt_id, b"\x00")
                    if verbose:
                        print(f"  Mkdir '{dname}' -> OK")
                else:
                    send_response(conn, pkt_id, b"\x01")
                    if verbose:
                        print(f"  Mkdir '{dname}' -> Failed")

            elif cmd == 13:  # Chmod
                cname, off = parse_null_string(body, 1)
                send_response(conn, pkt_id, b"\x00")
                if verbose:
                    print(f"  Chmod '{cname}' -> OK")

            else:
                send_response(conn, pkt_id, b"\x7f")
                if verbose:
                    print(f"  Unknown cmd {cmd} -> 0x7F")

    except Exception as e:
        if verbose:
            import traceback
            traceback.print_exc()
            print(f"  Error: {e}")
    finally:
        conn.close()
        if verbose:
            print(f"Disconnected {addr}")


def main():
    parser = argparse.ArgumentParser(description="MN4 Head Unit Emulator")
    parser.add_argument("--port", type=int, default=9876)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--daemon", action="store_true", help="Fork into background")
    parser.add_argument("--pidfile", type=str, help="Write PID to file (implies --daemon)")
    args = parser.parse_args()

    if args.pidfile:
        args.daemon = True

    if args.daemon:
        # Re-launch ourselves without --daemon, fully detached
        import subprocess
        cmd = [sys.executable, os.path.abspath(__file__),
               "--port", str(args.port)]
        if args.verbose:
            cmd.append("--verbose")
        devnull = open(os.devnull, "r+b")
        proc = subprocess.Popen(cmd, stdin=devnull, stdout=devnull,
                                stderr=devnull, start_new_session=True)
        devnull.close()
        if args.pidfile:
            with open(args.pidfile, "w") as f:
                f.write(str(proc.pid))
        print(f"Daemonised, PID: {proc.pid}")
        sys.exit(0)

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", args.port))
    srv.listen(1)
    print(f"Listening on port {args.port}")
    try:
        while True:
            conn, addr = srv.accept()
            t = threading.Thread(target=handle_connection, args=(conn, addr, args.verbose), daemon=True)
            t.start()
    except KeyboardInterrupt:
        print("\nShutting down")
    finally:
        srv.close()


if __name__ == "__main__":
    main()
