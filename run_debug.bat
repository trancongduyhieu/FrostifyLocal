@echo off
chcp 65001 >nul
title Nutsty Debug Console
echo ====================================================
echo             Nutsty Windows Debug Launcher
echo ====================================================
echo Starting Nutsty.exe...
echo.
Nutsty.exe
echo.
echo ====================================================
echo Nutsty process finished with code: %errorlevel%
echo ====================================================
if exist "%TEMP%\nutsty\launcher.log" (
    echo.
    echo --- Last 40 lines of %TEMP%\nutsty\launcher.log ---
    powershell -Command "Get-Content -Tail 40 $env:TEMP\nutsty\launcher.log"
)
echo.
pause
