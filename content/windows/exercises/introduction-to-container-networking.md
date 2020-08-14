# Introduction to Container Networking

By the end of this exercise, you should be able to:

 - Attach containers to Docker's default nat network
 - Resolve containers by DNS entry

## Inspecting the Default Nat Network

1.  Let's use the Docker CLI to inspect the NAT network. The `docker network inspect` command yields network information about what containers are connected to the specified network; the default network is always called `nat`, so run:

    ```powershell
    PS: node-1 Administrator> docker network inspect nat
    ```

    This returns state and metadata about your network; note especially the list of containers attached to this network:

    ```json
     "Containers": {}
    ```

    Currently, there are no containers attached to the `nat` network; but if you create any without specifying a network, this is where they'll be attached by default.

## Connecting Containers to Default Nat

1.  Start some named containers:

    ```powershell
    PS: node-1 Administrator> docker container run --name=u1 -dt `
        mcr.microsoft.com/powershell:preview-nanoserver-1809
    PS: node-1 Administrator> docker container run --name=u2 -dt `
        mcr.microsoft.com/powershell:preview-nanoserver-1809
    ```

2.  Inspect the `nat` network again:

    ```powershell
    PS: node-1 Administrator> docker network inspect nat
    ```

    You should see two new entries in the `Containers` section of the result, one for each container:
    
    ```json
    ...
    "Containers": {
        "45e8576...": {
            "Name": "u1",
            "EndpointID": "8e938af....",
            "MacAddress": "00:15:5d:e6:0a:ec",
            "IPv4Address": "172.20.131.137/16",
            "IPv6Address": ""
        },
        "b7e49f5...": {
            "Name": "u2",
            "EndpointID": "266f0c0...",
            "MacAddress": "00:15:5d:e6:07:06",
            "IPv4Address": "172.20.135.21/16",
            "IPv6Address": ""
        },
        ...
    }
    ...
    ```
    
    We can see that each container gets a `MacAddress` and an `IPv4Address` associated. The `nat` network is providing level 2 routing and transfers network packets between MAC addresses.

3.  Connect to container `u2` of your containers using `docker container exec -it u2 pwsh.exe`. 

4.  From inside `u2`, try pinging container `u1` by the IP address you found in the previous step; then try pinging `u1` by container name, `ping u1`. Notice the lookup works with both the IP and the container name.

5.  Clean up these containers:

    ```powershell
    PS: node-1 Administrator> docker container rm -f u1 u2
    ```

## Conclusion

In this exercise, you explored the most basic example of container networking: two containers communicating on the same host via network address translation and a layer 2 in-software router in the form a a Hyper-V switch. In addition to this basic routing technology, you saw how Docker leverages DNS lookup via container name to make our container networking portable; by allowing us to reach another container purely by name, without doing any other service discovery, we make it simple to design application logic meant to communicate container-to-container. At no point did our application logic need to discover anything directly about the networking infrastructure it was running on.
