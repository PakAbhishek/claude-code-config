@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   Starting Hindsight on GCP
echo ============================================
echo.

REM Use gcloud.cmd explicitly to avoid shell script conflict
set "GCLOUD=gcloud.cmd"

echo [1/3] Starting Database (Cloud SQL)...
call %GCLOUD% sql instances patch hindsight-db --project=hindsight-prod-9802 --activation-policy=ALWAYS
echo        Done.

echo.
echo        Checking database state...
:dbcheck
for /f "usebackq tokens=*" %%i in (`call %GCLOUD% sql instances describe hindsight-db --project=hindsight-prod-9802 --format^="value(state)"`) do set "DB_STATE=%%i"
echo        State: !DB_STATE!
if /i not "!DB_STATE!"=="RUNNABLE" (
    echo        Waiting...
    timeout /t 5 /nobreak > nul
    goto dbcheck
)
echo        Database: READY

echo.
echo [2/3] Starting VM...
call %GCLOUD% compute instances start hindsight-vm --project=hindsight-prod-9802 --zone=us-south1-a
echo        Done.

echo.
echo        Checking VM state...
for /f "usebackq tokens=*" %%i in (`call %GCLOUD% compute instances describe hindsight-vm --project=hindsight-prod-9802 --zone=us-south1-a --format^="value(status)"`) do set "VM_STATE=%%i"
echo        State: !VM_STATE!
echo        VM: READY

echo.
echo [3/3] Waiting for Hindsight API (30s startup)...
timeout /t 30 /nobreak > nul

:apicheck
curl -s http://34.174.13.163:8888/health >nul 2>&1
if !errorlevel! neq 0 (
    echo        Still starting...
    timeout /t 5 /nobreak > nul
    goto apicheck
)

echo.
echo ============================================
echo   Hindsight is ready!
echo ============================================
echo   MCP API: http://34.174.13.163:8888/mcp/claude-code/
echo   Web UI:  http://34.174.13.163:9999/banks/claude-code?view=data
echo.
pause
