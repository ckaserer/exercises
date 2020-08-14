# Creating Images with Dockerfiles (2/2)

By the end of this exercise, you should be able to:

 - Define a default process for an image to containerize by using the `ENTRYPOINT` or `CMD` Dockerfile commands
 - Understand the differences and interactions between `ENTRYPOINT` and `CMD` 

## Setting Default Commands

1.  Add the following line to your Dockerfile from the last problem, at the bottom:

    ```dockerfile
    ...
    CMD ["ping", "127.0.0.1", "-n", "5"]
    ```

    This sets `ping` as the default command to run in a container created from this image, and also sets some parameters for that command. 

2.  Rebuild your image:

    ```powershell
    PS: node-0 myimage> docker image build -t myimage .
    ```

3.  Run a container from your new image with no command provided:

    ```powershell
    PS: node-0 myimage> docker container run myimage
    ```

    You should see the command provided by the `CMD` parameter in the Dockerfile running.

4.  Try explicitly providing a command when running a container:

    ```powershell
    PS: node-0 myimage> docker container run myimage powershell write-host "hello world"
    ```

    Providing a command in `docker container run` overrides the command defined by `CMD`.

5.  Replace the `CMD` instruction in your Dockerfile with an `ENTRYPOINT`:

    ```dockerfile
    ...
    ENTRYPOINT ["ping"]
    ```

6.  Build the image and use it to run a container with no process arguments:

    ```powershell
    PS: node-0 myimage> docker image build -t myimage .
    PS: node-0 myimage> docker container run myimage
    ```

    You'll get an error. What went wrong? 

7.  Try running with an argument after the image name:

    ```powershell
    PS: node-0 myimage> docker container run myimage 127.0.0.1
    ```

    Tokens provided after an image name are sent as arguments to the command specified by `ENTRYPOINT`.

## Combining Default Commands and Options

1.  Open your Dockerfile and modify the `ENTRYPOINT` instruction to include 2 arguments for the ping command:

    ```dockerfile
    ...
    ENTRYPOINT ["ping", "-n", "3"]
    ```

2.  If `CMD` and `ENTRYPOINT` are both specified in a Dockerfile, tokens listed in `CMD` are used as default parameters for the `ENTRYPOINT` command. Add a `CMD` with a default IP to ping:

    ```dockerfile
    ...
    CMD ["127.0.0.1"]
    ```

3.  Build the image and run a container with the defaults:

    ```bash
    PS: node-0 myimage> docker image build -t myimage .
    PS: node-0 myimage> docker container run myimage
    ```

    You should see it pinging the default IP, `127.0.0.1`.

4.  Run another container with a custom IP argument:

    ```bash
    PS: node-0 myimage> docker container run myimage 8.8.8.8
    ```

    This time, you should see a ping to `8.8.8.8`. Explain the difference in behavior between these two last containers.

## Conclusion

In this exercise, we encountered the Dockerfile commands `CMD` and `ENTRYPOINT`. These are useful for defining the default process to run inside the container right in the Dockerfile, making our containers more like executables and adding clarity to exactly what process was meant to run in a given image's containers.
