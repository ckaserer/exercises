# Routing to Services

By the end of this exercise, you should be able to:

 - Route traffic originating either inside or outside your cluster to stateless Swarm services.

## Routing Cluster-Internal Traffic

1.  By *cluster-internal traffic*, we mean traffic from originating from a container running on your swarm, sending a request to another container running on the same swarm. Let's create a stack with two such services, attached to a custom overlay network; create a file `net-demo.yaml` with the following content:

    ```yaml
    version: "3.7"    

    services:
      destination:
        image: training/whoami:latest
        deploy:
          replicas: 3
        networks:
          - demonet

      origin:
        image: centos:7
        command: ["sleep", "100000"]
        networks:
          - demonet          

    networks:
      demonet:
        driver: overlay
    ```

    Here our `destination` service is using the `deploy:replicas` key to ask for three replica containers based on the `training/whoami` image; this image serves a simple web page on port 8000 that reports the ID of the container its running in. Our `origin` service is using the `command` key to define what process to run in a container based on the `centos:7` image. 

2.  Deploy your stack, and find out what node your `origin` container is running on:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c net-demo.yaml netstack

    [centos@node-0 ~]$ docker stack ps netstack
    
    ID                  NAME                     IMAGE                    NODE
    tqsurlytrruu        netstack_destination.1   training/whoami:latest   node-0
    lp3hwp3c4nih        netstack_origin.1        centos:7                 node-3
    g94q730kdto5        netstack_destination.2   training/whoami:latest   node-1                         
    n5297tisleso        netstack_destination.3   training/whoami:latest   node-2
    ```

3.  Switch to the node running your `origin` container (`node-3` in the example above), and create a bash shell inside that container:

    ```bash
    [centos@node-3 ~]$ docker container ls

    CONTAINER ID        IMAGE               COMMAND       
    3047dbb47a7a        centos:7            "sleep 100000"

    [centos@node-3 ~]$ docker container exec -it <container ID> bash

    [root@3047dbb47a7a /]#
    ```

4.  From within your origin container, attempt to `curl` your destination container by service name several times:

    ```bash
    [root@3047dbb47a7a /]# curl destination:8000
    I'm a16b6e9741db
    [root@3047dbb47a7a /]# curl destination:8000
    I'm d3d800059d7b
    [root@3047dbb47a7a /]# curl destination:8000
    I'm bace80287419
    [root@3047dbb47a7a /]# curl destination:8000
    I'm a16b6e9741db
    ```

    *The service name defined in you stack file is DNS resolvable*, and load balances traffic in round robin fashion across all the containers corresponding to that service. In this way, your application logic (simply `curl` in this example) doesn't need to do any explicit service discovery or routing to contact another service; all of that is handled by Docker's networking layer.

5.  (Optional): Still inside your `centos` container, install `nslookup`, and use it to see what `destination` is actually resolving to:

    ```bash
    [root@3047dbb47a7a /]# yum install -y bind-utils

    [root@3047dbb47a7a /]# nslookup destination
    Server:     127.0.0.11
    Address:    127.0.0.11#53    

    Non-authoritative answer:
    Name:   destination
    Address: 10.85.5.133
    ```

    That IP (`10.85.5.133`) is the *virtual IP* of your `destination` service. Docker automatically configures an IP virtual server on every host in your Swarm to route traffic from this VIP to the corresponding backend containers as we saw above.

6.  Exit your container, and clean up by removing your stack:

    ```bash
    [root@3047dbb47a7a /]# exit
    [centos@node-0 ~]$ docker stack rm netstack
    ```

## Routing Cluster-External Traffic

In the last section, we routed traffic from one Docker service to another, all within the same swarm. If we want to route ingress traffic from an external network to a service, we have to expose it on the *routing mesh*.

1.  Create a new stack file `mesh.yaml`:

    ```yaml
    version: "3.7"    

    services:
      destination:
        image: training/whoami:latest
        deploy:
          replicas: 3
        ports:
          - 8080:8000
    ```

    Here the `ports:` key is specifying that traffic arriving at port 8080 on *any node in the swarm* should be forwarded to port 8000 of our `whoami` container.

2.  Deploy your stack, and curl the public IP of any node in your swarm on port 8080 a few times:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c mesh.yaml mesh

    [centos@node-0 ~]$ curl 52.55.221.133:8080
    I'm 17f79606a85b
    [centos@node-0 ~]$ curl 52.55.221.133:8080
    I'm a8f60ac476b9
    [centos@node-0 ~]$ curl 52.55.221.133:8080
    I'm b285c54f5fb0
    [centos@node-0 ~]$ curl 52.55.221.133:8080
    I'm 17f79606a85b
    ```

    Traffic is forwarded from the host's network namespace's port 8080 to the `whoami` containers' network namespaces in round robin fashion, similarly to above, but this time from *outside* our swarm; try visiting this IP and port in your browser to convince yourself this is externally reachable (but note that many browsers' caching behavior will hide the round robin load balancing; if you want to see the load balancing in the browser, try using a 'history-less' browser mode, closing and reopening the browser or completely purging history between each refresh).

3.  Try the same `curl` again, but with the public IP for a different node in your swarm; it'll work the exact same way, since the routing mesh forwards traffic inbound to port 8080 on *any* node in the swarm on to the containers scheduled for your `destination` service.

    > **Cluster internal versus cluster external routing** is often misunderstood by new Swarm users; note that the port mapping `8080:8000` we created to make our service available externally on the mesh net was *not necessary* for making our service reachable by other services internally to our swarm. In general, you should not expose services on the mesh net unless they need to be reachable on the external network.

4.  Clean up by deleting your `mesh` stack.

## Conclusion

In this exercise, you saw the basic service discovery and routing that Swarm enables via DNS lookup of service names, VIP routing and port forwarding across network namespaces. In general, using this networking plane to do our service discovery helps make our inter-service communication more robust against container failure. If we were communicating with a container directly by its IP, we would have to constantly monitor whether that container was still actually reachable at that IP; Swarm effectively does that for us when we communicate via DNS resolution of service names to VIPs, since a failed container will get pulled out of the virtual IP server's round-robin routing automatically. In the case of using the mesh net to route ingress traffic from outside our cluster, mapping the external port on *every* host in the swarm onto the service's VIP means our external load balancers (which is realistically the point of ingress for external traffic to our swarm), doesn't need to know anything about where our service is scheduled; it can simply send requests to any node in the swarm, and Docker handles the rest.
