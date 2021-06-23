begin;

  revoke all on schema public from public;

  create role northwind_analyst noinherit;
  grant usage on schema public to northwind_analyst;
  grant select on all tables in schema public to northwind_analyst;
  grant usage on all sequences in schema public to northwind_analyst;
  grant execute on all functions in schema public to northwind_analyst;

  create role northwind_dba noinherit;
  grant all privileges on database northwind to northwind_dba;

-- CREATE ROLE admin WITH CREATEDB CREATEROLE;
-- create database vault owner vault;
-- grant all privileges on database vault to vault;
-- alter user vault password 'vault-password';
-- alter role vault with superuser;

  -- Vault
  create role vault with superuser login createrole password 'vault-password';
commit;

