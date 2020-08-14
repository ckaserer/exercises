# Installing Kubernetes

By the end of this exercise, you should be able to:

 - Set up a Kubernetes cluster with one master and one node

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

6.  Execute the join command you found above when initializing Kubernetes on `kube-1` (you'll need to add `sudo` to the start, and `--ignore-preflight-errors=SystemVerification` to the end), and then check the status back on `kube-0`:

    ```bash
    [centos@kube-1 ~]$ sudo kubeadm join ... --ignore-preflight-errors=SystemVerification
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
    calico-etcd-pfhj4                          1/1       Running   1          5h
    calico-kube-controllers-559c657d6d-ztk8c   1/1       Running   1          5h
    calico-node-89k9v                          2/2       Running   0          4h
    calico-node-brqxz                          2/2       Running   2          5
    coredns-78fcdf6894-gtj87                   1/1       Running   1          5h
    coredns-78fcdf6894-nz2kw                   1/1       Running   1          5h
    etcd-kube-0                                1/1       Running   1          5h
    kube-apiserver-kube-0                      1/1       Running   1          5h
    kube-controller-manager-kube-0             1/1       Running   1          5h
    kube-proxy-vgrtm                           1/1       Running   0          4h
    kube-proxy-ws2z5                           1/1       Running   0          5h
    kube-scheduler-kube-0                      1/1       Running   1          5h
    ```

    We can see the pods running on the master: etcd, api-server, controller manager and scheduler, as well as calico and DNS infrastructure pods deployed when we installed calico. 

## Conclusion

At this point, we have a Kubernetes cluster with one master and one worker ready to accept workloads. 
