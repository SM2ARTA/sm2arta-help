# Path where HelpNDoc exports (your repo root)
$Out = "C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"

# We'll insert this exact tag if missing
$tag = '<script src="/guard.js"></script>'

Get-ChildItem -Path $Out -Filter *.html -Recurse |
Where-Object { $_.Name -ne 'index.html' } |   # <-- skip index.html to avoid double include
ForEach-Object {
  $p = $_.FullName
  $html = Get-Content -LiteralPath $p -Raw

  # Skip if either /guard.js OR guard.js is already present
  if ($html -match '<script\s+src="/?guard\.js"\s*></script>' ) { return }

  # Insert just before </head> (case-insensitive)
  $new = [regex]::Replace($html, '</head>', "$tag`r`n</head>", 'IgnoreCase', [TimeSpan]::FromSeconds(1))
  if ($new -ne $html) {
    Set-Content -LiteralPath $p -Value $new -Encoding UTF8
    Write-Host "Injected guard into: $p"
  }
}
