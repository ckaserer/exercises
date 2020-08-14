# Creating Images with Dockerfiles (1/2)

By the end of this exercise, you should be able to:

 - Write a Dockerfile using the `FROM` and `RUN` commands
 - Build an image from a Dockerfile
 - Anticipate which image layers will be fetched from the cache at build time
 - Fetch build history for an image
 
## Writing and Building a Dockerfile

1.  Create a folder called `myimage`, and a text file called `Dockerfile` within that folder. In `Dockerfile`, include the following instructions:

    ```dockerfile
    FROM centos:7

    RUN yum update -y
    RUN yum install -y wget
    ```

    This serves as a recipe for an image based on `centos:7`, that has all its default packages updated and `wget` installed on top.

2.  Build your image with the `build` command. Don't miss the `.` at the end; that's the path to your `Dockerfile`. Since we're currently in the directory `myimage` which contains it, the path is just `.` (here).

    ```bash
    [centos@node-0 myimage]$ docker image build -t myimage .
    ```

    You'll see a long build output - we'll go through the meaning of this output in a demo later. For now, your image creation was successful if the output ends with `Successfully tagged myimage:latest`.

3.  Verify that your new image exists with `docker image ls`, then use your new image to run a container and `wget` something from within that container, just to confirm that everything worked as expected:

    ```bash
    [centos@node-0 myimage]$ docker container run -it myimage bash
    [root@1d86d4093cce /]# wget example.com
    [root@1d86d4093cce /]# cat index.html
    [root@1d86d4093cce /]# exit
    ```

    You should see the HTML from example.com, downloaded by `wget` from within your container.    

4.  It's also possible to pipe a Dockerfile in from STDIN; try rebuilding your image with the following:

    ```bash
    [centos@node-0 myimage]$ cat Dockerfile | docker image build -t myimage -f - .
    ```

    (This is useful when reading a Dockerfile from a remote location with `curl`, for example).

## Using the Build Cache

In the previous step, the second time you built your image should have completed immediately, with each step except the first reporting `using cache`. Cached build steps will be used until a change in the Dockerfile is found by the builder.

1.  Open your Dockerfile and add another `RUN` step at the end to install `vim`:

    ```dockerfile
    FROM centos:7

    RUN yum update -y
    RUN yum install -y wget
    RUN yum install -y vim
    ```

2.  Build the image again as before; which steps is the cache used for?

3.  Build the image again; which steps use the cache this time?

4.  Swap the order of the two `RUN` commands for installing `wget` and `vim` in the Dockerfile:

    ```dockerfile
    FROM centos:7

    RUN yum update -y
    RUN yum install -y vim
    RUN yum install -y wget
    ```

    Build one last time. Which steps are cached this time?

## Using the `history` Command

1.  The `docker image history` command allows us to inspect the build cache history of an image. Try it with your new image:

    ```bash
    [centos@node-0 myimage]$ docker image history myimage:latest

    IMAGE          CREATED          CREATED BY                                      SIZE      
    f2e85c162453   8 seconds ago    /bin/sh -c yum install -y wget                  87.2MB              
    93385ea67464   12 seconds ago   /bin/sh -c yum install -y vim                   142MB               
    27ad488e6b79   3 minutes ago    /bin/sh -c yum update -y                        86.5MB              
    5182e96772bf   44 hours ago     /bin/sh -c #(nop)  CMD ["/bin/bash"]            0B                  
    <missing>      44 hours ago     /bin/sh -c #(nop)  LABEL org.label-schema....   0B                  
    <missing>      44 hours ago     /bin/sh -c #(nop) ADD file:6340c690b08865d...   200MB 
    ```

    Note the image id of the layer built for the `yum update` command.

2.  Replace the two `RUN` commands that installed `wget` and `vim` with a single command:

    ```bash
    ...
    RUN yum install -y wget vim
    ```

3.  Build the image again, and run `docker image history` on this new image. How has the history changed?

## Conclusion

In this exercise, we've seen how to write a basic Dockerfile using `FROM` and `RUN` commands, some basics of how image caching works, and seen the `docker image history` command. Using the build cache effectively is crucial for images that involve lengthy compile or download steps. In general, moving commands that change frequently as late as possible in the Dockerfile will minimize build times. We'll see some more specific advice on this later in this lesson.
