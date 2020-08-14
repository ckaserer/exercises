# Inspection Commands

By the end of this exercise, you should be able to:

 - Gather system level info from the docker engine
 - Consume and format the docker engine's event stream for monitoring purposes

## Inspecting System Information

1.  We can find the `info` command under `system`. Execute:

    ```powershell
    PS: node-0 Administrator> docker system info
    ```

2.  From the output of the last command, identify:

    - how many images are cached on your machine?
    - how many containers are running or stopped?
    - what kernel version of Windows are you running?
    - whether Docker is running in swarm mode?

## Monitoring System Events

1.  There is another powerful system command that allows us to monitor what's happening on the Docker host. Execute the following command:

    ```powershell
    PS: node-0 Administrator> docker system events
    ```

    Please note that it looks like the system is hanging, but that is not the case. The system is just waiting for some events to happen.

2.  Open a second powershell window and execute the following command:

    ```powershell
    PS: node-0 Administrator> docker container run --rm `
           mcr.microsoft.com/windows/nanoserver:10.0.17763.737 `
           ping 8.8.8.8
    ```

    and observe the generated output in the first terminal. It should look similar to this:

    ```powershell
    2019-10-31T14:57:42.365968600Z container create fa55...
    2019-10-31T14:57:42.372964200Z container attach fa55...
    2019-10-31T14:57:42.467961900Z network connect a7c2...
    2019-10-31T14:57:42.931061900Z container start fa55...
    2019-10-31T14:57:46.237482500Z container die fa55...
    2019-10-31T14:57:46.262481400Z network disconnect a7c2...
    2019-10-31T14:57:46.335474200Z container destroy fa55...
    ```

3.  If you don't like the format of the output then we can use the `--format` parameter to define our own format in the form of a [Go template](https://golang.org/pkg/text/template/). Stop the events watch on your first terminal with `CTRL+C`, and try this:

    ```powershell
    PS: node-0 Administrator> docker system events --format '--> {{.Type}}-{{.Action}}'
    ```

    now the output looks a little bit less cluttered when we rerun our nanoserver container on the second terminal as above.

4.  Finally we can find out what the event structure looks like by outputting the events in `json` format (once again after killing the events watcher on the first terminal and restarting it with):

    ```powershell
    PS: node-0 Administrator> docker events --format '{{json .}}'
    ```

    which should give us for the first event in the series after re-running our nanoserver container something like this (note, the output has been prettyfied for readability):

    ```json
    {
    "status": "create",
    "id": "3a8d28972026945ca27727e48bcbc66ae7539ecbe0a85d3c3d82d4c34463954f",
    "from": "mcr.microsoft.com/windows/nanoserver:10.0.14393.2551",
    "Type": "container",
    "Action": "create",
    "Actor": {
        "ID": "3a8d28972026945ca27727e48bcbc66ae7539ecbe0a85d3c3d82d4c34463954f",
        "Attributes": {
        "image": "mcr.microsoft.com/windows/nanoserver:10.0.14393.2551",
        "name": "festive_engelbart"
        }
    },
    "scope": "local",
    "time": 1502850178,
    "timeNano": 1502850178980991200
    }
    ```

## Conclusion

In this exercise we have learned how to inspect system wide properties of our Docker host by using the `docker system info` command; this is one of the first places to look for general config information to include in a bug report. We also saw a simple example of `docker system events`; the events stream is one of the primary sources of information that should be logged and monitored when running Docker in production. Many commercial as well as open source products (such as Elastic Stack) exist to facilitate aggregating and mining these streams at scale.
