#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/lib/common.sh"
log_init "00_check_connectivity"

validate_platform_nonfips

check_tcp() {
  local host="$1"
  local port="$2"
  local name="$3"
  if command -v nc >/dev/null 2>&1; then
    if nc -zw5 "$host" "$port" >/dev/null 2>&1; then
      echo "[OK] $name reachable at $host:$port"
    else
      echo "[WARN] $name not reachable at $host:$port"
    fi
  else
    echo "[WARN] nc not installed, skipping TCP check for $name"
  fi
}

check_http() {
  local url="$1"
  local name="$2"
  if command -v curl >/dev/null 2>&1; then
    if curl -k -I -L --connect-timeout 8 --max-time 20 "$url" >/dev/null 2>&1; then
      echo "[OK] $name reachable: $url"
    else
      echo "[WARN] $name NOT reachable: $url"
    fi
  else
    echo "[WARN] curl not installed, skipping HTTP check for $name"
  fi
}

echo "==== Local identity ===="
hostname -f || true
hostname -i || true
ip route || true
echo

echo "==== Basic command checks ===="
for c in curl dnf python3 java getenforce timedatectl chronyc host nslookup nc jq; do
  warn_cmd "$c"
done
echo

echo "==== SELinux / firewalld / time sync ===="
getenforce || true
systemctl is-enabled firewalld 2>/dev/null || true
systemctl is-active firewalld 2>/dev/null || true
timedatectl || true
chronyc tracking || true
echo

echo "==== DNF repos ===="
REPOLIST_OUTPUT="$(dnf repolist 2>/dev/null || true)"
echo "$REPOLIST_OUTPUT"
echo

echo "==== Repo Architecture Validation ===="
echo "$REPOLIST_OUTPUT" | grep -E "x86_64|aarch64" || true
if echo "$REPOLIST_OUTPUT" | grep -qi aarch64; then
  echo "[WARN] ARM repo architecture detected"
fi
if echo "$REPOLIST_OUTPUT" | grep -qi x86_64; then
  echo "[OK] x86_64 repo architecture detected"
fi
echo

echo "==== External repo reachability ===="
check_http "https://cdn.redhat.com" "Red Hat CDN"
check_http "https://dl.fedoraproject.org/pub/epel/" "EPEL"
check_http "https://download.postgresql.org/pub/repos/yum/" "PostgreSQL PGDG"
check_http "https://archive.cloudera.com/" "Cloudera archive"
echo

echo "==== Cloudera repo auth probe ===="
if [[ -n "${CLOUDERA_REPO_USER:-}" && -n "${CLOUDERA_REPO_PASS:-}" ]]; then
  if curl_head_auth "${CM_REPO_BASE_URL:-https://archive.cloudera.com/p/cm7/${CM_VERSION:-7.13.2.0}/redhat9/yum/}"; then
    echo "[OK] Cloudera Manager repo reachable with supplied credentials"
  else
    echo "[WARN] Cloudera Manager repo NOT reachable with supplied credentials"
  fi
else
  echo "[INFO] CLOUDERA_REPO_USER / CLOUDERA_REPO_PASS not set, skipping authenticated Cloudera check"
fi
echo

echo "==== Optional east-west checks ===="
if [[ -n "${MANAGER_HOST:-}" ]]; then
  check_tcp "$MANAGER_HOST" 7180 "Cloudera Manager UI"
  check_tcp "$MANAGER_HOST" 7182 "Cloudera SCM Agent -> Server"
  check_tcp "$MANAGER_HOST" 5432 "PostgreSQL"
fi
if [[ -n "${AGENT_HOST:-}" ]]; then
  check_tcp "$AGENT_HOST" 2181 "ZooKeeper"
  check_tcp "$AGENT_HOST" 9443 "NiFi HTTPS"
  check_tcp "$AGENT_HOST" 18443 "NiFi Registry HTTPS"
fi

echo
echo "==== Completed ===="
echo "Log file: $LOG_FILE"
