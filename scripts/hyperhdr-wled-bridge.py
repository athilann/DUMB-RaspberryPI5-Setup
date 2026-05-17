#!/usr/bin/env python3
"""Bridge: HyperHDR LED colors → WLED per-LED via chunked DDP UDP."""

import json
import socket
import struct
import os
import base64
import time
import sys
import urllib.request

HYPERHDR_HOST = "localhost"
HYPERHDR_PORT = 8090
WLED_IP = "192.168.50.157"
WLED_URL = f"http://{WLED_IP}"
WLED_DDP_PORT = 4048

NUM_LEDS = 534

# Max LEDs per DDP chunk: keeps UDP payload ≤ 1472 bytes (no IP fragmentation)
# 487 × 3 + 10 (header) = 1471 bytes
MAX_LEDS_PER_CHUNK = 487

# Precomputed physical→HyperHDR index remapping
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
#   P   0–178  →  H = P + 355
#   P 179–533  →  H = P - 179
REMAP = [(p + 355) if p <= 178 else (p - 179) for p in range(NUM_LEDS)]

udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)


def wled_post(path, data):
    payload = json.dumps(data).encode()
    req = urllib.request.Request(
        f"{WLED_URL}{path}",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    return json.loads(urllib.request.urlopen(req, timeout=3).read())


def wled_setup():
    """Configure WLED with a single full-strip segment (fallback when DDP live mode ends)."""
    return wled_post("/json/state", {
        "on": True,
        "bri": 255,
        "transition": 0,
        "seg": [{"id": 0, "start": 0, "stop": NUM_LEDS, "on": True, "bri": 255, "fx": 0, "col": [[0, 0, 0]]}],
    }).get("success", False)


def send_ddp(hyperhdr_flat):
    """Send one per-LED DDP frame split into sub-MTU chunks."""
    # Build physical-order RGB bytes from HyperHDR H-indexed flat array
    phys = bytearray(NUM_LEDS * 3)
    for p in range(NUM_LEDS):
        h = REMAP[p]
        phys[p * 3]     = hyperhdr_flat[h * 3]
        phys[p * 3 + 1] = hyperhdr_flat[h * 3 + 1]
        phys[p * 3 + 2] = hyperhdr_flat[h * 3 + 2]

    offset = 0
    while offset < NUM_LEDS:
        chunk = min(MAX_LEDS_PER_CHUNK, NUM_LEDS - offset)
        is_last = (offset + chunk >= NUM_LEDS)
        flags = 0x41 if is_last else 0x40  # push flag only on last chunk
        byte_offset = offset * 3
        data = phys[byte_offset: byte_offset + chunk * 3]
        header = struct.pack('>BBBBIH', flags, 0x00, 0x01, 0x01, byte_offset, len(data))
        udp_sock.sendto(header + data, (WLED_IP, WLED_DDP_PORT))
        offset += chunk


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
    print(f"Bridge started: HyperHDR:{HYPERHDR_PORT} → WLED {WLED_IP}:{WLED_DDP_PORT} (per-LED DDP, {NUM_LEDS} LEDs)")
    try:
        ok = wled_setup()
        print(f"WLED single-segment configured: {ok}")
    except Exception as e:
        print(f"Warning: WLED setup failed: {e}")

    while True:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect((HYPERHDR_HOST, HYPERHDR_PORT))
            ws_handshake(sock)
            ws_send(sock, {"command": "ledcolors", "subcommand": "ledstream-start", "tan": 1})
            sock.settimeout(5)
            print("Connected to HyperHDR, streaming per-LED DDP to WLED...")
            frames = 0
            while True:
                msg = ws_recv(sock)
                if msg is None:
                    break
                leds = (msg.get("result") or {}).get("leds")
                if leds:
                    send_ddp(leds)
                    frames += 1
                    if frames % 300 == 0:
                        print(f"  {frames} frames forwarded")
        except KeyboardInterrupt:
            print("Bridge stopped.")
            sys.exit(0)
        except Exception as e:
            print(f"Reconnecting in 5s ({e})")
            time.sleep(5)


if __name__ == "__main__":
    main()
