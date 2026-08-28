[CmdletBinding()]
param(
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$root = $PSScriptRoot
$sourceRoot = Join-Path $root 'src'
$sourceManifest = Join-Path $root 'manifest\sources-ssa.txt'
$referenceManifest = Join-Path $root 'manifest\references.txt'
$compiler = Join-Path $root 'tools\roslyn\csc.exe'
$signingKey = Join-Path $root 'keys\MotifTest.snk'
$jwtReference = Join-Path $root 'refs\JWT-System.IdentityModel.Tokens.Jwt.dll'
$enterpriseServicesWrapper = Join-Path $root 'refs\System.EnterpriseServices.Wrapper.dll'
$dependencyManifest = Join-Path $root 'resources\DependencyManifest.bid'
$formsSchema = Join-Path $root 'resources\FormsCustomization\schema.xml'
$formsFeature = Join-Path $root 'resources\FormsCustomization\feature.xml'
$formsListTemplate = Join-Path $root 'resources\FormsCustomization\listtemplate.xml'
$outputRoot = Join-Path $root 'bin'
$intermediateRoot = Join-Path $root 'obj'
$assemblyName = 'MS.Internal.Test.Automation.Office.Osg.Wss.Tests'

foreach ($requiredPath in @(
    $sourceRoot,
    $sourceManifest,
    $referenceManifest,
    $compiler,
    $signingKey,
    $jwtReference,
    $enterpriseServicesWrapper,
    $dependencyManifest,
    $formsSchema,
    $formsFeature,
    $formsListTemplate
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Portable build payload is incomplete: $requiredPath"
    }
}

if ($Clean) {
    Remove-Item -LiteralPath $outputRoot, $intermediateRoot -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $outputRoot, $intermediateRoot -Force | Out-Null

$sources = @(
    Get-Content -LiteralPath $sourceManifest |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Get-Item -LiteralPath (Join-Path $sourceRoot $_) }
)
$references = @(
    Get-Content -LiteralPath $referenceManifest |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Join-Path $root $_ }
)

if ($sources.Count -eq 0) {
    throw "No C# sources were found under $sourceRoot"
}

$missingReferences = @($references | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missingReferences.Count -gt 0) {
    throw "Missing staged reference(s):`n$($missingReferences -join "`n")"
}

$outputAssembly = Join-Path $outputRoot "$assemblyName.dll"
$outputPdb = Join-Path $outputRoot "$assemblyName.pdb"
$responseFile = Join-Path $intermediateRoot 'compile.rsp'

$arguments = @(
    '/nostdlib+'
    '/target:library'
    '/platform:x64'
    '/unsafe+'
    '/debug:full'
    '/optimize-'
    '/deterministic+'
    '/highentropyva+'
    '/checksumalgorithm:SHA256'
    '/langversion:latest'
    '/define:DEBUG;PLATFORM_X64;PLATFORM_x64;DOT_NET_IDENTITY'
    '/nowarn:0612,0618,1607,1685'
    '/delaysign-'
    "/keyfile:`"$signingKey`""
    "/resource:`"$dependencyManifest`""
    "/resource:`"$formsSchema`",FORMSLISTSCHEMAXML"
    "/resource:`"$formsFeature`",FORMSFEATUREXML"
    "/resource:`"$formsListTemplate`",FORMSLISTTEMPLATEXML"
    "/out:`"$outputAssembly`""
    "/pdb:`"$outputPdb`""
)

$arguments += $references | ForEach-Object { "/reference:`"$_`"" }
$arguments += "/reference:JWT=`"$jwtReference`""
$arguments += $sources | ForEach-Object { "`"$($_.FullName)`"" }
Set-Content -LiteralPath $responseFile -Value $arguments -Encoding UTF8

Write-Host "Compiling $($sources.Count) source files with $($references.Count + 1) references..."
& $compiler '/noconfig' "@$responseFile"
if ($LASTEXITCODE -ne 0) {
    throw "C# compiler failed with exit code $LASTEXITCODE"
}

$assembly = [Reflection.AssemblyName]::GetAssemblyName($outputAssembly)
$hash = (Get-FileHash -LiteralPath $outputAssembly -Algorithm SHA256).Hash
Write-Host "Built: $outputAssembly"
Write-Host "Identity: $($assembly.FullName)"
Write-Host "SHA256: $hash"