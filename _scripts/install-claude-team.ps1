# ============================================
# Claude Code Team Installation
# One-click installer for Windows (Team Version)
# v1.3.2 - Added 1-click Mac installer
# ============================================
#
# This installer sets up Claude Code with AWS Bedrock access.
# Does NOT include Hindsight MCP server (personal use only).
#
# What this installs:
# - Node.js check (recommends v22 LTS)
# - Git check/install
# - Claude Code (latest version)
# - AWS CLI v2
# - AWS SSO for Bedrock access
# ============================================

# ============================================
# LOGGING SETUP
# ============================================
$LogFile = "$env:TEMP\claude-team-installer.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage

    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARN"  { Write-Host $Message -ForegroundColor Yellow }
        "OK"    { Write-Host $Message -ForegroundColor Green }
        "STEP"  { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

# Start fresh log
"============================================" | Set-Content $LogFile
"Claude Code Team Installer Log" | Add-Content $LogFile
"Started: $(Get-Date)" | Add-Content $LogFile
"============================================" | Add-Content $LogFile

Write-Log "Team installer started"
Write-Log "Log file: $LogFile"
Write-Log "PowerShell version: $($PSVersionTable.PSVersion)"

# Global error handler
trap {
    Write-Log "FATAL ERROR: $_" "ERROR"
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "INSTALLATION FAILED" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Log file: $LogFile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ============================================
# Admin Check
# ============================================
Write-Log "Checking administrator privileges..."
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $isAdmin) {
    Write-Log "Not running as admin, attempting elevation..." "WARN"
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "Administrator Privileges Required" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This installer needs administrator privileges to:"
    Write-Host "  - Install software globally"
    Write-Host "  - Set environment variables"
    Write-Host ""

    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit 0
    } catch {
        Write-Log "Failed to elevate: $_" "ERROR"
        Write-Host "Failed to elevate privileges. Please right-click and select 'Run as Administrator'" -ForegroundColor Red
        pause
        exit 1
    }
}

Write-Log "Running with administrator privileges" "OK"

# ============================================
# Load GUI Assemblies
# ============================================
Write-Log "Loading GUI assemblies..."
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Write-Log "GUI assemblies loaded" "OK"

function Show-MessageBox {
    param(
        [string]$Message,
        [string]$Title = "Claude Code Team Installer",
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

# ============================================
# Welcome Screen
# ============================================
Write-Log "Showing welcome screen..."

$welcome = Show-MessageBox -Message @"
Welcome to Claude Code Team Installer!

This installer will set up Claude Code with AWS Bedrock access:

- Check/install Node.js (recommends v22 LTS)
- Check/install Git
- Install Claude Code (latest version)
- Install AWS CLI v2 (if needed)
- Configure AWS SSO for PakEnergy Bedrock access

Click OK to begin installation.
"@ -Title "Claude Code Team Installer" -Buttons OKCancel -Icon Information

if ($welcome -eq [System.Windows.Forms.DialogResult]::Cancel) {
    Write-Log "Installation cancelled by user"
    exit 0
}

Write-Log "User clicked OK, proceeding with installation"

# ============================================
# Step 1: Check Node.js
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 1: Checking Node.js Installation" "STEP"
Write-Log "============================================" "STEP"

$nodeInstalled = $false
$nodeVersionMajor = 0
try {
    Write-Log "Checking for node..."
    $nodeVersion = & node --version 2>$null
    if ($nodeVersion) {
        Write-Log "Node.js is installed: $nodeVersion" "OK"
        $nodeInstalled = $true

        # Extract major version number
        if ($nodeVersion -match "v(\d+)") {
            $nodeVersionMajor = [int]$matches[1]
            Write-Log "Node.js major version: $nodeVersionMajor"
        }

        # Warn about Node.js v24 libuv bug on Windows
        if ($nodeVersionMajor -ge 24) {
            Write-Log "Node.js v24+ detected - known libuv assertion bug on Windows" "WARN"
            Show-MessageBox -Message "Node.js $nodeVersion detected.`n`nNote: Node.js v24 has a known bug on Windows that causes harmless 'assertion failed' errors.`n`nRecommended: Node.js v22 LTS for best stability.`n`nClaude Code will still work, but you may see red error messages." -Title "Node.js Version Notice" -Icon Warning
        }
    }
} catch {
    Write-Log "Node.js check failed: $_" "WARN"
}

if (-not $nodeInstalled) {
    Write-Log "Prompting user to install Node.js..."
    $installNode = Show-MessageBox -Message "Node.js is required but not installed.`n`nWould you like to download and install Node.js v22 LTS automatically?" -Buttons YesNo -Icon Question

    if ($installNode -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Downloading Node.js v22 LTS installer..."
        $nodeInstallerUrl = "https://nodejs.org/dist/v22.13.0/node-v22.13.0-x64.msi"
        $nodeInstallerPath = "$env:TEMP\node-installer.msi"

        try {
            Write-Host "Downloading Node.js v22 LTS..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $nodeInstallerUrl -OutFile $nodeInstallerPath -UseBasicParsing
            Write-Log "Node.js downloaded, installing..."

            Write-Host "Installing Node.js (this may take a minute)..." -ForegroundColor Cyan
            Start-Process msiexec.exe -ArgumentList "/i `"$nodeInstallerPath`" /qb" -Wait
            Write-Log "Node.js installed" "OK"

            # Refresh PATH to pick up node and npm
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Log "PATH refreshed"

            # Verify installation
            $nodeVersion = & node --version 2>$null
            if ($nodeVersion) {
                Write-Log "Node.js verified: $nodeVersion" "OK"
                $nodeInstalled = $true
            } else {
                Write-Log "Node.js installed but not found in PATH" "WARN"
                Show-MessageBox -Message "Node.js was installed but not found in PATH.`n`nPlease restart this installer." -Icon Warning
                exit 1
            }
        } catch {
            Write-Log "Failed to install Node.js: $_" "ERROR"
            Show-MessageBox -Message "Failed to install Node.js automatically.`n`nPlease install manually from:`nhttps://nodejs.org/`n`nThen run this installer again." -Icon Error
            exit 1
        }
    } else {
        Write-Log "User declined Node.js installation" "ERROR"
        Show-MessageBox -Message "Claude Code requires Node.js. Installation cancelled." -Icon Warning
        exit 1
    }
}

# ============================================
# Step 2: Check Git
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 2: Checking Git Installation" "STEP"
Write-Log "============================================" "STEP"

$gitInstalled = $false
try {
    Write-Log "Checking for git..."
    $gitVersion = & git --version 2>$null
    if ($gitVersion) {
        Write-Log "Git is installed: $gitVersion" "OK"
        $gitInstalled = $true
    }
} catch {
    Write-Log "Git check failed: $_" "WARN"
}

if (-not $gitInstalled) {
    Write-Log "Prompting user to install Git..."
    $installGit = Show-MessageBox -Message "Git is recommended but not installed.`n`nWould you like to download and install it now?" -Buttons YesNo -Icon Question

    if ($installGit -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Downloading Git installer..."
        $gitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
        $gitInstallerPath = "$env:TEMP\Git-installer.exe"

        try {
            Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $gitInstallerPath -UseBasicParsing
            Write-Log "Git downloaded, installing..."
            Start-Process -FilePath $gitInstallerPath -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS" -Wait
            Write-Log "Git installed" "OK"

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $gitInstalled = $true
        } catch {
            Write-Log "Failed to install Git: $_" "ERROR"
            Show-MessageBox -Message "Failed to install Git automatically.`n`nPlease install manually from:`nhttps://git-scm.com/download/win" -Icon Warning
        }
    } else {
        Write-Log "User skipped Git installation" "WARN"
    }
}

# ============================================
# Step 3: Install/Update Claude Code
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 3: Installing/Updating Claude Code" "STEP"
Write-Log "============================================" "STEP"

# Check npm global prefix is in PATH
Write-Log "Checking npm global prefix..."
try {
    $npmPrefix = (npm config get prefix 2>$null).Trim()
    if ($npmPrefix) {
        Write-Log "npm global prefix: $npmPrefix"
        if (-not ($env:Path -like "*$npmPrefix*")) {
            Write-Log "npm global prefix not in PATH, adding temporarily..." "WARN"
            $env:Path = "$npmPrefix;$env:Path"
        }
    }
} catch {
    Write-Log "npm prefix check failed: $_" "WARN"
}

$claudeInstalled = $false
try {
    Write-Log "Checking for claude..."
    $claudeVersion = & claude --version 2>$null
    if ($claudeVersion) {
        Write-Log "Claude Code is installed: $claudeVersion" "OK"
        $claudeInstalled = $true

        $update = Show-MessageBox -Message "Claude Code is already installed ($claudeVersion).`n`nUpdate to latest version?" -Buttons YesNo -Icon Question
        if ($update -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Log "Updating Claude Code..."
            npm update -g @anthropic-ai/claude-code
            Write-Log "Claude Code updated" "OK"
        }
    }
} catch {
    Write-Log "Claude Code check failed: $_" "WARN"
}

if (-not $claudeInstalled) {
    Write-Log "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Claude Code npm install completed" "OK"

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verify
        try {
            $claudeVersion = & claude --version 2>$null
            if ($claudeVersion) {
                Write-Log "Claude Code verified: $claudeVersion" "OK"
            } else {
                Write-Log "Claude installed but not found in PATH" "WARN"
                $npmPrefix = (npm config get prefix 2>$null).Trim()
                Show-MessageBox -Message "Claude Code installed but not found in PATH.`n`nYou may need to restart your terminal.`n`nnpm prefix: $npmPrefix" -Icon Warning
            }
        } catch {
            Write-Log "Claude verification failed: $_" "WARN"
        }
    } else {
        Write-Log "npm install failed" "ERROR"
        Show-MessageBox -Message "Failed to install Claude Code. Please check your internet connection." -Icon Error
        exit 1
    }
}

# ============================================
# Step 4: AWS CLI and SSO Configuration
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 4: AWS Bedrock Configuration" "STEP"
Write-Log "============================================" "STEP"

# Check AWS CLI
$awsCliInstalled = $false
try {
    Write-Log "Checking for AWS CLI..."
    $awsVersion = & aws --version 2>$null
    if ($awsVersion) {
        Write-Log "AWS CLI is installed: $awsVersion" "OK"
        $awsCliInstalled = $true
    }
} catch {
    Write-Log "AWS CLI check failed: $_" "WARN"
}

if (-not $awsCliInstalled) {
    Write-Log "Prompting user to install AWS CLI..."
    $installAwsCli = Show-MessageBox -Message "AWS CLI v2 is required for Bedrock access.`n`nClick OK to download and install." -Buttons OKCancel -Icon Warning

    if ($installAwsCli -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Log "Downloading AWS CLI v2..."
        $awsInstallerUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
        $awsInstallerPath = "$env:TEMP\AWSCLIV2.msi"

        try {
            Invoke-WebRequest -Uri $awsInstallerUrl -OutFile $awsInstallerPath -UseBasicParsing
            Write-Log "AWS CLI downloaded, installing..."
            Start-Process msiexec.exe -ArgumentList "/i `"$awsInstallerPath`" /qb" -Wait
            Write-Log "AWS CLI v2 installed" "OK"
            $awsCliInstalled = $true

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        } catch {
            Write-Log "Failed to install AWS CLI: $_" "ERROR"
            Show-MessageBox -Message "Failed to install AWS CLI.`n`nPlease install manually from:`nhttps://aws.amazon.com/cli/" -Icon Error
        }
    }
}

# Configure AWS SSO
Write-Log "Configuring AWS SSO..."
$awsDir = "$env:USERPROFILE\.aws"
if (-not (Test-Path $awsDir)) {
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
}

# Check if already logged in with valid SSO session
Write-Log "Checking AWS SSO login status..."
$ssoLoggedIn = $false
try {
    $callerIdentity = & aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($callerIdentity.Account) {
        Write-Log "Already authenticated: $($callerIdentity.Arn)" "OK"
        $ssoLoggedIn = $true
    }
} catch {
    Write-Log "AWS SSO not logged in"
}

if (-not $ssoLoggedIn) {
    Write-Log "AWS SSO configuration required..."

    # Copy AWS config template to user's AWS directory
    $configTemplate = "$PSScriptRoot\aws-config-template"
    $configDest = "$env:USERPROFILE\.aws\config"

    if (Test-Path $configTemplate) {
        Write-Log "Copying AWS config template..."
        Copy-Item -Path $configTemplate -Destination $configDest -Force
        Write-Log "AWS config template copied" "OK"
    } else {
        Write-Log "AWS config template not found, using interactive setup" "WARN"
    }

    $setupSso = Show-MessageBox -Message "AWS SSO authentication is required for Bedrock access.`n`nPakEnergy SSO URL: https://d-9a6774682a.awsapps.com/start`n`nThis will:`n1. Open your browser`n2. Prompt you to login with PakEnergy SSO credentials`n3. Authenticate your AWS access`n`nClick OK to begin authentication." -Buttons OKCancel -Icon Information

    if ($setupSso -eq [System.Windows.Forms.DialogResult]::Cancel) {
        Write-Log "User cancelled SSO setup"
    } else {
        Write-Log "Starting AWS SSO login..."

        $ssoSuccess = $false
        $ssoRetry = $true

        while ($ssoRetry -and -not $ssoSuccess) {
            try {
                Write-Host ""
                Write-Host "============================================" -ForegroundColor Cyan
                Write-Host "AWS SSO Login" -ForegroundColor Cyan
                Write-Host "============================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Opening browser for PakEnergy SSO authentication..." -ForegroundColor Yellow
                Write-Host "SSO URL: https://d-9a6774682a.awsapps.com/start" -ForegroundColor White
                Write-Host ""

                # Capture existing profiles BEFORE running aws configure sso
                # IMPORTANT: Wrap in @() to force array - single profile returns string, not array
                $profilesBefore = @()
                try {
                    $profilesBefore = @((& aws configure list-profiles 2>$null) -split "`n" | Where-Object { $_ -ne "" })
                    Write-Log "Existing profiles before SSO ($($profilesBefore.Count)): $($profilesBefore -join ', ')"
                } catch {
                    Write-Log "Could not list existing profiles: $_"
                }

                # IMPORTANT: AWS SSO requires a proper Windows console.
                # When PowerShell is elevated via UAC, it may not have a console attached.
                # Solution: Launch aws sso login in a NEW cmd.exe window that waits for completion.
                Write-Log "Launching SSO login in new console window..."

                $ssoScriptPath = "$env:TEMP\aws-sso-login.bat"
                @"
@echo off
echo ============================================
echo AWS SSO Setup
echo ============================================
echo.
echo You will be prompted for several values.
echo Enter these EXACTLY as shown:
echo.
echo   SSO session name:  pakenergy
echo   SSO start URL:     https://d-9a6774682a.awsapps.com/start
echo   SSO region:        us-east-2
echo.
echo Then browser opens - complete PakEnergy login.
echo After login, select your AWS account and role.
echo Finally:
echo   CLI default client Region: us-east-1
echo   CLI default output format: json
echo   CLI profile name:          default
echo.
echo ============================================
echo.
aws configure sso
echo.
if %ERRORLEVEL% NEQ 0 (
    echo SSO login failed with error code %ERRORLEVEL%
    echo ERROR > "$env:TEMP\sso-result.txt"
) else (
    echo SUCCESS > "$env:TEMP\sso-result.txt"
)
echo.
echo Press any key to close this window...
pause >nul
"@ | Set-Content -Path $ssoScriptPath -Encoding ASCII

                # Remove previous result file
                Remove-Item -Path "$env:TEMP\sso-result.txt" -Force -ErrorAction SilentlyContinue

                # Launch in a new cmd.exe window and wait for it to complete
                $ssoProcess = Start-Process cmd.exe -ArgumentList "/c `"$ssoScriptPath`"" -PassThru -Wait
                Write-Log "SSO process exited with code: $($ssoProcess.ExitCode)"

                # Check result file
                $ssoResultFile = "$env:TEMP\sso-result.txt"
                $ssoOutput = ""
                if (Test-Path $ssoResultFile) {
                    $ssoOutput = Get-Content $ssoResultFile -Raw
                    Write-Log "SSO result: $ssoOutput"
                }

                # Check result - SUCCESS means SSO command exited cleanly
                if ($ssoOutput -match "SUCCESS") {
                    Write-Log "AWS SSO login command completed successfully"
                    Write-Log "AWS SSO configuration process completed"

                    # Detect the newly created profile by comparing before/after
                    # IMPORTANT: Wrap in @() to force array - single profile returns string, not array
                    $profilesAfter = @()
                    try {
                        $profilesAfter = @((& aws configure list-profiles 2>$null) -split "`n" | Where-Object { $_ -ne "" })
                        Write-Log "Profiles after SSO ($($profilesAfter.Count)): $($profilesAfter -join ', ')"
                    } catch {
                        Write-Log "Could not list profiles after SSO: $_"
                    }

                    # Find new profile (in after but not in before)
                    $newProfiles = @($profilesAfter | Where-Object { $_ -notin $profilesBefore })
                    if ($newProfiles -and $newProfiles.Count -gt 0) {
                        # Use the first new profile (there should only be one)
                        $script:detectedAwsProfile = $newProfiles[0]
                        Write-Log "Detected new AWS profile: $($script:detectedAwsProfile)" "OK"
                    } elseif ($profilesAfter -and $profilesAfter.Count -gt 0) {
                        # No new profile found, use the first available profile
                        # Force array to avoid single-string indexing issue
                        $profilesArray = @($profilesAfter)
                        $script:detectedAwsProfile = $profilesArray[0]
                        Write-Log "Using existing AWS profile: $($script:detectedAwsProfile)" "OK"
                    } else {
                        # Fallback to default
                        $script:detectedAwsProfile = "default"
                        Write-Log "No profiles detected, using 'default'" "WARN"
                    }

                    Write-Log "AWS SSO configuration successful" "OK"
                    $ssoSuccess = $true
                } else {
                    # SSO command failed or result unknown
                    Write-Log "SSO login failed or result unknown: $ssoOutput" "ERROR"
                    $retryChoice = Show-MessageBox -Message "AWS SSO login failed.`n`nThis could mean:`n- Network connectivity issues`n- Browser login was cancelled`n- SSO session expired`n`nWould you like to retry?" -Buttons YesNo -Icon Error

                    if ($retryChoice -eq [System.Windows.Forms.DialogResult]::No) {
                        $ssoRetry = $false
                    }
                }
            } catch {
                Write-Log "AWS SSO configuration failed: $_" "ERROR"
                $retryChoice = Show-MessageBox -Message "AWS SSO configuration failed:`n$_`n`nWould you like to retry?" -Buttons YesNo -Icon Error

                if ($retryChoice -eq [System.Windows.Forms.DialogResult]::No) {
                    $ssoRetry = $false
                }
            }
        }

        if (-not $ssoSuccess) {
            Write-Log "AWS SSO not configured successfully" "WARN"
            Show-MessageBox -Message "AWS SSO setup was not completed successfully.`n`nYou can configure it manually later by running:`n  aws configure sso`n`nMake sure you're connected to the VPN first." -Icon Warning
        }
    }
}

# Set CLAUDE_MODEL environment variable to Sonnet
Write-Host ""
Write-Log "Setting CLAUDE_MODEL environment variable..."
$bedrockModel = "us.anthropic.claude-sonnet-4-20250514-v1:0"
[System.Environment]::SetEnvironmentVariable("CLAUDE_MODEL", $bedrockModel, "User")
$env:CLAUDE_MODEL = $bedrockModel
Write-Log "CLAUDE_MODEL set to: $bedrockModel" "OK"

# ============================================
# Step 5: Configure Claude Code settings for Bedrock
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 5: Configuring Claude Code settings for Bedrock" "STEP"
Write-Log "============================================" "STEP"

# Ensure .claude directory exists
$claudeDir = "$env:USERPROFILE\.claude"
if (-not (Test-Path $claudeDir)) {
    Write-Log "Creating .claude directory..."
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# Copy team-settings.json template
$settingsTemplate = "$PSScriptRoot\team-settings.json"
$settingsFile = "$claudeDir\settings.json"

Write-Log "Settings template: $settingsTemplate"
Write-Log "Target settings: $settingsFile"

# Determine the awsAuthRefresh command based on detected profile
$awsAuthRefreshCmd = "aws sso login"
if ($script:detectedAwsProfile -and $script:detectedAwsProfile -ne "default") {
    $awsAuthRefreshCmd = "aws sso login --profile $($script:detectedAwsProfile)"
    Write-Log "Using profile-specific auth refresh: $awsAuthRefreshCmd"
}

if (Test-Path $settingsTemplate) {
    Write-Log "Copying team settings template..."
    Copy-Item -Path $settingsTemplate -Destination $settingsFile -Force

    # Update awsAuthRefresh and AWS_PROFILE with detected profile
    try {
        $settingsContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
        $settingsContent.awsAuthRefresh = $awsAuthRefreshCmd
        # Also set AWS_PROFILE in env so Claude Code uses the right profile for Bedrock calls
        if ($script:detectedAwsProfile) {
            if (-not $settingsContent.env) {
                $settingsContent | Add-Member -NotePropertyName "env" -NotePropertyValue @{} -Force
            }
            $settingsContent.env | Add-Member -NotePropertyName "AWS_PROFILE" -NotePropertyValue $script:detectedAwsProfile -Force
            Write-Log "Set AWS_PROFILE to: $($script:detectedAwsProfile)" "OK"
        }
        $settingsContent | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
        Write-Log "Updated awsAuthRefresh to: $awsAuthRefreshCmd" "OK"
    } catch {
        Write-Log "Could not update settings: $_" "WARN"
    }

    Write-Log "Team settings installed to $settingsFile" "OK"

    # Verify the settings file
    try {
        $settingsContent = Get-Content $settingsFile -Raw | ConvertFrom-Json
        Write-Log "Settings verification:"
        Write-Log "  - provider: $($settingsContent.provider)"
        Write-Log "  - awsAuthRefresh: $($settingsContent.awsAuthRefresh)"
        Write-Log "  - permissions.deny count: $($settingsContent.permissions.deny.Count)"
        Write-Host "  Settings configured:" -ForegroundColor Green
        Write-Host "    - Provider: bedrock" -ForegroundColor White
        Write-Host "    - Auto SSO refresh: $awsAuthRefreshCmd" -ForegroundColor White
        Write-Host "    - ADO write protection: enabled" -ForegroundColor White
    } catch {
        Write-Log "Settings verification failed: $_" "WARN"
    }
} else {
    Write-Log "Team settings template not found at: $settingsTemplate" "ERROR"
    Write-Log "Creating minimal settings manually..."

    # Fallback: create settings manually if template missing
    $envBlock = @{
        CLAUDE_CODE_USE_BEDROCK = "1"
        AWS_REGION = "us-east-1"
    }
    # Add AWS_PROFILE if we detected a profile
    if ($script:detectedAwsProfile) {
        $envBlock["AWS_PROFILE"] = $script:detectedAwsProfile
    }
    $settings = @{
        provider = "bedrock"
        awsAuthRefresh = $awsAuthRefreshCmd
        env = $envBlock
        permissions = @{
            deny = @(
                "mcp__ado__wit_create_work_item",
                "mcp__ado__wit_update_work_item",
                "mcp__ado__wit_update_work_items_batch",
                "mcp__ado__wit_add_work_item_comment"
            )
        }
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    Write-Log "Settings written manually to $settingsFile" "OK"
}

# ============================================
# Completion
# ============================================
Write-Host ""
Write-Log "============================================" "OK"
Write-Log "Installation Complete!" "OK"
Write-Log "============================================" "OK"

$completionMessage = @"
Installation completed successfully!

Configured:
- Claude Code installed
- AWS Bedrock provider configured
- Auto SSO refresh (no manual 'aws sso login' needed)
- CLAUDE_MODEL set to Claude Sonnet 4
- ADO work item write protection enabled

Next steps:
1. Open a NEW terminal/command prompt
2. Run: claude
3. Start using Claude Code!

SSO will auto-refresh when sessions start.

Log file: $LogFile
"@

Show-MessageBox -Message $completionMessage -Title "Installation Complete" -Icon Information

Write-Log "Installation completed successfully"
Write-Host ""
Write-Host "Log file: $LogFile" -ForegroundColor Cyan
Write-Host ""
pause
