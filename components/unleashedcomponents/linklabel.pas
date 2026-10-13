{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit LinkLabel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType;

type
  TLinkUnderline = (luAlways, luHover, luNever);
  TLinkClickEvent = procedure(Sender: TObject; const link: string; var handled: boolean) of object;

  { TLinkLabel }

  // a label whose caption holds links: the text between <a href="...">
  // and </a> shows as a link and opens its target when clicked, unless
  // OnLinkClick handles it. <b>, <i> and <u> mark bold, italic and
  // underlined runs; the rest is plain text
  TLinkLabel = class(TGraphicControl)
  private
    type
      TRun = record
        text: string;
        link: string; // '' for plain text
        bold, italic, underline: boolean;
        rect: TRect; // where it was painted last
        line: integer;
      end;
    var
    FRuns: array of TRun;
    FLinkColor, FHoverColor, FVisitedColor: TColor;
    FUnderline: TLinkUnderline;
    FOpenLinks, FTrackVisited, FWordWrap, FTransparent: boolean;
    FAlignment: TAlignment;
    FLayout: TTextLayout;
    FVisited: TStringList;
    FHotRun, FPressedRun: integer;
    FOnLinkClick: TLinkClickEvent;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setUnderline(value: TLinkUnderline);
    procedure setWordWrap(value: boolean);
    procedure setTransparent(value: boolean);
    procedure setAlignment(value: TAlignment);
    procedure setLayout(value: TTextLayout);
    procedure parse;
    // lays the runs out in the client width; returns the height used
    function measure(width: integer; out lines: integer): integer;
    function runAt(x, y: integer): integer;
    procedure setHotRun(value: integer);
    procedure applyFont(const run: TRun; hot: boolean);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure DoSetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the links of the caption in order
    function LinkCount: integer;
    function Links(index: integer): string;
    // the link was followed; VisitedColor shows it
    function Visited(const link: string): boolean;
    procedure MarkVisited(const link: string);
    procedure ClearVisited;
  published
    property Caption;
    // clDefault takes the colors of the theme
    property LinkColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property HoverColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property VisitedColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Underline: TLinkUnderline read FUnderline write setUnderline default luHover;
    // a click opens the link in the browser unless OnLinkClick handled it
    property OpenLinks: boolean read FOpenLinks write FOpenLinks default true;
    // a followed link turns VisitedColor
    property TrackVisited: boolean read FTrackVisited write FTrackVisited default false;
    property WordWrap: boolean read FWordWrap write setWordWrap default false;
    // the background stays as the parent paints it
    property Transparent: boolean read FTransparent write setTransparent default true;
    property Alignment: TAlignment read FAlignment write setAlignment default taLeftJustify;
    property Layout: TTextLayout read FLayout write setLayout default tlTop;
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

constructor TLinkLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption, csReplicatable]-[csOpaque];
  FLinkColor := clDefault;
  FHoverColor := clDefault;
  FVisitedColor := clDefault;
  FUnderline := luHover;
  FOpenLinks := true;
  FTransparent := true;
  FLayout := tlTop;
  FVisited := TStringList.Create;
  FVisited.CaseSensitive := false;
  FHotRun := -1;
  FPressedRun := -1;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TLinkLabel.Destroy;
begin
  FVisited.Free;
  inherited Destroy;
end;

class function TLinkLabel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 17;
end;

// -- markup ----------------------

// the caption into runs: a tag opens or closes a style, text between tags
// becomes a run; a lone word break inside plain text splits runs so the
// wrap can break there
procedure TLinkLabel.parse;
var
  s, link, text: string;
  bold, italic, underline: boolean;
  i, n: integer;

  procedure addRun(const piece: string);
  begin
    SetLength(FRuns, length(FRuns)+1);
    FRuns[high(FRuns)].text := piece;
    FRuns[high(FRuns)].link := link;
    FRuns[high(FRuns)].bold := bold;
    FRuns[high(FRuns)].italic := italic;
    FRuns[high(FRuns)].underline := underline;
  end;

  // a line break is a run of its own, outside any link
  procedure addBreak;
  begin
    var saved := link;
    link := '';
    addRun(#10);
    link := saved;
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

begin
  FRuns := nil;
  s := Caption;
  link := '';
  bold := false;
  italic := false;
  underline := false;
  text := '';
  i := 1;
  n := length(s);
  while i <= n do begin
    if s[i] = '<' then begin
      var close := Pos('>', s, i);
      if close = 0 then break;
      var tag := LowerCase(Copy(s, i+1, close-i-1));
      flush;
      if Copy(tag, 1, 2) = 'a ' then begin
        var q := Pos('href=', tag);
        link := '';
        if q > 0 then begin
          var v := Copy(tag, q+5, MaxInt);
          if (v <> '') and (v[1] in ['"', #39]) then begin
            var e := Pos(v[1], v, 2);
            link := Copy(v, 2, (if e = 0 then length(v) else e-1)-1);
          end else link := Trim(v);
        end;
        if link = '' then link := ' '; // an anchor without a target still reads as a link
      end else if tag = '/a' then link := ''
      else if tag = 'b' then bold := true
      else if tag = '/b' then bold := false
      else if tag = 'i' then italic := true
      else if tag = '/i' then italic := false
      else if tag = 'u' then underline := true
      else if tag = '/u' then underline := false
      else if tag = 'br' then addBreak;
      i := close+1;
    end else begin
      // &lt; &gt; &amp; read as the characters they stand for
      if s[i] = '&' then begin
        if Copy(s, i, 4) = '&lt;' then begin text += '<'; i += 4; continue; end;
        if Copy(s, i, 4) = '&gt;' then begin text += '>'; i += 4; continue; end;
        if Copy(s, i, 5) = '&amp;' then begin text += '&'; i += 5; continue; end;
      end;
      if s[i] = #10 then begin
        flush;
        addBreak;
        i += 1;
        continue;
      end;
      if s[i] <> #13 then text += s[i];
      i += 1;
    end;
  end;
  flush;
end;

procedure TLinkLabel.applyFont(const run: TRun; hot: boolean);
begin
  var style := Font.Style;
  if run.bold then Include(style, fsBold);
  if run.italic then Include(style, fsItalic);
  if run.underline then Include(style, fsUnderline);
  if run.link <> '' then begin
    if (FUnderline = luAlways) or ((FUnderline = luHover) and hot) then Include(style, fsUnderline);
  end;
  Canvas.Font.Assign(Font);
  Canvas.Font.Style := style;
end;

function TLinkLabel.measure(width: integer; out lines: integer): integer;
begin
  // measured with the quality the text is painted in
  applyTextQuality(Canvas);
  var x := 0;
  var y := 0;
  var lineHeight := Canvas.TextHeight('Hg');
  lines := 1;
  for var i := 0 to high(FRuns) do begin
    if FRuns[i].text = #10 then begin
      FRuns[i].rect := Rect(x, y, x, y+lineHeight);
      FRuns[i].line := lines-1;
      x := 0;
      y += lineHeight;
      inc(lines);
      continue;
    end;
    applyFont(FRuns[i], false);
    var w := Canvas.TextWidth(FRuns[i].text);
    if FWordWrap and (x > 0) and (x+w > width) then begin
      x := 0;
      y += lineHeight;
      inc(lines);
    end;
    FRuns[i].rect := Rect(x, y, x+w, y+lineHeight);
    FRuns[i].line := lines-1;
    x += w;
  end;
  result := y+lineHeight;
end;

procedure TLinkLabel.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  if FRuns = nil then parse;
  var lines: integer;
  var limit := if FWordWrap then Width else MaxInt;
  PreferredHeight := measure(limit, lines);
  PreferredWidth := 0;
  if not FWordWrap then begin
    var w := 0;
    for var i := 0 to high(FRuns) do w := Max(w, FRuns[i].rect.Right);
    PreferredWidth := w;
  end;
end;

// -- painting ----------------------

procedure TLinkLabel.Paint;
begin
  if FRuns = nil then parse;
  applyTextQuality(Canvas);
  var lines: integer;
  var used := measure(ClientWidth, lines);
  if not FTransparent then begin
    Canvas.Brush.Color := Color;
    Canvas.FillRect(ClientRect);
  end;
  var top := match FLayout of
    tlCenter: (ClientHeight-used) div 2;
    tlBottom: ClientHeight-used;
  else
    0
  end;
  // the shift of each line for the alignment
  var shift: array of integer;
  SetLength(shift, lines);
  for var l := 0 to lines-1 do begin
    var right := 0;
    for var i := 0 to high(FRuns) do if FRuns[i].line = l then right := Max(right, FRuns[i].rect.Right);
    shift[l] := match FAlignment of
      taCenter: (ClientWidth-right) div 2;
      taRightJustify: ClientWidth-right;
    else
      0
    end;
  end;
  var plain := ColorToRGB(if Enabled then clWindowText else clGrayText);
  var linkColor := pick(FLinkColor, clHotLight);
  var hoverColor := pick(FHoverColor, blend(linkColor, clWindowText, 35));
  var visitedColor := pick(FVisitedColor, blend(linkColor, clGrayText, 50));
  Canvas.Brush.Style := bsClear;
  for var i := 0 to high(FRuns) do begin
    if FRuns[i].text = #10 then continue;
    var r := FRuns[i].rect;
    r.Offset(shift[FRuns[i].line], top);
    FRuns[i].rect := r;
    // every run of the link under the mouse lights up, not only the word
    var hot := Enabled and hoverEnabled and (FHotRun >= 0) and (FRuns[i].link <> '') and (FRuns[i].link = FRuns[FHotRun].link);
    applyFont(FRuns[i], hot);
    if FRuns[i].link = '' then Canvas.Font.Color := plain
    else if not Enabled then Canvas.Font.Color := ColorToRGB(clGrayText)
    else if hot then Canvas.Font.Color := hoverColor
    else if FTrackVisited and Visited(FRuns[i].link) then Canvas.Font.Color := visitedColor
    else Canvas.Font.Color := linkColor;
    Canvas.TextOut(r.Left, r.Top, FRuns[i].text);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

function TLinkLabel.runAt(x, y: integer): integer;
begin
  result := -1;
  for var i := 0 to high(FRuns) do if (FRuns[i].link <> '') and FRuns[i].rect.Contains(Point(x, y)) then exit(i);
end;

procedure TLinkLabel.setHotRun(value: integer);
begin
  if FHotRun = value then exit;
  // every run of the same link lights up together
  FHotRun := value;
  Cursor := if value >= 0 then crHandPoint else crDefault;
  Invalidate;
end;

procedure TLinkLabel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var i := runAt(X, Y);
  // the hot state follows the link, not the piece of it under the mouse
  if (i >= 0) and (FHotRun >= 0) and (FRuns[i].link = FRuns[FHotRun].link) then exit;
  setHotRun(i);
end;

procedure TLinkLabel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then FPressedRun := runAt(X, Y);
end;

procedure TLinkLabel.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var i := runAt(X, Y);
  var pressed := FPressedRun;
  FPressedRun := -1;
  if (i < 0) or (pressed < 0) or (FRuns[i].link <> FRuns[pressed].link) or not Enabled then exit;
  var link := Trim(FRuns[i].link);
  var handled := false;
  if Assigned(FOnLinkClick) then FOnLinkClick(self, link, handled);
  if not handled and FOpenLinks and (link <> '') then OpenURL(link);
  if FTrackVisited then MarkVisited(link);
end;

procedure TLinkLabel.MouseLeave;
begin
  inherited MouseLeave;
  FPressedRun := -1;
  setHotRun(-1);
end;

procedure TLinkLabel.TextChanged;
begin
  inherited TextChanged;
  FRuns := nil;
  FHotRun := -1;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TLinkLabel.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// a wrapped caption lays out again when the width changes, like TLabel
procedure TLinkLabel.DoSetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
  var widthChanged := AWidth <> Width;
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
  if widthChanged and FWordWrap then begin
    InvalidatePreferredSize;
    AdjustSize;
  end;
end;

// -- links ----------------------

function TLinkLabel.LinkCount: integer;
begin
  if FRuns = nil then parse;
  result := 0;
  var last := '';
  for var i := 0 to high(FRuns) do if (FRuns[i].link <> '') and (FRuns[i].link <> last) then begin
    inc(result);
    last := FRuns[i].link;
  end;
end;

function TLinkLabel.Links(index: integer): string;
begin
  if FRuns = nil then parse;
  result := '';
  var n := -1;
  var last := '';
  for var i := 0 to high(FRuns) do if (FRuns[i].link <> '') and (FRuns[i].link <> last) then begin
    inc(n);
    last := FRuns[i].link;
    if n = index then exit(Trim(last));
  end;
end;

function TLinkLabel.Visited(const link: string): boolean;
begin
  result := FVisited.IndexOf(Trim(link)) >= 0;
end;

procedure TLinkLabel.MarkVisited(const link: string);
begin
  if Visited(link) then exit;
  FVisited.Add(Trim(link));
  Invalidate;
end;

procedure TLinkLabel.ClearVisited;
begin
  FVisited.Clear;
  Invalidate;
end;

// -- properties ----------------------

function TLinkLabel.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FLinkColor;
    1: result := FHoverColor;
    _: result := FVisitedColor;
  end;
end;

procedure TLinkLabel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FLinkColor := value;
    1: FHoverColor := value;
    _: FVisitedColor := value;
  end;
  Invalidate;
end;

procedure TLinkLabel.setUnderline(value: TLinkUnderline);
begin
  if FUnderline = value then exit;
  FUnderline := value;
  Invalidate;
end;

procedure TLinkLabel.setWordWrap(value: boolean);
begin
  if FWordWrap = value then exit;
  FWordWrap := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TLinkLabel.setTransparent(value: boolean);
begin
  if FTransparent = value then exit;
  FTransparent := value;
  Invalidate;
end;

procedure TLinkLabel.setAlignment(value: TAlignment);
begin
  if FAlignment = value then exit;
  FAlignment := value;
  Invalidate;
end;

procedure TLinkLabel.setLayout(value: TTextLayout);
begin
  if FLayout = value then exit;
  FLayout := value;
  Invalidate;
end;

end.
