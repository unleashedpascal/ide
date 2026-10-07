{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ProgressRing;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  TRingTextMode = (rtPercent, rtValue, rtCaption, rtNone);
  // the ring: one arc, an arc cut into segments, a ring of dots, or a disc
  // filling up like a pie
  TRingStyle = (rsArc, rsSegments, rsDots, rsPie);
  TRingTextEvent = procedure(Sender: TObject; var text: string) of object;

  { TProgressRing }

  // progress as an arc closing a ring, the number in the middle. Indeterminate
  // runs a short arc around the ring instead; the arc animates toward a new
  // position when Animated is on
  TProgressRing = class(TGraphicControl)
  private
    FMin, FMax, FPosition: integer;
    FShown: double; // the position the arc draws now, on its way to FPosition
    FThickness, FStartAngle, FGap: integer;
    FClockwise, FRoundCaps, FIndeterminate, FAnimated: boolean;
    FTextMode: TRingTextMode;
    FTextFormat: string;
    FColor, FTrackColor, FTextColor: TColor;
    FTimer: TTimer;
    FPhase: integer;
    FOnGetText: TRingTextEvent;
    procedure setMin(value: integer);
    procedure setMax(value: integer);
    procedure setPosition(value: integer);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setTextMode(value: TRingTextMode);
    procedure setTextFormat(const value: string);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure tick(Sender: TObject);
    procedure syncTimer;
    function fraction(pos: double): double;
    function ringText: string;
  private
    FAntialiasing: TAntialiasSetting;
    FStyle: TRingStyle;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setStyle(value: TRingStyle);
  protected
    procedure Paint; override;
    procedure TextChanged; override;
    procedure VisibleChanged; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the share done, 0..1
    function Fraction: double;
    // steps the position by `delta`
    procedure StepBy(delta: integer);
  published
    property Min: integer read FMin write setMin default 0;
    property Max: integer read FMax write setMax default 100;
    property Position: integer read FPosition write setPosition default 0;
    property Thickness: integer index 0 read getMetric write setMetric default 6;
    // where the arc starts, degrees clockwise from the top
    property StartAngle: integer index 1 read getMetric write setMetric default 0;
    // left open at the bottom of the ring, degrees; 0 closes it
    property Gap: integer index 2 read getMetric write setMetric default 0;
    property Clockwise: boolean index 0 read getFlag write setFlag default true;
    property RoundCaps: boolean index 1 read getFlag write setFlag default true;
    // no position to show: a short arc runs around the ring
    property Indeterminate: boolean index 2 read getFlag write setFlag default false;
    // the arc glides to a new position instead of jumping
    property Animated: boolean index 3 read getFlag write setFlag default true;
    property TextMode: TRingTextMode read FTextMode write setTextMode default rtPercent;
    // a Format pattern; the argument is the percent or the value, after TextMode
    property TextFormat: string read FTextFormat write setTextFormat;
    property Caption;
    // clDefault takes the colors of the theme
    property RingColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TrackColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    // replaces the text in the middle
    property OnGetText: TRingTextEvent read FOnGetText write FOnGetText;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Style: TRingStyle read FStyle write setStyle default rsArc;
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

constructor TProgressRing.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption]-[csOpaque];
  FMax := 100;
  FThickness := 6;
  FClockwise := true;
  FRoundCaps := true;
  FAnimated := true;
  FTextMode := rtPercent;
  FTextFormat := '%d%%';
  FColor := clDefault;
  FTrackColor := clDefault;
  FTextColor := clDefault;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 30;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TProgressRing.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

class function TProgressRing.GetControlClassDefaultSize: TSize;
begin
  result.cx := 64;
  result.cy := 64;
end;

procedure TProgressRing.Loaded;
begin
  inherited Loaded;
  FShown := FPosition;
  syncTimer;
end;

function TProgressRing.fraction(pos: double): double;
begin
  result := if FMax > FMin then EnsureRange((pos-FMin)/(FMax-FMin), 0, 1) else 0;
end;

function TProgressRing.Fraction: double;
begin
  result := fraction(FPosition);
end;

function TProgressRing.ringText: string;
begin
  result := match FTextMode of
    rtPercent: Format(if FTextFormat = '' then '%d%%' else FTextFormat, [Round(Fraction*100)]);
    rtValue: Format(if FTextFormat = '' then '%d' else FTextFormat, [FPosition]);
    rtCaption: Caption;
  else
    ''
  end;
  if Assigned(FOnGetText) then FOnGetText(self, result);
end;

// -- painting ----------------------

procedure TProgressRing.Paint;
begin
  var ring := pick(FColor, clHighlight);
  var track := pick(FTrackColor, blend(clBtnFace, clBtnShadow, 35));
  var textColor := pick(FTextColor, clWindowText);
  if not Enabled then begin
    ring := blend(ring, clBtnFace, 50);
    textColor := ColorToRGB(clGrayText);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var thick := Math.Max(scaled(self, FThickness), 1);
  var size := Math.Min(ClientWidth, ClientHeight);
  var box := Rect((ClientWidth-size) div 2, (ClientHeight-size) div 2, (ClientWidth-size) div 2+size, (ClientHeight-size) div 2+size);
  box.Inflate(-1, -1);
  if (box.Width < thick*2) or (box.Height < thick*2) then exit;
  // the angles count counterclockwise from 3 o'clock
  var span := 360-EnsureRange(FGap, 0, 350);
  var startDeg := 90-FStartAngle-(if FGap > 0 then (360-span) div 2 else 0)*(if FClockwise then 1 else -1);
  var dir := if FClockwise then -1 else 1;
  var share := if FIndeterminate then (FPhase mod 60)/60 else fraction(FShown);
  match FStyle of
    rsSegments: begin
      var parts := Math.Max(span div 12, 6);
      for var i := 0 to parts-1 do begin
        var lit := if FIndeterminate then (i >= Round(share*parts)-3) and (i < Round(share*parts)) else share > i/parts;
        paintArc(sp, box, startDeg+dir*Round(i*span/parts), dir*Round(span/parts*0.75), (if lit then ring else track), thick, false);
      end;
    end;
    rsDots: begin
      var parts := Math.Max(span div 30, 6);
      var cx := (box.Left+box.Right)/2;
      var cy := (box.Top+box.Bottom)/2;
      var rad := box.Width/2;
      for var i := 0 to parts-1 do begin
        var a := DegToRad(startDeg+dir*(i*span/parts));
        var lit := if FIndeterminate then (i >= Round(share*parts)-2) and (i < Round(share*parts)) else share > i/parts;
        sp.FillEllipse(cx+cos(a)*rad, cy-sin(a)*rad, thick/2, thick/2, if lit then ring else track);
      end;
    end;
    // a disc eaten by the value, from the start angle on
    rsPie: begin
      var cx := (box.Left+box.Right)/2;
      var cy := (box.Top+box.Bottom)/2;
      var rad := box.Width/2;
      paintCircle(sp, Round(cx), Round(cy), Round(rad), track, clNone);
      var deg := Round(share*span);
      if deg > 0 then begin
        var pts: array of TPointF := [PointF(cx, cy)];
        var steps := Math.Max(deg div 4, 1);
        for var i := 0 to steps do begin
          var a := DegToRad(startDeg+dir*deg*i/steps);
          pts += [PointF(cx+cos(a)*rad, cy-sin(a)*rad)];
        end;
        sp.FillPolygon(pts, ring);
      end;
    end;
  else
    paintArc(sp, box, startDeg, dir*span, track, thick, FRoundCaps);
    if FIndeterminate then begin
      var sweep := 80;
      var start := startDeg+dir*Round(FPhase mod 60/60*360);
      paintArc(sp, box, start, dir*sweep, ring, thick, FRoundCaps);
    end else begin
      var deg := Round(fraction(FShown)*span);
      if deg > 0 then paintArc(sp, box, startDeg, dir*deg, ring, thick, FRoundCaps);
    end;
  end;
  sp.Flush;
  var text := if FIndeterminate and (FTextMode in [rtPercent, rtValue]) then '' else ringText;
  if text <> '' then begin
    var inner := box;
    inner.Inflate(-thick-thick div 2, -thick-thick div 2);
    // a long text shrinks to the width of the hole
    Canvas.Font := Font;
    var avail := inner.Width-scaled(self, 4);
    for var pass := 1 to 3 do begin
      var tw := Canvas.TextWidth(text);
      if (tw <= avail) or (avail <= 0) then break;
      var em := if Canvas.Font.Height <> 0 then Abs(Canvas.Font.Height) else Round(Canvas.TextHeight(text)*0.8);
      Canvas.Font.Height := -Math.Max(em*avail div tw-(pass-1), 6);
    end;
    paintCenteredText(Canvas, inner, text, textColor);
  end;
end;

// -- animation ----------------------

procedure TProgressRing.tick(Sender: TObject);
begin
  inc(FPhase);
  if FPhase >= 100000 then FPhase := 0;
  if not FIndeterminate then begin
    // the arc covers a fifth of what is left each frame, and lands exactly
    var delta := FPosition-FShown;
    if Abs(delta) < 0.05 then begin
      FShown := FPosition;
      FTimer.Enabled := false;
    end else FShown += delta*0.2;
  end;
  Invalidate;
end;

procedure TProgressRing.syncTimer;
begin
  if csDesigning in ComponentState then begin
    FShown := FPosition;
    FTimer.Enabled := false;
    exit;
  end;
  if FIndeterminate then FTimer.Enabled := Visible
  else if FAnimated and (FShown <> FPosition) and Visible then FTimer.Enabled := true
  else begin
    FShown := FPosition;
    FTimer.Enabled := false;
  end;
end;

procedure TProgressRing.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

procedure TProgressRing.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TProgressRing.StepBy(delta: integer);
begin
  setPosition(FPosition+delta);
end;

// -- properties ----------------------

procedure TProgressRing.setMin(value: integer);
begin
  if FMin = value then exit;
  FMin := value;
  if FMax < FMin then FMax := FMin;
  setPosition(FPosition);
  Invalidate;
end;

procedure TProgressRing.setMax(value: integer);
begin
  if FMax = value then exit;
  FMax := value;
  if FMin > FMax then FMin := FMax;
  setPosition(FPosition);
  Invalidate;
end;

procedure TProgressRing.setPosition(value: integer);
begin
  value := EnsureRange(value, FMin, FMax);
  if FPosition = value then exit;
  FPosition := value;
  if csLoading in ComponentState then exit;
  syncTimer;
  Invalidate;
end;

function TProgressRing.getMetric(index: integer): integer;
begin
  match index of
    0: result := FThickness;
    1: result := FStartAngle;
    _: result := FGap;
  end;
end;

procedure TProgressRing.setMetric(index: integer; value: integer);
begin
  if (index <> 1) and (value < 0) then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FThickness := value;
    1: FStartAngle := value;
    _: FGap := value;
  end;
  Invalidate;
end;

function TProgressRing.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FClockwise;
    1: result := FRoundCaps;
    2: result := FIndeterminate;
    _: result := FAnimated;
  end;
end;

procedure TProgressRing.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FClockwise := value;
    1: FRoundCaps := value;
    2: FIndeterminate := value;
    _: FAnimated := value;
  end;
  syncTimer;
  Invalidate;
end;

procedure TProgressRing.setTextMode(value: TRingTextMode);
begin
  if FTextMode = value then exit;
  FTextMode := value;
  Invalidate;
end;

procedure TProgressRing.setTextFormat(const value: string);
begin
  if FTextFormat = value then exit;
  FTextFormat := value;
  Invalidate;
end;

function TProgressRing.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FColor;
    1: result := FTrackColor;
    _: result := FTextColor;
  end;
end;

procedure TProgressRing.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FColor := value;
    1: FTrackColor := value;
    _: FTextColor := value;
  end;
  Invalidate;
end;

procedure TProgressRing.setStyle(value: TRingStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TProgressRing.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
