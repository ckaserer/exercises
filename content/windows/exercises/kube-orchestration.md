# Kubernetes Orchestration

By the end of this exercise, you should be able to:

 - Define and launch basic pods, replicaSets and deployments using `kubectl`
 - Get metadata, configuration and state information about a kubernetes object using `kubectl describe`
 - Update an image for a pod in a running kubernetes deployment

## Creating Pods

1.  On your master node, create a yaml file `pod.yaml` to describe a simple pod with the following content:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
    ```

2.  Deploy your pod:

    ```bash
    [centos@kube-0 ~]$ kubectl create -f pod.yaml
    ```

3.  Confirm your pod is running:

    ```bash
    [centos@kube-0 ~]$ kubectl get pod demo
    ```

4.  Get some metadata about your pod:

    ```bash
    [centos@kube-0 ~]$ kubectl describe pod demo
    ```

5.  Delete your pod:

    ```bash
    [centos@kube-0 ~]$ kubectl delete pod demo
    ```

6.  Modify `pod.yaml` to create a second container inside your pod:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
      - name: sidecar
        image: centos:7
        command: ["ping"]
        args: ["8.8.8.8"]
    ```

7.  Deploy this new pod, and create a bash shell inside the container named `sidecar`:

    ```bash
    [centos@kube-0 ~]$ kubectl create -f pod.yaml
    [centos@kube-0 ~]$ kubectl exec -c=sidecar -it demo -- /bin/bash
    ```

8.  From within the `sidecar` container, fetch the nginx landing page on the default port 80 using `localhost`:

    ```bash
    [root@demo /]# curl localhost:80 
    ```

    You should see the html of the nginx landing page. Note **these containers can reach each other on localhost**, meaning they are sharing a network namespace. Now list the processes in your `sidecar` container:

    ```bash
    [root@demo /]# ps -aux
    ```

    You should see the `ping` process we containerized, the shell we created to explore this container using `kubectl exec`, and the `ps` process itself - but no `nginx`. While a network namespace is shared between the containers, they still have their own PID namespace (for example).

9.  Finally, remember to exit out of this pod, and delete it:

    ```bash
    [root@demo /]# exit
    [centos@kube-0 ~]$ kubectl delete pod demo
    ```

## Creating ReplicaSets

1.  On your master node, create a yaml file `replicaset.yaml` to describe a simple replicaSet with the following content:

    ```yaml
    apiVersion: apps/v1
    kind: ReplicaSet
    metadata:
      name: rs-demo
    spec:
      replicas: 3
      selector:
        matchLabels:
          component: reverse-proxy
      template:
        metadata:
          labels:
            component: reverse-proxy
        spec:
          containers:
          - name: nginx
            image: nginx:1.7.9
    ```

    Notice especially the `replicas` key, which defines how many copies of this pod to create, and the `template` section; this defines the pod to replicate, and is described almost exactly like the first pod definition we created above. The difference here is the required presence of the `labels` key in the pod's metadata, which must match the `selector -> matchLabels` item in the specification of the replicaSet.

2.  Deploy your replicaSet, and get some state information about it:

    ```bash
    [centos@kube-0 ~]$ kubectl create -f replicaset.yaml
    [centos@kube-0 ~]$ kubectl describe replicaset rs-demo
    ```

    After a few moments, you should see something like

    ```bash
    Name:         rs-demo
    Namespace:    default
    Selector:     component=reverse-proxy
    Labels:       component=reverse-proxy
    Annotations:  <none>
    Replicas:     3 current / 3 desired
    Pods Status:  3 Running / 0 Waiting / 0 Succeeded / 0 Failed
    Pod Template:
      Labels:  component=reverse-proxy
      Containers:
       nginx:
        Image:        nginx:1.7.9
        Port:         <none>
        Host Port:    <none>
        Environment:  <none>
        Mounts:       <none>
      Volumes:        <none>
    Events:
      Type    Reason            Age   From                   Message
      ----    ------            ----  ----                   -------
      Normal  SuccessfulCreate  35s   replicaset-controller  Created pod: rs-demo-jxmjj
      Normal  SuccessfulCreate  35s   replicaset-controller  Created pod: rs-demo-dmdtf
      Normal  SuccessfulCreate  35s   replicaset-controller  Created pod: rs-demo-j62fx
    ```

    Note the replicaSet has created three pods as requested, and will reschedule them if they exit.

3.  Try killing off one of your pods, and reexamining the output of the above `describe` command. The `<pod name>` comes from the last three lines in the output above, such as `rs-demo-jxmjj`:

    ```bash
    [centos@kube-0 ~]$ kubectl delete pod <pod name>
    [centos@kube-0 ~]$ kubectl describe replicaset rs-demo
    ```

    The dead pod gets rescheduled by the replicaSet, similar to a failed task in Docker Swarm.

4.  Delete your replicaSet:

    ```bash
    [centos@kube-0 ~]$ kubectl delete replicaset rs-demo
    ```

## Creating Deployments

1.  On your master node, create a yaml file `deployment.yaml` to describe a simple deployment with the following content:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: nginx:1.7.9
    ```

    Notice this is the exact same structure as your replicaSet yaml above, but this time the `kind` is `Deployment`. Deployments create a replicaSet of pods, but add some deployment management functionality on top of them, such as rolling updates and rollback.

2.  Spin up your deployment, and get some state information:

    ```bash
    [centos@kube-0 ~]$ kubectl create -f deployment.yaml
    [centos@kube-0 ~]$ kubectl describe deployment nginx-deployment
    ```

    The `describe` command should return something like:

    ```bash
    Name:                   nginx-deployment
    Namespace:              default
    CreationTimestamp:      Thu, 24 May 2018 04:29:18 +0000
    Labels:                 <none>
    Annotations:            deployment.kubernetes.io/revision=1
    Selector:               app=nginx
    Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
    StrategyType:           RollingUpdate
    MinReadySeconds:        0
    RollingUpdateStrategy:  25% max unavailable, 25% max surge
    Pod Template:
      Labels:  app=nginx
      Containers:
       nginx:
        Image:        nginx:1.7.9
        Port:         <none>
        Host Port:    <none>
        Environment:  <none>
        Mounts:       <none>
      Volumes:        <none>
    Conditions:
      Type           Status  Reason
      ----           ------  ------
      Available      True    MinimumReplicasAvailable
      Progressing    True    NewReplicaSetAvailable
    OldReplicaSets:  <none>
    NewReplicaSet:   nginx-deployment-85f7784776 (3/3 replicas created)
    Events:
      Type    Reason             Age   From                   Message
      ----    ------             ----  ----                   -------
      Normal  ScalingReplicaSet  10s   deployment-controller  Scaled up replica set 
                                                              nginx-deployment-85f7784776
                                                              to 3
    ```

    Note the very last line, indicating this deployment actually created a replicaSet which it used to scale up to three pods.

3.  List your replicaSets and pods:

    ```bash
    [centos@kube-0 ~]$ kubectl get replicaSet
    [centos@kube-0 ~]$ kubectl get pod
    ```

    You should see one replicaSet and three pods created by your deployment.

4.  Upgrade the nginx image from `1.7.9` to `1.9.1`:

    ```bash
    [centos@kube-0 ~]$ kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1
    ```

5.  After a few seconds, `kubectl describe` your deployment as above again. You should see that the image has been updated, and that the old replicaSet has been scaled down to 0 replicas, while a new replicaSet (with your updated image) has been scaled up to 3 pods. List your replicaSets one more time:

    ```bash
    [centos@kube-0 ~]$ kubectl get replicaSets
    ```

    You should see something like

    ```bash
    NAME                          DESIRED   CURRENT   READY     AGE
    nginx-deployment-69df9ccbf8   3         3         3         4m
    nginx-deployment-85f7784776   0         0         0         9m
    ```

    Do a `kubectl describe replicaSet <replicaSet scaled down to 0>`; you should see that while no pods are running for this replicaSet, the old replicaSet's definition is still around so we can easily roll back to this version of the app if we need to.

6.  Clean up your cluster:

    ```bash
    [centos@kube-0 ~]$ kubectl delete deployment nginx-deployment
    ``` 

## Conclusion

In this exercise, you explored the basic scheduling objects of pods, replicaSets, and deployments. Each object is responsible for a different part of the orchestration stack; pods are the basic unit of scheduling, replicaSets do keep-alive and scaling, and deployments provide update and rollback functionality. In a sense, these objects all 'nest' one inside the next; by creating a deployment, you implicitly created a replicaSet which in turn created the corresponding pods. In most cases, you're better off creating deployments rather than replicaSets or pods directly; this way, you get all the orchestrating scheduling features you would expect in analogy to a Docker Swarm service.
