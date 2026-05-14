#!/usr/bin/env bash
# Step 05 — Deploy DUMB Docker Compose stack on the Pi
# Safe to re-run (docker compose up -d is idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log_section "Step 05 — Deploy Stack"

ENV_FILE="${REPO_ROOT}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
  log_error ".env not found at ${ENV_FILE}"
  log_error "Run step 04 first: bash scripts/04-configure-env.sh"
  exit 1
fi

check_ssh_connectivity

# ── Copy config templates to Pi ───────────────────────────────────────────────
log_step "Copying config templates to Pi..."

pi_scp "${REPO_ROOT}/config/docker-compose.yml.template"     "/opt/dumb/docker-compose.yml.template"
pi_scp "${REPO_ROOT}/config/dumb_config.json.template"       "/opt/dumb/config/dumb_config.json.template"
pi_scp "${REPO_ROOT}/config/decypharr_config.json.template"  "/opt/dumb/config/decypharr_config.json.template"

log_ok "Templates copied"

# ── Render templates on Pi using envsubst ─────────────────────────────────────
log_step "Rendering config templates on Pi..."

pi_ssh 'bash -s' <<'REMOTE'
set -euo pipefail

INSTALL_DIR="/opt/dumb"

# Load environment variables from .env
if [[ ! -f "${INSTALL_DIR}/.env" ]]; then
  echo "ERROR: /opt/dumb/.env not found on Pi. Re-run step 04."
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${INSTALL_DIR}/.env"
set +a

echo "→ Rendering docker-compose.yml..."
envsubst < "${INSTALL_DIR}/docker-compose.yml.template" > "${INSTALL_DIR}/docker-compose.yml"

echo "→ Rendering dumb_config.json..."
envsubst < "${INSTALL_DIR}/config/dumb_config.json.template" > "${INSTALL_DIR}/config/dumb_config.json"

echo "→ Pre-creating Decypharr config with Real-Debrid credentials..."
mkdir -p "${INSTALL_DIR}/data/decypharr/cache"
chown -R "${PUID}:${PGID}" "${INSTALL_DIR}/data/decypharr" 2>/dev/null || true
# Only write if no existing config (preserve user customisations on re-runs)
if [[ ! -f "${INSTALL_DIR}/data/decypharr/config.json" ]]; then
  envsubst < "${INSTALL_DIR}/config/decypharr_config.json.template" > "${INSTALL_DIR}/data/decypharr/config.json"
  chmod 600 "${INSTALL_DIR}/data/decypharr/config.json"
  echo "  Decypharr config written."
else
  echo "  Decypharr config already exists — skipping (delete to reset)."
fi

echo "→ Protecting rendered files (600)..."
chmod 600 "${INSTALL_DIR}/docker-compose.yml"
chmod 600 "${INSTALL_DIR}/config/dumb_config.json"

echo "Templates rendered successfully."
REMOTE

log_ok "Templates rendered"

# ── Pull latest DUMB image ────────────────────────────────────────────────────
log_step "Pulling latest DUMB Docker image (iampuid0/dumb:latest)..."
pi_ssh "cd /opt/dumb && sudo docker compose pull"
log_ok "Image pulled"

# ── Start the stack ───────────────────────────────────────────────────────────
log_step "Starting DUMB stack (docker compose up -d)..."
pi_ssh "cd /opt/dumb && sudo docker compose up -d"

# ── Wait for container to be running ─────────────────────────────────────────
log_step "Waiting for DUMB container to start (up to 90 seconds)..."
TIMEOUT=90
ELAPSED=0
INTERVAL=5

until pi_ssh "sudo docker ps --filter name=dumb --filter status=running --format '{{.Names}}'" 2>/dev/null | grep -q dumb; do
  if [[ ${ELAPSED} -ge ${TIMEOUT} ]]; then
    log_error "DUMB container did not start within ${TIMEOUT} seconds."
    log_error "Check logs: ssh ${PI_USER}@${PI_HOST} 'sudo docker logs dumb'"
    exit 1
  fi
  echo "  Waiting... (${ELAPSED}s elapsed)"
  sleep ${INTERVAL}
  ELAPSED=$(( ELAPSED + INTERVAL ))
done

log_ok "DUMB container is running"

echo ""
log_ok "Step 05 complete — stack deployed."
echo ""
echo "Note: Services inside DUMB take 1–3 minutes to fully initialize."
echo "Run step 06 to verify: bash scripts/06-verify-services.sh"
