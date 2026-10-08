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
