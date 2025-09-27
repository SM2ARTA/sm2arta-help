@echo off
setlocal
cd /d C:\Users\abram\Documents\GitHub\sm2arta-help

REM --- ensure GitHub Pages helpers exist
echo admin.smmarta.com> CNAME
type NUL > .nojekyll

REM --- make a version string like 2025-09-27-153045
for /f "tokens=1-2 delims==." %%a in ('wmic os get LocalDateTime /value ^| find "="') do set DTS=%%b
set V=%DTS:~0,4%-%DTS:~4,2%-%DTS:~6,2%-%DTS:~8,2%-%DTS:~10,2%-%DTS:~12,2%

REM --- write version.json
> version.json echo { "v": "%V%" }

REM --- stage/commit/push
git add -A
git diff --cached --quiet && echo No changes to publish.& goto :end
git commit -m "Publish %V%"
git push origin main

echo.
echo Deployed build %V%
echo Open: https://admin.smmarta.com/
echo.

:end
endlocal
