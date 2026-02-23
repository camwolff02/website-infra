#!/usr/bin/env bash
set -euo pipefail

# Config (override if you want)
HOST_PORT="${HOST_PORT:-800}"
SERVICE_NAME="${SERVICE_NAME:-website}"
URL="http://localhost:${HOST_PORT}/"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

require docker
require curl

# Ensure docker compose v2 exists
docker compose version >/dev/null 2>&1 || {
  echo "ERROR: 'docker compose' not available (need Docker Compose v2)." >&2
  exit 1
}

cleanup() {
  # Stop the stack (keep volume by default to avoid re-downloading LFS every commit)
  docker compose down --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Building image via docker compose..."
docker compose build

echo "==> Starting stack on localhost:${HOST_PORT}..."
HOST_PORT="${HOST_PORT}" docker compose up -d --force-recreate

# Ensure container is running (not exited)
CID="$(docker compose ps -q "${SERVICE_NAME}" || true)"
if [ -z "${CID}" ]; then
  echo "ERROR: Could not find container for service '${SERVICE_NAME}'." >&2
  docker compose ps || true
  exit 1
fi

STATUS="$(docker inspect -f '{{.State.Status}}' "${CID}" 2>/dev/null || true)"
if [ "${STATUS}" != "running" ]; then
  echo "ERROR: Container is not running (status=${STATUS})." >&2
  echo "---- docker logs (${SERVICE_NAME}) ----" >&2
  docker compose logs --no-color --tail=200 "${SERVICE_NAME}" || true
  exit 1
fi

echo "==> Waiting for HTTP to come up at ${URL} ..."
ok=0
for i in $(seq 1 30); do
  if curl -fsS "${URL}" >/dev/null; then
    ok=1
    break
  fi
  sleep 1
done

if [ "${ok}" -ne 1 ]; then
  echo "ERROR: Website did not become reachable at ${URL} within 30s." >&2
  echo "---- docker logs (${SERVICE_NAME}) ----" >&2
  docker compose logs --no-color --tail=200 "${SERVICE_NAME}" || true
  exit 1
fi

echo "==> HTTP reachable ✅"

# Optional: sanity check that index.pck isn't an LFS pointer file
# (Fast: only fetch the first ~200 bytes)
if curl -fsS --range 0-200 "${URL}index.pck" | grep -a -q "git-lfs.github.com/spec/v1"; then
  echo "ERROR: index.pck appears to be a Git LFS pointer, not the real binary." >&2
  exit 1
fi

echo "==> index.pck looks real ✅"

echo "==> Smoke test passed."
