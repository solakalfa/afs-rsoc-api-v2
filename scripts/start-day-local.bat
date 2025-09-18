@echo off
setlocal
chcp 65001>nul
set PGPASSWORD=0505554499

REM ===== RSOC — Start Day Local =====

echo == Git pull ==
git pull

echo == Quickstart Local ==
call scripts\quickstart-local.bat

REM == Wait for health up to 60s ==
set URL=http://127.0.0.1:8080/api/health
set /a tries=0
:WAIT_HEALTH
for /f "delims=" %%H in ('curl -s %URL%') do set RESP=%%H
echo %RESP% | find "\"db\":true" >nul && goto HEALTH_OK
set /a tries+=1
if %tries% GEQ 60 goto HEALTH_TIMEOUT
ping -n 2 127.0.0.1 >nul
goto WAIT_HEALTH

:HEALTH_OK
echo ✓ Health OK
curl -s http://127.0.0.1:8080/api/health-db & echo.

echo == Smoke ==
curl -sX POST http://127.0.0.1:8080/api/tracking ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer dev-token-123" ^
  -H "Idempotency-Key: clk-001" ^
  -d "{\"clickId\":\"clk_001\",\"source\":\"meta\",\"campaignId\":\"cmp_11\",\"ts\":1710000000}" & echo.

curl -sX POST http://127.0.0.1:8080/api/convert ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer dev-token-123" ^
  -H "Idempotency-Key: conv-001" ^
  -d "{\"clickId\":\"clk_001\",\"event\":\"purchase\",\"value\":29.9,\"currency\":\"USD\",\"ts\":1710000300}" & echo.

goto END

:HEALTH_TIMEOUT
echo ❌ Health לא עלה בזמן. בדוק את חלון "RSOC API" ולוגים.

:END
endlocal
