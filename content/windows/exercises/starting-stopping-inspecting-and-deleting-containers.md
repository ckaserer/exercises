# Starting, Stopping, Inspecting and Deleting Containers

By the end of this exercise, you should be able to:

- Restart containers which have exited
- Distinguish between stopping and killing a container
- Fetch container metadata using `docker container inspect`
- Delete containers

## Starting and Restarting Containers

1.  Start by running a IIS web server in the background, and check that it's really running:

    ```powershell
    PS: node-0 Administrator> docker container run -d `
        --name demo mcr.microsoft.com/windows/nanoserver:10.0.17763.737 ping 8.8.8.8 -t
    PS: node-0 Administrator> docker container ls
    ```

    Note how we called the container `demo` for easier identification later on.
    
2.  Stop the container using `docker container stop`, and check that the container is indeed stopped:

    ```powershell
    PS: node-0 Administrator> docker container stop demo
    PS: node-0 Administrator> docker container ls -a
    ```

## Inspecting a Container

1.  Start your `demo` container again, then inspect the container details using `docker container inspect`:

    ```powershell
    PS: node-0 Administrator> docker container start demo
    PS: node-0 Administrator> docker container inspect demo
    ```

    You get a JSON object describing the container's config, metadata and state.

2.  Find the container's IP and long ID in the JSON output of `inspect`. If you know the key name of the property you're looking for, try piping to `select-string`:

    ```powershell
    PS: node-0 Administrator> docker container inspect demo | select-string IPAddress
    ```
    
    The output should look similar to this:

    ```powershell
    "SecondaryIPAddresses": null,
    "IPAddress": "",
            "IPAddress": "172.20.137.22",
    ```
    
3.  Now try to use `select-string` for `Cmd`, the main process being run by this container. `select-string`'s simple text search doesn't always return helpful results:

    ```powershell
    PS: node-0 Administrator> docker container inspect demo | select-string Cmd

    "Cmd": [
    ```

4.  A more powerful way to filter this JSON is with the `--format` flag. Syntax follows Go's text/template package: [http://golang.org/pkg/text/template/](http://golang.org/pkg/text/template/). For example, to find the `Cmd` value we tried to `select-string` for above, instead try:

    ```powershell
    PS: node-0 Administrator> docker container inspect --format='{{.Config.Cmd}}' demo

    [ping 8.8.8.8 -t]
    ```

    This time, we get a the value of the `Config.Cmd` key from the `inspect` JSON.

5.  Keys nested in the JSON returned by `docker container inspect` can be chained together in this fashion. Try modifying this example to return the IP address you selected previously.

6.  Finally, we can extract all the key/value pairs for a given object using the `json` function:

    ```powershell
    PS: node-0 Administrator> docker container inspect --format='{{json .Config}}' demo
    ```

    Try adding `| jq` to this command to get the same output a little bit easier to read.

## Deleting Containers

1.  Start three containers in background mode, then stop the first one.

2.  List only exited containers using the `--filter` flag we learned earlier, and the option `status=exited`.

3.  Delete the container you stopped above with `docker container rm`, and do the same listing operation as above to confirm that it has been removed:

    ```powershell
    PS: node-0 Administrator> docker container rm <container ID>
    PS: node-0 Administrator> docker container ls
    ```

4.  Now do the same to one of the containers that's still running; notice `docker container rm` won't delete a container that's still running, unless we pass it the force flag `-f`. Delete the second container you started above:

    ```powershell
    PS: node-0 Administrator> docker container rm -f <container ID>
    ```

5.  Try using the `docker container ls` flags we learned previously to remove the last container that was run, or all stopped containers. Recall that you can pass the output of one shell command `cmd-A` into a variable of another command `cmd-B` with syntax like `cmd-B $(cmd-A)`.

## Conclusion

In this exercise, you saw the basics of managing the container lifecycle. Containers can be restarted when stopped, and are only truly gone once they've been removed.

Also keep in mind the `docker container inspect` command we saw, for examining container metadata, state and config; this is often the first place to look when trying to troubleshoot a failed container.
