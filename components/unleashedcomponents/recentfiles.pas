{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RecentFiles;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Menus;

type
  TRecentFileEvent = procedure(Sender: TObject; const fileName: string) of object;

  { TRecentFiles }

  // the files opened last, newest first, as entries of a menu and as a
  // list kept in a file between the runs
  TRecentFiles = class(TComponent)
  private
    FItems: TStringList;
    FMaxItems, FMaxLength: integer;
    FMenuItem: TMenuItem;
    FStorageFile: string;
    FShowNumbers, FShowClearItem, FAutoSave, FDropMissing: boolean;
    FClearCaption: string;
    FOnOpen: TRecentFileEvent;
    FOnChange: TNotifyEvent;
    procedure setMenuItem(value: TMenuItem);
    procedure setMaxItems(value: integer);
    procedure setMaxLength(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setClearCaption(const value: string);
    function shortened(const path: string): string;
    procedure rebuildMenu;
    procedure entryClick(Sender: TObject);
    procedure clearClick(Sender: TObject);
    procedure changed;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // puts the file first
    procedure Add(const fileName: string);
    procedure Remove(const fileName: string);
    procedure Clear;
    procedure Load;
    procedure Save;
    function Count: integer;
    property Items: TStringList read FItems;
  published
    property MaxItems: integer read FMaxItems write setMaxItems default 10;
    // longer paths show their start and their end; 0 shows them whole
    property MaxLength: integer read FMaxLength write setMaxLength default 60;
    // the menu entry whose submenu lists the files
    property MenuItem: TMenuItem read FMenuItem write setMenuItem;
    // the list goes to this file; empty keeps it in memory only
    property StorageFile: string read FStorageFile write FStorageFile;
    property ShowNumbers: boolean index 0 read getFlag write setFlag default true;
    property ShowClearItem: boolean index 1 read getFlag write setFlag default true;
    // every change goes to the storage file at once
    property AutoSave: boolean index 2 read getFlag write setFlag default true;
    // files that no longer exist leave the list when it is loaded
    property DropMissing: boolean index 3 read getFlag write setFlag default true;
    property ClearCaption: string read FClearCaption write setClearCaption;
    property OnOpen: TRecentFileEvent read FOnOpen write FOnOpen;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses
  Math, LazFileUtils;

constructor TRecentFiles.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FMaxItems := 10;
  FMaxLength := 60;
  FShowNumbers := true;
  FShowClearItem := true;
  FAutoSave := true;
  FDropMissing := true;
  FClearCaption := 'Clear list';
end;

destructor TRecentFiles.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TRecentFiles.Loaded;
begin
  inherited Loaded;
  if not (csDesigning in ComponentState) then Load;
  rebuildMenu;
end;

// -- the list ----------------------

procedure TRecentFiles.Add(const fileName: string);
begin
  if fileName = '' then exit;
  var i := FItems.IndexOf(fileName);
  if i >= 0 then FItems.Delete(i);
  FItems.Insert(0, fileName);
  while (FMaxItems > 0) and (FItems.Count > FMaxItems) do FItems.Delete(FItems.Count-1);
  changed;
end;

procedure TRecentFiles.Remove(const fileName: string);
begin
  var i := FItems.IndexOf(fileName);
  if i < 0 then exit;
  FItems.Delete(i);
  changed;
end;

procedure TRecentFiles.Clear;
begin
  if FItems.Count = 0 then exit;
  FItems.Clear;
  changed;
end;

function TRecentFiles.Count: integer;
begin
  result := FItems.Count;
end;

procedure TRecentFiles.Load;
begin
  if (FStorageFile = '') or not FileExistsUTF8(FStorageFile) then exit;
  FItems.LoadFromFile(FStorageFile);
  for var i := FItems.Count-1 downto 0 do
    if (Trim(FItems[i]) = '') or (FDropMissing and not FileExistsUTF8(FItems[i])) then FItems.Delete(i);
  while (FMaxItems > 0) and (FItems.Count > FMaxItems) do FItems.Delete(FItems.Count-1);
  rebuildMenu;
  if Assigned(FOnChange) then FOnChange(self);
end;

procedure TRecentFiles.Save;
begin
  if FStorageFile = '' then exit;
  ForceDirectoriesUTF8(ExtractFilePath(FStorageFile));
  FItems.SaveToFile(FStorageFile);
end;

procedure TRecentFiles.changed;
begin
  rebuildMenu;
  if FAutoSave and not (csDesigning in ComponentState) and not (csLoading in ComponentState) then Save;
  if Assigned(FOnChange) then FOnChange(self);
end;

// -- the menu ----------------------

// a long path keeps its drive and its last parts
function TRecentFiles.shortened(const path: string): string;
begin
  result := path;
  if (FMaxLength <= 0) or (length(path) <= FMaxLength) then exit;
  var name := ExtractFileName(path);
  var head := Copy(path, 1, Max(FMaxLength-length(name)-4, 3));
  var cut := head.LastIndexOf(PathDelim);
  if cut > 0 then head := Copy(head, 1, cut+1);
  result := head+'...'+PathDelim+name;
end;

procedure TRecentFiles.rebuildMenu;
begin
  if FMenuItem = nil then exit;
  FMenuItem.Clear;
  for var i := 0 to FItems.Count-1 do begin
    var entry := TMenuItem.Create(FMenuItem);
    var text := shortened(FItems[i]);
    entry.Caption := if FShowNumbers and (i < 9) then '&'+IntToStr(i+1)+' '+text else text;
    entry.Hint := FItems[i];
    entry.Tag := i;
    entry.OnClick := @entryClick;
    FMenuItem.Add(entry);
  end;
  if FShowClearItem and (FItems.Count > 0) then begin
    var line := TMenuItem.Create(FMenuItem);
    line.Caption := '-';
    FMenuItem.Add(line);
    var clearItem := TMenuItem.Create(FMenuItem);
    clearItem.Caption := FClearCaption;
    clearItem.OnClick := @clearClick;
    FMenuItem.Add(clearItem);
  end;
  FMenuItem.Enabled := FItems.Count > 0;
end;

procedure TRecentFiles.entryClick(Sender: TObject);
begin
  var i := TMenuItem(Sender).Tag;
  if (i < 0) or (i >= FItems.Count) then exit;
  var name := FItems[i];
  if Assigned(FOnOpen) then FOnOpen(self, name);
end;

procedure TRecentFiles.clearClick(Sender: TObject);
begin
  Clear;
end;

procedure TRecentFiles.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FMenuItem) then FMenuItem := nil;
end;

// -- properties ----------------------

procedure TRecentFiles.setMenuItem(value: TMenuItem);
begin
  if FMenuItem = value then exit;
  if FMenuItem <> nil then FMenuItem.RemoveFreeNotification(self);
  FMenuItem := value;
  if FMenuItem <> nil then FMenuItem.FreeNotification(self);
  rebuildMenu;
end;

procedure TRecentFiles.setMaxItems(value: integer);
begin
  value := Max(value, 0);
  if FMaxItems = value then exit;
  FMaxItems := value;
  while (FMaxItems > 0) and (FItems.Count > FMaxItems) do FItems.Delete(FItems.Count-1);
  rebuildMenu;
end;

procedure TRecentFiles.setMaxLength(value: integer);
begin
  value := Max(value, 0);
  if FMaxLength = value then exit;
  FMaxLength := value;
  rebuildMenu;
end;

function TRecentFiles.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowNumbers;
    1: FShowClearItem;
    2: FAutoSave;
  else
    FDropMissing
  end;
end;

procedure TRecentFiles.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowNumbers := value;
    1: FShowClearItem := value;
    2: FAutoSave := value;
  else
    FDropMissing := value;
  end;
  rebuildMenu;
end;

procedure TRecentFiles.setClearCaption(const value: string);
begin
  if FClearCaption = value then exit;
  FClearCaption := value;
  rebuildMenu;
end;

end.
