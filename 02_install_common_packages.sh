#!/bin/bash
set -uo pipefail

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/02_install_common_packages_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

COMMON_PACKAGES=(
  wget curl vim tar unzip bind-utils net-tools lsof which rsync jq
  chrony rng-tools nmap-ncat tcpdump telnet perl iproute rpcbind
  python3 python3-devel python3-pip python3-psycopg2
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

echo
echo "==== Preserving RHEL system Python for Cloudera Manager Agent ===="

# RHEL 9 Cloudera Manager agents expect Python 3.9. NiFi can use Python 3.11,
# but Python 3.11 must not replace /usr/bin/python3.
if [[ ! -x /usr/bin/python3 && -x /usr/bin/python3.9 ]]; then
  echo "[INFO] /usr/bin/python3 missing. Linking it to /usr/bin/python3.9."
  ln -sf /usr/bin/python3.9 /usr/bin/python3
fi

if [[ ! -x /usr/bin/python3 ]]; then
  echo "[ERROR] /usr/bin/python3 is missing. On RHEL 9 this should be Python 3.9."
  exit 1
fi

/usr/bin/python3 --version
python3 --version || true

echo
echo "==== Validating psycopg2 for Python 3 ===="
if python3 -c "import psycopg2; print(psycopg2.__version__)"; then
  echo "[OK] psycopg2 is importable from python3"
else
  echo "[WARN] psycopg2 is not importable from python3. Host Inspector may warn if using PostgreSQL-backed Hue."
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

python3 --version || true
which nc || true
which nslookup || true
which host || true
which jq || true
