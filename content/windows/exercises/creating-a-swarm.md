# Creating a Swarm

By the end of this exercise, you should be able to:

 - Create a swarm in high availability mode
 - Set default address pools
 - Check necessary connectivity between swarm nodes
 - Configure the swarm's TLS certificate rotation

## Starting Swarm Mode

1.  On `node-0`, initialize swarm and create a cluster with a default address pool for a discontiguous address range of 10.85.0.0/16 and 10.91.0.0/16 with a default subnet size of 128 addresses. This will be your first manager node:

    ```powershell
    PS: node-0 Administrator> $PRIVATEIP = '<node-0 private IP>'
    PS: node-0 Administrator> docker swarm init `
        --advertise-addr ${PRIVATEIP} `
        --listen-addr ${PRIVATEIP}:2377 `
        --default-addr-pool 10.85.0.0/16 `
        --default-addr-pool 10.91.0.0/16 `
        --default-addr-pool-mask-length 25

    Swarm initialized: current node (xyz) is now a manager.

    To add a worker to this swarm, run the following command:

        docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377

    To add a manager to this swarm, run 'docker swarm join-token manager' 
        and follow the instructions.
    ```

2.  Confirm that Swarm Mode is active and that the default address pool configuration has been registered by inspecting the output of:

    ```powershell
    PS: node-0 Administrator> docker system info

    ...
    Swarm: active
    ...
        Default Address Pool: 10.85.0.0/16  10.91.0.0/16
        SubnetSize: 25
    ...
    ```

3.  See all nodes currently in your swarm by doing:

    ```powershell
    PS: node-0 Administrator> docker node ls

    ID      HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS
    xyz *   node-0     Ready    Active         Leader
    ```

    A single node is reported in the cluster.

4.  Change the certificate rotation period from the default of 90 days to one week, and rotate the certificate now:

    ```powershell
    PS: node-0 Administrator> docker swarm ca --rotate --cert-expiry 168h
    ```

    Note that the `docker swarm ca [options]` command *must* receive the `--rotate` flag, or all other flags will be ignored.

## Adding Workers to the Swarm

A single node swarm is not a particularly interesting swarm; let's add some workers to really see swarm mode in action.

1.  On your manager node, get the swarm join token you'll use to add worker nodes to your swarm:

    ```powershell
    PS: node-0 Administrator> docker swarm join-token worker
    ```

2.  Switch into `node-1` from the dropdown menu, and paste the result of the last step there. This new node will join the swarm as a worker.

3.  Do `docker node ls` on `node-0` again, and you should see both your nodes and their status; note that `docker node ls` won't work on a worker node, as the cluster status is maintained only by the manager nodes.

4.  Have a look at open TCP connections on `node-0`:

    ```powershell
    PS: node-0 Administrator> netstat

    Active Connections

      Proto  Local Address          Foreign Address        State
      TCP    10.10.5.199:2377       ip-10-10-21-25:52054   ESTABLISHED
      TCP    10.10.5.199:3389       WimaxUser37230-226:63128  CLOSE_WAIT
      TCP    10.10.5.199:3389       ool-944be43f:51428     ESTABLISHED
      TCP    10.10.5.199:7946       ip-10-10-21-25:52010   TIME_WAIT
      TCP    10.10.5.199:7946       ip-10-10-21-25:52057   TIME_WAIT
      TCP    10.10.5.199:51233      13.89.217.116:https    ESTABLISHED
      TCP    10.10.5.199:51862      52.94.233.129:https    TIME_WAIT
      TCP    10.10.5.199:51865      ip-10-10-21-25:7946    TIME_WAIT
      TCP    10.10.5.199:51866      ip-10-10-21-25:7946    TIME_WAIT
    ```

    You should see something similar; most notably, the first line in the example above corresponds to `node-1` (private IP 10.10.21.25 in this example) connecting to this node on tcp/2377. Also, many mutual connections are made between the two nodes on 7946, corresponding to gossip control plane communications.

4.  Finally, use the same join token to add two more workers to your swarm. When you're done, confirm that `docker node ls` on your one manager node reports 4 nodes in the cluster - one manager, and three workers:

    ```powershell
    PS: node-0 Administrator> docker node ls

    ID      HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS
    ghi     node-3     Ready    Active              
    def     node-2     Ready    Active              
    abc     node-1     Ready    Active              
    xyz *   node-0     Ready    Active         Leader
    ```

## Promoting Workers to Managers

At this point, our swarm has a single manager. If this node goes down, the whole swarm is lost. In a real deployment, this is unacceptable; we need some redundancy to our system, and swarm mode achieves this by using a raft consensus of multiple managers to preserve swarm state. 

1.  Promote two of your workers to manager status by executing, on `node-0`:

    ```powershell
    PS: node-0 Administrator> docker node promote node-1 node-2
    ```

2.  Finally, do a `docker node ls` to check and see that you now have three managers; `node-1` and `node-2` should report as `Reachable`, indicating that they are healthy members of the raft consensus. Note that manager nodes also count as worker nodes - tasks can still be scheduled on them as normal by default.

## Conclusion

In this exercise, you set up a basic high-availability swarm. In practice, it is crucial to have at least 3 (and always an odd number) of managers in order to ensure high availability of your cluster, and to ensure that the management, control, and data plane communications a swarm maintains can proceed unimpeded between all nodes.
