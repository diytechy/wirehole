
@echo off
setlocal

REM Get the full path of this batch file
set "scriptPath=%~dp0"
set "scriptName=%~n0"

REM Run the PowerShell script with the same name
powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%%scriptName%.ps1"

endlocal


pause