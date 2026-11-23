@echo off
setlocal EnableExtensions
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Win11Emoji.ps1" -Diagnose %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
