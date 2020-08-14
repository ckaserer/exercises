# Running & Inspecting Containers

By the end of this exercise, you should be able to:

 - Start a container
 - List containers in a couple of different ways
 - Query the `docker` command line help
 - Remove containers
 
1.  Create and start a new nanoserver container running `ping` to 8.8.8.8:

    ```powershell
    PS: node-0 Administrator> docker container run `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -n 3    

    Pinging 8.8.8.8 with 32 bytes of data:
    Reply from 8.8.8.8: bytes=32 time=2ms TTL=113
    Reply from 8.8.8.8: bytes=32 time<1ms TTL=113
    Reply from 8.8.8.8: bytes=32 time<1ms TTL=113    

    Ping statistics for 8.8.8.8:
        Packets: Sent = 3, Received = 3, Lost = 0 (0% loss),
    Approximate round trip times in milli-seconds:
        Minimum = 0ms, Maximum = 2ms, Average = 0ms
    ```
 
2.  This first container sent its STDOUT to your terminal; create a second container, this time in *detatched mode*, and let it run indefinitely:

    ```powershell
    PS: node-0 Administrator> docker container run --detach `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.4.4 -t
    
    4bc814e2257b2d1046c10e563b553279b7e11e8bf6309eff9047d2dfb086900f
    ```
   
    Instead of seeing the executed command (`ping 8.8.4.4 -t`), Docker engine displays a long hexidecimal number, which is the full *container ID* of your new container. The container is running detached, which means the container is running as a background process, rather than printing its STDOUT to your terminal.

3.  List the running Docker containers using the `docker container ls` container command. You will see only one container running.

    ```powershell    
    PS: node-0 Administrator> docker container ls

    CONTAINER ID  IMAGE                       COMMAND            ...  STATUS       
    4bc814e2257b  nanoserver:10.0.17763.737  "ping 8.8.4.4 -t"  ...  Up 53 seconds
    ```

4.  Now you know that the `docker container ls` command only shows running containers. You can show all containers that exist (running or stopped) by using `docker container ls --all`.  Your container ID and name will vary. Note that you will see two containers: a stopped container and a running container.

    ```powershell
    PS: node-0 Administrator> docker container ls --all 

    CONTAINER ID  IMAGE       COMMAND              STATUS
    4bc814e2257b  nanoserver  "ping 8.8.4.4 -t"    Up About a minute
    7aea600a8c76  nanoserver  "ping 8.8.8.8 -n 3"  Exited (0) 3 minutes
    ```
  
    > **Where did those names come from?** The table above has been truncated for readability, but in your output you should also see a `NAME` column on the right. All containers have names, which in most Docker CLI commands can be substituted for the container ID as we'll see in later exercises. By default, containers get a randomly generated name of the form `<adjective>_<scientist / technologist>`, but you can choose a name explicitly with the `--name` flag in `docker container run`. 

5.  Start up another detached container, this time giving it a name "opendnsping".

    ```powershell
    PS: node-0 Administrator> docker container run --detach --name opendnsping `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 208.67.222.222 -t
    ```

6.  List all your containers again. You can see all of the containers, including your new one with your customized name.

    ```powershell
    PS: node-0 Administrator> docker container ls --all

    CONTAINER ID  IMAGE        COMMAND                  NAMES
    e706e1168689  nanoserver   "ping 208.67.222.222…"   opendnsping
    4bc814e2257b  nanoserver   "ping 8.8.4.4 -t"        eloquent_rubin
    7aea600a8c76  nanoserver   "ping 8.8.8.8 -n 3"      frosty_mclean
    ```

7.  Next, remove the exited container. To do this, use `docker container rm <container-id>`. In the example above, the Docker container ID is `7aea600a8c76`.

    ```powershell
    PS: node-0 Administrator> docker container rm <container ID>

    7aea600a8c76
    ``` 

8.  Now try to remove one of the other Docker containers using the same command. It does not work. Why?

    ```powershell
    PS: node-0 Administrator> docker container rm <container ID>
    
    Error response from daemon: You cannot remove a running container 
    4bc814e2257b2d1046c10e563b553279b7e11e8bf6309eff9047d2dfb086900f. 
    Stop the container before attempting removal or force remove
    ```
  
9.  You can see that running containers are not removed. You'll have to look for an option to remove a running container. In order to find out the option you need to do a force remove, check the command line help. To do this with the `docker container rm` command, use the `--help` option:

    ```powershell
    PS: node-0 Administrator> docker container rm --help

    Usage: docker container rm [OPTIONS] CONTAINER [CONTAINER...]

    Remove one or more containers

    Options:
     -f, --force     Force the removal of a running container (uses SIGKILL)
     -l, --link      Remove the specified link
     -v, --volumes   Remove the volumes associated with the container
    ```

    > **Help works with all Docker commands** Not only can you use `--help` with `docker container rm`, but it works on all levels of `docker` commands. For example, `docker --help` provides you will all the available `docker` commands, as does `docker container --help` provide you with all available container commands.
 
10. Now, run a force remove on the running container you tried to remove in the two previous steps. This time it works.

    ```powershell
    PS: node-0 Administrator> docker container rm --force <container ID>
    
    4bc814e2257b
    ```

11. Start another detached container pinging 8.8.8.8, with the name `pinggoogledns`.

    ```powershell
    PS: node-0 Administrator> docker container run --detach --name pinggoogledns `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -t
                       
    38e121e629611daa0726a21d634bc5189400377d82882cc6fd8a3870dc9943a0
    ```

12. Now that you've finished your testing, you need to remove your containers. In order to remove all of them at once, you want to get only the container IDs. Look at `docker container ls --help` to get the information you need:

    ```powershell
    PS: node-0 Administrator> docker container ls --help

    Usage:  docker container ls [OPTIONS]

    List containers

    Aliases:
      ls, ps, list

    Options:
      -a, --all           Show all containers (default shows just running)
      -f, --filter filter Filter output based on conditions provided
      --format string     Pretty-print containers using a Go template
      -n, --last int      Show n last created containers (includes all states)
      -l, --latest        Show the latest created container (includes all states)
          --no-trunc      Don't truncate output
      -q, --quiet         Only display numeric IDs
      -s, --size          Display total file sizes
    ```

13. To get only the container IDs, use the `--quiet` option.  If you want to use only the container IDs of all existing containers to perform an action on, you can use `--quiet` with the `--all` option.

    ```powershell
    PS: node-0 Administrator> docker container ls --all --quiet
    
    e706e1168689     
    38e121e62961
    ```

14. Since we are done running pings on the public DNS servers, destroy the containers. To do this, use the syntax `docker container rm --force <containerID>`. However, this only kills one container at a time. We want to kill all the containers, no matter what state the containers are in. To get this information, you will need to use the output from `docker container ls --quiet --all`. To capture this output within the command, use `$(...)` to nest the listing command inside the `docker container rm` command.

    ```powershell
    PS: node-0 Administrator> docker container rm --force `
        $(docker container ls --quiet --all)
    
    e706e1168689     
    38e121e62961
    ```

## Conclusion

This exercise taught you how to start, list, and kill containers. In this exercise you ran your first containers using `docker container run`, and how they are running commands inside the containers. You also learned to how to list your containers, and how to kill the containers using the command `docker container rm`. In you run into trouble, you've learned that the `--help` option can provide you with some ideas that could help get you answers.
