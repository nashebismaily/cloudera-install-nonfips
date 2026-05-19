#!/bin/bash

#export CM_DB_PASS='ClouderaCM_2026'
#export RM_DB_PASS='Rman_DB_2026'
#export REG_DB_PASS='Registry_DB_2026'

set -euo pipefail

CM_DB_NAME="${CM_DB_NAME:-scm}"
CM_DB_USER="${CM_DB_USER:-scm}"
CM_DB_PASS="${CM_DB_PASS:-ClouderaCM_2026}"

RM_DB_NAME="${RM_DB_NAME:-rman}"
RM_DB_USER="${RM_DB_USER:-rman}"
RM_DB_PASS="${RM_DB_PASS:-Rman_DB_2026}"

REG_DB_NAME="${REG_DB_NAME:-nifireg}"
REG_DB_USER="${REG_DB_USER:-nifireg}"
REG_DB_PASS="${REG_DB_PASS:-Registry_DB_2026}"

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/07_create_cm_and_registry_dbs_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Creating CM and NiFi Registry databases/users"

create_role_if_needed() {
  local role_name="$1"
  local role_pass="$2"
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${role_name}'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE ROLE ${role_name} LOGIN PASSWORD '${role_pass}';"
  else
    echo "[INFO] Role ${role_name} already exists"
  fi
}

create_db_if_needed() {
  local db_name="$1"
  local db_owner="$2"
  if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_owner} ENCODING 'UTF8';"
  else
    echo "[INFO] Database ${db_name} already exists"
  fi
}

create_role_if_needed "$CM_DB_USER" "$CM_DB_PASS"
create_db_if_needed "$CM_DB_NAME" "$CM_DB_USER"

create_role_if_needed "$RM_DB_USER" "$RM_DB_PASS"
create_db_if_needed "$RM_DB_NAME" "$RM_DB_USER"

create_role_if_needed "$REG_DB_USER" "$REG_DB_PASS"
create_db_if_needed "$REG_DB_NAME" "$REG_DB_USER"

echo "[OK] Databases and roles created if absent"
echo
echo "Next steps:"
echo "1. CM packages installed on manager host"
echo "2. Run scm_prepare_database.sh to create CM tables"
echo "3. Configure NiFi Registry JDBC properties in Cloudera Manager; Registry creates its schema on first start"
echo
echo "Log file: $LOG_FILE"

sudo -u postgres psql -l
