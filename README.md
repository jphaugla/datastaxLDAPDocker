# datastaxLDAPDocker

## About

This github covers setting up a DataStax Docker container with UnifiedAuthentication using a combination of *LDAP* and *DataStax Internal* authentication schemes. LDAP users can log in to DataStax with their role assignments also being fetched from the LDAP.  Two main docker containers are used:  openldap and DataStax Server.  A third container, phpldapadmin, is not necessary but helpful.  The fourth container, DataStax opscenter, is also not needed for this demo.

If you're looking for a tutorial for setting up LDAP with OpsCenter, have a look here: [OpCenter LDAP](https://gist.github.com/gmflau/2c5b1939f3df3a7e6bb2554733c7310e)

This github was created using a VM tutorial created by Matt Kennedy.  [LDAP DataStax VM tutorial](https://git.io/v6JKb)

The DataStax images are well documented at this github location  [https://github.com/datastax/docker-images/](https://github.com/datastax/docker-images/)



## Getting Started
1. Prepare Docker environment
2. Pull this github into a directory  
```bash
git clone https://github.com/jphaugla/datastaxLDAPDocker.git
```
3. Follow notes from DataStax Docker github to pull the needed DataStax images.  Directions are here:  [https://github.com/datastax/docker-images/#datastax-platform-overview](https://github.com/datastax/docker-images/#datastax-platform-overview).  Don't get too bogged down here.  The pull command is provided with this github in pull.sh. It is requried to have the docker login and **subscription** complete before running the pull.  The also included docker-compose.yaml handles most everything else.
4. Open terminal, then: `docker-compose up -d`
5. Verify LDAP is functioning 
```bash
docker exec openldap ldapsearch -D "cn=admin,dc=example,dc=org" -w admin -b "dc=example,dc=org"
```
This should return success (careful with this command as ldapsearch is very exacting and is confused by spaces or other slight changes in syntax.
6. Also, can login to the phpldadmin using a browser enter `localhost:8080`  For login credentials use "Login DN":  
`cn=admin,dc=example,dc=org` and "password": `admin`
7. Verify DataStax is working 
```bash
docker exec dse cqlsh -u cassandra -p cassandra -e "desc keyspaces"
```
8. Verify hostname on DataStax server `docker exec dse hostname --fqdn`  Expected result is: `dse.example.org` Note:  hostname command is not installed on openldap container so it won't work there but hostname will work on opscenter and phpldapadmin as well as dse.
9. Add demo tables and keyspace for later testing:
```bash
docker exec dse cqlsh -u cassandra -p cassandra -f /opt/dse/demos/solr_stress/resources/schema/create_table.cql
```
10. Also note, in the home directory for the github repository directory the docker volumes should be created as subdirectories.  To manipulate the dse.yaml file and add the LDAP authentication the local conf subdirectory will be used.  The other dse directories are logs, cache and data.

## Enable DSE Advanced Security

The general instructions for starting the DSE Advanced security set up are here:
[https://docs.datastax.com/en/latest-dse/datastax_enterprise/unifiedAuth/configAuthenticate.html](https://docs.datastax.com/en/latest-dse/datastax_enterprise/unifiedAuth/configAuthenticate.html)

This tutorial provides specific commands for this environment, so it shouldn't be necessary to refer to the docs, but they are a handy reference if something goes awry.  Note, the group for LDAP role authentication can be set up using a Directory Group Search or using a member of Group lookup.  The dse.yaml is configured to use both with a one line toggle to change between the two.

1. Get the IP address of the DataStax and openldap servers by running:
```bash
export DSE_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dse)
```
   and:
```bash
export LDAP_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' openldap)
```
use `echo $DSE_IPE` and `echo $LDAP_IP` to view

2. Get a local copy of the dse.yaml file from the dse container or use the existing dse.yaml provided in the github.  However, this existing dse.yaml is for 5.1.6 and may not work in subsequent versions.  Also provided in the github is a diff file called dse.yaml.diff.   To use github dse.yaml that is already modified, don't run the following command and skip subsequent step 3.  To follow step 3, get the clean dse.yaml file.

```bash
docker cp dse:/opt/dse/resources/dse/conf/dse.yaml .
``` 

3. Edit local copy of the dse.yaml being extremely careful to maintain the correct spaces as the yaml is space aware.   Thankfully, any errors are obvious in /var/log/cassandra/system.log on startup failure (~line 56 - 63):

```yaml
authentication_options:
    enabled: true
    default_scheme: internal
    allow_digest_with_kerberos: true
    plain_text_without_ssl: warn
    transitional_mode: disabled
    other_schemes:
      - ldap
    scheme_permissions: true
```
    Continue to Edit dse.yaml (~line 76-77):
    
```yaml
role_management_options:
    mode: ldap
```
    Continue to Edit dse.yaml (~line 94-96):
    
```yaml
authorization_options:
    enabled: true
    transitional_mode: disabled
```
    Continue to Edit dse.yaml using the $LDAP_ID retrieved in Step 1 as the IP Address for the server host below  (~line 124-125):
```yaml
 ldap_options:
    server_host: dse
```
Continue to Edit the dse.yaml (~line 130) by uncommenting the following lines and adding content.  This is the point where a choice can be made between the group search type:
```yaml
    server_port: 389
    search_dn: cn=admin,dc=example,dc=org
    search_password: admin
    use_ssl: false
    use_tls: false
    truststore_path:
    truststore_password:
    truststore_type: jks
    user_search_base: ou=People,dc=example,dc=org
    user_search_filter: (uid={0})
    group_search_type: directory_search
    #group_search_type: memberof_search
    group_search_base: ou=Groups,dc=example,dc=org
    group_search_filter: (uniquemember={0})
    group_name_attribute: cn
    credentials_validity_in_ms: 0
    search_validity_in_seconds: 0
    connection_pool:
        max_active: 2
        max_idle: 2
```    
4. Save this edited dse.yaml file to the conf subdirectory and it will be picked up on the next dse restart. `cp dse.yaml conf` For notes on this look here:  [https://github.com/datastax/docker-images/#using-the-dse-conf-volume](https://github.com/datastax/docker-images/#using-the-dse-conf-volume)
5. Restart the dse docker container: `docker restart dse`
6. Check logs as you go!  `docker logs dse`
7. To allow for memberof_search search type, enable memberof for the ldap server.
```bash
docker cp memberof2.ldif openldap:/root;
docker exec openldap ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /root/memberof2.ldif
```
8. Add an LDAP user by copying the ldif file to the container and then running ldapadd.  This adds the directory_search style group killrdevs for ldap 
```bash
docker cp add_kennedy.ldif openldap:/root;
docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=org" -w admin -f /root/add_kennedy.ldif
```
9. Do an LDAP Search to see the new user:
```bash
    docker exec openldap ldapsearch -D "cn=admin,dc=example,dc=org" -w admin -b "dc=example,dc=org" -H ldap://openldap    
```
 10. Additional users can be added using ldif file such as provided add_matt.ldif using a similar ldapadd command as in step 7 above.
 11. To instead set up memberof_search, add a member to a group.
```bash
    docker cp add_john_doe.ldif openldap:/root
    docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=org" -w admin -f /root/add_john_doe.ldif
``` 
 12. Use an ldapsearch to ensure member of is set
```bash
docker exec openldap ldapsearch -x -LLL -w admin -D cn=admin,dc=example,dc=org -H ldap:/// -b dc=example,dc=org memberof
```

## Configure DSERoleManager to Enable DSE + LDAP Roles


1.  Create killrdevs cassandra role:
```bash
docker cp killrdevs.cql dse:/opt/dse;
docker exec dse cqlsh -u cassandra -p cassandra -f /opt/dse/killrdevs.cql
```  
2. Finally, log in as the *kennedy* user successfully  : 
```bash
docker exec dse cqlsh -u kennedy -p tinkerbell -e "select * from demo.solr"
```
3. For memberof_search create mygroup cassandra role:
```bash
docker cp mygroup.cql dse:/opt/dse;
docker exec dse cqlsh -u cassandra -p cassandra -f /opt/dse/mygroup.cql
``` 
4. Log in as the *john* user successfully  : 
```bash
docker exec dse cqlsh -u john -p public -e "select * from demo.solr"
```

## Conclusion
At this point, DSE and LDAP are connected such that user management is much easier than it has been before. We can use internal Cassandra auth for the app-tier or for dev/test users that really have no business in an LDAP. LDAP can be used for real human user's accounts using any groups that an individual belongs to, or that have been created for use with DSE. The only additional overhead that the DSE admin has is to create a role name matching an LDAP group assignment and to assign appropriate permissions to that role. This results in a far more manageable permissions catalog inside of DSE as compared to releases prior to 5.0.
