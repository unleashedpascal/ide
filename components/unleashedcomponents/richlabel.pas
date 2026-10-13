{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RichLabel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType;

type

  { TRichLabel }

  TLinkClickEvent = procedure(Sender: TObject; const href: string) of object;

  // a label with styled runs inside one caption: <b>, <i>, <u>, <s> for
  // bold, italic, underlined and struck text, <c=#RRGGBB> or <c=clRed>
  // for a color, <size=N> for a point size, <br> for a line break,
  // <a href="url"> for a link; &lt; &gt; &amp; stand for the characters
  TRichLabel = class(TGraphicControl)
  private
    type
      TRun = record
        text: string;
        bold, italic, underline, strike: boolean;
        color: TColor; // clDefault keeps the font color
        size: integer; // 0 keeps the font size
        href: string; // the link the run belongs to
        rect: TRect;
        line: integer;
      end;
    var
    FRuns: array of TRun;
    FWordWrap, FTransparent, FEndEllipsis, FOpenLinks: boolean;
    FAlignment: TAlignment;
    FLayout: TTextLayout;
    FLineSpacing: integer;
    FTextColor, FLinkColor, FHoverLinkColor: TColor;
    FHotLink: string;
    FOnLinkClick: TLinkClickEvent;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    function linkAt(x, y: integer): string;
    procedure setWordWrap(value: boolean);
    procedure setTransparent(value: boolean);
    procedure setAlignment(value: TAlignment);
    procedure setLayout(value: TTextLayout);
    procedure setLineSpacing(value: integer);
    procedure parse;
    procedure applyFont(const run: TRun);
    function measure(width: integer; out lines: integer): integer;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the caption without its tags
    function PlainText: string;
  published
    property Caption;
    property WordWrap: boolean read FWordWrap write setWordWrap default false;
    property Transparent: boolean read FTransparent write setTransparent default true;
    property Alignment: TAlignment read FAlignment write setAlignment default taLeftJustify;
    property Layout: TTextLayout read FLayout write setLayout default tlTop;
    // extra pixels between lines
    property LineSpacing: integer read FLineSpacing write setLineSpacing default 0;
    // a caption that does not fit ends in an ellipsis instead of being cut
    property EndEllipsis: boolean index 0 read getFlag write setFlag default false;
    // a click on a link opens it in the browser, before OnLinkClick
    property OpenLinks: boolean index 1 read getFlag write setFlag default true;
    // clDefault takes the font color, or the text color of the theme
    property TextColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property LinkColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property HoverLinkColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property OnLinkClick: TLinkClickEvent read FOnLinkClick write FOnLinkClick;
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
  Math, LCLIntf, ControlPaint;

constructor TRichLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption, csReplicatable]-[csOpaque];
  FTransparent := true;
  FOpenLinks := true;
  FLayout := tlTop;
  FTextColor := clDefault;
  FLinkColor := clDefault;
  FHoverLinkColor := clDefault;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TRichLabel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 17;
end;

// -- markup ----------------------

procedure TRichLabel.parse;
var
  s, text, href: string;
  bold, italic, underline, strike: boolean;
  color: TColor;
  size, i, n: integer;

  procedure addRun(const piece: string);
  begin
    SetLength(FRuns, length(FRuns)+1);
    FRuns[high(FRuns)].text := piece;
    FRuns[high(FRuns)].bold := bold;
    FRuns[high(FRuns)].italic := italic;
    FRuns[high(FRuns)].underline := underline;
    FRuns[high(FRuns)].strike := strike;
    FRuns[high(FRuns)].color := color;
    FRuns[high(FRuns)].size := size;
    FRuns[high(FRuns)].href := href;
  end;

  // plain text splits at spaces so a wrapped line can break between words
  procedure flush;
  begin
    if text = '' then exit;
    var start := 1;
    for var k := 1 to length(text) do if (text[k] = ' ') or (k = length(text)) then begin
      addRun(Copy(text, start, k-start+1));
      start := k+1;
    end;
    text := '';
  end;

  function colorOf(const spec: string): TColor;
  begin
    result := clDefault;
    var v := Trim(spec);
    if v = '' then exit;
    if v[1] = '#' then begin
      var n: longint;
      if TryStrToInt('$'+Copy(v, 2, MaxInt), n) then result := RGBToColor((n shr 16) and $FF, (n shr 8) and $FF, n and $FF);
    end else if not IdentToColor(v, longint(result)) then result := clDefault;
  end;

begin
  FRuns := nil;
  s := Caption;
  text := '';
  bold := false;
  italic := false;
  underline := false;
  strike := false;
  color := clDefault;
  size := 0;
  href := '';
  i := 1;
  n := length(s);
  while i <= n do begin
    if s[i] = '<' then begin
      var close := Pos('>', s, i);
      if close = 0 then break;
      var tag := LowerCase(Copy(s, i+1, close-i-1));
      flush;
      if tag = 'b' then bold := true
      else if tag = '/b' then bold := false
      else if tag = 'i' then italic := true
      else if tag = '/i' then italic := false
      else if tag = 'u' then underline := true
      else if tag = '/u' then underline := false
      else if tag = 's' then strike := true
      else if tag = '/s' then strike := false
      else if Copy(tag, 1, 2) = 'c=' then color := colorOf(Copy(tag, 3, MaxInt))
      else if tag = '/c' then color := clDefault
      else if Copy(tag, 1, 5) = 'size=' then size := StrToIntDef(Trim(Copy(tag, 6, MaxInt)), 0)
      else if tag = '/size' then size := 0
      else if tag = 'br' then addRun(#10)
      else if Copy(tag, 1, 2) = 'a ' then begin
        // the address between the quotes, or whatever follows href=
        var raw := Copy(s, i+1, close-i-1);
        var at := Pos('href=', LowerCase(raw));
        href := if at > 0 then Trim(Copy(raw, at+5, MaxInt)) else '';
        if (href <> '') and (href[1] in ['"', '''']) then href := Copy(href, 2, length(href)-2);
      end else if tag = '/a' then href := '';
      i := close+1;
    end else begin
      if s[i] = '&' then begin
        if Copy(s, i, 4) = '&lt;' then begin text += '<'; i += 4; continue; end;
        if Copy(s, i, 4) = '&gt;' then begin text += '>'; i += 4; continue; end;
        if Copy(s, i, 5) = '&amp;' then begin text += '&'; i += 5; continue; end;
      end;
      if s[i] = #10 then begin
        flush;
        addRun(#10);
        i += 1;
        continue;
      end;
      if s[i] <> #13 then text += s[i];
      i += 1;
    end;
  end;
  flush;
end;

function TRichLabel.PlainText: string;
begin
  if FRuns = nil then parse;
  result := '';
  for var i := 0 to high(FRuns) do result += FRuns[i].text;
end;

procedure TRichLabel.applyFont(const run: TRun);
begin
  Canvas.Font.Assign(Font);
  var style := Font.Style;
  if run.bold then Include(style, fsBold);
  if run.italic then Include(style, fsItalic);
  if run.underline then Include(style, fsUnderline);
  if run.strike then Include(style, fsStrikeOut);
  Canvas.Font.Style := style;
  if run.size > 0 then Canvas.Font.Size := run.size;
  applyTextQuality(Canvas);
end;

// lays the runs out in `width`; a line is as tall as its tallest run
function TRichLabel.measure(width: integer; out lines: integer): integer;
var
  x, y, lineStart, lineHeight, spacing: integer;

  procedure closeLine(nextIndex: integer);
  begin
    // the runs of the line sit on its baseline, the tallest sets the height
    for var k := lineStart to nextIndex-1 do if FRuns[k].text <> #10 then FRuns[k].rect.Top := y+lineHeight-FRuns[k].rect.Height;
    for var k := lineStart to nextIndex-1 do FRuns[k].rect.Bottom := FRuns[k].rect.Top+FRuns[k].rect.Height;
    y += lineHeight+spacing;
    lineHeight := 0;
    x := 0;
    lineStart := nextIndex;
    inc(lines);
  end;

begin
  x := 0;
  y := 0;
  lines := 1;
  lineStart := 0;
  lineHeight := 0;
  spacing := scaled(self, FLineSpacing);
  applyFont(Default(TRun));
  var baseHeight := Canvas.TextHeight('Hg');
  for var i := 0 to high(FRuns) do begin
    if FRuns[i].text = #10 then begin
      if lineHeight = 0 then lineHeight := baseHeight;
      FRuns[i].rect := Rect(x, y, x, y+lineHeight);
      FRuns[i].line := lines-1;
      closeLine(i+1);
      continue;
    end;
    applyFont(FRuns[i]);
    var w := Canvas.TextWidth(FRuns[i].text);
    var h := Canvas.TextHeight('Hg');
    if FWordWrap and (x > 0) and (x+w > width) then closeLine(i);
    FRuns[i].rect := Rect(x, y, x+w, y+h);
    FRuns[i].line := lines-1;
    lineHeight := Max(lineHeight, h);
    x += w;
  end;
  if lineHeight = 0 then lineHeight := baseHeight;
  closeLine(length(FRuns));
  dec(lines);
  result := y-spacing;
end;

procedure TRichLabel.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  if FRuns = nil then parse;
  var lines: integer;
  var limit := if FWordWrap then Width else MaxInt;
  PreferredHeight := measure(limit, lines);
  PreferredWidth := 0;
  if FWordWrap then exit;
  var w := 0;
  for var i := 0 to high(FRuns) do w := Max(w, FRuns[i].rect.Right);
  PreferredWidth := w;
end;

// -- painting ----------------------

procedure TRichLabel.Paint;
begin
  if FRuns = nil then parse;
  var lines: integer;
  var used := measure(ClientWidth, lines);
  if not FTransparent then begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := GetRGBColorResolvingParent;
    Canvas.FillRect(ClientRect);
  end;
  var top := match FLayout of
    tlCenter: (ClientHeight-used) div 2;
    tlBottom: ClientHeight-used;
  else
    0
  end;
  var shift: array of integer;
  SetLength(shift, Max(lines, 1));
  for var l := 0 to high(shift) do begin
    var right := 0;
    for var i := 0 to high(FRuns) do if FRuns[i].line = l then right := Max(right, FRuns[i].rect.Right);
    shift[l] := match FAlignment of
      taCenter: (ClientWidth-right) div 2;
      taRightJustify: ClientWidth-right;
    else
      0
    end;
  end;
  var plain := if FTextColor <> clDefault then ColorToRGB(FTextColor) else ColorToRGB(if Font.Color = clDefault then clWindowText else Font.Color);
  if not Enabled then plain := ColorToRGB(clGrayText);
  var link := pick(FLinkColor, clHotLight);
  var hotLink := pick(FHoverLinkColor, blend(link, clWindowText, 30));
  Canvas.Brush.Style := bsClear;
  // the ellipsis takes the place of the last run of the first line that
  // reaches past the right edge
  var dots := if FEndEllipsis and not FWordWrap then Canvas.TextWidth('...') else 0;
  for var i := 0 to high(FRuns) do begin
    if FRuns[i].text = #10 then continue;
    var r := FRuns[i].rect;
    r.Offset(shift[FRuns[i].line], top);
    if r.Left >= ClientWidth then continue;
    applyFont(FRuns[i]);
    if FRuns[i].href <> '' then begin
      Canvas.Font.Style := Canvas.Font.Style+[fsUnderline];
      Canvas.Font.Color := if not Enabled then plain else if FRuns[i].href = FHotLink then hotLink else link;
    end else Canvas.Font.Color := if (FRuns[i].color = clDefault) or not Enabled then plain else ColorToRGB(FRuns[i].color);
    var piece := FRuns[i].text;
    if (dots > 0) and (r.Right > ClientWidth) then begin
      // the run is cut to what leaves room for the dots
      while (piece <> '') and (r.Left+Canvas.TextWidth(piece)+dots > ClientWidth) do SetLength(piece, length(piece)-1);
      Canvas.TextOut(r.Left, r.Top, piece+'...');
      break;
    end;
    Canvas.TextOut(r.Left, r.Top, piece);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// the link under a point, after the last layout
function TRichLabel.linkAt(x, y: integer): string;
begin
  result := '';
  if FRuns = nil then exit;
  var lines: integer;
  var used := measure(ClientWidth, lines);
  var top := match FLayout of
    tlCenter: (ClientHeight-used) div 2;
    tlBottom: ClientHeight-used;
  else
    0
  end;
  for var i := 0 to high(FRuns) do begin
    if (FRuns[i].href = '') or (FRuns[i].text = #10) then continue;
    var r := FRuns[i].rect;
    var right := 0;
    for var k := 0 to high(FRuns) do if FRuns[k].line = FRuns[i].line then right := Max(right, FRuns[k].rect.Right);
    var shift := match FAlignment of
      taCenter: (ClientWidth-right) div 2;
      taRightJustify: ClientWidth-right;
    else
      0
    end;
    r.Offset(shift, top);
    if r.Contains(Point(x, y)) then exit(FRuns[i].href);
  end;
end;

procedure TRichLabel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := linkAt(X, Y);
  if hot <> FHotLink then begin
    FHotLink := hot;
    Cursor := if hot <> '' then crHandPoint else crDefault;
    Invalidate;
  end;
end;

procedure TRichLabel.MouseLeave;
begin
  inherited MouseLeave;
  if FHotLink <> '' then begin
    FHotLink := '';
    Cursor := crDefault;
    Invalidate;
  end;
end;

procedure TRichLabel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  var href := linkAt(X, Y);
  if href = '' then exit;
  if FOpenLinks then OpenURL(href);
  if Assigned(FOnLinkClick) then FOnLinkClick(self, href);
end;

procedure TRichLabel.TextChanged;
begin
  inherited TextChanged;
  FRuns := nil;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRichLabel.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRichLabel.DoSetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  var widthChanged := AWidth <> Width;
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
  if widthChanged and FWordWrap then begin
    InvalidatePreferredSize;
    AdjustSize;
  end;
end;

// -- properties ----------------------

procedure TRichLabel.setWordWrap(value: boolean);
begin
  if FWordWrap = value then exit;
  FWordWrap := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TRichLabel.setTransparent(value: boolean);
begin
  if FTransparent = value then exit;
  FTransparent := value;
  Invalidate;
end;

procedure TRichLabel.setAlignment(value: TAlignment);
begin
  if FAlignment = value then exit;
  FAlignment := value;
  Invalidate;
end;

procedure TRichLabel.setLayout(value: TTextLayout);
begin
  if FLayout = value then exit;
  FLayout := value;
  Invalidate;
end;

function TRichLabel.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FEndEllipsis else FOpenLinks;
end;

procedure TRichLabel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FEndEllipsis := value else FOpenLinks := value;
  Invalidate;
end;

function TRichLabel.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FTextColor;
    1: FLinkColor;
  else
    FHoverLinkColor
  end;
end;

procedure TRichLabel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FTextColor := value;
    1: FLinkColor := value;
  else
    FHoverLinkColor := value;
  end;
  Invalidate;
end;

procedure TRichLabel.setLineSpacing(value: integer);
begin
  if FLineSpacing = value then exit;
  FLineSpacing := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

end.
