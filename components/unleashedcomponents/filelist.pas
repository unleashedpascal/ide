{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit FileList;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint, DataTable;

type
  TFileSort = (fsName, fsSize, fsModified, fsType);
  TFileEvent = procedure(Sender: TObject; const path: string) of object;
  // the color of the type mark of a file; comes in from the extension
  TFileColorEvent = procedure(Sender: TObject; const path: string; var color: TColor) of object;

  { TFileList }

  // the files of one folder as rows: name, size, modified, type, with a
  // colored mark per extension, a mask, sorting by any column and a
  // double click that opens. Built on TDataTable, so it sorts, filters
  // and selects like one
  TFileList = class(TDataTable)
  private
    FFolder, FMask: string;
    FShowHidden, FShowFolders, FShowSize, FShowModified, FShowType, FShowParent, FAutoRefresh: boolean;
    FPaths: array of string;
    FOnFileOpen, FOnFolderChange: TFileEvent;
    FOnFileColor: TFileColorEvent;
    procedure setFolder(const value: string);
    procedure setMask(const value: string);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure buildColumns;
    function sizeText(size: int64): string;
    function typeColor(const name: string; isFolder: boolean): TColor;
    procedure cellColors(Sender: TObject; row, column: integer; var back, text: TColor);
    procedure rowDblClick(Sender: TObject; row, column: integer);
    procedure compareRows(Sender: TObject; column, rowA, rowB: integer; var result: integer);
  protected
    procedure Loaded; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Refresh;
    // the path of a shown row
    function PathOf(row: integer): string;
    // the path of the focused row, empty for none
    function SelectedPath: string;
    // the selected paths
    procedure SelectedPaths(list: TStrings);
    // opens the folder or fires OnFileOpen for the focused row
    procedure OpenSelected;
    // one folder up
    procedure GoUp;
  published
    property Folder: string read FFolder write setFolder;
    // the files shown, like *.pas;*.inc
    property Mask: string read FMask write setMask;
    property ShowHidden: boolean index 0 read getFlag write setFlag default false;
    property ShowFolders: boolean index 1 read getFlag write setFlag default true;
    property ShowSize: boolean index 2 read getFlag write setFlag default true;
    property ShowModified: boolean index 3 read getFlag write setFlag default true;
    property ShowType: boolean index 4 read getFlag write setFlag default true;
    // a ".." row that goes up
    property ShowParent: boolean index 5 read getFlag write setFlag default true;
    // a double click on a file
    property OnFileOpen: TFileEvent read FOnFileOpen write FOnFileOpen;
    // the list moved into another folder
    property OnFolderChange: TFileEvent read FOnFolderChange write FOnFolderChange;
    property OnFileColor: TFileColorEvent read FOnFileColor write FOnFileColor;
  end;

implementation

uses
  Math, Masks, LCLType, DateUtils;

const
  HIDDEN_ATTR = $2; // the hidden attribute where the system has one

constructor TFileList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMask := '*';
  FShowFolders := true;
  FShowSize := true;
  FShowModified := true;
  FShowType := true;
  FShowParent := true;
  OnGetCellColors := @cellColors;
  OnCellDblClick := @rowDblClick;
  OnCompare := @compareRows;
  buildColumns;
end;

class function TFileList.GetControlClassDefaultSize: TSize;
begin
  result.cx := 480;
  result.cy := 220;
end;

procedure TFileList.Loaded;
begin
  inherited Loaded;
  if not (csDesigning in ComponentState) then Refresh;
end;

procedure TFileList.buildColumns;
begin
  Columns.BeginUpdate;
  try
    Columns.Clear;
    with Columns.Add do begin Caption := 'Name'; Width := 220; AutoWidth := true; end;
    with Columns.Add do begin Caption := 'Size'; Width := 80; Alignment := taRightJustify; Visible := FShowSize; end;
    with Columns.Add do begin Caption := 'Modified'; Width := 130; Visible := FShowModified; end;
    with Columns.Add do begin Caption := 'Type'; Width := 70; Visible := FShowType; end;
  finally
    Columns.EndUpdate;
  end;
end;

// -- reading ----------------------

function TFileList.sizeText(size: int64): string;
begin
  var fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  if size < 1024 then exit(IntToStr(size)+' B');
  if size < 1024*1024 then exit(FormatFloat('0.#', size/1024, fs)+' KB');
  if size < 1024*1024*1024 then exit(FormatFloat('0.#', size/1024/1024, fs)+' MB');
  result := FormatFloat('0.##', size/1024/1024/1024, fs)+' GB';
end;

procedure TFileList.Refresh;
begin
  if csDesigning in ComponentState then exit;
  var dir := FFolder;
  if dir = '' then dir := GetCurrentDir;
  dir := IncludeTrailingPathDelimiter(ExpandFileName(dir));
  ClearRows;
  FPaths := nil;
  if not DirectoryExists(dir) then exit;
  var info: TSearchRec;
  var parentDir := ExtractFilePath(ExcludeTrailingPathDelimiter(dir));
  if FShowParent and (parentDir <> '') and (parentDir <> dir) then begin
    AddRow(['..', '', '', 'Folder']);
    SetLength(FPaths, length(FPaths)+1);
    FPaths[high(FPaths)] := ExcludeTrailingPathDelimiter(parentDir);
  end;
  if FindFirst(dir+'*', faAnyFile, info) = 0 then begin
    repeat
      if (info.Name = '.') or (info.Name = '..') then continue;
      var hidden := ((info.Attr and HIDDEN_ATTR) <> 0) or (info.Name[1] = '.');
      if hidden and not FShowHidden then continue;
      var isFolder := (info.Attr and faDirectory) <> 0;
      if isFolder and not FShowFolders then continue;
      if not isFolder and (FMask <> '') and (FMask <> '*') and not MatchesMaskList(info.Name, FMask, ';') then continue;
      var ext := LowerCase(Copy(ExtractFileExt(info.Name), 2, MaxInt));
      var modified := FormatDateTime('yyyy-mm-dd hh:nn', FileDateToDateTime(info.Time));
      AddRow([info.Name, (if isFolder then '' else sizeText(info.Size)), modified, (if isFolder then 'Folder' else ext)], (if isFolder then 1 else 0));
      SetLength(FPaths, length(FPaths)+1);
      FPaths[high(FPaths)] := dir+info.Name;
    until FindNext(info) <> 0;
    FindClose(info);
  end;
  if SortColumn < 0 then SortColumn := 0;
end;

function TFileList.PathOf(row: integer): string;
begin
  result := if (row >= 0) and (row < length(FPaths)) then FPaths[row] else '';
end;

function TFileList.SelectedPath: string;
begin
  var row := ShownRow(FocusedIndex);
  result := PathOf(row);
end;

procedure TFileList.SelectedPaths(list: TStrings);
begin
  for var i := 0 to RowCount-1 do if Selected[i] then list.Add(PathOf(i));
end;

procedure TFileList.OpenSelected;
begin
  var row := ShownRow(FocusedIndex);
  if row < 0 then exit;
  var path := PathOf(row);
  if path = '' then exit;
  if DirectoryExists(path) then Folder := path
  else if Assigned(FOnFileOpen) then FOnFileOpen(self, path);
end;

procedure TFileList.GoUp;
begin
  var dir := ExcludeTrailingPathDelimiter(ExpandFileName(if FFolder = '' then GetCurrentDir else FFolder));
  var parent := ExcludeTrailingPathDelimiter(ExtractFilePath(dir));
  if (parent <> '') and (parent <> dir) then Folder := parent;
end;

// -- sorting and colors ----------------------

// folders first, then the column; sizes and dates compare by value
procedure TFileList.compareRows(Sender: TObject; column, rowA, rowB: integer; var result: integer);
begin
  var a := Cells[0, rowA];
  var b := Cells[0, rowB];
  if a = '..' then begin result := -1; exit; end;
  if b = '..' then begin result := 1; exit; end;
  var folderA := RowTags[rowA] = 1;
  var folderB := RowTags[rowB] = 1;
  if folderA <> folderB then begin result := if folderA then -1 else 1; exit; end;
  match column of
    1: begin
      var pa := PathOf(rowA);
      var pb := PathOf(rowB);
      var sa: int64 := 0;
      var sb: int64 := 0;
      var info: TSearchRec;
      if FindFirst(pa, faAnyFile, info) = 0 then begin sa := info.Size; FindClose(info); end;
      if FindFirst(pb, faAnyFile, info) = 0 then begin sb := info.Size; FindClose(info); end;
      result := CompareValue(sa, sb);
    end;
    2: result := CompareText(Cells[2, rowA], Cells[2, rowB]);
    3: result := CompareText(Cells[3, rowA], Cells[3, rowB]);
  else
    result := CompareText(a, b);
  end;
  if result = 0 then result := CompareText(a, b);
end;

function TFileList.typeColor(const name: string; isFolder: boolean): TColor;
begin
  if isFolder then exit($3B8BD9);
  var ext := LowerCase(Copy(ExtractFileExt(name), 2, MaxInt));
  result := match ext of
    'pas', 'pp', 'inc', 'lpr', 'dpr': $5CB85C;
    'c', 'cpp', 'h', 'hpp', 'rs', 'go', 'js', 'ts', 'py', 'java', 'cs': $4EADF0;
    'txt', 'md', 'rst', 'log', 'ini', 'cfg', 'json', 'xml', 'yaml', 'yml', 'toml': $B35CA0;
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg', 'ico', 'webp': $17A2B8;
    'zip', '7z', 'rar', 'gz', 'tar', 'xz': $D98B3B;
    'exe', 'dll', 'so', 'dylib', 'o', 'ppu', 'a': $6C757D;
    'lfm', 'lpi', 'lpk', 'lps': $D9534F;
  else
    blend(clWindowText, clWindow, 50)
  end;
end;

procedure TFileList.cellColors(Sender: TObject; row, column: integer; var back, text: TColor);
begin
  if column <> 0 then exit;
  if RowTags[row] = 1 then text := blend(ColorToRGB(clWindowText), $3B8BD9, 30);
end;

procedure TFileList.rowDblClick(Sender: TObject; row, column: integer);
begin
  OpenSelected;
end;

procedure TFileList.KeyDown(var Key: Word; Shift: TShiftState);
begin
  match Key of
    VK_RETURN: begin OpenSelected; Key := 0; exit; end;
    VK_BACK: begin GoUp; Key := 0; exit; end;
    VK_F5: begin Refresh; Key := 0; exit; end;
  end;
  inherited KeyDown(Key, Shift);
end;

// -- properties ----------------------

procedure TFileList.setFolder(const value: string);
begin
  if FFolder = value then exit;
  FFolder := value;
  Refresh;
  if not (csLoading in ComponentState) and Assigned(FOnFolderChange) then FOnFolderChange(self, ExcludeTrailingPathDelimiter(ExpandFileName(if FFolder = '' then GetCurrentDir else FFolder)));
end;

procedure TFileList.setMask(const value: string);
begin
  if FMask = value then exit;
  FMask := value;
  Refresh;
end;

function TFileList.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowHidden;
    1: FShowFolders;
    2: FShowSize;
    3: FShowModified;
    4: FShowType;
  else
    FShowParent
  end;
end;

procedure TFileList.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowHidden := value;
    1: FShowFolders := value;
    2: FShowSize := value;
    3: FShowModified := value;
    4: FShowType := value;
  else
    FShowParent := value;
  end;
  if index in [2, 3, 4] then begin
    if Columns.Count >= 4 then begin
      Columns[1].Visible := FShowSize;
      Columns[2].Visible := FShowModified;
      Columns[3].Visible := FShowType;
    end;
  end else Refresh;
end;

end.
