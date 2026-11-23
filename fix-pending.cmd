@echo off
setlocal EnableExtensions
set "SCRIPT=%~dp0src\FixPending.ps1"

net session >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator rights to fix the pending rename queue...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
