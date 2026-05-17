#!/usr/bin/env python3
"""Debug: raw dump of HyperHDR WebSocket messages after ledstream-start."""

import json
import socket
import struct
import os
import time
import base64

HYPERHDR_HOST = "localhost"
HYPERHDR_PORT = 8090

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(10)
sock.connect((HYPERHDR_HOST, HYPERHDR_PORT))

key = base64.b64encode(b"hyperhdr-wled-bridge-key").decode()
sock.send((
    f"GET / HTTP/1.1\r\n"
    f"Host: {HYPERHDR_HOST}:{HYPERHDR_PORT}\r\n"
    f"Upgrade: websocket\r\n"
    f"Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    f"Sec-WebSocket-Version: 13\r\n\r\n"
).encode())

resp = b""
while b"\r\n\r\n" not in resp:
    resp += sock.recv(4096)
print("Handshake:", resp.decode(errors="replace").split("\r\n")[0])


def ws_send(sock, msg):
    data = json.dumps(msg).encode()
    length = len(data)
    mask = os.urandom(4)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
    if length <= 125:
        frame = bytes([0x81, 0x80 | length]) + mask + masked
    else:
        frame = bytes([0x81, 0x80 | 126]) + struct.pack(">H", length) + mask + masked
    sock.send(frame)


ws_send(sock, {"command": "ledcolors", "subcommand": "ledstream-start", "tan": 1})
print("Sent ledstream-start, waiting 15s for frames...")

sock.settimeout(3)
start = time.time()
msg_count = 0

while time.time() - start < 15:
    try:
        header = b""
        while len(header) < 2:
            chunk = sock.recv(2 - len(header))
            if not chunk:
                print("Connection closed by server")
                break
            header += chunk
        else:
            opcode = header[0] & 0x0F
            is_masked = bool(header[1] & 0x80)
            payload_len = header[1] & 0x7F

            if payload_len == 126:
                payload_len = struct.unpack(">H", sock.recv(2))[0]
            elif payload_len == 127:
                payload_len = struct.unpack(">Q", sock.recv(8))[0]

            if is_masked:
                mask_key = sock.recv(4)
            else:
                mask_key = None

            data = b""
            while len(data) < payload_len:
                chunk = sock.recv(payload_len - len(data))
                if not chunk:
                    break
                data += chunk

            if mask_key:
                data = bytes(b ^ mask_key[i % 4] for i, b in enumerate(data))

            print(f"Frame #{msg_count}: opcode={opcode} masked={is_masked} len={payload_len}")
            try:
                parsed = json.loads(data.decode())
                keys = list(parsed.keys())
                print(f"  JSON keys: {keys}")
                if "leds" in parsed:
                    leds = parsed["leds"]
                    print(f"  leds count: {len(leds)}, first 3: {leds[:3]}")
                elif "result" in parsed or "command" in parsed:
                    print(f"  content: {str(parsed)[:300]}")
                else:
                    print(f"  content: {str(parsed)[:300]}")
            except Exception as ex:
                print(f"  not JSON ({ex}), raw first 60 bytes: {data[:60]}")

            msg_count += 1
            continue
        break

    except socket.timeout:
        elapsed = time.time() - start
        print(f"[{elapsed:.1f}s] timeout — {msg_count} msgs so far")

sock.close()
print(f"\nDone: {msg_count} messages in {time.time() - start:.1f}s")
