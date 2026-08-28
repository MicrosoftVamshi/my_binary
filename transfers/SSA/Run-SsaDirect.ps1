#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = 'C:\SsaChromeValidation'
$runtime = 'C:\Program Files\motif debug\16\Bin'
$sth = Join-Path $runtime 'sth.exe'
$scenario = Join-Path $root 'SSAChromeRuntime.scn'
$dll = Join-Path $root 'compiler\bin\MS.Internal.Test.Automation.Office.Osg.Wss.Tests.dll'
$timeoutMilliseconds = 120000
$runId = 'SSAChromeDirect_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$logDirectory = Join-Path $root $runId
$depot = Join-Path $logDirectory 'depot.tsd'
$topology = Join-Path $logDirectory 'topology.tsd'
$stdout = Join-Path $logDirectory 'sth.stdout.log'
$stderr = Join-Path $logDirectory 'sth.stderr.log'
$report = Join-Path $root 'direct-run-report.txt'

function Stop-SsaProcesses {
    Get-Process -Name robocopy,tc,oaclient,TestMonitor,sth,wttsth,CLRTestHost,chrome,chromedriver -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

foreach ($path in @($sth, $scenario, $dll)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required direct-run input missing: $path" }
}

Stop-SsaProcesses
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
Remove-Item -LiteralPath (Join-Path $runtime 'Results.log'), (Join-Path $runtime 'Results.wrn') -Force -ErrorAction SilentlyContinue

[xml]$scenarioXml = Get-Content -LiteralPath $scenario -Raw
$assembly = $scenarioXml.SelectSingleNode("//*[local-name()='Assembly']")
if (-not $assembly) { throw 'SSA Assembly element was not found.' }
$assembly.InnerText = $dll
$scenarioXml.Save($scenario)

$escapedRoot = [Security.SecurityElement]::Escape($root)
$escapedMachine = [Security.SecurityElement]::Escape($env:COMPUTERNAME)
$depotXml = @"
<?xml version="1.0"?>
<TestData Version="2.1" xmlns="http://motifschemas/SCNSchema"><DataProviders><DataProvider AssemblyQualifiedName="MS.Internal.Motif.Providers.FileDepotStoresDataProvider, Motif.Providers"><FileDepotStores Version="1.0"><Depot Name="builttestcasefiles"><DepotStores><DepotStore AssemblyQualifiedName="MS.Internal.Motif.FileDepot.FileSystemDepotStore, Motif" CacheLocally="False" Priority="0" Version="1.0"><FileSystemDepotStore><Root>$escapedRoot</Root></FileSystemDepotStore></DepotStore></DepotStores></Depot></FileDepotStores></DataProvider></DataProviders></TestData>
"@
$topologyXml = @"
<?xml version="1.0" encoding="utf-8"?>
<TestData Version="2.0"><DataProviders><DataProvider AssemblyQualifiedName="MS.Internal.Motif.TopologyData.TopologyDataProvider, Motif"><TopologyData><TopologyDataSurrogate><MapEntries><MapEntry><Machine>$escapedMachine</Machine><Type>[WFE]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Master]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Search]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Index]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Job]{1}</Type></MapEntry></MapEntries></TopologyDataSurrogate></TopologyData></DataProvider></DataProviders></TestData>
"@
[IO.File]::WriteAllText($depot, $depotXml, (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($topology, $topologyXml, (New-Object Text.UTF8Encoding($false)))

$env:GIT_ENV = '1'
$env:LoggingDirectory = $logDirectory
$arguments = @('run', '-n', '-b', 'debug', '-ep', 'x64', $scenario, $depot, $topology)
$process = Start-Process -FilePath $sth -ArgumentList $arguments -WorkingDirectory $runtime -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$timedOut = -not $process.WaitForExit($timeoutMilliseconds)
if ($timedOut) {
    & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>$null | Out-Null
    Stop-SsaProcesses
}
$exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
$resultsLog = Join-Path $runtime 'Results.log'
$evidence = if (Test-Path $resultsLog) {
    @(Select-String -LiteralPath $resultsLog -Pattern 'PASS|FAIL|Chrome|Navigation checks complete' -ErrorAction SilentlyContinue |
        Select-Object -Last 100 | ForEach-Object { $_.Line })
} else { @() }
$lines = @(
    "RUN_ID=$runId"
    "EXIT_CODE=$exitCode"
    "TIMED_OUT=$timedOut"
    "TIMEOUT_SECONDS=$($timeoutMilliseconds / 1000)"
    "LOG_DIRECTORY=$logDirectory"
    "RESULTS_LOG=$resultsLog"
    'EVIDENCE_BEGIN'
) + $evidence + 'EVIDENCE_END'
$lines | Set-Content -LiteralPath $report
Get-Content -LiteralPath $report
