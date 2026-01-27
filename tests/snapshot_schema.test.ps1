# Snapshot schema test
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path -Path "$root/.." | Select-Object -ExpandProperty Path
Push-Location $repo

# Create a temporary inbox fixture
$tmp = Join-Path $PWD ("tmp_inbox_{0}" -f (Get-Random -Maximum 100000))
New-Item -ItemType Directory -Path $tmp | Out-Null

# Create a couple of files deterministically
Set-Content -Path (Join-Path $tmp 'aa.txt') -Value 'alpha'
Set-Content -Path (Join-Path $tmp 'bb.txt') -Value 'beta'

# Run snapshot (include hashes to exercise optional property)
pwsh ./scripts/capture_inbox_snapshot.ps1 -InboxPath $tmp -IncludeHashes

# Find the latest snapshot
$snapDir = Join-Path $tmp '_snapshots'
if (-not (Test-Path $snapDir)) { Write-Error "No _snapshots directory found"; exit 1 }
$snap = Get-ChildItem -Path $snapDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $snap) { Write-Error "No snapshot file created"; exit 1 }

$json = Get-Content $snap.FullName -Raw | ConvertFrom-Json

function Fail($msg) { Write-Error $msg; exit 1 }

# Top-level assertions
if (-not ($json.psobject.Properties.Name -contains 'snapshot_version')) { Fail 'Missing snapshot_version' }
if ($json.snapshot_version -ne 1) { Fail "Unexpected snapshot_version: $($json.snapshot_version)" }

if (-not ($json.psobject.Properties.Name -contains 'captured_at')) { Fail 'Missing captured_at' }
try { [datetime]$tmpd = [datetime]::Parse($json.captured_at) } catch { Fail 'captured_at not parseable as datetime' }

if (-not ($json.psobject.Properties.Name -contains 'watch_path')) { Fail 'Missing watch_path' }
if ($json.watch_path -ne $tmp) { Fail "watch_path mismatch: expected $tmp got $($json.watch_path)" }

if (-not ($json.files -and ($json.files.Count -eq 2))) { Fail 'files array missing or wrong count' }

# File entry assertions
$relative_paths = @()
foreach ($f in $json.files) {
    if (-not $f.name) { Fail 'file entry missing name' }
    if (-not $f.relative_path) { Fail 'file entry missing relative_path' }
    $relative_paths += $f.relative_path
    if (-not ($f.size_bytes -is [int] -or $f.size_bytes -is [long])) { Fail "size_bytes not numeric for $($f.relative_path)" }
    try { [datetime]::Parse($f.mtime) } catch { Fail "mtime not parseable for $($f.relative_path)" }
    try { [datetime]::Parse($f.ctime) } catch { Fail "ctime not parseable for $($f.relative_path)" }
    if ($f.sha256 -ne $null -and -not ($f.sha256 -is [string])) { Fail "sha256 present but not string for $($f.relative_path)" }
}

# Check determinism: relative_path sequence must be sorted
$sorted = $relative_paths | Sort-Object
if (-not ($relative_paths -eq $sorted)) { Fail 'files array is not sorted by relative_path' }

Write-Host 'Snapshot schema test PASSED'

# Cleanup
Remove-Item -Recurse -Force $tmp

Pop-Location
exit 0
