#!/usr/bin/env bash
set -euo pipefail

PG_MAJOR="${PG_MAJOR:-14}"
PGDATA_DIR="${PGDATA_DIR:-/data/postgres14}"
ALLOWED_CIDR="${ALLOWED_CIDR:-10.0.0.0/20}"

LOG_DIR="/var/log/cloudera-bootstrap"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/06_configure_postgres_networking_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

POSTGRESQL_CONF="${PGDATA_DIR}/postgresql.conf"
PG_HBA_CONF="${PGDATA_DIR}/pg_hba.conf"

if [[ ! -f "$POSTGRESQL_CONF" ]]; then
  echo "[ERROR] PostgreSQL config not found: $POSTGRESQL_CONF"
  exit 1
fi

if [[ ! -f "$PG_HBA_CONF" ]]; then
  echo "[ERROR] PostgreSQL pg_hba.conf not found: $PG_HBA_CONF"
  exit 1
fi

echo "==== Configuring PostgreSQL Networking ===="
echo "PG_MAJOR=${PG_MAJOR}"
echo "PGDATA_DIR=${PGDATA_DIR}"
echo "ALLOWED_CIDR=${ALLOWED_CIDR}"
echo

echo "==== Updating listen_addresses ===="

if grep -qE "^[#[:space:]]*listen_addresses[[:space:]]*=" "$POSTGRESQL_CONF"; then
  sed -i "s|^[#[:space:]]*listen_addresses[[:space:]]*=.*|listen_addresses = '*'|" "$POSTGRESQL_CONF"
else
  echo "listen_addresses = '*'" >> "$POSTGRESQL_CONF"
fi

grep -n "^listen_addresses" "$POSTGRESQL_CONF" || true
echo "[OK] listen_addresses configured"
echo

append_pg_hba_rule() {
  local RULE="$1"

  if grep -Fq "$RULE" "$PG_HBA_CONF"; then
    echo "[OK] pg_hba rule already exists: $RULE"
  else
    echo "$RULE" >> "$PG_HBA_CONF"
    echo "[OK] Added pg_hba rule: $RULE"
  fi
}

echo "==== Updating pg_hba.conf ===="

if ! grep -Fq "# Cloudera DB Access" "$PG_HBA_CONF"; then
  echo "" >> "$PG_HBA_CONF"
  echo "# Cloudera DB Access" >> "$PG_HBA_CONF"
fi

append_pg_hba_rule "host    scm         scm         ${ALLOWED_CIDR}        md5"
append_pg_hba_rule "host    rman        rman        ${ALLOWED_CIDR}        md5"
append_pg_hba_rule "host    nifireg     nifireg     ${ALLOWED_CIDR}        md5"
append_pg_hba_rule "host    all         all         ${ALLOWED_CIDR}        md5"

echo
echo "==== Restarting PostgreSQL ===="

POSTGRES_SERVICE="postgresql-${PG_MAJOR}.service"

systemctl daemon-reload
systemctl enable "$POSTGRES_SERVICE" || true

if systemctl restart "$POSTGRES_SERVICE"; then
  echo "[OK] Restarted ${POSTGRES_SERVICE}"
else
  echo "[WARN] PostgreSQL restart failed for ${POSTGRES_SERVICE}"
  systemctl status "$POSTGRES_SERVICE" -l --no-pager || true
fi

sleep 3

echo
echo "==== PostgreSQL Service Status ===="
systemctl status "$POSTGRES_SERVICE" -l --no-pager || true

echo
echo "==== PostgreSQL Listener ===="
ss -lntp | grep 5432 || true

if ss -lntp | grep 5432 | grep -Eq "0.0.0.0:5432|\*:5432|\[::\]:5432"; then
  echo "[OK] PostgreSQL is listening on the network."
else
  echo "[WARN] PostgreSQL is not listening on the network."
  echo "[WARN] Expected 0.0.0.0:5432 or [::]:5432."
  echo "[WARN] Current listener:"
  ss -lntp | grep 5432 || true
fi

echo
echo "==== PostgreSQL Effective Config ===="

if systemctl is-active --quiet "$POSTGRES_SERVICE"; then
  sudo -u postgres psql -c "SHOW data_directory;" || true
  sudo -u postgres psql -c "SHOW config_file;" || true
  sudo -u postgres psql -c "SHOW hba_file;" || true
  sudo -u postgres psql -c "SHOW listen_addresses;" || true
else
  echo "[WARN] PostgreSQL service is not active, skipping effective config validation"
fi

echo
echo "==== PostgreSQL Validation ===="
sudo -u postgres psql -c "SELECT version();" || true

echo
echo "==== pg_hba.conf Tail ===="
tail -20 "$PG_HBA_CONF"

echo
echo "[OK] PostgreSQL networking configured for ${ALLOWED_CIDR}"
echo "Log file: $LOG_FILE"