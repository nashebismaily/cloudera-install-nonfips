#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/cloudera-bootstrap"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/12_start_cm_services_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

CM_DEFAULTS_FILE="/etc/default/cloudera-scm-server"

echo "==== Starting Cloudera services ===="

echo "==== Configuring Cloudera Manager defaults ===="

touch "$CM_DEFAULTS_FILE"

if ! grep -Eq '^[[:space:]]*export[[:space:]]+CMF_FF_PREVENT_HOST_HEADER_INJECTION=' "$CM_DEFAULTS_FILE"; then
  echo 'export CMF_FF_PREVENT_HOST_HEADER_INJECTION="false"' >> "$CM_DEFAULTS_FILE"
  echo "[OK] Added CM host header override"
else
  echo "[INFO] CM host header override already present"
fi

echo "==== Reloading systemd ===="
systemctl daemon-reload

echo "==== Enabling services ===="
systemctl enable cloudera-scm-server
systemctl enable cloudera-scm-agent

echo "==== Starting Cloudera Manager Server ===="
systemctl restart cloudera-scm-server

echo "==== Starting Cloudera Manager Agent ===="
systemctl restart cloudera-scm-agent

echo "==== Waiting for CM port 7180 ===="

CM_READY=false

for i in {1..60}; do
  if ss -plnt | grep -q ":7180"; then
    echo "[OK] CM listening on 7180"
    CM_READY=true
    break
  fi

  echo "[INFO] Waiting for CM startup... attempt $i/60"
  sleep 5
done

if [[ "$CM_READY" != "true" ]]; then
  echo "[ERROR] CM did not start listening on port 7180"
  exit 1
fi

echo
echo "==== Service Validation ===="

systemctl status cloudera-scm-server --no-pager || true
systemctl status cloudera-scm-agent --no-pager || true

echo
echo "==== Listening Ports ===="
ss -plnt | egrep '5432|7180|9000|9443' || true

echo
echo "==== PostgreSQL Check ===="
sudo -u postgres psql -c "SELECT version();" || true

echo
echo "==== CM HTTP Check ===="
curl -I http://localhost:7180 || true

echo
echo "==== Filesystem Check ===="
df -h

echo
echo "[OK] Bootstrap completed"

PRIVATE_IP=$(hostname -I | awk '{print $1}')

echo "CM UI (private): http://${PRIVATE_IP}:7180"
echo "Default Login: admin / admin"

echo
echo "Log file: $LOG_FILE"
