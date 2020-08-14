# Instructor Demo: Single Host Networks

In this demo, we'll illustrate:

 - The networking stack created for the default Docker `nat` network
 - Attaching containers to docker networks
 - Inspecting networking metadata
 - How network adapters appear in different network namespaces

## Following Default Docker Networking

1.  On a fresh node you haven't run any containers on yet, list your networks:

    ```powershell
    PS: node-1 Administrator> docker network ls
    
    NETWORK ID          NAME                DRIVER              SCOPE
    03f6ddacab50        nat                 nat                 local
    b0de36ba94f3        none                null                local
    ```

2.  Get some metadata about the `nat` network, which is the default network containers attach to when doing `docker container run`:

    ```powershell
    PS: node-1 Administrator> docker network inspect nat
    ```

    Note the `containers` key:

    ```json
    "Containers": {}
    ```

    So far, no containers have been plugged into this network.

3.  Create a container attached to your nat network:

    ```powershell
    PS: node-1 Administrator> docker container run --name=c1 -dt `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737
    ```

    The `network inspect` command above will now show this container plugged into the `nat` network, which is the default network containers are attached to if they aren't created with a `--network` key.

4.  Have a look at the network adapters created inside this container's network namespace:

    ```powershell
    PS: node-1 Administrator> docker container exec c1 ipconfig /all

    Windows IP Configuration    

       Host Name . . . . . . . . . . . . : b201969c45d5
       Primary Dns Suffix  . . . . . . . :
       Node Type . . . . . . . . . . . . : Hybrid
       IP Routing Enabled. . . . . . . . : No
       WINS Proxy Enabled. . . . . . . . : No
       DNS Suffix Search List. . . . . . : us-east-2.compute.internal    

    Ethernet adapter vEthernet (Ethernet) 4:    

       Connection-specific DNS Suffix  . : us-east-2.compute.internal
       Description . . . . . . . . . . . : Hyper-V Virtual Ethernet Adapter #6
       Physical Address. . . . . . . . . : 00-15-5D-74-66-CC
       DHCP Enabled. . . . . . . . . . . : No
       Autoconfiguration Enabled . . . . : Yes
       Link-local IPv6 Address . . . . . : fe80::81f:26c5:f9a3:b2cf%22(Preferred)
       IPv4 Address. . . . . . . . . . . : 172.17.168.239(Preferred)
       Subnet Mask . . . . . . . . . . . : 255.255.240.0
       Default Gateway . . . . . . . . . : 172.17.160.1
       DNS Servers . . . . . . . . . . . : 172.17.160.1
                                           172.31.0.2
       NetBIOS over Tcpip. . . . . . . . : Disabled
       Connection-specific DNS Suffix Search List :
                                           us-east-2.compute.internal
    ```

    Note the Host Name matches the container ID by default, and the IPv4 address of the virtual ethernet adapter inside the container matches the container IP.

5.  Create another container, and ping one from the other by container name:

    ```powershell
    PS: node-1 Administrator> docker container run --name=c2 -dt `
                                mcr.microsoft.com/windows/nanoserver:10.0.17763.737
    PS: node-1 Administrator> docker container exec c1 ping c2

    Pinging c2 [172.20.134.196] with 32 bytes of data:
    Reply from 172.20.134.196: bytes=32 time<1ms TTL=128
    Reply from 172.20.134.196: bytes=32 time<1ms TTL=128
    Reply from 172.20.134.196: bytes=32 time<1ms TTL=128
    Reply from 172.20.134.196: bytes=32 time<1ms TTL=128

    Ping statistics for 172.20.134.196:
        Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
    Approximate round trip times in milli-seconds:
        Minimum = 0ms, Maximum = 0ms, Average = 0ms
    ```

    The ping is successful; Docker uses DNS resolution so that our application logic (`ping c2` in this case) doesn't need to do any explicit service discovery or networking lookups by hand; all that is provided by the Docker engine and Windows networking stack.

6.  Create one final container, but don't name it this time, and attempt to ping it from `c1` like above:

    ```powershell
    PS: node-1 Administrator> docker container run -dt `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737
        
    PS: node-1 Administrator> docker container exec c1 ping <new container name>

    Ping request could not find host <new container name>. 
        Please check the name and try again.
    ```

    Docker only provides DNS lookup for containers explicitly named with the `--name` flag.

## Forwarding a Host Port to a Container

1.  Start an `nginx` container with a port exposure:

    ```powershell
    PS: node-1 Administrator> docker container run -d -p 5000:80 --name proxy nginx
    ```

    This syntax asks docker to forward all traffic arriving on port 5000 of the host's network namespace to port 80 of the container's network namespace. Visit the `nginx` landing page at `<node-1 public IP>:5000` in a browser.

2.  Delete all you containers on this node to clean up:

    ```powershell
    PS: node-1 Administrator> docker container rm -f $(docker container ls -aq)
    ```

## Conclusion

In this demo, we stepped through the basic behavior of docker software defined nat networks. By default, all containers started on a host without any explicit networking configuration will be able to communicate across Docker's `nat` network, and in order for containers to resolve each other's name by DNS, they must also be explicitly named upon creation.
