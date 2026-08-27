#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePassword
)

$ErrorActionPreference = 'Stop'
$root = 'C:\SsaChromeValidation'
$tools = Join-Path $root 'tools'
$compiler = Join-Path $root 'compiler'
$payload = Join-Path $root 'payload'
$report = Join-Path $root 'prepare-report.txt'
$baseUrl = 'https://raw.githubusercontent.com/MicrosoftVamshi/my_binary/main'
$compilerArchive = Join-Path $root 'compiler.7z'
$payloadArchive = Join-Path $root 'payload.7z'
$expectedCompilerHash = '65990F3C1C3BC365D0EDD817DC53874033258492EFB07EFEF0CADCB37D89DF43'
$expectedPayloadHash = '7004A03153B10861A9E4205086A7665CD41A2FC515CAC0E32593CF7E4B8B1784'

Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
New-Item $tools, $compiler, $payload -ItemType Directory -Force | Out-Null

function Download([string]$RelativePath, [string]$Destination) {
    Invoke-WebRequest "$baseUrl/$RelativePath" -OutFile $Destination -UseBasicParsing
    Unblock-File -LiteralPath $Destination
}

Download 'tools/7zip/7z.exe' (Join-Path $tools '7z.exe')
Download 'tools/7zip/7z.dll' (Join-Path $tools '7z.dll')
Download 'transfers/SSA/WssTestsDllPortable_Chrome_20260827.7z' $compilerArchive
Download 'transfers/SSA/ssa-chrome-runtime-fix-20260827.7z' $payloadArchive

$compilerHash = (Get-FileHash $compilerArchive -Algorithm SHA256).Hash
$payloadHash = (Get-FileHash $payloadArchive -Algorithm SHA256).Hash
if ($compilerHash -ne $expectedCompilerHash) { throw "Compiler archive hash mismatch: $compilerHash" }
if ($payloadHash -ne $expectedPayloadHash) { throw "Payload archive hash mismatch: $payloadHash" }

$sevenZip = Join-Path $tools '7z.exe'
& $sevenZip x -y "-p$ArchivePassword" "-o$compiler" $compilerArchive | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Compiler extraction failed: $LASTEXITCODE" }
& $sevenZip x -y "-p$ArchivePassword" "-o$payload" $payloadArchive | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Payload extraction failed: $LASTEXITCODE" }
Get-ChildItem $compiler, $payload -Recurse -File | Unblock-File

$manifest = @(Import-Csv (Join-Path $payload 'MANIFEST.csv'))
foreach ($entry in $manifest) {
    $path = Join-Path $payload $entry.Path
    if (-not (Test-Path $path -PathType Leaf)) { throw "Payload file missing: $($entry.Path)" }
    if ((Get-FileHash $path -Algorithm SHA256).Hash -ne $entry.SHA256) {
        throw "Payload hash mismatch: $($entry.Path)"
    }
}

$buildScript = Get-ChildItem $compiler -Filter Build.ps1 -Recurse -File | Select-Object -First 1
if (-not $buildScript) { throw 'Build.ps1 was not found in the compiler package.' }
$buildRoot = $buildScript.Directory.FullName
$source = Join-Path $buildRoot 'src\Local_Search\SearchServiceApplication.cs'
Copy-Item (Join-Path $payload 'SearchServiceApplication.cs') $source -Force
$buildLog = Join-Path $root 'build.log'
& $buildScript.FullName -Clean *>&1 | Set-Content $buildLog
if ($LASTEXITCODE -ne 0) { throw "Build failed. See $buildLog" }

$builtDll = Join-Path $buildRoot 'bin\MS.Internal.Test.Automation.Office.Osg.Wss.Tests.dll'
if (-not (Test-Path $builtDll -PathType Leaf)) { throw "Built DLL missing: $builtDll" }
$scenario = Join-Path $root 'SearchServiceApplication.scn'
[xml]$scenarioXml = Get-Content (Join-Path $payload 'SearchServiceApplication.scn') -Raw
$assembly = $scenarioXml.SelectSingleNode("//*[local-name()='Assembly']")
if (-not $assembly) { throw 'SSA Assembly element was not found.' }
$assembly.InnerText = $builtDll
$scenarioXml.Save($scenario)

$jobRoots = @(
    Get-ChildItem 'C:\data\CHT\*\UserLogs\*\TestResults\ststest\SearchServiceApplicationLeftNavCheck' -Directory -ErrorAction SilentlyContinue
    Get-ChildItem 'D:\data\CHT\*\UserLogs\*\TestResults\ststest\SearchServiceApplicationLeftNavCheck' -Directory -ErrorAction SilentlyContinue
) | Sort-Object LastWriteTime -Descending
$jobRoot = $jobRoots | Select-Object -First 1
$files = if ($jobRoot) { @(Get-ChildItem $jobRoot.FullName -Filter files.txt -Recurse -File -ErrorAction SilentlyContinue) } else { @() }
$psinfo = if ($jobRoot) { @(Get-ChildItem $jobRoot.FullName -Filter *.psinfo -Recurse -File -ErrorAction SilentlyContinue) } else { @() }

$shell = New-Object -ComObject WScript.Shell
$shortcuts = @(Get-ChildItem ([Environment]::GetFolderPath('Desktop')) -Filter '*Rerun*.lnk' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $shortcut = $shell.CreateShortcut($_.FullName)
    [pscustomobject]@{ Path=$_.FullName; Target=$shortcut.TargetPath; Arguments=$shortcut.Arguments }
})

$lines = @(
    'PREPARE_OK=True'
    "COMPILER_HASH=$compilerHash"
    "PAYLOAD_HASH=$payloadHash"
    "BUILD_DLL=$builtDll"
    "BUILD_DLL_HASH=$((Get-FileHash $builtDll -Algorithm SHA256).Hash)"
    "SCENARIO=$scenario"
    "JOB_ROOT=$($jobRoot.FullName)"
    "FILES_COUNT=$($files.Count)"
    "PSINFO_COUNT=$($psinfo.Count)"
)
$lines += $files | ForEach-Object { "FILES=$($_.FullName)" }
$lines += $psinfo | ForEach-Object { "PSINFO=$($_.FullName)" }
$lines += $shortcuts | ForEach-Object { "RERUN=$($_.Target) $($_.Arguments)" }
$lines | Set-Content $report
Get-Content $report
