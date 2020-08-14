# Swarm Scheduling

By default, the Swarm scheduling algorithm tries to spread workload out roughly evenly across your Swarm. In many cases, we want to exert more nuanced control over what containers get scheduled where, in order to respect resource availability, hardware requirements, application high availability and other concerns. By the end of this exercise, you should be able to:

 - Impose CPU and memory resource reservations and limitations
 - Schedule services in global or replicated mode, and define appropriate use cases for each
 - Schedule tasks on a subset of nodes via label constraints
 - Schedule topology-aware services

## Restricting Resource Consumption

By default, containers can consume as much CPU and memory as they want; in practice, unconstrained CPU usage leads to noisy-neighbor problems where one container can starve all other co-located containers of CPU time, and unconstrained memory usage leads to processes getting killed with out-of-memory errors. When scheduling services, we must prevent containers from overconsuming compute resources, and make sure we're scheduling only as many containers on a host as that host can realistically support.

1.  Create a service based on the `training/stress:3.0` container, with a few flags to make it consume two full CPUs and allocate a gigabyte of memory. We'll also introduce the `--detach` flag, which sends the service startup to the background:

    ```bash
    [centos@node-0 ~]$ docker service create --name compute-stress \
        --replicas 4 \
        --detach \
        training/stress:3.0 --vm 2 --vm-bytes 1024M
    ```

2.  Check the resource consumption of your containers on one of your hosts:

    ```bash
    [centos@node-0 ~]$ docker stats

    CONTAINER ID        NAME                      CPU %     MEM USAGE / LIMIT   MEM %
    b97b645e3a4f        compute-stress.4.o7v...   199.38%   1.128GiB / 3.7GiB   30.48%
    ```

    `CTRL+C` to escape from the stats view once you've seen it. The one container on this host is consuming two full CPUs and over a gigabyte of memory; anything else scheduled on this node is going to be starved of resources.

3.  Remove this service, recreate it with a limitation on how much CPU its containers are allowed to consume, and check the stats again:

    ```bash
    [centos@node-0 ~]$ docker service rm compute-stress
    [centos@node-0 ~]$ docker service create --name compute-stress \
        --replicas 4 \
        --limit-cpu 1 \
        --detach \
        training/stress:3.0 --vm 2 --vm-bytes 1024M    
    [centos@node-0 ~]$ docker stats

    CONTAINER ID        NAME                      CPU %     MEM USAGE / LIMIT   MEM %
    d311d88debd9        compute-stress.2.6w0...   100.52%   1.158GiB / 3.7GiB   31.29%
    ```

    The `--limit-cpu 1` flag imposes control group limits on our containers, preventing them from consuming more than one core's worth of cycles.

4.  We've throttled our CPU consumption above, but that one container is still hogging around a gigabyte of memory; we can similarly limit memory consumption to prevent random out-of-memory process kills from taking down the host. Remove and recreate your service, this time with a memory limit:

    ```bash
    [centos@node-0 ~]$ docker service rm compute-stress
    [centos@node-0 ~]$ docker service create --name compute-stress \
        --replicas 4 \
        --limit-cpu 1 \
        --limit-memory 512M \
        --detach \
        training/stress:3.0 --vm 2 --vm-bytes 1024M    
    ```

5.  List you containers with `docker container ls -a`; you should see a list of exited containers. Inspect one of them, and look for its out-of-memory status:

    ```bash
    [centos@node-0 ~]$ docker container ls -a
    CONTAINER ID     IMAGE                     CREATED         STATUS
    3eb69ace1d66     training/stress:3.0  ...  4 seconds ago   Created 
    eac5f4c35142     training/stress:3.0  ...  5 seconds ago   Exited (1) 5 seconds ago

    [centos@node-0 ~]$ docker container inspect eac5f4c35142 | grep OOM

                "OOMKilled": true,
    ```

    `--limit-memory` works a little differently than `--limit-cpu`; while the CPU limit throttled a running container, the memory limit kills the container with an Out Of Memory exception if it tries to exceed its memory limit; this way, we avoid the random out-of-memory process kill that the kernel usually imposes, and which can take down a worker by potentially killing the Docker daemon itself.

6.  So far, we've limited the amount of resources a container can consume once scheduled, but we still haven't prevented the scheduler from *overprovisioning* containers on a node; we would like to prevent Docker from scheduling more containers on a node than that node can support. Delete and recreate your service one more time, this time without exceeding your memory limit and also imposing a scheduling reservation with `--reserve-memory`:

    ```bash
    [centos@node-0 ~]$ docker service rm compute-stress
    [centos@node-0 ~]$ docker service create --name compute-stress \
        --replicas 4 \
        --limit-cpu 1 \
        --limit-memory 512M \
        --reserve-memory 512M \
        --detach \
        training/stress:3.0 --vm 2 --vm-bytes 128M  

    [centos@node-0 ~]$ docker service ps compute-stress
    ```

    You should see your four tasks running happily.

7.  Now scale up your service to more replicas than your current cluster can support:

    ```bash
    [centos@node-0 ~]$ docker service update compute-stress --replicas=40 --detach
    [centos@node-0 ~]$ docker service ps compute-stress

    ID       NAME                CURRENT STATE           ERROR                         
    ...    
    z6t...   compute-stress.31   Pending 2 seconds ago   "no suitable node (insufficien…" 
    xf3...   compute-stress.32   Pending 2 seconds ago   "no suitable node (insufficien…"
    ...
    ```

    Many of your tasks should be stuck in `CURRENT STATE: Pending`. Inspect one of them:

    ```bash
    [centos@node-0 ~]$ docker inspect xf3xigecdfw8

    ...
        "Status": {
            "Timestamp": "2019-01-29T16:31:45.5859483Z",
            "State": "pending",
            "Message": "pending task scheduling",
            "Err": "no suitable node (insufficient resources on 4 nodes)",
            "PortStatus": {}
        }
    ...
    ```

    From the `Status` block in the task info, we can see that this task isn't getting scheduled because there isn't sufficient resources available in the cluster to support it.

    > **Always limit resource consumption** using *both* limits and reservations for CPU and memory. Failing to do so is a very common mistake that can lead to a widespread cluster outage; if your cluster is running at near-capacity and one node fails, its workload will get rescheduled to other nodes, potentially causing them to also fail, initiating a cascading cluster outage.

8.  Clean up by removing your service:

    ```bash
    [centos@node-0 ~]$ docker service rm compute-stress
    ```

## Configuring Global Scheduling

So far, all the services we've created have been run in the default *replicated mode*; as we've seen, Swarm spreads containers out across the cluster, potentially respecting resource reservations. Sometimes, we want to run services that create *exactly one* container on each host in our cluster; this is typically used for deploying daemon, like logging, monitoring, or node management tools which need to run locally on every node.

1.  Create a globally scheduled service:

    ```bash
    [centos@node-0 ~]$ docker service create --mode global \
        --name my-global \
        centos:7 ping 8.8.8.8
    ``` 

2.  Check what nodes your service tasks were scheduled on:

    ```bash
    [centos@node-0 ~]$ docker service ps my-global

    ID                 NAME                                          IMAGE         NODE   
    rjl91n1i5o4g       competent_taussig.j9hmrf8ne6s8ysyb3k3y0wtp9   centos:7      node-3
    pzkiv2kpsu26       competent_taussig.c3va5z6je8zpkozgn0cm5kllt   centos:7      node-2
    k767q7i1f73t       competent_taussig.afoyo4r860dbwve1h4dm3dsrq   centos:7      node-1
    wem26fmzq2k5       competent_taussig.lnki68wnzp0r7456zo6xc46s2   centos:7      node-0
    ```

    One task is scheduled on every node in the swarm; as you add or remove nodes from the swarm, the global service will be rescaled appropriately.

3.  Remove your service with `docker service rm my-global`.

## Scheduling via Node Constraints

Sometimes, we want to confine our containers to specific nodes; for this, we can use *constraints* and *node properties*.

1.  Add a label `datacenter` with value `east` to two nodes of your swarm:

    ```bash
    [centos@node-0 ~]$ docker node update --label-add datacenter=east node-0
    [centos@node-0 ~]$ docker node update --label-add datacenter=east node-1
    ```

2.  Add a label `datacenter` with value `west` to the other two nodes:

    ```bash
    [centos@node-0 ~]$ docker node update --label-add datacenter=west node-2
    [centos@node-0 ~]$ docker node update --label-add datacenter=west node-3
    ```

    Note these labels are user-defined; `datacenter` and its values `east` and `west` can be anything you like.

3.  Schedule a service constrained to run on nodes labeled as `datacenter=east`:

    ```bash
    [centos@node-0 ~]$ docker service create --replicas 4 \
        --constraint node.labels.datacenter==east \
        --name east-deploy \
        centos:7 ping 8.8.8.8
    ```

4.  Check what nodes your tasks were scheduled on as above; they should all be on nodes bearing the `datacenter==east` label (`node-0` and `node-1`).

5.  Remove your service, and schedule another, this time constrained to run only on worker nodes:

    ```bash
    [centos@node-0 ~]$ docker service rm east-deploy
    [centos@node-0 ~]$ docker service create --replicas 4 \
        --constraint node.role==worker \
        --name worker-only \
        centos:7 ping 8.8.8.8
    ```

    Once again, check where your `worker-only` service tasks got scheduled; they'll all be on `node-3`, your only worker.

    > **Keep workload off of managers** using these selectors, especially in production. If something goes badly wrong with a workload container and causes its host to crash, we don't want to take down a manager and possibly lose our raft consensus. As we've seen, Swarm can recover from losing workers automatically; a lost manager consensus can be much harder to recover from.

6.  Clean up by removing this service: `docker service rm worker-only`.

## Scheduling Topology-Aware Services

Oftentimes, we want to schedule workload to be tolerant of faults in our datacenters; we wouldn't want every replica for a service on one power zone or one rack which can go down all at once, for example. 

1.  Create a service using the `--placement-pref` flag to spread replicas across our `datacenter` label:

    ```bash
    [centos@node-0 ~]$ docker service create --name my_proxy \
        --replicas=2 --publish 8000:80 \
        --placement-pref spread=node.labels.datacenter \
        nginx
    ```

    There should be `nginx` containers present on nodes with every possible value of the `node.labels.datacenter` label, one in `datacenter=east` nodes, and one in `datacenter=west` nodes.

2.  Use `docker service ps my_proxy` as above to check that replicas got spread across the datacenter labels.

3.  Clean up: `docker service rm my_proxy`.

## Conclusion

In this exercise, we saw how to use resource allocations, global scheduling, labels and node properties to influence scheduling. A few best practices:

 - **Always apply memory and CPU limits and reservations**, and in essentially all cases, the limit should be less than or equal to the reservation to ensure nodes are never overprovisioned.
 - **Keep workload off of manager** as mentioned above, to prevent application logic bugs from taking down your manager consensus
 - **Don't overconstrain your scheduler**: it can be tempting to exert strict control over exactly what gets scheduled exactly where; don't. If a service is constrained to run on a very small set of nodes, and those nodes go down, the service will become unschedulable and suffer an outage. Let your orchestraor's scheduler make decisions as independently as possible in order to maximize workload resilience.
