{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit GridPanel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  // how a child sits in its cell
  TGridCellAlign = (gaStretch, gaStart, gaCenter, gaEnd);

  { TGridPanel }

  // lays its children out on a grid of Columns by Rows, left to right and
  // top to bottom in the order of their position. A column or row takes a
  // share of the space after its weight, or a fixed size with a px suffix
  TGridPanel = class(TCustomControl)
  private
    FColumns, FRows, FColumnSpacing, FRowSpacing, FPadding: integer;
    FColumnWeights, FRowWeights: string;
    FHorizontalAlign, FVerticalAlign: TGridCellAlign;
    FShowGrid: boolean;
    FLaying: boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setWeights(index: integer; const value: string);
    function getWeights(index: integer): string;
    procedure setCellAlign(index: integer; value: TGridCellAlign);
    function getCellAlign(index: integer): TGridCellAlign;
    procedure setShowGrid(value: boolean);
    function ordered: TList;
    function rowCount(children: integer): integer;
    // the start offsets of the tracks, one more than the count
    function tracks(const weights: string; count, total, gap: integer): TIntegerDynArray;
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure Paint; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the cell a child sits in
    function CellOf(child: TControl; out column, row: integer): boolean;
  published
    property Columns: integer index 0 read getMetric write setMetric default 2;
    // 0 takes as many as the children need
    property Rows: integer index 1 read getMetric write setMetric default 0;
    property ColumnSpacing: integer index 2 read getMetric write setMetric default 6;
    property RowSpacing: integer index 3 read getMetric write setMetric default 6;
    property Padding: integer index 4 read getMetric write setMetric default 6;
    // comma separated, one per column: a weight like 2, or a size like 120px;
    // missing entries weigh 1
    property ColumnWeights: string index 0 read getWeights write setWeights;
    property RowWeights: string index 1 read getWeights write setWeights;
    property HorizontalAlign: TGridCellAlign index 0 read getCellAlign write setCellAlign default gaStretch;
    property VerticalAlign: TGridCellAlign index 1 read getCellAlign write setCellAlign default gaStretch;
    // the lines of the grid, at design time or always
    property ShowGrid: boolean read FShowGrid write setShowGrid default false;
    property Align;
    property Anchors;
    property BorderSpacing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
  end;

implementation

uses
  Math;

constructor TGridPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  FColumns := 2;
  FColumnSpacing := 6;
  FRowSpacing := 6;
  FPadding := 6;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TGridPanel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 180;
end;

function byPosition(a, b: Pointer): integer;
begin
  result := TControl(a).Top-TControl(b).Top;
  if result = 0 then result := TControl(a).Left-TControl(b).Left;
end;

function TGridPanel.ordered: TList;
begin
  result := TList.Create;
  for var i := 0 to ControlCount-1 do if Controls[i].Visible or (csDesigning in ComponentState) then result.Add(Controls[i]);
  result.Sort(@byPosition);
end;

function TGridPanel.rowCount(children: integer): integer;
begin
  result := if FRows > 0 then FRows else Max((children+Max(FColumns, 1)-1) div Max(FColumns, 1), 1);
end;

function TGridPanel.tracks(const weights: string; count, total, gap: integer): TIntegerDynArray;
begin
  SetLength(result, count+1);
  var parts := weights.Split([',']);
  var fixed: array of integer;
  var weight: array of double;
  SetLength(fixed, count);
  SetLength(weight, count);
  var fixedSum := 0;
  var weightSum := 0.0;
  for var i := 0 to count-1 do begin
    var spec := if i < length(parts) then Trim(parts[i]) else '';
    if spec.EndsWith('px') then begin
      fixed[i] := scaled(self, StrToIntDef(Copy(spec, 1, length(spec)-2), 0));
      weight[i] := 0;
    end else begin
      fixed[i] := 0;
      weight[i] := StrToFloatDef(spec, 1, DefaultFormatSettings);
      if weight[i] <= 0 then weight[i] := 1;
    end;
    fixedSum += fixed[i];
    weightSum += weight[i];
  end;
  var free := Max(total-gap*(count-1)-fixedSum, 0);
  var pos := 0;
  for var i := 0 to count-1 do begin
    result[i] := pos;
    var size := if fixed[i] > 0 then fixed[i] else (if weightSum > 0 then Round(free*weight[i]/weightSum) else 0);
    pos += size+gap;
  end;
  result[count] := pos-gap;
end;

procedure TGridPanel.AlignControls(AControl: TControl; var ARect: TRect);
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  var list := ordered;
  try
    var cols := Max(FColumns, 1);
    var rows := rowCount(list.Count);
    var pad := scaled(self, FPadding);
    var xs := tracks(FColumnWeights, cols, ClientWidth-pad*2, scaled(self, FColumnSpacing));
    var ys := tracks(FRowWeights, rows, ClientHeight-pad*2, scaled(self, FRowSpacing));
    for var i := 0 to list.Count-1 do begin
      var c := TControl(list[i]);
      var col := i mod cols;
      var row := i div cols;
      if row >= rows then begin
        // past the last row the children keep their size out of sight
        var away := Rect(ClientWidth, ClientHeight, ClientWidth+c.Width, ClientHeight+c.Height);
        if c.BoundsRect <> away then c.BoundsRect := away;
        continue;
      end;
      var cell := Rect(pad+xs[col], pad+ys[row], pad+xs[col+1]-(if col < cols-1 then scaled(self, FColumnSpacing) else 0), pad+ys[row+1]-(if row < rows-1 then scaled(self, FRowSpacing) else 0));
      // a child sizing itself keeps its size, or the two would fight
      var w := if (FHorizontalAlign = gaStretch) and not c.AutoSize then cell.Width else Min(c.Width, cell.Width);
      var h := if (FVerticalAlign = gaStretch) and not c.AutoSize then cell.Height else Min(c.Height, cell.Height);
      var x := match FHorizontalAlign of
        gaCenter: cell.Left+(cell.Width-w) div 2;
        gaEnd: cell.Right-w;
      else
        cell.Left
      end;
      var y := match FVerticalAlign of
        gaCenter: cell.Top+(cell.Height-h) div 2;
        gaEnd: cell.Bottom-h;
      else
        cell.Top
      end;
      // a placement only goes through when it changes something, since even
      // an unchanged one asks for another pass
      var r := Rect(x, y, x+w, y+h);
      if c.BoundsRect <> r then c.BoundsRect := r;
    end;
  finally
    list.Free;
    FLaying := false;
  end;
end;

function TGridPanel.CellOf(child: TControl; out column, row: integer): boolean;
begin
  var list := ordered;
  try
    var i := list.IndexOf(child);
    result := i >= 0;
    column := if result then i mod Max(FColumns, 1) else -1;
    row := if result then i div Max(FColumns, 1) else -1;
  finally
    list.Free;
  end;
end;

procedure TGridPanel.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := GetRGBColorResolvingParent;
  Canvas.FillRect(ClientRect);
  if not (FShowGrid or (csDesigning in ComponentState)) then exit;
  var list := ordered;
  try
    var cols := Max(FColumns, 1);
    var rows := rowCount(list.Count);
    var pad := scaled(self, FPadding);
    var xs := tracks(FColumnWeights, cols, ClientWidth-pad*2, scaled(self, FColumnSpacing));
    var ys := tracks(FRowWeights, rows, ClientHeight-pad*2, scaled(self, FRowSpacing));
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := ColorToRGB(clGrayText);
    Canvas.Brush.Style := bsClear;
    for var col := 0 to cols-1 do for var row := 0 to rows-1 do
      Canvas.Rectangle(pad+xs[col], pad+ys[row], pad+xs[col+1]-(if col < cols-1 then scaled(self, FColumnSpacing) else 0), pad+ys[row+1]-(if row < rows-1 then scaled(self, FRowSpacing) else 0));
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Style := bsSolid;
  finally
    list.Free;
  end;
end;

// -- properties ----------------------

function TGridPanel.getMetric(index: integer): integer;
begin
  result := match index of
    0: FColumns;
    1: FRows;
    2: FColumnSpacing;
    3: FRowSpacing;
  else
    FPadding
  end;
end;

procedure TGridPanel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if (index = 0) and (value < 1) then value := 1;
  if getMetric(index) = value then exit;
  match index of
    0: FColumns := value;
    1: FRows := value;
    2: FColumnSpacing := value;
    3: FRowSpacing := value;
  else
    FPadding := value;
  end;
  ReAlign;
  Invalidate;
end;

function TGridPanel.getWeights(index: integer): string;
begin
  result := if index = 0 then FColumnWeights else FRowWeights;
end;

procedure TGridPanel.setWeights(index: integer; const value: string);
begin
  if getWeights(index) = value then exit;
  if index = 0 then FColumnWeights := value else FRowWeights := value;
  ReAlign;
  Invalidate;
end;

function TGridPanel.getCellAlign(index: integer): TGridCellAlign;
begin
  result := if index = 0 then FHorizontalAlign else FVerticalAlign;
end;

procedure TGridPanel.setCellAlign(index: integer; value: TGridCellAlign);
begin
  if getCellAlign(index) = value then exit;
  if index = 0 then FHorizontalAlign := value else FVerticalAlign := value;
  ReAlign;
end;

procedure TGridPanel.setShowGrid(value: boolean);
begin
  if FShowGrid = value then exit;
  FShowGrid := value;
  Invalidate;
end;

end.
