{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ProgressLine;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, LCLIntf, ControlPaint;

type
  TProgressLineOrientation = (plHorizontal, plVertical);
  // the fill: one block, a row of segments with gaps between them, or a
  // block with a lighter upper half
  TProgressLineStyle = (plsSolid, plsSegments, plsGradient);
  TProgressLineTextMode = (ltPercent, ltValue, ltCaption, ltNone);
  // what moves over the part still to do while AnimateRemainder is on:
  // reMarquee a block running along it, reShimmer a soft highlight sweeping
  // it, reFade the whole part breathing, reStripes diagonal stripes rolling,
  // reDots dots lighting up in turn, reWave a wave of brightness running
  TRemainderEffect = (reMarquee, reShimmer, reFade, reStripes, reDots, reWave);
  TProgressLineTextEvent = procedure(Sender: TObject; var text: string) of object;

  { TProgressLine }

  // progress as a bar filling from one end, the number over it. The fill
  // glides to a new position when Animated is on; Indeterminate runs a block
  // along the whole bar instead. AnimateRemainder keeps the part still to do
  // moving while the position holds, for a step whose length is unknown
  TProgressLine = class(TGraphicControl)
  private
    FMin, FMax, FPosition: integer;
    FShown: double; // the position the fill draws now, on its way to FPosition
    FOrientation: TProgressLineOrientation;
    FStyle: TProgressLineStyle;
    FTextMode: TProgressLineTextMode;
    FTextFormat: string;
    FEffect: TRemainderEffect;
    FIndeterminate, FAnimated, FAnimateRemainder: boolean;
    FCornerRadius, FBorderWidth, FSegmentLength: integer;
    FBarColor, FTrackColor, FTextColor, FBorderColor, FEffectColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FTimer: TTimer;
    FPhase: integer;
    FOnGetText: TProgressLineTextEvent;
    procedure setMin(value: integer);
    procedure setMax(value: integer);
    procedure setPosition(value: integer);
    procedure setOrientation(value: TProgressLineOrientation);
    procedure setStyle(value: TProgressLineStyle);
    procedure setTextMode(value: TProgressLineTextMode);
    procedure setTextFormat(const value: string);
    procedure setEffect(value: TRemainderEffect);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure tick(Sender: TObject);
    procedure syncTimer;
    function fraction(pos: double): double;
    function lineText: string;
    procedure textClipped(const area, box: TRect; const text: string; color: TColor);
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
    // a horizontal bar fills from the left, a vertical one from the bottom
    property Orientation: TProgressLineOrientation read FOrientation write setOrientation default plHorizontal;
    property Style: TProgressLineStyle read FStyle write setStyle default plsSolid;
    // no position to show: a block runs along the whole bar
    property Indeterminate: boolean index 0 read getFlag write setFlag default false;
    // the fill glides to a new position instead of jumping
    property Animated: boolean index 1 read getFlag write setFlag default true;
    // the part past the position moves with RemainderEffect, to show work
    // going on while the position cannot tell how far it is
    property AnimateRemainder: boolean index 2 read getFlag write setFlag default false;
    property RemainderEffect: TRemainderEffect read FEffect write setEffect default reMarquee;
    property TextMode: TProgressLineTextMode read FTextMode write setTextMode default ltNone;
    // a Format pattern; the argument is the percent or the value, after TextMode
    property TextFormat: string read FTextFormat write setTextFormat;
    property Caption;
    // the rounding of the ends of the bar, in pixels; 0 leaves them square
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    // a frame around the bar; 0 draws none
    property BorderWidth: integer index 1 read getMetric write setMetric default 0;
    // the length of one segment of the plsSegments style, in pixels
    property SegmentLength: integer index 2 read getMetric write setMetric default 10;
    // clDefault takes the colors of the theme
    property BarColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TrackColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    // the color of the remainder effect; clDefault takes a tint between the track and the bar
    property EffectColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // replaces the text over the bar
    property OnGetText: TProgressLineTextEvent read FOnGetText write FOnGetText;
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

type
  // a box in device coordinates, with fractional edges
  TBoxF = record
    x0, y0, x1, y1: single;
  end;

// the bar runs along one axis: `a` counts from 0 at the end the fill starts
// at, `c` runs across the bar; a vertical bar fills from the bottom up
function pointAt(const r: TRect; vertical: boolean; a, c: single): TPointF;
begin
  result := if vertical then PointF(r.Left+c, r.Bottom-a) else PointF(r.Left+a, r.Top+c);
end;

function boxOf(const r: TRect; vertical: boolean; a0, a1, c0, c1: single): TBoxF;
begin
  var p := pointAt(r, vertical, a0, c0);
  var q := pointAt(r, vertical, a1, c1);
  result.x0 := Math.Min(p.X, q.X);
  result.y0 := Math.Min(p.Y, q.Y);
  result.x1 := Math.Max(p.X, q.X);
  result.y1 := Math.Max(p.Y, q.Y);
end;

function rectOf(const b: TBoxF): TRect;
begin
  result := Rect(Floor(b.x0), Floor(b.y0), Ceil(b.x1), Ceil(b.y1));
end;

constructor TProgressLine.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption]-[csOpaque];
  FMax := 100;
  FAnimated := true;
  FCornerRadius := 4;
  FSegmentLength := 10;
  FTextMode := ltNone;
  FTextFormat := '%d%%';
  FBarColor := clDefault;
  FTrackColor := clDefault;
  FTextColor := clDefault;
  FBorderColor := clDefault;
  FEffectColor := clDefault;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 30;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TProgressLine.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

class function TProgressLine.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 20;
end;

procedure TProgressLine.Loaded;
begin
  inherited Loaded;
  FShown := FPosition;
  syncTimer;
end;

function TProgressLine.fraction(pos: double): double;
begin
  result := if FMax > FMin then EnsureRange((pos-FMin)/(FMax-FMin), 0, 1) else 0;
end;

function TProgressLine.Fraction: double;
begin
  result := fraction(FPosition);
end;

function TProgressLine.lineText: string;
begin
  result := match FTextMode of
    ltPercent: Format(if FTextFormat = '' then '%d%%' else FTextFormat, [Round(Fraction*100)]);
    ltValue: Format(if FTextFormat = '' then '%d' else FTextFormat, [FPosition]);
    ltCaption: Caption;
  else
    ''
  end;
  if Assigned(FOnGetText) then FOnGetText(self, result);
end;

// -- painting ----------------------

procedure TProgressLine.Paint;
begin
  var r := ClientRect;
  var vertical := FOrientation = plVertical;
  var len := if vertical then r.Height else r.Width;
  var thick := if vertical then r.Width else r.Height;
  if (len <= 0) or (thick <= 0) then exit;
  var back := GetRGBColorResolvingParent;
  var track := pick(FTrackColor, trackShade(back));
  var bar := pick(FBarColor, valueShade(clHighlight, track));
  var textColor := pick(FTextColor, clWindowText);
  var effect := pick(FEffectColor, legibleOn(blend(track, bar, 45), track, 2));
  if not Enabled then begin
    bar := blend(bar, clBtnFace, 50);
    effect := blend(effect, clBtnFace, 50);
    textColor := ColorToRGB(clGrayText);
  end;
  var sp := autofree beginShapes(Canvas, r, back, FAntialiasing);
  var radius := Math.Min(scaled(self, FCornerRadius), thick div 2);
  // the designer shows one still frame from the middle of the animations
  var seconds := if csDesigning in ComponentState then 0.6 else FPhase*FTimer.Interval/1000;

  // the segments: one as long as the bar for the other styles
  var segs := 1;
  var segLen: single := len;
  var gap := 0;
  if FStyle = plsSegments then begin
    gap := Math.Max(scaled(self, 2), 1);
    segs := Math.Max((len+gap) div (Math.Max(scaled(self, FSegmentLength), 2)+gap), 1);
    segLen := (len-gap*(segs-1))/segs;
  end;
  var pitch := segLen+gap;

  var done: single := if FIndeterminate then 0 else fraction(FShown)*len;
  // the block of the indeterminate bar, a third of the bar long
  var blockLen: single := Math.Min(Math.Max(len*0.3, scaled(self, 20)), len);
  var blockAt: single := -blockLen+Frac(seconds/1.6)*(len+blockLen);
  // where the part still to do starts: the position, or the first unlit segment
  var remStart: single := done;

  if FStyle = plsSegments then begin
    remStart := len;
    for var i := 0 to segs-1 do begin
      var a0 := i*pitch;
      var center := a0+segLen/2;
      var lit := if FIndeterminate then (center >= blockAt) and (center < blockAt+blockLen) else center <= done;
      if (not lit) and (not FIndeterminate) and (a0 < remStart) then remStart := a0;
      var b := boxOf(r, vertical, a0, a0+segLen, 0, thick);
      sp.FillRoundRect(b.x0, b.y0, b.x1, b.y1, Math.Min(radius, segLen/2), if lit then bar else track);
    end;
  end else begin
    var b := boxOf(r, vertical, 0, len, 0, thick);
    sp.FillRoundRect(b.x0, b.y0, b.x1, b.y1, radius, track);
    if FIndeterminate then begin
      b := boxOf(r, vertical, Math.Max(blockAt, 0), Math.Min(blockAt+blockLen, len), 0, thick);
      sp.FillRectF(b.x0, b.y0, b.x1, b.y1, bar);
    end else if done > 0 then begin
      b := boxOf(r, vertical, 0, done, 0, thick);
      sp.FillRectF(b.x0, b.y0, b.x1, b.y1, bar);
      if FStyle = plsGradient then begin
        b := boxOf(r, vertical, 0, done, 0, thick/2);
        sp.FillRectF(b.x0, b.y0, b.x1, b.y1, blend(bar, clWhite, 22));
      end;
    end;
  end;

  // the effect over the part still to do, clipped to it
  if FAnimateRemainder and (not FIndeterminate) and (remStart < len) then begin
    var remLen := len-remStart;
    sp.SetClip(rectOf(boxOf(r, vertical, remStart, len, 0, thick)));
    match FEffect of
      reMarquee: begin
        var bl := Math.Min(Math.Max(remLen*0.25, scaled(self, 16)), remLen);
        var a := remStart-bl+Frac(seconds/1.4)*(remLen+bl);
        var b := boxOf(r, vertical, a, a+bl, 0, thick);
        sp.FillRoundRect(b.x0, b.y0, b.x1, b.y1, Math.Min(radius, bl/2), effect);
      end;
      reShimmer: begin
        var c := remStart+Frac(seconds/1.8)*remLen;
        var w := Math.Max(remLen*0.12, scaled(self, 10));
        // four bands around the center, the wider the fainter
        var shares: array of integer := [20, 40, 65, 100];
        for var k := 0 to 3 do begin
          var half := w*(4-k)/4;
          var b := boxOf(r, vertical, c-half, c+half, 0, thick);
          sp.FillRectF(b.x0, b.y0, b.x1, b.y1, blend(track, effect, shares[k]));
        end;
      end;
      reFade: begin
        var k := 0.5+0.5*Sin(seconds*2.5);
        var b := boxOf(r, vertical, remStart, len, 0, thick);
        sp.FillRectF(b.x0, b.y0, b.x1, b.y1, blend(track, effect, Round(10+70*k)));
      end;
      reStripes: begin
        var w := Math.Max(scaled(self, 8), 4);
        var period := 2*w;
        var a := remStart-thick-period+Frac(seconds)*period;
        while a < len do begin
          sp.FillPolygon([pointAt(r, vertical, a, 0), pointAt(r, vertical, a+w, 0), pointAt(r, vertical, a+w+thick, thick), pointAt(r, vertical, a+thick, thick)], effect);
          a += period;
        end;
      end;
      reDots: begin
        var d: single := if FStyle = plsSegments then pitch else Math.Max(scaled(self, 14), 6);
        var rd := Math.Min(thick*0.3, scaled(self, 4));
        var n := Trunc(remLen/d);
        for var i := 0 to n-1 do begin
          var k := 0.5+0.5*Sin(seconds*4-i*0.9);
          var p := pointAt(r, vertical, remStart+d/2+i*d, thick/2);
          sp.FillEllipse(p.X, p.Y, rd, rd, blend(track, effect, Round(15+85*k)));
        end;
      end;
    else
      // reWave: slices along the bar, each as bright as the wave is there
      var s := Math.Max(scaled(self, 3), 2);
      var a: single := remStart;
      while a < len do begin
        var k := 0.5+0.5*Sin(a/Math.Max(remLen, 1)*3*Pi-seconds*5);
        sp.FillRect(rectOf(boxOf(r, vertical, a, Math.Min(a+s, len), 0, thick)), blend(track, effect, Round(15+75*k)));
        a += s;
      end;
    end;
    sp.ResetClip;
    // the gaps between the segments stay open
    if FStyle = plsSegments then
      for var i := 0 to segs-2 do begin
        var a0 := i*pitch+segLen;
        if a0 >= remStart then sp.FillRect(rectOf(boxOf(r, vertical, a0, a0+gap, 0, thick)), back);
      end;
  end;

  if FBorderWidth > 0 then begin
    var b := boxOf(r, vertical, 0, len, 0, thick);
    sp.FrameRoundRect(b.x0, b.y0, b.x1, b.y1, radius, scaled(self, FBorderWidth), pick(FBorderColor, clBtnShadow));
  end;
  // whatever ran square into the ends gets the rounding back: the frame of
  // the bar minus its outline, run the other way, is the four corners
  if radius > 0 then begin
    var frame: TOutline := [PointF(r.Left, r.Top), PointF(r.Right, r.Top), PointF(r.Right, r.Bottom), PointF(r.Left, r.Bottom)];
    sp.FillOutlines([frame, roundRectOutline(r.Left, r.Top, r.Right, r.Bottom, radius, true)], back);
  end;
  sp.Flush;

  var text := if FIndeterminate and (FTextMode in [ltPercent, ltValue]) then '' else lineText;
  if text = '' then exit;
  Canvas.Font := Font;
  if FIndeterminate or (done <= 0) then paintCenteredText(Canvas, r, text, textColor)
  else if done >= len then paintCenteredText(Canvas, r, text, contrastText(bar))
  else begin
    // over the fill the text takes a color that reads on it
    var filled := rectOf(boxOf(r, vertical, 0, done, 0, thick));
    textClipped(filled, r, text, contrastText(bar));
    textClipped(rectOf(boxOf(r, vertical, done, len, 0, thick)), r, text, textColor);
  end;
end;

procedure TProgressLine.textClipped(const area, box: TRect; const text: string; color: TColor);
begin
  var dc := Canvas.Handle;
  var saved := SaveDC(dc);
  IntersectClipRect(dc, area.Left, area.Top, area.Right, area.Bottom);
  paintCenteredText(Canvas, box, text, color);
  RestoreDC(dc, saved);
end;

// -- animation ----------------------

procedure TProgressLine.tick(Sender: TObject);
begin
  inc(FPhase);
  if FPhase >= 1000000 then FPhase := 0;
  if (not FIndeterminate) and (FShown <> FPosition) then begin
    // the fill covers a fifth of what is left each frame, and lands exactly
    var delta := FPosition-FShown;
    if Abs(delta) < 0.05 then begin
      FShown := FPosition;
      syncTimer;
    end else FShown += delta*0.2;
  end;
  Invalidate;
end;

procedure TProgressLine.syncTimer;
begin
  if csDesigning in ComponentState then begin
    FShown := FPosition;
    FTimer.Enabled := false;
    exit;
  end;
  var gliding := FAnimated and (FShown <> FPosition);
  if not gliding then FShown := FPosition;
  FTimer.Enabled := Visible and (FIndeterminate or gliding or (FAnimateRemainder and (fraction(FPosition) < 1)));
end;

procedure TProgressLine.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

procedure TProgressLine.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TProgressLine.StepBy(delta: integer);
begin
  setPosition(FPosition+delta);
end;

// -- properties ----------------------

procedure TProgressLine.setMin(value: integer);
begin
  if FMin = value then exit;
  FMin := value;
  if FMax < FMin then FMax := FMin;
  setPosition(FPosition);
  Invalidate;
end;

procedure TProgressLine.setMax(value: integer);
begin
  if FMax = value then exit;
  FMax := value;
  if FMin > FMax then FMin := FMax;
  setPosition(FPosition);
  Invalidate;
end;

procedure TProgressLine.setPosition(value: integer);
begin
  value := EnsureRange(value, FMin, FMax);
  if FPosition = value then exit;
  FPosition := value;
  if csLoading in ComponentState then exit;
  syncTimer;
  Invalidate;
end;

procedure TProgressLine.setOrientation(value: TProgressLineOrientation);
begin
  if FOrientation = value then exit;
  FOrientation := value;
  Invalidate;
end;

procedure TProgressLine.setStyle(value: TProgressLineStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TProgressLine.setTextMode(value: TProgressLineTextMode);
begin
  if FTextMode = value then exit;
  FTextMode := value;
  Invalidate;
end;

procedure TProgressLine.setTextFormat(const value: string);
begin
  if FTextFormat = value then exit;
  FTextFormat := value;
  Invalidate;
end;

procedure TProgressLine.setEffect(value: TRemainderEffect);
begin
  if FEffect = value then exit;
  FEffect := value;
  Invalidate;
end;

function TProgressLine.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FIndeterminate;
    1: result := FAnimated;
    _: result := FAnimateRemainder;
  end;
end;

procedure TProgressLine.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FIndeterminate := value;
    1: FAnimated := value;
    _: FAnimateRemainder := value;
  end;
  syncTimer;
  Invalidate;
end;

function TProgressLine.getMetric(index: integer): integer;
begin
  match index of
    0: result := FCornerRadius;
    1: result := FBorderWidth;
    _: result := FSegmentLength;
  end;
end;

procedure TProgressLine.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FCornerRadius := value;
    1: FBorderWidth := value;
    _: FSegmentLength := value;
  end;
  Invalidate;
end;

function TProgressLine.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FBarColor;
    1: result := FTrackColor;
    2: result := FTextColor;
    3: result := FBorderColor;
    _: result := FEffectColor;
  end;
end;

procedure TProgressLine.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBarColor := value;
    1: FTrackColor := value;
    2: FTextColor := value;
    3: FBorderColor := value;
    _: FEffectColor := value;
  end;
  Invalidate;
end;

procedure TProgressLine.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
