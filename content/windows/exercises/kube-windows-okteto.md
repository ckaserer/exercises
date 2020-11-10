# Installing okteto on Windows

By the end of this exercise, you should be able to:

 - Use okteto from the Commandline of your workstation

## Download okteto

1.  On your windows machine download the okteto binary from

   ```
   https://okteto.com/docs/getting-started/installation/index.html
   ```

2. Store it in a location of your choosing. We recommend you store it in

    ```
    C:\Program Files\okteto\okteto.exe
    ```

## Add okteto to PATH

1. Open the Start Search, type in "env", and choose "Edit the system environment variable":

   <img src="../media/windows-path-1-start-menu.png" style="height: auto !important; width: 400px !important" />

2. Click the "Environment Variables..." button.

    <img src="../media/windows-path-2-system-properties.png" style="height: auto !important; width: 600px !important" />

3. Set the PATH variable to include the okteto folder by selecting the System Variable "PATH" and use the edit button to modify the selected variable. In the edit window add "C:\Program Files\okteto" as new entry at the bottom.
    
    <img src="../media/windows-path-3-select-row-and-edit.png" style="height: auto !important; width: 600px !important" />

   Dismiss all of the dialogs by choosing "OK". Your changes are now saved!

## Check that okteto is working

1. Open a Terminal on your Workstation and execute okteto to get the default help page of okteto.

    ```
    > okteto
    ```

## Conclusion

At this point, we have a the okteto set up on our Windows machine and can use it via the commandline.