{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PageIndicator;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ComCtrls, ControlPaint;

type
  // the marks of the pages: dots, bars, numbers, squares, hollow rings,
  // diamonds, a worm stretched over the current page, one line with a thicker
  // part for the current page
  TIndicatorStyle = (isDots, isBars, isNumbers, isSquares, isRings, isDiamonds, isWorm, isLine);

  { TPageIndicator }

  // a row of dots standing for pages, one of them lit. On its own it
  // holds PageCount and PageIndex; tied to a page control or a notebook
  // through Target it follows and drives that one
  TPageIndicator = class(TGraphicControl)
  private
    FPageCount, FPageIndex, FHot: integer;
    FDotSize, FSpacing, FActiveWidth: integer;
    FStyle: TIndicatorStyle;
    FTarget: TWinControl;
    FDotColor, FActiveColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnChange: TNotifyEvent;
    FOnDrawDot: TCustomDrawEvent;
    procedure setPageCount(value: integer);
    procedure setPageIndex(value: integer);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setStyle(value: TIndicatorStyle);
    procedure setTarget(value: TWinControl);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function count: integer;
    function current: integer;
    function dotRect(index: integer): TRect;
    function dotAt(x, y: integer): integer;
    procedure pushToTarget(index: integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // picks up the page of the target again, after it changed elsewhere
    procedure Refresh;
  published
    // used without a target
    property PageCount: integer read FPageCount write setPageCount default 3;
    property PageIndex: integer read FPageIndex write setPageIndex default 0;
    // a TPageControl, a TNotebook or a carousel-like control with PageIndex
    property Target: TWinControl read FTarget write setTarget;
    property Style: TIndicatorStyle read FStyle write setStyle default isDots;
    property DotSize: integer index 0 read getMetric write setMetric default 8;
    property Spacing: integer index 1 read getMetric write setMetric default 8;
    // the lit dot stretches to this width; 0 keeps it round
    property ActiveWidth: integer index 2 read getMetric write setMetric default 0;
    // clDefault takes the colors of the theme
    property DotColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ActiveColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // paints one dot by itself: dsSelected for the current page, dsHover under the mouse
    property OnDrawDot: TCustomDrawEvent read FOnDrawDot write FOnDrawDot;
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
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
  end;

implementation

uses
  Math, TypInfo, ExtCtrls;

constructor TPageIndicator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FPageCount := 3;
  FHot := -1;
  FDotSize := 8;
  FSpacing := 8;
  FDotColor := clDefault;
  FActiveColor := clDefault;
  FAntialiasing := asTheme;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TPageIndicator.GetControlClassDefaultSize: TSize;
begin
  result.cx := 60;
  result.cy := 16;
end;

// -- the target ----------------------

// the pages of the target, or the own count
function TPageIndicator.count: integer;
begin
  if FTarget is TCustomTabControl then exit(TCustomTabControl(FTarget).PageCount);
  if FTarget is TNotebook then exit(TNotebook(FTarget).PageCount);
  if (FTarget <> nil) and (GetPropInfo(FTarget, 'PageCount') <> nil) then exit(GetOrdProp(FTarget, 'PageCount'));
  if FTarget <> nil then exit(FTarget.ControlCount);
  result := FPageCount;
end;

function TPageIndicator.current: integer;
begin
  if FTarget is TCustomTabControl then exit(TCustomTabControl(FTarget).PageIndex);
  if FTarget is TNotebook then exit(TNotebook(FTarget).PageIndex);
  if (FTarget <> nil) and (GetPropInfo(FTarget, 'PageIndex') <> nil) then exit(GetOrdProp(FTarget, 'PageIndex'));
  result := FPageIndex;
end;

procedure TPageIndicator.pushToTarget(index: integer);
begin
  if FTarget is TCustomTabControl then TCustomTabControl(FTarget).PageIndex := index
  else if FTarget is TNotebook then TNotebook(FTarget).PageIndex := index
  else if (FTarget <> nil) and (GetPropInfo(FTarget, 'PageIndex') <> nil) then SetOrdProp(FTarget, 'PageIndex', index);
end;

procedure TPageIndicator.Refresh;
begin
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- geometry ----------------------

function TPageIndicator.dotRect(index: integer): TRect;
begin
  var n := count;
  var dot := scaled(self, FDotSize);
  var gap := scaled(self, FSpacing);
  var active := if FActiveWidth > 0 then scaled(self, FActiveWidth) else dot;
  var cur := current;
  var x := 0;
  var total := 0;
  for var i := 0 to n-1 do total += (if (i = cur) and (FStyle <> isNumbers) then active else dot)+(if i < n-1 then gap else 0);
  x := (ClientWidth-total) div 2;
  for var i := 0 to n-1 do begin
    var w := if (i = cur) and (FStyle <> isNumbers) then active else dot;
    if i = index then exit(Rect(x, (ClientHeight-dot) div 2, x+w, (ClientHeight+dot) div 2));
    x += w+gap;
  end;
  result := Rect(0, 0, 0, 0);
end;

function TPageIndicator.dotAt(x, y: integer): integer;
begin
  for var i := 0 to count-1 do begin
    var r := dotRect(i);
    r.Inflate(scaled(self, FSpacing) div 2, scaled(self, 4));
    if r.Contains(Point(x, y)) then exit(i);
  end;
  result := -1;
end;

procedure TPageIndicator.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var n := count;
  var dot := scaled(self, FDotSize);
  var gap := scaled(self, FSpacing);
  var active := if (FActiveWidth > 0) and (FStyle <> isNumbers) then scaled(self, FActiveWidth) else dot;
  PreferredWidth := Max(n-1, 0)*(dot+gap)+active+scaled(self, 4);
  PreferredHeight := Max(dot, (if FStyle = isNumbers then Canvas.TextHeight('0') else 0))+scaled(self, 4);
end;

// -- painting ----------------------

procedure TPageIndicator.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var dot := pick(FDotColor, blend(clBtnFace, clBtnShadow, 60));
  var active := pick(FActiveColor, clHighlight);
  if not Enabled then active := blend(active, back, 50);
  var cur := current;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  var custom := Assigned(FOnDrawDot);
  if not custom then
    for var i := 0 to count-1 do begin
      var r := dotRect(i);
      var color := if i = cur then active else if (i = FHot) and hoverEnabled then blend(dot, active, 50) else dot;
      var cx := (r.Left+r.Right)/2;
      var cy := (r.Top+r.Bottom)/2;
      match FStyle of
        isBars: paintRoundRect(sp, Rect(r.Left, r.Top+r.Height div 3, r.Right, r.Bottom-r.Height div 3), 1, color, clNone);
        isNumbers: ;
        isSquares: paintRoundRect(sp, r, 1, color, clNone);
        // hollow rings, the current one filled
        isRings: if i = cur then paintPill(sp, r, color, clNone) else paintCircle(sp, Round(cx), Round(cy), r.Height div 2-1, clNone, color, Math.Max(r.Height div 5, 1));
        isDiamonds: sp.FillPolygon(polygonOutline(cx, cy, r.Height/2, 4, 90), color);
        // the current dot stretches over the gap to the next one
        isWorm: if i = cur then paintPill(sp, Rect(r.Left, r.Top, r.Right+(if i < count-1 then scaled(self, FSpacing) div 2 else 0), r.Bottom), color, clNone) else paintPill(sp, r, color, clNone);
        // one thin line with the current page as a thicker part
        isLine: paintRoundRect(sp, Rect(r.Left-(if i > 0 then scaled(self, FSpacing) else 0), (if i = cur then r.Top+r.Height div 4 else Round(cy)-1), r.Right, (if i = cur then r.Bottom-r.Height div 4 else Round(cy)+1)), 1, color, clNone);
      else
        paintPill(sp, r, color, clNone);
      end;
    end;
  sp.Flush;
  if custom then
    for var i := 0 to count-1 do begin
      var r := dotRect(i);
      var state: TDrawState := if i = cur then [dsSelected] else [];
      if (i = FHot) and hoverEnabled then state += [dsHover];
      if not Enabled then state += [dsDisabled];
      var handled := false;
      FOnDrawDot(self, Canvas, r, i, state, handled);
      if not handled then begin
        var own := autofree beginShapes(Canvas, r, back, FAntialiasing);
        paintPill(own, r, (if i = cur then active else dot), clNone);
        own.Flush;
      end;
    end;
  if FStyle = isNumbers then begin
    applyTextQuality(Canvas);
    for var i := 0 to count-1 do begin
      var r := dotRect(i);
      r.Inflate(scaled(self, 2), scaled(self, 4));
      Canvas.Font.Style := if i = cur then Font.Style+[fsBold] else Font.Style;
      paintCenteredText(Canvas, r, IntToStr(i+1), (if i = cur then active else ColorToRGB(clGrayText)));
    end;
    Canvas.Font.Style := Font.Style;
  end;
end;

// -- input ----------------------

procedure TPageIndicator.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  var hit := dotAt(X, Y);
  if hit >= 0 then PageIndex := hit;
end;

procedure TPageIndicator.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hit := dotAt(X, Y);
  if hit <> FHot then begin
    FHot := hit;
    Invalidate;
  end;
end;

procedure TPageIndicator.MouseLeave;
begin
  inherited MouseLeave;
  if FHot >= 0 then begin
    FHot := -1;
    Invalidate;
  end;
end;

procedure TPageIndicator.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FTarget) then begin
    FTarget := nil;
    Refresh;
  end;
end;

// -- properties ----------------------

procedure TPageIndicator.setPageCount(value: integer);
begin
  value := Max(value, 0);
  if FPageCount = value then exit;
  FPageCount := value;
  if FPageIndex >= value then FPageIndex := Max(value-1, 0);
  Refresh;
end;

procedure TPageIndicator.setPageIndex(value: integer);
begin
  value := EnsureRange(value, 0, Max(count-1, 0));
  if FTarget <> nil then pushToTarget(value);
  if FPageIndex = value then begin
    Invalidate;
    exit;
  end;
  FPageIndex := value;
  Refresh;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

function TPageIndicator.getMetric(index: integer): integer;
begin
  result := match index of
    0: FDotSize;
    1: FSpacing;
  else
    FActiveWidth
  end;
end;

procedure TPageIndicator.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FDotSize := value;
    1: FSpacing := value;
  else
    FActiveWidth := value;
  end;
  Refresh;
end;

procedure TPageIndicator.setStyle(value: TIndicatorStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Refresh;
end;

procedure TPageIndicator.setTarget(value: TWinControl);
begin
  if FTarget = value then exit;
  if FTarget <> nil then FTarget.RemoveFreeNotification(self);
  FTarget := value;
  if FTarget <> nil then FTarget.FreeNotification(self);
  Refresh;
end;

function TPageIndicator.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FDotColor else FActiveColor;
end;

procedure TPageIndicator.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FDotColor := value else FActiveColor := value;
  Invalidate;
end;

procedure TPageIndicator.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
