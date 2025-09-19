Param(
  [string]$Project = "afs-rsoc-api-v2",
  [string]$Region = "us-central1",
  [string]$ServicePrefix = "afs-rsoc-api"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "== RSOC Start Day (PowerShell) =="
Write-Host "Project: $Project, Region: $Region, Service: $ServicePrefix"
Write-Host ""

function Fail($msg) {
  Write-Host "❌ $msg" -ForegroundColor Red
  exit 1
}
function Warn($msg) {
  Write-Host "❗ $msg" -ForegroundColor Yellow
}
function Ok($msg) {
  Write-Host "✅ $msg" -ForegroundColor Green
}

# 1) Git sync
Write-Host "[1/7] Git sync"
git fetch origin | Out-Null
git checkout master | Out-Null
git pull --ff-only | Out-Null
Ok "Git up to date"

# 2) Load env from .env.local or .env
Write-Host "[2/7] Load environment"
$envFile = $null
if (Test-Path ".env.local") { $envFile = ".env.local" }
elseif (Test-Path ".env")    { $envFile = ".env" }

if ($envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
      $kv = $line -split "=",2
      if ($kv.Count -eq 2) {
        $key = $kv[0].Trim()
        $val = $kv[1].Trim().Trim('"')
        [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
      }
    }
  }
  Ok "Loaded env from $envFile"
} else {
  Fail "Missing .env.local/.env"
}

if (-not $env:DATABASE_URL -or -not $env:RSOC_API_TOKEN) {
  Fail "Missing DATABASE_URL or RSOC_API_TOKEN"
}

# 3) DB connectivity check
Write-Host "[3/7] Database connectivity"
$psql = (Get-Command psql -ErrorAction SilentlyContinue)
if (-not $psql) {
  Warn "psql not found in PATH — skipping DB connectivity/migrations. Install PostgreSQL client tools."
  $dbOk = $true
} else {
  try {
    & psql $env:DATABASE_URL -c "SELECT 1;" | Out-Null
    Ok "DB reachable"
    $dbOk = $true
  } catch {
    Fail "Database not reachable via psql"
  }
}

# 4) Run migrations (if psql exists)
Write-Host "[4/7] Migrations"
if ($psql) {
  $migDir = "sql/migrations"
  if (Test-Path $migDir) {
    Get-ChildItem $migDir -Filter *.sql | Sort-Object Name | ForEach-Object {
      Write-Host ("Applying {0}" -f $_.FullName)
      & psql $env:DATABASE_URL -f $_.FullName | Out-Null
    }
    Ok "Migrations applied"
  } else {
    Warn "$migDir not found (skipping)"
  }
} else {
  Warn "Skipping migrations (psql missing)"
}

# 5) Start server (background)
Write-Host "[5/7] Start server"
# prefer npm scripts
$serverPid = $null
try {
  if (Test-Path "package.json") {
    # install deps quick if needed
    npm install | Out-Null
    $proc = Start-Process -FilePath "npm" -ArgumentList "run","dev" -PassThru -WindowStyle Hidden
    $serverPid = $proc.Id
  } elseif (Test-Path "services/api/server.mjs") {
    $proc = Start-Process -FilePath "node" -ArgumentList "services/api/server.mjs" -PassThru -WindowStyle Hidden
    $serverPid = $proc.Id
  } elseif (Test-Path "dist/server.js") {
    $proc = Start-Process -FilePath "node" -ArgumentList "dist/server.js" -PassThru -WindowStyle Hidden
    $serverPid = $proc.Id
  } else {
    Warn "Could not find a known server entrypoint. Make sure npm run dev works."
  }
} catch {
  Warn "Failed starting server: $($_.Exception.Message)"
}
Start-Sleep -Seconds 3

# 6) Smoke tests
Write-Host "[6/7] Smoke tests"
$fail = 0

function StatusCode($url, $headers=@{}) {
  try {
    $wc = New-Object System.Net.WebClient
    foreach ($k in $headers.Keys) { $wc.Headers.Add($k, $headers[$k]) }
    $wc.DownloadString($url) | Out-Null
    return 200
  } catch [System.Net.WebException] {
    if ($_.Exception.Response) {
      return [int]$_.Exception.Response.StatusCode
    } else {
      return 0
    }
  }
}

$base = "http://127.0.0.1:8080"

# Health (expect 200); if no explicit health route exists in code, this may fail — acceptable for now
$code = StatusCode("$base/api/health")
if ($code -ne 200) { Write-Host "❌ Health: $code"; $fail=1 } else { Ok "Health 200" }

# Auth: expect 401 on /api/convert without token
$code = StatusCode("$base/api/convert")
if ($code -ne 401) { Write-Host "❌ Auth (no token): $code"; $fail=1 } else { Ok "Auth 401 OK" }

# Conversion happy flow (200/201)
try {
  $uri = "$base/api/convert"
  $body = '{"click_id":"test123","value":1,"currency":"USD"}'
  $wc = New-Object System.Net.WebClient
  $wc.Headers.Add("Content-Type","application/json")
  $wc.Headers.Add("Authorization","Bearer " + $env:RSOC_API_TOKEN)
  $wc.UploadString($uri, "POST", $body) | Out-Null
  Ok "Convert flow OK"
} catch [System.Net.WebException] {
  $status = 0
  if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
  Write-Host "❌ Convert flow failed ($status)"
  $fail = 1
}

# 7) Summary
if ($fail -eq 0) {
  Ok "All checks passed"
  exit 0
} else {
  Fail "Some checks failed"
}
