#!/usr/bin/env bash
# Step 03 — Create directory structure on the Pi
# Safe to re-run (mkdir -p is idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "Step 03 — Setup Directories"

check_ssh_connectivity

log_step "Creating /opt/dumb directory structure on Pi..."

pi_ssh "PI_USER=${PI_USER}" 'bash -s' <<'REMOTE'
set -euo pipefail

INSTALL_DIR="/opt/dumb"

echo "→ Creating directory structure under ${INSTALL_DIR}..."
sudo mkdir -p \
  "${INSTALL_DIR}/config/decypharr" \
  "${INSTALL_DIR}/data" \
  "${INSTALL_DIR}/data/threadfin" \
  "${INSTALL_DIR}/data/hyperhdr" \
  "${INSTALL_DIR}/log"

echo "→ Setting ownership to ${PI_USER:-pi}..."
OWNER="${PI_USER:-pi}"
sudo chown -R "${OWNER}:${OWNER}" "${INSTALL_DIR}"

echo "→ Configuring FUSE to allow user mounts (needed for DFS)..."
FUSE_CONF="/etc/fuse.conf"
if ! grep -q "^user_allow_other" "${FUSE_CONF}" 2>/dev/null; then
  echo "user_allow_other" | sudo tee -a "${FUSE_CONF}" > /dev/null
  echo "  Added user_allow_other to ${FUSE_CONF}"
else
  echo "  user_allow_other already set in ${FUSE_CONF}"
fi

echo ""
echo "Directory layout:"
find "${INSTALL_DIR}" -type d | sort | sed 's|^|  |'
echo ""
echo "Directory setup complete."
REMOTE

log_ok "Step 03 complete — directories created."
