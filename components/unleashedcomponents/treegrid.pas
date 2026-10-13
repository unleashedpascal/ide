{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit TreeGrid;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, StdCtrls, LCLType, ControlPaint;

type
  TTreeGrid = class;
  TTreeGridNode = class;
  TTreeGridCheck = (tcNone, tcUnchecked, tcChecked, tcMixed);
  TTreeGridNodeEvent = procedure(Sender: TObject; node: TTreeGridNode) of object;
  TTreeGridCellEvent = procedure(Sender: TObject; node: TTreeGridNode; column: integer) of object;
  // the text of a cell of a node that was not given one; for a virtual tree
  TTreeGridTextEvent = procedure(Sender: TObject; node: TTreeGridNode; column: integer; var text: string) of object;
  // a node is about to open the first time: the handler adds its children
  TTreeGridExpandEvent = procedure(Sender: TObject; node: TTreeGridNode; var allow: boolean) of object;
  TTreeGridEditEvent = procedure(Sender: TObject; node: TTreeGridNode; column: integer; var text: string; var accept: boolean) of object;
  TTreeGridCompareEvent = procedure(Sender: TObject; a, b: TTreeGridNode; column: integer; var result: integer) of object;
  // paints over a cell once its row is painted: dsSelected for the focused
  // row; `handled` true leaves the text out
  TTreeGridDrawCellEvent = procedure(Sender: TObject; canvas: TCanvas; const r: TRect; node: TTreeGridNode; column: integer; state: TDrawState; var handled: boolean) of object;

  { TTreeGridColumn }

  TTreeGridColumn = class(TCollectionItem)
  private
    FCaption: string;
    FWidth, FMinWidth: integer;
    FAlignment: TAlignment;
    FVisible, FSortable, FEditable, FAutoWidth: boolean;
    FTag: PtrInt;
    procedure setCaption(const value: string);
    procedure setWidth(value: integer);
    procedure setAlignment(value: TAlignment);
    procedure setFlag(index: integer; value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Caption: string read FCaption write setCaption;
    property Width: integer read FWidth write setWidth default 120;
    property MinWidth: integer read FMinWidth write FMinWidth default 24;
    property Alignment: TAlignment read FAlignment write setAlignment default taLeftJustify;
    property Visible: boolean index 0 read FVisible write setFlag default true;
    property Sortable: boolean index 1 read FSortable write setFlag default true;
    // a double click or F2 edits the cell in place
    property Editable: boolean index 2 read FEditable write setFlag default false;
    // the column takes the width that is left
    property AutoWidth: boolean index 3 read FAutoWidth write setFlag default false;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TTreeGridColumns }

  TTreeGridColumns = class(TOwnedCollection)
  private
    function getItem(index: integer): TTreeGridColumn;
    procedure setItem(index: integer; value: TTreeGridColumn);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TTreeGridColumn;
    property Items[index: integer]: TTreeGridColumn read getItem write setItem; default;
  end;

  { TTreeGridNode }

  // a row of the tree: the cells of its columns, its children, its state
  TTreeGridNode = class
  private
    FOwner: TTreeGrid;
    FParent: TTreeGridNode;
    FChildren: TList;
    FCells: array of string;
    FExpanded, FHasChildren, FLoaded: boolean;
    FCheck: TTreeGridCheck;
    FTag: PtrInt;
    FData: TObject;
    FImageIndex: integer;
    FColor: TColor;
    function getCell(column: integer): string;
    procedure setCell(column: integer; const value: string);
    function getChild(index: integer): TTreeGridNode;
    function getCount: integer;
    procedure setExpanded(value: boolean);
    procedure setCheck(value: TTreeGridCheck);
    procedure setHasChildren(value: boolean);
    procedure setColor(value: TColor);
  public
    constructor Create(owner: TTreeGrid; parent: TTreeGridNode);
    destructor Destroy; override;
    function AddChild(const cells: array of string): TTreeGridNode;
    procedure Clear;
    procedure Delete;
    function Level: integer;
    function Index: integer;
    function NextSibling: TTreeGridNode;
    function PreviousSibling: TTreeGridNode;
    // the node and every node under it
    function IsVisible: boolean;
    procedure Expand(recursive: boolean = false);
    procedure Collapse(recursive: boolean = false);
    property Cells[column: integer]: string read getCell write setCell; default;
    property Text: string index 0 read getCell write setCell;
    property Children[index: integer]: TTreeGridNode read getChild;
    property Count: integer read getCount;
    property Parent: TTreeGridNode read FParent;
    property Expanded: boolean read FExpanded write setExpanded;
    // shows the expand mark before any child is added, for loading on demand
    property HasChildren: boolean read FHasChildren write setHasChildren;
    property Check: TTreeGridCheck read FCheck write setCheck;
    property Tag: PtrInt read FTag write FTag;
    property Data: TObject read FData write FData;
    property ImageIndex: integer read FImageIndex write FImageIndex;
    // the row; clDefault takes the surface
    property Color: TColor read FColor write setColor;
    property Owner: TTreeGrid read FOwner;
  end;

  { TTreeGrid }

  // a tree whose rows have columns: an outline on the left, cells to the
  // right, a header that sorts and resizes, check boxes, in-place editing,
  // children loaded when a node opens. The kind of view a tree view with
  // columns would be, built once instead of faked with a list view
  TTreeGrid = class(TScrollingWinControl)
  private
    FColumns: TTreeGridColumns;
    FRoot: TTreeGridNode;
    FShown: array of TTreeGridNode;
    FFocus, FHot, FHotHeader, FSortColumn, FDragEdge, FDragX, FDragWidth: integer;
    FSortDescending, FShowHeader, FShowLines, FShowGridLines, FShowCheckBoxes, FAlternateRows, FRowSelect, FShowRoot, FReadOnly, FAutoCheck, FFullRowExpand: boolean;
    FRowHeight, FHeaderHeight, FIndent, FPadding: integer;
    FHeaderColor, FHeaderTextColor, FTextColor, FGridColor, FSelectedColor, FAlternateColor, FLineColor, FBackColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FEdit: TEdit;
    FEditing: TTreeGridNode;
    FEditColumn: integer;
    FRangeDirty: boolean;
    FOnSelect, FOnExpanded, FOnCollapsed, FOnChecked: TTreeGridNodeEvent;
    FOnCellClick, FOnCellDblClick, FOnHeaderClick: TTreeGridCellEvent;
    FOnGetText: TTreeGridTextEvent;
    FOnExpanding: TTreeGridExpandEvent;
    FOnEdit: TTreeGridEditEvent;
    FOnCompare: TTreeGridCompareEvent;
    FOnDrawCell: TTreeGridDrawCellEvent;
    procedure setColumns(value: TTreeGridColumns);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setSortColumn(value: integer);
    procedure setSortDescending(value: boolean);
    function getFocused: TTreeGridNode;
    procedure setFocused(value: TTreeGridNode);
    function rowPx: integer;
    function headerPx: integer;
    function columnLeft(index: integer): integer;
    function columnWidthPx(index: integer): integer;
    function columnAt(x: integer): integer;
    function edgeAt(x: integer): integer;
    function rowAt(y: integer): integer;
    function cellText(node: TTreeGridNode; column: integer): string;
    procedure rebuildShown;
    procedure addShown(node: TTreeGridNode);
    procedure sortChildren(node: TTreeGridNode);
    function compareNodes(a, b: TTreeGridNode): integer;
    procedure updateRange;
    procedure ensureVisible(index: integer);
    procedure beginEdit(node: TTreeGridNode; column: integer);
    procedure endEdit(apply: boolean);
    procedure editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure editExit(Sender: TObject);
    procedure nodeChanged;
    procedure propagateCheck(node: TTreeGridNode);
  protected
    procedure Paint; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Add(const cells: array of string): TTreeGridNode;
    function AddChild(parent: TTreeGridNode; const cells: array of string): TTreeGridNode;
    procedure Clear;
    procedure ExpandAll;
    procedure CollapseAll;
    // the nodes shown, top to bottom
    function ShownCount: integer;
    function ShownNode(index: integer): TTreeGridNode;
    // the checked nodes, the whole tree through
    procedure CheckedNodes(list: TList);
    // the first node whose cell equals the text, or nil
    function Find(const text: string; column: integer = 0): TTreeGridNode;
    // the tree as indented lines of cells joined by tabs
    procedure SaveToStrings(lines: TStrings);
    procedure BeginUpdate;
    procedure EndUpdate;
    property Root: TTreeGridNode read FRoot;
    property FocusedNode: TTreeGridNode read getFocused write setFocused;
  published
    property Columns: TTreeGridColumns read FColumns write setColumns;
    property SortColumn: integer read FSortColumn write setSortColumn default -1;
    property SortDescending: boolean read FSortDescending write setSortDescending default false;
    // 0 takes it from the font
    property RowHeight: integer index 0 read getMetric write setMetric default 0;
    property HeaderHeight: integer index 1 read getMetric write setMetric default 0;
    property Indent: integer index 2 read getMetric write setMetric default 18;
    property Padding: integer index 3 read getMetric write setMetric default 6;
    property ShowHeader: boolean index 0 read getFlag write setFlag default true;
    // the lines from a node to its children
    property ShowLines: boolean index 1 read getFlag write setFlag default true;
    property ShowGridLines: boolean index 2 read getFlag write setFlag default false;
    property ShowCheckBoxes: boolean index 3 read getFlag write setFlag default false;
    property AlternateRows: boolean index 4 read getFlag write setFlag default false;
    // the whole row takes the selection color, not the first cell alone
    property RowSelect: boolean index 5 read getFlag write setFlag default true;
    property ReadOnly: boolean index 6 read getFlag write setFlag default false;
    // a check on a node checks its children, the parent follows
    property AutoCheck: boolean index 7 read getFlag write setFlag default true;
    // a double click anywhere on the row opens it, not only the mark
    property FullRowExpand: boolean index 8 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property HeaderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property HeaderTextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property SelectedColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property AlternateColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property LineColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnSelect: TTreeGridNodeEvent read FOnSelect write FOnSelect;
    property OnExpanded: TTreeGridNodeEvent read FOnExpanded write FOnExpanded;
    property OnCollapsed: TTreeGridNodeEvent read FOnCollapsed write FOnCollapsed;
    property OnChecked: TTreeGridNodeEvent read FOnChecked write FOnChecked;
    property OnCellClick: TTreeGridCellEvent read FOnCellClick write FOnCellClick;
    property OnCellDblClick: TTreeGridCellEvent read FOnCellDblClick write FOnCellDblClick;
    property OnHeaderClick: TTreeGridCellEvent read FOnHeaderClick write FOnHeaderClick;
    property OnGetText: TTreeGridTextEvent read FOnGetText write FOnGetText;
    property OnExpanding: TTreeGridExpandEvent read FOnExpanding write FOnExpanding;
    property OnEdit: TTreeGridEditEvent read FOnEdit write FOnEdit;
    property OnCompare: TTreeGridCompareEvent read FOnCompare write FOnCompare;
    // paints over a cell; see TTreeGridDrawCellEvent
    property OnDrawCell: TTreeGridDrawCellEvent read FOnDrawCell write FOnDrawCell;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsSingle;
    property Color default clWindow;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
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
    property OnMouseWheel;
    property OnResize;
  end;

implementation

uses
  Math;

{ TTreeGridColumn }

constructor TTreeGridColumn.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FWidth := 120;
  FMinWidth := 24;
  FVisible := true;
  FSortable := true;
end;

procedure TTreeGridColumn.Assign(Source: TPersistent);
begin
  if Source is TTreeGridColumn then begin
    var s := TTreeGridColumn(Source);
    FCaption := s.FCaption;
    FWidth := s.FWidth;
    FMinWidth := s.FMinWidth;
    FAlignment := s.FAlignment;
    FVisible := s.FVisible;
    FSortable := s.FSortable;
    FEditable := s.FEditable;
    FAutoWidth := s.FAutoWidth;
    FTag := s.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TTreeGridColumn.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TTreeGridColumn.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TTreeGridColumn.setWidth(value: integer);
begin
  value := Max(value, FMinWidth);
  if FWidth = value then exit;
  FWidth := value;
  Changed(false);
end;

procedure TTreeGridColumn.setAlignment(value: TAlignment);
begin
  if FAlignment = value then exit;
  FAlignment := value;
  Changed(false);
end;

procedure TTreeGridColumn.setFlag(index: integer; value: boolean);
begin
  match index of
    0: FVisible := value;
    1: FSortable := value;
    2: FEditable := value;
  else
    FAutoWidth := value;
  end;
  Changed(false);
end;

{ TTreeGridColumns }

function TTreeGridColumns.getItem(index: integer): TTreeGridColumn;
begin
  result := TTreeGridColumn(inherited Items[index]);
end;

procedure TTreeGridColumns.setItem(index: integer; value: TTreeGridColumn);
begin
  inherited Items[index] := value;
end;

function TTreeGridColumns.Add: TTreeGridColumn;
begin
  result := TTreeGridColumn(inherited Add);
end;

procedure TTreeGridColumns.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TTreeGrid then TTreeGrid(Owner).Invalidate;
end;

{ TTreeGridNode }

constructor TTreeGridNode.Create(owner: TTreeGrid; parent: TTreeGridNode);
begin
  inherited Create;
  FOwner := owner;
  FParent := parent;
  FChildren := TList.Create;
  FImageIndex := -1;
  FColor := clDefault;
  if parent <> nil then parent.FChildren.Add(self);
end;

destructor TTreeGridNode.Destroy;
begin
  Clear;
  if (FParent <> nil) then FParent.FChildren.Remove(self);
  if (FOwner <> nil) then begin
    if FOwner.FEditing = self then FOwner.FEditing := nil;
  end;
  FChildren.Free;
  inherited Destroy;
end;

function TTreeGridNode.AddChild(const cells: array of string): TTreeGridNode;
begin
  result := TTreeGridNode.Create(FOwner, self);
  SetLength(result.FCells, length(cells));
  for var i := 0 to high(cells) do result.FCells[i] := cells[i];
  FHasChildren := true;
  FLoaded := true;
  if FOwner <> nil then FOwner.nodeChanged;
end;

procedure TTreeGridNode.Clear;
begin
  for var i := FChildren.Count-1 downto 0 do begin
    var c := TTreeGridNode(FChildren[i]);
    c.FParent := nil;
    c.Free;
  end;
  FChildren.Clear;
  // a grid going down frees its nodes without rebuilding the view between them
  if (FOwner <> nil) and (FOwner.FRoot <> self) and (FOwner.FRoot <> nil) and not (csDestroying in FOwner.ComponentState) then FOwner.nodeChanged;
end;

procedure TTreeGridNode.Delete;
begin
  var owner := FOwner;
  Free;
  if (owner <> nil) and not (csDestroying in owner.ComponentState) then owner.nodeChanged;
end;

function TTreeGridNode.Level: integer;
begin
  result := -1;
  var n := FParent;
  while n <> nil do begin
    inc(result);
    n := n.FParent;
  end;
end;

function TTreeGridNode.Index: integer;
begin
  result := if FParent = nil then -1 else FParent.FChildren.IndexOf(self);
end;

function TTreeGridNode.NextSibling: TTreeGridNode;
begin
  result := nil;
  if FParent = nil then exit;
  var i := Index;
  if i+1 < FParent.FChildren.Count then result := TTreeGridNode(FParent.FChildren[i+1]);
end;

function TTreeGridNode.PreviousSibling: TTreeGridNode;
begin
  result := nil;
  if FParent = nil then exit;
  var i := Index;
  if i > 0 then result := TTreeGridNode(FParent.FChildren[i-1]);
end;

function TTreeGridNode.IsVisible: boolean;
begin
  result := true;
  var n := FParent;
  while (n <> nil) and (n.FParent <> nil) do begin
    if not n.FExpanded then exit(false);
    n := n.FParent;
  end;
end;

procedure TTreeGridNode.Expand(recursive: boolean);
begin
  setExpanded(true);
  if recursive then for var i := 0 to FChildren.Count-1 do TTreeGridNode(FChildren[i]).Expand(true);
end;

procedure TTreeGridNode.Collapse(recursive: boolean);
begin
  setExpanded(false);
  if recursive then for var i := 0 to FChildren.Count-1 do TTreeGridNode(FChildren[i]).Collapse(true);
end;

function TTreeGridNode.getCell(column: integer): string;
begin
  result := if (column >= 0) and (column < length(FCells)) then FCells[column] else '';
end;

procedure TTreeGridNode.setCell(column: integer; const value: string);
begin
  if column < 0 then exit;
  if column >= length(FCells) then SetLength(FCells, column+1);
  if FCells[column] = value then exit;
  FCells[column] := value;
  if FOwner <> nil then FOwner.Invalidate;
end;

function TTreeGridNode.getChild(index: integer): TTreeGridNode;
begin
  result := TTreeGridNode(FChildren[index]);
end;

function TTreeGridNode.getCount: integer;
begin
  result := FChildren.Count;
end;

procedure TTreeGridNode.setExpanded(value: boolean);
begin
  if FExpanded = value then exit;
  if value and not FLoaded and (FOwner <> nil) and Assigned(FOwner.FOnExpanding) then begin
    // the first opening asks for the children
    var allow := true;
    FLoaded := true;
    FOwner.FOnExpanding(FOwner, self, allow);
    if not allow then begin
      FLoaded := false;
      exit;
    end;
  end;
  FLoaded := true;
  FExpanded := value;
  if FOwner = nil then exit;
  FOwner.nodeChanged;
  if value then begin
    if Assigned(FOwner.FOnExpanded) then FOwner.FOnExpanded(FOwner, self);
  end else if Assigned(FOwner.FOnCollapsed) then FOwner.FOnCollapsed(FOwner, self);
end;

procedure TTreeGridNode.setCheck(value: TTreeGridCheck);
begin
  if FCheck = value then exit;
  FCheck := value;
  if FOwner = nil then exit;
  if FOwner.FAutoCheck and (value in [tcChecked, tcUnchecked]) then begin
    for var i := 0 to FChildren.Count-1 do TTreeGridNode(FChildren[i]).setCheck(value);
    FOwner.propagateCheck(FParent);
  end;
  FOwner.Invalidate;
  if Assigned(FOwner.FOnChecked) then FOwner.FOnChecked(FOwner, self);
end;

procedure TTreeGridNode.setHasChildren(value: boolean);
begin
  FHasChildren := value;
  if FOwner <> nil then FOwner.Invalidate;
end;

procedure TTreeGridNode.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  if FOwner <> nil then FOwner.Invalidate;
end;

{ TTreeGrid }

constructor TTreeGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FColumns := TTreeGridColumns.Create(self, TTreeGridColumn);
  FRoot := TTreeGridNode.Create(self, nil);
  FRoot.FExpanded := true;
  FRoot.FLoaded := true;
  FFocus := -1;
  FHot := -1;
  FHotHeader := -1;
  FSortColumn := -1;
  FDragEdge := -1;
  FShowHeader := true;
  FShowLines := true;
  FRowSelect := true;
  FAutoCheck := true;
  FFullRowExpand := true;
  FIndent := 18;
  FPadding := 6;
  FHeaderColor := clDefault;
  FHeaderTextColor := clDefault;
  FTextColor := clDefault;
  FGridColor := clDefault;
  FSelectedColor := clDefault;
  FAlternateColor := clDefault;
  FLineColor := clDefault;
  FBackColor := clDefault;
  FAntialiasing := asTheme;
  FEditColumn := -1;
  Color := clWindow;
  BorderStyle := bsSingle;
  TabStop := true;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Tracking := true;
  FEdit := TEdit.Create(self);
  FEdit.Visible := false;
  FEdit.BorderStyle := bsNone;
  FEdit.OnKeyDown := @editKeyDown;
  FEdit.OnExit := @editExit;
  FEdit.Parent := self;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TTreeGrid.Destroy;
begin
  FEditing := nil;
  FRoot.FOwner := nil;
  FRoot.Free;
  FColumns.Free;
  inherited Destroy;
end;

class function TTreeGrid.GetControlClassDefaultSize: TSize;
begin
  result.cx := 360;
  result.cy := 240;
end;

// -- nodes ----------------------

function TTreeGrid.Add(const cells: array of string): TTreeGridNode;
begin
  result := FRoot.AddChild(cells);
end;

function TTreeGrid.AddChild(parent: TTreeGridNode; const cells: array of string): TTreeGridNode;
begin
  result := (if parent = nil then FRoot else parent).AddChild(cells);
end;

procedure TTreeGrid.Clear;
begin
  endEdit(false);
  FRoot.Clear;
  FFocus := -1;
  nodeChanged;
end;

procedure TTreeGrid.ExpandAll;
begin
  BeginUpdate;
  try
    for var i := 0 to FRoot.Count-1 do FRoot.Children[i].Expand(true);
  finally
    EndUpdate;
  end;
end;

procedure TTreeGrid.CollapseAll;
begin
  BeginUpdate;
  try
    for var i := 0 to FRoot.Count-1 do FRoot.Children[i].Collapse(true);
  finally
    EndUpdate;
  end;
end;

var
  updateDepth: integer = 0;

procedure TTreeGrid.BeginUpdate;
begin
  inc(updateDepth);
end;

procedure TTreeGrid.EndUpdate;
begin
  dec(updateDepth);
  if updateDepth <= 0 then begin
    updateDepth := 0;
    nodeChanged;
  end;
end;

procedure TTreeGrid.nodeChanged;
begin
  if updateDepth > 0 then exit;
  rebuildShown;
  updateRange;
  Invalidate;
end;

procedure TTreeGrid.propagateCheck(node: TTreeGridNode);
begin
  // a parent is checked when every child is, mixed when some are
  while (node <> nil) and (node <> FRoot) do begin
    var checked := 0;
    var mixed := 0;
    for var i := 0 to node.Count-1 do
      match node.Children[i].Check of
        tcChecked: inc(checked);
        tcMixed: inc(mixed);
      end;
    node.FCheck := if (checked = node.Count) and (node.Count > 0) then tcChecked else if (checked+mixed > 0) then tcMixed else tcUnchecked;
    node := node.Parent;
  end;
end;

procedure TTreeGrid.addShown(node: TTreeGridNode);
begin
  for var i := 0 to node.Count-1 do begin
    var c := node.Children[i];
    FShown := FShown+[c];
    if c.Expanded then addShown(c);
  end;
end;

function TTreeGrid.compareNodes(a, b: TTreeGridNode): integer;
begin
  result := 0;
  if Assigned(FOnCompare) then FOnCompare(self, a, b, FSortColumn, result)
  else result := AnsiCompareText(cellText(a, FSortColumn), cellText(b, FSortColumn));
  if FSortDescending then result := -result;
end;

procedure TTreeGrid.sortChildren(node: TTreeGridNode);
begin
  // an insertion sort per level keeps equal siblings in their order
  for var i := 1 to node.Count-1 do begin
    var k := i;
    while (k > 0) and (compareNodes(node.Children[k-1], node.Children[k]) > 0) do begin
      node.FChildren.Exchange(k-1, k);
      dec(k);
    end;
  end;
  for var i := 0 to node.Count-1 do sortChildren(node.Children[i]);
end;

procedure TTreeGrid.rebuildShown;
begin
  var focused := getFocused;
  if FSortColumn >= 0 then sortChildren(FRoot);
  FShown := nil;
  addShown(FRoot);
  FFocus := -1;
  for var i := 0 to high(FShown) do if FShown[i] = focused then FFocus := i;
  if FHot >= length(FShown) then FHot := -1;
end;

function TTreeGrid.ShownCount: integer;
begin
  result := length(FShown);
end;

function TTreeGrid.ShownNode(index: integer): TTreeGridNode;
begin
  result := if (index >= 0) and (index < length(FShown)) then FShown[index] else nil;
end;

procedure TTreeGrid.CheckedNodes(list: TList);
  procedure walk(node: TTreeGridNode);
  begin
    for var i := 0 to node.Count-1 do begin
      if node.Children[i].Check = tcChecked then list.Add(node.Children[i]);
      walk(node.Children[i]);
    end;
  end;
begin
  walk(FRoot);
end;

function TTreeGrid.Find(const text: string; column: integer): TTreeGridNode;
  function walk(node: TTreeGridNode): TTreeGridNode;
  begin
    result := nil;
    for var i := 0 to node.Count-1 do begin
      if SameText(cellText(node.Children[i], column), text) then exit(node.Children[i]);
      result := walk(node.Children[i]);
      if result <> nil then exit;
    end;
  end;
begin
  result := walk(FRoot);
end;

procedure TTreeGrid.SaveToStrings(lines: TStrings);
  procedure walk(node: TTreeGridNode; depth: integer);
  begin
    for var i := 0 to node.Count-1 do begin
      var c := node.Children[i];
      var line := StringOfChar(' ', depth*2);
      for var k := 0 to FColumns.Count-1 do line += (if k > 0 then #9 else '')+cellText(c, k);
      lines.Add(line);
      walk(c, depth+1);
    end;
  end;
begin
  walk(FRoot, 0);
end;

function TTreeGrid.cellText(node: TTreeGridNode; column: integer): string;
begin
  result := node.Cells[column];
  if (result = '') and Assigned(FOnGetText) then FOnGetText(self, node, column, result);
end;

function TTreeGrid.getFocused: TTreeGridNode;
begin
  result := ShownNode(FFocus);
end;

procedure TTreeGrid.setFocused(value: TTreeGridNode);
begin
  if value = nil then begin
    FFocus := -1;
    Invalidate;
    exit;
  end;
  // the ancestors open so the node shows
  var p := value.Parent;
  while (p <> nil) and (p <> FRoot) do begin
    p.Expanded := true;
    p := p.Parent;
  end;
  for var i := 0 to high(FShown) do if FShown[i] = value then begin
    if FFocus <> i then begin
      FFocus := i;
      ensureVisible(i);
      Invalidate;
      if Assigned(FOnSelect) then FOnSelect(self, value);
    end;
    exit;
  end;
end;

// -- geometry ----------------------

function TTreeGrid.rowPx: integer;
begin
  result := if FRowHeight > 0 then scaled(self, FRowHeight) else lineHeightOf(Font)+scaled(self, 8);
end;

function TTreeGrid.headerPx: integer;
begin
  if not FShowHeader then exit(0);
  result := if FHeaderHeight > 0 then scaled(self, FHeaderHeight) else lineHeightOf(Font)+scaled(self, 10);
end;

function TTreeGrid.columnWidthPx(index: integer): integer;
begin
  var col := FColumns[index];
  if not col.Visible then exit(0);
  result := scaled(self, col.Width);
  if col.AutoWidth then begin
    var used := 0;
    for var i := 0 to FColumns.Count-1 do if (i <> index) and FColumns[i].Visible then used += scaled(self, FColumns[i].Width);
    result := Max(ClientWidth-used, scaled(self, col.MinWidth));
  end;
end;

function TTreeGrid.columnLeft(index: integer): integer;
begin
  result := 0;
  for var i := 0 to index-1 do result += columnWidthPx(i);
end;

function TTreeGrid.columnAt(x: integer): integer;
begin
  var px := x+HorzScrollBar.Position;
  var left := 0;
  for var i := 0 to FColumns.Count-1 do begin
    var w := columnWidthPx(i);
    if (px >= left) and (px < left+w) then exit(i);
    left += w;
  end;
  result := -1;
end;

function TTreeGrid.edgeAt(x: integer): integer;
begin
  var px := x+HorzScrollBar.Position;
  var left := 0;
  for var i := 0 to FColumns.Count-1 do begin
    left += columnWidthPx(i);
    if FColumns[i].Visible and (Abs(px-left) <= scaled(self, 3)) then exit(i);
  end;
  result := -1;
end;

function TTreeGrid.rowAt(y: integer): integer;
begin
  var ly := y+VertScrollBar.Position-headerPx;
  if ly < 0 then exit(-1);
  result := ly div rowPx;
  if result >= length(FShown) then result := -1;
end;

procedure TTreeGrid.updateRange;
begin
  if not HandleAllocated then exit;
  VertScrollBar.Increment := rowPx;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := headerPx+length(FShown)*rowPx;
  // the range counts an auto-width column at its least, so it never follows the client width
  var total := 0;
  for var i := 0 to FColumns.Count-1 do if FColumns[i].Visible then total += scaled(self, (if FColumns[i].AutoWidth then FColumns[i].MinWidth else FColumns[i].Width));
  if HorzScrollBar.Increment <> scaled(self, 20) then HorzScrollBar.Increment := scaled(self, 20);
  if HorzScrollBar.Page <> Max(ClientWidth, 1) then HorzScrollBar.Page := Max(ClientWidth, 1);
  if HorzScrollBar.Range <> total then HorzScrollBar.Range := total;
end;

procedure TTreeGrid.ensureVisible(index: integer);
begin
  if (index < 0) or not HandleAllocated then exit;
  var top := headerPx+index*rowPx;
  if top-headerPx < VertScrollBar.Position then VertScrollBar.Position := top-headerPx
  else if top+rowPx > VertScrollBar.Position+ClientHeight then VertScrollBar.Position := top+rowPx-ClientHeight;
end;

procedure TTreeGrid.ScrollBy(DeltaX, DeltaY: Integer);
begin
  endEdit(true);
  Invalidate;
end;

procedure TTreeGrid.Resize;
begin
  inherited Resize;
  // the scroll bars wait for the paint: set while the bounds change, they
  // make the control keep its old place
  FRangeDirty := true;
  Invalidate;
end;

procedure TTreeGrid.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

// -- editing ----------------------

procedure TTreeGrid.beginEdit(node: TTreeGridNode; column: integer);
begin
  if FReadOnly or (node = nil) or (column < 0) or (column >= FColumns.Count) or not FColumns[column].Editable then exit;
  endEdit(true);
  var index := -1;
  for var i := 0 to high(FShown) do if FShown[i] = node then index := i;
  if index < 0 then exit;
  var top := headerPx+index*rowPx-VertScrollBar.Position;
  var left := columnLeft(column)-HorzScrollBar.Position;
  if column = 0 then left += scaled(self, FIndent)*(node.Level+1)+(if FShowCheckBoxes then rowPx else 0);
  FEditing := node;
  FEditColumn := column;
  FEdit.Text := cellText(node, column);
  FEdit.SetBounds(left+1, top+1, columnWidthPx(column)-(left-columnLeft(column)+HorzScrollBar.Position)-2, rowPx-2);
  FEdit.Visible := true;
  FEdit.SetFocus;
  FEdit.SelectAll;
end;

procedure TTreeGrid.endEdit(apply: boolean);
begin
  if FEditing = nil then exit;
  var node := FEditing;
  var column := FEditColumn;
  FEditing := nil;
  FEditColumn := -1;
  var text := FEdit.Text;
  FEdit.Visible := false;
  if apply and (text <> cellText(node, column)) then begin
    var accept := true;
    if Assigned(FOnEdit) then FOnEdit(self, node, column, text, accept);
    if accept then node.Cells[column] := text;
  end;
  if CanSetFocus and not Focused and (Screen.ActiveControl = FEdit) then SetFocus;
  Invalidate;
end;

procedure TTreeGrid.editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  match Key of
    VK_RETURN: begin endEdit(true); Key := 0; end;
    VK_ESCAPE: begin endEdit(false); Key := 0; end;
  end;
end;

procedure TTreeGrid.editExit(Sender: TObject);
begin
  endEdit(true);
end;

// -- painting ----------------------

procedure TTreeGrid.Paint;
begin
  if FRangeDirty then begin
    FRangeDirty := false;
    updateRange;
  end;
  var back := pick(FBackColor, Color);
  var text := pick(FTextColor, clWindowText);
  var header := pick(FHeaderColor, blend(back, clWindowText, 7));
  var headerText := pick(FHeaderTextColor, clWindowText);
  var grid := pick(FGridColor, blend(back, clWindowText, 12));
  var selected := pick(FSelectedColor, blend(back, clHighlight, 30));
  var alt := pick(FAlternateColor, blend(back, clWindowText, 4));
  var lineColor := pick(FLineColor, blend(back, clWindowText, 25));
  var view := ClientRect;
  OffsetRect(view, HorzScrollBar.Position, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var rh := rowPx;
  var hh := headerPx;
  var pad := scaled(self, FPadding);
  var indent := scaled(self, FIndent);
  var checkW := if FShowCheckBoxes then rh else 0;
  var first := Max((VertScrollBar.Position-hh) div rh, 0);
  var last := Min((VertScrollBar.Position+ClientHeight-hh) div rh, high(FShown));
  var total := 0;
  for var c := 0 to FColumns.Count-1 do total += columnWidthPx(c);
  // the rows
  for var i := first to last do begin
    var node := FShown[i];
    var top := hh+i*rh;
    var fill := if node.Color <> clDefault then ColorToRGB(node.Color) else if FAlternateRows and (i mod 2 = 1) then alt else back;
    if i = FFocus then fill := if Focused and ringEnabled then blend(selected, clHighlight, 20) else selected
    else if (i = FHot) and hoverEnabled then fill := hoverColor(fill);
    if fill <> back then sp.FillRect(Rect(view.Left, top, (if FRowSelect or (i <> FFocus) then view.Right else columnWidthPx(0)), top+rh), fill);
    if FShowGridLines then sp.FillRect(Rect(view.Left, top+rh-1, view.Right, top+rh), grid);
    var level := node.Level;
    var x := columnLeft(0)+level*indent;
    // the lines from the parent down and across
    if FShowLines then begin
      var cx := x+indent div 2;
      var cy := top+rh div 2;
      sp.FillRect(Rect(cx, cy, x+indent, cy+1), lineColor);
      var up := node.PreviousSibling <> nil;
      var down := node.NextSibling <> nil;
      sp.FillRect(Rect(cx, (if up or (node.Parent <> FRoot) then top else cy), cx+1, (if down then top+rh else cy)), lineColor);
      // the lines of the ancestors with siblings below
      var p := node.Parent;
      var lx := x-indent div 2;
      while (p <> nil) and (p <> FRoot) do begin
        if p.NextSibling <> nil then sp.FillRect(Rect(lx, top, lx+1, top+rh), lineColor);
        lx -= indent;
        p := p.Parent;
      end;
    end;
    // the expand mark
    if node.HasChildren or (node.Count > 0) then begin
      var cx := x+indent div 2;
      var size := scaled(self, 7);
      sp.FillRect(Rect(cx-size div 2-1, top+rh div 2-size div 2-1, cx+size div 2+2, top+rh div 2+size div 2+2), fill);
      paintChevron(sp, Rect(cx-size, top, cx+size, top+rh), (if node.Expanded then cdDown else cdRight), size, text);
    end;
    x += indent;
    if FShowCheckBoxes then begin
      var size := rh-scaled(self, 10);
      var box := Rect(x+scaled(self, 2), top+scaled(self, 5), x+scaled(self, 2)+size, top+scaled(self, 5)+size);
      var accent := ColorToRGB(clHighlight);
      match node.Check of
        tcChecked: begin
          paintRoundRect(sp, box, scaled(self, 2), accent, accent);
          paintCheck(sp, box, size*7 div 10, contrastText(accent), Max(size div 7, 2));
        end;
        tcMixed: begin
          paintRoundRect(sp, box, scaled(self, 2), accent, accent);
          sp.FillRect(Rect(box.Left+size div 4, (box.Top+box.Bottom) div 2-1, box.Right-size div 4, (box.Top+box.Bottom) div 2+1), contrastText(accent));
        end;
        tcUnchecked: paintRoundRect(sp, box, scaled(self, 2), back, blend(back, clWindowText, 40));
      end;
    end;
  end;
  if FShowGridLines then begin
    var left := 0;
    for var c := 0 to FColumns.Count-1 do begin
      left += columnWidthPx(c);
      sp.FillRect(Rect(left-1, view.Top+hh, left, view.Bottom), grid);
    end;
  end;
  // the header on top
  if hh > 0 then begin
    sp.FillRect(Rect(view.Left, view.Top, view.Right, view.Top+hh), header);
    sp.FillRect(Rect(view.Left, view.Top+hh-1, view.Right, view.Top+hh), grid);
    var left := 0;
    for var c := 0 to FColumns.Count-1 do begin
      var w := columnWidthPx(c);
      if w = 0 then continue;
      if (c = FHotHeader) and FColumns[c].Sortable and hoverEnabled then sp.FillRect(Rect(left, view.Top, left+w, view.Top+hh-1), hoverColor(header));
      sp.FillRect(Rect(left+w-1, view.Top+scaled(self, 6), left+w, view.Top+hh-scaled(self, 6)), grid);
      if c = FSortColumn then begin
        var cx := left+w-scaled(self, 10);
        paintChevron(sp, Rect(cx-scaled(self, 5), view.Top, cx+scaled(self, 5), view.Top+hh), (if FSortDescending then cdDown else cdUp), scaled(self, 7), headerText);
      end;
      left += w;
    end;
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.EndEllipsis := true;
  style.ShowPrefix := false;
  style.Opaque := false;
  // the rows scroll under the header: their text stops where it begins
  Canvas.ClipRect := Rect(view.Left, view.Top+hh, view.Right, view.Bottom);
  Canvas.Clipping := true;
  for var i := first to last do begin
    var node := FShown[i];
    var top := hh+i*rh;
    if (node = FEditing) then continue;
    var left := 0;
    for var c := 0 to FColumns.Count-1 do begin
      var w := columnWidthPx(c);
      if w = 0 then continue;
      var r := Rect(left+pad, top, left+w-pad, top+rh);
      if c = 0 then r.Left := left+node.Level*indent+indent+checkW+pad div 2;
      var handled := false;
      if Assigned(FOnDrawCell) then begin
        var state: TDrawState := if i = FFocus then [dsSelected] else [];
        if not Enabled then state += [dsDisabled];
        FOnDrawCell(self, Canvas, Rect((if c = 0 then r.Left else left), top, left+w, top+rh), node, c, state, handled);
      end;
      style.Alignment := FColumns[c].Alignment;
      Canvas.Font.Color := text;
      Canvas.Font.Style := Font.Style;
      if not handled and (r.Right > r.Left) then Canvas.TextRect(r, r.Left, r.Top, cellText(node, c), style);
      left += w;
    end;
  end;
  Canvas.Clipping := false;
  if hh > 0 then begin
    Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.Font.Color := headerText;
    var left := 0;
    for var c := 0 to FColumns.Count-1 do begin
      var w := columnWidthPx(c);
      if w = 0 then continue;
      var r := Rect(left+pad, view.Top, left+w-pad-(if c = FSortColumn then scaled(self, 14) else 0), view.Top+hh);
      style.Alignment := FColumns[c].Alignment;
      if r.Right > r.Left then Canvas.TextRect(r, r.Left, r.Top, FColumns[c].Caption, style);
      left += w;
    end;
    Canvas.Font.Style := Font.Style;
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TTreeGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus and (FEditing = nil) then SetFocus;
  if Button <> mbLeft then exit;
  if (headerPx > 0) and (Y < headerPx) then begin
    var edge := edgeAt(X);
    if edge >= 0 then begin
      FDragEdge := edge;
      FDragX := X;
      FDragWidth := FColumns[edge].Width;
      exit;
    end;
    var c := columnAt(X);
    if c < 0 then exit;
    if Assigned(FOnHeaderClick) then FOnHeaderClick(self, nil, c);
    if FColumns[c].Sortable then begin
      if FSortColumn = c then SortDescending := not FSortDescending else SortColumn := c;
    end;
    exit;
  end;
  var row := rowAt(Y);
  if row < 0 then begin
    endEdit(true);
    exit;
  end;
  var node := FShown[row];
  var c := columnAt(X);
  var indent := scaled(self, FIndent);
  var px := X+HorzScrollBar.Position;
  var markLeft := columnLeft(0)+node.Level*indent;
  if (px >= markLeft) and (px < markLeft+indent) and (node.HasChildren or (node.Count > 0)) then begin
    node.Expanded := not node.Expanded;
    exit;
  end;
  if FShowCheckBoxes and (px >= markLeft+indent) and (px < markLeft+indent+rowPx) and not FReadOnly then begin
    node.Check := if node.Check = tcChecked then tcUnchecked else tcChecked;
    exit;
  end;
  if row <> FFocus then begin
    endEdit(true);
    FFocus := row;
    Invalidate;
    if Assigned(FOnSelect) then FOnSelect(self, node);
  end;
  if Assigned(FOnCellClick) then FOnCellClick(self, node, c);
end;

procedure TTreeGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragEdge >= 0 then begin
    FColumns[FDragEdge].Width := FDragWidth+Round((X-FDragX)/Max(scaled(self, 100)/100, 0.01));
    updateRange;
    exit;
  end;
  var inHeader := (headerPx > 0) and (Y < headerPx);
  Cursor := if inHeader and (edgeAt(X) >= 0) then crHSplit else crDefault;
  var hotHeader := if inHeader then columnAt(X) else -1;
  var hot := if inHeader then -1 else rowAt(Y);
  if (hot = FHot) and (hotHeader = FHotHeader) then exit;
  FHot := hot;
  FHotHeader := hotHeader;
  Invalidate;
end;

procedure TTreeGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragEdge := -1;
end;

procedure TTreeGrid.MouseLeave;
begin
  inherited MouseLeave;
  if (FHot < 0) and (FHotHeader < 0) then exit;
  FHot := -1;
  FHotHeader := -1;
  Invalidate;
end;

procedure TTreeGrid.DblClick;
begin
  inherited DblClick;
  var p := ScreenToClient(Mouse.CursorPos);
  var row := rowAt(p.Y);
  if row < 0 then exit;
  var node := FShown[row];
  var c := columnAt(p.X);
  if Assigned(FOnCellDblClick) then FOnCellDblClick(self, node, c);
  if (c >= 0) and FColumns[c].Editable and not FReadOnly then beginEdit(node, c)
  else if FFullRowExpand and (node.HasChildren or (node.Count > 0)) then node.Expanded := not node.Expanded;
end;

procedure TTreeGrid.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var n := length(FShown);
  if n = 0 then exit;
  var node := getFocused;
  var page := Max(ClientHeight div Max(rowPx, 1), 1);
  match Key of
    VK_UP: FFocus := Max(FFocus-1, 0);
    VK_DOWN: FFocus := Min(FFocus+1, n-1);
    VK_HOME: FFocus := 0;
    VK_END: FFocus := n-1;
    VK_PRIOR: FFocus := Max(FFocus-page, 0);
    VK_NEXT: FFocus := Min(FFocus+page, n-1);
    VK_RIGHT, VK_ADD: begin
      if (node <> nil) and (not node.Expanded) and (node.HasChildren or (node.Count > 0)) then node.Expanded := true
      else if (node <> nil) and (node.Count > 0) then FFocus := Min(FFocus+1, n-1);
    end;
    VK_LEFT, VK_SUBTRACT: begin
      if (node <> nil) and node.Expanded then node.Expanded := false
      else if (node <> nil) and (node.Parent <> FRoot) then FocusedNode := node.Parent;
    end;
    VK_MULTIPLY: if node <> nil then node.Expand(true);
    VK_SPACE: if (node <> nil) and FShowCheckBoxes and not FReadOnly then node.Check := if node.Check = tcChecked then tcUnchecked else tcChecked;
    VK_F2, VK_RETURN: begin
      if node <> nil then for var c := 0 to FColumns.Count-1 do if FColumns[c].Editable then begin beginEdit(node, c); break; end;
    end;
  else
    exit;
  end;
  Key := 0;
  ensureVisible(FFocus);
  Invalidate;
  var now := getFocused;
  if (now <> node) and (now <> nil) and Assigned(FOnSelect) then FOnSelect(self, now);
end;

procedure TTreeGrid.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TTreeGrid.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

procedure TTreeGrid.setColumns(value: TTreeGridColumns);
begin
  FColumns.Assign(value);
  updateRange;
  Invalidate;
end;

procedure TTreeGrid.setSortColumn(value: integer);
begin
  if value < -1 then value := -1;
  if FSortColumn = value then exit;
  FSortColumn := value;
  FSortDescending := false;
  nodeChanged;
end;

procedure TTreeGrid.setSortDescending(value: boolean);
begin
  if FSortDescending = value then exit;
  FSortDescending := value;
  nodeChanged;
end;

function TTreeGrid.getMetric(index: integer): integer;
begin
  result := match index of
    0: FRowHeight;
    1: FHeaderHeight;
    2: FIndent;
  else
    FPadding
  end;
end;

procedure TTreeGrid.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 2 then value := Max(value, 8);
  if getMetric(index) = value then exit;
  match index of
    0: FRowHeight := value;
    1: FHeaderHeight := value;
    2: FIndent := value;
  else
    FPadding := value;
  end;
  updateRange;
  Invalidate;
end;

function TTreeGrid.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowHeader;
    1: FShowLines;
    2: FShowGridLines;
    3: FShowCheckBoxes;
    4: FAlternateRows;
    5: FRowSelect;
    6: FReadOnly;
    7: FAutoCheck;
  else
    FFullRowExpand
  end;
end;

procedure TTreeGrid.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowHeader := value;
    1: FShowLines := value;
    2: FShowGridLines := value;
    3: FShowCheckBoxes := value;
    4: FAlternateRows := value;
    5: FRowSelect := value;
    6: FReadOnly := value;
    7: FAutoCheck := value;
  else
    FFullRowExpand := value;
  end;
  updateRange;
  Invalidate;
end;

function TTreeGrid.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FHeaderColor;
    1: FHeaderTextColor;
    2: FTextColor;
    3: FGridColor;
    4: FSelectedColor;
    5: FAlternateColor;
    6: FLineColor;
  else
    FBackColor
  end;
end;

procedure TTreeGrid.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FHeaderColor := value;
    1: FHeaderTextColor := value;
    2: FTextColor := value;
    3: FGridColor := value;
    4: FSelectedColor := value;
    5: FAlternateColor := value;
    6: FLineColor := value;
  else
    FBackColor := value;
  end;
  Invalidate;
end;

procedure TTreeGrid.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
