# Kubernetes Networking

By the end of this exercise, you should be able to:

 - Predict what routing tables rules calico will write to each host in your cluster
 - Route and load balance traffic to deployments using clusterIP and nodePort services
 - Reconfigure a deployment into a daemonSet (analogous to changing scheduling from 'replicated' to 'global' in a swarm service)

## Routing Traffic with Calico

1.  Make sure you're on the master node `kube-0`, and redeploy the nginx deployment defined in `deployment.yaml` from the last exercise.

2.  List your pods:

    ```bash
    [centos@kube-0 ~]$ kubectl get pods
    ```

3.  Get some metadata on one of the pods found in the last step:

    ```bash
    [centos@kube-0 ~]$ kubectl describe pods <pod name>
    ```

    which in my case results in:

    ```bash
    Name:               nginx-deployment-69df458bc5-cg4mk
    Namespace:          default
    Priority:           0
    PriorityClassName:  <none>
    Node:               kube-1/10.10.95.205
    Start Time:         Tue, 21 Aug 2018 14:47:48 +0000
    Labels:             app=nginx
                        pod-template-hash=2589014671
    Annotations:        <none>
    Status:             Running
    IP:                 192.168.126.80
    Controlled By:      ReplicaSet/nginx-deployment-69df458bc5
    Containers:
      nginx:
        Container ID:   docker://664616e...
        Image:          nginx:1.7.9
        Image ID:       docker-pullable://nginx@sha256:e3456c8...
        Port:           <none>
        Host Port:      <none>
        State:          Running
          Started:      Tue, 21 Aug 2018 14:47:50 +0000
        Ready:          True
        Restart Count:  0
        Environment:    <none>
        Mounts:
          /var/run/secrets/kubernetes.io/serviceaccount from default-token-5ggnn (ro)
    Conditions:
      Type              Status
      Initialized       True 
      Ready             True 
      ContainersReady   True 
      PodScheduled      True 
    Volumes:
      default-token-5ggnn:
        Type:        Secret (a volume populated by a Secret)
        SecretName:  default-token-5ggnn
        Optional:    false
    QoS Class:       BestEffort
    Node-Selectors:  <none>
    Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                     node.kubernetes.io/unreachable:NoExecute for 300s
    Events:
      Type    Reason     Age   From               Message
      ----    ------     ----  ----               -------
      Normal  Scheduled  1m    default-scheduler  Successfully assigned default/
                                                  nginx-deployment-69df458bc5-cg4mk 
                                                  to kube-1
      Normal  Pulled     1m    kubelet, kube-1    Container image "nginx:1.7.9" 
                                                  already present on machine
      Normal  Created    1m    kubelet, kube-1    Created container
      Normal  Started    1m    kubelet, kube-1    Started container
    ```

    We can see that in our case the pod has been deployed to `kube-1` as indicated near the top of the output, and the pod has an IP of `192.168.126.80`.

4.  Have a look at the routing table on `kube-0` using `ip route`, which for my example looks like:

    ```bash
    [centos@kube-0 ~]$ ip route

    default via 10.10.64.1 dev eth0 
    10.10.64.0/20 dev eth0  proto kernel  scope link  src 10.10.68.222 
    172.17.0.0/16 dev docker0  proto kernel  scope link  src 172.17.0.1 
    192.168.126.64/26 via 10.10.95.205 dev tunl0  proto bird onlink 
    blackhole 192.168.145.64/26  proto bird 
    192.168.145.65 dev cali6edd91665ff  scope link 
    192.168.145.66 dev calia9ee759be59  scope link
    ```

    Notice the fourth line; this rule was written by Calico to send any traffic on the 192.168.126.64/26 subnet (which the pod we examined above is on) to the host at IP 10.10.95.205 via IP in IP as indicated by the `dev tunl0` entry. Look at your own routing table and list of VM IPs; what are the corresponding subnets, pod IPs and host IPs in your case? Does that make sense based on the host you found for the nginx pod above?

5.  Curl your pod's IP on port 80 from `kube-0`; you should see the HTML for the nginx landing page. By default this pod is reachable at this IP from anywhere in the Kubernetes cluster.

6.  Head over to the node this pod got scheduled on (`kube-1` in the example above), and have a look at that host's routing table in the same way:

    ```bash
    [centos@kube-1 ~]$ ip route

    default via 10.10.80.1 dev eth0
    10.10.80.0/20 dev eth0  proto kernel  scope link  src 10.10.95.205
    172.17.0.0/16 dev docker0  proto kernel  scope link  src 172.17.0.1
    blackhole 192.168.126.64/26  proto bird
    192.168.126.78 dev calib0aa6a43271  scope link
    192.168.126.79 dev cali3489915b309  scope link
    192.168.126.80 dev cali2d894f7a3f6  scope link
    192.168.145.64/26 via 10.10.68.222 dev tunl0  proto bird onlink
    ```

    Again notice the second-to-last line; this time, the pod IP is routed to a `cali***` device, which is a virtual ethernet endpoint in the host's network namespace, providing a point of ingress into that pod. Once again try `curl <pod IP>:80` - you'll see the nginx landing page html as before.

7.  Back on `kube-0`, fetch the logs generated by the pod you've been curling:

    ```bash
    [centos@kube-0 ~]$ kubectl logs <pod name>

    10.10.52.135 - - [09/May/2018:13:58:42 +0000] 
        "GET / HTTP/1.1" 200 612 "-" "curl/7.29.0" "-"
    192.168.84.128 - - [09/May/2018:14:00:41 +0000] 
        "GET / HTTP/1.1" 200 612 "-" "curl/7.29.0" "-"
    ```

    We see records of the curls we preformed above; like Docker containers, these logs are the STDOUT and STDERR of the containerized processes.

## Routing and Load Balancing with Services

1.  Above we were able to hit nginx at the pod IP, but there is no guarantee this pod won't get rescheduled to a new IP. If we want a stable IP for this deployment, we need to create a `ClusterIP` service. In a file `cluster.yaml` on your master `kube-0`:

    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: cluster-demo
    spec:
      selector:
        app: nginx
      ports:
      - port: 8080
        targetPort: 80
    ```

    Create this service with `kubectl create -f cluster.yaml`. This maps the pod internal port 80 to the cluster wide external port 8080; furthermore, this IP and port will only be reachable from *within* the cluster. Also note the `selector: app: nginx` specification; that indicates that this service will route traffic to every pod that has `nginx` as the value of the `app` label in this namespace.

2.  Let's see what services we have now:

    ```bash
    [centos@kube-0 ~]$ kubectl get services
    NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
    kubernetes     ClusterIP   10.96.0.1       <none>        443/TCP    33m
    cluster-demo   ClusterIP   10.104.201.93   <none>        8080/TCP   48s
    ```

    The second one is the one we just created and we can see that a stable IP address and port `10.104.201.93:8080` has been assigned to our `nginx` service. 

3.  Let's try to access Nginx now, from any node in our cluster:

    ```bash
    [centos@kube-0 ~]$ curl <nginx CLUSTER-IP>:8080
    ```

    which should return the Nginx welcome page. Even if pods get rescheduled to new IPs, this clusterIP service will preserve a stable entrypoint for traffic to be load balanced across all pods matching the service's label selector.

4.  ClusterIP services are reachable only from within the Kubernetes cluster. If you want to route traffic to your pods from an external network, you'll need a NodePort service. On your master `kube-0`, create a file `nodeport.yaml`:

    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: nodeport-demo
    spec:
      type: NodePort
      selector:
          app: nginx
      ports:
      - port: 8080
        targetPort: 80
    ```

    Create this service with `kubectl create -f nodeport.yaml`. Notice this is exactly the same as the ClusterIP service definition, but now we're requesting a type NodePort. 

5.  Inspect this service's metadata:

    ```bash
    [centos@kube-0 ~]$ kubectl describe service nodeport-demo
    ```

    Notice the NodePort field: this is a randomly selected port from the range 30000-32767 where your pods will be reachable externally. Try visiting your nginx deployment at any public IP of your cluster, and the port you found above, and confirming you can see the nginx landing page.

6.  Clean up the objects you created in this section:

    ```bash
    [centos@kube-0 ~]$ kubectl delete deployment nginx-deployment
    [centos@kube-0 ~]$ kubectl delete service cluster-demo
    [centos@kube-0 ~]$ kubectl delete service nodeport-demo
    ```

## Optional: Deploying DockerCoins onto the Kubernetes Cluster

1.  First deploy Redis via `kubectl create deployment`:

    ```bash
    [centos@kube-0 ~]$ kubectl create deployment redis --image=redis
    ```

2.  And now all the other deployments. To avoid too much typing we do that in a loop:

    ```bash
    [centos@kube-0 ~]$ for DEPLOYMENT in hasher rng webui worker; do
        kubectl create deployment $DEPLOYMENT \
            --image=training/dockercoins-${DEPLOYMENT}:1.0
    done
    ```

3.  Let's see what we have:

    ```bash
    [centos@kube-0 ~]$ kubectl get pods -o wide -w
    ```

    in my case the result is:

    ```bash
    hasher-6c64f78655-rgjk5   1/1       Running   0          53s       10.36.0.1   kube-1
    redis-75586d7d7c-mmjg7    1/1       Running   0          5m        10.44.0.2   kube-1
    rng-d94d56d4f-twlwz       1/1       Running   0          53s       10.44.0.1   kube-1
    webui-6d8668984d-sqtt8    1/1       Running   0          52s       10.36.0.2   kube-1
    worker-56756ddbb8-lbv9r   1/1       Running   0          52s       10.44.0.3   kube-1
    ```

    pods have been distributed across our cluster.

4.  We can also look at some logs:

    ```bash
    [centos@kube-0 ~]$ kubectl logs deploy/rng
    [centos@kube-0 ~]$ kubectl logs deploy/worker
    ```

    The `rng` service (and also the `hasher` and `webui` services) seem to work fine but the `worker` service reports errors. The reason is that unlike on Swarm, Kubernetes does not automatically provide a stable networking endpoint for deployments. We need to create at least a `ClusterIP` service for each of our deployments so they can communicate.

5.  List your current services:

    ```bash
    [centos@kube-0 ~]$ kubectl get services
    NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
    kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   46m
    ```

6.  Expose the `redis`, `rng` and `hasher` internally to your cluster, specifying the correct internal port:

    ```bash
    [centos@kube-0 ~]$ kubectl expose deployment redis --port 6379
    [centos@kube-0 ~]$ kubectl expose deployment rng --port 80
    [centos@kube-0 ~]$ kubectl expose deployment hasher --port 80
    ```

7.  List your services again:

    ```bash
    [centos@kube-0 ~]$ kubectl get services
    NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
    hasher       ClusterIP   10.108.207.22    <none>        80/TCP     20s
    kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP    47m
    redis        ClusterIP   10.100.14.121    <none>        6379/TCP   31s
    rng          ClusterIP   10.111.235.252   <none>        80/TCP     26s
    ```

    Evidently `kubectl expose` creates `ClusterIP` services allowing stable, internal reachability for your deployments, much like you did via yaml manifests for your nginx deployment in the last section. See the `kubectl` api docs for more command-line alternatives to yaml manifests.

8.  Get the logs of the worker again:

    ```bash
    [centos@kube-0 ~]$ kubectl logs deploy/worker
    ```

    This time you should see that the `worker` recovered (give it at least 10 seconds to do so). The `worker` can now access the other services.

9.  Now let's expose the `webui` to the public using a service of type `NodePort`:

    ```bash
    [centos@kube-0 ~]$ kubectl expose deploy/webui --type=NodePort --port 80
    ```

10. List your services one more time:

    ```bash
    [centos@kube-0 ~]$ kubectl get services
    NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
    hasher       ClusterIP   10.108.207.22    <none>        80/TCP         2m
    kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP        49m
    redis        ClusterIP   10.100.14.121    <none>        6379/TCP       2m
    rng          ClusterIP   10.111.235.252   <none>        80/TCP         2m
    webui        NodePort    10.108.88.182    <none>        80:32015/TCP   33s
    ```

    Notice the `NodePort` service created for `webui`. This type of service provides similar behavior to the Swarm L4 mesh net: a port (32015 in my case) has been reserved across the cluster; any external traffic hitting any cluster IP on that port will be directed to port 80 inside a `webui` pod.

11. Visit your Dockercoins web ui at `http://<node IP>:<port>`, where `<node IP>` is the public IP address any of your cluster members. You should see the dashboard of our DockerCoins application.

12. Let's scale up the worker a bit and see the effect of it:

    ```bash
    [centos@kube-0 ~]$ kubectl scale deploy/worker --replicas=10
    ```

    Observe the result of this scaling in the browser. We do not really get a 10-fold increase in throughput, just as when we deployed DockerCoins on swarm; the `rng` service is causing a bottleneck.

13. To scale up, we want to run an instance of `rng` on each node of the cluster. For this we use a `DaemonSet`. We do this by using a yaml file that captures the desired configuration, rather than through the CLI.

    Create a file `deploy-rng.yaml` as follows:

    ```bash
    [centos@kube-0 ~]$ kubectl get deploy/rng -o yaml --export > deploy-rng.yaml
    ```

    Note: `--export` will remove "cluster-specific" information

14. Edit this file to make it describe a `DaemonSet` instead of a `Deployment`:
    - change `kind` to `DaemonSet`
    - remove the `progressDeadlineSeconds` field
    - remove the `replicas` field
    - remove the `strategy` block (which defines the rollout mechanism for a deployment)
    - remove the `status: {}` line at the end

15. Now apply this YAML file to create the `DaemonSet`:

    ```bash
    [centos@kube-0 ~]$ kubectl apply -f deploy-rng.yaml
    ```

16. We can now look at the `DaemonSet` that was created:

    ```bash
    [centos@kube-0 ~]$ kubectl get daemonset

    NAME      DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
    rng       1         1         1         1            1           <none>          1m
    ```

    Since we only have one workload-bearing node in our cluster (`kube-1`), we still only get one rng pod and no performance improvement - but, if we added more non-master nodes to our Kubernetes cluster, they would get random number generator pods scheduled on them as they joined, relaxing the bottleneck.

17. If we do a `kubectl get all` we will see that we now have both a `deployment.apps/rng` AND a `daemonset.apps/rng`. Deployments are not just converted to DaemonSets. Let's delete the `rng` deployment:

    ```bash
    [centos@kube-0 ~]$ kubectl delete deploy/rng
    ```

18. Clean up your resources when done:

    ```bash
    [centos@kube-0 ~]$ for D in redis hasher rng webui; \
        do kubectl delete svc/$D; done
    [centos@kube-0 ~]$ for D in redis hasher webui worker; \
        do kubectl delete deploy/$D; done
    [centos@kube-0 ~]$ kubectl delete ds/rng
    ```

19. Make sure that everything is cleared:

    ```bash
    [centos@kube-0 ~]$ kubectl get all
    ```

    should only show the `svc/kubernetes` resource.

## Conclusion

In this exercise, we looked at some of the key Kubernetes service objects that provide routing and load balancing for collections of pods; clusterIP for internal communication, analogous to Swarm's VIPs, and NodePort, for routing external traffic to an app similarly to Swarm's L4 mesh net. We also briefly touched on the inner workings of Calico, one of many Kubernetes network plugins and the one that ships natively with Docker's Enterprise Edition product. The key networking difference between Swarm and Kubernetes is their approach to default firewalling; while Swarm firewalls software defined networks automatically, all pods can reach all other pods on a Kube cluster, in Calico's case via the BGP-updated control plane and IP-in-IP data plane you explored above.
