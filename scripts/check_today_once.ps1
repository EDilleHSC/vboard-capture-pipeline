<#
check_today_once.ps1

Manual check for ~/TODAY to prevent it from becoming a junk drawer.
- Read-only: does not move, rename, or delete files.
- Reports files older than X hours (default 24).
- Appends an NDJSON event to TODAY/_events.log.

Usage:
  pwsh ./scripts/check_today_once.ps1 -TodayPath "$HOME/TODAY" [-MaxAgeHours 24]

Exit codes:
- 0: No violations
- 1: Violations found
- 2: Path missing or other fatal error
#>

Param(
    [string]$TodayPath = "$HOME/TODAY",
    [int]$MaxAgeHours = 24
)

Set-StrictMode -Version Latest

try {
    $todayResolved = Resolve-Path -Path $TodayPath -ErrorAction Stop
} catch {
    Write-Error "Today path not found: $TodayPath"
    exit 2
}

$today = $todayResolved.ProviderPath
$now = Get-Date
$threshold = $now.AddHours(-1 * $MaxAgeHours)

# Gather files (top-level only)
$items = Get-ChildItem -Path $today -File -Force | Sort-Object LastWriteTime

$violations = @()
foreach ($i in $items) {
    if ($i.LastWriteTime -lt $threshold) { $violations += $i.Name }
}

$evt = [PSCustomObject]@{
    timestamp = (Get-Date).ToString('o')
    action = 'check'
    violations = $violations.Count
    violated_files = $violations
    note = if ($violations.Count -gt 0) { "Files older than $MaxAgeHours hours" } else { "OK" }
}

# Write event to _events.log
$evtLog = Join-Path $today '_events.log'
try {
    $line = ($evt | ConvertTo-Json -Compress)
    Add-Content -Path $evtLog -Value $line -Encoding UTF8
} catch {
    Write-Error 'Failed to write _events.log'
}

if ($violations.Count -gt 0) {
    Write-Host "Violations found: $($violations.Count)"
    foreach ($v in $violations) { Write-Host " - $v" }
    exit 1
}

Write-Host 'No violations found.'
exit 0
