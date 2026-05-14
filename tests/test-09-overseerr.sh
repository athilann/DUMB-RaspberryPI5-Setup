#!/usr/bin/env bash
# Test 09 — Overseerr responding

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 09: Overseerr"

HTTP_STATUS=$(pi_ssh 'curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:5055/ 2>/dev/null' || echo "000")
if [[ "${HTTP_STATUS}" =~ ^(200|301|302|303|307)$ ]]; then
  assert_pass "Overseerr responding at :5055 (HTTP ${HTTP_STATUS})"
else
  assert_fail "Overseerr not responding at :5055" "HTTP status: ${HTTP_STATUS}"
fi

print_test_summary
