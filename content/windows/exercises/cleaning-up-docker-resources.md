# Cleaning up Docker Resources

By the end of this exercise, you should be able to:

 - Assess how much disk space docker objects are consuming
 - Use `docker prune` commands to clear out unneeded docker objects
 - Apply label based filters to `prune` commands to control what gets deleted in a cleanup operation

1.  Find out how much memory Docker is using by executing:

    ```powershell
    PS: node-0 Administrator> docker system df
    ```

    The output will show us how much space images, containers and local volumes are occupying and how much of this space can be reclaimed. 

2.  Reclaim all reclaimable space by using the following command:

    ```powershell
    PS: node-0 Administrator> docker system prune
    ```

    Answer with `y` when asked if we really want to remove all unused networks, containers, images and volumes.

3.  Create a couple of containers with labels (these will exit immediately; why?):

    ```powershell
    PS: node-0 Administrator> docker container run `
        --label apple --name fuji -d `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737

    PS: node-0 Administrator> docker container run `
        --label orange --name clementine -d `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737
    ```

4.  Delete only those stopped containers bearing the `apple` label:

    ```powershell
    PS: node-0 Administrator> docker container ls -a
    PS: node-0 Administrator> docker container prune --filter 'label=apple'
    PS: node-0 Administrator> docker container ls -a
    ```

    Only the container named `clementine` should remain after the targeted prune.

5.  Finally, prune containers launched before a given timestamp using the `until` filter; start by getting the current RFC 3339 time ([https://tools.ietf.org/html/rfc3339](https://tools.ietf.org/html/rfc3339) - note Docker *requires* the otherwise optional `T` separating date and time), then creating a new container:

    ```powershell
    PS: node-0 Administrator> $dt=date
    PS: node-0 Administrator> $until='until=' + $dt.ToString("yyyy-MM-dd'T'HH:mm:ss.fffK")
    PS: node-0 Administrator> docker container run `
        --label tomato --name beefsteak -d `
        mcr.microsoft.com/windows/nanoserver:10.0.17763.737
    ```

    And use the timestamp returned in a prune:

    ```powershell
    PS: node-0 Administrator> docker container prune -f --filter $until
    PS: node-0 Administrator> docker container ls -a 
    ```

    Note the `-f` flag, to suppress the confirmation step. `label` and `until` filters for pruning are also available for networks and images, while data volumes can only be selectively pruned by `label`; finally, images can also be pruned by the boolean `dangling` key, indicating if the image is untagged.

6.  Cleanup all containers to end the exercise:

    ```powershell
    PS: node-0 Administrator> docker container rm $(docker container ls -aq)
    ```

## Conclusion

In this exercise, we saw some very basic `docker prune` usage - most of the top-level docker objects have a `prune` command (`docker container prune`, `docker volume prune` etc). Most docker objects leave something on disk even after being shut down; consider using these cleanup commands as part of your cluster maintenance and garbage collection plan, to avoid accidentally running out of disk on your Docker hosts.
