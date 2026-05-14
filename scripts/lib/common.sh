#!/usr/bin/env bash
# Shared helpers for DUMB installer scripts

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Connection defaults (override via env before sourcing) ────────────────────
PI_HOST="${PI_HOST:-192.168.50.55}"
PI_USER="${PI_USER:-pi}"
PI_SSH_KEY="${PI_SSH_KEY:-${HOME}/.ssh/id_ed25519_dumb}"

# ── Logging ───────────────────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_section() { echo -e "\n${BOLD}══════════════════════════════════════${RESET}"; echo -e "${BOLD} $*${RESET}"; echo -e "${BOLD}══════════════════════════════════════${RESET}"; }
log_step()    { echo -e "\n${YELLOW}▶ $*${RESET}"; }

# ── SSH / SCP helpers ─────────────────────────────────────────────────────────
_ssh_opts() {
  local opts=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
  [[ -n "${PI_SSH_KEY}" ]] && opts+=(-i "${PI_SSH_KEY}")
  echo "${opts[@]}"
}

pi_ssh() {
  # Usage: pi_ssh 'remote command'
  # shellcheck disable=SC2046
  ssh $(_ssh_opts) "${PI_USER}@${PI_HOST}" "$@"
}

pi_ssh_script() {
  # Upload and run a local script remotely via stdin
  # Usage: pi_ssh_script scripts/01-system-update.sh [env_overrides...]
  local script="$1"; shift
  local env_vars="${*:-}"
  # shellcheck disable=SC2046
  ssh $(_ssh_opts) "${PI_USER}@${PI_HOST}" "${env_vars} bash -s" < "${script}"
}

pi_scp() {
  # Usage: pi_scp local_file remote_path
  local src="$1" dst="$2"
  # shellcheck disable=SC2046
  scp $(_ssh_opts) "${src}" "${PI_USER}@${PI_HOST}:${dst}"
}

pi_scp_dir() {
  # Recursively copy a local directory to the Pi
  local src="$1" dst="$2"
  # shellcheck disable=SC2046
  scp -r $(_ssh_opts) "${src}" "${PI_USER}@${PI_HOST}:${dst}"
}

# ── Prerequisite checker ──────────────────────────────────────────────────────
require_local_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" &>/dev/null; then
    log_error "Required local command not found: ${cmd}"
    return 1
  fi
  log_ok "Local command available: ${cmd}"
}

# ── SSH connectivity test ─────────────────────────────────────────────────────
check_ssh_connectivity() {
  log_step "Testing SSH connectivity to ${PI_USER}@${PI_HOST} ..."
  if pi_ssh 'echo connected' &>/dev/null; then
    log_ok "SSH connection successful"
  else
    log_error "Cannot reach ${PI_USER}@${PI_HOST} via SSH"
    log_error "Ensure the Pi is powered on, on the network, and SSH is enabled"
    exit 1
  fi
}

# ── Pass/fail tracker (used by run-all-tests.sh) ─────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0

assert_pass() {
  local label="$1"
  PASS_COUNT=$(( PASS_COUNT + 1 ))
  echo -e "  ${GREEN}PASS${RESET}  ${label}"
}

assert_fail() {
  local label="$1" reason="${2:-}"
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  echo -e "  ${RED}FAIL${RESET}  ${label}${reason:+ — ${reason}}"
}

print_test_summary() {
  echo ""
  echo -e "${BOLD}Test Summary${RESET}"
  echo -e "  ${GREEN}Passed: ${PASS_COUNT}${RESET}"
  echo -e "  ${RED}Failed: ${FAIL_COUNT}${RESET}"
  if [[ ${FAIL_COUNT} -gt 0 ]]; then
    exit 1
  fi
}

# ── Human-interactive pause ───────────────────────────────────────────────────
wait_for_human() {
  local msg="${1:-Press ENTER when ready to continue...}"
  echo -e "\n${YELLOW}[HUMAN ACTION REQUIRED]${RESET} ${msg}"
  read -r -p "" _
}
