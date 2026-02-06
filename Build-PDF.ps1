# Build-PDF.ps1 — Generate conference-quality PDF from HINDSIGHT-DEPLOYMENT-GUIDE.md
# Requires: Pandoc, MiKTeX (xelatex), Mermaid CLI (mmdc)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "=== Hindsight Deployment Guide PDF Builder ===" -ForegroundColor Cyan
Write-Host ""

# ─── Step 1: Check / Install eisvogel template ───────────────────────────────

$templateDir = "$env:APPDATA\pandoc\templates"
$templatePath = "$templateDir\eisvogel.latex"

if (-not (Test-Path $templatePath)) {
    Write-Host "[1/5] Eisvogel template not found. Installing..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $templateDir -Force | Out-Null

    $tarUrl = "https://github.com/Wandmalfarbe/pandoc-latex-template/releases/download/v3.3.0/Eisvogel.tar.gz"
    $tarPath = "$env:TEMP\eisvogel.tar.gz"
    $extractDir = "$env:TEMP\Eisvogel-3.3.0"

    Invoke-WebRequest -Uri $tarUrl -OutFile $tarPath
    Push-Location $env:TEMP
    & "$env:SystemRoot\System32\tar.exe" -xzf eisvogel.tar.gz
    Pop-Location
    Copy-Item "$extractDir\eisvogel.latex" $templatePath

    Write-Host "  Eisvogel v3.3.0 installed to: $templatePath" -ForegroundColor Green
} else {
    Write-Host "[1/5] Eisvogel template found." -ForegroundColor Green
}

# ─── Step 2: Render Mermaid diagrams to high-res PNG ─────────────────────────

Write-Host "[2/5] Rendering Mermaid diagrams..." -ForegroundColor Cyan

$diagrams = @(
    "gcp-architecture",
    "aws-credential-pipeline",
    "onedrive-sync-tree",
    "filtering-pipeline"
)
$configPath = "$ScriptDir\diagrams\mermaid-config.json"

foreach ($diagram in $diagrams) {
    $input  = "$ScriptDir\diagrams\$diagram.mmd"
    $output = "$ScriptDir\diagrams\$diagram.png"

    if (-not (Test-Path $input)) {
        Write-Host "  WARNING: $input not found, skipping." -ForegroundColor Yellow
        continue
    }

    Write-Host "  Rendering $diagram..." -NoNewline
    & mmdc -i $input -o $output -c $configPath -s 3 -w 1200 -b white 2>&1 | Out-Null
    if (Test-Path $output) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        exit 1
    }
}

# ─── Step 3: Create temp Markdown with image references ──────────────────────

Write-Host "[3/5] Preparing Markdown for Pandoc..." -ForegroundColor Cyan

$sourceFile = "$ScriptDir\HINDSIGHT-DEPLOYMENT-GUIDE.md"
$tempFile   = "$ScriptDir\_temp-build.md"

$content = Get-Content $sourceFile -Raw -Encoding UTF8

# Replace mermaid blocks in order of appearance.
# The 4 blocks appear sequentially: GCP arch, AWS pipeline, OneDrive sync, filtering.
# We use a simple sequential approach to avoid regex cross-matching issues.
$imageReplacements = @(
    "![](diagrams/gcp-architecture.png){ width=95% }`n`n*Figure 1: GCP Deployment Architecture*",
    "![](diagrams/aws-credential-pipeline.png){ width=95% }`n`n*Figure 2: AWS Credential Pipeline*",
    "![](diagrams/onedrive-sync-tree.png){ width=55% }`n`n*Figure 3: Multi-Machine Sync Architecture*",
    "![](diagrams/filtering-pipeline.png){ width=60% }`n`n*Figure 4: Auto-Capture Filtering Pipeline*"
)

$blockIndex = 0
$result = [System.Text.StringBuilder]::new()
$i = 0
while ($i -lt $content.Length) {
    # Look for ```mermaid
    $mermaidStart = $content.IndexOf('```mermaid', $i)
    if ($mermaidStart -eq -1) {
        [void]$result.Append($content.Substring($i))
        break
    }

    # Find the closing ```
    $blockContentStart = $content.IndexOf("`n", $mermaidStart) + 1
    $closingFence = $content.IndexOf("``````", $blockContentStart)
    if ($closingFence -eq -1) {
        [void]$result.Append($content.Substring($i))
        break
    }
    $blockEnd = $closingFence + 3  # past the closing ```

    # Append everything before this mermaid block
    [void]$result.Append($content.Substring($i, $mermaidStart - $i))

    # Replace with the corresponding image reference
    if ($blockIndex -lt $imageReplacements.Count) {
        [void]$result.Append($imageReplacements[$blockIndex])
        $blockIndex++
    }

    $i = $blockEnd
}

$content = $result.ToString()

# Write temp file with UTF-8 BOM for xelatex compatibility
[System.IO.File]::WriteAllText($tempFile, $content, [System.Text.UTF8Encoding]::new($true))
Write-Host "  Temp Markdown created." -ForegroundColor Green

# ─── Step 4: Write Lua filter for page breaks ────────────────────────────────

Write-Host "[4/5] Writing Lua page-break filter..." -ForegroundColor Cyan

$luaFilter = "$ScriptDir\_pagebreak.lua"
$luaContent = @'
-- pagebreak.lua: No forced page breaks before section headings.
-- Forced \newpage/\clearpage creates blank pages when short spillover content
-- lands on a new page right before the next section heading.
-- Instead, let LaTeX handle pagination naturally. Level-1 headings are already
-- visually prominent (large bold text from eisvogel template).
-- We just add a small vertical gap for breathing room when sections flow mid-page.
function Header(el)
    if el.level == 1 then
        return {
            pandoc.RawBlock('latex', '\\vspace{1.5em}'),
            el
        }
    end
end
'@
[System.IO.File]::WriteAllText($luaFilter, $luaContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "  Lua filter written." -ForegroundColor Green

# ─── Step 5: Run Pandoc ──────────────────────────────────────────────────────

Write-Host "[5/5] Generating PDF with Pandoc + xelatex..." -ForegroundColor Cyan

$outputPdf = "$ScriptDir\HINDSIGHT-DEPLOYMENT-GUIDE.pdf"

$pandocArgs = @(
    $tempFile,
    "-f", "markdown-implicit_figures",
    "--template", "eisvogel",
    "--pdf-engine=xelatex",
    "--lua-filter=$luaFilter",
    "--syntax-highlighting=tango",
    "--number-sections",
    "--resource-path=$ScriptDir",
    "-o", $outputPdf
)

Write-Host "  Running: pandoc $($pandocArgs -join ' ')" -ForegroundColor DarkGray
& pandoc @pandocArgs

if (Test-Path $outputPdf) {
    $size = [math]::Round((Get-Item $outputPdf).Length / 1KB)
    Write-Host ""
    Write-Host "SUCCESS: PDF generated ($size KB)" -ForegroundColor Green
    Write-Host "  Output: $outputPdf" -ForegroundColor Green

    # Copy PDF to work OneDrive if available
    $workOneDrive = "$env:USERPROFILE\OneDrive - PakEnergy\Claude Backup\claude-config"
    if (Test-Path $workOneDrive) {
        Copy-Item $outputPdf "$workOneDrive\HINDSIGHT-DEPLOYMENT-GUIDE.pdf" -Force
        Write-Host "  Copied to work OneDrive: $workOneDrive" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "FAILED: PDF was not generated." -ForegroundColor Red
    exit 1
}

# ─── Cleanup ─────────────────────────────────────────────────────────────────

Remove-Item $tempFile -ErrorAction SilentlyContinue
Remove-Item $luaFilter -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Build complete." -ForegroundColor Cyan
