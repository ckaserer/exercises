# Instructor Demo: Creating Images

In this demo, we'll illustrate:

 - How to read each step of the image build output
 - How intermediate image layers behave in the cache and as independent images
 - What the meanings of 'dangling' and `<missing>` image layers are

## Understanding Image Build Output

1.  Make a folder `demo` for our image demo:
    
    ```powershell
    PS: node-0 Administrator> mkdir demo ; cd demo
    ```

    In this folder, create a `Dockerfile`:

    ```powershell
    FROM mcr.microsoft.com/windows/servercore:10.0.17763.805
    SHELL ["powershell", "-Command"]
    RUN iex (invoke-webrequest https://chocolatey.org/install.ps1 -UseBasicParsing)
    RUN choco install -y which
    RUN choco install -y wget
    RUN choco install -y vim
    ```

2.  Build the image from the `Dockerfile`:

    ```powershell
    PS: node-0 demo> docker image build -t demo .
    ```

3.  Examine the output from the build process. The very first line looks like:

    ```powershell
    Sending build context to Docker daemon  2.048kB
    ```

    Here the Docker daemon is archiving everything at the path specified in the `docker image build command` (`.` or the current directory in this example). This is why we made a fresh directory `demo` to build in, so that nothing extra is included in this process.

4.  The next two lines look like this:

    ```powershell
    Step 1/6 : FROM mcr.microsoft.com/windows/servercore:10.0.17763.805
     ---> 42277f7f55c3
    ```

    Do a `docker image ls`:

    ```powershell
    REPOSITORY                    TAG      IMAGE ID       CREATED        SIZE
    demo                          latest   889ea81f9564   13 hours ago   11GB
    servercore:10.0.17763.805     latest   42277f7f55c3   6 days ago     4.79GB
    ```

    Notice the Image ID for `mcr.microsoft.com/windows/servercore:10.0.17763.805` matches that second line in the build output. The build starts from the base image defined in the `FROM` command.

5.  The next few lines look like:

    ```powershell
    Step 2/6 : SHELL powershell -Command
    ---> Running in c84a289effac
    ```

    This is the output of the `SHELL` command, `powershell -Command`. The line `Running in c84a289effac` specifies a container that this command is running in, which is spun up based on all previous image layers (just the `mcr.microsoft.com/windows/servercore:10.0.17763.805` base at the moment). Scroll down a bit and you should see something like:

    ```powershell
    ---> e573fdd8f035
    Removing intermediate container c84a289effac
    ```

    At the end of this first `SHELL` command, the temporary container `c84a289effac` is saved as an image layer `e573fdd8f035`, and the container is removed. This is the exact same process as when you used `docker container commit` to save a container as a new image layer, but now running automatically as part of a Dockerfile build.

6.  Look at the history of your image:

    ```powershell
    docker image history demo

    IMAGE         CREATED        CREATED BY                             SIZE   
    10598cb26c8e  2 minutes ago  powershell choco install -y vim        141MB
    4a746a1f589f  3 minutes ago  powershell choco install -y wget       31.9MB
    e6af1aae39ef  3 minutes ago  powershell choco install -y which      6.7MB
    1f167ec4ff77  2 weeks ago    powershell iex (invoke-webrequest h…   59.6MB
    e883ed43fca2  2 weeks ago    powershell #(nop)  SHELL [powershel…   41kB
    42277f7f55c3  3 weeks ago    Install update 10.0.17763.805-amd64    1.32GB
    <missing>     13 months ago  Apply image 10.0.17763.1-amd64         3.47GB
    ```

    As you can see, the different layers of `demo` correspond to a separate line in the Dockerfile and the layers have their own ID. You can see the image layer `e573fdd8f035` committed in the second build step in the list of layers for this image.

7.  Look through your build output for where steps 3/6 (installing chocolatey), 4/6 (installing which), 5/6 (installing wget), and 6/6 (installing vim) occur - the same behavior of starting a temporary container based on the previous image layers, running the RUN command, saving the container as a new image layer visible in your docker iamge history output, and deleting the temporary container is visible.

8.  Every layer can be used as you would use any image, which means we can inspect a single layer. Let's inspect the `wget` layer, which in my case is `4a746a1f589f` (yours will be different, look at your `docker image history` output):

    ```powershell
    PS: node-0 demo> docker image inspect <layer ID>
    ```

9.  Let's look for the command associated with this image layer by using `--format`:

    ```bash
    PS: node-0 demo> docker image inspect --format='{{.ContainerConfig.Cmd}}' <layer ID>

    [powershell -Command choco install -y wget]
    ```

10.  We can even start containers based on intermediate image layers; start an interactive container based on the `wget` layer, and look for whether `wget` and `vim` are installed:

    ```powershell
    PS: node-0 demo> docker container run -it <layer ID> powershell
    PS C:\> which wget
    C:\ProgramData\chocolatey\bin\wget.exe

    PS C:\> which vim
    Not found
    ```

    `wget` is installed in this layer, but since `vim` didn't arrive until the next layer, it's not available here.

##  Managing Image Layers

1.  Change the last line in the `Dockerfile` from the last section to install `nano` instead of `vim`:

    ```powershell
    FROM mcr.microsoft.com/windows/servercore:10.0.17763.805
    SHELL ["powershell", "-Command"]
    RUN iex (invoke-webrequest https://chocolatey.org/install.ps1 -UseBasicParsing)
    RUN choco install -y which
    RUN choco install -y wget
    RUN choco install -y nano
    ```

2.  Rebuild your image, and list your images again:

    ```powershell
    PS: node-0 demo> docker image build -t demo .
    PS: node-0 demo> docker image ls

    REPOSITORY  TAG             IMAGE ID       CREATED         SIZE
    demo        latest          d405556fb8ad   6 seconds ago   4.91GB
    <none>      <none>          10598cb26c8e   7 minutes ago   5.03GB
    servercore  10.0.17763.805  42277f7f55c3   3 weeks ago     4.79GB
    ```

    What is that image named `<none>`? Notice the image ID is the same as the old image ID for `demo:latest` (see your history output above). The name and tag of an image is just a pointer to the stack of layers that make it up; reuse a name and tag, and you are effectively moving that pointer to a new stack of layers, leaving the old one (the one containing the `vim` install in this case) as an untagged or 'dangling' image.

3.  Rewrite your `Dockerfile` one more time, to combine some of those install steps:

    ```powershell
    FROM mcr.microsoft.com/windows/servercore:10.0.17763.805
    SHELL ["powershell", "-Command"]
    RUN iex (invoke-webrequest https://chocolatey.org/install.ps1 -UseBasicParsing)
    RUN choco install -y which wget nano
    ```

    Rebuild using a `new` tag this time, and use `docker image inspect` to pull out the size of both this and your previous image, tagged `latest`:

    ```powershell
    PS: node-0 demo> docker image build -t demo:new .

    PS: node-0 demo> docker image inspect --format '{{json .Size}}' demo:latest
    4906923551
    PS: node-0 demo> docker image inspect --format '{{json .Size}}' demo:new
    4892480752
    ```

    Image `demo:new` is smaller in size than `demo:latest`, even though it contains the exact same software - why?

##  Conclusion

In this demo, we explored the layered structure of images; each layer is built as a distinct image and can be treated as such, on the host where it was built. This information is preserved on the build host for use in the build cache; build another image based on the same lower layers, and they will be reused to speed up the build process. Notice that the same is not true of downloaded images like `mcr.microsoft.com/windows/servercore:10.0.17763.805`; intermediate image caches are not downloaded, but rather only the final complete image.
