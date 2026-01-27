# Stage + commit smoke test
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path -Path "$root/.." | Select-Object -ExpandProperty Path
Push-Location $repo

# Create a temp source with 10 files
$src = Join-Path $PWD ("tmp_src_{0}" -f (Get-Random -Maximum 100000))
New-Item -ItemType Directory -Path $src | Out-Null
for ($i=1; $i -le 10; $i++) { Set-Content -Path (Join-Path $src ("file{0}.txt" -f $i)) -Value ("content{0}" -f $i) }

# Stage a small batch (5 files)
pwsh ./scripts/stage_batch.ps1 -SourcePath $src -BatchSize 5 -IncludeHashes

# Find the manifest
$man = Get-ChildItem -Path "$HOME/CAPTURE_HOLE/_manifests" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $man) { Write-Error 'No manifest created' ; exit 1 }
$json = Get-Content $man.FullName -Raw | ConvertFrom-Json
if ($json.Count -ne 5) { Write-Error 'Manifest file count mismatch' ; exit 1 }

# Identify batch id from manifest filename
$batchId = ($man.Name -replace '^manifest-','' -replace '\.json$','')

# Ensure incoming batch exists
$batchDir = Join-Path "$HOME/CAPTURE_HOLE/_incoming_batches" $batchId
if (-not (Test-Path $batchDir)) { Write-Error 'Incoming batch dir missing' ; exit 1 }

# Commit the batch
pwsh ./scripts/commit_batch.ps1 -BatchId $batchId

# Validate files moved to CAPTURE_HOLE root (by checking for a prefixed file)
$files = Get-ChildItem -Path "$HOME/CAPTURE_HOLE" -File | Where-Object { $_.Name -match '^\d{4}-' }
if (-not $files) { Write-Error 'No files found in CAPTURE_HOLE root after commit' ; exit 1 }

Write-Host 'Stage + commit smoke test PASSED'

# Cleanup
Remove-Item -Recurse -Force $src
Pop-Location
exit 0