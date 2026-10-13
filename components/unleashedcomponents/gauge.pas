{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Gauge;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  TGauge = class;

  { TGaugeZone }

  // a colored stretch of the scale, from one value to another
  TGaugeZone = class(TCollectionItem)
  private
    FFrom, FTo: double;
    FColor: TColor;
    procedure setFrom(value: double);
    procedure setTo(value: double);
    procedure setColor(value: TColor);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property FromValue: double read FFrom write setFrom;
    property ToValue: double read FTo write setTo;
    property Color: TColor read FColor write setColor default clRed;
  end;

  { TGaugeZones }

  TGaugeZones = class(TOwnedCollection)
  private
    function getItem(index: integer): TGaugeZone;
    procedure setItem(index: integer; value: TGaugeZone);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(owner: TGauge);
    function Add: TGaugeZone;
    function AddZone(fromValue, toValue: double; color: TColor): TGaugeZone;
    property Items[index: integer]: TGaugeZone read getItem write setItem; default;
  end;

  TGaugeTextEvent = procedure(Sender: TObject; value: double; var text: string) of object;
  // the dial: a needle over the arc, the arc filled up to the value, or an
  // arc of segments lit up to the value
  TGaugeStyle = (gsDial, gsFilled, gsSegments);

  { TGauge }

  // a dial: an arc scale from StartAngle through SweepAngle, colored zones
  // on it, a needle at the value and the number below. The needle glides to
  // a new value when Animated
  TGauge = class(TGraphicControl)
  private
    FMin, FMax, FValue, FShown: double;
    FStartAngle, FSweepAngle, FArcWidth, FMajorTicks, FMinorTicks: integer;
    FZones: TGaugeZones;
    FShowNeedle, FShowValue, FShowLabels, FAnimated, FShowArc: boolean;
    FValueFormat, FLabelFormat: string;
    FArcColor, FNeedleColor, FTickColor, FTextColor: TColor;
    FTimer: TTimer;
    FAntialiasing: TAntialiasSetting;
    FStyle: TGaugeStyle;
    FLanguage: TFormatLanguage;
    FOnGetText: TGaugeTextEvent;
    procedure setRange(index: integer; value: double);
    function getRange(index: integer): double;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setZones(value: TGaugeZones);
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setStyle(value: TGaugeStyle);
    procedure setLanguage(value: TFormatLanguage);
    function fraction(v: double): double;
    function angleOf(v: double): double;
    procedure tick(Sender: TObject);
    procedure syncTimer;
    procedure zonesChanged;
    function valueStored(index: integer): boolean;
  protected
    procedure Paint; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Min: double index 0 read getRange write setRange stored valueStored;
    property Max: double index 1 read getRange write setRange stored valueStored;
    property Value: double index 2 read getRange write setRange stored valueStored;
    // degrees clockwise from the top where Min sits
    property StartAngle: integer index 0 read getMetric write setMetric default -120;
    property SweepAngle: integer index 1 read getMetric write setMetric default 240;
    property ArcWidth: integer index 2 read getMetric write setMetric default 10;
    // ticks with labels along the scale; 0 for none
    property MajorTicks: integer index 3 read getMetric write setMetric default 5;
    // ticks between two major ones
    property MinorTicks: integer index 4 read getMetric write setMetric default 4;
    property Zones: TGaugeZones read FZones write setZones;
    property ShowArc: boolean index 0 read getFlag write setFlag default true;
    property ShowNeedle: boolean index 1 read getFlag write setFlag default true;
    property ShowValue: boolean index 2 read getFlag write setFlag default true;
    property ShowLabels: boolean index 3 read getFlag write setFlag default true;
    property Animated: boolean index 4 read getFlag write setFlag default true;
    // Format patterns with the value as a float argument
    property ValueFormat: string index 0 read getText write setText;
    property LabelFormat: string index 1 read getText write setText;
    // clDefault takes the colors of the theme
    property ArcColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property NeedleColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TickColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Style: TGaugeStyle read FStyle write setStyle default gsDial;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnGetText: TGaugeTextEvent read FOnGetText write FOnGetText;
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

{ TGaugeZone }

constructor TGaugeZone.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clRed;
end;

procedure TGaugeZone.Assign(Source: TPersistent);
begin
  if Source is TGaugeZone then begin
    FFrom := TGaugeZone(Source).FFrom;
    FTo := TGaugeZone(Source).FTo;
    FColor := TGaugeZone(Source).FColor;
    Changed(false);
  end else inherited Assign(Source);
end;

function TGaugeZone.GetDisplayName: string;
begin
  result := Format('%g .. %g', [FFrom, FTo]);
end;

procedure TGaugeZone.setFrom(value: double);
begin
  if FFrom = value then exit;
  FFrom := value;
  Changed(false);
end;

procedure TGaugeZone.setTo(value: double);
begin
  if FTo = value then exit;
  FTo := value;
  Changed(false);
end;

procedure TGaugeZone.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

{ TGaugeZones }

constructor TGaugeZones.Create(owner: TGauge);
begin
  inherited Create(owner, TGaugeZone);
end;

function TGaugeZones.getItem(index: integer): TGaugeZone;
begin
  result := TGaugeZone(inherited Items[index]);
end;

procedure TGaugeZones.setItem(index: integer; value: TGaugeZone);
begin
  inherited Items[index] := value;
end;

function TGaugeZones.Add: TGaugeZone;
begin
  result := TGaugeZone(inherited Add);
end;

function TGaugeZones.AddZone(fromValue, toValue: double; color: TColor): TGaugeZone;
begin
  result := Add;
  result.FFrom := fromValue;
  result.FTo := toValue;
  result.FColor := color;
  result.Changed(false);
end;

procedure TGaugeZones.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TGauge then TGauge(Owner).zonesChanged;
end;

{ TGauge }

constructor TGauge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FMax := 100;
  FStartAngle := -120;
  FSweepAngle := 240;
  FArcWidth := 10;
  FMajorTicks := 5;
  FMinorTicks := 4;
  FZones := TGaugeZones.Create(self);
  FShowArc := true;
  FShowNeedle := true;
  FShowValue := true;
  FShowLabels := true;
  FAnimated := true;
  FValueFormat := '%.0f';
  FLabelFormat := '%.0f';
  FArcColor := clDefault;
  FNeedleColor := clDefault;
  FTickColor := clDefault;
  FTextColor := clDefault;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 30;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TGauge.Destroy;
begin
  FTimer.Enabled := false;
  FZones.Free;
  inherited Destroy;
end;

class function TGauge.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 110;
end;

procedure TGauge.Loaded;
begin
  inherited Loaded;
  FShown := FValue;
end;

function TGauge.valueStored(index: integer): boolean;
begin
  result := true;
end;

// -- geometry ----------------------

function TGauge.fraction(v: double): double;
begin
  result := if FMax > FMin then EnsureRange((v-FMin)/(FMax-FMin), 0, 1) else 0;
end;

// radians counterclockwise from 3 o'clock, as the canvas counts
function TGauge.angleOf(v: double): double;
begin
  result := DegToRad(90-(FStartAngle+fraction(v)*FSweepAngle));
end;

// -- painting ----------------------

procedure TGauge.Paint;
begin
  var arcColor := pick(FArcColor, blend(clBtnFace, clBtnShadow, 40));
  var needle := pick(FNeedleColor, clWindowText);
  var tickColor := pick(FTickColor, clGrayText);
  var textColor := pick(FTextColor, clWindowText);
  if not Enabled then begin
    needle := ColorToRGB(clGrayText);
    textColor := ColorToRGB(clGrayText);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var labelH := if FShowLabels then Canvas.TextHeight('0') else 0;
  var size := Math.Min(ClientWidth-labelH*2, ClientHeight-labelH);
  if size < 10 then exit;
  var cx := ClientWidth div 2;
  // the dial centers on the sweep: a half dial sits lower than a full one
  var cy := (ClientHeight-labelH) div 2+(if FSweepAngle <= 200 then size div 5 else 0);
  var arcW := scaled(self, FArcWidth);
  var radius := size div 2-arcW div 2-1;
  var box := Rect(cx-radius, cy-radius, cx+radius, cy+radius);
  var startDeg := 90-FStartAngle;
  if FShowArc then begin
    paintArc(sp, box, startDeg, -FSweepAngle, arcColor, arcW, false);
    for var i := 0 to FZones.Count-1 do begin
      var z := FZones[i];
      var a := startDeg-Round(fraction(z.FromValue)*FSweepAngle);
      var sweep := Round((fraction(z.ToValue)-fraction(z.FromValue))*FSweepAngle);
      if sweep > 0 then paintArc(sp, box, a, -sweep, ColorToRGB(z.Color), arcW, false);
    end;
  end;
  // the value on the arc itself: a filled part or lit segments
  var accent := ColorToRGB(clHighlight);
  if not Enabled then accent := blend(accent, clBtnFace, 50);
  match FStyle of
    gsFilled: begin
      var deg := Round(fraction(FShown)*FSweepAngle);
      if deg > 0 then paintArc(sp, box, startDeg, -deg, accent, arcW, false);
    end;
    gsSegments: begin
      var parts := Math.Max(FSweepAngle div 10, 8);
      for var i := 0 to parts-1 do
        paintArc(sp, box, startDeg-Round(i*FSweepAngle/parts), -Round(FSweepAngle/parts*0.7), (if fraction(FShown) > i/parts then accent else arcColor), arcW, false);
    end;
  else
    ;
  end;
  // the ticks sit just inside the arc
  var tickOuter := radius-arcW div 2-scaled(self, 2);
  if FMajorTicks > 1 then begin
    var total := (FMajorTicks-1)*(FMinorTicks+1);
    for var i := 0 to total do begin
      var major := i mod (FMinorTicks+1) = 0;
      var v := FMin+(FMax-FMin)*i/total;
      var a := angleOf(v);
      var len := if major then scaled(self, 8) else scaled(self, 4);
      paintLine(sp, cx+Round(cos(a)*(tickOuter-len)), cy-Round(sin(a)*(tickOuter-len)), cx+Round(cos(a)*tickOuter), cy-Round(sin(a)*tickOuter), tickColor, (if major then 2 else 1));
    end;
  end;
  if FShowNeedle and (FStyle = gsDial) then begin
    var a := angleOf(FShown);
    var tipR := tickOuter-scaled(self, 10);
    var tailR := radius div 6;
    // a slim triangle from a hub to the tip
    var side := DegToRad(90)+a;
    var hubR := Math.Max(radius div 12, 3);
    // around the middle of the hub pixel
    var hx := cx+0.5;
    var hy := cy+0.5;
    sp.FillPolygon([PointF(hx+cos(a)*tipR, hy-sin(a)*tipR), PointF(hx+cos(side)*hubR*0.6, hy-sin(side)*hubR*0.6), PointF(hx-cos(a)*tailR, hy+sin(a)*tailR), PointF(hx-cos(side)*hubR*0.6, hy+sin(side)*hubR*0.6)], needle);
    paintCircle(sp, cx, cy, hubR, needle, clNone);
    paintCircle(sp, cx, cy, Math.Max(hubR div 2, 1), blend(needle, clWhite, 50), clNone);
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  var fs := formatSettingsOf(FLanguage);
  if FShowLabels and (FMajorTicks > 1) then begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := textColor;
    for var i := 0 to FMajorTicks-1 do begin
      var v := FMin+(FMax-FMin)*i/(FMajorTicks-1);
      var a := angleOf(v);
      var text := if FLabelFormat = '' then FloatToStr(v, fs) else Format(FLabelFormat, [v], fs);
      var lr := tickOuter-scaled(self, 12);
      var tw := Canvas.TextWidth(text);
      Canvas.TextOut(cx+Round(cos(a)*lr)-tw div 2, cy-Round(sin(a)*lr)-labelH div 2, text);
    end;
    Canvas.Brush.Style := bsSolid;
  end;
  if FShowValue then begin
    var text := if FValueFormat = '' then FloatToStr(FValue, fs) else Format(FValueFormat, [FValue], fs);
    if Assigned(FOnGetText) then FOnGetText(self, FValue, text);
    var th := Canvas.TextHeight(text);
    var vr := if FSweepAngle <= 200 then Rect(0, cy+scaled(self, 4), ClientWidth, cy+scaled(self, 4)+th) else Rect(0, cy+radius div 3, ClientWidth, cy+radius div 3+th);
    paintCenteredText(Canvas, vr, text, textColor);
  end;
end;

// -- animation ----------------------

procedure TGauge.tick(Sender: TObject);
begin
  var delta := FValue-FShown;
  if Abs(delta) < (FMax-FMin)/2000 then begin
    FShown := FValue;
    FTimer.Enabled := false;
  end else FShown += delta*0.2;
  Invalidate;
end;

procedure TGauge.syncTimer;
begin
  if not FAnimated or (csDesigning in ComponentState) or (csLoading in ComponentState) or not Visible then begin
    FShown := FValue;
    FTimer.Enabled := false;
    Invalidate;
    exit;
  end;
  FTimer.Enabled := FShown <> FValue;
end;

procedure TGauge.zonesChanged;
begin
  Invalidate;
end;

// -- properties ----------------------

function TGauge.getRange(index: integer): double;
begin
  match index of
    0: result := FMin;
    1: result := FMax;
    _: result := FValue;
  end;
end;

procedure TGauge.setRange(index: integer; value: double);
begin
  if getRange(index) = value then exit;
  match index of
    0: begin
      FMin := value;
      if FMax < FMin then FMax := FMin;
    end;
    1: begin
      FMax := value;
      if FMin > FMax then FMin := FMax;
    end;
    _: FValue := EnsureRange(value, FMin, FMax);
  end;
  if index <> 2 then FValue := EnsureRange(FValue, FMin, FMax);
  syncTimer;
  Invalidate;
end;

function TGauge.getMetric(index: integer): integer;
begin
  match index of
    0: result := FStartAngle;
    1: result := FSweepAngle;
    2: result := FArcWidth;
    3: result := FMajorTicks;
    _: result := FMinorTicks;
  end;
end;

procedure TGauge.setMetric(index: integer; value: integer);
begin
  if getMetric(index) = value then exit;
  match index of
    0: FStartAngle := value;
    1: FSweepAngle := EnsureRange(value, 1, 360);
    2: FArcWidth := Math.Max(value, 1);
    3: FMajorTicks := Math.Max(value, 0);
    _: FMinorTicks := Math.Max(value, 0);
  end;
  Invalidate;
end;

function TGauge.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FShowArc;
    1: result := FShowNeedle;
    2: result := FShowValue;
    3: result := FShowLabels;
    _: result := FAnimated;
  end;
end;

procedure TGauge.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowArc := value;
    1: FShowNeedle := value;
    2: FShowValue := value;
    3: FShowLabels := value;
    _: FAnimated := value;
  end;
  syncTimer;
  Invalidate;
end;

procedure TGauge.setZones(value: TGaugeZones);
begin
  FZones.Assign(value);
end;

function TGauge.getText(index: integer): string;
begin
  result := if index = 0 then FValueFormat else FLabelFormat;
end;

procedure TGauge.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  if index = 0 then FValueFormat := value else FLabelFormat := value;
  Invalidate;
end;

function TGauge.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FArcColor;
    1: result := FNeedleColor;
    2: result := FTickColor;
    _: result := FTextColor;
  end;
end;

procedure TGauge.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FArcColor := value;
    1: FNeedleColor := value;
    2: FTickColor := value;
    _: FTextColor := value;
  end;
  Invalidate;
end;

procedure TGauge.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TGauge.setStyle(value: TGaugeStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TGauge.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
