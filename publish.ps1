$ErrorActionPreference = 'Stop'

$root = 'C:\Users\v-vemmadi\Music\rbs_drop'
$sevenZip = 'C:\Program Files\7-Zip\7z.exe'
$iter = Join-Path $root '_iter'

# The archive password is never stored in the repository. It is read from the RBS_DROP_PASSWORD
# environment variable, or from .secret\pkg-password.txt, both of which are untracked.
# A previous revision hard-coded it here, which published it to a public repo and defeated the
# whole point of shipping an encrypted archive.
$secretFile = Join-Path $root '.secret\pkg-password.txt'
$password = $env:RBS_DROP_PASSWORD
if ([string]::IsNullOrWhiteSpace($password) -and (Test-Path $secretFile)) {
    $password = (Get-Content -LiteralPath $secretFile -Raw).Trim()
}
if ([string]::IsNullOrWhiteSpace($password)) {
    throw "No archive password. Set `$env:RBS_DROP_PASSWORD or create $secretFile (both untracked)."
}

Remove-Item $iter -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $iter 'WssTestsDllPortable\src\RBS') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $iter 'SCNS\rbs') | Out-Null
Copy-Item (Join-Path $root '_stage\scripts') (Join-Path $iter 'scripts') -Recurse -Force
Copy-Item 'C:\Users\v-vemmadi\Music\WssTestsDllPortable\src\RBS\RBS_Smoke.cs' (Join-Path $iter 'WssTestsDllPortable\src\RBS\RBS_Smoke.cs') -Force
Copy-Item 'C:\Users\v-vemmadi\Music\SCNS\rbs\*.scn' (Join-Path $iter 'SCNS\rbs') -Force

# Refresh.ps1 needs the password to re-extract on the VM. It is injected here, so the literal only
# ever exists inside the encrypted archive (and on the VM after extraction), never in git.
$refresh = Join-Path $iter 'scripts\Refresh.ps1'
if (Test-Path $refresh) {
    $text = Get-Content -LiteralPath $refresh -Raw
    $text = $text.Replace('__RBS_DROP_PASSWORD__', $password)
    Set-Content -LiteralPath $refresh -Value $text -Encoding UTF8 -NoNewline
}

$package = Join-Path $root 'pkg\pkg_run.7z'
Remove-Item $package -Force -ErrorAction SilentlyContinue
& $sevenZip a -t7z -mhe=on -mx=5 "-p$password" $package (Join-Path $iter '*') | Out-Null
if ($LASTEXITCODE -ne 0) { throw "7z failed with exit code $LASTEXITCODE" }

# _iter holds the plaintext payload that was just encrypted; do not leave it on disk.
Remove-Item $iter -Recurse -Force -ErrorAction SilentlyContinue

Set-Location $root

# Guard: refuse to commit if anything other than the encrypted package and tooling is staged.
$tracked = @(git ls-files)
$plaintext = $tracked | Where-Object { $_ -match '\.(cs|scn|dll)$' -and $_ -notlike 'tools/*' }
if ($plaintext.Count -gt 0) {
    throw "Refusing to publish: plaintext payload is tracked in git: $($plaintext -join ', ')"
}
$leak = @(Select-String -Path (Join-Path $root 'publish.ps1') -Pattern $password -SimpleMatch -ErrorAction SilentlyContinue)
if ($leak.Count -gt 0) {
    throw 'Refusing to publish: the archive password appears in a tracked file.'
}

git add -A
git commit -q -m "Update RBS smoke iteration package

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push -q origin rbs

$item = Get-Item $package
Write-Output "published pkg_run.7z size=$($item.Length)"
git --no-pager log --oneline -1
