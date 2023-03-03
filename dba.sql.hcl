-- Copyright (c) HashiCorp, Inc.
-- SPDX-License-Identifier: MPL-2.0

create role "{{name}}"
with login password '{{password}}'
valid until '{{expiration}}' inherit;
grant northwind_dba to "{{name}}";
