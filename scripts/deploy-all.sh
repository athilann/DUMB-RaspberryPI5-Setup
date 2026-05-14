#!/usr/bin/env bash
# Master installer — runs all steps 00–06 via SSH against the Raspberry Pi 5
# Usage: bash scripts/deploy-all.sh
#        PI_HOST=x.x.x.x PI_USER=pi bash scripts/deploy-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

log_section "DUMB Raspberry Pi 5 — Full Installer"
echo "  Target: ${PI_USER}@${PI_HOST}"
echo "  Date:   $(date)"
echo ""

STEPS=(
  "00-check-prerequisites.sh"
  "01-system-update.sh"
  "02-install-docker.sh"
  "03-setup-directories.sh"
  "04-configure-env.sh"
  "05-deploy-stack.sh"
  "06-verify-services.sh"
)

STEP_RESULTS=()

run_step() {
  local script="${SCRIPT_DIR}/${1}"
  local label="$1"

  if [[ ! -f "${script}" ]]; then
    log_error "Script not found: ${script}"
    STEP_RESULTS+=("SKIP  ${label} (file missing)")
    return 1
  fi

  log_section "Step: ${label}"
  if bash "${script}"; then
    STEP_RESULTS+=("OK    ${label}")
    log_ok "Step completed: ${label}"
  else
    STEP_RESULTS+=("FAIL  ${label}")
    log_error "Step failed: ${label}"
    echo ""
    echo "Installation stopped. Fix the error above and re-run:"
    echo "  bash scripts/${label}"
    echo "Or restart from scratch:"
    echo "  bash scripts/deploy-all.sh"
    exit 1
  fi
}

for step in "${STEPS[@]}"; do
  run_step "${step}"
done

log_section "Installation Complete"
echo ""
for result in "${STEP_RESULTS[@]}"; do
  if [[ "${result}" == OK* ]]; then
    echo -e "  ${GREEN}${result}${RESET}"
  else
    echo -e "  ${RED}${result}${RESET}"
  fi
done

echo ""
echo -e "${BOLD}Next steps (manual, in browser):${RESET}"
echo "  1. Plex       http://${PI_HOST}:32400/web  — sign in and claim server"
echo "  2. Overseerr  http://${PI_HOST}:5055        — connect Plex + Radarr/Sonarr"
echo "  3. Prowlarr   http://${PI_HOST}:9696        — add indexers"
echo "  4. Decypharr  http://${PI_HOST}:8082        — verify Real-Debrid connection"
echo "  5. Radarr     http://${PI_HOST}:7878        — Settings → Import Lists → Plex Watchlist"
echo "  6. Sonarr     http://${PI_HOST}:8989        — Settings → Import Lists → Plex Watchlist"
echo ""
echo "Run tests: bash tests/run-all-tests.sh"
