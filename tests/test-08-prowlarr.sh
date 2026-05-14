#!/usr/bin/env bash
# Test 08 — Prowlarr responding

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 08: Prowlarr"

HTTP_STATUS=$(pi_ssh 'curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:9696/ 2>/dev/null' || echo "000")
if [[ "${HTTP_STATUS}" =~ ^(200|302|401)$ ]]; then
  assert_pass "Prowlarr responding at :9696 (HTTP ${HTTP_STATUS})"
else
  assert_fail "Prowlarr not responding at :9696" "HTTP status: ${HTTP_STATUS}"
fi

print_test_summary
