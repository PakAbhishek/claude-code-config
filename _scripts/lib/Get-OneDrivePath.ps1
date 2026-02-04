# ============================================
# Get-OneDrivePath.ps1
# Utility function to auto-detect OneDrive path
# Works on both personal (OneDrive) and work (OneDrive - PakEnergy) machines
# ============================================

function Get-OneDrivePath {
    <#
    .SYNOPSIS
    Detects and returns the OneDrive path for this machine.

    .DESCRIPTION
    Checks for OneDrive folders in order of priority:
    1. "OneDrive - PakEnergy" (work machine - more specific)
    2. "OneDrive" (personal machine)

    Returns the first existing path, or throws an error if neither exists.

    .EXAMPLE
    $oneDrive = Get-OneDrivePath
    $configDir = Join-Path $oneDrive "Claude Backup\claude-config"
    #>

    $candidates = @(
        "OneDrive - PakEnergy",  # Work machine (more specific, check first)
        "OneDrive"               # Personal machine
    )

    foreach ($candidate in $candidates) {
        $fullPath = Join-Path $env:USERPROFILE $candidate
        if (Test-Path $fullPath) {
            return $fullPath
        }
    }

    throw "OneDrive folder not found. Checked: $($candidates -join ', ')"
}

# Export function if running in module context
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function Get-OneDrivePath
}
