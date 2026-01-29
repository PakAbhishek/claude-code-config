@echo off
echo === Update Hindsight AWS Credentials ===
echo.
echo This refreshes local AWS SSO credentials and pushes them to GCP Hindsight.
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
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\OneDrive\Claude Backup\claude-config\hindsight-setup\Auto-Push-AWS-Credentials.ps1"

echo.
echo Done! Local credentials refreshed and pushed to GCP Hindsight.
echo Credentials expire in ~12 hours. Run this script again when needed.
echo.
pause
