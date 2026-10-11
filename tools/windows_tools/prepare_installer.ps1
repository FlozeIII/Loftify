param(
    [Parameter(Mandatory)][string]$PortableDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$metadata = Get-Content -LiteralPath (Join-Path $PortableDirectory 'DISTRIBUTION.json') -Raw | ConvertFrom-Json
$provenance = Get-Content -LiteralPath (Join-Path $PortableDirectory 'BUILD-PROVENANCE.json') -Raw | ConvertFrom-Json
if ($metadata.schemaVersion -ne 1 -or $metadata.applicationId -ne 'io.github.flozeiii.loftify.community' -or $metadata.kind -ne 'portable' -or $metadata.platform -ne 'windows' -or $metadata.architecture -ne 'x86_64' -or $metadata.sourceCommit -notmatch '^[0-9a-fA-F]{40}$' -or $metadata.sourceCommit -ne $provenance.sourceCommit -or $metadata.version -ne $provenance.version -or $metadata.version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw 'Installer requires a matching Community portable build and provenance'
}
if (Test-Path -LiteralPath $OutputDirectory) {
    throw 'Installer staging already exists; use a fresh output directory'
}
foreach ($file in @('LoftifyCommunity.exe', 'sqlite3.dll', 'flutter_windows.dll', 'data/icudtl.dat', 'data/app.so')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PortableDirectory $file) -PathType Leaf)) {
        throw "Installer build is missing $file"
    }
}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
Copy-Item -Path (Join-Path $PortableDirectory '*') -Destination $OutputDirectory -Recurse
$metadata.kind = 'installed'
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'DISTRIBUTION.json') -Encoding utf8
(Resolve-Path -LiteralPath $OutputDirectory).Path
