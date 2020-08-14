# Containerizing an Application

In this exercise, you'll be provided with the application logic of a simple three tier application; your job will be to write Dockerfiles to containerize each tier, and write a Docker Compose file to orchestrate the deployment of that app. This application serves a website that presents cat gifs pulled from a database. The tiers are as follows:

- **Database**: Postgres 9.6
- **API**: Java SpringBoot built via Maven
- **Frontend**: NodeJS + Express

Basic success means writing the Dockerfiles and docker-compose file needed to deploy this application to your orchestrator of choice; to go beyond this, think about minimizing image size, maximizing image performance, and making good choices regarding configuration management.

Start by cloning the source code for this app:

```bash
[centos@node-0 ~]$ git clone -b ee3.0 \
    https://github.com/docker-training/fundamentals-final.git
```

## Containerizing the Database

1.  Navigate to `fundamentals-final/database` to find the config for your database tier.

2.  Begin writing a Dockerfile for your postgres database image by choosing an appropriate base image.

3.  Your developers have provided you with postgres configuration files `pg_hba.conf` and `postgresql.conf`. Both of these need to be present in `/usr/share/postgresql/9.6/`.

4.  You have also been provided with `init-db.sql`. This SQL script populates your database with the required cat gifs. Read the docs for Postgres and / or your base image to determine how to run this script.

5.  Postgres expects the environment variables `POSTGRES_USER` and `POSTGRES_DB` to be set at runtime. Make sure these are set to `gordonuser` and `ddev`, respectively, when your database container is running.

6.  Once you've built your image, try running it, connecting to it, and querying the postgres database to make sure it's up and running as you'd expect:

    ```bash
    [centos@node-0 ~]$ docker container run --name database -d mydb:latest
    [centos@node-0 ~]$ docker container exec -it database bash
    [root@641172f742a5 /]# psql ddev gordonuser -c 'select * from images;'
    ```

    If everything is working correctly, you should see a table with URLs to cat gifs returned by the query. Exit and delete this container once you're satisfied that it is working correctly.

## Containerizing the API

1.  Navigate to `fundamentals-final/api` to find the source and config for your api tier.

2.  We intend to build this SpringBoot API with Maven. Begin writing a Dockerfile for your API by choosing an appropriate base image for your **build** environment.

3.  Your developers gave you the following pieces of information:

    - Everything Maven needs to build our API is in `fundamentals-final/api`.
    - The Maven commands to build your API are:

    ```bash
    $ mvn -B -f pom.xml -s /usr/share/maven/ref/settings-docker.xml dependency:resolve
    $ mvn -B -s /usr/share/maven/ref/settings-docker.xml package -DskipTests
    ```

    - This will produce a jar file `target/ddev-0.0.1-SNAPSHOT.jar` at the path where you ran Maven.
    - In order to successfully access Postgres, the **execution** environment for your API should be based on Java 8 in an alpine environemnt, and have the user `gordon`, as per:

    ```bash
    $ adduser -Dh /home/gordon gordon
    ```

    - The correct command to launch your API after it's built is:

    ```bash
    $ java -jar <path to jar file>/ddev-0.0.1-SNAPSHOT.jar \
        --spring.profiles.active=postgres
    ```

    Use this information to finish writing your API Dockerfile. Mind your image size, and think about what components need to be present in production.

4.  Once you've built your API image, set up a simple integration test between your database and api by creating a container for each, attached to a network:

    ```bash
    [centos@node-0 ~]$ docker network create demo_net
    [centos@node-0 ~]$ docker container run \
        -d --network demo_net --name database mydb:latest
    [centos@node-0 ~]$ docker container run \
        -d --network demo_net -p 8080:8080 --name api myapi:latest
    ```

5.  Curl an API endpoint:

    ```bash
    [centos@node-0 ~]$ curl localhost:8080/api/pet
    ```

    If everything is working correctly, you should see a JSON response containing one of the cat gif URLs from the database. Leave this integration environment running for now.

## Containerizing the Frontend

1.  Navigate to `fundamentals-final/ui` to find the source and config for your web frontend.

2.  You know the following about setting up this frontend:

    - It's a node application.
    - The filesystem structure under `fundamentals-final/ui` is exactly as it should be in the frontend's running environment.
    - Install proceeds by running `npm install` in the same directory as `package.json`.
    - The frontend is started by running `node src/server.js`.

    Write a Dockerfile that makes an appropriate environment, installs the frontend and starts it on container launch.

3.  Once you've built your ui image, start a container based on it, and attach it to your integration environment from the last step. Check to see if you can hit your website in your browser at `IP:port/pet`; if so, you have successfully containerized all three tiers of your application.

## Orchestrating the Application

Once all three elements of the application are containerized, it's time to assemble them into a functioning application by writing a Docker compose file. The environmental requirements for each service are as follows:

- **Database**:
  - Named `database`.
  - Make sure the environment variables `POSTGRES_USER` and `POSTGRES_DB` are set in the compose file, if they weren't set in the database's Dockerfile (when would you want to set them in one place versus the other?).
  - The database will need to communicate with the API.
- **API**:
  - Named `api`.
  - The API needs to communicate with both the database and the web frontend.
- **Frontend**:
  - Named `ui`.
  - Serves the web frontend on container port 3000.
  - Needs to be able to communicate with the API.

Write a `docker-compose.yml` to capture this configuration, and use it to stand up your app with Docker Compose, Swarm, or Kubernetes. Make sure the website is reachable from the browser.

## Conclusion

In this exercise, you containerized and orchestrated a simple three tier application by writing a Dockerfile for each service, and a Docker Compose file for the full application. In practice, developers should be including their Dockerfiles with their source code, and senior developers and / or application architects should be providing Docker Compose files for the full application, possibly in conjunction with the operations team for environment-specific config.

Compare your Dockerfiles and Docker Compose file with other people in the class; how do your solutions differ? What are the possible advantages of each approach?
