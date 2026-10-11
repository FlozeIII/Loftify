param([string]$Compiler = 'C:/Program Files (x86)/Inno Setup 6/ISCC.exe')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw 'Inno Setup compiler is required for installer syntax validation'
}
$repository = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path $repository ('build/installer-syntax/' + [guid]::NewGuid())
$source = Join-Path $fixture 'source'
$output = Join-Path $fixture 'output'
New-Item -ItemType Directory -Path $source, $output | Out-Null
[IO.File]::WriteAllText((Join-Path $source 'syntax-fixture.txt'), 'Compiler-only fixture; not a distribution.')
& $Compiler '/DMyAppVersion=0.0.0' "/DSourceDir=$source" "/DPackageOutputDir=$output" "$PSScriptRoot/Loftify.iss" | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Community installer script failed to compile' }
Write-Output 'Community installer script compiled successfully'
