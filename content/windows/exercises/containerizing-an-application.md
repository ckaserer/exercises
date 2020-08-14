# Containerizing an Application

In this exercise, you'll be provided with the application logic of a simple three tier application; your job will be to write Dockerfiles to containerize each tier, and write a Docker Compose file to orchestrate the deployment of that app. This application serves a website that presents cat gifs pulled from a database. The tiers are as follows:

- **Database**: Microsoft SQL Server
- **API**: ASP.NET framework application
- **Frontend**: ASP.NET core application

Basic success means writing the Dockerfiles and docker-compose file needed to deploy this application to your orchestrator of choice; to go beyond this, think about minimizing image size, maximizing image performance, and making good choices regarding configuration management.

Start by cloning the source code for this app:

```powershell
PS: node-0 Administrator> git clone -b ee3.0 `
    https://github.com/docker-training/fundamentals-final-win.git
```

## Containerizing the Database

1.  Navigate to `fundamentals-final-win/database` to find the config for your database tier. 

2.  Begin writing a Dockerfile for your Microsoft SQL Server database image by choosing an appropriate base image. Your developers gave you the following information about stating up and configuring your database tier:

3.  Your developers have provided you with SQL configuration file `init-db.sql` and startup script `start.ps1`. Both of these need to be present in `C:\`.

4.  The database must be initialized by the command `powershell .\start -sa_password $env:sa_password -Verbose`. The `start.ps1` script expects two environment variables to be defined:

    - `ACCEPT_EULA` = `Y`
    - `sa_password` = `P@ssw0rd` 

5.  Finish writing a Dockerfile to containerize your database tier, build the image as `mssql:dev`, and prove that things are working and configured correctly by standing up a container, connecting to it, and querying the database via `sqlcmd -d 'pets' -Q 'select url from images;'`. If successful, you should see URLs for 13 images returned. 

## Containerizing the API

1.  Navigate to `fundamentals-final-win/api` to find the source and config for your api tier.

2.  We'd like to define separate build and execution environments for our API tier. Begin writing a Dockerfile for your API by choosing an appropriate base image for your **build** environment; your developers designed this API to be build in dotnet framework 4.7.1.

3.  Your developers gave you the following further pieces of information about building your project:

    - Everything should be built from the directory `\sln\api`
    - You'll need the `*.csproj` and `packages.config` from the provided source to install the dependencies for your build process
    - Dependencies for your build process can be installed via:

    ```
    PS C:\> nuget restore -PackagesDirectory /sln/packages `
        -Verbosity Detailed -NonInteractive
    PS C:\> nuget install Microsoft.ApplicationInsights.Web -Version 2.2.0 `
        -OutputDirectory /sln/packages;
    PS C:\> nuget install Newtonsoft.Json -Version 6.0.4 `
        -OutputDirectory /sln/packages;
    PS C:\> nuget install Antlr -Version 3.4.1.9004 `
        -OutputDirectory /sln/packages;
    ```

    - You'll need everything else in the `fundamentals-final-win/api` to run the build process after the above dependencies are installed
    - After everything is set up correctly, the API can be built via `msbuild /p:Configuration=Release`.

4.  Finally, define an execution environment based on ASPNET 4.7.1 by copying everything in the `/sln/api` path in your build environment to the usual `/inetpub/wwwroot` in your execution environment.

5.  Once you've built your API image, set up a simple integration test between your database and api by creating a container for each; note that your commands might be different depending on how you designed your Dockerfiles:

    ```powershell
    PS: node-0 Administrator> docker container run -d `
        -e ACCEPT_EULA=Y -e sa_password=P@ssw0rd `
        --name database mssql:dev
    PS: node-0 Administrator> docker container run -d  `
        -p 8081:80 --name api api:dev
    ```

    Visit your API at `<node-0 public IP>:8081/api/pet`. You should see a JSON response containing one of the image URLs from your database. Leave these containers running for now.

## Containerizing the Frontend

1.  Navigate to `fundamentals-final-win/ui` to find the source and config for your web frontend.

2.  You know the following about compiling and running this frontend:

    - It's an ASP.NET core 2.0 app
    - All the source is available in `fundamentals-final-win/ui`
    - To build the app, run `dotnet restore`, then `dotnet publish -c Release -o out`
    - The above build step will leave all the build output needed to run the app in `out/`
    - From the directory containing the build output, the frontend can be started via `dotnet ui.dll`
    - Once up, the frontend will serve itself on port 3000.

    Write a Dockerfile that captures the necessary build and config information, and build your ui image.

3.  Once you've built your ui image, start a container based on it. Make sure your database and api containers are still running, and check to see if you can hit your website in your browser at `<node-0 public IP>:<port>/pet`; if so, you have successfully containerized all three tiers of your application.

## Orchestrating the Application

Once all three elements of the application are containerized, it's time to assemble them into a functioning application by writing a Docker compose file. The environmental requirements for each service are as follows:

- **Database**:
  - Named `database`.
  - Make sure the environment variables `ACCEPT_EULA` and `sa_password` are set in the compose file, if they weren't set in the database's Dockerfile (when would you want to set them in one place versus the other?).
- **API**:
  - Named `api`.
- **Frontend**:
  - Named `ui`.

Write a `docker-compose.yml` to capture this configuration, and use it to stand up your app with Docker Compose, Swarm, or Kubernetes. Make sure the website is reachable from the browser.

## Conclusion

In this exercise, you containerized and orchestrated a simple three tier application by writing a Dockerfile for each service, and a Docker Compose file for the full application. In practice, developers should be including their Dockerfiles with their source code, and senior developers and / or application architects should be providing Docker Compose files for the full application, possibly in conjunction with the operations team for environment-specific config.

Compare your Dockerfiles and Docker Compose file with other people in the class; how do your solutions differ? What are the possible advantages of each approach?
