{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit DataTable;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, LMessages, ControlPaint;

type
  TDataTable = class;
  TDataColumnKind = (ckText, ckNumber, ckCheck);

  { TDataColumn }

  TDataColumn = class(TCollectionItem)
  private
    FCaption: string;
    FWidth, FMinWidth: integer;
    FAlignment: TAlignment;
    FKind: TDataColumnKind;
    FSortable, FVisible, FAutoWidth: boolean;
    FFormat: string;
    FTag: PtrInt;
    procedure setCaption(const value: string);
    procedure setWidth(value: integer);
    procedure setAlignment(value: TAlignment);
    procedure setKind(value: TDataColumnKind);
    procedure setFlag(index: integer; value: boolean);
    procedure setFormat(const value: string);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Caption: string read FCaption write setCaption;
    property Width: integer read FWidth write setWidth default 100;
    property MinWidth: integer read FMinWidth write FMinWidth default 30;
    property Alignment: TAlignment read FAlignment write setAlignment default taLeftJustify;
    // ckNumber sorts and aligns as a number, ckCheck shows a check mark for
    // 1, true, yes
    property Kind: TDataColumnKind read FKind write setKind default ckText;
    // a click on the header sorts by this column
    property Sortable: boolean index 0 read FSortable write setFlag default true;
    property Visible: boolean index 1 read FVisible write setFlag default true;
    // the column takes what the others leave
    property AutoWidth: boolean index 2 read FAutoWidth write setFlag default false;
    // a Format pattern for a number, like "%.2f" or "%d items"
    property Format: string read FFormat write setFormat;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TDataColumns }

  TDataColumns = class(TOwnedCollection)
  private
    function getItem(index: integer): TDataColumn;
    procedure setItem(index: integer; value: TDataColumn);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TDataColumn;
    function AddColumn(const caption: string; width: integer = 100; kind: TDataColumnKind = ckText): TDataColumn;
    property Items[index: integer]: TDataColumn read getItem write setItem; default;
  end;

  TDataSelection = (dsNone, dsSingle, dsMulti);
  TDataCellEvent = procedure(Sender: TObject; row, column: integer) of object;
  TDataCellColorEvent = procedure(Sender: TObject; row, column: integer; var back, text: TColor) of object;
  // the text of a cell of a virtual table
  TDataGetCellEvent = procedure(Sender: TObject; row, column: integer; var text: string) of object;
  TDataCompareEvent = procedure(Sender: TObject; column, rowA, rowB: integer; var result: integer) of object;
  // paints over a cell once its row is painted: dsSelected for a selected
  // row, dsFocused for the keyboard row; `handled` true leaves the text out
  TDataDrawCellEvent = procedure(Sender: TObject; canvas: TCanvas; const r: TRect; row, column: integer; state: TDrawState; var handled: boolean) of object;

  { TDataTable }

  // a table of text cells with a header: a click on a header sorts, a text
  // filters the rows, the rows select, scroll and answer the keyboard.
  // The cells are strings; a number column sorts and aligns as numbers
  TDataTable = class(TScrollingWinControl)
  private
    FColumns: TDataColumns;
    FCells: array of array of string; // [row][column], the stored order
    FRowTags: array of PtrInt;
    FOrder: array of integer; // the rows shown, sorted and filtered
    FSelected: array of boolean;
    FFocusRow, FHotRow, FHotHeader, FSortColumn: integer;
    FSortDescending, FShowHeader, FAlternateRows, FShowGridLines, FShowRowNumbers, FAutoSort: boolean;
    FSelection: TDataSelection;
    FRowHeight, FHeaderHeight, FPadding: integer;
    FFilter: string;
    FFilterColumn: integer;
    FHeaderColor, FHeaderTextColor, FBackColor, FTextColor, FAlternateColor, FGridColor, FSelectedColor, FSelectedTextColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FDragColumn, FDragStart, FDragWidth: integer;
    FOnSelect, FOnCellClick, FOnCellDblClick, FOnHeaderClick: TDataCellEvent;
    FOnGetCellColors: TDataCellColorEvent;
    FOnCompare: TDataCompareEvent;
    FOnSort: TNotifyEvent;
    FOnGetCell: TDataGetCellEvent;
    FOnDrawCell: TDataDrawCellEvent;
    FVirtualCount: integer;
    FRangeDirty: boolean;
    procedure setColumns(value: TDataColumns);
    function getCell(column, row: integer): string;
    procedure setCell(column, row: integer; const value: string);
    function getRowTag(row: integer): PtrInt;
    procedure setRowTag(row: integer; value: PtrInt);
    function getRowCount: integer;
    function getSelectedRow(index: integer): boolean;
    procedure setSelectedRow(index: integer; value: boolean);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setSelection(value: TDataSelection);
    procedure setFilter(const value: string);
    procedure setFilterColumn(value: integer);
    procedure setVirtualCount(value: integer);
    procedure setSortColumn(value: integer);
    procedure setSortDescending(value: boolean);
    procedure setAntialiasing(value: TAntialiasSetting);
    function rowPx: integer;
    function headerPx: integer;
    function columnLeft(column: integer): integer;
    function columnWidthPx(column: integer): integer;
    function totalWidth: integer;
    function columnAt(x: integer): integer;
    function edgeAt(x: integer): integer;
    function shownRowAt(y: integer): integer;
    function shownRowTop(index: integer): integer;
    function matches(row: integer): boolean;
    function compareRows(a, b: integer): integer;
    procedure rebuild;
    procedure updateRange;
    procedure clickRow(index: integer; shift: TShiftState);
    procedure ensureVisible(index: integer);
    function checkValue(const s: string): boolean;
    function numberOf(const s: string): double;
    function cellText(row, column: integer): string;
    procedure columnsChanged;
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
    // a row from its cells, in the order of the columns; the index of the stored row
    function AddRow(const cells: array of string; tag: PtrInt = 0): integer;
    procedure DeleteRow(row: integer);
    procedure Clear;
    procedure ClearRows;
    // the rows in their stored order, cells separated by the delimiter
    procedure LoadFromStrings(lines: TStrings; delimiter: char = #9; firstLineIsHeader: boolean = false);
    procedure SaveToStrings(lines: TStrings; delimiter: char = #9; withHeader: boolean = true);
    procedure SelectAll;
    procedure ClearSelection;
    function SelectedCount: integer;
    // the stored row shown at a position of the view, after sort and filter
    function ShownRow(index: integer): integer;
    function ShownCount: integer;
    // the stored index of the focused row, -1 for none
    function FocusedRow: integer;
    procedure FocusRow(row: integer);
    property Cells[column, row: integer]: string read getCell write setCell;
    property RowTags[row: integer]: PtrInt read getRowTag write setRowTag;
    property RowCount: integer read getRowCount;
    // the shown index of the keyboard row, -1 for none; ShownRow turns it into a row
    property FocusedIndex: integer read FFocusRow;
    property Selected[row: integer]: boolean read getSelectedRow write setSelectedRow;
  published
    property Columns: TDataColumns read FColumns write setColumns;
    property Selection: TDataSelection read FSelection write setSelection default dsSingle;
    // above zero the table is virtual: this many rows, the text of each cell from
    // OnGetCell when it shows; sorting and filtering are then the job of the
    // application, a header click reports through OnHeaderClick
    property VirtualRowCount: integer read FVirtualCount write setVirtualCount default 0;
    // the rows holding the text stay; empty shows all
    property Filter: string read FFilter write setFilter;
    // the column the filter looks at; -1 for every column
    property FilterColumn: integer read FFilterColumn write setFilterColumn default -1;
    property SortColumn: integer read FSortColumn write setSortColumn default -1;
    property SortDescending: boolean read FSortDescending write setSortDescending default false;
    property ShowHeader: boolean index 0 read getFlag write setFlag default true;
    property AlternateRows: boolean index 1 read getFlag write setFlag default true;
    property ShowGridLines: boolean index 2 read getFlag write setFlag default false;
    property ShowRowNumbers: boolean index 3 read getFlag write setFlag default false;
    // a change of a cell keeps the rows sorted
    property AutoSort: boolean index 4 read getFlag write setFlag default true;
    // 0 takes it from the font
    property RowHeight: integer index 0 read getMetric write setMetric default 0;
    property HeaderHeight: integer index 1 read getMetric write setMetric default 0;
    property Padding: integer index 2 read getMetric write setMetric default 6;
    // clDefault takes the colors of the theme
    property HeaderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property HeaderTextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property AlternateColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property SelectedColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property SelectedTextColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnSelect: TDataCellEvent read FOnSelect write FOnSelect;
    property OnCellClick: TDataCellEvent read FOnCellClick write FOnCellClick;
    property OnCellDblClick: TDataCellEvent read FOnCellDblClick write FOnCellDblClick;
    property OnHeaderClick: TDataCellEvent read FOnHeaderClick write FOnHeaderClick;
    // the colors of a cell before it is painted
    property OnGetCellColors: TDataCellColorEvent read FOnGetCellColors write FOnGetCellColors;
    // the order of two stored rows for a column; result < 0 puts rowA first
    property OnCompare: TDataCompareEvent read FOnCompare write FOnCompare;
    property OnSort: TNotifyEvent read FOnSort write FOnSort;
    property OnGetCell: TDataGetCellEvent read FOnGetCell write FOnGetCell;
    // paints over a cell; see TDataDrawCellEvent
    property OnDrawCell: TDataDrawCellEvent read FOnDrawCell write FOnDrawCell;
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
  Math, StrUtils;

{ TDataColumn }

constructor TDataColumn.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FWidth := 100;
  FMinWidth := 30;
  FSortable := true;
  FVisible := true;
end;

procedure TDataColumn.Assign(Source: TPersistent);
begin
  if Source is TDataColumn then begin
    var o := TDataColumn(Source);
    FCaption := o.FCaption;
    FWidth := o.FWidth;
    FMinWidth := o.FMinWidth;
    FAlignment := o.FAlignment;
    FKind := o.FKind;
    FSortable := o.FSortable;
    FVisible := o.FVisible;
    FAutoWidth := o.FAutoWidth;
    FFormat := o.FFormat;
    FTag := o.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TDataColumn.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TDataColumn.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TDataColumn.setWidth(value: integer);
begin
  value := Max(value, FMinWidth);
  if FWidth = value then exit;
  FWidth := value;
  Changed(false);
end;

procedure TDataColumn.setAlignment(value: TAlignment);
begin
  if FAlignment = value then exit;
  FAlignment := value;
  Changed(false);
end;

procedure TDataColumn.setKind(value: TDataColumnKind);
begin
  if FKind = value then exit;
  FKind := value;
  Changed(false);
end;

procedure TDataColumn.setFlag(index: integer; value: boolean);
begin
  match index of
    0: begin if FSortable = value then exit; FSortable := value; end;
    1: begin if FVisible = value then exit; FVisible := value; end;
  else
    begin if FAutoWidth = value then exit; FAutoWidth := value; end;
  end;
  Changed(false);
end;

procedure TDataColumn.setFormat(const value: string);
begin
  if FFormat = value then exit;
  FFormat := value;
  Changed(false);
end;

{ TDataColumns }

function TDataColumns.getItem(index: integer): TDataColumn;
begin
  result := TDataColumn(inherited Items[index]);
end;

procedure TDataColumns.setItem(index: integer; value: TDataColumn);
begin
  inherited Items[index] := value;
end;

procedure TDataColumns.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TDataTable then TDataTable(Owner).columnsChanged;
end;

function TDataColumns.Add: TDataColumn;
begin
  result := TDataColumn(inherited Add);
end;

function TDataColumns.AddColumn(const caption: string; width: integer; kind: TDataColumnKind): TDataColumn;
begin
  result := Add;
  result.FCaption := caption;
  result.FWidth := width;
  result.FKind := kind;
  if kind = ckNumber then result.FAlignment := taRightJustify;
  result.Changed(false);
end;

{ TDataTable }

constructor TDataTable.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FColumns := TDataColumns.Create(self, TDataColumn);
  FSelection := dsSingle;
  FShowHeader := true;
  FAlternateRows := true;
  FAutoSort := true;
  FPadding := 6;
  FFilterColumn := -1;
  FSortColumn := -1;
  FFocusRow := -1;
  FHotRow := -1;
  FHotHeader := -1;
  FDragColumn := -1;
  FHeaderColor := clDefault;
  FHeaderTextColor := clDefault;
  FBackColor := clDefault;
  FTextColor := clDefault;
  FAlternateColor := clDefault;
  FGridColor := clDefault;
  FSelectedColor := clDefault;
  FSelectedTextColor := clDefault;
  FAntialiasing := asTheme;
  TabStop := true;
  Color := clWindow;
  BorderStyle := bsSingle;
  HorzScrollBar.Tracking := true;
  VertScrollBar.Tracking := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TDataTable.Destroy;
begin
  FColumns.Free;
  inherited Destroy;
end;

class function TDataTable.GetControlClassDefaultSize: TSize;
begin
  result.cx := 360;
  result.cy := 200;
end;

// -- the rows ----------------------

function TDataTable.AddRow(const cells: array of string; tag: PtrInt): integer;
begin
  result := length(FCells);
  SetLength(FCells, result+1);
  SetLength(FCells[result], FColumns.Count);
  for var i := 0 to Min(high(cells), FColumns.Count-1) do FCells[result][i] := cells[i];
  SetLength(FRowTags, result+1);
  FRowTags[result] := tag;
  SetLength(FSelected, result+1);
  FSelected[result] := false;
  rebuild;
end;

procedure TDataTable.DeleteRow(row: integer);
begin
  if (row < 0) or (row >= length(FCells)) then exit;
  for var i := row to high(FCells)-1 do begin
    FCells[i] := FCells[i+1];
    FRowTags[i] := FRowTags[i+1];
    FSelected[i] := FSelected[i+1];
  end;
  SetLength(FCells, length(FCells)-1);
  SetLength(FRowTags, length(FRowTags)-1);
  SetLength(FSelected, length(FSelected)-1);
  if FFocusRow >= length(FOrder)-1 then FFocusRow := length(FOrder)-2;
  rebuild;
end;

procedure TDataTable.ClearRows;
begin
  FCells := nil;
  FRowTags := nil;
  FSelected := nil;
  FFocusRow := -1;
  rebuild;
end;

procedure TDataTable.Clear;
begin
  ClearRows;
  FColumns.Clear;
end;

procedure TDataTable.LoadFromStrings(lines: TStrings; delimiter: char; firstLineIsHeader: boolean);
begin
  ClearRows;
  var first := 0;
  if firstLineIsHeader and (lines.Count > 0) then begin
    FColumns.Clear;
    for var name in lines[0].Split([delimiter]) do FColumns.AddColumn(name);
    first := 1;
  end;
  for var i := first to lines.Count-1 do begin
    if Trim(lines[i]) = '' then continue;
    var parts := lines[i].Split([delimiter]);
    while FColumns.Count < length(parts) do FColumns.AddColumn('');
    AddRow(parts);
  end;
end;

procedure TDataTable.SaveToStrings(lines: TStrings; delimiter: char; withHeader: boolean);
begin
  if withHeader then begin
    var line := '';
    for var c := 0 to FColumns.Count-1 do line += (if c > 0 then delimiter else '')+FColumns[c].Caption;
    lines.Add(line);
  end;
  for var r := 0 to high(FCells) do begin
    var line := '';
    for var c := 0 to FColumns.Count-1 do line += (if c > 0 then delimiter else '')+(if c < length(FCells[r]) then FCells[r][c] else '');
    lines.Add(line);
  end;
end;

function TDataTable.getCell(column, row: integer): string;
begin
  result := '';
  if FVirtualCount > 0 then begin
    if (row >= 0) and (row < FVirtualCount) and Assigned(FOnGetCell) then FOnGetCell(self, row, column, result);
    exit;
  end;
  if (row < 0) or (row >= length(FCells)) or (column < 0) or (column >= length(FCells[row])) then exit;
  result := FCells[row][column];
end;

procedure TDataTable.setCell(column, row: integer; const value: string);
begin
  if (row < 0) or (row >= length(FCells)) or (column < 0) or (column >= FColumns.Count) then exit;
  if length(FCells[row]) < FColumns.Count then SetLength(FCells[row], FColumns.Count);
  if FCells[row][column] = value then exit;
  FCells[row][column] := value;
  if FAutoSort and ((column = FSortColumn) or (FFilter <> '')) then rebuild else Invalidate;
end;

function TDataTable.getRowTag(row: integer): PtrInt;
begin
  result := if (row >= 0) and (row < length(FRowTags)) then FRowTags[row] else 0;
end;

procedure TDataTable.setRowTag(row: integer; value: PtrInt);
begin
  if (row >= 0) and (row < length(FRowTags)) then FRowTags[row] := value;
end;

function TDataTable.getRowCount: integer;
begin
  result := if FVirtualCount > 0 then FVirtualCount else length(FCells);
end;

procedure TDataTable.setVirtualCount(value: integer);
begin
  value := Max(value, 0);
  if FVirtualCount = value then exit;
  FVirtualCount := value;
  rebuild;
end;

// -- order ----------------------

function TDataTable.checkValue(const s: string): boolean;
begin
  var v := LowerCase(Trim(s));
  result := (v = '1') or (v = 'true') or (v = 'yes') or (v = 'on') or (v = 'x');
end;

function TDataTable.numberOf(const s: string): double;
begin
  var v := Trim(s);
  // both separators are accepted, so a file from anywhere sorts right
  if DefaultFormatSettings.DecimalSeparator <> '.' then v := StringReplace(v, DefaultFormatSettings.DecimalSeparator, '.', [rfReplaceAll]);
  var fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  fs.ThousandSeparator := #0;
  if not TryStrToFloat(v, result, fs) then result := 0;
end;

function TDataTable.matches(row: integer): boolean;
begin
  if FFilter = '' then exit(true);
  var needle := LowerCase(FFilter);
  if (FFilterColumn >= 0) and (FFilterColumn < FColumns.Count) then exit(Pos(needle, LowerCase(getCell(FFilterColumn, row))) > 0);
  for var c := 0 to FColumns.Count-1 do if Pos(needle, LowerCase(getCell(c, row))) > 0 then exit(true);
  result := false;
end;

function TDataTable.compareRows(a, b: integer): integer;
begin
  result := 0;
  if (FSortColumn < 0) or (FSortColumn >= FColumns.Count) then exit;
  if Assigned(FOnCompare) then begin
    FOnCompare(self, FSortColumn, a, b, result);
    if result <> 0 then exit(if FSortDescending then -result else result);
  end;
  var sa := getCell(FSortColumn, a);
  var sb := getCell(FSortColumn, b);
  match FColumns[FSortColumn].Kind of
    ckNumber: result := CompareValue(numberOf(sa), numberOf(sb));
    ckCheck: result := ord(checkValue(sa))-ord(checkValue(sb));
  else
    result := AnsiCompareText(sa, sb);
  end;
  if FSortDescending then result := -result;
end;

// the view from the stored rows: filtered, then sorted
procedure TDataTable.rebuild;
begin
  if FVirtualCount > 0 then begin
    // a virtual table shows its rows as they come; the order is the identity
    if length(FOrder) <> FVirtualCount then begin
      SetLength(FOrder, FVirtualCount);
      for var i := 0 to FVirtualCount-1 do FOrder[i] := i;
      SetLength(FSelected, FVirtualCount);
    end;
    if FFocusRow >= FVirtualCount then FFocusRow := FVirtualCount-1;
    updateRange;
    Invalidate;
    exit;
  end;
  var focused := if (FFocusRow >= 0) and (FFocusRow < length(FOrder)) then FOrder[FFocusRow] else -1;
  SetLength(FOrder, 0);
  for var r := 0 to high(FCells) do if matches(r) then begin
    SetLength(FOrder, length(FOrder)+1);
    FOrder[high(FOrder)] := r;
  end;
  if (FSortColumn >= 0) and (length(FOrder) > 1) then begin
    // an insertion sort keeps equal rows in their stored order
    for var i := 1 to high(FOrder) do begin
      var k := FOrder[i];
      var j := i-1;
      while (j >= 0) and (compareRows(FOrder[j], k) > 0) do begin
        FOrder[j+1] := FOrder[j];
        dec(j);
      end;
      FOrder[j+1] := k;
    end;
  end;
  FFocusRow := -1;
  for var i := 0 to high(FOrder) do if FOrder[i] = focused then FFocusRow := i;
  updateRange;
  Invalidate;
end;

function TDataTable.ShownRow(index: integer): integer;
begin
  result := if (index >= 0) and (index < length(FOrder)) then FOrder[index] else -1;
end;

function TDataTable.ShownCount: integer;
begin
  result := length(FOrder);
end;

function TDataTable.FocusedRow: integer;
begin
  result := ShownRow(FFocusRow);
end;

procedure TDataTable.FocusRow(row: integer);
begin
  for var i := 0 to high(FOrder) do if FOrder[i] = row then begin
    FFocusRow := i;
    ensureVisible(i);
    Invalidate;
    exit;
  end;
end;

// -- selection ----------------------

function TDataTable.getSelectedRow(index: integer): boolean;
begin
  result := (index >= 0) and (index < length(FSelected)) and FSelected[index];
end;

procedure TDataTable.setSelectedRow(index: integer; value: boolean);
begin
  if (index < 0) or (index >= length(FSelected)) or (FSelected[index] = value) then exit;
  if value and (FSelection = dsSingle) then ClearSelection;
  if value and (FSelection = dsNone) then exit;
  FSelected[index] := value;
  Invalidate;
end;

procedure TDataTable.SelectAll;
begin
  if FSelection <> dsMulti then exit;
  for var i := 0 to high(FOrder) do FSelected[FOrder[i]] := true;
  Invalidate;
end;

procedure TDataTable.ClearSelection;
begin
  for var i := 0 to high(FSelected) do FSelected[i] := false;
  Invalidate;
end;

function TDataTable.SelectedCount: integer;
begin
  result := 0;
  for var i := 0 to high(FSelected) do if FSelected[i] then inc(result);
end;

procedure TDataTable.clickRow(index: integer; shift: TShiftState);
begin
  if (index < 0) or (index >= length(FOrder)) then exit;
  var row := FOrder[index];
  if FSelection = dsMulti then begin
    if ssCtrl in shift then FSelected[row] := not FSelected[row]
    else if (ssShift in shift) and (FFocusRow >= 0) then begin
      for var i := 0 to high(FSelected) do FSelected[i] := false;
      for var i := Min(FFocusRow, index) to Max(FFocusRow, index) do FSelected[FOrder[i]] := true;
    end else begin
      for var i := 0 to high(FSelected) do FSelected[i] := false;
      FSelected[row] := true;
    end;
  end else if FSelection = dsSingle then begin
    for var i := 0 to high(FSelected) do FSelected[i] := false;
    FSelected[row] := true;
  end;
  if not (ssShift in shift) or (FFocusRow < 0) then FFocusRow := index;
  ensureVisible(index);
  Invalidate;
  if Assigned(FOnSelect) then FOnSelect(self, row, -1);
end;

// -- geometry ----------------------

function TDataTable.rowPx: integer;
begin
  result := if FRowHeight > 0 then scaled(self, FRowHeight) else lineHeightOf(Font)+scaled(self, 8);
end;

function TDataTable.headerPx: integer;
begin
  if not FShowHeader then exit(0);
  result := if FHeaderHeight > 0 then scaled(self, FHeaderHeight) else lineHeightOf(Font)+scaled(self, 10);
end;

function TDataTable.columnWidthPx(column: integer): integer;
begin
  var col := FColumns[column];
  if not col.Visible then exit(0);
  result := scaled(self, col.Width);
  if col.AutoWidth then begin
    // the column with AutoWidth takes what the fixed ones leave
    var fixed := if FShowRowNumbers then scaled(self, 40) else 0;
    for var c := 0 to FColumns.Count-1 do if FColumns[c].Visible and not FColumns[c].AutoWidth then fixed += scaled(self, FColumns[c].Width);
    result := Max(ClientWidth-fixed, scaled(self, col.MinWidth));
  end;
end;

function TDataTable.columnLeft(column: integer): integer;
begin
  result := if FShowRowNumbers then scaled(self, 40) else 0;
  for var c := 0 to column-1 do result += columnWidthPx(c);
end;

function TDataTable.totalWidth: integer;
begin
  // the scroll range counts the auto-width column at its least, so the range
  // never follows the client width: a range set while the bounds change
  // leaves the control at its old place
  result := if FShowRowNumbers then scaled(self, 40) else 0;
  for var c := 0 to FColumns.Count-1 do begin
    var col := FColumns[c];
    if not col.Visible then continue;
    result += if col.AutoWidth then scaled(self, col.MinWidth) else scaled(self, col.Width);
  end;
end;

function TDataTable.columnAt(x: integer): integer;
begin
  result := -1;
  x += HorzScrollBar.Position;
  for var c := 0 to FColumns.Count-1 do begin
    if not FColumns[c].Visible then continue;
    var left := columnLeft(c);
    if (x >= left) and (x < left+columnWidthPx(c)) then exit(c);
  end;
end;

// the column whose right edge is under x, for a drag of its width
function TDataTable.edgeAt(x: integer): integer;
begin
  result := -1;
  x += HorzScrollBar.Position;
  for var c := 0 to FColumns.Count-1 do begin
    if not FColumns[c].Visible or FColumns[c].AutoWidth then continue;
    var right := columnLeft(c)+columnWidthPx(c);
    if Abs(x-right) <= scaled(self, 3) then exit(c);
  end;
end;

function TDataTable.shownRowTop(index: integer): integer;
begin
  result := headerPx+index*rowPx;
end;

function TDataTable.shownRowAt(y: integer): integer;
begin
  y += VertScrollBar.Position;
  if y < headerPx then exit(-1);
  result := (y-headerPx) div rowPx;
  if result >= length(FOrder) then result := -1;
end;

function TDataTable.cellText(row, column: integer): string;
begin
  result := getCell(column, row);
  var col := FColumns[column];
  if (col.Kind = ckNumber) and (col.Format <> '') and (Trim(result) <> '') then begin
    var v := numberOf(result);
    try
      result := if Pos('%d', col.Format) > 0 then Format(col.Format, [Round(v)]) else Format(col.Format, [v]);
    except
      // a pattern that does not fit the value keeps the raw text
    end;
  end;
end;

procedure TDataTable.updateRange;
begin
  if not HandleAllocated then exit;
  // only what changes goes to the scroll bars: a bar set while the bounds
  // are being changed makes the control keep its old place
  var rh := rowPx;
  if VertScrollBar.Increment <> rh then VertScrollBar.Increment := rh;
  var page := Max(ClientHeight, 1);
  if VertScrollBar.Page <> page then VertScrollBar.Page := page;
  var range := headerPx+length(FOrder)*rh;
  if VertScrollBar.Range <> range then VertScrollBar.Range := range;
  var step := scaled(self, 20);
  if HorzScrollBar.Increment <> step then HorzScrollBar.Increment := step;
  page := Max(ClientWidth, 1);
  if HorzScrollBar.Page <> page then HorzScrollBar.Page := page;
  range := totalWidth;
  if HorzScrollBar.Range <> range then HorzScrollBar.Range := range;
end;

procedure TDataTable.ensureVisible(index: integer);
begin
  if (index < 0) or not HandleAllocated then exit;
  var top := shownRowTop(index);
  if top-headerPx < VertScrollBar.Position then VertScrollBar.Position := top-headerPx
  else if top+rowPx > VertScrollBar.Position+ClientHeight then VertScrollBar.Position := top+rowPx-ClientHeight;
end;

// a scroll repaints everything: the header stays in place
procedure TDataTable.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TDataTable.Resize;
begin
  inherited Resize;
  // the scroll bars wait for the paint: set while the bounds change, they
  // make the control keep its old place
  FRangeDirty := true;
  Invalidate;
end;

procedure TDataTable.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

procedure TDataTable.columnsChanged;
begin
  for var r := 0 to high(FCells) do if length(FCells[r]) < FColumns.Count then SetLength(FCells[r], FColumns.Count);
  if FSortColumn >= FColumns.Count then FSortColumn := -1;
  rebuild;
end;

// -- painting ----------------------

procedure TDataTable.Paint;
begin
  if FRangeDirty then begin
    FRangeDirty := false;
    updateRange;
  end;
  var back := pick(FBackColor, Color);
  var text := pick(FTextColor, clWindowText);
  var header := pick(FHeaderColor, blend(back, clWindowText, 7));
  var headerText := pick(FHeaderTextColor, clWindowText);
  var alt := pick(FAlternateColor, blend(back, clWindowText, 4));
  var grid := pick(FGridColor, blend(back, clWindowText, 12));
  var selected := pick(FSelectedColor, clHighlight);
  var selectedText := pick(FSelectedTextColor, contrastText(selected));
  var accent := ColorToRGB(clHighlight);
  // the canvas origin sits at the scroll position: everything paints in
  // unscrolled coordinates, the view is the visible part
  var view := ClientRect;
  OffsetRect(view, HorzScrollBar.Position, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var rh := rowPx;
  var hh := headerPx;
  var pad := scaled(self, FPadding);
  var numbers := if FShowRowNumbers then scaled(self, 40) else 0;
  var first := Max((VertScrollBar.Position-hh) div rh, 0);
  var last := Min((VertScrollBar.Position+ClientHeight-hh) div rh, high(FOrder));
  for var i := first to last do begin
    var row := FOrder[i];
    var top := shownRowTop(i);
    var fill := if FSelected[row] then selected else if FAlternateRows and (i mod 2 = 1) then alt else back;
    // the keyboard row shows as a stronger fill, never as a frame
    if (i = FFocusRow) and Focused and ringEnabled then fill := blend(fill, clHighlight, (if FSelected[row] then 25 else 15));
    if (i = FHotRow) and hoverEnabled and not FSelected[row] then fill := hoverColor(fill);
    if fill <> back then sp.FillRect(Rect(view.Left, top, view.Right, top+rh), fill);
    if FShowGridLines then sp.FillRect(Rect(view.Left, top+rh-1, view.Right, top+rh), grid);
  end;
  if FShowGridLines then
    for var c := 0 to FColumns.Count-1 do if FColumns[c].Visible then begin
      var right := columnLeft(c)+columnWidthPx(c);
      sp.FillRect(Rect(right-1, view.Top, right, view.Bottom), grid);
    end;
  // the check marks of the check columns
  for var i := first to last do
    for var c := 0 to FColumns.Count-1 do begin
      if not FColumns[c].Visible or (FColumns[c].Kind <> ckCheck) then continue;
      var left := columnLeft(c);
      var w := columnWidthPx(c);
      var top := shownRowTop(i);
      var size := Min(rh-scaled(self, 8), scaled(self, 16));
      var box := Rect(left+(w-size) div 2, top+(rh-size) div 2, left+(w+size) div 2, top+(rh+size) div 2);
      var on := checkValue(getCell(c, FOrder[i]));
      paintRoundRect(sp, box, scaled(self, 3), (if on then accent else clNone), (if on then clNone else blend(back, text, 40)));
      if on then paintCheck(sp, box, size div 2, contrastText(accent), 2);
    end;
  // the header stays on top while the rows scroll under it
  if hh > 0 then begin
    var headerTop := VertScrollBar.Position;
    sp.FillRect(Rect(view.Left, headerTop, view.Right, headerTop+hh), header);
    sp.FillRect(Rect(view.Left, headerTop+hh-1, view.Right, headerTop+hh), grid);
    for var c := 0 to FColumns.Count-1 do begin
      if not FColumns[c].Visible then continue;
      var left := columnLeft(c);
      var w := columnWidthPx(c);
      if (c = FHotHeader) and FColumns[c].Sortable and hoverEnabled then sp.FillRect(Rect(left, headerTop, left+w, headerTop+hh-1), hoverColor(header));
      sp.FillRect(Rect(left+w-1, headerTop+scaled(self, 6), left+w, headerTop+hh-scaled(self, 6)), grid);
      if c = FSortColumn then begin
        var cx := left+w-pad-scaled(self, 4);
        var cy := headerTop+hh div 2;
        paintChevron(sp, Rect(cx-scaled(self, 5), cy-scaled(self, 5), cx+scaled(self, 5), cy+scaled(self, 5)), (if FSortDescending then cdDown else cdUp), scaled(self, 7), accent);
      end;
    end;
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  // the rows scroll under the header: their text stops where it begins
  Canvas.ClipRect := Rect(view.Left, view.Top+hh, view.Right, view.Bottom);
  Canvas.Clipping := true;
  for var i := first to last do begin
    var row := FOrder[i];
    var top := shownRowTop(i);
    var rowFill := if FSelected[row] then selected else if FAlternateRows and (i mod 2 = 1) then alt else back;
    if FShowRowNumbers then begin
      style.Alignment := taRightJustify;
      Canvas.Font.Color := blend(text, rowFill, 45);
      var nr := Rect(0, top, numbers-pad, top+rh);
      Canvas.TextRect(nr, nr.Left, nr.Top, IntToStr(i+1), style);
    end;
    for var c := 0 to FColumns.Count-1 do begin
      var col := FColumns[c];
      if not col.Visible or (col.Kind = ckCheck) then continue;
      var left := columnLeft(c);
      var w := columnWidthPx(c);
      var cellBack := rowFill;
      var ink := if FSelected[row] then selectedText else text;
      if Assigned(FOnGetCellColors) then begin
        FOnGetCellColors(self, row, c, cellBack, ink);
        if cellBack <> rowFill then begin
          Canvas.Brush.Style := bsSolid;
          Canvas.Brush.Color := cellBack;
          Canvas.FillRect(left, top, left+w-1, top+rh-1);
          Canvas.Brush.Style := bsClear;
        end;
      end;
      if Assigned(FOnDrawCell) then begin
        var state: TDrawState := [];
        if FSelected[row] then state += [dsSelected];
        if i = FFocusRow then state += [dsFocused];
        if not Enabled then state += [dsDisabled];
        var handled := false;
        FOnDrawCell(self, Canvas, Rect(left, top, left+w, top+rh), row, c, state, handled);
        if handled then continue;
      end;
      style.Alignment := col.Alignment;
      Canvas.Font.Color := ink;
      var r := Rect(left+pad, top, left+w-pad, top+rh);
      if r.Right > r.Left then Canvas.TextRect(r, r.Left, r.Top, cellText(row, c), style);
    end;
  end;
  Canvas.Clipping := false;
  if hh > 0 then begin
    var headerTop := VertScrollBar.Position;
    Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.Font.Color := headerText;
    for var c := 0 to FColumns.Count-1 do begin
      var col := FColumns[c];
      if not col.Visible then continue;
      var left := columnLeft(c);
      var w := columnWidthPx(c);
      style.Alignment := col.Alignment;
      var r := Rect(left+pad, headerTop, left+w-pad-(if c = FSortColumn then scaled(self, 14) else 0), headerTop+hh);
      if r.Right > r.Left then Canvas.TextRect(r, r.Left, r.Top, col.Caption, style);
    end;
    Canvas.Font.Style := Font.Style;
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TDataTable.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  if (headerPx > 0) and (Y < headerPx) then begin
    var edge := edgeAt(X);
    if edge >= 0 then begin
      // a drag on the edge of a header changes the width of the column
      FDragColumn := edge;
      FDragStart := X;
      FDragWidth := FColumns[edge].Width;
      exit;
    end;
    var c := columnAt(X);
    if c < 0 then exit;
    if Assigned(FOnHeaderClick) then FOnHeaderClick(self, -1, c);
    if FColumns[c].Sortable then begin
      if FSortColumn = c then SortDescending := not FSortDescending
      else begin
        FSortDescending := false;
        SortColumn := c;
      end;
    end;
    exit;
  end;
  var index := shownRowAt(Y);
  if index < 0 then exit;
  clickRow(index, Shift);
  if Assigned(FOnCellClick) then FOnCellClick(self, FOrder[index], columnAt(X));
end;

procedure TDataTable.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragColumn >= 0 then begin
    FColumns[FDragColumn].Width := FDragWidth+Round((X-FDragStart)*96/Font.PixelsPerInch);
    exit;
  end;
  var header := (headerPx > 0) and (Y < headerPx);
  Cursor := if header and (edgeAt(X) >= 0) then crHSplit else crDefault;
  var hotHeader := if header then columnAt(X) else -1;
  var hotRow := if header then -1 else shownRowAt(Y);
  if (hotHeader <> FHotHeader) or (hotRow <> FHotRow) then begin
    FHotHeader := hotHeader;
    FHotRow := hotRow;
    Invalidate;
  end;
end;

procedure TDataTable.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragColumn := -1;
end;

procedure TDataTable.MouseLeave;
begin
  inherited MouseLeave;
  if (FHotRow >= 0) or (FHotHeader >= 0) then begin
    FHotRow := -1;
    FHotHeader := -1;
    Invalidate;
  end;
end;

procedure TDataTable.DblClick;
begin
  inherited DblClick;
  var p := ScreenToClient(Mouse.CursorPos);
  var index := shownRowAt(p.Y);
  if (index >= 0) and Assigned(FOnCellDblClick) then FOnCellDblClick(self, FOrder[index], columnAt(p.X));
end;

procedure TDataTable.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var n := length(FOrder);
  if n = 0 then exit;
  var page := Max(ClientHeight div rowPx, 1);
  var target := match Key of
    VK_UP: Max(FFocusRow-1, 0);
    VK_DOWN: Min(FFocusRow+1, n-1);
    VK_PRIOR: Max(FFocusRow-page, 0);
    VK_NEXT: Min(FFocusRow+page, n-1);
    VK_HOME: 0;
    VK_END: n-1;
  else
    -2
  end;
  if target = -2 then begin
    if (Key = VK_A) and (ssCtrl in Shift) then begin
      SelectAll;
      Key := 0;
    end else if (Key = VK_SPACE) and (FFocusRow >= 0) and (FSelection = dsMulti) then begin
      Selected[FOrder[FFocusRow]] := not Selected[FOrder[FFocusRow]];
      Key := 0;
    end;
    exit;
  end;
  Key := 0;
  clickRow(target, Shift*[ssShift]);
end;

procedure TDataTable.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TDataTable.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

procedure TDataTable.setColumns(value: TDataColumns);
begin
  FColumns.Assign(value);
end;

procedure TDataTable.setSelection(value: TDataSelection);
begin
  if FSelection = value then exit;
  FSelection := value;
  if value = dsNone then ClearSelection
  else if value = dsSingle then begin
    var keep := FocusedRow;
    ClearSelection;
    if keep >= 0 then FSelected[keep] := true;
  end;
  Invalidate;
end;

procedure TDataTable.setFilter(const value: string);
begin
  if FFilter = value then exit;
  FFilter := value;
  rebuild;
end;

procedure TDataTable.setFilterColumn(value: integer);
begin
  if FFilterColumn = value then exit;
  FFilterColumn := value;
  rebuild;
end;

procedure TDataTable.setSortColumn(value: integer);
begin
  if value < -1 then value := -1;
  if FSortColumn = value then exit;
  FSortColumn := value;
  rebuild;
  if not (csLoading in ComponentState) and Assigned(FOnSort) then FOnSort(self);
end;

procedure TDataTable.setSortDescending(value: boolean);
begin
  if FSortDescending = value then exit;
  FSortDescending := value;
  rebuild;
  if not (csLoading in ComponentState) and Assigned(FOnSort) then FOnSort(self);
end;

function TDataTable.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowHeader;
    1: FAlternateRows;
    2: FShowGridLines;
    3: FShowRowNumbers;
  else
    FAutoSort
  end;
end;

procedure TDataTable.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowHeader := value;
    1: FAlternateRows := value;
    2: FShowGridLines := value;
    3: FShowRowNumbers := value;
  else
    FAutoSort := value;
  end;
  updateRange;
  Invalidate;
end;

function TDataTable.getMetric(index: integer): integer;
begin
  result := match index of
    0: FRowHeight;
    1: FHeaderHeight;
  else
    FPadding
  end;
end;

procedure TDataTable.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FRowHeight := value;
    1: FHeaderHeight := value;
  else
    FPadding := value;
  end;
  updateRange;
  Invalidate;
end;

function TDataTable.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FHeaderColor;
    1: FHeaderTextColor;
    2: FBackColor;
    3: FTextColor;
    4: FAlternateColor;
    5: FGridColor;
    6: FSelectedColor;
  else
    FSelectedTextColor
  end;
end;

procedure TDataTable.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FHeaderColor := value;
    1: FHeaderTextColor := value;
    2: FBackColor := value;
    3: FTextColor := value;
    4: FAlternateColor := value;
    5: FGridColor := value;
    6: FSelectedColor := value;
  else
    FSelectedTextColor := value;
  end;
  Invalidate;
end;

procedure TDataTable.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
