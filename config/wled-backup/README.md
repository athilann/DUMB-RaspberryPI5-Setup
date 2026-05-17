# WLED Backup — Pre-Serial-Flash Snapshot

Captured: 2026-05-17 from WLED at 192.168.50.157 (Gledopto custom firmware, v0.15.3 "Kōsen")

## Files

| File | Contents |
|------|----------|
| `cfg.json` | Full hardware + network config (LED type, pin, count, Wi-Fi SSID, AP settings) |
| `state.json` | Current segment layout (32 zones, our bridge config) |
| `presets.json` | All saved presets (preset 1 = our boot preset with 32-zone segment layout) |
| `info.json` | Device info (firmware version, chip, flash size, MAC) |

## Critical LED Hardware Settings (from cfg.json)

These must be re-entered in standard WLED after serial flash:

| Setting | Value |
|---------|-------|
| LED type | SK6812 RGBW (type 30) |
| Data pin | GPIO 16 |
| LED count | 534 |
| Color order | RGB (order 1) |
| RGBW mode | rgbwm = 1 |

Additional non-addressable LEDs present in the Gledopto device (ignore these after flash,
they are Gledopto-internal indicator LEDs on GPIO 12, 4, 2 — not part of the LED strip):
- GPIO 12: 1 LED (type 40)
- GPIO 4: 1 LED (type 40)
- GPIO 2: 1 LED (type 40)

## Network Settings (from cfg.json)

| Setting | Value |
|---------|-------|
| Wi-Fi SSID | Matrix |
| mDNS name | wled-e094a8 |
| Device name | WLED-Gledopto |
| Static IP | DHCP (all zeros) |

## After Serial Flash — What to Restore

After flashing standard `WLED_0.15.3_ESP32.bin` via serial:

1. **Re-connect to Wi-Fi**: SSID = Matrix (enter password manually — not stored in backup)
2. **LED config** (Config → LED Preferences):
   - Strip 1: SK6812 RGBW, GPIO 16, 534 LEDs, RGB color order
   - Do NOT add the GPIO 12/4/2 entries (those are Gledopto-only)
3. **Verify DDP works**: bridge will switch to DDP per-LED mode automatically
4. The bridge (`hyperhdr-wled-bridge.py`) will call `setup_segments()` on first connect
   which will configure WLED correctly — no manual segment setup needed

## What NOT to restore

- Do not restore `cfg.json` directly to standard WLED — it contains Gledopto-specific
  settings (extra GPIO LEDs, AudioReactive blocks) that will break standard WLED
- Do not restore `state.json` or `presets.json` — segment layout will be rebuilt by the bridge
- Do not restore `presets.json` — preset 1 will be rebuilt by the bridge on first run
