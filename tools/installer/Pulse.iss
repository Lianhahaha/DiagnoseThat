; Pulse Windows installer (Inno Setup 6)
; Produced by tools/scripts/package_beta.ps1
;
; End users double-click Pulse-Setup-*-windows-x64.exe
; No PowerShell. No ExecutionPolicy. UAC elevation only.

#define MyAppName "Pulse"
#define MyAppVersion "1.5.0"
#define MyAppPublisher "Regncreative"
#define MyAppURL "https://github.com/Regncreative/Pulse"
#define MyAppExeName "Pulse.exe"

#ifndef PulsePayloadDir
  #define PulsePayloadDir "..\..\dist\Pulse"
#endif

#ifndef PulseOutDir
  #define PulseOutDir "..\..\dist"
#endif

[Setup]
AppId={{8F3C2A91-6D4E-4B7A-9E12-7C1D0A5B4E8F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\Pulse
DefaultGroupName=Pulse
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#PulseOutDir}
OutputBaseFilename=Pulse-Setup-{#MyAppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
; Midnight look (ADR-012): forced dark, no bevel lines, app canvas color.
; Images come from make_wizard_images.py; Setup picks the best DPI match.
WizardStyle=modern dark hidebevels
WizardBackColor=#08080A
WizardImageFile=branding\wizard-image-100.png,branding\wizard-image-125.png,branding\wizard-image-150.png,branding\wizard-image-175.png,branding\wizard-image-200.png,branding\wizard-image-250.png
WizardSmallImageFile=branding\wizard-small-image-100.png,branding\wizard-small-image-125.png,branding\wizard-small-image-150.png,branding\wizard-small-image-175.png,branding\wizard-small-image-200.png,branding\wizard-small-image-250.png
SetupLogging=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
; Ask Explorer to refresh icons at the end of setup. Without it, an upgrade
; that changes the app icon showed a blank taskbar icon (stale icon cache).
ChangesAssociations=yes
RestartIfNeededByRun=no
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[InstallDelete]
; Leftovers from earlier versions that upgrades never removed (~41 MB):
; debug symbols shipped by an early beta, and the VC++ redistributable that
; used to be kept in the install folder after setup.
Type: files; Name: "{app}\service\PulseService.pdb"
Type: filesandordirs; Name: "{app}\redist"
; AI Integration (PulseMCP) was removed in 1.3 (ADR-013): ~100 MB of private
; Node runtime and MCP server. Running instances are closed first (see
; RegisterExtraCloseApplicationsResources); the app removes its client
; registrations on first launch.
Type: files; Name: "{app}\PulseMCP.exe"
Type: files; Name: "{app}\PulseMCP.cmd"
Type: filesandordirs; Name: "{app}\runtime"
Type: filesandordirs; Name: "{app}\mcp"
Type: files; Name: "{app}\docs\guides\ai-integration.md"

[Files]
Source: "{#PulsePayloadDir}\*"; DestDir: "{app}"; Excludes: "redist\*,*.pdb"; Flags: ignoreversion recursesubdirs
; Only needed while installing: extract to the temp folder Setup cleans up.
Source: "{#PulsePayloadDir}\redist\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\Pulse"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall Pulse"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Pulse"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Launch after install — service is started in [Code] before this runs.
Filename: "{app}\{#MyAppExeName}"; \
  Description: "Launch Pulse"; \
  Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{app}\service\PulseService.exe"; \
  Parameters: "--uninstall"; \
  Flags: runhidden waituntilterminated; \
  RunOnceId: "UninstallPulseService"

[Code]
// Close PulseMCP processes left by 1.2 (the status daemon and AI-client
// sessions run runtime\node.exe) so [InstallDelete] can remove them. Setup
// only checks files it installs unless told otherwise.
procedure RegisterExtraCloseApplicationsResources;
begin
  RegisterExtraCloseApplicationsResource(False, ExpandConstant('{app}\runtime\node.exe'));
  RegisterExtraCloseApplicationsResource(False, ExpandConstant('{app}\PulseMCP.exe'));
end;

function ExecChecked(const FileName, Params, WorkDir: String; var ResultCode: Integer): Boolean;
begin
  Result := Exec(FileName, Params, WorkDir, SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  Redist: String;
  ServiceExe: String;
begin
  if CurStep <> ssPostInstall then
    Exit;

  Redist := ExpandConstant('{tmp}\VC_redist.x64.exe');
  ServiceExe := ExpandConstant('{app}\service\PulseService.exe');

  { 1) Visual C++ Redistributable (quiet). 0 / 1638 / 3010 are acceptable. }
  if FileExists(Redist) then
  begin
    WizardForm.StatusLabel.Caption := 'Installing Visual C++ runtime…';
    if ExecChecked(Redist, '/install /quiet /norestart',
                   ExpandConstant('{tmp}'), ResultCode) then
    begin
      if (ResultCode <> 0) and (ResultCode <> 1638) and (ResultCode <> 3010) then
        MsgBox('Visual C++ Redistributable returned exit code ' + IntToStr(ResultCode) + '.' + #13#10 +
               'Pulse may still run using bundled runtime DLLs.',
               mbInformation, MB_OK);
    end;
  end;

  { 2) Register + auto-start + start PulseService. No PowerShell. }
  WizardForm.StatusLabel.Caption := 'Installing and starting PulseService…';
  if not FileExists(ServiceExe) then
  begin
    MsgBox('PulseService.exe is missing from the install folder.', mbError, MB_OK);
    Exit;
  end;

  if not ExecChecked(ServiceExe, '--install-start',
                     ExpandConstant('{app}\service'), ResultCode) then
  begin
    MsgBox('Could not run PulseService --install-start.', mbError, MB_OK);
    Exit;
  end;

  if ResultCode <> 0 then
  begin
    MsgBox('PulseService did not start (exit code ' + IntToStr(ResultCode) + ').' + #13#10 +
           'Pulse will stay Offline until the service is running.' + #13#10 +
           'Reboot and open Pulse from the Start menu, or re-run this installer.',
           mbError, MB_OK);
    Exit;
  end;

  WizardForm.StatusLabel.Caption := 'PulseService is running.';
end;

{ Uninstall: close Pulse.exe from this install folder first. CloseApplications
  only applies to Setup, so a Pulse running in the tray kept running after
  the uninstall (its files were left for the next restart). AppMutex would
  only ask the user to close it, and would also block upgrades. Only this
  folder's Pulse.exe is closed; copies elsewhere are left alone. }
procedure ClosePulseFromInstallFolder;
var
  Locator, Service, Processes, Process: Variant;
  AppExe, Query: String;
  I: Integer;
begin
  AppExe := ExpandConstant('{app}\{#MyAppExeName}');
  { WQL string literals need doubled backslashes. }
  StringChangeEx(AppExe, '\', '\\', True);
  Query := 'SELECT ProcessId FROM Win32_Process WHERE ExecutablePath = ''' + AppExe + '''';
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Service := Locator.ConnectServer('.', 'root\CIMV2');
    Processes := Service.ExecQuery(Query);
    for I := 0 to Processes.Count - 1 do
    begin
      Process := Processes.ItemIndex(I);
      Log('Closing Pulse.exe (PID ' +
          IntToStr(Process.Properties_.Item('ProcessId').Value) +
          ') before uninstall');
      { Late-bound like VBScript; ExecMethod_ without input parameters
        fails here with "Invalid parameter". 0 is the exit code. }
      Process.Terminate(0);
    end;
    if Processes.Count > 0 then
      Sleep(1000);  { Let Windows release the closed process's files. }
  except
    Log('Could not close Pulse.exe before uninstall: ' + GetExceptionMessage);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    ClosePulseFromInstallFolder;
end;
