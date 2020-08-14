# Starting a Compose App

By the end of this exercise, you should be able to:

 - Read a basic docker compose yaml file and understand what components it is declaring
 - Start, stop, and inspect the logs of an application defined by a docker compose file

## Preparing Service Images

1.  Download the Dockercoins app from github:

    ```powershell
    PS: node-0 Administrator> git clone -b ee3.0-ws19 `
        https://github.com/docker-training/orchestration-workshop-net.git
    PS: node-0 Administrator> cd orchestration-workshop-net
    ```

    This app consists of 5 services: a random number generator `rng`, a `hasher`, a backend `worker`, a `redis` queue, and a `web` frontend; the code you just downloaded has the source code for each process and a Dockerfile to containerize each of them.

2.  Have a brief look at the source for each component of your application. Each folder under `~/orchestration-workshop-net/` contains the application logic for the component, and a Dockerfile for building that logic into a Docker image. We've pre-built these images as `training/dc_rng:1.0`, `training/dc_worker:1.0` et cetera, so no need to build them yourself.

3.  Have a look in `docker-compose.yml`; especially notice the `services` section. Each block here defines a different Docker service. They each have exactly one image which containers for this service will be started from, as well as other configuration details like network connections and port exposures. Full syntax for Docker Compose files can be found here: [https://dockr.ly/2iHUpeX](https://dockr.ly/2iHUpeX).

## Starting the App

1.  Stand up the app:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker-compose up
    ```

    After a moment, your app should be running; visit `<node 0 public IP>:8000` to see the web frontend visualizing your rate of Dockercoin mining.

2.  Logs from all the running services are sent to STDOUT. Let's send this to the background instead; kill the app with `CTRL+C`, and start the app again in the background:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker-compose up -d
    ```

3.  Check out which containers are running thanks to Compose (`Names` column truncated for clarity):

    ```powershell
    PS: node-0 orchestration-workshop-net> docker-compose ps
    
    Name       Command                          State   Ports
    ------------------------------------------------------------------------
    hasher_1   dotnet run                       Up      0.0.0.0:8002->80/tcp
    redis_1    redis-server.exe C:\Redis\ ...   Up      6379/tcp
    rng_1      dotnet run                       Up      0.0.0.0:8001->80/tcp
    webui_1    node webui.js                    Up      0.0.0.0:8000->80/tcp
    worker_1   dotnet run                       Up
    ```

4.  Compare this to the usual `docker container ls`; do you notice any differences? If not, start a couple of extra containers using `docker container run...`, and check again.

5.  See logs from a Compose-managed app via:

    ```bash
    PS: node-0 orchestration-workshop-net> docker-compose logs
    ```

## Conclusion

In this exercise, you saw how to start a pre-defined Compose app, and how to inspect its logs. Application logic was defined in each of the five images we used to create containers for the app, but the manner in which those containers were created was defined in the `docker-compose.yml` file; all runtime configuration for each container is captured in this manifest. Finally, the different elements of Dockercoins communicated with each other via service name; the Docker daemon's internal DNS was able to resolve traffic destined for a service, into the IP or MAC address of the corresponding container.
