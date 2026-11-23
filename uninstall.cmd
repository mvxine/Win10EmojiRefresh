@echo off
setlocal EnableExtensions
set "SCRIPT=%~dp0src\Win11Emoji.ps1"

rem Restoring the system font requires administrator rights (System mode is the default).
set "ELEVATE=1"
echo %* | findstr /i /c:"-User" >nul && set "ELEVATE=0"
echo %* | findstr /i /c:"-DryRun" >nul && set "ELEVATE=0"

if "%ELEVATE%"=="1" (
    net session >nul 2>&1
    if errorlevel 1 (
        echo Requesting administrator rights to restore the system font...
        if "%*"=="" (
            powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
        ) else (
            powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
        )
        exit /b
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Uninstall %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
