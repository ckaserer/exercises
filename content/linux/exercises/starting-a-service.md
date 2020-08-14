# Starting a Service

By the end of this exercise, you should be able to:

 - Schedule a docker service across a swarm
 - Predict and understand the scoping behavior of docker overlay networks
 - Scale a service on swarm up or down

## Creating an Overlay Network and Service

1.  Create a multi-host overlay network which you can connect your service to:

    ```bash
    [centos@node-0 ~]$ docker network create --driver overlay my_overlay
    ```

2.  Verify that the network subnet was taken from the address pool defined when creating your swarm:

    ```bash
    [centos@node-0 ~]$ docker network inspect my_overlay

    ...
    "Subnet": "10.85.0.0/25",
    "Gateway": "10.85.0.1"
    ...
    ```

    The overlay network has been assigned a subnet from the address pool we specified when creating our swarm.

3.  Create a service featuring an `alpine` container pinging Google resolvers, plugged into your overlay network:

    ```bash
    [centos@node-0 ~]$ docker service create --name pinger \
        --network my_overlay alpine ping 8.8.8.8
    ```

    Note the syntax is a lot like `docker container run`; an image (`alpine`) is specified, followed by the PID 1 process for that container (`ping 8.8.8.8`).

4.  Get some information about the currently running services:

    ```bash
    [centos@node-0 ~]$ docker service ls

    ID                  NAME      MODE                REPLICAS            IMAGE         
    bmthsr0m6xvr        pinger    replicated          1/1                 alpine:latest       
    ```

5.  Check which node the container was created on:

    ```bash
    [centos@node-0 ~]$ docker service ps pinger

    ID       NAME       IMAGE           NODE     DESIRED STATE   CURRENT STATE           
    lmm...   pinger.1   alpine:latest   node-0   Running         Running 42 seconds ago 
    ```

    In my case, the one container we started for this service was scheduled on `node-0`.

6.  Scale up the number of concurrent tasks that our `pinger` service is running to 3:

    ```bash
    [centos@node-0 ~]$ docker service update pinger --replicas=3

    pinger
    overall progress: 3 out of 3 tasks 
    1/3: running   [==================================================>] 
    2/3: running   [==================================================>] 
    3/3: running   [==================================================>] 
    verify: Service converged 
    ```

7.  Now run `docker service ps pinger` to inspect the service. How were tasks distributed across your swarm?

8.  Run `docker network inspect my_overlay` on any node that has a `pinger` task scheduled on it. Look for the `Containers` key in the output; it indicates the containers on this node attached to the `my_overlay` network. Also, look for the `Peers` list; mine looks like:

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

    ```bash
    [centos@node-0 ~]$ docker service logs pinger
    ```

    The ping logs for all 3 pinging containers will be displayed.

2.  If instead you'd like to see the logs of a single task, on a manager node run `docker service ps pinger`, choose any task ID, and run `docker service logs <task ID>`.

## Cleanup

1.  Remove all existing services, in preparation for future exercises:

    ```bash
    [centos@node-0 ~]$ docker service rm $(docker service ls -q)
    ```

## Conclusion

In this exercise, we saw the basics of creating, scheduling and updating services. A common mistake people make is thinking that a service is just the containers scheduled by the service; in fact, a Docker service is the definition of *desired state* for those containers. Changing a service definition does not in general change containers directly; it causes them to get rescheduled by Swarm in order to match their new desired state.
