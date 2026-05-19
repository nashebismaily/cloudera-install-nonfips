#!/bin/bash
set -uo pipefail

echo "==== Validation ===="
echo "Host: $(hostname -f || hostname)"
echo "OS: $(cat /etc/redhat-release)"
echo "Architecture: $(uname -m 2>/dev/null || true)"
echo "Python: $(python3 --version 2>/dev/null || echo missing)"
echo "Java:"
java -version || true
echo "SELinux: $(getenforce 2>/dev/null || true)"
echo "firewalld enabled: $(systemctl is-enabled firewalld 2>/dev/null || true)"
echo "THP:"
cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
echo "Time sync:"
timedatectl || true
chronyc tracking || true
echo "Limits:"
ulimit -n || true
echo "DNF repos:"
dnf repolist || true
echo "PostgreSQL services:"
systemctl status postgresql-* --no-pager 2>/dev/null || true
echo "Cloudera services:"
systemctl status cloudera-scm-server cloudera-scm-agent --no-pager 2>/dev/null || true
echo "==== Done ===="
