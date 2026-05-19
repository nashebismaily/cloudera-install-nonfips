#!/bin/bash
set -uo pipefail

LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/03_configure_os_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

DISABLE_SELINUX="${DISABLE_SELINUX:-false}"
DISABLE_FIREWALLD="${DISABLE_FIREWALLD:-true}"

echo "==== OS tuning ===="

if [[ "$DISABLE_SELINUX" == "true" ]]; then
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config || true
  setenforce 0 || true
  echo "[INFO] SELinux disabled by request"
else
  echo "[INFO] SELinux left unchanged"
fi

if [[ "$DISABLE_FIREWALLD" == "true" ]]; then
  systemctl stop firewalld || true
  systemctl disable firewalld || true
  echo "[INFO] firewalld disabled"
else
  echo "[INFO] firewalld left unchanged"
fi

cat <<'EOF' >/etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then echo never > /sys/kernel/mm/transparent_hugepage/enabled; fi; if [ -f /sys/kernel/mm/transparent_hugepage/defrag ]; then echo never > /sys/kernel/mm/transparent_hugepage/defrag; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload || true
systemctl enable disable-thp.service || true
systemctl restart disable-thp.service || true

cat <<'EOF' >/etc/sysctl.d/90-cloudera.conf
vm.swappiness=1
fs.file-max=1000000
vm.max_map_count=262144
net.core.somaxconn=65535
EOF

sysctl --system || true

mkdir -p /etc/systemd/system.conf.d
cat <<'EOF' >/etc/systemd/system.conf.d/99-cloudera-limits.conf
[Manager]
DefaultLimitNOFILE=65536
DefaultLimitNPROC=65536
EOF

cat <<'EOF' >/etc/security/limits.d/99-cloudera.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

systemctl daemon-reexec || true

echo "==== OS tuning complete ===="
echo "Log file: $LOG_FILE"

cat /sys/kernel/mm/transparent_hugepage/enabled
sysctl vm.swappiness
ulimit -n
