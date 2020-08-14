# Instructor Demo: Self-Healing Swarm

In this demo, we'll illustrate:

 - Setting up a swarm
 - How swarm makes basic scheduling decisions
 - Actions swarm takes to self-heal a docker service

## Setting Up a Swarm

1.  Start by making sure no containers are running on any of your nodes:

    ```powershell
    PS: node-0 Administrator> docker container rm -f $(docker container ls -aq)
    PS: node-1 Administrator> docker container rm -f $(docker container ls -aq)
    PS: node-2 Administrator> docker container rm -f $(docker container ls -aq)
    PS: node-3 Administrator> docker container rm -f $(docker container ls -aq)
    ```

2.  Initialize a swarm on `node-0`:

    ```powershell
    PS: node-0 Administrator> $PRIVATEIP = '<node-0 private IP>'
    PS: node-0 Administrator> docker swarm init `
        --advertise-addr ${PRIVATEIP} `
        --listen-addr ${PRIVATEIP}:2377

	Swarm initialized: current node (xyz) is now a manager.

	To add a worker to this swarm, run the following command:

	    docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377

	To add a manager to this swarm, run 'docker swarm join-token manager' 
        and follow the instructions.
    ```

3.  List the nodes in your swarm:

    ```powershell
    PS: node-0 Administrator> docker node ls

    ID      HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS
    xyz *   node-0     Ready    Active         Leader
    ```

4.  Add some workers to your swarm by cutting and pasting the `docker swarm join...` token Docker provided in step 2 above:

    ```powershell
    PS: node-1 Administrator> docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377
    PS: node-2 Administrator> docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377
    PS: node-3 Administrator> docker swarm join --token SWMTKN-1-0s96... 10.10.1.40:2377
    ```

    Each node should report `This node joined a swarm as a worker.` after joining.

5.  Back on `node-0`, list your swarm members again:

    ```powershell
    PS: node-0 Administrator> docker node ls

    ID      HOSTNAME   STATUS   AVAILABILITY   MANAGER STATUS
    ghi     node-3     Ready    Active              
    def     node-2     Ready    Active              
    abc     node-1     Ready    Active              
    xyz *   node-0     Ready    Active         Leader
    ```
    
    You have a four-member swarm, ready to accept workloads.

## Scheduling Workload

1.  Create a service on your swarm:

    ```powershell
    PS: node-0 Administrator> docker service create `
        --replicas 4 `
        --name service-demo `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping -t 8.8.8.8
    ```

2.  List what processes have been started for your service:

    ```powershell
    PS: node-0 Administrator> docker service ps service-demo

    ID     NAME            IMAGE       NODE    DESIRED   CURRENT STATE
                                                 STATE
    g3...  service-demo.1  nanoserver  node-3  Running   Running 18 seconds ago
    e7...  service-demo.2  nanoserver  node-0  Running   Running 18 seconds ago  
    wv...  service-demo.3  nanoserver  node-1  Running   Running 18 seconds ago    
    ty...  service-demo.4  nanoserver  node-2  Running   Running 18 seconds ago
    ```

    Our service has scheduled four tasks, one on each node in our cluster; by default, swarm tries to spread tasks out evenly across hosts, but much more sophisticated scheduling controls are also available.

## Maintaining Desired State

1.  Connect to `node-1`, and list the containers running there:

    ```powershell
    PS: node-1 Administrator> docker container ls

    CONTAINER ID  IMAGE          COMMAND                    ...  NAMES
    5b5f77c67eff  54.152.61.101  "powershell ping 8.8.8.8"  ...  service-demo.3.wv0cul...
    ```

    Note the container's name indicates the service it belongs to.

2.  Let's simulate a container crash, by killing off this container:

    ```powershell
    PS: node-1 Administrator> docker container rm -f <container ID>
    ```

    Back on our swarm manager `node-0`, list the processes running for our `service-demo` service again:

    ```powershell
    PS: node-0 Administrator> docker service ps service-demo

    ... NAME               IMAGE        NODE    DESIRED   CURRENT STATE
                                                  STATE      
    ... service-demo.1     nanoserver   node-3  Running   Running 6 minutes ago   
    ... service-demo.2     nanoserver   node-0  Running   Running 6 minutes ago      
    ... service-demo.3     nanoserver   node-1  Running   Running 3 seconds ago          
    ... \_ service-demo.3  nanoserver   node-1  Shutdown  Failed 3 seconds ago
    ... service-demo.4     nanoserver   node-2  Running   Running 6 minutes ago 
    ```

    Swarm has automatically started a replacement container for the one you killed on `node-1`. Go back over to `node-1`, and do `docker container ls` again; you'll see a new container for this service up and running.

3.  Next, let's simulate a complete node failure by rebooting one of our nodes; on `node-3`, navigate **Start menu -> Power -> Restart**.

4.  Back on your swarm manager, check your service containers again; after a few moments, you should see something like:

    ```powershell
    PS: node-0 Administrator> docker service ps service-demo
    NAME               IMAGE       NODE    DESIRED    CURRENT STATE
                                             STATE
    service-demo.1     nanoserver  node-0  Running    Running 19 seconds ago
    \_ service-demo.1  nanoserver  node-3  Shutdown   Running 38 seconds ago     
    service-demo.2     nanoserver  node-0  Running    Running 12 minutes ago
    service-demo.3     nanoserver  node-1  Running    Running 5 minutes ago
    \_ service-demo.3  nanoserver  node-1  Shutdown   Failed 5 minutes ago
    service-demo.4     nanoserver  node-2  Running    Running 12 minutes ago 
    ```

    The process on node-3 has been scheduled for `SHUTDOWN` when the swarm manager lost connection to that node, and meanwhile the workload has been rescheduled onto node-0 in this case. When node-3 comes back up and rejoins the swarm, its container will be confirmed to be in the `SHUTDOWN` state, and reconciliation is complete.

5.  Remove your `service-demo`:

    ```powershell
    PS: node-0 Administrator> docker service rm service-demo
    ```

    All tasks and containers will be removed.

## Conclusion

One of the great advantages of the portability of containers is that we can imagine orchestrators like Swarm which can schedule and re-schedule workloads across an entire datacenter, such that if a given node fails, all its workload can be automatically moved to another host with available resources. In the above example, we saw the most basic examples of this 'reconciliation loop' that swarm provides: the swarm manager is constantly monitoring all the containers it has scheduled, and replaces them if they fail or their hosts become unreachable, completely automatically.
