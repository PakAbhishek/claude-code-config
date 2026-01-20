# PowerShell script to add PreToolUse hook for SOC 2 compliance validation
# Used by setup-new-machine.bat to register the soc2-validator.py hook

param(
    [string]$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
)

try {
    # Ensure .claude directory exists
    $claudeDir = Split-Path $SettingsPath -Parent
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-Host "Created .claude directory"
    }

    # Create settings.json if it doesn't exist
    if (-not (Test-Path $SettingsPath)) {
        Write-Host "Creating new settings.json..."
        $settings = [PSCustomObject]@{}
    } else {
        # Read existing settings.json
        $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json

        # Handle empty or invalid settings.json
        if (-not $settings) {
            Write-Host "Settings.json was empty, initializing..."
            $settings = [PSCustomObject]@{}
        }
    }

    # Initialize hooks if missing
    if (-not $settings.hooks) {
        $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    # Check if SOC2 PreToolUse hook already exists
    $soc2HookExists = $false

    if ($settings.hooks.PreToolUse) {
        foreach ($hookEntry in $settings.hooks.PreToolUse) {
            if ($hookEntry.matcher -and $hookEntry.matcher -match "Write.*Edit") {
                if ($hookEntry.hooks) {
                    foreach ($hook in $hookEntry.hooks) {
                        if ($hook.command -and $hook.command -like "*soc2-validator.py*") {
                            $soc2HookExists = $true
                            break
                        }
                    }
                }
            }
        }
    }

    if ($soc2HookExists) {
        Write-Host "SOC 2 PreToolUse hook already configured"
        exit 0
    }

    # Create PreToolUse hook array if missing
    if (-not $settings.hooks.PreToolUse) {
        $settings.hooks | Add-Member -NotePropertyName 'PreToolUse' -NotePropertyValue @() -Force
    }

    # Create the SOC 2 validation hook
    $soc2Hook = [PSCustomObject]@{
        type = "command"
        command = "python `"$env:USERPROFILE\.claude\hooks\soc2-validator.py`""
        timeout = 5000
    }

    # Create PreToolUse hook configuration
    $preToolUseEntry = [PSCustomObject]@{
        matcher = "Write|Edit|NotebookEdit"
        hooks = @($soc2Hook)
    }

    # Add to PreToolUse hooks
    $preToolUseHooks = @($settings.hooks.PreToolUse)
    $preToolUseHooks += $preToolUseEntry
    $settings.hooks.PreToolUse = $preToolUseHooks

    # Write back to file
    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
    Write-Host "SOC 2 PreToolUse hook added successfully"

    exit 0

} catch {
    Write-Error "Failed to add PreToolUse hook: $_"
    exit 1
}
