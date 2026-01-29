@echo off
echo === Hindsight GCP Status ===
echo.

echo Checking Database...
for /f "tokens=*" %%i in ('gcloud sql instances describe hindsight-db --project=hindsight-prod-9802 --format="value(state)" 2^>nul') do set dbstatus=%%i
if "%dbstatus%"=="RUNNABLE" (
    echo   Database: RUNNING
) else (
    echo   Database: %dbstatus%
)

echo.
echo Checking VM...
for /f "tokens=*" %%i in ('gcloud compute instances describe hindsight-vm --project=hindsight-prod-9802 --zone=us-south1-a --format="value(status)" 2^>nul') do set vmstatus=%%i
if "%vmstatus%"=="RUNNING" (
    echo   VM: RUNNING
) else (
    echo   VM: %vmstatus%
    echo.
    echo Hindsight is not fully running. Run Start-Hindsight.bat to start.
    pause
    exit /b
)

echo.
echo Checking API...
curl -s http://34.174.13.163:8888/health > nul 2>&1
if %errorlevel% equ 0 (
    echo   API: HEALTHY
) else (
    echo   API: NOT RESPONDING
)

echo.
echo === Endpoints ===
echo   MCP API: http://34.174.13.163:8888/mcp/claude-code/
echo   Web UI:  http://34.174.13.163:9999/banks/claude-code?view=data
echo.
pause
