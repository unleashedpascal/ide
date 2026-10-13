{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit CardPanel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  // the look of the card: with a shadow, a frame only, a flat tint without a
  // frame, or a frame with an accent strip along the top
  TCardStyle = (cpCard, cpOutline, cpFlat, cpAccent);
  { TCardPanel }

  // a container drawn as a card: rounded, framed, with a soft shadow and a
  // header strip carrying the caption. The children sit inside the padding
  TCardPanel = class(TCustomControl)
  private
    FShowHeader, FShadow: boolean;
    FHeaderHeight, FCornerRadius, FPadding, FShadowSize, FBorderWidth: integer;
    FHeaderAlignment: TAlignment;
    FCardColor, FHeaderColor, FBorderColor, FTitleColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FStyle: TCardStyle;
    function headerPx: integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setHeaderAlignment(value: TAlignment);
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setStyle(value: TCardStyle);
  protected
    procedure Paint; override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption;
    property ShowHeader: boolean index 0 read getFlag write setFlag default true;
    property Shadow: boolean index 1 read getFlag write setFlag default true;
    // 0 takes it from the font
    property HeaderHeight: integer index 0 read getMetric write setMetric default 0;
    property CornerRadius: integer index 1 read getMetric write setMetric default 6;
    // between the frame and the children
    property Padding: integer index 2 read getMetric write setMetric default 8;
    property ShadowSize: integer index 3 read getMetric write setMetric default 4;
    property BorderWidth: integer index 4 read getMetric write setMetric default 1;
    property HeaderAlignment: TAlignment read FHeaderAlignment write setHeaderAlignment default taLeftJustify;
    // clDefault takes the colors of the theme
    property CardColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property HeaderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Style: TCardStyle read FStyle write setStyle default cpCard;
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
    property OnResize;
    property OnUnDock;
  end;

implementation

uses
  Math;

constructor TCardPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csSetCaption, csOpaque, csNoFocus];
  TabStop := false;
  FShowHeader := true;
  FShadow := true;
  FCornerRadius := 6;
  FPadding := 8;
  FShadowSize := 4;
  FBorderWidth := 1;
  FCardColor := clDefault;
  FHeaderColor := clDefault;
  FBorderColor := clDefault;
  FTitleColor := clDefault;
  FAntialiasing := asTheme;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TCardPanel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 160;
end;

function TCardPanel.headerPx: integer;
begin
  if not FShowHeader then exit(0);
  result := if FHeaderHeight > 0 then scaled(self, FHeaderHeight) else lineHeightOf(Font)+scaled(self, 14);
end;

procedure TCardPanel.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  var inset := scaled(self, FBorderWidth)+scaled(self, FPadding);
  var shadow := if FShadow then scaled(self, FShadowSize) else 0;
  ARect := Rect(ARect.Left+inset, ARect.Top+inset+headerPx, ARect.Right-inset-shadow, ARect.Bottom-inset-shadow);
end;

procedure TCardPanel.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var card := pick(FCardColor, blend(clWindow, clBtnFace, 30));
  var border := pick(FBorderColor, blend(clBtnFace, clBtnShadow, 50));
  var header := pick(FHeaderColor, blend(card, clWindowText, 5));
  var title := pick(FTitleColor, clWindowText);
  var radius := scaled(self, FCornerRadius);
  var shadow := if FShadow and (FStyle = cpCard) then scaled(self, FShadowSize) else 0;
  if FStyle = cpFlat then begin
    card := blend(back, clWindowText, 7);
    border := clNone;
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  var body := Rect(0, 0, ClientWidth-shadow, ClientHeight-shadow);
  // the shadow: rings of the card shape fading out behind it
  for var i := shadow downto 1 do begin
    var r := body;
    OffsetRect(r, i div 2+1, i div 2+1);
    r.Inflate(i div 2, i div 2);
    paintRoundRect(sp, r, radius+i div 2, blend(back, clBlack, 18-i*16 div Max(shadow, 1)), clNone);
  end;
  paintRoundRect(sp, body, radius, card, clNone);
  var h := headerPx;
  if h > 0 then begin
    // the header keeps the rounded top and a flat bottom
    paintRoundRect(sp, Rect(body.Left, body.Top, body.Right, Min(body.Top+h+radius, body.Bottom)), radius, header, clNone);
    if body.Top+h < body.Bottom then paintRoundRect(sp, Rect(body.Left, body.Top+h, body.Right, Min(body.Top+h+radius, body.Bottom)), 0, card, clNone);
    paintLine(sp, body.Left, body.Top+h, body.Right, body.Top+h, border, 1);
  end;
  if FStyle = cpAccent then begin
    // the strip keeps the rounded top and a flat bottom
    var strip := Max(scaled(self, 4), 3);
    paintRoundRect(sp, Rect(body.Left, body.Top, body.Right, body.Top+strip+radius), radius, ColorToRGB(clHighlight), clNone);
    paintRoundRect(sp, Rect(body.Left, body.Top+strip, body.Right, body.Top+strip+radius), 0, (if h > 0 then header else card), clNone);
  end;
  if border <> clNone then paintRoundRect(sp, body, radius, clNone, border, Max(FBorderWidth, 1));
  sp.Flush;
  if (h > 0) and (Caption <> '') then begin
    applyTextQuality(Canvas);
    Canvas.Font.Style := Font.Style+[fsBold];
    var pad := scaled(self, FPadding)+scaled(self, 4);
    var box := Rect(body.Left+pad, body.Top, body.Right-pad, body.Top+h);
    var style := Canvas.TextStyle;
    style.Alignment := FHeaderAlignment;
    style.Layout := tlCenter;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    style.EndEllipsis := true;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := if Enabled then title else ColorToRGB(clGrayText);
    Canvas.TextRect(box, box.Left, box.Top, Caption, style);
    Canvas.Brush.Style := bsSolid;
    Canvas.Font.Style := Font.Style;
  end;
end;

procedure TCardPanel.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TCardPanel.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  ReAlign;
  Invalidate;
end;

// -- properties ----------------------

function TCardPanel.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FShowHeader else FShadow;
end;

procedure TCardPanel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FShowHeader := value else FShadow := value;
  ReAlign;
  Invalidate;
end;

function TCardPanel.getMetric(index: integer): integer;
begin
  result := match index of
    0: FHeaderHeight;
    1: FCornerRadius;
    2: FPadding;
    3: FShadowSize;
  else
    FBorderWidth
  end;
end;

procedure TCardPanel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FHeaderHeight := value;
    1: FCornerRadius := value;
    2: FPadding := value;
    3: FShadowSize := value;
  else
    FBorderWidth := value;
  end;
  ReAlign;
  Invalidate;
end;

function TCardPanel.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FCardColor;
    1: FHeaderColor;
    2: FBorderColor;
  else
    FTitleColor
  end;
end;

procedure TCardPanel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FCardColor := value;
    1: FHeaderColor := value;
    2: FBorderColor := value;
  else
    FTitleColor := value;
  end;
  Invalidate;
end;

procedure TCardPanel.setHeaderAlignment(value: TAlignment);
begin
  if FHeaderAlignment = value then exit;
  FHeaderAlignment := value;
  Invalidate;
end;

procedure TCardPanel.setStyle(value: TCardStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TCardPanel.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
