@echo off
setlocal
set "DISPATCH="
for %%f in ("%~dp0dispatch\*.exe") do if not defined DISPATCH set "DISPATCH=%%f"
if not defined DISPATCH echo [ERROR] dispatch\dispatch.exe not found & pause & exit /b 1
"%DISPATCH%" list
echo.
echo Usage: dispatch start ^<IP1^>/1 ^<IP2^>/1 --port 17419
pause
