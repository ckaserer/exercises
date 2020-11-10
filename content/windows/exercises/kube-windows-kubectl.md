# Installing Kubectl on Windows

By the end of this exercise, you should be able to:

 - Use kubectl on your windows machine

## Download Kubectl

1.  On your Windows Machine download the kubectl binary from

     ```
     https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-windows
     ```

2. Store it in a location of your choosing. We recommend you store it in

    ```
    C:\Program Files\kubectl\kubectl.exe
    ```

## Add Kubectl to PATH

1. Open the Start Search, type in "env", and choose "Edit the system environment variable":

   <img src="../media/windows-path-1-start-menu.png" style="height: auto !important; width: 400px !important" />

2. Click the "Environment Variables..." button.

    <img src="../media/windows-path-2-system-properties.png" style="height: auto !important; width: 600px !important" />

3. Set the PATH variable to include the kubectl folder by selecting the system variable "PATH" and use the edit button to modify the selected variable. In the edit window add "C:\Program Files\kubectl" as new entry at the bottom.
    
    <img src="../media/windows-path-3-select-row-and-edit.png" style="height: auto !important; width: 600px !important" />

   Dismiss all of the dialogs by choosing "OK". Your changes are now saved!

## Check that kubectl is working

1. Open a Terminal on your Workstation and execute kubectl to get the default help page of kubectl.

    ```
    > kubectl
    ```

## Conclusion

At this point, we have a the kubectl set up on our Windows Workstation and can use it via the commandline.