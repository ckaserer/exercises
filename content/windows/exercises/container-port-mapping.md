# Container Port Mapping

By the end of this exercise, you should be able to:

 - Forward traffic from a port on the docker host to a port inside a container's network namespace
 - Define ports to automatically expose in a Dockerfile

## Port Mapping at Runtime

1.  Run an IIS container with no special port mappings:

    ```powershell
    PS: node-1 Administrator> docker container run -d microsoft/iis
    ```

    IIS stands up a landing page at `http://<IP>:80`; try to visit this at your host's public IP, and it won't be visible; no external traffic can make it past the Windows NAT's firewall to the container running IIS.

2.  Now run an IIS container and map port 80 on the container to port 5000 on your host using the `-p` flag:

    ```powershell
    PS: node-1 Administrator> docker container run -d -p 5000:80 --name iis microsoft/iis
    ```

    Note that the syntax is: `-p [host-port]:[container-port]`.

3.  Verify the port mappings with the `docker container port` command:

    ```powershell
    PS: node-1 Administrator> docker container port iis
    ```

4.  Open a browser window and visit your IIS landing page at `<host ip>:5000`; you should see the default IIS landing page. Your browser's network request to port 5000 in the host network namespace has been forwarded on to the container's network namespace at port 80.

## Exposing Ports from the Dockerfile

1.  In addition to manual port mapping, we can expose some ports in a Dockerfile for automatic port mapping on container startup. In a fresh directory `portdemo`, create a Dockerfile:

    ```dockerfile
    FROM microsoft/iis
    EXPOSE 80
    ```

2.  Build your image as `my_iis`:
    
    ```powershell
    PS: node-1 portdemo> docker image build -t my_iis .
    ```

3.  Use the `-P` flag when running to map all ports mentioned in the `EXPOSE` directive:

    ```powershell
    PS: node-1 portdemo> docker container run -d -P my_iis
    ```

4.  Use `docker container ls` or `docker container port` to find out what host ports were used, and visit your IIS landing page in a browser at `<node-1 public IP>:<port>`.

5.  Clean up your containers:

    ```powershell
    PS: node-1 portdemo> docker container rm -f $(docker container ls -aq)
    ```

## Conclusion

In this exercise, we saw how to explicitly map ports from our container's network stack onto ports of our host at runtime with the `-p` option to `docker container run`, or more flexibly in our Dockerfile with `EXPOSE`, which will result in the listed ports inside our container being mapped to random available ports on our host.
