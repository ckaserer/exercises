# Instructor Demo: Kubernetes Basics

In this demo, we'll illustrate:

 - Setting up a Kubernetes cluster with one master and two nodes
 - Scheduling a pod, including the effect of taints on scheduling
 - Namespaces shared by containers in a pod

> *Note:* At the moment, support for Kubernetes nodes on Windows is still developing. In these exercises, we'll explore Kubernetes on linux to get familiar with Kubernetes objects and scheduling, which will work very similarly on Windows. Furthermore, Kubernetes masters will for the near future remain linux-only; stay tuned to updates in Docker's Universal Control Plane for upcoming tools for bootstrapping mixed linux / windows Kubernetes clusters.

## Connecting to Linux Nodes

The easiest way to connect to your Linux nodes will be via PuTTY, which is already installed on your Windows nodes (see the desktop shortcut). Provide the public IP for `kube-0`, hit *Open*, and provide the username and password that your instructor will provide you.

## Initializing Kubernetes

1.  On `kube-0`, initialize the cluster with `kubeadm`:
    
    ```bash
    [centos@kube-0 ~]$ sudo kubeadm init --pod-network-cidr=192.168.0.0/16 \
        --ignore-preflight-errors=SystemVerification
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
    [centos@kube-0 ~]$ mkdir -p $HOME/.kube
    [centos@kube-0 ~]$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    [centos@kube-0 ~]$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```

3.  List all your nodes in the cluster:

    ```bash
    [centos@kube-0 ~]$ kubectl get nodes
    ```
    
    Which should output something like:

    ```bash
    NAME      STATUS     ROLES     AGE       VERSION
    kube-0    NotReady   master    2h        v1.11.1
    ```

    The `NotReady` status indicates that we must install a network for our cluster.

4.  Let's install the Calico network driver:

    ```bash
    [centos@kube-0 ~]$ kubectl apply -f https://bit.ly/2v9yaaV
    ```

5.  After a moment, if we list nodes again, ours should be ready:

    ```bash
    [centos@kube-0 ~]$ kubectl get nodes -w
    NAME      STATUS     ROLES     AGE       VERSION
    kube-0    NotReady   master    1m        v1.11.1
    kube-0    NotReady   master    1m        v1.11.1
    kube-0    NotReady   master    1m        v1.11.1
    kube-0    Ready     master    2m        v1.11.1
    kube-0    Ready     master    2m        v1.11.1
    ```

## Exploring Kubernetes Scheduling

1.  Let's create a `demo-pod.yaml` file on `kube-0` after enabling Kubernetes on this single node. Use `nano demo-pod.yaml` to create the file:

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

    When done, save with `CTRL+o ENTER`, and quit with `CTRL+x`.

2.  Deploy the pod:

    ```bash
    [centos@kube-0 ~]$ kubectl create -f demo-pod.yaml
    ```

3.  Check to see if the pod is running:

    ```bash
    [centos@kube-0 ~]$ kubectl get pod demo-pod

    NAME       READY     STATUS    RESTARTS   AGE
    demo-pod   0/2       Pending   0          7s
    ```

    The status should be stuck in pending. Why is that?

4.  Let's attempt to troubleshoot by obtaining some information about the pod:

    ```bash
    [centos@kube-0 ~]$ kubectl describe pod demo-pod
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
    [centos@kube-0 ~]$ kubectl describe nodes
    ```

    If we scroll a little, we should see a field titled `Taints`, and it should say something like:

    ```bash
    Taints:  node-role.kubernetes.io/master:NoSchedule
    ```

    By default, Kubernetes masters carry a taint that disallows scheduling pods on them. While this can be overridden, it is best practice to not allow pods to get scheduled on master nodes, in order to ensure the stability of your cluster.

6.  Execute the join command you found above when initializing Kubernetes on `kube-1` (you'll need to add `sudo` to the start, and `--ignore-preflight-errors=SystemVerification` to the end), and then check the status back on `kube-0`:

    ```bash
    [centos@kube-1 ~]$ sudo kubeadm join...--ignore-preflight-errors=SystemVerification
    [centos@kube-0 ~]$ kubectl get nodes
    ```

    After a few moments, there should be two nodes listed - all with the `Ready` status.

7.  Let's see what system pods are running on our cluster:

    ```bash
    [centos@kube-0 ~]$ kubectl get pods -n kube-system
    ```

    which results in something similar to this:

    ```bash
    NAME                                       READY     STATUS    RESTARTS   AGE
    calico-etcd-69x56                          1/1       Running   0          5m
    calico-kube-controllers-559c657d6d-2nx8f   1/1       Running   0          5m
    calico-node-dwl9v                          2/2       Running   0          5m
    calico-node-gv9mt                          2/2       Running   0          58s
    coredns-78fcdf6894-44tfj                   1/1       Running   0          56m
    coredns-78fcdf6894-w97xx                   1/1       Running   0          56m
    etcd-kube-0                                1/1       Running   0          55m
    kube-apiserver-kube-0                      1/1       Running   0          55m
    kube-controller-manager-kube-0             1/1       Running   0          55m
    kube-proxy-c7wpf                           1/1       Running   0          58s
    kube-proxy-nnsj6                           1/1       Running   0          56m
    kube-scheduler-kube-0                      1/1       Running   0          55m
    ```

    We can see the pods running on the master: etcd, api-server, controller manager and scheduler, as well as calico and DNS infrastructure pods deployed when we installed calico.

8.  Finally, let's check the status of our demo pod now:

    ```bash
    [centos@kube-0 ~]$ kubectl get pod demo-pod
    ```

    Everything should be working correctly with 2/2 containers in the pod running, now that there is an un-tainted node for the pod to get scheduled on.

## Exploring Containers in a Pod

1.  Let's interact with the centos container running in demo-pod by getting a shell in it:

    ```bash
    [centos@kube-0 ~]$ kubectl exec -it -c mydemo demo-pod -- /bin/bash
    ```

    Try listing the processes in this container:

    ```bash
    [root@demo-pod /]# ps -aux    
    USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
    root         1  0.0  0.0  24860  1992 ?        Ss   14:48   0:00 ping 8.8.8.8
    root         5  0.0  0.0  11832  3036 pts/0    Ss   14:48   0:00 /bin/bash
    root        20  0.0  0.0  51720  3508 pts/0    R+   14:48   0:00 ps -aux
    ```

    We can see the ping process we containerized in our yaml file running as PID 1 inside this container - this is characteristic of PID kernel namespaces on linux.

2.  Try reaching Nginx:

    ```bash
    [root@demo-pod /]# curl localhost:80
    ```

    You should see the HTML for the default nginx landing page. Notice the difference here from a regular container; we were able to reach our nginx deployment from our centos container on a port on localhost. The nginx and centos containers share a network namespace and therefore all their ports, since they are part of the same pod.

## Conclusion

In this demo, we saw two scheduling innovations Kubernetes offers: taints, which provide 'anti-affinity', or reasons not to schedule a pod on a given node; and pods, which are groups of containers that are always scheduled on the same node, and share network, IPC and hostname namespaces. These are both examples of Kubernetes's highly expressive scheduling, and are both difficult to reproduce with the simpler scheduling offered by Swarm.
