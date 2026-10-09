{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Countdown;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  // how the time left shows: a ring running out, a bar, the text alone, a
  // disc eaten like a pie, twelve dots going out, a ring of segments
  TCountdownStyle = (cdRing, cdBar, cdText, cdPie, cdDots, cdSegments);
  TCountdownTextMode = (ctRemaining, ctElapsed, ctPercent, ctNone);
  TCountdownEvent = procedure(Sender: TObject; remainingMs: int64) of object;

  { TCountdown }

  // counts down from Duration: a ring or a bar runs out, the time left
  // shows as text, OnFinish fires at zero. Start, Pause and Reset drive it;
  // the clock is the wall clock, so a busy main loop does not slow it down
  TCountdown = class(TGraphicControl)
  private
    FDuration, FRemaining, FWarnAt: int64; // milliseconds
    FStartedAt: QWord; // the tick of Start, 0 while it stands
    FTimer: TTimer;
    FStyle: TCountdownStyle;
    FTextMode: TCountdownTextMode;
    FShowMilliseconds, FAutoStart, FLoop: boolean;
    FThickness, FInterval: integer;
    FTextFormat: string;
    FRingColor, FTrackColor, FTextColor, FWarnColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnFinish, FOnStart, FOnPause: TNotifyEvent;
    FOnTick, FOnWarn: TCountdownEvent;
    FWarned: boolean;
    procedure tick(Sender: TObject);
    procedure setDuration(value: int64);
    procedure setWarnAt(value: int64);
    procedure setStyle(value: TCountdownStyle);
    procedure setTextMode(value: TCountdownTextMode);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setTextFormat(const value: string);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function remainingNow: int64;
    function textOf(ms: int64): string;
  protected
    procedure Paint; override;
    procedure Loaded; override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start;
    procedure Pause;
    // back to the full duration, stopped
    procedure Reset;
    function Running: boolean;
    // milliseconds left
    property Remaining: int64 read remainingNow;
    // the share of the duration gone by, 0 to 1
    function Progress: double;
  published
    // milliseconds
    property Duration: int64 read FDuration write setDuration default 60000;
    // OnWarn fires once the time left falls to this; 0 for never
    property WarnAt: int64 read FWarnAt write setWarnAt default 0;
    property Style: TCountdownStyle read FStyle write setStyle default cdRing;
    property TextMode: TCountdownTextMode read FTextMode write setTextMode default ctRemaining;
    property ShowMilliseconds: boolean index 0 read getFlag write setFlag default false;
    property AutoStart: boolean index 1 read getFlag write setFlag default false;
    // at zero the count starts over
    property Loop: boolean index 2 read getFlag write setFlag default false;
    // the ring and the bar
    property Thickness: integer index 0 read getMetric write setMetric default 6;
    // milliseconds between two repaints
    property Interval: integer index 1 read getMetric write setMetric default 100;
    // a Format pattern around the time text, like "%s left"
    property TextFormat: string read FTextFormat write setTextFormat;
    // clDefault takes the colors of the theme
    property RingColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TrackColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    // the ring past WarnAt
    property WarnColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    property OnPause: TNotifyEvent read FOnPause write FOnPause;
    // every repaint while it runs
    property OnTick: TCountdownEvent read FOnTick write FOnTick;
    property OnWarn: TCountdownEvent read FOnWarn write FOnWarn;
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

constructor TCountdown.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FDuration := 60000;
  FRemaining := FDuration;
  FThickness := 6;
  FInterval := 100;
  FRingColor := clDefault;
  FTrackColor := clDefault;
  FTextColor := clDefault;
  FWarnColor := clDefault;
  FAntialiasing := asTheme;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := FInterval;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TCountdown.GetControlClassDefaultSize: TSize;
begin
  result.cx := 80;
  result.cy := 80;
end;

procedure TCountdown.Loaded;
begin
  inherited Loaded;
  FRemaining := FDuration;
  if FAutoStart and not (csDesigning in ComponentState) then Start;
end;

// -- the clock ----------------------

function TCountdown.remainingNow: int64;
begin
  result := FRemaining;
  if FStartedAt <> 0 then result := Max(FRemaining-int64(GetTickCount64-FStartedAt), 0);
end;

function TCountdown.Running: boolean;
begin
  result := FStartedAt <> 0;
end;

function TCountdown.Progress: double;
begin
  result := if FDuration > 0 then 1-remainingNow/FDuration else 1;
end;

procedure TCountdown.Start;
begin
  if Running or (csDesigning in ComponentState) then exit;
  if FRemaining <= 0 then FRemaining := FDuration;
  FStartedAt := GetTickCount64;
  FWarned := false;
  FTimer.Interval := Max(FInterval, 10);
  FTimer.Enabled := true;
  Invalidate;
  if Assigned(FOnStart) then FOnStart(self);
end;

procedure TCountdown.Pause;
begin
  if not Running then exit;
  FRemaining := remainingNow;
  FStartedAt := 0;
  FTimer.Enabled := false;
  Invalidate;
  if Assigned(FOnPause) then FOnPause(self);
end;

procedure TCountdown.Reset;
begin
  FStartedAt := 0;
  FTimer.Enabled := false;
  FRemaining := FDuration;
  FWarned := false;
  Invalidate;
end;

procedure TCountdown.tick(Sender: TObject);
begin
  var left := remainingNow;
  if (FWarnAt > 0) and not FWarned and (left <= FWarnAt) then begin
    FWarned := true;
    if Assigned(FOnWarn) then FOnWarn(self, left);
  end;
  if Assigned(FOnTick) then FOnTick(self, left);
  Invalidate;
  if left > 0 then exit;
  // the end: the count stands at zero, or starts over
  FStartedAt := 0;
  FTimer.Enabled := false;
  FRemaining := 0;
  if Assigned(FOnFinish) then FOnFinish(self);
  if FLoop then begin
    FRemaining := FDuration;
    Start;
  end;
end;

// -- text ----------------------

function TCountdown.textOf(ms: int64): string;
begin
  var total := ms div 1000;
  var h := total div 3600;
  var m := (total div 60) mod 60;
  var s := total mod 60;
  result := if h > 0 then Format('%d:%.2d:%.2d', [h, m, s]) else Format('%d:%.2d', [m, s]);
  if FShowMilliseconds then result += Format('.%d', [(ms mod 1000) div 100]);
  if FTextFormat <> '' then result := Format(FTextFormat, [result]);
end;

// -- painting ----------------------

procedure TCountdown.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var left := remainingNow;
  var warn := (FWarnAt > 0) and (left <= FWarnAt);
  var ring := if warn then pick(FWarnColor, $3539E5) else pick(FRingColor, clHighlight);
  var track := pick(FTrackColor, blend(clBtnFace, clBtnShadow, 35));
  var text := pick(FTextColor, clWindowText);
  if not Enabled then begin
    ring := blend(ring, back, 50);
    text := ColorToRGB(clGrayText);
  end;
  var share := if FDuration > 0 then left/FDuration else 0;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  var thick := Max(scaled(self, FThickness), 1);
  var textBox := ClientRect;
  match FStyle of
    cdRing: begin
      var size := Min(ClientWidth, ClientHeight);
      var box := Rect((ClientWidth-size) div 2, (ClientHeight-size) div 2, (ClientWidth+size) div 2, (ClientHeight+size) div 2);
      box.Inflate(-thick div 2-1, -thick div 2-1);
      paintArc(sp, box, 0, 360, track, thick, false);
      // the arc runs down clockwise from the top
      if share > 0 then paintArc(sp, box, 90, -Round(360*share), ring, thick, true);
      textBox := box;
    end;
    cdBar: begin
      var y := (ClientHeight-thick) div 2;
      if FTextMode <> ctNone then y := ClientHeight-thick-scaled(self, 2);
      paintRoundRect(sp, Rect(0, y, ClientWidth, y+thick), thick div 2, track, clNone);
      if share > 0 then paintRoundRect(sp, Rect(0, y, Round(ClientWidth*share), y+thick), thick div 2, ring, clNone);
      textBox := Rect(0, 0, ClientWidth, y-scaled(self, 2));
    end;
    cdText: ;
    // a disc that is eaten clockwise from the top
    cdPie: begin
      var size := Min(ClientWidth, ClientHeight);
      var box := Rect((ClientWidth-size) div 2, (ClientHeight-size) div 2, (ClientWidth+size) div 2, (ClientHeight+size) div 2);
      box.Inflate(-1, -1);
      var cx := (box.Left+box.Right)/2;
      var cy := (box.Top+box.Bottom)/2;
      var rad := box.Width/2;
      paintCircle(sp, Round(cx), Round(cy), Round(rad), track, clNone);
      if share > 0 then begin
        var pts: array of TPointF := [PointF(cx, cy)];
        var steps := Max(Round(72*share), 1);
        for var i := 0 to steps do begin
          var a := pi/2-2*pi*share*i/steps;
          pts += [PointF(cx+cos(a)*rad, cy-sin(a)*rad)];
        end;
        sp.FillPolygon(pts, ring);
      end;
      textBox := box;
    end;
    // twelve dots around the face going out one by one
    cdDots: begin
      var size := Min(ClientWidth, ClientHeight);
      var cx := ClientWidth/2;
      var cy := ClientHeight/2;
      var dotR := Max(size/16, 1.5);
      var rad := size/2-dotR-1;
      for var i := 0 to 11 do begin
        var a := pi/2-2*pi*i/12;
        var lit := share > i/12;
        sp.FillEllipse(cx+cos(a)*rad, cy-sin(a)*rad, dotR, dotR, if lit then ring else track);
      end;
      textBox := Rect(Round(cx-rad+dotR), Round(cy-rad+dotR), Round(cx+rad-dotR), Round(cy+rad-dotR));
    end;
    // the ring cut into 36 segments
    cdSegments: begin
      var size := Min(ClientWidth, ClientHeight);
      var box := Rect((ClientWidth-size) div 2, (ClientHeight-size) div 2, (ClientWidth+size) div 2, (ClientHeight+size) div 2);
      box.Inflate(-thick div 2-1, -thick div 2-1);
      for var i := 0 to 35 do begin
        var lit := share > i/36;
        paintArc(sp, box, 90-i*10, -7, (if lit then ring else track), thick, false);
      end;
      textBox := box;
    end;
  end;
  sp.Flush;
  if FTextMode = ctNone then exit;
  var shown := match FTextMode of
    ctElapsed: textOf(FDuration-left);
    ctPercent: Format('%d%%', [Round((1-share)*100)]);
  else
    textOf(left)
  end;
  applyTextQuality(Canvas);
  paintCenteredText(Canvas, textBox, shown, text);
end;

procedure TCountdown.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var textW := if FTextMode = ctNone then 0 else Canvas.TextWidth(textOf(FDuration))+scaled(self, 12);
  match FStyle of
    cdRing: begin
      PreferredWidth := Max(textW+scaled(self, FThickness)*2+scaled(self, 8), scaled(self, 80));
      PreferredHeight := PreferredWidth;
    end;
    cdBar: begin
      PreferredWidth := Max(textW, scaled(self, 120));
      PreferredHeight := Canvas.TextHeight('0')+scaled(self, FThickness)+scaled(self, 6);
    end;
  else
    begin
      PreferredWidth := textW;
      PreferredHeight := Canvas.TextHeight('0')+scaled(self, 4);
    end;
  end;
end;

// -- properties ----------------------

procedure TCountdown.setDuration(value: int64);
begin
  value := Max(value, 0);
  if FDuration = value then exit;
  FDuration := value;
  if not Running then FRemaining := value;
  Invalidate;
end;

procedure TCountdown.setWarnAt(value: int64);
begin
  FWarnAt := Max(value, 0);
  Invalidate;
end;

procedure TCountdown.setStyle(value: TCountdownStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TCountdown.setTextMode(value: TCountdownTextMode);
begin
  if FTextMode = value then exit;
  FTextMode := value;
  Invalidate;
end;

function TCountdown.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowMilliseconds;
    1: FAutoStart;
  else
    FLoop
  end;
end;

procedure TCountdown.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowMilliseconds := value;
    1: FAutoStart := value;
  else
    FLoop := value;
  end;
  Invalidate;
end;

function TCountdown.getMetric(index: integer): integer;
begin
  result := if index = 0 then FThickness else FInterval;
end;

procedure TCountdown.setMetric(index: integer; value: integer);
begin
  if value < 1 then value := 1;
  if getMetric(index) = value then exit;
  if index = 0 then FThickness := value else begin
    FInterval := value;
    FTimer.Interval := Max(value, 10);
  end;
  Invalidate;
end;

procedure TCountdown.setTextFormat(const value: string);
begin
  if FTextFormat = value then exit;
  FTextFormat := value;
  Invalidate;
end;

function TCountdown.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FRingColor;
    1: FTrackColor;
    2: FTextColor;
  else
    FWarnColor
  end;
end;

procedure TCountdown.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FRingColor := value;
    1: FTrackColor := value;
    2: FTextColor := value;
  else
    FWarnColor := value;
  end;
  Invalidate;
end;

procedure TCountdown.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
