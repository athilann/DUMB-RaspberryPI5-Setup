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
# 32 zones (WLED max segments) — finer resolution than previous 12 zones
# Each entry: (wled_start, wled_stop_inclusive, hyperhdr_led_start, hyperhdr_led_stop_inclusive)
ZONES = [
    # bottom-left: 5 zones  (P 0–81 → H 355–436)
    (0,   16,  355, 371),
    (17,  33,  372, 388),
    (34,  50,  389, 405),
    (51,  66,  406, 421),
    (67,  81,  422, 436),
    # left: 6 zones          (P 82–178 → H 437–533)
    (82,  97,  437, 452),
    (98,  113, 453, 468),
    (114, 129, 469, 484),
    (130, 146, 485, 501),
    (147, 162, 502, 517),
    (163, 178, 518, 533),
    # top: 10 zones          (P 179–348 → H 0–169)
    (179, 195, 0,   16),
    (196, 212, 17,  33),
    (213, 229, 34,  50),
    (230, 246, 51,  67),
    (247, 263, 68,  84),
    (264, 280, 85,  101),
    (281, 297, 102, 118),
    (298, 314, 119, 135),
    (315, 331, 136, 152),
    (332, 348, 153, 169),
    # right: 5 zones         (P 349–443 → H 170–264)
    (349, 367, 170, 188),
    (368, 386, 189, 207),
    (387, 405, 208, 226),
    (406, 424, 227, 245),
    (425, 443, 246, 264),
    # bottom-right: 6 zones  (P 444–533 → H 265–354)
    (444, 458, 265, 279),
    (459, 474, 280, 295),
    (475, 489, 296, 310),
    (490, 504, 311, 325),
    (505, 519, 326, 340),
    (520, 533, 341, 354),
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
            "stop": we + 1,
            "on": True,
            "bri": 255,
            "fx": 0,
            "frz": False,
        })
    for i in range(len(ZONES), 32):
        segs.append({"id": i, "stop": 0})

    r = wled_post("/json/state", {
        "on": True,
        "bri": 255,
        "transition": 0,
        "AudioReactive": {"on": False},
        "seg": segs,
    })
    ok = r.get("success", False)
    if ok:
        try:
            wled_post("/json/state", {"psave": 1})
            wled_post("/json/cfg", {"def": {"ps": 1, "on": True, "bri": 255}})
        except Exception:
            pass
    return ok


def avg_color(flat, led_start, led_stop):
    r = g = b = 0
    count = led_stop - led_start + 1
    for i in range(led_start, led_stop + 1):
        idx = i * 3
        r += flat[idx]
        g += flat[idx + 1]
        b += flat[idx + 2]
    return [r // count, g // count, b // count]


wled_was_offline = False


def wled_segments_ok():
    try:
        state = json.loads(urllib.request.urlopen(
            f"{WLED_URL}/json/state", timeout=3
        ).read())
        active = [s for s in state.get("seg", []) if s.get("stop", 0) > s.get("start", 0)]
        return len(active) >= len(ZONES)
    except Exception:
        return False


def update_wled(flat):
    global wled_was_offline
    if wled_was_offline:
        try:
            setup_segments()
        except Exception:
            return
        for attempt in range(10):
            time.sleep(1.0)
            if wled_segments_ok():
                wled_was_offline = False
                print(f"WLED reconnected, segments verified after {attempt + 1}s")
                break
        return
    segs = []
    for i, (ws, we, hs, he) in enumerate(ZONES):
        color = avg_color(flat, hs, he)
        segs.append({"id": i, "col": [color]})
    try:
        wled_post("/json/state", {"on": True, "transition": 0, "seg": segs})
    except Exception:
        wled_was_offline = True
        raise


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
    print(f"Bridge started: HyperHDR:{HYPERHDR_PORT} → WLED {WLED_URL} (32-zone segments)")
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
