# Instructor Demo: Self-Healing Swarm

In this demo, we'll illustrate:

 - Setting up a swarm
 - How swarm makes basic scheduling decisions
 - Actions swarm takes to self-heal a docker service

## Setting Up a Swarm

1.  Start by making sure no containers are running on any of your nodes:

    ```bash
    [centos@node-0 ~]$ docker container rm -f $(docker container ls -aq)
    [centos@node-1 ~]$ docker container rm -f $(docker container ls -aq)
    [centos@node-2 ~]$ docker container rm -f $(docker container ls -aq)
    [centos@node-3 ~]$ docker container rm -f $(docker container ls -aq)
    ```

2.  Initialize a swarm on one node:

    ```bash
    [centos@node-0 ~]$ docker swarm init

	Swarm initialized: current node (xyz) is now a manager.

	To add a worker to this swarm, run the following command:

	    docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377

	To add a manager to this swarm, run 
        'docker swarm join-token manager' and follow the instructions.
    ```

3.  List the nodes in your swarm:

    ```bash
    [centos@node-0 ~]$ docker node ls

    ID      HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS
    xyz *   node-0     Ready    Active         Leader
    ```

4.  Add some workers to your swarm by cutting and pasting the `docker swarm join...` token Docker provided in step 2 above:

    ```bash
    [centos@node-1 ~]$ docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377
    [centos@node-2 ~]$ docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377
    [centos@node-3 ~]$ docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377
    ```

    Each node should report `This node joined a swarm as a worker.` after joining.

5.  Back on your first node, list your swarm members again:

    ```bash
    [centos@node-0 ~]$ docker node ls

    ID      HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS
    ghi     node-3     Ready    Active              
    def     node-2     Ready    Active              
    abc     node-1     Ready    Active              
    xyz *   node-0     Ready    Active         Leader
    ```
    
    You have a four-member swarm, ready to accept workloads.

## Scheduling Workload

1.  Create a service on your swarm:

    ```bash
    [centos@node-0 ~]$ docker service create \
        --replicas 4 \
        --name service-demo \
        centos:7 ping 8.8.8.8
    ```

2.  List what processes have been started for your service:

    ```bash
    [centos@node-0 ~]$ docker service ps service-demo

    ID            NAME            IMAGE     NODE    DESIRED STATE  CURRENT STATE         
    g3dimc0nkoha  service-demo.1  centos:7  node-3  Running        Running 18 seconds ago
    e7d7sy5saqqo  service-demo.2  centos:7  node-0  Running        Running 18 seconds ago  
    wv0culf6w8m6  service-demo.3  centos:7  node-1  Running        Running 18 seconds ago    
    ty35gss71mpf  service-demo.4  centos:7  node-2  Running        Running 18 seconds ago
    ```

    Our service has scheduled four tasks, one on each node in our cluster; by default, swarm tries to spread tasks out evenly across hosts, but much more sophisticated scheduling controls are also available.

## Maintaining Desired State

1.  Switch to `node-1`, and list the containers running there:

    ```bash
    [centos@node-1 ~]$ docker container ls
    ID      IMAGE     COMMAND         CREATED        STATUS        NAMES
    5b5...  centos:7  "ping 8.8.8.8"  4 minutes ago  Up 4 minutes  service-demo.3.wv0...
    ```

    Note the container's name indicates the service it belongs to.

2.  Let's simulate a container crash, by killing off this container:

    ```bash
    [centos@node-1 ~]$ docker container rm -f <container ID>
    ```

    Back on our swarm manager, list the processes running for our `service-demo` service again:

    ```bash
    [centos@node-0 ~]$ docker service ps service-demo

    ID      NAME               IMAGE     NODE    DESIRED STATE  CURRENT STATE      
    g3d...  service-demo.1     centos:7  node-3  Running        Running 6 minutes ago   
    e7d...  service-demo.2     centos:7  node-0  Running        Running 6 minutes ago      
    u7l...  service-demo.3     centos:7  node-1  Running        Running 3 seconds ago          
    wv0...  \_ service-demo.3  centos:7  node-1  Shutdown       Failed 3 seconds ago
    ty3...  service-demo.4     centos:7  node-2  Running        Running 6 minutes ago 
    ```

    Swarm has automatically started a replacement container for the one you killed on `node-1`. Go back over to `node-1`, and do `docker container ls` again; you'll see a new container for this service up and running.

3.  Next, let's simulate a complete node failure by rebooting one of our nodes:

    ```bash
    [centos@node-3 ~]$ sudo reboot now
    ```

4.  Back on your swarm manager, check your service containers again:

    ```bash
    [centos@node-0 ~]$ docker service ps service-demo
    ID      NAME               IMAGE     NODE    DESIRED STATE  CURRENT STATE
    ral...  service-demo.1     centos:7  node-0  Running        Running 19 seconds ago
    g3d...  \_ service-demo.1  centos:7  node-3  Shutdown       Running 38 seconds ago     
    e7d...  service-demo.2     centos:7  node-0  Running        Running 12 minutes ago
    u7l...  service-demo.3     centos:7  node-1  Running        Running 5 minutes ago
    wv0...  \_ service-demo.3  centos:7  node-1  Shutdown       Failed 5 minutes ago
    ty3...  service-demo.4     centos:7  node-2  Running        Running 12 minutes ago 
    ```

    The process on `node-3` has been scheduled for `SHUTDOWN` when the swarm manager lost connection to that node, and meanwhile the workload has been rescheduled onto `node-0` in this case. When `node-3` comes back up and rejoins the swarm, its container will be confirmed to be in the `SHUTDOWN` state, and reconciliation is complete.

5.  Remove your `service-demo`:

    ```bash
    [centos@node-0 ~]$ docker service rm service-demo
    ```

    All tasks and containers will be removed.

## Conclusion

One of the great advantages of the portability of containers is that we can imagine orchestrators like Swarm which can schedule and re-schedule workloads across an entire datacenter, such that if a given node fails, all its workload can be automatically moved to another host with available resources. In the above example, we saw the most basic examples of this 'reconciliation loop' that swarm provides: the swarm manager is constantly monitoring all the containers it has scheduled, and replaces them if they fail or their hosts become unreachable, completely automatically.
