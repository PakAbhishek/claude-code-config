# ============================================
# Claude Code Complete Installation & Setup
# One-click installer for Windows
# v3.0.31 - Auto-detect OneDrive path for personal vs work machines
# ============================================

# ============================================
# LOGGING SETUP - Must be first
# ============================================
$LogFile = "$env:TEMP\claude-installer.log"
$ErrorLogFile = "$env:TEMP\claude-installer-error.log"

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
"Claude Code Installer Log" | Add-Content $LogFile
"Started: $(Get-Date)" | Add-Content $LogFile
"============================================" | Add-Content $LogFile

Write-Log "Installer started"
Write-Log "Log file: $LogFile"
Write-Log "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"

# Global error handler
trap {
    Write-Log "FATAL ERROR: $_" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    $_ | Out-File -FilePath $ErrorLogFile -Append
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "INSTALLATION FAILED" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Log file: $LogFile" -ForegroundColor Yellow
    Write-Host "Error log: $ErrorLogFile" -ForegroundColor Yellow
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
Write-Log "Is admin: $isAdmin"

if (-not $isAdmin) {
    Write-Log "Not running as admin, attempting elevation..." "WARN"
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "Administrator Privileges Required" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This installer needs administrator privileges to:"
    Write-Host "  - Install Node.js (if needed)"
    Write-Host "  - Install Claude Code globally"
    Write-Host "  - Create symbolic links"
    Write-Host ""
    Write-Host "Attempting to restart with administrator privileges..." -ForegroundColor Yellow
    Write-Host ""

    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        Write-Log "Script path for elevation: $scriptPath"
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        Write-Log "Elevation request sent, exiting non-admin process"
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
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Write-Log "GUI assemblies loaded" "OK"
} catch {
    Write-Log "Failed to load GUI assemblies: $_" "ERROR"
    throw
}

# ============================================
# GUI Helper Functions
# ============================================

function Show-MessageBox {
    param(
        [string]$Message,
        [string]$Title = "Claude Code Installer",
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )
    Write-Log "Showing message box: $Title"
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

# ============================================
# Welcome Screen
# ============================================
Write-Log "Showing welcome screen..."

$welcome = Show-MessageBox -Message @"
Welcome to Claude Code Complete Installer!

This installer will:
- Check and install Node.js (if needed)
- Install/Update Claude Code to latest version
- Configure Hindsight MCP server
- Set up auto-sync for CLAUDE.md
- Install AWS CLI and configure Bedrock via SSO
- Set up automatic AWS credential push to GCP Hindsight

Click OK to begin installation.
"@ -Title "Claude Code Complete Installer" -Buttons OKCancel -Icon Information

if ($welcome -eq [System.Windows.Forms.DialogResult]::Cancel) {
    Write-Log "Installation cancelled by user"
    Write-Host "Installation cancelled by user."
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

        # Extract major version number (e.g., "v24.12.0" -> 24)
        if ($nodeVersion -match "v(\d+)") {
            $nodeVersionMajor = [int]$matches[1]
            Write-Log "Node.js major version: $nodeVersionMajor"
        }

        # Warn about Node.js v24 libuv bug on Windows
        if ($nodeVersionMajor -ge 24) {
            Write-Log "Node.js v24+ detected - known libuv assertion bug on Windows" "WARN"
            Show-MessageBox -Message "Node.js $nodeVersion detected.`n`nNote: Node.js v24 has a known bug on Windows that causes harmless 'assertion failed' errors.`n`nRecommended: Node.js v22 LTS for best stability.`n`nClaude Code will still work, but you may see red error messages." -Title "Node.js Version Notice" -Icon Warning
        }
    } else {
        Write-Log "Node.js not found (no version returned)" "WARN"
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
    } else {
        Write-Log "Git not found (no version returned)" "WARN"
    }
} catch {
    Write-Log "Git check failed: $_" "WARN"
}

if (-not $gitInstalled) {
    Write-Log "Prompting user to install Git..."
    $installGit = Show-MessageBox -Message "Git is recommended for Claude Code but not installed.`n`nGit is required for version control operations.`n`nWould you like to download and install it now?" -Buttons YesNo -Icon Question

    if ($installGit -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Downloading Git installer..."
        $gitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.2/Git-2.47.1.2-64-bit.exe"
        $gitInstallerPath = "$env:TEMP\Git-installer.exe"

        try {
            Write-Log "Downloading from: $gitInstallerUrl"
            Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $gitInstallerPath -UseBasicParsing
            Write-Log "Git downloaded, installing..."

            # Silent install with default options
            Start-Process -FilePath $gitInstallerPath -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait
            Write-Log "Git installed" "OK"

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Log "PATH refreshed"
            $gitInstalled = $true
        } catch {
            Write-Log "Failed to install Git: $_" "ERROR"
            Show-MessageBox -Message "Failed to install Git automatically.`n`nPlease install manually from:`nhttps://git-scm.com/download/win`n`nInstallation will continue without Git." -Icon Warning
        }
    } else {
        Write-Log "User declined Git installation" "WARN"
        Show-MessageBox -Message "Git is recommended but not required.`n`nYou can install it later from:`nhttps://git-scm.com/download/win" -Icon Information
    }
}

# ============================================
# Step 3: Install/Update Claude Code
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 3: Installing/Updating Claude Code" "STEP"
Write-Log "============================================" "STEP"

# First, check npm global prefix is in PATH
Write-Log "Checking npm global prefix..."
try {
    $npmPrefix = (npm config get prefix 2>$null).Trim()
    if ($npmPrefix) {
        Write-Log "npm global prefix: $npmPrefix"
        $npmBinPath = "$npmPrefix"
        if (-not ($env:Path -like "*$npmBinPath*")) {
            Write-Log "npm global prefix not in PATH, adding temporarily..." "WARN"
            $env:Path = "$npmBinPath;$env:Path"
            Write-Log "PATH updated for this session"
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

        $update = Show-MessageBox -Message "Claude Code is already installed ($claudeVersion). Update to latest version?" -Buttons YesNo -Icon Question
        if ($update -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Log "Updating Claude Code..."
            npm update -g @anthropic-ai/claude-code
            Write-Log "Claude Code updated" "OK"
        } else {
            Write-Log "User skipped update"
        }
    } else {
        Write-Log "Claude Code not found (no version returned)" "WARN"
    }
} catch {
    Write-Log "Claude Code check failed: $_" "WARN"
}

if (-not $claudeInstalled) {
    Write-Log "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Claude Code npm install completed" "OK"

        # Refresh PATH to pick up newly installed claude
        Write-Log "Refreshing PATH..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verify claude command works
        Write-Log "Verifying claude command..."
        try {
            $claudeVersion = & claude --version 2>$null
            if ($claudeVersion) {
                Write-Log "Claude Code verified: $claudeVersion" "OK"
            } else {
                Write-Log "Claude installed but 'claude' command not found in PATH" "WARN"
                $npmPrefix = (npm config get prefix 2>$null).Trim()
                Show-MessageBox -Message "Claude Code installed but not found in PATH.`n`nYou may need to:`n1. Close and reopen your terminal`n2. Or add this to your PATH: $npmPrefix`n`nThe installer will continue." -Icon Warning
            }
        } catch {
            Write-Log "Claude verification failed: $_" "WARN"
        }
    } else {
        Write-Log "npm install failed with exit code: $LASTEXITCODE" "ERROR"
        Show-MessageBox -Message "Failed to install Claude Code. Please check your internet connection and try again." -Icon Error
        exit 1
    }
}

# ============================================
# Step 4: Configure Hindsight & Auto-Sync
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 4: Configuring Hindsight & Auto-Sync" "STEP"
Write-Log "============================================" "STEP"

# Auto-detect OneDrive path (works on both personal and work machines)
Write-Log "Auto-detecting OneDrive path..."
$libDir = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "lib"
. "$libDir\Get-OneDrivePath.ps1"

try {
    $oneDrivePath = Get-OneDrivePath
    Write-Log "OneDrive detected: $oneDrivePath" "OK"
} catch {
    Write-Log "Failed to detect OneDrive: $_" "ERROR"
    Show-MessageBox -Message "OneDrive folder not found.`n`nPlease ensure OneDrive is installed and synced.`n`nChecked locations:`n- OneDrive - PakEnergy`n- OneDrive" -Icon Error
    exit 1
}

$configDir = "$oneDrivePath\Claude Backup\claude-config"
$scriptsDir = "$configDir\_scripts"
$setupScript = "$scriptsDir\setup-new-machine.bat"

Write-Log "Config dir: $configDir"
Write-Log "Scripts dir: $scriptsDir"
Write-Log "Setup script: $setupScript"

if (Test-Path $setupScript) {
    Write-Log "Setup script found, running..."
    try {
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$setupScript`"" -Wait -PassThru -NoNewWindow
        Write-Log "Setup script exit code: $($process.ExitCode)"
        if ($process.ExitCode -eq 0) {
            Write-Log "Configuration complete" "OK"
        } else {
            Write-Log "Configuration script returned non-zero exit code: $($process.ExitCode)" "WARN"
            Show-MessageBox -Message "Configuration script failed (exit code: $($process.ExitCode)). Check log for details." -Icon Warning
        }
    } catch {
        Write-Log "Failed to run setup script: $_" "ERROR"
        throw
    }
} else {
    Write-Log "Setup script not found at: $setupScript" "ERROR"
    Show-MessageBox -Message "Configuration script not found at:`n$setupScript`n`nPlease ensure OneDrive is synced." -Icon Warning
}

# ============================================
# Step 5: AWS Bedrock Configuration
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 5: AWS Bedrock Configuration (Required)" "STEP"
Write-Log "============================================" "STEP"

# Check if AWS CLI is installed
$awsCliInstalled = $false
try {
    Write-Log "Checking for AWS CLI..."
    $awsVersion = & aws --version 2>$null
    if ($awsVersion) {
        Write-Log "AWS CLI is installed: $awsVersion" "OK"
        $awsCliInstalled = $true
    } else {
        Write-Log "AWS CLI not found (no version returned)" "WARN"
    }
} catch {
    Write-Log "AWS CLI check failed: $_" "WARN"
}

if (-not $awsCliInstalled) {
    Write-Log "Prompting user to install AWS CLI..."
    $installAwsCli = Show-MessageBox -Message "AWS CLI v2 is required for Bedrock access but not installed.`n`nClick OK to download the AWS CLI installer." -Buttons OKCancel -Icon Warning

    if ($installAwsCli -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Log "Downloading AWS CLI v2 installer..."
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
            Write-Log "PATH refreshed"
        } catch {
            Write-Log "Failed to install AWS CLI: $_" "ERROR"
            Show-MessageBox -Message "Failed to install AWS CLI. Please install manually from:`nhttps://aws.amazon.com/cli/" -Icon Error
        }
    } else {
        Write-Log "User skipped AWS CLI installation"
    }
}

# Configure AWS SSO
Write-Log "Configuring AWS SSO..."
$awsDir = "$env:USERPROFILE\.aws"
if (-not (Test-Path $awsDir)) {
    Write-Log "Creating .aws directory..."
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
}

# Copy SSO config from OneDrive
$ssoConfigSource = "$configDir\aws-config-template"
$awsConfigPath = "$awsDir\config"

Write-Log "SSO config source: $ssoConfigSource"
Write-Log "AWS config path: $awsConfigPath"

if (Test-Path $ssoConfigSource) {
    Copy-Item -Path $ssoConfigSource -Destination $awsConfigPath -Force
    Write-Log "AWS SSO configuration copied" "OK"
} else {
    Write-Log "AWS SSO config template not found in OneDrive" "WARN"
}

# Determine which profile to use for verification
$awsProfileName = ""
$awsConfigContent = Get-Content $awsConfigPath -Raw -ErrorAction SilentlyContinue

if ($awsConfigContent -match '\[default\]') {
    $awsProfileName = ""  # Empty means use default
    Write-Log "Using default AWS profile for verification"
} elseif ($awsConfigContent -match '\[profile\s+(\w+)\]') {
    $awsProfileName = $matches[1]
    Write-Log "Using named AWS profile: $awsProfileName"
}

# Check if already logged in to SSO
Write-Log "Checking AWS SSO login status..."
$ssoLoggedIn = $false
try {
    $callerIdentity = & aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($callerIdentity.Account) {
        Write-Log "Already authenticated to AWS: $($callerIdentity.Arn)" "OK"
        $ssoLoggedIn = $true
    }
} catch {
    Write-Log "AWS SSO not logged in: $_"
}

if (-not $ssoLoggedIn) {
    Write-Log "AWS SSO login required, prompting user..."
    Show-MessageBox -Message "AWS SSO login is required.`n`nA browser window will open for PakEnergy SSO authentication.`n`nClick OK to proceed." -Icon Information

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
            Write-Host "Complete the login in your browser, then return here." -ForegroundColor Yellow
            Write-Host ""

            # Run aws sso login directly in the current PowerShell session
            # This avoids issues with spawning new windows from nested elevation contexts
            Write-Log "Running aws sso login inline..."

            $ssoExitCode = 0
            try {
                # Run aws sso login and capture exit code
                & aws sso login
                $ssoExitCode = $LASTEXITCODE
                Write-Log "aws sso login exited with code: $ssoExitCode"
            } catch {
                Write-Log "aws sso login threw exception: $_" "ERROR"
                $ssoExitCode = 1
            }

            # Check result - exit code 0 means SSO command completed successfully
            if ($ssoExitCode -eq 0) {
                Write-Log "AWS SSO login command completed successfully"
                Write-Host ""
                Write-Host "Verifying AWS authentication..." -ForegroundColor Cyan
                Write-Host "(This may take up to 60 seconds for credentials to propagate)" -ForegroundColor Gray

                # Check for potential clock skew before verification
                Write-Host ""
                Write-Host "Checking system clock synchronization..." -ForegroundColor Cyan
                try {
                    $localTime = Get-Date

                    # Try to get NTP time from time.windows.com
                    $w32tm = & w32tm /stripchart /computer:time.windows.com /dataonly /samples:1 2>$null
                    if ($w32tm -match "([+-]\d+\.\d+)s") {
                        $offsetSeconds = [double]$matches[1]
                        Write-Log "System clock offset: $offsetSeconds seconds"

                        if ([Math]::Abs($offsetSeconds) -gt 300) {
                            # More than 5 minutes offset - significant clock skew
                            Write-Host "  [!] WARNING: System clock is $([Math]::Round($offsetSeconds / 60, 1)) minutes off" -ForegroundColor Yellow
                            Write-Log "Significant clock skew detected: $offsetSeconds seconds" "WARN"
                            Show-MessageBox -Message "Your system clock appears to be significantly out of sync ($([Math]::Round($offsetSeconds / 60, 1)) minutes).`n`nThis can cause AWS authentication issues.`n`nConsider syncing your clock with:`n  Settings > Time & Language > Date & Time > Sync now`n`nInstallation will continue, but you may see credential warnings." -Icon Warning
                        } elseif ([Math]::Abs($offsetSeconds) -gt 30) {
                            Write-Host "  [!] Minor clock drift detected ($offsetSeconds seconds)" -ForegroundColor Yellow
                            Write-Log "Minor clock drift: $offsetSeconds seconds" "WARN"
                        } else {
                            Write-Host "  [OK] System clock is synchronized" -ForegroundColor Green
                            Write-Log "System clock synchronized (offset: $offsetSeconds seconds)" "OK"
                        }
                    } else {
                        Write-Host "  [?] Could not verify clock sync (continuing...)" -ForegroundColor Gray
                        Write-Log "Could not check clock sync - w32tm failed"
                    }
                } catch {
                    Write-Log "Clock sync check failed: $_" "WARN"
                    Write-Host "  [?] Could not verify clock sync (continuing...)" -ForegroundColor Gray
                }
                Write-Host ""

                $maxAttempts = 20
                $attemptDelay = 3
                $verified = $false

                for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                    Write-Host "  Attempt $attempt of $maxAttempts..." -NoNewline
                    Start-Sleep -Seconds $attemptDelay

                    try {
                        # Build aws command arguments
                        $awsArgs = @("sts", "get-caller-identity")
                        if ($awsProfileName) {
                            $awsArgs += @("--profile", $awsProfileName)
                        }

                        # Run AWS CLI with stderr suppressed (prevents stream mixing)
                        $jsonOutput = & aws $awsArgs 2>$null
                        $exitCode = $LASTEXITCODE

                        # Check exit code first (most reliable indicator)
                        if ($exitCode -eq 0) {
                            # Success: Parse JSON from clean stdout
                            try {
                                $callerIdentity = $jsonOutput | ConvertFrom-Json -ErrorAction Stop

                                if ($callerIdentity.Account) {
                                    Write-Host " [OK] Authenticated" -ForegroundColor Green
                                    Write-Log "AWS SSO verified: $($callerIdentity.Arn)" "OK"
                                    Write-Host ""
                                    Write-Host "Authenticated as: $($callerIdentity.Arn)" -ForegroundColor Green
                                    $verified = $true
                                    break
                                } else {
                                    Write-Host " [X] No account in response" -ForegroundColor Yellow
                                    Write-Log "AWS CLI returned valid JSON but no account field"
                                }
                            } catch {
                                Write-Log "AWS CLI exit code 0 but JSON parse failed: $_" "WARN"
                                Write-Host " [X] Parse error" -ForegroundColor Yellow
                            }
                        } else {
                            # Failure: Capture and classify error
                            $errorOutput = & aws $awsArgs 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }
                            $errorMsg = $errorOutput -join "`n"

                            Write-Log "Verification attempt $attempt failed (exit code: $exitCode): $errorMsg"

                            # Classify error type for intelligent retry
                            if ($errorMsg -match "ExpiredToken|refreshed credentials are still expired") {
                                # Two scenarios:
                                # 1. Normal expiration: Token expired, will auto-refresh at session start
                                # 2. Clock skew: Credentials can't be refreshed due to time mismatch

                                # Try to verify SSO token validity instead of credentials
                                Write-Host " [?] Checking SSO token..." -ForegroundColor Yellow
                                Write-Log "Credential error detected, checking SSO token validity"

                                $ssoTokenValid = $false
                                try {
                                    # SSO cache is in ~/.aws/sso/cache/*.json
                                    $ssoCacheDir = "$env:USERPROFILE\.aws\sso\cache"
                                    if (Test-Path $ssoCacheDir) {
                                        $cacheFiles = Get-ChildItem -Path $ssoCacheDir -Filter "*.json" -ErrorAction SilentlyContinue
                                        foreach ($cacheFile in $cacheFiles) {
                                            try {
                                                $cacheData = Get-Content $cacheFile.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
                                                if ($cacheData.expiresAt) {
                                                    # Parse expiresAt (ISO 8601 format like "2026-01-21T00:48:03Z")
                                                    $expiresAt = [DateTime]::Parse($cacheData.expiresAt).ToUniversalTime()
                                                    $now = [DateTime]::UtcNow

                                                    if ($expiresAt -gt $now) {
                                                        $hoursRemaining = [Math]::Round(($expiresAt - $now).TotalHours, 1)
                                                        Write-Host " [OK] SSO token valid ($hoursRemaining hours remaining)" -ForegroundColor Green
                                                        Write-Log "SSO token valid until $expiresAt (UTC) - $hoursRemaining hours remaining" "OK"
                                                        $ssoTokenValid = $true
                                                        break
                                                    }
                                                }
                                            } catch {
                                                # Skip invalid cache files
                                            }
                                        }
                                    }
                                } catch {
                                    Write-Log "SSO token check failed: $_" "WARN"
                                }

                                if ($ssoTokenValid) {
                                    # SSO token is valid - credential issue is likely clock skew or transient
                                    Write-Host " [OK] SSO authenticated (credentials will refresh on use)" -ForegroundColor Green
                                    Write-Log "SSO token valid - treating as success despite credential warning" "OK"
                                    $verified = $true
                                    break
                                } else {
                                    # SSO token invalid or not found - need to re-authenticate
                                    Write-Host " [X] SSO token expired or invalid" -ForegroundColor Yellow
                                    Write-Log "SSO token check failed - may need re-authentication"
                                }
                            }
                            elseif ($errorMsg -match "InvalidClientTokenId|Unable to locate credentials") {
                                Write-Host " [X] Not authenticated" -ForegroundColor Yellow
                            }
                            elseif ($errorMsg -match "Could not connect|Network|Timeout") {
                                Write-Host " [X] Network error" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host " [X] Error: $(($errorMsg -split '\n')[0])" -ForegroundColor Yellow
                            }
                        }
                    } catch {
                        # Outer catch for unexpected PowerShell errors
                        $errorMsg = $_.Exception.Message
                        Write-Log "Verification attempt $attempt exception: $errorMsg" "WARN"
                        Write-Host " [X] Exception: $(($errorMsg -split '\n')[0])" -ForegroundColor Yellow
                    }
                }

                if ($verified) {
                    Write-Log "AWS SSO verification successful" "OK"
                    $ssoSuccess = $true
                } else {
                    Write-Log "AWS SSO verification timed out after $($maxAttempts * $attemptDelay) seconds" "WARN"
                    Write-Host ""

                    $retryChoice = Show-MessageBox -Message @"
AWS SSO login completed but authentication could not be verified after 60 seconds.

This could mean:
- Credentials are still propagating (try waiting a moment)
- Browser login wasn't completed
- Network connectivity issues
- VPN not connected
- System clock is out of sync with AWS servers

If you see "refreshed credentials are still expired" errors:
- Check your system clock (Settings > Time & Language > Sync now)
- Credentials will auto-refresh when Claude Code starts

Would you like to retry the entire SSO login process?
"@ -Buttons YesNo -Icon Warning

                    if ($retryChoice -eq [System.Windows.Forms.DialogResult]::No) {
                        $ssoRetry = $false

                        # Ask if they want to continue anyway
                        $continueChoice = Show-MessageBox -Message "Continue installation without verified AWS access?`n`nYou can run 'aws sso login' manually later." -Buttons YesNo -Icon Question

                        if ($continueChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
                            Write-Log "User chose to continue without verified AWS access" "WARN"
                            $ssoSuccess = $true  # Allow installation to complete
                        }
                    }
                }
            } else {
                # SSO command failed
                Write-Log "SSO login failed with exit code: $ssoExitCode" "ERROR"
                $retryChoice = Show-MessageBox -Message "AWS SSO login failed (exit code: $ssoExitCode).`n`nThis could mean:`n- Network connectivity issues`n- Browser login was cancelled`n- SSO session expired`n`nWould you like to retry?" -Buttons YesNo -Icon Error

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
        Show-MessageBox -Message "AWS SSO setup was not completed successfully.`n`nYou can configure it manually later by running:`n  aws sso login`n`nMake sure you're connected to the VPN first." -Icon Warning
    }
}

# Set CLAUDE_MODEL environment variable permanently
Write-Host ""
Write-Log "Setting CLAUDE_MODEL environment variable..."

$bedrockModel = "us.anthropic.claude-opus-4-5-20251101-v1:0"
[System.Environment]::SetEnvironmentVariable("CLAUDE_MODEL", $bedrockModel, "User")
$env:CLAUDE_MODEL = $bedrockModel
Write-Log "CLAUDE_MODEL set to: $bedrockModel" "OK"

# ============================================
# Step 6: AWS Credential Push to GCP Hindsight
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 6: Configuring AWS Credential Push to GCP Hindsight" "STEP"
Write-Log "============================================" "STEP"

$hindsightSetupDir = "$configDir\hindsight-setup"
$autoPushScript = "$hindsightSetupDir\Auto-Push-AWS-Credentials.ps1"

Write-Log "Hindsight setup dir: $hindsightSetupDir"
Write-Log "Auto-push script: $autoPushScript"

if (Test-Path $autoPushScript) {
    Write-Log "Auto-Push script found, configuring Scheduled Task..." "OK"

    try {
        # Create Scheduled Task for login-time credential push
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$autoPushScript`""
        $trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

        # Remove existing if present
        Unregister-ScheduledTask -TaskName 'Hindsight-AWS-Credential-Push' -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Removed existing Scheduled Task (if any)"

        # Register new task
        Register-ScheduledTask -TaskName 'Hindsight-AWS-Credential-Push' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Auto-push AWS credentials to GCP Hindsight on login' | Out-Null
        Write-Log "Scheduled Task 'Hindsight-AWS-Credential-Push' registered successfully" "OK"

        # Run initial credential push now (if AWS SSO is logged in)
        Write-Host ""
        Write-Host "Pushing AWS credentials to GCP Hindsight..." -ForegroundColor Cyan
        Write-Log "Running initial credential push..."

        try {
            & $autoPushScript
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Initial credential push completed" "OK"
            } else {
                Write-Log "Initial credential push returned non-zero exit code: $LASTEXITCODE" "WARN"
            }
        } catch {
            Write-Log "Initial credential push failed: $_" "WARN"
        }

        # Verify Hindsight health (with retry)
        Write-Host ""
        Write-Host "Verifying Hindsight MCP server health..." -ForegroundColor Cyan
        Write-Log "Starting Hindsight health verification..."

        $maxHealthRetries = 3
        $healthCheckPassed = $false
        for ($healthAttempt = 1; $healthAttempt -le $maxHealthRetries; $healthAttempt++) {
            Write-Host "  Health check attempt $healthAttempt of $maxHealthRetries..." -NoNewline
            Start-Sleep -Seconds 10

            try {
                $health = Invoke-RestMethod -Uri "http://34.174.13.163:8888/health" -TimeoutSec 10 -ErrorAction Stop
                if ($health.status -eq "healthy") {
                    Write-Host " [OK] Healthy" -ForegroundColor Green
                    Write-Log "Hindsight health check PASSED: status=healthy" "OK"
                    $healthCheckPassed = $true
                    break
                } else {
                    Write-Host " [?] Status: $($health.status)" -ForegroundColor Yellow
                    Write-Log "Hindsight health check returned: $($health.status)"
                }
            } catch {
                Write-Host " [X] Connection failed" -ForegroundColor Yellow
                Write-Log "Hindsight health check attempt $healthAttempt failed: $_"
            }
        }

        if (-not $healthCheckPassed) {
            Write-Log "Hindsight health check did not pass after $maxHealthRetries attempts" "WARN"
            Write-Host ""
            Write-Host "Note: Hindsight health check did not pass. This may be because:" -ForegroundColor Yellow
            Write-Host "  - Containers are still starting up" -ForegroundColor Gray
            Write-Host "  - Network connectivity to GCP" -ForegroundColor Gray
            Write-Host "You can verify manually later with: recall('test')" -ForegroundColor Gray
        }

    } catch {
        Write-Log "Failed to configure Scheduled Task: $_" "ERROR"
        Show-MessageBox -Message "Failed to configure automatic credential push.`n`nError: $_`n`nYou can set this up manually later." -Icon Warning
    }
} else {
    Write-Log "Auto-Push script not found at: $autoPushScript" "WARN"
    Show-MessageBox -Message "Auto-Push script not found.`n`nExpected location:`n$autoPushScript`n`nAutomatic credential push will not be configured." -Icon Warning
}

Write-Log "AWS Credential Push configuration complete" "OK"

# ============================================
# Step 7: SDLC Enforcement Hooks & Settings Sync
# ============================================
Write-Host ""
Write-Log "============================================" "STEP"
Write-Log "Step 7: Configuring SDLC Enforcement Hooks & Settings Sync" "STEP"
Write-Log "============================================" "STEP"

$claudeDir = "$env:USERPROFILE\.claude"
$localHooksDir = "$claudeDir\hooks"
$oneDriveHooksDir = "$configDir\hooks"
$settingsFile = "$claudeDir\settings.json"
$oneDriveSettingsTemplate = "$configDir\settings.json"

Write-Log "Claude dir: $claudeDir"
Write-Log "Local hooks dir: $localHooksDir"
Write-Log "OneDrive hooks dir: $oneDriveHooksDir"
Write-Log "Settings file: $settingsFile"
Write-Log "Settings template: $oneDriveSettingsTemplate"

# Ensure .claude directory exists
if (-not (Test-Path $claudeDir)) {
    Write-Log "Creating .claude directory..."
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
}

# ============================================
# 6a. Symlink hooks directory
# ============================================
if (Test-Path $oneDriveHooksDir) {
    Write-Log "OneDrive hooks folder found" "OK"

    # Remove existing hooks directory if it exists (could be regular folder or symlink)
    if (Test-Path $localHooksDir) {
        $existingItem = Get-Item $localHooksDir -Force
        if ($existingItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Log "Removing existing hooks symlink..."
            Remove-Item $localHooksDir -Force
        } else {
            Write-Log "Removing existing hooks directory..."
            Remove-Item $localHooksDir -Recurse -Force
        }
    }

    # Create symlink to OneDrive hooks folder
    Write-Log "Creating hooks symlink..."
    try {
        New-Item -ItemType SymbolicLink -Path $localHooksDir -Target $oneDriveHooksDir -Force | Out-Null
        Write-Log "Hooks symlink created successfully" "OK"

        # Verify symlink
        $hookFiles = Get-ChildItem -Path $localHooksDir -Filter "*.js" -ErrorAction SilentlyContinue
        Write-Log "Found $($hookFiles.Count) hook files in symlinked directory"
    } catch {
        Write-Log "Failed to create hooks symlink: $_" "WARN"
        Write-Log "Falling back to copy method..."

        # Copy hooks as fallback
        New-Item -ItemType Directory -Path $localHooksDir -Force | Out-Null
        Copy-Item -Path "$oneDriveHooksDir\*" -Destination $localHooksDir -Recurse -Force
        Write-Log "Hooks copied to local directory" "OK"
    }
} else {
    Write-Log "OneDrive hooks folder not found at: $oneDriveHooksDir" "WARN"
    Show-MessageBox -Message "SDLC enforcement hooks not found in OneDrive.`n`nThe hooks folder should be at:`n$oneDriveHooksDir`n`nYou can set this up manually later." -Icon Warning
}

# ============================================
# 6b. Configure settings.json with auto-sync
# ============================================
Write-Log "Configuring settings.json with auto-sync..."

if (-not (Test-Path $oneDriveSettingsTemplate)) {
    Write-Log "OneDrive settings template not found, creating from defaults..." "WARN"
    # If template doesn't exist, create basic one
    $defaultSettings = @{
        "env" = @{
            "CLAUDE_CODE_USE_BEDROCK" = "1"
            "AWS_REGION" = "us-east-1"
        }
        "provider" = "bedrock"
        "model" = "us.anthropic.claude-opus-4-5-20251101-v1:0"
        "mcpServers" = @{
            "hindsight" = @{
                "url" = "http://34.174.13.163:8888/mcp/claude-code/"
            }
        }
        "hooks" = @{
            "SessionStart" = @(
                @{
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/sync-claude-md.js`""
                            "timeout" = 10
                        },
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/check-aws-sso.js`""
                            "timeout" = 120
                        }
                    )
                },
                @{
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/protocol-reminder.js`""
                            "timeout" = 5
                        }
                    )
                }
            )
            "PreToolUse" = @(
                @{
                    "matcher" = @{ "tools" = @("Edit") }
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/check-edit-token.js`""
                            "timeout" = 5
                        }
                    )
                },
                @{
                    "matcher" = @{ "tools" = @("Write") }
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/check-edit-token.js`""
                            "timeout" = 5
                        }
                    )
                },
                @{
                    "matcher" = @{ "tools" = @("Bash") }
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/check-commit-gate.js`""
                            "timeout" = 5
                        }
                    )
                }
            )
            "PostToolUse" = @(
                @{
                    "matcher" = @{ "tools" = @("Task") }
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/grant-edit-token.js`""
                            "timeout" = 10
                        }
                    )
                },
                @{
                    "matcher" = @{ "tools" = @("Edit") }
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/track-edit.js`""
                            "timeout" = 5
                        }
                    )
                },
                @{
                    "matcher" = @{ "tools" = @("Write") }
                    "hooks" = @(
                        @{
                            "type" = "command"
                            "command" = "node `"{{HOOKS_DIR}}/track-edit.js`""
                            "timeout" = 5
                        }
                    )
                }
            )
        }
    }
    $defaultJson = $defaultSettings | ConvertTo-Json -Depth 10
    Set-Content -Path $oneDriveSettingsTemplate -Value $defaultJson -Encoding UTF8
    Write-Log "Created default settings template in OneDrive"
}

# Read template and replace placeholders
Write-Log "Reading settings template from OneDrive..."
$settingsTemplate = Get-Content $oneDriveSettingsTemplate -Raw
$settingsWithPaths = $settingsTemplate -replace '\{\{HOOKS_DIR\}\}', $localHooksDir.Replace('\', '\\')

# Preserve existing permissions if settings.json already exists
$existingPermissions = $null
if (Test-Path $settingsFile) {
    try {
        $existingSettings = Get-Content $settingsFile -Raw | ConvertFrom-Json
        if ($existingSettings.permissions) {
            $existingPermissions = $existingSettings.permissions
            Write-Log "Preserving existing permissions configuration"
        }
    } catch {
        Write-Log "Could not read existing settings: $_" "WARN"
    }
}

# Parse the processed settings
$settingsContent = $settingsWithPaths | ConvertFrom-Json

# Merge back existing permissions if they exist
if ($existingPermissions) {
    $settingsContent | Add-Member -NotePropertyName "permissions" -NotePropertyValue $existingPermissions -Force
}

# Write the final settings.json
try {
    $settingsJson = $settingsContent | ConvertTo-Json -Depth 10
    Set-Content -Path $settingsFile -Value $settingsJson -Encoding UTF8
    Write-Log "Settings.json configured with OneDrive-synced hooks (NEW format)" "OK"
} catch {
    Write-Log "Failed to update settings.json: $_" "ERROR"
}

Write-Log "SDLC enforcement hooks and settings configured" "OK"

# ============================================
# Completion
# ============================================
Write-Host ""
Write-Log "============================================" "OK"
Write-Log "Installation Complete!" "OK"
Write-Log "============================================" "OK"
Write-Host ""

$completionMessage = "Installation completed successfully!`n`n" +
    "Configured:`n" +
    "- Claude Code installed`n" +
    "- Hindsight MCP server configured`n" +
    "- CLAUDE.md auto-sync enabled`n" +
    "- AWS Bedrock (via SSO) configured`n" +
    "- CLAUDE_MODEL environment variable set`n" +
    "- AWS credential auto-push to GCP Hindsight (on login)`n" +
    "- SDLC enforcement hooks (synced via OneDrive)`n" +
    "- Settings.json with NEW hook format (auto-synced)`n`n" +
    "Next steps:`n" +
    "1. Open a NEW terminal/command prompt`n" +
    "2. Run: claude`n" +
    "3. Test with: recall('test connection')`n`n" +
    "Log file: $LogFile"

Write-Log "Showing completion message..."
Show-MessageBox -Message $completionMessage -Title "Installation Complete" -Icon Information

Write-Log "Installation completed successfully"
Write-Host ""
Write-Host "Log file: $LogFile" -ForegroundColor Cyan
Write-Host ""
pause
