#!/usr/bin/env bash
# Uninstall — stops DUMB, removes containers/images, deletes /opt/dumb
# Run from your local machine. Optionally removes Docker itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "DUMB Uninstaller"

echo ""
echo -e "${RED}WARNING: This will destroy all DUMB data on ${PI_HOST}${RESET}"
echo ""
echo "This will:"
echo "  • Stop and remove all DUMB containers"
echo "  • Remove the DUMB Docker image"
echo "  • Delete /opt/dumb (config, data, logs)"
echo ""
read -r -p "Type 'yes' to confirm: " CONFIRM

if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

check_ssh_connectivity

# ── Stop and remove containers ────────────────────────────────────────────────
log_step "Stopping and removing DUMB Docker stack..."
pi_ssh 'bash -s' <<'REMOTE'
set -euo pipefail

COMPOSE_FILE="/opt/dumb/docker-compose.yml"

if [[ -f "${COMPOSE_FILE}" ]]; then
  echo "→ Running docker compose down..."
  cd /opt/dumb
  sudo docker compose down --rmi all --volumes --remove-orphans 2>&1 || true
else
  echo "→ No docker-compose.yml found; stopping container by name if running..."
  sudo docker stop dumb 2>/dev/null || true
  sudo docker rm   dumb 2>/dev/null || true
fi

echo "→ Removing DUMB image if still present..."
sudo docker rmi iampuid0/dumb:latest 2>/dev/null || true

echo "Docker cleanup done."
REMOTE

# ── Remove install directory ──────────────────────────────────────────────────
log_step "Removing /opt/dumb..."
pi_ssh "sudo rm -rf /opt/dumb"
log_ok "/opt/dumb removed"

# ── Local cleanup ─────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ -f "${REPO_ROOT}/.env" ]]; then
  read -r -p "Delete local .env file? [y/N]: " DEL_ENV
  if [[ "${DEL_ENV}" =~ ^[Yy]$ ]]; then
    rm -f "${REPO_ROOT}/.env"
    log_ok "Local .env deleted"
  fi
fi

# ── Optional: remove Docker ───────────────────────────────────────────────────
echo ""
read -r -p "Also remove Docker from the Pi? [y/N]: " REMOVE_DOCKER
if [[ "${REMOVE_DOCKER}" =~ ^[Yy]$ ]]; then
  log_step "Removing Docker from Pi..."
  pi_ssh 'bash -s' <<'REMOTE'
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true
sudo rm -rf /var/lib/docker /etc/docker /var/run/docker.sock
echo "Docker removed."
REMOTE
  log_ok "Docker removed from Pi"
fi

echo ""
log_ok "Uninstall complete. The Pi has been cleaned up."
