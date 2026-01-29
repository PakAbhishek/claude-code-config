# Setup Windows Scheduled Task for Auto AWS Credential Push
# Run this once to enable automatic credential pushing to GCP Hindsight

Write-Host "Setting up Hindsight Auto-Push Scheduled Task..." -ForegroundColor Cyan

$scriptPath = "$env:USERPROFILE\OneDrive\Claude Backup\claude-config\hindsight-setup\Auto-Push-AWS-Credentials.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Script not found at $scriptPath" -ForegroundColor Red
    exit 1
}

# Create task action
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Trigger on user login
$trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

# Principal (run as current user)
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

# Remove existing task if present
$existingTask = Get-ScheduledTask -TaskName 'Hindsight-AWS-Credential-Push' -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName 'Hindsight-AWS-Credential-Push' -Confirm:$false
}

# Register new task
try {
    Register-ScheduledTask `
        -TaskName 'Hindsight-AWS-Credential-Push' `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description 'Automatically pushes AWS credentials to GCP Hindsight on login. Runs silently if SSO session is active.'

    Write-Host ""
    Write-Host "SUCCESS! Scheduled task created." -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Get-ScheduledTask -TaskName 'Hindsight-AWS-Credential-Push' | Format-List TaskName, State, Description

    Write-Host ""
    Write-Host "What happens now:" -ForegroundColor Yellow
    Write-Host "  - On every Windows login, the task runs automatically"
    Write-Host "  - If your AWS SSO session is active: Credentials pushed silently"
    Write-Host "  - If SSO session expired: Logged to ~/hindsight-auto-push.log"
    Write-Host "  - Check log: Get-Content ~/hindsight-auto-push.log -Tail 20"
    Write-Host ""
    Write-Host "To test now: Start-ScheduledTask -TaskName 'Hindsight-AWS-Credential-Push'"

} catch {
    Write-Host "ERROR: Failed to create task: $_" -ForegroundColor Red
    exit 1
}
