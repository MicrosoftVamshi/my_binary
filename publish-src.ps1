$ErrorActionPreference = 'Stop'

# Publishes the FULL source tree once so the VM can build. Run publish.ps1 for fast
# per-iteration updates that only carry the Local_Search sources and scripts.

$root = 'C:\Users\v-vemmadi\Music\search_drop'
$password = 'Srch!Drop#2026-0804$kQ9wR'
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
$stage = Join-Path $root '_stage'

Remove-Item (Join-Path $stage 'WssTestsDllPortable') -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item 'C:\Users\v-vemmadi\Music\WssTestsDllPortable' (Join-Path $stage 'WssTestsDllPortable') -Recurse -Force

$package = Join-Path $root 'pkg\pkg_src.7z'
Remove-Item $package -Force -ErrorAction SilentlyContinue
& $sevenZip a -t7z -mhe=on -mx=5 "-p$password" $package (Join-Path $stage '*') | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z failed with exit code $LASTEXITCODE" }

Set-Location $root
git add -A
git commit -q -m "Publish Local_Search source drop

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push -q origin local_search

$item = Get-Item $package
Write-Output ("published pkg_src.7z size={0:N1} MB" -f ($item.Length / 1MB))
git --no-pager log --oneline -1
