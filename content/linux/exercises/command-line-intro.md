# Appendix: A Brief Introduction to Bash

If you're not familiar with the common Linux commands (cd, ls, ps, sudo, etc.), this exercise is designed to lead you through the common linux commands that we use in the Docker training.

By the end of this exercise, you should be able to:

- Manage files and folders using Linux commands
- Inspect processes running on your machine and use some discovery tools.

Pre-requisites:

- A Linux machine.

## Managing Files and Folders

In this first part we will walk through common commands for creating and manipulating files and folders from the command line.

1.  Open a terminal.

2.  Terminals work by accepting text-based commands, and retuning text-based responses. Ask the terminal what directory you are currently in; in all our instructions, `$` represents the terminal prompt, and you should enter what you see *after* the prompt. Yours might look a bit different; in any case, type `pwd`:

    ```bash
    $ pwd
    ```

    `pwd` stands for Print Working Directory. You should see something like:

    ```bash
    /Users/ckaserer
    ```

    This means your terminal is currently in the `ckaserer` folder, which itself is in the `/Users` folder (yours will have different folder names, but the logic is the same).

3.  List the files and folders in your current directory:

    ```bash
    $ ls

    Applications    Documents   Library     Music       
    Projects        Desktop
    ```

    Here we show some typical output below the command; again, you only need to enter what comes after the command prompt, `ls` in this case. `ls` lists all the contents of your current directory.

4.  Change directory with `cd`:

    ```bash
    cd Desktop
    ```

    Again, your directories might be named differently - that's ok. Try to navigate to a directory you recognize the names of; `Desktop` or `Downloads` are common. 

5.  Use `ls` again to see what's in this directory. Compare what you see in your `Desktop` directory to what you actually see on your machine's desktop; the contents are identical. The terminal is just another way to browse the contents of your machine, based on programmatic text rather than visual analogies.

6.  Make a new folder on your desktop (or wherever you currently are):

    ```bash
    $ mkdir demo-dir
    ```

    If you do `ls` again, you'll see a new directory `demo-dir` has been made.

7.  Change directory to `demo-dir`, and open a new plain text file called `demo.txt` using the simple text editor `nano`:

    ```bash
    $ cd demo-dir
    $ nano demo.txt
    ```

    You're taken to `nano`'s text-based interface for creating a plain-text file. There are many other plain-text editors available, the most popular being `vim`, but `nano` is probably the simplest if this is your first time using a text editor from the command line.

8.  Add any text you want to your file, just by typing something.

9.  Save your file by pressing `CMD+O`, and pressing return when asked for a filename. Exit by typing `CMD+X`.

10. Dump the contents of your file to the screen:

    ```bash
    $ cat demo.txt
    ```

11. Make a copy of your file with `cp`:

    ```bash
    $ cp demo.txt demo.copy.txt
    ```

12. Move and rename your file with `mv`:

    ```bash
    $ mv demo.txt demo.moved.txt
    ```

13. Delete a file:

    ```bash
    $ rm demo.moved.txt
    ```

14. Check what directory you're in, then back up one level with the special `..` path, and check again:

    ```bash
    $ pwd

    /Users/ckaserer/Desktop/demo-dir

    $ cd ..
    $ pwd
    /Users/ckaserer/Desktop
    ```

    `cd ..` took us one level up in our directory tree, from `demo-dir` back out to the directory that contains it, `Desktop` in my example.

15. Delete your `demo-dir`, again with remove, but this time using the `-r` *flag*, which stands for recursive in order to delete the folder and all its contents:

    ```bash
    rm -r demo-dir
    ```
    
## Some Common Tools

In this section we will see the basic usage of different command line tools we'll see again when working with Docker.

### Inspecting Processes

1.  In the next steps we will use `ps` and `top`. Check whether these tools are existing in our system:
    
    ```
    $ which pwd
    ```
    
    `which` is a quick way to identify the location of executables and should return something similar to the following:
    
    ```
    /bin/pwd
    ```

    The `pwd` command we used above is actually a tiny program, and it lives in our filesystem at the path indicated by `which`. If `which` returns nothing, that means the requested program probably isn't installed on your machine.

2.  List all processes running in your system:
    
    ```
    $ ps -aux
    ```
    
    A long list of processes is returned.
    
    We will see later how to filter this output to extract only the information we need.
    
3.  There different other tools to inspect processes. Try for example showing the list of processes with usage details (cpu usage, memory, etc.):
    
    ```
    $ top
    ```
    
    Exit with `CTRL+C`.
    
### The Superuser
    
In some cases you want to run commands that require privileges that you don't have.

1.  Try creating a new user:
    
    ```
    $ adduser myName
    ```
    
    This should return `Permission denied`.
    
2.  Run the same command with `sudo`:
    
    ```
    $ sudo adduser myName
    ```
    
    Sudo runs the command with the privileges of the super user.
    
3.  List the existing users:
    
    ```
    $ cat /etc/passwd
    ```
    
    You should see the user `myName` in the bottom of the list.
    
### Pinging of an address

`ping` is a tool used to test the reachability of a network address.

1.  Send a ping to your `localhost`:
    
    ```
    $ ping localhost
    ```

    The ping should be successful. Interrupt it with `CTRL+C`.
    
2.  Try pinging an unreachable address:

    ```
    $ ping -c 3 192.168.1.1
    ```

    The flag `-c` stands for the count of the sent packets. If no device is plugged to your machine and has this address, the request should timeout after 3 packets with `100% packet loss`.

### Making HTTP Requests

Use the `curl` command to issue HTTP requests across the network.

1.  `curl` an example webpage:

    ```bash
    $ curl example.com
    ```

    You'll get some HTML corresponding to a dummy webpage, downloaded directly to your terminal.

### Working with Commands

#### Command piping

So far, every command we've used as accepted text as input, and returned text as output. We can send the text output from one command into the text input of another command using a *pipe*, `|`.

1.  Earlier we saw the `ps` command, to write a large table of all the processes running on our machine. We can send that table to `grep`, which is a text search tool that will pick out lines containing something we're interested in:

    ```bash
    $ ps -aux | grep 'ps'
    ```

    Rather than getting every process on the system, we can just pick out the `ps` process by text-searching for it using `grep`.

2.  Another common grep usage is with `cat`, to find a string in a file. Search your `/etc/passwd` file for the `root` user:

    ```bash
    cat /etc/passwd | grep root
    ```

    Instead of getting every user on the system, only lines with the string `root` are printed out, making it easier to findwhat you're looking for. 

#### Successive Commands

We can run several commands in a one liner using semicolon `;` or double-ampersand `&&`.

1.  Create a new directory:
    
    ```
    $ mkdir newDir
    ```
    
2.  We know that to remove a directory we need to use `rm -r`. Let's simulate a error by forgetting the `-r` flag, and immediately after removing we'll create a new directory with the same name:
    
    ```
    $ rm newDir ; mkdir newDir
    ```

    This should returns:
    
    ```
    rm: cannot remove ‘newDir’: Is a directory
    mkdir: cannot create directory ‘newDir’: File exists
    ```
    
    The semicolon `;` runs the second command even when the first command wasn't successful.

3.  Combining commands with the double-ampersand `&&` insures that the second command will run only if the first command was successful. Try the following:
    
    ```
    $ rm newDir && mkdir newDir
    ```
    
    This should return the error for the first command only:
    
    ```
    rm: cannot remove ‘newDir’: Is a directory
    ```

#### Breaking long commands

Some commands get too long, for example because it includes a long file path or it's a one liner that combines several commands. For better readability, you can break long commands into several lines using the backslash:

    ```
    $ mkdir aDirectoryWithAVeryLongName ;  \
        cd aDirectoryWithAVeryLongName ; \
        echo "this is a test file" > myTestFile ; \
        cat myTestFile ; cd ..
    ```

 This one liner will create a directory, cd into it, create a file, cat the content of the file, and finally change directory a level up.

## Conclusion

We saw most of the Linux commands that we will use in the actual Docker training. Feel free to discover more commands in the following cheat sheet: https://www.git-tower.com/blog/command-line-cheat-sheet/
