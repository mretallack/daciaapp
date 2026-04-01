"""Tests for the NFTP head unit emulator."""

import socket
import struct
import threading
import time
import pytest

# Import emulator functions
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from emulator import (
    HEADER_SIZE, MAX_PAYLOAD, CONTROL_ID, FAKE_DEVICE_NNG, FAKE_FILES,
    encode_vlu, read_message, send_response, read_packet,
    write_packet, handle_connection, EmulatorFS,
    serialize_identifier, serialize_string, serialize_tuple, serialize_dict,
    serialize_int_vli, TAG_TUPLE_VLI_LEN, TAG_DICT_VLI_LEN,
    deserialize_value,
)


@pytest.fixture
def server():
    """Start emulator on a random port, yield (host, port), then shut down."""
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    port = srv.getsockname()[1]

    def accept_loop():
        try:
            while True:
                conn, addr = srv.accept()
                handle_connection(conn, addr, verbose=False)
        except OSError:
            pass

    t = threading.Thread(target=accept_loop, daemon=True)
    t.start()
    yield ("127.0.0.1", port)
    srv.close()


def connect(server):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(server)
    return sock


def send_request(sock, pkt_id, body):
    write_packet(sock, False, False, pkt_id, body)


def recv_response(sock):
    return read_message(sock)


def build_init():
    return b"\x00" + encode_vlu(1) + b"NftpProbe\x00"


def build_getfile(name):
    return b"\x03" + name.encode() + b"\x00" + encode_vlu(0) + encode_vlu(0)


def test_init_handshake(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    _, resp = recv_response(sock)
    assert resp[0] == 0  # success
    assert b"FakeHeadUnit" in resp
    sock.close()


def test_getfile_device_nng(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_getfile("license/device.nng"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert b"SWID=CK-DACIA-EMU-0001" in resp
    sock.close()


def test_getfile_unknown(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_getfile("nonexistent.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # failed
    assert b"EACCESS" in resp
    sock.close()


def test_unknown_command(server):
    sock = connect(server)
    send_request(sock, 1, b"\x63")  # type 99
    _, resp = recv_response(sock)
    assert resp[0] == 0x7F
    sock.close()


def test_multiple_requests(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    _, r1 = recv_response(sock)
    assert r1[0] == 0

    send_request(sock, 2, build_getfile("license/device.nng"))
    _, r2 = recv_response(sock)
    assert r2[0] == 0

    send_request(sock, 3, build_getfile("license/device.nng"))
    _, r3 = recv_response(sock)
    assert r3[0] == 0
    sock.close()


def test_large_response(server):
    """device.nng is small, but verify fragmentation works by checking the response is intact."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_getfile("license/device.nng"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    payload = resp[1:]
    assert payload == FAKE_DEVICE_NNG
    sock.close()


def build_checksum(path, method=0):
    return b"\x05" + bytes([method]) + path.encode() + b"\x00" + encode_vlu(0)


def test_checksum_md5(server):
    import hashlib
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_checksum("license/device.nng", 0))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    got_hash = resp[1:]
    assert len(got_hash) == 16
    expected = hashlib.md5(FAKE_DEVICE_NNG).digest()
    assert got_hash == expected
    sock.close()


def test_checksum_sha1(server):
    import hashlib
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_checksum("license/device.nng", 1))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    got_hash = resp[1:]
    assert len(got_hash) == 20
    expected = hashlib.sha1(FAKE_DEVICE_NNG).digest()
    assert got_hash == expected
    sock.close()


def test_checksum_unknown_file(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_checksum("nonexistent.txt", 0))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # failed
    sock.close()


def test_getfile_test_lyc(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_getfile("license/test.lyc"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == b"\x01\x02\x03\x04\x05\x06\x07\x08"
    sock.close()


def build_queryinfo_ls(path, fields=("name", "size")):
    """Build a QueryInfo @ls request: (@ls, path, #{fields: (@name, @size, ...)})"""
    body = b"\x04"  # QueryInfo command
    # Tuple: (@ls, path, #{fields: (...)})
    field_items = b"".join(serialize_identifier(f) for f in fields)
    fields_tuple = bytes([TAG_TUPLE_VLI_LEN]) + encode_vlu(len(fields)) + field_items
    opts = bytes([TAG_DICT_VLI_LEN]) + encode_vlu(1) + serialize_identifier("fields") + fields_tuple
    inner = serialize_identifier("ls") + serialize_string(path) + opts
    body += bytes([TAG_TUPLE_VLI_LEN]) + encode_vlu(3) + inner
    return body


def build_queryinfo_keys(*keys):
    """Build a QueryInfo request for simple keys like @device, @brand."""
    body = b"\x04"
    items = b"".join(serialize_identifier(k) for k in keys)
    body += bytes([TAG_TUPLE_VLI_LEN]) + encode_vlu(len(keys)) + items
    return body


def test_queryinfo_device(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_keys("device"))
    _, resp = recv_response(sock)
    assert resp[0] == 0  # success
    val, _ = deserialize_value(resp, 1)
    assert isinstance(val, dict)
    # Real head unit returns modelName/brandName but failures for swid/vin/igoVersion
    assert val["modelName"] == "DaciaAutomotiveDeviceCY20_ULC4dot5"
    assert val["brandName"] == "DaciaAutomotive"
    # swid/vin/igoVersion are simple failures (tag 25) → deserialized as None
    assert val["swid"] is None
    assert val["vin"] is None
    assert val["igoVersion"] is None
    # appcid is a FailureVLILen (tag 33) → deserialized as dict with message
    assert isinstance(val["appcid"], dict)
    assert val["appcid"]["message"] == "Object has no such property @brand"
    sock.close()


def test_queryinfo_filemapping(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_keys("fileMapping"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    val, _ = deserialize_value(resp, 1)
    assert isinstance(val, dict)
    assert val["device.nng"] == "license/device.nng"
    assert val[".lyc"] == "license/"
    sock.close()


def test_queryinfo_multi_keys(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_keys("device", "brand"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    val, _ = deserialize_value(resp, 1)
    assert isinstance(val, tuple)
    assert len(val) == 2
    # First is device dict, second is brand dict
    assert val[0]["modelName"] == "DaciaAutomotiveDeviceCY20_ULC4dot5"
    assert val[1]["agentBrand"] == "Dacia_ULC"
    sock.close()


def test_ls_content(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_ls("content", ("name", "size")))
    _, resp = recv_response(sock)
    assert resp[0] == 0  # success
    # Parse the response — should be a tuple (name, size, child1, child2, ...)
    val, _ = deserialize_value(resp, 1)
    assert isinstance(val, tuple)
    # First field is name
    assert val[0] == "content"
    # Second field is size (0 for dir)
    assert val[1] == 0
    # Remaining items are children (map, poi, speedcam)
    children = val[2:]
    assert len(children) == 3  # map, poi, speedcam
    # Each child is a tuple too
    child_names = [c[0] for c in children]
    assert "map" in child_names
    assert "poi" in child_names
    assert "speedcam" in child_names
    sock.close()


def test_ls_license(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_ls("license", ("name", "size", "isFile", "mtimeMs")))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    val, _ = deserialize_value(resp, 1)
    assert isinstance(val, tuple)
    assert val[0] == "license"  # name
    # Children are the files in license/
    children = val[4:]  # skip name, size, isFile, mtimeMs
    assert len(children) == 3  # device.nng, nav_eur.lyc, test.lyc
    child_names = [c[0] for c in children]
    assert "device.nng" in child_names
    assert "test.lyc" in child_names
    sock.close()


def test_ls_content_map(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_ls("content/map", ("name", "size")))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    val, _ = deserialize_value(resp, 1)
    assert isinstance(val, tuple)
    assert val[0] == "map"
    children = val[2:]  # skip name, size
    child_names = [c[0] for c in children]
    assert "europe.fbl" in child_names
    assert "test.fbl" in child_names
    sock.close()


def test_ls_nonexistent(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_ls("nonexistent", ("name", "size")))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # failed
    sock.close()


def test_getfile_partial(server):
    """Test GetFile with offset and length (getSmallFile)."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Request first 8 bytes of device.nng
    body = b"\x03" + b"license/device.nng\x00" + encode_vlu(0) + encode_vlu(8)
    send_request(sock, 2, body)
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert len(resp[1:]) == 8
    assert resp[1:] == FAKE_DEVICE_NNG[:8]
    sock.close()


def test_getfile_with_offset(server):
    """Test GetFile with non-zero offset."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Request 5 bytes starting at offset 5
    body = b"\x03" + b"license/device.nng\x00" + encode_vlu(5) + encode_vlu(5)
    send_request(sock, 2, body)
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == FAKE_DEVICE_NNG[5:10]
    sock.close()


# ---------------------------------------------------------------------------
# Helpers for write commands
# ---------------------------------------------------------------------------

def build_pushfile(path, content, options=0, resume_offset=0):
    """Build a PushFile request."""
    body = b"\x01" + path.encode() + b"\x00"
    if options:
        extra = encode_vlu(options)
        if options & 0x02:  # UsePartFile
            extra += encode_vlu(resume_offset)
        body += bytes([len(extra)]) + extra
    else:
        body += b"\x00"  # extra_len = 0
    body += content
    return body


def build_deletefile(path, recursive=0):
    return b"\x06" + path.encode() + b"\x00" + bytes([recursive])


def build_renamefile(src, dst):
    return b"\x07" + src.encode() + b"\x00" + dst.encode() + b"\x00"


def build_linkfile(orig, new_path, hardlink=0):
    return b"\x08" + orig.encode() + b"\x00" + new_path.encode() + b"\x00" + bytes([hardlink])


def build_mkdir(path):
    return b"\x0c" + path.encode() + b"\x00"


def build_chmod(path, mode=0o755):
    return b"\x0d" + path.encode() + b"\x00" + struct.pack("<H", mode)


# ---------------------------------------------------------------------------
# PushFile tests
# ---------------------------------------------------------------------------

def test_pushfile_basic(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push a new file
    send_request(sock, 2, build_pushfile("test/hello.txt", b"hello world"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Verify via GetFile
    send_request(sock, 3, build_getfile("test/hello.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == b"hello world"
    sock.close()


def test_pushfile_truncate(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push initial content
    send_request(sock, 2, build_pushfile("test/trunc.txt", b"original"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Push with truncate
    send_request(sock, 3, build_pushfile("test/trunc.txt", b"new", options=0x01))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Verify
    send_request(sock, 4, build_getfile("test/trunc.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == b"new"
    sock.close()


def test_pushfile_partfile(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push with UsePartFile
    send_request(sock, 2, build_pushfile("test/part.txt", b"partdata", options=0x02))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # .part should have been renamed to final path
    send_request(sock, 3, build_getfile("test/part.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == b"partdata"
    sock.close()


def test_pushfile_only_if_exists(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push with OnlyIfExists to a non-existent file
    send_request(sock, 2, build_pushfile("test/noexist.txt", b"data", options=0x10))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # Failed
    sock.close()


# ---------------------------------------------------------------------------
# DeleteFile tests
# ---------------------------------------------------------------------------

def test_deletefile(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push then delete
    send_request(sock, 2, build_pushfile("test/del.txt", b"delete me"))
    recv_response(sock)
    send_request(sock, 3, build_deletefile("test/del.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Verify gone
    send_request(sock, 4, build_getfile("test/del.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # EACCESS / not found
    sock.close()


def test_deletefile_recursive(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push files into a dir
    send_request(sock, 2, build_pushfile("deldir/a.txt", b"a"))
    recv_response(sock)
    send_request(sock, 3, build_pushfile("deldir/b.txt", b"b"))
    recv_response(sock)
    # Delete recursively
    send_request(sock, 4, build_deletefile("deldir", recursive=1))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Verify both gone
    send_request(sock, 5, build_getfile("deldir/a.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 1
    sock.close()


def test_deletefile_nonexistent(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_deletefile("nonexistent/file.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # Failed
    sock.close()


# ---------------------------------------------------------------------------
# RenameFile tests
# ---------------------------------------------------------------------------

def test_renamefile(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push then rename
    send_request(sock, 2, build_pushfile("test/old.txt", b"rename me"))
    recv_response(sock)
    send_request(sock, 3, build_renamefile("test/old.txt", "test/new.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Old gone
    send_request(sock, 4, build_getfile("test/old.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 1
    # New exists
    send_request(sock, 5, build_getfile("test/new.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == b"rename me"
    sock.close()


def test_renamefile_nonexistent(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_renamefile("no/such/file.txt", "dst.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # Failed
    sock.close()


# ---------------------------------------------------------------------------
# LinkFile tests
# ---------------------------------------------------------------------------

def test_linkfile(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Push then link
    send_request(sock, 2, build_pushfile("test/orig.txt", b"linked"))
    recv_response(sock)
    send_request(sock, 3, build_linkfile("test/orig.txt", "test/link.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Both accessible
    send_request(sock, 4, build_getfile("test/orig.txt"))
    _, resp = recv_response(sock)
    assert resp[1:] == b"linked"
    send_request(sock, 5, build_getfile("test/link.txt"))
    _, resp = recv_response(sock)
    assert resp[1:] == b"linked"
    sock.close()


# ---------------------------------------------------------------------------
# Mkdir tests
# ---------------------------------------------------------------------------

def test_mkdir(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_mkdir("newdir/sub"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # Push a file into it and verify
    send_request(sock, 3, build_pushfile("newdir/sub/f.txt", b"in subdir"))
    recv_response(sock)
    send_request(sock, 4, build_getfile("newdir/sub/f.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == b"in subdir"
    sock.close()


def test_mkdir_exists(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # license/ already exists as a dir
    send_request(sock, 2, build_mkdir("license"))
    _, resp = recv_response(sock)
    assert resp[0] == 0  # OK — already exists
    sock.close()


# ---------------------------------------------------------------------------
# Chmod test
# ---------------------------------------------------------------------------

def test_chmod(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_chmod("license/device.nng"))
    _, resp = recv_response(sock)
    assert resp[0] == 0  # Always OK
    sock.close()


# ---------------------------------------------------------------------------
# PrepareForTransfer / TransferFinished
# ---------------------------------------------------------------------------

def test_prepare_transfer_finished(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # PrepareForTransfer
    send_request(sock, 2, b"\x0a")
    _, resp = recv_response(sock)
    assert resp[0] == 0
    # TransferFinished
    send_request(sock, 3, b"\x0b")
    _, resp = recv_response(sock)
    assert resp[0] == 0
    sock.close()


# ---------------------------------------------------------------------------
# Control message test
# ---------------------------------------------------------------------------

def test_control_message(server):
    """Control messages should not produce a response."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    # Send a control packet (StopStream, stream_id=1)
    ctrl_body = b"\x00" + struct.pack("<H", 1)  # type=0 (StopStream), stream_id=1
    write_packet(sock, False, False, CONTROL_ID, ctrl_body)
    # Send a normal request after — if control ate a response, this would fail
    send_request(sock, 2, build_getfile("license/device.nng"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert b"SWID" in resp
    sock.close()


# ---------------------------------------------------------------------------
# Full update flow test
# ---------------------------------------------------------------------------

def test_full_update_flow(server):
    """Simulate: Init -> Prepare -> Push -> CheckSum -> Rename -> Finished."""
    import hashlib
    sock = connect(server)
    # Init
    send_request(sock, 1, build_init())
    _, resp = recv_response(sock)
    assert resp[0] == 0

    # PrepareForTransfer
    send_request(sock, 2, b"\x0a")
    _, resp = recv_response(sock)
    assert resp[0] == 0

    # PushFile with UsePartFile
    map_data = b"FAKEMAP" * 100
    send_request(sock, 3, build_pushfile("content/map/update.fbl", map_data, options=0x02))
    _, resp = recv_response(sock)
    assert resp[0] == 0

    # CheckSum the file
    send_request(sock, 4, build_checksum("content/map/update.fbl", 0))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    expected_md5 = hashlib.md5(map_data).digest()
    assert resp[1:] == expected_md5

    # TransferFinished
    send_request(sock, 5, b"\x0b")
    _, resp = recv_response(sock)
    assert resp[0] == 0

    # Verify file is accessible
    send_request(sock, 6, build_getfile("content/map/update.fbl"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert resp[1:] == map_data
    sock.close()


# ---------------------------------------------------------------------------
# Failure serialization tests
# ---------------------------------------------------------------------------

def test_serialize_failure_simple():
    """Tag 25 (0x19): simple failure with VLU error code."""
    from emulator import serialize_failure_simple, TAG_FAILURE_SIMPLE, encode_vlu
    data = serialize_failure_simple(3)
    assert data[0] == TAG_FAILURE_SIMPLE
    # Remaining bytes are VLU(3)
    assert data[1:] == encode_vlu(3)
    # Deserialize: tag 25 → None
    val, _ = deserialize_value(data, 0)
    assert val is None


def test_serialize_failure_vli():
    """Tag 33 (0x21): failure with key-value pairs."""
    from emulator import serialize_failure_vli, serialize_string, TAG_FAILURE_VLI_LEN
    data = serialize_failure_vli([
        ("message", serialize_string("Object has no such property @brand")),
    ])
    assert data[0] == TAG_FAILURE_VLI_LEN
    # Deserialize: tag 33 → dict with message
    val, _ = deserialize_value(data, 0)
    assert isinstance(val, dict)
    assert val["message"] == "Object has no such property @brand"


def test_commit(server):
    """Commit (cmd 2) returns success."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    body = b"\x02" + b"content/map/update.fbl\x00"
    send_request(sock, 2, body)
    _, resp = recv_response(sock)
    assert resp[0] == 0
    sock.close()


def test_queryinfo_device_failures(server):
    """QueryInfo @device returns failures for swid/vin/igoVersion matching real head unit."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_keys("device"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    val, _ = deserialize_value(resp, 1)
    # Fields that work
    assert val["modelName"] == "DaciaAutomotiveDeviceCY20_ULC4dot5"
    assert val["firstUse"] == 0
    # Simple failures (tag 25) → None
    for field in ("swid", "vin", "igoVersion", "sku", "imei"):
        assert val[field] is None, f"Expected None for {field}, got {val[field]}"
    # FailureVLILen (tag 33) → dict
    assert isinstance(val["appcid"], dict)
    sock.close()


def test_queryinfo_brand_brandfiles(server):
    """QueryInfo @brand includes brandFiles array matching real head unit."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_queryinfo_keys("brand"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    val, _ = deserialize_value(resp, 1)
    assert val["agentBrand"] == "Dacia_ULC"
    assert val["brandName"] == "DaciaAutomotive"
    # brandFiles is a tuple of dicts
    assert isinstance(val["brandFiles"], tuple)
    assert len(val["brandFiles"]) == 2
    sock.close()


def test_capture_file(tmp_path):
    """Verify --capture writes packet logs."""
    import tempfile
    capture_path = tmp_path / "capture.log"
    capture_f = open(capture_path, "a")

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    port = srv.getsockname()[1]

    def accept_one():
        try:
            conn, addr = srv.accept()
            handle_connection(conn, addr, verbose=False, capture_file=capture_f)
        except OSError:
            pass

    t = threading.Thread(target=accept_one, daemon=True)
    t.start()

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(("127.0.0.1", port))
    send_request(sock, 1, build_init())
    recv_response(sock)
    sock.close()
    t.join(timeout=2)
    srv.close()
    capture_f.close()

    lines = capture_path.read_text().strip().split("\n")
    assert len(lines) >= 2  # at least REQ + RSP
    assert "REQ cmd=0" in lines[0]
    assert "RSP cmd=0" in lines[1]
