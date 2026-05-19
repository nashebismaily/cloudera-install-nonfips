#!/bin/bash

#export ALLOW_EXTERNAL=true
#export ENABLE_PGDG=true
#export PG_MAJOR=14
#export PGDATA_DIR=/data/postgres14
#export ALLOWED_CIDR=10.0.0.0/20

set -euo pipefail

PG_MAJOR="${PG_MAJOR:-14}"
PGDATA_DIR="${PGDATA_DIR:-/var/lib/pgsql/${PG_MAJOR}/data}"
USE_PGDG="${USE_PGDG:-true}"

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/05_install_postgres_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Installing PostgreSQL ${PG_MAJOR}"
echo "PGDATA_DIR=$PGDATA_DIR"

if [[ "$USE_PGDG" == "true" ]]; then
  if ! rpm -q pgdg-redhat-repo >/dev/null 2>&1; then
    echo "[INFO] PGDG repo not present. Install it first if you want PGDG packages."
  fi
fi

dnf install -y "postgresql${PG_MAJOR}-server" "postgresql${PG_MAJOR}" "postgresql${PG_MAJOR}-contrib"

POSTGRES_BIN="/usr/pgsql-${PG_MAJOR}/bin/initdb"
if [[ ! -x "$POSTGRES_BIN" ]]; then
  echo "[ERROR] Expected initdb not found at $POSTGRES_BIN"
  exit 1
fi

if [[ ! -d "$PGDATA_DIR" || -z "$(ls -A "$PGDATA_DIR" 2>/dev/null || true)" ]]; then
  mkdir -p "$PGDATA_DIR"
  chown -R postgres:postgres "$PGDATA_DIR"
  chmod 700 "$PGDATA_DIR"
  sudo -u postgres "$POSTGRES_BIN" -D "$PGDATA_DIR" --encoding=UTF8 --locale=en_US.UTF-8
else
  echo "[INFO] PGDATA_DIR already initialized or contains files, skipping initdb"
fi

mkdir -p "/etc/systemd/system/postgresql-${PG_MAJOR}.service.d"
cat <<EOF >/etc/systemd/system/postgresql-${PG_MAJOR}.service.d/override.conf
[Service]
Environment=PGDATA=${PGDATA_DIR}
EOF

systemctl daemon-reload
systemctl enable "postgresql-${PG_MAJOR}"
systemctl restart "postgresql-${PG_MAJOR}"

echo "[OK] PostgreSQL ${PG_MAJOR} installed and started"
echo "Log file: $LOG_FILE"

dnf list postgresql14-server
