# Builds dist\HarpurNMS-Portable.exe: one file holding the app, the server and PostgreSQL.
# Only named files go in, so no .env, database or router login can end up inside.
param([string]$PgRoot = 'C:\pgsql16-dev', [switch]$SkipAppBuild)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$work = Join-Path $repo 'build\portable'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force "$work\app", "$work\server\internal\database", "$work\pg\bin" | Out-Null

Push-Location $repo
if (-not $SkipAppBuild) {
    flutter build windows --release --no-pub
    if ($LASTEXITCODE) { throw 'flutter build failed' }
}
Pop-Location
Copy-Item -Recurse "$repo\build\windows\x64\runner\Release\*" "$work\app"

Push-Location "$repo\backend"
go build -o "$work\server\server.exe" ./cmd/server
if ($LASTEXITCODE) { throw 'server build failed' }
Pop-Location
Copy-Item -Recurse "$repo\backend\internal\database\migrations" "$work\server\internal\database\migrations"

Copy-Item "$PgRoot\bin\postgres.exe", "$PgRoot\bin\initdb.exe", "$PgRoot\bin\pg_ctl.exe", "$PgRoot\bin\*.dll" "$work\pg\bin"
Copy-Item -Recurse "$PgRoot\lib" "$work\pg\lib"
Copy-Item -Recurse "$PgRoot\share" "$work\pg\share"

# A PC without the Visual C++ runtime still runs both.
foreach ($dll in 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item "$env:WINDIR\System32\$dll" "$work\app"
    Copy-Item "$env:WINDIR\System32\$dll" "$work\pg\bin"
}

$bad = Get-ChildItem -Recurse -Force $work | Where-Object { $_.Name -in '.env', 'config.env', 'pg_hba.conf' -or $_.FullName -like '*\pgdata*' }
if ($bad) { throw "Refusing to package: $($bad.FullName -join ', ')" }

$zip = "$repo\backend\cmd\nms-portable\payload.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path "$work\app", "$work\server", "$work\pg" -DestinationPath $zip -CompressionLevel Optimal

New-Item -ItemType Directory -Force "$repo\dist" | Out-Null
Push-Location "$repo\backend"
go build -tags portable -ldflags '-s -w' -o "$repo\dist\HarpurNMS-Portable.exe" ./cmd/nms-portable
if ($LASTEXITCODE) { throw 'launcher build failed' }
Pop-Location
Remove-Item -Force $zip
Remove-Item -Recurse -Force $work
Get-Item "$repo\dist\HarpurNMS-Portable.exe" | Select-Object FullName, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB) } }
