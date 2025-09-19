@echo off
setlocal enabledelayedexpansion
title RSOC Start Day (CMD)

REM === Config ===
set PROJECT=afs-rsoc-api-v2
set REGION=us-central1
set SERVICE_PREFIX=afs-rsoc-api

echo == RSOC Start Day (CMD) ==
echo Project: %PROJECT%  Region: %REGION%  Service: %SERVICE_PREFIX%
echo.

REM [1/6] Git sync
echo [1/6] Git sync
git fetch origin || goto :fail
git checkout master || goto :fail
git pull --ff-only || goto :fail
echo OK Git up to date
echo.

REM [2/6] Load env (.env.local -> .env)
echo [2/6] Load environment
set ENV_FILE=
if exist ".env.local" set ENV_FILE=.env.local
if not defined ENV_FILE if exist ".env" set ENV_FILE=.env

if not defined ENV_FILE (
  echo ERROR: Missing .env.local/.env
  goto :fail
)

for /f "usebackq tokens=* delims=" %%L in (`type "%ENV_FILE%" ^| findstr /rvc:"^#"` ) do (
  REM Only lines with KEY=VAL
  echo %%L | findstr "=" >nul && (set %%L)
)
if not defined DATABASE_URL (
  echo ERROR: DATABASE_URL is not set
  goto :fail
)
if not defined RSOC_API_TOKEN (
  echo ERROR: RSOC_API_TOKEN is not set
  goto :fail
)
echo OK Loaded %ENV_FILE%
echo.

REM [3/6] DB connectivity
echo [3/6] Database connectivity
where psql >nul 2>nul
if errorlevel 1 (
  echo WARN: psql not found in PATH ^(skipping DB checks/migrations^)
) else (
  psql "%DATABASE_URL%" -c "SELECT 1;" >nul 2>nul || goto :fail_db
  echo OK DB reachable
)
echo.

REM [4/6] Migrations
if exist "sql\migrations" (
  if exist "sql\migrations\*.sql" (
    for %%F in (sql\migrations\*.sql) do (
      echo Applying %%F
      psql "%DATABASE_URL%" -f "%%F" >nul 2>nul || goto :fail_db
    )
    echo OK Migrations applied
  ) else (
    echo No migrations to apply
  )
) else (
  echo No migrations folder found
)
echo.

REM [5/6] Start server (background)
echo [5/6] Starting server
if exist "package.json" (
  call npm install >nul 2>nul || goto :fail
  start "" /b cmd /c "npm run dev"
) else if exist "services\api\server.mjs" (
  start "" /b cmd /c "node services\api\server.mjs"
) else if exist "dist\server.js" (
  start "" /b cmd /c "node dist\server.js"
) else (
  echo WARN: Could not find a known server entrypoint. Ensure npm run dev works.
)
REM Give server a moment to boot
timeout /t 3 >nul

REM [6/6] Smoke tests
echo [6/6] Smoke tests
set FAIL=0

REM Health (expect 200)
for /f %%S in ('curl -s -o NUL -w "%%{http_code}" http://127.0.0.1:8080/api/health') do set HC=%%S
if not "%HC%"=="200" (
  echo FAIL Health: %HC%
  set FAIL=1
) else (
  echo OK Health 200
)

REM Auth (expect 401)
for /f %%S in ('curl -s -o NUL -w "%%{http_code}" http://127.0.0.1:8080/api/convert') do set AC=%%S
if not "%AC%"=="401" (
  echo FAIL Auth (no token): %AC%
  set FAIL=1
) else (
  echo OK Auth 401
)

REM Conversion happy path (200/201)
for /f %%S in ('curl -s -o NUL -w "%%{http_code}" -H "Authorization: Bearer %RSOC_API_TOKEN%" -H "Content-Type: application/json" -d "{\"click_id\":\"test123\",\"value\":1,\"currency\":\"USD\"}" http://127.0.0.1:8080/api/convert') do set CC=%%S
if "%CC%"=="200" (set OKC=1) else if "%CC%"=="201" (set OKC=1) else (set OKC=0)
if "%OKC%"=="1" (
  echo OK Convert flow %CC%
) else (
  echo FAIL Convert flow %CC%
  set FAIL=1
)

echo.
if "%FAIL%"=="0" (
  echo == ALL CHECKS PASSED ==
  exit /b 0
) else (
  echo == SOME CHECKS FAILED ==
  exit /b 1
)

:fail_db
echo ERROR: Database not reachable or migration failed
goto :fail

:fail
echo.
echo == FAILED ==
exit /b 1
