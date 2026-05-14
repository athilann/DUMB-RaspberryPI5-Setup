#!/usr/bin/env bash
# Master test runner — runs all tests and prints a summary

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TESTS_DIR}/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "DUMB Installation Test Suite"
echo "  Target: ${PI_USER}@${PI_HOST}"
echo "  Date:   $(date)"
echo ""

TESTS=(
  "test-01-connectivity.sh"
  "test-02-docker.sh"
  "test-03-containers.sh"
  "test-04-decypharr.sh"
  "test-05-dfs-mount.sh"
  "test-06-radarr.sh"
  "test-07-sonarr.sh"
  "test-08-prowlarr.sh"
  "test-09-overseerr.sh"
  "test-10-plex.sh"
)

TOTAL_PASS=0
TOTAL_FAIL=0
SKIPPED=0

run_test() {
  local test_file="${TESTS_DIR}/${1}"
  local label="$1"

  if [[ ! -f "${test_file}" ]]; then
    echo -e "  ${YELLOW}SKIP${RESET}  ${label} (file not found)"
    SKIPPED=$(( SKIPPED + 1 ))
    return
  fi

  echo ""
  echo -e "${BOLD}Running: ${label}${RESET}"
  if bash "${test_file}"; then
    TOTAL_PASS=$(( TOTAL_PASS + 1 ))
  else
    TOTAL_FAIL=$(( TOTAL_FAIL + 1 ))
    echo -e "  ${RED}Test failed: ${label}${RESET}"
  fi
}

for test in "${TESTS[@]}"; do
  run_test "${test}"
done

echo ""
log_section "Test Summary"
echo -e "  ${GREEN}Passed:  ${TOTAL_PASS}${RESET}"
echo -e "  ${RED}Failed:  ${TOTAL_FAIL}${RESET}"
[[ ${SKIPPED} -gt 0 ]] && echo -e "  ${YELLOW}Skipped: ${SKIPPED}${RESET}"

if [[ ${TOTAL_FAIL} -gt 0 ]]; then
  echo ""
  log_error "Some tests failed. Review output above."
  exit 1
else
  echo ""
  log_ok "All tests passed."
fi
