#!/bin/bash
set -euo pipefail

#export CLOUDERA_REPO_USER='your_cloudera_username'
#export CLOUDERA_REPO_PASS='your_cloudera_password'

CM_VERSION="${CM_VERSION:-7.13.2.0}"
CLOUDERA_REPO_USER="${CLOUDERA_REPO_USER:-}"
CLOUDERA_REPO_PASS="${CLOUDERA_REPO_PASS:-}"
ENABLE_CFM_NOTE="${ENABLE_CFM_NOTE:-true}"

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/08_add_cloudera_repos_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

if [[ -z "$CLOUDERA_REPO_USER" ]]; then
  read -r -p "Enter Cloudera archive username: " CLOUDERA_REPO_USER
fi
if [[ -z "$CLOUDERA_REPO_PASS" ]]; then
  read -r -s -p "Enter Cloudera archive password: " CLOUDERA_REPO_PASS
  echo
fi

BASE_URL="https://${CLOUDERA_REPO_USER}:${CLOUDERA_REPO_PASS}@archive.cloudera.com/p/cm7/${CM_VERSION}/redhat9/yum"

if ! curl -k -I -L --connect-timeout 8 --max-time 20 "$BASE_URL/" >/dev/null 2>&1; then
  echo "[ERROR] Cloudera repo base URL is not reachable with supplied credentials"
  exit 1
fi

if ! curl -k -L -o /etc/yum.repos.d/cloudera-manager.repo "${BASE_URL}/cloudera-manager.repo"; then
  echo "[ERROR] Failed to download cloudera-manager.repo"
  exit 1
fi

sed -i "s#https://archive.cloudera.com#https://${CLOUDERA_REPO_USER}:${CLOUDERA_REPO_PASS}@archive.cloudera.com#g" /etc/yum.repos.d/cloudera-manager.repo

rpm --import "${BASE_URL}/RPM-GPG-KEY-cloudera" || true
dnf clean all || true
dnf makecache || true

echo "[OK] Cloudera Manager repo configured for version ${CM_VERSION}"
echo

if [[ "$ENABLE_CFM_NOTE" == "true" ]]; then
  echo "[INFO] CFM 4.12.0 is usually added in Cloudera Manager as a remote parcel URL and by placing CSD jars on the CM server."
  echo "[INFO] This script configures only the CM package repo for server and agent installation."
fi

echo "Log file: $LOG_FILE"

dnf repolist | grep -i cloudera

