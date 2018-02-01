create role killrdevs with login = true;
grant execute on ldap scheme to killrdevs;
grant select on keyspace demo to killrdevs;
