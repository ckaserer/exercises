# Installing Kubectl on Windows

By the end of this exercise, you should be able to:

 - Connect to your Kuberentes cluster from your windows machine

## Download your kubeconfig

1.  On your windows machine download the kubeconfig from your master node to your workstation.

   ```
   /home/centos/.kube/config
   ```

2. Place the kubeconfig inside your user folder on windows inside a folder named "kube"

   ```
   kube\config
   ```

## Add KUBECONFIG to PATH

1. Open the Start Search, type in "env", and choose "Edit the system environment variable":

   <img src="../media/windows-path-1-start-menu.png" style="height: auto !important; width: 400px !important" />

2. Click the "Environment Variables..." button.

   <img src="../media/windows-path-2-system-properties.png" style="height: auto !important; width: 600px !important" />

3. ADD a KUBECONFIG variable with location of your "kube/config" as value.
    
   <img src="../media/windows-path-3-select-row-and-edit.png" style="height: auto !important; width: 600px !important" />

   Dismiss all of the dialogs by choosing "OK". Your changes are now saved!

## Check that kubectl is working with your kubeconfig

1. Open a Terminal on your Workstation and execute the follwing command to get a list of nodes in your kubernetes cluster.

    ```
    > kubectl get nodes
    ```

## Conclusion

At this point, we have a the kubectl set up on our windows machine and can interact with the kubernetes cluster via the commandline.