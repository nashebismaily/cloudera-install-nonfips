#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/lib/common.sh"

ROLE="${1:-}"
log_init "04_install_role_runtime_${ROLE:-unknown}"
need_root

if [[ "$ROLE" != "manager" && "$ROLE" != "agent" ]]; then
  echo "Usage: sudo -E bash 04_install_role_runtime.sh [manager|agent]"
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

install_java_major() {
  local major="$1"
  install_pkg "java-${major}-openjdk"
  install_pkg "java-${major}-openjdk-devel"
}

install_nifi_python_runtime() {
  if [[ "${INSTALL_NIFI_PYTHON:-true}" != "true" ]]; then
    echo "[INFO] INSTALL_NIFI_PYTHON is not true; skipping Python 3.11 install"
    return 0
  fi

  echo "==== Installing Python 3.11 for NiFi Python processors ===="
  install_pkg "python3.11"
  install_pkg "python3.11-pip"

  echo "==== Validating Python runtimes ===="
  if [[ ! -x /usr/bin/python3 && -x /usr/bin/python3.9 ]]; then
    ln -sf /usr/bin/python3.9 /usr/bin/python3
  fi

  if [[ -x /usr/bin/python3 ]]; then
    echo "System Python for CM agent: $(/usr/bin/python3 --version 2>&1)"
  else
    echo "[ERROR] /usr/bin/python3 is missing. On RHEL 9 this should be Python 3.9."
    exit 1
  fi

  if [[ -x /usr/bin/python3.11 ]]; then
    echo "NiFi Python runtime: $(/usr/bin/python3.11 --version 2>&1)"
  else
    echo "[ERROR] /usr/bin/python3.11 was not installed successfully."
    exit 1
  fi
}

if [[ "$ROLE" == "manager" ]]; then
  MANAGER_JAVA="${JAVA_MANAGER_MAJOR:-17}"
  echo "==== Installing manager Java runtime ===="
  install_java_major "$MANAGER_JAVA"
  MANAGER_JAVA_HOME="${JAVA_MANAGER_HOME_TARGET:-$(java_home_for_major "$MANAGER_JAVA")}"
  set_default_java_home "$MANAGER_JAVA_HOME"
  validate_java_major "$MANAGER_JAVA" "${MANAGER_JAVA_HOME}/bin/java"
fi

if [[ "$ROLE" == "agent" ]]; then
  PRIMARY_JAVA="${JAVA_AGENT_PRIMARY_MAJOR:-17}"
  EXTRA_JAVA_LIST="${JAVA_AGENT_EXTRA_MAJORS:-21}"

  echo "==== Installing agent Java runtimes ===="
  for major in $EXTRA_JAVA_LIST; do
    install_java_major "$major"
  done
  install_java_major "$PRIMARY_JAVA"

  echo "==== Validating installed agent Java runtimes ===="
  for major in $EXTRA_JAVA_LIST $PRIMARY_JAVA; do
    home="$(java_home_for_major "$major")"
    validate_java_major "$major" "${home}/bin/java"
  done

  AGENT_JAVA_HOME="${JAVA_AGENT_HOME_TARGET:-$(java_home_for_major "$PRIMARY_JAVA")}"
  set_default_java_home "$AGENT_JAVA_HOME"
  validate_java_major "$PRIMARY_JAVA" "${AGENT_JAVA_HOME}/bin/java"

  install_nifi_python_runtime
fi

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  echo "[WARN] Packages that failed: ${FAILED_PACKAGES[*]}"
fi

echo
echo "==== Java summary ===="
java -version || true
alternatives --display java || true
ls -ld /usr/lib/jvm/java-*openjdk* 2>/dev/null || true

echo
echo "==== Python summary ===="
/usr/bin/python3 --version 2>/dev/null || true
/usr/bin/python3.11 --version 2>/dev/null || true
ls -l /usr/bin/python3 /usr/bin/python3.9 /usr/bin/python3.11 2>/dev/null || true

echo "Log file: $LOG_FILE"
