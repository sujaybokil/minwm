#define MyAppName "minwm"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#define MyAppPublisher "Sujay Bokil"
#define MyAppURL "https://github.com/sujaybokil/minwm"
#define MyTaskName "minwm"

[Setup]
AppId={{E6983B8A-4961-4CB1-BDF3-0E3379B1A65C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={localappdata}\minwm
DefaultGroupName=minwm
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\dist
OutputBaseFilename=minwm-setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
LicenseFile=..\LICENSE
UninstallDisplayIcon={app}\assets\minwm.ico

[Files]
Source: "..\minwm.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\config.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\config\config.toml"; DestDir: "{app}\config"; Flags: onlyifdoesntexist
Source: "..\lib\*.ahk"; DestDir: "{app}\lib"; Flags: ignoreversion
Source: "..\dependencies\virtualdesktop\VirtualDesktop11.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Tasks: virtualdesktophelper
Source: "..\dependencies\virtualdesktop\VirtualDesktop11-24H2.exe"; DestDir: "{app}\bin"; Flags: ignoreversion; Tasks: virtualdesktophelper
Source: "..\licenses\LICENSE-VirtualDesktop.txt"; DestDir: "{app}\licenses"; Flags: ignoreversion; Tasks: virtualdesktophelper
Source: "..\assets\minwm.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "startatlogon"; Description: "Start minwm automatically when I log on"; GroupDescription: "Startup:"
Name: "virtualdesktophelper"; Description: "Install direct virtual-desktop switching (recommended: no intermediate animations)"; GroupDescription: "Virtual desktops:"; Flags: checkablealone

[Icons]
Name: "{autoprograms}\minwm"; Filename: "{code:GetAutoHotkeyPath}"; Parameters: """{app}\minwm.ahk"""; WorkingDir: "{app}"; IconFilename: "{app}\assets\minwm.ico"

[Run]
Filename: "{code:GetAutoHotkeyPath}"; Parameters: """{app}\minwm.ahk"""; WorkingDir: "{app}"; Description: "Launch minwm now"; Flags: nowait postinstall skipifsilent

[InstallDelete]
; Remove obsolete files from development installers which bundled AutoHotkey.
; Current installers always use the user's installed runtime.
Type: files; Name: "{app}\AutoHotkey64.exe"
Type: files; Name: "{app}\licenses\LICENSE-AutoHotkey.txt"

[UninstallRun]
Filename: "{sys}\schtasks.exe"; Parameters: "/delete /tn ""{#MyTaskName}"" /f"; Flags: runhidden; RunOnceId: "DeleteMinwmLogonTask"

[UninstallDelete]
Type: files; Name: "{userstartup}\minwm.lnk"
Type: filesandordirs; Name: "{app}"

[Code]
var
  AutoHotkeyPath: String;

function TryAutoHotkeyInDirectory(InstallDir: String): Boolean;
var
  Candidate: String;
begin
  Result := False;
  if InstallDir = '' then
    exit;

  Candidate := AddBackslash(InstallDir) + 'AutoHotkey.exe';
  if FileExists(Candidate) then
  begin
    AutoHotkeyPath := Candidate;
    Result := True;
    exit;
  end;

  Candidate := AddBackslash(InstallDir) + 'v2\AutoHotkey64.exe';
  if FileExists(Candidate) then
  begin
    AutoHotkeyPath := Candidate;
    Result := True;
    exit;
  end;

  Candidate := AddBackslash(InstallDir) + 'AutoHotkey64.exe';
  if FileExists(Candidate) then
  begin
    AutoHotkeyPath := Candidate;
    Result := True;
  end;
end;

function FindAutoHotkey(): Boolean;
var
  InstallDir: String;
begin
  Result := False;
  if TryAutoHotkeyInDirectory(
    AddBackslash(GetEnv('USERPROFILE')) + 'scoop\apps\autohotkey\current') then
  begin
    Result := True;
    exit;
  end;
  if RegQueryStringValue(HKCU, 'Software\AutoHotkey', 'InstallDir', InstallDir) and
    TryAutoHotkeyInDirectory(InstallDir) then
  begin
    Result := True;
    exit;
  end;
  if RegQueryStringValue(HKLM, 'Software\AutoHotkey', 'InstallDir', InstallDir) and
    TryAutoHotkeyInDirectory(InstallDir) then
  begin
    Result := True;
    exit;
  end;

  Result :=
    TryAutoHotkeyInDirectory(ExpandConstant('{localappdata}\Programs\AutoHotkey')) or
    TryAutoHotkeyInDirectory(ExpandConstant('{pf}\AutoHotkey'));
end;

function GetAutoHotkeyPath(Param: String): String;
begin
  Result := AutoHotkeyPath;
end;

function InitializeSetup(): Boolean;
begin
  Result := FindAutoHotkey();
  if not Result and not WizardSilent then
    MsgBox(
      'minwm requires AutoHotkey v2, but setup could not find an installed copy.' + #13#10 + #13#10 +
      'Install AutoHotkey v2 from https://www.autohotkey.com/ and run setup again.',
      mbError, MB_OK);
end;

procedure MigrateConfigurationDirectory();
var
  LegacyConfigPath: String;
  ConfigDirectory: String;
  ConfigPath: String;
begin
  LegacyConfigPath := ExpandConstant('{app}\config.toml');
  ConfigDirectory := ExpandConstant('{app}\config');
  ConfigPath := AddBackslash(ConfigDirectory) + 'config.toml';
  if FileExists(ConfigPath) or not FileExists(LegacyConfigPath) then
    exit;
  if not ForceDirectories(ConfigDirectory) then
  begin
    Log('Could not create the minwm configuration directory for migration.');
    exit;
  end;
  if RenameFile(LegacyConfigPath, ConfigPath) then
    Log('Migrated config.toml into the configuration directory.')
  else
    Log('Could not migrate the existing config.toml into the configuration directory.');
end;

procedure EnsureOptionalConfig();
var
  ConfigPath: String;
  Contents: AnsiString;
  Addition: AnsiString;
begin
  ConfigPath := ExpandConstant('{app}\config\config.toml');
  if not LoadStringFromFile(ConfigPath, Contents) then
    exit;

  Addition := '';
  if Pos('focusBorderWidth', Contents) = 0 then
    Addition := Addition + 'focusBorderWidth = 1' + #13#10;
  if Pos('focusBorderColor', Contents) = 0 then
    Addition := Addition + 'focusBorderColor = "FFFFFF"' + #13#10;
  if Pos('defaultLayout', Contents) = 0 then
    Addition := Addition + 'defaultLayout = "vertical"' + #13#10;
  if Pos('virtualDesktopsEnabled', Contents) = 0 then
    Addition := Addition + 'virtualDesktopsEnabled = true' + #13#10;
  if Addition = '' then
    exit;

  Log('Adding new optional settings to the preserved config.toml.');
  SaveStringToFile(ConfigPath,
    Chr(13) + Chr(10) +
    '# Optional focus-border settings.' + #13#10 +
    Addition, True);
end;

procedure MigrateDefaultHotkeys();
var
  ConfigPath: String;
  Contents: AnsiString;
  MatchPosition: Integer;
  Changed: Boolean;
  OldBinding: AnsiString;
  NewBinding: AnsiString;
begin
  ConfigPath := ExpandConstant('{app}\config\config.toml');
  if not LoadStringFromFile(ConfigPath, Contents) then
    exit;
  Changed := False;

  OldBinding := 'swapMaster = "#Enter"';
  NewBinding := 'swapMaster = "#m"';
  MatchPosition := Pos(OldBinding, Contents);
  if MatchPosition <> 0 then
  begin
    Delete(Contents, MatchPosition, Length(OldBinding));
    Insert(NewBinding, Contents, MatchPosition);
    Log('Migrating the unchanged promote-to-master hotkey from Win+Enter to Win+M.');
    Changed := True;
  end;

  OldBinding := 'showHotkeys = "#i"';
  NewBinding := 'showHotkeys = "#h"';
  MatchPosition := Pos(OldBinding, Contents);
  if MatchPosition <> 0 then
  begin
    Delete(Contents, MatchPosition, Length(OldBinding));
    Insert(NewBinding, Contents, MatchPosition);
    Log('Migrating the unchanged hotkey-reference binding from Win+I to Win+H.');
    Changed := True;
  end;
  if Changed then
    SaveStringToFile(ConfigPath, Contents, False);
end;

function CreateMinwmLogonTask(): Boolean;
var
  ResultCode: Integer;
  Parameters: String;
  ElevatedParameters: String;
  UserName: String;
begin
  Log('Creating the minwm user logon task.');
  Parameters := '/create /tn "{#MyTaskName}" /tr """' +
    AutoHotkeyPath + '"" ""' +
    ExpandConstant('{app}\minwm.ahk') + '""" /sc ONLOGON /rl LIMITED /delay 0000:05 /it /f';
  Result := Exec(ExpandConstant('{sys}\schtasks.exe'), Parameters,
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  if Result then
  begin
    Log('Created the minwm user logon task.');
    exit;
  end;

  Log(Format('User-level minwm logon-task creation failed (exit code %d).', [ResultCode]));
  if WizardSilent then
    exit;
  if MsgBox('Windows denied creation of the minwm logon task. Allow an administrator prompt to retry?',
    mbConfirmation, MB_YESNO) <> IDYES then
    exit;

  UserName := GetEnv('USERNAME');
  if GetEnv('USERDOMAIN') <> '' then
    UserName := GetEnv('USERDOMAIN') + '\' + UserName;
  ElevatedParameters := '/create /tn "{#MyTaskName}" /tr """' +
    AutoHotkeyPath + '"" ""' +
    ExpandConstant('{app}\minwm.ahk') + '""" /sc ONLOGON /ru "' +
    UserName + '" /rl LIMITED /delay 0000:05 /it /f';
  Result := ShellExec('runas', ExpandConstant('{sys}\schtasks.exe'), ElevatedParameters,
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  if Result then
    Log('Created the minwm user logon task after elevation.')
  else
    Log(Format('Elevated minwm logon-task creation failed (exit code %d).', [ResultCode]));
end;

function MinwmLogonTaskExists(): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(ExpandConstant('{sys}\schtasks.exe'), '/query /tn "{#MyTaskName}"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

procedure CreateStartupFallback();
begin
  Log('Creating the minwm Startup-folder fallback shortcut.');
  CreateShellLink(ExpandConstant('{userstartup}\minwm.lnk'),
    'Start minwm at logon', AutoHotkeyPath,
    '"' + ExpandConstant('{app}\minwm.ahk') + '"', ExpandConstant('{app}'),
    ExpandConstant('{app}\assets\minwm.ico'), 0, SW_SHOWNORMAL);
end;

procedure RemoveMinwmLogonTask();
var
  ResultCode: Integer;
begin
  if MinwmLogonTaskExists() then
  begin
    Log('Removing the existing minwm logon task because startup at logon was not selected.');
    Exec(ExpandConstant('{sys}\schtasks.exe'), '/delete /tn "{#MyTaskName}" /f',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    MigrateConfigurationDirectory();
    Log('Removing an existing minwm Startup-folder fallback before replacement.');
    DeleteFile(ExpandConstant('{userstartup}\minwm.lnk'));
    if not WizardIsTaskSelected('virtualdesktophelper') then
    begin
      Log('Removing the optional VirtualDesktop helper because it was not selected.');
      DeleteFile(ExpandConstant('{app}\bin\VirtualDesktop11.exe'));
      DeleteFile(ExpandConstant('{app}\bin\VirtualDesktop11-24H2.exe'));
      DeleteFile(ExpandConstant('{app}\licenses\LICENSE-VirtualDesktop.txt'));
    end;
    if not WizardIsTaskSelected('startatlogon') then
      RemoveMinwmLogonTask();
  end
  else if CurStep = ssPostInstall then
  begin
    EnsureOptionalConfig();
    MigrateDefaultHotkeys();
    DeleteFile(ExpandConstant('{userstartup}\minwm.lnk'));
    if WizardIsTaskSelected('startatlogon') then
    begin
      if not CreateMinwmLogonTask() then
        CreateStartupFallback();
    end
    else
      Log('Startup at logon was not selected; no startup entry was created.');
  end;
end;
