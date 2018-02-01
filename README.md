# datastaxLDAPDocker

## About

This github covers setting up a DataStax Docker container with UnifiedAuthentication using a combination of *LDAP* and *DataStax Internal* authentication schemes. LDAP users can log in to DataStax with their role assignments also being fetched from the LDAP.  Two main docker containers are used:  openldap and DataStax Server.  A third container, phpldapadmin, is not necessary but helpful.  The fourth container, DataStax opscenter, is also not needed for this demo.

If you're looking for a tutorial for setting up LDAP with OpsCenter, have a look here: [https://gist.github.com/gmflau/2c5b1939f3df3a7e6bb2554733c7310e](LDAP with DataStax OpsCenter)

This github was created using a VM tutorial created by Matt Kennedy.  [https://git.io/v6JKb]()

The DataStax images are well documented at this github location  [https://github.com/datastax/docker-images/]()



## Getting Started
1. Prepare Docker environment
2. Pull this github into a directory
3. Follow notes from DataStax Docker github to pull the needed DataStax images.  Directions are here:  [https://github.com/datastax/docker-images/#datastax-platform-overview]().  Don't get too bogged down here.  The pull command is provided with this github in pull.sh. It is requried to have the docker login complete before running the pull.  The also included docker-compose.yaml handles most everything else.
4. Open terminal, then: `docker-compose up -d`
5. Verify LDAP is functioning `docker exec openldap ldapsearch -D "cn=admin,dc=example,dc=org" -w admin -b "dc=example,dc=org"`  This should return success (careful with this command as ldapsearch is very exacting and is confused by spaces or other slight changes in syntax.
6. Also, can login to the phpldadmin using a browser enter `localhost:8080`  For login credentials use "Login DN":  
`cn=admin,dc=example,dc=org` and "password": `admin`
7. Verify DataStax is working `docker exec dse cqlsh -u cassandra -p cassandra -e "desc keyspaces"`
8. Verify hostname on DataStax server `docker exec dse hostname --fqdn`  Expected result is: `dse.example.org` Note:  hostname command is not installed on openldap container so it won't work there but hostname will work on opscenter and phpldapadmin as well as dse.
9. Add some tables for later testing:
```
docker exec dse cqlsh -u cassandra -p cassandra -f /opt/dse/demos/solr_stress/resources/schema/create_table.cql
```
10. Also note, in the home directory for the github repository directory the docker volumes should be created as subdirectories.  To manipulate the dse.yaml file and add the LDAP authentication the local conf subdirectory will be used.  The other dse directories are logs, cache and data.

## Enable DSE Advanced Security

The general instructions for starting the DSE Advanced security set up are here:
https://docs.datastax.com/en/latest-dse/datastax_enterprise/unifiedAuth/configAuthenticate.html

This tutorial provides specific commands for this environment, so it shouldn't be necessary to refer to the docs, but they're a handy reference if something goes awry.

1. Get the IP address of the DataStax and openldap servers by running:
`export DSE_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dse)`
   and:
`export LDAP_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' openldap)`

2. Get a local copy of the dse.yaml file from the dse container.  `docker cp dse:/opt/dse/resources/dse/conf/dse.yaml .`  or if you prefer use the existing dse.yaml provided in the github.  However, this existing dse.yaml is for 5.1.5 and may not work in subsequent versions.  Also provided in the github is a diff file call dse.yaml.diff

3. Edit local copy of the dse.yaml being extremely careful to maintain the correct spaces as the yaml is space aware.   Thankfully, any errors are obvious in /var/log/cassandra/system.log on startup failure (~line 56 - 63):

    ```
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
    
    ```
    role_management_options:
    mode: ldap
    ```
    
    Continue to Edit dse.yaml (~line 94-96):
    
    ```
    authorization_options:
    enabled: true
    transitional_mode: disabled
    ```
    
    Continue to Edit dse.yaml using the $LDAP_ID retrieved in Step 1 as the IP Address for the server host below  (~line 124-125):
    
    ```
    ldap_options:
    server_host: 172.20.0.3
    ```
    
    Continue to Edit the dse.yaml (~line 130) by uncommenting the following lines and adding content:
    
    ```
    server_port: 389
    search_password: admin
    use_ssl: false
    use_tls: false
    truststore_path:
    truststore_password:
    truststore_type: jks
    user_search_base: ou=People,dc=example,dc=org
    user_search_filter: (uid={0})
    group_search_type: directory_search
    group_search_base: ou=Groups,dc=example,dc=org
    group_search_filter: (uniquemember={0})
    group_name_attribute: cn
    credentials_validity_in_ms: 0
    search_validity_in_seconds: 0
    connection_pool:
        max_active: 2
        max_idle: 2
    ```    
4. Restart the dse docker container: `docker restart dse`
5. Check logs as you go!  `docker logs dse`
4. Log in as the Cassandra user: `docker exec cqlsh -u cassandra -p cassandra`
5. create a new superuser:

    `create role matt with password = 'datastax' and login = true and superuser = true;`
6. Check the new login: `cqlsh -u matt` (password prompt this time)
7. Alter the Cassandra user’s passwd to something nonsensical:

    `alter role cassandra with password='LaceyIsBrilliant!';`


9. Log in as the *matt* admin user, then create a normal user:

    `create role patrick with password = 'cassandra' and login = true;`


    > :fire: Shin-banging for fun and profit! :fire:
    >
    > If you try to log in as patrick now, you can't, because we set scheme_permissions: true in dse.yaml

    

10. As superuser *matt*: `grant execute on internal scheme to patrick;`

    > :fire: Shin-banging for fun and profit! :fire:
    >
    > If you were to try to log in now, you'd only have access to the tables described in:
    >
    > https://docs.datastax.com/en/latest-dse/datastax_enterprise/unifiedAuth/configAuthorize.html
    
    > * system.schema_keyspace
    > * system.schema_columns
    > * system.schema_columnfamilies
    > * system.local
    > * system.peers|
    
11. As superuser *matt*, grant patrick a role: 

    ```
    create role killrvideo;
    grant select on keyspace killrvideo to killrvideo;
    grant killrvideo to patrick;
    list all permissions of patrick;
    ```

At this point, DSE Security has been set up and we have some users to work with that have been granted some permissions. You can run some select statements on the killrvideo tables to verify that *patrick* can in fact read those tables now. Let's now turn to setting up LDAP.

5. Now, we'll add some entries to our LDAP. Create a file called 'add_users.ldif' with the following contents:
    ```
    #add_users.ldif
    dn: ou=People,dc=datastax,dc=com
    objectClass: organizationalUnit
    ou: People

    dn: ou=Groups,dc=datastax,dc=com
    objectClass: organizationalUnit
    ou: Groups

    dn: cn=db,ou=Groups,dc=datastax,dc=com
    objectClass: posixGroup
    cn: db
    gidNumber: 5000

    dn: uid=kennedy,ou=People,dc=datastax,dc=com
    objectClass: inetOrgPerson
    objectClass: posixAccount
    objectClass: shadowAccount
    uid: kennedy
    sn: Kennedy
    givenName: Matt
    cn: Matt Kennedy
    displayName: Matt Kennedy
    uidNumber: 10000
    gidNumber: 5000
    userPassword: tinkerbell
    gecos: Matt Kennedy,remote,7035825017,matt.kennedy@datastax.com
    loginShell: /bin/bash
    homeDirectory: /home/kennedy
    ```

6. Add the LDIF file to the LDAP (replace the admin user with the appropriate one for your olcSuffix):

    ```
    #NB: You may have to type this one in, some copy/paste errors can result in ldapadd not being found.
    ldapadd -x -D cn=admin,dc=datastax,dc=com -W -f add_users.ldif
    ```

7. Do an LDAP Search to see the new user:

    ```
    ldapsearch -x -LLL -D  uid=kennedy,ou=People,dc=datastax,dc=com -W -b dc=datastax,dc=com 'uid=kennedy'
    ```

    > :fire: Shin-banging for fun and profit! :fire:
    >
    > The password for the above command was given in plaintext in the LDIF file.
    > Try entering the wrong password to verify that it's checking the password for the user.

8. Now let's add a *mcfadin* user. First, create the LDIF:

    ```
    #add_mcfadin.ldif
    dn: uid=mcfadin,ou=People,dc=datastax,dc=com
    objectClass: inetOrgPerson
    objectClass: posixAccount
    objectClass: shadowAccount
    uid: mcfadin
    sn: McFadin
    givenName: Patrick
    cn: Patrick McFadin
    displayName: Patrick McFadin
    uidNumber: 10001
    gidNumber: 5000
    userPassword: ariel
    gecos: Patrick McFadin,remote,7079748575,patrick@datastax.com
    loginShell: /bin/bash
    homeDirectory: /home/mcfadin
    ```

9. Based on the ldapadd command in step 6, figure out how to add *mcfadin* and then test a search with his password.

## Set up LDAP in dse.yaml

Now, we'll connect DSE with LDAP.

> :fire: Shin-banging for fun and profit! :fire:
>
> If you're a masochist, have a go at configuring the LDAP section of dse.yaml yourself.
> You may find it helpful to setting the log level to TRACE in logback.xml.
> In case you're wondering, I've already filed: https://datastax.jira.com/browse/DSP-10595

Just so we can inspect what's going on in the next few steps,
follow these instructions to enable syslog output from OpenLDAP: 

First, make a new LDIF file:

```
#logging.ldif
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats
```

Then execute it: `sudo ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f logging.ldif`

Finally, open up a new terminal window and tail -f/less (cap F) /var/log/syslog

1. Verify that dse.yaml has the following sections:

    - Uncomment the ldap entry for other_schemes, that section should look like:
    ```
    authentication_options:
        enabled: true
        default_scheme: internal
        other_schemes:
          - ldap
        scheme_permissions: true
        allow_digest_with_kerberos: true
        plain_text_without_ssl: warn
        transitional_mode: disabled
    ```
    - Including line numbers for this next section because it's so long. Obvs, don't add them in.

    ```
    117 # LDAP options
    118 #
    119 # These are options are used when the com.datastax.bdp.cassandra.auth.LdapAuthenticator
    120 # is configured as the authenticator in cassandra.yaml
    121 #
    122 ldap_options:
    123     server_host: <your vm's ip>
    124     # Port to use to connect to the LDAP server. This is normally 389 for unencrypted
    125     # connections and 636 for ssl encrypted connections. If use_tls is set to true, use the
    126     # unencrypted port
    127     server_port: 389
    128     # The distinguished name (DN) of the user that is used to search for other users on the
    129     # LDAP server. This user should have only the necessary permissions to do the search
    130     # If not present then an anonymous bind is used for the search
    131     #search_dn: cn=admin,dc=datastax,dc=com
    132     # Password of the search user
    133     #search_password: datastax
    134     # Set to true to use an SSL encrypted connection. In this case the server_port needs
    135     # to be set to the LDAP port for the server
    136     use_ssl: false
    137     # Set to true to initiate a TLS encrypted connection on the default ldap port
    138     use_tls: false
    139     truststore_path:
    140     truststore_password:
    141     truststore_type: jks
    142     user_search_base: ou=People,dc=datastax,dc=com
    143     user_search_filter: (uid={0})
    144     # Set to the attribute on the user entry containing group membership information.
    145 #    user_memberof_attribute: memberof
    146     # The group_search_type defines how group membership will be determined for a user. It
    147     # can be one of:
    148     #   directory_search - will do a subtree search of group_search_base using
    149     #                      group_search_filter to filter the results
    150     #   memberof_search - will get groups from the memberof attribute of the user. This
    151     #                     requires the directory server to have memberof support
    152     group_search_type: directory_search
    153     group_search_base: ou=Groups,dc=datastax,dc=com
    154     group_search_filter: (uniquemember={0})
    155     # The attribute in the group entry that holds the group name.
    156     group_name_attribute: cn
    157     # Validity period for the credentials cache in milli-seconds (remote bind is an expensive
    158     # operation). Defaults to 0, set to 0 to disable.
    159     credentials_validity_in_ms: 0
    160     # Validity period for the search cache in seconds. Defaults to 0, set to 0 to disable.
    161     search_validity_in_seconds: 0
    162     connection_pool:
    163         max_active: 2
    164         max_idle: 2
    ```

2. Restart DSE: `service dse restart`
3. Try to log in w/McFadin (keep an eye on syslog window): `cqlsh -u mcfadin`
4. Why doesn't it work?
5. Fix it: `create role mcfadin with login = true;`
6. `cqlsh -u mcfadin` -- It STILL doesn't work?
7. Why doesn't it work?
8. Fix it: `grant execute on ldap scheme to mcfadin;`

So, LDAP is only good for storing passwords? At this stage of the lab, the only thing that LDAP is buying us is the ability to store each user's password in a separate service. Basically, for each user provisioned in LDAP, a role has to be provisioned in DSE with the LDAP users privileges. That obviously isn't the most scalable system in the world. But, with DSE 5.0, we can instead get a role assignment from LDAP. This actually works in one of two ways. We'll cover the more commonly used, easier to configure, but slightly less efficient option in this lab called a Directory Search. The other option is called  a memberOf search.

## Configure DSERoleManager to Enable DSE + LDAP Roles

Note that the instructions so far already created a group called *db* earlier in the process when we added the *kennedy* user. Let's try to log in to DSE by adding the db role to the database.


1. Log in as the *matt* admin user, then:

    ```
    create role db with login = true;
    grant execute on ldap scheme to db;
    ```

2. `cqlsh -u kennedy`
3. Why didn't that work? Let's check dse.yaml... Did we set the role_management_options?

    ```
     role_management_options:
        mode: ldap
    ```

4. Reboot DSE: `service dse restart` ... How about now?: `cqlsh -u kennedy`
5. That still didn't work? We can see the search going through in syslog...
6. D’oh! -- That group we added is a posixGroup, which is used to assign a "primary group" to an OS login. We need to add a different kind of group called a uniqueMemberOf group. Create a new LDIF file:

    ```
    #killrdevs.ldif
    dn: cn=killrdevs,ou=Groups,dc=datastax,dc=com
    objectClass: groupOfUniqueNames
    cn: killrdevs
    uniquemember: uid=kennedy,ou=People,dc=datastax,dc=com
    ```
    
7. Add it to the LDAP and check to see if we can do a group search: 

    ```
    ldapadd -x -D cn=admin,dc=datastax,dc=com -W -f killrdevs.ldif
    ldapsearch -x -LLL -D  uid=mcfadin,ou=People,dc=datastax,dc=com -W -b ou=groups,dc=datastax,dc=com  "(uniqueMember=uid=kennedy,ou=People,dc=datastax,dc=com)" cn
    ```

8.  Log in as the *matt* admin user, then:

    ```
    create role killrdevs with login = true;
    grant execute on ldap scheme to killrdevs;
    grant select on keyspace killrvideo to killrdevs;
    ```
    
9. Finally, log in as the *kennedy* user successfully: `cqlsh -u kennedy`

## Conclusion
At this point, DSE and LDAP are connected such that user management is much easier than it has been before. We can use internal Cassandra auth for the app-tier or for dev/test users that really have no business in an LDAP. LDAP can be used for real human user's accounts using any groups that an individual belongs to, or that have been created for use with DSE. The only additional overhead that the DSE admin has is to create a role name matching an LDAP group assignment and to assign appropriate permissions to that role. This results in a far more manageable permissions catalog inside of DSE as compared to releases prior to 5.0.

###Additional Experiments

1. What happens if there is an LDAP user with the same uid as an internal role? Does it make any difference which is the default\_scheme and which is an other\_scheme entry?
2. What is required to use a memberof\_search instead of a directory\_search? What are the advantages of a memberof\_search?
    * http://www.adimian.com/blog/2014/10/how-to-enable-memberof-using-openldap/
    * https://technicalnotes.wordpress.com/2014/04/19/openldap-setup-with-memberof-overlay/
3. Set up SSL connections and figure out how to avoid plaintext passwords in LDIF files.
4. Investigate the ldapscripts package. Can you make devise a template that allows easy user management for DSE users?
