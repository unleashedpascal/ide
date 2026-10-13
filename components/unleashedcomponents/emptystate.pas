{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit EmptyState;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ImgList, LCLType, ControlPaint;

type
  TEmptyStateGlyph = (egNone, egInbox, egSearch, egFolder, egDocument, egCloud, egCheck, egWarning, egImage);

  { TEmptyState }

  // what a list or a view shows while it has nothing: a picture in a soft
  // circle, a title, a line or two of text and a button that does something
  // about it. Everything sits in the middle of the control
  TEmptyState = class(TCustomControl)
  private
    FTitle, FDescription, FActionCaption: string;
    FGlyph: TEmptyStateGlyph;
    FGlyphSize, FSpacing, FMaxTextWidth, FPadding: integer;
    FTitleColor, FTextColor, FGlyphColor, FButtonColor: TColor;
    FImages: TCustomImageList;
    FImageIndex: TImageIndex;
    FImagesWidth: integer;
    FHot, FPressed: boolean;
    FAntialiasing: TAntialiasSetting;
    FOnAction: TNotifyEvent;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setGlyph(value: TEmptyStateGlyph);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setImages(value: TCustomImageList);
    procedure setImageIndex(value: TImageIndex);
    procedure setAntialiasing(value: TAntialiasSetting);
    function hasImage: boolean;
    function glyphPx: integer;
    procedure titleFont(target: TFont);
    function wrapped(const text: string; width: integer): TStringArray;
    procedure layout(out glyphBox, titleBox, textBox, buttonBox: TRect; out lines: TStringArray);
    procedure paintGlyph(sp: TSmoothPaint; const box: TRect; color: TColor);
    procedure changed;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure DoOnResize; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // what a click on the button does, OnAction included
    procedure Action;
  published
    property Title: string index 0 read getText write setText;
    // wraps at MaxTextWidth; line breaks in it stay
    property Description: string index 1 read getText write setText;
    // the button; empty shows none
    property ActionCaption: string index 2 read getText write setText;
    property Glyph: TEmptyStateGlyph read FGlyph write setGlyph default egInbox;
    // a picture of the list instead of the glyph
    property Images: TCustomImageList read FImages write setImages;
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    property ImagesWidth: integer index 4 read getMetric write setMetric default 0;
    // the circle around the glyph
    property GlyphSize: integer index 0 read getMetric write setMetric default 72;
    property Spacing: integer index 1 read getMetric write setMetric default 12;
    property MaxTextWidth: integer index 2 read getMetric write setMetric default 320;
    property Padding: integer index 3 read getMetric write setMetric default 16;
    // clDefault takes the colors of the theme
    property TitleColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property GlyphColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property ButtonColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // a click on the button, Enter or Space
    property OnAction: TNotifyEvent read FOnAction write FOnAction;
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
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEnter;
    property OnExit;
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

constructor TEmptyState.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FTitle := 'Nothing here yet';
  FDescription := 'Items you add show up here.';
  FGlyph := egInbox;
  FGlyphSize := 72;
  FSpacing := 12;
  FMaxTextWidth := 320;
  FPadding := 16;
  FImageIndex := -1;
  FTitleColor := clDefault;
  FTextColor := clDefault;
  FGlyphColor := clDefault;
  FButtonColor := clDefault;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TEmptyState.GetControlClassDefaultSize: TSize;
begin
  result.cx := 360;
  result.cy := 260;
end;

procedure TEmptyState.Action;
begin
  if Assigned(FOnAction) then FOnAction(self);
end;

function TEmptyState.hasImage: boolean;
begin
  result := (FImages <> nil) and (FImageIndex >= 0) and (FImageIndex < FImages.Count);
end;

function TEmptyState.glyphPx: integer;
begin
  result := if (FGlyph = egNone) and not hasImage then 0 else scaled(self, FGlyphSize);
end;

procedure TEmptyState.titleFont(target: TFont);
begin
  target.Assign(Font);
  target.Style := Font.Style+[fsBold];
  target.Height := -Round(Abs(Canvas.TextHeight('Hg'))*1.35);
end;

// the words of `text` in lines no wider than `width`; a word wider than
// the width gets a line of its own
function TEmptyState.wrapped(const text: string; width: integer): TStringArray;
begin
  result := [];
  for var paragraph in text.Replace(#13#10, #10).Split([#10]) do begin
    var line := '';
    for var word in paragraph.Split([' '], TStringSplitOptions.ExcludeEmpty) do begin
      var next := if line = '' then word else line+' '+word;
      if (line <> '') and (Canvas.TextWidth(next) > width) then begin
        result += [line];
        line := word;
      end else line := next;
    end;
    result += [line];
  end;
end;

procedure TEmptyState.layout(out glyphBox, titleBox, textBox, buttonBox: TRect; out lines: TStringArray);
begin
  var pad := scaled(self, FPadding);
  var gap := scaled(self, FSpacing);
  var room := Max(Min(scaled(self, FMaxTextWidth), ClientWidth-2*pad), 20);
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  lines := if FDescription = '' then [] else wrapped(FDescription, room);
  var textW := 0;
  for var s in lines do textW := Max(textW, Canvas.TextWidth(s));
  var big := autofree TFont.Create;
  titleFont(big);
  Canvas.Font := big;
  var titleH := if FTitle = '' then 0 else Canvas.TextHeight('Hg');
  var titleW := Min(Canvas.TextWidth(FTitle), room);
  Canvas.Font := Font;
  var buttonW := if FActionCaption = '' then 0 else Canvas.TextWidth(FActionCaption)+scaled(self, 32);
  var buttonH := if FActionCaption = '' then 0 else th+scaled(self, 14);
  var g := glyphPx;
  // the parts stacked with a gap between the ones that show
  var heights: array of integer := [];
  if g > 0 then heights += [g];
  if titleH > 0 then heights += [titleH];
  if length(lines) > 0 then heights += [length(lines)*th];
  if buttonH > 0 then heights += [buttonH];
  var total := 0;
  for var h in heights do total += h;
  total += Max(length(heights)-1, 0)*gap;
  var y := Max((ClientHeight-total) div 2, pad);
  var cx := ClientWidth div 2;
  glyphBox := Rect(cx-g div 2, y, cx-g div 2+g, y+g);
  if g > 0 then y += g+gap;
  titleBox := Rect(cx-titleW div 2, y, cx-titleW div 2+titleW, y+titleH);
  if titleH > 0 then y += titleH+(if length(lines) > 0 then gap div 2 else gap);
  textBox := Rect(cx-textW div 2, y, cx-textW div 2+textW, y+length(lines)*th);
  if length(lines) > 0 then y += length(lines)*th+gap;
  buttonBox := Rect(cx-buttonW div 2, y, cx-buttonW div 2+buttonW, y+buttonH);
end;

procedure TEmptyState.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var pad := scaled(self, FPadding);
  var gap := scaled(self, FSpacing);
  var room := scaled(self, FMaxTextWidth);
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  var lines := if FDescription = '' then [] else wrapped(FDescription, room);
  var w := glyphPx;
  for var s in lines do w := Max(w, Canvas.TextWidth(s));
  if FActionCaption <> '' then w := Max(w, Canvas.TextWidth(FActionCaption)+scaled(self, 32));
  var big := autofree TFont.Create;
  titleFont(big);
  Canvas.Font := big;
  w := Max(w, Min(Canvas.TextWidth(FTitle), room));
  var h := glyphPx+(if FTitle <> '' then Canvas.TextHeight('Hg')+gap else 0);
  Canvas.Font := Font;
  h += length(lines)*th+(if FActionCaption <> '' then th+scaled(self, 14)+gap else 0)+gap;
  PreferredWidth := w+2*pad;
  PreferredHeight := h+2*pad;
end;

// -- painting ----------------------

procedure TEmptyState.paintGlyph(sp: TSmoothPaint; const box: TRect; color: TColor);
begin
  var s := box.Width;
  var lw := Max(s div 14, 1);
  var px := function(f: double): integer
  begin
    result := box.Left+Round(s*f);
  end;
  var py := function(f: double): integer
  begin
    result := box.Top+Round(s*f);
  end;
  var line := procedure(x1, y1, x2, y2: double)
  begin
    paintLine(sp, px(x1), py(y1), px(x2), py(y2), color, lw);
  end;
  var pt := function(fx, fy: double): TPointF
  begin
    result := PointF(px(fx), py(fy));
  end;
  match FGlyph of
    egInbox: begin
      // a tray with a slot in its front
      paintRoundRect(sp, Rect(px(0.12), py(0.30), px(0.88), py(0.78)), lw*2, clNone, color, lw);
      line(0.12, 0.56, 0.36, 0.56);
      line(0.36, 0.56, 0.42, 0.64);
      line(0.42, 0.64, 0.58, 0.64);
      line(0.58, 0.64, 0.64, 0.56);
      line(0.64, 0.56, 0.88, 0.56);
    end;
    egSearch: begin
      paintCircle(sp, px(0.44), py(0.44), Round(s*0.25), clNone, color, lw);
      paintLine(sp, px(0.62), py(0.62), px(0.84), py(0.84), color, lw+1);
    end;
    egFolder: begin
      sp.StrokePolyline([pt(0.12, 0.28), pt(0.40, 0.28), pt(0.48, 0.36), pt(0.88, 0.36), pt(0.88, 0.76), pt(0.12, 0.76)], lw, color, true);
      line(0.12, 0.44, 0.88, 0.44);
    end;
    egDocument: begin
      // a page with a folded corner and lines of text
      sp.StrokePolyline([pt(0.24, 0.14), pt(0.60, 0.14), pt(0.76, 0.30), pt(0.76, 0.86), pt(0.24, 0.86)], lw, color, true);
      line(0.60, 0.14, 0.60, 0.30);
      line(0.60, 0.30, 0.76, 0.30);
      for var k := 0 to 2 do line(0.34, 0.46+k*0.12, 0.66, 0.46+k*0.12);
    end;
    egCloud: begin
      var fill := color;
      paintCircle(sp, px(0.36), py(0.56), Round(s*0.16), fill, clNone);
      paintCircle(sp, px(0.54), py(0.46), Round(s*0.21), fill, clNone);
      paintCircle(sp, px(0.70), py(0.58), Round(s*0.14), fill, clNone);
      paintRoundRect(sp, Rect(px(0.22), py(0.56), px(0.84), py(0.72)), Round(s*0.08), fill, clNone);
    end;
    egCheck: begin
      paintCircle(sp, px(0.5), py(0.5), Round(s*0.34), clNone, color, lw);
      paintCheck(sp, Rect(px(0.28), py(0.28), px(0.72), py(0.72)), s*4 div 10, color, lw+1);
    end;
    egWarning: begin
      sp.StrokePolyline([pt(0.5, 0.16), pt(0.88, 0.82), pt(0.12, 0.82)], lw, color, true);
      line(0.5, 0.40, 0.5, 0.60);
      paintCircle(sp, px(0.5), py(0.70), Max(lw*2 div 3, 1), color, clNone);
    end;
    egImage: begin
      // a frame with hills and a sun
      paintRoundRect(sp, Rect(px(0.14), py(0.20), px(0.86), py(0.80)), lw*2, clNone, color, lw);
      line(0.20, 0.72, 0.42, 0.48);
      line(0.42, 0.48, 0.58, 0.64);
      line(0.54, 0.60, 0.66, 0.50);
      line(0.66, 0.50, 0.80, 0.66);
      paintCircle(sp, px(0.66), py(0.34), Max(Round(s*0.06), 2), color, clNone);
    end;
  else
    ;
  end;
end;

procedure TEmptyState.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var accent := pick(FGlyphColor, clHighlight);
  var titleColor := pick(FTitleColor, clWindowText);
  var textColor := pick(FTextColor, blend(back, clWindowText, 60));
  var buttonColor := pick(FButtonColor, clHighlight);
  if not Enabled then begin
    accent := blend(accent, back, 55);
    titleColor := ColorToRGB(clGrayText);
    textColor := titleColor;
    buttonColor := blend(buttonColor, back, 55);
  end;
  var glyphBox, titleBox, textBox, buttonBox: TRect;
  var lines: TStringArray;
  layout(glyphBox, titleBox, textBox, buttonBox, lines);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  if glyphBox.Width > 0 then begin
    paintCircle(sp, (glyphBox.Left+glyphBox.Right) div 2, (glyphBox.Top+glyphBox.Bottom) div 2, glyphBox.Width div 2, blend(back, accent, 14), clNone);
    if not hasImage then begin
      var inner := glyphBox;
      inner.Inflate(-glyphBox.Width div 5, -glyphBox.Width div 5);
      paintGlyph(sp, inner, accent);
    end;
  end;
  if buttonBox.Width > 0 then begin
    var fill := buttonColor;
    if FPressed and hoverEnabled then fill := blend(buttonColor, clBlack, 18)
    else if FHot and hoverEnabled then fill := blend(buttonColor, clWhite, 14);
    paintRoundRect(sp, buttonBox, buttonBox.Height div 2, fill, (if Focused and ringEnabled then ringColor else clNone));
  end;
  sp.Flush;

  if hasImage then begin
    var res := FImages.ResolutionForControl[FImagesWidth, self];
    res.Draw(Canvas, (glyphBox.Left+glyphBox.Right-res.Width) div 2, (glyphBox.Top+glyphBox.Bottom-res.Height) div 2, FImageIndex, Enabled);
  end;
  applyTextQuality(Canvas);
  var style := Canvas.TextStyle;
  style.Alignment := taCenter;
  style.Layout := tlTop;
  style.SingleLine := true;
  style.Clipping := false;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  Canvas.Brush.Style := bsClear;
  if FTitle <> '' then begin
    titleFont(Canvas.Font);
    Canvas.Font.Color := titleColor;
    var r := Rect(0, titleBox.Top, ClientWidth, titleBox.Bottom);
    r.Inflate(-scaled(self, FPadding), 0);
    style.Clipping := true;
    Canvas.TextRect(r, r.Left, r.Top, FTitle, style);
    style.Clipping := false;
  end;
  Canvas.Font := Font;
  Canvas.Font.Color := textColor;
  var th := Canvas.TextHeight('Hg');
  for var k := 0 to length(lines)-1 do begin
    var r := Rect(0, textBox.Top+k*th, ClientWidth, textBox.Top+(k+1)*th);
    Canvas.TextRect(r, r.Left, r.Top, lines[k], style);
  end;
  if buttonBox.Width > 0 then paintCenteredText(Canvas, buttonBox, FActionCaption, contrastText(buttonColor));
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TEmptyState.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FActionCaption = '') or not Enabled then exit;
  var glyphBox, titleBox, textBox, buttonBox: TRect;
  var lines: TStringArray;
  layout(glyphBox, titleBox, textBox, buttonBox, lines);
  if buttonBox.Contains(Point(X, Y)) then begin
    FPressed := true;
    if TabStop and CanSetFocus then SetFocus;
    Invalidate;
  end;
end;

procedure TEmptyState.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var glyphBox, titleBox, textBox, buttonBox: TRect;
  var lines: TStringArray;
  layout(glyphBox, titleBox, textBox, buttonBox, lines);
  var hot := (FActionCaption <> '') and buttonBox.Contains(Point(X, Y));
  if hot <> FHot then begin
    FHot := hot;
    Cursor := if hot then crHandPoint else crDefault;
    Invalidate;
  end;
end;

procedure TEmptyState.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not FPressed then exit;
  FPressed := false;
  Invalidate;
  if FHot then Action;
end;

procedure TEmptyState.MouseLeave;
begin
  inherited MouseLeave;
  if FHot or FPressed then begin
    FHot := false;
    FPressed := false;
    Cursor := crDefault;
    Invalidate;
  end;
end;

procedure TEmptyState.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key in [VK_RETURN, VK_SPACE]) and (FActionCaption <> '') and Enabled then begin
    Action;
    Key := 0;
  end;
end;

procedure TEmptyState.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TEmptyState.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TEmptyState.DoOnResize;
begin
  inherited DoOnResize;
  Invalidate;
end;

procedure TEmptyState.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  changed;
end;

procedure TEmptyState.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then begin
    FImages := nil;
    changed;
  end;
end;

// -- properties ----------------------

procedure TEmptyState.changed;
begin
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TEmptyState.getText(index: integer): string;
begin
  result := match index of
    0: FTitle;
    1: FDescription;
  else
    FActionCaption
  end;
end;

procedure TEmptyState.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FTitle := value;
    1: FDescription := value;
  else
    FActionCaption := value;
  end;
  changed;
end;

procedure TEmptyState.setGlyph(value: TEmptyStateGlyph);
begin
  if FGlyph = value then exit;
  FGlyph := value;
  changed;
end;

function TEmptyState.getMetric(index: integer): integer;
begin
  result := match index of
    0: FGlyphSize;
    1: FSpacing;
    2: FMaxTextWidth;
    3: FPadding;
  else
    FImagesWidth
  end;
end;

procedure TEmptyState.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FGlyphSize := value;
    1: FSpacing := value;
    2: FMaxTextWidth := Max(value, 40);
    3: FPadding := value;
  else
    FImagesWidth := value;
  end;
  changed;
end;

function TEmptyState.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FTitleColor;
    1: FTextColor;
    2: FGlyphColor;
  else
    FButtonColor
  end;
end;

procedure TEmptyState.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FTitleColor := value;
    1: FTextColor := value;
    2: FGlyphColor := value;
  else
    FButtonColor := value;
  end;
  Invalidate;
end;

procedure TEmptyState.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  changed;
end;

procedure TEmptyState.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  changed;
end;

procedure TEmptyState.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
