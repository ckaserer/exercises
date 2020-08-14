# Database Volumes

By the end of this exercise, you should be able to:

 - Provide a docker volume as a database backing to mongodb
 - Make one mongodb container's database available to other mongodb containers

## Launching mongodb

1.  Download a mongodb image, and inspect it to determine its default volume usage:

    ```powershell
    PS: node-0 Administrator> docker image pull training/mongo:ws19
    PS: node-0 Administrator> docker image inspect training/mongo:ws19

    ...
    "Volumes": {
        "C:\\data\\configdb": {},
        "C:\\data\\db": {}
    },
    ...
    ```

    You should see a `Volumes` block like the above, indicating that those paths in the container filesystem will get volumes automatically mounted to them when a container is started based on this image.

2.  Set up a running instance of this mongodb container:

    ```powershell
    PS: node-0 Administrator> docker container run --name mongoserv -d `
        -v mongodata:C:\data\db `
        training/mongo:ws19
    ```

    Notice the explicit volume mount, `-v mongodata:C:\data\db`; if we hadn't done this, a randomly named volume would have been mounted to the container's `C:\data\db`. Naming the volume explicitly is a best practice that will become useful when we start mounting this volume in multiple containers.

## Writing to the Database 

1.  Spawn a `mongo` process inside your mongodb container:

    ```powershell
    PS: node-0 Administrator> docker container exec -it mongoserv mongo
    ```

    You'll be presented with a mongodb terminal where you can manipulate a database directly.

2.  Create an arbitrary table in the database:

    ```powershell
    > use products
    > db.products.save({"name":"widget", "price":"18.95"})
    > db.products.save({"name":"sprocket", "price":"1.45"})
    ```

    Double check you created the table you expected, and then quit this container:

    ```powershell
    > db.products.find()

    { "_id" : ObjectId("..."), "name" : "widget", "price" : "18.95" }
    { "_id" : ObjectId("..."), "name" : "sprocket", "price" : "1.45" }

    > exit
    ```

3.  Delete the `mongoserv` container:

    ```powershell
    PS: node-0 Administrator> docker container rm -f mongoserv
    ```

4.  Create a new mongodb server container, mounting the `mongodata` volume just like last time:

    ```powershell
    PS: node-0 Administrator> docker container run --name mongoserv -d `
        -v mongodata:C:\data\db `
        training/mongo:ws19
    ```

5.  Spawn another `mongo` process inside this new container to get a mongodb terminal, also like before:

    ```powershell
    PS: node-0 Administrator> docker container exec -it mongoserv mongo
    ```

6.  List the contents of the `products` database:

    ```powershell
    > use products
    > db.products.find()
    ```

    The contents of the database have survived the deletion and recreation of the database container; this would not have been true if the database was keeping its data in the writable container layer. As above, use `exit` to quit from the mongodb prompt.

7.  Delete your mongodb container and volume:

    ```powershell
    PS: node-0 Administrator> docker container rm -f mongoserv
    PS: node-0 Administrator> docker volume rm mongodata
    ```

## Conclusion

Whenever data needs to live longer than the lifecycle of a container, it should be pushed out to a volume outside the container's filesystem; numerous popular databases are containerized using this pattern.
