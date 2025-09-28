# Robustly ensure every page (except root index.html) includes <script src="/guard.js"></script> in <head>
$ErrorActionPreference = 'Stop'

# === CONFIG ===
$Out = "C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"
$tag = '<script src="/guard.js"></script>'

# Skip the root index.html (your gate)
$rootIndex = Join-Path $Out 'index.html'

# Find .html/.htm files reliably (avoid -Include quirks)
$files = Get-ChildItem -Path $Out -Recurse -File |
  Where-Object { $_.Extension -match '^\.(html|htm)$' -and $_.FullName -ine $rootIndex }

$injected = 0
foreach ($f in $files) {
  $p = $f.FullName
  $html = Get-Content -LiteralPath $p -Raw

  # Skip if already present (either /guard.js or guard.js)
  if ($html -match '<script\s+src="/?guard\.js"\s*>\s*</script>') { continue }

  $new = $html

  # 1) Insert before </head> if present
  if ($new -match '</head>') {
    $new = [regex]::Replace($new, '</head>', "$tag`r`n</head>", 'IgnoreCase')
  }
  # 2) Else insert after <head...> if present
  elseif ($new -match '<head(\b[^>]*)?>') {
    $new = [regex]::Replace($new, '<head(\b[^>]*)?>', { param($m) "$($m.Value)`r`n$tag" }, 'IgnoreCase')
  }
  # 3) Else prepend (last resort)
  else {
    $new = "$tag`r`n$new"
  }

  if ($new -ne $html) {
    Set-Content -LiteralPath $p -Value $new -Encoding UTF8
    Write-Output "Injected guard into: $p"
    $injected++
  }
}

Write-Output "Injected into $injected file(s)."
exit 0
