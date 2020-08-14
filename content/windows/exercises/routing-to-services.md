# Routing Traffic to Docker Services

By the end of this exercise, you should be able to:

 - Route traffic to a Docker service from within the swarm using dnsrr DNS lookups
 - Route traffic to a Docker service from outside the swarm using host port publishing

## Routing Cluster-Internal Traffic

1.  By *cluster-internal traffic*, we mean traffic from originating from a container running on your swarm, sending a request to another container running on the same swarm. Let's create a stack with two such services, attached to a custom overlay network; create a file `net-demo.yaml` with the following content:

    ```yaml
    version: "3.7"    

    services:
      destination:
        image: training/whoami-windows:ws19
        deploy:
          replicas: 3
        networks:
          - demonet

      origin:
        image: mcr.microsoft.com/powershell:preview-nanoserver-1809
        command: ["pwsh.exe", "-Command", "Start-Sleep", "100000"]
        networks:
          - demonet          

    networks:
      demonet:
        driver: overlay
    ```

    Here our `destination` service is using the `deploy:replicas` key to ask for three replica containers based on the `training/whoami-windows` image; this image serves a simple web page on port 5000 that reports the ID of the container its running in. Our `origin` service is using the `command` key to define what process to run in a container based on the `mcr.microsoft.com/powershell:preview-nanoserver-1809` image; in this case we just put it to sleep so we have a running container we can attach to and interact with later.

2.  Deploy your stack, and find out what node your `origin` container is running on:

    ```powershell
    PS: node-0 Administrator> docker stack deploy -c net-demo.yaml netstack

    PS: node-0 Administrator> docker stack ps netstack

    ID       NAME                     IMAGE                       NODE     DESIRED STATE
    73i...   netstack_destination.1   training/whoami-windows     node-2   Running       
    y8i...   netstack_origin.1        nanoserver:10.0.14393.2551  node-0   Running       
    pgw...   netstack_destination.2   training/whoami-windows     node-1   Running       
    thi...   netstack_destination.3   training/whoami-windows     node-3   Running       
    ```

3.  Connect to the node running your `origin` container (`node-0` in the example above), and create a powershell inside that container:

    ```powershell
    PS: node-0 Administrator> docker container ls

    CONTAINER ID        IMAGE                        COMMAND       
    3047dbb47a7a        nanoserver:10.0.14393.2551   Start-Sleep...

    PS: node-0 Administrator> docker container exec -it <container ID> pwsh.exe

    PS C:\>
    ```

4.  Probe the DNS resolution of your `destination` service:

    ```powershell
    PS C:\> [System.Net.Dns]::GetHostEntry('destination')

    HostName    Aliases AddressList
    --------    ------- -----------
    destination {}      {10.85.6.130}
    ```

    By default, swarm services are assigned a *virtual IP*, and their service name will DNS resolve to this VIP inside any container attached to the same Docker network. Try doing `docker service inspect netstack_destination` back on a manager to confirm that the IP you resolved above is what's listed for the virtual IP for this service.

5.  Try contacting your `destination` service using the VIP you found above:

    ```powershell
    PS C:\> (Invoke-WebRequest http://<virtual IP>:5000).Content

    I am 02FF20A20861
    ```

    Execute the same a few more times to see swarm's default load balancing: subsequent requests get routed across all `whoami` containers in round robin fashion.

6.  Clean up by removing your stack: `docker stack rm netstack`.

## Routing Cluster-External Traffic

In the last section, we routed traffic from one Docker service to another within the same swarm. If we want to route ingress traffic from an external network to a service, we have to expose it on the *routing mesh*.

1.  Create a new stack file `mesh.yaml`:

    ```yaml
    version: "3.7"

    services:
      destination:
        image: training/whoami-windows:ws19
        deploy:
          replicas: 3
        ports:
          - 8080:5000
    ```

    Here the `ports:` key is specifying that traffic arriving at port 8080 on *any node in the swarm* should be forwarded to port 5000 of our `whoami` container.

2.  Deploy your stack:

    ```bash
    PS: node-0 Administrator> docker stack deploy -c mesh.yaml mesh
    ```

3.  List your service and observe which nodes the containers got scheduled on:

    ```bash
    PS: node-0 Administrator> docker service ls
    PS: node-0 Administrator> docker service ps mesh_destination

    ID                  NAME                 IMAGE                 NODE  
    1wsqyjgznv0a        mesh_destination.1   whoami-windows:ws19   node-0     
    ljhr1dukx6v0        mesh_destination.2   whoami-windows:ws19   node-3     
    albbml1idsw4        mesh_destination.3   whoami-windows:ws19   node-2
    ```

4.  Visit the public IP of every one of your nodes on port 8080 in your browser; no matter which public IP you choose, your request will get routed to a `whoami` backend container - even if you visit the public IP of a node *not* running a `whoami` container. This is the mesh net in action (note that many browsers' caching behavior will hide the round robin load balancing; if you want to see the load balancing in the browser, try using a 'history-less' browser mode, closing and reopening the browser or completely purging history between each refresh).

5.  Clean up by deleting your `mesh` stack.

## Conclusion

In this exercise, you saw the basic service discovery and routing that Swarm enables via DNS lookup of service names, VIP routing and port forwarding across network namespaces. In general, using this networking plane to do our service discovery helps make our inter-service communication more robust against container failure. If we were communicating with a container directly by its IP, we would have to constantly monitor whether that container was still actually reachable at that IP; Swarm effectively does that for us when we communicate via DNS resolution of service names to VIPs, since a failed container will get pulled out of the virtual IP server's round-robin routing automatically. In the case of using the mesh net to route ingress traffic from outside our cluster, mapping the external port on *every* host in the swarm onto the service's VIP means our external load balancers (which is realistically the point of ingress for external traffic to our swarm), doesn't need to know anything about where our service is scheduled; it can simply send requests to any node in the swarm, and Docker handles the rest.
