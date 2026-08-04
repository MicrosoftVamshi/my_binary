$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# One-shot VM bootstrap: pulls the 7-Zip binaries and the encrypted source package,
# then extracts the full drop into C:\searchdrop. Run this once per VM.

$root = 'C:\searchdrop'
$base = 'https://raw.githubusercontent.com/MicrosoftVamshi/my_binary/local_search'
$password = 'Srch!Drop#2026-0804$kQ9wR'

New-Item -ItemType Directory -Force -Path $root | Out-Null

function Get-DropFile {
    param([string]$RelativeUrl, [string]$Destination)
    $uri = $base + '/' + $RelativeUrl + '?nocache=' + [guid]::NewGuid().ToString('N')
    Invoke-WebRequest -Uri $uri -OutFile $Destination -UseBasicParsing
    Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue
    return (Get-Item $Destination).Length
}

$sizes = @()
$sizes += '7z.exe=' + (Get-DropFile -RelativeUrl 'tools/7z.exe' -Destination (Join-Path $root '7z.exe'))
$sizes += '7z.dll=' + (Get-DropFile -RelativeUrl 'tools/7z.dll' -Destination (Join-Path $root '7z.dll'))
$sizes += 'pkg_src.7z=' + (Get-DropFile -RelativeUrl 'pkg/pkg_src.7z' -Destination (Join-Path $root 'pkg_src.7z'))

& (Join-Path $root '7z.exe') x (Join-Path $root 'pkg_src.7z') "-o$root" "-p$password" -aoa -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z extraction failed with exit code $LASTEXITCODE" }

$checks = @(
    (Join-Path $root 'scripts\_common.ps1'),
    (Join-Path $root 'WssTestsDllPortable\Build.ps1'),
    (Join-Path $root 'SCNS\local_search\SearchServiceApplication.scn')
)

$message = 'BOOTSTRAP ' + ($sizes -join ' ')
foreach ($check in $checks) {
    $message += "`r`n" + (Split-Path $check -Leaf) + '=' + (Test-Path $check)
}

Set-Clipboard -Value $message
Write-Host $message
