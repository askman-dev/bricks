#!/usr/bin/env bash
set -euo pipefail

# Installs the Bricks sandbox runner on a single Vultr/Dokku host.
# Run from the Bricks repository root on the server.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER_DIR="${REPO_ROOT}/apps/node_sandbox_runner"
SERVICE_NAME="${SERVICE_NAME:-bricks-sandbox-runner}"
SERVICE_USER="${SERVICE_USER:-root}"
SANDBOX_ROOT="${SANDBOX_ROOT:-/home/bricks/data}"
RUNNER_HOST="${RUNNER_HOST:-172.17.0.1}"
RUNNER_PORT="${RUNNER_PORT:-8787}"
RUNNER_TOKEN="${RUNNER_TOKEN:-}"
SANDBOX_IMAGE="${SANDBOX_IMAGE:-node:22-bookworm}"
SANDBOX_RUNTIME="${SANDBOX_RUNTIME:-runsc}"
DOCKER_BRIDGE_INTERFACE="${DOCKER_BRIDGE_INTERFACE:-docker0}"
DOCKER_BRIDGE_CIDR="${DOCKER_BRIDGE_CIDR:-172.17.0.0/16}"

if [[ ! -f "${RUNNER_DIR}/package.json" ]]; then
  echo "Expected sandbox runner package at ${RUNNER_DIR}" >&2
  exit 1
fi

echo "==> Installing host packages"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required before installing the sandbox runner." >&2
  echo "Install Docker for this Dokku host, then re-run this script." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "Node.js and npm are required before installing the sandbox runner." >&2
  echo "Install a Node.js package that includes npm, then re-run this script." >&2
  exit 1
fi

echo "==> Installing gVisor runsc apt repository"
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://gvisor.dev/archive.key \
  | gpg --batch --yes --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" \
  > /etc/apt/sources.list.d/gvisor.list
apt-get update
apt-get install -y runsc

echo "==> Ensuring Docker runtime ${SANDBOX_RUNTIME}"
if command -v runsc >/dev/null 2>&1; then
  runsc install || true
fi
systemctl enable --now docker
systemctl reload docker || systemctl restart docker

echo "==> Preparing sandbox root ${SANDBOX_ROOT}"
mkdir -p "${SANDBOX_ROOT}"

echo "==> Building sandbox runner"
cd "${RUNNER_DIR}"
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
npm run build

echo "==> Writing systemd unit"
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Bricks gVisor sandbox runner
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${RUNNER_DIR}
Environment=NODE_ENV=production
Environment=SANDBOX_RUNNER_HOST=${RUNNER_HOST}
Environment=SANDBOX_RUNNER_PORT=${RUNNER_PORT}
Environment=SANDBOX_ROOT=${SANDBOX_ROOT}
Environment=SANDBOX_DOCKER_RUNTIME=${SANDBOX_RUNTIME}
Environment=SANDBOX_IMAGE=${SANDBOX_IMAGE}
$(if [[ -n "${RUNNER_TOKEN}" ]]; then printf 'Environment=SANDBOX_RUNNER_TOKEN=%s\n' "${RUNNER_TOKEN}"; fi)
ExecStart=/usr/bin/node ${RUNNER_DIR}/dist/index.js
Restart=always
RestartSec=5
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

echo "==> Verifying runner health"
for attempt in {1..20}; do
  if curl -fsS "http://${RUNNER_HOST}:${RUNNER_PORT}/healthz"; then
    break
  fi
  if [[ "${attempt}" == "20" ]]; then
    echo "Sandbox runner did not become healthy." >&2
    systemctl status "${SERVICE_NAME}" --no-pager -l >&2 || true
    exit 1
  fi
  sleep 1
done
echo

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q '^Status: active'; then
  echo "==> Allowing Docker bridge access to sandbox runner"
  ufw allow in on "${DOCKER_BRIDGE_INTERFACE}" proto tcp \
    from "${DOCKER_BRIDGE_CIDR}" to "${RUNNER_HOST}" port "${RUNNER_PORT}" \
    comment "Bricks sandbox runner from Dokku containers"
fi

echo "==> Verifying runsc Docker runtime"
docker run --rm --runtime="${SANDBOX_RUNTIME}" hello-world >/dev/null

echo "Sandbox runner installed and verified."
