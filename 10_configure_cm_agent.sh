#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

MANAGER_HOST_ARG="${1:-}"
log_init "10_configure_cm_agent"
need_root

if [[ -z "$MANAGER_HOST_ARG" ]]; then
  echo "Usage: sudo -E bash 10_configure_cm_agent.sh <manager-hostname>"
  exit 1
fi

CONFIG_FILE="/etc/cloudera-scm-agent/config.ini"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] $CONFIG_FILE not found. Install cloudera-manager-agent first."
  exit 1
fi

if grep -q "^server_host=" "$CONFIG_FILE"; then
  sed -i "s/^server_host=.*/server_host=${MANAGER_HOST_ARG}/" "$CONFIG_FILE"
else
  echo "server_host=${MANAGER_HOST_ARG}" >> "$CONFIG_FILE"
fi

echo "==== Configuring CM agent Python for RHEL 9 ===="

# RHEL 9 CM agents require Python 3.9. Keep Python 3.11 available for NiFi,
# but do not make it the CM agent Python.
if [[ ! -x /usr/bin/python3 && -x /usr/bin/python3.9 ]]; then
  echo "[INFO] /usr/bin/python3 missing. Linking it to /usr/bin/python3.9."
  ln -sf /usr/bin/python3.9 /usr/bin/python3
fi

if [[ ! -x /usr/bin/python3 ]]; then
  echo "[ERROR] /usr/bin/python3 is missing. On RHEL 9 this should be Python 3.9."
  exit 1
fi

ln -sf /usr/bin/python3 /opt/cloudera/cm-agent/bin/python
chown -h root:root /opt/cloudera/cm-agent/bin/python

echo "System python:"
/usr/bin/python3 --version

echo "CM agent python:"
/opt/cloudera/cm-agent/bin/python --version

echo "==== Installing psycopg2 into CM agent Python environment ===="

# CM Host Inspector checks psycopg2 from the CM agent Python environment.
# On RHEL 9, system python3 can have python3-psycopg2 installed while the
# /opt/cloudera/cm-agent/bin/python environment still cannot import psycopg2.
# Installing psycopg2-binary here clears the Hue/PostgreSQL Host Inspector warning.
if [[ -x /opt/cloudera/cm-agent/bin/python ]]; then
  /opt/cloudera/cm-agent/bin/python -m pip --version || true
  /opt/cloudera/cm-agent/bin/python -m ensurepip --upgrade || true
  /opt/cloudera/cm-agent/bin/python -m pip install --upgrade "psycopg2-binary>=2.9.5"

  echo "==== Validating psycopg2 from CM agent Python ===="
  /opt/cloudera/cm-agent/bin/python -c "import sys; print(sys.executable); import psycopg2; print(psycopg2.__version__)"
else
  echo "[ERROR] /opt/cloudera/cm-agent/bin/python does not exist"
  exit 1
fi

echo "==== Starting Cloudera Manager agent services ===="
systemctl daemon-reload
systemctl enable cloudera-scm-supervisord || true
systemctl restart cloudera-scm-supervisord || true

systemctl enable cloudera-scm-agent
systemctl restart cloudera-scm-agent

sleep 3

echo "==== Service status ===="
systemctl status cloudera-scm-supervisord -l --no-pager || true
systemctl status cloudera-scm-agent -l --no-pager || true

echo "[OK] Agent configured to point at ${MANAGER_HOST_ARG}"
echo "Log file: $LOG_FILE"
grep '^server_host=' "$CONFIG_FILE"
