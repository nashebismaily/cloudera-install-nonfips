#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
log_init "11_prepare_cm_database"
need_root

CM_DB_NAME="${CM_DB_NAME:-scm}"
CM_DB_USER="${CM_DB_USER:-scm}"
CM_DB_PASS="${CM_DB_PASS:-changeme_scm}"

if [[ ! -x /opt/cloudera/cm/schema/scm_prepare_database.sh ]]; then
  echo "[ERROR] scm_prepare_database.sh not found. Install Cloudera Manager packages first."
  exit 1
fi

if [[ ! -f /usr/share/java/postgresql-connector-java.jar && ! -f /usr/share/java/postgresql.jar ]]; then
  echo "[WARN] PostgreSQL JDBC jar not found in common locations. Verify JDBC availability before continuing."
fi

echo "Running scm_prepare_database.sh for database ${CM_DB_NAME} and user ${CM_DB_USER}"
/opt/cloudera/cm/schema/scm_prepare_database.sh postgresql "${CM_DB_NAME}" "${CM_DB_USER}" "${CM_DB_PASS}"

echo "[OK] CM database initialized. Tables created by scm_prepare_database.sh"
echo "Log file: $LOG_FILE"
