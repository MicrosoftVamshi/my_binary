$ErrorActionPreference = 'Stop'

# Fast per-iteration publish: carries only the Local_Search sources and the VM scripts.
# The VM already has the full tree from publish-src.ps1, so this stays a few KB.

$root = 'C:\Users\v-vemmadi\Music\search_drop'
$password = 'Srch!Drop#2026-0804$kQ9wR'
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
if (-not (Test-Path $sevenZip)) {
	$sevenZip = Join-Path $root 'tools\7z.exe'
}
$iter = Join-Path $root '_iter'
$localSearch = Join-Path $iter 'WssTestsDllPortable\src\Local_Search'
$spqa = Join-Path $iter 'WssTestsDllPortable\src\SPQA\DriverMethods'
$manifest = Join-Path $iter 'WssTestsDllPortable\manifest'
$scnDir = Join-Path $iter 'SCNS\local_search'

Remove-Item $iter -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $localSearch, $spqa, $manifest, $scnDir | Out-Null

Copy-Item (Join-Path $root '_stage\scripts') (Join-Path $iter 'scripts') -Recurse -Force
Copy-Item 'C:\Users\v-vemmadi\Music\WssTestsDllPortable\src\Local_Search\*.cs' $localSearch -Force
Copy-Item 'C:\Users\v-vemmadi\Music\WssTestsDllPortable\manifest\sources.txt' $manifest -Force
Copy-Item 'C:\Users\v-vemmadi\Music\WssTestsDllPortable\src\Local_Search\SearchServiceApplication.scn' $scnDir -Force
# SPQA ships in the same push as Local_Search and the test consumes it directly, so an iteration
# that changed Locator/MotifDriver must carry them or the VM builds the old driver helpers.
Copy-Item 'C:\Users\v-vemmadi\Music\WssTestsDllPortable\src\SPQA\DriverMethods\*.cs' $spqa -Force

$package = Join-Path $root 'pkg\pkg_run.7z'
Remove-Item $package -Force -ErrorAction SilentlyContinue
& $sevenZip a -t7z -mhe=on -mx=5 "-p$password" $package (Join-Path $iter '*') | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z failed with exit code $LASTEXITCODE" }

Set-Location $root
git add -A
git commit -q -m "Update Local_Search iteration package

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push -q origin local_search

$item = Get-Item $package
Write-Output "published pkg_run.7z size=$($item.Length)"
git --no-pager log --oneline -1
