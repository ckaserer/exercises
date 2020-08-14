# Provisioning Swarm Configuration

When deploying an application, especially one meant to be migrated across different environments, it's helpful to be able to provision configuration like environment variables and config files to your services in a modular, pluggable fashion. By the end of this exercise, you should be able to:

 - Assemble application components together as a Docker stack
 - Provision insecure configuration to service containers using `.env` files and Docker configs
 - Provision secure configuration to service containers using Docker secrets

## Creating a Stack

So far, we've run individual services with `docker service create`. As we build more complex applications consisting of multiple components, we'd like a way to capture them all in a single file we can version control and recreate; for this, we can use *stack files*.

1.  Create a file called `mystack.yaml` with the following content:

    ```yaml
    version: "3.7" 

    services:
      whoami:
        image: training/whoami-windows:ws19
        deploy:
          mode: global
        ports:
          - target: 5000
            published: 8080
    ```

    This stack file will create a single service named `whoami-windows`, based on the `training/whoami-windows:ws19` image, schedule it globally, and make the `whoami` response reachable on port 8080 of any host in the cluster.

    > Docker stack file syntax is based on Docker Compose; we'll see numerous examples of this syntax in this workshop, but if you'd like the full reference, see the docs at [https://dockr.ly/2iHUpeX](https://dockr.ly/2iHUpeX).

2.  Deploy your stack:

    ```powershell
    PS: node-0 Administrator> docker stack deploy -c mystack.yaml stackdemo
    ```

    Your service is created, along with a default network for the stack (more on service networking in a future exercise).

3.  List your stacks and, see its services:

    ```powershell
    PS: node-0 Administrator> docker stack ls

    NAME                SERVICES            ORCHESTRATOR
    stackdemo           1                   Swarm

    PS: node-0 Administrator> docker service ls  
    
    ID      NAME              MODE    REPLICAS  IMAGE
    bon...  stackdemo_whoami  global  4/4       training/whoami-windows:ws19
    ```

    By default, your service gets named as the stack (`stackdemo`), concatenated with the key you labeled your service with in your stack file (`whoami`).

4.  Make sure everything is working as expected by visiting the Who Am I response at `http://<public IP>:8080`, where `<public IP>` is the public IP of any node in your swarm - by default, Swarm uses its _layer 4 mesh net_ to route request arriving at the exposed port (8080) on _any_ host in the swarm to the appropriate backend containers.

## Defining and Using Docker Configs

Above, we created a simple website with four replicas; we'd like to set up a load balancer to direct traffic to our website replicas, but we don't want to have to create a special load balancer image just for this one task; we'd rather use a generic load balancer image, and provision it with the appropriate config at startup. For this we can use a *docker config*.

1.  Create an nginx configuration file called `nginx.conf`, changing the lines with `<node-x public IP>` to the public IPs of each of your swarm nodes:

    ```powershell
    worker_processes  1;    

    events {
        worker_connections  1024;
    }    

    stream {
        upstream myapp {
            server <node-0 public IP>:8080;
            server <node-1 public IP>:8080;
            server <node-2 public IP>:8080;
            server <node-3 public IP>:8080;
        }    

        server {
            listen 80;
            proxy_pass myapp;
        }
    }
    ```

2.  Modify your stack file to add in a proxy service, using this config file as a Docker config:

    ```powershell
    version: "3.7"        

    services:
      whoami:
        image: training/whoami-windows:ws19
        deploy:
          mode: global
        ports:
          - target: 5000
            published: 8080    

      proxy:
        image: training/win-nginx:ee3.0-ws19
        ports:
          - target: 80
            published: 8001     
        configs:
          - source: nginxconf
            target: C:\nginx\nginx-1.12.0\conf\nginx.conf    

    configs:
      nginxconf:
        file: .\nginx.conf
    ```

    Here we've added a new top level object, `configs`, that lists Docker config objects (just `nginxconf` in this example), which each specify a file to be populated by. In our `proxy` service we mount this config by name, and give it a path to mount to.

3.  Update your stack:

    ```powershell
    PS: node-0 Administrator> docker stack deploy -c mystack.yaml stackdemo
    ```

    Note this is the exact same command you used to create the stack in the first place; recreating an existing stack will apply only the updates since your last deploy.

4.  List and inspect your `config` objects:

    ```powershell
    PS: node-0 Administrator> docker config ls

    ID                     NAME                  CREATED              UPDATED
    9k8qm1en5e7t5tn7q...   stackdemo_nginxconf   About a minute ago   About a minute ago

    PS: node-0 Administrator> docker config inspect --pretty <config ID>

    ID:                     9k8qm1en5e7t5tn7qyloi2pf0
    Name:                   stackdemo_nginxconf
    Labels:
     - com.docker.stack.namespace=stackdemo
    Created at:             2019-02-03 00:44:37.9298585 +0000 utc
    Updated at:             2019-02-03 00:44:37.9298585 +0000 utc
    Data:
    worker_processes  1;    

    events {
        worker_connections  1024;
    }    

    stream {
        upstream myapp {
            server 3.92.18.65:8080;
            server 3.87.220.140:8080;
            server 3.80.99.91:8080;
            server 3.90.223.203:8080;
        }    

        server {
            listen 80;
            proxy_pass myapp;
        }
    }
    ```

    We can recover the plain-text contents of any config option in this manner.

5.  Make sure this all worked as expected by visiting port 8001 (the public port for your `nginx` service) and make sure you can see the `whoami` response, proving your proxy is routing to your simple website being served on 8080.

6.  Clean up: `docker stack rm stackdemo`

## Defining and Using .env Files and Secrets

Above, we provisioned an entire configuration file to a service via a docker config object. Often we only want to provision individual tokens, like paths or passwords; furthermore, these tokens can have varying security needs. For non-secure information, we can specify *environment variables* in our containers, and for sensitive information we should use *docker secrets*, as follows.

1.  Create a new directory `image-secrets` on `node-0` and navigate to this folder. In this folder create a file named `app.py` and add the following content; this is a Python script that consumes a password from a file with a path specified by the environment variable `PASSWORD_FILE`:

    ```python
    import os
    print('***** Docker Secrets ******')
    print('USERNAME: {0}'.format(os.environ['USERNAME']))

    fname = os.environ['PASSWORD_FILE']
    with open(fname) as f:
        content = f.readlines()

    print('PASSWORD_FILE: {0}'.format(fname))
    print('PASSWORD: {0}'.format(content[0]))
    ```

    For optimal security, secret information like passwords shouldn't be stored in an environment variable directly; Docker will provision the secret to the container as a file. We can then define an environment variable that points at the path of this secret file, which our script can then consume.

2.  Create a file called `Dockerfile` with the following content:

    ```powershell
    FROM python:3.8.0-windowsservercore-1809
    RUN mkdir -p /app
    WORKDIR /app
    COPY . /app
    CMD python ./app.py; sleep 100000
    ```

3.  Build the image and push it to a registry so it's available to all nodes in your swarm:

    ```powershell
    PS: node-0 image-secrets> docker image build -t <Docker ID>/secrets-demo:1.0 .
    PS: node-0 image-secrets> docker image push <Docker ID>/secrets-demo:1.0
    ```

4.  Next let's create a secret. In the current directory create a file called `password.txt` and add the value `my-pass` to it. Turn the contents of that file into a docker secret:

    ```powershell
    PS: node-0 image-secrets> docker secret create mypass ./password.txt
    PS: node-0 image-secrets> rm password.txt
    ```

    Remember to delete the plaintext copy of your password in `password.txt`. Swarm encrypts your secret value and won't return it in plain text, so with this file removed your secret is secure at rest on your management cluster.

5.  Define your non-secure environment variables in a file called `myconf.env`:

    ```powershell
    PASSWORD_FILE=C:\ProgramData\Docker\secrets\mypass
    ```

    By default, Docker will place a secret called `mypass` at the path `C:\ProgramData\Docker\secrets\mypass`, which we're going to inform our containerized process of via and environment variable defined in this env file.

6.  Create a stack file called `secretstack.yaml` that makes a service out of your `secrets-demo:1.0` image, and provisions it with your secret password and environment variable (don't forget to change `<Docker ID>` to your Docker Hub ID):

    ```yaml
    version: "3.7"    

    services:
      myapp:
        image: <Docker ID>/secrets-demo:1.0
        env_file:
          - myconf.env 
        secrets:
          - mypass

    secrets:
      mypass:
        external: true
    ```

    Here we introduce a few keys:
    - `services:env_file` lists files that contain key/value pairs like our `myconf.env` to be declared as environment variables in the containers for this service
    - `services:secrets` lists docker secrets, created as above, to provision to the containers for this service. By default, the content of the secret will be available as a file at the path `C:\ProgramData\Docker\secrets\<secret name>`
    - The top level `secrets` key lists secrets created as above, for consumption in your services.

7.  Deploy your stack, list the services on you swarm, and get the logs for your single service:

    ```powershell
    PS: node-0 image-secrets> docker stack deploy -c .\secretstack.yaml secretdemo
    Creating network secretdemo_default
    Creating service secretdemo_destination

    PS: node-0 image-secrets>docker service ls

    ID            NAME              MODE        REPLICAS  IMAGE                     
    8aoeanv90dqm  secretdemo_myapp  replicated  1/1       training/secrets-demo:1.0

    PS: node-0 image-secrets> docker service logs <service ID>

    secretdemo_myapp.1.xxx@node-0  | ***** Docker Secrets ******
    secretdemo_myapp.1.xxx@node-0  | USERNAME: ContainerAdministrator
    secretdemo_myapp.1.xxx@node-0  | PASSWORD_FILE: C:\ProgramData\Docker\secrets\mypass
    secretdemo_myapp.1.xxx@node-0  | PASSWORD: my-pass
    ```

    If all has been successful, your script will have used the environment variable `PASSWORD_FILE` to locate your secret password, and read it from there. Of course this is just a toy script to demonstrate usage, but the same pattern of provisioning secure information through secrets pointed at by environment variables is a common best practice for handling this type of config.

8.  Optional: Locate the node running your single container for this service, and use `docker container inspect` on it. Notice all the environment variables defined in the container are visible in the `Env:` block of the output. A common mistake when provisioning configuration is to provide passwords directly as environment variables; do that, and those passwords will be exposed in plain text to anyone who has inspect access to your containers.

8.  Clean up: `docker stack rm secretdemo`

## Conclusion

In this exercise, we saw several different methods for defining and provisioning configurations, as well as a few examples of stack files for defining and composing all the elements of our application. Deciding what information to provision via configurations is an important architectural choice; in general, anything that's going to change when moving from environment to environment is a good candidate for a config, since env files, docker configs, and docker secrets are all modular and defined separately from the service definition itself; by separating configs in this way, we can just swap the config out when changing environments, without redefining our services. The (usually worse) alternative to provisioning by config is to include this information directly in the image; this is a good choice for information that is the same in all environments you plan on running that image in, but can lead to image management complexity and loss of portability if environment-specific information is hard-coded into the image. Of course, secure information like passwords should *never* be hard-coded into images; they should strictly be provisioned as Docker secrets, and consumed only from the filesystem inside the container to which they are mounted.
