# Database Volumes

By the end of this exercise, you should be able to:

 - Provide a docker volume as a database backing to Postgres
 - Recover a Postgres database from volume contents after destroying the original Postgres container

## Launching Postgres

1.  Download a postgres image, and look at its history to determine its default volume usage:

    ```bash
    [centos@node-0 ~]$ docker image pull postgres:9-alpine
    [centos@node-0 ~]$ docker image inspect postgres:9-alpine

    ...
    "Volumes": {
        "/var/lib/postgresql/data": {}
    },
    ...
    ```

    You should see a `Volumes` block like the above, indicating that those paths in the container filesystem will get volumes automatically mounted to them when a container is started based on this image.

2.  Set up a running instance of this postgres container:

    ```bash
    [centos@node-0 ~]$ docker container run --name some-postgres \
        -v db_backing:/var/lib/postgresql/data \
        -d postgres:9-alpine
    ```

    Notice the explicit volume mount, `-v db_backing:/var/lib/postgresql/data`; if we hadn't done this, a randomly named volume would have been mounted to the container's `/var/lib/postgresql/data`. Naming the volume explicitly is a best practice that will become useful when we start mounting this volume in multiple containers.

## Writing to the Database 

1.  The `psql` command line interface to postgres comes packaged with the postgres image; spawn it as a child process in your postgres container interactively, to create a postgres terminal:

    ```bash
    [centos@node-0 ~]$ docker container exec \
        -it some-postgres psql -U postgres
    ```

2.  Create an arbitrary table in the database:

    ```bash
    postgres=# CREATE TABLE PRODUCTS(PRICE FLOAT, NAME TEXT);
    postgres=# INSERT INTO PRODUCTS VALUES('18.95', 'widget');
    postgres=# INSERT INTO PRODUCTS VALUES('1.45', 'sprocket');
    ```

    Double check you created the table you expected, and then quit this container:

    ```bash
    postgres=# SELECT * FROM PRODUCTS;

      price  |  name  
    ---------+-----------
      18.95  | widget
      1.45   | sprocket
    (2 rows)

    postgres=# \q
    ```

3.  Delete the postgres container:

    ```bash
    [centos@node-0 ~]$ docker container rm -f some-postgres
    ```

4.  Create a new postgres container, mounting the `db_backing` volume just like last time:

    ```bash
    [centos@node-0 ~]$ docker container run \
        --name some-postgres \
        -v db_backing:/var/lib/postgresql/data \
        -d postgres:9-alpine
    ```

5.  Reconnect a `psql` interface to your database, also like before:

    ```bash
    [centos@node-0 ~]$ docker container exec \
        -it some-postgres psql -U postgres
    ```

6.  List the contents of the `PRODUCTS` table:

    ```bash
    postgres=# SELECT * FROM PRODUCTS;
    ```

    The contents of the database have survived the deletion and recreation of the database container; this would not have been true if the database was keeping its data in the writable container layer. As above, use `\q` to quit from the postgres prompt.

## Conclusion

Whenever data needs to live longer than the lifecycle of a container, it should be pushed out to a volume outside the container's filesystem; numerous popular databases are containerized using this pattern.
