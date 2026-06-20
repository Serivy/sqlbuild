# Introduction
A set of scripts which can be run against a MSSQL Server that will install an assembly allowing high level actions to aid in building. Primarily the functions focus on restoring and backing up databases but to a remote machine not on the sql server.

# Scripts
The scripts are provided in two formats, Powershell and MSBuild but it can be adapted to any system which allows execution against a MSSQL Server.
These can be found in the dist\ folder.

## MSBuild
Consume the sqlbuild.targets in an import.
[dist\sqlbuild.targets](https://github.com/Serivy/sqlbuild/blob/main/dist/sqlbuild.targets)

## Powershell
Use the powershell script to import functions.
[dist\sqlbuild.targets](https://github.com/Serivy/sqlbuild/blob/main/dist/sqlbuild.ps1)


# MSbuild Task testing
The MSBuild task is designed to be a isolated and safer way to run backup and restore functions.
To run the tests, ensure you had a docker container running on the port 31433 with a MSSQL Server instance running and a database called "master" with the user "sa" and password "yourStrong(!)Password". Then run the tests in sqlbuild.test.

```bash
podman run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=yourStrong(!)Password" -p 31433:1433 --name sqlbuild-test -d mcr.microsoft.com/mssql/server:2022-latest

podman exec -it sqlbuild-test /opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1,1433 -C  -U sa -P "yourStrong(!)Password" -Q "print system_user + ', ' + @@servername + ', ' + @@servicename + ', ' + user_name() + ', ' + CURRENT_USER; print @@version"

sqlcmd -S 127.0.0.1,31433 -U sa -P "yourStrong(!)Password" -Q "print @@version"

podman rm -f sqlbuild-test

podman run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=yourStrong(!)Password" -p 31433:1433 --name sqlbuild-test -d mcr.microsoft.com/mssql/server:2019-latest
```