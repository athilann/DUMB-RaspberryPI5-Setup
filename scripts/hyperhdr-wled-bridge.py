#!/usr/bin/env python3
"""Bridge: HyperHDR LED colors → WLED zones via /json/state segments."""

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
WLED_URL = "http://192.168.50.157"

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
#
# Each entry: (wled_start, wled_stop_inclusive, hyperhdr_led_start, hyperhdr_led_stop_inclusive)
ZONES = [
    # bottom-left: 2 zones  (P 0–81 → H 355–436, mapping H=P+355)
    (0,   40,  355, 395),
    (41,  81,  396, 436),
    # left: 2 zones          (P 82–178 → H 437–533, mapping H=P+355)
    (82,  129, 437, 484),
    (130, 178, 485, 533),
    # top: 4 zones           (P 179–348 → H 0–169, mapping H=P-179)
    (179, 220, 0,   41),
    (221, 262, 42,  83),
    (263, 304, 84,  125),
    (305, 348, 126, 169),
    # right: 2 zones         (P 349–443 → H 170–264, mapping H=P-179)
    (349, 396, 170, 217),
    (397, 443, 218, 264),
    # bottom-right: 2 zones  (P 444–533 → H 265–354, mapping H=P-179)
    (444, 488, 265, 309),
    (489, 533, 310, 354),
]


def wled_post(path, data):
    payload = json.dumps(data).encode()
    req = urllib.request.Request(
        f"{WLED_URL}{path}",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    return json.loads(urllib.request.urlopen(req, timeout=3).read())


def setup_segments():
    segs = []
    for i, (ws, we, _, _) in enumerate(ZONES):
        segs.append({
            "id": i,
            "start": ws,
            "stop": we + 1,   # WLED stop is exclusive
            "on": True,
            "bri": 255,
            "fx": 0,          # solid color — no animation
            "frz": False,
        })
    # Turn off any leftover segments beyond our count
    for i in range(len(ZONES), 16):
        segs.append({"id": i, "stop": 0})

    r = wled_post("/json/state", {
        "on": True,
        "bri": 255,
        "transition": 0,
        "seg": segs,
    })
    return r.get("success", False)


def avg_color(flat, led_start, led_stop):
    r = g = b = 0
    count = led_stop - led_start + 1
    for i in range(led_start, led_stop + 1):
        idx = i * 3
        r += flat[idx]
        g += flat[idx + 1]
        b += flat[idx + 2]
    return [r // count, g // count, b // count]


def update_wled(flat):
    segs = []
    for i, (_, _, hs, he) in enumerate(ZONES):
        color = avg_color(flat, hs, he)
        segs.append({"id": i, "col": [color]})
    wled_post("/json/state", {"transition": 0, "seg": segs})


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
    print(f"Bridge started: HyperHDR:{HYPERHDR_PORT} → WLED {WLED_URL} (12-zone segments)")
    try:
        ok = setup_segments()
        print(f"WLED segments configured: {ok}")
    except Exception as e:
        print(f"Warning: segment setup failed: {e}")

    while True:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect((HYPERHDR_HOST, HYPERHDR_PORT))
            ws_handshake(sock)
            ws_send(sock, {"command": "ledcolors", "subcommand": "ledstream-start", "tan": 1})
            sock.settimeout(5)
            print("Connected to HyperHDR, streaming LED colors to WLED...")
            frames = 0
            while True:
                msg = ws_recv(sock)
                if msg is None:
                    break
                leds = (msg.get("result") or {}).get("leds")
                if leds:
                    try:
                        update_wled(leds)
                    except Exception as e:
                        print(f"  WLED update error: {e}")
                    frames += 1
                    if frames % 100 == 0:
                        print(f"  {frames} frames forwarded")
        except KeyboardInterrupt:
            print("Bridge stopped.")
            sys.exit(0)
        except Exception as e:
            print(f"Reconnecting in 5s ({e})")
            time.sleep(5)


if __name__ == "__main__":
    main()
