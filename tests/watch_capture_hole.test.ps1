# Watcher smoke test for CAPTURE_HOLE
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path -Path "$root/.." | Select-Object -ExpandProperty Path
Push-Location $repo

# Create a temporary capture hole fixture
$tmp = Join-Path $PWD ("tmp_capture_{0}" -f (Get-Random -Maximum 100000))
New-Item -ItemType Directory -Path $tmp | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tmp '_events') | Out-Null

# Create a file
Set-Content -Path (Join-Path $tmp 'foo.txt') -Value 'hello'

# Run watcher
pwsh ./scripts/watch_inbox_once.ps1 -InboxPath $tmp -IncludeHashes

# Assertions
$events = Get-ChildItem -Path (Join-Path $tmp '_events') -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $events) { Write-Error 'No events log written'; exit 1 }
$last = Get-Content $events.FullName -Raw | ConvertFrom-Json
if ($last.action -ne 'snapshot') { Write-Error "Unexpected event action: $($last.action)"; exit 1 }
if (-not $last.snapshot) { Write-Error 'Event missing snapshot field'; exit 1 }
if (-not (Test-Path $last.snapshot_path)) { Write-Error "Snapshot file missing: $($last.snapshot_path)"; exit 1 }

Write-Host 'Watch CAPTURE_HOLE smoke test PASSED'

# Cleanup
Remove-Item -Recurse -Force $tmp
Pop-Location
exit 0
