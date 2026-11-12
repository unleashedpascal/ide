{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ContentPanel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  TContentHorizontalAlign = (chLeft, chCenter, chRight);
  TContentVerticalAlign = (cvTop, cvCenter, cvBottom);

  { TContentPanel }

  // a plain container with the few knobs a panel lacks: the children that
  // are not aligned or anchored move as one group to the left, the center or
  // the right and to the top, the middle or the bottom of the free area, a
  // padding keeps them off the edges, and the box can have rounded corners,
  // a frame, or no background of its own
  TContentPanel = class(TCustomControl)
  private
    FHorizontalAlign: TContentHorizontalAlign;
    FVerticalAlign: TContentVerticalAlign;
    FPadding, FCornerRadius, FBorderWidth: integer;
    FBorderColor: TColor;
    FTransparent: boolean;
    FAntialiasing: TAntialiasSetting;
    FArranging: boolean;
    // per axis: where the group stood before it left the left or the top,
    // whether that is known, and a note to take it or to go back to it
    FHome: TPoint;
    FHomeKnown, FLeaving, FReturning: array[boolean] of boolean;
    procedure setHorizontalAlign(value: TContentHorizontalAlign);
    procedure setVerticalAlign(value: TContentVerticalAlign);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setBorderColor(value: TColor);
    procedure setTransparent(value: boolean);
    procedure setAntialiasing(value: TAntialiasSetting);
    // true for a child the group placement moves: not aligned, anchored to
    // the left and the top only
    function free(c: TControl): boolean;
  protected
    procedure Paint; override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure TextChanged; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    // where the group of free children sits in the box: the children that are
    // not aligned or anchored move together, keeping their places to each
    // other. Left and top leave them where they were placed, and bring them
    // back there after another choice; AutoSize leaves them alone
    property HorizontalAlign: TContentHorizontalAlign read FHorizontalAlign write setHorizontalAlign default chLeft;
    property VerticalAlign: TContentVerticalAlign read FVerticalAlign write setVerticalAlign default cvTop;
    // between the edge and the aligned children or the placed group
    property Padding: integer index 0 read getMetric write setMetric default 0;
    property CornerRadius: integer index 1 read getMetric write setMetric default 0;
    // a frame around the box; 0 draws none
    property BorderWidth: integer index 2 read getMetric write setMetric default 0;
    // clDefault takes the color of the theme
    property BorderColor: TColor read FBorderColor write setBorderColor default clDefault;
    // the box paints no background of its own, the parent shows through
    property Transparent: boolean read FTransparent write setTransparent default false;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // shown in the middle when there is one
    property Caption;
    property Align;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property DockSite;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property Hint;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDockDrop;
    property OnDockOver;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnPaint;
    property OnResize;
    property OnUnDock;
  end;

implementation

uses
  Math;

constructor TContentPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csSetCaption, csOpaque, csNoFocus]-[csOpaque];
  TabStop := false;
  FBorderColor := clDefault;
  FAntialiasing := asTheme;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TContentPanel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 120;
end;

procedure TContentPanel.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  var inset := scaled(self, FPadding)+scaled(self, FBorderWidth);
  ARect.Inflate(-inset, -inset);
end;

function TContentPanel.free(c: TControl): boolean;
begin
  result := (c.Align = alNone) and (c.Anchors = [akLeft, akTop]) and (c.Visible or (csDesigning in ComponentState));
end;

// the LCL places the aligned and the anchored children; the rest moves as
// one group to where HorizontalAlign and VerticalAlign say
procedure TContentPanel.AlignControls(AControl: TControl; var ARect: TRect);
begin
  inherited AlignControls(AControl, ARect);
  if FArranging or AutoSize or (csDestroying in ComponentState) then exit;
  if (FHorizontalAlign = chLeft) and (FVerticalAlign = cvTop) and not (FReturning[false] or FReturning[true]) then exit;
  var box := Rect(MaxInt, MaxInt, -MaxInt, -MaxInt);
  for var i := 0 to ControlCount-1 do
    if free(Controls[i]) then UnionRect(box, box, Controls[i].BoundsRect);
  if box.Left > box.Right then exit;
  if FLeaving[false] then begin
    FHome.X := box.Left;
    FHomeKnown[false] := true;
  end;
  if FLeaving[true] then begin
    FHome.Y := box.Top;
    FHomeKnown[true] := true;
  end;
  var dx := match FHorizontalAlign of
    chCenter: (ARect.Left+ARect.Right-box.Left-box.Right) div 2;
    chRight: ARect.Right-box.Right;
  else
    if FReturning[false] then (if FHomeKnown[false] then FHome.X else ARect.Left)-box.Left else 0
  end;
  var dy := match FVerticalAlign of
    cvCenter: (ARect.Top+ARect.Bottom-box.Top-box.Bottom) div 2;
    cvBottom: ARect.Bottom-box.Bottom;
  else
    if FReturning[true] then (if FHomeKnown[true] then FHome.Y else ARect.Top)-box.Top else 0
  end;
  FLeaving[false] := false;
  FLeaving[true] := false;
  FReturning[false] := false;
  FReturning[true] := false;
  if (dx = 0) and (dy = 0) then exit;
  FArranging := true;
  DisableAlign;
  try
    for var i := 0 to ControlCount-1 do
      if free(Controls[i]) then with Controls[i] do SetBounds(Left+dx, Top+dy, Width, Height);
  finally
    EnableAlign;
    FArranging := false;
  end;
end;

procedure TContentPanel.Paint;
begin
  var back := if Parent <> nil then Parent.GetRGBColorResolvingParent else GetRGBColorResolvingParent;
  var fill := if FTransparent then back else GetRGBColorResolvingParent;
  var radius := scaled(self, FCornerRadius);
  var border := if FBorderWidth > 0 then pick(FBorderColor, blend(clBtnFace, clBtnShadow, 50)) else clNone;
  if (radius = 0) and (border = clNone) then begin
    Canvas.Brush.Color := fill;
    Canvas.FillRect(ClientRect);
  end else begin
    var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
    paintRoundRect(sp, ClientRect, radius, fill, border, Math.Max(scaled(self, FBorderWidth), 1));
    sp.Flush;
  end;
  if Caption <> '' then begin
    Canvas.Font := Font;
    paintCenteredText(Canvas, ClientRect, Caption, if Enabled then ColorToRGB(clBtnText) else ColorToRGB(clGrayText));
  end;
  if Assigned(OnPaint) then OnPaint(self);
end;

procedure TContentPanel.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

// -- properties ----------------------

procedure TContentPanel.setHorizontalAlign(value: TContentHorizontalAlign);
begin
  if FHorizontalAlign = value then exit;
  // a form being loaded holds the children where the choice already put them
  if not (csLoading in ComponentState) then begin
    // back before the layout ran: the group never left
    if (value = chLeft) and FLeaving[false] then FLeaving[false] := false
    else begin
      FLeaving[false] := FLeaving[false] or (FHorizontalAlign = chLeft);
      FReturning[false] := value = chLeft;
    end;
  end;
  FHorizontalAlign := value;
  ReAlign;
end;

procedure TContentPanel.setVerticalAlign(value: TContentVerticalAlign);
begin
  if FVerticalAlign = value then exit;
  if not (csLoading in ComponentState) then begin
    if (value = cvTop) and FLeaving[true] then FLeaving[true] := false
    else begin
      FLeaving[true] := FLeaving[true] or (FVerticalAlign = cvTop);
      FReturning[true] := value = cvTop;
    end;
  end;
  FVerticalAlign := value;
  ReAlign;
end;

function TContentPanel.getMetric(index: integer): integer;
begin
  match index of
    0: result := FPadding;
    1: result := FCornerRadius;
    _: result := FBorderWidth;
  end;
end;

procedure TContentPanel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FPadding := value;
    1: FCornerRadius := value;
    _: FBorderWidth := value;
  end;
  ReAlign;
  Invalidate;
end;

procedure TContentPanel.setBorderColor(value: TColor);
begin
  if FBorderColor = value then exit;
  FBorderColor := value;
  Invalidate;
end;

procedure TContentPanel.setTransparent(value: boolean);
begin
  if FTransparent = value then exit;
  FTransparent := value;
  Invalidate;
end;

procedure TContentPanel.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
