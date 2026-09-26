{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SchemeManager;

{$mode unleashed}

interface

uses
  Classes, Forms, Controls, ComCtrls, StdCtrls, ExtCtrls, Menus;

type

  { TSchemeManagerForm }

  // the registered color schemes; user schemes can be renamed and deleted
  TSchemeManagerForm = class(TForm)
    ListSchemes: TListView;
    EditRename: TEdit;
    PanelButtons: TPanel;
    ButtonCreate: TButton;
    ButtonClose: TButton;
    PopupScheme: TPopupMenu;
    ItemApply: TMenuItem;
    ItemRename: TMenuItem;
    ItemDelete: TMenuItem;
    procedure FormCreate({%H-}Sender: TObject);
    procedure FormActivate({%H-}Sender: TObject);
    procedure FormClose({%H-}Sender: TObject; var CloseAction: TCloseAction);
    procedure ListSchemesColumnClick({%H-}Sender: TObject; Column: TListColumn);
    procedure ListSchemesDblClick({%H-}Sender: TObject);
    procedure ListSchemesKeyDown({%H-}Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PopupSchemePopup({%H-}Sender: TObject);
    procedure ItemApplyClick({%H-}Sender: TObject);
    procedure ItemRenameClick({%H-}Sender: TObject);
    procedure ItemDeleteClick({%H-}Sender: TObject);
    procedure EditRenameKeyDown({%H-}Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
    procedure EditRenameExit({%H-}Sender: TObject);
    procedure ButtonCreateClick({%H-}Sender: TObject);
    procedure ButtonCloseClick({%H-}Sender: TObject);
  private
    fSortColumn: integer; // -1 keeps the registration order
    fSortDescending: boolean;
    fRenaming: string; // the scheme whose name is being edited
    procedure fill(const selectName: string);
    function selectedName: string;
    function selectedIsUserScheme: boolean;
    procedure finishRename(commit: boolean);
  end;

// shows the single manager window
procedure showSchemeManager;

implementation

uses
  SysUtils, Math, Dialogs, LCLType, LazFileUtils, Laz2_XMLCfg, Laz2_DOM, EditorOptions, LazarusIDEStrConsts, SchemeMenu, SchemeCreator, SchemeIdeColors;

{$R *.lfm}

const
  SCHEME_PATH = 'Lazarus/ColorSchemes/';
  COLUMN_NUMBER = 0;
  COLUMN_NAME = 1;
  COLUMN_BUILT_IN = 2;
  COLUMN_MODIFIED = 3;

type
  TSchemeRow = record
    index: integer; // place in the registered list, shown as the number
    name: string;
    builtIn: boolean;
    modified: TDateTime; // of the scheme file, 0 without one
  end;

var
  manager: TSchemeManagerForm = nil;

function schemeKey(const name: string): string;
begin
  result := 'Scheme'+validXmlName(name);
end;

// a scheme stores its colors in one element per group (Globals, Lang<x>, IdeColors); an empty newKey removes them
procedure renameSchemeElements(cfg: TRttiXMLConfig; const oldKey, newKey: string);
begin
  var root := cfg.FindNode(SCHEME_PATH, false);
  if root = nil then exit;
  var group := root.FirstChild;
  while group <> nil do begin
    var old := group.FindNode(oldKey);
    if old <> nil then begin
      if newKey = '' then group.RemoveChild(old).Free
      else if newKey <> oldKey then begin
        var renamed := cfg.Document.CreateElement(newKey);
        while old.FirstChild <> nil do renamed.AppendChild(old.FirstChild);
        for var i := 0 to old.Attributes.Length-1 do renamed.SetAttribute(old.Attributes.Item[i].NodeName, old.Attributes.Item[i].NodeValue);
        group.ReplaceChild(renamed, old).Free;
      end;
    end;
    group := group.NextSibling;
  end;
  cfg.InvalidatePathCache;
  cfg.Modified := true;
end;

procedure readNames(cfg: TRttiXMLConfig; names: TStrings);
begin
  for var i := 1 to cfg.GetValue(SCHEME_PATH+'Names/Count', 0) do names.Add(cfg.GetValue(SCHEME_PATH+$'Names/Item{i}/Value', ''));
end;

procedure writeNames(cfg: TRttiXMLConfig; names: TStrings);
begin
  cfg.DeletePath(SCHEME_PATH+'Names');
  cfg.SetValue(SCHEME_PATH+'Names/Count', names.Count);
  for var i := 1 to names.Count do cfg.SetValue(SCHEME_PATH+$'Names/Item{i}/Value', names[i-1]);
end;

// renames a user scheme in its file, and the file after it when it holds that scheme alone; returns an error text
function renameScheme(const oldName, newName: string): string;
begin
  result := '';
  var name := Trim(newName);
  if name = '' then exit(lisSchemeCreatorNameEmpty);
  if name = oldName then exit;
  var scheme := ColorSchemeFactory.ColorSchemeGroup[oldName];
  if scheme is not TColorSchemeFromFile then exit;
  var other := ColorSchemeFactory.ColorSchemeGroup[name];
  if (other <> nil) and (other <> scheme) then exit(Format(lisSchemeManagerNameTaken, [name]));
  var fileName := TColorSchemeFromFile(scheme).FileName;
  var cfg := autofree TRttiXMLConfig.Create(fileName);
  var names := autofree TStringList.Create;
  readNames(cfg, names);
  var newFile := fileName;
  if names.Count = 1 then newFile := ExtractFilePath(fileName)+validXmlName(name)+'.xml';
  if not SameText(newFile, fileName) and FileExistsUTF8(newFile) then exit(Format(lisSchemeManagerNameTaken, [name]));
  var active := EditorOpts.ReadPascalColorScheme = oldName;
  renameSchemeElements(cfg, schemeKey(oldName), schemeKey(name));
  names[names.IndexOf(oldName)] := name;
  writeNames(cfg, names);
  cfg.Flush;
  if (newFile <> fileName) and not RenameFileUTF8(fileName, newFile) then newFile := fileName;
  ColorSchemeFactory.UnregisterScheme(oldName);
  EditorOpts.UserColorSchemeGroup.UnregisterScheme(oldName);
  registerUserScheme(cfg, newFile, name);
  renameSchemeMenuItem(oldName, name);
  if active then activateColorScheme(name);
end;

// removes a user scheme with its file, or from its file when the file holds more schemes
procedure deleteScheme(const name: string);
begin
  var scheme := ColorSchemeFactory.ColorSchemeGroup[name];
  if scheme is not TColorSchemeFromFile then exit;
  var fileName := TColorSchemeFromFile(scheme).FileName;
  var active := EditorOpts.ReadPascalColorScheme = name;
  var cfg := autofree TRttiXMLConfig.Create(fileName);
  var names := autofree TStringList.Create;
  readNames(cfg, names);
  if names.Count <= 1 then DeleteFileUTF8(fileName)
  else begin
    renameSchemeElements(cfg, schemeKey(name), '');
    names.Delete(names.IndexOf(name));
    writeNames(cfg, names);
    cfg.Flush;
  end;
  ColorSchemeFactory.UnregisterScheme(name);
  EditorOpts.UserColorSchemeGroup.UnregisterScheme(name);
  removeSchemeMenuItem(name);
  if active then activateColorScheme(DefaultColorSchemeName);
end;

procedure showSchemeManager;
begin
  if manager = nil then manager := TSchemeManagerForm.Create(Application);
  manager.Show;
  manager.BringToFront;
end;

{ TSchemeManagerForm }

procedure TSchemeManagerForm.FormCreate(Sender: TObject);
begin
  Caption := lisSchemeManagerTitle;
  ListSchemes.Columns[COLUMN_NAME].Caption := lisSchemeManagerName;
  ListSchemes.Columns[COLUMN_BUILT_IN].Caption := lisSchemeManagerBuiltIn;
  ListSchemes.Columns[COLUMN_MODIFIED].Caption := lisSchemeManagerModified;
  ItemApply.Caption := lisSchemeManagerApply;
  ItemRename.Caption := lisSchemeManagerRename;
  ItemDelete.Caption := lisSchemeManagerDelete;
  ButtonCreate.Caption := lisSchemeManagerCreate;
  ButtonClose.Caption := lisClose;
  fSortColumn := -1;
  fill(EditorOpts.ReadPascalColorScheme);
end;

// schemes saved by the creator meanwhile show up
procedure TSchemeManagerForm.FormActivate(Sender: TObject);
begin
  if fRenaming = '' then fill(selectedName);
end;

procedure TSchemeManagerForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  manager := nil;
  CloseAction := caFree;
end;

function compareRows(const a, b: TSchemeRow; column: integer): integer;
begin
  match column of
    COLUMN_NAME: result := CompareText(a.name, b.name);
    COLUMN_BUILT_IN: result := ord(a.builtIn)-ord(b.builtIn);
    COLUMN_MODIFIED: result := CompareValue(a.modified, b.modified);
    _: result := a.index-b.index;
  end;
end;

// the number is the place in the registered list, so it stays with its scheme when sorted
procedure TSchemeManagerForm.fill(const selectName: string);
begin
  var names := autofree TStringList.Create;
  ColorSchemeFactory.GetRegisteredSchemes(names);
  var rows: array of TSchemeRow;
  SetLength(rows, names.Count);
  for var i := 0 to high(rows) do begin
    rows[i].index := i;
    rows[i].name := names[i];
    var scheme := ColorSchemeFactory.ColorSchemeGroup[names[i]];
    rows[i].builtIn := scheme is not TColorSchemeFromFile;
    rows[i].modified := 0;
    if rows[i].builtIn then continue;
    var age := FileAgeUTF8(TColorSchemeFromFile(scheme).FileName);
    if age <> -1 then rows[i].modified := FileDateToDateTime(age);
  end;
  if fSortColumn >= 0 then
    // insertion sort, stable, so equal values keep the registered order
    for var i := 1 to high(rows) do begin
      var j := i;
      while j > 0 do begin
        var diff := compareRows(rows[j-1], rows[j], fSortColumn);
        if fSortDescending then diff := -diff;
        if diff <= 0 then break;
        var swap := rows[j];
        rows[j] := rows[j-1];
        rows[j-1] := swap;
        dec(j);
      end;
    end;
  ListSchemes.Items.BeginUpdate;
  defer ListSchemes.Items.EndUpdate;
  ListSchemes.Items.Clear;
  for var row in rows do begin
    var item := ListSchemes.Items.Add;
    item.Caption := IntToStr(row.index+1);
    item.SubItems.Add(row.name);
    item.SubItems.Add(if row.builtIn then lisSchemeManagerYes else '-');
    item.SubItems.Add(if row.modified = 0 then '-' else FormatDateTime('yyyy-mm-dd hh:nn', row.modified));
    if row.name = selectName then begin
      item.Selected := true;
      item.Focused := true;
    end;
  end;
  for var i := 0 to ListSchemes.Columns.Count-1 do
    ListSchemes.Columns[i].SortIndicator := if i <> fSortColumn then siNone else if fSortDescending then siDescending else siAscending;
end;

function TSchemeManagerForm.selectedName: string;
begin
  result := '';
  if ListSchemes.Selected <> nil then result := ListSchemes.Selected.SubItems[0];
end;

// each click on a column goes ascending, descending, unsorted
procedure TSchemeManagerForm.ListSchemesColumnClick(Sender: TObject; Column: TListColumn);
begin
  finishRename(false);
  if fSortColumn <> Column.Index then begin
    fSortColumn := Column.Index;
    fSortDescending := false;
  end else if not fSortDescending then fSortDescending := true
  else fSortColumn := -1;
  fill(selectedName);
end;

procedure TSchemeManagerForm.ListSchemesDblClick(Sender: TObject);
begin
  if selectedName <> '' then activateColorScheme(selectedName);
end;

procedure TSchemeManagerForm.ListSchemesKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key <> VK_F2) or (Shift <> []) or not selectedIsUserScheme then exit;
  Key := 0;
  ItemRenameClick(nil);
end;

// built-in schemes come back on every start, so only user schemes are renamed or deleted
function TSchemeManagerForm.selectedIsUserScheme: boolean;
begin
  var name := selectedName;
  result := (name <> '') and (ColorSchemeFactory.ColorSchemeGroup[name] is TColorSchemeFromFile);
end;

procedure TSchemeManagerForm.PopupSchemePopup(Sender: TObject);
begin
  ItemApply.Enabled := selectedName <> '';
  ItemRename.Enabled := selectedIsUserScheme;
  ItemDelete.Enabled := selectedIsUserScheme;
end;

procedure TSchemeManagerForm.ItemApplyClick(Sender: TObject);
begin
  activateColorScheme(selectedName);
end;

// an edit box over the name cell; Enter renames, Esc or leaving it cancels
procedure TSchemeManagerForm.ItemRenameClick(Sender: TObject);
begin
  var item := ListSchemes.Selected;
  if item = nil then exit;
  fRenaming := item.SubItems[0];
  item.MakeVisible(false);
  EditRename.Parent := ListSchemes;
  EditRename.BoundsRect := item.DisplayRectSubItem(COLUMN_NAME, drBounds);
  EditRename.Text := fRenaming;
  EditRename.Visible := true;
  EditRename.SetFocus;
  EditRename.SelectAll;
end;

procedure TSchemeManagerForm.ItemDeleteClick(Sender: TObject);
begin
  var name := selectedName;
  if name = '' then exit;
  if MessageDlg(lisSchemeManagerTitle, Format(lisSchemeManagerDeleteAsk, [name]), mtConfirmation, [mbYes, mbNo, mbCancel], 0) <> mrYes then exit;
  deleteScheme(name);
  fill(EditorOpts.ReadPascalColorScheme);
end;

procedure TSchemeManagerForm.EditRenameKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  match Key of
    VK_RETURN: finishRename(true);
    VK_ESCAPE: finishRename(false);
    _: exit;
  end;
  Key := 0;
end;

procedure TSchemeManagerForm.EditRenameExit(Sender: TObject);
begin
  finishRename(false);
end;

procedure TSchemeManagerForm.finishRename(commit: boolean);
begin
  if fRenaming = '' then exit;
  var oldName := fRenaming;
  // cleared first: hiding the box moves the focus and calls this again
  fRenaming := '';
  EditRename.Visible := false;
  if ListSchemes.CanFocus then ListSchemes.SetFocus;
  if not commit then exit;
  var error := renameScheme(oldName, EditRename.Text);
  if error <> '' then MessageDlg(lisSchemeManagerTitle, error, mtError, [mbOK], 0);
  fill(if error = '' then Trim(EditRename.Text) else oldName);
end;

procedure TSchemeManagerForm.ButtonCreateClick(Sender: TObject);
begin
  showSchemeCreator;
end;

procedure TSchemeManagerForm.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
