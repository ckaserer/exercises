#  Instructor Demo: Process Isolation

In this demo, we'll illustrate:

 - What containerized process IDs look like inside versus outside of a namespace
 - How to impose resource limitations on CPU and memory consumption of a containerized process

##  Exploring the PID Namespace

1.  Start a simple container we can explore:

    ```powershell
    PS: node-0 Administrator> docker container run -d --name pinger `
        mcr.microsoft.com/powershell:preview-windowsservercore-1809 ping -t 8.8.8.8
    ```

2.  Launch a child process inside this container to display all the processes running inside it:

    ```powershell
    PS: node-0 Administrator> docker container exec pinger powershell Get-Process

    Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
    -------  ------    -----      -----     ------     --  -- -----------
        120       6     1220       4796       0.02    432   3 CExecSvc
         79       5      920       3632       0.00   6244   3 CompatTelRunner
        151      10     6836      12528       0.02   5408   3 conhost
        222      11     2072       4988       0.11   7076   3 csrss
         49       6     1004       3276       0.02   5540   3 fontdrvhost
          0       0       56          8                 0   0 Idle
        777      22     4340      12820       0.11   7276   3 lsass
         68       6      884       3240       0.02   7452   3 PING
        506      34    66768      73244       3.23   6824   3 powershell
        219      12     2796       6272       0.14   6480   3 services
         50       4      536       1208       0.11    568   0 smss
        767      28     6540      18568       0.20   1496   3 svchost
        396      16     7560      13700       0.09   3376   3 svchost
        485      21     7928      19780       0.27   3668   3 svchost
        188      15     3052       8880       0.06   4272   3 svchost
        348      14     2896       9848       0.06   4588   3 svchost
        144       9     1764       6364       0.05   5832   3 svchost
        123       7     1344       5716       0.02   6784   3 svchost
        482      35     5692      17820       1.81   7004   3 svchost
        309      16     2592       8132       0.08   7620   3 svchost
       2981       0      196        152      39.72      4   0 System
        188      12     2020       7136       0.05   6208   3 wininit
    ```

    In Windows containers, a whole set of system processes need to run in order for the intended application process to be executed successfully. Just like a regular Windows process list, we see the root `Idle` process at PID 0, and the `System` process at PID 4.

    Another way to achieve a similar result is to use `container top`:

    ```powershell
    PS: node-0 Administrator> docker container top pinger

    Name                  PID                 CPU                 Private Working Set
    smss.exe              568                 00:00:00.109        286.7kB
    csrss.exe             7076                00:00:00.109        1.106MB
    wininit.exe           6208                00:00:00.046        1.204MB
    services.exe          6480                00:00:00.140        1.602MB
    lsass.exe             7276                00:00:00.109        3.453MB
    svchost.exe           4588                00:00:00.062        2.109MB
    fontdrvhost.exe       5540                00:00:00.015        548.9kB
    svchost.exe           7620                00:00:00.078        2.015MB
    svchost.exe           1496                00:00:00.218        5.173MB
    svchost.exe           4272                00:00:00.062        2.417MB
    CExecSvc.exe          432                 00:00:00.031        860.2kB
    svchost.exe           3376                00:00:00.093        5.62MB
    PING.EXE              7452                00:00:00.015        548.9kB
    svchost.exe           7004                00:00:01.812        4.092MB
    svchost.exe           6784                00:00:00.015        876.5kB
    svchost.exe           3668                00:00:00.265        6.513MB
    svchost.exe           5832                00:00:00.046        1.11MB
    CompatTelRunner.exe   6244                00:00:00.000        589.8kB
    conhost.exe           5408                00:00:00.015        6.304MB
    ```

3.  Run `Get-Process` directly on your host. The ping process is visible there, but so are all the other processes on this machine; the container's namespaces isolated what `Get-Process` returns when executed as a child process within the container.

4.  List your containers to show that the `pinger` container is still running:

    ```powershell
    PS: node-0 Administrator> docker container ls
    ```

    Kill the ping process by host PID, confirm with `Y` to stop the process, and show the container has stopped:

    ```powershell
    PS: node-0 Administrator>Stop-Process -Id [PID of ping]
    PS: node-0 Administrator>docker container ls

    CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES
    ```

    Killing the ping process on the host also kills the container. Note using `Stop-Process` is just for demonstration purposes here; never stop containers this way.

##  Imposing Resource Limitations

1.  Open the Task Manager, either through the search bar or by typing `taskmgr` in the command prompt. Then click **More Details** in the task manager to get a live report of resource consumption.

2.  Start a container designed to simulate cpu and memory load:

    ```powershell
    PS: node-0 Administrator> docker container run -it training/winstress:ws19 pwsh.exe
    ```

3.  Execute a script inside your container to allocate memory as fast as possible:

    ```powershell
    PS C:\> .\saturate-mem.ps1
    ```

    You should see the `Memory` column on the Task Manager increase quickly, even turning red after a while. Then, this error message should be thrown (CTRL+c to break the loop):
    
    ```powershell
    Exception of type 'System.OutOfMemoryException' was thrown.
    At C:\saturate-mem.ps1:2 char:37
    + ...  -lt 100000; $i++) { $mem_stress += ("a" * 1023MB) + ("b" * 1023MB) }
    +                          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        + CategoryInfo          : OperationStopped: (:) [], OutOfMemoryException
        + FullyQualifiedErrorId : System.OutOfMemoryException
    ```

    Note this may even disrupt your RDP connection to your VM - failing to constrain resource consumption can be catastrophic.

4.  `CTRL+C` to kill this memory-saturating process. Then, exit and remove the container to release the allocated memory:

    ```powershell
    PS: node-0 Administrator>docker container rm -f <container ID>
    ```

    Immediately, the memory in the Task Manager should drop.

5.  Now, let's start a container with a memory limit:

    ```powershell
    PS: node-0 Administrator> docker container run `
        -it -m 4096mb training/winstress:ws19 pwsh.exe
    ```

6.  Run the same script to generate memory pressure:

    ```powershell
    PS C:\> .\saturate-mem.ps1
    ```

    While the memory does increase in the Task Manager, allocations get cut off before the system memory is completely consumed. `CTRL+C` to kill the process, and exit the container again.

7.  Remove this container.

    ```powershell
    PS: node-0 Administrator>docker container rm -f <container ID>
    ```

## Conclusion

In this demo, we explored some of the most important technologies that make containerization possible: namespaces and control groups. The core message here is that containerized processes are just processes running on their host, isolated and constrained by these technologies. All the tools and management strategies you would use for conventional processes apply just as well for containerized processes.
