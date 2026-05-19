#!/bin/bash
set -uo pipefail

echo "==== Validation ===="
echo "Host: $(hostname -f || hostname)"
echo "OS: $(cat /etc/redhat-release)"
echo "Architecture: $(uname -m 2>/dev/null || true)"
echo "Python system default: $(python3 --version 2>/dev/null || echo missing)"
echo "Python /usr/bin/python3: $(/usr/bin/python3 --version 2>/dev/null || echo missing)"
echo "Python 3.9: $(/usr/bin/python3.9 --version 2>/dev/null || echo missing)"
echo "Python 3.11: $(/usr/bin/python3.11 --version 2>/dev/null || echo missing)"
echo "CM agent Python: $(/opt/cloudera/cm-agent/bin/python --version 2>/dev/null || echo missing)"
echo "psycopg2 system python: $(python3 -c 'import psycopg2; print(psycopg2.__version__)' 2>/dev/null || echo missing)"
echo "psycopg2 /usr/bin/python3: $(/usr/bin/python3 -c 'import psycopg2; print(psycopg2.__version__)' 2>/dev/null || echo missing)"
echo "psycopg2 CM agent Python: $(/opt/cloudera/cm-agent/bin/python -c 'import psycopg2; print(psycopg2.__version__)' 2>/dev/null || echo missing)"
echo "CM agent Python executable: $(/opt/cloudera/cm-agent/bin/python -c 'import sys; print(sys.executable)' 2>/dev/null || echo missing)"
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
systemctl status cloudera-scm-server cloudera-scm-supervisord cloudera-scm-agent --no-pager 2>/dev/null || true
echo "Listening ports:"
ss -lntp | egrep '7180|7182|7183|9000|5432' || true
echo "==== Done ===="
