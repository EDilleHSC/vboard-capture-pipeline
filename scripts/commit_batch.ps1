<#
commit_batch.ps1

Commit a previously staged batch into CAPTURE_HOLE root (move files from incoming batch dir into CAPTURE_HOLE root), archive the batch, and write an event.

Usage:
  pwsh ./scripts/commit_batch.ps1 -BatchId batch-001 -DryRun

Behavior:
- Moves files from CAPTURE_HOLE/_incoming_batches/<BatchId>/ to CAPTURE_HOLE/
- Creates an archive of the batch under CAPTURE_HOLE/_batches/archive/<BatchId>-archived/
- Writes an event to CAPTURE_HOLE/_events/events.log

Options:
-BatchId (required)
-DryRun (switch)
#>

Param(
    [Parameter(Mandatory=$true)][string]$BatchId,
    [switch]$DryRun
)

Set-StrictMode -Version Latest

$inbox = "$HOME/CAPTURE_HOLE"
$batchDir = Join-Path $inbox '_incoming_batches' | Join-Path -ChildPath $BatchId
if (-not (Test-Path $batchDir)) { Write-Error "Batch not found: $batchDir"; exit 1 }

$files = Get-ChildItem -Path $batchDir -File
if (-not $files) { Write-Error "No files found in batch: $batchDir"; exit 1 }

if ($DryRun) {
    Write-Host "DryRun: would move $($files.Count) files from $batchDir to $inbox"
    $files | ForEach-Object { Write-Host $_.FullName }
    exit 0
}

# Move files into inbox root
foreach ($f in $files) {
    $dest = Join-Path $inbox $f.Name
    Move-Item -Path $f.FullName -Destination $dest -Force
}

# Archive the batch (move batch dir to _batches/archive)
$batchesBase = Join-Path $inbox '_batches'
$archiveBase = Join-Path $batchesBase 'archive'
if (-not (Test-Path $archiveBase)) { New-Item -ItemType Directory -Path $archiveBase | Out-Null }
$archived = Join-Path $archiveBase ("$BatchId-archived")
Move-Item -Path $batchDir -Destination $archived

# Write event
$eventsDir = Join-Path $inbox '_events'
if (-not (Test-Path $eventsDir)) { New-Item -ItemType Directory -Path $eventsDir | Out-Null }
$event = [PSCustomObject]@{
    timestamp = (Get-Date).ToString('o')
    action = 'commit_batch'
    batch = $BatchId
    archived = $archived
    file_count = $files.Count
}
Add-Content -Path (Join-Path $eventsDir 'events.log') -Value ($event | ConvertTo-Json -Compress) -Encoding UTF8

Write-Host "Committed batch $BatchId: $($files.Count) files moved to $inbox, archived at $archived"
exit 0
