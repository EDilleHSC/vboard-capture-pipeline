<#
capture_inbox_snapshot.ps1

Purpose: Create an immutable JSON snapshot of files in a Desktop INBOX folder.
Usage (recommended): pwsh ./scripts/capture_inbox_snapshot.ps1 -InboxPath $HOME/Desktop/INBOX -IncludeHashes
Notes:
- Read-only: does not move or modify files
- Writes snapshot to INBOX/_snapshots/snapshot-<timestamp>.json
- By default hashes are not calculated (opt-in via -IncludeHashes)
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

# Ensure snapshots directory exists
$snapDir = Join-Path $inbox '_snapshots'
if (-not (Test-Path $snapDir)) {
    New-Item -ItemType Directory -Path $snapDir | Out-Null
}

# Collect top-level files only (do not recurse by default). Exclude control directories.
$files = Get-ChildItem -Path $inbox -File -Force | Where-Object { $_.Name -ne '_snapshots' -and $_.Name -ne '_quarantine' -and $_.Name -ne '_processed' } | Sort-Object Name

$entries = @()
foreach ($f in $files) {
    $entry = [PSCustomObject]@{
        filename = $f.Name
        relative_path = $f.Name
        size = $f.Length
        mtime = $f.LastWriteTimeUtc.ToString('o')
    }
    if ($IncludeHashes) {
        try {
            $h = Get-FileHash -Algorithm SHA256 -Path $f.FullName -ErrorAction Stop
            $entry | Add-Member -NotePropertyName sha256 -NotePropertyValue $h.Hash
        } catch {
            $entry | Add-Member -NotePropertyName sha256 -NotePropertyValue $null
        }
    }
    $entries += $entry
}

$snapshot = [PSCustomObject]@{
    snapshot_time = (Get-Date).ToString('o')
    inbox = $inbox
    file_count = $entries.Count
    files = $entries
}

$timestamp = Get-Date -Format 'yyyyMMddTHHmmssZ'
$outName = "snapshot-$timestamp.json"
$outPath = Join-Path $snapDir $outName

# Write compact UTF8 JSON
$snapshot | ConvertTo-Json -Depth 6 | Out-File -FilePath $outPath -Encoding UTF8

Write-Host "Snapshot written to $outPath"
Write-Host "Files: $($entries.Count)"
exit 0
