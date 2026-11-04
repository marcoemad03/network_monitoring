# Builds, in dist\:
#   open server.exe       starts or stops the database and server on this PC
#   Harpur NMS.exe        the app, for this PC and others, connected to this PC's server
# The access key lives in backend\.env and inside the client exe, never in git.
param([string]$ServerHost = '172.16.0.50', [switch]$SkipAppBuild)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$envFile = "$repo\backend\.env"

$line = Select-String -Path $envFile -Pattern '^NMS_ACCESS_KEY=(.+)$' | Select-Object -First 1
if ($line) {
    $key = $line.Matches[0].Groups[1].Value.Trim()
} else {
    $bytes = New-Object byte[] 24
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $key = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    Add-Content -Path $envFile -Value "NMS_ACCESS_KEY=$key" -Encoding ascii
}

if (-not $SkipAppBuild) {
    Push-Location $repo
    flutter build windows --release --no-pub
    if ($LASTEXITCODE) { throw 'flutter build failed' }
    Pop-Location
}

$work = "$repo\build\client"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force "$work\app" | Out-Null
Copy-Item -Recurse "$repo\build\windows\x64\runner\Release\*" "$work\app"
foreach ($dll in 'msvcp140.dll', 'msvcp140_1.dll', 'msvcp140_2.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item "$env:WINDIR\System32\$dll" "$work\app"
}
$zip = "$repo\backend\cmd\nms-client\payload.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path "$work\app" -DestinationPath $zip -CompressionLevel Optimal

New-Item -ItemType Directory -Force "$repo\dist" | Out-Null
Push-Location "$repo\backend"
go build -tags portable -ldflags "-s -w -H=windowsgui -X main.serverHost=$ServerHost -X main.accessKey=$key" -o "$repo\dist\Harpur NMS.exe" ./cmd/nms-client
if ($LASTEXITCODE) { throw 'client build failed' }
go build -ldflags '-s -w -H=windowsgui' -o "$repo\dist\open server.exe" ./cmd/open-server
if ($LASTEXITCODE) { throw 'open server build failed' }
go build -o cmd\server\server.exe.new ./cmd/server
if ($LASTEXITCODE) { throw 'server build failed' }
Pop-Location
Remove-Item -Force $zip
Remove-Item -Recurse -Force $work
Get-ChildItem "$repo\dist" -Filter '*.exe' | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB) } }
