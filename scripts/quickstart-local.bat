@echo off
setlocal
chcp 65001>nul
REM ===== RSOC — Quickstart Local (Windows) =====
set PSQL="C:\Program Files\PostgreSQL\17\bin\psql.exe"
set PGPASSWORD=0505554499

call scripts\kill-8080.bat

REM [1] DB reachable?
%PSQL% -U postgres -d rsoc -c "select 1;" >nul 2>&1 || (
  echo ❌ DB לא נגיש. ודא ששירות PostgreSQL רץ.
  exit /b 1
)

echo ✓ DB זמין

REM [2] .env.local
if not exist .env.local (
  echo ❌ חסר .env.local. הוסף DATABASE_URL ונסה שוב.
  exit /b 1
)

echo ✓ .env.local קיים

REM [3] install deps
npm ci >nul 2>&1 || npm install >nul

REM [4] start server in a new window
start "RSOC API" cmd /k "cd /d %cd% && npm run dev"

endlocal
