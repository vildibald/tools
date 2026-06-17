#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-prometheus.sh
#
# Creates /opt/prometheus with:
#   - prometheus.yml          (basic scrape config)
#   - compose.yaml            (Docker Compose: tmpfs storage, 8 GB RAM cap)
#   - systemd unit            (auto-starts the compose stack on boot)
#
# Then enables and starts the systemd service.
#
# SECURITY NOTE: Prometheus listens on 0.0.0.0:9090 with no built-in auth.
#   Place behind a reverse proxy or firewall in production.
###############################################################################

# ─── Dependency checks ──────────────────────────────────────────────────────
if [[ "${EUID:-}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if ! command -v docker &>/dev/null; then
    echo "ERROR: 'docker' is not installed or not in PATH."
    exit 1
fi

if ! docker compose version &>/dev/null; then
    echo "ERROR: Docker Compose v2 is not available."
    exit 1
fi

if ! command -v systemctl &>/dev/null; then
    echo "ERROR: 'systemctl' is not available. This system does not use systemd."
    exit 1
fi

DOCKER_BIN="$(command -v docker)"

# Detect the correct Docker systemd service (apt vs. snap)
if systemctl is-active docker.service &>/dev/null; then
    DOCKER_SERVICE="docker.service"
elif systemctl is-active snap.docker.dockerd.service &>/dev/null; then
    DOCKER_SERVICE="snap.docker.dockerd.service"
else
    echo "WARNING: No Docker systemd service detected. The systemd unit may not work."
    DOCKER_SERVICE=""
fi

# ─── Paths ───────────────────────────────────────────────────────────────────
PROM_DIR="/opt/prometheus"
UNIT_FILE="/etc/systemd/system/prometheus-compose.service"

# ─── Helpers ─────────────────────────────────────────────────────────────────
backup_if_exists() {
    local f="$1"
    if [[ -f "$f" ]]; then
        local ts
        ts="$(date +%Y%m%d%H%M%S)"
        cp -a "$f" "${f}.bak.${ts}"
        echo "    (backed up existing file to ${f}.bak.${ts})"
    fi
}

# ─── Create directory ───────────────────────────────────────────────────────
echo "==> Creating Prometheus directory: ${PROM_DIR}"
mkdir -p "${PROM_DIR}"

# ─── prometheus.yml ─────────────────────────────────────────────────────────
echo "==> Writing ${PROM_DIR}/prometheus.yml"
backup_if_exists "${PROM_DIR}/prometheus.yml"
cat > "${PROM_DIR}/prometheus.yml" <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
          - localhost:9090
EOF

# ─── compose.yaml ───────────────────────────────────────────────────────────
echo "==> Writing ${PROM_DIR}/compose.yaml"
backup_if_exists "${PROM_DIR}/compose.yaml"
cat > "${PROM_DIR}/compose.yaml" <<'EOF'
services:
  prometheus:
    image: prom/prometheus:v2.55.0
    container_name: prometheus
    user: root
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.size=5GB
      - --web.listen-address=0.0.0.0:9090
    ports:
      - "0.0.0.0:9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    tmpfs:
      - /prometheus:size=6g
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 8g
EOF

# ─── systemd unit ───────────────────────────────────────────────────────────
echo "==> Writing systemd unit: ${UNIT_FILE}"
backup_if_exists "${UNIT_FILE}"
cat > "${UNIT_FILE}" <<EOF
[Unit]
Description=Prometheus Docker Compose Service
Requires=${DOCKER_SERVICE}
Wants=network-online.target
After=${DOCKER_SERVICE} network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${PROM_DIR}
ExecStart=${DOCKER_BIN} compose up -d
ExecStop=${DOCKER_BIN} compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# ─── Enable & start ─────────────────────────────────────────────────────────
echo "==> Reloading systemd daemon"
systemctl daemon-reload

echo "==> Enabling prometheus-compose.service"
systemctl enable prometheus-compose.service

echo "==> Starting prometheus-compose.service"
if systemctl start prometheus-compose.service; then
    echo "==> Service started via systemd."
else
    echo "==> systemd start failed (Docker may not be managed by systemd)."
    echo "==> Disabling systemd unit and falling back to direct compose start..."
    systemctl disable prometheus-compose.service --now 2>/dev/null || true
    docker compose -f "${PROM_DIR}/compose.yaml" up -d
    echo "==> Compose stack started directly. Re-enable the systemd unit on a systemd host."
fi

echo "==> Setup complete. Prometheus is available at http://localhost:9090"
