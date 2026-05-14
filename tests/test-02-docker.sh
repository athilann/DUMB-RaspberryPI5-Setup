#!/usr/bin/env bash
# Test 02 — Docker and Docker Compose installed and running

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

echo "Test 02: Docker Installation"

DOCKER_VERSION=$(pi_ssh 'sudo docker --version 2>/dev/null' || echo "")
if [[ "${DOCKER_VERSION}" == *"Docker version"* ]]; then
  assert_pass "Docker installed: ${DOCKER_VERSION}"
else
  assert_fail "Docker not installed" "Run: bash scripts/02-install-docker.sh"
fi

COMPOSE_VERSION=$(pi_ssh 'sudo docker compose version 2>/dev/null' || echo "")
if [[ "${COMPOSE_VERSION}" == *"Docker Compose version"* ]]; then
  assert_pass "Docker Compose installed: ${COMPOSE_VERSION}"
else
  assert_fail "Docker Compose not installed" "Compose v2 required"
fi

DOCKER_RUNNING=$(pi_ssh 'sudo systemctl is-active docker 2>/dev/null' || echo "inactive")
if [[ "${DOCKER_RUNNING}" == "active" ]]; then
  assert_pass "Docker service is active"
else
  assert_fail "Docker service is not running" "Run: ssh pi@${PI_HOST} 'sudo systemctl start docker'"
fi

print_test_summary
