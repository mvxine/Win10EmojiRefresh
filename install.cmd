@echo off
setlocal EnableExtensions
set "SCRIPT=%~dp0src\Win11Emoji.ps1"

rem System mode is the default because it is the only one that changes Win + .
rem Elevates automatically, except for -User / -DryRun.
set "ELEVATE=1"
echo %* | findstr /i /c:"-User" >nul && set "ELEVATE=0"
echo %* | findstr /i /c:"-DryRun" >nul && set "ELEVATE=0"

net session >nul 2>&1
if errorlevel 1 (
    echo NOTE: Do NOT right-click this file and choose "Run as administrator".
    echo       This wrapper requests UAC by itself. Running it twice queues duplicate boot renames.
    echo.
)

if "%ELEVATE%"=="1" (
    net session >nul 2>&1
    if errorlevel 1 (
        echo Requesting administrator rights to replace the system font...
        if "%*"=="" (
            powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
        ) else (
            powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
        )
        exit /b
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
