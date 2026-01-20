@echo off
REM ============================================
REM Claude Code One-Click Installer (Windows)
REM Double-click this file to install everything
REM ============================================

echo.
echo ============================================
echo Claude Code Complete Installer
echo ============================================
echo.
echo This will install and configure:
echo   - Node.js (if needed)
echo   - Claude Code (latest version)
echo   - Hindsight MCP server
echo   - CLAUDE.md auto-sync
echo   - AWS Bedrock via SSO
echo.
echo Starting installation...
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with administrator privileges...
    goto :RunInstaller
) else (
    echo Requesting administrator privileges...
    echo Please click "Yes" in the UAC prompt to continue...
    echo.
    REM Re-launch this batch file as administrator
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    goto :End
)

:RunInstaller
echo Log file will be at: %TEMP%\claude-installer.log
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_scripts\install-claude-complete.ps1"
if %errorLevel% neq 0 (
    echo.
    echo ============================================
    echo INSTALLER FAILED - Check log file:
    echo %TEMP%\claude-installer.log
    echo ============================================
    echo.
    pause
)
goto :End

:End
exit
