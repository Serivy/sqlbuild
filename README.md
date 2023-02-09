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