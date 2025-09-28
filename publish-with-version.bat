@echo off
setlocal EnableExtensions

rem === paths ===
set "REPO=C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help"
set "LOGDIR=%REPO%\_logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
set "LOG=%LOGDIR%\publish.log"
set "INJLOG=%LOGDIR%\inject-guard.log"
set "INJECT=%REPO%\inject-guard.ps1"

rem === pick PowerShell (prefer pwsh, fallback to WindowsPowerShell) ===
set "PWSH=pwsh.exe"
where %PWSH% >nul 2>&1 || set "PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

rem === pick git (system or GitHub Desktop embedded) ===
set "GIT=git"
%GIT% --version >nul 2>&1 || (
  for /f "delims=" %%p in ('%PWSH% -NoProfile -NonInteractive -Command ^
    "(Get-ChildItem $env:LOCALAPPDATA\GitHubDesktop -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName"') do set "GHDPATH=%%p"
  if exist "%GHDPATH%\resources\app\git\cmd\git.exe" set "GIT=%GHDPATH%\resources\app\git\cmd\git.exe"
)

cd /d "%REPO%"

rem === 1) run injector BEFORE staging files (background-safe; log output) ===
if exist "%INJECT%" (
  "%PWSH%" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%INJECT%" 1>>"%INJLOG%" 2>&1
) else (
  echo %date% %time% [WARN] Injector not found: %INJECT%>>"%INJLOG%"
)

rem === 2) keep GitHub Pages helpers (in case export overwrote them) ===
echo guide.smmarta.com> CNAME
type NUL > .nojekyll

rem === 3) write/update version.json (YYYY-MM-DD-HHMM) ===
for /f %%i in ('%PWSH% -NoProfile -NonInteractive -Command "Get-Date -Format yyyy-MM-dd-HHmm"') do set "V=%%i"
> version.json echo { "v": "%V%" }

rem === 4) commit & push (background-safe; log to file) ===
%GIT% add -A 1>>"%LOG%" 2>&1
%GIT% diff --cached --quiet && echo %date% %time% No changes to publish.>>"%LOG%" & goto :end
%GIT% commit -m "Publish %V%" 1>>"%LOG%" 2>&1
%GIT% push origin main 1>>"%LOG%" 2>&1
echo %date% %time% Deployed build %V%  https://guide.smmarta.com/>> "%LOG%"

:end
endlocal
