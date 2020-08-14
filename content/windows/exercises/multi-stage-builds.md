# Multi-Stage Builds

By the end of this exercise, you should be able to:

- Write a Dockerfile that describes multiple images, which can copy files from one image to the next.

## Defining a multi-stage build

1.  Make a fresh folder `multi-stage` to do this exercise in, and `cd` into it.

2.  Add a file `hello.go` to the `multi-stage` folder containing **Hello World** in Go:

    ```go
    package main
    
    import "fmt"

    func main() {
        fmt.Println("hello world")
    }
    ```

3.  Now let's Dockerize our hello world application. Add a `Dockerfile` to the `multi-stage` folder with this content:

    ```dockerfile
    FROM golang:1.12.5-windowsservercore
    COPY . /code
    WORKDIR /code
    RUN go build hello.go
    CMD ["\\code\\hello.exe"]
    ```

4.  Build the image and observe its size:

    ```powershell
    PS: node-0 multi-stage> docker image build -t my-app-large .
    PS: node-0 multi-stage> docker image ls | select-string my-app-large

    REPOSITORY     TAG      IMAGE ID      CREATED         SIZE
    my-app-large   latest   7c95f4e0112e  11 minutes ago  5.86GB
    ```

5.  Test the image to confirm it actually works:

    ```powershell
    PS: node-0 multi-stage> docker container run my-app-large
    ```

    It should print "hello world" in the console.

6.  Update your Dockerfile to use an `AS` clause on the first line, and add a second stanza describing a second build stage:

    ```dockerfile
    FROM golang:1.12.5-windowsservercore AS gobuild
    COPY . /code
    WORKDIR /code
    RUN go build hello.go

    FROM mcr.microsoft.com/windows/nanoserver:10.0.17763.737
    COPY --from=gobuild /code/hello.exe /hello.exe
    CMD ["\\hello.exe"]
    ```

7.  Build the image again, test it and compare the size with the previous version:

    ```powershell
    PS: node-0 multi-stage> docker image build -t my-app-small .
    PS: node-0 multi-stage> docker image ls | select-string 'my-app-'

    REPOSITORY     TAG      IMAGE ID      CREATED         SIZE
    my-app-small   latest   13a42c43f45f  11 minutes ago  253MB
    my-app-large   latest   7c95f4e0112e  13 minutes ago  5.86GB
    ```

    As expected, the size of the multi-stage build is much smaller than the large one since it does not contain the .NET SDK.

8.  Finally, make sure the app actually works:

    ```powershell
    PS: node-0 multi-stage> docker container run my-app-small
    ```

    You should get the expected 'hello world' output from the container with just the required executable.

## Building Intermediate Images

In the previous step, we took our compiled executable from the first build stage, but that image wasn't tagged as a regular image we can use to start containers with; only the final `FROM` statement generated a tagged image. In this step, we'll see how to persist whichever build stage we like.

1.  Build an image from the `build` stage in your Dockerfile using the `--target` flag:

    ```powershell
    PS: node-0 multi-stage> docker image build -t my-build-stage --target gobuild .
    ```

2.  Run a container from this image and make sure it yields the expected result:

    ```powershell
    PS: node-0 multi-stage> docker container run -it --rm my-build-stage hello.exe
    ```

3.  List your images again to see the size of `my-build-stage` compared to the small version of the app.

## Conclusion

In this exercise, you created a Dockerfile defining multiple build stages. Being able to take artifacts like compiled binaries from one image and insert them into another allows you to create very lightweight images that do not include developer tools or other unnecessary components in your production-ready images, just like how you currently probably have separate build and run environments for your software. This will result in containers that start faster, and are less vulnerable to attack.
