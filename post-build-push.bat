@echo off
setlocal
cd /d C:\Users\you\Documents\GitHub\sm2arta-help

REM --- keep GitHub Pages helpers in case the build overwrote them
REM Replace the domain below with your real custom domain
echo guide.smmarta.com> CNAME
type NUL > .nojekyll

REM --- stage files
git add -A

REM --- skip commit if nothing changed
git diff --cached --quiet && echo No changes to publish.& goto :end

REM --- make a readable commit message with date+time
for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set TODAY=%%a-%%b-%%c
git commit -m "HelpNDoc build %TODAY% %time%"

REM --- push
git push origin main

:end
endlocal
