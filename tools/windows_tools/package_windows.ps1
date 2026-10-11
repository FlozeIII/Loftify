param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$SourceCommit,
    [Parameter(Mandatory)][string]$FlutterVersion,
    [string]$SourceDirectory = 'build/windows/x64/runner/Release',
    [string]$DllDirectory = 'tools/windows_dll',
    [string]$OutputDirectory = 'build/windows/outputs',
    [string]$Compiler = 'C:/Program Files (x86)/Inno Setup 6/ISCC.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw 'Inno Setup 6 compiler is required to produce both distribution forms'
}
$portable = & "$PSScriptRoot/package_portable.ps1" -Version $Version -SourceCommit $SourceCommit -FlutterVersion $FlutterVersion -SourceDirectory $SourceDirectory -DllDirectory $DllDirectory -OutputDirectory $OutputDirectory
$installerStage = & "$PSScriptRoot/prepare_installer.ps1" -PortableDirectory $portable.StageDirectory -OutputDirectory (Join-Path $OutputDirectory 'installer-stage')
$absoluteOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
$installerPath = Join-Path $absoluteOutput "Loftify-Community-$Version-windows-x86_64-setup.exe"
if (Test-Path -LiteralPath $installerPath) {
    throw 'Installer output already exists; use a fresh output directory'
}
& $Compiler "/DMyAppVersion=$Version" "/DSourceDir=$installerStage" "/DPackageOutputDir=$absoluteOutput" "$PSScriptRoot/Loftify.iss" | Out-Host
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw 'Community installer compilation failed'
}
$hash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$installerPath.sha256" -Value $hash -Encoding ascii
[PSCustomObject]@{ ZipPath = $portable.ZipPath; InstallerPath = $installerPath; ZipSha256 = $portable.Sha256; InstallerSha256 = $hash }
