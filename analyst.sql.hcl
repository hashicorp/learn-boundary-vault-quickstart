create role "{{name}}"
with login password '{{password}}'
valid until '{{expiration}}' inherit;
grant northwind_analyst to "{{name}}";
