# DUMB Raspberry Pi 5 Setup

Automated SSH-based installer for [DUMB](https://github.com/I-am-PUID-0/DUMB) (Debrid Unlimited
Media Bridge) on a **Raspberry Pi 5**, with Real-Debrid integration and Plex streaming.

## What This Does

Deploys a fully-automated media stack on your Pi 5 in one command:

```
Plex Watchlist ──────────────────────────────────────┐
                                                      ↓
Overseerr (request UI) ──────────────────→ Radarr / Sonarr / Prowlarr
                                                      ↓
                            Decypharr + DFS (Real-Debrid virtual filesystem)
                                                      ↓
                                           Plex Media Server
```

- **Add to Plex Watchlist** → auto-downloads via Real-Debrid
- **Request via Overseerr** → routes through Radarr/Sonarr → Real-Debrid
- **Decypharr File System (DFS)** serves content directly — no rclone FUSE mount needed

## Requirements

- Raspberry Pi 5 running Raspberry Pi OS Bookworm 64-bit
- SSH access to `192.168.50.55`
- [Real-Debrid](https://real-debrid.com) account + API token
- [Plex](https://plex.tv) account

Local machine needs: `ssh`, `scp`, `envsubst` (part of `gettext`)

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/athilann/DUMB-RaspberryPI5-Setup.git
cd DUMB-RaspberryPI5-Setup

# 2. Run the full installer (prompts for credentials)
bash scripts/deploy-all.sh

# 3. Validate the installation
bash tests/run-all-tests.sh
```

## Services After Install

| Service    | URL                              |
|------------|----------------------------------|
| Plex       | http://192.168.50.55:32400/web   |
| Overseerr  | http://192.168.50.55:5055        |
| Radarr     | http://192.168.50.55:7878        |
| Sonarr     | http://192.168.50.55:8989        |
| Prowlarr   | http://192.168.50.55:9696        |
| Decypharr  | http://192.168.50.55:8082        |

## Individual Steps

```bash
bash scripts/00-check-prerequisites.sh   # Verify Pi is reachable and meets requirements
bash scripts/01-system-update.sh         # Update system packages
bash scripts/02-install-docker.sh        # Install Docker CE
bash scripts/03-setup-directories.sh     # Create /opt/dumb structure
bash scripts/04-configure-env.sh         # Enter credentials (never committed to git)
bash scripts/05-deploy-stack.sh          # Deploy DUMB Docker stack
bash scripts/06-verify-services.sh       # Confirm all services running
```

## Uninstall

```bash
bash scripts/uninstall.sh
```

Stops all containers, removes images, deletes `/opt/dumb`. Optionally removes Docker.

## Security

Credentials are **never stored in this repository**. The `.env` file is gitignored and only
lives locally and on the Pi. See [CLAUDE.md](CLAUDE.md) for the full credential policy.

## Documentation

- [Installation Guide](docs/INSTALLATION.md) — step-by-step with screenshots guidance
- [PRD](docs/PRD.md) — requirements and success criteria
- [DUMB Official Docs](https://dumbarr.com)

## License

GPL-3.0 — see [LICENSE](LICENSE)
