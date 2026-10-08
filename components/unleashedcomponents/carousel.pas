{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Carousel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, LCLType, ControlPaint;

type
  { TCarousel }

  // shows one of its children at a time, as a page: the pages slide
  // sideways on their way in and out, the arrows and the dots move
  // between them, AutoPlay moves on its own. The pages are the children
  // in the order they were added
  TCarousel = class(TCustomControl)
  private
    FPageIndex, FLeaving: integer;
    FAutoPlay, FLoop, FAnimated, FShowArrows, FShowDots, FWheelMoves: boolean;
    FInterval, FAnimationTime, FArrowSize, FDotSize, FPadding: integer;
    FPlayTimer, FSlideTimer: TTimer;
    FStarted: QWord;
    FDirection: integer; // 1 forward, -1 back
    FHot: integer; // -1 none, -2 left arrow, -3 right arrow, dots from 0
    FLaying: boolean;
    FArrowColor, FDotColor, FActiveDotColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnPageChange: TNotifyEvent;
    procedure setPageIndex(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function pages: TList;
    function arrowRect(right: boolean): TRect;
    function dotRect(index: integer): TRect;
    function hitAt(x, y: integer): integer;
    procedure layout;
    procedure slideTick(Sender: TObject);
    procedure playTick(Sender: TObject);
    procedure syncPlay;
    procedure moveTo(target, direction: integer);
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure Loaded; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    function PageCount: integer;
    function CurrentPage: TControl;
    procedure NextPage;
    procedure PreviousPage;
  published
    property PageIndex: integer read FPageIndex write setPageIndex default 0;
    property AutoPlay: boolean index 0 read getFlag write setFlag default false;
    // past the last page comes the first
    property Loop: boolean index 1 read getFlag write setFlag default true;
    property Animated: boolean index 2 read getFlag write setFlag default true;
    property ShowArrows: boolean index 3 read getFlag write setFlag default true;
    property ShowDots: boolean index 4 read getFlag write setFlag default true;
    property WheelMoves: boolean index 5 read getFlag write setFlag default true;
    // milliseconds a page stays with AutoPlay
    property Interval: integer index 0 read getMetric write setMetric default 4000;
    property AnimationTime: integer index 1 read getMetric write setMetric default 250;
    property ArrowSize: integer index 2 read getMetric write setMetric default 32;
    property DotSize: integer index 3 read getMetric write setMetric default 8;
    // around the pages
    property Padding: integer index 4 read getMetric write setMetric default 0;
    // clDefault takes the colors of the theme
    property ArrowColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property DotColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property ActiveDotColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnPageChange: TNotifyEvent read FOnPageChange write FOnPageChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property ClientHeight;
    property ClientWidth;
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
  HOT_NONE = -1;
  HOT_LEFT = -2;
  HOT_RIGHT = -3;

constructor TCarousel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque]-[csSetCaption];
  TabStop := true;
  FLeaving := -1;
  FHot := HOT_NONE;
  FLoop := true;
  FAnimated := true;
  FShowArrows := true;
  FShowDots := true;
  FWheelMoves := true;
  FInterval := 4000;
  FAnimationTime := 250;
  FArrowSize := 32;
  FDotSize := 8;
  FArrowColor := clDefault;
  FDotColor := clDefault;
  FActiveDotColor := clDefault;
  FAntialiasing := asTheme;
  FPlayTimer := TTimer.Create(self);
  FPlayTimer.Enabled := false;
  FPlayTimer.OnTimer := @playTick;
  FSlideTimer := TTimer.Create(self);
  FSlideTimer.Enabled := false;
  FSlideTimer.Interval := 16;
  FSlideTimer.OnTimer := @slideTick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TCarousel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 320;
  result.cy := 200;
end;

// the children as pages; the layout moves them about, so their position
// says nothing about their order
function TCarousel.pages: TList;
begin
  result := TList.Create;
  for var i := 0 to ControlCount-1 do result.Add(Controls[i]);
end;

function TCarousel.PageCount: integer;
begin
  result := ControlCount;
end;

function TCarousel.CurrentPage: TControl;
begin
  var list := pages;
  try
    result := if (FPageIndex >= 0) and (FPageIndex < list.Count) then TControl(list[FPageIndex]) else nil;
  finally
    list.Free;
  end;
end;

// -- geometry ----------------------

function TCarousel.arrowRect(right: boolean): TRect;
begin
  var size := scaled(self, FArrowSize);
  var y := (ClientHeight-size) div 2;
  result := if right then Rect(ClientWidth-size-scaled(self, 4), y, ClientWidth-scaled(self, 4), y+size) else Rect(scaled(self, 4), y, scaled(self, 4)+size, y+size);
end;

function TCarousel.dotRect(index: integer): TRect;
begin
  var n := PageCount;
  var dot := scaled(self, FDotSize);
  var gap := dot;
  var total := n*dot+(n-1)*gap;
  var x := (ClientWidth-total) div 2+index*(dot+gap);
  var y := ClientHeight-scaled(self, 8)-dot;
  result := Rect(x, y, x+dot, y+dot);
end;

function TCarousel.hitAt(x, y: integer): integer;
begin
  if FShowArrows and (PageCount > 1) then begin
    if arrowRect(false).Contains(Point(x, y)) then exit(HOT_LEFT);
    if arrowRect(true).Contains(Point(x, y)) then exit(HOT_RIGHT);
  end;
  if FShowDots then
    for var i := 0 to PageCount-1 do begin
      var r := dotRect(i);
      r.Inflate(scaled(self, 3), scaled(self, 3));
      if r.Contains(Point(x, y)) then exit(i);
    end;
  result := HOT_NONE;
end;

// the current page fills the area; during a slide the leaving page and
// the coming one share it, the rest sits out of sight on the right
procedure TCarousel.layout;
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  var list := pages;
  try
    var pad := scaled(self, FPadding);
    var area := Rect(pad, pad, ClientWidth-pad, ClientHeight-pad);
    var w := area.Width;
    var t := 1.0;
    if FSlideTimer.Enabled and (FAnimationTime > 0) then begin
      t := Min((GetTickCount64-FStarted)/FAnimationTime, 1);
      t := 1-(1-t)*(1-t);
    end;
    for var i := 0 to list.Count-1 do begin
      var c := TControl(list[i]);
      var r := if i = FPageIndex then Rect(area.Left+Round(FDirection*w*(1-t)), area.Top, 0, 0)
        else if (i = FLeaving) and (t < 1) then Rect(area.Left-Round(FDirection*w*t), area.Top, 0, 0)
        else Rect(ClientWidth, area.Top, 0, 0);
      r.Right := r.Left+w;
      r.Bottom := r.Top+area.Height;
      // only a real change goes through, a repeat would realign forever
      if c.BoundsRect <> r then c.BoundsRect := r;
      var shown := (i = FPageIndex) or ((i = FLeaving) and (t < 1)) or (csDesigning in ComponentState);
      if c.Visible <> shown then c.Visible := shown;
    end;
  finally
    list.Free;
    FLaying := false;
  end;
end;

procedure TCarousel.AlignControls(AControl: TControl; var ARect: TRect);
begin
  layout;
end;

// -- moving ----------------------

procedure TCarousel.moveTo(target, direction: integer);
begin
  var n := PageCount;
  if n = 0 then exit;
  if FLoop then target := (target+n) mod n else target := EnsureRange(target, 0, n-1);
  if target = FPageIndex then exit;
  FLeaving := FPageIndex;
  FPageIndex := target;
  FDirection := direction;
  if FAnimated and (FAnimationTime > 0) and HandleAllocated and not (csDesigning in ComponentState) then begin
    FStarted := GetTickCount64;
    FSlideTimer.Enabled := true;
  end else FLeaving := -1;
  layout;
  Invalidate;
  syncPlay;
  if Assigned(FOnPageChange) then FOnPageChange(self);
end;

procedure TCarousel.NextPage;
begin
  moveTo(FPageIndex+1, 1);
end;

procedure TCarousel.PreviousPage;
begin
  moveTo(FPageIndex-1, -1);
end;

procedure TCarousel.slideTick(Sender: TObject);
begin
  if GetTickCount64-FStarted >= QWord(FAnimationTime) then begin
    FSlideTimer.Enabled := false;
    FLeaving := -1;
  end;
  // the pages move in one pass of the form
  DisableAutoSizing;
  try
    layout;
  finally
    EnableAutoSizing;
  end;
end;

procedure TCarousel.playTick(Sender: TObject);
begin
  if (PageCount > 1) and (FLoop or (FPageIndex < PageCount-1)) then NextPage
  else FPlayTimer.Enabled := false;
end;

procedure TCarousel.syncPlay;
begin
  FPlayTimer.Enabled := false;
  FPlayTimer.Interval := Max(FInterval, 100);
  FPlayTimer.Enabled := FAutoPlay and (PageCount > 1) and not (csDesigning in ComponentState) and not (csLoading in ComponentState);
end;

procedure TCarousel.Loaded;
begin
  inherited Loaded;
  layout;
  syncPlay;
end;

// -- painting ----------------------

procedure TCarousel.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var arrow := pick(FArrowColor, clWindowText);
  var dot := pick(FDotColor, blend(clBtnFace, clBtnShadow, 60));
  var active := pick(FActiveDotColor, clHighlight);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  var n := PageCount;
  if FShowArrows and (n > 1) then
    for var right in [false, true] do begin
      var r := arrowRect(right);
      var hot := (FHot = (if right then HOT_RIGHT else HOT_LEFT)) and hoverEnabled;
      var dimmed := not FLoop and ((right and (FPageIndex >= n-1)) or (not right and (FPageIndex <= 0)));
      paintCircle(sp, (r.Left+r.Right) div 2, (r.Top+r.Bottom) div 2, r.Width div 2, blend(back, arrow, (if hot then 25 else 12)), clNone);
      paintChevron(sp, r, (if right then cdRight else cdLeft), Max(r.Width div 3, 6), (if dimmed then blend(arrow, back, 60) else arrow));
    end;
  if FShowDots then
    for var i := 0 to n-1 do begin
      var r := dotRect(i);
      var color := if i = FPageIndex then active else if (i = FHot) and hoverEnabled then blend(dot, active, 50) else dot;
      paintCircle(sp, (r.Left+r.Right) div 2, (r.Top+r.Bottom) div 2, r.Width div 2, color, clNone);
    end;
  if Focused and ringEnabled then paintRing(sp, ClientRect, scaled(self, 4));
  sp.Flush;
end;

// -- input ----------------------

procedure TCarousel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  var hit := hitAt(X, Y);
  match hit of
    HOT_LEFT: PreviousPage;
    HOT_RIGHT: NextPage;
    HOT_NONE: ;
  else
    moveTo(hit, if hit > FPageIndex then 1 else -1);
  end;
end;

procedure TCarousel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hit := hitAt(X, Y);
  if hit <> FHot then begin
    FHot := hit;
    Invalidate;
  end;
end;

procedure TCarousel.MouseLeave;
begin
  inherited MouseLeave;
  if FHot <> HOT_NONE then begin
    FHot := HOT_NONE;
    Invalidate;
  end;
end;

procedure TCarousel.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_LEFT: PreviousPage;
    VK_RIGHT: NextPage;
    VK_HOME: moveTo(0, -1);
    VK_END: moveTo(PageCount-1, 1);
  else
    exit;
  end;
  Key := 0;
end;

function TCarousel.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or not FWheelMoves then exit;
  if WheelDelta < 0 then NextPage else PreviousPage;
  result := true;
end;

// -- properties ----------------------

procedure TCarousel.setPageIndex(value: integer);
begin
  if csLoading in ComponentState then begin
    FPageIndex := value;
    exit;
  end;
  moveTo(value, if value > FPageIndex then 1 else -1);
end;

function TCarousel.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FAutoPlay;
    1: FLoop;
    2: FAnimated;
    3: FShowArrows;
    4: FShowDots;
  else
    FWheelMoves
  end;
end;

procedure TCarousel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAutoPlay := value;
    1: FLoop := value;
    2: FAnimated := value;
    3: FShowArrows := value;
    4: FShowDots := value;
  else
    FWheelMoves := value;
  end;
  syncPlay;
  Invalidate;
end;

function TCarousel.getMetric(index: integer): integer;
begin
  result := match index of
    0: FInterval;
    1: FAnimationTime;
    2: FArrowSize;
    3: FDotSize;
  else
    FPadding
  end;
end;

procedure TCarousel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FInterval := value;
    1: FAnimationTime := value;
    2: FArrowSize := value;
    3: FDotSize := value;
  else
    FPadding := value;
  end;
  syncPlay;
  layout;
  Invalidate;
end;

function TCarousel.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FArrowColor;
    1: FDotColor;
  else
    FActiveDotColor
  end;
end;

procedure TCarousel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FArrowColor := value;
    1: FDotColor := value;
  else
    FActiveDotColor := value;
  end;
  Invalidate;
end;

procedure TCarousel.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
