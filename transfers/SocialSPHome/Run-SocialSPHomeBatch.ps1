#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = 'C:\SocialSPHomeRun'
$runtime = 'C:\Program Files\motif debug\16\Bin'
$sth = Join-Path $runtime 'sth.exe'
$dll = 'C:\SsaChromeValidation\compiler\bin\MS.Internal.Test.Automation.Office.Osg.Wss.Tests.dll'
$scenarioRoot = Join-Path $root 'scenarios'
$resultsRoot = Join-Path $root 'results'
$depotRoot = Join-Path $root 'depot'
$exporter = Join-Path $root 'Export-OtsOtl.ps1'
$timeoutMilliseconds = 120000
$computerName = $env:COMPUTERNAME
$contentUrl = 'http://' + $computerName
$adminUrl = 'http://' + $computerName + ':8080'

foreach ($path in @($sth, $dll, $scenarioRoot, $exporter)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required batch input missing: $path" }
}

Get-Process -Name sth,wttsth,chrome,chromedriver,robocopy,tc,oaclient,TestMonitor,CLRTestHost -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $resultsRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null

$depotTsd = Join-Path $root 'depot.tsd'
$topologyTsd = Join-Path $root 'topology.tsd'
$escapedRoot = [Security.SecurityElement]::Escape($depotRoot)
$escapedMachine = [Security.SecurityElement]::Escape($computerName)
$escapedContentUrl = [Security.SecurityElement]::Escape($contentUrl)
$depotXml = @"
<?xml version="1.0"?>
<TestData Version="2.1" xmlns="http://motifschemas/SCNSchema"><DataProviders><DataProvider AssemblyQualifiedName="MS.Internal.Motif.Providers.FileDepotStoresDataProvider, Motif.Providers"><FileDepotStores Version="1.0"><Depot Name="builttestcasefiles"><DepotStores><DepotStore AssemblyQualifiedName="MS.Internal.Motif.FileDepot.FileSystemDepotStore, Motif" CacheLocally="False" Priority="0" Version="1.0"><FileSystemDepotStore><Root>$escapedRoot\builttestcasefiles</Root></FileSystemDepotStore></DepotStore></DepotStores></Depot><Depot Name="packages"><DepotStores><DepotStore AssemblyQualifiedName="MS.Internal.Motif.FileDepot.FileSystemDepotStore, Motif" CacheLocally="False" Priority="0" Version="1.0"><FileSystemDepotStore><Root>$escapedRoot\packages</Root></FileSystemDepotStore></DepotStore></DepotStores></Depot></FileDepotStores></DataProvider></DataProviders></TestData>
"@
$topologyXml = @"
<?xml version="1.0" encoding="utf-8"?>
<TestData Version="2.0"><DataProviders><DataProvider AssemblyQualifiedName="MS.Internal.Motif.TopologyData.TopologyDataProvider, Motif"><TopologyData><TopologyDataSurrogate><MapEntries><MapEntry><Machine>$escapedMachine</Machine><Type>[WFE]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Master]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Search]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Index]{1}</Type></MapEntry><MapEntry><Machine>$escapedMachine</Machine><Type>[Job]{1}</Type></MapEntry></MapEntries></TopologyDataSurrogate></TopologyData></DataProvider><DataProvider AssemblyQualifiedName="MS.Internal.Motif.Context.XmlContext, Motif" Version="2.2"><Context><Nodes><Node Name="EXECUTION"><Nodes><Node Name="TEST"><Nodes><Node Name="MACHINES"><Nodes><Node Name="[WFE]{1}"><Nodes><Node Name="CONFIGDATA"><Nodes><Node Name="COMPONENTS"><Nodes><Node Name="SHAREPOINT"><Values><Value Name="SHAREPOINTURL" TypeName="System.String"><string>$escapedContentUrl</string></Value></Values></Node></Nodes></Node></Nodes></Node></Nodes></Node></Nodes></Node></Nodes></Node></Nodes></Node></Nodes></Context></DataProvider></DataProviders></TestData>
"@
[IO.File]::WriteAllText($depotTsd, $depotXml, (New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText($topologyTsd, $topologyXml, (New-Object Text.UTF8Encoding($false)))

$overrides = @{
    RootSiteUrl = $contentUrl
    ContentSiteUrl = $contentUrl
    TargetSiteUrl = $contentUrl
    CentralAdminUrl = $adminUrl
    TargetAdminUrl = $adminUrl
}
foreach ($name in $overrides.Keys) { [Environment]::SetEnvironmentVariable($name, $overrides[$name], 'Process') }
$env:DUAL_MODE_OVERRIDE_MEMBERS = ($overrides.Keys -join ';')
$env:GIT_ENV = '1'

$rows = New-Object Collections.Generic.List[object]
$scenarios = @(Get-ChildItem -LiteralPath $scenarioRoot -File -Filter '*.scn' | Sort-Object Name)
foreach ($sourceScenario in $scenarios) {
    $name = $sourceScenario.BaseName
    $group = if ($name.StartsWith('SPHome_', [StringComparison]::OrdinalIgnoreCase)) { 'SPHome' } else { 'Social' }
    $caseRoot = Join-Path $resultsRoot $name
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $scenario = Join-Path $caseRoot ($name + '.scn')
    Copy-Item -LiteralPath $sourceScenario.FullName -Destination $scenario -Force
    [xml]$scenarioXml = Get-Content -LiteralPath $scenario -Raw
    foreach ($assembly in @($scenarioXml.SelectNodes("//*[local-name()='Assembly']"))) { $assembly.InnerText = $dll }
    $scenarioXml.Save($scenario)

    $runtimeResults = Join-Path $runtime 'Results.log'
    Remove-Item -LiteralPath $runtimeResults, (Join-Path $runtime 'Results.wrn') -Force -ErrorAction SilentlyContinue
    $stdout = Join-Path $caseRoot 'sth.stdout.log'
    $stderr = Join-Path $caseRoot 'sth.stderr.log'
    $started = Get-Date
    $arguments = @('run', '-n', '-b', 'debug', '-ep', 'x64', $scenario, $depotTsd, $topologyTsd)
    $process = Start-Process -FilePath $sth -ArgumentList $arguments -WorkingDirectory $runtime -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $timedOut = -not $process.WaitForExit($timeoutMilliseconds)
    if ($timedOut) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F 2>$null | Out-Null
        Get-Process -Name sth,wttsth,chrome,chromedriver -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    $durationSeconds = [Math]::Round(((Get-Date) - $started).TotalSeconds, 2)
    $processExitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    $archivedResults = Join-Path $caseRoot 'Results.log'
    if (Test-Path -LiteralPath $runtimeResults) {
        Copy-Item -LiteralPath $runtimeResults -Destination $archivedResults -Force
    } else {
        Set-Content -LiteralPath $archivedResults -Value 'No Results.log was produced.'
    }
    $markers = @(Select-String -LiteralPath $archivedResults -Pattern '(?i)TESTS\s+(PASSED|FAILED)\s*$' -ErrorAction SilentlyContinue)
    $marker = if ($markers.Count) { $markers[-1].Matches[0].Value.ToUpperInvariant() } else { '' }
    $outcome = if ($timedOut) { 'TIMEOUT' } elseif ($marker -match 'PASSED') { 'PASS' } else { 'FAIL' }
    $otl = Join-Path $caseRoot ($name + '.otl')
    & $exporter -SourcePath $archivedResults -DestinationPath $otl -ExitCode $(if ($outcome -eq 'PASS') { 0 } else { 1 }) -Title ($group + '/' + $name) -ProcessName 'sth.exe'
    $rows.Add([pscustomobject]@{
        Group = $group
        Scenario = $name
        Outcome = $outcome
        DurationSeconds = $durationSeconds
        TimedOut = $timedOut
        ProcessExitCode = $processExitCode
        Marker = $marker
        OtlPath = $otl
        ResultsLog = $archivedResults
    })
    Write-Host ("{0}/{1}: {2} in {3}s" -f $group, $name, $outcome, $durationSeconds)
}

$summary = Join-Path $root 'summary.csv'
$rows | Export-Csv -LiteralPath $summary -NoTypeInformation -Encoding UTF8
$otlFolder = Join-Path $root 'otl'
Remove-Item -LiteralPath $otlFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $otlFolder -Force | Out-Null
foreach ($row in $rows) { Copy-Item -LiteralPath $row.OtlPath -Destination (Join-Path $otlFolder ([IO.Path]::GetFileName($row.OtlPath))) -Force }
$zip = Join-Path $root 'Social-SPHome-OTL.zip'
Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $otlFolder '*'), $summary -DestinationPath $zip -CompressionLevel Optimal
$counts = $rows | Group-Object Outcome | ForEach-Object { [pscustomobject]@{ Outcome=$_.Name; Count=$_.Count } }
$counts | Format-Table -AutoSize
Write-Host "SUMMARY=$summary"
Write-Host "OTL_FOLDER=$otlFolder"
Write-Host "ZIP=$zip"
