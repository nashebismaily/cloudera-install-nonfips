#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/lib/common.sh"

ROLE="${1:-}"
log_init "09_install_cm_packages_${ROLE:-unknown}"
need_root

if [[ "$ROLE" != "manager" && "$ROLE" != "agent" ]]; then
  echo "Usage: sudo -E bash 09_install_cm_packages.sh [manager|agent]"
  exit 1
fi

FAILED_PACKAGES=()
install_pkg() {
  local pkg="$1"
  echo "---- Installing: $pkg"
  if ! dnf install -y "$pkg"; then
    echo "[WARN] Failed to install $pkg"
    FAILED_PACKAGES+=("$pkg")
  fi
}

if [[ "$ROLE" == "manager" ]]; then
  install_pkg cloudera-manager-server
  install_pkg cloudera-manager-daemons
  install_pkg cloudera-manager-agent
fi

if [[ "$ROLE" == "agent" ]]; then
  install_pkg cloudera-manager-agent
fi

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  echo "[WARN] Packages that failed: ${FAILED_PACKAGES[*]}"
fi

echo "[OK] CM package installation attempted for role ${ROLE}"
echo "Log file: $LOG_FILE"
