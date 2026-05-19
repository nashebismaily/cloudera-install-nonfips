#!/bin/bash
set -uo pipefail

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/02_install_common_packages_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

COMMON_PACKAGES=(
  wget curl vim tar unzip bind-utils net-tools lsof which rsync jq
  chrony rng-tools nmap-ncat tcpdump telnet perl iproute rpcbind
  python3.11 python3.11-pip python3-psycopg2
)

echo "Installing common packages"

FAILED_PACKAGES=()
for pkg in "${COMMON_PACKAGES[@]}"; do
  echo "---- Installing: $pkg"
  if ! dnf install -y "$pkg"; then
    echo "[WARN] Failed to install $pkg"
    FAILED_PACKAGES+=("$pkg")
  fi
done

if [[ -x /usr/bin/python3.11 ]]; then
  alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 20 || true
else
  echo "[WARN] /usr/bin/python3.11 not found, skipping alternatives setup"
fi

systemctl enable chronyd || true
systemctl restart chronyd || true

systemctl enable rngd || true
systemctl restart rngd || true

echo
echo "Completed common package installation"
if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  echo "[WARN] Packages that failed: ${FAILED_PACKAGES[*]}"
fi
echo "Log file: $LOG_FILE"

python3 --version
which nc
which nslookup
which host
which jq
