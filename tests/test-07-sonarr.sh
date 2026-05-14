#!/usr/bin/env bash
# Test 07 — Sonarr responding

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 07: Sonarr"

HTTP_STATUS=$(pi_ssh 'curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:8989/ 2>/dev/null' || echo "000")
if [[ "${HTTP_STATUS}" =~ ^(200|302|401)$ ]]; then
  assert_pass "Sonarr responding at :8989 (HTTP ${HTTP_STATUS})"
else
  assert_fail "Sonarr not responding at :8989" "HTTP status: ${HTTP_STATUS}"
fi

print_test_summary
