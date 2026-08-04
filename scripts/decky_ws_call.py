#!/usr/bin/env python3
"""Call a Decky Loader method over its local WebSocket API.

Decky v3 removed the HTTP /methods/<name> endpoint, so execute_in_tab is now
served on ws://127.0.0.1:1337/ws with the same call-reply protocol used by
the Decky frontend. This client uses only the Python standard library.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import socket
import sys
import time
import urllib.parse


CALL_TYPE = 0
REPLY_TYPE = 1
ERROR_TYPE = -1
DISCARD_TYPE = 2
RECEIVED_RESPONSE_TYPE = 3


class WsError(RuntimeError):
    pass


class SocketReader:
    def __init__(self, conn: socket.socket) -> None:
        self.conn = conn
        self.buffer = bytearray()

    def read(self, size: int) -> bytes:
        while len(self.buffer) < size:
            chunk = self.conn.recv(65536)
            if not chunk:
                raise WsError("Decky closed the WebSocket connection early")
            self.buffer.extend(chunk)
        result = bytes(self.buffer[:size])
        del self.buffer[:size]
        return result

    def read_until(self, marker: bytes, limit: int) -> bytes:
        while marker not in self.buffer:
            if len(self.buffer) > limit:
                raise WsError("Decky WebSocket handshake headers too large")
            chunk = self.conn.recv(65536)
            if not chunk:
                raise WsError("Decky closed the WebSocket during handshake")
            self.buffer.extend(chunk)
        end = self.buffer.index(marker) + len(marker)
        result = bytes(self.buffer[:end])
        del self.buffer[:end]
        return result


def send_frame(conn: socket.socket, payload: bytes, opcode: int = 1) -> None:
    mask = os.urandom(4)
    length = len(payload)
    header = bytearray([0x80 | opcode])
    if length < 126:
        header.append(0x80 | length)
    elif length < 65536:
        header.append(0x80 | 126)
        header.extend(length.to_bytes(2, "big"))
    else:
        header.append(0x80 | 127)
        header.extend(length.to_bytes(8, "big"))
    header.extend(mask)
    masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    conn.sendall(bytes(header) + masked)


def recv_frame(reader: SocketReader) -> tuple[bool, int, bytes]:
    first = reader.read(2)
    fin = bool(first[0] & 0x80)
    opcode = first[0] & 0x0F
    masked = bool(first[1] & 0x80)
    length = first[1] & 0x7F
    if length == 126:
        length = int.from_bytes(reader.read(2), "big")
    elif length == 127:
        length = int.from_bytes(reader.read(8), "big")
    mask = reader.read(4) if masked else b""
    payload = reader.read(length)
    if masked:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return fin, opcode, payload


def ws_connect(base_url: str, token: str, timeout: float) -> tuple[socket.socket, SocketReader]:
    parsed = urllib.parse.urlparse(base_url)
    if parsed.scheme not in ("http", "https"):
        raise WsError("Decky API base URL must use http or https")
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (443 if parsed.scheme == "https" else 1337)
    conn = socket.create_connection((host, port), timeout=timeout)
    conn.settimeout(timeout)
    key = base64.b64encode(os.urandom(16)).decode("ascii")
    query = urllib.parse.urlencode({"auth": token})
    host_header = host if parsed.port is None else f"{host}:{port}"
    request = (
        f"GET /ws?{query} HTTP/1.1\r\n"
        f"Host: {host_header}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n"
    )
    conn.sendall(request.encode("ascii"))
    reader = SocketReader(conn)
    headers = reader.read_until(b"\r\n\r\n", 65536)
    status = headers.split(b"\r\n", 1)[0]
    if b" 101 " not in status:
        conn.close()
        raise WsError("Decky WebSocket handshake rejected: " + status.decode("ascii", "replace"))
    return conn, reader


def call_execute_in_tab(
    base_url: str, token: str, payload: dict[str, object], timeout: float
) -> object:
    conn, reader = ws_connect(base_url, token, timeout)
    call_id = 1
    message = json.dumps(
        {
            "type": CALL_TYPE,
            "route": "utilities/execute_in_tab",
            "args": [
                payload["tab"],
                bool(payload.get("run_async", False)),
                payload["code"],
            ],
            "id": call_id,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    try:
        send_frame(conn, message)
        deadline = time.monotonic() + timeout
        fragment = bytearray()
        in_text = False
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise WsError("Decky did not answer execute_in_tab within timeout")
            conn.settimeout(remaining)
            fin, opcode, frame = recv_frame(reader)
            if opcode == 8:
                raise WsError("Decky closed the WebSocket before replying")
            if opcode == 9:
                send_frame(conn, frame, opcode=10)
                continue
            if opcode == 10:
                continue
            if opcode == 1:
                fragment = bytearray(frame)
                in_text = True
            elif opcode == 0 and in_text:
                fragment.extend(frame)
            else:
                continue
            if not fin or not in_text:
                continue
            data = json.loads(bytes(fragment).decode("utf-8"))
            if data.get("id") != call_id:
                continue
            msg_type = data.get("type")
            if msg_type == ERROR_TYPE:
                error = data.get("error") or {}
                detail = error.get("error") if isinstance(error, dict) else error
                raise WsError("Decky execute_in_tab error: " + str(detail))
            if msg_type == DISCARD_TYPE:
                raise WsError("Decky discarded the execute_in_tab call")
            if msg_type == REPLY_TYPE:
                result = data.get("result")
                send_frame(
                    conn,
                    json.dumps({"type": RECEIVED_RESPONSE_TYPE, "id": call_id}).encode("ascii"),
                )
                return result
    finally:
        conn.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--token", required=True)
    parser.add_argument("--payload-file", required=True)
    parser.add_argument("--base-url", default="http://127.0.0.1:1337")
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()
    if not args.token:
        parser.error("--token is required")
    try:
        with open(args.payload_file, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except (OSError, ValueError) as error:
        print(f"decky_ws_call.py: cannot read payload: {error}", file=sys.stderr)
        return 1
    if (
        not isinstance(payload, dict)
        or not isinstance(payload.get("tab"), str)
        or not isinstance(payload.get("code"), str)
    ):
        print("decky_ws_call.py: payload must contain tab and code strings", file=sys.stderr)
        return 1
    try:
        result = call_execute_in_tab(args.base_url, args.token, payload, args.timeout)
    except WsError as error:
        print(f"decky_ws_call.py: {error}", file=sys.stderr)
        return 1
    if result is None:
        return 1
    if isinstance(result, dict):
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
        return 0 if result.get("success") is not False else 1
    print(str(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
