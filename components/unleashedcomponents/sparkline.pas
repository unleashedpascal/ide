{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Sparkline;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LMessages, ControlPaint;

type
  // the drawing: a line, a filled area, bars from the baseline, dots alone, a
  // stepped line, fixed bars up or down from the baseline, stems with a dot
  TSparklineStyle = (ssLine, ssArea, ssBars, ssDots, ssStep, ssWinLoss, ssStem);
  TSparklineValues = array of double;
  // the value under the mouse, index -1 when the mouse left the values
  TSparklineHoverEvent = procedure(Sender: TObject; index: integer; value: double) of object;

  { TSparkline }

  // a tiny chart without axes: a line, a filled area or bars over the last
  // MaxPoints values. New values push the oldest out
  TSparkline = class(TGraphicControl)
  private
    FValues: TSparklineValues;
    FStyle: TSparklineStyle;
    FMaxPoints, FLineWidth, FDotSize, FPadding: integer;
    FMinValue, FMaxValue, FBaseline: double;
    FAutoRange, FShowDots, FShowLastDot, FShowBaseline, FShowMinMax: boolean;
    FLineColor, FFillColor, FDotColor, FBaselineColor, FMinColor, FMaxColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FHot: integer;
    FHoverMarker: boolean;
    FValueFormat: string;
    FOnHover: TSparklineHoverEvent;
    procedure setValueFormat(const value: string);
    function plotRect: TRect;
    procedure setStyle(value: TSparklineStyle);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setRange(index: integer; value: double);
    function getRange(index: integer): double;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure bounds(out lo, hi: double);
    function rangeStored(index: integer): boolean;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure CMHintShow(var Message: TLMessage); message CM_HINTSHOW;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the value nearest to a point of the control, -1 without values
    function IndexAt(x: integer): integer;
    // the value as the hint shows it
    function ValueText(index: integer): string;
    // the value under the mouse, -1 for none
    property HotIndex: integer read FHot;
    // appends a value; past MaxPoints the oldest goes
    procedure AddValue(value: double);
    procedure SetValues(const values: array of double);
    procedure Clear;
    function Count: integer;
    function LastValue: double;
    property Values: TSparklineValues read FValues;
  published
    property Style: TSparklineStyle read FStyle write setStyle default ssLine;
    // values kept; 0 keeps every one
    property MaxPoints: integer index 0 read getMetric write setMetric default 50;
    property LineWidth: integer index 1 read getMetric write setMetric default 2;
    property DotSize: integer index 2 read getMetric write setMetric default 4;
    property Padding: integer index 3 read getMetric write setMetric default 2;
    // the range of the drawing; with AutoRange the values set it
    property MinValue: double index 0 read getRange write setRange stored rangeStored;
    property MaxValue: double index 1 read getRange write setRange stored rangeStored;
    // the value the area fills from and the baseline sits at
    property Baseline: double index 2 read getRange write setRange stored rangeStored;
    property AutoRange: boolean index 0 read getFlag write setFlag default true;
    property ShowDots: boolean index 1 read getFlag write setFlag default false;
    property ShowLastDot: boolean index 2 read getFlag write setFlag default true;
    property ShowBaseline: boolean index 3 read getFlag write setFlag default false;
    // the lowest and the highest value marked
    property ShowMinMax: boolean index 4 read getFlag write setFlag default false;
    // clDefault takes the colors of the theme
    property LineColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FillColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property DotColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BaselineColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property MinColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property MaxColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // a line and a dot on the value under the mouse
    property HoverMarker: boolean index 5 read getFlag write setFlag default true;
    // a Format pattern for the hint, like '%.1f ms'; empty shows the plain number
    property ValueFormat: string read FValueFormat write setValueFormat;
    property OnHover: TSparklineHoverEvent read FOnHover write FOnHover;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Hint;
    property ParentColor;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
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

constructor TSparkline.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FStyle := ssLine;
  FMaxPoints := 50;
  FLineWidth := 2;
  FDotSize := 4;
  FPadding := 2;
  FMaxValue := 100;
  FAutoRange := true;
  FShowLastDot := true;
  FLineColor := clDefault;
  FFillColor := clDefault;
  FDotColor := clDefault;
  FBaselineColor := clDefault;
  FMinColor := clDefault;
  FMaxColor := clDefault;
  FHot := -1;
  FHoverMarker := true;
  ParentColor := true;
  ParentShowHint := false;
  ShowHint := true;
  Hint := 'value'; // replaced per value when the hint shows
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

// the values spread over the control inside the padding and the room of
// the dots and the line
function TSparkline.plotRect: TRect;
begin
  var pad := scaled(self, FPadding)+Max(scaled(self, FDotSize) div 2, scaled(self, FLineWidth));
  result := ClientRect;
  result.Inflate(-pad, -pad);
end;

function TSparkline.IndexAt(x: integer): integer;
begin
  var n := length(FValues);
  var r := plotRect;
  if (n = 0) or (r.Width < 2) then exit(-1);
  if n = 1 then exit(0);
  // the bars sit in slots, the rest on a line from edge to edge
  result := if FStyle in [ssBars, ssWinLoss] then Trunc((x-r.Left)*n/r.Width) else Round((x-r.Left)*(n-1)/(r.Width-1));
  result := EnsureRange(result, 0, n-1);
end;

function TSparkline.ValueText(index: integer): string;
begin
  if (index < 0) or (index >= length(FValues)) then exit('');
  var fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  result := if FValueFormat <> '' then Format(FValueFormat, [FValues[index]], fs) else FloatToStrF(FValues[index], ffGeneral, 6, 2, fs);
end;

procedure TSparkline.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := IndexAt(X);
  if hot = FHot then exit;
  FHot := hot;
  if FHoverMarker then Invalidate;
  if Assigned(FOnHover) then FOnHover(self, hot, (if hot >= 0 then FValues[hot] else 0));
end;

procedure TSparkline.MouseLeave;
begin
  inherited MouseLeave;
  if FHot < 0 then exit;
  FHot := -1;
  if FHoverMarker then Invalidate;
  if Assigned(FOnHover) then FOnHover(self, -1, 0);
end;

procedure TSparkline.CMHintShow(var Message: TLMessage);
begin
  var info := PHintInfo(Message.LParam);
  var i := IndexAt(info^.CursorPos.X);
  if i < 0 then begin
    Message.Result := 1; // nothing under the mouse
    exit;
  end;
  info^.HintStr := ValueText(i);
  // the hint goes when the mouse leaves the slot of the value, so the next
  // one gets its own
  var r := plotRect;
  var n := length(FValues);
  var slot := r.Width/n;
  info^.CursorRect := Rect(r.Left+Round(i*slot), 0, r.Left+Round((i+1)*slot), ClientHeight);
end;

class function TSparkline.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 32;
end;

function TSparkline.rangeStored(index: integer): boolean;
begin
  result := not FAutoRange;
end;

// -- values ----------------------

procedure TSparkline.AddValue(value: double);
begin
  var n := length(FValues);
  if (FMaxPoints > 0) and (n >= FMaxPoints) then begin
    for var i := 0 to n-2 do FValues[i] := FValues[i+1];
    FValues[n-1] := value;
  end else begin
    SetLength(FValues, n+1);
    FValues[n] := value;
  end;
  Invalidate;
end;

procedure TSparkline.SetValues(const values: array of double);
begin
  var start := 0;
  if (FMaxPoints > 0) and (length(values) > FMaxPoints) then start := length(values)-FMaxPoints;
  SetLength(FValues, length(values)-start);
  for var i := start to high(values) do FValues[i-start] := values[i];
  Invalidate;
end;

procedure TSparkline.Clear;
begin
  FValues := nil;
  Invalidate;
end;

function TSparkline.Count: integer;
begin
  result := length(FValues);
end;

function TSparkline.LastValue: double;
begin
  result := if FValues = nil then 0 else FValues[high(FValues)];
end;

procedure TSparkline.bounds(out lo, hi: double);
begin
  lo := FMinValue;
  hi := FMaxValue;
  if FAutoRange and (FValues <> nil) then begin
    lo := FValues[0];
    hi := FValues[0];
    for var v in FValues do begin
      lo := Min(lo, v);
      hi := Max(hi, v);
    end;
    if FStyle = ssArea then lo := Min(lo, FBaseline);
  end;
  if hi <= lo then hi := lo+1;
end;

// -- painting ----------------------

procedure TSparkline.Paint;
begin
  var line := pick(FLineColor, clHighlight);
  var fill := pick(FFillColor, blend(GetRGBColorResolvingParent, line, 30));
  var dot := pick(FDotColor, clHotLight);
  var base := pick(FBaselineColor, clGrayText);
  var minColor := pick(FMinColor, clRed);
  var maxColor := pick(FMaxColor, clGreen);
  if not Enabled then line := blend(line, clBtnFace, 50);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var n := length(FValues);
  var r := plotRect;
  if (n = 0) or (r.Width < 2) or (r.Height < 2) then exit;
  var lo, hi: double;
  bounds(lo, hi);

  var xOf := function(i: integer): integer
  begin
    result := if n = 1 then r.Left+r.Width div 2 else r.Left+Round(i*(r.Width-1)/(n-1));
  end;
  var yOf := function(v: double): integer
  begin
    result := r.Bottom-1-Round((EnsureRange(v, lo, hi)-lo)/(hi-lo)*(r.Height-1));
  end;

  var baseY := yOf(FBaseline);
  var dotRad := Max(scaled(self, FDotSize) div 2, 1);
  match FStyle of
    // every value a fixed bar up or down from the baseline
    ssWinLoss: begin
      var slot := r.Width/n;
      var w := Max(Round(slot*0.7), 1);
      var h := Max(r.Height div 2-1, 2);
      for var i := 0 to n-1 do begin
        var x := r.Left+Round(i*slot+(slot-w)/2);
        var mid := r.Top+r.Height div 2;
        if FValues[i] >= FBaseline then paintRoundRect(sp, Rect(x, mid-h, x+w, mid), 1, line, clNone)
        else paintRoundRect(sp, Rect(x, mid, x+w, mid+h), 1, minColor, clNone);
      end;
    end;
    // a stem from the baseline to every value, a dot on top
    ssStem: for var i := 0 to n-1 do begin
      var x := xOf(i);
      var y := yOf(FValues[i]);
      paintLine(sp, x, baseY, x, y, (if FValues[i] >= FBaseline then line else minColor), Max(scaled(self, FLineWidth), 1));
      paintCircle(sp, x, y, dotRad, dot, clNone);
    end;
    ssDots: for var i := 0 to n-1 do paintCircle(sp, xOf(i), yOf(FValues[i]), dotRad, (if i = n-1 then dot else line), clNone);
    ssBars: begin
      var slot := r.Width/n;
      var w := Max(Round(slot*0.7), 1);
      for var i := 0 to n-1 do begin
        var x := r.Left+Round(i*slot+(slot-w)/2);
        var y := yOf(FValues[i]);
        var top := Min(y, baseY);
        var bottom := Max(y, baseY);
        if bottom = top then inc(bottom);
        paintRoundRect(sp, Rect(x, top, x+w, bottom), 0, (if FValues[i] >= FBaseline then line else minColor), clNone);
      end;
    end;
  else
    begin
      var pts: array of TPoint;
      SetLength(pts, n);
      for var i := 0 to n-1 do pts[i] := Point(xOf(i), yOf(FValues[i]));
      if FStyle = ssArea then begin
        var poly: array of TPointF;
        SetLength(poly, n+2);
        for var i := 0 to n-1 do poly[i] := PointF(pts[i].X, pts[i].Y);
        poly[n] := PointF(pts[n-1].X, baseY);
        poly[n+1] := PointF(pts[0].X, baseY);
        sp.FillPolygon(poly, fill);
      end;
      if n > 1 then begin
        // the line through the middles of the pixels; a step holds each
        // value until the next one
        var centers: array of TPointF := [];
        for var i := 0 to n-1 do begin
          if (FStyle = ssStep) and (i > 0) then centers += [PointF(pts[i].X+0.5, pts[i-1].Y+0.5)];
          centers += [PointF(pts[i].X+0.5, pts[i].Y+0.5)];
        end;
        sp.StrokePolyline(centers, FLineWidth, line);
      end;
      if FShowDots then for var i := 0 to n-1 do paintCircle(sp, pts[i].X, pts[i].Y, dotRad, dot, clNone);
      if FShowLastDot and not FShowDots then paintCircle(sp, pts[n-1].X, pts[n-1].Y, dotRad, dot, clNone);
      if FShowMinMax then begin
        var iMin := 0;
        var iMax := 0;
        for var i := 1 to n-1 do begin
          if FValues[i] < FValues[iMin] then iMin := i;
          if FValues[i] > FValues[iMax] then iMax := i;
        end;
        paintCircle(sp, pts[iMin].X, pts[iMin].Y, dotRad, minColor, clNone);
        paintCircle(sp, pts[iMax].X, pts[iMax].Y, dotRad, maxColor, clNone);
      end;
    end;
  end;
  if FShowBaseline then paintLine(sp, r.Left, baseY, r.Right, baseY, base);
  // the value under the mouse: a line down the control and a ring on the value
  if FHoverMarker and hoverEnabled and (FHot >= 0) and (FHot < n) then begin
    var x := if FStyle in [ssBars, ssWinLoss] then r.Left+Round((FHot+0.5)*r.Width/n) else xOf(FHot);
    paintLine(sp, x, r.Top, x, r.Bottom, blend(GetRGBColorResolvingParent, line, 45));
    paintCircle(sp, x, yOf(FValues[FHot]), dotRad+1, dot, GetRGBColorResolvingParent, 1);
  end;
end;

// -- properties ----------------------

procedure TSparkline.setStyle(value: TSparklineStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

function TSparkline.getMetric(index: integer): integer;
begin
  match index of
    0: result := FMaxPoints;
    1: result := FLineWidth;
    2: result := FDotSize;
    _: result := FPadding;
  end;
end;

procedure TSparkline.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: begin
      FMaxPoints := value;
      if (value > 0) and (length(FValues) > value) then SetValues(FValues);
    end;
    1: FLineWidth := Max(value, 1);
    2: FDotSize := value;
    _: FPadding := value;
  end;
  Invalidate;
end;

function TSparkline.getRange(index: integer): double;
begin
  match index of
    0: result := FMinValue;
    1: result := FMaxValue;
    _: result := FBaseline;
  end;
end;

procedure TSparkline.setRange(index: integer; value: double);
begin
  if getRange(index) = value then exit;
  match index of
    0: FMinValue := value;
    1: FMaxValue := value;
    _: FBaseline := value;
  end;
  Invalidate;
end;

function TSparkline.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FAutoRange;
    1: result := FShowDots;
    2: result := FShowLastDot;
    3: result := FShowBaseline;
    4: result := FShowMinMax;
    _: result := FHoverMarker;
  end;
end;

procedure TSparkline.setValueFormat(const value: string);
begin
  if FValueFormat = value then exit;
  FValueFormat := value;
end;

procedure TSparkline.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAutoRange := value;
    1: FShowDots := value;
    2: FShowLastDot := value;
    3: FShowBaseline := value;
    4: FShowMinMax := value;
    _: FHoverMarker := value;
  end;
  Invalidate;
end;

function TSparkline.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FLineColor;
    1: result := FFillColor;
    2: result := FDotColor;
    3: result := FBaselineColor;
    4: result := FMinColor;
    _: result := FMaxColor;
  end;
end;

procedure TSparkline.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FLineColor := value;
    1: FFillColor := value;
    2: FDotColor := value;
    3: FBaselineColor := value;
    4: FMinColor := value;
    _: FMaxColor := value;
  end;
  Invalidate;
end;

procedure TSparkline.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
