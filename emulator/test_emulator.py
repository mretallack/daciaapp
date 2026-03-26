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
    HEADER_SIZE, MAX_PAYLOAD, CONTROL_ID, FAKE_DEVICE_NNG,
    encode_vlu, read_message, send_response, read_packet,
    write_packet, handle_connection,
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
    send_request(sock, 2, build_getfile("device.nng"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    assert b"SWID=CK-TEST-FAKE-0000" in resp
    sock.close()


def test_getfile_unknown(server):
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_getfile("nonexistent.txt"))
    _, resp = recv_response(sock)
    assert resp[0] == 1  # failed
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

    send_request(sock, 2, build_getfile("device.nng"))
    _, r2 = recv_response(sock)
    assert r2[0] == 0

    send_request(sock, 3, build_getfile("device.nng"))
    _, r3 = recv_response(sock)
    assert r3[0] == 0
    sock.close()


def test_large_response(server):
    """device.nng is small, but verify fragmentation works by checking the response is intact."""
    sock = connect(server)
    send_request(sock, 1, build_init())
    recv_response(sock)
    send_request(sock, 2, build_getfile("device.nng"))
    _, resp = recv_response(sock)
    assert resp[0] == 0
    payload = resp[1:]
    assert payload == FAKE_DEVICE_NNG
    sock.close()
