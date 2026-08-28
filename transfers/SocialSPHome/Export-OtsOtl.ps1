#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$DestinationPath,
    [Parameter(Mandatory)][int]$ExitCode,
    [string]$Title = 'Simple Local Test',
    [string]$ProcessName = 'sth.exe'
)

$ErrorActionPreference = 'Stop'
$settings = New-Object Xml.XmlWriterSettings
$settings.Encoding = New-Object Text.UTF8Encoding($false)
$settings.Indent = $true
$writer = $null
try {
    $writer = [Xml.XmlWriter]::Create([IO.Path]::GetFullPath($DestinationPath), $settings)
    $writer.WriteStartDocument()
    $writer.WriteStartElement('Log')
    $writer.WriteAttributeString('Generator', 'OTSLogging')
    $writer.WriteAttributeString('Version', '16.0.0.0')
    $machineId = [Guid]::NewGuid().ToString('N').Substring(0, 12)
    $writer.WriteStartElement('MID')
    $writer.WriteAttributeString('ID', $machineId)
    $writer.WriteAttributeString('ComputerName', $env:COMPUTERNAME)
    $writer.WriteAttributeString('OutOfDisk', '0')
    $writer.WriteEndElement()
    $writer.WriteStartElement('PID')
    $writer.WriteAttributeString('ID', [string]$PID)
    $writer.WriteAttributeString('Path', $ProcessName)
    $writer.WriteAttributeString('MID', $machineId)
    $writer.WriteEndElement()
    $writer.WriteStartElement('LID')
    $writer.WriteAttributeString('ID', '1')
    $writer.WriteAttributeString('Name', $Title)
    $writer.WriteAttributeString('Description', 'MOTIF Results.log')
    $writer.WriteAttributeString('PID', [string]$PID)
    $writer.WriteAttributeString('MID', $machineId)
    $writer.WriteEndElement()
    foreach ($line in [IO.File]::ReadLines([IO.Path]::GetFullPath($SourcePath))) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $entryType = if ($line -match '(?i)\bTESTS\s+FAILED\s*$' -or $line -match '(?i)\bFAIL:\s*(?:Error|Failed|Skipped)') {
            '2'
        } elseif ($line -match '(?i)\bTESTS\s+PASSED\s*$' -or $line -match '(?i)\bPASS(?:ED)?\s*[:\-]') {
            '1'
        } elseif ($line -match '(?i)\bWARNING\s*:') {
            '4'
        } elseif ($line -match '(?i)\b(?:ERROR|FATAL)\s*:') {
            '5'
        } else {
            '3'
        }
        $writer.WriteStartElement('E')
        $writer.WriteAttributeString('T', [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.ffffZ'))
        $writer.WriteAttributeString('N', $entryType)
        $writer.WriteAttributeString('C', ($line -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''))
        $writer.WriteAttributeString('I', '1')
        $writer.WriteEndElement()
    }
    $writer.WriteStartElement('E')
    $writer.WriteAttributeString('T', [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.ffffZ'))
    $writer.WriteAttributeString('N', $(if ($ExitCode -eq 0) { '1' } else { '2' }))
    $writer.WriteAttributeString('C', "$Title exit code $ExitCode")
    $writer.WriteAttributeString('I', '1')
    $writer.WriteEndElement()
    $writer.WriteEndElement()
    $writer.WriteEndDocument()
} finally {
    if ($writer) { $writer.Dispose() }
}
