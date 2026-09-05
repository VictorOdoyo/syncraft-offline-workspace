$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } elseif (Test-Path 'C:\syncraft-sdk\bin\flutter.bat') { 'C:\syncraft-sdk\bin\flutter.bat' } else { throw 'Install Flutter 3.47.2 and add its bin directory to PATH.' }
Push-Location (Join-Path $projectRoot 'apps/field')
try {
  & $flutterPath pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Dependency install failed' }
  & $flutterPath build web --release --no-web-resources-cdn
  if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
} finally { Pop-Location }
Push-Location $projectRoot
try {
  node scripts/package-offline.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Offline packaging failed' }
  docker compose up --build -d --wait --wait-timeout 180
  if ($LASTEXITCODE -ne 0) { throw 'Containers did not become healthy' }
  Write-Host 'Syncraft: http://127.0.0.1:5176'
  Write-Host 'Demo users: inspector, reviewer, observer, admin. Password: local-demo'
} finally { Pop-Location }
