# Instructor Demo: Kubernetes Basics

In this demo, we'll illustrate:

 - Setting up a Kubernetes cluster with one master and two nodes
 - Scheduling a pod, including the effect of taints on scheduling
 - Namespaces shared by containers in a pod

## Initializing Kubernetes

1.  On `node-0`, initialize the cluster with `kubeadm`:
    
    ```bash
    [centos@node-0 ~]$ sudo kubeadm init --pod-network-cidr=192.168.0.0/16 \
        --ignore-preflight-errors=SystemVerification \
        --control-plane-endpoint $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    ```

    If successful, the output will end with a join command:

    ```bash
    ...
    You can now join any number of machines by running the following on each node
    as root:

      kubeadm join 10.10.29.54:6443 --token xxx --discovery-token-ca-cert-hash sha256:yyy
    ```

2.  To start using you cluster, you need to run:

    ```bash
    [centos@node-0 ~]$ mkdir -p $HOME/.kube
    [centos@node-0 ~]$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    [centos@node-0 ~]$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

3.  List all your nodes in the cluster:

    ```bash
    [centos@node-0 ~]$ kubectl get nodes
    ```
    
    Which should output something like:

    ```bash
    NAME      STATUS     ROLES     AGE       VERSION
    node-0    NotReady   master    2h        v1.11.1
    ```

    The `NotReady` status indicates that we must install a network for our cluster.

4.  Let's install the Calico network driver:

    ```bash
    [centos@node-0 ~]$ kubectl apply -f https://bit.ly/2CubzwM
    ```

5.  After a moment, if we list nodes again, ours should be ready:

    ```bash
    [centos@node-0 ~]$ kubectl get nodes -w
    NAME      STATUS     ROLES     AGE       VERSION
    node-0    NotReady   master    1m        v1.11.1
    node-0    NotReady   master    1m        v1.11.1
    node-0    NotReady   master    1m        v1.11.1
    node-0    Ready     master    2m        v1.11.1
    node-0    Ready     master    2m        v1.11.1
    ```

## Exploring Kubernetes Scheduling

1.  Let's create a `demo-pod.yaml` file on `node-0` after enabling Kubernetes on this single node:

    ```bash  
    apiVersion: v1
    kind: Pod
    metadata:
      name: demo-pod
    spec:
      volumes:
      - name: shared-data
        emptyDir: {}
      containers:
      - name: nginx
        image: nginx
      - name: mydemo
        image: centos:7
        command: ["ping", "8.8.8.8"]
    ```

2.  Deploy the pod:

    ```bash
    [centos@node-0 ~]$ kubectl create -f demo-pod.yaml
    ```

3.  Check to see if the pod is running:

    ```bash
    [centos@node-0 ~]$ kubectl get pod demo-pod

    NAME       READY     STATUS    RESTARTS   AGE
    demo-pod   0/2       Pending   0          7s
    ```

    The status should be stuck in pending. Why is that?

4.  Let's attempt to troubleshoot by obtaining some information about the pod:

    ```bash
    [centos@node-0 ~]$ kubectl describe pod demo-pod
    ```

    In the bottom section titled `Events:`, we should see something like this:

    ```bash
    ...
    Events:
      Type     Reason            ...  Message
      ----     ------            ...  -------
      Warning  FailedScheduling  ...  0/1 nodes are available: 1 node(s) 
                                      had taints that the pod didn't tolerate.
    ```

    Note how it states that the one node in your cluster has a taint, which is Kubernetes's way of saying there's a reason you might not want to schedule pods there.

5.  Get some state and config information about your single kubernetes node:

    ```bash
    [centos@node-0 ~]$ kubectl describe nodes
    ```

    If we scroll a little, we should see a field titled `Taints`, and it should say something like:

    ```bash
    Taints:  node-role.kubernetes.io/master:NoSchedule
    ```

    By default, Kubernetes masters carry a taint that disallows scheduling pods on them. While this can be overridden, it is best practice to not allow pods to get scheduled on master nodes, in order to ensure the stability of your cluster.

6.  Execute the join command you found above when initializing Kubernetes on `node-1` and `node-2` (you'll need to add `sudo` to the start, and `--ignore-preflight-errors=SystemVerification` to the end), and then check the status back on `node-0`:

    ```bash
    [centos@node-1 ~]$ sudo kubeadm join...--ignore-preflight-errors=SystemVerification
    [centos@node-2 ~]$ sudo kubeadm join...--ignore-preflight-errors=SystemVerification
    [centos@node-0 ~]$ kubectl get nodes
    ```

    After a few moments, there should be three nodes listed - all with the `Ready` status.

7.  Let's see what system pods are running on our cluster:

    ```bash
    [centos@node-0 ~]$ kubectl get pods -n kube-system
    ```

    which results in something similar to this:

    ```bash
    NAME                                       READY     STATUS    RESTARTS   AGE
    calico-etcd-pfhj4                          1/1       Running   1          5h
    calico-kube-controllers-559c657d6d-ztk8c   1/1       Running   1          5h
    calico-node-89k9v                          2/2       Running   0          4h
    calico-node-brqxz                          2/2       Running   2          5h
    calico-node-zsmh2                          2/2       Running   1          41s
    coredns-78fcdf6894-gtj87                   1/1       Running   1          5h
    coredns-78fcdf6894-nz2kw                   1/1       Running   1          5h
    etcd-node-0                                1/1       Running   1          5h
    kube-apiserver-node-0                      1/1       Running   1          5h
    kube-controller-manager-node-0             1/1       Running   1          5h
    kube-proxy-qxfzt                           1/1       Running   0          41s
    kube-proxy-vgrtm                           1/1       Running   0          4h
    kube-proxy-ws2z5                           1/1       Running   0          5h
    kube-scheduler-node-0                      1/1       Running   1          5h
    ```

    We can see the pods running on the master: etcd, api-server, controller manager and scheduler, as well as calico and DNS infrastructure pods deployed when we installed calico.

8.  Finally, let's check the status of our demo pod now:

    ```bash
    [centos@node-0 ~]$ kubectl get pod demo-pod
    ```

    Everything should be working correctly with 2/2 containers in the pod running, now that there are un-tainted nodes for the pod to get scheduled on.

## Exploring Containers in a Pod

1.  Let's interact with the centos container running in demo-pod by getting a shell in it:

    ```bash
    [centos@node-0 ~]$ kubectl exec -it -c mydemo demo-pod -- /bin/bash
    ```

    Try listing the processes in this container:

    ```bash
    [root@demo-pod /]# ps -aux    
    USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    root         1  0.0  0.0  24860  1992 ?        Ss   14:48   0:00 ping 8.8.8.8
    root         5  0.0  0.0  11832  3036 pts/0    Ss   14:48   0:00 /bin/bash
    root        20  0.0  0.0  51720  3508 pts/0    R+   14:48   0:00 ps -aux
    ```

    We can see the ping process we containerized in our yaml file running as PID 1 inside this container, just like we saw for plain containers.

2.  Try reaching Nginx:

    ```bash
    [root@demo-pod /]# curl localhost:80
    ```

    You should see the HTML for the default nginx landing page. Notice the difference here from a regular container; we were able to reach our nginx deployment from our centos container on a port on localhost. The nginx and centos containers share a network namespace and therefore all their ports, since they are part of the same pod.

## Conclusion

In this demo, we saw two scheduling innovations Kubernetes offers: taints, which provide 'anti-affinity', or reasons not to schedule a pod on a given node; and pods, which are groups of containers that are always scheduled on the same node, and share network, IPC and hostname namespaces. These are both examples of Kubernetes's highly expressive scheduling, and are both difficult to reproduce with the simpler scheduling offered by Swarm.
