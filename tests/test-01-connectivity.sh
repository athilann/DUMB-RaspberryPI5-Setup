#!/usr/bin/env bash
# Test 01 — SSH connectivity to Raspberry Pi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 01: SSH Connectivity"

RESULT=$(pi_ssh 'echo "pong"' 2>/dev/null || echo "")
if [[ "${RESULT}" == "pong" ]]; then
  assert_pass "SSH connection to ${PI_USER}@${PI_HOST}"
else
  assert_fail "SSH connection to ${PI_USER}@${PI_HOST}" "Cannot reach host"
  print_test_summary
  exit 1
fi

ARCH=$(pi_ssh 'uname -m' 2>/dev/null || echo "unknown")
if [[ "${ARCH}" == "aarch64" ]]; then
  assert_pass "Architecture is aarch64 (ARM64)"
else
  assert_fail "Architecture check" "Expected aarch64, got ${ARCH}"
fi

print_test_summary
