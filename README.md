# Cloudera Non-FIPS Install Kit

This repository prepares a small Cloudera environment on RHEL 9 without FIPS enabled.

The current profile is:

- RHEL 9.x
- Non-FIPS operating system mode
- Cloudera Manager 7.13.2.0
- PostgreSQL 14
- Java 17 as the default Java runtime
- Java 21 installed on agent hosts for services that require it
- Optional CFM 4.12.0.1 support for NiFi and NiFi Registry

This kit is for the non-FIPS path only. Keep it separate from the FIPS install repository.

---

## 1. Host layout

This kit assumes at least two hosts:

| Role | Description |
|---|---|
| Manager | Runs Cloudera Manager Server, local PostgreSQL, and the local Cloudera Manager Agent |
| Agent | Runs Cloudera Manager Agent and is managed by the Manager |

Example values:

```bash
export MANAGER_HOST='ip-10-0-3-31.us-east-2.compute.internal'
export AGENT_HOST='ip-10-0-11-156.us-east-2.compute.internal'
export ALLOWED_CIDR='10.0.0.0/20'
```

Use private DNS names or private IPs that are reachable inside the VPC.

The manager/server host must also run the Cloudera Manager Agent and `cloudera-scm-supervisord`. This lets the manager host appear as a managed host in Cloudera Manager.

---

## 2. Confirm this is the non-FIPS path

Run this on every host:

```bash
cat /etc/redhat-release
cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo "0"
fips-mode-setup --check 2>/dev/null || true
```

Expected for this repository:

```text
Red Hat Enterprise Linux release 9.x
0
FIPS mode is disabled.
```

Do not use this repository for a FIPS-enabled customer install.

For FIPS installs, use the separate FIPS repository.

---

## 3. Stage the install kit

Copy the install kit to the manager and unzip it.

```bash
sudo -i
cd /root

unzip cloudera-install-nonfips.zip
cd cloudera-install-nonfips

chmod +x *.sh RUN_MANAGER RUN_AGENT
```

Copy the same folder to each agent host later before running `RUN_AGENT`.

---

## 4. Configure `EXPORTS`

Edit the file:

```bash
cd /root/cloudera-install-nonfips
vi EXPORTS
```

Set the environment-specific values:

```bash
export CLOUDERA_REPO_USER='your_cloudera_archive_username'
export CLOUDERA_REPO_PASS='your_cloudera_archive_password'

export MANAGER_HOST='ip-10-0-3-31.us-east-2.compute.internal'
export AGENT_HOST='ip-10-0-11-156.us-east-2.compute.internal'
export ALLOWED_CIDR='10.0.0.0/20'
```

For the default non-FIPS profile, keep:

```bash
export EXPECTED_RHEL_MAJOR='9'
export REQUIRE_FIPS='false'

export CM_VERSION='7.13.2.0'

export PG_MAJOR='14'
export PGDATA_DIR='/data/postgres14'
```

Java defaults:

```bash
export JAVA_MANAGER_MAJOR='17'
export JAVA_MANAGER_HOME_TARGET='/usr/lib/jvm/java-17-openjdk'

export JAVA_AGENT_PRIMARY_MAJOR='17'
export JAVA_AGENT_EXTRA_MAJORS='21'
export JAVA_AGENT_HOME_TARGET='/usr/lib/jvm/java-17-openjdk'
```

This means:

```text
Manager installs Java 17.
Agent installs Java 17 and Java 21.
Agent default Java remains Java 17.
Java 21 is available for services that require it.
```

Database defaults:

```bash
export CM_DB_NAME='scm'
export CM_DB_USER='scm'
export CM_DB_PASS='ClouderaCM_2026'

export RM_DB_NAME='rman'
export RM_DB_USER='rman'
export RM_DB_PASS='Rman_DB_2026'

export REG_DB_NAME='nifireg'
export REG_DB_USER='nifireg'
export REG_DB_PASS='Registry_DB_2026'
```

Optional CFM 4.12 defaults:

```bash
export CFM_STREAM='cfm4'
export CFM_VERSION='4.12.0.1'
export CFM_OS_REPO='redhat9'

export CFM_NIFI_CSD_JAR='NIFI-2.6.0.4.12.0.1-8.jar'
export CFM_NIFIREGISTRY_CSD_JAR='NIFIREGISTRY-2.6.0.4.12.0.1-8.jar'
export CFM_PARCEL_DIR_NAME='CFM-4.12.0.1-8'
```

Important: the CFM repository version and parcel build name are not the same thing.

Use this:

```bash
export CFM_VERSION='4.12.0.1'
```

Do not use this:

```bash
export CFM_VERSION='4.12.0.1-8'
```

The `-8` suffix belongs in the CSD jar names and parcel directory name, not the repository version.

The CFM parcel repository for this profile is:

```text
https://archive.cloudera.com/p/cfm4/4.12.0.1/redhat9/yum/tars/parcel/
```

---

## 5. Validate the manager before installing

On the manager:

```bash
cd /root/cloudera-install-nonfips
source ./EXPORTS

sudo -E bash 00_check_connectivity.sh
```

Warnings for missing packages are normal before the install:

```text
[WARN] command missing: python3
[WARN] command missing: java
[WARN] command missing: host
[WARN] command missing: nslookup
[WARN] command missing: nc
[WARN] command missing: jq
```

Those are installed by later scripts.

Hard blockers include:

- wrong RHEL version
- FIPS enabled when this non-FIPS kit expects FIPS disabled
- invalid Cloudera archive credentials
- inaccessible Cloudera repositories
- bad manager or agent host values
- missing or unmounted `/data` when local PostgreSQL is expected

---

## 6. Run the manager install

On the manager:

```bash
cd /root/cloudera-install-nonfips
source ./EXPORTS

sudo -E ./RUN_MANAGER
```

`RUN_MANAGER` runs the manager-side scripts in order and stops if a script fails.

It installs and configures:

- common OS packages
- required networking and troubleshooting tools
- Java 17
- PostgreSQL 14
- Cloudera Manager repository
- Cloudera Manager Server
- local Cloudera Manager Agent on the manager/server host
- local `cloudera-scm-supervisord` on the manager/server host
- Cloudera Manager database preparation
- optional CFM CSDs
- readiness validation

Important: the Cloudera Manager server host must also run the CM agent and supervisord. Otherwise it may not appear as a managed host in CM.

After `RUN_MANAGER` completes, check:

```bash
systemctl status cloudera-scm-server -l --no-pager
systemctl status cloudera-scm-supervisord -l --no-pager
systemctl status cloudera-scm-agent -l --no-pager

tail -n 80 /var/log/cloudera-scm-server/cloudera-scm-server.log
tail -n 80 /var/log/cloudera-scm-agent/cloudera-scm-agent.log
```

Then open Cloudera Manager:

```text
http://<manager-host>:7180
```

Default login is usually:

```text
admin / admin
```

---

## 7. Run the agent install

Copy the same folder to the agent.

From the manager:

```bash
scp -r /root/cloudera-install-nonfips ec2-user@<agent-host>:/tmp/
```

On the agent:

```bash
sudo -i

mv /tmp/cloudera-install-nonfips /root/
cd /root/cloudera-install-nonfips

chmod +x *.sh RUN_AGENT
source ./EXPORTS
```

Make sure the agent's `EXPORTS` has:

```bash
export MANAGER_HOST='<manager-private-dns-or-ip>'
export AGENT_HOST='<this-agent-private-dns-or-ip>'
export ALLOWED_CIDR='10.0.0.0/20'
```

Run the precheck:

```bash
sudo -E bash 00_check_connectivity.sh
```

Then run the agent installer:

```bash
sudo -E ./RUN_AGENT
```

`RUN_AGENT` installs and configures:

- common OS packages
- required networking and troubleshooting tools
- Java 17
- Java 21
- Java 17 as the default Java runtime
- Cloudera Manager repository
- Cloudera Manager Agent
- local `cloudera-scm-supervisord`
- readiness validation

Check the agent services:

```bash
systemctl status cloudera-scm-supervisord -l --no-pager
systemctl status cloudera-scm-agent -l --no-pager

tail -n 80 /var/log/cloudera-scm-agent/cloudera-scm-agent.log
```

Both `cloudera-scm-supervisord` and `cloudera-scm-agent` should be active. The agent should connect back to the manager host.

For additional agents, leave the shared values the same and change only:

```bash
export AGENT_HOST='<this-agent-private-dns-or-ip>'
```

The most important value for every agent is:

```bash
export MANAGER_HOST='<manager-private-dns-or-ip>'
```

---

## 8. What the wrappers do

`RUN_MANAGER` is the normal way to install the manager/server host.

`RUN_AGENT` is the normal way to install each remote agent host.

The individual numbered scripts are left in the repository for transparency and troubleshooting, but the intended install path is to run the wrappers.

`RUN_MANAGER` runs:

```bash
00_check_connectivity.sh
01_bootstrap_repos.sh
02_install_common_packages.sh
03_configure_os.sh
04_install_role_runtime.sh manager
05_install_postgres.sh
06_configure_postgres_networking.sh
07_create_cm_and_registry_dbs.sh
08_add_cloudera_repos.sh
09_install_cm_packages.sh manager
10_configure_cm_agent.sh "$MANAGER_HOST"
11_prepare_cm_database.sh
12_start_cm_services.sh
13_install_cfm_csds.sh
14_validate_ready_state.sh
```

`RUN_AGENT` runs:

```bash
00_check_connectivity.sh
01_bootstrap_repos.sh
02_install_common_packages.sh
03_configure_os.sh
04_install_role_runtime.sh agent
08_add_cloudera_repos.sh
09_install_cm_packages.sh agent
10_configure_cm_agent.sh "$MANAGER_HOST"
14_validate_ready_state.sh
```

Both wrappers are designed to fail fast. If one script exits with a non-zero status, the wrapper should stop and should not continue blindly.

You can confirm this with:

```bash
head -40 RUN_MANAGER
head -40 RUN_AGENT
```

Look for:

```bash
set -e
```

or:

```bash
set -euo pipefail
```

---

## 9. PostgreSQL model

The current kit assumes local PostgreSQL on the manager.

Default:

```bash
export PG_MAJOR='14'
export PGDATA_DIR='/data/postgres14'
```

Before running `RUN_MANAGER`, make sure `/data` exists and has enough space:

```bash
df -h
lsblk -f
```

The scripts create PostgreSQL databases by default on the manager host.

| Purpose | Database | Username | Password | Notes |
|---|---|---|---|---|
| Cloudera Manager Server | `scm` | `scm` | `ClouderaCM_2026` | Used by `scm_prepare_database.sh`; not usually entered in the CM UI after install |
| Reports Manager | `rman` | `rman` | `Rman_DB_2026` | Enter this in the CM Management Service Reports Manager database screen |
| NiFi Registry | `nifireg` | `nifireg` | `Registry_DB_2026` | Enter this in the NiFi Registry database configuration |
| Hue, optional | `hue` | `hue` | `Hue_DB_2026` | Created only if `CREATE_EXTRA_DBS=true` |
| Hive Metastore, optional | `metastore` | `hive` | `Hive_DB_2026` | Created only if `CREATE_EXTRA_DBS=true` |
| Ranger, optional | `ranger` | `rangeradmin` | `Ranger_DB_2026` | Created only if `CREATE_EXTRA_DBS=true` |

The database host for UI configuration is normally the manager private DNS name:

```text
<manager-private-dns-or-ip>
```

The PostgreSQL port is:

```text
5432
```

If your manager host is different, use the value of `MANAGER_HOST` from `EXPORTS`.

PostgreSQL service checks:

```bash
systemctl status postgresql-14 -l --no-pager
ss -plnt | grep 5432
sudo -u postgres psql -c "\l"
```

---

## 10. Cloudera Manager deployment sequence

After manager and agent are installed:

1. Log into Cloudera Manager.
2. Confirm the manager/server host appears as a managed host.
3. Confirm each remote agent host appears as a managed host.
4. Deploy the CDP Runtime/Base cluster.
5. ZooKeeper comes from CDP Base/Runtime. Do not manually install ZooKeeper outside CM.
6. If using CFM, add the CFM parcel repository from `EXPORTS`:

```bash
echo "$CFM_PARCEL_REPO_URL"
```

For the default CFM 4.12 profile, this is:

```text
https://archive.cloudera.com/p/cfm4/4.12.0.1/redhat9/yum/tars/parcel/
```

7. In CM, go to `Hosts -> Parcels -> Configuration` and add that repository URL.
8. Go back to `Hosts -> Parcels`, click `Check for New Parcels`, and look for:

```text
CFM-4.12.0.1-8
```

9. Download, distribute, and activate the CFM parcel.
10. Deploy the desired services from Cloudera Manager.

Important: the CFM CSD jars and the CFM parcel repository must come from the same CFM build. For the default profile, the CSDs are:

```text
NIFI-2.6.0.4.12.0.1-8.jar
NIFIREGISTRY-2.6.0.4.12.0.1-8.jar
```

and the parcel repo is:

```text
https://archive.cloudera.com/p/cfm4/4.12.0.1/redhat9/yum/tars/parcel/
```

Do not mix CSDs and parcel artifacts from different CFM builds.

---

## 11. NiFi Registry PostgreSQL configuration

When adding NiFi Registry in Cloudera Manager, replace the default embedded H2 values with PostgreSQL.

Use these values unless you changed the database variables in `EXPORTS`:

| CM field | Value |
|---|---|
| NiFi Registry JDBC Url | `jdbc:postgresql://<manager-private-dns-or-ip>:5432/nifireg` |
| NiFi Registry JDBC Driver | `org.postgresql.Driver` |
| NiFi Registry Database Driver Directory | `/usr/share/java` |
| NiFi Registry Database Username | `nifireg` |
| NiFi Registry Database Password | `Registry_DB_2026` |
| Maximum connection in db pool | `5` |
| Enable database sql debugging | `false` |

Install the PostgreSQL JDBC driver on the host where NiFi Registry will run:

```bash
sudo -i
dnf install -y postgresql-jdbc
ls -lh /usr/share/java | grep -i postgres
find /usr/share/java -iname '*postgres*.jar' -print
```

Before saving the NiFi Registry config in CM, test the database connection from the NiFi Registry host:

```bash
PGPASSWORD='Registry_DB_2026' psql \
  -h <manager-private-dns-or-ip> \
  -p 5432 \
  -U nifireg \
  -d nifireg \
  -c "select current_database(), current_user;"
```

Expected result:

```text
 current_database | current_user
------------------+--------------
 nifireg          | nifireg
```

If `psql` is not available on the agent host, install the PostgreSQL client package:

```bash
dnf install -y postgresql
```

---

## 12. NiFi Java configuration

Agent nodes install both Java 17 and Java 21.

The host default remains Java 17:

```bash
java -version
alternatives --display java
```

Java 21 is installed for services that need it, especially NiFi 2.x based CFM 4.12 environments.

Check available Java homes:

```bash
ls -ld /usr/lib/jvm/java-*openjdk*
```

For NiFi, set the custom Java home in Cloudera Manager if required:

```text
Custom Java Home: /usr/lib/jvm/java-21-openjdk
```

Depending on the installed RPM build, the full path may look like:

```text
/usr/lib/jvm/java-21-openjdk-21.0.x.x.x-x.el9.x86_64
```

Use the path that exists on the agent node.

If Cloudera Manager does not resolve the generic symlink, use the full installed Java 21 path.

---

## 13. NiFi TLS / HTTPS notes

These values were previously captured in the standalone TLS notes and are now included here.

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

For a demo or bootstrap environment without LDAP, anonymous bootstrap auth can be used:

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

Important: leave the suffix blank unless you know you need it.

A suffix such as this caused an identity collision in one working environment:

```text
, OU=NIFI
```

The final working state had the suffix blank.

After major NiFi auth changes, these files can be regenerated:

```bash
sudo rm -f /var/lib/nifi/users.xml
sudo rm -f /var/lib/nifi/authorizations.xml
```

Restart NiFi after changing auth or TLS settings.

---

## 14. NiFi Registry TLS / HTTPS notes

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

If NiFi Registry fails with a KeyManagerFactory or TrustManagerFactory error, check the effective process configuration first:

```bash
grep -i 'keymanager\|trustmanager\|keystoreType\|truststoreType' \
  /var/run/cloudera-scm-agent/process/*-NIFI_REGISTRY-*/nifi-registry.properties 2>/dev/null
```

If needed, set:

```properties
nifi.registry.security.keymanager.algorithm=PKIX
nifi.registry.security.trustmanager.algorithm=PKIX
```

Also verify the keystore and truststore type values match the actual stores:

```properties
nifi.registry.security.keystoreType=JKS
nifi.registry.security.truststoreType=JKS
```

or:

```properties
nifi.registry.security.keystoreType=PKCS12
nifi.registry.security.truststoreType=PKCS12
```

---

## 15. Auto-TLS approach

This kit includes an Auto-TLS utility workflow under:

```bash
utilities/tls
```

The top-level install scripts handle the operating system, Java runtime, PostgreSQL, Cloudera Manager, agents, CSDs, parcels, and base service installation.

The `utilities/tls` directory is a separate post-install utility area for enabling Cloudera Manager Auto-TLS after the manager and agent hosts are installed and visible in Cloudera Manager.

Use this top-level README for the platform install. Use `utilities/tls/README.md` when you are ready to enable Auto-TLS.

Do not run Auto-TLS before the CM agents are installed and communicating with the CM server.

### When to run Auto-TLS

Run Auto-TLS only after:

1. `RUN_MANAGER` has completed successfully on the manager host.
2. `RUN_AGENT` has completed successfully on each agent host.
3. The manager host and agent hosts appear in Cloudera Manager.
4. Cloudera Manager is reachable on HTTP port `7180`.
5. The Cloudera Manager admin credentials work.
6. Passwordless SSH works from the manager host to every cluster host using the configured Auto-TLS SSH user.
7. The hostnames in `utilities/tls/hosts.csv` match the hostnames used by Cloudera Manager.

### Auto-TLS utility files

The Auto-TLS utilities are in:

```bash
cd /root/cloudera-install-nonfips/utilities/tls
```

Important files:

| File | Purpose |
|---|---|
| `README.md` | Detailed Auto-TLS utility instructions |
| `tls.env` | Local runtime configuration for the Auto-TLS scripts |
| `tls.env.example` | Example configuration template |
| `hosts.csv` | Host inventory used to generate certificates and payload entries |
| `hosts.csv.example` | Example host inventory |
| `00_prepare_dirs.sh` | Creates the Auto-TLS artifact directories |
| `01_generate_keys_csrs.sh` | Generates host private keys and CSRs |
| `02_create_demo_ca.sh` | Creates the local CA used by the demo/local CA flow |
| `03_sign_csrs_with_demo_ca.sh` | Signs the host CSRs using the demo/local CA |
| `04_build_pkcs12_stores.sh` | Builds PKCS12 keystores and truststores for validation/use |
| `05_validate_autotls_prereqs.sh` | Validates CM API access, DNS, SSH, filesystem paths, and artifacts |
| `06_validate_artifacts.sh` | Validates certificates, keys, SANs, and stores |
| `07_enable_autotls.sh` | Calls the Cloudera Manager `generateCmca` API |

`tls.env` and `hosts.csv` are local runtime files. They should normally not be committed with customer-specific hostnames, credentials, passwords, private keys, or certificate material. Commit the `.example` files instead.

### Configure Auto-TLS utilities

On the manager host:

```bash
sudo -i
cd /root/cloudera-install-nonfips/utilities/tls

cp tls.env.example tls.env
cp hosts.csv.example hosts.csv

vi tls.env
vi hosts.csv
```

Example `hosts.csv` for a two-host manager plus agent environment:

```csv
host_id,ip_sans,dns_sans
ip-10-0-3-31.us-east-2.compute.internal,10.0.3.31,ip-10-0-3-31.us-east-2.compute.internal
ip-10-0-11-156.us-east-2.compute.internal,10.0.11.156,ip-10-0-11-156.us-east-2.compute.internal
```

The `host_id` must match the hostname Cloudera Manager knows for that host. The Cloudera Manager host must be included.

Example `tls.env` values:

```bash
export AUTO_TLS_LOCATION="/opt/cloudera/AutoTLS"
export AUTO_TLS_WORKDIR="${AUTO_TLS_LOCATION}/artifacts"

export CM_HOST="ip-10-0-3-31.us-east-2.compute.internal"
export CM_PORT="7180"
export CM_API_VERSION="v41"
export CM_USER="admin"
export CM_PASSWORD="admin"

export AUTO_TLS_SSH_USER="autotls"
export AUTO_TLS_SSH_PORT="22"
export AUTO_TLS_SSH_KEY_FILE="/home/autotls/.ssh/id_rsa"
```

The `autotls` user should have passwordless SSH from the manager host to every managed host and passwordless sudo on each host:

```bash
autotls ALL=(ALL) NOPASSWD:ALL
```

### Host private key mode

The Auto-TLS utilities support both encrypted and unencrypted host private keys.

For customer/live environments, use encrypted host keys:

```bash
export AUTO_TLS_ENCRYPT_HOST_KEYS="true"
export AUTO_TLS_HOST_KEY_PASSWORD="ChangeMe12345"
```

In this mode:

- `01_generate_keys_csrs.sh` generates encrypted PEM host private keys.
- `07_enable_autotls.sh` validates those encrypted keys.
- `07_enable_autotls.sh` creates the per-host password files Cert Manager expects:

```text
/opt/cloudera/AutoTLS/hosts-key-store/<hostname>/cm-auto-host_key.pw
```

For lab or temporary testing only, unencrypted host keys can be used:

```bash
export AUTO_TLS_ENCRYPT_HOST_KEYS="false"
```

In this mode:

- `01_generate_keys_csrs.sh` generates unencrypted PEM host private keys.
- `04_build_pkcs12_stores.sh` and `06_validate_artifacts.sh` do not use a private-key passphrase.
- `07_enable_autotls.sh` removes stale per-host password files before submitting the Auto-TLS command.

For customer work, encrypted mode is preferred.

### Demo/local CA execution sequence

Use this sequence when the utility scripts are creating and signing certificates with the local demo CA.

On the manager host:

```bash
sudo -i
cd /root/cloudera-install-nonfips/utilities/tls

source ./tls.env

rm -rf /opt/cloudera/AutoTLS/artifacts
rm -rf /opt/cloudera/AutoTLS/hosts-key-store
rm -rf /opt/cloudera/AutoTLS/trust-store
rm -rf /opt/cloudera/AutoTLS/private

./00_prepare_dirs.sh
./01_generate_keys_csrs.sh
./02_create_demo_ca.sh
./03_sign_csrs_with_demo_ca.sh
./04_build_pkcs12_stores.sh
./06_validate_artifacts.sh
./05_validate_autotls_prereqs.sh
./07_enable_autotls.sh
```

The order intentionally runs `06_validate_artifacts.sh` before `05_validate_autotls_prereqs.sh` so the prerequisite script can confirm the expected artifacts are already present.

### Real CA workflow

For a real customer CA, do not use the demo CA signing step.

Run only the preparation and CSR generation steps:

```bash
sudo -i
cd /root/cloudera-install-nonfips/utilities/tls

source ./tls.env

./00_prepare_dirs.sh
./01_generate_keys_csrs.sh
```

Send the generated CSRs to the customer CA team:

```text
/opt/cloudera/AutoTLS/artifacts/csrs/<host_id>-csr.pem
```

Place the returned host certificates here:

```text
/opt/cloudera/AutoTLS/artifacts/certs/<host_id>-cert.pem
```

Place the CA chain here:

```text
/opt/cloudera/AutoTLS/artifacts/ca/ca-chain.pem
```

Then continue with:

```bash
./04_build_pkcs12_stores.sh
./06_validate_artifacts.sh
./05_validate_autotls_prereqs.sh
./07_enable_autotls.sh
```

### What `05_validate_autotls_prereqs.sh` checks

The prerequisite script validates:

- Required local commands are present.
- `tls.env` contains required variables.
- Password values meet the script requirements.
- `hosts.csv` exists and has at least one host.
- Each host resolves through local DNS or `/etc/hosts`.
- The Cloudera Manager API responds on `http://<CM_HOST>:7180/api/<version>/cm/version`.
- CM credentials are valid.
- Passwordless SSH works to every host using `AUTO_TLS_SSH_USER` and `AUTO_TLS_SSH_KEY_FILE`.
- `/opt/cloudera/AutoTLS` is readable and writable by `cloudera-scm`.
- CA, host certificate, and host key artifacts exist.

Do not run `07_enable_autotls.sh` until `05_validate_autotls_prereqs.sh` and `06_validate_artifacts.sh` both pass.

### What `07_enable_autotls.sh` does

`07_enable_autotls.sh` builds a payload for:

```text
http://<CM_HOST>:7180/api/<CM_API_VERSION>/cm/commands/generateCmca
```

The payload includes:

- Auto-TLS location
- CA certificate path
- CM host certificate path
- CM host private key path
- host certificate/key entries for every host
- keystore and truststore password file paths
- SSH user and SSH private key for host access
- `configureAllServices=true` when configured

For encrypted host private keys, `07_enable_autotls.sh` also writes:

```text
/opt/cloudera/AutoTLS/hosts-key-store/<hostname>/cm-auto-host_key.pw
```

This is required because Cloudera Cert Manager uses those files when converting encrypted host private keys into the Auto-TLS keystore format.

If Cert Manager logs show this error:

```text
No password file found for host ... cm-auto-host_key.pw
Assuming default in-cluster password
unable to load private key
bad decrypt
```

then the per-host password file is missing or the password does not match the encrypted host private key.

### Auto-TLS outputs

The utilities create artifacts under:

```text
/opt/cloudera/AutoTLS/artifacts
```

Common outputs:

```text
/opt/cloudera/AutoTLS/artifacts/keys/<host_id>-key.pem
/opt/cloudera/AutoTLS/artifacts/csrs/<host_id>-csr.pem
/opt/cloudera/AutoTLS/artifacts/certs/<host_id>-cert.pem
/opt/cloudera/AutoTLS/artifacts/fullchains/<host_id>-fullchain.pem
/opt/cloudera/AutoTLS/artifacts/stores/<host_id>-keystore.p12
/opt/cloudera/AutoTLS/artifacts/stores/<host_id>-truststore.p12
/opt/cloudera/AutoTLS/artifacts/payload/generate_cmca_payload.json
```

### After `07_enable_autotls.sh` succeeds

After the API call succeeds, watch the logs:

```bash
tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log
tail -f /var/log/cloudera-scm-agent/certmanager.log
```

Then restart Cloudera Manager:

```bash
systemctl restart cloudera-scm-server
```

After CM returns, access the UI using HTTPS:

```text
https://<manager-host>:7183
```

Then restart the CM agent on every host:

```bash
systemctl restart cloudera-scm-agent
```

From the manager host, you can restart a remote agent with:

```bash
ssh -i /home/autotls/.ssh/id_rsa autotls@<agent-host> "sudo systemctl restart cloudera-scm-agent"
```

Finally, restart Cloudera Management Service and the cluster services from the Cloudera Manager UI.

### Post Auto-TLS notes for NiFi and NiFi Registry

After Auto-TLS, NiFi and NiFi Registry use the keystores and truststores produced by Cloudera Manager.

For NiFi Registry, if the service fails with a KeyManagerFactory or TrustManagerFactory error, check the effective process configuration first:

```bash
grep -i 'keymanager\|trustmanager\|keystoreType\|truststoreType' \
  /var/run/cloudera-scm-agent/process/*-NIFI_REGISTRY-*/nifi-registry.properties 2>/dev/null
```

If needed, set:

```properties
nifi.registry.security.keymanager.algorithm=PKIX
nifi.registry.security.trustmanager.algorithm=PKIX
```

Also verify the keystore and truststore type values match the actual stores:

```properties
nifi.registry.security.keystoreType=JKS
nifi.registry.security.truststoreType=JKS
```

or:

```properties
nifi.registry.security.keystoreType=PKCS12
nifi.registry.security.truststoreType=PKCS12
```

## 16. Common validation commands

Check OS:

```bash
cat /etc/redhat-release
uname -m
```

Check FIPS state:

```bash
cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo "0"
fips-mode-setup --check 2>/dev/null || true
```

Check Java:

```bash
java -version
alternatives --display java
ls -ld /usr/lib/jvm/java-*openjdk*
```

Check Cloudera Manager server:

```bash
systemctl status cloudera-scm-server -l --no-pager
tail -f /var/log/cloudera-scm-server/cloudera-scm-server.log
```

Check Cloudera Manager agent:

```bash
systemctl status cloudera-scm-agent -l --no-pager
systemctl status cloudera-scm-supervisord -l --no-pager
tail -f /var/log/cloudera-scm-agent/cloudera-scm-agent.log
```

Check PostgreSQL:

```bash
systemctl status postgresql-14 -l --no-pager
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

## 17. Logs

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

## 18. Quick command summary

Manager:

```bash
sudo -i
cd /root/cloudera-install-nonfips

source ./EXPORTS
sudo -E bash 00_check_connectivity.sh
sudo -E ./RUN_MANAGER
```

Agent:

```bash
sudo -i
cd /root/cloudera-install-nonfips

source ./EXPORTS
sudo -E bash 00_check_connectivity.sh
sudo -E ./RUN_AGENT
```

After CFM parcel activation, deploy and configure NiFi and NiFi Registry from Cloudera Manager.

---

## 19. Notes

This repository is intentionally non-FIPS.

Do not mix this repository with the FIPS scripts. The FIPS path requires additional crypto modules, Java provider configuration, service-specific FIPS settings, and FIPS-specific validation that are not part of this repository.

The numbered scripts are useful for troubleshooting, but the intended installation process is:

```text
Configure EXPORTS
Validate with 00_check_connectivity.sh
Run RUN_MANAGER on the manager
Run RUN_AGENT on each agent
Finish service deployment in Cloudera Manager
```
