# Creating a Swarm

By the end of this exercise, you should be able to:

 - Create a swarm in high availability mode
 - Set default address pools
 - Check necessary connectivity between swarm nodes
 - Configure the swarm's TLS certificate rotation

## Starting Swarm

1.  Switch back to `node-0` by using the dropdown menu. Then, initialize swarm and create a cluster with a default address pool for a discontiguous address range of 10.85.0.0/16 and 10.91.0.0/16 with a default subnet size of 128 addresses. This will be your first manager node:

    ```bash
    [centos@node-0 ~]$ docker swarm init \
        --default-addr-pool 10.85.0.0/16 \
        --default-addr-pool 10.91.0.0/16 \
        --default-addr-pool-mask-length 25
    ```

2.  Confirm that Swarm Mode is active and that the default address pool configuration has been registered by inspecting the output of:

    ```bash
    [centos@node-0 ~]$ docker system info

    ...
    Swarm: active
    ...
        Default Address Pool: 10.85.0.0/16  10.91.0.0/16
        SubnetSize: 25
    ...
    ```

3.  See all nodes currently in your swarm by doing:

    ```bash
    [centos@node-0 ~]$ docker node ls
    ```

    A single node is reported in the cluster.

4.  Change the certificate rotation period from the default of 90 days to one week, and rotate the certificate now:

    ```bash
    [centos@node-0 ~]$ docker swarm ca --rotate --cert-expiry 168h
    ```

    Note that the `docker swarm ca [options]` command *must* receive the `--rotate` flag, or all other flags will be ignored.

5.  Display UDP and TCP activity on your manager:

    ```bash
    [centos@node-0 ~]$ sudo netstat -plunt | grep -E "2377|7946|4789"
    ```

    You should see (at least) TCP+UDP 7946, UDP 4789, and TCP 2377. What are each of these ports for?

## Adding Workers to the Swarm

A single node swarm is not a particularly interesting swarm; let's add some workers to really see Swarm Mode in action.

1.  On your manager node (`node-0`), get the swarm 'join token' you'll use to add worker nodes to your swarm:

    ```bash
    [centos@node-0 ~]$ docker swarm join-token worker
    ```

2.  Switch to `node-1` from the dropdown menu.

3.  Paste in the join token you found in the first step above. `node-1` will join the swarm as a worker.

4.  Inspect the network on `node-1` with `sudo netstat -plunt` like you did for the manager node. Are the same ports open? Why or why not?

5.  Do `docker node ls` after switching back to the manager `node-0` again, and you should see both your nodes and their status. Note that `docker node ls` won't work on a worker node, as the cluster status is maintained only by the manager nodes.

6.  Finally, use the same join token to add two more workers (`node-2` and `node-3`) to your swarm. When you're done, confirm that `docker node ls` on your one manager node reports 4 nodes in the cluster - one manager, and three workers.

## Promoting Workers to Managers

At this point, our swarm has a single manager, `node-0`. If this node goes down, we'll lose the ability to maintain and schedule workloads on our swarm. In a real deployment, this is unacceptable; we need some redundancy to our system, and Swarm achieves this by allowing a raft consensus of multiple managers to preserve swarm state.

1.  Promote two of your workers to manager status by executing, on the current manager node:

    ```bash
    [centos@node-0 ~]$ docker node promote node-1 node-2
    ```

2.  Finally, do a `docker node ls` to check and see that you now have three managers. Note that manager nodes also count as worker nodes - tasks can still be scheduled on them as normal.

## Conclusion

In this exercise, you set up a basic high-availability swarm. In practice, it is crucial to have at least 3 (and always an odd number) of managers in order to ensure high availability of your cluster, and to ensure that the management, control, and data plane communications a swarm maintains can proceed unimpeded between all nodes.
