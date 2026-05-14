# DUMB Raspberry Pi 5 Setup — Claude Code Instructions

## Project Overview

This repository automates the installation and configuration of **DUMB** (Debrid Unlimited Media
Bridge — [github.com/I-am-PUID-0/DUMB](https://github.com/I-am-PUID-0/DUMB)) on a
**Raspberry Pi 5** at `192.168.50.55`. DUMB is an all-in-one Docker container that provides a
fully-automated Real-Debrid + Plex media stack.

### Architecture

```
Plex Watchlist ──────────────────────────────────────┐
                                                      ↓
Overseerr (request UI) ──────────────────→ Radarr / Sonarr / Prowlarr
                                                      ↓ download requests
                            Decypharr + DFS (RD download client + virtual filesystem)
                                                      ↓ streams via DFS virtual paths
                                           Plex Media Server (serves media to users)
```

**Decypharr File System (DFS)** creates a virtual filesystem for Plex — no Zurg or rclone FUSE
mount required.

### Enabled DUMB Services

| Service     | Port  | Purpose                                |
|-------------|-------|----------------------------------------|
| Plex        | 32400 | Media streaming server                 |
| Decypharr   | 8082  | Real-Debrid download client for *arr (internal: 8282) |
| Radarr      | 7878  | Movie library automation               |
| Sonarr      | 8989  | TV show library automation             |
| Prowlarr    | 9696  | Indexer management                     |
| Overseerr   | 5055  | Media request UI                       |

---

## Target Machine

| Property     | Value              |
|--------------|--------------------|
| IP Address   | `192.168.50.55`    |
| SSH User     | `pi`               |
| OS           | Raspberry Pi OS Bookworm 64-bit (aarch64) |
| Docker       | Installed by `02-install-docker.sh` |
| Install Dir  | `/opt/dumb`        |

---

## CRITICAL: Credential Rules

- **NEVER commit** `.env`, tokens, API keys, or passwords to git
- Credentials are **always prompted** interactively in `scripts/04-configure-env.sh`
- Config templates use `${VAR}` placeholders — rendered via `envsubst` on the Pi
- `.env` is written locally (gitignored) and copied to the Pi via `scp`
- The Pi's copy lives at `/opt/dumb/.env` — never in the repo

Required credentials (obtained from user, never hardcoded):
- `RD_API_TOKEN` — Real-Debrid API token from https://real-debrid.com/apitoken
- `PLEX_CLAIM` — One-time server claim token from https://plex.tv/claim (expires in 4 min)
- `PLEX_TOKEN` — Plex auth token for Radarr/Sonarr Watchlist import (different from PLEX_CLAIM)

---

## Script Conventions

### Remote execution pattern
```bash
ssh pi@192.168.50.55 'bash -s' < scripts/01-system-update.sh
```

### File copy pattern
```bash
scp config/docker-compose.yml.template pi@192.168.50.55:/opt/dumb/
```

### Environment variable passing to remote scripts
```bash
ssh pi@192.168.50.55 "RD_API_TOKEN='$RD_API_TOKEN' bash -s" < scripts/some-script.sh
```

### Script sourcing
All scripts source `scripts/lib/common.sh` for logging, error handling, and SSH helpers.

---

## Execution Order

Run scripts in this order, or execute `scripts/deploy-all.sh` to run all steps automatically:

| Step | Script                        | Where     | Purpose                            |
|------|-------------------------------|-----------|------------------------------------|
| 00   | `00-check-prerequisites.sh`   | local+SSH | Validate local tools + Pi specs    |
| 01   | `01-system-update.sh`         | SSH       | apt update/upgrade + dependencies  |
| 02   | `02-install-docker.sh`        | SSH       | Install Docker CE + Compose v2     |
| 03   | `03-setup-directories.sh`     | SSH       | Create `/opt/dumb` structure       |
| 04   | `04-configure-env.sh`         | local     | Prompt credentials, write `.env`   |
| 05   | `05-deploy-stack.sh`          | local+SSH | Deploy DUMB docker-compose stack   |
| 06   | `06-verify-services.sh`       | SSH       | Confirm all services are healthy   |
| —    | `uninstall.sh`                | SSH       | Full teardown and cleanup          |

### Idempotency

All install scripts are safe to re-run — they check for existing state before acting.

---

## Testing

```bash
# Run all tests
bash tests/run-all-tests.sh

# Run individual test
bash tests/test-03-containers.sh
```

Tests that require human interaction print a clear prompt and wait for keypress.

---

## Key File Reference

| File                                  | Purpose                                      |
|---------------------------------------|----------------------------------------------|
| `config/docker-compose.yml.template`  | DUMB container definition (no credentials)   |
| `config/dumb_config.json.template`    | Enable/disable DUMB internal services        |
| `config/.env.template`               | Credential variable list (all values empty)  |
| `scripts/lib/common.sh`              | Shared helpers: logging, SSH, error handling |
| `scripts/deploy-all.sh`              | Single entry point for full install          |
| `scripts/uninstall.sh`               | Full teardown                                |
| `tests/run-all-tests.sh`             | Validate entire installation                 |
| `docs/PRD.md`                        | Requirements and success criteria            |
| `docs/INSTALLATION.md`              | Human step-by-step guide                     |

---

## Post-Install Manual Steps

After `deploy-all.sh` and tests pass, complete these in a browser:

1. **Plex** `http://192.168.50.55:32400/web` — sign in, claim server
2. **Overseerr** `http://192.168.50.55:5055` — connect to Plex + Radarr/Sonarr
3. **Prowlarr** `http://192.168.50.55:9696` — add indexers, sync to Radarr/Sonarr
4. **Decypharr** `http://192.168.50.55:8082` — verify Real-Debrid connection
5. **Radarr** `http://192.168.50.55:7878` → Settings → Import Lists → add Plex Watchlist
6. **Sonarr** `http://192.168.50.55:8989` → Settings → Import Lists → add Plex Watchlist
7. Add a movie to your Plex Watchlist — verify Radarr picks it up within 15 minutes
