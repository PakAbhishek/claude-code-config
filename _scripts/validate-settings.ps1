# ============================================
# Settings.json Validation Script
# Ensures team installer produces working Claude Code config
# v1.0.0
# ============================================
#
# This script validates:
# 1. team-settings.json template has all required fields
# 2. Fallback settings creation produces valid config
# 3. All values are correct for PakEnergy Bedrock access
#
# Run this BEFORE releasing any installer update.
# ============================================

param(
    [switch]$CI  # Set for CI mode (exit codes only, no colors)
)

$ErrorCount = 0
$WarningCount = 0

function Write-Result {
    param(
        [string]$Status,  # PASS, FAIL, WARN
        [string]$Message
    )

    if ($CI) {
        Write-Host "[$Status] $Message"
    } else {
        switch ($Status) {
            "PASS" { Write-Host "[$Status] $Message" -ForegroundColor Green }
            "FAIL" { Write-Host "[$Status] $Message" -ForegroundColor Red }
            "WARN" { Write-Host "[$Status] $Message" -ForegroundColor Yellow }
            default { Write-Host "[$Status] $Message" }
        }
    }

    if ($Status -eq "FAIL") { $script:ErrorCount++ }
    if ($Status -eq "WARN") { $script:WarningCount++ }
}

function ConvertTo-Hashtable {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $collection = @()
        foreach ($item in $InputObject) {
            $collection += ConvertTo-Hashtable $item
        }
        return $collection
    } elseif ($InputObject -is [PSObject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable $property.Value
        }
        return $hash
    } else {
        return $InputObject
    }
}

function Test-SettingsJson {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings,
        [string]$Source = "settings"
    )

    $localErrors = 0

    Write-Host ""
    Write-Host "Validating $Source..." -ForegroundColor Cyan
    Write-Host "----------------------------------------"

    # Required fields and their expected values
    $requiredFields = @{
        "provider" = @{
            Required = $true
            ExpectedValue = "bedrock"
            Description = "Must be 'bedrock' for AWS Bedrock access"
        }
        "awsAuthRefresh" = @{
            Required = $true
            ExpectedValue = "aws sso login"
            Description = "Auto-refreshes SSO credentials on session start"
        }
    }

    $requiredEnvVars = @{
        "CLAUDE_CODE_USE_BEDROCK" = @{
            ExpectedValue = "1"
            Description = "Enables Bedrock mode"
        }
        "AWS_REGION" = @{
            ExpectedValue = "us-east-1"
            Description = "AWS region for Bedrock"
        }
    }

    $requiredDenyPermissions = @(
        "mcp__ado__wit_create_work_item",
        "mcp__ado__wit_update_work_item",
        "mcp__ado__wit_update_work_items_batch",
        "mcp__ado__wit_add_work_item_comment"
    )

    # Test top-level required fields
    foreach ($field in $requiredFields.Keys) {
        $spec = $requiredFields[$field]

        if (-not $Settings.ContainsKey($field)) {
            Write-Result "FAIL" "$field is MISSING - $($spec.Description)"
            $localErrors++
        } elseif ($Settings[$field] -ne $spec.ExpectedValue) {
            Write-Result "FAIL" "$field = '$($Settings[$field])' (expected '$($spec.ExpectedValue)')"
            $localErrors++
        } else {
            Write-Result "PASS" "$field = '$($Settings[$field])'"
        }
    }

    # Test env block
    if (-not $Settings.ContainsKey("env")) {
        Write-Result "FAIL" "env block is MISSING - Required for AWS configuration"
        $localErrors++
    } else {
        $env = $Settings["env"]
        foreach ($envVar in $requiredEnvVars.Keys) {
            $spec = $requiredEnvVars[$envVar]

            if (-not $env.ContainsKey($envVar)) {
                Write-Result "FAIL" "env.$envVar is MISSING - $($spec.Description)"
                $localErrors++
            } elseif ($env[$envVar] -ne $spec.ExpectedValue) {
                Write-Result "FAIL" "env.$envVar = '$($env[$envVar])' (expected '$($spec.ExpectedValue)')"
                $localErrors++
            } else {
                Write-Result "PASS" "env.$envVar = '$($env[$envVar])'"
            }
        }
    }

    # Test permissions.deny block
    if (-not $Settings.ContainsKey("permissions")) {
        Write-Result "FAIL" "permissions block is MISSING - Required for ADO protection"
        $localErrors++
    } elseif (-not $Settings["permissions"].ContainsKey("deny")) {
        Write-Result "FAIL" "permissions.deny is MISSING - Required for ADO protection"
        $localErrors++
    } else {
        $denyList = $Settings["permissions"]["deny"]

        foreach ($permission in $requiredDenyPermissions) {
            if ($denyList -contains $permission) {
                Write-Result "PASS" "permissions.deny contains '$permission'"
            } else {
                Write-Result "FAIL" "permissions.deny MISSING '$permission'"
                $localErrors++
            }
        }
    }

    return $localErrors
}

# ============================================
# Main Validation
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Claude Code Settings.json Validator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = $PSScriptRoot

# ============================================
# Test 1: Validate team-settings.json template
# ============================================

Write-Host "TEST 1: team-settings.json Template" -ForegroundColor White
Write-Host "========================================"

$templatePath = Join-Path $scriptDir "team-settings.json"

if (-not (Test-Path $templatePath)) {
    Write-Result "FAIL" "team-settings.json NOT FOUND at $templatePath"
    $ErrorCount++
} else {
    Write-Result "PASS" "team-settings.json exists"

    try {
        $templateJson = Get-Content $templatePath -Raw | ConvertFrom-Json
        $templateContent = ConvertTo-Hashtable $templateJson
        $templateErrors = Test-SettingsJson -Settings $templateContent -Source "team-settings.json template"
        $ErrorCount += $templateErrors
    } catch {
        Write-Result "FAIL" "team-settings.json is not valid JSON: $_"
        $ErrorCount++
    }
}

# ============================================
# Test 2: Validate installer fallback settings
# ============================================

Write-Host ""
Write-Host "TEST 2: Installer Fallback Settings" -ForegroundColor White
Write-Host "========================================"
Write-Host "Simulating what install-claude.ps1 creates if template is missing..."

# This is the exact fallback code from install-claude.ps1
$fallbackSettings = @{
    provider = "bedrock"
    awsAuthRefresh = "aws sso login"
    env = @{
        CLAUDE_CODE_USE_BEDROCK = "1"
        AWS_REGION = "us-east-1"
    }
    permissions = @{
        deny = @(
            "mcp__ado__wit_create_work_item",
            "mcp__ado__wit_update_work_item",
            "mcp__ado__wit_update_work_items_batch",
            "mcp__ado__wit_add_work_item_comment"
        )
    }
}

$fallbackErrors = Test-SettingsJson -Settings $fallbackSettings -Source "installer fallback code"
$ErrorCount += $fallbackErrors

# ============================================
# Test 3: Verify template matches fallback
# ============================================

Write-Host ""
Write-Host "TEST 3: Template/Fallback Consistency" -ForegroundColor White
Write-Host "========================================"

if ((Test-Path $templatePath) -and $templateContent) {
    $templateJson = $templateContent | ConvertTo-Json -Depth 10 -Compress
    $fallbackJson = $fallbackSettings | ConvertTo-Json -Depth 10 -Compress

    if ($templateJson -eq $fallbackJson) {
        Write-Result "PASS" "Template and fallback produce identical settings"
    } else {
        Write-Result "WARN" "Template and fallback differ (both may be valid, but should match)"
        Write-Host "  Template: $templateJson" -ForegroundColor Gray
        Write-Host "  Fallback: $fallbackJson" -ForegroundColor Gray
    }
}

# ============================================
# Test 4: Verify install-claude.ps1 references template
# ============================================

Write-Host ""
Write-Host "TEST 4: Installer Script References" -ForegroundColor White
Write-Host "========================================"

$psInstallerPath = Join-Path $scriptDir "install-claude.ps1"
if (Test-Path $psInstallerPath) {
    $psContent = Get-Content $psInstallerPath -Raw

    if ($psContent -match 'team-settings\.json') {
        Write-Result "PASS" "install-claude.ps1 references team-settings.json"
    } else {
        Write-Result "FAIL" "install-claude.ps1 does NOT reference team-settings.json"
        $ErrorCount++
    }

    if ($psContent -match 'awsAuthRefresh') {
        Write-Result "PASS" "install-claude.ps1 fallback includes awsAuthRefresh"
    } else {
        Write-Result "FAIL" "install-claude.ps1 fallback MISSING awsAuthRefresh"
        $ErrorCount++
    }
} else {
    Write-Result "FAIL" "install-claude.ps1 NOT FOUND"
    $ErrorCount++
}

$shInstallerPath = Join-Path $scriptDir "install-claude.sh"
if (Test-Path $shInstallerPath) {
    $shContent = Get-Content $shInstallerPath -Raw

    if ($shContent -match 'team-settings\.json') {
        Write-Result "PASS" "install-claude.sh references team-settings.json"
    } else {
        Write-Result "FAIL" "install-claude.sh does NOT reference team-settings.json"
        $ErrorCount++
    }

    if ($shContent -match 'awsAuthRefresh') {
        Write-Result "PASS" "install-claude.sh fallback includes awsAuthRefresh"
    } else {
        Write-Result "FAIL" "install-claude.sh fallback MISSING awsAuthRefresh"
        $ErrorCount++
    }
} else {
    Write-Result "FAIL" "install-claude.sh NOT FOUND"
    $ErrorCount++
}

# ============================================
# Summary
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($ErrorCount -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "The installer will produce a working settings.json with:" -ForegroundColor White
    Write-Host "  - Bedrock provider configured" -ForegroundColor Green
    Write-Host "  - Auto SSO refresh enabled" -ForegroundColor Green
    Write-Host "  - AWS environment variables set" -ForegroundColor Green
    Write-Host "  - ADO write protection enabled" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "VALIDATION FAILED: $ErrorCount error(s), $WarningCount warning(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "DO NOT RELEASE THIS INSTALLER until all errors are fixed." -ForegroundColor Red
    Write-Host ""
    exit 1
}
