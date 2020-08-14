# Scaling a Compose App

By the end of this exercise, you should be able to:

 - Scale a service from Docker Compose up or down

## Scaling a Service

Any service defined in our `docker-compose.yml` can be scaled up from the Compose API; in this context, 'scaling' means launching multiple containers for the same service, which Docker Compose can route requests to and from.

1.  Scale up the `worker` service in our Dockercoins app to have two workers generating coin candidates by redeploying the app with the `--scale` flag, while checking the list of running containers before and after:

    ```bash
    [centos@node-0 dockercoins]$ docker-compose ps
    [centos@node-0 dockercoins]$ docker-compose up -d --scale worker=2
    [centos@node-0 dockercoins]$ docker-compose ps

            Name                       Command               State          Ports         
    -------------------------------------------------------------------------------------
    dockercoins_hasher_1    ruby hasher.rb                   Up      0.0.0.0:8002->80/tcp 
    dockercoins_redis_1     docker-entrypoint.sh redis ...   Up      6379/tcp             
    dockercoins_rng_1       python rng.py                    Up      0.0.0.0:8001->80/tcp 
    dockercoins_webui_1     node webui.js                    Up      0.0.0.0:8000->80/tcp 
    dockercoins_worker_1    python worker.py                 Up                                                     
    dockercoins_worker_2    python worker.py                 Up
    ```

    A new worker container has appeared in your list of containers.

2.  Look at the performance graph provided by the web frontend; the coin mining rate should have doubled. Also check the logs using the logging API we learned in the last exercise; you should see a second `worker` instance reporting.

## Investigating Bottlenecks

1.  Try running `top` to inspect the system resource usage; it should still be fairly negligible. So, keep scaling up your workers:

    ```bash
    [centos@node-0 dockercoins]$ docker-compose up -d --scale worker=10
    [centos@node-0 dockercoins]$ docker-compose ps
    ```

2.  Check your web frontend again; has going from 2 to 10 workers provided a 5x performance increase? It seems that something else is bottlenecking our application; any distributed application such as Dockercoins needs tooling to understand where the bottlenecks are, so that the application can be scaled intelligently.

3.  Look in `docker-compose.yml` at the `rng` and `hasher` services; they're exposed on host ports 8001 and 8002, so we can use `httping` to probe their latency. 

    ```bash
    [centos@node-0 dockercoins]$ httping -c 5 localhost:8001
    [centos@node-0 dockercoins]$ httping -c 5 localhost:8002
    ```

    `rng` on port 8001 has the much higher latency, suggesting that it might be our bottleneck. A random number generator based on entropy won't get any better by starting more instances on the same machine; we'll need a way to bring more nodes into our application to scale past this, which we'll explore in the next unit on Docker Swarm.

4.  For now, shut your app down:

    ```bash
    [centos@node-0 dockercoins]$ docker-compose down
    ```

## Conclusion

In this exercise, we saw how to scale up a service defined in our Compose app using the `--scale` flag. Also, we saw how crucial it is to have detailed monitoring and tooling in a microservices-oriented application, in order to correctly identify bottlenecks and take advantage of the simplicity of scaling with Docker.
