#!/usr/bin/env bash
# Test 04 — Decypharr service responding

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 04: Decypharr"

HTTP_STATUS=$(pi_ssh 'curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:8082/ 2>/dev/null' || echo "000")
if [[ "${HTTP_STATUS}" =~ ^(200|301|302|303|307|401|403)$ ]]; then
  assert_pass "Decypharr responding at :8082 (HTTP ${HTTP_STATUS})"
else
  assert_fail "Decypharr not responding at :8082" "HTTP status: ${HTTP_STATUS} — service may still be initializing"
fi

print_test_summary
