#!/usr/bin/env bash
# Step 00 — Check prerequisites (local tools + Pi specs via SSH)
# Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "Step 00 — Check Prerequisites"

# ── Local tool checks ─────────────────────────────────────────────────────────
log_step "Checking required local tools..."
MISSING=0
for cmd in ssh scp envsubst curl; do
  if command -v "${cmd}" &>/dev/null; then
    log_ok "  ${cmd}"
  else
    log_error "  ${cmd} — NOT FOUND"
    MISSING=$(( MISSING + 1 ))
  fi
done

if [[ ${MISSING} -gt 0 ]]; then
  log_error "${MISSING} required local tool(s) missing."
  echo "Install hints:"
  echo "  macOS:  brew install gettext openssh curl"
  echo "  Ubuntu: sudo apt install gettext openssh-client curl"
  echo "  Windows (WSL/Git Bash): same as Ubuntu"
  exit 1
fi

# ── SSH connectivity ──────────────────────────────────────────────────────────
check_ssh_connectivity

# ── Remote system checks ──────────────────────────────────────────────────────
log_step "Checking Pi hardware and OS..."

pi_ssh 'bash -s' <<'REMOTE'
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; RESET='\033[0m'
ok()  { echo -e "  ${GREEN}OK${RESET}  $*"; }
err() { echo -e "  ${RED}FAIL${RESET} $*" >&2; exit 1; }

# Architecture
ARCH="$(uname -m)"
if [[ "${ARCH}" == "aarch64" ]]; then
  ok "Architecture: ${ARCH} (ARM64)"
else
  err "Expected aarch64, got ${ARCH}. This installer requires a 64-bit Raspberry Pi OS."
fi

# OS check
if grep -qi "bookworm\|debian" /etc/os-release 2>/dev/null; then
  PRETTY=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  ok "OS: ${PRETTY}"
else
  err "Expected Raspberry Pi OS Bookworm (Debian). Found: $(cat /etc/os-release | head -1)"
fi

# RAM
TOTAL_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
if [[ ${TOTAL_MB} -ge 2048 ]]; then
  ok "RAM: ${TOTAL_MB} MB"
else
  err "Insufficient RAM: ${TOTAL_MB} MB. Minimum 2048 MB required."
fi

# Disk space on /
FREE_GB=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
if [[ ${FREE_GB} -ge 20 ]]; then
  ok "Free disk on /: ${FREE_GB} GB"
else
  err "Insufficient free disk: ${FREE_GB} GB. Minimum 20 GB required."
fi

# /dev/fuse presence (needed for DFS)
if [[ -e /dev/fuse ]]; then
  ok "/dev/fuse present"
else
  err "/dev/fuse not found. Kernel may not support FUSE. Try: sudo modprobe fuse"
fi

echo ""
echo "All Pi checks passed."
REMOTE

log_ok "All prerequisite checks passed."
