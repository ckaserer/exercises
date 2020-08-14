# Starting a Service

By the end of this exercise, you should be able to:

 - Schedule a docker service across a swarm
 - Predict and understand the scoping behavior of docker overlay networks
 - Scale a service on swarm up or down

## Creating an Overlay Network and Service

1.  Create a multi-host overlay network to connect your service to:

    ```powershell
    PS: node-0 Administrator> docker network create --driver overlay my_overlay
    ```

2.  Verify that the network subnet was taken from the address pool defined when creating your swarm::

    ```powershell
    PS: node-0 Administrator> docker network inspect my_overlay

    ...
    "Subnet": "10.85.0.0/25",
    "Gateway": "10.85.0.1"
    ...
    ```

    The overlay network has been assigned a subnet from the address pool we specified when creating our swarm.

3.  Create a service featuring a `training/probe`, which sends a periodic network request to docker.com to see if the internet is reachable from your container:

    ```powershell
    PS: node-0 Administrator> docker service create --name prober `
        --network my_overlay training/probe:ws19
    ```

    Note the syntax is a lot like `docker container run`; an image (`training/probe:ws19`) is specified after some flags, which conainerizes a default process.

4.  Get some information about the currently running services:

    ```powershell
    PS: node-0 Administrator> docker service ls

    ID             NAME     MODE         REPLICAS   IMAGE                      
    k6caojtyqp2p   prober   replicated   1/1        training/probe:ws19
    ```

5.  Check which node the container was created on:

    ```powershell
    PS: node-0 Administrator> docker service ps prober

    ID       NAME       IMAGE                      NODE     DESIRED STATE   ...
    jot...   prober.1   docker service ps prober   node-1   Running         ...
    ```

    In my case, the one container we started for this service was scheduled on `node-1`.

6.  Scale up the number of concurrent tasks that our `prober` service is running to 3:

    ```powershell
    PS: node-0 Administrator> docker service update prober --replicas=3

    prober
    overall progress: 3 out of 3 tasks
    1/3: running   [==================================================>]
    2/3: running   [==================================================>]
    3/3: running   [==================================================>]
    verify: Service converged
    ```

7.  Now run `docker service ps prober` to inspect the service. How were tasks distributed across your swarm?

8.  Run `docker network inspect my_overlay` on any node that has a `prober` task scheduled on it. Look for the `Containers` key in the output; it indicates the containers on this node attached to the `my_overlay` network. Also, look for the `Peers` list; mine looks like:

    ```json
    "Peers": [
        {
            "Name": "967da1a0349f",
            "IP": "10.10.12.136"
        },
        {
            "Name": "d1cd9f4a25bb",
            "IP": "10.10.35.36"
        },
        {
            "Name": "d7e00d4376ca",
            "IP": "10.10.57.19"
        }
    ]
    ```

    Challenge: Looking at your own `Peers` list, what do the IPs correspond to?

## Inspecting Service Logs

1.  Manager nodes can assemble all logs for all tasks of a given service:

    ```powershell
    PS: node-0 Administrator> docker service logs --tail 100 prober
    ```

    The last 100 lines of logs for all 3 probe containers will be displayed.

2.  If instead you'd like to see the logs of a single task, on a manager node run `docker service ps prober`, choose any task ID, and run `docker service logs <task ID>`.

## Cleanup

1.  Remove all existing services, in preparation for future exercises:

    ```powershell
    PS: node-0 Administrator> docker service rm $(docker service ls -q)
    ```

## Conclusion

In this exercise, we saw the basics of creating, scheduling and updating services. A common mistake people make is thinking that a service is just the containers scheduled by the service; in fact, a Docker service is the definition of *desired state* for those containers. Changing a service definition does not in general change containers directly; it causes them to get rescheduled by Swarm in order to match their new desired state.
