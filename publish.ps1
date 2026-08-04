$ErrorActionPreference = 'Stop'

$root = 'C:\Users\v-vemmadi\Music\rbs_drop'
$password = 'Rbs!Drop#2026-0804$vX7qP'
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
$iter = Join-Path $root '_iter'

Remove-Item $iter -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $iter 'WssTestsDllPortable\src\RBS') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $iter 'SCNS\rbs') | Out-Null
Copy-Item (Join-Path $root '_stage\scripts') (Join-Path $iter 'scripts') -Recurse -Force
Copy-Item 'C:\Users\v-vemmadi\Music\WssTestsDllPortable\src\RBS\RBS_Smoke.cs' (Join-Path $iter 'WssTestsDllPortable\src\RBS\RBS_Smoke.cs') -Force
Copy-Item 'C:\Users\v-vemmadi\Music\SCNS\rbs\*.scn' (Join-Path $iter 'SCNS\rbs') -Force

$package = Join-Path $root 'pkg\pkg_run.7z'
Remove-Item $package -Force -ErrorAction SilentlyContinue
& $sevenZip a -t7z -mhe=on -mx=5 "-p$password" $package (Join-Path $iter '*') | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z failed with exit code $LASTEXITCODE" }

Set-Location $root
git add -A
git commit -q -m "Update RBS smoke iteration package

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push -q origin rbs

$item = Get-Item $package
Write-Output "published pkg_run.7z size=$($item.Length)"
git --no-pager log --oneline -1
