{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Divider;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  TDividerOrientation = (doHorizontal, doVertical);
  // where the caption sits on the line; for a vertical line start is the top
  TDividerCaptionPosition = (dpStart, dpCenter, dpEnd);
  // the line: solid, dashed, dotted, dash-dot, two thin lines, fading out at
  // both ends
  TDividerLineStyle = (dlSolid, dlDashed, dlDotted, dlDashDot, dlDouble, dlGradient);

  { TDivider }

  // a line separating two parts of a form, with an optional caption set
  // into it
  TDivider = class(TGraphicControl)
  private
    FOrientation: TDividerOrientation;
    FCaptionPosition: TDividerCaptionPosition;
    FLineStyle: TDividerLineStyle;
    FLineWidth, FSpacingBefore, FSpacingAfter, FMargin, FCaptionOffset: integer;
    FLineColor, FTextColor: TColor;
    FTransparent: boolean;
    procedure setOrientation(value: TDividerOrientation);
    procedure setCaptionPosition(value: TDividerCaptionPosition);
    procedure setLineStyle(value: TDividerLineStyle);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setTransparent(value: boolean);
  protected
    procedure Paint; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption;
    property Orientation: TDividerOrientation read FOrientation write setOrientation default doHorizontal;
    property CaptionPosition: TDividerCaptionPosition read FCaptionPosition write setCaptionPosition default dpStart;
    property LineStyle: TDividerLineStyle read FLineStyle write setLineStyle default dlSolid;
    // the thickness of the line
    property LineWidth: integer index 0 read getMetric write setMetric default 1;
    // between the line and the caption, before it (left, or above on a
    // vertical line) and after it
    property SpacingBefore: integer index 1 read getMetric write setMetric default 8;
    property SpacingAfter: integer index 3 read getMetric write setMetric default 8;
    // from the edges of the control to the start of the line
    property Margin: integer index 2 read getMetric write setMetric default 0;
    // the line before a caption at the start, or after one at the end;
    // 0 starts the caption right at the margin
    property CaptionOffset: integer index 4 read getMetric write setMetric default 0;
    // clDefault takes the colors of the theme
    property LineColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property Transparent: boolean read FTransparent write setTransparent default true;
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

constructor TDivider.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption]-[csOpaque];
  FLineWidth := 1;
  FSpacingBefore := 8;
  FSpacingAfter := 8;
  FLineColor := clDefault;
  FTextColor := clDefault;
  FTransparent := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TDivider.GetControlClassDefaultSize: TSize;
begin
  result.cx := 160;
  result.cy := 17;
end;

procedure TDivider.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var thick := Max(scaled(self, FLineWidth), 1);
  var textH := if Caption = '' then 0 else Canvas.TextHeight('Hg');
  if FOrientation = doHorizontal then begin
    PreferredWidth := 0;
    PreferredHeight := Max(thick, textH)+2;
  end else begin
    PreferredWidth := Max(thick, textH)+2;
    PreferredHeight := 0;
  end;
end;

procedure TDivider.Paint;
begin
  var line := pick(FLineColor, blend(clBtnFace, clBtnShadow, 60));
  var text := pick(FTextColor, clGrayText);
  if not Enabled then text := blend(text, clBtnFace, 40);
  if not FTransparent then begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := GetRGBColorResolvingParent;
    Canvas.FillRect(ClientRect);
  end;
  Canvas.Pen.Color := line;
  Canvas.Pen.Width := Max(scaled(self, FLineWidth), 1);
  Canvas.Pen.Style := match FLineStyle of
    dlDashed: psDash;
    dlDotted: psDot;
    dlDashDot: psDashDot;
  else
    psSolid
  end;
  Canvas.Pen.EndCap := pecFlat;
  var back := GetRGBColorResolvingParent;
  // one stretch of the line after the style: two thin lines side by side,
  // or a line fading into the background at both ends
  var stretch := procedure(x1, y1, x2, y2: integer)
  begin
    match FLineStyle of
      dlDouble: begin
        var w := Max(scaled(self, FLineWidth), 1);
        Canvas.Pen.Width := 1;
        if y1 = y2 then begin
          Canvas.Line(x1, y1-w, x2, y1-w);
          Canvas.Line(x1, y1+w, x2, y1+w);
        end else begin
          Canvas.Line(x1-w, y1, x1-w, y2);
          Canvas.Line(x1+w, y1, x1+w, y2);
        end;
      end;
      dlGradient: begin
        var steps := Max((Abs(x2-x1)+Abs(y2-y1)) div 6, 1);
        for var i := 0 to steps-1 do begin
          // full color in the middle, the background at the ends
          var share := 1-Abs((i+0.5)/steps*2-1);
          Canvas.Pen.Color := blend(back, line, Round(share*100));
          Canvas.Line(x1+(x2-x1)*i div steps, y1+(y2-y1)*i div steps, x1+(x2-x1)*(i+1) div steps, y1+(y2-y1)*(i+1) div steps);
        end;
        Canvas.Pen.Color := line;
      end;
    else
      Canvas.Line(x1, y1, x2, y2);
    end;
  end;
  var margin := scaled(self, FMargin);
  var before := scaled(self, FSpacingBefore);
  var after := scaled(self, FSpacingAfter);
  var offset := scaled(self, FCaptionOffset);
  var horizontal := FOrientation = doHorizontal;
  var length := (if horizontal then ClientWidth else ClientHeight)-margin*2;
  var mid := (if horizontal then ClientHeight else ClientWidth) div 2;
  var textSize: TSize;
  textSize.cx := 0;
  textSize.cy := 0;
  if Caption <> '' then begin
    applyTextQuality(Canvas);
    textSize := Canvas.TextExtent(Caption);
  end;
  // the caption takes its span out of the line; a vertical line keeps the
  // text upright, so the span is its height
  var span := if horizontal then textSize.cx else textSize.cy;
  var textStart := match FCaptionPosition of
    dpStart: margin+(if offset > 0 then offset+before else 0);
    dpEnd: margin+length-span-(if offset > 0 then offset+after else 0);
  else
    margin+(length-span) div 2
  end;
  if Caption = '' then begin
    if horizontal then stretch(margin, mid, margin+length, mid) else stretch(mid, margin, mid, margin+length);
  end else begin
    var first := textStart-before;
    var second := textStart+span+after;
    if horizontal then begin
      if first > margin then stretch(margin, mid, first, mid);
      if second < margin+length then stretch(second, mid, margin+length, mid);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := text;
      Canvas.TextOut(textStart, (ClientHeight-textSize.cy) div 2, Caption);
    end else begin
      if first > margin then stretch(mid, margin, mid, first);
      if second < margin+length then stretch(mid, second, mid, margin+length);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := text;
      Canvas.TextOut((ClientWidth-textSize.cx) div 2, textStart, Caption);
    end;
  end;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsSolid;
end;

procedure TDivider.TextChanged;
begin
  inherited TextChanged;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TDivider.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

procedure TDivider.setOrientation(value: TDividerOrientation);
begin
  if FOrientation = value then exit;
  FOrientation := value;
  // the control turns with the line
  if not (csLoading in ComponentState) then SetBounds(Left, Top, Height, Width);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TDivider.setCaptionPosition(value: TDividerCaptionPosition);
begin
  if FCaptionPosition = value then exit;
  FCaptionPosition := value;
  Invalidate;
end;

procedure TDivider.setLineStyle(value: TDividerLineStyle);
begin
  if FLineStyle = value then exit;
  FLineStyle := value;
  Invalidate;
end;

function TDivider.getMetric(index: integer): integer;
begin
  result := match index of
    0: FLineWidth;
    1: FSpacingBefore;
    2: FMargin;
    3: FSpacingAfter;
  else
    FCaptionOffset
  end;
end;

procedure TDivider.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FLineWidth := value;
    1: FSpacingBefore := value;
    2: FMargin := value;
    3: FSpacingAfter := value;
  else
    FCaptionOffset := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDivider.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FLineColor else FTextColor;
end;

procedure TDivider.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FLineColor := value else FTextColor := value;
  Invalidate;
end;

procedure TDivider.setTransparent(value: boolean);
begin
  if FTransparent = value then exit;
  FTransparent := value;
  Invalidate;
end;

end.
