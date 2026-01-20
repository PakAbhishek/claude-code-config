@echo off
setlocal EnableDelayedExpansion
REM ============================================
REM Claude Code Multi-Machine Setup Script
REM v3.0.23 - Custom agents auto-sync
REM Run this on each new machine to configure Claude Code
REM ============================================

REM Set paths
set "CONFIG_DIR=%USERPROFILE%\OneDrive - PakEnergy\Claude Backup\claude-config"
set "SCRIPTS_DIR=%CONFIG_DIR%\_scripts"
set "LOG_FILE=%TEMP%\claude-setup.log"

echo ====================================
echo Claude Code Multi-Machine Setup
echo ====================================
echo.

REM Log to file for debugging
echo [%DATE% %TIME%] Setup started > "%LOG_FILE%"
echo [%DATE% %TIME%] CONFIG_DIR: %CONFIG_DIR% >> "%LOG_FILE%"

REM ============================================
REM Verify OneDrive path exists
REM ============================================
if not exist "%CONFIG_DIR%" (
    echo ERROR: OneDrive path not found!
    echo Expected: %CONFIG_DIR%
    echo.
    echo Please ensure OneDrive is synced and try again.
    echo [%DATE% %TIME%] ERROR: CONFIG_DIR not found >> "%LOG_FILE%"
    pause
    exit /b 1
)
echo [%DATE% %TIME%] CONFIG_DIR verified >> "%LOG_FILE%"

REM ============================================
REM Step 1: Ensure .claude directory exists
REM ============================================
echo Step 1: Ensuring .claude directory exists...
if not exist "%USERPROFILE%\.claude" (
    echo   Creating .claude directory...
    mkdir "%USERPROFILE%\.claude"
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR: Failed to create .claude directory
        echo [%DATE% %TIME%] ERROR: mkdir .claude failed >> "%LOG_FILE%"
        pause
        exit /b 1
    )
)
echo [OK] .claude directory exists
echo [%DATE% %TIME%] Step 1 complete >> "%LOG_FILE%"
echo.

REM ============================================
REM Step 2: Ensure .claude\hooks directory exists
REM ============================================
echo Step 2: Ensuring hooks directory exists...
if not exist "%USERPROFILE%\.claude\hooks" (
    echo   Creating hooks directory...
    mkdir "%USERPROFILE%\.claude\hooks"
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR: Failed to create hooks directory
        echo [%DATE% %TIME%] ERROR: mkdir hooks failed >> "%LOG_FILE%"
        pause
        exit /b 1
    )
)
echo [OK] hooks directory exists
echo [%DATE% %TIME%] Step 2 complete >> "%LOG_FILE%"
echo.

REM ============================================
REM Step 3: Setup CLAUDE.md with auto-sync
REM ============================================
echo Step 3: Setting up CLAUDE.md with auto-sync...
set "SOURCE_CLAUDE=%CONFIG_DIR%\CLAUDE.md"
set "TARGET_CLAUDE=%USERPROFILE%\.claude\CLAUDE.md"
set "NEEDS_SYNC_HOOK=0"

REM Remove existing target if it exists (for clean symlink creation)
if exist "%TARGET_CLAUDE%" (
    echo   Removing existing CLAUDE.md...
    del "%TARGET_CLAUDE%" 2>nul
)

REM Try to create symbolic link (best option - real-time sync)
echo   Creating symbolic link...
mklink "%TARGET_CLAUDE%" "%SOURCE_CLAUDE%"
set "MKLINK_RESULT=!ERRORLEVEL!"

if "!MKLINK_RESULT!"=="0" (
    echo [OK] CLAUDE.md linked with real-time auto-sync
    set "NEEDS_SYNC_HOOK=0"
    echo [%DATE% %TIME%] Symlink created successfully >> "%LOG_FILE%"
    goto :SkipCopyFallback
)

echo   Symbolic link failed, using copy with SessionStart hook...
copy "%SOURCE_CLAUDE%" "%TARGET_CLAUDE%" /Y
if !ERRORLEVEL! NEQ 0 (
    echo ERROR: Failed to setup CLAUDE.md
    echo [%DATE% %TIME%] ERROR: copy CLAUDE.md failed >> "%LOG_FILE%"
    pause
    exit /b 1
)
echo [OK] CLAUDE.md copied (will auto-sync on session start)
set "NEEDS_SYNC_HOOK=1"
echo [%DATE% %TIME%] CLAUDE.md copied (fallback) >> "%LOG_FILE%"

:SkipCopyFallback
echo.

REM ============================================
REM Step 4: Setting up custom agents with auto-sync
REM ============================================
echo Step 4: Setting up custom agents with auto-sync...

set "SOURCE_AGENTS=%CONFIG_DIR%\agents"
set "TARGET_AGENTS=%USERPROFILE%\.claude\agents"

REM Check if source agents directory exists
if not exist "%SOURCE_AGENTS%" (
    echo [WARN] Source agents directory not found: %SOURCE_AGENTS%
    echo [INFO] Skipping agents setup
    goto :skip_agents
)

REM Remove existing target if it's a file or broken symlink
if exist "%TARGET_AGENTS%" (
    echo   Removing existing agents directory...
    rmdir /S /Q "%TARGET_AGENTS%" 2>nul
    del "%TARGET_AGENTS%" 2>nul
)

REM Try to create symbolic link (requires admin or Developer Mode)
echo   Creating symbolic link...
mklink /D "%TARGET_AGENTS%" "%SOURCE_AGENTS%" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    echo symbolic link created for %TARGET_AGENTS% ^<^<^=^=^=^>^> %SOURCE_AGENTS%
    echo [OK] Agents linked with real-time auto-sync
) else (
    REM Fallback: Copy directory if symlink fails
    echo   Directory link failed ^(requires admin^), copying instead...
    xcopy "%SOURCE_AGENTS%" "%TARGET_AGENTS%\" /E /I /Y >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo [OK] Agents copied ^(manual sync needed for updates^)
    ) else (
        echo [WARN] Failed to copy agents directory
    )
)

:skip_agents
echo [%DATE% %TIME%] Step 4 complete >> "%LOG_FILE%"
echo.

REM ============================================
REM Step 5: Configure Hindsight MCP server
REM ============================================
echo Step 5: Configuring Hindsight MCP server...

REM Always run add-hindsight.ps1 - it has its own check using claude mcp list
echo   Running Hindsight MCP configuration...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\add-hindsight.ps1"
set "HINDSIGHT_RESULT=!ERRORLEVEL!"
echo [%DATE% %TIME%] add-hindsight.ps1 exit code: !HINDSIGHT_RESULT! >> "%LOG_FILE%"

if !HINDSIGHT_RESULT! EQU 0 (
    echo [OK] Hindsight MCP server configured
    echo [%DATE% %TIME%] Hindsight configured >> "%LOG_FILE%"
) else (
    echo [WARN] Hindsight MCP configuration returned non-zero exit code
    echo [%DATE% %TIME%] WARNING: add-hindsight.ps1 returned !HINDSIGHT_RESULT! >> "%LOG_FILE%"
    echo You may need to run manually: claude mcp add --transport http hindsight http://hindsight-achau.southcentralus.azurecontainer.io:8888/mcp/claude-code/
)
echo.

REM ============================================
REM Step 6: Copy hook scripts to .claude/hooks
REM ============================================
echo Step 6: Installing hook scripts...

REM Always copy AWS SSO hook
echo   Copying AWS SSO hook...
copy "%SCRIPTS_DIR%\check-aws-sso.js" "%USERPROFILE%\.claude\hooks\check-aws-sso.js" /Y >nul
if !ERRORLEVEL! EQU 0 (
    echo [OK] AWS SSO credential check hook installed
    echo [%DATE% %TIME%] check-aws-sso.js copied >> "%LOG_FILE%"
) else (
    echo WARNING: Failed to copy AWS SSO hook
    echo [%DATE% %TIME%] WARNING: check-aws-sso.js copy failed >> "%LOG_FILE%"
)

REM Copy Hindsight capture hook
echo   Installing Hindsight memory capture hook...
if not exist "%USERPROFILE%\.claude\hooks\hindsight" (
    mkdir "%USERPROFILE%\.claude\hooks\hindsight"
)
copy "%SCRIPTS_DIR%\hindsight\capture.js" "%USERPROFILE%\.claude\hooks\hindsight\capture.js" /Y >nul
if !ERRORLEVEL! EQU 0 (
    echo [OK] Hindsight capture hook installed
    echo [%DATE% %TIME%] hindsight/capture.js copied >> "%LOG_FILE%"
) else (
    echo WARNING: Failed to copy Hindsight capture hook
    echo [%DATE% %TIME%] WARNING: hindsight/capture.js copy failed >> "%LOG_FILE%"
)

REM Copy sync hook if needed
if "%NEEDS_SYNC_HOOK%"=="1" (
    echo   Copying CLAUDE.md sync hook...
    copy "%SCRIPTS_DIR%\sync-claude-md.js" "%USERPROFILE%\.claude\hooks\sync-claude-md.js" /Y >nul
    if !ERRORLEVEL! EQU 0 (
        echo [OK] CLAUDE.md sync hook installed
        echo [%DATE% %TIME%] sync-claude-md.js copied >> "%LOG_FILE%"
    ) else (
        echo WARNING: Failed to copy sync hook
        echo [%DATE% %TIME%] WARNING: sync-claude-md.js copy failed >> "%LOG_FILE%"
    )
) else (
    REM Copy anyway for completeness
    copy "%SCRIPTS_DIR%\sync-claude-md.js" "%USERPROFILE%\.claude\hooks\sync-claude-md.js" /Y >nul
    echo [OK] Sync hook installed (backup for symlink)
)

REM Copy protocol reminder hook
echo   Copying protocol reminder hook...
copy "%SCRIPTS_DIR%\protocol-reminder.js" "%USERPROFILE%\.claude\hooks\protocol-reminder.js" /Y >nul
if !ERRORLEVEL! EQU 0 (
    echo [OK] Protocol reminder hook installed
    echo [%DATE% %TIME%] protocol-reminder.js copied >> "%LOG_FILE%"
) else (
    echo WARNING: Failed to copy protocol reminder hook
    echo [%DATE% %TIME%] WARNING: protocol-reminder.js copy failed >> "%LOG_FILE%"
)
echo.

REM ============================================
REM Step 7: Register hooks in settings.json
REM ============================================
echo Step 7: Registering hooks in settings.json...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\add-sessionstart-hook.ps1"
if !ERRORLEVEL! EQU 0 (
    echo [OK] SessionStart hooks registered
    echo [%DATE% %TIME%] SessionStart hooks registered >> "%LOG_FILE%"
) else (
    echo WARNING: Failed to register SessionStart hooks
    echo [%DATE% %TIME%] WARNING: add-sessionstart-hook.ps1 failed >> "%LOG_FILE%"
)
echo.

REM ============================================
REM Complete
REM ============================================
echo ====================================
echo Setup Complete!
echo ====================================
echo.
echo Configured:
echo [OK] .claude directory ready
echo [OK] CLAUDE.md auto-sync across all machines
echo [OK] Custom agents auto-sync across all machines
echo [OK] Hindsight MCP server
echo [OK] Hindsight memory capture hook
echo [OK] AWS SSO credential auto-refresh on session start
echo [OK] Protocol reminder hook (agent behavior enforcement)
echo.
echo Log file: %LOG_FILE%
echo.
echo Next steps:
echo 1. Restart Claude Code
echo 2. Test with: reflect("What is my startup protocol?")
echo 3. Should connect to Hindsight cloud server
echo.

echo [%DATE% %TIME%] Setup completed successfully >> "%LOG_FILE%"
endlocal
pause
