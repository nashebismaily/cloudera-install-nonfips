#!/usr/bin/env bash
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORTS_FILE="${EXPORTS_FILE:-${SCRIPT_DIR}/EXPORTS}"

if [[ -f "$EXPORTS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$EXPORTS_FILE"
fi

log_init() {
  local name="$1"
  LOG_DIR="${LOG_DIR:-/var/log/cloudera-bootstrap}"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/${name}_$(date +%Y%m%d_%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "==== ${name} ===="
  echo "Timestamp: $(date -Is)"
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  echo "OS: $(cat /etc/redhat-release 2>/dev/null || echo unknown)"
  echo "Log: $LOG_FILE"
  echo
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] Run as root or with sudo -E."
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command missing: $cmd"
    exit 1
  fi
}

warn_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[OK] command present: $cmd"
  else
    echo "[WARN] command missing: $cmd"
  fi
}

rhel_major() { rpm -E '%{rhel}' 2>/dev/null || echo unknown; }

validate_platform_nonfips() {
  local arch expected_major
  arch="$(uname -m 2>/dev/null || echo unknown)"
  expected_major="${EXPECTED_RHEL_MAJOR:-9}"

  echo "==== Platform validation ===="
  echo "Architecture: $arch"
  echo "RHEL major: $(rhel_major)"

  if [[ "${REQUIRE_X86_64:-true}" == "true" && "$arch" != "x86_64" ]]; then
    echo "[ERROR] Expected x86_64 but detected $arch"
    exit 1
  fi

  if [[ "$(rhel_major)" != "$expected_major" ]]; then
    echo "[WARN] Expected RHEL major $expected_major but detected $(rhel_major)"
  else
    echo "[OK] RHEL ${expected_major}.x detected"
  fi
  echo
}

require_cloudera_credentials() {
  if [[ -z "${CLOUDERA_REPO_USER:-}" || -z "${CLOUDERA_REPO_PASS:-}" ]]; then
    echo "[ERROR] CLOUDERA_REPO_USER and CLOUDERA_REPO_PASS must be set in EXPORTS or exported in the shell."
    exit 1
  fi
}

curl_head_auth() {
  local url="$1"
  curl -k -I -L --connect-timeout 10 --max-time 30 -u "${CLOUDERA_REPO_USER}:${CLOUDERA_REPO_PASS}" "$url" >/dev/null 2>&1
}

curl_download_auth() {
  local url="$1"
  local out="$2"
  curl -f -L --connect-timeout 20 --max-time 600 -u "${CLOUDERA_REPO_USER}:${CLOUDERA_REPO_PASS}" -o "$out" "$url"
}

pg_service_name() { echo "postgresql-${PG_MAJOR:-14}"; }
pg_bin_dir() { echo "/usr/pgsql-${PG_MAJOR:-14}/bin"; }
pg_default_data_dir() { echo "/var/lib/pgsql/${PG_MAJOR:-14}/data"; }

java_home_for_major() {
  local major="$1"
  local candidate
  candidate="/usr/lib/jvm/java-${major}-openjdk"
  if [[ -x "${candidate}/bin/java" ]]; then
    echo "$candidate"
    return 0
  fi
  candidate="$(find /usr/lib/jvm -maxdepth 1 -type d -name "java-${major}-openjdk*" 2>/dev/null | sort | head -1)"
  if [[ -n "$candidate" && -x "${candidate}/bin/java" ]]; then
    echo "$candidate"
    return 0
  fi
  echo "/usr/lib/jvm/java-${major}-openjdk"
}

set_default_java_home() {
  local java_home="$1"
  local java_bin="${java_home}/bin/java"

  if [[ ! -x "$java_bin" ]]; then
    echo "[WARN] Java executable not found at $java_bin; skipping default Java setup"
    return 0
  fi

  export JAVA_HOME="$java_home"
  export PATH="$JAVA_HOME/bin:$PATH"

  if command -v alternatives >/dev/null 2>&1; then
    alternatives --set java "$java_bin" >/dev/null 2>&1 || true
  fi

  cat >/etc/profile.d/cloudera-java.sh <<EOFJAVA
export JAVA_HOME='${JAVA_HOME}'
export PATH=\$JAVA_HOME/bin:\$PATH
EOFJAVA

  cat >/etc/default/cloudera-java <<EOFJAVADEFAULT
export JAVA_HOME='${JAVA_HOME}'
EOFJAVADEFAULT

  echo "[OK] JAVA_HOME set to ${JAVA_HOME}"
}

validate_java_major() {
  local expected="$1"
  local java_bin="${2:-$(command -v java || true)}"
  local version_output version_line detected

  if [[ -z "$java_bin" || ! -x "$java_bin" ]]; then
    echo "[ERROR] Java executable not found for Java ${expected}."
    exit 1
  fi

  version_output="$($java_bin -version 2>&1 || true)"
  version_line="$(printf '%s\n' "$version_output" | grep -E '^(openjdk|java) version ' | head -1)"

  echo "Java executable: $java_bin"
  echo "Java version: ${version_line:-unknown}"

  if [[ -z "$version_line" ]]; then
    echo "$version_output"
    echo "[ERROR] Java ${expected} required, detected unknown."
    exit 1
  fi

  detected="unknown"
  local re_quoted='"([0-9]+)\.'
  local re_openjdk='openjdk[[:space:]]+([0-9]+)\.'
  if [[ "$version_line" =~ $re_quoted ]]; then
    detected="${BASH_REMATCH[1]}"
  elif [[ "$version_line" =~ $re_openjdk ]]; then
    detected="${BASH_REMATCH[1]}"
  fi

  if [[ "$detected" != "$expected" ]]; then
    echo "$version_output"
    echo "[ERROR] Java ${expected} required, detected: $detected"
    exit 1
  fi

  echo "[OK] Java ${expected} validation passed"
}
