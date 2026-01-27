<#
stage_batch.ps1

Stage a controlled batch of files from a source into CAPTURE_HOLE for snapshot + review.

Usage (recommended):
  pwsh ./scripts/stage_batch.ps1 -SourcePath "/path/to/source" -BatchSize 300 -IncludeHashes

Behavior:
- Copies up to -BatchSize files (deterministic order) from -SourcePath into
  CAPTURE_HOLE/_incoming_batch_<id>/ (copy, never move)
- Writes a manifest JSON describing original paths and destination paths
- Runs the canonical snapshot script `capture_inbox_snapshot.ps1` against CAPTURE_HOLE
- Leaves files in the incoming batch dir until you run commit_batch.ps1

Options:
-SourcePath (required)
-BatchSize (default 300)
-BatchId (optional; auto-incremented if not supplied)
-IncludeHashes (switch)
-DryRun (switch) — perform selection and manifest generation but don't copy

Exit codes:
 0 success
 1 invalid args / fatal error
#>

Param(
    [Parameter(Mandatory=$true)][string]$SourcePath,
    [int]$BatchSize = 300,
    [string]$BatchId,
    [switch]$IncludeHashes,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

function Fail($msg) { Write-Error $msg; exit 1 }

try { $source = Resolve-Path -Path $SourcePath -ErrorAction Stop } catch { Fail "SourcePath not found: $SourcePath" }
$sourcePath = $source.ProviderPath

$inbox = "$HOME/CAPTURE_HOLE"
if (-not (Test-Path $inbox)) { Fail "CAPTURE_HOLE not found at $inbox; create it first" }

# Ensure batches dir exists
$batchesDir = Join-Path $inbox '_incoming_batches'
if (-not (Test-Path $batchesDir)) { New-Item -ItemType Directory -Path $batchesDir | Out-Null }

# Determine BatchId if missing: next sequential
if (-not $BatchId) {
    $existing = Get-ChildItem -Path $batchesDir -Directory -Name 2>$null | Where-Object { $_ -match '^batch-\d{3}$' }
    $nums = $existing | ForEach-Object { [int]($_ -replace '^batch-','') }
    $next = if ($nums) { ([int]($nums | Sort-Object -Descending | Select-Object -First 1)) + 1 } else { 1 }
    $BatchId = ('batch-{0:D3}' -f $next)
}

$batchDir = Join-Path $batchesDir $BatchId
if (Test-Path $batchDir) { Fail "Batch directory already exists: $batchDir" }

# Select files deterministically from source (top-level files first)
# We use Get-ChildItem -File -Recurse to find candidates, sorted by FullName
$candidates = Get-ChildItem -Path $sourcePath -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName
if (-not $candidates) { Fail "No files found in source: $sourcePath" }
$selected = $candidates | Select-Object -First $BatchSize

Write-Host "Selected $($selected.Count) files for batch $BatchId from $sourcePath"

if ($DryRun) {
    $selected | ForEach-Object { Write-Host $_.FullName }
    exit 0
}

# Create batch dir
New-Item -ItemType Directory -Path $batchDir | Out-Null

# Copy files into batch dir; preserve file names but avoid collisions by using numeric prefix
$manifest = @()
$idx = 1
foreach ($f in $selected) {
    $prefix = '{0:D4}' -f $idx
    $destName = "$prefix-$($f.Name)"
    $destPath = Join-Path $batchDir $destName
    Copy-Item -Path $f.FullName -Destination $destPath -Force
    $entry = [PSCustomObject]@{
        index = $idx
        source = $f.FullName
        dest = $destPath
        size = $f.Length
        mtime = $f.LastWriteTimeUtc.ToString('o')
    }
    if ($IncludeHashes) {
        try { $h = Get-FileHash -Algorithm SHA256 -Path $destPath -ErrorAction Stop; $entry | Add-Member -NotePropertyName sha256 -NotePropertyValue $h.Hash } catch { $entry | Add-Member -NotePropertyName sha256 -NotePropertyValue $null }
    }
    $manifest += $entry
    $idx++
}

# Write manifest
$manifestDir = Join-Path $inbox '_manifests'
if (-not (Test-Path $manifestDir)) { New-Item -ItemType Directory -Path $manifestDir | Out-Null }
$manifestPath = Join-Path $manifestDir ("manifest-$BatchId.json")
$manifest | ConvertTo-Json -Depth 6 | Out-File -FilePath $manifestPath -Encoding UTF8
Write-Host "Manifest written: $manifestPath"

# Run snapshot against CAPTURE_HOLE
Write-Host "Running snapshot against $inbox"
$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'capture_inbox_snapshot.ps1'
$psArgs = @('-NoProfile','-NonInteractive',$script,'-InboxPath',$inbox)
if ($IncludeHashes) { $psArgs += '-IncludeHashes' }
$procOut = & pwsh @psArgs 2>&1
$exit = $LASTEXITCODE
Write-Host $procOut
if ($exit -ne 0) {
    Write-Error "Snapshot script failed with exit $exit"
    exit $exit
}

# Record batch event
$eventsDir = Join-Path $inbox '_events'
if (-not (Test-Path $eventsDir)) { New-Item -ItemType Directory -Path $eventsDir | Out-Null }
$event = [PSCustomObject]@{
    timestamp = (Get-Date).ToString('o')
    action = 'stage_batch'
    batch = $BatchId
    batch_dir = $batchDir
    manifest = $manifestPath
    file_count = $manifest.Count
}
$evLine = ($event | ConvertTo-Json -Compress)
Add-Content -Path (Join-Path $eventsDir 'events.log') -Value $evLine -Encoding UTF8

Write-Host "Batch $BatchId staged: $($manifest.Count) files. Inspect manifest and snapshots before committing."
exit 0
