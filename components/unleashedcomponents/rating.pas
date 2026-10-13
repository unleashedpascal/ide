{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Rating;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  // the outline of an item: a star, a circle, a heart, a diamond, a square, a
  // triangle, a hexagon, a thumb up, a smiley, bars climbing in height, a
  // circle with a check mark
  TRatingShape = (rsStar, rsCircle, rsHeart, rsDiamond, rsSquare, rsTriangle, rsHexagon, rsThumb, rsSmiley, rsBar, rsCheck);
  TRatingChangeEvent = procedure(Sender: TObject; value: double) of object;
  // paints one item in place of the control: `share` is the filled part of
  // it, 0 to 1; dsHover while the mouse previews a value, dsChecked for a
  // filled item; `handled` left false paints the stock shape
  TRatingDrawEvent = procedure(Sender: TObject; canvas: TCanvas; const r: TRect; index: integer; share: double; state: TDrawState; var handled: boolean) of object;

  { TRating }

  // a row of stars to rate with: the mouse picks a star, or half of one, the
  // arrow keys step the value. Hovering previews the pick
  TRating = class(TCustomControl)
  private
    FMax: integer;
    FValue: double;
    FHover: double; // the value under the mouse, -1 off
    FAllowHalf, FReadOnly, FAllowClear, FShowValue: boolean;
    FShape: TRatingShape;
    FItemSize, FSpacing, FBorderWidth: integer;
    FActiveColor, FInactiveColor, FHoverColor, FBorderColor, FTextColor: TColor;
    FValueFormat: string;
    FLabels: TStrings;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FOnChange: TRatingChangeEvent;
    FOnDrawItem: TRatingDrawEvent;
    procedure setMax(value: integer);
    procedure setValue(value: double);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setShape(value: TRatingShape);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    function itemPx: integer;
    function itemRect(index: integer): TRect;
    function valueAt(x, y: integer): double;
    procedure paintItem(sp: TSmoothPaint; const r: TRect; fill, border: TColor; share: double; index: integer);
    function valueStored: boolean;
    procedure setValueFormat(const value: string);
    procedure setLabels(value: TStrings);
    function valueText(v: double): string;
    function textWidthPx: integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Max: integer read FMax write setMax default 5;
    // the rating; with AllowHalf in steps of 0.5
    property Value: double read FValue write setValue stored valueStored;
    property AllowHalf: boolean index 0 read getFlag write setFlag default true;
    property ReadOnly: boolean index 1 read getFlag write setFlag default false;
    // a click on the current value clears the rating
    property AllowClear: boolean index 2 read getFlag write setFlag default true;
    // the value as text after the stars, after ValueFormat
    property ShowValue: boolean index 3 read getFlag write setFlag default false;
    // a Format pattern with the value and the maximum, like "%.1f / %d"
    property ValueFormat: string read FValueFormat write setValueFormat;
    // one line per star: its hint, and the text ShowValue prefers over the number
    property Labels: TStrings read FLabels write setLabels;
    property Shape: TRatingShape read FShape write setShape default rsStar;
    property ItemSize: integer index 0 read getMetric write setMetric default 20;
    property Spacing: integer index 1 read getMetric write setMetric default 4;
    // an outline around every star; 0 for none
    property BorderWidth: integer index 2 read getMetric write setMetric default 0;
    // clDefault: gold stars, red hearts, circles in the highlight of the theme
    property ActiveColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    // clDefault takes the color of the theme
    property InactiveColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // the preview under the mouse; clDefault pales the active color
    property HoverColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    // the outline; clDefault darkens the active color
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnChange: TRatingChangeEvent read FOnChange write FOnChange;
    // paints every item by itself; see TRatingDrawEvent
    property OnDrawItem: TRatingDrawEvent read FOnDrawItem write FOnDrawItem;
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
    property OnResize;
  end;

implementation

uses
  Math;

constructor TRating.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FMax := 5;
  FHover := -1;
  FAllowHalf := true;
  FAllowClear := true;
  FShape := rsStar;
  FItemSize := 20;
  FSpacing := 4;
  FActiveColor := clDefault;
  FInactiveColor := clDefault;
  FHoverColor := clDefault;
  FBorderColor := clDefault;
  FTextColor := clDefault;
  FValueFormat := '%.1f';
  FLabels := TStringList.Create;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TRating.Destroy;
begin
  FLabels.Free;
  inherited Destroy;
end;

// the text for a value: the label of the star when there is one, else the number
function TRating.valueText(v: double): string;
begin
  var star := Round(v+0.49);
  if (star >= 1) and (star <= FLabels.Count) and (FLabels[star-1] <> '') then exit(FLabels[star-1]);
  result := Format(FValueFormat, [v, FMax], formatSettingsOf(FLanguage));
end;

// the room the widest value text can take
function TRating.textWidthPx: integer;
begin
  if not FShowValue then exit(0);
  result := Canvas.TextWidth(valueText(FMax));
  for var i := 0 to FLabels.Count-1 do result := Math.Max(result, Canvas.TextWidth(FLabels[i]));
  result += scaled(self, 8);
end;

class function TRating.GetControlClassDefaultSize: TSize;
begin
  result.cx := 116;
  result.cy := 20;
end;

function TRating.valueStored: boolean;
begin
  result := FValue <> 0;
end;

// -- geometry ----------------------

function TRating.itemPx: integer;
begin
  result := scaled(self, FItemSize);
end;

function TRating.itemRect(index: integer): TRect;
begin
  var size := itemPx;
  var gap := scaled(self, FSpacing);
  var top := (ClientHeight-size) div 2;
  result := Rect(index*(size+gap), top, index*(size+gap)+size, top+size);
end;

function TRating.valueAt(x, y: integer): double;
begin
  result := 0;
  var size := itemPx;
  var gap := scaled(self, FSpacing);
  if x < 0 then exit;
  var slot := x div (size+gap);
  var inside := x-slot*(size+gap);
  if slot >= FMax then exit(FMax);
  if inside > size then exit(slot+1);
  result := slot+1;
  if FAllowHalf and (inside < size div 2) then result := slot+0.5;
end;

procedure TRating.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var size := itemPx;
  PreferredWidth := FMax*size+Math.Max(FMax-1, 0)*scaled(self, FSpacing)+textWidthPx;
  PreferredHeight := Math.Max(size, (if FShowValue then Canvas.TextHeight('Hg') else 0));
end;

// -- painting ----------------------

// a star, a circle or a heart in `r`; `share` of its width filled, the rest
// in the inactive color
procedure TRating.paintItem(sp: TSmoothPaint; const r: TRect; fill, border: TColor; share: double; index: integer);

  procedure poly(const pts: array of TPointF; color, outline: TColor);
  begin
    sp.FillPolygon(pts, color);
    if outline <> clNone then sp.StrokePolyline(pts, 1, outline, true);
  end;

  procedure shape(const box: TRect; color, outline: TColor);
  const
    // a thumb up over a cuff, in parts of the box
    THUMB: array[0..11] of TPointF = ((x: 0.26; y: 0.48), (x: 0.42; y: 0.48), (x: 0.5; y: 0.1), (x: 0.62; y: 0.1), (x: 0.66; y: 0.22), (x: 0.58; y: 0.48), (x: 0.9; y: 0.48), (x: 0.94; y: 0.6), (x: 0.86; y: 0.92), (x: 0.26; y: 0.92), (x: 0.26; y: 0.92), (x: 0.26; y: 0.48));
  begin
    var cx := (box.Left+box.Right)/2;
    var cy := (box.Top+box.Bottom)/2;
    var rad := box.Width/2;
    match FShape of
      rsCircle: paintCircle(sp, Round(cx), Round(cy), Round(rad*0.9), color, outline);
      rsDiamond: poly(polygonOutline(cx, cy, rad, 4, 90), color, outline);
      rsSquare: paintRoundRect(sp, Rect(Round(cx-rad*0.85), Round(cy-rad*0.85), Round(cx+rad*0.85), Round(cy+rad*0.85)), Round(rad*0.2), color, outline);
      rsTriangle: poly(polygonOutline(cx, cy+rad*0.1, rad, 3, 90), color, outline);
      rsHexagon: poly(polygonOutline(cx, cy, rad, 6, 30), color, outline);
      rsThumb: begin
        var pts: array of TPointF := [];
        for var p in THUMB do pts += [PointF(box.Left+p.x*box.Width, box.Top+p.y*box.Height)];
        poly(pts, color, outline);
        sp.FillRectF(box.Left+box.Width*0.06, box.Top+box.Height*0.5, box.Left+box.Width*0.22, box.Top+box.Height*0.92, color);
      end;
      rsSmiley: begin
        paintCircle(sp, Round(cx), Round(cy), Round(rad*0.92), color, outline);
        var face := blend(color, clBlack, 55);
        sp.FillEllipse(cx-rad*0.33, cy-rad*0.25, rad*0.12, rad*0.14, face);
        sp.FillEllipse(cx+rad*0.33, cy-rad*0.25, rad*0.12, rad*0.14, face);
        sp.StrokeArc(cx, cy+rad*0.05, rad*0.5, rad*0.45, 200, 140, Math.Max(rad*0.11, 1.0), face, true);
      end;
      rsBar: begin
        // the bars climb from the first to the last
        var h := box.Height*(0.35+0.65*(index+1)/Math.Max(FMax, 1));
        sp.FillRoundRect(cx-rad*0.6, box.Bottom-h, cx+rad*0.6, box.Bottom, rad*0.15, color);
        if outline <> clNone then sp.FrameRoundRect(cx-rad*0.6, box.Bottom-h, cx+rad*0.6, box.Bottom, rad*0.15, 1, outline);
      end;
      rsCheck: begin
        paintCircle(sp, Round(cx), Round(cy), Round(rad*0.92), color, outline);
        paintCheck(sp, box, Round(rad*1.1), contrastText(color), Math.Max(Round(rad*0.2), 1));
      end;
      rsHeart: begin
        // two lobes over a point
        var pts: array of TPointF;
        SetLength(pts, 0);
        for var i := 0 to 40 do begin
          var t := -pi+i/40*2*pi;
          var hx := 16*power(sin(t), 3);
          var hy := 13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t);
          var p := PointF(cx+hx*rad/17, cy-hy*rad/17+rad*0.05);
          SetLength(pts, length(pts)+1);
          pts[high(pts)] := p;
        end;
        sp.FillPolygon(pts, color);
        if outline <> clNone then sp.StrokePolyline(pts, 1, outline, true);
      end;
    else
      begin
        var pts: array[10] of TPointF;
        for var i := 0 to 9 do begin
          var a := -pi/2+i*pi/5;
          var d := if i mod 2 = 0 then rad else rad*0.42;
          pts[i] := PointF(cx+cos(a)*d, cy+sin(a)*d);
        end;
        sp.FillPolygon(pts, color);
        if outline <> clNone then sp.StrokePolyline(pts, 1, outline, true);
      end;
    end;
  end;

begin
  var inactive := pick(FInactiveColor, blend(clBtnFace, clBtnShadow, 60));
  // the check keeps its mark readable on the dim fill
  if FShape = rsCheck then inactive := blend(inactive, clBtnFace, 30);
  shape(r, inactive, clNone);
  if share <= 0 then exit;
  if share >= 1 then begin
    shape(r, fill, border);
    exit;
  end;
  // the filled part shows through a clip on the left share of the box
  sp.SetClip(Rect(r.Left, r.Top, r.Left+Round(r.Width*share), r.Bottom));
  shape(r, fill, border);
  sp.ResetClip;
end;

procedure TRating.Paint;
begin
  var natural := match FShape of
    rsStar, rsSmiley: RGBToColor(255, 193, 7);
    rsHeart: RGBToColor(229, 57, 53);
    rsThumb: RGBToColor(33, 150, 243);
    rsCheck: RGBToColor(67, 160, 71);
  else
    clHighlight
  end;
  var active := pick(FActiveColor, natural);
  var hoverFill := pick(FHoverColor, blend(active, clWhite, 40));
  if not Enabled then active := blend(active, clBtnFace, 50);
  var outline := if FBorderWidth > 0 then pick(FBorderColor, blend(active, clBlack, 30)) else clNone;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var shown := FValue;
  var fill := active;
  if Enabled and hoverEnabled and (FHover >= 0) and not FReadOnly then begin
    shown := FHover;
    fill := hoverFill;
  end;
  var custom := Assigned(FOnDrawItem);
  if not custom then
    for var i := 0 to FMax-1 do paintItem(sp, itemRect(i), fill, outline, EnsureRange(shown-i, 0, 1), i);
  sp.Flush;
  if custom then
    // every item goes to the handler over the painted background; an item
    // it leaves alone is painted the stock way in its own box
    for var i := 0 to FMax-1 do begin
      var r := itemRect(i);
      var share := EnsureRange(shown-i, 0, 1);
      var state: TDrawState := [];
      if shown = FHover then state += [dsHover];
      if share > 0 then state += [dsChecked];
      if not Enabled then state += [dsDisabled];
      if Focused then state += [dsFocused];
      var handled := false;
      FOnDrawItem(self, Canvas, r, i, share, state, handled);
      if not handled then begin
        var own := autofree beginShapes(Canvas, r, GetRGBColorResolvingParent, FAntialiasing);
        paintItem(own, r, fill, outline, share, i);
        own.Flush;
      end;
    end;
  if FShowValue then begin
    applyTextQuality(Canvas);
    var size := itemPx;
    var left := FMax*size+Math.Max(FMax-1, 0)*scaled(self, FSpacing)+scaled(self, 8);
    paintCenteredText(Canvas, Rect(left, 0, ClientWidth, ClientHeight), valueText(shown), pick(FTextColor, (if Enabled then clWindowText else clGrayText)));
  end;
end;

// -- input ----------------------

procedure TRating.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FReadOnly then exit;
  var v := valueAt(X, Y);
  if v <> FHover then begin
    FHover := v;
    // the label of the star under the mouse comes up as the hint
    var star := Round(v+0.49);
    if (star >= 1) and (star <= FLabels.Count) then Hint := FLabels[star-1];
    Invalidate;
  end;
end;

procedure TRating.MouseLeave;
begin
  inherited MouseLeave;
  if FHover >= 0 then begin
    FHover := -1;
    Invalidate;
  end;
end;

procedure TRating.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  if FReadOnly then exit;
  var v := valueAt(X, Y);
  if FAllowClear and (v = FValue) then v := 0;
  setValue(v);
end;

procedure TRating.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FReadOnly then exit;
  var step: double := if FAllowHalf then 0.5 else 1;
  match Key of
    VK_LEFT, VK_DOWN: setValue(FValue-step);
    VK_RIGHT, VK_UP: setValue(FValue+step);
    VK_HOME: setValue(0);
    VK_END: setValue(FMax);
    VK_DELETE, VK_BACK: setValue(0);
  else
    exit;
  end;
  Key := 0;
end;

// -- properties ----------------------

procedure TRating.setMax(value: integer);
begin
  if value < 1 then value := 1;
  if FMax = value then exit;
  FMax := value;
  if FValue > FMax then FValue := FMax;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRating.setValue(value: double);
begin
  value := EnsureRange(value, 0, FMax);
  value := if FAllowHalf then Round(value*2)/2 else Round(value);
  if FValue = value then exit;
  FValue := value;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self, FValue);
end;

function TRating.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FAllowHalf;
    1: result := FReadOnly;
    2: result := FAllowClear;
    _: result := FShowValue;
  end;
end;

procedure TRating.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAllowHalf := value;
    1: FReadOnly := value;
    2: FAllowClear := value;
    _: FShowValue := value;
  end;
  if (index = 0) and not value then FValue := Round(FValue);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRating.setShape(value: TRatingShape);
begin
  if FShape = value then exit;
  FShape := value;
  Invalidate;
end;

function TRating.getMetric(index: integer): integer;
begin
  result := match index of
    0: FItemSize;
    1: FSpacing;
  else
    FBorderWidth
  end;
end;

procedure TRating.setValueFormat(const value: string);
begin
  if FValueFormat = value then exit;
  FValueFormat := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRating.setLabels(value: TStrings);
begin
  FLabels.Assign(value);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRating.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FItemSize := Math.Max(value, 6);
    1: FSpacing := value;
  else
    FBorderWidth := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TRating.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FActiveColor;
    1: FInactiveColor;
    2: FHoverColor;
    3: FBorderColor;
  else
    FTextColor
  end;
end;

procedure TRating.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FActiveColor := value;
    1: FInactiveColor := value;
    2: FHoverColor := value;
    3: FBorderColor := value;
  else
    FTextColor := value;
  end;
  Invalidate;
end;

procedure TRating.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TRating.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
