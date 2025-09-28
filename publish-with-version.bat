@echo off
setlocal

rem --- paths
set REPO=C:\Users\abram\OneDrive\DOCUMENTS\GitHub\sm2arta-help
set PWSH=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe

cd /d "%REPO%"

rem --- run the injector BEFORE staging files
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%REPO%\inject-guard.ps1"

rem --- keep GitHub Pages helpers (in case export overwrote them)
echo guide.smmarta.com> CNAME
type NUL > .nojekyll

rem --- write/update version.json (YYYY-MM-DD-HHMM)
for /f "tokens=1-2 delims==." %%a in ('wmic os get LocalDateTime /value ^| find "="') do set DTS=%%b
set V=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%-%DTS:~8,2%%DTS:~10,2%
> version.json echo { "v": "%V%" }

rem --- commit & push
git add -A
git diff --cached --quiet && echo No changes to publish.& goto :end
git commit -m "Publish %V%"
git push origin main

echo.
echo Deployed build %V%  https://guide.smmarta.com/
echo.

:end
endlocal
