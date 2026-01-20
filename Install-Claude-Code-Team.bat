@echo off
REM ============================================
REM Claude Code Team Installer Launcher
REM Double-click to run the installer
REM For PakEnergy employees
REM ============================================

title Claude Code Team Installer

REM Check if running as admin, if not, request elevation
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM Run the PowerShell installer (quotes handle spaces in path)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_scripts\install-claude-team.ps1"
