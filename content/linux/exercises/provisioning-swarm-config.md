# Provisioning Swarm Configuration

When deploying an application, especially one meant to be migrated across different environments, it's helpful to be able to provision configuration like environment variables and config files to your services in a modular, pluggable fashion. By the end of this exercise, you should be able to:

 - Assemble application components together as a Docker stack
 - Provision insecure configuration to service containers using `.env` files and Docker configs
 - Provision secure configuration to service containers using Docker secrets

## Creating a Stack

So far, we've run individual services with `docker service create`. As we build more complex applications consisting of multiple components, we'd like a way to capture them all in a single file we can version control and recreate; for this, we can use *stack files*.

1.  Create a file called `mystack.yaml` with the following content:

    ```yaml
    version: "3.7"    

    services:
      db:
        image: postgres:9.6
    ```

    This simple stack file will create a single service named `db`, based on the `postgres:9.6` image.

    > Docker stack file syntax is based on Docker Compose; we'll see numerous examples of this syntax in this workshop, but if you'd like the full reference, see the docs at [https://dockr.ly/2iHUpeX](https://dockr.ly/2iHUpeX).

2.  Deploy your stack:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c mystack.yaml dbdemo
    ```

    Your service is created, along with a default network for the stack (more on service networking in a future exercise).

3.  List your stacks and, see its services:

    ```bash
    [centos@node-0 ~]$ docker stack ls

    NAME                SERVICES            ORCHESTRATOR
    dbdemo              1                   Swarm

    [centos@node-0 ~]$ docker service ls  
    
    ID             NAME        MODE         REPLICAS   IMAGE        
    xb7cl9heahku   dbdemo_db   replicated   1/1        postgres:9.6   
    ```

    By default, your service gets named as the stack (`dbdemo`), concatenated with the key you labeled your service with in your stack file (`db`).

4.  Delete your stack:

    ```bash
    [centos@node-0 ~]$ docker stack rm dbdemo
    ```

## Defining and Using `.env` Files

Many configurations don't have strong security needs, and can be stored and transmitted unencrypted. For these, we can use *Docker config* objects.

1.  Create a file called `myvars.env` listing environment variables to define inside your container:

    ```bash
    POSTGRES_USER=moby
    POSTGRES_DB=mydb
    ```

    If defined at postgres startup, these environment variables will set the default username and database for postgres.

2.  Modify your stack file so your `db` service consumes this `.env` file:

    ```yaml
    version: "3.7"    

    services:
      db:
        image: postgres:9.6
        env_file:
          - myvars.env
    ```

3.  Redeploy your stack:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c mystack.yaml dbdemo
    ```

4.  We'd like to confirm that the environment variables got set and had the desired effect; to do so, list all the tasks running for every service in your stack:

    ```bash
    [centos@node-0 ~]$ docker stack ps dbdemo

    ID       NAME          IMAGE          NODE     DESIRED STATE   CURRENT STATE
    uil...   dbdemo_db.1   postgres:9.6   node-0   Running         Running about 
                                                                      a minute ago
    ```

    As expected, we have one service with one task, which got scheduled in my case on `node-0`.

5.  Find the container corresponding to the single task started for your `db` service:

    ```bash
    [centos@node-0 ~]$ docker inspect <task ID> | grep ContainerID

                    "ContainerID": "b2ffe30...",
    ```

6.  Confirm the environment variables you provisioned actually got set (note you'll have to run this on the node listed in the `NODE` column in the output of `docker stack ps dbdemo` above, `node-0` for me):

    ```bash
    [centos@node-0 ~]$ docker container inspect <container ID> | grep POSTGRES

                "POSTGRES_DB=mydb",
                "POSTGRES_USER=moby",
    ```

7.  Also on the node running the postgres container, run a command line interface (`psql`) inside this container to confirm your config was used to correctly set up the default user and database:

    ```bash
    [centos@node-0 ~]$ docker container exec -it <container ID> psql -U moby -d mydb

    psql (9.6.11)
    Type "help" for help.    

    mydb=# \du
                                       List of roles
     Role name |                         Attributes                         | Member of 
    -----------+------------------------------------------------------------+-----------
     moby      | Superuser, Create role, Create DB, Replication, Bypass RLS | {}    

    mydb=# \q
    ```

    We can see that the user `moby` and default database `mydb` were created as expected.

## Defining and Using Docker Configs

The config we've seen so far is centered around defining environment variables in our containers, but oftentimes we need entire configuration files or scripts to be available within our containerized environments. We can provision these flexibly in our stack definitions using *docker configs*.

1.  Create a database initialization script `db-init.sh`:

    ```bash
    #!/bin/bash
    set -e        

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE TABLE PRODUCTS(PRICE FLOAT, NAME TEXT);
        INSERT INTO PRODUCTS VALUES('18.95', 'widget');
        INSERT INTO PRODUCTS VALUES('1.45', 'sprocket');
    EOSQL
    ```

2.  On startup, the postgres container will automatically run any file `*.sh` found in the directory `/docker-entrypoint-initdb.d`. Modify your stack file to look like this:

    ```bash
    version: "3.7"    

    services:
      db:
        image: postgres:9.6
        env_file:
          - myvars.env
        configs:
          - source: initscript
            target: /docker-entrypoint-initdb.d/init.sh  

    configs:
      initscript:
        file: ./db-init.sh
    ```

    Here we see our first concrete example of composing two objects together in a stack file: our original service, and a new top-level key, `configs:`, which lists all the config objects we can provision to our service objects.

3.  Update your stack:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c mystack.yaml dbdemo
    ```

    Notice we didn't actually delete the old version of our stack first; recreating a stack with the same name and stack file will apply updates to a running stack.

4.  List and inspect your `config` objects:

    ```bash
    [centos@node-0 ~]$ docker config ls

    ID                          NAME                CREATED             UPDATED
    hjrbeqqpe8l25r7u70sulung4   dbdemo_initscript   3 minutes ago       3 minutes ago

    [centos@node-0 ~]$ docker config inspect --pretty <config ID>

    ID:			hjrbeqqpe8l25r7u70sulung4
    Name:			dbdemo_initscript
    Labels:
     - com.docker.stack.namespace=dbdemo
    Created at:            	2019-01-30 15:36:31.953234447 +0000 utc
    Updated at:            	2019-01-30 15:36:31.953234447 +0000 utc
    Data:
    #!/bin/bash
    set -e            

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE TABLE PRODUCTS(PRICE FLOAT, NAME TEXT);
        INSERT INTO PRODUCTS VALUES('18.95', 'widget');
        INSERT INTO PRODUCTS VALUES('1.45', 'sprocket');
    EOSQL
    ```

    We can recover the plain-text contents of any config option in this manner.

5.  Reconnect to your postgres database, and confirm the data got loaded correctly (remember to do this from whichever node is running your postgres container):

    ```bash
    [centos@node-0 ~]$ docker container exec -it <container ID> psql -U moby -d mydb
    psql (9.6.11)
    Type "help" for help.    

    mydb=# SELECT * FROM products;

     price |   name   
    -------+----------
     18.95 | widget
      1.45 | sprocket
    (2 rows)

    mydb=# \q
    ```

## Defining and Using Docker Secrets

In everything we've seen so far, our configurations are stored unencrypted and are recoverable directly from their definition. In some cases, this isn't good enough; when we want to store and distribute secure information like passwords or access tokens, we want this information to be encrypted by default. For this, we use *Docker secrets*.

Postgres will set the password for remote login based on the contents of the file with path specified in the `POSTGRES_PASSWORD_FILE` environment variable on startup; we'll use a secret to set this environment variable securely.

1.  On `node-0`, place your postgres password `12345678` in a file called `mypassword`.

2.  Turn the contents of `mypassword` into a Docker secret:

    ```bash
    [centos@node-0 ~]$ docker secret create password ./mypassword
    [centos@node-0 ~]$ rm mypassword
    ```

    Note we immediately remove the plaintext `mypassword` - of course we don't want it sitting around in plain text for someone to find later.

3.  Inspect your secret:

    ```bash
    [centos@node-0 ~]$ docker secret inspect password

    [
        {
            "ID": "agxqp9v4zdch2igeh59zt1qyb",
            "Version": {
                "Index": 5548
            },
            "CreatedAt": "2019-01-30T15:50:45.035216925Z",
            "UpdatedAt": "2019-01-30T15:50:45.035216925Z",
            "Spec": {
                "Name": "password",
                "Labels": {}
            }
        }
    ]
    ```

    Unlike configs, Docker won't return the value of a secret at the command line once encrypted in the raft datastore. Only containers authorized to use this secret will be able to recover it in plain text.

4.  By default, secrets are provisioned in containers as plaintext files at the path `/run/secrets/<secretname>`. Modify your stack file to consume your secret, and point to it with the `POSTGRES_PASSWORD_FILE` environment variable:

    ```yaml
    version: "3.7"    

    services:
      db:
        image: postgres:9.6
        env_file:
          - myvars.env
        configs:
          - source: initscript
            target: /docker-entrypoint-initdb.d/init.sh  
        secrets:
          - password
        environment:
          - POSTGRES_PASSWORD_FILE=/run/secrets/password

    configs:
      initscript:
        file: ./db-init.sh

    secrets:
      password:
        external: true
    ```

    Here we're adding a third top-level object, `secrets:`, to our stack; the `external: true` key indicates that we defined this object outside of our stack and are just using it here, which is a typical pattern for secrets so we can avoid having them sitting around in plain text at any time. 

5.  Update your stack, confirm the environment variables are set correctly, and check that the password is available at `/run/secrets/password` as expected:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c mystack.yaml dbdemo

    [centos@node-0 ~]$ docker stack ps dbdemo
    ID                  NAME                IMAGE               NODE   
    n0c9efwva2ri        dbdemo_db.1         postgres:9.6        node-0

    [centos@node-0 ~]$ docker inspect <task ID> | grep ContainerID
                    "ContainerID": "c1c7cef...",

    [centos@node-0 ~]$ docker container inspect <container ID> | grep POSTGRES
                    "POSTGRES_DB=mydb",
                    "POSTGRES_PASSWORD_FILE=/run/secrets/password",
                    "POSTGRES_USER=moby",

    [centos@node-0 ~]$ docker container exec <container ID> cat /run/secrets/password
    1234568
    ```

    (Remember to do the `docker container ...` commands on the node the task is actually running on). With this secret configuration, our postgres password is available in plaintext only inside the container filesystem that it has been explicitly provisioned to in our stack file.

6.  Clean up by removing your stack:

    ```bash
    [centos@node-0 ~]$ docker stack rm dbdemo
    ```

## Conclusion

In this exercise, we saw several different methods for defining and provisioning configurations, as well as our first example of a complete stack file for defining and composing all the elements of our application. Deciding what information to provision via configurations is an important architectural choice; in general, anything that's going to change when moving from environment to environment is a good candidate for a config, since env files, docker configs, and docker secrets are all modular and defined separately from the service definition itself; by separating configs in this way, we can just swap the config out when changing environments, without redefining our services. The (usually worse) alternative to provisioning by config is to include this information directly in the image; this is a good choice for information that is the same in all environments you plan on running that image in, but can lead to image management complexity and loss of portability if environment-specific information is hard-coded into the image. Of course, secure information like passwords should *never* be hard-coded into images; they should strictly be provisioned as Docker secrets, and consumed only from the temporary filesystem inside the container to which they are mounted.
