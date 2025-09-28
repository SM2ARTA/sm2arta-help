@echo off
setlocal

REM === paths ===
set "REPO=C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"
set "LOGDIR=%REPO%\_logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set "LOG=%LOGDIR%\publish.log"
set "INJLOG=%LOGDIR%\inject-guard.log"

REM === pick PowerShell (prefer pwsh, fallback to WindowsPowerShell) ===
set "PWSH=pwsh.exe"
where %PWSH% >nul 2>&1 || set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

REM === pick git (system or GitHub Desktop embedded) ===
set "GIT=git"
%GIT% --version >nul 2>&1 || (
  for /f "delims=" %%p in ('%PWSH% -NoProfile -NonInteractive -Command ^
    "(Get-ChildItem $env:LOCALAPPDATA\GitHubDesktop -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName"') do set "GHDPATH=%%p"
  if exist "%GHDPATH%\resources\app\git\cmd\git.exe" set "GIT=%GHDPATH%\resources\app\git\cmd\git.exe"
)

cd /d "%REPO%"

REM === 0) write a TEMP inline injector and run it (no external PS1 dependency) ===
set "TMPPS=%TEMP%\inject-guard-inline.ps1"
> "%TMPPS%" echo $ErrorActionPreference='Stop'
>>"%TMPPS%" echo $Out = "%REPO%"
>>"%TMPPS%" echo $tag = '<script src="/guard.js"></script>'
>>"%TMPPS%" echo $rootIndex = Join-Path $Out 'index.html'
>>"%TMPPS%" echo $files = Get-ChildItem -Path $Out -Recurse -File -Include *.html, *.htm ^| Where-Object { -not ($_.FullName -ieq $rootIndex) }
>>"%TMPPS%" echo foreach ($f in $files) {
>>"%TMPPS%" echo   $p = $f.FullName
>>"%TMPPS%" echo   $html = Get-Content -LiteralPath $p -Raw
>>"%TMPPS%" echo   if ($html -match '<script\s+src="/?guard\.js"\s*>\s*</script>') { continue }
>>"%TMPPS%" echo   $new = $null
>>"%TMPPS%" echo   if ($html -match '</head>') {
>>"%TMPPS%" echo     $new = [regex]::Replace($html, '</head>', "$tag`r`n</head>", 'IgnoreCase')
>>"%TMPPS%" echo   } elseif ($html -match '<head(\b[^>]*)?>') {
>>"%TMPPS%" echo     $new = [regex]::Replace($html, '<head(\b[^>]*)?>', { param($m) "$($m.Value)`r`n$tag" }, 'IgnoreCase')
>>"%TMPPS%" echo   } else {
>>"%TMPPS%" echo     $new = "$tag`r`n$html"
>>"%TMPPS%" echo   }
>>"%TMPPS%" echo   if ($new -ne $html) {
>>"%TMPPS%" echo     Set-Content -LiteralPath $p -Value $new -Encoding UTF8
>>"%TMPPS%" echo     Write-Host "Injected guard into: $p"
>>"%TMPPS%" echo   }
>>"%TMPPS%" echo }

"%PWSH%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%TMPPS%" >> "%INJLOG%" 2>&1
del /q "%TMPPS%" >nul 2>&1

REM === 1) keep GitHub Pages helpers (in case export overwrote them) ===
echo guide.smmarta.com> CNAME
type NUL > .nojekyll

REM === 2) write/update version.json (YYYY-MM-DD-HHMM) ===
for /f %%i in ('%PWSH% -NoProfile -NonInteractive -Command "Get-Date -Format yyyy-MM-dd-HHmm"') do set "V=%%i"
> version.json echo { "v": "%V%" }

REM === 3) commit & push (silent; log to file) ===
%GIT% add -A >> "%LOG%" 2>&1
%GIT% diff --cached --quiet && echo %date% %time% No changes to publish.>> "%LOG%" & goto :end
%GIT% commit -m "Publish %V%" >> "%LOG%" 2>&1
%GIT% push origin main >> "%LOG%" 2>&1

echo %date% %time% Deployed build %V%  https://guide.smmarta.com/>> "%LOG%"

:end
endlocal
