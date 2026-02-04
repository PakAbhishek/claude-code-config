@echo off
setlocal EnableDelayedExpansion
echo === Update Hindsight AWS Credentials ===
echo.
echo This refreshes local AWS SSO credentials and pushes them to GCP Hindsight.
echo.

:: Auto-detect OneDrive path (v3.0.31)
echo Detecting OneDrive path...
set "ONEDRIVE_PATH="

:: Check work machine path first (more specific)
if exist "%USERPROFILE%\OneDrive - PakEnergy" (
    set "ONEDRIVE_PATH=%USERPROFILE%\OneDrive - PakEnergy"
    echo   Found: OneDrive - PakEnergy ^(work machine^)
    goto :onedrive_found
)

:: Check personal machine path
if exist "%USERPROFILE%\OneDrive" (
    set "ONEDRIVE_PATH=%USERPROFILE%\OneDrive"
    echo   Found: OneDrive ^(personal machine^)
    goto :onedrive_found
)

:: No OneDrive found
echo ERROR: OneDrive folder not found!
echo Checked:
echo   - %USERPROFILE%\OneDrive - PakEnergy
echo   - %USERPROFILE%\OneDrive
pause
exit /b 1

:onedrive_found
echo.

:: Get fresh credentials from local AWS SSO
echo Step 1: Refreshing AWS SSO credentials...
aws sso login 2>nul || (
    echo ERROR: AWS SSO login failed. Make sure AWS CLI is configured.
    pause
    exit /b 1
)

echo.
echo Step 2: Verifying credentials...
aws sts get-caller-identity >nul 2>&1 || (
    echo ERROR: Failed to get valid credentials after SSO login
    pause
    exit /b 1
)
echo   Credentials valid!

echo.
echo Step 3: Pushing credentials to GCP Hindsight...
powershell -ExecutionPolicy Bypass -File "%ONEDRIVE_PATH%\Claude Backup\claude-config\hindsight-setup\Auto-Push-AWS-Credentials.ps1"

echo.
echo Done! Local credentials refreshed and pushed to GCP Hindsight.
echo Credentials expire in ~12 hours. Run this script again when needed.
echo.
pause
