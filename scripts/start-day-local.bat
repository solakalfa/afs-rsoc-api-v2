@echo off
setlocal
chcp 65001>nul
set PGPASSWORD=0505554499

echo == Git pull ==
git pull

echo == Quickstart Local ==
call scripts\quickstart-local.bat

rem == Wait for health up to 60s ==
set URL=http://127.0.0.1:8080/api/health
set /a tries=0
:WAIT_HEALTH
for /f "delims=" %%H in ('curl -s %URL%') do set RESP=%%H
echo %RESP% | findstr /i /c:"\"db\":true" >nul && goto HEALTH_OK
set /a tries+=1
if %tries% GEQ 60 goto HEALTH_TIMEOUT
ping -n 2 127.0.0.1 >nul
goto WAIT_HEALTH

:HEALTH_OK
echo OK: Health
goto END

:HEALTH_TIMEOUT
echo ERROR: Health did not become ready in time. Check "RSOC API" window.

:END
endlocal
