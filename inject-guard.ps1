# Robustly ensure every page (except index.html) includes <script src="/guard.js"></script> in <head>
$Out = "C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"
$tag = '<script src="/guard.js"></script>'

# Find .html/.htm files (case-insensitive), skip index.html at root
$files = Get-ChildItem -Path $Out -Recurse -File -Include *.html, *.htm |
  Where-Object {
    # Skip the root index.html (adjust if your gate has a different name)
    -not ($_.FullName -ieq (Join-Path $Out "index.html"))
  }

foreach ($f in $files) {
  $p = $f.FullName
  $html = Get-Content -LiteralPath $p -Raw

  # Skip if the tag already exists in any variant (/guard.js or guard.js)
  if ($html -match '<script\s+src="/?guard\.js"\s*>\s*</script>' ) { continue }

  $new = $null
  # 1) Insert before </head> if present
  if ($html -match '</head>' -or $html -match '</HEAD>') {
    $new = [regex]::Replace($html, '</head>', "$tag`r`n</head>", 'IgnoreCase', [TimeSpan]::FromSeconds(1))
  }
  # 2) Else insert after <head ...> if present
  if (-not $new -or $new -eq $html) {
    $new = [regex]::Replace($html, '<head(\b[^>]*)?>', { param($m) "$($m.Value)`r`n$tag" }, 'IgnoreCase', [TimeSpan]::FromSeconds(1))
  }
  # 3) Else as last resort, prepend at top of file (still works, executed early)
  if (-not $new -or $new -eq $html) {
    $new = "$tag`r`n$html"
  }

  if ($new -ne $html) {
    Set-Content -LiteralPath $p -Value $new -Encoding UTF8
    Write-Host "Injected guard into: $p"
  }
}
