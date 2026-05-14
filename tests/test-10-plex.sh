#!/usr/bin/env bash
# Test 10 — Plex responding + human validation of Watchlist integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 10: Plex + Watchlist Integration"

# ── Automated: HTTP check ─────────────────────────────────────────────────────
HTTP_STATUS=$(pi_ssh 'curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:32400/web 2>/dev/null' || echo "000")
if [[ "${HTTP_STATUS}" =~ ^(200|301|302)$ ]]; then
  assert_pass "Plex web responding at :32400 (HTTP ${HTTP_STATUS})"
else
  assert_fail "Plex web not responding at :32400" "HTTP status: ${HTTP_STATUS} — Plex may still be initializing"
fi

# ── Human: Plex login ─────────────────────────────────────────────────────────
echo ""
wait_for_human "Open http://${PI_HOST}:32400/web and sign in with your Plex account. Confirm the server appears. Press ENTER when done."
assert_pass "Human confirmed Plex web UI accessible and signed in"

# ── Human: Plex Watchlist → Radarr ───────────────────────────────────────────
echo ""
echo "Plex Watchlist Integration Test:"
echo "  1. In Radarr (http://${PI_HOST}:7878):"
echo "     Settings → Import Lists → confirm a 'Plex Watchlist' import list exists"
echo "  2. Add any movie to your Plex Watchlist"
echo "  3. In Radarr → Movies → check if the movie appears within ~15 minutes"
echo "     (Radarr syncs the Watchlist on its configured schedule)"
echo ""
wait_for_human "Confirm Radarr has a Plex Watchlist import list configured. Press ENTER when confirmed."
assert_pass "Human confirmed Plex Watchlist import list configured in Radarr"

echo ""
wait_for_human "Add a test movie to your Plex Watchlist now, then press ENTER to continue."
assert_pass "Human added test movie to Plex Watchlist"

echo ""
echo "NOTE: Radarr will pick up the Watchlist item on its next sync (up to 15 minutes)."
echo "      You can manually trigger a sync in Radarr: Movies → Lists → Sync Lists"
wait_for_human "Confirm the test movie appeared in Radarr. Press ENTER when confirmed (or 's' to skip)."
assert_pass "Human confirmed Plex Watchlist → Radarr sync working"

print_test_summary
