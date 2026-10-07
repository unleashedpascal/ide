{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RangeSlider;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  TSliderOrientation = (soHorizontal, soVertical);
  TSliderThumb = (stLow, stHigh);
  // the thumb: a disc, a square, a diamond, a tag pointing at the track, a
  // narrow bar
  TSliderThumbShape = (tsRound, tsSquare, tsDiamond, tsPointer, tsBar);
  // where the values of the thumbs are written
  TSliderValuePosition = (vpNone, vpOutside, vpInside);
  TSliderValueEvent = procedure(Sender: TObject; thumb: TSliderThumb; value: integer; var text: string) of object;

  { TRangeSlider }

  // a track with two thumbs picking a range from LowValue to HighValue. The
  // thumbs drag with the mouse, the range between them drags as a whole, a
  // click on the track jumps the nearer thumb; the keyboard moves the active
  // thumb and the wheel the one under the mouse
  TRangeSlider = class(TCustomControl)
  private
    FMin, FMax, FLow, FHigh: integer;
    FStep, FMinRange, FKeyStep, FPageStep, FWheelStep: integer;
    FOrientation: TSliderOrientation;
    FThumbShape: TSliderThumbShape;
    FThumbSize, FTrackSize, FTickStep, FTickSize: integer;
    FShowTicks, FMoveRange, FClickJump, FReadOnly: boolean;
    FValuePosition: TSliderValuePosition;
    FValueFormat: string;
    FTrackColor, FRangeColor, FThumbColor, FThumbBorderColor, FTickColor: TColor;
    FActive: TSliderThumb; // the thumb the keyboard moves
    FHot: integer; // -1 none, 0 low, 1 high, 2 range
    FDrag: integer; // the part being dragged, as FHot
    FDragOffset: integer; // pixels from the thumb center to the mouse at the drag start
    FDragSpan: integer; // LowValue..HighValue distance while the range drags
    FOnChange, FOnChanging: TNotifyEvent;
    FOnFormatValue: TSliderValueEvent;
    procedure setMin(value: integer);
    procedure setMax(value: integer);
    procedure setLow(value: integer);
    procedure setHigh(value: integer);
    procedure setStep(value: integer);
    procedure setMinRange(value: integer);
    procedure setOrientation(value: TSliderOrientation);
    procedure setThumbShape(value: TSliderThumbShape);
    procedure setThumbSize(value: integer);
    procedure setTrackSize(value: integer);
    procedure setTickStep(value: integer);
    procedure setTickSize(value: integer);
    procedure setShowTicks(value: boolean);
    procedure setValuePosition(value: TSliderValuePosition);
    procedure setValueFormat(const value: string);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setHot(value: integer);
    // the pixel span of the track and its start
    function trackRect: TRect;
    function trackStart: integer;
    function trackLength: integer;
    function valueToPixel(value: integer): integer;
    function pixelToValue(pixel: integer): integer;
    function thumbCenter(thumb: TSliderThumb): TPoint;
    function thumbRect(thumb: TSliderThumb): TRect;
    function partAt(x, y: integer): integer;
    function snap(value: integer): integer;
    // text written at the thumb
    function valueText(thumb: TSliderThumb): string;
    function valueHeight: integer;
    procedure moveActive(delta: integer);
    procedure changing;
    procedure changed;
  private
    FAntialiasing: TAntialiasSetting;
    FOnDrawThumb: TCustomDrawEvent;
    procedure setAntialiasing(value: TAntialiasSetting);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // both values at once, clamped and ordered
    procedure SetRange(low, high: integer);
    // the thumb the keyboard moves
    property ActiveThumb: TSliderThumb read FActive write FActive;
    // a thumb or the range is being dragged
    function Dragging: boolean;
  published
    property Min: integer read FMin write setMin default 0;
    property Max: integer read FMax write setMax default 100;
    property LowValue: integer read FLow write setLow default 20;
    property HighValue: integer read FHigh write setHigh default 80;
    // the values land on Min plus a multiple of Step
    property Step: integer read FStep write setStep default 1;
    // the thumbs stay at least this far apart
    property MinRange: integer read FMinRange write setMinRange default 0;
    // an arrow key moves the active thumb by this much
    property KeyStep: integer read FKeyStep write FKeyStep default 1;
    property PageStep: integer read FPageStep write FPageStep default 10;
    property WheelStep: integer read FWheelStep write FWheelStep default 1;
    property Orientation: TSliderOrientation read FOrientation write setOrientation default soHorizontal;
    property ThumbShape: TSliderThumbShape read FThumbShape write setThumbShape default tsRound;
    property ThumbSize: integer read FThumbSize write setThumbSize default 16;
    property TrackSize: integer read FTrackSize write setTrackSize default 4;
    property ShowTicks: boolean read FShowTicks write setShowTicks default false;
    // a tick every TickStep values; 0 picks ten ticks
    property TickStep: integer read FTickStep write setTickStep default 0;
    property TickSize: integer read FTickSize write setTickSize default 4;
    property ValuePosition: TSliderValuePosition read FValuePosition write setValuePosition default vpOutside;
    // a Format pattern with the value as its integer argument
    property ValueFormat: string read FValueFormat write setValueFormat;
    // the range between the thumbs drags as a whole
    property MoveRange: boolean read FMoveRange write FMoveRange default true;
    // a click on the track jumps the nearer thumb there
    property ClickJump: boolean read FClickJump write FClickJump default true;
    property ReadOnly: boolean read FReadOnly write FReadOnly default false;
    // clDefault takes the colors of the theme
    property TrackColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property RangeColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property ThumbColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property ThumbBorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TickColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    // after a value settled: the drag ended, a key or the wheel moved a thumb
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // on every move while a thumb drags
    property OnChanging: TNotifyEvent read FOnChanging write FOnChanging;
    // replaces the text written at a thumb
    property OnFormatValue: TSliderValueEvent read FOnFormatValue write FOnFormatValue;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over a thumb: index 0 is the low one, 1 the high one; dsHover,
    // dsPressed while dragged, dsFocused for the thumb the keyboard moves
    property OnDrawThumb: TCustomDrawEvent read FOnDrawThumb write FOnDrawThumb;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Cursor;
    property Enabled;
    property Font;
    property Hint;
    property ParentColor;
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
  PART_NONE = -1;
  PART_LOW = 0;
  PART_HIGH = 1;
  PART_RANGE = 2;

constructor TRangeSlider.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FMin := 0;
  FMax := 100;
  FLow := 20;
  FHigh := 80;
  FStep := 1;
  FKeyStep := 1;
  FPageStep := 10;
  FWheelStep := 1;
  FThumbSize := 16;
  FTrackSize := 4;
  FTickSize := 4;
  FValuePosition := vpOutside;
  FValueFormat := '%d';
  FMoveRange := true;
  FClickJump := true;
  FTrackColor := clDefault;
  FRangeColor := clDefault;
  FThumbColor := clDefault;
  FThumbBorderColor := clDefault;
  FTickColor := clDefault;
  FHot := PART_NONE;
  FDrag := PART_NONE;
  TabStop := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TRangeSlider.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 40;
end;

// the room the focus ring takes around a thumb
const RING_ROOM = 2;

procedure TRangeSlider.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var thick := scaled(self, FThumbSize)+RING_ROOM*2+valueHeight+2;
  if FShowTicks then thick += scaled(self, FTickSize)+2;
  if FOrientation = soHorizontal then begin
    PreferredWidth := 0;
    PreferredHeight := thick;
  end else begin
    PreferredWidth := thick;
    PreferredHeight := 0;
  end;
end;

// -- geometry ----------------------

function TRangeSlider.valueHeight: integer;
begin
  result := 0;
  if FValuePosition = vpOutside then result := Canvas.TextHeight('0')+2;
end;

function TRangeSlider.trackRect: TRect;
begin
  var half := scaled(self, FThumbSize) div 2+RING_ROOM;
  var thick := scaled(self, FTrackSize);
  var r := ClientRect;
  // the values take the side above (left of) the track, the ticks the other
  var before := valueHeight;
  var after := if FShowTicks then scaled(self, FTickSize)+2 else 0;
  if FOrientation = soHorizontal then begin
    var cy := r.Top+before+(r.Height-before-after) div 2;
    result := Rect(r.Left+half, cy-thick div 2, r.Right-half, cy-thick div 2+thick);
  end else begin
    var cx := r.Left+before+(r.Width-before-after) div 2;
    result := Rect(cx-thick div 2, r.Top+half, cx-thick div 2+thick, r.Bottom-half);
  end;
end;

function TRangeSlider.trackStart: integer;
begin
  result := if FOrientation = soHorizontal then trackRect.Left else trackRect.Bottom-1;
end;

function TRangeSlider.trackLength: integer;
begin
  result := if FOrientation = soHorizontal then trackRect.Width-1 else trackRect.Height-1;
  if result < 1 then result := 1;
end;

function TRangeSlider.valueToPixel(value: integer): integer;
begin
  var span := FMax-FMin;
  if span <= 0 then exit(trackStart);
  var offset := Round((value-FMin)/span*trackLength);
  result := if FOrientation = soHorizontal then trackStart+offset else trackStart-offset;
end;

function TRangeSlider.pixelToValue(pixel: integer): integer;
begin
  var offset := if FOrientation = soHorizontal then pixel-trackStart else trackStart-pixel;
  result := snap(FMin+Round(offset/trackLength*(FMax-FMin)));
end;

function TRangeSlider.thumbCenter(thumb: TSliderThumb): TPoint;
begin
  var p := valueToPixel(if thumb = stLow then FLow else FHigh);
  var t := trackRect;
  result := if FOrientation = soHorizontal then Point(p, (t.Top+t.Bottom) div 2) else Point((t.Left+t.Right) div 2, p);
end;

function TRangeSlider.thumbRect(thumb: TSliderThumb): TRect;
begin
  var c := thumbCenter(thumb);
  var half := scaled(self, FThumbSize) div 2;
  result := Rect(c.X-half, c.Y-half, c.X+half+1, c.Y+half+1);
end;

function TRangeSlider.partAt(x, y: integer): integer;
begin
  result := PART_NONE;
  var lowR := thumbRect(stLow);
  var highR := thumbRect(stHigh);
  // when the thumbs overlap the one the keyboard moves wins
  if (FActive = stHigh) and highR.Contains(Point(x, y)) then exit(PART_HIGH);
  if lowR.Contains(Point(x, y)) then exit(PART_LOW);
  if highR.Contains(Point(x, y)) then exit(PART_HIGH);
  var t := trackRect;
  t.Inflate(if FOrientation = soHorizontal then 0 else 4, if FOrientation = soHorizontal then 4 else 0);
  if not t.Contains(Point(x, y)) then exit;
  var a := valueToPixel(FLow);
  var b := valueToPixel(FHigh);
  var p := if FOrientation = soHorizontal then x else y;
  if (p > Math.Min(a, b)) and (p < Math.Max(a, b)) then result := PART_RANGE;
end;

function TRangeSlider.snap(value: integer): integer;
begin
  var step := Math.Max(FStep, 1);
  result := FMin+Round((value-FMin)/step)*step;
  result := EnsureRange(result, FMin, FMax);
end;

function TRangeSlider.valueText(thumb: TSliderThumb): string;
begin
  var v := if thumb = stLow then FLow else FHigh;
  result := if FValueFormat = '' then IntToStr(v) else Format(FValueFormat, [v]);
  if Assigned(FOnFormatValue) then FOnFormatValue(self, thumb, v, result);
end;

// -- painting ----------------------

procedure TRangeSlider.Paint;
begin
  var track := pick(FTrackColor, blend(clBtnFace, clBtnShadow, 50));
  var range := pick(FRangeColor, clHighlight);
  var thumb := pick(FThumbColor, clWindow);
  var thumbBorder := pick(FThumbBorderColor, clBtnShadow);
  var tick := pick(FTickColor, clGrayText);
  if not Enabled then begin
    range := blend(range, clBtnFace, 50);
    thumb := blend(thumb, clBtnFace, 50);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);

  var t := trackRect;
  var radius := Math.Min(t.Width, t.Height) div 2;
  paintRoundRect(sp, t, radius, track, clNone);
  // the range fills the track between the thumbs
  var a := valueToPixel(FLow);
  var b := valueToPixel(FHigh);
  var filled := if FOrientation = soHorizontal then Rect(Math.Min(a, b), t.Top, Math.Max(a, b)+1, t.Bottom) else Rect(t.Left, Math.Min(a, b), t.Right, Math.Max(a, b)+1);
  paintRoundRect(sp, filled, radius, range, clNone);

  if FShowTicks then begin
    var step := FTickStep;
    if step <= 0 then step := Math.Max((FMax-FMin) div 10, 1);
    var size := scaled(self, FTickSize);
    var v := FMin;
    while v <= FMax do begin
      var p := valueToPixel(v);
      if FOrientation = soHorizontal then paintLine(sp, p, t.Bottom+2, p, t.Bottom+2+size, tick) else paintLine(sp, t.Right+2, p, t.Right+2+size, p, tick);
      v += step;
    end;
  end;

  var fills: array[TSliderThumb] of TColor;
  for var th in [stLow, stHigh] do begin
    var r := thumbRect(th);
    var fill := thumb;
    var border := thumbBorder;
    var part := ord(th);
    if Enabled and hoverEnabled and ((FHot = part) or (FDrag = part) or ((FHot = PART_RANGE) or (FDrag = PART_RANGE))) then border := if FDrag = part then range else hoverShade(thumbBorder, range);
    if FDrag = part then fill := blend(thumb, range, 25);
    if Focused and ringEnabled and (FActive = th) then border := ringColor;
    fills[th] := fill;
    var cx := (r.Left+r.Right)/2;
    var cy := (r.Top+r.Bottom)/2;
    var horizontal := FOrientation = soHorizontal;
    match FThumbShape of
      tsSquare: paintRoundRect(sp, r, 2, fill, border);
      tsDiamond: begin
        sp.FillPolygon(polygonOutline(cx, cy, r.Width/2, 4, 90), fill);
        sp.StrokePolyline(polygonOutline(cx, cy, r.Width/2, 4, 90), 1, border, true);
      end;
      // a tag pointing at the track
      tsPointer: begin
        var pts: array of TPointF := if horizontal then [PointF(r.Left, r.Top), PointF(r.Right, r.Top), PointF(r.Right, cy), PointF(cx, r.Bottom), PointF(r.Left, cy)]
          else [PointF(r.Left, r.Top), PointF(cx, r.Top), PointF(r.Right, cy), PointF(cx, r.Bottom), PointF(r.Left, r.Bottom)];
        sp.FillPolygon(pts, fill);
        sp.StrokePolyline(pts, 1, border, true);
      end;
      // a narrow bar across the track
      tsBar: if horizontal then paintRoundRect(sp, Rect(Round(cx)-r.Width div 5, r.Top, Round(cx)+r.Width div 5+1, r.Bottom), 2, fill, border)
        else paintRoundRect(sp, Rect(r.Left, Round(cy)-r.Height div 5, r.Right, Round(cy)+r.Height div 5+1), 2, fill, border);
    else
      paintCircle(sp, (r.Left+r.Right) div 2, (r.Top+r.Bottom) div 2, r.Width div 2, fill, border);
    end;
  end;
  sp.Flush;
  if Assigned(FOnDrawThumb) then
    for var th in [stLow, stHigh] do begin
      var state: TDrawState := [];
      if (FHot = ord(th)) and hoverEnabled then state += [dsHover];
      if FDrag = ord(th) then state += [dsPressed];
      if Focused and (FActive = th) then state += [dsFocused];
      if not Enabled then state += [dsDisabled];
      var handled := false;
      FOnDrawThumb(self, Canvas, thumbRect(th), ord(th), state, handled);
    end;

  if FValuePosition = vpNone then exit;
  applyTextQuality(Canvas);
  for var th in [stLow, stHigh] do begin
    var r := thumbRect(th);
    var text := valueText(th);
    var w := Canvas.TextWidth(text);
    var h := Canvas.TextHeight(text);
    var c := thumbCenter(th);
    var box: TRect;
    if FValuePosition = vpInside then box := Rect(c.X-w div 2-2, c.Y-h div 2, c.X+w div 2+2, c.Y+h div 2)
    else if FOrientation = soHorizontal then box := Rect(c.X-w div 2-2, r.Top-h-2, c.X+w div 2+2, r.Top-2)
    else box := Rect(r.Left-w-4, c.Y-h div 2, r.Left-2, c.Y+h div 2);
    var textColor := if FValuePosition = vpInside then contrastText(fills[th]) else ColorToRGB(if Enabled then clWindowText else clGrayText);
    paintCenteredText(Canvas, box, text, textColor);
  end;
end;

// -- input ----------------------

procedure TRangeSlider.setHot(value: integer);
begin
  if FHot = value then exit;
  FHot := value;
  Invalidate;
end;

procedure TRangeSlider.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  if FReadOnly then exit;
  var part := partAt(X, Y);
  var p := if FOrientation = soHorizontal then X else Y;
  if (part = PART_RANGE) and not FMoveRange then part := PART_NONE;
  if part = PART_NONE then begin
    if not FClickJump then exit;
    // the nearer thumb comes to the click and the drag goes on with it
    var v := pixelToValue(p);
    part := if Abs(v-FLow) <= Abs(v-FHigh) then PART_LOW else PART_HIGH;
    if part = PART_LOW then setLow(v) else setHigh(v);
    changing;
  end;
  FDrag := part;
  match part of
    PART_LOW: begin
      FActive := stLow;
      FDragOffset := p-valueToPixel(FLow);
    end;
    PART_HIGH: begin
      FActive := stHigh;
      FDragOffset := p-valueToPixel(FHigh);
    end;
    PART_RANGE: begin
      FDragOffset := p-valueToPixel(FLow);
      FDragSpan := FHigh-FLow;
    end;
  end;
  Invalidate;
end;

procedure TRangeSlider.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var p := if FOrientation = soHorizontal then X else Y;
  if FDrag = PART_NONE then begin
    setHot(partAt(X, Y));
    exit;
  end;
  var v := pixelToValue(p-FDragOffset);
  match FDrag of
    PART_LOW: setLow(v);
    PART_HIGH: setHigh(v);
    PART_RANGE: begin
      v := EnsureRange(v, FMin, FMax-FDragSpan);
      if v = FLow then exit;
      FLow := v;
      FHigh := v+FDragSpan;
      Invalidate;
    end;
  end;
  changing;
end;

procedure TRangeSlider.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FDrag = PART_NONE) then exit;
  FDrag := PART_NONE;
  setHot(partAt(X, Y));
  Invalidate;
  changed;
end;

procedure TRangeSlider.MouseLeave;
begin
  inherited MouseLeave;
  if FDrag = PART_NONE then setHot(PART_NONE);
end;

function TRangeSlider.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or FReadOnly or not Enabled then exit;
  var local := MousePos; // the wheel position comes in client coordinates
  var part := partAt(local.X, local.Y);
  if part in [PART_LOW, PART_HIGH] then FActive := TSliderThumb(part);
  moveActive(if WheelDelta > 0 then FWheelStep else -FWheelStep);
  result := true;
end;

procedure TRangeSlider.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FReadOnly then exit;
  var step := if ssCtrl in Shift then FPageStep else FKeyStep;
  match Key of
    VK_LEFT, VK_DOWN: moveActive(-step);
    VK_RIGHT, VK_UP: moveActive(step);
    VK_PRIOR: moveActive(FPageStep);
    VK_NEXT: moveActive(-FPageStep);
    VK_HOME: moveActive(FMin-FMax);
    VK_END: moveActive(FMax-FMin);
    VK_SPACE: begin
      FActive := if FActive = stLow then stHigh else stLow;
      Invalidate;
    end;
  else
    exit;
  end;
  Key := 0;
end;

procedure TRangeSlider.moveActive(delta: integer);
begin
  if delta = 0 then exit;
  var before := FLow+FHigh;
  if FActive = stLow then setLow(FLow+delta) else setHigh(FHigh+delta);
  if before <> FLow+FHigh then changed;
end;

procedure TRangeSlider.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TRangeSlider.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

function TRangeSlider.Dragging: boolean;
begin
  result := FDrag <> PART_NONE;
end;

procedure TRangeSlider.changing;
begin
  if Assigned(FOnChanging) then FOnChanging(self);
end;

procedure TRangeSlider.changed;
begin
  if Assigned(FOnChange) then FOnChange(self);
end;

// -- properties ----------------------

procedure TRangeSlider.SetRange(low, high: integer);
begin
  if low > high then SwapValues(low, high);
  FLow := snap(low);
  FHigh := snap(high);
  if FHigh-FLow < FMinRange then FHigh := Math.Min(FLow+FMinRange, FMax);
  Invalidate;
end;

procedure TRangeSlider.setMin(value: integer);
begin
  if FMin = value then exit;
  FMin := value;
  if FMax < FMin then FMax := FMin;
  SetRange(FLow, FHigh);
end;

procedure TRangeSlider.setMax(value: integer);
begin
  if FMax = value then exit;
  FMax := value;
  if FMin > FMax then FMin := FMax;
  SetRange(FLow, FHigh);
end;

procedure TRangeSlider.setLow(value: integer);
begin
  value := snap(value);
  // the low thumb pushes against the high one, never past it
  if value > FHigh-FMinRange then value := FHigh-FMinRange;
  if value < FMin then value := FMin;
  if FLow = value then exit;
  FLow := value;
  Invalidate;
end;

procedure TRangeSlider.setHigh(value: integer);
begin
  value := snap(value);
  if value < FLow+FMinRange then value := FLow+FMinRange;
  if value > FMax then value := FMax;
  if FHigh = value then exit;
  FHigh := value;
  Invalidate;
end;

procedure TRangeSlider.setStep(value: integer);
begin
  if value < 1 then value := 1;
  if FStep = value then exit;
  FStep := value;
  SetRange(FLow, FHigh);
end;

procedure TRangeSlider.setMinRange(value: integer);
begin
  if value < 0 then value := 0;
  if FMinRange = value then exit;
  FMinRange := value;
  SetRange(FLow, FHigh);
end;

procedure TRangeSlider.setOrientation(value: TSliderOrientation);
begin
  if FOrientation = value then exit;
  FOrientation := value;
  // a slider drawn the other way keeps its box turned too
  if not (csLoading in ComponentState) then SetBounds(Left, Top, Height, Width);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRangeSlider.setThumbShape(value: TSliderThumbShape);
begin
  if FThumbShape = value then exit;
  FThumbShape := value;
  Invalidate;
end;

procedure TRangeSlider.setThumbSize(value: integer);
begin
  if value < 6 then value := 6;
  if FThumbSize = value then exit;
  FThumbSize := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRangeSlider.setTrackSize(value: integer);
begin
  if value < 1 then value := 1;
  if FTrackSize = value then exit;
  FTrackSize := value;
  Invalidate;
end;

procedure TRangeSlider.setTickStep(value: integer);
begin
  if value < 0 then value := 0;
  if FTickStep = value then exit;
  FTickStep := value;
  Invalidate;
end;

procedure TRangeSlider.setTickSize(value: integer);
begin
  if value < 1 then value := 1;
  if FTickSize = value then exit;
  FTickSize := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRangeSlider.setShowTicks(value: boolean);
begin
  if FShowTicks = value then exit;
  FShowTicks := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRangeSlider.setValuePosition(value: TSliderValuePosition);
begin
  if FValuePosition = value then exit;
  FValuePosition := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRangeSlider.setValueFormat(const value: string);
begin
  if FValueFormat = value then exit;
  FValueFormat := value;
  Invalidate;
end;

function TRangeSlider.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FTrackColor;
    1: result := FRangeColor;
    2: result := FThumbColor;
    3: result := FThumbBorderColor;
    _: result := FTickColor;
  end;
end;

procedure TRangeSlider.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FTrackColor := value;
    1: FRangeColor := value;
    2: FThumbColor := value;
    3: FThumbBorderColor := value;
    _: FTickColor := value;
  end;
  Invalidate;
end;

procedure TRangeSlider.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
