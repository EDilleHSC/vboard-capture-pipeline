<#
Upgrade validation helper
Usage: Run this script from the repo root:
  pwsh .\scripts\upgrade_validation_check.ps1

Behavior:
- Runs the Step 4 checklist as much as possible automatically
- Prints PASS / FAIL / SKIPPED for each item
- Exits with code 0 if all items PASS or SKIPPED; exits non-zero if any FAIL

Notes:
- This script is intentionally conservative (skips steps that are not defined in package.json)
- Run manually and attach logs to upgrade PR
#>

Param(
    [string]$CreateBranchName,
    [string]$TargetDoclingVersion
)

Set-StrictMode -Version Latest
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir\.. | Out-Null

$results = @()
function Report($name, $status, $note='') {
    $results += [PSCustomObject]@{ Check = $name; Status = $status; Note = $note }
    $pad = 50
    if ($status -eq 'PASS') { $color = 'Green' } elseif ($status -eq 'FAIL') { $color = 'Red' } else { $color = 'Yellow' }
    Write-Host ("{0,-$pad} {1}" -f $name, $status) -ForegroundColor $color
    if ($note) { Write-Host "  Note: $note" }
}

# Helper to choose runner (pnpm preferred)
function Get-RunnerCmd {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) { return 'pnpm' }
    if (Get-Command npm -ErrorAction SilentlyContinue) { return 'npm' }
    return $null
}

# STEP 0 — CONFIRMATION (DO NOT SKIP)
Write-Host "STEP 0 — CONFIRMATION: reporting current branch and git status"
# current branch (wrap git calls to capture stderr for clearer messages)
try {
    $branch = git rev-parse --abbrev-ref HEAD 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed: $branch" }
    Write-Host "Current branch: $branch"
    Report 'current branch' 'PASS'
} catch {
    Report 'current branch' 'FAIL' "git not available or not a repo: $_"
    exit 2
}

# git status
try {
    $gst = git status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git status failed: $gst" }
    if (-not [string]::IsNullOrWhiteSpace($gst)) { Report 'git status is clean' 'FAIL' 'Working tree contains changes'; Write-Host 'Please commit or stash changes and re-run.'; exit 2 } else { Report 'git status is clean' 'PASS' }
} catch {
    Report 'git status is clean' 'FAIL' "git not available or not a repo: $_"
    exit 2
}

# check for running dev servers (mcp_server pid files)
$pidCandidates = @('runtime/current/mcp_server.pid','runtime/mcp_server.pid')
$devServerRunning = $false
foreach ($pfile in $pidCandidates) {
    if (Test-Path $pfile) {
        try {
            $pid = Get-Content $pfile -ErrorAction Stop
            if ($pid -match '^\d+$') {
                $proc = Get-Process -Id [int]$pid -ErrorAction SilentlyContinue
                if ($proc) { Report 'No dev server running' 'FAIL' "PID $pid from $pfile is running (process: $($proc.ProcessName)). Please stop it and re-run."; exit 2 }
            } else { Report 'No dev server running' 'FAIL' "Found pid file $pfile but content is not a pid"; exit 2 }
        } catch { Report 'No dev server running' 'FAIL' "Found pid file $pfile but could not verify process: $_"; exit 2 }
    }
}
Report 'No dev server running' 'PASS'

# Branch creation / validation
$pattern = '^upgrade/docling-\d{4}-\d{2}-\d{2}$'
if ($CreateBranchName) {
    if (-not ($CreateBranchName -match $pattern)) { Report 'Branch name valid' 'FAIL' "Branch name must match upgrade/docling-YYYY-MM-DD"; exit 2 }
    # ensure doesn't exist
    git rev-parse --verify --quiet refs/heads/$CreateBranchName > $null 2>&1
    if ($LASTEXITCODE -eq 0) { Report 'Branch creation' 'FAIL' 'Branch already exists; do not reuse'; exit 2 }
    git checkout -b $CreateBranchName 2>$null
    if ($LASTEXITCODE -ne 0) { Report 'Branch creation' 'FAIL' 'git checkout -b failed'; exit 2 }
    $branch = git rev-parse --abbrev-ref HEAD
    if ($branch -eq $CreateBranchName) { Write-Host 'Upgrade branch created and checked out.'; Report 'Upgrade branch created and checked out' 'PASS' } else { Report 'Upgrade branch created and checked out' 'FAIL' 'Unexpected branch after checkout'; exit 2 }
} else {
    if (-not ($branch -match $pattern)) { Report 'Current branch' 'FAIL' "Current branch must be upgrade/docling-YYYY-MM-DD or pass -CreateBranchName to create one"; exit 2 } else { Report 'Current branch' 'PASS' }
}

# Target Docling version must be supplied
if (-not $TargetDoclingVersion) { Report 'Target Docling version' 'FAIL' 'Please supply -TargetDoclingVersion <version>'; exit 2 } else { Report 'Target Docling version' 'PASS' }

# Load package.json
$pkg = $null
if (Test-Path 'package.json') {
    try { $pkg = Get-Content 'package.json' -Raw | ConvertFrom-Json } catch { $pkg = $null }
}

$runner = Get-RunnerCmd

# 2) Lint
if ($pkg -and $pkg.scripts.lint) {
    $cmd = if ($runner -eq 'pnpm') { @('pnpm','lint') } else { @('npm','run','lint') }
    Write-Host "Running lint: $($cmd -join ' ')"
    $cmdExe = $cmd[0]
    if ($cmd.Length -gt 1) {
        $last = $cmd.Length - 1
        $cmdArgs = $cmd[1..$last]
    } else { $cmdArgs = @() }
    $lintOut = & $cmdExe @cmdArgs 2>&1
    $lintExit = $LASTEXITCODE
    if ($lintExit -eq 0) {
        if ($lintOut -match '(?i)warning') { Report 'Lint passes with no new errors' 'PASS' 'Warnings detected; please review' } else { Report 'Lint passes with no new errors' 'PASS' }
    } else { Report 'Lint passes with no new errors' 'FAIL' "Exit code $lintExit" }
} else { Report 'Lint passes with no new errors' 'SKIPPED' 'No lint script found in package.json' }

# 3) Build/dev starts successfully
$devOutFile = "$PWD\upgrade_dev_out.txt"
$devErrFile = "$PWD\upgrade_dev_err.txt"
if ($pkg -and $pkg.scripts.dev) {
    $devCmd = if ($runner -eq 'pnpm') { @('pnpm','run','dev') } else { @('npm','run','dev') }
    $devExe = $devCmd[0]
    if ($devCmd.Length -gt 1) {
        $last = $devCmd.Length - 1
        $devArgs = $devCmd[1..$last]
    } else { $devArgs = @() }
    Write-Host "Starting dev: $($devCmd -join ' ') (short check, will stop after 8s)"
    try {
        $proc = Start-Process -FilePath $devExe -ArgumentList $devArgs -NoNewWindow -RedirectStandardOutput $devOutFile -RedirectStandardError $devErrFile -PassThru
        Start-Sleep -Seconds 8
        $proc.Refresh()
        if ($proc.HasExited) {
            $exit = $proc.ExitCode
            $err = ''
            if (Test-Path $devErrFile) { $err = Get-Content $devErrFile -Raw }
            Report 'Build/dev starts successfully' 'FAIL' "Process exited with code $exit. Error excerpt: $([string]$err). Check $devErrFile"
        } else {
            Report 'Build/dev starts successfully' 'PASS'
            # kill the process
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Report 'Build/dev starts successfully' 'FAIL' "Could not start dev process: $_"
    }
} else { Report 'Build/dev starts successfully' 'SKIPPED' 'No dev script found in package.json' }

# 4) No runtime crashes on startup
$devRes = $results | Where-Object { $_.Check -eq 'Build/dev starts successfully' }
if ($devRes.Status -eq 'PASS') { Report 'No runtime crashes on startup' 'PASS' } elseif ($devRes.Status -eq 'FAIL') { Report 'No runtime crashes on startup' 'FAIL' 'Dev process failed or crashed' } else { Report 'No runtime crashes on startup' 'SKIPPED' 'No dev to exercise; consider manual checks' }

# 5) No new warnings introduced
$warningsFound = $false
# check dev out
if (Test-Path $devOutFile) {
    $tout = Get-Content $devOutFile -Raw
    if ($tout -match '(?i)warning') { $warningsFound = $true }
}
# check lintOut from earlier
if ($lintOut -and ($lintOut -match '(?i)warning')) { $warningsFound = $true }
if ($warningsFound) { Report 'No new warnings introduced' 'FAIL' "Warnings found in output; search for 'warning' in $devOutFile or lint output" } else { Report 'No new warnings introduced' 'PASS' }

# 6) Application behavior unchanged outside upgrade scope
if ($pkg -and $pkg.scripts.'test:unit') {
    Write-Host "Running unit tests (smoke): run 'test:unit' (may take some time)"
    $tCmd = if ($runner -eq 'pnpm') { @('pnpm','run','test:unit','--silent') } else { @('npm','run','test:unit','--silent') }
    $tExe = $tCmd[0]
    if ($tCmd.Length -gt 1) {
        $last = $tCmd.Length - 1
        $tArgs = $tCmd[1..$last]
    } else { $tArgs = @() }
    $tOut = & $tExe @tArgs 2>&1
    $tExit = $LASTEXITCODE
    if ($tExit -eq 0) { Report 'Application behavior unchanged outside upgrade scope' 'PASS' } else { Report 'Application behavior unchanged outside upgrade scope' 'FAIL' "Unit tests returned exit code $tExit" }
} else { Report 'Application behavior unchanged outside upgrade scope' 'SKIPPED' 'No test:unit script; run full test-suite manually' }

# Summary
Write-Host "`nUpgrade Validation Summary:`n"
$results | Format-Table -AutoSize

$failures = $results | Where-Object { $_.Status -eq 'FAIL' }
if ($failures) {
    Write-Host "`nOne or more checks FAILED. Attach logs to your PR and fix before proceeding." -ForegroundColor Red
    exit 2
} else {
    Write-Host "`nAll checks PASS or SKIPPED. Good to proceed with upgrade branch." -ForegroundColor Green
    exit 0
}

Pop-Location | Out-Null