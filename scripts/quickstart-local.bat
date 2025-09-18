@echo off
REM RSOC — Quickstart Local (Windows)

echo [1/3] בדיקת DB מקומי...
"C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -d rsoc -c "select 1;" >nul 2>&1
if errorlevel 1 (
  echo ❌ DB לא נגיש. ודא שהתקנת והפעלת Postgres.
  exit /b 1
)
echo ✓ DB זמין

echo [2/3] התקנת חבילות...
npm install >nul

echo [3/3] הרצת שרת...
npm run dev
