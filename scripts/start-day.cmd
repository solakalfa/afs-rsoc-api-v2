@echo off
setlocal
title RSOC Start Day (CMD v3.1)

REM ================== BASIC INFO ==================
set "PROJECT=afs-rsoc-api-v2"
set "REGION=us-central1"
set "SERVICE_PREFIX=afs-rsoc-api"

echo == RSOC Start Day (CMD v3.1) ==
echo Project: %PROJECT%  Region: %REGION%  Service: %SERVICE_PREFIX%
echo.

REM ===== Ensure Postgres CLI in PATH (for monitor DB ping) =====
if exist "C:\Program Files\PostgreSQL\17\bin\psql.exe" set "PATH=C:\Program Files\PostgreSQL\17\bin;%PATH%"

REM ================== [0] TOOLS ==================
where curl >nul 2>nul || (echo ERROR: curl not found & goto fail)
where git  >nul 2>nul || (echo ERROR: git not found & goto fail)
where node >nul 2>nul || (echo ERROR: node not found & goto fail)
where npm  >nul 2>nul || (echo ERROR: npm not found & goto fail)
where psql >nul 2>nul && (set HAVE_PSQL=1) || (set HAVE_PSQL=0)

REM ================== [1] GIT ====================
echo [1/6] Git sync
git fetch origin || goto fail
git checkout master || goto fail
git pull --ff-only || goto fail
echo OK Git up to date
echo.

REM ================== [2] ENV ====================
echo [2/6] Load environment
set "ENV_FILE="
if exist ".env.local" set "ENV_FILE=.env.local"
if not defined ENV_FILE if exist ".env" set "ENV_FILE=.env"
if not defined ENV_FILE ( echo ERROR: Missing .env.local/.env & goto fail )

for /f "usebackq tokens=* delims=" %%L in (`type "%ENV_FILE%" ^| findstr /rvc:"^#"` ) do (
  echo %%L | findstr "=" >nul && (set %%L)
)
if not defined DATABASE_URL ( echo ERROR: DATABASE_URL is not set & goto fail )
if not defined AUTH_TOKEN if not defined RSOC_API_TOKEN ( echo ERROR: AUTH_TOKEN/RSOC_API_TOKEN not set & goto fail )
echo OK Loaded %ENV_FILE%
echo.

REM =========== [3] DB CONNECTIVITY + MIGRATIONS ===========
echo [3/6] Database connectivity
set "SKIP_DB=0"
if "%HAVE_PSQL%"=="0" (
  echo WARN: psql not in PATH, skipping DB checks/migrations
  set "SKIP_DB=1"
)
if "%SKIP_DB%"=="0" (
  psql "%DATABASE_URL%" -c "SELECT 1;" >nul 2>nul || ( echo ERROR: DB unreachable & goto fail_db )
  echo OK DB reachable
  echo.
  echo [4/6] Migrations
  if exist "sql\migrations\*.sql" (
    for %%F in (sql\migrations\*.sql) do (
      echo Applying %%F
      psql "%DATABASE_URL%" -f "%%F" >nul 2>nul || goto fail_db
    )
  ) else (
    echo No migrations to apply
  )
  REM Schema guards to prevent loops on fresh DBs
  psql "%DATABASE_URL%" -c "ALTER TABLE public.conversions ADD COLUMN IF NOT EXISTS payload JSONB;" >nul 2>nul
  psql "%DATABASE_URL%" -c "ALTER TABLE public.conversions ADD COLUMN IF NOT EXISTS idempotency_key TEXT;" >nul 2>nul
  echo OK Migrations applied
) else (
  echo Skipping migrations
)
echo.

REM ================== [5] START SERVER ====================
REM ================== [5/6] START SERVER ====================
echo [5/6] Starting server

REM Pick port: prefer existing PORT, else 8080, else 3000, else 8081
if not defined PORT set "PORT=8080"

netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
if not errorlevel 1 (
  set "PORT=3000"
  netstat -ano | findstr /R /C:":%PORT% .*LISTENING" >nul
  if not errorlevel 1 set "PORT=8081"
)

echo Using PORT=%PORT%

if not exist "logs" mkdir "logs"
set "SERVER_LOG=logs\server-%PORT%.log"

REM Install deps quietly
call npm install --no-fund --no-audit >nul 2>nul

REM Start server in background; log redirected
if exist "package.json" (
  start "" /b cmd /c "set PORT=%PORT%&& npm run dev" >> "%SERVER_LOG%" 2>&1
) else if exist "services\api\server.mjs" (
  start "" /b cmd /c "set PORT=%PORT%&& node services\api\server.mjs" >> "%SERVER_LOG%" 2>&1
) else if exist "dist\server.js" (
  start "" /b cmd /c "set PORT=%PORT%&& node dist\server.js" >> "%SERVER_LOG%" 2>&1
) else (
  echo WARN: No server entrypoint found. Skipping server start.
  goto after_server
)

REM Give server a few seconds to boot
timeout /t 4 >nul

REM === Explicit health check ===
curl -s -o NUL -w "%%{http_code}" http://127.0.0.1:%PORT%/api/health > "%TEMP%\rsoc_code.txt"
set /p HC=<"%TEMP%\rsoc_code.txt"
if "%HC%"=="200" (
  echo Health check: %HC% (OK)
) else (
  echo Health check: %HC% (FAILED) -- see "%SERVER_LOG%"
)

:after_server

REM ================== [6] MONITOR ====================
call scripts\monitor.cmd
echo == DONE ==
exit /b 0

:fail_db
echo ERROR: Database not reachable or migration failed
goto fail

:fail
echo.
echo == FAILED ==
exit /b 1
