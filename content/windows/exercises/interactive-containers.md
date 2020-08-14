# Interactive Containers

By the end of this exercise, you should be able to:

- Launch an interactive shell in a new or existing container
- Run a child process inside a running container
- List containers using more options and filters

## Writing to Containers

1.  Create a container using the `mcr.microsoft.com/powershell:preview-nanoserver-1809` image, and connect to its powershell shell in interactive mode using the `-i` flag (also the `-t` flag, to request a TTY connection):

    ```powershell
    PS: node-0 Administrator> docker container run `
        -it  mcr.microsoft.com/powershell:preview-nanoserver-1809
    ```

2.  Explore your container's filesystem with `ls`, and then create a new file:

    ```powershell
    PS C:\> ls
    PS C:\> cd .\Users\Public
    PS C:\Users\Public> echo 'hello world' > test.txt
    PS C:\Users\Public> ls
    PS C:\Users\Public> type .\test.txt
    ```

3.  Exit the connection to the container:

    ```powershell
    PS C:Users\Public\> exit
    ```

4.  Run the same command as above to start a container in the same way:

    ```powershell
    PS: node-0 Administrator> docker container run `
        -it mcr.microsoft.com/powershell:preview-nanoserver-1809
    ```

5.  Try finding your `test.txt` file inside this new container; it is nowhere to be found. Exit this container for now in the same way you did above.

## Reconnecting to Containers

1.  We'd like to recover the information written to our container in the first example, but starting a new container didn't get us there; instead, we need to restart our original container, and reconnect to it. List all your stopped containers:

    ```powershell
    PS: node-0 Administrator> docker container ls --all

    CONTAINER ID  IMAGE                    COMMAND       CREATED                            
    041379c4f254  preview-nanoserver-1809  "pwsh.exe"  About a minute ago 
    d5b9286194f9  preview-nanoserver-1809  "pwsh.exe"  2 minutes ago       
    ```

2.  We can restart a container via the container ID listed in the first column. Use the container ID for the first `nanoserver`  container you created with `powershell` as its command (see the `CREATED` column above to make sure you're choosing the *first* powershell container you ran):

    ```powershell
    PS: node-0 Administrator> docker container start <container ID>
    PS: node-0 Administrator> docker container ls

    CONTAINER ID  IMAGE                    COMMAND       CREATED        STATUS
    d5b9286194f9  preview-nanoserver-1809  "pwsh.exe"  3 minutes ago  Up 2 seconds
    ```

    Your container status has changed from `Exited` to `Up`, via `docker container start`.

3.  Now that your container is running again, launch a powershell process as a child process inside the container:

    ```powershell
    PS: node-0 Administrator> docker container exec -it <container ID> pwsh.exe
    ```

4.  List the contents of the container's filesystem again with `ls`; your `test.txt` should be where you left it. Double check that its content is what you expect: 
    
    ```powershell
    PS C:\> cd .\Users\Public
    PS C:\Users\Public> ls
    ```

6.  Exit the container again by typing `exit`.

## Using Container Listing Options

1.  In the last step, we saw how to get the short container ID of all our containers using `docker container ls -a`. Try adding the `--no-trunc` flag to see the entire container ID:

    ```powershell
    PS: node-0 Administrator> docker container ls -a --no-trunc 
    ```

    This long ID is the same as the string that is returned after starting a container with `docker container run`.

2.  List only the container ID using the `-q` flag:

    ```powershell
    PS: node-0 Administrator> docker container ls -a -q
    ```

3.  List the last container to have been created using the `-l` flag:

    ```powershell
    PS: node-0 Administrator> docker container ls -l
    ```

4.  Finally, you can also filter results with the `--filter` flag; for example, try filtering by exit code:

    ```powershell
    PS: node-0 Administrator> docker container ls -a --filter "exited=0"
    ```
    
    The output of this command will list the containers that have exited successfully.

5.  Clean up with:

    ```powershell
    PS: node-0 Administrator> docker container rm -f $(docker container ls -aq)
    ```
    
## Conclusion

In this demo, you saw that files added to a container's filesystem do not get added to all containers created from the same image; changes to a container's filesystem are local to itself, and exist only in that particular container. You also learned how to restart a stopped Docker container using `docker container start`, how to run a command in a running container using `docker container exec`, and also saw some more options for listing containers via `docker container ls`.
