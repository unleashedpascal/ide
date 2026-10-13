{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit FolderTree;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ComCtrls, ControlPaint;

type
  TFolderEvent = procedure(Sender: TObject; const path: string) of object;
  // a folder is about to show; show false leaves it out
  TFolderFilterEvent = procedure(Sender: TObject; const path: string; var show: boolean) of object;

  { TFolderTree }

  // the folders under a root as a tree, read as they open. The root is
  // a path given by the application, so the tree looks and behaves the
  // same on every system; a selection names a path, a double click opens
  TFolderTree = class(TCustomTreeView)
  private
    FRoot: string;
    FShowHidden, FShowRoot, FShowFiles, FLoading: boolean;
    FFileMask: string;
    FFolderColor, FFileColor: TColor;
    FOnFolderChange: TFolderEvent;
    FOnFilter: TFolderFilterEvent;
    procedure setRoot(const value: string);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setFileMask(const value: string);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure fill(node: TTreeNode; const path: string);
    function nodePath(node: TTreeNode): string;
    function isHidden(const info: TSearchRec; const path: string): boolean;
    function matchesMask(const name: string): boolean;
  protected
    function CanExpand(Node: TTreeNode): Boolean; override;
    procedure Change(Node: TTreeNode); override;
    procedure Loaded; override;
    procedure AdvancedCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean); // the icons of folders and files
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // reads the tree again from the root
    procedure Refresh;
    // reads the children of the selected folder again
    procedure RefreshSelected;
    // opens the tree down to a path and selects it
    function SelectPath(const path: string): boolean;
    // the path of the selected node, or the root
    function SelectedPath: string;
    function SelectedIsFolder: boolean;
    // the path of any node
    function PathOf(node: TTreeNode): string;
  published
    // the folder the tree starts at; empty takes the current directory
    property Root: string read FRoot write setRoot;
    property ShowHidden: boolean index 0 read getFlag write setFlag default false;
    // the root as the top node, or its children at the top
    property ShowRoot: boolean index 1 read getFlag write setFlag default true;
    // files under their folders, too
    property ShowFiles: boolean index 2 read getFlag write setFlag default false;
    // the files shown, like *.pas;*.inc
    property FileMask: string read FFileMask write setFileMask;
    // clDefault takes the colors of the theme
    property FolderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FileColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // the selection moved to another folder or file
    property OnFolderChange: TFolderEvent read FOnFolderChange write FOnFolderChange;
    property OnFilter: TFolderFilterEvent read FOnFilter write FOnFilter;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property Indent;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ReadOnly default true;
    property RowSelect;
    property ScrollBars;
    property ShowButtons;
    property ShowHint;
    property ShowLines;
    property TabOrder;
    property TabStop default true;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnSelectionChanged;
  end;

implementation

uses
  Math, Masks;

const
  // the hidden attribute of the systems that have one; a dot does the rest
  HIDDEN_ATTR = $2;

constructor TFolderTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FShowRoot := true;
  FFileMask := '*';
  FFolderColor := clDefault;
  FFileColor := clDefault;
  ReadOnly := true;
  TabStop := true;
  Options := Options+[tvoReadOnly, tvoRowSelect]-[tvoAllowMultiselect];
  OnAdvancedCustomDrawItem := @AdvancedCustomDrawItem;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TFolderTree.GetControlClassDefaultSize: TSize;
begin
  result.cx := 220;
  result.cy := 260;
end;

procedure TFolderTree.Loaded;
begin
  inherited Loaded;
  if not (csDesigning in ComponentState) then Refresh;
end;

// -- reading ----------------------

function TFolderTree.isHidden(const info: TSearchRec; const path: string): boolean;
begin
  // a leading dot hides on every system; the hidden attribute where it exists
  result := (info.Name <> '') and (info.Name[1] = '.');
  if (info.Attr and HIDDEN_ATTR) <> 0 then result := true;
end;

function TFolderTree.matchesMask(const name: string): boolean;
begin
  result := (FFileMask = '') or (FFileMask = '*') or MatchesMaskList(name, FFileMask, ';');
end;

// the entries of a path as children of a node; a folder with children of
// its own gets a placeholder so it shows the expand button
procedure TFolderTree.fill(node: TTreeNode; const path: string);
begin
  var info: TSearchRec;
  var dir := IncludeTrailingPathDelimiter(path);
  var folders := autofree TStringList.Create;
  var files := autofree TStringList.Create;
  folders.Sorted := true;
  files.Sorted := true;
  folders.CaseSensitive := false;
  files.CaseSensitive := false;
  if FindFirst(dir+'*', faAnyFile, info) = 0 then begin
    repeat
      if (info.Name = '.') or (info.Name = '..') then continue;
      if not FShowHidden and isHidden(info, dir) then continue;
      if (info.Attr and faDirectory) <> 0 then begin
        var show := true;
        if Assigned(FOnFilter) then FOnFilter(self, dir+info.Name, show);
        if show then folders.Add(info.Name);
      end else if FShowFiles and matchesMask(info.Name) then files.Add(info.Name);
    until FindNext(info) <> 0;
    FindClose(info);
  end;
  for var i := 0 to folders.Count-1 do begin
    var child := if node = nil then Items.Add(nil, folders[i]) else Items.AddChild(node, folders[i]);
    child.ImageIndex := 0;
    child.Data := Pointer(1); // a folder not read yet
    child.HasChildren := true;
  end;
  for var i := 0 to files.Count-1 do begin
    var child := if node = nil then Items.Add(nil, files[i]) else Items.AddChild(node, files[i]);
    child.ImageIndex := 1;
    child.Data := Pointer(2);
  end;
end;

function TFolderTree.CanExpand(Node: TTreeNode): Boolean;
begin
  result := inherited CanExpand(Node);
  if not result or (Node.Data <> Pointer(1)) then exit;
  // the first expansion reads the folder
  Items.BeginUpdate;
  try
    Node.DeleteChildren;
    fill(Node, nodePath(Node));
    Node.Data := Pointer(3); // read
    Node.HasChildren := Node.Count > 0;
  finally
    Items.EndUpdate;
  end;
end;

procedure TFolderTree.Refresh;
begin
  if csDesigning in ComponentState then exit;
  FLoading := true;
  Items.BeginUpdate;
  try
    Items.Clear;
    var root := FRoot;
    if root = '' then root := GetCurrentDir;
    root := ExcludeTrailingPathDelimiter(ExpandFileName(root));
    if not DirectoryExists(root) then exit;
    if FShowRoot then begin
      var top := Items.Add(nil, (if ExtractFileName(root) <> '' then ExtractFileName(root) else root));
      top.ImageIndex := 0;
      top.Data := Pointer(3);
      fill(top, root);
      top.HasChildren := top.Count > 0;
      top.Expand(false);
    end else fill(nil, root);
  finally
    Items.EndUpdate;
    FLoading := false;
  end;
end;

procedure TFolderTree.RefreshSelected;
begin
  var node := Selected;
  if (node = nil) or (node.Data = Pointer(2)) then exit;
  Items.BeginUpdate;
  try
    node.DeleteChildren;
    fill(node, nodePath(node));
    node.Data := Pointer(3);
    node.HasChildren := node.Count > 0;
    node.Expand(false);
  finally
    Items.EndUpdate;
  end;
end;

// -- paths ----------------------

function TFolderTree.nodePath(node: TTreeNode): string;
begin
  var root := FRoot;
  if root = '' then root := GetCurrentDir;
  root := ExcludeTrailingPathDelimiter(ExpandFileName(root));
  result := '';
  var n := node;
  while n <> nil do begin
    if FShowRoot and (n.Parent = nil) then break;
    result := if result = '' then n.Text else n.Text+PathDelim+result;
    n := n.Parent;
  end;
  result := if result = '' then root else root+PathDelim+result;
end;

function TFolderTree.PathOf(node: TTreeNode): string;
begin
  result := if node = nil then '' else nodePath(node);
end;

function TFolderTree.SelectedPath: string;
begin
  result := if Selected = nil then nodePath(nil) else nodePath(Selected);
end;

function TFolderTree.SelectedIsFolder: boolean;
begin
  result := (Selected = nil) or (Selected.Data <> Pointer(2));
end;

function TFolderTree.SelectPath(const path: string): boolean;
begin
  result := false;
  var root := ExcludeTrailingPathDelimiter(ExpandFileName(if FRoot = '' then GetCurrentDir else FRoot));
  var full := ExcludeTrailingPathDelimiter(ExpandFileName(path));
  if not SameFileName(Copy(full, 1, length(root)), root) then exit;
  var rest := Copy(full, length(root)+2, MaxInt);
  var node: TTreeNode := if FShowRoot then Items.GetFirstNode else nil;
  if (node <> nil) and (rest <> '') then node.Expand(false);
  while rest <> '' do begin
    var cut := Pos(PathDelim, rest);
    var part := if cut > 0 then Copy(rest, 1, cut-1) else rest;
    rest := if cut > 0 then Copy(rest, cut+1, MaxInt) else '';
    if part = '' then continue;
    var child := if node = nil then Items.GetFirstNode else node.GetFirstChild;
    var found: TTreeNode := nil;
    while child <> nil do begin
      if SameFileName(child.Text, part) then begin found := child; break; end;
      child := child.GetNextSibling;
    end;
    if found = nil then exit;
    found.Expand(false);
    node := found;
  end;
  if node = nil then exit;
  Selected := node;
  node.MakeVisible;
  result := true;
end;

procedure TFolderTree.Change(Node: TTreeNode);
begin
  inherited Change(Node);
  if FLoading or (csLoading in ComponentState) then exit;
  if Assigned(FOnFolderChange) then FOnFolderChange(self, nodePath(Node));
end;

// -- painting ----------------------

// a small folder or file glyph in front of the caption, in the theme colors
procedure TFolderTree.AdvancedCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
begin
  DefaultDraw := true;
  if Stage <> cdPostPaint then exit;
  var r := Node.DisplayRect(true);
  var size := Max(Canvas.TextHeight('0')-2, 8);
  var x := r.Left-size-4;
  var y := r.Top+(r.Height-size) div 2;
  if x < 0 then exit;
  var sp := autofree beginShapes(Canvas, Rect(x-1, y-1, x+size+1, y+size+1), Color, asTheme);
  if Node.Data = Pointer(2) then begin
    var c := pick(FFileColor, blend(clWindowText, clWindow, 35));
    paintRoundRect(sp, Rect(x+size div 5, y, x+size-size div 5, y+size), 1, clNone, c, 1);
    sp.FillRect(Rect(x+size div 5+2, y+size div 2, x+size-size div 5-2, y+size div 2+1), c);
  end else begin
    var c := pick(FFolderColor, $3B8BD9);
    sp.FillRoundRect(x, y+1, x+size*0.45, y+size*0.35, 1, c);
    sp.FillRoundRect(x, y+size*0.25, x+size, y+size, 1.5, c);
  end;
  sp.Flush;
end;

// -- properties ----------------------

procedure TFolderTree.setRoot(const value: string);
begin
  if FRoot = value then exit;
  FRoot := value;
  Refresh;
end;

function TFolderTree.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowHidden;
    1: FShowRoot;
  else
    FShowFiles
  end;
end;

procedure TFolderTree.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowHidden := value;
    1: FShowRoot := value;
  else
    FShowFiles := value;
  end;
  Refresh;
end;

procedure TFolderTree.setFileMask(const value: string);
begin
  if FFileMask = value then exit;
  FFileMask := value;
  if FShowFiles then Refresh;
end;

function TFolderTree.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FFolderColor else FFileColor;
end;

procedure TFolderTree.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FFolderColor := value else FFileColor := value;
  Invalidate;
end;

end.
