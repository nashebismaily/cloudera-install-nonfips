# Cloudera Non-FIPS Install Automation

This repository contains non-FIPS installation automation for a Cloudera environment on RHEL 9.x.

It installs and prepares the core platform components needed for a Cloudera deployment, including:

- Cloudera Manager
- Cloudera Manager Agent
- PostgreSQL 14
- Java runtime setup
- Cloudera parcel repository configuration
- Optional Cloudera Flow Management setup support for NiFi and NiFi Registry

This is the **non-FIPS** repository. Keep this separate from the FIPS install repository.

---

## Target Platform

Default target:

```text
Operating System:     RHEL 9.x
Architecture:         x86_64
Cloudera Manager:     7.13.2.0
PostgreSQL:           14
Manager Java:         Java 17
Agent Java:           Java 17 and Java 21
Agent default Java:   Java 17
Optional CFM:         4.12.0.1 build -8
```

Important Java behavior:

```text
Manager nodes install Java 17.
Agent nodes install Java 17 and Java 21.
Agent nodes keep Java 17 as the default runtime.
Java 21 remains installed and available for services that require it.
```

---

## Repository Layout

```text
00_check_connectivity.sh
01_bootstrap_repos.sh
02_install_common_packages.sh
03_configure_os.sh
04_install_role_runtime.sh
05_install_postgres.sh
06_configure_postgres_networking.sh
07_create_cm_and_registry_dbs.sh
08_add_cloudera_repos.sh
09_install_cm_packages.sh
10_configure_cm_agent.sh
11_prepare_cm_database.sh
12_start_cm_services.sh
13_install_cfm_csds.sh
14_validate_ready_state.sh

EXPORTS
RUN_MANAGER
RUN_AGENT
AGENT

nifi_reg_config
lib/common.sh
```

The old standalone `Install Notes` and `nifitls.rtf` files are no longer required. The important information from those notes is now included in this README.

---

## Before You Run Anything

Edit `EXPORTS` first.

At minimum, set your Cloudera archive credentials:

```bash
export CLOUDERA_REPO_USER='your_cloudera_username'
export CLOUDERA_REPO_PASS='your_cloudera_password'
```

For multi-node installs, set the manager hostname:

```bash
export MANAGER_HOST='manager-private-dns-or-fqdn'
```

Set the network CIDR that should be allowed to connect to PostgreSQL:

```bash
export ALLOWED_CIDR='10.0.0.0/20'
```

Review and change the default database passwords:

```bash
export CM_DB_PASS='ClouderaCM_2026'
export RM_DB_PASS='Rman_DB_2026'
export REG_DB_PASS='Registry_DB_2026'
```

Load the exports before running individual scripts:

```bash
source ./EXPORTS
```

When using `sudo`, preserve the environment:

```bash
sudo -E bash script_name.sh
```

The wrapper scripts already source `EXPORTS` for you.

---

## Important Version Detail for Optional CFM 4.12

The CFM repository version and parcel build name are not the same thing.

Use this in `EXPORTS`:

```bash
export CFM_VERSION='4.12.0.1'
```

Do not set `CFM_VERSION` to this:

```bash
export CFM_VERSION='4.12.0.1-8'
```

The `-8` build suffix belongs in the CSD jar names and parcel directory name:

```bash
export CFM_NIFI_CSD_JAR='NIFI-2.6.0.4.12.0.1-8.jar'
export CFM_NIFIREGISTRY_CSD_JAR='NIFIREGISTRY-2.6.0.4.12.0.1-8.jar'
export CFM_PARCEL_DIR_NAME='CFM-4.12.0.1-8'
```

The CFM parcel repository URL is:

```bash
https://archive.cloudera.com/p/cfm4/4.12.0.1/redhat9/yum/tars/parcel/
```

---

## Manager Node Install

Run this on the Cloudera Manager and PostgreSQL server node.

Preferred method:

```bash
source ./EXPORTS
./RUN_MANAGER
```

`RUN_MANAGER` executes the manager-side install flow in this order:

```bash
sudo -E bash 00_check_connectivity.sh
sudo -E bash 01_bootstrap_repos.sh
sudo -E bash 02_install_common_packages.sh
sudo -E bash 03_configure_os.sh
sudo -E bash 04_install_role_runtime.sh manager
sudo -E bash 05_install_postgres.sh
sudo -E bash 06_configure_postgres_networking.sh
sudo -E bash 07_create_cm_and_registry_dbs.sh
sudo -E bash 08_add_cloudera_repos.sh
sudo -E bash 09_install_cm_packages.sh manager
sudo -E bash 10_configure_cm_agent.sh "${MANAGER_HOST:-localhost}"
sudo -E bash 11_prepare_cm_database.sh
sudo -E bash 12_start_cm_services.sh
sudo -E bash 13_install_cfm_csds.sh
sudo -E bash 14_validate_ready_state.sh
```

After the manager install completes, open Cloudera Manager:

```text
http://<manager-host>:7180
```

Default login:

```text
admin / admin
```

---

## Agent Node Install

Run this on each agent node, including NiFi and NiFi Registry nodes.

Edit `EXPORTS` and set:

```bash
export MANAGER_HOST='manager-private-dns-or-fqdn'
```

Preferred method:

```bash
source ./EXPORTS
./RUN_AGENT
```

`RUN_AGENT` executes the agent-side install flow in this order:

```bash
sudo -E bash 00_check_connectivity.sh
sudo -E bash 01_bootstrap_repos.sh
sudo -E bash 02_install_common_packages.sh
sudo -E bash 03_configure_os.sh
sudo -E bash 04_install_role_runtime.sh agent
sudo -E bash 08_add_cloudera_repos.sh
sudo -E bash 09_install_cm_packages.sh agent
sudo -E bash 10_configure_cm_agent.sh "$MANAGER_HOST"
sudo -E bash 14_validate_ready_state.sh
```

Agent Java behavior:

```text
Installs Java 17
Installs Java 21
Sets Java 17 as the default runtime
Validates both Java versions
```

This is intentional. Java 17 remains the default for the host and Cloudera agent behavior, while Java 21 is available for services that need a newer runtime.

---

## Manual Script Execution

If you do not want to use the wrapper scripts, run the scripts manually.

Manager node:

```bash
source ./EXPORTS

sudo -E bash 00_check_connectivity.sh
sudo -E bash 01_bootstrap_repos.sh
sudo -E bash 02_install_common_packages.sh
sudo -E bash 03_configure_os.sh
sudo -E bash 04_install_role_runtime.sh manager
sudo -E bash 05_install_postgres.sh
sudo -E bash 06_configure_postgres_networking.sh
sudo -E bash 07_create_cm_and_registry_dbs.sh
sudo -E bash 08_add_cloudera_repos.sh
sudo -E bash 09_install_cm_packages.sh manager
sudo -E bash 10_configure_cm_agent.sh localhost
sudo -E bash 11_prepare_cm_database.sh
sudo -E bash 12_start_cm_services.sh
sudo -E bash 13_install_cfm_csds.sh
sudo -E bash 14_validate_ready_state.sh
```

Agent node:

```bash
source ./EXPORTS

sudo -E bash 00_check_connectivity.sh
sudo -E bash 01_bootstrap_repos.sh
sudo -E bash 02_install_common_packages.sh
sudo -E bash 03_configure_os.sh
sudo -E bash 04_install_role_runtime.sh agent
sudo -E bash 08_add_cloudera_repos.sh
sudo -E bash 09_install_cm_packages.sh agent
sudo -E bash 10_configure_cm_agent.sh <manager-private-dns-or-fqdn>
sudo -E bash 14_validate_ready_state.sh
```

---

## PostgreSQL Configuration

Default PostgreSQL data directory:

```bash
/data/postgres14
```

Make sure `/data` is mounted before running the manager install.

Recommended checks before running PostgreSQL setup:

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
df -h /data
```

PostgreSQL service checks:

```bash
sudo systemctl status postgresql-14 --no-pager
ss -plnt | grep 5432
sudo -u postgres psql -c "SELECT version();"
```

Database values from `EXPORTS`:

```bash
export CM_DB_NAME='scm'
export CM_DB_USER='scm'

export RM_DB_NAME='rman'
export RM_DB_USER='rman'

export REG_DB_NAME='nifireg'
export REG_DB_USER='nifireg'
```

The Registry database is created because NiFi Registry needs its own backing database.

---

## Cloudera Manager Post-Install Steps

After `RUN_MANAGER` completes and Cloudera Manager is available, log in at:

```text
http://<manager-host>:7180
```

Default credentials:

```text
admin / admin
```

Then complete the cluster wizard.

If using CFM, add the CFM parcel repository:

```bash
https://archive.cloudera.com/p/cfm4/4.12.0.1/redhat9/yum/tars/parcel/
```

In Cloudera Manager, this is added under:

```text
Hosts > Parcels > Configuration > Remote Parcel Repository URLs
```

After adding the repository:

```text
Check for New Parcels
Download CFM
Distribute CFM
Activate CFM
```

---

## Optional NiFi Service Configuration

If deploying NiFi, set the custom Java home in Cloudera Manager.

Recommended Java home for NiFi:

```bash
/usr/lib/jvm/java-21-openjdk
```

Depending on the installed RPM build, the full path may look like:

```bash
/usr/lib/jvm/java-21-openjdk-21.0.10.0.7-1.el9.x86_64
```

Use the path that exists on the agent node.

Check Java paths with:

```bash
ls -ld /usr/lib/jvm/java-*openjdk*
```

Set this in the NiFi service configuration:

```text
Custom Java Home: /usr/lib/jvm/java-21-openjdk
```

Use the exact installed Java 21 path if Cloudera Manager does not resolve the generic symlink.

---

## Optional NiFi Registry Database Configuration

If deploying NiFi Registry, configure the Registry database in Cloudera Manager.

Use the values from `EXPORTS`.

Example:

```text
Database Type: PostgreSQL
JDBC URL: jdbc:postgresql://<postgres-host>:5432/nifireg
Database Driver Class: org.postgresql.Driver
Database Driver Location: /opt/cloudera/parcels/CFM-4.12.0.1-8/REGISTRY/jdbc-drivers/postgresql-42.5.5.jar
Database Username: nifireg
Database Password: <REG_DB_PASS from EXPORTS>
Validation Query: SELECT 1
SSL: Disabled
```

If PostgreSQL is on the manager host, use the manager host private IP or private DNS name in the JDBC URL.

Example:

```text
jdbc:postgresql://10.0.7.147:5432/nifireg
```

---

## Optional NiFi TLS / HTTPS Configuration

These are the NiFi properties that were used to get the HTTPS deployment working.

Use hostnames that match your certificate subject/SAN values.

Example NiFi HTTPS settings:

```properties
nifi.web.https.host=<nifi-hostname>
nifi.web.https.port=8443

nifi.security.keystore=/opt/cloudera/security/keystore.p12
nifi.security.keystoreType=PKCS12
nifi.security.keystorePasswd=<your_password>
nifi.security.keyPasswd=<your_password>

nifi.security.truststore=/opt/cloudera/security/truststore.jks
nifi.security.truststoreType=JKS
nifi.security.truststorePasswd=<your_password>
```

For a demo or bootstrap environment without LDAP, anonymous bootstrap auth was used:

```properties
nifi.security.allow.anonymous.authentication=true
nifi.initial.admin.identity=anonymous
```

For node identity generation:

```properties
nifi.autogen.node.identities=true
nifi.autogen.node.identities.dn.prefix=CN=
nifi.autogen.node.identities.dn.suffix=
```

Important: leave the suffix blank.

The suffix was originally set to:

```text
, OU=NIFI
```

That caused an identity collision in the working environment. The final working state had the suffix blank.

After major NiFi auth changes, these files were regenerated:

```bash
sudo rm -f /var/lib/nifi/users.xml
sudo rm -f /var/lib/nifi/authorizations.xml
```

Restart NiFi after changing auth or TLS settings.

---

## Optional NiFi Registry TLS / HTTPS Configuration

Example NiFi Registry HTTPS settings:

```properties
nifi.registry.web.https.host=<registry-hostname>
nifi.registry.web.https.port=18443

nifi.registry.security.keystore=/opt/cloudera/security/keystore.p12
nifi.registry.security.keystoreType=PKCS12
nifi.registry.security.keystorePasswd=<password>
nifi.registry.security.keyPasswd=<password>

nifi.registry.security.truststore=/opt/cloudera/security/truststore.jks
nifi.registry.security.truststoreType=JKS
nifi.registry.security.truststorePasswd=<password>

nifi.registry.security.needClientAuth=false
nifi.registry.security.initial.admin.identity=anonymous
```

Use hostnames that match the certificate SANs.

---

## Trusting the Demo Root CA

If using a local or demo CA, import the root CA into the Java truststore used by Cloudera components.

Example:

```bash
sudo keytool -importcert \
  -alias cloudera-rootca \
  -file /opt/cloudera/security/rootCA.crt \
  -keystore /usr/lib/jvm/java/lib/security/cacerts \
  -storepass changeit \
  -noprompt
```

Depending on the installed Java layout, the truststore may live under the specific Java home.

Check with:

```bash
readlink -f /usr/lib/jvm/java
ls -l /usr/lib/jvm/java/lib/security/cacerts
```

If Java 17 is the default, confirm:

```bash
java -version
readlink -f "$(which java)"
```

---

## Common Validation Commands

Check OS:

```bash
cat /etc/redhat-release
uname -m
```

Check Java:

```bash
java -version
alternatives --display java
ls -ld /usr/lib/jvm/java-*openjdk*
```

Check Cloudera Manager server:

```bash
sudo systemctl status cloudera-scm-server --no-pager
sudo tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log
```

Check Cloudera Manager agent:

```bash
sudo systemctl status cloudera-scm-agent --no-pager
sudo tail -f /var/log/cloudera-scm-agent/cloudera-scm-agent.log
```

Check PostgreSQL:

```bash
sudo systemctl status postgresql-14 --no-pager
ss -plnt | grep 5432
sudo -u postgres psql -c "\l"
```

Check parcel directory:

```bash
ls -l /opt/cloudera/parcels
```

Check CSD directory:

```bash
ls -l /opt/cloudera/csd
```

---

## Logs

Bootstrap logs are written to:

```bash
/var/log/cloudera-bootstrap
```

Useful Cloudera logs:

```bash
/var/log/cloudera-scm-server/cloudera-scm-server.log
/var/log/cloudera-scm-agent/cloudera-scm-agent.log
/var/log/cloudera-scm-agent/certmanager.log
```

Useful NiFi logs:

```bash
/var/log/nifi/nifi-app.log
/var/log/nifi/nifi-bootstrap.log
/var/log/nifi/nifi-user.log
```

Useful NiFi Registry logs:

```bash
/var/log/nifiregistry/nifi-registry-app.log
/var/log/nifiregistry/nifi-registry-bootstrap.log
```

---

## Notes

This repository is intentionally non-FIPS.

For FIPS installs, use the separate FIPS repository.

Do not mix the non-FIPS and FIPS scripts. The FIPS path requires additional crypto modules, Java provider configuration, and service-specific FIPS settings that are not part of this repository.
