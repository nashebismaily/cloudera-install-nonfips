#!/bin/bash
set -uo pipefail

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/01_bootstrap_repos_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

ALLOW_EXTERNAL="${ALLOW_EXTERNAL:-true}"
ENABLE_EPEL="${ENABLE_EPEL:-false}"
ENABLE_PGDG="${ENABLE_PGDG:-true}"

echo "==== Repo bootstrap starting ===="
echo "ALLOW_EXTERNAL=$ALLOW_EXTERNAL ENABLE_EPEL=$ENABLE_EPEL ENABLE_PGDG=$ENABLE_PGDG"

dnf clean all || true
dnf repolist || true

if [[ "$ALLOW_EXTERNAL" != "true" ]]; then
  echo "[INFO] External repo enablement disabled. Logging current repo state only."
  exit 0
fi

if [[ "$ENABLE_EPEL" == "true" ]]; then
  if curl -k -I -L --connect-timeout 8 --max-time 20 https://dl.fedoraproject.org/pub/epel/ >/dev/null 2>&1; then
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm || echo "[WARN] EPEL install failed"
    echo "[OK] EPEL bootstrap attempted"
  else
    echo "[WARN] EPEL endpoint unreachable, skipping"
  fi
fi

if [[ "$ENABLE_PGDG" == "true" ]]; then
  if curl -k -I -L --connect-timeout 8 --max-time 20 https://download.postgresql.org/pub/repos/yum/ >/dev/null 2>&1; then
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm || echo "[WARN] PGDG repo package install failed"
    dnf -qy module disable postgresql || true
    echo "[OK] PGDG EL9 repo bootstrap attempted"
  else
    echo "[WARN] PGDG endpoint unreachable, skipping"
  fi
fi

dnf makecache || true
echo "==== Repo bootstrap complete ===="
echo "Log file: $LOG_FILE"
