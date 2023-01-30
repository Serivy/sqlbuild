@REM https://github.com/microsoft/vswhere/wiki/Installing

@if not defined _echo echo off
setlocal enabledelayedexpansion

@REM Check the VS Installed vswhere.
SET VSINSTALL="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist %VSINSTALL% (
    %VSINSTALL% %*
    exit /b !ERRORLEVEL!
)

for /f "usebackq delims=" %%I in (`dir /b /aD /o-N /s "%~dp0..\packages\vswhere*"`) do (
    for /f "usebackq delims=" %%J in (`where /r "%%I" vswhere.exe 2^>nul`) do (
        "%%J" %*
        exit /b !ERRORLEVEL!
    )
)