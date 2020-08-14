# Node Failure Recovery

By the end of this exercise, you should be able to:

 - Anticipate swarm scheduling decisions when nodes fail and recover
 - Force swarm to reallocate workload across a swarm

## Setting up a Service

1.  Set up an `microsoft/iis` service with four replicas on `node-0`, and wait for all four tasks to be up and running:

    ```powershell
    PS: node-0 Administrator> docker service create --replicas 4 --name iis `
        microsoft/iis
    ```

## Simulating Node Failure

1.  Switch to the non-manager node in your swarm (`node-3`), and simulate a node failure by rebooting it:

    ```powershell
    PS: node-3 Administrator> Restart-Computer -Force
    ```

2.  Back on `node-0`, keep doing `docker service ps iis` every few seconds; what happens to the task running on the rebooted node? Look at its desired state, any other tasks that get scheduled with the same name, and keep watching until `node-3` comes back online.

## Force Rebalancing

By default, if a node fails and rejoins a swarm it *will not* get its old workload back; if we want to redistribute workload across a swarm after new nodes join (or old nodes rejoin), we need to force-rebalance our tasks.

1.  Make sure `node-3` has fully rebooted and rejoined the swarm.

2.  Force rebalance the tasks:

    ```powershell
    PS: node-0 Administrator> docker service update --force iis
    ```
    
3.  After the service converges, check which nodes the service tasks are scheduled on:

    ```
    PS: node-0 Administrator>docker service ps iis

    ID      NAME       IMAGE                 NODE    DESIRED STATE  CURRENT STATE
    dv5...  iis.1      microsoft/iis  node-0  Running        Running 20 seconds ago
    xge...   \_ iis.1  microsoft/iis  node-0  Shutdown       Shutdown 36 seconds ago
    jma...  iis.2      microsoft/iis  node-1  Running        Running about a minute ago
    afd...   \_ iis.2  microsoft/iis  node-1  Shutdown       Shutdown about a minute ago
    3hc...  iis.3      microsoft/iis  node-2  Running        Running 39 seconds ago
    j30...   \_ iis.3  microsoft/iis  node-2  Shutdown       Shutdown 56 seconds ago
    yzz...  iis.4      microsoft/iis  node-3  Running        Running 58 seconds ago
    w9s...   \_ iis.4  microsoft/iis  node-2  Shutdown       Shutdown about a minute ago
    bqz...   \_ iis.4  microsoft/iis  node-3  Shutdown       Shutdown 3 minutes ago
    ```

    The `\_` shape indicate *ancestor* tasks which have been shut down and replaced by a new task, typically after reconfiguring the service or rebalancing like we've done here. Once the rebalance is complete, the current tasks for the `iis` service should be evenly distributed across your swarm.

## Cleanup

1.  Remove all existing services, in preparation for future exercises:

    ```powershell
    PS: node-0 Administrator> docker service rm $(docker service ls -q)
    ```

## Conclusion

In this exercise, you saw swarm's scheduler in action - when a node is lost from the swarm, tasks are automatically rescheduled to restore the state of our services. Note that nodes joining or rejoining the swarm do not get workload automatically reallocated from existing nodes to them; rescheduling only happens when tasks crash, services are first scheduled, or you force a reschedule as above.
