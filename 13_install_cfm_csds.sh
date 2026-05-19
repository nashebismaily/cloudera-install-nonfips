#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
log_init "13_install_cfm_csds"
need_root
require_cloudera_credentials

CSD_DIR="/opt/cloudera/csd"
TMP_DIR="/tmp/cfm-csds"
CFM_URL="${CFM_PARCEL_REPO_URL:-https://archive.cloudera.com/p/${CFM_STREAM:-cfm4}/${CFM_VERSION:-4.12.0.1}/${CFM_OS_REPO:-redhat9}/yum/tars/parcel/}"
NIFI_JAR="${CFM_NIFI_CSD_JAR:-NIFI-2.6.0.4.12.0.1-8.jar}"
NIFIREG_JAR="${CFM_NIFIREGISTRY_CSD_JAR:-NIFIREGISTRY-2.6.0.4.12.0.1-8.jar}"

echo "==== Installing CFM CSDs ===="
echo "CFM_VERSION=${CFM_VERSION:-4.12.0.1}"
echo "CFM_URL=${CFM_URL}"
echo "CSD_DIR=${CSD_DIR}"

mkdir -p "$CSD_DIR" "$TMP_DIR"
rm -f "$TMP_DIR"/*.jar || true

for jar in "$NIFI_JAR" "$NIFIREG_JAR"; do
  echo "==== Downloading ${jar} ===="
  curl_download_auth "${CFM_URL}${jar}" "${TMP_DIR}/${jar}"
done

echo "==== Validating downloads ===="
for f in "${TMP_DIR}/${NIFI_JAR}" "${TMP_DIR}/${NIFIREG_JAR}"; do
  if [[ ! -f "$f" ]]; then
    echo "[ERROR] Missing download: $f"
    exit 1
  fi
  SIZE=$(stat -c%s "$f")
  if [[ "$SIZE" -lt 50000 ]]; then
    echo "[ERROR] File too small and likely invalid: $f (${SIZE} bytes)"
    head -20 "$f" || true
    exit 1
  fi
  echo "[OK] Valid file: $(basename "$f") (${SIZE} bytes)"
done

echo "==== Removing old CSD jars ===="
rm -f "$CSD_DIR"/*.jar || true

echo "==== Installing CSD jars ===="
cp -f "$TMP_DIR"/*.jar "$CSD_DIR/"
chown cloudera-scm:cloudera-scm "$CSD_DIR"/*.jar
chmod 644 "$CSD_DIR"/*.jar
ls -lh "$CSD_DIR"

echo "==== Restarting Cloudera Manager Server ===="
systemctl restart cloudera-scm-server

echo "==== Waiting for CM restart ===="
sleep_seconds="${CM_RESTART_WAIT_SECONDS:-90}"
sleep "$sleep_seconds"

if ss -plnt | grep -q ":7180"; then
  echo "[OK] Cloudera Manager listening on 7180"
else
  echo "[WARN] CM port 7180 not detected yet"
fi

echo "==== Done ===="
echo "Refresh CM UI and go to Cluster -> Add Service. You should now see NiFi and NiFi Registry."
echo "Log file: $LOG_FILE"
