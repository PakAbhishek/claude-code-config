# PowerShell script to add Hindsight MCP server
# Uses Claude Code CLI to properly configure MCP servers
# Used by setup-new-machine.bat
# v3.0.20 - Project-aware MCP registration + deprecated config cleanup

param(
    [string]$HindsightUrl = "http://hindsight-achau.southcentralus.azurecontainer.io:8888/mcp/claude-code/"
)

# Helper function to run claude commands and filter out libuv assertion errors
function Invoke-ClaudeCommand {
    param([string]$Arguments)

    # Create temp files for output
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        # Run claude command via cmd.exe, redirecting output to temp files
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c claude $Arguments 1>$stdoutFile 2>$stderrFile" -Wait -PassThru -NoNewWindow

        $stdout = Get-Content $stdoutFile -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue

        # Filter out the libuv assertion error from stderr
        if ($stderr) {
            $stderr = $stderr -replace "Assertion failed:.*UV_HANDLE_CLOSING.*\r?\n?", ""
        }

        return @{
            Output = if ($stdout) { $stdout.Trim() } else { "" }
            Error = if ($stderr) { $stderr.Trim() } else { "" }
            ExitCode = $process.ExitCode
        }
    } finally {
        # Clean up temp files
        Remove-Item $stdoutFile -ErrorAction SilentlyContinue
        Remove-Item $stderrFile -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host "Configuring Hindsight MCP server..."

    # Refresh PATH in case Claude was just installed
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Also check npm global prefix
    try {
        $npmPrefix = (npm config get prefix 2>$null)
        if ($npmPrefix) {
            $npmPrefix = $npmPrefix.Trim()
            if ($npmPrefix -and -not ($env:Path -like "*$npmPrefix*")) {
                $env:Path = "$npmPrefix;$env:Path"
                Write-Host "Added npm prefix to PATH: $npmPrefix"
            }
        }
    } catch {
        Write-Host "Could not check npm prefix: $_"
    }

    # Check if claude command is available
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Host "Claude not found in PATH, checking common locations..."

        # Check common npm global locations
        $possiblePaths = @(
            "$env:APPDATA\npm\claude.cmd",
            "$env:USERPROFILE\AppData\Roaming\npm\claude.cmd",
            "C:\Program Files\nodejs\claude.cmd"
        )

        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $parentDir = Split-Path $path -Parent
                $env:Path = "$parentDir;$env:Path"
                Write-Host "Found claude at: $path"
                break
            }
        }

        # Try again
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
        if (-not $claudeCmd) {
            Write-Error "Claude Code CLI not found. Please ensure Claude Code is installed and in PATH."
            Write-Host "Current PATH: $env:Path"
            exit 1
        }
    }

    Write-Host "Claude found at: $($claudeCmd.Source)"

    # Ensure we're registering for a consistent project (C:\ is the common base)
    $targetProject = "C:\"
    Push-Location $targetProject
    Write-Host "Registering Hindsight for project: $targetProject"

    try {
        # Check if hindsight is already configured for THIS project
        Write-Host "Checking existing MCP configuration..."
        $mcpResult = Invoke-ClaudeCommand -Arguments "mcp list"

        if ($mcpResult.Output -match "hindsight.*Connected" -or $mcpResult.Output -match "hindsight:") {
            Write-Host "Hindsight MCP server is already configured for this project"
            # Show filtered output
            if ($mcpResult.Output) { Write-Host $mcpResult.Output }
            Pop-Location

            # Clean up deprecated config even if already registered
            $settingsPath = "$env:USERPROFILE\.claude\settings.json"
            if (Test-Path $settingsPath) {
                $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
                if ($settings.mcpServers) {
                    Write-Host "Removing deprecated mcpServers field from settings.json..."
                    $settings.PSObject.Properties.Remove('mcpServers')
                    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                    Write-Host "Deprecated configuration cleaned up"
                }
            }

            exit 0
        }

        # Add Hindsight MCP server using CLI
        Write-Host "Adding Hindsight MCP server via CLI..."
        $addResult = Invoke-ClaudeCommand -Arguments "mcp add --transport http hindsight $HindsightUrl"

        if ($addResult.ExitCode -eq 0) {
            Write-Host "Hindsight MCP server added successfully"
            Write-Host ""
            Write-Host "Verifying connection..."
            Start-Sleep -Seconds 1
            $verifyResult = Invoke-ClaudeCommand -Arguments "mcp list"
            if ($verifyResult.Output) { Write-Host $verifyResult.Output }

            # Clean up deprecated configuration from settings.json
            Write-Host ""
            Write-Host "Cleaning up deprecated configuration..."
            $settingsPath = "$env:USERPROFILE\.claude\settings.json"
            if (Test-Path $settingsPath) {
                $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

                $cleaned = $false

                # Remove deprecated mcpServers field
                if ($settings.mcpServers) {
                    Write-Host "  Removing deprecated mcpServers field..."
                    $settings.PSObject.Properties.Remove('mcpServers')
                    $cleaned = $true
                }

                # Remove deprecated enabledMcpjsonServers if it references Hindsight
                if ($settings.enabledMcpjsonServers -and ($settings.enabledMcpjsonServers -contains "hindsight")) {
                    Write-Host "  Removing Hindsight from deprecated enabledMcpjsonServers..."
                    $settings.enabledMcpjsonServers = @($settings.enabledMcpjsonServers | Where-Object { $_ -ne "hindsight" })
                    if ($settings.enabledMcpjsonServers.Count -eq 0) {
                        $settings.PSObject.Properties.Remove('enabledMcpjsonServers')
                    }
                    $cleaned = $true
                }

                if ($cleaned) {
                    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                    Write-Host "Deprecated configuration removed"
                } else {
                    Write-Host "No deprecated configuration found"
                }
            }

            Pop-Location
            exit 0
        } else {
            $errorMsg = if ($addResult.Error) { $addResult.Error } else { $addResult.Output }
            Write-Error "Failed to add Hindsight MCP server: $errorMsg"
            Pop-Location
            exit 1
        }
    } finally {
        # Ensure we return to original directory
        if ((Get-Location).Path -eq $targetProject) {
            Pop-Location
        }
    }

} catch {
    Write-Error "Failed to configure Hindsight MCP server: $_"
    exit 1
}
