unit project_paths_options;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  // LCL
  Controls, Forms, StdCtrls, ExtCtrls, Dialogs, Graphics, LCLIntf,
  // LazControls
  DividerBevel,
  // LazUtils
  AvgLvlTree,
  // BuildIntf
  IDEOptionsIntf,
  // IdeIntf
  IDEOptEditorIntf,
  // IDE
  Project;

const
  // key stored in the project .lpi under ProjectOptions/CustomData/
  ProjectRTLPathKey = 'RTLPath';

  BinaryMetadataDocsURL =
    'https://github.com/unleashedpascal/compiler/blob/main/unleashed/docs/binary-metadata.md';
  StripRTTIDocsURL =
    'https://github.com/unleashedpascal/compiler/blob/main/unleashed/docs/strip-rtti.md';

type

  { TProjectPathsOptionsFrame }

  TProjectPathsOptionsFrame = class(TAbstractIDEOptionsEditor)
    divSrcDir: TDividerBevel;
    FPCSrcDirEdit: TEdit;
    RescanInfoLabel: TLabel;

    divSignature: TDividerBevel;
    SignatureDocsPrefix: TLabel;
    SignatureDocsLink: TLabel;
    FPCSignatureEdit: TEdit;
    SignatureEmptyCheckBox: TCheckBox;
    SignatureInfoLabel: TLabel;

    divLinker: TDividerBevel;
    LinkerDocsPrefix: TLabel;
    LinkerDocsLink: TLabel;
    LinkerPresetCombo: TComboBox;
    LinkerMajorLabel: TLabel;
    LinkerMajorEdit: TEdit;
    LinkerMinorLabel: TLabel;
    LinkerMinorEdit: TEdit;
    LinkerInfoLabel: TLabel;

    divOS: TDividerBevel;
    OSDocsPrefix: TLabel;
    OSDocsLink: TLabel;
    OSPresetCombo: TComboBox;
    OSMajorLabel: TLabel;
    OSMajorEdit: TEdit;
    OSMinorLabel: TLabel;
    OSMinorEdit: TEdit;
    OSInfoLabel: TLabel;

    divStripRTTI: TDividerBevel;
    StripDocsPrefix: TLabel;
    StripDocsLink: TLabel;
    StripRTTICheckBox: TCheckBox;
    WhitelistLabel: TLabel;
    RTTIExposeEdit: TEdit;
    StripInfoLabel: TLabel;

    divAutoProp: TDividerBevel;
    AutoPropPrefixEdit: TEdit;
    AutoPropInfoLabel: TLabel;

    ResetPanel: TPanel;
    ResetButton: TButton;

    procedure DocsLinkClick(Sender: TObject);
    procedure ResetButtonClick(Sender: TObject);
    procedure DocsLinkMouseEnter(Sender: TObject);
    procedure DocsLinkMouseLeave(Sender: TObject);
    procedure SignatureEmptyCheckBoxChange(Sender: TObject);
    procedure StripRTTICheckBoxChange(Sender: TObject);
    procedure LinkerPresetComboSelect(Sender: TObject);
    procedure OSPresetComboSelect(Sender: TObject);
    procedure LinkerVersionEditChange(Sender: TObject);
    procedure OSVersionEditChange(Sender: TObject);
  private
    // suppress control event handlers while ReadSettings/preset code drives them
    FUpdating: boolean;
    // last non-header linker preset index, restored when a header is clicked
    FLinkerPrevIndex: integer;
    procedure SplitVersion(const AValue: string; AMajor, AMinor: TEdit);
  public
    function Check: Boolean; override;
    function GetTitle: string; override;
    procedure Setup({%H-}ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings(AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings(AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

implementation

{$R *.lfm}

type
  TVerKind = (vkKeep, vkUser, vkHeader, vkVer);
  TVerPreset = record
    Kind: TVerKind;
    Major, Minor, Caption: string;
  end;

const
  AutoPropDefaultPrefix = 'F';
  // (keep default) is index 0, (user-specified) index 1 in both preset arrays
  PresetUserIdx = 1;

  LinkerPresets: array[0..22] of TVerPreset = (
    (Kind: vkKeep;   Major: '';    Minor: ''; Caption: ''),
    (Kind: vkUser;   Major: '';    Minor: ''; Caption: ''),
    (Kind: vkHeader; Major: '';    Minor: ''; Caption: 'Windows'),
    (Kind: vkVer;    Major: '14';  Minor: '44'; Caption: 'Microsoft LINK'),
    (Kind: vkVer;    Major: '2';   Minor: '44'; Caption: 'GNU ld / GNU ld.bfd / GNU gold'),
    (Kind: vkVer;    Major: '20';  Minor: '1';  Caption: 'LLVM LLD'),
    (Kind: vkVer;    Major: '2';   Minor: '43'; Caption: 'Go cmd/link'),
    (Kind: vkVer;    Major: '1';   Minor: '24'; Caption: 'Zig linker'),
    (Kind: vkVer;    Major: '6';   Minor: '13'; Caption: 'Embarcadero ILINK64'),
    (Kind: vkVer;    Major: '1';   Minor: '8';  Caption: 'OpenWatcom WLINK'),
    (Kind: vkVer;    Major: '8';   Minor: '39'; Caption: 'Digital Mars OPTLINK'),
    (Kind: vkHeader; Major: '';    Minor: ''; Caption: 'Linux'),
    (Kind: vkVer;    Major: '2';   Minor: '44'; Caption: 'GNU ld / GNU ld.bfd / GNU gold'),
    (Kind: vkVer;    Major: '12';  Minor: '0';  Caption: 'mold / mold-static'),
    (Kind: vkVer;    Major: '20';  Minor: '1';  Caption: 'LLVM LLD / wasm-ld'),
    (Kind: vkVer;    Major: '2';   Minor: '43'; Caption: 'Go cmd/link'),
    (Kind: vkVer;    Major: '1';   Minor: '24'; Caption: 'Zig linker'),
    (Kind: vkHeader; Major: '';    Minor: ''; Caption: 'Others'),
    (Kind: vkVer;    Major: '100'; Minor: '1';  Caption: 'Apple ld / ld64.lld'),
    (Kind: vkVer;    Major: '20';  Minor: '1';  Caption: 'LLVM LLD'),
    (Kind: vkVer;    Major: '11';  Minor: '4';  Caption: 'Oracle Solaris ld'),
    (Kind: vkVer;    Major: '1';   Minor: '16'; Caption: 'TinyCC linker'),
    (Kind: vkVer;    Major: '1';   Minor: '8';  Caption: 'OpenWatcom WLINK')
  );

  OSPresets: array[0..12] of TVerPreset = (
    (Kind: vkKeep; Major: '';   Minor: ''; Caption: ''),
    (Kind: vkUser; Major: '';   Minor: ''; Caption: ''),
    (Kind: vkVer;  Major: '4';  Minor: '0';  Caption: '95'),
    (Kind: vkVer;  Major: '4';  Minor: '10'; Caption: '98'),
    (Kind: vkVer;  Major: '4';  Minor: '90'; Caption: 'ME'),
    (Kind: vkVer;  Major: '5';  Minor: '0';  Caption: '2000'),
    (Kind: vkVer;  Major: '5';  Minor: '1';  Caption: 'XP'),
    (Kind: vkVer;  Major: '5';  Minor: '2';  Caption: '2003'),
    (Kind: vkVer;  Major: '6';  Minor: '0';  Caption: 'Vista'),
    (Kind: vkVer;  Major: '6';  Minor: '1';  Caption: '7'),
    (Kind: vkVer;  Major: '6';  Minor: '2';  Caption: '8'),
    (Kind: vkVer;  Major: '6';  Minor: '3';  Caption: '8.1'),
    (Kind: vkVer;  Major: '10'; Minor: '0';  Caption: '10/11')
  );

// "major.minor" key for a version preset, '' for header / user-specified
function VerKey(const P: TVerPreset): string;
begin
  if P.Kind = vkVer then Result := P.Major + '.' + P.Minor else Result := '';
end;

// dot becomes the 3rd char of a 5-char field: major right-, minor left-justified
function FormatVer(const Major, Minor: string): string;
var
  mj, mn: string;
begin
  mj := Major;
  mn := Minor;
  while Length(mj) < 2 do mj := ' ' + mj;
  while Length(mn) < 2 do mn := mn + ' ';
  Result := mj + '.' + mn;
end;

function PresetDisplay(const P: TVerPreset): string;
begin
  case P.Kind of
    vkKeep:   Result := '(keep default)';
    vkUser:   Result := '(user-specified)';
    vkHeader: Result := '--- ' + P.Caption;
  else
    Result := FormatVer(P.Major, P.Minor) + ' ' + P.Caption;
  end;
end;

procedure FillPresetCombo(Combo: TComboBox; const Presets: array of TVerPreset);
var
  i: integer;
begin
  Combo.Items.BeginUpdate;
  try
    Combo.Items.Clear;
    for i := Low(Presets) to High(Presets) do
      Combo.Items.Add(PresetDisplay(Presets[i]));
  finally
    Combo.Items.EndUpdate;
  end;
end;

// first non-header index from FromIdx moving by Dir (+1/-1), or -1 if out of range
function SkipHeaders(const Presets: array of TVerPreset; FromIdx, Dir: integer): integer;
begin
  Result := FromIdx;
  while (Result >= Low(Presets)) and (Result <= High(Presets))
  and (Presets[Result].Kind = vkHeader) do
    Inc(Result, Dir);
  if (Result < Low(Presets)) or (Result > High(Presets)) then Result := -1;
end;

// called only for a non-empty stored version: match a preset, else (user-specified)
procedure SelectVerPreset(Combo: TComboBox; const Presets: array of TVerPreset;
  const Version: string);
var
  i: integer;
begin
  for i := Low(Presets) to High(Presets) do
    if (Presets[i].Kind = vkVer) and (CompareText(VerKey(Presets[i]), Version) = 0) then
    begin
      Combo.ItemIndex := i;
      exit;
    end;
  Combo.ItemIndex := PresetUserIdx;
end;

// blend color toward the window background by Pct percent
function DimColor(C: TColor; Pct: byte): TColor;
var
  cr, cg, cb, br, bg, bb: byte;
begin
  RedGreenBlue(ColorToRGB(C), cr, cg, cb);
  RedGreenBlue(ColorToRGB(clWindow), br, bg, bb);
  Result := RGBToColor(
    (cr * (100 - Pct) + br * Pct) div 100,
    (cg * (100 - Pct) + bg * Pct) div 100,
    (cb * (100 - Pct) + bb * Pct) div 100);
end;

function ValidAutoPropPrefix(const s: string): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(s) < 1) or (Length(s) > 127) then exit;
  if not (s[1] in ['A'..'Z', 'a'..'z', '_']) then exit;
  for i := 2 to Length(s) do
    if not (s[i] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then exit;
  Result := True;
end;

{ TProjectPathsOptionsFrame }

function TProjectPathsOptionsFrame.Check: Boolean;

  // both fields empty (no override) or both filled is valid; exactly one is not
  function PairValid(AMajor, AMinor: TEdit): boolean;
  begin
    Result := (Trim(AMajor.Text) = '') = (Trim(AMinor.Text) = '');
  end;

begin
  Result := False;
  if not PairValid(LinkerMajorEdit, LinkerMinorEdit) then
  begin
    MessageDlg('Override linker version: set both major and minor, or leave both empty.',
      mtError, [mbOK], 0);
    exit;
  end;
  if not PairValid(OSMajorEdit, OSMinorEdit) then
  begin
    MessageDlg('Override OS version: set both major and minor, or leave both empty.',
      mtError, [mbOK], 0);
    exit;
  end;
  if not ValidAutoPropPrefix(Trim(AutoPropPrefixEdit.Text)) then
  begin
    MessageDlg('Auto-properties prefix must be 1-127 chars matching [A-Za-z_][A-Za-z0-9_]*.',
      mtError, [mbOK], 0);
    exit;
  end;
  Result := True;
end;

function TProjectPathsOptionsFrame.GetTitle: string;
begin
  Result := 'Overrides';
end;

procedure TProjectPathsOptionsFrame.Setup(ADialog: TAbstractOptionsEditorDialog);
begin
  divSrcDir.Caption := 'RTL path (--rtl)';
  RescanInfoLabel.Caption :=
    'Folder with the RTL sources for this project: passed to the compiler as --rtl=<path> and used by the IDE for code completion.'
    + LineEnding +
    'A rescan may be required after changing it: main menu -> Tools -> Rescan FPC Source Directory.';

  divSignature.Caption := 'FPC signature';
  SignatureDocsPrefix.Caption := 'docs:';
  SignatureDocsLink.Caption := 'binary-metadata.md';
  SignatureDocsLink.Hint := BinaryMetadataDocsURL;
  SignatureEmptyCheckBox.Caption := 'Set empty';
  SignatureInfoLabel.Caption :=
    'Replaces the .fpc.version ident string in the binary. "Set empty" drops the section entirely.';

  divLinker.Caption := 'Override linker version (PE only)';
  LinkerDocsPrefix.Caption := 'docs:';
  LinkerDocsLink.Caption := 'binary-metadata.md';
  LinkerDocsLink.Hint := BinaryMetadataDocsURL;
  LinkerMajorLabel.Caption := 'major:';
  LinkerMinorLabel.Caption := 'minor:';
  LinkerInfoLabel.Caption :=
    'PE optional header linker version. Windows PE targets only, ignored elsewhere.';
  FillPresetCombo(LinkerPresetCombo, LinkerPresets);

  divOS.Caption := 'Override OS version (PE only)';
  OSDocsPrefix.Caption := 'docs:';
  OSDocsLink.Caption := 'binary-metadata.md';
  OSDocsLink.Hint := BinaryMetadataDocsURL;
  OSMajorLabel.Caption := 'major:';
  OSMinorLabel.Caption := 'minor:';
  OSInfoLabel.Caption :=
    'Minimum-OS-version field in the PE header. Windows PE targets only, ignored elsewhere.';
  FillPresetCombo(OSPresetCombo, OSPresets);

  divStripRTTI.Caption := 'Strip RTTI';
  StripDocsPrefix.Caption := 'docs:';
  StripDocsLink.Caption := 'strip-rtti.md';
  StripDocsLink.Hint := StripRTTIDocsURL;
  StripRTTICheckBox.Caption := 'Strip RTTI';
  WhitelistLabel.Caption := 'Whitelist:';
  StripInfoLabel.Caption :=
    'Nulls type-name strings in RTTI/VMT. The whitelist keeps matching types visible (comma-separated, wildcards allowed).';

  divAutoProp.Caption := 'Auto-properties prefix';
  AutoPropInfoLabel.Caption :=
    'Prefix for the backing field synthesized for an accessor-less property (--autopropprefix). Default "F".';

  ResetButton.Caption := 'Reset all to defaults';
end;

procedure TProjectPathsOptionsFrame.DocsLinkClick(Sender: TObject);
begin
  OpenURL((Sender as TLabel).Hint);
end;

procedure TProjectPathsOptionsFrame.ResetButtonClick(Sender: TObject);
begin
  FUpdating := True;
  try
    FPCSignatureEdit.Text := '';
    SignatureEmptyCheckBox.Checked := False;
    FPCSignatureEdit.Enabled := True;

    LinkerMajorEdit.Text := '';
    LinkerMinorEdit.Text := '';
    LinkerPresetCombo.ItemIndex := 0; // (keep default)
    FLinkerPrevIndex := 0;

    OSMajorEdit.Text := '';
    OSMinorEdit.Text := '';
    OSPresetCombo.ItemIndex := 0; // (keep default)

    StripRTTICheckBox.Checked := False;
    RTTIExposeEdit.Text := 'TForm*';
    RTTIExposeEdit.Enabled := False;

    AutoPropPrefixEdit.Text := AutoPropDefaultPrefix;
  finally
    FUpdating := False;
  end;
end;

procedure TProjectPathsOptionsFrame.DocsLinkMouseEnter(Sender: TObject);
begin
  (Sender as TLabel).Font.Color := DimColor(clWindowText, 5);
end;

procedure TProjectPathsOptionsFrame.DocsLinkMouseLeave(Sender: TObject);
begin
  (Sender as TLabel).Font.Color := clWindowText;
end;

procedure TProjectPathsOptionsFrame.SignatureEmptyCheckBoxChange(Sender: TObject);
begin
  FPCSignatureEdit.Enabled := not SignatureEmptyCheckBox.Checked;
end;

procedure TProjectPathsOptionsFrame.StripRTTICheckBoxChange(Sender: TObject);
begin
  RTTIExposeEdit.Enabled := StripRTTICheckBox.Checked;
end;

procedure TProjectPathsOptionsFrame.LinkerPresetComboSelect(Sender: TObject);
var
  idx: integer;
begin
  if FUpdating then exit;
  idx := LinkerPresetCombo.ItemIndex;
  if idx < 0 then exit;
  if LinkerPresets[idx].Kind = vkHeader then
  begin
    // a header is not selectable: skip to the next item in the scroll direction
    if idx >= FLinkerPrevIndex then idx := SkipHeaders(LinkerPresets, idx, 1)
    else idx := SkipHeaders(LinkerPresets, idx, -1);
    if idx < 0 then idx := FLinkerPrevIndex; // no item that way, stay put
    FUpdating := True;
    LinkerPresetCombo.ItemIndex := idx;
    FUpdating := False;
  end;
  FLinkerPrevIndex := idx;
  if LinkerPresets[idx].Kind = vkUser then exit; // keep the current edits
  FUpdating := True;
  LinkerMajorEdit.Text := LinkerPresets[idx].Major; // empty for (keep default)
  LinkerMinorEdit.Text := LinkerPresets[idx].Minor;
  FUpdating := False;
end;

procedure TProjectPathsOptionsFrame.OSPresetComboSelect(Sender: TObject);
var
  idx: integer;
begin
  if FUpdating then exit;
  idx := OSPresetCombo.ItemIndex;
  if idx < 0 then exit;
  if OSPresets[idx].Kind = vkUser then exit; // keep the current edits
  FUpdating := True;
  OSMajorEdit.Text := OSPresets[idx].Major; // empty for (keep default)
  OSMinorEdit.Text := OSPresets[idx].Minor;
  FUpdating := False;
end;

procedure TProjectPathsOptionsFrame.LinkerVersionEditChange(Sender: TObject);
begin
  if FUpdating then exit;
  LinkerPresetCombo.ItemIndex := PresetUserIdx;
  FLinkerPrevIndex := PresetUserIdx;
end;

procedure TProjectPathsOptionsFrame.OSVersionEditChange(Sender: TObject);
begin
  if FUpdating then exit;
  OSPresetCombo.ItemIndex := PresetUserIdx;
end;

procedure TProjectPathsOptionsFrame.SplitVersion(const AValue: string;
  AMajor, AMinor: TEdit);
var
  p: integer;
begin
  p := Pos('.', AValue);
  if p > 0 then
  begin
    AMajor.Text := Copy(AValue, 1, p-1);
    AMinor.Text := Copy(AValue, p+1, Length(AValue));
  end
  else
  begin
    AMajor.Text := AValue;
    AMinor.Text := '';
  end;
end;

procedure TProjectPathsOptionsFrame.ReadSettings(AOptions: TAbstractIDEOptions);
var
  Data: TStringToStringTree;
begin
  Data := (AOptions as TProjectIDEOptions).Project.CustomData;
  FUpdating := True;
  try
    FPCSrcDirEdit.Text := Data.Values[ProjectRTLPathKey];

    FPCSignatureEdit.Text := Data.Values[ProjFPCSignatureKey];
    SignatureEmptyCheckBox.Checked := Data.Values[ProjFPCSignatureEmptyKey] = '1';
    FPCSignatureEdit.Enabled := not SignatureEmptyCheckBox.Checked;

    SplitVersion(Data.Values[ProjLinkerVersionKey], LinkerMajorEdit, LinkerMinorEdit);
    if Data.Values[ProjLinkerVersionKey] = '' then
      LinkerPresetCombo.ItemIndex := 0 // (keep default)
    else
      SelectVerPreset(LinkerPresetCombo, LinkerPresets, Data.Values[ProjLinkerVersionKey]);
    FLinkerPrevIndex := LinkerPresetCombo.ItemIndex;

    SplitVersion(Data.Values[ProjOSVersionKey], OSMajorEdit, OSMinorEdit);
    if Data.Values[ProjOSVersionKey] = '' then
      OSPresetCombo.ItemIndex := 0 // (keep default)
    else
      SelectVerPreset(OSPresetCombo, OSPresets, Data.Values[ProjOSVersionKey]);

    StripRTTICheckBox.Checked := Data.Values[ProjStripRTTIKey] = '1';
    if Data.Contains(ProjRTTIExposeKey) then
      RTTIExposeEdit.Text := Data.Values[ProjRTTIExposeKey]
    else
      RTTIExposeEdit.Text := 'TForm*';
    RTTIExposeEdit.Enabled := StripRTTICheckBox.Checked;

    if Data.Contains(ProjAutoPropPrefixKey) then
      AutoPropPrefixEdit.Text := Data.Values[ProjAutoPropPrefixKey]
    else
      AutoPropPrefixEdit.Text := AutoPropDefaultPrefix;
  finally
    FUpdating := False;
  end;
end;

procedure TProjectPathsOptionsFrame.WriteSettings(AOptions: TAbstractIDEOptions);
var
  Prj: TProject;
  Data: TStringToStringTree;
  DataChanged: boolean;
  Whitelist, Prefix: string;

  procedure PutVal(const Key, Val: string);
  begin
    if Val = Data.Values[Key] then exit;
    if Val = '' then
    begin
      if Data.Contains(Key) then
      begin
        Data.Remove(Key);
        DataChanged := True;
      end;
    end
    else
    begin
      Data.Values[Key] := Val;
      DataChanged := True;
    end;
  end;

  function BoolVal(b: boolean): string;
  begin
    if b then Result := '1' else Result := '';
  end;

  function VersionVal(AMajor, AMinor: TEdit): string;
  var
    mj, mn: string;
  begin
    mj := Trim(AMajor.Text);
    mn := Trim(AMinor.Text);
    if mj = '' then Result := ''
    else if mn = '' then Result := mj
    else Result := mj + '.' + mn;
  end;

begin
  Prj := (AOptions as TProjectIDEOptions).Project;
  Data := Prj.CustomData;
  DataChanged := False;

  PutVal(ProjectRTLPathKey, Trim(FPCSrcDirEdit.Text));
  PutVal(ProjFPCSignatureKey, FPCSignatureEdit.Text);
  PutVal(ProjFPCSignatureEmptyKey, BoolVal(SignatureEmptyCheckBox.Checked));
  PutVal(ProjLinkerVersionKey, VersionVal(LinkerMajorEdit, LinkerMinorEdit));
  PutVal(ProjOSVersionKey, VersionVal(OSMajorEdit, OSMinorEdit));
  PutVal(ProjStripRTTIKey, BoolVal(StripRTTICheckBox.Checked));

  // store the whitelist only when stripping or when it differs from the default,
  // so untouched projects do not get a redundant entry in the .lpi
  Whitelist := Trim(RTTIExposeEdit.Text);
  if StripRTTICheckBox.Checked or (Whitelist <> 'TForm*') then
    PutVal(ProjRTTIExposeKey, Whitelist)
  else
    PutVal(ProjRTTIExposeKey, '');

  // Check has already validated the prefix; the default means "no override"
  Prefix := Trim(AutoPropPrefixEdit.Text);
  if Prefix = AutoPropDefaultPrefix then
    PutVal(ProjAutoPropPrefixKey, '')
  else
    PutVal(ProjAutoPropPrefixKey, Prefix);

  if DataChanged then Prj.Modified := True;
end;

class function TProjectPathsOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result := TProjectIDEOptions;
end;

initialization
  RegisterIDEOptionsEditor(GroupProject, TProjectPathsOptionsFrame, ProjectOptionsMisc + 50);

end.
