; Community installer. Upstream AppId BED24EC1-0C45-4AED-94C7-69F3A620CFCD is never used here.
#define MyAppName "Loftify Community"
#define MyAppExeName "LoftifyCommunity.exe"
#define MyAppPublisher "FlozeIII"
#define MyAppURL "https://github.com/FlozeIII/Loftify"
#ifndef MyAppVersion
  #error MyAppVersion must be supplied by the build
#endif
#ifndef SourceDir
  #error SourceDir must refer to the installed distribution staging directory
#endif
#ifndef PackageOutputDir
  #error PackageOutputDir must be supplied by the build
#endif

[Setup]
AppId={{DC4EB2B7-7325-40AC-A9E1-FA2F26F77F14}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
VersionInfoProductName={#MyAppName}
VersionInfoDescription=Loftify Community Setup
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.22000
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir={#PackageOutputDir}
OutputBaseFilename=Loftify-Community-{#MyAppVersion}-windows-x86_64-setup
SetupIconFile=..\..\assets\logo-transparent-big.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=LoftifyCommunity.exe
RestartApplications=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\FlozeIII\Loftify Community"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\FlozeIII\Loftify Community"; ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\App Paths\{#MyAppExeName}"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\loftify-community"; ValueType: string; ValueName: ""; ValueData: "URL:Loftify Community"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\loftify-community"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\loftify-community\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if FileExists(ExpandConstant('{app}\Loftify.exe')) then
    Result := 'This directory contains Loftify. Choose a separate directory for Loftify Community.';
end;

function CommandExecutable(Command: String): String;
var
  Separator: Integer;
begin
  Command := Trim(Command);
  Result := '';
  if Copy(Command, 1, 1) = '"' then begin
    Delete(Command, 1, 1);
    Separator := Pos('"', Command);
    if Separator > 0 then Result := Copy(Command, 1, Separator - 1);
  end else begin
    Separator := Pos(' ', Command);
    if Separator = 0 then Result := Command
    else Result := Copy(Command, 1, Separator - 1);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Command: String;
  Executable: String;
begin
  if CurUninstallStep = usUninstall then
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}', Command) then begin
      // launch_at_startup 0.3.1 also produced complete unquoted paths with
      // spaces when no arguments were supplied. Match that legacy form whole.
      if Lowercase(Trim(Command)) = Lowercase(ExpandConstant('{app}\{#MyAppExeName}')) then
        Executable := Trim(Command)
      else
        Executable := CommandExecutable(Command);
      if (Executable <> '') and
          (Lowercase(ExpandFileName(Executable)) = Lowercase(ExpandConstant('{app}\{#MyAppExeName}'))) then begin
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', '{#MyAppName}');
        RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', '{#MyAppName}');
      end;
    end;
end;

; No UninstallDelete section: settings, cookies, databases and user downloads are retained.
