# PowerShell script to add SessionStart hooks and ensure Bedrock provider settings
# Used by setup-new-machine.bat for complete Claude Code configuration
# v2.1.0 - Added protocol-reminder hook for agent behavior enforcement

param(
    [string]$SettingsPath = "$env:USERPROFILE\.claude\settings.json"
)

# Get the script directory to find the template
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $ScriptDir "personal-settings.json"

try {
    # Ensure .claude directory exists
    $claudeDir = Split-Path $SettingsPath -Parent
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-Host "Created .claude directory"
    }

    # Create settings.json if it doesn't exist - use template as base
    if (-not (Test-Path $SettingsPath)) {
        Write-Host "Creating new settings.json from template..."
        if (Test-Path $TemplatePath) {
            $settings = Get-Content $TemplatePath -Raw | ConvertFrom-Json
            Write-Host "  Loaded personal-settings.json template"
        } else {
            Write-Host "  Template not found, creating minimal settings..."
            $settings = [PSCustomObject]@{}
        }
    } else {
        # Read existing settings.json
        $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json

        # Handle empty or invalid settings.json
        if (-not $settings) {
            Write-Host "Settings.json was empty, initializing from template..."
            if (Test-Path $TemplatePath) {
                $settings = Get-Content $TemplatePath -Raw | ConvertFrom-Json
            } else {
                $settings = [PSCustomObject]@{}
            }
        }
    }

    # ============================================
    # Ensure provider is set to bedrock
    # ============================================
    if (-not $settings.provider) {
        Write-Host "Setting provider to bedrock..."
        $settings | Add-Member -NotePropertyName 'provider' -NotePropertyValue 'bedrock' -Force
    } elseif ($settings.provider -ne 'bedrock') {
        Write-Host "Updating provider to bedrock (was: $($settings.provider))..."
        $settings.provider = 'bedrock'
    }

    # ============================================
    # Ensure env block exists with required vars
    # ============================================
    if (-not $settings.env) {
        Write-Host "Adding env block..."
        $settings | Add-Member -NotePropertyName 'env' -NotePropertyValue ([PSCustomObject]@{
            CLAUDE_CODE_USE_BEDROCK = "1"
            AWS_REGION = "us-east-1"
        }) -Force
    } else {
        # Ensure required env vars are set
        if (-not $settings.env.CLAUDE_CODE_USE_BEDROCK) {
            $settings.env | Add-Member -NotePropertyName 'CLAUDE_CODE_USE_BEDROCK' -NotePropertyValue '1' -Force
            Write-Host "  Added CLAUDE_CODE_USE_BEDROCK=1"
        }
        if (-not $settings.env.AWS_REGION) {
            $settings.env | Add-Member -NotePropertyName 'AWS_REGION' -NotePropertyValue 'us-east-1' -Force
            Write-Host "  Added AWS_REGION=us-east-1"
        }
    }

    # ============================================
    # Ensure mcpServers has Hindsight
    # ============================================
    if (-not $settings.mcpServers) {
        Write-Host "Adding mcpServers with Hindsight..."
        $settings | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{
            hindsight = [PSCustomObject]@{
                transport = "sse"
                url = "http://34.174.13.163:8888/mcp/claude-code/"
            }
        }) -Force
    } elseif (-not $settings.mcpServers.hindsight) {
        Write-Host "Adding Hindsight to mcpServers..."
        $settings.mcpServers | Add-Member -NotePropertyName 'hindsight' -NotePropertyValue ([PSCustomObject]@{
            transport = "sse"
            url = "http://34.174.13.163:8888/mcp/claude-code/"
        }) -Force
    }

    # ============================================
    # Ensure permissions.deny for ADO safety
    # ============================================
    $adoDenyList = @(
        "mcp__ado__wit_create_work_item",
        "mcp__ado__wit_update_work_item",
        "mcp__ado__wit_update_work_items_batch",
        "mcp__ado__wit_add_work_item_comment"
    )

    if (-not $settings.permissions) {
        Write-Host "Adding permissions with ADO deny list..."
        $settings | Add-Member -NotePropertyName 'permissions' -NotePropertyValue ([PSCustomObject]@{
            deny = $adoDenyList
        }) -Force
    } elseif (-not $settings.permissions.deny) {
        Write-Host "Adding ADO deny list to permissions..."
        $settings.permissions | Add-Member -NotePropertyName 'deny' -NotePropertyValue $adoDenyList -Force
    }

    # Initialize hooks if missing
    if (-not $settings.hooks) {
        $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{}) -Force
    }

    # Check which hooks already exist
    $syncHookExists = $false
    $awsHookExists = $false
    $protocolHookExists = $false

    if ($settings.hooks.SessionStart) {
        foreach ($hookEntry in $settings.hooks.SessionStart) {
            if ($hookEntry.hooks) {
                foreach ($hook in $hookEntry.hooks) {
                    if ($hook.command -and $hook.command -like "*sync-claude-md.js*") {
                        $syncHookExists = $true
                    }
                    if ($hook.command -and $hook.command -like "*check-aws-sso.js*") {
                        $awsHookExists = $true
                    }
                    if ($hook.command -and $hook.command -like "*protocol-reminder.js*") {
                        $protocolHookExists = $true
                    }
                }
            }
        }
    }

    # Note: Don't exit early even if hooks exist - we still need to write provider/env settings

    # Create SessionStart hook array if missing
    if (-not $settings.hooks.SessionStart) {
        $settings.hooks | Add-Member -NotePropertyName 'SessionStart' -NotePropertyValue @() -Force
    }

    # Build hooks array with both hooks
    $hooksToAdd = @()

    if (-not $syncHookExists) {
        $hooksToAdd += [PSCustomObject]@{
            type = "command"
            command = "node `"$env:USERPROFILE\.claude\hooks\sync-claude-md.js`""
            timeout = 10
        }
        Write-Host "Adding CLAUDE.md sync hook"
    }

    if (-not $awsHookExists) {
        $hooksToAdd += [PSCustomObject]@{
            type = "command"
            command = "node `"$env:USERPROFILE\.claude\hooks\check-aws-sso.js`""
            timeout = 120
        }
        Write-Host "Adding AWS SSO credential check hook"
    }

    if (-not $protocolHookExists) {
        $hooksToAdd += [PSCustomObject]@{
            type = "command"
            command = "node `"$env:USERPROFILE\.claude\hooks\protocol-reminder.js`""
            timeout = 5
        }
        Write-Host "Adding protocol reminder hook"
    }

    if ($hooksToAdd.Count -gt 0) {
        # Create hook configuration with all hooks
        $sessionHook = [PSCustomObject]@{
            hooks = $hooksToAdd
        }

        # Add to SessionStart hooks
        $sessionStartHooks = @($settings.hooks.SessionStart)
        $sessionStartHooks += $sessionHook
        $settings.hooks.SessionStart = $sessionStartHooks
        Write-Host "SessionStart hooks added successfully"
    } else {
        Write-Host "SessionStart hooks already configured"
    }

    # Always write settings.json to ensure provider/env settings are saved
    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
    Write-Host "Settings saved to $SettingsPath"

    exit 0

} catch {
    Write-Error "Failed to add SessionStart hooks: $_"
    exit 1
}
