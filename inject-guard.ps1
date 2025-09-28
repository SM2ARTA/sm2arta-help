# Insert <script src="/guard.js"></script> before </head> in every HTML file
$Out = "C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"
$tag = '<script src="/guard.js"></script>'

Get-ChildItem -Path $Out -Filter *.html -Recurse | ForEach-Object {
  $p = $_.FullName
  $html = Get-Content -LiteralPath $p -Raw
  if ($html -notmatch [regex]::Escape($tag)) {
    # Insert before </head> (case-insensitive)
    $new = [regex]::Replace($html, '</head>', "$tag`r`n</head>", 'IgnoreCase', [TimeSpan]::FromSeconds(1))
    if ($new -ne $html) {
      Set-Content -LiteralPath $p -Value $new -Encoding UTF8
      Write-Host "Injected guard into: $p"
    }
  }
}
