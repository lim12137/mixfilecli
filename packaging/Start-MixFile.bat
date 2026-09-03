@echo off
rem One-click launch: auto-detects WiFi + Ethernet, aggregates via dispatch.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1"
echo.
pause
