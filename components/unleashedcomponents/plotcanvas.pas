{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PlotCanvas;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  TPlotCanvas = class;
  // the mark at every point: none, a dot, a square, a cross, a hollow circle,
  // a triangle, a diamond, a plus
  TPlotMarker = (pmNone, pmDot, pmSquare, pmCross, pmCircle, pmTriangle, pmDiamond, pmPlus);
  TPlotPoint = record
    X, Y: double;
  end;
  TPlotFunction = function(x: double): double of object;
  TPlotPointEvent = procedure(Sender: TObject; curve, index: integer) of object;
  // the mouse moved over the plot; x and y are plot coordinates
  TPlotMouseEvent = procedure(Sender: TObject; x, y: double) of object;
  // the view changed by a zoom or a pan
  TPlotViewEvent = procedure(Sender: TObject; xMin, xMax, yMin, yMax: double) of object;

  { TPlotCurve }

  TPlotCurve = class(TCollectionItem)
  private
    FTitle: string;
    FColor: TColor;
    FWidth: integer;
    FMarker: TPlotMarker;
    FVisible, FFilled, FStepped: boolean;
    FTag: PtrInt;
    FX, FY: array of double;
    FCount: integer;
    procedure setTitle(const value: string);
    procedure setColor(value: TColor);
    procedure setWidth(value: integer);
    procedure setMarker(value: TPlotMarker);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    function getX(index: integer): double;
    function getY(index: integer): double;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    procedure AddPoint(x, y: double);
    procedure AddPoints(const xs, ys: array of double);
    // y values at 0, 1, 2 and so on
    procedure AddValues(const ys: array of double);
    procedure Clear;
    // keeps the last n points, for a rolling plot
    procedure Trim(n: integer);
    property Count: integer read FCount;
    property X[index: integer]: double read getX;
    property Y[index: integer]: double read getY;
  published
    property Title: string read FTitle write setTitle;
    // clDefault takes a color from the palette of the plot
    property Color: TColor read FColor write setColor default clDefault;
    property Width: integer read FWidth write setWidth default 2;
    property Marker: TPlotMarker read FMarker write setMarker default pmNone;
    property Visible: boolean index 0 read getFlag write setFlag default true;
    // the area down to zero shaded
    property Filled: boolean index 1 read getFlag write setFlag default false;
    // a staircase instead of a slope between points
    property Stepped: boolean index 2 read getFlag write setFlag default false;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TPlotCurves }

  TPlotCurves = class(TOwnedCollection)
  private
    function getItem(index: integer): TPlotCurve;
    procedure setItem(index: integer; value: TPlotCurve);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TPlotCurve;
    property Items[index: integer]: TPlotCurve read getItem write setItem; default;
  end;

  { TPlotCanvas }

  // x and y pairs as curves on two axes with ticks and a grid: a
  // measurement, a function, a rolling signal. The wheel zooms, a drag
  // pans, a crosshair reads the value, the range follows the data or
  // stays where it was set
  TPlotCanvas = class(TCustomControl)
  private
    FCurves: TPlotCurves;
    FXMin, FXMax, FYMin, FYMax: double;
    FAutoRange, FShowGrid, FShowLegend, FShowCrosshair, FInteractive, FShowAxes, FSquare, FShowZero: boolean;
    FXTitle, FYTitle, FTitle, FXFormat, FYFormat: string;
    FPadding, FTickLength: integer;
    FGridColor, FAxisColor, FTextColor, FBackColor, FPlotColor, FCrosshairColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FArea: TRect; // where the curves go, inside the axes
    FMouse: TPoint;
    FMouseInside, FPanning: boolean;
    FPanStart: TPoint;
    FPanOrigin: array[0..3] of double;
    FHotCurve, FHotIndex: integer;
    FOnPointHover, FOnPointClick: TPlotPointEvent;
    FOnMouseMovePlot: TPlotMouseEvent;
    FOnViewChange: TPlotViewEvent;
    procedure setCurves(value: TPlotCurves);
    procedure setRange(index: integer; value: double);
    function getRange(index: integer): double;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function curveColor(index: integer): TColor;
    procedure dataRange(out x0, x1, y0, y1: double);
    procedure viewRange(out x0, x1, y0, y1: double);
    function niceStep(span: double; pixels, want: integer): double;
    function tickText(value, step: double; const fmt: string): string;
    procedure findPoint(px, py: integer; out curve, index: integer);
    procedure viewChanged;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddCurve(const title: string; color: TColor = clDefault): TPlotCurve;
    // a curve from a function sampled across the x range in `samples` points
    function AddFunction(const title: string; f: TPlotFunction; xFrom, xTo: double; samples: integer = 200; color: TColor = clDefault): TPlotCurve;
    procedure Clear;
    // the view back on the data
    procedure ZoomToFit;
    procedure SetView(xMin, xMax, yMin, yMax: double);
    procedure Zoom(factor: double);
    // pixels to plot coordinates and back
    function ToPlot(px, py: integer): TPlotPoint;
    function ToPixel(x, y: double): TPoint;
    property PlotArea: TRect read FArea;
  published
    property Curves: TPlotCurves read FCurves write setCurves;
    property XMin: double index 0 read getRange write setRange;
    property XMax: double index 1 read getRange write setRange;
    property YMin: double index 2 read getRange write setRange;
    property YMax: double index 3 read getRange write setRange;
    // the view follows the data; a zoom or a pan turns it off
    property AutoRange: boolean index 0 read getFlag write setFlag default true;
    property ShowGrid: boolean index 1 read getFlag write setFlag default true;
    property ShowLegend: boolean index 2 read getFlag write setFlag default true;
    // the readout follows the mouse
    property ShowCrosshair: boolean index 3 read getFlag write setFlag default true;
    // the wheel zooms, a drag pans, a double click fits
    property Interactive: boolean index 4 read getFlag write setFlag default true;
    property ShowAxes: boolean index 5 read getFlag write setFlag default true;
    // the same scale on both axes
    property Square: boolean index 6 read getFlag write setFlag default false;
    // the axes drawn through zero when it is in view
    property ShowZero: boolean index 7 read getFlag write setFlag default true;
    property Title: string index 0 read getText write setText;
    property XTitle: string index 1 read getText write setText;
    property YTitle: string index 2 read getText write setText;
    // Format patterns for the tick labels; empty picks the digits by the step
    property XFormat: string index 3 read getText write setText;
    property YFormat: string index 4 read getText write setText;
    property Padding: integer index 0 read getMetric write setMetric default 8;
    property TickLength: integer index 1 read getMetric write setMetric default 4;
    // clDefault takes the colors of the theme
    property GridColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property AxisColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    // the area inside the axes
    property PlotColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property CrosshairColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the mouse is near a point; curve -1 once it left
    property OnPointHover: TPlotPointEvent read FOnPointHover write FOnPointHover;
    property OnPointClick: TPlotPointEvent read FOnPointClick write FOnPointClick;
    property OnMouseMovePlot: TPlotMouseEvent read FOnMouseMovePlot write FOnMouseMovePlot;
    property OnViewChange: TPlotViewEvent read FOnViewChange write FOnViewChange;
    property Align;
    property Anchors;
    property BorderSpacing;
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

const
  PALETTE: array[0..7] of TColor = ($D98B3B, $5CB85C, $4E4EE0, $F0AD4E, $B35CA0, $17A2B8, $6C757D, $343A40);

{ TPlotCurve }

constructor TPlotCurve.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clDefault;
  FWidth := 2;
  FVisible := true;
end;

procedure TPlotCurve.Assign(Source: TPersistent);
begin
  if Source is TPlotCurve then begin
    var s := TPlotCurve(Source);
    FTitle := s.FTitle;
    FColor := s.FColor;
    FWidth := s.FWidth;
    FMarker := s.FMarker;
    FVisible := s.FVisible;
    FFilled := s.FFilled;
    FStepped := s.FStepped;
    FTag := s.FTag;
    FX := Copy(s.FX);
    FY := Copy(s.FY);
    FCount := s.FCount;
    Changed(false);
  end else inherited Assign(Source);
end;

function TPlotCurve.GetDisplayName: string;
begin
  result := if FTitle <> '' then FTitle else inherited GetDisplayName;
end;

procedure TPlotCurve.AddPoint(x, y: double);
begin
  if FCount = length(FX) then begin
    SetLength(FX, Max(16, FCount*2));
    SetLength(FY, length(FX));
  end;
  FX[FCount] := x;
  FY[FCount] := y;
  inc(FCount);
  Changed(false);
end;

procedure TPlotCurve.AddPoints(const xs, ys: array of double);
begin
  var n := Min(length(xs), length(ys));
  if FCount+n > length(FX) then begin
    SetLength(FX, FCount+n);
    SetLength(FY, FCount+n);
  end;
  for var i := 0 to n-1 do begin
    FX[FCount] := xs[i];
    FY[FCount] := ys[i];
    inc(FCount);
  end;
  Changed(false);
end;

procedure TPlotCurve.AddValues(const ys: array of double);
begin
  if FCount+length(ys) > length(FX) then begin
    SetLength(FX, FCount+length(ys));
    SetLength(FY, FCount+length(ys));
  end;
  for var i := 0 to high(ys) do begin
    FX[FCount] := FCount;
    FY[FCount] := ys[i];
    inc(FCount);
  end;
  Changed(false);
end;

procedure TPlotCurve.Clear;
begin
  FCount := 0;
  Changed(false);
end;

procedure TPlotCurve.Trim(n: integer);
begin
  if (n < 0) or (FCount <= n) then exit;
  var drop := FCount-n;
  for var i := 0 to n-1 do begin
    FX[i] := FX[i+drop];
    FY[i] := FY[i+drop];
  end;
  FCount := n;
  Changed(false);
end;

function TPlotCurve.getX(index: integer): double;
begin
  result := if (index >= 0) and (index < FCount) then FX[index] else 0;
end;

function TPlotCurve.getY(index: integer): double;
begin
  result := if (index >= 0) and (index < FCount) then FY[index] else 0;
end;

procedure TPlotCurve.setTitle(const value: string);
begin
  if FTitle = value then exit;
  FTitle := value;
  Changed(false);
end;

procedure TPlotCurve.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TPlotCurve.setWidth(value: integer);
begin
  value := Max(value, 1);
  if FWidth = value then exit;
  FWidth := value;
  Changed(false);
end;

procedure TPlotCurve.setMarker(value: TPlotMarker);
begin
  if FMarker = value then exit;
  FMarker := value;
  Changed(false);
end;

function TPlotCurve.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FVisible;
    1: FFilled;
  else
    FStepped
  end;
end;

procedure TPlotCurve.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FVisible := value;
    1: FFilled := value;
  else
    FStepped := value;
  end;
  Changed(false);
end;

{ TPlotCurves }

function TPlotCurves.getItem(index: integer): TPlotCurve;
begin
  result := TPlotCurve(inherited Items[index]);
end;

procedure TPlotCurves.setItem(index: integer; value: TPlotCurve);
begin
  inherited Items[index] := value;
end;

function TPlotCurves.Add: TPlotCurve;
begin
  result := TPlotCurve(inherited Add);
end;

procedure TPlotCurves.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TPlotCanvas then TPlotCanvas(Owner).Invalidate;
end;

{ TPlotCanvas }

constructor TPlotCanvas.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FCurves := TPlotCurves.Create(self, TPlotCurve);
  FXMin := 0;
  FXMax := 10;
  FYMin := -1;
  FYMax := 1;
  FAutoRange := true;
  FShowGrid := true;
  FShowLegend := true;
  FShowCrosshair := true;
  FInteractive := true;
  FShowAxes := true;
  FShowZero := true;
  FPadding := 8;
  FTickLength := 4;
  FGridColor := clDefault;
  FAxisColor := clDefault;
  FTextColor := clDefault;
  FBackColor := clDefault;
  FPlotColor := clDefault;
  FCrosshairColor := clDefault;
  FAntialiasing := asTheme;
  FHotCurve := -1;
  FHotIndex := -1;
  TabStop := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TPlotCanvas.Destroy;
begin
  FCurves.Free;
  inherited Destroy;
end;

class function TPlotCanvas.GetControlClassDefaultSize: TSize;
begin
  result.cx := 320;
  result.cy := 220;
end;

function TPlotCanvas.AddCurve(const title: string; color: TColor): TPlotCurve;
begin
  result := FCurves.Add;
  result.Title := title;
  result.Color := color;
end;

function TPlotCanvas.AddFunction(const title: string; f: TPlotFunction; xFrom, xTo: double; samples: integer; color: TColor): TPlotCurve;
begin
  result := AddCurve(title, color);
  if not Assigned(f) then exit;
  samples := Max(samples, 2);
  FCurves.BeginUpdate;
  try
    for var i := 0 to samples-1 do begin
      var x := xFrom+(xTo-xFrom)*i/(samples-1);
      var y := f(x);
      if not IsNan(y) and not IsInfinite(y) then result.AddPoint(x, y);
    end;
  finally
    FCurves.EndUpdate;
  end;
end;

procedure TPlotCanvas.Clear;
begin
  FCurves.Clear;
  Invalidate;
end;

// -- ranges ----------------------

function TPlotCanvas.curveColor(index: integer): TColor;
begin
  result := FCurves[index].Color;
  if result = clDefault then result := PALETTE[index mod length(PALETTE)];
  result := ColorToRGB(result);
end;

procedure TPlotCanvas.dataRange(out x0, x1, y0, y1: double);
begin
  var any := false;
  x0 := 0; x1 := 0; y0 := 0; y1 := 0;
  for var c := 0 to FCurves.Count-1 do begin
    var curve := FCurves[c];
    if not curve.Visible then continue;
    for var i := 0 to curve.Count-1 do begin
      if not any then begin
        x0 := curve.FX[i]; x1 := x0;
        y0 := curve.FY[i]; y1 := y0;
        any := true;
      end else begin
        x0 := Min(x0, curve.FX[i]); x1 := Max(x1, curve.FX[i]);
        y0 := Min(y0, curve.FY[i]); y1 := Max(y1, curve.FY[i]);
      end;
    end;
    if curve.Filled then begin y0 := Min(y0, 0); y1 := Max(y1, 0); end;
  end;
  if not any then begin x0 := 0; x1 := 10; y0 := -1; y1 := 1; end;
  if x1 = x0 then begin x0 -= 1; x1 += 1; end;
  if y1 = y0 then begin y0 -= 1; y1 += 1; end;
  // a little air around the data
  var dy := (y1-y0)*0.05;
  y0 -= dy;
  y1 += dy;
end;

procedure TPlotCanvas.viewRange(out x0, x1, y0, y1: double);
begin
  if FAutoRange then dataRange(x0, x1, y0, y1)
  else begin
    x0 := FXMin; x1 := FXMax; y0 := FYMin; y1 := FYMax;
    if x1 <= x0 then x1 := x0+1;
    if y1 <= y0 then y1 := y0+1;
  end;
  if FSquare and (FArea.Width > 0) and (FArea.Height > 0) then begin
    // the same units per pixel on both axes, the view grown to fit
    var sx := (x1-x0)/FArea.Width;
    var sy := (y1-y0)/FArea.Height;
    if sx > sy then begin
      var mid := (y0+y1)/2;
      y0 := mid-sx*FArea.Height/2;
      y1 := mid+sx*FArea.Height/2;
    end else begin
      var mid := (x0+x1)/2;
      x0 := mid-sy*FArea.Width/2;
      x1 := mid+sy*FArea.Width/2;
    end;
  end;
end;

// a tick step of 1, 2 or 5 times a power of ten that gives about `want` ticks
function TPlotCanvas.niceStep(span: double; pixels, want: integer): double;
begin
  if (span <= 0) or (pixels <= 0) then exit(1);
  var rough := span/Max(want, 1);
  var mag := Power(10, Floor(Log10(rough)));
  var ratio := rough/mag;
  result := if ratio < 1.5 then mag else if ratio < 3.5 then 2*mag else if ratio < 7.5 then 5*mag else 10*mag;
end;

function TPlotCanvas.tickText(value, step: double; const fmt: string): string;
begin
  if fmt <> '' then exit(Format(fmt, [value]));
  var digits := 0;
  if step < 1 then digits := Min(Ceil(-Log10(step)), 10);
  if Abs(value) < step/1000 then value := 0;
  // a dot whatever the locale: the labels of a plot are not prose
  var fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  result := FloatToStrF(value, ffFixed, 15, digits, fs);
end;

function TPlotCanvas.ToPlot(px, py: integer): TPlotPoint;
begin
  var x0, x1, y0, y1: double;
  viewRange(x0, x1, y0, y1);
  result.X := if FArea.Width > 0 then x0+(px-FArea.Left)*(x1-x0)/FArea.Width else x0;
  result.Y := if FArea.Height > 0 then y1-(py-FArea.Top)*(y1-y0)/FArea.Height else y0;
end;

function TPlotCanvas.ToPixel(x, y: double): TPoint;
begin
  var x0, x1, y0, y1: double;
  viewRange(x0, x1, y0, y1);
  result.X := FArea.Left+Round((x-x0)/(x1-x0)*FArea.Width);
  result.Y := FArea.Top+Round((y1-y)/(y1-y0)*FArea.Height);
end;

procedure TPlotCanvas.viewChanged;
begin
  Invalidate;
  if Assigned(FOnViewChange) then begin
    var x0, x1, y0, y1: double;
    viewRange(x0, x1, y0, y1);
    FOnViewChange(self, x0, x1, y0, y1);
  end;
end;

procedure TPlotCanvas.ZoomToFit;
begin
  FAutoRange := true;
  viewChanged;
end;

procedure TPlotCanvas.SetView(xMin, xMax, yMin, yMax: double);
begin
  FAutoRange := false;
  FXMin := xMin; FXMax := xMax; FYMin := yMin; FYMax := yMax;
  viewChanged;
end;

procedure TPlotCanvas.Zoom(factor: double);
begin
  var x0, x1, y0, y1: double;
  viewRange(x0, x1, y0, y1);
  var cx := (x0+x1)/2;
  var cy := (y0+y1)/2;
  SetView(cx-(x1-x0)/2/factor, cx+(x1-x0)/2/factor, cy-(y1-y0)/2/factor, cy+(y1-y0)/2/factor);
end;

// -- painting ----------------------

procedure TPlotCanvas.Paint;
begin
  var back := pick(FBackColor, clBtnFace);
  var plot := pick(FPlotColor, clWindow);
  var grid := pick(FGridColor, blend(plot, clWindowText, 10));
  var axis := pick(FAxisColor, blend(plot, clWindowText, 45));
  var text := pick(FTextColor, clWindowText);
  var cross := pick(FCrosshairColor, blend(plot, clHighlight, 60));
  var pad := scaled(self, FPadding);
  var tick := scaled(self, FTickLength);
  var lh := lineHeightOf(Font);
  applyTextQuality(Canvas);
  Canvas.Font := Font;
  // the plot area leaves room for the labels and the titles
  var r := ClientRect;
  r.Inflate(-pad, -pad);
  if FTitle <> '' then r.Top += lh+scaled(self, 4);
  if FShowAxes then begin
    r.Bottom -= lh+tick+scaled(self, 2);
    if FXTitle <> '' then r.Bottom -= lh;
    // a guess of the widest y label: 8 characters
    r.Left += Canvas.TextWidth('-0.00000')+tick+scaled(self, 4);
    if FYTitle <> '' then r.Left += lh;
  end;
  if (r.Width < 20) or (r.Height < 20) then r := ClientRect;
  FArea := r;
  var x0, x1, y0, y1: double;
  viewRange(x0, x1, y0, y1);
  var sx := FArea.Width/(x1-x0);
  var sy := FArea.Height/(y1-y0);
  var px := function(x: double): double
  begin
    result := FArea.Left+(x-x0)*sx;
  end;
  var py := function(y: double): double
  begin
    result := FArea.Top+(y1-y)*sy;
  end;

  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  sp.FillRect(FArea, plot);
  var xStep := niceStep(x1-x0, FArea.Width, Max(FArea.Width div scaled(self, 70), 2));
  var yStep := niceStep(y1-y0, FArea.Height, Max(FArea.Height div scaled(self, 40), 2));
  if FShowGrid then begin
    var x := Ceil(x0/xStep)*xStep;
    while x <= x1 do begin
      var gx := Round(px(x));
      sp.FillRect(Rect(gx, FArea.Top, gx+1, FArea.Bottom), grid);
      x += xStep;
    end;
    var y := Ceil(y0/yStep)*yStep;
    while y <= y1 do begin
      var gy := Round(py(y));
      sp.FillRect(Rect(FArea.Left, gy, FArea.Right, gy+1), grid);
      y += yStep;
    end;
  end;
  if FShowZero then begin
    if (x0 < 0) and (x1 > 0) then sp.FillRect(Rect(Round(px(0)), FArea.Top, Round(px(0))+1, FArea.Bottom), axis);
    if (y0 < 0) and (y1 > 0) then sp.FillRect(Rect(FArea.Left, Round(py(0)), FArea.Right, Round(py(0))+1), axis);
  end;
  // the curves, clipped to the area
  sp.SetClip(FArea);
  for var c := 0 to FCurves.Count-1 do begin
    var curve := FCurves[c];
    if not curve.Visible or (curve.Count = 0) then continue;
    var color := curveColor(c);
    var n := curve.Count;
    var pts: array of TPointF;
    if curve.Stepped then begin
      SetLength(pts, n*2-1);
      for var i := 0 to n-1 do begin
        pts[i*2] := PointF(px(curve.FX[i]), py(curve.FY[i]));
        if i < n-1 then pts[i*2+1] := PointF(px(curve.FX[i+1]), py(curve.FY[i]));
      end;
    end else begin
      SetLength(pts, n);
      for var i := 0 to n-1 do pts[i] := PointF(px(curve.FX[i]), py(curve.FY[i]));
    end;
    if curve.Filled and (length(pts) > 1) then begin
      var poly: array of TPointF;
      SetLength(poly, length(pts)+2);
      for var i := 0 to high(pts) do poly[i] := pts[i];
      var base := py(EnsureRange(0, y0, y1));
      poly[length(pts)] := PointF(pts[high(pts)].X, base);
      poly[length(pts)+1] := PointF(pts[0].X, base);
      sp.FillPolygon(poly, blend(color, plot, 70));
    end;
    if length(pts) > 1 then sp.StrokePolyline(pts, Max(scaled(self, curve.Width), 1), color)
    else if curve.Marker = pmNone then paintCircle(sp, Round(pts[0].X), Round(pts[0].Y), Max(scaled(self, curve.Width), 2), color, clNone);
    if curve.Marker <> pmNone then begin
      var rad := Max(scaled(self, curve.Width)+1, 3);
      for var i := 0 to n-1 do begin
        var mx := Round(px(curve.FX[i]));
        var my := Round(py(curve.FY[i]));
        if (mx < FArea.Left-rad) or (mx > FArea.Right+rad) then continue;
        match curve.Marker of
          pmDot: paintCircle(sp, mx, my, rad, color, clNone);
          pmSquare: sp.FillRect(Rect(mx-rad, my-rad, mx+rad+1, my+rad+1), color);
          pmCross: paintCross(sp, Rect(mx-rad-1, my-rad-1, mx+rad+2, my+rad+2), rad*2, color, 1);
          pmCircle: paintCircle(sp, mx, my, rad, pick(FBackColor, GetRGBColorResolvingParent), color, Max(scaled(self, curve.Width), 1));
          pmTriangle: sp.FillPolygon(polygonOutline(mx+0.5, my+0.5, rad+1, 3, 90), color);
          pmDiamond: sp.FillPolygon(polygonOutline(mx+0.5, my+0.5, rad+1, 4, 90), color);
          pmPlus: begin
            paintLine(sp, mx-rad, my, mx+rad, my, color, Max(scaled(self, curve.Width), 1));
            paintLine(sp, mx, my-rad, mx, my+rad, color, Max(scaled(self, curve.Width), 1));
          end;
        end;
      end;
    end;
  end;
  // the point under the mouse
  if (FHotCurve >= 0) and (FHotCurve < FCurves.Count) and (FHotIndex >= 0) and (FHotIndex < FCurves[FHotCurve].Count) then begin
    var hx := Round(px(FCurves[FHotCurve].FX[FHotIndex]));
    var hy := Round(py(FCurves[FHotCurve].FY[FHotIndex]));
    paintCircle(sp, hx, hy, scaled(self, 4), plot, curveColor(FHotCurve), 2);
  end;
  // the crosshair
  if FShowCrosshair and FMouseInside and PtInRect(FArea, FMouse) and not FPanning then begin
    sp.FillRect(Rect(FMouse.X, FArea.Top, FMouse.X+1, FArea.Bottom), cross);
    sp.FillRect(Rect(FArea.Left, FMouse.Y, FArea.Right, FMouse.Y+1), cross);
  end;
  sp.ResetClip;
  if FShowAxes then begin
    sp.FillRect(Rect(FArea.Left, FArea.Top, FArea.Left+1, FArea.Bottom), axis);
    sp.FillRect(Rect(FArea.Left, FArea.Bottom-1, FArea.Right, FArea.Bottom), axis);
    var x := Ceil(x0/xStep)*xStep;
    while x <= x1 do begin
      var gx := Round(px(x));
      sp.FillRect(Rect(gx, FArea.Bottom, gx+1, FArea.Bottom+tick), axis);
      x += xStep;
    end;
    var y := Ceil(y0/yStep)*yStep;
    while y <= y1 do begin
      var gy := Round(py(y));
      sp.FillRect(Rect(FArea.Left-tick, gy, FArea.Left, gy+1), axis);
      y += yStep;
    end;
  end;
  // the focus frames the plot area itself
  if Focused and ringEnabled then sp.FrameRoundRect(FArea.Left, FArea.Top, FArea.Right, FArea.Bottom, 0, 1, ringColor);
  // the legend in the top right corner of the area
  var legendRects: array of TRect := [];
  if FShowLegend and (FCurves.Count > 0) then begin
    var widest := 0;
    var count := 0;
    for var c := 0 to FCurves.Count-1 do if FCurves[c].Visible and (FCurves[c].Title <> '') then begin
      widest := Max(widest, Canvas.TextWidth(FCurves[c].Title));
      inc(count);
    end;
    if count > 0 then begin
      var box := scaled(self, 10);
      var lw := widest+box+scaled(self, 18);
      var lr := Rect(FArea.Right-lw-scaled(self, 6), FArea.Top+scaled(self, 6), FArea.Right-scaled(self, 6), 0);
      lr.Bottom := lr.Top+count*lh+scaled(self, 8);
      paintRoundRect(sp, lr, scaled(self, 3), blend(plot, back, 30), axis, 1);
      var k := 0;
      for var c := 0 to FCurves.Count-1 do if FCurves[c].Visible and (FCurves[c].Title <> '') then begin
        var ly := lr.Top+scaled(self, 4)+k*lh;
        sp.FillRoundRect(lr.Left+scaled(self, 6), ly+(lh-box) div 2, lr.Left+scaled(self, 6)+box, ly+(lh+box) div 2, 2, curveColor(c));
        SetLength(legendRects, length(legendRects)+1);
        legendRects[high(legendRects)] := Rect(lr.Left+scaled(self, 6)+box+scaled(self, 6), ly, lr.Right, ly+lh);
        inc(k);
      end;
    end;
  end;
  sp.Flush;

  // the texts
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := text;
  if FTitle <> '' then begin
    Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.TextOut(FArea.Left+(FArea.Width-Canvas.TextWidth(FTitle)) div 2, pad, FTitle);
    Canvas.Font.Style := Font.Style;
  end;
  if FShowAxes then begin
    var x := Ceil(x0/xStep)*xStep;
    var lastRight := -MaxInt;
    while x <= x1 do begin
      var s := tickText(x, xStep, FXFormat);
      var w := Canvas.TextWidth(s);
      var gx := Round(px(x));
      if gx-w div 2 > lastRight+scaled(self, 4) then begin
        Canvas.TextOut(gx-w div 2, FArea.Bottom+tick+scaled(self, 1), s);
        lastRight := gx+w div 2;
      end;
      x += xStep;
    end;
    var y := Ceil(y0/yStep)*yStep;
    while y <= y1 do begin
      var s := tickText(y, yStep, FYFormat);
      var gy := Round(py(y));
      Canvas.TextOut(FArea.Left-tick-scaled(self, 3)-Canvas.TextWidth(s), gy-lh div 2, s);
      y += yStep;
    end;
    if FXTitle <> '' then Canvas.TextOut(FArea.Left+(FArea.Width-Canvas.TextWidth(FXTitle)) div 2, ClientHeight-pad-lh, FXTitle);
    if FYTitle <> '' then begin
      // the y title turned upright along the left edge
      Canvas.Font.Orientation := 900;
      Canvas.TextOut(pad, FArea.Top+(FArea.Height+Canvas.TextWidth(FYTitle)) div 2, FYTitle);
      Canvas.Font.Orientation := 0;
    end;
  end;
  var k := 0;
  for var c := 0 to FCurves.Count-1 do if FCurves[c].Visible and (FCurves[c].Title <> '') and (k < length(legendRects)) then begin
    Canvas.TextOut(legendRects[k].Left, legendRects[k].Top, FCurves[c].Title);
    inc(k);
  end;
  // the readout next to the crosshair
  if FShowCrosshair and FMouseInside and PtInRect(FArea, FMouse) and not FPanning then begin
    var p := ToPlot(FMouse.X, FMouse.Y);
    var s := tickText(p.X, xStep/10, FXFormat)+', '+tickText(p.Y, yStep/10, FYFormat);
    if (FHotCurve >= 0) and (FHotCurve < FCurves.Count) and (FHotIndex >= 0) then
      s := FCurves[FHotCurve].Title+': '+tickText(FCurves[FHotCurve].X[FHotIndex], xStep/10, FXFormat)+', '+tickText(FCurves[FHotCurve].Y[FHotIndex], yStep/10, FYFormat);
    var w := Canvas.TextWidth(s)+scaled(self, 8);
    var tx := FMouse.X+scaled(self, 12);
    var ty := FMouse.Y-lh-scaled(self, 6);
    if tx+w > FArea.Right then tx := FMouse.X-w-scaled(self, 6);
    if ty < FArea.Top then ty := FMouse.Y+scaled(self, 12);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := blend(plot, back, 20);
    Canvas.Pen.Color := axis;
    Canvas.Rectangle(tx, ty, tx+w, ty+lh+scaled(self, 4));
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(tx+scaled(self, 4), ty+scaled(self, 2), s);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

// the point of any curve within a few pixels of the mouse
procedure TPlotCanvas.findPoint(px, py: integer; out curve, index: integer);
begin
  curve := -1;
  index := -1;
  var best := Sqr(scaled(self, 8));
  for var c := 0 to FCurves.Count-1 do begin
    var cv := FCurves[c];
    if not cv.Visible then continue;
    for var i := 0 to cv.Count-1 do begin
      var p := ToPixel(cv.FX[i], cv.FY[i]);
      var d := Sqr(p.X-px)+Sqr(p.Y-py);
      if d < best then begin
        best := d;
        curve := c;
        index := i;
      end;
    end;
  end;
end;

procedure TPlotCanvas.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  FMouse := Point(X, Y);
  if FPanning then begin
    var dx := (X-FPanStart.X)*(FPanOrigin[1]-FPanOrigin[0])/Max(FArea.Width, 1);
    var dy := (Y-FPanStart.Y)*(FPanOrigin[3]-FPanOrigin[2])/Max(FArea.Height, 1);
    FXMin := FPanOrigin[0]-dx;
    FXMax := FPanOrigin[1]-dx;
    FYMin := FPanOrigin[2]+dy;
    FYMax := FPanOrigin[3]+dy;
    viewChanged;
    exit;
  end;
  var c, i: integer;
  findPoint(X, Y, c, i);
  if (c <> FHotCurve) or (i <> FHotIndex) then begin
    FHotCurve := c;
    FHotIndex := i;
    if Assigned(FOnPointHover) then FOnPointHover(self, c, i);
  end;
  if Assigned(FOnMouseMovePlot) and PtInRect(FArea, FMouse) then begin
    var p := ToPlot(X, Y);
    FOnMouseMovePlot(self, p.X, p.Y);
  end;
  if FShowCrosshair or (c >= 0) then Invalidate;
end;

procedure TPlotCanvas.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  if (FHotCurve >= 0) and Assigned(FOnPointClick) then FOnPointClick(self, FHotCurve, FHotIndex);
  if not FInteractive or not PtInRect(FArea, Point(X, Y)) then exit;
  viewRange(FPanOrigin[0], FPanOrigin[1], FPanOrigin[2], FPanOrigin[3]);
  FAutoRange := false;
  FPanStart := Point(X, Y);
  FPanning := true;
  Cursor := crSizeAll;
end;

procedure TPlotCanvas.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not FPanning then exit;
  FPanning := false;
  Cursor := crDefault;
  Invalidate;
end;

procedure TPlotCanvas.MouseEnter;
begin
  inherited MouseEnter;
  FMouseInside := true;
end;

procedure TPlotCanvas.MouseLeave;
begin
  inherited MouseLeave;
  FMouseInside := false;
  if FHotCurve >= 0 then begin
    FHotCurve := -1;
    FHotIndex := -1;
    if Assigned(FOnPointHover) then FOnPointHover(self, -1, -1);
  end;
  Invalidate;
end;

function TPlotCanvas.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or not FInteractive then exit;
  var p := MousePos; // client coordinates
  if not PtInRect(FArea, p) then exit;
  // the zoom keeps the point under the mouse in place
  var x0, x1, y0, y1: double;
  viewRange(x0, x1, y0, y1);
  var at := ToPlot(p.X, p.Y);
  var factor := if WheelDelta > 0 then 1/1.25 else 1.25;
  var nx0 := at.X-(at.X-x0)*factor;
  var nx1 := at.X+(x1-at.X)*factor;
  var ny0 := at.Y-(at.Y-y0)*factor;
  var ny1 := at.Y+(y1-at.Y)*factor;
  if ssShift in Shift then begin ny0 := y0; ny1 := y1; end;
  if ssCtrl in Shift then begin nx0 := x0; nx1 := x1; end;
  SetView(nx0, nx1, ny0, ny1);
  result := true;
end;

procedure TPlotCanvas.DblClick;
begin
  inherited DblClick;
  if FInteractive then ZoomToFit;
end;

procedure TPlotCanvas.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not FInteractive then exit;
  var x0, x1, y0, y1: double;
  viewRange(x0, x1, y0, y1);
  var dx := (x1-x0)/10;
  var dy := (y1-y0)/10;
  match Key of
    VK_LEFT: SetView(x0-dx, x1-dx, y0, y1);
    VK_RIGHT: SetView(x0+dx, x1+dx, y0, y1);
    VK_UP: SetView(x0, x1, y0+dy, y1+dy);
    VK_DOWN: SetView(x0, x1, y0-dy, y1-dy);
    VK_ADD, VK_OEM_PLUS: Zoom(1.25);
    VK_SUBTRACT, VK_OEM_MINUS: Zoom(1/1.25);
    VK_HOME, VK_SPACE: ZoomToFit;
  else
    exit;
  end;
  Key := 0;
end;

// -- properties ----------------------

procedure TPlotCanvas.setCurves(value: TPlotCurves);
begin
  FCurves.Assign(value);
  Invalidate;
end;

function TPlotCanvas.getRange(index: integer): double;
begin
  result := match index of
    0: FXMin;
    1: FXMax;
    2: FYMin;
  else
    FYMax
  end;
end;

procedure TPlotCanvas.setRange(index: integer; value: double);
begin
  match index of
    0: FXMin := value;
    1: FXMax := value;
    2: FYMin := value;
  else
    FYMax := value;
  end;
  if not FAutoRange then viewChanged;
end;

function TPlotCanvas.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FAutoRange;
    1: FShowGrid;
    2: FShowLegend;
    3: FShowCrosshair;
    4: FInteractive;
    5: FShowAxes;
    6: FSquare;
  else
    FShowZero
  end;
end;

procedure TPlotCanvas.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAutoRange := value;
    1: FShowGrid := value;
    2: FShowLegend := value;
    3: FShowCrosshair := value;
    4: FInteractive := value;
    5: FShowAxes := value;
    6: FSquare := value;
  else
    FShowZero := value;
  end;
  if index in [0, 6] then viewChanged else Invalidate;
end;

function TPlotCanvas.getText(index: integer): string;
begin
  result := match index of
    0: FTitle;
    1: FXTitle;
    2: FYTitle;
    3: FXFormat;
  else
    FYFormat
  end;
end;

procedure TPlotCanvas.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FTitle := value;
    1: FXTitle := value;
    2: FYTitle := value;
    3: FXFormat := value;
  else
    FYFormat := value;
  end;
  Invalidate;
end;

function TPlotCanvas.getMetric(index: integer): integer;
begin
  result := if index = 0 then FPadding else FTickLength;
end;

procedure TPlotCanvas.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FPadding := value else FTickLength := value;
  Invalidate;
end;

function TPlotCanvas.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FGridColor;
    1: FAxisColor;
    2: FTextColor;
    3: FBackColor;
    4: FPlotColor;
  else
    FCrosshairColor
  end;
end;

procedure TPlotCanvas.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FGridColor := value;
    1: FAxisColor := value;
    2: FTextColor := value;
    3: FBackColor := value;
    4: FPlotColor := value;
  else
    FCrosshairColor := value;
  end;
  Invalidate;
end;

procedure TPlotCanvas.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
