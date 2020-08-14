# Interactive Image Creation

By the end of this exercise, you should be able to:

 - Capture a container's filesystem state as a new docker image
 - Read and understand the output of `docker container diff`

## Modifying a Container

1.  Start a bash terminal in a CentOS container:

    ```bash
    [centos@node-0 ~]$ docker container run -it centos:7 bash
    ```

2.  Install a couple pieces of software in this container - there's nothing special about `wget`, any changes to the filesystem will do. Afterwards, exit the container:

    ```bash
    [root@dfe86ed42be9 /]# yum install -y which wget
    [root@dfe86ed42be9 /]# exit
    ```

3.  Finally, try `docker container diff` to see what's changed about a container relative to its image; you'll need to get the container ID via `docker container ls -a` first:

    ```bash
    [centos@node-0 ~]$ docker container ls -a
    [centos@node-0 ~]$ docker container diff <container ID>

    C /root
    A /root/.bash_history
    C /usr
    C /usr/bin
    A /usr/bin/gsoelim
    ...
    ```

    Those `C`s at the beginning of each line stand for files `C`hanged, and `A` for `A`dded; lines that start with `D` indicate `D`eletions.

## Capturing Container State as an Image

1.  Installing `which` and `wget` in the last step wrote information to the container's read/write layer; now let's save that read/write layer as a new read-only image layer in order to create a new image that reflects our additions, via the `docker container commit`:

    ```bash
    [centos@node-0 ~]$ docker container commit <container ID> myapp:1.0
    ```

2.  Check that you can see your new image by listing all your images:

    ```bash
    [centos@node-0 ~]$ docker image ls

    REPOSITORY  TAG   IMAGE ID       CREATED         SIZE
    myapp       1.0   34f97e0b087b   8 seconds ago   300MB
    centos      7     5182e96772bf   44 hours ago    200MB
    ```

3.  Create a container running bash using your new image, and check that which and wget are installed:

    ```bash
    [centos@node-0 ~]$ docker container run -it myapp:1.0 bash
    [root@2ecb80c76853 /]# which wget
    ```

    The `which` commands should show the path to the specified executable, indicating they have been installed in the image. Exit your container when done by typing `exit`.

## Conclusion

In this exercise, you saw how to inspect the contents of a container's read / write layer with `docker container diff`, and commit those changes to a new image layer with `docker container commit`. Committing a container as an image in this fashion can be useful when developing an environment inside a container, when you want to capture that environment for reproduction elsewhere.
