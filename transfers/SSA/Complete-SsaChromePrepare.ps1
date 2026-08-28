#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = 'C:\SsaChromeValidation'
$compiler = Join-Path $root 'compiler'
$payload = Join-Path $root 'payload'
$builtDll = Join-Path $compiler 'bin\MS.Internal.Test.Automation.Office.Osg.Wss.Tests.dll'
$scenario = Join-Path $root 'SSAChromeRuntime.scn'
$legacyScenario = Join-Path $root 'SearchServiceApplication.scn'
$fileList = Join-Path $root 'files.txt'
$report = Join-Path $root 'prepare-report.txt'

if (-not (Test-Path $builtDll -PathType Leaf)) { throw "Built DLL missing: $builtDll" }
[xml]$scenarioXml = Get-Content (Join-Path $payload 'SearchServiceApplication.scn')
$assembly = $scenarioXml.SelectSingleNode("//*[local-name()='Assembly']")
if (-not $assembly) { throw 'SSA Assembly element was not found.' }
$assembly.InnerText = $builtDll
$scenarioXml.Save($scenario)
Set-Content -LiteralPath $fileList -Value @($scenario, $builtDll)
Remove-Item -LiteralPath $legacyScenario -Force -ErrorAction SilentlyContinue
Unblock-File $builtDll, $scenario, $fileList

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
    "BUILD_DLL=$builtDll"
    "BUILD_DLL_HASH=$((Get-FileHash $builtDll -Algorithm SHA256).Hash)"
    "SCENARIO=$scenario"
    "FILE_LIST=$fileList"
    "JOB_ROOT=$($jobRoot.FullName)"
    "FILES_COUNT=$($files.Count)"
    "PSINFO_COUNT=$($psinfo.Count)"
)
$lines += $files | ForEach-Object { "FILES=$($_.FullName)" }
$lines += $psinfo | ForEach-Object { "PSINFO=$($_.FullName)" }
$lines += $shortcuts | ForEach-Object { "RERUN=$($_.Target) $($_.Arguments)" }
$lines | Set-Content $report
Get-Content $report
