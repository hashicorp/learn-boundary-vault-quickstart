# Boundary and Vault Integration Quickstart

This directory contains an example deployment of Boundary using docker-compose and Terraform. The lab environment is meant to accompany the Hashicorp Learn [Boundary Vault integration quickstart tutorial](https://learn.hashicorp.com/tutorials/boundary/vault-quickstart).

In this example, a demo postgres database target is deployed. A dev Vault server is then configured using the database secrets engine and policies allowing Boundary to request credentials for two roles, a DBA and an "analyst". Boundary is then run in dev mode, and the DBA and analyst targets are configured using a credential store that contains credential libraries for both targets. This enables credential brokering via Vault, which is demonstrated using the `boundary connect postgres` command.

1. Setup PostgreSQL Northwind demo database
2. Setup Vault
3. Setup Boundary
4. Use Boundary to connect to the Northwind demo database

## Setup PostgreSQL Northwind demo database


```shell
export PG_DB="northwind";export PG_URL="postgres://postgres:secret@localhost:16001/${PG_DB}?sslmode=disable"
docker run -d -e POSTGRES_PASSWORD=secret -e POSTGRES_DB="${PG_DB}" --name ${PG_DB} -p 16001:5432 postgres
psql -d $PG_URL -f northwind-database.sql
psql -d $PG_URL -f northwind-roles.sql
```

## Setup Vault

### Run Vault in dev mode

```shell
export VAULT_ADDR="http://127.0.0.1:8200"; export VAULT_TOKEN="groot"
vault server -dev -dev-root-token-id=${VAULT_TOKEN}
```

### Create boundary-controller policy

```shell
vault policy write boundary-controller boundary-controller-policy.hcl
```

### Configure database secrets engine

1. Enable the database secrets engine:

    ```shell
    vault secrets enable database
    ```

1. Configure Vault with the proper plugin and connection information:

    ```shell
    vault write database/config/northwind \
         plugin_name=postgresql-database-plugin \
         connection_url="postgresql://{{username}}:{{password}}@localhost:16001/postgres?sslmode=disable" \
         allowed_roles=dba,analyst \
         username="vault" \
         password="vault-password"
    ```

1. Create the DBA role that creates credentials with `dba.sql.hcl`:

    ```shell
    vault write database/roles/dba \
          db_name=northwind \
          creation_statements=@dba.sql.hcl \
          default_ttl=3m \
          max_ttl=60m
    ```

    Request DBA credentials from Vault to confirm:

    ```shell
    vault read database/creds/dba
    ```

1. Create the analyst role that creates credentials with `analyst.sql.hcl`:

    ```shell
    vault write database/roles/analyst \
          db_name=northwind \
          creation_statements=@analyst.sql.hcl \
          default_ttl=3m \
          max_ttl=60m
    ```

    Request analyst credentials from Vault to confirm:

    ```shell
    vault read database/creds/analyst
    ```

### Create northwind-database policy

```shell
vault policy write northwind-database northwind-database-policy.hcl
```

### Create vault token for Boundary credential store

```shell
vault token create \
  -no-default-policy=true \
  -policy="boundary-controller" \
  -policy="northwind-database" \
  -orphan=true \
  -period=20m \
  -renewable=true
```

## Setup Boundary

### Run Boundary in dev mode

```shell
boundary dev
```

### Authenticate to Boundary

```shell
boundary authenticate password \
  -auth-method-id=ampw_1234567890 \
  -login-name=admin \
  -password=password
```

### Configure Database Target

#### Option 1: Edit existing target

```shell
boundary targets update tcp -id=ttcp_1234567890 -default-port=16001
```

#### Option 2: Create new target

1. Create target for analyst

    ```shell
    boundary targets create tcp \
      -scope-id "p_1234567890" \
      -default-port=16001 \
      -session-connection-limit=-1 \
      -name "Northwind Analyst Database"
    ```

    ID: `ttcp_MugI59YN6b`

1. Create target for DBA

    ```shell
    boundary targets create tcp \
      -scope-id "p_1234567890" \
      -default-port=16001 \
      -session-connection-limit=-1 \
      -name "Northwind DBA Database"
    ```

    ID: `ttcp_4J24foaobT`

1. Add host set to both

    ```shell
    boundary targets add-host-sets -host-set=hsst_1234567890 -id=ttcp_MugI59YN6b
    boundary targets add-host-sets -host-set=hsst_1234567890 -id=ttcp_4J24foaobT
    ```

### Connect to Database

```shell
boundary connect postgres -target-id ttcp_1234567890 -username postgres
```

Password is `secret`.

### Create Vault Credential Store

```shell
boundary credential-stores create vault -scope-id "p_1234567890" \
  -vault-address "http://127.0.0.1:8200" \
  -vault-token "s.kGa7MXH1YXvrFWNunGgppnnk"
```

### Create Credential Libraries

1. Create library for analyst credentials

    ```shell
    boundary credential-libraries create vault \
      -credential-store-id ${CS_ID} \
      -vault-path "database/creds/analyst" \
      -name "northwind analyst"
    ```

    Analyst Library ID: `clvlt_3zCNiY66lG`

1. Create library for DBA credentials

    ```shell
    boundary credential-libraries create vault \
      -credential-store-id ${CS_ID} \
      -vault-path "database/creds/dba" \
      -name "northwind dba"
    ```

    DBA Library ID: `clvlt_vaaDNUTZmi`

### Add Credential Libraries to Targets

1. Analyst target

    ```shell
    boundary targets add-credential-libraries \
      -id=ttcp_MugI59YN6b \
      -application-credential-library=clvlt_3zCNiY66lG
    ```

1. DBA target

    ```shell
    boundary targets add-credential-libraries \
      -id=ttcp_4J24foaobT \
      -application-credential-library=clvlt_vaaDNUTZmi
    ```
## Use Boundary to connect to the Northwind demo database

1. Analyst target

    ```shell
    boundary connect postgres -target-id ttcp_MugI59YN6b -dbname northwind
    ```
