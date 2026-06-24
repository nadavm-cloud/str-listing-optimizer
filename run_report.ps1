<#
  STR Listing Optimizer — one-click unattended report generator.
  Flow:  URL  ->  claude headless writes listing_data.json  ->  inject into
         report_template.html  ->  Chrome headless prints the PDF  ->  open it.
  Usage:  double-click run_report.cmd, or:  powershell -File run_report.ps1 -Url "<listing url>"
#>
param([string]$Url, [string]$Model = "claude-opus-4-8")

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root "output"
$log    = Join-Path $outDir "run.log"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

function Say($m){ Write-Host "[STR] $m" -ForegroundColor Cyan; Add-Content $log "$(Get-Date -Format s)  $m" }
function Fail($m){ Write-Host "[STR] ERROR: $m" -ForegroundColor Red; Add-Content $log "$(Get-Date -Format s)  ERROR: $m"; Read-Host "Press Enter to close"; exit 1 }

Set-Content $log "STR run started $(Get-Date)"

# --- 1. get URL (GUI prompt if not supplied) ---
if (-not $Url) {
  Add-Type -AssemblyName Microsoft.VisualBasic
  $Url = [Microsoft.VisualBasic.Interaction]::InputBox("Paste the Airbnb or Booking.com listing URL:","STR Listing Optimizer","")
}
if (-not $Url -or $Url -notmatch '^https?://') { Fail "No valid URL provided." }
Say "Listing URL: $Url"

# --- 2. locate claude.exe (newest bundled version) ---
$claudeRoots = @(
  "$env:APPDATA\Claude\claude-code",
  "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code"
)
$claude = $claudeRoots |
  ForEach-Object { Get-ChildItem -Path $_ -Filter claude.exe -Recurse -ErrorAction SilentlyContinue } |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
$onPath = (Get-Command claude -ErrorAction SilentlyContinue).Source
if ($onPath) { $claude = $onPath }
if (-not $claude) { Fail "Could not find claude.exe. Install Claude Code or add it to PATH." }
Say "Using Claude CLI: $claude"

# --- 3. locate Chrome (or Edge fallback) ---
$browser = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { Fail "Could not find Chrome or Edge for PDF rendering." }
Say "Using browser: $browser"

# --- 4. build prompt and run Claude headless ---
$promptTpl = Get-Content (Join-Path $root "report_prompt.md") -Raw
$prompt    = $promptTpl.Replace("{{URL}}", $Url)
$jsonPath  = Join-Path $root "listing_data.json"
if (Test-Path $jsonPath) { Remove-Item $jsonPath -Force }

Say "Running analysis (scrape + market research + audit). This can take several minutes..."
Push-Location $root
try {
  # Permissions are governed by the scoped allowlist in .claude\settings.json
  # (web lookups, open listing, save files here). No global bypass.
  $claudeArgs = @('-p', $prompt,
            '--permission-mode', 'acceptEdits',
            '--add-dir', $root,
            '--model', $Model)
  & $claude @claudeArgs 2>&1 | Tee-Object -FilePath (Join-Path $outDir "claude.log")
} finally { Pop-Location }

if (-not (Test-Path $jsonPath)) { Fail "Analysis finished but listing_data.json was not produced. See output\claude.log." }

# --- 5. validate JSON ---
try { $data = Get-Content $jsonPath -Raw | ConvertFrom-Json }
catch { Fail "listing_data.json is not valid JSON: $($_.Exception.Message)" }
Say "listing_data.json validated."

# --- 6. inject data into template ---
$tpl  = Get-Content (Join-Path $root "report_template.html") -Raw
$json = Get-Content $jsonPath -Raw
$html = $tpl.Replace("__LISTING_DATA__", $json)
$reportHtml = Join-Path $outDir "str_optimization_report.html"
[System.IO.File]::WriteAllText($reportHtml, $html, (New-Object System.Text.UTF8Encoding $false))
Say "Report HTML built: $reportHtml"

# --- 7. render PDF with headless browser ---
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$pdf   = Join-Path $outDir "str_optimization_report_$stamp.pdf"
$uri   = "file:///" + ($reportHtml -replace '\\','/')
$tmpProfile = Join-Path $env:TEMP "str_chrome_$stamp"
& $browser --headless=new --disable-gpu --no-pdf-header-footer `
  --user-data-dir="$tmpProfile" --print-to-pdf="$pdf" "$uri" 2>&1 | Out-Null
Start-Sleep -Milliseconds 400
if (-not (Test-Path $pdf)) { Fail "Browser did not produce a PDF. HTML is available at $reportHtml" }
Remove-Item $tmpProfile -Recurse -Force -ErrorAction SilentlyContinue
Say "PDF created: $pdf"

# --- 8. 3-line summary + open ---
$bestRoi = ($data.owner_summary.bullets | Where-Object { $_.label -match 'ROI' } | Select-Object -First 1).text
Write-Host ""
Write-Host "==================== SUMMARY ====================" -ForegroundColor Green
Write-Host ("Verdict      : " + $data.owner_summary.headline)
Write-Host ("Best ROI fix : " + $bestRoi)
Write-Host ("Total upside : " + $data.total_upside)
Write-Host "=================================================" -ForegroundColor Green

Invoke-Item $pdf
Say "Done."
