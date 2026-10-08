param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$SourceCommit,
    [Parameter(Mandatory)][string]$FlutterVersion,
    [string]$SourceDirectory = 'build/windows/x64/runner/Release',
    [string]$DllDirectory = 'tools/windows_dll',
    [string]$OutputDirectory = 'build/windows/outputs'
)

$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$' -or $SourceCommit -notmatch '^[0-9a-fA-F]{40}$') {
    throw 'A semantic version and full source commit are required'
}
$requiredFiles = @('Loftify.exe', 'flutter_windows.dll', 'data/icudtl.dat', 'data/app.so')
foreach ($relative in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceDirectory $relative) -PathType Leaf)) {
        throw "Windows build is missing $relative"
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $SourceDirectory 'data/flutter_assets') -PathType Container)) {
    throw 'Windows build is missing data/flutter_assets'
}
if (-not (Test-Path -LiteralPath (Join-Path $DllDirectory 'sqlite3.dll') -PathType Leaf)) {
    throw 'sqlite3.dll is missing from the packaging dependencies'
}
Get-ChildItem -LiteralPath $DllDirectory -Filter '*.dll' -File |
    Copy-Item -Destination $SourceDirectory -Force

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$name = "Loftify-$Version-windows-x86_64"
$destination = Join-Path $OutputDirectory $name
$zipPath = Join-Path $OutputDirectory "$name.zip"
if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath $zipPath)) {
    throw 'Package output already exists; use a fresh output directory'
}
New-Item -ItemType Directory -Path $destination | Out-Null
Copy-Item -Path (Join-Path $SourceDirectory '*') -Destination $destination -Recurse
$provenancePath = Join-Path $destination 'BUILD-PROVENANCE.json'
$provenance = [ordered]@{
    schemaVersion = 1
    application = 'Loftify'
    version = $Version
    platform = 'windows'
    architecture = 'x86_64'
    sourceCommit = $SourceCommit
    flutterVersion = $FlutterVersion
}
$provenance | ConvertTo-Json | Set-Content -LiteralPath $provenancePath -Encoding utf8
Compress-Archive -LiteralPath $destination -DestinationPath $zipPath
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$zipPath.sha256" -Value $hash -Encoding ascii
[PSCustomObject]@{ ZipPath = $zipPath; Sha256 = $hash; ProvenancePath = $provenancePath }
