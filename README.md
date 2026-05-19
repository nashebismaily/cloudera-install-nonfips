# Cloudera Manager 7.13.2 + CFM 4.12 Non-FIPS Install Kit

This is the non-FIPS install kit for deploying Cloudera Manager, PostgreSQL, Cloudera Flow Management, NiFi, and NiFi Registry on RHEL 9.x.

The install can be run one script at a time, or with the wrapper scripts:

```bash
./RUN_MANAGER
./RUN_AGENT
```

The wrapper scripts are the preferred path because they load `EXPORTS`, run the steps in order, and stop on the first failure.

---

## Target Platform

Default target:

```text
RHEL:        9.x
Architecture: x86_64
CM:          7.13.2.0
CFM:         4.12.0.1 / build -8
PostgreSQL: 14
Manager JVM: Java 17
Agent JVMs:  Java 17 and Java 21
Agent default JVM: Java 17
```

Important: this is the **non-FIPS** kit. Do not use the FIPS kit scripts here. The FIPS kit was only used as a formatting and structure reference.

---

## Directory Layout

```bash
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
Install Notes
nifi_reg_config
nifitls.rtf
lib/common.sh
```

---

## Before You Run Anything

Edit `EXPORTS` first.

Required values:

```bash
export CLOUDERA_REPO_USER='your_cloudera_username'
export CLOUDERA_REPO_PASS='your_cloudera_password'
```

For multi-node installs, also set:

```bash
export MANAGER_HOST='manager-private-dns-or-fqdn'
export ALLOWED_CIDR='10.0.0.0/20'
```

On the manager node, `MANAGER_HOST` can be left blank and `RUN_MANAGER` will configure the local agent with `localhost`. For real agent nodes, `MANAGER_HOST` must be the actual private DNS name or FQDN of the manager host.

Load the exports manually when running individual scripts:

```bash
source ./EXPORTS
```

When using `sudo`, preserve the environment:

```bash
sudo -E bash script_name.sh
```

---

## Important Version Detail for CFM 4.12

The repo directory and the parcel build name are different.

Use this in `EXPORTS`:

```bash
export CFM_VERSION='4.12.0.1'
```

Do **not** use this for `CFM_VERSION`:

```bash
export CFM_VERSION='4.12.0.1-8'
```

The `-8` belongs in the CSD jar names and parcel directory name:

```bash
export CFM_NIFI_CSD_JAR='NIFI-2.6.0.4.12.0.1-8.jar'
export CFM_NIFIREGISTRY_CSD_JAR='NIFIREGISTRY-2.6.0.4.12.0.1-8.jar'
export CFM_PARCEL_DIR_NAME='CFM-4.12.0.1-8'
```

The CFM parcel repo URL printed by the wrapper is:

```bash
https://archive.cloudera.com/p/cfm4/4.12.0.1/redhat9/yum/tars/parcel/
```

---

## Manager Node Install

Preferred method:

```bash
source ./EXPORTS
./RUN_MANAGER
```

The manager wrapper runs:

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

After `RUN_MANAGER` completes, open Cloudera Manager:

```text
http://<manager-host>:7180
```

Default login:

```text
admin / admin
```

Then add the CFM parcel repository in Cloudera Manager:

```bash
$CFM_PARCEL_REPO_URL
```

---

## Agent / NiFi Node Install

Edit `EXPORTS` and set the real manager hostname:

```bash
export MANAGER_HOST='manager-private-dns-or-fqdn'
```

Preferred method:

```bash
source ./EXPORTS
./RUN_AGENT
```

The agent wrapper runs:

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
Installs Java 17 and Java 21
Sets Java 17 as the default runtime
Validates both Java versions
```

This is intentional. Agent/NiFi nodes need Java 17 as the default runtime while still having Java 21 installed and available for services that require it.

---

## PostgreSQL Layout

Default PostgreSQL data directory:

```bash
/data/postgres14
```

Make sure `/data` is mounted before running the manager install.

Quick checks:

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
sudo systemctl status postgresql-14 --no-pager
ss -plnt | grep 5432
sudo -u postgres psql -c "SELECT version();"
```

---

## Databases Created

The database script creates these by default:

```text
scm      / scm
rman     / rman
nifireg  / nifireg
```

Passwords come from `EXPORTS`:

```bash
CM_DB_PASS
RM_DB_PASS
REG_DB_PASS
```

NiFi Registry uses the `nifireg` database. Registry creates its own schema on first start after the JDBC settings are configured in Cloudera Manager.

---

## NiFi Registry Database Settings in Cloudera Manager

Use the values from `EXPORTS` when configuring NiFi Registry:

```text
Database Type: PostgreSQL
Database Host: <manager-host>
Database Port: 5432
Database Name: nifireg
Database User: nifireg
Database Password: Registry_DB_2026
```

Make sure PostgreSQL allows the agent subnet through `ALLOWED_CIDR`.

---

## Manual TLS Notes

This package includes the prior TLS notes in:

```bash
nifitls.rtf
```

Those are notes only. They are not automatically executed by `RUN_MANAGER` or `RUN_AGENT`.

---

## Common Validation Commands

```bash
sudo -E bash 14_validate_ready_state.sh
java -version
ls -ld /usr/lib/jvm/java-*openjdk*
systemctl status cloudera-scm-server --no-pager
systemctl status cloudera-scm-agent --no-pager
systemctl status postgresql-14 --no-pager
ss -plnt | egrep '5432|7180|7182|9443|18443'
dnf repolist | grep -i cloudera
```

---

## Troubleshooting Notes

If the Cloudera repo fails, confirm credentials and access:

```bash
source ./EXPORTS
curl -I -L -u "$CLOUDERA_REPO_USER:$CLOUDERA_REPO_PASS" "$CM_REPO_BASE_URL"
```

If CFM CSD download fails, confirm the CFM URL:

```bash
curl -I -L -u "$CLOUDERA_REPO_USER:$CLOUDERA_REPO_PASS" "$CFM_PARCEL_REPO_URL"
```

If an agent does not heartbeat, confirm the manager hostname:

```bash
grep '^server_host=' /etc/cloudera-scm-agent/config.ini
nc -vz "$MANAGER_HOST" 7182
systemctl status cloudera-scm-agent --no-pager
```

If PostgreSQL connection fails from an agent node:

```bash
nc -vz <manager-host> 5432
sudo -u postgres psql -c "SHOW listen_addresses;"
sudo tail -50 /data/postgres14/pg_hba.conf
```
