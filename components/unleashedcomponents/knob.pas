{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Knob;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  // kdCircular follows the angle of the mouse around the center; kdVertical
  // turns with the vertical mouse movement, like a fader
  TKnobDragMode = (kdCircular, kdVertical);
  // the look: an arc around the knob, a flat disc with a dot for the mark,
  // or a ring of dots lighting up with the value
  TKnobStyle = (ksArc, ksFlat, ksDots);
  TKnobValueEvent = procedure(Sender: TObject; value: double; var text: string) of object;

  { TKnob }

  // a rotary control: the mark turns from StartAngle through SweepAngle as
  // the value runs from Min to Max. The mouse drags it, the wheel and the
  // arrow keys step it
  TKnob = class(TCustomControl)
  private
    FMin, FMax, FValue, FStep: double;
    FStartAngle, FSweepAngle, FKnobSize, FArcWidth: integer;
    FDragMode: TKnobDragMode;
    FShowArc, FShowValue, FShowTicks, FReadOnly: boolean;
    FTickCount: integer;
    FValueFormat: string;
    FKnobColor, FArcColor, FTrackColor, FMarkerColor, FBorderColor: TColor;
    FDragging: boolean;
    FDragStart: TPoint;
    FDragValue: double;
    FAntialiasing: TAntialiasSetting;
    FStyle: TKnobStyle;
    FLanguage: TFormatLanguage;
    FOnChange: TNotifyEvent;
    FOnFormatValue: TKnobValueEvent;
    procedure setRange(index: integer; value: double);
    function getRange(index: integer): double;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setDragMode(value: TKnobDragMode);
    procedure setValueFormat(const value: string);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setStyle(value: TKnobStyle);
    procedure setLanguage(value: TFormatLanguage);
    function fraction: double;
    function angleOf(frac: double): double;
    function knobRect: TRect;
    function valueText: string;
    procedure moveBy(delta: double);
    function valueStored(index: integer): boolean;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Min: double index 0 read getRange write setRange stored valueStored;
    property Max: double index 1 read getRange write setRange stored valueStored;
    property Value: double index 2 read getRange write setRange stored valueStored;
    // the value snaps to multiples of Step; 0 turns freely
    property Step: double index 3 read getRange write setRange stored valueStored;
    // degrees clockwise from the top where Min sits
    property StartAngle: integer index 0 read getMetric write setMetric default -135;
    // degrees the mark travels to Max
    property SweepAngle: integer index 1 read getMetric write setMetric default 270;
    // the knob; 0 fills the control
    property KnobSize: integer index 2 read getMetric write setMetric default 0;
    property ArcWidth: integer index 3 read getMetric write setMetric default 4;
    property TickCount: integer index 4 read getMetric write setMetric default 0;
    property DragMode: TKnobDragMode read FDragMode write setDragMode default kdCircular;
    // the arc from Min to the value around the knob
    property ShowArc: boolean index 0 read getFlag write setFlag default true;
    property ShowValue: boolean index 1 read getFlag write setFlag default true;
    property ShowTicks: boolean index 2 read getFlag write setFlag default false;
    property ReadOnly: boolean index 3 read getFlag write setFlag default false;
    // a Format pattern with the value as a float argument
    property ValueFormat: string read FValueFormat write setValueFormat;
    // clDefault takes the colors of the theme
    property KnobColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ArcColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TrackColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property MarkerColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Style: TKnobStyle read FStyle write setStyle default ksArc;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnFormatValue: TKnobValueEvent read FOnFormatValue write FOnFormatValue;
    property Align;
    property Anchors;
    property BorderSpacing;
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

constructor TKnob.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FMax := 100;
  FStep := 1;
  FStartAngle := -135;
  FSweepAngle := 270;
  FArcWidth := 4;
  FShowArc := true;
  FShowValue := true;
  FValueFormat := '%.0f';
  FKnobColor := clDefault;
  FArcColor := clDefault;
  FTrackColor := clDefault;
  FMarkerColor := clDefault;
  FBorderColor := clDefault;
  TabStop := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TKnob.GetControlClassDefaultSize: TSize;
begin
  result.cx := 64;
  result.cy := 64;
end;

function TKnob.valueStored(index: integer): boolean;
begin
  result := true;
end;

// -- geometry ----------------------

function TKnob.fraction: double;
begin
  result := if FMax > FMin then EnsureRange((FValue-FMin)/(FMax-FMin), 0, 1) else 0;
end;

// the angle of a share of the sweep, in radians counterclockwise from 3
// o'clock, as the canvas counts
function TKnob.angleOf(frac: double): double;
begin
  var deg := FStartAngle+frac*FSweepAngle; // clockwise from the top
  result := DegToRad(90-deg);
end;

function TKnob.knobRect: TRect;
begin
  var size := Math.Min(ClientWidth, ClientHeight);
  if FKnobSize > 0 then size := Math.Min(size, scaled(self, FKnobSize));
  // the arc and the ticks need their margin, the focus ring at least two
  var margin := if FShowArc or FShowTicks then scaled(self, FArcWidth)+scaled(self, 3) else 2;
  size -= margin*2;
  result := Rect((ClientWidth-size) div 2, (ClientHeight-size) div 2, (ClientWidth-size) div 2+size, (ClientHeight-size) div 2+size);
end;

function TKnob.valueText: string;
begin
  var fs := formatSettingsOf(FLanguage);
  result := if FValueFormat = '' then FloatToStr(FValue, fs) else Format(FValueFormat, [FValue], fs);
  if Assigned(FOnFormatValue) then FOnFormatValue(self, FValue, result);
end;

// -- painting ----------------------

procedure TKnob.Paint;
begin
  var face := pick(FKnobColor, cl3DLight);
  var arc := pick(FArcColor, clHighlight);
  var track := pick(FTrackColor, blend(clBtnFace, clBtnShadow, 40));
  var marker := pick(FMarkerColor, clWindowText);
  var border := pick(FBorderColor, clBtnShadow);
  if Focused and ringEnabled then border := ringColor;
  if not Enabled then begin
    arc := blend(arc, clBtnFace, 50);
    marker := ColorToRGB(clGrayText);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var k := knobRect;
  var cx := (k.Left+k.Right) div 2;
  var cy := (k.Top+k.Bottom) div 2;
  var rad := k.Width div 2;
  var arcW := scaled(self, FArcWidth);
  if FShowArc and (FStyle <> ksFlat) then begin
    var box := k;
    box.Inflate(arcW div 2+scaled(self, 3), arcW div 2+scaled(self, 3));
    // the canvas counts degrees counterclockwise from 3 o'clock
    var startDeg := 90-FStartAngle;
    if FStyle = ksDots then begin
      var parts := Math.Max(FSweepAngle div 15, 6);
      var ringR := box.Width/2;
      for var i := 0 to parts do begin
        var a := DegToRad(startDeg-i*FSweepAngle/parts);
        sp.FillEllipse(cx+0.5+cos(a)*ringR, cy+0.5-sin(a)*ringR, arcW/2, arcW/2, if fraction >= i/parts then arc else track);
      end;
    end else begin
      paintArc(sp, box, startDeg, -FSweepAngle, track, arcW, true);
      var deg := Round(fraction*FSweepAngle);
      if deg > 0 then paintArc(sp, box, startDeg, -deg, arc, arcW, true);
    end;
  end;
  if FShowTicks and (FTickCount > 1) then begin
    var outer := rad+scaled(self, 2)+(if FShowArc then arcW+scaled(self, 4) else 0);
    for var i := 0 to FTickCount-1 do begin
      var a := angleOf(i/(FTickCount-1));
      paintLine(sp, cx+Round(cos(a)*(outer-scaled(self, 3))), cy-Round(sin(a)*(outer-scaled(self, 3))), cx+Round(cos(a)*outer), cy-Round(sin(a)*outer), ColorToRGB(clGrayText));
    end;
  end;
  paintCircle(sp, cx, cy, rad, face, (if FStyle = ksFlat then clNone else border));
  if Enabled and hoverEnabled and FDragging then paintCircle(sp, cx, cy, rad-1, blend(face, clWindowText, 8), clNone);
  // the mark runs from the middle out, or sits as a dot near the edge
  var a := angleOf(fraction);
  var inner := rad*0.35;
  var outerM := rad*0.85;
  if FStyle = ksFlat then paintCircle(sp, cx+Round(cos(a)*rad*0.7), cy-Round(sin(a)*rad*0.7), Math.Max(rad div 7, 2), marker, clNone)
  else paintLine(sp, cx+Round(cos(a)*inner), cy-Round(sin(a)*inner), cx+Round(cos(a)*outerM), cy-Round(sin(a)*outerM), marker, Math.Max(rad div 8, 2));
  sp.Flush;
  if FShowValue then begin
    var box := Rect(0, k.Bottom, ClientWidth, ClientHeight);
    if box.Height < Canvas.TextHeight('0') then box := Rect(k.Left, cy+rad div 3, k.Right, k.Bottom);
    paintCenteredText(Canvas, box, valueText, ColorToRGB(if Enabled then clWindowText else clGrayText));
  end;
end;

// -- input ----------------------

procedure TKnob.moveBy(delta: double);
begin
  if FReadOnly or not Enabled then exit;
  setRange(2, FValue+delta);
end;

procedure TKnob.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  if FReadOnly then exit;
  FDragging := true;
  FDragStart := Point(X, Y);
  FDragValue := FValue;
  if FDragMode = kdCircular then MouseMove(Shift, X, Y);
  Invalidate;
end;

procedure TKnob.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging then exit;
  var span := FMax-FMin;
  if span <= 0 then exit;
  if FDragMode = kdVertical then begin
    // the full range over 200 pixels of travel
    setRange(2, FDragValue+(FDragStart.Y-Y)/200*span);
    exit;
  end;
  var k := knobRect;
  var cx := (k.Left+k.Right)/2;
  var cy := (k.Top+k.Bottom)/2;
  // the angle clockwise from the top, folded into the sweep
  var deg := RadToDeg(ArcTan2(X-cx, cy-Y));
  var rel := deg-FStartAngle;
  while rel < 0 do rel += 360;
  while rel >= 360 do rel -= 360;
  // the dead arc below the sweep snaps to the nearer end
  if rel > FSweepAngle+(360-FSweepAngle)/2 then rel -= 360;
  if FSweepAngle < 360 then rel := EnsureRange(rel, 0, FSweepAngle);
  setRange(2, FMin+rel/FSweepAngle*span);
end;

procedure TKnob.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FDragging then exit;
  FDragging := false;
  Invalidate;
end;

function TKnob.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result then exit;
  var step := if FStep > 0 then FStep else (FMax-FMin)/100;
  moveBy(if WheelDelta > 0 then step else -step);
  result := true;
end;

procedure TKnob.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var step := if FStep > 0 then FStep else (FMax-FMin)/100;
  if ssCtrl in Shift then step := step*10;
  match Key of
    VK_LEFT, VK_DOWN: moveBy(-step);
    VK_RIGHT, VK_UP: moveBy(step);
    VK_HOME: moveBy(FMin-FValue);
    VK_END: moveBy(FMax-FValue);
  else
    exit;
  end;
  Key := 0;
end;

procedure TKnob.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TKnob.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

function TKnob.getRange(index: integer): double;
begin
  match index of
    0: result := FMin;
    1: result := FMax;
    2: result := FValue;
    _: result := FStep;
  end;
end;

procedure TKnob.setRange(index: integer; value: double);
begin
  match index of
    0: begin
      if FMin = value then exit;
      FMin := value;
      if FMax < FMin then FMax := FMin;
    end;
    1: begin
      if FMax = value then exit;
      FMax := value;
      if FMin > FMax then FMin := FMax;
    end;
    2: begin
      if FStep > 0 then value := FMin+Round((value-FMin)/FStep)*FStep;
      value := EnsureRange(value, FMin, FMax);
      if SameValue(FValue, value) then exit;
      FValue := value;
      Invalidate;
      if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
      exit;
    end;
    _: begin
      if FStep = value then exit;
      FStep := Math.Max(value, 0);
    end;
  end;
  setRange(2, FValue);
  Invalidate;
end;

function TKnob.getMetric(index: integer): integer;
begin
  match index of
    0: result := FStartAngle;
    1: result := FSweepAngle;
    2: result := FKnobSize;
    3: result := FArcWidth;
    _: result := FTickCount;
  end;
end;

procedure TKnob.setMetric(index: integer; value: integer);
begin
  if getMetric(index) = value then exit;
  match index of
    0: FStartAngle := value;
    1: FSweepAngle := EnsureRange(value, 1, 360);
    2: FKnobSize := Math.Max(value, 0);
    3: FArcWidth := Math.Max(value, 1);
    _: FTickCount := Math.Max(value, 0);
  end;
  Invalidate;
end;

function TKnob.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FShowArc;
    1: result := FShowValue;
    2: result := FShowTicks;
    _: result := FReadOnly;
  end;
end;

procedure TKnob.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowArc := value;
    1: FShowValue := value;
    2: FShowTicks := value;
    _: FReadOnly := value;
  end;
  Invalidate;
end;

procedure TKnob.setDragMode(value: TKnobDragMode);
begin
  FDragMode := value;
end;

procedure TKnob.setValueFormat(const value: string);
begin
  if FValueFormat = value then exit;
  FValueFormat := value;
  Invalidate;
end;

function TKnob.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FKnobColor;
    1: result := FArcColor;
    2: result := FTrackColor;
    3: result := FMarkerColor;
    _: result := FBorderColor;
  end;
end;

procedure TKnob.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FKnobColor := value;
    1: FArcColor := value;
    2: FTrackColor := value;
    3: FMarkerColor := value;
    _: FBorderColor := value;
  end;
  Invalidate;
end;

procedure TKnob.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TKnob.setStyle(value: TKnobStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TKnob.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
