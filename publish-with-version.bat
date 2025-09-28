@echo off
setlocal

rem --- paths
set REPO=C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help
set PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe

rem --- pick git (system or GitHub Desktop embedded)
set GIT=git
%GIT% --version >nul 2>&1 || (
  for /f "delims=" %%p in ('powershell -NoProfile -Command ^
    "(Get-ChildItem $env:LOCALAPPDATA\GitHubDesktop -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName"') do set GHDPATH=%%p
  if exist "%GHDPATH%\resources\app\git\cmd\git.exe" set GIT="%GHDPATH%\resources\app\git\cmd\git.exe"
)


rem --- keep GitHub Pages helpers (in case export overwrote them)
echo guide.smmarta.com> CNAME
type NUL > .nojekyll

rem --- write/update version.json (YYYY-MM-DD-HHMM)
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd-HHmm"') do set V=%%i
> version.json echo { "v": "%V%" }

rem --- commit & push
%GIT% add -A
%GIT% diff --cached --quiet && echo No changes to publish.& goto :end
%GIT% commit -m "Publish %V%"
%GIT% push origin main

echo(
echo Deployed build %V%  https://guide.smmarta.com/
echo(

:end
endlocal
