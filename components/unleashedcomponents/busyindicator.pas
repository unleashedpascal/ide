{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit BusyIndicator;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  // biRing: an arc running around a track; biDots: dots lighting up in
  // turn; biBars: bars pulsing in turn; biPulse: a disc breathing;
  // biDualRing: two arcs chasing each other; biChase: a comet of dots;
  // biOrbit: a dot circling a core; biGrid: nine dots lit by a wave;
  // biRipple: rings growing out of the center; biEllipsis: three dots
  // bouncing; biSegments: a ring of segments lit in turn; biClock: hands
  // turning; biFlip: a tile flipping over; biBounce: a ball on a floor
  TBusyStyle = (biRing, biDots, biBars, biPulse, biDualRing, biChase, biOrbit, biGrid, biRipple, biEllipsis, biSegments, biClock, biFlip, biBounce);
  TBusyCaptionPosition = (bcBelow, bcRight, bcNone);

  { TBusyIndicator }

  // an activity marker for a wait of unknown length. Active runs the
  // animation; off, the control shows nothing or stays as a static glyph
  TBusyIndicator = class(TGraphicControl)
  private
    FActive: boolean;
    FStyle: TBusyStyle;
    FTimer: TTimer;
    FPhase: integer; // animation step
    FFrameInterval, FSpeed: integer;
    FThickness, FDotCount, FGlyphSize, FSpacing: integer;
    FHideWhenInactive: boolean;
    FCaptionPosition: TBusyCaptionPosition;
    FColor, FTrackColor: TColor;
    procedure setActive(value: boolean);
    procedure setStyle(value: TBusyStyle);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setHideWhenInactive(value: boolean);
    procedure setCaptionPosition(value: TBusyCaptionPosition);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure tick(Sender: TObject);
    function glyphRect: TRect;
    function glyphPx: integer;
    procedure syncTimer;
  private
    FAntialiasing: TAntialiasSetting;
    procedure setAntialiasing(value: TAntialiasSetting);
  protected
    procedure Paint; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure VisibleChanged; override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Active: boolean read FActive write setActive default false;
    property Style: TBusyStyle read FStyle write setStyle default biRing;
    // milliseconds between two frames
    property FrameInterval: integer index 0 read getMetric write setMetric default 40;
    // steps of a full turn; fewer steps turn faster
    property Speed: integer index 1 read getMetric write setMetric default 24;
    // the ring and the bars
    property Thickness: integer index 2 read getMetric write setMetric default 3;
    property DotCount: integer index 3 read getMetric write setMetric default 8;
    // the glyph; 0 takes it from the font
    property GlyphSize: integer index 4 read getMetric write setMetric default 0;
    // between the glyph and the caption
    property Spacing: integer index 5 read getMetric write setMetric default 6;
    // nothing shows while inactive; off, the glyph stands still
    property HideWhenInactive: boolean read FHideWhenInactive write setHideWhenInactive default true;
    property Caption;
    property CaptionPosition: TBusyCaptionPosition read FCaptionPosition write setCaptionPosition default bcRight;
    // clDefault takes the colors of the theme
    property GlyphColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TrackColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Align;
    property Anchors;
    property AutoSize;
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

constructor TBusyIndicator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption]-[csOpaque];
  FStyle := biRing;
  FFrameInterval := 40;
  FSpeed := 24;
  FThickness := 3;
  FDotCount := 8;
  FSpacing := 6;
  FHideWhenInactive := true;
  FCaptionPosition := bcRight;
  FColor := clDefault;
  FTrackColor := clDefault;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := FFrameInterval;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TBusyIndicator.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

class function TBusyIndicator.GetControlClassDefaultSize: TSize;
begin
  result.cx := 24;
  result.cy := 24;
end;

procedure TBusyIndicator.Loaded;
begin
  inherited Loaded;
  syncTimer;
end;

// -- geometry ----------------------

function TBusyIndicator.glyphPx: integer;
begin
  if FGlyphSize > 0 then exit(scaled(self, FGlyphSize));
  if AutoSize then exit(Canvas.TextHeight('Hg')+scaled(self, 6));
  // sized by hand: the glyph fills what the caption leaves
  var hasText := (Caption <> '') and (FCaptionPosition <> bcNone);
  var gap := if hasText then scaled(self, FSpacing) else 0;
  result := match FCaptionPosition of
    bcRight: Min(ClientHeight, ClientWidth-(if hasText then Canvas.TextWidth(Caption) else 0)-gap);
    bcBelow: Min(ClientWidth, ClientHeight-(if hasText then Canvas.TextHeight('Hg') else 0)-gap);
  else
    Min(ClientWidth, ClientHeight)
  end;
  result := Max(result, 4);
end;

function TBusyIndicator.glyphRect: TRect;
begin
  var g := glyphPx;
  var hasText := (Caption <> '') and (FCaptionPosition <> bcNone);
  match FCaptionPosition of
    bcBelow: result := Rect((ClientWidth-g) div 2, 0, (ClientWidth-g) div 2+g, g);
    bcRight: result := Rect(0, (ClientHeight-g) div 2, g, (ClientHeight-g) div 2+g);
  else
    result := Rect((ClientWidth-g) div 2, (ClientHeight-g) div 2, (ClientWidth-g) div 2+g, (ClientHeight-g) div 2+g);
  end;
  if not hasText and (FCaptionPosition = bcRight) then result := Rect((ClientWidth-g) div 2, (ClientHeight-g) div 2, (ClientWidth-g) div 2+g, (ClientHeight-g) div 2+g);
end;

procedure TBusyIndicator.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var g := glyphPx;
  PreferredWidth := g;
  PreferredHeight := g;
  if (Caption = '') or (FCaptionPosition = bcNone) then exit;
  var tw := Canvas.TextWidth(Caption);
  var th := Canvas.TextHeight('Hg');
  var gap := scaled(self, FSpacing);
  if FCaptionPosition = bcRight then begin
    PreferredWidth := g+gap+tw;
    PreferredHeight := Max(g, th);
  end else begin
    PreferredWidth := Max(g, tw);
    PreferredHeight := g+gap+th;
  end;
end;

// -- painting ----------------------

procedure TBusyIndicator.Paint;
begin
  var accent := pick(FColor, clHighlight);
  var track := pick(FTrackColor, blend(clBtnFace, clBtnShadow, 35));
  if not Enabled then accent := blend(accent, clBtnFace, 50);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var showGlyph := FActive or not FHideWhenInactive;
  if showGlyph then begin
    var r := glyphRect;
    var cx := (r.Left+r.Right) div 2;
    var cy := (r.Top+r.Bottom) div 2;
    var size := r.Width;
    var steps := Max(FSpeed, 4);
    var phase := FPhase mod steps;
    match FStyle of
      biRing: begin
        var thick := Max(scaled(self, FThickness), 1);
        var box := r;
        box.Inflate(-1, -1);
        paintArc(sp, box, 0, 360, track, thick, true);
        // a quarter arc running clockwise; the angles count counterclockwise from 3 o'clock
        var start := 90-Round(phase/steps*360);
        paintArc(sp, box, start, -100, accent, thick, true);
      end;
      biDots: begin
        var n := Max(FDotCount, 3);
        var radius := size div 2-Max(size div 10, 2);
        var dot := Max(size div 10, 2);
        for var i := 0 to n-1 do begin
          var a := 2*pi*i/n-pi/2;
          var x := cx+Round(cos(a)*radius);
          var y := cy+Round(sin(a)*radius);
          // the lit dot trails three fading ones behind it
          var lead := Round(phase/steps*n) mod n;
          var back := ((i-lead) mod n+n) mod n;
          var tone := if not FActive then 50 else Max(100-back*30, 20);
          paintCircle(sp, x, y, dot, blend(track, accent, tone), clNone);
        end;
      end;
      biBars: begin
        var n := Max(Min(FDotCount, 12), 3);
        var gap := Max(size div 12, 1);
        var w := Max((size-gap*(n-1)) div n, 1);
        var x := r.Left+(size-(w*n+gap*(n-1))) div 2;
        for var i := 0 to n-1 do begin
          var t := if FActive then (sin(2*pi*(phase/steps)-i*0.6)+1)/2 else 0.5;
          var h := Round(size*(0.3+0.7*t));
          paintRoundRect(sp, Rect(x, cy-h div 2, x+w, cy-h div 2+h), Max(w div 4, 1), blend(track, accent, Round(40+60*t)), clNone);
          x += w+gap;
        end;
      end;
      biPulse: begin
        var t := if FActive then (sin(2*pi*(phase/steps))+1)/2 else 0.5;
        var radius := Round(size/2*(0.45+0.5*t));
        paintCircle(sp, cx, cy, Max(size div 2, 1), blend(GetRGBColorResolvingParent, accent, 15), clNone);
        paintCircle(sp, cx, cy, radius, blend(accent, GetRGBColorResolvingParent, Round(30*(1-t))), clNone);
      end;
      biDualRing: begin
        var thick := Max(scaled(self, FThickness), 1);
        var box := r;
        box.Inflate(-1, -1);
        var start := 90-Round(phase/steps*360);
        paintArc(sp, box, start, -70, accent, thick, true);
        paintArc(sp, box, start+180, -70, blend(accent, track, 50), thick, true);
      end;
      biChase: begin
        var n := Max(FDotCount, 4);
        var radius := size div 2-Max(size div 8, 2);
        var lead := phase/steps*n;
        for var i := 0 to n-1 do begin
          // the dots behind the lead shrink and fade
          var back := lead-i;
          while back < 0 do back += n;
          while back >= n do back -= n;
          var share := 1-back/n;
          var a := 2*pi*i/n-pi/2;
          var dot := Max(Round(size/8*(0.3+0.7*share)), 1);
          paintCircle(sp, cx+Round(cos(a)*radius), cy+Round(sin(a)*radius), dot, blend(track, accent, Round(100*share)), clNone);
        end;
      end;
      biOrbit: begin
        var radius := size div 2-Max(size div 8, 2);
        paintCircle(sp, cx, cy, Max(size div 6, 2), accent, clNone);
        paintArc(sp, Rect(cx-radius, cy-radius, cx+radius, cy+radius), 0, 360, track, 1, false);
        var a := 2*pi*phase/steps-pi/2;
        paintCircle(sp, cx+Round(cos(a)*radius), cy+Round(sin(a)*radius), Max(size div 8, 2), accent, clNone);
        var b := a-0.6;
        paintCircle(sp, cx+Round(cos(b)*radius), cy+Round(sin(b)*radius), Max(size div 14, 1), blend(track, accent, 50), clNone);
      end;
      biGrid: begin
        var cell := size/3;
        var dot := Max(Round(cell*0.3), 1);
        for var row := 0 to 2 do for var col := 0 to 2 do begin
          // the wave runs down the diagonals
          var t := if FActive then (sin(2*pi*(phase/steps)-(row+col)*0.9)+1)/2 else 0.5;
          paintCircle(sp, r.Left+Round(cell*(col+0.5)), r.Top+Round(cell*(row+0.5)), dot, blend(track, accent, Round(20+80*t)), clNone);
        end;
      end;
      biRipple: begin
        var thick := Max(scaled(self, FThickness) div 2, 1);
        for var k := 0 to 1 do begin
          // two rings half a cycle apart grow out and fade as they reach the edge
          var t := frac(phase/steps+k*0.5);
          var radius := Max(Round(size/2*t), 1);
          var tone := Round(100*(1-t));
          paintArc(sp, Rect(cx-radius, cy-radius, cx+radius, cy+radius), 0, 360, blend(GetRGBColorResolvingParent, accent, tone), thick, false);
        end;
      end;
      biEllipsis: begin
        var dot := Max(size div 8, 2);
        var gap := size div 3;
        for var i := 0 to 2 do begin
          var t := if FActive then Max(sin(2*pi*(phase/steps)-i*0.8), 0) else 0;
          paintCircle(sp, cx+(i-1)*gap, cy-Round(size/5*t), dot, blend(track, accent, Round(40+60*t)), clNone);
        end;
      end;
      biSegments: begin
        var n := Max(FDotCount, 4);
        var thick := Max(scaled(self, FThickness), 1);
        var box := r;
        box.Inflate(-1, -1);
        var lead := Round(phase/steps*n) mod n;
        for var i := 0 to n-1 do begin
          var back := ((i-lead) mod n+n) mod n;
          var tone := if not FActive then 50 else Max(100-back*(100 div n)*2, 15);
          // the gap between the segments is a tenth of their span
          var span := 360/n;
          paintArc(sp, box, 90-Round(span*i), -Round(span*0.8), blend(track, accent, tone), thick, false);
        end;
      end;
      biClock: begin
        var radius := size div 2-1;
        paintCircle(sp, cx, cy, radius, clNone, track, Max(scaled(self, FThickness) div 2, 1));
        var minute := 2*pi*phase/steps-pi/2;
        var hour := minute/12-pi/2;
        var w := Max(scaled(self, FThickness) div 2, 1);
        paintLine(sp, cx, cy, cx+Round(cos(hour)*radius*0.5), cy+Round(sin(hour)*radius*0.5), accent, w+1);
        paintLine(sp, cx, cy, cx+Round(cos(minute)*radius*0.8), cy+Round(sin(minute)*radius*0.8), accent, w);
        paintCircle(sp, cx, cy, w, accent, clNone);
      end;
      biFlip: begin
        // the tile narrows to a line and widens again, the back in the track color
        var t := cos(2*pi*phase/steps);
        var half := Max(Round(size/2*0.8*abs(t)), 1);
        var color := if t >= 0 then accent else blend(accent, track, 60);
        paintRoundRect(sp, Rect(cx-half, cy-Round(size*0.4), cx+half, cy+Round(size*0.4)), Max(half div 4, 1), color, clNone);
      end;
      biBounce: begin
        var floor := r.Bottom-Max(size div 10, 1);
        paintLine(sp, r.Left+size div 6, floor, r.Right-size div 6, floor, track, Max(scaled(self, FThickness) div 2, 1));
        var t := if FActive then abs(sin(2*pi*phase/steps)) else 1;
        var ball := Max(size div 6, 2);
        // the ball squashes as it lands
        var squash := Round(ball*(1-t)*0.4);
        paintCircle(sp, cx, floor-ball-Round((size-ball*3)*t)+squash, ball, accent, clNone);
      end;
    end;
  end;
  sp.Flush;
  if (Caption <> '') and (FCaptionPosition <> bcNone) then begin
    applyTextQuality(Canvas);
    var g := glyphRect;
    var gap := scaled(self, FSpacing);
    var box := if FCaptionPosition = bcRight then Rect(g.Right+gap, 0, ClientWidth, ClientHeight) else Rect(0, g.Bottom+gap, ClientWidth, ClientHeight);
    var style := Canvas.TextStyle;
    style.Alignment := if FCaptionPosition = bcRight then taLeftJustify else taCenter;
    style.Layout := if FCaptionPosition = bcRight then tlCenter else tlTop;
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

// -- animation ----------------------

procedure TBusyIndicator.tick(Sender: TObject);
begin
  inc(FPhase);
  if FPhase >= 100000 then FPhase := 0;
  Invalidate;
end;

procedure TBusyIndicator.syncTimer;
begin
  FTimer.Interval := Max(FFrameInterval, 10);
  FTimer.Enabled := FActive and Visible and not (csDesigning in ComponentState) and not (csLoading in ComponentState);
end;

procedure TBusyIndicator.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

procedure TBusyIndicator.TextChanged;
begin
  inherited TextChanged;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TBusyIndicator.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

procedure TBusyIndicator.setActive(value: boolean);
begin
  if FActive = value then exit;
  FActive := value;
  FPhase := 0;
  syncTimer;
  Invalidate;
end;

procedure TBusyIndicator.setStyle(value: TBusyStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

function TBusyIndicator.getMetric(index: integer): integer;
begin
  match index of
    0: result := FFrameInterval;
    1: result := FSpeed;
    2: result := FThickness;
    3: result := FDotCount;
    4: result := FGlyphSize;
    _: result := FSpacing;
  end;
end;

procedure TBusyIndicator.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FFrameInterval := value;
    1: FSpeed := value;
    2: FThickness := value;
    3: FDotCount := value;
    4: FGlyphSize := value;
    _: FSpacing := value;
  end;
  syncTimer;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TBusyIndicator.setHideWhenInactive(value: boolean);
begin
  if FHideWhenInactive = value then exit;
  FHideWhenInactive := value;
  Invalidate;
end;

procedure TBusyIndicator.setCaptionPosition(value: TBusyCaptionPosition);
begin
  if FCaptionPosition = value then exit;
  FCaptionPosition := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TBusyIndicator.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FColor else FTrackColor;
end;

procedure TBusyIndicator.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FColor := value else FTrackColor := value;
  Invalidate;
end;

procedure TBusyIndicator.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
