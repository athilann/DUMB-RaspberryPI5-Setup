#!/usr/bin/env python3
"""Bridge: HyperHDR LED colors → WLED via DDP (per-LED, UDP port 4048)."""

import json
import socket
import struct
import os
import base64
import time
import sys

HYPERHDR_HOST = "localhost"
HYPERHDR_PORT = 8090
WLED_HOST = "192.168.50.157"
WLED_DDP_PORT = 4048
NUM_LEDS = 534

# LED layout — 534 LEDs, counterclockwise from front, starting at bottom-center going left:
#   Physical WLED:    0–81   bottom-left (center→left corner)
#                    82–178  left side (bottom→top)
#                   179–348  top (left→right)
#                   349–443  right side (top→bottom)
#                   444–533  bottom-right (right corner→center)
#
# HyperHDR Classic layout (position=3, clockwise from top-left):
#   H   0–169  top (left→right)
#   H 170–264  right (top→bottom)
#   H 265–436  bottom (right→left)
#   H 437–533  left (bottom→top)
#
# Mapping: physical P → HyperHDR H
#   P   0–178  →  H = P + 355  (bottom-left and left side)
#   P 179–533  →  H = P - 179  (top, right, bottom-right)
LED_MAP = [p + 355 if p < 179 else p - 179 for p in range(NUM_LEDS)]

# Pre-built DDP header: push flag | v1, reserved, type=RGB8, id=default, offset=0, length
_DDP_HEADER = struct.pack(">BBBBIH", 0x41, 0x00, 0x01, 0x01, 0, NUM_LEDS * 3)


def build_ddp_packet(flat):
    data = bytearray(NUM_LEDS * 3)
    for p in range(NUM_LEDS):
        src = LED_MAP[p] * 3
        dst = p * 3
        data[dst]     = flat[src]
        data[dst + 1] = flat[src + 1]
        data[dst + 2] = flat[src + 2]
    return _DDP_HEADER + bytes(data)


def ws_handshake(sock):
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


def ws_send(sock, msg):
    data = json.dumps(msg).encode()
    n = len(data)
    mask = os.urandom(4)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
    if n <= 125:
        frame = bytes([0x81, 0x80 | n]) + mask + masked
    else:
        frame = bytes([0x81, 0xFE]) + struct.pack(">H", n) + mask + masked
    sock.send(frame)


def ws_recv(sock):
    header = b""
    while len(header) < 2:
        c = sock.recv(2 - len(header))
        if not c:
            return None
        header += c
    payload_len = header[1] & 0x7F
    if payload_len == 126:
        payload_len = struct.unpack(">H", sock.recv(2))[0]
    elif payload_len == 127:
        payload_len = struct.unpack(">Q", sock.recv(8))[0]
    data = b""
    while len(data) < payload_len:
        c = sock.recv(payload_len - len(data))
        if not c:
            return None
        data += c
    try:
        return json.loads(data.decode())
    except Exception:
        return None


def main():
    print(f"Bridge started: HyperHDR:{HYPERHDR_PORT} → WLED {WLED_HOST}:{WLED_DDP_PORT} (DDP per-LED)")
    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    while True:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect((HYPERHDR_HOST, HYPERHDR_PORT))
            ws_handshake(sock)
            ws_send(sock, {"command": "ledcolors", "subcommand": "ledstream-start", "tan": 1})
            sock.settimeout(5)
            print("Connected to HyperHDR, streaming LED colors to WLED via DDP...")
            frames = 0
            while True:
                msg = ws_recv(sock)
                if msg is None:
                    break
                leds = (msg.get("result") or {}).get("leds")
                if leds:
                    try:
                        udp.sendto(build_ddp_packet(leds), (WLED_HOST, WLED_DDP_PORT))
                    except Exception as e:
                        print(f"  DDP send error: {e}")
                    frames += 1
                    if frames % 100 == 0:
                        print(f"  {frames} frames forwarded")
        except KeyboardInterrupt:
            print("Bridge stopped.")
            udp.close()
            sys.exit(0)
        except Exception as e:
            print(f"Reconnecting in 5s ({e})")
            time.sleep(5)


if __name__ == "__main__":
    main()
