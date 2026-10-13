{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Badge;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  // the corner of the attached control the badge sits on
  TBadgePosition = (bpTopRight, bpTopLeft, bpBottomRight, bpBottomLeft, bpRightCenter, bpLeftCenter);
  // the outline: a pill, a circle, a square with small rounding, a box rounded
  // by a third of its height, a tag pointed on the left, a diamond
  TBadgeShape = (bsPill, bsCircle, bsSquare, bsRounded, bsTag, bsDiamond);

  { TBadge }

  // a small counter or dot pinned to a corner of another control: Value
  // shows as a number up to Max, then as "Max+"; Dot shows a plain mark.
  // AttachTo keeps the badge on the control as it moves. A window of its
  // own, cut to its shape, so it sits on top of the native controls too
  TBadge = class(TCustomControl)
  private
    FAttachTo: TControl;
    FPosition: TBadgePosition;
    FShape: TBadgeShape;
    FValue, FMax, FOffsetX, FOffsetY, FMinSize, FPadding: integer;
    FText: string;
    FDot, FShowZero: boolean;
    FBadgeColor, FTextColor, FBorderColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnDraw: TCustomDrawEvent;
    procedure setAttachTo(value: TControl);
    procedure setPosition(value: TBadgePosition);
    procedure setShape(value: TBadgeShape);
    procedure setInt(index: integer; value: integer);
    function getInt(index: integer): integer;
    procedure setText(const value: string);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function caption: string;
    procedure attachedMoved(Sender: TObject);
    procedure refit;
    procedure applyShape;
  protected
    procedure Paint; override;
    procedure DoOnResize; override;
    procedure CreateWnd; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // puts the badge back on its corner of the attached control
    procedure Reposition;
  published
    // the control the badge sits on; nil leaves it where it is
    property AttachTo: TControl read FAttachTo write setAttachTo;
    property Position: TBadgePosition read FPosition write setPosition default bpTopRight;
    property Shape: TBadgeShape read FShape write setShape default bsPill;
    property Value: integer index 0 read getInt write setInt default 0;
    // values past this show as "Max+"
    property Max: integer index 1 read getInt write setInt default 99;
    // moves the badge from its corner, in pixels
    property OffsetX: integer index 2 read getInt write setInt default 0;
    property OffsetY: integer index 3 read getInt write setInt default 0;
    // the height, and the width of a dot
    property MinSize: integer index 4 read getInt write setInt default 18;
    property Padding: integer index 5 read getInt write setInt default 5;
    // replaces the number
    property Text: string read FText write setText;
    // a plain mark without a number
    property Dot: boolean index 0 read getFlag write setFlag default false;
    // a zero shows; off, the badge hides at zero
    property ShowZero: boolean index 1 read getFlag write setFlag default false;
    // clDefault takes the colors of the theme
    property BadgeColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // the outline, usually the color behind the badge; clNone for none
    property BorderColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints the badge by itself, text included
    property OnDraw: TCustomDrawEvent read FOnDraw write FOnDraw;
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

constructor TBadge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csNoFocus]-[csOpaque, csSetCaption];
  TabStop := false;
  FPosition := bpTopRight;
  FShape := bsPill;
  FMax := 99;
  FMinSize := 18;
  FPadding := 5;
  FBadgeColor := clDefault;
  FTextColor := clDefault;
  FBorderColor := clDefault;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TBadge.Destroy;
begin
  if FAttachTo <> nil then FAttachTo.RemoveHandlerOnChangeBounds(@attachedMoved);
  inherited Destroy;
end;

class function TBadge.GetControlClassDefaultSize: TSize;
begin
  result.cx := 24;
  result.cy := 18;
end;

procedure TBadge.Loaded;
begin
  inherited Loaded;
  Reposition;
end;

function TBadge.caption: string;
begin
  if FDot then exit('');
  if FText <> '' then exit(FText);
  result := if FValue > FMax then IntToStr(FMax)+'+' else IntToStr(FValue);
end;

procedure TBadge.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  // measured with the quality the text is painted in
  applyTextQuality(Canvas);
  var h := scaled(self, FMinSize);
  if FDot then begin
    PreferredWidth := h;
    PreferredHeight := h;
    exit;
  end;
  var text := caption;
  var w := if text = '' then 0 else Canvas.TextWidth(text);
  h := Math.Max(h, Canvas.TextHeight('0')+scaled(self, 4));
  PreferredHeight := h;
  PreferredWidth := Math.Max(w+scaled(self, FPadding)*2, h);
  if FShape = bsCircle then PreferredWidth := Math.Max(PreferredWidth, h);
end;

// -- placement ----------------------

procedure TBadge.Reposition;
begin
  if (FAttachTo = nil) or (Parent = nil) or (csLoading in ComponentState) then exit;
  // the attached control may sit on another parent, so its box comes
  // through the screen
  var box := FAttachTo.BoundsRect;
  if FAttachTo.Parent <> Parent then begin
    if FAttachTo.Parent = nil then exit;
    var tl := Parent.ScreenToClient(FAttachTo.Parent.ClientToScreen(box.TopLeft));
    box := Rect(tl.X, tl.Y, tl.X+box.Width, tl.Y+box.Height);
  end;
  var w := Width;
  var h := Height;
  var x, y: integer;
  match FPosition of
    bpTopRight: begin x := box.Right-w div 2; y := box.Top-h div 2; end;
    bpTopLeft: begin x := box.Left-w div 2; y := box.Top-h div 2; end;
    bpBottomRight: begin x := box.Right-w div 2; y := box.Bottom-h div 2; end;
    bpBottomLeft: begin x := box.Left-w div 2; y := box.Bottom-h div 2; end;
    bpRightCenter: begin x := box.Right-w div 2; y := (box.Top+box.Bottom-h) div 2; end;
  else
    begin x := box.Left-w div 2; y := (box.Top+box.Bottom-h) div 2; end;
  end;
  SetBounds(x+scaled(self, FOffsetX), y+scaled(self, FOffsetY), w, h);
  BringToFront;
end;

// the window keeps only the pixels inside the shape
procedure TBadge.applyShape;
begin
  if not HandleAllocated or (Width <= 0) or (Height <= 0) then exit;
  var mask := autofree TBitmap.Create;
  mask.PixelFormat := pf24bit;
  mask.SetSize(Width, Height);
  mask.Canvas.Brush.Color := clBlack;
  mask.Canvas.FillRect(0, 0, Width, Height);
  mask.Canvas.Brush.Color := clWhite;
  mask.Canvas.Pen.Color := clWhite;
  match FShape of
    bsCircle: begin
      var d := Math.Min(Width, Height);
      mask.Canvas.Ellipse((Width-d) div 2, (Height-d) div 2, (Width-d) div 2+d, (Height-d) div 2+d);
    end;
    bsSquare: mask.Canvas.RoundRect(0, 0, Width, Height, scaled(self, 6), scaled(self, 6));
    bsRounded: mask.Canvas.RoundRect(0, 0, Width, Height, Height*2 div 3, Height*2 div 3);
    bsTag: begin
      var tip := Round(Height*0.4);
      mask.Canvas.Polygon([Point(tip, 0), Point(Width, 0), Point(Width, Height), Point(tip, Height), Point(0, Height div 2)]);
    end;
    bsDiamond: mask.Canvas.Polygon([Point(Width div 2, 0), Point(Width, Height div 2), Point(Width div 2, Height), Point(0, Height div 2)]);
  else
    begin
      var d := Math.Min(Width, Height);
      mask.Canvas.RoundRect(0, 0, Width, Height, d, d);
    end;
  end;
  // the property setter of the shape shadows the window method
  inherited SetShape(mask);
end;

procedure TBadge.DoOnResize;
begin
  inherited DoOnResize;
  applyShape;
end;

procedure TBadge.CreateWnd;
begin
  inherited CreateWnd;
  applyShape;
end;

procedure TBadge.attachedMoved(Sender: TObject);
begin
  Reposition;
end;

procedure TBadge.refit;
begin
  InvalidatePreferredSize;
  AdjustSize;
  Reposition;
  Invalidate;
end;

// -- painting ----------------------

procedure TBadge.Paint;
begin
  if not FDot and (FText = '') and (FValue = 0) and not FShowZero then exit;
  var fill := pick(FBadgeColor, clHighlight);
  var textColor := pick(FTextColor, contrastText(fill));
  var border := if FBorderColor = clNone then clNone else pick(FBorderColor, GetRGBColorResolvingParent);
  if not Enabled then fill := blend(fill, clBtnFace, 50);
  var r := ClientRect;
  if customDraw(self, Canvas, FOnDraw, r, 0, (if Enabled then [] else [dsDisabled]), GetRGBColorResolvingParent, FAntialiasing) then exit;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  match FShape of
    bsCircle: begin
      var d := Math.Min(r.Width, r.Height);
      paintCircle(sp, r.Left+r.Width div 2, r.Top+r.Height div 2, d div 2, fill, border);
    end;
    bsSquare: paintRoundRect(sp, r, scaled(self, 3), fill, border);
    bsRounded: paintRoundRect(sp, r, r.Height div 3, fill, border);
    // a tag: a point on the left, the rest a rounded box
    bsTag: begin
      var tip := r.Height*0.4;
      var pts: array of TPointF := [PointF(r.Left+tip, r.Top), PointF(r.Right, r.Top), PointF(r.Right, r.Bottom), PointF(r.Left+tip, r.Bottom), PointF(r.Left, (r.Top+r.Bottom)/2)];
      sp.FillPolygon(pts, fill);
      if border <> clNone then sp.StrokePolyline(pts, 1, border, true);
    end;
    bsDiamond: begin
      var pts: array of TPointF := [PointF((r.Left+r.Right)/2, r.Top), PointF(r.Right, (r.Top+r.Bottom)/2), PointF((r.Left+r.Right)/2, r.Bottom), PointF(r.Left, (r.Top+r.Bottom)/2)];
      sp.FillPolygon(pts, fill);
      if border <> clNone then sp.StrokePolyline(pts, 1, border, true);
    end;
  else
    paintPill(sp, r, fill, border);
  end;
  sp.Flush;
  var text := caption;
  if text <> '' then paintCenteredText(Canvas, r, text, textColor);
end;

procedure TBadge.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FAttachTo) then FAttachTo := nil;
end;

procedure TBadge.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  refit;
end;

// -- properties ----------------------

procedure TBadge.setAttachTo(value: TControl);
begin
  if FAttachTo = value then exit;
  if value = self then exit;
  if FAttachTo <> nil then begin
    FAttachTo.RemoveHandlerOnChangeBounds(@attachedMoved);
    FAttachTo.RemoveFreeNotification(self);
  end;
  FAttachTo := value;
  if FAttachTo <> nil then begin
    FAttachTo.FreeNotification(self);
    FAttachTo.AddHandlerOnChangeBounds(@attachedMoved);
  end;
  Reposition;
end;

procedure TBadge.setPosition(value: TBadgePosition);
begin
  if FPosition = value then exit;
  FPosition := value;
  Reposition;
end;

procedure TBadge.setShape(value: TBadgeShape);
begin
  if FShape = value then exit;
  FShape := value;
  applyShape;
  refit;
end;

function TBadge.getInt(index: integer): integer;
begin
  match index of
    0: result := FValue;
    1: result := FMax;
    2: result := FOffsetX;
    3: result := FOffsetY;
    4: result := FMinSize;
    _: result := FPadding;
  end;
end;

procedure TBadge.setInt(index: integer; value: integer);
begin
  if (index in [4, 5]) and (value < 0) then value := 0;
  if getInt(index) = value then exit;
  match index of
    0: FValue := value;
    1: FMax := value;
    2: FOffsetX := value;
    3: FOffsetY := value;
    4: FMinSize := value;
    _: FPadding := value;
  end;
  refit;
end;

procedure TBadge.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  refit;
end;

function TBadge.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FDot else FShowZero;
end;

procedure TBadge.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FDot := value else FShowZero := value;
  refit;
end;

function TBadge.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FBadgeColor;
    1: result := FTextColor;
    _: result := FBorderColor;
  end;
end;

procedure TBadge.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBadgeColor := value;
    1: FTextColor := value;
    _: FBorderColor := value;
  end;
  Invalidate;
end;

procedure TBadge.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
