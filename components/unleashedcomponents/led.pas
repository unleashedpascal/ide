{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Led;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  // the outline of the light: a disc, a square, a rounded square, a diamond,
  // a triangle, a hexagon, a wide bar, a hollow ring
  TLedShape = (lsRound, lsSquare, lsRounded, lsDiamond, lsTriangle, lsHexagon, lsBar, lsRing);
  TLedCaptionPosition = (lcRight, lcLeft, lcBelow, lcNone);

  { TLed }

  // an indicator light: on, off or blinking, with a caption beside it. A
  // clickable one toggles on a click
  TLed = class(TGraphicControl)
  private
    FOn, FBlink, FClickable, FGlow, FBorder: boolean;
    FBlinkInterval, FLedSize, FSpacing, FBorderWidth: integer;
    FShape: TLedShape;
    FCaptionPosition: TLedCaptionPosition;
    FColorOn, FColorOff, FBorderColor: TColor;
    FTimer: TTimer;
    FPhase: boolean; // the lit half of a blink
    FAntialiasing: TAntialiasSetting;
    FOnChange: TNotifyEvent;
    FOnDraw: TCustomDrawEvent;
    procedure setOn(value: boolean);
    procedure setBlink(value: boolean);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setShape(value: TLedShape);
    procedure setCaptionPosition(value: TLedCaptionPosition);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure tick(Sender: TObject);
    procedure syncTimer;
    function ledRect: TRect;
  protected
    procedure Paint; override;
    procedure Click; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure VisibleChanged; override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Toggle;
    // the light is lit right now, the blink phase included
    function Lit: boolean;
  published
    property LedOn: boolean read FOn write setOn default false;
    // the light flashes while on
    property Blink: boolean read FBlink write setBlink default false;
    // milliseconds of a blink half
    property BlinkInterval: integer index 0 read getMetric write setMetric default 500;
    property LedSize: integer index 1 read getMetric write setMetric default 14;
    // between the light and the caption
    property Spacing: integer index 2 read getMetric write setMetric default 6;
    // a click toggles the light
    property Clickable: boolean index 0 read getFlag write setFlag default false;
    // a soft halo around a lit light
    property Glow: boolean index 1 read getFlag write setFlag default true;
    property Shape: TLedShape read FShape write setShape default lsRound;
    // a frame around the light, in BorderColor
    property Border: boolean index 2 read getFlag write setFlag default true;
    // the frame, in pixels
    property BorderWidth: integer index 3 read getMetric write setMetric default 1;
    property Caption;
    property CaptionPosition: TLedCaptionPosition read FCaptionPosition write setCaptionPosition default lcRight;
    // clDefault takes the colors of the theme
    property ColorOn: TColor index 0 read getPartColor write setPartColor default clLime;
    property ColorOff: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // after the light went on or off
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // paints the light by itself: dsChecked while it is lit
    property OnDraw: TCustomDrawEvent read FOnDraw write FOnDraw;
    property Align;
    property Anchors;
    property AutoSize default true;
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
  end;

implementation

uses
  Math;

constructor TLed.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption]-[csOpaque];
  FBlinkInterval := 500;
  FLedSize := 14;
  FSpacing := 6;
  FGlow := true;
  FBorder := true;
  FBorderWidth := 1;
  FShape := lsRound;
  FCaptionPosition := lcRight;
  FColorOn := clLime;
  FColorOff := clDefault;
  FBorderColor := clDefault;
  FPhase := true;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TLed.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

class function TLed.GetControlClassDefaultSize: TSize;
begin
  result.cx := 60;
  result.cy := 16;
end;

procedure TLed.Loaded;
begin
  inherited Loaded;
  syncTimer;
end;

function TLed.Lit: boolean;
begin
  result := FOn and (not FBlink or FPhase);
end;

procedure TLed.Toggle;
begin
  setOn(not FOn);
end;

// -- geometry ----------------------

function TLed.ledRect: TRect;
begin
  var size := scaled(self, FLedSize);
  var hasText := (Caption <> '') and (FCaptionPosition <> lcNone);
  match FCaptionPosition of
    lcLeft: if hasText then result := Rect(ClientWidth-size, (ClientHeight-size) div 2, ClientWidth, (ClientHeight-size) div 2+size) else result := Rect(0, (ClientHeight-size) div 2, size, (ClientHeight-size) div 2+size);
    lcBelow: result := Rect((ClientWidth-size) div 2, 0, (ClientWidth-size) div 2+size, size);
    lcRight: result := Rect(0, (ClientHeight-size) div 2, size, (ClientHeight-size) div 2+size);
  else
    result := Rect((ClientWidth-size) div 2, (ClientHeight-size) div 2, (ClientWidth-size) div 2+size, (ClientHeight-size) div 2+size);
  end;
end;

procedure TLed.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var size := scaled(self, FLedSize);
  PreferredWidth := size+2;
  PreferredHeight := size+2;
  if (Caption = '') or (FCaptionPosition = lcNone) then exit;
  var tw := Canvas.TextWidth(Caption);
  var th := Canvas.TextHeight('Hg');
  var gap := scaled(self, FSpacing);
  if FCaptionPosition = lcBelow then begin
    PreferredWidth := Math.Max(size, tw)+2;
    PreferredHeight := size+gap+th;
  end else begin
    PreferredWidth := size+gap+tw+2;
    PreferredHeight := Math.Max(size, th)+2;
  end;
end;

// -- painting ----------------------

procedure TLed.Paint;
begin
  var onColor := ColorToRGB(FColorOn);
  var offColor := pick(FColorOff, blend(clBtnFace, clBtnShadow, 70));
  var border := pick(FBorderColor, clBtnShadow);
  var isLit := Lit and Enabled;
  var bg := GetRGBColorResolvingParent;
  var r := ledRect;
  var state: TDrawState := if isLit then [dsChecked] else [];
  if not Enabled then state += [dsDisabled];
  if not customDraw(self, Canvas, FOnDraw, r, 0, state, bg, FAntialiasing) then begin
  var sp := autofree beginShapes(Canvas, ClientRect, bg, FAntialiasing);
  var cx := (r.Left+r.Right) div 2;
  var cy := (r.Top+r.Bottom) div 2;
  var rad := r.Width div 2;
  var fill := if isLit then onColor else offColor;
  if not Enabled then fill := blend(fill, clBtnFace, 50);
  var bw := Math.Max(scaled(self, FBorderWidth), 1);
  // the light at any size: the halo is the same shape, wider
  var shape := procedure(radius: integer; fill, edge: TColor; halo: boolean)
  begin
    var box := Rect(cx-radius, cy-radius, cx+radius+1, cy+radius+1);
    var polygon := procedure(sides: integer; startDeg, dy: single)
    begin
      var o := polygonOutline(cx+0.5, cy+0.5+dy, radius+0.5, sides, startDeg);
      sp.FillPolygon(o, fill);
      if edge <> clNone then sp.StrokePolyline(o, bw, edge, true);
    end;
    match FShape of
      lsSquare: paintRoundRect(sp, box, 0, fill, edge, bw);
      lsRounded: paintRoundRect(sp, box, Math.Max(radius div 3, 1), fill, edge, bw);
      lsDiamond: polygon(4, 90, 0);
      lsTriangle: polygon(3, 90, radius*0.15);
      lsHexagon: polygon(6, 30, 0);
      // a wide pill, half as high as the light
      lsBar: paintRoundRect(sp, Rect(cx-radius, cy-radius div 2, cx+radius+1, cy+radius div 2+1), radius div 2, fill, edge, bw);
      // a ring that lights up as a whole, under a disc of halo
      lsRing: if halo then paintCircle(sp, cx, cy, radius, fill, clNone)
      else begin
        var thick := Math.Max(radius div 3, 2);
        paintCircle(sp, cx, cy, radius, clNone, fill, thick);
        if edge <> clNone then begin
          paintCircle(sp, cx, cy, radius, clNone, edge, bw);
          paintCircle(sp, cx, cy, radius-thick, clNone, edge, bw);
        end;
      end;
    else
      paintCircle(sp, cx, cy, radius, fill, edge, bw);
    end;
  end;
  if isLit and FGlow then begin
    // the halo fades out in two steps
    shape(rad, blend(bg, onColor, 20), clNone, true);
    shape(rad-rad div 5, blend(bg, onColor, 45), clNone, true);
  end;
  var inner := rad-Math.Max(rad div 4, 2);
  shape(inner, fill, if FBorder then border else clNone, false);
  sp.Flush;
  end;

  if (Caption <> '') and (FCaptionPosition <> lcNone) then begin
    applyTextQuality(Canvas);
    var gap := scaled(self, FSpacing);
    var box: TRect;
    match FCaptionPosition of
      lcLeft: box := Rect(0, 0, r.Left-gap, ClientHeight);
      lcBelow: box := Rect(0, r.Bottom+gap, ClientWidth, ClientHeight);
    else
      box := Rect(r.Right+gap, 0, ClientWidth, ClientHeight);
    end;
    var style := Canvas.TextStyle;
    style.Alignment := match FCaptionPosition of lcLeft: taRightJustify; lcBelow: taCenter; else taLeftJustify end;
    style.Layout := if FCaptionPosition = lcBelow then tlTop else tlCenter;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := ColorToRGB(if Enabled then clWindowText else clGrayText);
    Canvas.TextRect(box, box.Left, box.Top, Caption, style);
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- behavior ----------------------

procedure TLed.tick(Sender: TObject);
begin
  FPhase := not FPhase;
  Invalidate;
end;

procedure TLed.syncTimer;
begin
  FTimer.Interval := Math.Max(FBlinkInterval, 20);
  var run := FOn and FBlink and Visible and not (csDesigning in ComponentState) and not (csLoading in ComponentState);
  if not run then FPhase := true;
  FTimer.Enabled := run;
end;

procedure TLed.Click;
begin
  if FClickable and Enabled then Toggle;
  inherited Click;
end;

procedure TLed.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

procedure TLed.TextChanged;
begin
  inherited TextChanged;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TLed.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

procedure TLed.setOn(value: boolean);
begin
  if FOn = value then exit;
  FOn := value;
  syncTimer;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TLed.setBlink(value: boolean);
begin
  if FBlink = value then exit;
  FBlink := value;
  syncTimer;
  Invalidate;
end;

function TLed.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FClickable;
    1: result := FGlow;
    _: result := FBorder;
  end;
end;

procedure TLed.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FClickable := value;
    1: FGlow := value;
    _: FBorder := value;
  end;
  Cursor := if FClickable then crHandPoint else crDefault;
  Invalidate;
end;

function TLed.getMetric(index: integer): integer;
begin
  match index of
    0: result := FBlinkInterval;
    1: result := FLedSize;
    2: result := FSpacing;
    _: result := FBorderWidth;
  end;
end;

procedure TLed.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FBlinkInterval := value;
    1: FLedSize := Math.Max(value, 4);
    2: FSpacing := value;
    _: FBorderWidth := value;
  end;
  syncTimer;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TLed.setShape(value: TLedShape);
begin
  if FShape = value then exit;
  FShape := value;
  Invalidate;
end;

procedure TLed.setCaptionPosition(value: TLedCaptionPosition);
begin
  if FCaptionPosition = value then exit;
  FCaptionPosition := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TLed.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FColorOn;
    1: result := FColorOff;
    _: result := FBorderColor;
  end;
end;

procedure TLed.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FColorOn := value;
    1: FColorOff := value;
    _: FBorderColor := value;
  end;
  Invalidate;
end;

procedure TLed.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
