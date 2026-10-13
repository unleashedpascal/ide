{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SettingsStore;

{$mode unleashed}

interface

uses
  Classes, SysUtils, IniFiles, Forms, Controls, Graphics;

type
  TSettingsLocation = (slUserConfig, slAppDirectory, slCustom);
  TSettingsEvent = procedure(Sender: TObject; const section, key: string) of object;

  { TSettingsStore }

  // the settings of the application in a text file: typed reads with a
  // default, writes that save on their own, defaults from the designer, the
  // bounds of a form kept across runs. The file lands in the configuration
  // folder of the user unless told otherwise, so it works the same on every
  // system
  TSettingsStore = class(TComponent)
  private
    FIni: TMemIniFile;
    FFileName: string;
    FLocation: TSettingsLocation;
    FSection: string;
    FAutoLoad, FAutoSave, FLoaded, FDirty: boolean;
    FDefaults: TStrings;
    FOnLoad, FOnSave: TNotifyEvent;
    FOnChange: TSettingsEvent;
    procedure setDefaults(value: TStrings);
    procedure setFileName(const value: string);
    procedure setLocation(value: TSettingsLocation);
    function resolvedSection(const section: string): string;
    procedure need;
    procedure touched(const section, key: string);
    function defaultOf(const section, key, fallback: string): string;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the path of the file as the location and the file name make it
    function Path: string;
    procedure Load;
    procedure Save;
    // drops every value, the file too
    procedure Clear;
    function ValueExists(const key: string; const section: string = ''): boolean;
    procedure DeleteValue(const key: string; const section: string = '');
    procedure DeleteSection(const section: string);
    // the keys of a section, the sections of the file
    procedure ReadKeys(keys: TStrings; const section: string = '');
    procedure ReadSections(sections: TStrings);
    function ReadString(const key: string; const fallback: string = ''; const section: string = ''): string;
    function ReadInteger(const key: string; fallback: integer = 0; const section: string = ''): integer;
    function ReadInt64(const key: string; fallback: int64 = 0; const section: string = ''): int64;
    function ReadBool(const key: string; fallback: boolean = false; const section: string = ''): boolean;
    function ReadFloat(const key: string; fallback: double = 0; const section: string = ''): double;
    function ReadColor(const key: string; fallback: TColor = clBlack; const section: string = ''): TColor;
    function ReadDateTime(const key: string; fallback: TDateTime = 0; const section: string = ''): TDateTime;
    // lines kept as one value, newlines escaped
    procedure ReadStrings(const key: string; lines: TStrings; const section: string = '');
    procedure WriteString(const key, value: string; const section: string = '');
    procedure WriteInteger(const key: string; value: integer; const section: string = '');
    procedure WriteInt64(const key: string; value: int64; const section: string = '');
    procedure WriteBool(const key: string; value: boolean; const section: string = '');
    procedure WriteFloat(const key: string; value: double; const section: string = '');
    procedure WriteColor(const key: string; value: TColor; const section: string = '');
    procedure WriteDateTime(const key: string; value: TDateTime; const section: string = '');
    procedure WriteStrings(const key: string; lines: TStrings; const section: string = '');
    // the bounds and the state of a form under a section named after it
    procedure SaveForm(form: TCustomForm; const section: string = '');
    procedure RestoreForm(form: TCustomForm; const section: string = '');
    // unsaved writes wait in memory
    property Dirty: boolean read FDirty;
  published
    // relative to the location; empty takes the name of the program plus .ini
    property FileName: string read FFileName write setFileName;
    property Location: TSettingsLocation read FLocation write setLocation default slUserConfig;
    // the section reads and writes go to when they name none
    property Section: string read FSection write FSection;
    // read the file the first time a value is needed
    property AutoLoad: boolean read FAutoLoad write FAutoLoad default true;
    // write the file after every change
    property AutoSave: boolean read FAutoSave write FAutoSave default true;
    // values for keys the file does not have, as key=value or section/key=value
    property Defaults: TStrings read FDefaults write setDefaults;
    property OnLoad: TNotifyEvent read FOnLoad write FOnLoad;
    property OnSave: TNotifyEvent read FOnSave write FOnSave;
    property OnChange: TSettingsEvent read FOnChange write FOnChange;
  end;

implementation

uses
  Math;

constructor TSettingsStore.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSection := 'Settings';
  FAutoLoad := true;
  FAutoSave := true;
  FDefaults := TStringList.Create;
end;

destructor TSettingsStore.Destroy;
begin
  if FDirty and FAutoSave then Save;
  FIni.Free;
  FDefaults.Free;
  inherited Destroy;
end;

procedure TSettingsStore.Loaded;
begin
  inherited Loaded;
end;

function TSettingsStore.Path: string;
begin
  var name := FFileName;
  if name = '' then name := ChangeFileExt(ExtractFileName(ParamStr(0)), '.ini');
  if (FLocation = slCustom) or (ExtractFileDrive(name) <> '') or (name[1] = PathDelim) then exit(ExpandFileName(name));
  var dir := if FLocation = slAppDirectory then ExtractFilePath(ParamStr(0)) else GetAppConfigDir(false);
  result := IncludeTrailingPathDelimiter(dir)+name;
end;

// -- the file ----------------------

procedure TSettingsStore.need;
begin
  if FIni <> nil then exit;
  if FAutoLoad or (csDesigning in ComponentState) then Load
  else FIni := TMemIniFile.Create('');
end;

procedure TSettingsStore.Load;
begin
  FreeAndNil(FIni);
  var path := self.Path;
  if (csDesigning in ComponentState) or not FileExists(path) then FIni := TMemIniFile.Create('')
  else FIni := TMemIniFile.Create(path);
  FIni.Options := FIni.Options+[ifoStripQuotes];
  FLoaded := true;
  FDirty := false;
  if Assigned(FOnLoad) then FOnLoad(self);
end;

procedure TSettingsStore.Save;
begin
  need;
  if csDesigning in ComponentState then exit;
  var path := self.Path;
  ForceDirectories(ExtractFilePath(path));
  FIni.Rename(path, false);
  FIni.UpdateFile;
  FDirty := false;
  if Assigned(FOnSave) then FOnSave(self);
end;

procedure TSettingsStore.Clear;
begin
  FreeAndNil(FIni);
  FIni := TMemIniFile.Create('');
  FDirty := true;
  if FAutoSave then Save;
end;

procedure TSettingsStore.touched(const section, key: string);
begin
  FDirty := true;
  if Assigned(FOnChange) then FOnChange(self, section, key);
  if FAutoSave and not (csDesigning in ComponentState) then Save;
end;

function TSettingsStore.resolvedSection(const section: string): string;
begin
  result := if section <> '' then section else FSection;
  if result = '' then result := 'Settings';
end;

// the value from Defaults for a key, as section/key=value or key=value
function TSettingsStore.defaultOf(const section, key, fallback: string): string;
begin
  result := FDefaults.Values[section+'/'+key];
  if (result = '') and (FDefaults.IndexOfName(section+'/'+key) < 0) then begin
    result := FDefaults.Values[key];
    if (result = '') and (FDefaults.IndexOfName(key) < 0) then result := fallback;
  end;
end;

// -- values ----------------------

function TSettingsStore.ValueExists(const key: string; const section: string): boolean;
begin
  need;
  result := FIni.ValueExists(resolvedSection(section), key);
end;

procedure TSettingsStore.DeleteValue(const key: string; const section: string);
begin
  need;
  var s := resolvedSection(section);
  if not FIni.ValueExists(s, key) then exit;
  FIni.DeleteKey(s, key);
  touched(s, key);
end;

procedure TSettingsStore.DeleteSection(const section: string);
begin
  need;
  var s := resolvedSection(section);
  if not FIni.SectionExists(s) then exit;
  FIni.EraseSection(s);
  touched(s, '');
end;

procedure TSettingsStore.ReadKeys(keys: TStrings; const section: string);
begin
  need;
  FIni.ReadSection(resolvedSection(section), keys);
end;

procedure TSettingsStore.ReadSections(sections: TStrings);
begin
  need;
  FIni.ReadSections(sections);
end;

function TSettingsStore.ReadString(const key: string; const fallback: string; const section: string): string;
begin
  need;
  var s := resolvedSection(section);
  result := FIni.ReadString(s, key, defaultOf(s, key, fallback));
end;

function TSettingsStore.ReadInteger(const key: string; fallback: integer; const section: string): integer;
begin
  result := StrToIntDef(ReadString(key, IntToStr(fallback), section), fallback);
end;

function TSettingsStore.ReadInt64(const key: string; fallback: int64; const section: string): int64;
begin
  result := StrToInt64Def(ReadString(key, IntToStr(fallback), section), fallback);
end;

function TSettingsStore.ReadBool(const key: string; fallback: boolean; const section: string): boolean;
begin
  var text := LowerCase(Trim(ReadString(key, (if fallback then '1' else '0'), section)));
  result := match text of
    '1', 'true', 'yes', 'on': true;
    '0', 'false', 'no', 'off', '': false;
  else
    fallback
  end;
end;

function TSettingsStore.ReadFloat(const key: string; fallback: double; const section: string): double;
begin
  // the file always holds a dot, whatever the locale of the machine
  result := StrToFloatDef(ReadString(key, FloatToStr(fallback, DefaultFormatSettings), section), fallback, DefaultFormatSettings);
end;

function TSettingsStore.ReadColor(const key: string; fallback: TColor; const section: string): TColor;
begin
  var text := ReadString(key, ColorToString(fallback), section);
  if not IdentToColor(text, longint(result)) then result := TColor(StrToIntDef(text, fallback));
end;

function TSettingsStore.ReadDateTime(const key: string; fallback: TDateTime; const section: string): TDateTime;
begin
  var text := ReadString(key, '', section);
  if (text = '') or not TryStrToFloat(text, result, DefaultFormatSettings) then result := fallback;
end;

procedure TSettingsStore.ReadStrings(const key: string; lines: TStrings; const section: string);
begin
  var text := ReadString(key, '', section);
  lines.Text := StringReplace(StringReplace(text, '\n', LineEnding, [rfReplaceAll]), '\\', '\', [rfReplaceAll]);
end;

procedure TSettingsStore.WriteString(const key, value: string; const section: string);
begin
  need;
  var s := resolvedSection(section);
  if FIni.ValueExists(s, key) and (FIni.ReadString(s, key, '') = value) then exit;
  FIni.WriteString(s, key, value);
  touched(s, key);
end;

procedure TSettingsStore.WriteInteger(const key: string; value: integer; const section: string);
begin
  WriteString(key, IntToStr(value), section);
end;

procedure TSettingsStore.WriteInt64(const key: string; value: int64; const section: string);
begin
  WriteString(key, IntToStr(value), section);
end;

procedure TSettingsStore.WriteBool(const key: string; value: boolean; const section: string);
begin
  WriteString(key, (if value then '1' else '0'), section);
end;

procedure TSettingsStore.WriteFloat(const key: string; value: double; const section: string);
begin
  WriteString(key, FloatToStr(value, DefaultFormatSettings), section);
end;

procedure TSettingsStore.WriteColor(const key: string; value: TColor; const section: string);
begin
  WriteString(key, ColorToString(value), section);
end;

procedure TSettingsStore.WriteDateTime(const key: string; value: TDateTime; const section: string);
begin
  WriteString(key, FloatToStr(double(value), DefaultFormatSettings), section);
end;

procedure TSettingsStore.WriteStrings(const key: string; lines: TStrings; const section: string);
begin
  var text := StringReplace(lines.Text, '\', '\\', [rfReplaceAll]);
  text := StringReplace(text, LineEnding, '\n', [rfReplaceAll]);
  WriteString(key, text, section);
end;

// -- forms ----------------------

procedure TSettingsStore.SaveForm(form: TCustomForm; const section: string);
begin
  if form = nil then exit;
  var s := if section <> '' then section else 'Form.'+form.Name;
  var wasAuto := FAutoSave;
  FAutoSave := false;
  try
    // the normal bounds, so a maximized form comes back the same size
    var r := if form.WindowState = wsNormal then form.BoundsRect else Rect(form.RestoredLeft, form.RestoredTop, form.RestoredLeft+form.RestoredWidth, form.RestoredTop+form.RestoredHeight);
    WriteInteger('Left', r.Left, s);
    WriteInteger('Top', r.Top, s);
    WriteInteger('Width', r.Width, s);
    WriteInteger('Height', r.Height, s);
    WriteBool('Maximized', form.WindowState = wsMaximized, s);
  finally
    FAutoSave := wasAuto;
  end;
  if FAutoSave then Save;
end;

procedure TSettingsStore.RestoreForm(form: TCustomForm; const section: string);
begin
  if form = nil then exit;
  var s := if section <> '' then section else 'Form.'+form.Name;
  if not ValueExists('Width', s) then exit;
  var r := Rect(ReadInteger('Left', form.Left, s), ReadInteger('Top', form.Top, s), 0, 0);
  r.Right := r.Left+Max(ReadInteger('Width', form.Width, s), 50);
  r.Bottom := r.Top+Max(ReadInteger('Height', form.Height, s), 50);
  // keep it on a monitor that still exists
  var m := Screen.MonitorFromRect(r);
  if m = nil then m := Screen.PrimaryMonitor;
  if m <> nil then begin
    var work := m.WorkareaRect;
    if r.Right > work.Right then r.Offset(work.Right-r.Right, 0);
    if r.Bottom > work.Bottom then r.Offset(0, work.Bottom-r.Bottom);
    if r.Left < work.Left then r.Offset(work.Left-r.Left, 0);
    if r.Top < work.Top then r.Offset(0, work.Top-r.Top);
  end;
  form.Position := poDesigned;
  form.BoundsRect := r;
  if ReadBool('Maximized', false, s) then form.WindowState := wsMaximized;
end;

// -- properties ----------------------

procedure TSettingsStore.setDefaults(value: TStrings);
begin
  FDefaults.Assign(value);
end;

procedure TSettingsStore.setFileName(const value: string);
begin
  if FFileName = value then exit;
  FFileName := value;
  FreeAndNil(FIni);
  FLoaded := false;
end;

procedure TSettingsStore.setLocation(value: TSettingsLocation);
begin
  if FLocation = value then exit;
  FLocation := value;
  FreeAndNil(FIni);
  FLoaded := false;
end;

end.
