# Swarm Scheduling

By default, the Swarm scheduling algorithm tries to spread workload out roughly evenly across your Swarm. In many cases, we want to exert more nuanced control over what containers get scheduled where, in order to respect resource availability, hardware requirements, application high availability and other concerns. By the end of this exercise, you should be able to:

 - Impose memory resource reservations and limitations
 - Schedule services in global or replicated mode, and define appropriate use cases for each
 - Schedule tasks on a subset of nodes via label constraints
 - Schedule topology-aware services

## Restricting Resource Consumption

By default, containers can consume as much compute resources as they want. Overconsumption of memory can cause an entire node to fail; as such, we need to make sure we're scheduling only as many containers on a host as that host can realistically support, and preventing them from allocating too much memory.

1.  On your worker node `node-3` (**not** on a manager node please), open the Task Manager, either through the search bar or by typing `taskmgr` in the command prompt, and click on **More Details** to get a report of current compute resource consumption.

2.  Still on that same node, spin up a container that will allocate as much memory as it can:

    ```powershell
    PS: node-3 Administrator> docker container run `
        training/winstress:ws19 pwsh.exe C:\saturate-mem.ps1
    ```

    After a minute, the memory column in Task Manager will max out, and your node will become unresponsive. Use `CTRL+C` to detach from the container, and `docker container rm -f` to remove this container.

3.  If we spun this container up as a service, it could take down our entire swarm. Prevent this from happening by imposing a memory limitation on the service; from `node-0`:

    ```powershell
    PS: node-0 Administrator> docker service create `
        --replicas 4 --limit-memory 4096M --name memcap `
        training/winstress:ws19 pwsh.exe C:\saturate-mem.ps1
    ```

    Observe the memory consumption through Task Manager on any node hosting a task for this service; it'll spike, but be capped before it can completely take down the node.

4.  Observe your container's memory consumption directly with `docker stats` on any node hosting one of these containers:

    ```powershell
    docker stats

    CONTAINER ID  NAME             CPU %   PRIV WORKING SET ...
    09fd6cef8528  memcap.1.rko...  48.29%  2.065GiB         ...
    ```

    The private working set memory is capped below whatever limit you set with the `--limit-memory` flag. Use `CTRL+C` to break out of the `docker stats` view when done.

5.  Clean up by deleting your service:

    ```powershell
    PS: node-0 Administrator> docker service rm memcap
    ```

5.  So far, we've limited the amount of resources a container can consume once scheduled, but we still haven't prevented the scheduler from *overprovisioning* containers on a node; we would like to prevent Docker from scheduling more containers on a node than that node can support. Delete and recreate your service one more time, this time also imposing a scheduling reservation with `--reserve-memory`:

    ```powershell
    PS: node-0 Administrator> docker service create `
        --replicas 4 --limit-memory 2048M --name memcap `
        --reserve-memory 2048M `
        training/winstress:ws19 pwsh.exe C:\saturate-mem.ps1

    PS: node-0 Administrator> docker service ps memcap    
    ```

    You should see your four tasks running happily.

7.  Now scale up your service to more replicas than your current cluster can support:

    ```powershell
    PS: node-0 Administrator> docker service update memcap --replicas=10 --detach
    PS: node-0 Administrator> docker service ps memcap

    ID       NAME       CURRENT STATE           ERROR                         
    ...    
    z6t...   memcap.5   Pending 2 seconds ago   "no suitable node (insufficien…" 
    xf3...   memcap.6   Pending 2 seconds ago   "no suitable node (insufficien…"
    ...
    ```

    Many of your tasks should be stuck in `CURRENT STATE: Pending`. Inspect one of them:

    ```powershell
    PS: node-0 Administrator> docker inspect <task ID>

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

    > **Always limit resource consumption** using *both* limits and reservations. Failing to do so is a very common mistake that can lead to a widespread cluster outage; if your cluster is running at near-capacity and one node fails, its workload will get rescheduled to other nodes, potentially causing them to also fail, initiating a cascading cluster outage.

8.  Clean up by removing your service:

    ```powershell
    PS: node-0 Administrator> docker service rm memcap
    ```

## Configuring Global Scheduling

So far, all the services we've created have been run in the default *replicated mode*; as we've seen, Swarm spreads containers out across the cluster, potentially respecting resource reservations. Sometimes, we want to run services that create *exactly one* container on each host in our cluster; this is typically used for deploying daemon, like logging, monitoring, or node management tools which need to run locally on every node.

1.  Create a globally scheduled service:

    ```powershell
    PS: node-0 Administrator> docker service create --mode global `
        --name my-global `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -t
    ``` 

2.  Check what nodes your service tasks were scheduled on:

    ```powershell
    PS: node-0 Administrator> docker service ps my-global

    ID            NAME                      IMAGE                      NODE   
    rjl91n1i5o4g  competent_taussig.j9h...  nanoserver:10.0.17763.737  node-3
    pzkiv2kpsu26  competent_taussig.c3v...  nanoserver:10.0.17763.737  node-2
    k767q7i1f73t  competent_taussig.afo...  nanoserver:10.0.17763.737  node-1
    wem26fmzq2k5  competent_taussig.lnk...  nanoserver:10.0.17763.737  node-0
    ```

    One task is scheduled on every node in the swarm; as you add or remove nodes from the swarm, the global service will be rescaled appropriately.

3.  Remove your service with `docker service rm my-global`.

## Scheduling via Node Constraints

Sometimes, we want to confine our containers to specific nodes; for this, we can use *constraints* and *node properties*.

1.  Add a label `datacenter` with value `east` to two nodes of your swarm:

    ```powershell
    PS: node-0 Administrator> docker node update --label-add datacenter=east node-0
    PS: node-0 Administrator> docker node update --label-add datacenter=east node-1
    ```

2.  Add a label `datacenter` with value `west` to the other two nodes:

    ```powershell
    PS: node-0 Administrator> docker node update --label-add datacenter=west node-2
    PS: node-0 Administrator> docker node update --label-add datacenter=west node-3
    ```

    Note these labels are user-defined; `datacenter` and its values `east` and `west` can be anything you like.

3.  Schedule a service constrained to run on nodes labeled as `datacenter=east`:

    ```powershell
    PS: node-0 Administrator> docker service create --replicas 4 `
        --constraint node.labels.datacenter==east `
        --name east-deploy `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -t
    ```

4.  Check what nodes your tasks were scheduled on as above; they should all be on nodes bearing the `datacenter==east` label (`node-0` and `node-1`).

5.  Remove your service, and schedule another, this time constrained to run only on worker nodes:

    ```powershell
    PS: node-0 Administrator> docker service rm east-deploy
    PS: node-0 Administrator> docker service create --replicas 4 `
        --constraint node.role==worker `
        --name worker-only `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -t
    ```

    Once again, check where your `worker-only` service tasks got scheduled; they'll all be on `node-3`, your only worker.

    > **Keep workload off of managers** using these selectors, especially in production. If something goes badly wrong with a workload container and causes its host to crash, we don't want to take down a manager and possibly lose our raft consensus. As we've seen, Swarm can recover from losing workers automatically; a lost manager consensus can be much harder to recover from.

6.  Clean up by removing this service: `docker service rm worker-only`.

## Scheduling Topology-Aware Services

Oftentimes, we want to schedule workload to be tolerant of faults in our datacenters; we wouldn't want every replica for a service on one power zone or one rack which can go down all at once, for example. 

1.  Create a service using the `--placement-pref` flag to spread replicas across our `datacenter` label:

    ```powershell
    PS: node-0 Administrator> docker service create --name spreaddemo `
        --replicas=2 --publish 8000:80 `
        --placement-pref spread=node.labels.datacenter `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -t
    ```

    There should be `nanoserver` containers present on nodes with every possible value of the `node.labels.datacenter` label, one in `datacenter=east` nodes, and one in `datacenter=west` nodes.

2.  Use `docker service ps spreaddemo` as above to check that replicas got spread across the datacenter labels.

3.  Clean up: `docker service rm spreaddemo`.

## Conclusion

In this exercise, we saw how to use resource allocations, global scheduling, labels and node properties to influence scheduling. A few best practices:

 - **Always apply memory and CPU limits and reservations**, and in essentially all cases, the limit should be less than or equal to the reservation to ensure nodes are never overprovisioned.
 - **Keep workload off of manager** as mentioned above, to prevent application logic bugs from taking down your manager consensus
 - **Don't overconstrain your scheduler**: it can be tempting to exert strict control over exactly what gets scheduled exactly where; don't. If a service is constrained to run on a very small set of nodes, and those nodes go down, the service will become unschedulable and suffer an outage. Let your orchestraor's scheduler make decisions as independently as possible in order to maximize workload resilience.
