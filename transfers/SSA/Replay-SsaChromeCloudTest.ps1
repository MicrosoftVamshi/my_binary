#requires -Version 2.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = 'C:\SsaChromeValidation'
$psinfo = 'C:\data\CHT\7c4c4287\UserLogs\a8c7267f\TestResults\TestConsoleExecutionLogs\SearchServiceApplication_2101.psinfo'
$scenario = Join-Path $root 'SearchServiceApplication.scn'
$context = 'C:\data\CHT\7c4c4287\JWD_a8c7267f\ststest\SearchServiceApplicationLeftNavCheck\context.xml'
$runId = 'SSAChrome_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$logDirectory = Join-Path 'C:\data\CHT\7c4c4287\Reruns' $runId
$report = Join-Path $root 'run-report.txt'

if (-not (Test-Path -LiteralPath $psinfo)) { throw "Required replay input missing: $psinfo" }
if (-not (Test-Path -LiteralPath $scenario)) { throw "Required replay input missing: $scenario" }
if (-not (Test-Path -LiteralPath $context)) { throw "Required replay input missing: $context" }
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

$section = ''
$environment = @{}
$startup = @{}
foreach ($line in (Get-Content -LiteralPath $psinfo)) {
    if ($line -match '^\[(?<section>[^]]+)\]$') {
        $section = $Matches.section
        continue
    }
    if ($line -notmatch '^(?<name>[^=]+)=(?<value>.*)$') { continue }
    if ($section -eq 'EnvironmentVariables') { $environment[$Matches.name] = $Matches.value }
    elseif ($section -eq 'Startup') { $startup[$Matches.name] = $Matches.value }
}

foreach ($name in @($environment.Keys)) {
    [Environment]::SetEnvironmentVariable([string]$name, [string]$environment[$name], 'Process')
}
[Environment]::SetEnvironmentVariable('LoggingDirectory', $logDirectory, 'Process')

$executable = [string]$startup.Executable
$arguments = [string]$startup.Arguments
$workingDirectory = [string]$startup.WorkingDirectory
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Recorded executable missing: $executable" }
if (-not (Test-Path -LiteralPath $workingDirectory -PathType Container)) { throw "Recorded working directory missing: $workingDirectory" }

$quotedScenario = '"' + $scenario + '"'
$arguments = [Regex]::Replace($arguments, '(?i)(^|\s)-t\s+("[^"]+"|\S+)', ('$1-t ' + $quotedScenario), 1)
$quotedContext = '"' + $context + '"'
$arguments = [Regex]::Replace($arguments, '(?i)(^|\s)-a\s+("[^"]+"|\S+)', ('$1-a ' + $quotedContext), 1)

$stdout = Join-Path $logDirectory 'tc.stdout.log'
$stderr = Join-Path $logDirectory 'tc.stderr.log'
$startInfo = New-Object Diagnostics.ProcessStartInfo
$startInfo.FileName = $executable
$startInfo.Arguments = $arguments
$startInfo.WorkingDirectory = $workingDirectory
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = New-Object Diagnostics.Process
$process.StartInfo = $startInfo
[void]$process.Start()
$outputText = $process.StandardOutput.ReadToEnd()
$errorText = $process.StandardError.ReadToEnd()
$process.WaitForExit()
$outputText | Set-Content $stdout
$errorText | Set-Content $stderr

$otls = @(Get-ChildItem $logDirectory -Recurse -File -Include *.otl -ErrorAction SilentlyContinue)
$resultsLogs = @(Get-ChildItem $logDirectory -Recurse -File -Include Results.log,*.Results.log -ErrorAction SilentlyContinue)
$evidence = @()
foreach ($path in @($resultsLogs | ForEach-Object { $_.FullName } | Where-Object { $_ })) {
    $evidence += @(Select-String -LiteralPath $path -Pattern 'TESTS PASSED|TESTS FAILED|PASS:|FAIL:' -ErrorAction SilentlyContinue | Select-Object -Last 80 | ForEach-Object { $_.Line })
}
foreach ($path in @($otls | ForEach-Object { $_.FullName } | Where-Object { $_ })) {
    $evidence += @(Select-String -LiteralPath $path -Pattern 'TESTS PASSED|TESTS FAILED|PASS:|FAIL:' -ErrorAction SilentlyContinue | Select-Object -Last 80 | ForEach-Object { $_.Line })
}
$stdoutTail = @(Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue | Select-Object -Last 40)
$stderrTail = @(Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue | Select-Object -Last 40)

$lines = @(
    "RUN_ID=$runId"
    "EXIT_CODE=$($process.ExitCode)"
    "LOG_DIRECTORY=$logDirectory"
    "EXECUTABLE=$executable"
    "ARGUMENTS=$arguments"
    "WORKING_DIRECTORY=$workingDirectory"
    "OTL_COUNT=$($otls.Count)"
    "RESULTS_LOG_COUNT=$($resultsLogs.Count)"
)
$lines += $otls | ForEach-Object { "OTL=$($_.FullName)" }
$lines += $resultsLogs | ForEach-Object { "RESULTS_LOG=$($_.FullName)" }
$lines += 'STDOUT_BEGIN'
$lines += $stdoutTail
$lines += 'STDOUT_END'
$lines += 'STDERR_BEGIN'
$lines += $stderrTail
$lines += 'STDERR_END'
$lines += 'EVIDENCE_BEGIN'
$lines += $evidence
$lines += 'EVIDENCE_END'
$lines | Set-Content $report
Get-Content $report
