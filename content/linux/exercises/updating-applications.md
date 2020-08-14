# Updating Applications

Once we have defined an application as a Docker stack, we will periodically want to update its scale, configuration, and source code. By the end of this exercise, you should be able to:

 - Scale up microservice components of a stack to improve application performance
 - Define and trigger a rolling update of a service
 - Define and trigger an automatic rollback of a failed service update

## Deploying Dockercoins

For this exercise, we'll work with a toy application called *Dockercoins*. This application is a toy 'dockercoin' miner, consisting of five microservices interacting in the following workflow:

 1. A **worker** container requests a random number from a random number generator **rng**
 2. After receiving a random number, the worker pushes it to a **hasher** container, which computes a hash of this number.
 3. If the hash of the random number starts with 0, we accept this as a Dockercoin, and forward it to a **redis** container.
 4. Meanwhile, a **webui** container monitors the rate of coins being sent to redis, and visualizes this as a chart on a web page.

1.  Download the Dockercoins app from Github and change directory to ~/orchestration-workshop/dockercoins:

    ```bash
    [centos@node-0 ~]$ git clone -b ee3.0 \
        https://github.com/docker-training/orchestration-workshop.git

    [centos@node-0 ~]$ cd ~/orchestration-workshop/dockercoins
    ```

2.  The Dockercoins application is defined in `docker-compose.yml`; have a look at this file, and make sure you understand what every key is doing. Once you're satisfied with this, deploy the stack:

    ```bash
    [centos@node-0 dockercoins]$ docker stack deploy -c docker-compose.yml dockercoins
    ```

    Visit the Dockercoins web frontend at `<public IP>:8000`, for any public IP in your swarm. You should see Dockercoins getting mined at a rate of a few per second.

## Scaling Up an Application

If we've written our services to be stateless, we might hope for linear performance scaling in the number of replicas of that service. For example, our `worker` service requests a random number from the `rng` service and hands it off to the `hasher` service; the faster we make those requests, the higher our throughput of Dockercoins should be, as long as there are no other confounding bottlenecks.

1.  Modify the `worker` service definition in `docker-compose.yml` to set the number of replicas to create using the `deploy` and `replicas` keys:

    ```yaml
    worker:
      image: training/dockercoins-worker:1.0
      networks:
      - dockercoins
      deploy:
         replicas: 2
    ```

2.  Update your app by running the same command you used to launch it in the first place:

    ```bash
    [centos@node-0 dockercoins]$ docker stack deploy -c docker-compose.yml dockercoins
    ```

    Check the web frontend; after a few seconds, you should see about double the number of hashes per second, as expected.

3.  Scale up even more by changing the `worker` replicas to 10. A small improvement should be visible, but certainly not an additional factor of 5. Something else is bottlenecking Dockercoins; let's investigate the two services `worker` is interacting with: `rng` and `hasher`.

4.  The `rng` and `hasher` services are exposed on host ports 8001 and 8002, so we can use `httping` to probe their latency:

    ```bash
    [centos@node-0 dockercoins]$ httping -c 5 localhost:8001
    [centos@node-0 dockercoins]$ httping -c 5 localhost:8002
    ```

    `rng` is much slower to respond, suggesting that it might be the bottleneck. If this random number generator is based on an entropy collector (random voltage microfluctuations in the machine's power supply, for example), it won't be able to generate random numbers beyond a physically limited rate; we need more machines collecting more entropy in order to scale this up. This is a case where it makes sense to run exactly one copy of this service per machine, via `global` scheduling (as opposed to potentially many copies on one machine, or whatever the scheduler decides as in the default `replicated` scheduling).

2.  Modify the definition of our `rng` service in `docker-compose.yml` to be globally scheduled:

    ```yaml
    rng:
      image: training/dockercoins-rng:1.0
      networks:
      - dockercoins
      ports:
      - "8001:80"
      deploy:
        mode: global
    ```

3.  Scheduling can't be changed on the fly, so we need to stop our app and restart it:

    ```bash
    [centos@node-0 dockercoins]$ docker stack rm dockercoins
    [centos@node-0 dockercoins]$ docker stack deploy -c=docker-compose.yml dockercoins
    ```

4.  Check the web frontend again; the overall factor of 10 improvement (from ~3 to ~35 hashes per second) should now be visible.

## Creating Rolling Updates

Beyond scaling up an existing application, we'll periodically want to update the underlying source code of one or more of our components; Swarm provides mechanisms for rolling out updates in a controlled fashion that minimizes downtime.

1.  First, let's change one of our services a bit: open `orchestration-workshop/dockercoins/worker/worker.py` in your favorite text editor, and find the following section:

    ```python
    def work_once():
        log.debug("Doing one unit of work")
        time.sleep(0.1)
    ```

    Change the `0.1` to a `0.01`. Save the file, exit the text editor. 

2.  Rebuild the worker image with a tag of `<Docker ID>/dockercoins-worker:1.1`, and push it to Docker Hub.

3.  Change the `image:` value for the `worker` service in your `docker-compose.yml` file to that of the image you just pushed.

4.  Start the update:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c='docker-compose.yml' dockercoins
    ```

    Use `docker stack ps dockercoins` to watch tasks get updated to our new 1.1 image one at a time.

## Parallelizing Updates

1.  We can also set our updates to run in batches by configuring some options associated with each service. Change the update parallelism to 2 and the delay to 5 seconds on the `worker` service by editing its definition in the `docker-compose.yml`:

    ```yaml
    worker:
      image: training/dockercoins-worker:1.0
      networks:
      - dockercoins
      deploy:
        replicas: 10
        update_config:
          parallelism: 2
          delay: 5s
    ```

2.  Roll back the `worker` service to 1.0:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c=docker-compose.yml dockercoins
    ```

3.  On `node-1`, watch your updates:

    ```bash
    [centos@node-1 ~]$ watch -n1 "docker service ps dockercoins_worker \
        | grep -v Shutdown.*Shutdown"
    ```

    You should see two tasks get shutdown and restarted with the `1.0` image every five seconds.

## Auto-Rollback Failed Updates

In the event of an application or container failure on deployment, we'd like to automatically roll the update back to the previous version.

1.  Update the `worker` service with some parameters to define rollback:

    ```yaml
    worker:
      image: training/dockercoins-worker:1.0
      networks:
      - dockercoins
      deploy:
        replicas: 10
        update_config:
          parallelism: 2
          delay: 5s
          failure_action: rollback
          max_failure_ratio: 0.2
          monitor: 20s
    ```

    These parameters will trigger a rollback if more than 20% of services tasks fail in the first 20 seconds after an update.

2.  Update your stack to make sure the rollback parameters are in place before you attempt to update your image:

    ```bash
    [centos@node-0 ~]$ docker stack deploy -c=docker-compose.yml dockercoins
    ```

3.  Make a broken version of the `worker` service to trigger a rollback with; try removing all the `import` commands at the top of `worker.py`, for example. Then rebuild the worker image with a tag `<Docker ID>/dockercoins-worker:bugged`, push it to Docker Hub, and attempt to update your service:

    ```bash
    [centos@node-0 worker]$ docker image build -t <Docker ID>/dockercoins-worker:bugged .
    [centos@node-0 worker]$ docker image push <Docker ID>/dockercoins-worker:bugged
    ```

4.  Update your `docker-compose.yml` file to use the `:bugged` tag for the `worker` service, and redeploy your stack as above.

5.  The connection to `node-1` running `watch` should show the `:bugged` tag getting deployed, failing, and rolling back to `:1.0` automatically over the next minute or two:

    ```bash
    NAME                       IMAGE                       CURRENT STATE                
    dockercoins_worker.1       dockercoins-worker:1.0      Running 2 minutes ago
    dockercoins_worker.2       dockercoins-worker:1.0      Running 2 minutes ago
    dockercoins_worker.3       dockercoins-worker:1.0      Running about a minute ago
     \_ dockercoins_worker.3   dockercoins-worker:bugged   Failed about a minute ago   
     \_ dockercoins_worker.3   dockercoins-worker:bugged   Failed about a minute ago    
     \_ dockercoins_worker.3   dockercoins-worker:bugged   Failed about a minute ago    
    dockercoins_worker.4       dockercoins-worker:1.0      Running about a minute ago
     \_ dockercoins_worker.4   dockercoins-worker:bugged   Failed about a minute ago    
    dockercoins_worker.5       dockercoins-worker:1.0      Running about a minute ago
     \_ dockercoins_worker.5   dockercoins-worker:bugged   Failed about a minute ago 
     \_ dockercoins_worker.5   dockercoins-worker:bugged   Failed about a minute ago  
     \_ dockercoins_worker.5   dockercoins-worker:bugged   Failed about a minute ago   
    dockercoins_worker.6       dockercoins-worker:1.0      Running 2 minutes ago
    dockercoins_worker.7       dockercoins-worker:1.0      Running 2 minutes ago
    dockercoins_worker.8       dockercoins-worker:1.0      Running 2 minutes ago
    dockercoins_worker.9       dockercoins-worker:1.0      Running about a minute ago
     \_ dockercoins_worker.9   dockercoins-worker:bugged   Failed about a minute ago  
    dockercoins_worker.10      dockercoins-worker:1.0      Running 2 minutes ago
    ```

    For example, this table indicates that tasks 3, 4, 5 and 9 all attempted to update to the `:bugged` tag, failed, and successfully rolled back to the `:1.0` tag (the `\_` symbol is meant to indicate failed ancestors for an individual task; so `dockercoins_worker.3` above made three failed attempts to run the `:bugged` image before rolling back).

    Use `CTRL+C` to exit this `watch` view when done.

5.  Clean up by removing your stack:

    ```bash
    [centos@node-0 dockercoins]$ docker stack rm dockercoins
    ```

## Optional Challenge: Improving Dockercoins

Dockercoins' stack file is very rudimentary, and not at all suitable for production. If you have time, try modifying Dockercoins' stack file with some of the best practices you've learned in this workshop; think about things like security, operational stability, latency and scheduling. This activity is best done in groups! Partner up with someone else and discuss what improvements you can make, then try them out and make sure they work as you expected.

## Conclusion

In this exercise, we explored deploying and redeploying an application as stacks and services. Note that relaunching a running stack updates all the objects it manages in the most non-disruptive way possible; there is usually no need to remove a stack before updating it. In production, rollback contingencies should always be used to cautiously upgrade images, cutting off potential damage before an entire service is taken down.
