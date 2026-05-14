# Product Requirements Document — DUMB Raspberry Pi 5 Setup

## Objective

Automate the end-to-end installation and configuration of **DUMB** (Debrid Unlimited Media Bridge)
on a Raspberry Pi 5, enabling a fully-automated Real-Debrid + Plex media stack. Any user with a
Raspberry Pi 5 and a Real-Debrid account should be able to go from a fresh OS to a working system
using a single command.

---

## Background

Real-Debrid provides high-speed cached torrent downloads. DUMB integrates Real-Debrid with Plex
via **Decypharr** (download client + virtual filesystem), **Radarr/Sonarr** (library automation),
**Prowlarr** (indexer management), and **Overseerr** (request UI) — all inside a single Docker
container.

---

## Target User

A home media enthusiast who:
- Has a Raspberry Pi 5 running Raspberry Pi OS Bookworm 64-bit
- Has a Real-Debrid subscription
- Has a Plex account
- Is comfortable with SSH but does not need to understand Docker internals

---

## Architecture

```
Plex Watchlist ──────────────────────────────────────┐
                                                      ↓
Overseerr (request UI) ──────────────────→ Radarr / Sonarr / Prowlarr
                                                      ↓ download requests
                            Decypharr + DFS (RD download client + virtual filesystem)
                                                      ↓ streams via DFS virtual paths
                                           Plex Media Server (serves media to users)
```

### Media Request Paths

| Path | How |
|------|-----|
| Plex Watchlist | Add to Plex Watchlist → Radarr/Sonarr import list picks it up automatically |
| Overseerr | Request via web UI → routes to Radarr/Sonarr → Decypharr → Real-Debrid |

---

## Target Machine

| Property     | Value                            |
|--------------|----------------------------------|
| IP Address   | `192.168.50.55`                  |
| SSH User     | `pi`                             |
| OS           | Raspberry Pi OS Bookworm 64-bit  |
| Architecture | aarch64 (ARM64)                  |
| Min RAM      | 2 GB                             |
| Min Disk     | 20 GB free                       |
| Install Dir  | `/opt/dumb`                      |

---

## Functional Requirements

### FR-01 — One-Command Install
`bash scripts/deploy-all.sh` must complete all installation steps without manual intervention,
except for credential prompts (which must not be automatable for security reasons).

### FR-02 — Credential Security
- No credentials ever written to or read from the git repository
- `.env` is always gitignored and generated locally via interactive prompt
- Credentials copied to Pi via `scp` with 600 permissions

### FR-03 — Idempotent Scripts
All install scripts must be safe to re-run. Re-running on an existing installation must not
break or duplicate the configuration.

### FR-04 — Plex Watchlist Integration
Radarr and Sonarr must be configured with a Plex Watchlist import list using the user's
`PLEX_TOKEN`. Adding a title to the Plex Watchlist must trigger Radarr/Sonarr within 15 minutes.

### FR-05 — Overseerr Integration
Overseerr must be accessible at port 5055 and configurable to connect to the local Plex server
and Radarr/Sonarr instances.

### FR-06 — Decypharr DFS
Decypharr must be configured with DFS (Decypharr File System) enabled, making Real-Debrid
content available to Plex without requiring a separate rclone FUSE mount.

### FR-07 — Uninstall
`bash scripts/uninstall.sh` must cleanly remove all containers, images, and the `/opt/dumb`
directory, optionally removing Docker as well.

### FR-08 — Test Coverage
All 10 tests in `tests/` must pass on a correctly installed system. Tests requiring human
interaction must print clear instructions and wait for user confirmation.

---

## Non-Functional Requirements

### NFR-01 — ARM64 Compatibility
All Docker images must support `linux/arm64` (Raspberry Pi 5).

### NFR-02 — Install Time
Full installation (steps 00–06) must complete within 30 minutes on a typical home broadband
connection, excluding Docker image pull time.

### NFR-03 — Restart Behavior
The DUMB container must have `restart: unless-stopped` so all services recover automatically
after a Pi reboot.

### NFR-04 — Resource Usage
DUMB container must be configured with `shm_size: 128mb` and `stop_grace_period: 30s` as
recommended by the upstream project.

---

## Services and Ports

| Service    | Port  | Enabled | Purpose                              |
|------------|-------|---------|--------------------------------------|
| Plex       | 32400 | Yes     | Media streaming                      |
| Decypharr  | 8082  | Yes     | Real-Debrid download client + DFS    |
| Radarr     | 7878  | Yes     | Movie automation                     |
| Sonarr     | 8989  | Yes     | TV show automation                   |
| Prowlarr   | 9696  | Yes     | Indexer management                   |
| Overseerr  | 5055  | Yes     | Media request UI                     |
| Zurg       | —     | No      | Replaced by DFS                      |
| rclone     | —     | No      | Replaced by DFS                      |

---

## Success Criteria

| # | Criteria | How Verified |
|---|----------|-------------|
| 1 | `deploy-all.sh` completes without error on fresh Pi 5 | CI / manual run |
| 2 | Plex accessible at `:32400/web` | test-10-plex.sh |
| 3 | Overseerr accessible at `:5055` | test-09-overseerr.sh |
| 4 | Radarr/Sonarr/Prowlarr accessible on their ports | tests 06/07/08 |
| 5 | Decypharr DFS active | test-04-decypharr.sh, test-05-dfs-mount.sh |
| 6 | Plex Watchlist syncs to Radarr within 15 min | test-10-plex.sh (human) |
| 7 | `uninstall.sh` leaves Pi clean | Manual verification |
| 8 | No credentials in git history | `git log -p | grep -E 'token|password|secret'` |

---

## Out of Scope

- Enabling Jellyfin or Emby (Plex-only)
- Enabling Zurg or rclone (DFS is used instead)
- Configuring Prowlarr indexers (user does this in browser)
- Configuring Overseerr Plex connection (user does this in browser)
- SSL/TLS / reverse proxy setup
- External access / port forwarding
- Backup and restore procedures
