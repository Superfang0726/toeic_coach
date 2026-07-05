; Inno Setup script for TOEIC Coach (Windows).
; Compile with the version passed in from the build command, e.g.:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.2.0 windows\installer\toeic_coach.iss
; See docs/RELEASING.md for the full release checklist.

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "TOEIC Coach"
#define MyAppExeName "toeic_coach.exe"
#define MyAppPublisher "Superfang0726"

[Setup]
; AppId uniquely identifies this app so future installers UPGRADE in place
; instead of installing side-by-side. Never change this value once shipped.
AppId={{8F3A1C7E-2B4D-4E9A-9C1F-6D5E7A8B9C0D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; Output installer file -> dist\toeic_coach-<version>-setup.exe
; The "-setup.exe" suffix is the convention the in-app updater looks for.
OutputDir=..\..\dist
OutputBaseFilename=toeic_coach-{#MyAppVersion}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Allow a normal (non-admin) install into the user's profile if needed.
PrivilegesRequiredOverridesAllowed=dialog
; During an update, close the running app and relaunch it afterward so files
; aren't locked. Paired with the updater's "launch installer then exit".
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "ChineseTraditional"; MessagesFile: "Languages\ChineseTraditional.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Flutter release output: the .exe plus its required data\ folder and
; bundled DLLs. recursesubdirs copies the nested data\ tree.
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Offer to launch the app when the installer finishes (and after an update).
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\{#MyAppExeName}"; Flags: nowait skipifnotsilent
