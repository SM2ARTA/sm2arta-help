@echo off
setlocal
cd /d C:\Users\abram\Documents\GitHub\sm2arta-help

REM keep helpers (in case the export overwrote)
echo guide.smmarta.com> CNAME
type NUL > .nojekyll

REM timestamp like 2025-09-27-1650
for /f "tokens=1-2 delims==." %%a in ('wmic os get LocalDateTime /value ^| find "="') do set DTS=%%b
set V=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%-%DTS:~8,2%%DTS:~10,2%

> version.json echo { "v": "%V%" }

git add -A
git diff --cached --quiet && echo No changes.& goto :end
git commit -m "Publish %V%"
git push origin main

:end
endlocal
