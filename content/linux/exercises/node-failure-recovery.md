# Node Failure Recovery

By the end of this exercise, you should be able to:

 - Anticipate swarm scheduling decisions when nodes fail and recover
 - Force swarm to reallocate workload across a swarm

## Setting up a Service

1.  Set up a `myProxy` service with four replicas on one of your manager nodes:

    ```bash
    [centos@node-0 ~]$ docker service create --replicas 4 --name myProxy nginx
    ```

2.  Now watch the output of `docker service ps` on the same node:

    ```bash
    [centos@node-0 ~]$ watch docker service ps myProxy
    ```

    This should be stable for now, but will let us monitor scheduling updates as we interfere with the rest of our swarm.

## Simulating Node Failure

1.  Switch into `node-3`, and simulate a node failure by rebooting it:

    ```bash
    [centos@node-3 ~]$ sudo reboot now
    ```

2.  Back on your manager node, watch the updates to `docker service ps`; what happens to the task running on the rebooted node? Look at its desired state, any other tasks that get scheduled with the same name, and keep watching until `node-3` comes back online.

## Force Rebalancing

By default, if a node fails and rejoins a swarm it *will not* get its old workload back; if we want to redistribute workload across a swarm after new nodes join (or old nodes rejoin), we need to force-rebalance our tasks

1.  Back on the manager node, exit the watch mode with `CTRL+C`.

2.  Force rebalance the tasks:

    ```bash
    [centos@node-0 ~]$ docker service update --force myProxy
    ```

3.  After the service converges, check which nodes the service tasks are scheduled on:

    ```bash
    [centos@node-0 ~]$ docker service ps myProxy
    ... NAME            NODE        DESIRED STATE     CURRENT STATE
    ... myProxy.1       node-0      Running           Running about a minute ago
    ...  \_ myProxy.1   node-0      Shutdown          Shutdown about a minute ago
    ... myProxy.2       node-3      Running           Running about a minute ago
    ...  \_ myProxy.2   node-1      Shutdown          Shutdown about a minute ago
    ... myProxy.3       node-1      Running           Running about a minute ago
    ...  \_ myProxy.3   node-2      Shutdown          Shutdown about a minute ago
    ... myProxy.4       node-2      Running           Running about a minute ago
    ...  \_ myProxy.4   node-0      Shutdown          Shutdown about a minute ago
    ...  \_ myProxy.4   node-3      Shutdown          Shutdown 2 minutes ago  
    ```

    The `\_` shape indicate *ancestor* tasks which have been shut down and replaced by a new task, typically after reconfiguring the service or rebalancing like we've done here. Once the rebalance is complete, the current tasks for the `myProxy` service should be evenly distributed across your swarm.

## Cleanup

1.  On your manager node, remove all existing services, in preparation for future exercises:

    ```bash
    [centos@node-0 ~]$ docker service rm $(docker service ls -q)
    ```

## Conclusion

In this exercise, you saw swarm's scheduler in action - when a node is lost from the swarm, tasks are automatically rescheduled to restore the state of our services. Note that nodes joining or rejoining the swarm do not get workload automatically reallocated from existing nodes to them; rescheduling only happens when tasks crash, services are first scheduled, or you force a reschedule as above.
