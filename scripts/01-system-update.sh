#!/usr/bin/env bash
# Step 01 — System update and install required packages
# Safe to re-run (apt is idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "Step 01 — System Update"

check_ssh_connectivity

log_step "Running apt update + upgrade and installing dependencies on Pi..."

pi_ssh 'bash -s' <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "→ apt-get update"
sudo apt-get update -qq

echo "→ apt-get upgrade"
sudo apt-get upgrade -y -qq

echo "→ Installing required packages"
sudo apt-get install -y -qq \
  fuse3 \
  curl \
  git \
  ca-certificates \
  gettext-base \
  gnupg \
  lsb-release \
  apt-transport-https

echo "→ Verifying fuse3"
fusermount3 --version || fusermount --version

echo ""
echo "System update complete."
REMOTE

log_ok "Step 01 complete — system updated."
