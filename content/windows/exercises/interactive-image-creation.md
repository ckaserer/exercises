# Interactive Image Creation

By the end of this exercise, you should be able to:

 - Capture a container's filesystem state as a new docker image
 - Read and understand the output of `docker container diff`

## Modifying a Container

1.  Start a Powershell terminal in a Windows Server Core container:

    ```powershell
    PS: node-0 Administrator> docker container run `
        -it --name demo mcr.microsoft.com/powershell:preview-windowsservercore-1809
    ```

2.  Install a couple pieces of software in this container - First install a package manager; in this case **Chocolatey**:

    ```powershell
    PS C:\> iex (iwr https://chocolatey.org/install.ps1 -UseBasicParsing)
    ```

    Then install some packages. There's nothing special about `wget`, any changes to the filesystem will do. Afterwards, exit the container:

    ```powershell
    PS C:\> choco install -y wget
    PS C:\> exit
    ```

3.  Finally, try `docker container diff` to see what's changed about a container relative to its image:

    ```powershell
    PS: node-0 Administrator> docker container diff demo

    C Files
    C Files/Documents and Settings
    C Files/Program Files (x86)
    ...
    ```

    Those `C`s at the beginning of each line stand for files `C`hanged; lines that start with `D` indicate `D`eletions.

## Capturing Container State as an Image

1.  Installing wget in the last step wrote information to the container's read/write layer; now let's save that read/write layer as a new read-only image layer in order to create a new image that reflects our additions, via the `docker container commit`:

    ```powershell
    PS: node-0 Administrator> docker container commit demo myapp:1.0
    ```

2.  Check that you can see your new image by listing all your images:

    ```powershell
    PS: node-0 Administrator> docker image ls

    REPOSITORY    TAG      IMAGE ID            CREATED             SIZE
    myapp         1.0      9ce128f61c85        2 minutes ago       11GB
    ...
    ```

3.  Create a container running Powershell using your new image, and check that wget is installed:

    ```powershell
    PS: node-0 Administrator> docker container run -it myapp:1.0 powershell
    PS C:\> cd \ProgramData\chocolatey\lib
    PS C:\> ls

        Directory: C:\ProgramData\chocolatey\lib

    Mode                LastWriteTime         Length Name
    ----                -------------         ------ ----
    d-----        8/29/2018  10:30 PM                chocolatey
    d-----        8/29/2018  10:31 PM                Wget
    ```

    The software you installed in your previous container is also available in this container, and all subsequent containers you start from the image you captured using `docker container commit`.

## Conclusion

In this exercise, you saw how to inspect the contents of a container's read / write layer with `docker container diff`, and commit those changes to a new image layer with `docker container commit`. Committing a container as an image in this fashion can be useful when developing an environment inside a container, when you want to capture that environment for reproduction elsewhere.
