<#
watch_inbox_once.ps1

Prototype watcher (manual, read-only trigger):
- Manually invoked convenience wrapper around `capture_inbox_snapshot.ps1`.
- Does NOT run as a daemon. No inotify, no systemd, no background service.
- Does NOT move/rename/delete files.
- Appends a single JSON event to `INBOX/_snapshots/events.log` describing the snapshot.

Usage:
  pwsh ./scripts/watch_inbox_once.ps1 -InboxPath "$HOME/Desktop/INBOX" [-IncludeHashes]

Exit codes:
- 0: snapshot succeeded and event logged
- non-zero: snapshot failed (event with action: snapshot_failed written when possible)
#>

Param(
    [string]$InboxPath = "$HOME/Desktop/INBOX",
    [switch]$IncludeHashes
)

Set-StrictMode -Version Latest

try {
    $inboxResolved = Resolve-Path -Path $InboxPath -ErrorAction Stop
} catch {
    Write-Error "Inbox path not found: $InboxPath"
    exit 2
}

$inbox = $inboxResolved.ProviderPath
$snapDir = Join-Path $inbox '_snapshots'
if (-not (Test-Path $snapDir)) { New-Item -ItemType Directory -Path $snapDir | Out-Null }

# Run the core snapshot script exactly as-is (opt-in IncludeHashes passthrough)
$script = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'capture_inbox_snapshot.ps1'
if ($IncludeHashes) {
    $cmd = @('pwsh','-NoProfile','-NonInteractive',$script,'-InboxPath',$inbox,'-IncludeHashes')
} else {
    $cmd = @('pwsh','-NoProfile','-NonInteractive',$script,'-InboxPath',$inbox)
}

Write-Host "Invoking snapshot: $($cmd -join ' ')"
$proc = & $cmd[0] @($cmd[1..($cmd.Length-1)]) 2>&1
$exit = $LASTEXITCODE

# Attempt to locate the latest snapshot file (by LastWriteTime)
$snap = $null
try {
    $snap = Get-ChildItem -Path $snapDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} catch {
    # ignore
}

function Write-Event($obj) {
    $log = Join-Path $snapDir 'events.log'
    $line = ($obj | ConvertTo-Json -Compress)
    Add-Content -Path $log -Value $line -Encoding UTF8
}

if ($exit -ne 0) {
    Write-Error "Snapshot command failed with exit code $exit"
    $evt = [PSCustomObject]@{
        timestamp = (Get-Date).ToString('o')
        action = 'snapshot_failed'
        command = ($cmd -join ' ')
        exit_code = $exit
        output = ($proc -join "`n")
    }
    try { Write-Event $evt } catch { Write-Error 'Failed to write events.log' }
    exit $exit
}

if (-not $snap) {
    Write-Error 'Snapshot succeeded but no snapshot file was found'
    $evt = [PSCustomObject]@{
        timestamp = (Get-Date).ToString('o')
        action = 'snapshot_missing'
        note = 'no snapshot file found after successful command'
    }
    try { Write-Event $evt } catch { Write-Error 'Failed to write events.log' }
    exit 3
}

# Read snapshot to obtain file_count deterministically
try {
    $json = Get-Content $snap.FullName -Raw | ConvertFrom-Json
    $count = $json.file_count
} catch {
    $count = $null
}

$evt = [PSCustomObject]@{
    timestamp = (Get-Date).ToString('o')
    action = 'snapshot'
    snapshot = $snap.Name
    snapshot_path = $snap.FullName
    file_count = $count
    command = ($cmd -join ' ')
}

try { Write-Event $evt } catch { Write-Error 'Failed to write events.log'; exit 4 }

Write-Host "Snapshot event logged: $($evt.snapshot) (files: $($evt.file_count))"
exit 0
