# Managing Images

By the end of this exercise, you should be able to:

 - Rename and retag an image
 - Push and pull images from the public registry
 - Delete image tags and image layers, and understand the difference between the two operations

## Making an Account on Docker's Hosted Registry

1.  If you don't have one already, head over to [https://hub.docker.com](https://hub.docker.com) and make an account. For the rest of this workshop, `<Docker ID>` refers to the username you chose for this account.

## Tagging and Listing Images

1.  Download the `mcr.microsoft.com/windows/nanoserver:10.0.17763.737` image from Docker Hub:

    ```powershell
    PS: node-0 Administrator> docker image pull `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737
    ```

2.  Make a new tag of this image:

    ```powershell
    PS: node-0 Administrator> docker image tag `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737 mynanoserver:dev
    ```

    Note no new image has been created; `mynanoserver:dev` is just a pointer pointing to the same image as `mcr.microsoft.com/windows/nanoserver:10.0.17763.737`.

3.  List your images:

    ```powershell
    PS: node-0 Administrator> docker image ls

    ...
    mynanoserver       dev            4c872414bf9d   3 weeks ago   250MB
    windows/nanoserver 10.0.17763.737 4c872414bf9d   3 weeks ago   250MB
    ...
    ```
    
    You should have `mcr.microsoft.com/windows/nanoserver:10.0.17763.737` and `mynanoserver:dev` both listed, but they ought to have the same hash under image ID, since they're actually the same image. (Note you'll have a lot of other images, too - these were pre-downloaded for this workshop. On your own machines, you'll have to download the images you want using `docker image pull` like above).

## Sharing Images on Docker Hub

1.  Push your image to Docker Hub:

    ```powershell
    PS: node-0 Administrator> docker image push mynanoserver:dev
    ```

    You should get an `denied: requested access to the resource is denied` error.

2.  Login by doing `docker login`, and try pushing again. The push fails again because we haven't namespaced our image correctly for distribution on Docker Hub; all images you want to share on Docker Hub must be named like `<Docker ID>/<repo name>[:<optional tag>]`.

3.  Retag your image to be namespaced properly, and push again:

    ```powershell
    PS: node-0 Administrator> $user="<Docker ID>"
    PS: node-0 Administrator> docker image tag mynanoserver:dev $user/mynanoserver:dev
    PS: node-0 Administrator> docker image push $user/mynanoserver:dev
    ```

4.  Search Docker Hub for your new `<Docker ID>/mynanoserver` repo, and confirm that you can see the `:dev` tag therein.

5.  Next, write a Dockerfile that uses `$user/mynanoserver:dev` as its base image, and add an `ENTRYPOINT` or `CMD` parameter. Build the image, and simultaneously tag it as `:1.0`:

    ```powershell
    PS: node-0 Administrator> docker image build -t $user/mynanoserver:1.0 .
    ```

6.  Push your `:1.0` tag to Docker Hub, and confirm you can see it in the appropriate repository.

7.  Finally, list the images currently on your node with `docker image ls`. You should still have the version of your image that wasn't namespaced with your Docker Hub user name; delete this using `docker image rm`:

    ```powershell
    PS: node-0 Administrator> docker image rm mynanoserver:dev
    ```

    Only the tag gets deleted, not the actual image. The image layers are still referenced by another tag.

## Conclusion

In this exercise, we practiced tagging images and exchanging them on the public registry. The namespacing rules for images on registries are *mandatory*: user-generated images to be exchanged on the public registry must be named like `<Docker ID>/<repo name>[:<optional tag>]`; official images on Hub just have the repo name and tag.

Also note that as we saw when building images, image names and tags are just pointers; deleting an image with `docker image rm` just deletes that pointer if the corresponding image layers are still being referenced by another such pointer. Only when the last pointer is deleted are the image layers actually destroyed by `docker image rm`.
