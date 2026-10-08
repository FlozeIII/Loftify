$ErrorActionPreference = 'Stop'
$repository = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path $repository ('build/package-tests/' + [guid]::NewGuid())
$source = Join-Path $fixture 'runner'
$dlls = Join-Path $fixture 'dlls'
$output = Join-Path $fixture 'output'
New-Item -ItemType Directory -Path "$source/data/flutter_assets", $dlls -Force | Out-Null
foreach ($relative in @('Loftify.exe', 'flutter_windows.dll', 'data/icudtl.dat', 'data/app.so')) {
    [IO.File]::WriteAllText((Join-Path $source $relative), "fixture: $relative")
}
[IO.File]::WriteAllText((Join-Path $dlls 'sqlite3.dll'), 'sqlite fixture')
$commit = '0123456789abcdef0123456789abcdef01234567'
$package = & "$PSScriptRoot/package_portable.ps1" -SourceDirectory $source -DllDirectory $dlls -OutputDirectory $output -Version '2.5.3' -SourceCommit $commit -FlutterVersion '3.41.5'

$zip = [IO.Compression.ZipFile]::OpenRead($package.ZipPath)
try {
    foreach ($relative in @('Loftify.exe', 'sqlite3.dll', 'flutter_windows.dll', 'data/icudtl.dat', 'data/app.so', 'BUILD-PROVENANCE.json')) {
        if (-not $zip.GetEntry("Loftify-2.5.3-windows-x86_64/$relative")) {
            throw "Package is missing $relative"
        }
    }
} finally {
    $zip.Dispose()
}
$provenance = Get-Content -LiteralPath $package.ProvenancePath -Raw | ConvertFrom-Json
if ($provenance.sourceCommit -ne $commit -or $provenance.flutterVersion -ne '3.41.5') {
    throw 'Package provenance does not describe the supplied build'
}
$expectedHash = (Get-FileHash -LiteralPath $package.ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ((Get-Content -LiteralPath "$($package.ZipPath).sha256" -Raw).Trim() -ne $expectedHash) {
    throw 'Published SHA256 does not match the ZIP'
}
Write-Output 'PASS: complete portable ZIP, source provenance and matching SHA256'

$emptyDlls = Join-Path $fixture 'empty-dlls'
New-Item -ItemType Directory -Path $emptyDlls | Out-Null
$missingDllOutput = Join-Path $fixture 'missing-dll-output'
$rejectedMissingDll = $false
try {
    & "$PSScriptRoot/package_portable.ps1" -SourceDirectory $source -DllDirectory $emptyDlls -OutputDirectory $missingDllOutput -Version '2.5.3' -SourceCommit $commit -FlutterVersion '3.41.5' | Out-Null
} catch {
    if ($_.Exception.Message -notlike '*sqlite3.dll*') { throw }
    $rejectedMissingDll = $true
}
if (-not $rejectedMissingDll -or (Test-Path -LiteralPath $missingDllOutput)) {
    throw 'Missing SQLite must fail without producing an output package'
}
Write-Output 'PASS: missing SQLite is rejected before packaging'

$rejectedStaleOutput = $false
try {
    & "$PSScriptRoot/package_portable.ps1" -SourceDirectory $source -DllDirectory $dlls -OutputDirectory $output -Version '2.5.3' -SourceCommit $commit -FlutterVersion '3.41.5' | Out-Null
} catch {
    if ($_.Exception.Message -notlike '*already exists*') { throw }
    $rejectedStaleOutput = $true
}
if (-not $rejectedStaleOutput -or (Get-FileHash -LiteralPath $package.ZipPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'An existing output package must be preserved rather than overwritten'
}
Write-Output 'PASS: existing output ZIP is rejected and preserved'

$zipOnlyOutput = Join-Path $fixture 'zip-only-output'
New-Item -ItemType Directory -Path $zipOnlyOutput | Out-Null
$existingZip = Join-Path $zipOnlyOutput 'Loftify-2.5.3-windows-x86_64.zip'
Copy-Item -LiteralPath $package.ZipPath -Destination $existingZip
$rejectedZipOnly = $false
try {
    & "$PSScriptRoot/package_portable.ps1" -SourceDirectory $source -DllDirectory $dlls -OutputDirectory $zipOnlyOutput -Version '2.5.3' -SourceCommit $commit -FlutterVersion '3.41.5' | Out-Null
} catch {
    if ($_.Exception.Message -notlike '*already exists*') { throw }
    $rejectedZipOnly = $true
}
if (-not $rejectedZipOnly -or (Test-Path -LiteralPath (Join-Path $zipOnlyOutput 'Loftify-2.5.3-windows-x86_64')) -or (Get-FileHash -LiteralPath $existingZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'A ZIP-only collision must preserve the ZIP without creating a staging directory'
}
Write-Output 'PASS: ZIP-only collision is rejected without staging or overwrite'
