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

1.  Download the Dockercoins app from Github and change directory to ~/orchestration-workshop-net:

    ```powershell
    PS: node-0 Administrator> git clone -b ee3.0-ws19 `
        https://github.com/docker-training/orchestration-workshop-net.git

    PS: node-0 Administrator> cd ~/orchestration-workshop-net
    ```

2.  The Dockercoins application is defined in `stack.yml`; have a look at this file, and make sure you understand what every key is doing. Once you're satisfied with this, deploy the stack:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack deploy `
        -c stack.yml dockercoins
    ```

    Visit the Dockercoins web frontend at `<public IP>:8000`, where `<public IP>` is the public IP of any node in your swarm. You should see Dockercoins getting mined at a rate of a few per second.

## Scaling Up an Application

If we've written our services to be stateless, we might hope for linear performance scaling in the number of replicas of that service. For example, our `worker` service requests a random number from the `rng` service and hands it off to the `hasher` service; the faster we make those requests, the higher our throughput of Dockercoins should be, as long as there are no other confounding bottlenecks.

1.  Modify the `worker` service definition in `stack.yml` to set the number of replicas to create using the `deploy` and `replicas` keys:

    ```yaml
    worker:
      image: training/dc_worker:ws19
      networks:
        - dockercoins
      deploy:
        replicas: 2
    ```

2.  Update your app by running the same command you used to launch it in the first place:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack deploy -c `
        stack.yml dockercoins
    ```

    Check the web frontend; after a few seconds, you should see about double the number of hashes per second, as expected.

3.  Scale up even more by changing the `worker` replicas to 10. A small improvement should be visible, but certainly not an additional factor of 5. Something else is bottlenecking Dockercoins; let's investigate the two services `worker` is interacting with: `rng` and `hasher`.

4.  First, we need to expose ports for the `rng` and `hasher` services, so we can probe their latency. Update their definitions in `stack.yml` with a `ports` key:

    ```yaml
    rng:
      image: training/dc_rng:ws19
      networks:
        - dockercoins
      ports:
        - target: 80
          published: 8001   

    hasher:
      image: training/dc_hasher:ws19
      networks:
        - dockercoins
      ports:
        - target: 80
          published: 8002
    ```

    Update the services by redeploying the stack file:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack deploy `
        -c stack.yml dockercoins
    ```

    If this is successful, a `docker service ls` should show `rng` and `hasher` exposed on the appropriate ports.

5.  With `rng` and `hasher` exposed, we can use `httping` to probe their latency; in both cases, `<public IP>` is the public IP of any node in your swarm:

    ```powershell
    PS: node-0 orchestration-workshop-net> httping -c 5 <public IP>:8001
    PS: node-0 orchestration-workshop-net> httping -c 5 <public IP>:8002
    ```

    `rng` is much slower to respond, suggesting that it might be the bottleneck. If this random number generator is based on an entropy collector (random voltage microfluctuations in the machine's power supply, for example), it won't be able to generate random numbers beyond a physically limited rate; we need more machines collecting more entropy in order to scale this up. This is a case where it makes sense to run exactly one copy of this service per machine, via `global` scheduling (as opposed to potentially many copies on one machine, or whatever the scheduler decides as in the default `replicated` scheduling).

7.  Modify the definition of our `rng` service in `stack.yml` to be globally scheduled:

    ```yaml
    rng:
      image: training/dc_rng:ws19
      networks:
        - dockercoins
      deploy:
        mode: global
      ports:
        - target: 80
          published: 8001 
    ```

8.  Scheduling can't be changed on the fly, so we need to stop our app and restart it:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack rm dockercoins
    PS: node-0 orchestration-workshop-net> docker stack deploy `
        -c stack.yml dockercoins
    ```

9.  Check the web frontend again; you should finally see the factor of 10 improvement in performance versus a single worker container, from 3-4 coins per second to around 35.

## Creating Rolling Updates

Beyond scaling up an existing application, we'll periodically want to update the underlying source code of one or more of our components; Swarm provides mechanisms for rolling out updates in a controlled fashion that minimizes downtime.

1.  First, let's change one of our services a bit: open `orchestration-workshop-net/worker/Program.cs` in your favorite text editor, and find the following section:

    ```java
    private static void WorkOnce(){
        Console.WriteLine("Doing one unit of work");
        Thread.Sleep(100);  // 100 ms
    ```

    Change the `100` to a `10`. Save the file, exit the text editor. 

2.  Rebuild the worker image with a tag of `<Docker ID>/dc_worker:ws19-1.1`, and push it to Docker Hub.

3.  Change the `image:` value for the `worker` service in your `stack.yml` file to that of the image you just pushed.

4.  Start the update:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack deploy `
        -c stack.yml dockercoins
    ```

    Use `docker stack ps dockercoins` every couple of seconds to watch tasks get updated to our new 1.1 image one at a time.

## Parallelizing Updates

1.  We can also set our updates to run in batches by configuring some options associated with each service. Change the update parallelism to 2 and the delay to 5 seconds on the `worker` service by editing its definition in `stack.yml`:

    ```yaml
    worker:
      image: training/dc_worker:ws19
      networks:
        - dockercoins
      deploy:
        replicas: 10
        update_config:
          parallelism: 2
          delay: 5s
    ```

2.  Roll back the `worker` service to its original image:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack deploy `
        -c stack.yml dockercoins
    ```

    Run `docker service ps dockercoins_worker` every couple of seconds; you should see pairs of worker tasks getting shut down and replaced with the original version, with a 5 second delay between updates (this is perhaps easiest to notice by examining the `NAME` column - every worker replica will start with one dead task from when you upgraded in the last step; you should be able to notice pairs of tasks with two dead ancestors as this rollback moves through the list, two at a time).

## Auto-Rollback Failed Updates

In the event of an application or container failure on deployment, we'd like to automatically roll the update back to the previous version.

1.  Update the `worker` service with some parameters to define rollback:

    ```yaml
    worker:
      image: training/dc_worker:ws19
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

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack deploy `
        -c stack.yml dockercoins
    ```

3.  Make a broken version of the `worker` service to trigger a rollback with; try removing all the `using` commands at the top of `worker/Program.cs`, for example. Then rebuild the worker image with a tag `<Docker ID>/dc_worker:bugged`, push it to Docker Hub, and attempt to update your service:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker image build `
        -t <Docker ID>/dc_worker:bugged worker
    PS: node-0 orchestration-workshop-net> docker image push `
        <Docker ID>/dc_worker:bugged
    ```

4.  Update your `stack.yml` file to use the `:bugged` tag for the `worker` service, and redeploy your stack as above.

5.  Use `docker stack ps dockercoins` to watch the `:bugged` tag getting deployed, failing, and rolling back automatically over the next minute or two:

    ```powershell
    NAME                       IMAGE              CURRENT STATE                
    dockercoins_worker.1       dc_worker:ws19     Running 2 minutes ago
    dockercoins_worker.2       dc_worker:ws19     Running 2 minutes ago
    dockercoins_worker.3       dc_worker:ws19     Running about a minute ago
     \_ dockercoins_worker.3   dc_worker:bugged   Failed about a minute ago   
     \_ dockercoins_worker.3   dc_worker:bugged   Failed about a minute ago    
     \_ dockercoins_worker.3   dc_worker:bugged   Failed about a minute ago    
    dockercoins_worker.4       dc_worker:ws19     Running about a minute ago
     \_ dockercoins_worker.4   dc_worker:bugged   Failed about a minute ago    
    dockercoins_worker.5       dc_worker:ws19     Running about a minute ago
     \_ dockercoins_worker.5   dc_worker:bugged   Failed about a minute ago 
     \_ dockercoins_worker.5   dc_worker:bugged   Failed about a minute ago  
     \_ dockercoins_worker.5   dc_worker:bugged   Failed about a minute ago   
    dockercoins_worker.6       dc_worker:ws19     Running 2 minutes ago
    dockercoins_worker.7       dc_worker:ws19     Running 2 minutes ago
    dockercoins_worker.8       dc_worker:ws19     Running 2 minutes ago
    dockercoins_worker.9       dc_worker:ws19     Running about a minute ago
     \_ dockercoins_worker.9   dc_worker:bugged   Failed about a minute ago  
    dockercoins_worker.10      dc_worker:ws19     Running 2 minutes ago
    ```

    For example, this table indicates that tasks 3, 4, 5 and 9 all attempted to update to the `:bugged` tag, failed, and successfully rolled back to the `:ws19` tag (the `\_` symbol is meant to indicate failed ancestors for an individual task; so `dockercoins_worker.3` above made three failed attempts to run the `:bugged` image before rolling back).

5.  Clean up by removing your stack:

    ```powershell
    PS: node-0 orchestration-workshop-net> docker stack rm dockercoins
    ```

## Optional Challenge: Improving Dockercoins

Dockercoins' stack file is very rudimentary, and not at all suitable for production. If you have time, try modifying Dockercoins' stack file with some of the best practices you've learned in this workshop; think about things like security, operational stability, latency and scheduling. This activity is best done in groups! Partner up with someone else and discuss what improvements you can make, then try them out and make sure they work as you expected.

## Conclusion

In this exercise, we explored deploying and redeploying an application as stacks and services. Note that relaunching a running stack updates all the objects it manages in the most non-disruptive way possible; there is usually no need to remove a stack before updating it. In production, rollback contingencies should always be used to cautiously upgrade images, cutting off potential damage before an entire service is taken down.
