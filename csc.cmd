@REM https://github.com/microsoft/vswhere/wiki/Installing
@REM https://github.com/Microsoft/vswhere/wiki/Find-MSBuild

@if not defined _echo echo off
setlocal enabledelayedexpansion

@REM Determine if MSBuild is already in the PATH
for /f "usebackq delims=" %%I in (`where csc.exe 2^>nul`) do (
    "%%I" %*
    exit /b !ERRORLEVEL!
)

@REM Use a less agressive form of finding an installed msbuild from vswhere.
for /f "usebackq tokens=*" %%i in (`call "%~dp0vswhere.cmd" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\csc.exe`) do (
    "%%i" %*
    exit /b !ERRORLEVEL!
)

echo Could not find msbuild.exe 1>&2
exit /b 2