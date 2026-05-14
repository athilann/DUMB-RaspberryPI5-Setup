#!/usr/bin/env bash
# Test 03 — DUMB container is running

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 03: DUMB Container"

CONTAINER_STATUS=$(pi_ssh 'sudo docker ps --filter name=dumb --filter status=running --format "{{.Names}}" 2>/dev/null' || echo "")
if [[ "${CONTAINER_STATUS}" == *"dumb"* ]]; then
  assert_pass "DUMB container is running"
else
  assert_fail "DUMB container is not running" "Run: bash scripts/05-deploy-stack.sh"
fi

CONTAINER_IMAGE=$(pi_ssh 'sudo docker ps --filter name=dumb --format "{{.Image}}" 2>/dev/null' || echo "")
if [[ "${CONTAINER_IMAGE}" == *"iampuid0/dumb"* ]]; then
  assert_pass "Correct image: ${CONTAINER_IMAGE}"
else
  assert_fail "Unexpected image: ${CONTAINER_IMAGE}"
fi

INSTALL_DIR_EXISTS=$(pi_ssh '[ -d /opt/dumb ] && echo yes || echo no' 2>/dev/null || echo "no")
if [[ "${INSTALL_DIR_EXISTS}" == "yes" ]]; then
  assert_pass "/opt/dumb directory exists"
else
  assert_fail "/opt/dumb directory missing" "Run: bash scripts/03-setup-directories.sh"
fi

print_test_summary
