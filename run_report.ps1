<#
  STR Listing Optimizer — one-click report generator.
  Flow:  URL dialog  →  Claude AI analysis (silent)  →  PDF  →  open
  Usage: double-click run_report.cmd
         or: powershell -File run_report.ps1 -Url "<url>"
#>
param([string]$Url, [string]$Model = "claude-opus-4-8")

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root "output"
$log    = Join-Path $outDir "run.log"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-Content $log "STR run started $(Get-Date)" -Encoding UTF8
try { $Host.UI.RawUI.WindowTitle = "STR Listing Optimizer" } catch {}

# ── Helpers ──────────────────────────────────────────────────────────────────
function Step($n, $of, $msg) {
    Write-Host ""
    Write-Host "  [$n/$of] $msg" -ForegroundColor Cyan
    Add-Content $log "$(Get-Date -Format s)  [$n/$of] $msg"
}
function OK($msg) { Write-Host "       [OK] $msg" -ForegroundColor Green }
function Fail($msg) {
    Write-Host ""
    Write-Host "  [ERROR] $msg" -ForegroundColor Red
    Add-Content $log "$(Get-Date -Format s)  ERROR  $msg"
    try {
        [System.Windows.Forms.MessageBox]::Show(
            $msg, "STR Listing Optimizer - Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } catch {}
    Write-Host ""
    Read-Host "  Press Enter to close"
    exit 1
}
function Toast($title, $body) {
    try {
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information
        $n.BalloonTipTitle = $title
        $n.BalloonTipText  = $body
        $n.Visible = $true
        $n.ShowBalloonTip(8000)
        Start-Sleep -Milliseconds 300
        $n.Dispose()
    } catch {}
}

# ── Banner ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "   STR Listing Optimizer  |  AI Revenue Audit" -ForegroundColor White
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host ""

# ── URL input (Windows dialog) ───────────────────────────────────────────────
if (-not $Url) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = "STR Listing Optimizer"
    $form.ClientSize      = New-Object System.Drawing.Size(500, 150)
    $form.StartPosition   = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.TopMost         = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text     = "Paste the Airbnb or Booking.com listing URL:"
    $lbl.Location = New-Object System.Drawing.Point(14, 16)
    $lbl.Size     = New-Object System.Drawing.Size(472, 18)
    $lbl.Font     = New-Object System.Drawing.Font("Segoe UI", 10)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location  = New-Object System.Drawing.Point(14, 42)
    $tb.Size      = New-Object System.Drawing.Size(472, 26)
    $tb.Font      = New-Object System.Drawing.Font("Segoe UI", 11)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text      = "The AI will scrape the listing, research the market, and write a full PDF audit (2-4 min)."
    $hint.Location  = New-Object System.Drawing.Point(14, 74)
    $hint.Size      = New-Object System.Drawing.Size(472, 18)
    $hint.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
    $hint.ForeColor = [System.Drawing.Color]::Gray

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text         = "Run Analysis"
    $btn.Location     = New-Object System.Drawing.Point(14, 100)
    $btn.Size         = New-Object System.Drawing.Size(472, 36)
    $btn.Font         = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $btn
    $form.Controls.AddRange(@($lbl, $tb, $hint, $btn))

    if ($form.ShowDialog() -ne 'OK' -or -not $tb.Text.Trim()) {
        Write-Host "  Cancelled." -ForegroundColor DarkGray
        exit 0
    }
    $Url = $tb.Text.Trim()
}
if ($Url -notmatch '^https?://') { Fail "URL must start with https://`n`nYou entered: $Url" }
Write-Host "  Listing: $Url" -ForegroundColor DarkCyan

# ── 1/3  Locate tools ────────────────────────────────────────────────────────
Step 1 3 "Locating tools..."

$claudeRoots = @(
    "$env:APPDATA\Claude\claude-code",
    "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code"
)
$claude = $claudeRoots |
    ForEach-Object { Get-ChildItem -Path $_ -Filter claude.exe -Recurse -ErrorAction SilentlyContinue } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
$onPath = (Get-Command claude -ErrorAction SilentlyContinue).Source
if ($onPath) { $claude = $onPath }
if (-not $claude) { Fail "Could not find claude.exe.`nMake sure the Claude Code desktop app is installed." }
OK "Claude AI   -> $(Split-Path $claude -Leaf)"

$browser = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { Fail "Could not find Chrome or Edge.`nInstall Google Chrome and try again." }
OK "PDF engine  -> $(Split-Path $browser -Leaf)"

# ── 2/3  Run AI analysis (silent — output goes to log file) ──────────────────
Step 2 3 "Running AI analysis  (grab a coffee, this takes 2-4 minutes...)"
Write-Host ""
Write-Host "    Scraping listing, researching the market, writing your audit." -ForegroundColor DarkGray
Write-Host "    Full log: output\claude.log" -ForegroundColor DarkGray
Write-Host ""

$promptTpl = Get-Content (Join-Path $root "report_prompt.md") -Raw
$prompt    = $promptTpl.Replace("{{URL}}", $Url)
$jsonPath  = Join-Path $root "listing_data.json"
$claudeLog = Join-Path $outDir "claude.log"
if (Test-Path $jsonPath) { Remove-Item $jsonPath -Force }

# Write prompt to a temp file so the background job can read it
# (avoids PowerShell argument-length limits for large prompts)
$pFile = Join-Path $env:TEMP "str_prompt_$(Get-Date -Format HHmmss).txt"
[System.IO.File]::WriteAllText($pFile, $prompt, [System.Text.Encoding]::UTF8)

$job = Start-Job -ScriptBlock {
    param($exe, $pf, $rt, $md, $lg)
    Set-Location $rt
    $p = [System.IO.File]::ReadAllText($pf)
    & $exe -p $p --permission-mode acceptEdits --add-dir $rt --model $md 2>&1 |
        Out-File $lg -Encoding UTF8
} -ArgumentList $claude, $pFile, $root, $Model, $claudeLog

# Progress bar while Claude works (so the window doesn't look frozen)
$t0 = Get-Date
while ($job.State -eq 'Running') {
    $e   = (Get-Date) - $t0
    $pct = [math]::Min([int]($e.TotalSeconds / 240 * 100), 95)
    $kb  = if (Test-Path $claudeLog) { "$([math]::Round((Get-Item $claudeLog).Length / 1024, 0)) KB" } else { "starting..." }
    Write-Progress -Activity "AI Analysis" `
        -Status "$([int]$e.TotalMinutes)m $($e.Seconds)s elapsed  |  $kb written to log" `
        -PercentComplete $pct
    Start-Sleep -Milliseconds 700
}
Write-Progress -Completed -Activity "AI Analysis"
Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
Remove-Job $job -Force
Remove-Item $pFile -ErrorAction SilentlyContinue

if (-not (Test-Path $jsonPath)) {
    Fail "Analysis finished but no report data was produced.`nCheck output\claude.log for details."
}
try { $data = Get-Content $jsonPath -Raw | ConvertFrom-Json }
catch { Fail "Report data file is not valid JSON: $($_.Exception.Message)" }
OK "Analysis complete"

# ── 3/3  Build PDF ───────────────────────────────────────────────────────────
Step 3 3 "Building PDF report..."

$tpl        = Get-Content (Join-Path $root "report_template.html") -Raw
$json       = Get-Content $jsonPath -Raw
$html       = $tpl.Replace("__LISTING_DATA__", $json)
$reportHtml = Join-Path $outDir "str_optimization_report.html"
[System.IO.File]::WriteAllText($reportHtml, $html, (New-Object System.Text.UTF8Encoding $false))

$stamp      = Get-Date -Format "yyyyMMdd-HHmmss"
$pdf        = Join-Path $outDir "str_optimization_report_$stamp.pdf"
$uri        = "file:///" + ($reportHtml -replace '\\', '/')
$tmpProfile = Join-Path $env:TEMP "str_chrome_$stamp"

& $browser --headless=new --disable-gpu --no-pdf-header-footer `
    --user-data-dir="$tmpProfile" --print-to-pdf="$pdf" "$uri" 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
if (-not (Test-Path $pdf)) {
    Fail "Browser did not produce a PDF.`nHTML report is available at:`n$reportHtml"
}
Remove-Item $tmpProfile -Recurse -Force -ErrorAction SilentlyContinue
OK "PDF saved: output\$(Split-Path $pdf -Leaf)"

# ── Summary ──────────────────────────────────────────────────────────────────
$headline = $data.owner_summary.headline
$quickWin = ($data.owner_summary.bullets | Where-Object { $_.label -match 'quick' } | Select-Object -First 1).text
$bestRoi  = ($data.owner_summary.bullets | Where-Object { $_.label -match 'ROI'   } | Select-Object -First 1).text
$upside   = $data.total_upside

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "  REPORT SUMMARY" -ForegroundColor White
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "  $headline" -ForegroundColor White
Write-Host ""
if ($quickWin) { Write-Host "  Quick win : $quickWin" -ForegroundColor White }
if ($bestRoi)  { Write-Host "  Best ROI  : $bestRoi"  -ForegroundColor White }
if ($upside)   { Write-Host "  Upside    : $upside"   -ForegroundColor Yellow }
Write-Host "  ================================================" -ForegroundColor Green

Write-Host ""
Write-Host "  Opening your PDF now..." -ForegroundColor Cyan
Toast "STR Report Ready!" "$upside estimated upside. Your audit PDF is opening now."
Invoke-Item $pdf

Add-Content $log "$(Get-Date -Format s)  Done. PDF: $pdf"
Write-Host ""
Write-Host "  Done! You can close this window." -ForegroundColor Green
Write-Host ""
