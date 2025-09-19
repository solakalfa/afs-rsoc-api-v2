@echo off
setlocal
title RSOC Monitor (Lite v3)

echo == RSOC Monitor (Lite v3) ==

REM [0] load env
set "ENV_FILE="
if exist ".env.local" set "ENV_FILE=.env.local"
if not defined ENV_FILE if exist ".env" set "ENV_FILE=.env"
if defined ENV_FILE (
  for /f "usebackq tokens=* delims=" %%L in (`type "%ENV_FILE%" ^| findstr /rvc:"^#"` ) do (
    echo %%L | findstr "=" >nul && (set %%L)
  )
  echo Using env: %ENV_FILE%
) else (
  echo WARN: Missing .env.local/.env
)

REM derive token (AUTH_TOKEN first, then RSOC_API_TOKEN)
set "TOKEN=%AUTH_TOKEN%"
if "%TOKEN%"=="" set "TOKEN=%RSOC_API_TOKEN%"

REM [1] DB ping
if "%DATABASE_URL%"=="" goto no_db
psql "%DATABASE_URL%" -c "SELECT 1;" >nul 2>nul && echo DB: reachable || echo DB: UNREACHABLE
goto health
:no_db
echo DB: no DATABASE_URL

:health
REM [2] Health -> expect 200
curl -s -o NUL -w "%%{http_code}" http://127.0.0.1:8080/api/health > "%TEMP%\rsoc_mon_code.txt"
set /p HC=<"%TEMP%\rsoc_mon_code.txt"
echo Health: %HC% (expect 200)

REM [3] Convert (no token, POST) -> expect 401
echo {} > "%TEMP%\rsoc_mon_body.json"
curl -s -o NUL -w "%%{http_code}" -H "Content-Type: application/json" --data "@%TEMP%\rsoc_mon_body.json" http://127.0.0.1:8080/api/convert > "%TEMP%\rsoc_mon_code.txt"
set /p AC=<"%TEMP%\rsoc_mon_code.txt"
echo Convert no-token POST: %AC% (expect 401)

REM [4] Convert (with token, POST) -> expect 200/201
if "%TOKEN%"=="" goto no_token
echo {"click_id":"monitor-%RANDOM%","value":1,"currency":"USD"} > "%TEMP%\rsoc_mon_body.json"
curl -s -o NUL -w "%%{http_code}" -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" --data "@%TEMP%\rsoc_mon_body.json" http://127.0.0.1:8080/api/convert > "%TEMP%\rsoc_mon_code.txt"
set /p CC=<"%TEMP%\rsoc_mon_code.txt"
echo Convert with-token POST: %CC% (expect 200/201)
goto end

:no_token
echo Convert with-token: SKIPPED (no token)

:end
echo == End ==
exit /b 0
