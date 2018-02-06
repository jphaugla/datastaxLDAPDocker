create role mygroup with login = true;
grant execute on ldap scheme to mygroup;
grant select on keyspace demo to mygroup;
