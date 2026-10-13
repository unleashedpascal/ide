{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Marquee;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls;

type
  TMarqueeDirection = (mdLeft, mdRight, mdUp, mdDown);
  // mbScroll runs the text through and starts over; mbBounce turns at the ends
  TMarqueeBehavior = (mbScroll, mbBounce);

  { TMarquee }

  // a caption rolling across the control, like a ticker. Pauses under the
  // mouse when wanted; OnCycle fires each time the text went through
  TMarquee = class(TGraphicControl)
  private
    FTimer: TTimer;
    FActive, FPauseOnHover, FHovered, FTransparent: boolean;
    FDirection: TMarqueeDirection;
    FBehavior: TMarqueeBehavior;
    FSpeed, FInterval, FGap: integer;
    FOffset: integer; // pixels the text moved from its start
    FForward: boolean; // the bounce direction
    FOnCycle: TNotifyEvent;
    procedure setActive(value: boolean);
    procedure setDirection(value: TMarqueeDirection);
    procedure setBehavior(value: TMarqueeBehavior);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setTransparent(value: boolean);
    procedure tick(Sender: TObject);
    procedure syncTimer;
    function textSize: TSize;
    function vertical: boolean;
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure TextChanged; override;
    procedure VisibleChanged; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // puts the text back at its start
    procedure Reset;
  published
    property Caption;
    property Active: boolean read FActive write setActive default true;
    property Direction: TMarqueeDirection read FDirection write setDirection default mdLeft;
    property Behavior: TMarqueeBehavior read FBehavior write setBehavior default mbScroll;
    // pixels per step
    property Speed: integer index 0 read getMetric write setMetric default 2;
    // milliseconds between steps
    property Interval: integer index 1 read getMetric write setMetric default 30;
    // pixels between the end of the text and its next run
    property Gap: integer index 2 read getMetric write setMetric default 40;
    property PauseOnHover: boolean read FPauseOnHover write FPauseOnHover default true;
    property Transparent: boolean read FTransparent write setTransparent default true;
    property OnCycle: TNotifyEvent read FOnCycle write FOnCycle;
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
  Math, LCLIntf, ControlPaint;

constructor TMarquee.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption]-[csOpaque];
  FActive := true;
  FPauseOnHover := true;
  FTransparent := true;
  FDirection := mdLeft;
  FBehavior := mbScroll;
  FSpeed := 2;
  FInterval := 30;
  FGap := 40;
  FForward := true;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TMarquee.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

class function TMarquee.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 24;
end;

procedure TMarquee.Loaded;
begin
  inherited Loaded;
  syncTimer;
end;

function TMarquee.vertical: boolean;
begin
  result := FDirection in [mdUp, mdDown];
end;

function TMarquee.textSize: TSize;
begin
  result.cx := Canvas.TextWidth(Caption);
  result.cy := Canvas.TextHeight('Hg');
end;

// -- motion ----------------------

procedure TMarquee.tick(Sender: TObject);
begin
  if FPauseOnHover and FHovered then exit;
  var size := textSize;
  var span := if vertical then size.cy else size.cx;
  var room := if vertical then ClientHeight else ClientWidth;
  var step := Max(FSpeed, 1);
  if FBehavior = mbScroll then begin
    FOffset += step;
    // one cycle is the text plus the gap; past it the run starts over
    if FOffset >= span+scaled(self, FGap) then begin
      FOffset := 0;
      if Assigned(FOnCycle) then FOnCycle(self);
    end;
  end else begin
    var travel := Max(room-span, 0);
    if FForward then FOffset += step else FOffset -= step;
    if FOffset >= travel then begin
      FOffset := travel;
      FForward := false;
      if Assigned(FOnCycle) then FOnCycle(self);
    end else if FOffset <= 0 then begin
      FOffset := 0;
      FForward := true;
    end;
  end;
  Invalidate;
end;

procedure TMarquee.syncTimer;
begin
  FTimer.Interval := Max(FInterval, 10);
  FTimer.Enabled := FActive and Visible and not (csDesigning in ComponentState) and not (csLoading in ComponentState);
end;

procedure TMarquee.Reset;
begin
  FOffset := 0;
  FForward := true;
  Invalidate;
end;

// -- painting ----------------------

procedure TMarquee.Paint;
begin
  if not FTransparent then begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := GetRGBColorResolvingParent;
    Canvas.FillRect(ClientRect);
  end;
  if Caption = '' then exit;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ColorToRGB(if Enabled then Font.Color else clGrayText);
  if Font.Color = clDefault then Canvas.Font.Color := ColorToRGB(if Enabled then clWindowText else clGrayText);
  var size := textSize;
  var room := if vertical then ClientHeight else ClientWidth;
  var span := if vertical then size.cy else size.cx;
  var cycle := span+scaled(self, FGap);
  // the text runs past both edges of a graphic control, so the canvas is
  // clipped in logical coordinates and the clip the parent set stays
  var saved := SaveDC(Canvas.Handle);
  try
    IntersectClipRect(Canvas.Handle, 0, 0, ClientWidth, ClientHeight);
    var positions: array of integer;
    if FBehavior = mbBounce then positions := [FOffset]
    else begin
      // the text enters from one side, leaves on the other, and its next
      // run follows one cycle behind
      var start := match FDirection of
        mdLeft, mdUp: room-FOffset;
      else
        FOffset-span
      end;
      positions := [start];
      if FDirection in [mdLeft, mdUp] then begin
        if start+span < room then positions := [start, start+cycle];
        if start > 0 then positions := positions+[start-cycle];
      end else begin
        if start > 0 then positions := [start, start-cycle];
        if start+span < room then positions := positions+[start+cycle];
      end;
    end;
    for var p in positions do begin
      if (p > room) or (p+span < 0) then continue;
      if vertical then Canvas.TextOut((ClientWidth-size.cx) div 2, p, Caption) else Canvas.TextOut(p, (ClientHeight-size.cy) div 2, Caption);
    end;
  finally
    RestoreDC(Canvas.Handle, saved);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TMarquee.MouseEnter;
begin
  inherited MouseEnter;
  FHovered := true;
end;

procedure TMarquee.MouseLeave;
begin
  inherited MouseLeave;
  FHovered := false;
end;

procedure TMarquee.TextChanged;
begin
  inherited TextChanged;
  Reset;
end;

procedure TMarquee.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

// -- properties ----------------------

procedure TMarquee.setActive(value: boolean);
begin
  if FActive = value then exit;
  FActive := value;
  syncTimer;
end;

procedure TMarquee.setDirection(value: TMarqueeDirection);
begin
  if FDirection = value then exit;
  FDirection := value;
  Reset;
end;

procedure TMarquee.setBehavior(value: TMarqueeBehavior);
begin
  if FBehavior = value then exit;
  FBehavior := value;
  Reset;
end;

function TMarquee.getMetric(index: integer): integer;
begin
  match index of
    0: result := FSpeed;
    1: result := FInterval;
    _: result := FGap;
  end;
end;

procedure TMarquee.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FSpeed := value;
    1: FInterval := value;
    _: FGap := value;
  end;
  syncTimer;
end;

procedure TMarquee.setTransparent(value: boolean);
begin
  if FTransparent = value then exit;
  FTransparent := value;
  Invalidate;
end;

end.
