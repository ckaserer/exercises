# Plugins

By the end of this exercise, you should be able to:

 - Install, configure, and delete any Docker plugin
 - Use the `vieux/sshfs` plugin to create ssh-mountable volumes that can be mounted into any container in your cluster

## Installing a Plugin

1.  Plugins can be hosted on Docker Hub or any other (private) repository. Let's start with Docker Hub. Browse to [https://hub.docker.com](https://hub.docker.com) and enter `vieux/sshfs` in the search box. The result should show you the plugin that we are going to work with.

2.  Install the plugin into our Docker Engine:

    ```bash
    [centos@node-0 ~]$ docker plugin install vieux/sshfs
    ```

    The system should ask us for permission to use privileges. In the case of the `sshfs` plugin there are 4 privileges. Answer with `y`.

3.  Once we have successfully installed some plugins we can use the `ls` command to see the status of each of the installed plugins. Execute:

    ```bash
    [centos@node-0 ~]$ docker plugin ls
    ```

## Enabling and Disabling a Plugin

1.  Once a plugin is installed it is `enabled` by default. We can disable it using this command:

    ```bash
    [centos@node-0 ~]$ docker plugin disable vieux/sshfs
    ```

    only when a plugin is disabled can certain operations on it be executed.

2.  The plugin can be (re-) enabled by using this command:

    ```bash
    [centos@node-0 ~]$ docker plugin enable vieux/sshfs
    ```

    Play with the above commands and notice how the status of the plugin changes when displaying it with `docker plugin ls`.

## Inspecting a Plugin

1.  We can also use the `inspect` command to further inspect all the attributes of a given plugin. Execute the following command:

    ```bash
    [centos@node-0 ~]$ docker plugin inspect vieux/sshfs
    ```

    and examine the output. Specifically note that there are two sections in the metadata called `Env`, one is under `Config` and the other under `Settings`. This is where the list of environment variables are listed that the author of the plugin has defined. In this specific situation we can see that there is a single variable called `DEBUG` defined. Its initial value is `0`.

2.  We can use the `set` command to change values of the environment variables. Execute:

    ```bash
    [centos@node-0 ~]$ docker plugin set vieux/sshfs DEBUG=1

    Error response from daemon: cannot set on an active plugin, 
        disable plugin before setting
    ```

    This is one of those times we have to disable the plugin first; do so, then try the `set` command again:

    ```bash
    [centos@node-0 ~]$ docker plugin disable vieux/sshfs
    [centos@node-0 ~]$ docker plugin set vieux/sshfs DEBUG=1
    [centos@node-0 ~]$ docker plugin enable vieux/sshfs
    ```

    and then inspect again the metadata of the plugin. Notice how the value of `DEBUG` has been adjusted. Only the one under the `Settings` node changed but the one under the `Config` node still shows the original (default) value.

## Using the Plugin

1.  Make a directory on `node-1` that we will mount as a volume across our cluster:

    ```bash
    [centos@node-1 ~]$ mkdir ~/demo
    ```

2.  Back on `node-0`, use the plugin to create a volume that can be mounted via ssh:

    ```bash
    [centos@node-0 ~]$ docker volume create -d vieux/sshfs \
        -o sshcmd=centos@<node-1 public IP>:/home/centos/demo \
        -o password=orca \
        sshvolume
    ```

3.  Mount that volume in a new container as per usual:

    ```bash
    [centos@node-0 ~]$ docker container run --rm -it -v sshvolume:/data alpine sh
    ```

4.  Inside the container navigate to the `/data` folder and create a new file:

    ```bash
    / # cd /data
    / # echo 'Hello from client!' > demo.txt
    / # ls -al
    ```

5.  Head over to `node-1`, and confirm that `demo.txt` got written there.

## Removing a Plugin

1.  If we don't want or need this plugin anymore we can remove it using the command:

    ```bash
    [centos@node-0 ~]$ docker volume rm sshvolume
    [centos@node-0 ~]$ docker plugin disable vieux/sshfs
    [centos@node-0 ~]$ docker plugin rm vieux/sshfs
    ```

    Note how we first have to disable the plugin before we can remove it.

## Conclusion

Docker follows a 'batteries included but swappable' mindset in its product design: everything you need to get started is included, but heavy customization is supported and encouraged. Docker plugins are one aspect of that flexibility, allowing users to define their own volume and networking behavior.
