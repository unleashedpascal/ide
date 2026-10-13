{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit InfoBar;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  TInfoSeverity = (isInfo, isSuccess, isWarning, isError);
  // the look of the bar: a tint of the severity, a frame only, the severity
  // color as the fill, or a strip of it along the left edge
  TInfoBarStyle = (ibTinted, ibOutline, ibSolid, ibStrip);
  TInfoBarCloseEvent = procedure(Sender: TObject; var canClose: boolean) of object;

  { TInfoBar }

  // a message that stays in the form, unlike a toast: a tinted bar with the
  // icon of its severity, a bold title, the text wrapped under it, a button
  // that does something about it and a close button. Show opens it, the
  // close button hides it
  TInfoBar = class(TCustomControl)
  private
    FTitle, FMessage, FActionCaption: string;
    FSeverity: TInfoSeverity;
    FClosable, FShowIcon: boolean;
    FCornerRadius, FPadding: integer;
    FColors: array[TInfoSeverity] of TColor;
    FHot: integer; // 1 the action, 2 the close button
    FPressed: integer;
    FAntialiasing: TAntialiasSetting;
    FStyle: TInfoBarStyle;
    FOnAction: TNotifyEvent;
    FOnClose: TInfoBarCloseEvent;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setSeverity(value: TInfoSeverity);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setSeverityColor(index: integer; value: TColor);
    function getSeverityColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setStyle(value: TInfoBarStyle);
    function severityColor: TColor;
    function iconSize: integer;
    procedure layout(width: integer; out lines: TStringArray; out textLeft, textRight, actionW, height: integer);
    function actionRect: TRect;
    function closeRect: TRect;
    function wrap(const text: string; width: integer): TStringArray;
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
    procedure DoOnResize; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // sets the message and shows the bar
    procedure Notify(const title, message: string; severity: TInfoSeverity = isInfo);
    // hides the bar the way its close button does, OnClose included
    function CloseBar: boolean;
  published
    property Title: string index 0 read getText write setText;
    property Message: string index 1 read getText write setText;
    // the button; empty shows none
    property ActionCaption: string index 2 read getText write setText;
    property Severity: TInfoSeverity read FSeverity write setSeverity default isInfo;
    property Closable: boolean index 0 read getFlag write setFlag default true;
    property ShowIcon: boolean index 1 read getFlag write setFlag default true;
    property CornerRadius: integer index 0 read getMetric write setMetric default 6;
    property Padding: integer index 1 read getMetric write setMetric default 10;
    // clDefault takes colors that suit the background
    property InfoColor: TColor index 0 read getSeverityColor write setSeverityColor default clDefault;
    property SuccessColor: TColor index 1 read getSeverityColor write setSeverityColor default clDefault;
    property WarningColor: TColor index 2 read getSeverityColor write setSeverityColor default clDefault;
    property ErrorColor: TColor index 3 read getSeverityColor write setSeverityColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Style: TInfoBarStyle read FStyle write setStyle default ibTinted;
    property OnAction: TNotifyEvent read FOnAction write FOnAction;
    // before the bar hides; canClose false keeps it
    property OnClose: TInfoBarCloseEvent read FOnClose write FOnClose;
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

constructor TInfoBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FTitle := 'Heads up';
  FMessage := 'Something you should know about.';
  FClosable := true;
  FShowIcon := true;
  FCornerRadius := 6;
  FPadding := 10;
  for var s := low(TInfoSeverity) to high(TInfoSeverity) do FColors[s] := clDefault;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TInfoBar.GetControlClassDefaultSize: TSize;
begin
  result.cx := 360;
  result.cy := 56;
end;

procedure TInfoBar.Notify(const title, message: string; severity: TInfoSeverity);
begin
  FTitle := title;
  FMessage := message;
  FSeverity := severity;
  changed;
  Visible := true;
end;

function TInfoBar.CloseBar: boolean;
begin
  var allow := true;
  if Assigned(FOnClose) then FOnClose(self, allow);
  if allow then Visible := false;
  result := allow;
end;

function TInfoBar.severityColor: TColor;
begin
  var back := GetRGBColorResolvingParent;
  var dark := isDark(back);
  result := pick(FColors[FSeverity], match FSeverity of
    isSuccess: if dark then RGBToColor(102, 187, 106) else RGBToColor(46, 125, 50);
    isWarning: if dark then RGBToColor(255, 183, 77) else RGBToColor(191, 120, 0);
    isError: if dark then RGBToColor(239, 83, 80) else RGBToColor(198, 40, 40);
  else
    ColorToRGB(clHighlight)
  end);
end;

function TInfoBar.iconSize: integer;
begin
  Canvas.Font := Font;
  result := Canvas.TextHeight('Hg')+scaled(self, 2);
end;

// -- layout ----------------------

function TInfoBar.wrap(const text: string; width: integer): TStringArray;
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

// the text column between the icon and the buttons, its lines and the
// height of the whole bar for a width
procedure TInfoBar.layout(width: integer; out lines: TStringArray; out textLeft, textRight, actionW, height: integer);
begin
  var pad := scaled(self, FPadding);
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  textLeft := pad+(if FShowIcon then iconSize+scaled(self, 10) else 0);
  actionW := if FActionCaption <> '' then Canvas.TextWidth(FActionCaption)+scaled(self, 24) else 0;
  textRight := width-pad-(if FClosable then scaled(self, 24) else 0)-(if actionW > 0 then actionW+scaled(self, 8) else 0);
  lines := if FMessage <> '' then wrap(FMessage, Max(textRight-textLeft, 20)) else [];
  var rows := length(lines)+(if FTitle <> '' then 1 else 0);
  height := Max(rows*th, Max(iconSize, th+scaled(self, 10)))+2*pad;
end;

function TInfoBar.actionRect: TRect;
begin
  var lines: TStringArray;
  var textLeft, textRight, actionW, h: integer;
  layout(ClientWidth, lines, textLeft, textRight, actionW, h);
  if actionW = 0 then exit(Rect(0, 0, 0, 0));
  Canvas.Font := Font;
  var bh := Canvas.TextHeight('Hg')+scaled(self, 10);
  var right := ClientWidth-scaled(self, FPadding)-(if FClosable then scaled(self, 24) else 0);
  var top := scaled(self, FPadding)+Max((Min(ClientHeight-2*scaled(self, FPadding), bh*2)-bh) div 2, 0);
  result := Rect(right-actionW, top, right, top+bh);
end;

function TInfoBar.closeRect: TRect;
begin
  if not FClosable then exit(Rect(0, 0, 0, 0));
  var size := scaled(self, 20);
  var pad := scaled(self, FPadding);
  result := Rect(ClientWidth-pad-size, pad, ClientWidth-pad, pad+size);
end;

procedure TInfoBar.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var lines: TStringArray;
  var textLeft, textRight, actionW, h: integer;
  layout(Max(Width, scaled(self, 120)), lines, textLeft, textRight, actionW, h);
  PreferredWidth := 0;
  PreferredHeight := h;
end;

// -- painting ----------------------

procedure TInfoBar.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var accent := severityColor;
  if not Enabled then accent := blend(accent, back, 55);
  var fill := match FStyle of
    ibOutline: back;
    ibSolid: accent;
    ibStrip: blend(back, accent, 8);
  else
    blend(back, accent, 14)
  end;
  var frame := match FStyle of
    ibSolid, ibStrip: clNone;
  else
    blend(back, accent, 45)
  end;
  var text := if FStyle = ibSolid then contrastText(accent) else ColorToRGB(clWindowText);
  // the icon keeps its contrast on a solid bar by swapping its colors
  var iconFill := if FStyle = ibSolid then contrastText(accent) else accent;
  var glyph := if FStyle = ibSolid then accent else contrastText(accent);
  var lines: TStringArray;
  var textLeft, textRight, actionW, h: integer;
  layout(ClientWidth, lines, textLeft, textRight, actionW, h);
  var pad := scaled(self, FPadding);
  var radius := scaled(self, FCornerRadius);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  paintRoundRect(sp, ClientRect, radius, fill, frame);
  if FStyle = ibStrip then paintRoundRect(sp, Rect(0, 0, Max(scaled(self, 4), 3), ClientHeight), 0, iconFill, clNone);
  if FShowIcon then begin
    var s := iconSize;
    var box := Rect(pad, pad, pad+s, pad+s);
    var cx := pad+s div 2;
    var cy := pad+s div 2;
    var lw := Max(s div 9, 2);
    match FSeverity of
      isWarning: begin
        sp.FillPolygon([PointF(cx, box.Top), PointF(box.Right, box.Bottom-1), PointF(box.Left, box.Bottom-1)], iconFill);
        paintLine(sp, cx, box.Top+s*35 div 100, cx, box.Top+s*62 div 100, glyph, lw);
        paintCircle(sp, cx, box.Top+s*78 div 100, Max(lw*2 div 3, 1), glyph, clNone);
      end;
      isSuccess: begin
        paintCircle(sp, cx, cy, s div 2, iconFill, clNone);
        paintCheck(sp, box, s*55 div 100, glyph, lw);
      end;
      isError: begin
        paintCircle(sp, cx, cy, s div 2, iconFill, clNone);
        paintCross(sp, box, s*40 div 100, glyph, lw);
      end;
    else
      begin
        paintCircle(sp, cx, cy, s div 2, iconFill, clNone);
        paintLine(sp, cx, cy-s div 20, cx, cy+s*25 div 100, glyph, lw);
        paintCircle(sp, cx, cy-s*24 div 100, Max(lw*2 div 3, 1), glyph, clNone);
      end;
    end;
  end;
  var a := actionRect;
  if a.Width > 0 then begin
    var buttonFill := if (FPressed = 1) and hoverEnabled then blend(back, accent, 40) else if (FHot = 1) and hoverEnabled then blend(back, accent, 30) else blend(back, accent, 22);
    paintRoundRect(sp, a, scaled(self, 4), buttonFill, (if Focused and ringEnabled then ringColor else blend(back, accent, 55)));
  end;
  var c := closeRect;
  if c.Width > 0 then begin
    if (FHot = 2) and hoverEnabled then paintRoundRect(sp, c, scaled(self, 4), blend(fill, text, 12), clNone);
    paintCross(sp, c, scaled(self, 9), blend(fill, text, 70), Max(scaled(self, 1), 1));
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlTop;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  Canvas.Brush.Style := bsClear;
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  var y := pad+Max((iconSize-th) div 2, 0);
  if FTitle <> '' then begin
    Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.Font.Color := if Enabled then text else ColorToRGB(clGrayText);
    var r := Rect(textLeft, y, textRight, y+th);
    Canvas.TextRect(r, r.Left, r.Top, FTitle, style);
    y += th;
    Canvas.Font.Style := Font.Style;
  end;
  Canvas.Font.Color := if Enabled then blend(fill, text, 85) else ColorToRGB(clGrayText);
  for var line in lines do begin
    var r := Rect(textLeft, y, textRight, y+th);
    Canvas.TextRect(r, r.Left, r.Top, line, style);
    y += th;
  end;
  if a.Width > 0 then paintCenteredText(Canvas, a, FActionCaption, text);
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TInfoBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  var p := Point(X, Y);
  FPressed := if actionRect.Contains(p) then 1 else if closeRect.Contains(p) then 2 else 0;
  if FPressed <> 0 then Invalidate;
end;

procedure TInfoBar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var p := Point(X, Y);
  var hot := if actionRect.Contains(p) then 1 else if closeRect.Contains(p) then 2 else 0;
  if hot <> FHot then begin
    FHot := hot;
    Cursor := if hot <> 0 then crHandPoint else crDefault;
    Invalidate;
  end;
end;

procedure TInfoBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  var pressed := FPressed;
  FPressed := 0;
  if pressed = 0 then exit;
  Invalidate;
  if pressed <> FHot then exit;
  if pressed = 1 then begin
    if Assigned(FOnAction) then FOnAction(self);
  end else CloseBar;
end;

procedure TInfoBar.MouseLeave;
begin
  inherited MouseLeave;
  if (FHot <> 0) or (FPressed <> 0) then begin
    FHot := 0;
    FPressed := 0;
    Cursor := crDefault;
    Invalidate;
  end;
end;

procedure TInfoBar.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_RETURN, VK_SPACE: if (FActionCaption <> '') and Assigned(FOnAction) then FOnAction(self) else exit;
    VK_ESCAPE: if FClosable then CloseBar else exit;
  else
    exit;
  end;
  Key := 0;
end;

procedure TInfoBar.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TInfoBar.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// the wrap depends on the width, so a new width asks for a new height
procedure TInfoBar.DoOnResize;
begin
  inherited DoOnResize;
  if AutoSize and HandleAllocated then begin
    var lines: TStringArray;
    var textLeft, textRight, actionW, h: integer;
    layout(ClientWidth, lines, textLeft, textRight, actionW, h);
    if h <> Height then begin
      InvalidatePreferredSize;
      AdjustSize;
    end;
  end;
  Invalidate;
end;

procedure TInfoBar.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  changed;
end;

// -- properties ----------------------

procedure TInfoBar.changed;
begin
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TInfoBar.getText(index: integer): string;
begin
  result := match index of
    0: FTitle;
    1: FMessage;
  else
    FActionCaption
  end;
end;

procedure TInfoBar.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FTitle := value;
    1: FMessage := value;
  else
    FActionCaption := value;
  end;
  changed;
end;

procedure TInfoBar.setSeverity(value: TInfoSeverity);
begin
  if FSeverity = value then exit;
  FSeverity := value;
  Invalidate;
end;

function TInfoBar.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FClosable else FShowIcon;
end;

procedure TInfoBar.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FClosable := value else FShowIcon := value;
  changed;
end;

function TInfoBar.getMetric(index: integer): integer;
begin
  result := if index = 0 then FCornerRadius else FPadding;
end;

procedure TInfoBar.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FCornerRadius := value else FPadding := value;
  changed;
end;

function TInfoBar.getSeverityColor(index: integer): TColor;
begin
  result := FColors[TInfoSeverity(index)];
end;

procedure TInfoBar.setSeverityColor(index: integer; value: TColor);
begin
  if FColors[TInfoSeverity(index)] = value then exit;
  FColors[TInfoSeverity(index)] := value;
  Invalidate;
end;

procedure TInfoBar.setStyle(value: TInfoBarStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TInfoBar.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
