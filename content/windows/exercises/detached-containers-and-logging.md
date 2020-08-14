# Detached Containers and Logging

By the end of this exercise, you should be able to:

- Run a container detached from the terminal
- Fetch the logs of a container
- Attach a terminal to the STDOUT of a running container

## Running a Container in the Background

1.  First try running a container as usual; the STDOUT and STDERR streams from the main containerized process are directed to the terminal:

    ```powershell
    PS: node-0 Administrator> docker container run `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -n 2

    Pinging 8.8.8.8 with 32 bytes of data:
    Reply from 8.8.8.8: bytes=32 time=1ms TTL=113
    Reply from 8.8.8.8: bytes=32 time=1ms TTL=113

    Ping statistics for 8.8.8.8:
        Packets: Sent = 2, Received = 2, Lost = 0 (0% loss),
    Approximate round trip times in milli-seconds:
        Minimum = 1ms, Maximum = 1ms, Average = 1ms
    ```

2.  The same process can be run in the background with the `-d` flag:

    ```powershell
    PS: node-0 Administrator> docker container run -d `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -t

    5505012d74b3480a0a05ebd0ca1d256d08edc1916ef19d56fbe728bc3cecc502
    ```

    This time, we only see the container's ID; its STDOUT isn't being sent to the terminal.

3.  Use this second container's ID to inspect the logs it generated:

    ```powershell
    PS: node-0 Administrator> docker container logs <container ID>
    ```

    These logs correspond to STDOUT and STDERR from all processes running in the container. Also note when using container IDs: you don't need to specify the entire ID. Just enough characters from the start of the ID to uniquely identify it, often just 2 or 3, is sufficient.

## Attaching to Container Output

1.  We can attach a terminal to a container's main process output with the `attach` command; try it with the last container you made in the previous step:

    ```powershell
    PS: node-0 Administrator> docker container attach <container ID>
    ```

2.  We can leave attached mode by then pressing `CTRL+C`. Note that the container still happily runs in the background as you can confirm with `docker container ls`.

## Using Logging Options

1.  We saw previously how to read the entire log of a container's main process; we can also use a couple of flags to control what logs are displayed. `--tail n` limits the display to the last n lines; try it with the container that should be running from the last step:

    ```powershell
    PS: node-0 Administrator> docker container logs --tail 5 <container ID>
    ```

    You should see the last 5 pings from this container.

## Conclusion

In this exercise, we saw our first detached containers. Almost all containers you ever run will be running in detached mode; you can use `container attach` to interact with their main processes, as well as `container logs` to fetch their logs. Note that both `attach` and `logs` interact with the main process only - if you launch child processes inside a container, it's up to you to manage their STDOUT and STDERR streams.
