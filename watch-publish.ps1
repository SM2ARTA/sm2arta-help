# === CONFIG ===
$Repo = "C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"
$Bat  = Join-Path $Repo "publish-with-version.bat"
$Log  = Join-Path $Repo "watch-publish.log"

# Toggle this:
$VISIBLE = $true   # = open a visible cmd window to run the BAT
#$VISIBLE = $false # = run hidden in background

function Log($msg) {
  $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -Path $Log -Value "[$stamp] $msg"
}

# Ignore files the publisher touches (prevent loops)
function ShouldIgnore($path) {
  $p = $path.ToLower()
  if ($p -match "\\.git\\")       { return $true }
  if ($p -match "\\_logs\\")      { return $true }
  if ($p -match "version\.json$") { return $true }
  if ($p -match "\\.nojekyll$")   { return $true }
  if ($p -match "\\bcname$")      { return $true }
  if ([System.IO.Path]::GetFileName($p) -like "~$*") { return $true } # temp files
  return $false
}

# Snapshot of the tree to detect stability
function Get-Signature($root) {
  $count = [long]0; $bytes = [long]0; $latest = 0L
  Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $p = $_.FullName.ToLower()
      -not ($p -match "\\.git\\" -or $p -match "\\_logs\\" -or $_.Name -in @("CNAME",".nojekyll","version.json","watch-publish.log","publish.log","inject-guard.log"))
    } | ForEach-Object {
      $count++; $bytes += $_.Length
      $t = $_.LastWriteTimeUtc.Ticks; if ($t -gt $latest) { $latest = $t }
    }
  [pscustomobject]@{ Count=$count; Bytes=$bytes; Latest=$latest }
}

# Wait until folder stays unchanged for QuietSeconds
function Wait-ForQuiet($root, [int]$QuietSeconds = 10, [int]$MaxWaitSeconds = 300) {
  Log "Waiting for quiet: $QuietSeconds s (max $MaxWaitSeconds s)…"
  $prev = Get-Signature $root; $stable = 0.0
  while ($stable -lt $QuietSeconds -and $MaxWaitSeconds -gt 0) {
    Start-Sleep -Milliseconds 500
    $cur = Get-Signature $root
    if ($cur.Count -eq $prev.Count -and $cur.Bytes -eq $prev.Bytes -and $cur.Latest -eq $prev.Latest) { $stable += 0.5 }
    else { $stable = 0.0; $prev = $cur }
    $MaxWaitSeconds -= 0.5
  }
  if ($stable -ge $QuietSeconds) { Log "Folder is quiet."; return $true }
  Log "Timed out waiting for quiet; proceeding anyway."; return $false
}

# --- FileSystemWatcher ---
$fsw = New-Object IO.FileSystemWatcher $Repo
$fsw.IncludeSubdirectories = $true
$fsw.Filter = "*"
$fsw.NotifyFilter = [IO.NotifyFilters] "FileName, DirectoryName, LastWrite, LastAccess, Size, CreationTime, Attributes, Security"
$fsw.EnableRaisingEvents = $true

# Debounce
$DEBOUNCE_MS = 15000
$timer = New-Object Timers.Timer $DEBOUNCE_MS
$timer.AutoReset = $false

$script:running = $false

Register-ObjectEvent $fsw Changed -Action {
  $path = $Event.SourceEventArgs.FullPath
  if (-not (ShouldIgnore $path)) { Log "Changed: $path"; $timer.Stop(); $timer.Start() }
} | Out-Null
Register-ObjectEvent $fsw Created -Action {
  $path = $Event.SourceEventArgs.FullPath
  if (-not (ShouldIgnore $path)) { Log "Created: $path"; $timer.Stop(); $timer.Start() }
} | Out-Null
Register-ObjectEvent $fsw Deleted -Action {
  $path = $Event.SourceEventArgs.FullPath
  if (-not (ShouldIgnore $path)) { Log "Deleted: $path"; $timer.Stop(); $timer.Start() }
} | Out-Null
Register-ObjectEvent $fsw Renamed -Action {
  $path = $Event.SourceEventArgs.FullPath
  if (-not (ShouldIgnore $path)) { Log "Renamed: $path"; $timer.Stop(); $timer.Start() }
} | Out-Null

Register-ObjectEvent $timer Elapsed -Action {
  if ($script:running) { Log "Timer elapsed but publish in progress; skipping."; return }
  $script:running = $true
  try {
    Wait-ForQuiet -root $Repo -QuietSeconds 10 -MaxWaitSeconds 300 | Out-Null

    Log "Launching publisher: $Bat  (VISIBLE=$VISIBLE)"
    if ($VISIBLE) {
      # Show a cmd window and keep it open so you can see it run (/k)
      Start-Process -FilePath "cmd.exe" -ArgumentList "/k `"$Bat`"" -WorkingDirectory $Repo -WindowStyle Normal
      Log "Publisher launched (visible window)."
    } else {
      # Hidden background run; wait for exit and log code
      $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$Bat`"" -WorkingDirectory $Repo -NoNewWindow -WindowStyle Hidden -PassThru -Wait
      Log "Publisher exit code: $($p.ExitCode)"
    }
  } catch {
    Log "Publish error: $_"
  } finally {
    $script:running = $false
  }
} | Out-Null

Log "Watching $Repo for changes (hidden)."
while ($true) { Start-Sleep -Seconds 3600 }
