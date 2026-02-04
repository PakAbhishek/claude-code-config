@echo off
echo Stopping Hindsight on GCP...
echo.
echo This will stop both VM and Database.
echo Savings: ~$11/day while stopped.
echo.

REM Use gcloud.cmd explicitly to avoid shell script conflict
set "GCLOUD=gcloud.cmd"

set /p confirm=Stop Hindsight? (Y/N):
if /i not "%confirm%"=="Y" (
    echo Cancelled.
    pause
    exit /b
)

echo.
echo [1/2] Stopping VM...
call %GCLOUD% compute instances stop hindsight-vm --project=hindsight-prod-9802 --zone=us-south1-a --quiet

echo.
echo [2/2] Stopping Database (Cloud SQL)...
call %GCLOUD% sql instances patch hindsight-db --project=hindsight-prod-9802 --activation-policy=NEVER --quiet

echo.
echo ============================================
echo   Hindsight stopped.
echo ============================================
echo   VM: STOPPED
echo   Database: STOPPED
echo   Storage: Still preserved (costs ~$0.36/day)
echo.
echo   To restart: double-click Start-Hindsight.bat
echo.
pause
