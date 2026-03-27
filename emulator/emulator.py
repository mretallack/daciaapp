#!/usr/bin/env python3
"""MN4 Head Unit Emulator — NFTP server over TCP."""

import argparse
import hashlib
import os
import socket
import struct
import sys
import threading

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

# Fake files served by the emulator
FAKE_FILES = {
    "license/device.nng": FAKE_DEVICE_NNG,
    "license/test.lyc": b"\x01\x02\x03\x04\x05\x06\x07\x08",
    "content/map/test.fbl": b"FAKE-MAP-DATA-" + bytes(range(256)),
}


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


def handle_connection(conn, addr, verbose):
    if verbose:
        print(f"Connection from {addr}")
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
            if cmd == 0:  # Init
                name, _ = parse_null_string(body, 2)  # skip cmd + vlu
                resp = b"\x00" + encode_vlu(1) + b"FakeHeadUnit\x00"
                send_response(conn, pkt_id, resp)
                if verbose:
                    print(f"  Init from '{name}' -> OK")
            elif cmd == 3:  # GetFile
                fname, _ = parse_null_string(body, 1)
                file_data = FAKE_FILES.get(fname)
                if file_data is not None:
                    send_response(conn, pkt_id, b"\x00" + file_data)
                    if verbose:
                        print(f"  GetFile '{fname}' -> {len(file_data)} bytes")
                else:
                    send_response(conn, pkt_id, b"\x01EACCESS")
                    if verbose:
                        print(f"  GetFile '{fname}' -> EACCESS")
            elif cmd == 4:  # QueryInfo
                send_response(conn, pkt_id, b"\x00")
                if verbose:
                    print("  QueryInfo -> OK (empty)")
            elif cmd == 5:  # CheckSum
                method = body[1]
                fname, offset = parse_null_string(body, 2)
                file_data = FAKE_FILES.get(fname)
                if file_data is not None:
                    if method == 0:
                        h = hashlib.md5(file_data).digest()
                    else:
                        h = hashlib.sha1(file_data).digest()
                    send_response(conn, pkt_id, b"\x00" + h)
                    if verbose:
                        mname = "MD5" if method == 0 else "SHA1"
                        print(f"  CheckSum {mname} '{fname}' -> {h.hex()}")
                else:
                    send_response(conn, pkt_id, b"\x01")
                    if verbose:
                        print(f"  CheckSum '{fname}' -> not found")
            else:
                send_response(conn, pkt_id, b"\x7f")
                if verbose:
                    print(f"  Unknown cmd {cmd} -> 0x7F")
    except Exception as e:
        if verbose:
            print(f"  Error: {e}")
    finally:
        conn.close()
        if verbose:
            print(f"Disconnected {addr}")


def main():
    parser = argparse.ArgumentParser(description="MN4 Head Unit Emulator")
    parser.add_argument("--port", type=int, default=9876)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

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
