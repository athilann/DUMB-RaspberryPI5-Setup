# HyperHDR → WLED Ambient Lighting Setup

Complete reference for the HyperHDR ambient lighting stack on the Raspberry Pi 5. Follow
this guide to fully replicate the configuration from scratch.

---

## Hardware

| Component | Details |
|-----------|---------|
| Raspberry Pi 5 | `192.168.50.55`, running HyperHDR in Docker |
| Fire TV Stick 4K Max | Video source, `192.168.50.2` |
| EZCoo HDMI 2.1 Splitter | Splits HDMI; OUT2 bypasses HDCP |
| USB3.0 Capture Card | Plugged into Pi USB3; appears as `/dev/video0` |
| WLED controller (Gledopto ESP32) | `192.168.50.157`, port 21324 (UDP), 80 (HTTP) |
| SK6812 RGBW LED strip | 534 LEDs total, mounted behind TV |

### HDMI signal chain

```
Fire TV → EZCoo IN → EZCoo OUT1 → TV (passthrough, HDCP intact)
                   → EZCoo OUT2 → USB Capture Card → Pi /dev/video0
```

OUT2 bypasses HDCP so the capture card receives a clean signal. OUT1 is untouched
so the TV works normally.

### LED layout (534 total)

Viewed from the **front** of the TV, LEDs run **counter-clockwise** starting at
bottom-center going left:

```
         ←←← top 170 LEDs ←←←
    ↑                           ↑
left 97                      right 95
    ↑                           ↑
  [bottom-left 82] [bottom-right 90]
             ↑ LED 0 starts here
```

| Section | LED range | Count |
|---------|-----------|-------|
| Bottom-left (center → left corner) | 0 – 81 | 82 |
| Left side (bottom → top) | 82 – 178 | 97 |
| Top (left → right) | 179 – 348 | 170 |
| Right side (top → bottom) | 349 – 443 | 95 |
| Bottom-right (right corner → center) | 444 – 533 | 90 |

---

## Software Architecture

```
Fire TV (HDMI)
    ↓ EZCoo OUT2 (HDCP stripped)
USB Capture Card /dev/video0
    ↓ MJPEG 1920×1080 @ 60fps
HyperHDR (Docker, port 8090)
  - Computes per-LED colors for 534 LEDs
  - Streams colors via WebSocket (ledstream-start)
    ↓ WebSocket ws://localhost:8090
hyperhdr-wled-bridge.py (systemd service)
  - Receives 534×RGB values per frame (~10fps)
  - Divides strip into 12 zones, averages each zone's color
  - POSTs all 12 zone colors in one /json/state call
    ↓ HTTP POST http://192.168.50.157/json/state
WLED (192.168.50.157)
  - 12 segments, each showing one averaged zone color
    ↓
SK6812 RGBW LED strip (534 LEDs)
```

---

## HyperHDR Docker Container

### Image

```
umuugg/hyperhdr-ha-aarch64:latest
```

This is the aarch64 build maintained for Home Assistant. The upstream HyperHDR image
does not publish aarch64 builds for Pi 5.

### docker-compose entry

See `config/docker-compose.yml.template` — the `hyperhdr` service definition.

Key settings:
- `network_mode: host` — required so the bridge script (running on the host) can reach
  HyperHDR's WebSocket on `localhost:8090`
- `/dev/video0` and `/dev/video1` passed through as devices

### Data directory

```
/opt/dumb/data/hyperhdr/     ← mounted as /config inside the container
  addons_config/hyperhdr/db/hyperhdr.db   ← SQLite config DB
  hyperhdr-wled-bridge.py                 ← bridge script (deployed here)
  debug-hyperhdr-ws.py                    ← debug utility
```

### HyperHDR web UI

`http://192.168.50.55:8090`

### Video grabber config (set via web UI or DB)

| Setting | Value |
|---------|-------|
| Device | `USB3.0 Capture: USB3.0 Capture (video0)` |
| Resolution | 1920×1080 |
| Encoding | MJPEG |
| FPS | 60 |
| HDR tone mapping | Enabled |

### LED layout config (set via web UI → LED Layout → Classic)

| Setting | Value |
|---------|-------|
| Top | 170 |
| Left | 97 |
| Right | 95 |
| Bottom | 172 |
| Position | 3 (bottom-left start) |
| Reverse | false |
| Total | 534 |

### LED Device config (in SQLite DB)

HyperHDR's built-in LED device is set to **file → /dev/null** so it does not send
any data directly to WLED. The bridge script handles all WLED communication.

To inspect or update:
```bash
docker cp hyperhdr:/config/addons_config/hyperhdr/db/hyperhdr.db /tmp/hyperhdr.db
python3 -c "
import sqlite3, json
conn = sqlite3.connect('/tmp/hyperhdr.db')
row = conn.execute(\"SELECT config FROM settings WHERE type='device'\").fetchone()
print(json.dumps(json.loads(row[0]), indent=2))
"
```

To set the file/null device (run on Pi):
```bash
docker cp hyperhdr:/config/addons_config/hyperhdr/db/hyperhdr.db /tmp/hyperhdr.db
python3 -c "
import sqlite3, json
conn = sqlite3.connect('/tmp/hyperhdr.db')
cfg = json.dumps({
    'colorOrder': 'rgb',
    'maxRetry': 0,
    'refreshTime': 0,
    'restoreOriginalState': False,
    'type': 'file',
    'fileName': '/dev/null'
})
conn.execute(\"UPDATE settings SET config=? WHERE type='device'\", (cfg,))
conn.commit()
"
docker cp /tmp/hyperhdr.db hyperhdr:/config/addons_config/hyperhdr/db/hyperhdr.db
docker restart hyperhdr
```

---

## WLED Configuration

**IP:** `192.168.50.157`  
**Firmware:** 0.15.3 "Kōsen" (custom AudioReactive build)

### LED hardware config

| Setting | Value |
|---------|-------|
| Strip type | SK6812 RGBW (type 30) |
| Data pin | GPIO 16 |
| LED count | 534 (main strip) + 3 aux LEDs on pins 12, 4, 2 |
| Color order | RGB (order: 1) |
| RGBW mode | 1 (Dual auto-white) |

### Critical settings

**AudioReactive must be ENABLED at module level** (even though it's not controlling
LEDs). Disabling it at the module level also disables WLED's UDP listener, breaking
other functionality.

To keep AudioReactive enabled but not controlling LEDs:
```bash
# Re-enable at module level (restores UDP listener)
curl -X POST http://192.168.50.157/json/cfg \
  -H 'Content-Type: application/json' \
  -d '{"um":{"AudioReactive":{"enabled":true}}}'

# Disable AR output via state API
curl -X POST http://192.168.50.157/json/state \
  -H 'Content-Type: application/json' \
  -d '{"AudioReactive":{"on":false},"seg":[{"id":0,"frz":false}]}'
```

**Important:** Do NOT disable AudioReactive at the module level (`enabled: false` in
cfg). This disables WLED's internal UDP receiver even though we're using HTTP.

### Why UDP DRGB doesn't work

This custom AudioReactive WLED build does not process UDP DRGB realtime packets
from external sources despite UDP being reachable. The `/json/live` HTTP endpoint
also returns success but doesn't update LEDs. The only working method for per-zone
color control is the `/json/state` segments API.

### Segments (configured by bridge on startup)

The bridge automatically creates 12 segments covering the 534 LEDs:

| Seg | WLED LEDs | Zone |
|-----|-----------|------|
| 0 | 0 – 40 | Bottom-left A |
| 1 | 41 – 81 | Bottom-left B |
| 2 | 82 – 129 | Left lower |
| 3 | 130 – 178 | Left upper |
| 4 | 179 – 220 | Top left |
| 5 | 221 – 262 | Top center-left |
| 6 | 263 – 304 | Top center-right |
| 7 | 305 – 348 | Top right |
| 8 | 349 – 396 | Right upper |
| 9 | 397 – 443 | Right lower |
| 10 | 444 – 488 | Bottom-right A |
| 11 | 489 – 533 | Bottom-right B |

Each segment uses `fx: 0` (solid color), `frz: false`, `transition: 0`.

---

## Bridge Script

**Source:** `scripts/hyperhdr-wled-bridge.py`  
**Deployed to:** `/opt/dumb/data/hyperhdr/hyperhdr-wled-bridge.py`

### How it works

1. Connects to HyperHDR WebSocket at `ws://localhost:8090`
2. Sends `{"command":"ledcolors","subcommand":"ledstream-start"}` to subscribe
3. HyperHDR sends `ledcolors-ledstream-update` messages containing a flat array of
   1602 values (534 LEDs × 3 RGB channels)
4. Bridge slices that array into 12 zone windows, averages each zone's RGB
5. POSTs a single `/json/state` to WLED with all 12 zone colors
6. On startup, configures WLED's 12 segments (one-time setup)
7. Auto-reconnects to HyperHDR if connection drops

### Deploy to Pi

```bash
scp scripts/hyperhdr-wled-bridge.py pi@192.168.50.55:/opt/dumb/data/hyperhdr/
```

### Systemd service

Install once on the Pi:

```bash
sudo tee /etc/systemd/system/hyperhdr-wled-bridge.service > /dev/null << 'EOF'
[Unit]
Description=HyperHDR to WLED UDP bridge
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=pi
Environment=PYTHONUNBUFFERED=1
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/python3 -u /opt/dumb/data/hyperhdr/hyperhdr-wled-bridge.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable hyperhdr-wled-bridge
sudo systemctl start hyperhdr-wled-bridge
```

### Service management

```bash
sudo systemctl status hyperhdr-wled-bridge
sudo journalctl -u hyperhdr-wled-bridge -f
sudo systemctl restart hyperhdr-wled-bridge
```

---

## Full Replication Steps (fresh Pi)

1. **Deploy the stack** (from repo root):
   ```bash
   bash scripts/deploy-all.sh
   ```

2. **Configure HyperHDR** via web UI at `http://192.168.50.55:8090`:
   - Video Grabber: device = `USB3.0 Capture`, 1920×1080, MJPEG, 60fps, HDR on
   - LED Layout: Classic — top=170, left=97, right=95, bottom=172, position=3
   - LED Output: disable the built-in device (set to file/null via DB — see above)

3. **Deploy bridge script**:
   ```bash
   scp scripts/hyperhdr-wled-bridge.py pi@192.168.50.55:/opt/dumb/data/hyperhdr/
   ```

4. **Install systemd service** (copy the unit file from the section above onto the Pi)

5. **Configure WLED** at `http://192.168.50.157`:
   - Keep AudioReactive **enabled at module level**
   - Disable AudioReactive output: `{"AudioReactive":{"on":false}}`
   - Segments are auto-created by the bridge on first start

6. **Start bridge**:
   ```bash
   sudo systemctl start hyperhdr-wled-bridge
   ```

7. **Verify** — check bridge logs and HyperHDR performance:
   ```bash
   sudo journalctl -u hyperhdr-wled-bridge -f
   docker logs hyperhdr --tail 3 -f
   ```
   Look for `frames > 0` in the HyperHDR log and `frames forwarded` in the bridge log.

---

## Troubleshooting

### LEDs are off / all one color

1. Check WLED segment freeze: `curl http://192.168.50.157/json/state | python3 -m json.tool`
   — if `"frz": true`, unfreeze: `curl -X POST ... -d '{"seg":[{"id":0,"frz":false}]}'`
2. Check AudioReactive isn't controlling LEDs:
   `curl -X POST http://192.168.50.157/json/state -d '{"AudioReactive":{"on":false}}'`
3. Restart bridge: `sudo systemctl restart hyperhdr-wled-bridge`

### HyperHDR shows "HyperHDR" logo / frames = 0 / invalid = 3600

This is the HDCP block. The EZCoo is not passing a clean signal to the capture card.

**Fix sequence:**
1. Unplug the HDMI cable between Fire TV and EZCoo — wait 5s — replug
2. Press the **UPDATE** button on the EZCoo (re-reads EDID, resets HDCP handshake)
3. On Fire TV: Settings → Display & Sounds → Display → set to **1080p** (forces
   HDCP 1.4 which the EZCoo handles more reliably than HDCP 2.2)
4. Wake Fire TV and start playing video

When working, HyperHDR log shows: `frames = N, invalid = 0`

### Bridge connects but no LED changes

Check that HyperHDR has an active source:
```bash
curl -s http://localhost:8090/json-rpc -d '{"command":"serverinfo"}' | \
  python3 -c 'import json,sys; [print(p) for p in json.load(sys.stdin)["info"]["priorities"]]'
```
The VIDEOGRABBER priority must be `"active": true`. If it's false, no frames are
being captured (HDCP issue or no HDMI signal).

To force an effect for testing:
```bash
curl -X POST http://localhost:8090/json-rpc \
  -d '{"command":"effect","effect":{"name":"Rainbow swirl"},"priority":50,"duration":30000}'
```

### HyperHDR LEDDEVICE keeps interfering with WLED

If WLED shows `"live": true` but LEDs are black, HyperHDR's built-in device is sending
null/black packets to WLED. Confirm the device type is `file` in the DB (see above),
then restart HyperHDR: `docker restart hyperhdr`

---

## Debug Utilities

### `scripts/debug-hyperhdr-ws.py`

Run on the Pi to dump raw WebSocket messages from HyperHDR's ledstream:
```bash
python3 /opt/dumb/data/hyperhdr/debug-hyperhdr-ws.py
```
Useful for verifying the ledstream format and that HyperHDR is sending color data.

### Manual WLED segment color test

```bash
ssh pi@192.168.50.55 python3 - << 'EOF'
import socket, time
udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
for color, name in [([255,0,0],'RED'), ([0,255,0],'GREEN'), ([0,0,255],'BLUE')]:
    # via /json/state (works)
    import urllib.request, json
    data = json.dumps({"seg":[{"id":0,"col":[color],"fx":0,"frz":False}]}).encode()
    req = urllib.request.Request('http://192.168.50.157/json/state', data=data,
                                  headers={'Content-Type':'application/json'})
    urllib.request.urlopen(req)
    print(name)
    time.sleep(2)
EOF
```
