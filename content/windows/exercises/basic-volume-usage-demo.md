# Instructor Demo: Basic Volume Usage

In this demo, we'll illustrate:

 - Creating, updating, destroying, and mounting docker named volumes
 - How volumes interact with a container's layered filesystem
 - Usecases for mounting host directories into a container

## Using Named Volumes

1.  Create a volume, and inspect its metadata:

    ```powershell
    PS: node-0 Administrator> docker volume create demovol
    PS: node-0 Administrator> docker volume inspect demovol

    [
        {
            "Driver": "local",
            "Labels": {},
            "Mountpoint": "C:\\ProgramData\\docker\\volumes\\demovol\\_data",
            "Name": "demovol",
            "Options": {},
            "Scope": "local"
        }
    ]
    ```

    We can see that by default, named volumes are created under `C:\\ProgramData\\docker\\volumes\\<volume name>\\_data`.

2.  Run a container that mounts this volume, and list the filesystem therein:

    ```powershell
    PS: node-0 Administrator> docker container run `
           -it -v demovol:C:\demo `
           mcr.microsoft.com/windows/servercore:10.0.17763.805 cmd

    C:\>dir
     Volume in drive C has no label.
     Volume Serial Number is 38CD-4889    

     Directory of C:\    

    10/30/2019  05:45 PM    <DIR>          demo
    09/15/2018  09:42 AM             5,510 License.txt
    10/06/2019  10:04 AM    <DIR>          Program Files
    10/06/2019  10:02 AM    <DIR>          Program Files (x86)
    10/06/2019  10:05 AM    <DIR>          Users
    10/30/2019  05:46 PM    <DIR>          Windows
                   1 File(s)          5,510 bytes
                   5 Dir(s)  21,209,698,304 bytes free
    ```

    The `demo` directory is created as the mountpoint for our volume, as specified in the flag `-v demovol:C:\demo`. 

3.  Put some text in a file in this volume; this is analogous to your containerized application writing data out to its filesystem:

    ```powershell
    C:\>cd demo    

    C:\demo>dir > data.dat
    ```

4.  Exit the container, and list the contents of your volume on the host:

    ```powershell
    PS: node-0 Administrator> ls C:\\ProgramData\\docker\\volumes\\demovol\\_data
    ```

    You'll see your `data.dat` file present at this point in the host's filesystem. Delete the container:

    ```powershell
    PS: node-0 Administrator> docker container rm -f <container ID>
    ```

    The volume and its contents will still be present on the host.

5.  Start a new container mounting the same volume, and show that the old data is present in your new container:

    ```powershell
    PS: node-0 Administrator> docker container run `
           -it -v demovol:C:\demo `
           mcr.microsoft.com/windows/servercore:10.0.17763.805 cmd

    C:\>cd demo

    C:\demo>dir
     Volume in drive C has no label.
     Volume Serial Number is 38CD-4889    

     Directory of C:\demo    

    10/30/2019  05:45 PM    <DIR>          .
    10/30/2019  05:45 PM    <DIR>          ..
    10/30/2019  05:47 PM               330 data.dat
                   1 File(s)            330 bytes
                   2 Dir(s)  36,361,719,808 bytes free
    ```

    `data.dat` is recovered from the volume in this new container.

6.  Exit this container, and inspect its mount metadata:

    ```powershell
    PS: node-0 Administrator> docker container inspect <container ID>

        "Mounts": [
            {
                "Type": "volume",
                "Name": "demovol",
                "Source": "C:\\ProgramData\\docker\\volumes\\demovol\\_data",
                "Destination": "c:\\demo",
                "Driver": "local",
                "Mode": "",
                "RW": true,
                "Propagation": ""
            }
        ],
    ```

    Here we can see the volumes and host mountpoints for everything mounted into this container.

7.  Clean up by removing that volume:

    ```powershell
    PS: node-0 Administrator> docker volume rm demovol
    ```

    You will get an error saying the volume is in use - docker will not delete a volume mounted to any container (even a stopped container) in this way. Remove the offending container first, then remove the volume again.

## Mounting Host Paths

1.  In a fresh directory `myweb`, make a Dockerfile to make a simple containerization of nginx:

    ```dockerfile
    FROM mcr.microsoft.com/windows/servercore:10.0.17763.805
    RUN ["powershell", "wget", "http://nginx.org/download/nginx-1.11.6.zip", \
         "-UseBasicParsing", "-OutFile", "c:\\nginx.zip"]
    RUN ["powershell", "Expand-Archive", "c:\\nginx.zip", "-Dest", "c:\\nginx"]
    WORKDIR c:\\nginx\\nginx-1.11.6
    ENTRYPOINT ["powershell", ".\\nginx.exe"]
    ```

2.  Build this image, and use it to start a container that serves the default nginx landing page:

    ```powershell
    PS: node-0 myweb> docker image build -t nginx .
    PS: node-0 myweb> docker container run -d -p 5000:80 nginx
    ```  

    Visit the landing page at `<node-0 public IP>:5000` to confirm everything is working, then remove this container.

3.  Create some custom HTML for your new website:

    ```powershell
    PS: node-0 myweb> echo "<h1>Hello Wrld</h1>" > index.html
    ```

4.  The HTML served by nginx is found in the container's filesystem at `C:\nginx\nginx-1.11.6\html`. Mount your `myweb` directory at this path:

    ```powershell
    PS: node-0 myweb> docker container run -d -p 5000:80 `
        -v C:\Users\Administrator\myweb:C:\nginx\nginx-1.11.6\html `
        nginx
    ```
    
    Visit your webpage `<node 0 public IP>:5000`; you should be able to see your custom webpage.

5.  There's a typo in your custom html. Fix the spelling of 'world' in your HTML, and refresh the webpage; the content served by nginx gets updated without having to restart or replace the nginx container.

## Conclusion

In this demo, we saw two key points about volumes: first, they persist and provision files beyond the lifecycle of any individual container. Second, we saw that manipulating files on the host that have been mounted into a container immediately propagates those changes to the running container; this is a popular technique for developers who containerize their running environment, and mount in their in-development code so they can edit their code using the tools on their host machine that they are familiar with, and have those changes immediately available inside a running container without having to restart or rebuild anything.
