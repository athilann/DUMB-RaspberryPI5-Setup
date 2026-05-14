#!/usr/bin/env bash
# Test 05 — Decypharr File System (DFS) virtual filesystem
# Requires a valid Real-Debrid token and at least one item in the RD library.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 05: Decypharr File System (DFS)"
echo ""
echo "NOTE: This test checks that the DFS virtual filesystem is active."
echo "      It requires a valid Real-Debrid API token and at least one"
echo "      item cached in your Real-Debrid account."
echo ""

# Check that the DUMB container is running first
RUNNING=$(pi_ssh 'sudo docker ps --filter name=dumb --filter status=running --format "{{.Names}}" 2>/dev/null' || echo "")
if [[ "${RUNNING}" != *"dumb"* ]]; then
  assert_fail "DFS check skipped" "DUMB container is not running — run test-03 first"
  print_test_summary
  exit 1
fi

# Check DFS status via Decypharr API
DFS_STATUS=$(pi_ssh 'curl -s --max-time 10 http://localhost:8082/ 2>/dev/null | head -c 200' || echo "")
if [[ -n "${DFS_STATUS}" ]]; then
  assert_pass "Decypharr DFS endpoint is reachable"
else
  assert_fail "Decypharr DFS endpoint not reachable" "Decypharr may still be initializing"
fi

# Check DUMB container logs for DFS-related startup messages
DFS_LOG=$(pi_ssh 'sudo docker logs dumb 2>&1 | grep -i "dfs\|decypharr\|filesystem" | tail -5' || echo "")
if [[ -n "${DFS_LOG}" ]]; then
  assert_pass "DFS activity found in container logs"
  echo "  Recent DFS log entries:"
  echo "${DFS_LOG}" | sed 's/^/    /'
else
  assert_fail "No DFS log entries found" "Check: ssh ${PI_USER}@${PI_HOST} 'sudo docker logs dumb 2>&1 | grep -i dfs'"
fi

echo ""
wait_for_human "Open http://${PI_HOST}:8082 in a browser and confirm Decypharr shows your Real-Debrid library. Press ENTER when confirmed."
assert_pass "Human confirmed Decypharr Real-Debrid library visible"

print_test_summary
