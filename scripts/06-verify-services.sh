#!/usr/bin/env bash
# Step 06 — Verify all DUMB services are reachable
# Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "Step 06 — Verify Services"

check_ssh_connectivity

log_step "Checking DUMB container status..."
pi_ssh "sudo docker ps --filter name=dumb --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo ""
log_step "Checking service endpoints (from Pi)..."

check_service() {
  local name="$1" port="$2" path="${3:-/}"
  local url="http://localhost:${port}${path}"
  if pi_ssh "curl -sf --max-time 10 '${url}' > /dev/null 2>&1"; then
    log_ok "${name} responding at :${port}"
  else
    log_warn "${name} not yet responding at :${port} (may still be initializing)"
  fi
}

# Allow services time to initialize if just started
echo "Waiting 30s for services to initialize..."
sleep 30

check_service "Plex"       32400 "/web"
check_service "Decypharr"  8082  "/"
check_service "Radarr"     7878  "/"
check_service "Sonarr"     8989  "/"
check_service "Prowlarr"   9696  "/"
check_service "Overseerr"  5055  "/"
check_service "Profilarr"  6868  "/"
check_service "Threadfin"  34400 "/"

echo ""
log_step "Checking logs for errors..."
pi_ssh "sudo docker logs dumb --tail 20 2>&1" || true

echo ""
log_ok "Step 06 complete — verification done."
echo ""
echo "Access services at:"
echo "  Plex:       http://${PI_HOST}:32400/web"
echo "  Overseerr:  http://${PI_HOST}:5055"
echo "  Radarr:     http://${PI_HOST}:7878"
echo "  Sonarr:     http://${PI_HOST}:8989"
echo "  Prowlarr:   http://${PI_HOST}:9696"
echo "  Decypharr:  http://${PI_HOST}:8082
  Profilarr:  http://${PI_HOST}:6868
  Threadfin:  http://${PI_HOST}:34400"
