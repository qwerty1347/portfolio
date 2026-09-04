@echo off
rem Case study generator. Runs regardless of PowerShell execution policy.
rem   usage:  new-case.cmd C:\work\my-api
rem           new-case.cmd C:\work\my-api -Title "Order Settlement API"
rem   Double-click to run: it will ask for the project path.

setlocal

set "PROJECT=%~1"
if "%PROJECT%"=="" (
    set /p PROJECT="Project folder path: "
)
if "%PROJECT%"=="" (
    echo No project path given.
    pause
    exit /b 1
)

shift
set "EXTRA="
:collect
if "%~1"=="" goto run
set "EXTRA=%EXTRA% %1"
shift
goto collect

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0New-CaseStudy.ps1" -Project "%PROJECT%"%EXTRA%
echo.
pause
