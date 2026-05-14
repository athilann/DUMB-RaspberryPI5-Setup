# Installation Guide — DUMB on Raspberry Pi 5

## Overview

This guide walks through installing DUMB (Debrid Unlimited Media Bridge) on a Raspberry Pi 5
with Real-Debrid and Plex. The installer handles everything via SSH from your local machine.

**Total time:** ~20–30 minutes (plus Docker image download time)

---

## Prerequisites

### Raspberry Pi 5
- Raspberry Pi OS **Bookworm 64-bit** installed (not 32-bit)
- SSH enabled (enabled by default on recent Pi OS images, or via `sudo raspi-config`)
- Connected to your local network
- IP address: `192.168.50.55` (verify with `hostname -I` on the Pi)
- At least 20 GB free disk space

### Accounts You Need
- [Real-Debrid](https://real-debrid.com) account (paid subscription)
- [Plex](https://plex.tv) account (free)

### Local Machine
Your computer needs these tools installed:

| Tool | Install (macOS) | Install (Ubuntu/WSL) |
|------|-----------------|----------------------|
| `ssh` / `scp` | Built-in | `sudo apt install openssh-client` |
| `envsubst` | `brew install gettext` | `sudo apt install gettext-base` |
| `curl` | Built-in | `sudo apt install curl` |

On Windows: use **WSL2** or **Git Bash** (Git for Windows includes all required tools).

---

## Step 0 — Prepare Your Credentials

Before running the installer, gather these three tokens:

### Real-Debrid API Token
1. Log in to [real-debrid.com](https://real-debrid.com)
2. Go to **My Account → API token**
3. Copy the token (keep it secret)

### Plex Claim Token
> **Important:** Claim tokens expire in 4 minutes. Get this immediately before running Step 04.

1. Go to [plex.tv/claim](https://plex.tv/claim)
2. Copy the token that starts with `claim-`

### Plex Authentication Token
Used by Radarr/Sonarr to sync your Plex Watchlist.

1. Sign in to [plex.tv](https://plex.tv)
2. Visit: `https://plex.tv/auth/resources?includeRelays=1`
3. In the JSON response, find `"authToken": "YOUR_TOKEN_HERE"`
4. Alternatively: open Plex Web → Account → click your avatar → the URL contains `X-Plex-Token=...`

---

## Step 1 — Clone the Repository

```bash
git clone https://github.com/athilann/DUMB-RaspberryPI5-Setup.git
cd DUMB-RaspberryPI5-Setup
```

---

## Step 2 — Quick Install (Recommended)

Run the master installer. It will run all steps in order and prompt for credentials at Step 04:

```bash
bash scripts/deploy-all.sh
```

The installer will:
1. Check your local tools and Pi connectivity
2. Update the Pi's system packages
3. Install Docker CE on the Pi
4. Create the `/opt/dumb` directory structure
5. **Prompt you for credentials** (RD token, Plex claim, Plex token)
6. Deploy the DUMB Docker stack
7. Verify all services are running

If any step fails, fix the issue and re-run `deploy-all.sh` — all steps are idempotent.

---

## Step 3 — Alternative: Run Steps Individually

If you prefer to run steps one at a time:

```bash
# Check your local tools and Pi specs
bash scripts/00-check-prerequisites.sh

# Update system packages on the Pi
bash scripts/01-system-update.sh

# Install Docker CE (ARM64) on the Pi
bash scripts/02-install-docker.sh

# Create /opt/dumb directory structure
bash scripts/03-setup-directories.sh

# Enter credentials — get your Plex Claim token NOW before running this
bash scripts/04-configure-env.sh

# Deploy the DUMB Docker stack
bash scripts/05-deploy-stack.sh

# Verify all services are responding
bash scripts/06-verify-services.sh
```

---

## Step 4 — Validate the Installation

```bash
bash tests/run-all-tests.sh
```

The automated tests check connectivity, Docker, container health, and all service endpoints.
Some tests (DFS, Plex UI, Watchlist) require human confirmation — the test runner will prompt you.

---

## Step 5 — Browser Configuration

After the installer completes, configure each service in your browser:

### 5.1 — Plex
1. Open [http://192.168.50.55:32400/web](http://192.168.50.55:32400/web)
2. Sign in with your Plex account
3. The server will be automatically claimed using the `PLEX_CLAIM` token you provided
4. Add a library pointing to your media folder (Decypharr DFS will provide paths)

### 5.2 — Prowlarr (Indexers)
1. Open [http://192.168.50.55:9696](http://192.168.50.55:9696)
2. Complete the setup wizard
3. Add your preferred indexers (e.g., YTS for movies, EZTV for TV)
4. Go to **Settings → Apps** and add Radarr and Sonarr connections
5. Click **Sync App Indexers** to push indexers to Radarr/Sonarr

### 5.3 — Decypharr (Real-Debrid Connection)
1. Open [http://192.168.50.55:8082](http://192.168.50.55:8082)
2. Verify your Real-Debrid API token is configured
3. Confirm the DFS virtual filesystem status shows active

### 5.4 — Radarr (Movies + Plex Watchlist)
1. Open [http://192.168.50.55:7878](http://192.168.50.55:7878)
2. Complete the setup wizard
3. Add Decypharr as a download client:
   - **Settings → Download Clients → +**
   - Type: **Decypharr** (or custom if not listed; point to `http://localhost:8082`)
4. Add Plex Watchlist as an import list:
   - **Settings → Import Lists → +**
   - Type: **Plex Watchlist**
   - Paste your `PLEX_TOKEN`
5. Set the quality profile and root folder

### 5.5 — Sonarr (TV Shows + Plex Watchlist)
1. Open [http://192.168.50.55:8989](http://192.168.50.55:8989)
2. Repeat the same setup as Radarr (download client + Plex Watchlist import list)

### 5.6 — Overseerr (Request UI)
1. Open [http://192.168.50.55:5055](http://192.168.50.55:5055)
2. Sign in with Plex
3. Configure your Plex server connection (`http://192.168.50.55:32400`)
4. Add Radarr and Sonarr as services
5. Share the Overseerr URL with other household members so they can request media

---

## Step 6 — Test Plex Watchlist

1. Open the Plex mobile app or web app
2. Find any movie and click **Add to Watchlist**
3. In Radarr: **Movies → Lists → Sync Lists** (or wait for auto-sync, up to 15 minutes)
4. The movie should appear in Radarr and be sent to Decypharr → Real-Debrid automatically

---

## Customising the Target IP / SSH User

If your Pi is at a different IP or uses a different user, set these environment variables:

```bash
PI_HOST=192.168.1.100 PI_USER=ubuntu bash scripts/deploy-all.sh
```

Or export them in your shell:

```bash
export PI_HOST=192.168.1.100
export PI_USER=ubuntu
bash scripts/deploy-all.sh
```

---

## Troubleshooting

### "Cannot reach host via SSH"
- Verify the Pi is on and connected: `ping 192.168.50.55`
- Confirm SSH is enabled on the Pi: `sudo raspi-config` → Interface Options → SSH
- Try connecting manually: `ssh pi@192.168.50.55`

### "Docker container not starting"
- Check container logs: `ssh pi@192.168.50.55 'sudo docker logs dumb'`
- Verify `/dev/fuse` exists: `ssh pi@192.168.50.55 'ls -la /dev/fuse'`
- Confirm SYS_ADMIN capability is allowed on the Pi

### "Service not responding"
- Services take 1–3 minutes to initialize after the container starts
- Check which processes are running inside DUMB: `ssh pi@192.168.50.55 'sudo docker exec dumb ps aux'`

### "Plex Claim token expired"
- Re-run step 04: `bash scripts/04-configure-env.sh`
- Get a fresh token from [plex.tv/claim](https://plex.tv/claim) immediately before pasting

### "Plex Watchlist not syncing to Radarr"
- Confirm your `PLEX_TOKEN` is correct in the Radarr import list settings
- Trigger a manual sync: Radarr → Movies → Lists → Sync Lists
- Check Radarr logs for auth errors

---

## Uninstall

To remove everything from the Pi:

```bash
bash scripts/uninstall.sh
```

This stops all containers, removes the DUMB image, and deletes `/opt/dumb`. You will be
prompted whether to also remove Docker.

---

## Security Notes

- All credentials are stored only in `.env` (gitignored, mode 600) and `/opt/dumb/.env` (mode 600 on Pi)
- No credentials are ever written to this repository
- The `.env` file is excluded from git by `.gitignore` — verify with `git status` before committing
- Consider using SSH key authentication for the Pi instead of password auth
