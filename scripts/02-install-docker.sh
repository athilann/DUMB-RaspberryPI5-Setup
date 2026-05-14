#!/usr/bin/env bash
# Step 02 — Install Docker CE + Compose v2 on the Pi
# Safe to re-run (skips if Docker already installed).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "Step 02 — Install Docker"

check_ssh_connectivity

log_step "Installing Docker CE on Pi (ARM64)..."

pi_ssh 'bash -s' <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if command -v docker &>/dev/null; then
  echo "Docker already installed: $(docker --version)"
  echo "Skipping installation."
else
  echo "→ Downloading and running Docker install script..."
  curl -fsSL https://get.docker.com | sudo sh

  echo "→ Adding current user to docker group..."
  sudo usermod -aG docker "${USER}"

  echo "→ Enabling and starting Docker service..."
  sudo systemctl enable docker
  sudo systemctl start docker
fi

echo "→ Verifying Docker..."
# Use sudo in case group change hasn't taken effect in this session
sudo docker --version
sudo docker compose version

echo "→ Running hello-world container to confirm Docker works..."
sudo docker run --rm hello-world 2>&1 | grep -E "Hello from Docker|error" || true

echo ""
echo "Docker installation complete."
REMOTE

log_ok "Step 02 complete — Docker installed."
log_warn "NOTE: The 'pi' user was added to the docker group."
log_warn "A new SSH session may be needed for group membership to take effect."
