#!/bin/bash

#export ALLOW_EXTERNAL=true
#export ENABLE_PGDG=true
#export PG_MAJOR=14
#export PGDATA_DIR=/var/lib/pgsql/14/data
#export ALLOWED_CIDR=10.0.0.0/8

set -euo pipefail

PG_MAJOR="${PG_MAJOR:-14}"
PGDATA_DIR="${PGDATA_DIR:-/var/lib/pgsql/${PG_MAJOR}/data}"
ALLOWED_CIDR="${ALLOWED_CIDR:-10.0.0.0/8}"

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/06_configure_postgres_networking_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

POSTGRESQL_CONF="${PGDATA_DIR}/postgresql.conf"
PG_HBA_CONF="${PGDATA_DIR}/pg_hba.conf"

if [[ ! -f "$POSTGRESQL_CONF" || ! -f "$PG_HBA_CONF" ]]; then
  echo "[ERROR] Could not find PostgreSQL config in $PGDATA_DIR"
  exit 1
fi

echo "==== Configuring PostgreSQL Networking ===="

# Enable listening on all interfaces
if grep -q "^#listen_addresses" "$POSTGRESQL_CONF"; then
  sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" "$POSTGRESQL_CONF"
elif grep -q "^listen_addresses" "$POSTGRESQL_CONF"; then
  sed -i "s/^listen_addresses.*/listen_addresses = '*'/" "$POSTGRESQL_CONF"
else
  echo "listen_addresses = '*'" >> "$POSTGRESQL_CONF"
fi

echo "[OK] listen_addresses configured"

# Add pg_hba rules if missing
append_pg_hba_rule() {
  local RULE="$1"

  if ! grep -Fq "$RULE" "$PG_HBA_CONF"; then
    echo "$RULE" >> "$PG_HBA_CONF"
    echo "[OK] Added pg_hba rule: $RULE"
  else
    echo "[SKIP] Rule already exists: $RULE"
  fi
}

echo >> "$PG_HBA_CONF"
echo "# Cloudera DB Access" >> "$PG_HBA_CONF"

append_pg_hba_rule "host    scm         scm         ${ALLOWED_CIDR}        md5"
append_pg_hba_rule "host    rman        rman        ${ALLOWED_CIDR}        md5"
append_pg_hba_rule "host    nifireg     nifireg     ${ALLOWED_CIDR}        md5"

# Optional generic access rule
append_pg_hba_rule "host    all         all         ${ALLOWED_CIDR}        md5"

# Restart PostgreSQL
echo "==== Restarting PostgreSQL ===="

if systemctl list-unit-files | grep -q "postgresql-${PG_MAJOR}"; then
  systemctl restart "postgresql-${PG_MAJOR}"
elif systemctl list-unit-files | grep -q "postgresql-${PG_MAJOR}.service"; then
  systemctl restart "postgresql-${PG_MAJOR}.service"
else
  echo "[WARN] Could not find postgresql-${PG_MAJOR} service"
  systemctl list-units --type=service | grep -i postgres || true
fi

sleep 3

echo "[OK] PostgreSQL networking configured for ${ALLOWED_CIDR}"
echo "Log file: $LOG_FILE"

echo
echo "==== PostgreSQL Listener ===="
ss -plnt | grep 5432 || true

echo
echo "==== PostgreSQL Validation ===="
sudo -u postgres psql -c "SELECT version();"

echo
echo "==== pg_hba.conf Tail ===="
tail -20 "$PG_HBA_CONF"