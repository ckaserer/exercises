# Instructor Demo: Docker Compose

In this demo, we'll illustrate:

 - Starting an app defined in a docker compose file
 - Inter-service communication using DNS resolution of service names

## Exploring the Compose File

1.  Please download the DockerCoins app from Github and change directory to ~/orchestration-workshop-net/dockercoins:

    ```powershell
    PS: node-0 Administrator> git clone -b ee3.0-ws19 `
        https://github.com/docker-training/orchestration-workshop-net.git
    PS: node-0 Administrator> cd ~/orchestration-workshop-net
    ```

2.  Let's take a quick look at our Compose file for Dockercoins:

    ```yaml
    version: "3.1"

    services:
      rng:
        image: training/dc_rng:ws19
        networks:
        - nat
        ports:
        - "8001:80"

      hasher:
        image: training/dc_hasher:ws19
        networks:
        - nat
        ports:
        - "8002:80"

      webui:
        image: training/dc_webui:ws19
        networks:
        - nat
        ports:
        - "8000:80"

      redis:
        image: training/dc_redis:ws19
        networks:
        - nat

      worker:
        image: training/dc_worker:ws19
        networks:
        - nat

    networks:
      nat:
        external: true
    ```

    This Compose file contains 5 services, and a pointer to the default `nat` network. The images `training/dc_rng:ws19` et cetera are pre-built images containing the application logic you can explore in the subfolders of `~/orchestration-workshop-net`.

3.  Start the app in the background:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker-compose up -d
    ```

4.  Make sure the services are up and running, and all the containers are attached to the local `nat` network:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker-compose ps
    PS: node-0 orchestration-workshop-net> docker network inspect nat
    ```

6.  If everything is up, visit your app at `<node-0 public IP>:8000` to see Dockercoins in action.

## Communicating Between Containers

1.  In this section, we'll demonstrate that containers created as part of a service in a Compose file are able to communicate with containers belonging to other services using just their service names. Let's start by listing our DockerCoins containers:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker container ls | findstr 'dc'
    ```

2.  Now, connect into one container; let's pick `webui`:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker container exec `
        -it <Container ID> powershell
    ```

3.  From within the container, ping `rng` by name:

    ```powershell
    PS C:\> ping rng
    ```

    Logs should be outputted resembling this:

    ```powershell
    Pinging rng [172.20.137.174] with 32 bytes of data:
    Reply from 172.20.137.174: bytes=32 time<1ms TTL=128
    Reply from 172.20.137.174: bytes=32 time<1ms TTL=128
    Reply from 172.20.137.174: bytes=32 time<1ms TTL=128
    Reply from 172.20.137.174: bytes=32 time<1ms TTL=128

    Ping statistics for 172.20.137.174:
        Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
    Approximate round trip times in milli-seconds:
        Minimum = 0ms, Maximum = 0ms, Average = 0ms
    ```

    DNS lookup for the services in DockerCoins works because they are all attached to the local `nat` network.

4.  After exiting this container, let's navigate to the `worker` folder and take a look at the top of `Program.cs`:

    ```powershell
    PS: node-0 orchestration-workshop-net> cd worker
    PS: node-0 worker> cat Program.cs

    using System;
    using System.Net.Http;
    using System.Threading;
    using ServiceStack.Redis;

    public class Program
    {
        private static HttpClient Client = new HttpClient();
        private const string rng_uri = "http://rng";
        private const string hasher_uri = "http://hasher";
    ...
    ```

    Our worker is configured to contact the random number generator and hasher directly by their service names, `rng` and `hasher`. No service discovery or IP lookups required - Docker ensures that service names are DNS-resolvable, abstracting away our service-to-service communication.

5.  Shut down Dockercoins and clean up its resources:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker-compose down
    ```

## Conclusion

In this exercise, we stood up an application using Docker Compose. The most important new idea here is the notion of Docker Services, which are collections of identically configured containers. Docker Service names are resolvable by DNS, so that we can write application logic designed to communicate service to service; all service discovery and load balancing between your application's services is abstracted away and handled by Docker.
