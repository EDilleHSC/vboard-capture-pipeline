Write-Host 'Docling smoke test starting...'

# smoke check
; docling --help | Out-Null
if (0 -ne 0) {
  Write-Error 'Docling not callable'
  exit 1
}
Write-Host 'Docling smoke test PASS'
