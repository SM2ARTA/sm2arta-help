# === CONFIG ===
$Repo = "C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"
$Bat  = Join-Path $Repo "publish-with-version.bat"

# Ignore files/paths that the publisher touches, to avoid loops
function ShouldIgnore($path) {
  $p = $path.ToLower()
  if ($p -match "\\.git\\")            { return $true }
  if ($p -match "version\.json$")      { return $true }
  if ($p -match "\\.nojekyll$")        { return $true }
  if ($p -match "\\bcname$")           { return $true }
  if ([System.IO.Path]::GetFileName($p) -like "~$*") { return $true } # temp files
  return $false
}

# Watcher + debounce timer
$fsw = New-Object IO.FileSystemWatcher $Repo -Property @{
  IncludeSubdirectories = $true
  EnableRaisingEvents   = $true
  Filter                = "*.*"
}
$timer = New-Object Timers.Timer 4000
$timer.AutoReset = $false
$running = $false

# Event handlers (restart timer on meaningful change)
Register-ObjectEvent $fsw Changed -Action {
  if (-not (ShouldIgnore($Event.SourceEventArgs.FullPath))) { $timer.Stop(); $timer.Start() }
} | Out-Null
Register-ObjectEvent $fsw Created -Action {
  if (-not (ShouldIgnore($Event.SourceEventArgs.FullPath))) { $timer.Stop(); $timer.Start() }
} | Out-Null
Register-ObjectEvent $fsw Deleted -Action {
  if (-not (ShouldIgnore($Event.SourceEventArgs.FullPath))) { $timer.Stop(); $timer.Start() }
} | Out-Null
Register-ObjectEvent $fsw Renamed -Action {
  if (-not (ShouldIgnore($Event.SourceEventArgs.FullPath))) { $timer.Stop(); $timer.Start() }
} | Out-Null

# When the timer elapses, run the publisher once
Register-ObjectEvent $timer Elapsed -Action {
  if ($running) { return }
  $script:running = $true
  try {
    Write-Host "Change detected. Publishing..." -ForegroundColor Cyan
    & cmd /c "`"$Bat`""
    Write-Host "Publish complete." -ForegroundColor Green
  } catch {
    Write-Host "Publish error: $_" -ForegroundColor Red
  } finally {
    $script:running = $false
  }
} | Out-Null

Write-Host "Watching $Repo for changes. Leave this window open; close to stop."
while ($true) { Start-Sleep -Seconds 3600 }
