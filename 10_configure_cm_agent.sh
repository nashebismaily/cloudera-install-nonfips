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

systemctl enable cloudera-scm-agent
systemctl restart cloudera-scm-agent

echo "[OK] Agent configured to point at ${MANAGER_HOST_ARG}"
echo "Log file: $LOG_FILE"
grep '^server_host=' "$CONFIG_FILE"
