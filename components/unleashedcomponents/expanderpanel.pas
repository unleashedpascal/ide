{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ExpanderPanel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, LCLType, ControlPaint;

type
  TChevronSide = (csLeft, csRight);
  // the mark on the header that shows the state: a chevron, a plus and a
  // minus, an arrow, a filled triangle, or nothing
  TExpanderGlyph = (egChevron, egPlusMinus, egArrow, egTriangle, egNone);

  { TExpanderPanel }

  // a container folding down to its header: a click on the header, Space
  // or Enter shows or hides the children. ExpandedHeight remembers the open
  // size while the panel is closed
  TExpanderPanel = class(TCustomControl)
  private
    FExpanded, FAnimated, FShowBorder: boolean;
    FExpandedHeight, FHeaderHeight, FCornerRadius, FAnimationTime: integer;
    FChevronSide: TChevronSide;
    FHeaderColor, FBorderColor, FTitleColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FGlyph: TExpanderGlyph;
    FTimer: TTimer;
    FFrom, FTo: integer; // the heights the animation runs between
    FStarted: QWord;
    FHot: boolean;
    FOnExpanded, FOnCollapsed, FOnChange: TNotifyEvent;
    function headerPx: integer;
    function headerRect: TRect;
    procedure setExpanded(value: boolean);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setChevronSide(value: TChevronSide);
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setGlyph(value: TExpanderGlyph);
    procedure settle(animate: boolean);
    procedure tick(Sender: TObject);
  protected
    procedure Paint; override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoOnResize; override;
    procedure Loaded; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Toggle;
  published
    property Caption;
    property Expanded: boolean read FExpanded write setExpanded default true;
    // the height while open; the panel keeps it up to date itself
    property ExpandedHeight: integer index 0 read getMetric write setMetric default 160;
    // 0 takes it from the font
    property HeaderHeight: integer index 1 read getMetric write setMetric default 0;
    property CornerRadius: integer index 2 read getMetric write setMetric default 4;
    property AnimationTime: integer index 3 read getMetric write setMetric default 150;
    property Animated: boolean index 0 read getFlag write setFlag default true;
    property ShowBorder: boolean index 1 read getFlag write setFlag default true;
    property ChevronSide: TChevronSide read FChevronSide write setChevronSide default csLeft;
    // clDefault takes the colors of the theme
    property HeaderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Glyph: TExpanderGlyph read FGlyph write setGlyph default egChevron;
    property OnExpanded: TNotifyEvent read FOnExpanded write FOnExpanded;
    property OnCollapsed: TNotifyEvent read FOnCollapsed write FOnCollapsed;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property ChildSizing;
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
    property OnResize;
  end;

implementation

uses
  Math;

constructor TExpanderPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csSetCaption, csOpaque];
  TabStop := true;
  FExpanded := true;
  FAnimated := true;
  FShowBorder := true;
  FExpandedHeight := 160;
  FCornerRadius := 4;
  FAnimationTime := 150;
  FHeaderColor := clDefault;
  FBorderColor := clDefault;
  FTitleColor := clDefault;
  FAntialiasing := asTheme;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 16;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TExpanderPanel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 160;
end;

function TExpanderPanel.headerPx: integer;
begin
  result := if FHeaderHeight > 0 then scaled(self, FHeaderHeight) else lineHeightOf(Font)+scaled(self, 12);
end;

function TExpanderPanel.headerRect: TRect;
begin
  result := Rect(0, 0, ClientWidth, Min(headerPx, ClientHeight));
end;

procedure TExpanderPanel.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  var inset := if FShowBorder then 1 else 0;
  var top := ARect.Top+headerPx;
  var bottom := ARect.Bottom-inset;
  // folding keeps the body at its open layout so the window clips it instead
  // of the children piling up over the header; folded, the body sits below
  // the window, out of sight even when the align keeps the panel tall
  var body := Max(FExpandedHeight-headerPx-inset, 0);
  if FTimer.Enabled then bottom := Max(bottom, top+body)
  else if not FExpanded then begin
    top := ARect.Bottom;
    bottom := top+body;
  end;
  ARect := Rect(ARect.Left+inset, top, ARect.Right-inset, bottom);
end;

// -- folding ----------------------

procedure TExpanderPanel.Toggle;
begin
  Expanded := not FExpanded;
end;

procedure TExpanderPanel.setExpanded(value: boolean);
begin
  if FExpanded = value then exit;
  if FExpanded and not FTimer.Enabled then FExpandedHeight := Height;
  FExpanded := value;
  settle(FAnimated and not (csDesigning in ComponentState) and not (csLoading in ComponentState));
  if csLoading in ComponentState then exit;
  if Assigned(FOnChange) then FOnChange(self);
  if FExpanded then begin
    if Assigned(FOnExpanded) then FOnExpanded(self);
  end else if Assigned(FOnCollapsed) then FOnCollapsed(self);
end;

// moves the height to where the state wants it, at once or over the animation
procedure TExpanderPanel.settle(animate: boolean);
begin
  var target := if FExpanded then FExpandedHeight else headerPx+(if FShowBorder then 1 else 0);
  FTimer.Enabled := false;
  if animate and HandleAllocated and (FAnimationTime > 0) then begin
    FFrom := Height;
    FTo := target;
    FStarted := GetTickCount64;
    FTimer.Enabled := true;
  end else begin
    Height := target;
    ReAlign;
  end;
  Invalidate;
end;

procedure TExpanderPanel.tick(Sender: TObject);
begin
  var elapsed := GetTickCount64-FStarted;
  if elapsed >= QWord(FAnimationTime) then begin
    FTimer.Enabled := false;
    Height := FTo;
    // the align may have held the height, so the body moves on its own
    ReAlign;
    exit;
  end;
  // eased out: fast off the start, soft into the target
  var t := elapsed/FAnimationTime;
  t := 1-(1-t)*(1-t);
  Height := FFrom+Round((FTo-FFrom)*t);
end;

procedure TExpanderPanel.DoOnResize;
begin
  inherited DoOnResize;
  // a resize by hand while open is the new open height
  if FExpanded and not FTimer.Enabled and not (csLoading in ComponentState) then FExpandedHeight := Height;
  Invalidate;
end;

procedure TExpanderPanel.Loaded;
begin
  inherited Loaded;
  if not FExpanded then settle(false);
end;

// -- painting ----------------------

procedure TExpanderPanel.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var header := pick(FHeaderColor, blend(clBtnFace, clWindowText, 5));
  var border := pick(FBorderColor, blend(clBtnFace, clBtnShadow, 50));
  // the focus shows on the border of the header, drawn then even without ShowBorder
  var framed := FShowBorder or (Focused and ringEnabled);
  if Focused and ringEnabled then border := ringColor;
  var title := pick(FTitleColor, clWindowText);
  if not Enabled then title := ColorToRGB(clGrayText);
  var radius := scaled(self, FCornerRadius);
  var h := headerRect;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  var fill := if FHot and Enabled and hoverEnabled then hoverColor(header) else header;
  // the header keeps rounded corners on top; open, the body continues below it
  if FExpanded or FTimer.Enabled then begin
    paintRoundRect(sp, ClientRect, radius, back, clNone);
    paintRoundRect(sp, Rect(h.Left, h.Top, h.Right, Min(h.Bottom+radius, ClientHeight)), radius, fill, clNone);
    if h.Bottom+radius < ClientHeight then paintRoundRect(sp, Rect(h.Left, h.Bottom, h.Right, h.Bottom+radius), 0, back, clNone);
    if framed then begin
      paintLine(sp, h.Left, h.Bottom, h.Right, h.Bottom, border, 1);
      paintRoundRect(sp, ClientRect, radius, clNone, border);
    end;
  end else begin
    paintRoundRect(sp, h, radius, fill, (if framed then border else clNone));
  end;
  var size := Max(scaled(self, 10), 6);
  var pad := scaled(self, 10);
  var chevron := if FChevronSide = csLeft then Rect(h.Left+pad, h.Top, h.Left+pad+size, h.Bottom) else Rect(h.Right-pad-size, h.Top, h.Right-pad, h.Bottom);
  var gcx := (chevron.Left+chevron.Right) div 2;
  var gcy := (chevron.Top+chevron.Bottom) div 2;
  var arm := size div 2;
  match FGlyph of
    egPlusMinus: begin
      paintLine(sp, gcx-arm, gcy, gcx+arm, gcy, title, 2);
      if not FExpanded then paintLine(sp, gcx, gcy-arm, gcx, gcy+arm, title, 2);
    end;
    egArrow: begin
      if FExpanded then paintLine(sp, gcx, gcy-arm, gcx, gcy+arm div 2, title, 2) else paintLine(sp, gcx-arm, gcy, gcx+arm div 2, gcy, title, 2);
      paintChevron(sp, (if FExpanded then Rect(chevron.Left, gcy-arm div 2, chevron.Right, gcy+arm) else Rect(gcx-arm div 2, chevron.Top, gcx+arm, chevron.Bottom)), (if FExpanded then cdDown else cdRight), size, title);
    end;
    egTriangle: sp.FillPolygon(polygonOutline(gcx+0.5, gcy+0.5, arm, 3, (if FExpanded then 270 else 0)), title);
    egNone: ;
  else
    paintChevron(sp, chevron, (if FExpanded then cdDown else cdRight), size, title);
  end;
  sp.Flush;
  if Caption <> '' then begin
    applyTextQuality(Canvas);
    Canvas.Font.Style := Font.Style+[fsBold];
    var box := if FChevronSide = csLeft then Rect(chevron.Right+pad, h.Top, h.Right-pad, h.Bottom) else Rect(h.Left+pad, h.Top, chevron.Left-pad, h.Bottom);
    var style := Canvas.TextStyle;
    style.Alignment := taLeftJustify;
    style.Layout := tlCenter;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    style.EndEllipsis := true;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := title;
    Canvas.TextRect(box, box.Left, box.Top, Caption, style);
    Canvas.Brush.Style := bsSolid;
    Canvas.Font.Style := Font.Style;
  end;
end;

// -- input ----------------------

procedure TExpanderPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled or not headerRect.Contains(Point(X, Y)) then exit;
  if TabStop and CanSetFocus then SetFocus;
  Toggle;
end;

procedure TExpanderPanel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := headerRect.Contains(Point(X, Y));
  if hot <> FHot then begin
    FHot := hot;
    Invalidate;
  end;
end;

procedure TExpanderPanel.MouseLeave;
begin
  inherited MouseLeave;
  if FHot then begin
    FHot := false;
    Invalidate;
  end;
end;

procedure TExpanderPanel.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key in [VK_SPACE, VK_RETURN] then begin
    Key := 0;
    Toggle;
  end;
end;

procedure TExpanderPanel.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TExpanderPanel.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TExpanderPanel.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TExpanderPanel.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  ReAlign;
  if not FExpanded then settle(false);
  Invalidate;
end;

// -- properties ----------------------

function TExpanderPanel.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FAnimated else FShowBorder;
end;

procedure TExpanderPanel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FAnimated := value else FShowBorder := value;
  ReAlign;
  Invalidate;
end;

function TExpanderPanel.getMetric(index: integer): integer;
begin
  result := match index of
    0: FExpandedHeight;
    1: FHeaderHeight;
    2: FCornerRadius;
  else
    FAnimationTime
  end;
end;

procedure TExpanderPanel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: begin
      FExpandedHeight := value;
      if FExpanded and not (csLoading in ComponentState) then Height := value;
    end;
    1: begin
      FHeaderHeight := value;
      ReAlign;
      if not FExpanded then settle(false);
    end;
    2: FCornerRadius := value;
  else
    FAnimationTime := value;
  end;
  Invalidate;
end;

function TExpanderPanel.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FHeaderColor;
    1: FBorderColor;
  else
    FTitleColor
  end;
end;

procedure TExpanderPanel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FHeaderColor := value;
    1: FBorderColor := value;
  else
    FTitleColor := value;
  end;
  Invalidate;
end;

procedure TExpanderPanel.setChevronSide(value: TChevronSide);
begin
  if FChevronSide = value then exit;
  FChevronSide := value;
  Invalidate;
end;

procedure TExpanderPanel.setGlyph(value: TExpanderGlyph);
begin
  if FGlyph = value then exit;
  FGlyph := value;
  Invalidate;
end;

procedure TExpanderPanel.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
