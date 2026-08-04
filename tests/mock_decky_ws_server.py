#!/usr/bin/env python3
"""Local mock Decky Loader WebSocket endpoint used only by tests."""

import base64
import hashlib
import json
import re
import socket
import sys
import threading


GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def read_until(conn: socket.socket, marker: bytes) -> bytes:
    data = b""
    while marker not in data:
        chunk = conn.recv(4096)
        if not chunk:
            raise EOFError("client closed during handshake")
        data += chunk
    return data


def recv_exact(conn: socket.socket, size: int) -> bytes:
    data = b""
    while len(data) < size:
        chunk = conn.recv(size - len(data))
        if not chunk:
            raise EOFError("client closed mid-frame")
        data += chunk
    return data


def recv_frame(conn: socket.socket) -> tuple[int, bytes]:
    first = recv_exact(conn, 2)
    opcode = first[0] & 0x0F
    masked = bool(first[1] & 0x80)
    length = first[1] & 0x7F
    if length == 126:
        length = int.from_bytes(recv_exact(conn, 2), "big")
    elif length == 127:
        length = int.from_bytes(recv_exact(conn, 8), "big")
    mask = recv_exact(conn, 4) if masked else b""
    payload = recv_exact(conn, length)
    if masked:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return opcode, payload


def send_frame(conn: socket.socket, payload: bytes) -> None:
    length = len(payload)
    if length < 126:
        header = bytes([0x81, length])
    elif length < 65536:
        header = bytes([0x81, 126]) + length.to_bytes(2, "big")
    else:
        header = bytes([0x81, 127]) + length.to_bytes(8, "big")
    conn.sendall(header + payload)


def handle_connection(conn: socket.socket) -> None:
    try:
        request = read_until(conn, b"\r\n\r\n")
        key = ""
        for line in request.split(b"\r\n"):
            if line.lower().startswith(b"sec-websocket-key:"):
                key = line.split(b":", 1)[1].strip().decode("ascii")
        if not key:
            conn.close()
            return
        accept = base64.b64encode(
            hashlib.sha1((key + GUID).encode("ascii")).digest()
        ).decode("ascii")
        conn.sendall(
            (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                "Sec-WebSocket-Accept: " + accept + "\r\n\r\n"
            ).encode("ascii")
        )
        opcode, payload = recv_frame(conn)
        if opcode != 1:
            conn.close()
            return
        message = json.loads(payload.decode("utf-8"))
        code = message["args"][2]
        match = re.search(r'const m="([^"]+)"', code)
        marker = match.group(1) if match else "unknown-marker"
        reply = json.dumps(
            {
                "type": 1,
                "id": message["id"],
                "result": {"success": True, "result": marker + ":ok:1"},
            },
            separators=(",", ":"),
        )
        send_frame(conn, reply.encode("utf-8"))
        try:
            recv_frame(conn)  # consume RECEIVED_RESPONSE
        except EOFError:
            pass
    except Exception:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: mock_decky_ws_server.py <port-file>", file=sys.stderr)
        return 1
    port_file = sys.argv[1]
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 0))
    server.listen(16)
    with open(port_file, "w", encoding="ascii") as handle:
        handle.write(str(server.getsockname()[1]))
    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle_connection, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    raise SystemExit(main())
