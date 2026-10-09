{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit MarkdownLabel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLIntf, ControlPaint;

type
  TMarkdownLinkEvent = procedure(Sender: TObject; const url: string; var handled: boolean) of object;

  { TMarkdownLabel }

  // a label that reads Markdown: headings, paragraphs, bullet and numbered
  // lists, quotes, code spans and blocks, rules, bold, italic and links.
  // The text wraps to the width and the height follows it, so a help
  // text or a changelog goes straight into the form
  TMarkdownLabel = class(TGraphicControl)
  private
    type
      TBlockKind = (bkParagraph, bkHeading, bkBullet, bkNumber, bkQuote, bkCode, bkRule);
      TRun = record
        text: string;
        bold, italic, code, strike: boolean;
        href: string;
        rect: TRect; // where it was painted, for the links
      end;
      TBlock = record
        kind: TBlockKind;
        level: integer; // the heading level, the list depth
        number: integer; // the number of a numbered item
        runs: array of TRun;
        lines: array of string; // a code block keeps its lines as they are
      end;
    var
    FLines: TStrings;
    FBlocks: array of TBlock;
    FLinks: array of TRun; // the painted link pieces
    FRunBuffer: array of TRun; // the runs of the block being parsed
    FRunCount: integer;
    FHotLink: integer;
    FLaidWidth: integer; // the width the height was computed for
    FLinkColor, FCodeColor, FCodeBackColor, FQuoteColor, FHeadingColor, FTextColor, FRuleColor: TColor;
    FHoverLinkColor: TColor;
    FParagraphSpacing, FLineSpacing, FIndent, FHeadingScale, FCodeRadius, FListSpacing, FPadding: integer;
    FCodeFont: TFont;
    FBulletText: string;
    FOpenLinks, FWordWrap: boolean;
    FAntialiasing: TAntialiasSetting;
    FOnLinkClick: TMarkdownLinkEvent;
    procedure setLines(value: TStrings);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setCodeFont(value: TFont);
    procedure setBulletText(const value: string);
    procedure codeFontChanged(Sender: TObject);
    procedure linesChanged(Sender: TObject);
    procedure parse;
    procedure parseInline(const text: string);
    procedure applyRun(const run: TRun; level: integer);
    function headingSize(level: integer): integer;
    // lays the blocks out in a width; pass 0 measures, 1 paints the shapes, 2 the text
    function layout(width: integer; pass: integer): integer;
    function linkAt(x, y: integer): integer;
    procedure setHoverLinkColor(value: TColor);
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure FontChanged(Sender: TObject); override;
    procedure Resize; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the whole text at once
    procedure SetText(const markdown: string);
    procedure LoadFromFile(const fileName: string);
  published
    // the Markdown source
    property Lines: TStrings read FLines write setLines;
    // clDefault takes the colors of the theme
    property LinkColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    // the link under the mouse; clDefault darkens LinkColor a little
    property HoverLinkColor: TColor read FHoverLinkColor write setHoverLinkColor default clDefault;
    property CodeColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property CodeBackColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property QuoteColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property HeadingColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property RuleColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property ParagraphSpacing: integer index 0 read getMetric write setMetric default 8;
    // extra pixels between the lines of a paragraph
    property LineSpacing: integer index 1 read getMetric write setMetric default 2;
    // the indent of a list level and of a quote
    property Indent: integer index 2 read getMetric write setMetric default 18;
    // the font size of a top heading as a percentage of the font
    property HeadingScale: integer index 3 read getMetric write setMetric default 160;
    property CodeRadius: integer index 4 read getMetric write setMetric default 3;
    // between the items of one list
    property ListSpacing: integer index 5 read getMetric write setMetric default 3;
    property Padding: integer index 6 read getMetric write setMetric default 0;
    // the font of code spans and blocks; size 0 keeps the size of Font
    property CodeFont: TFont read FCodeFont write setCodeFont;
    property BulletText: string read FBulletText write setBulletText;
    // a click opens the link in the browser, unless OnLinkClick handled it
    property OpenLinks: boolean index 0 read getFlag write setFlag default true;
    property WordWrap: boolean index 1 read getFlag write setFlag default true;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnLinkClick: TMarkdownLinkEvent read FOnLinkClick write FOnLinkClick;
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
  Math, StrUtils;

constructor TMarkdownLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FLines := TStringList.Create;
  TStringList(FLines).OnChange := @linesChanged;
  FLinkColor := clDefault;
  FHoverLinkColor := clDefault;
  FCodeColor := clDefault;
  FCodeBackColor := clDefault;
  FQuoteColor := clDefault;
  FHeadingColor := clDefault;
  FTextColor := clDefault;
  FRuleColor := clDefault;
  FParagraphSpacing := 8;
  FLineSpacing := 2;
  FIndent := 18;
  FHeadingScale := 160;
  FCodeRadius := 3;
  FListSpacing := 3;
  FBulletText := #$E2#$80#$A2;
  FCodeFont := TFont.Create;
  FCodeFont.Name := monospaceFontName;
  FCodeFont.Pitch := fpFixed;
  FCodeFont.Size := 0;
  FCodeFont.OnChange := @codeFontChanged;
  FOpenLinks := true;
  FWordWrap := true;
  FHotLink := -1;
  FAntialiasing := asTheme;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TMarkdownLabel.Destroy;
begin
  FCodeFont.Free;
  FLines.Free;
  inherited Destroy;
end;

class function TMarkdownLabel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 60;
end;

procedure TMarkdownLabel.SetText(const markdown: string);
begin
  FLines.Text := markdown;
end;

procedure TMarkdownLabel.LoadFromFile(const fileName: string);
begin
  FLines.LoadFromFile(fileName);
end;

procedure TMarkdownLabel.linesChanged(Sender: TObject);
begin
  parse;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- parsing ----------------------

// bold, italic, code, strike and links inside one line of text
procedure TMarkdownLabel.parseInline(const text: string);
begin
  FRunCount := 0;
  if length(FRunBuffer) = 0 then SetLength(FRunBuffer, 256);
  var bold := false;
  var italic := false;
  var strike := false;
  var piece := '';
  var n := length(text);
  var i := 1;
  var flush := procedure(const href: string; code: boolean)
  begin
    if piece = '' then exit;
    FRunBuffer[FRunCount].text := piece;
    FRunBuffer[FRunCount].bold := bold;
    FRunBuffer[FRunCount].italic := italic;
    FRunBuffer[FRunCount].strike := strike;
    FRunBuffer[FRunCount].code := code;
    FRunBuffer[FRunCount].href := href;
    inc(FRunCount);
    piece := '';
  end;
  while (i <= n) and (FRunCount < length(FRunBuffer)-1) do begin
    var c := text[i];
    if (c = '\') and (i < n) then begin
      // an escaped marker is plain text
      piece += text[i+1];
      i += 2;
    end else if (c = '*') and (i < n) and (text[i+1] = '*') or (c = '_') and (i < n) and (text[i+1] = '_') then begin
      flush('', false);
      bold := not bold;
      i += 2;
    end else if (c = '~') and (i < n) and (text[i+1] = '~') then begin
      flush('', false);
      strike := not strike;
      i += 2;
    end else if (c = '*') or (c = '_') and ((i = 1) or not (text[i-1] in ['a'..'z', 'A'..'Z', '0'..'9'])) then begin
      flush('', false);
      italic := not italic;
      inc(i);
    end else if c = '`' then begin
      // a code span runs to the next backtick, markers inside it are text
      var close := PosEx('`', text, i+1);
      if close = 0 then begin piece += c; inc(i); continue; end;
      flush('', false);
      piece := Copy(text, i+1, close-i-1);
      flush('', true);
      i := close+1;
    end else if (c = '[') then begin
      // [text](url)
      var closeText := PosEx(']', text, i+1);
      if (closeText > 0) and (closeText < n) and (text[closeText+1] = '(') then begin
        var closeUrl := PosEx(')', text, closeText+2);
        if closeUrl > 0 then begin
          flush('', false);
          piece := Copy(text, i+1, closeText-i-1);
          flush(Copy(text, closeText+2, closeUrl-closeText-2), false);
          i := closeUrl+1;
          continue;
        end;
      end;
      piece += c;
      inc(i);
    end else if (c = '<') and (PosEx('>', text, i) > 0) and ((PosEx('://', text, i) > 0) and (PosEx('://', text, i) < PosEx('>', text, i))) then begin
      // <https://...>
      var close := PosEx('>', text, i);
      flush('', false);
      piece := Copy(text, i+1, close-i-1);
      flush(piece, false);
      i := close+1;
    end else begin
      piece += c;
      inc(i);
    end;
  end;
  if i <= n then piece += Copy(text, i, MaxInt);
  flush('', false);
end;

procedure TMarkdownLabel.parse;
begin
  FBlocks := nil;
  var i := 0;
  var paragraph := '';
  var addBlock := procedure(kind: TBlockKind; level, number: integer; const text: string)
  begin
    SetLength(FBlocks, length(FBlocks)+1);
    var b := high(FBlocks);
    FBlocks[b] := Default(TBlock);
    FBlocks[b].kind := kind;
    FBlocks[b].level := level;
    FBlocks[b].number := number;
    parseInline(text);
    SetLength(FBlocks[b].runs, FRunCount);
    for var k := 0 to FRunCount-1 do FBlocks[b].runs[k] := FRunBuffer[k];
  end;
  var flushParagraph := procedure
  begin
    if paragraph <> '' then addBlock(bkParagraph, 0, 0, paragraph);
    paragraph := '';
  end;
  while i < FLines.Count do begin
    var line := FLines[i];
    var trimmed := TrimLeft(line);
    var indent := length(line)-length(trimmed);
    inc(i);
    if trimmed = '' then begin flushParagraph; continue; end;
    if (Copy(trimmed, 1, 3) = '```') or (Copy(trimmed, 1, 3) = '~~~') then begin
      // a fenced code block runs to the matching fence
      flushParagraph;
      var fence := Copy(trimmed, 1, 3);
      SetLength(FBlocks, length(FBlocks)+1);
      var b := high(FBlocks);
      FBlocks[b] := Default(TBlock);
      FBlocks[b].kind := bkCode;
      while (i < FLines.Count) and (Copy(TrimLeft(FLines[i]), 1, 3) <> fence) do begin
        SetLength(FBlocks[b].lines, length(FBlocks[b].lines)+1);
        FBlocks[b].lines[high(FBlocks[b].lines)] := FLines[i];
        inc(i);
      end;
      inc(i);
      continue;
    end;
    if trimmed[1] = '#' then begin
      var level := 0;
      while (level < length(trimmed)) and (trimmed[level+1] = '#') do inc(level);
      if (level <= 6) and (level < length(trimmed)) and (trimmed[level+1] = ' ') then begin
        flushParagraph;
        addBlock(bkHeading, level, 0, Trim(Copy(trimmed, level+1, MaxInt)));
        continue;
      end;
    end;
    if (trimmed = '---') or (trimmed = '***') or (trimmed = '___') then begin
      flushParagraph;
      addBlock(bkRule, 0, 0, '');
      continue;
    end;
    if trimmed[1] = '>' then begin
      flushParagraph;
      var text := Trim(Copy(trimmed, 2, MaxInt));
      // the lines of a quote that follow join it
      while (i < FLines.Count) and (TrimLeft(FLines[i]) <> '') and (TrimLeft(FLines[i])[1] = '>') do begin
        text += ' '+Trim(Copy(TrimLeft(FLines[i]), 2, MaxInt));
        inc(i);
      end;
      addBlock(bkQuote, 0, 0, text);
      continue;
    end;
    if (length(trimmed) > 1) and (trimmed[1] in ['-', '*', '+']) and (trimmed[2] = ' ') then begin
      flushParagraph;
      addBlock(bkBullet, indent div 2, 0, Trim(Copy(trimmed, 3, MaxInt)));
      continue;
    end;
    var digits := 0;
    while (digits < length(trimmed)) and (trimmed[digits+1] in ['0'..'9']) do inc(digits);
    if (digits > 0) and (digits+1 < length(trimmed)) and (trimmed[digits+1] in ['.', ')']) and (trimmed[digits+2] = ' ') then begin
      flushParagraph;
      addBlock(bkNumber, indent div 2, StrToIntDef(Copy(trimmed, 1, digits), 1), Trim(Copy(trimmed, digits+3, MaxInt)));
      continue;
    end;
    if (indent >= 4) and (paragraph = '') then begin
      // an indented block is code too
      SetLength(FBlocks, length(FBlocks)+1);
      var b := high(FBlocks);
      FBlocks[b] := Default(TBlock);
      FBlocks[b].kind := bkCode;
      SetLength(FBlocks[b].lines, 1);
      FBlocks[b].lines[0] := Copy(line, 5, MaxInt);
      while (i < FLines.Count) and ((Copy(FLines[i], 1, 4) = '    ') or (FLines[i] = '')) do begin
        if (FLines[i] = '') and ((i+1 >= FLines.Count) or (Copy(FLines[i+1], 1, 4) <> '    ')) then break;
        SetLength(FBlocks[b].lines, length(FBlocks[b].lines)+1);
        FBlocks[b].lines[high(FBlocks[b].lines)] := Copy(FLines[i], 5, MaxInt);
        inc(i);
      end;
      continue;
    end;
    // two spaces at the end of a line keep the break
    if paragraph <> '' then paragraph += (if Copy(line, length(line)-1, 2) = '  ' then #10 else ' ');
    paragraph += Trim(line);
  end;
  flushParagraph;
end;

// -- layout and painting ----------------------

function TMarkdownLabel.headingSize(level: integer): integer;
begin
  var base := Font.Size;
  if base = 0 then base := 9;
  var scale := FHeadingScale-(level-1)*(FHeadingScale-100) div 4;
  result := Max(Round(base*scale/100), base);
end;

procedure TMarkdownLabel.applyRun(const run: TRun; level: integer);
begin
  var style := Font.Style;
  if run.bold then style += [fsBold];
  if run.italic then style += [fsItalic];
  if run.strike then style += [fsStrikeOut];
  if run.href <> '' then style += [fsUnderline];
  if level > 0 then style += [fsBold];
  Canvas.Font.Style := style;
  Canvas.Font.Size := if level > 0 then headingSize(level) else Font.Size;
  if run.code then begin
    Canvas.Font.Name := FCodeFont.Name;
    Canvas.Font.Pitch := FCodeFont.Pitch;
    if FCodeFont.Size <> 0 then Canvas.Font.Size := FCodeFont.Size;
  end else begin
    Canvas.Font.Name := Font.Name;
    Canvas.Font.Pitch := Font.Pitch;
  end;
end;

// places every block and its runs in the width, word by word; returns the height
function TMarkdownLabel.layout(width: integer; pass: integer): integer;
begin
  var paint := pass = 2;
  var shapes := pass = 1;
  applyTextQuality(Canvas);
  var back := GetRGBColorResolvingParent;
  var textColor := pick(FTextColor, clWindowText);
  var linkColor := pick(FLinkColor, clHotLight);
  var hoverLink := pick(FHoverLinkColor, blend(linkColor, clWindowText, 35));
  var codeColor := pick(FCodeColor, blend(clWindowText, clHighlight, 30));
  var codeBack := pick(FCodeBackColor, blend(back, clWindowText, 8));
  var quoteColor := pick(FQuoteColor, blend(clWindowText, back, 35));
  var headingColor := pick(FHeadingColor, clWindowText);
  var ruleColor := pick(FRuleColor, blend(back, clWindowText, 20));
  var spacing := scaled(self, FParagraphSpacing);
  var lineGap := scaled(self, FLineSpacing);
  var indentPx := scaled(self, FIndent);
  var radius := scaled(self, FCodeRadius);
  var padPx := scaled(self, FPadding);
  var y := padPx;
  width -= padPx;
  FLinks := nil;
  if paint then Canvas.Brush.Style := bsClear;
  var sp: TSmoothPaint := nil;
  if shapes then sp := beginShapes(Canvas, ClientRect, back, FAntialiasing);
  try
    for var b := 0 to high(FBlocks) do begin
      var block := FBlocks[b];
      // list items of one list sit closer than paragraphs
      if b > 0 then y += (if (block.kind in [bkBullet, bkNumber]) and (FBlocks[b-1].kind = block.kind) then scaled(self, FListSpacing) else spacing);
      var left := padPx+(if block.kind in [bkBullet, bkNumber] then block.level*indentPx else 0);
      if block.kind in [bkBullet, bkNumber] then left += indentPx;
      if block.kind = bkQuote then left += indentPx;
      var right := width;
      match block.kind of
        bkRule: begin
          if shapes then sp.FillRect(Rect(0, y+spacing div 2, width, y+spacing div 2+1), ruleColor);
          y += spacing;
          continue;
        end;
        bkCode: begin
          var codeRun := Default(TRun);
          codeRun.code := true;
          applyRun(codeRun, 0);
          var lh := Canvas.TextHeight('Hg');
          var pad := scaled(self, 6);
          var h := length(block.lines)*lh+2*pad;
          if shapes then sp.FillRoundRect(0, y, width, y+h, radius, codeBack);
          if paint then begin
            Canvas.Font.Color := codeColor;
            for var k := 0 to high(block.lines) do Canvas.TextOut(pad, y+pad+k*lh, block.lines[k]);
          end;
          y += h;
          continue;
        end;
      end;
      // the text runs, wrapped word by word
      var level := if block.kind = bkHeading then block.level else 0;
      applyRun(Default(TRun), level);
      var lh := Canvas.TextHeight('Hg')+lineGap;
      var x := left;
      var lineTop := y;
      var marker := '';
      if block.kind = bkBullet then marker := FBulletText
      else if block.kind = bkNumber then marker := IntToStr(block.number)+'.';
      if paint and (marker <> '') then begin
        Canvas.Font.Color := textColor;
        Canvas.TextOut(left-indentPx+scaled(self, 2), lineTop, marker);
      end;
      var quoteTop := y;
      for var r := 0 to high(block.runs) do begin
        var run := block.runs[r];
        applyRun(run, level);
        var color := textColor;
        if run.href <> '' then color := linkColor;
        if run.code then color := codeColor;
        if block.kind = bkQuote then color := quoteColor;
        if block.kind = bkHeading then color := headingColor;
        if not Enabled then color := ColorToRGB(clGrayText);
        var spaceW := Canvas.TextWidth(' ');
        // the pieces: words and the spaces between, line breaks as their own
        var start := 1;
        var text := run.text;
        var n := length(text);
        var linkStart := Point(x, lineTop);
        var linkOpen := run.href <> '';
        var k := 1;
        while k <= n+1 do begin
          var atEnd := k > n;
          if atEnd or (text[k] = ' ') or (text[k] = #10) then begin
            var word := Copy(text, start, k-start);
            var ww := Canvas.TextWidth(word);
            if FWordWrap and (x > left) and (x+ww > right) and (word <> '') then begin
              // the word goes to the next line
              if linkOpen and paint then begin
                SetLength(FLinks, length(FLinks)+1);
                FLinks[high(FLinks)] := run;
                FLinks[high(FLinks)].rect := Rect(linkStart.X, linkStart.Y, x, lineTop+lh);
              end;
              x := left;
              lineTop += lh;
              linkStart := Point(x, lineTop);
            end;
            if (word <> '') then begin
              if shapes and run.code then sp.FillRoundRect(x-1, lineTop, x+ww+1, lineTop+lh-lineGap, radius, codeBack);
              if paint then begin
                // the pieces of a link join FLinks as they end, so the piece
                // being painted is the next one of the list
                Canvas.Font.Color := if linkOpen and Enabled and (length(FLinks) = FHotLink) then hoverLink else color;
                Canvas.TextOut(x, lineTop, word);
              end;
              x += ww;
            end;
            if not atEnd then begin
              if text[k] = #10 then begin
                if linkOpen and paint then begin
                  SetLength(FLinks, length(FLinks)+1);
                  FLinks[high(FLinks)] := run;
                  FLinks[high(FLinks)].rect := Rect(linkStart.X, linkStart.Y, x, lineTop+lh);
                end;
                x := left;
                lineTop += lh;
                linkStart := Point(x, lineTop);
              end else x += spaceW;
            end;
            start := k+1;
          end;
          inc(k);
        end;
        if linkOpen and paint then begin
          SetLength(FLinks, length(FLinks)+1);
          FLinks[high(FLinks)] := run;
          FLinks[high(FLinks)].rect := Rect(linkStart.X, linkStart.Y, x, lineTop+lh);
        end;
      end;
      y := lineTop+lh;
      if shapes and (block.kind = bkQuote) then
        sp.FillRoundRect(left-indentPx+scaled(self, 2), quoteTop, left-indentPx+scaled(self, 5), y-lineGap, 1.5, blend(back, quoteColor, 50));
      if block.kind = bkHeading then y += scaled(self, 2);
    end;
  finally
    if sp <> nil then begin
      sp.Flush;
      sp.Free;
    end;
    Canvas.Font := Font;
    Canvas.Brush.Style := bsSolid;
  end;
  result := y;
end;

procedure TMarkdownLabel.Paint;
begin
  if length(FBlocks) = 0 then parse;
  layout(ClientWidth, 1);
  layout(ClientWidth, 2);
end;

procedure TMarkdownLabel.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  if length(FBlocks) = 0 then parse;
  // the width stays as set, the height follows the wrapped text
  var w := if FWordWrap and (Width > 0) then Width else 10000;
  FLaidWidth := Width;
  PreferredHeight := layout(w, 0);
  PreferredWidth := if FWordWrap then 0 else Width;
  if not FWordWrap then begin
    // the widest line
    PreferredWidth := 0;
    for var b := 0 to high(FBlocks) do begin
      var lineW := 0;
      for var r := 0 to high(FBlocks[b].runs) do begin
        applyRun(FBlocks[b].runs[r], (if FBlocks[b].kind = bkHeading then FBlocks[b].level else 0));
        lineW += Canvas.TextWidth(FBlocks[b].runs[r].text);
      end;
      PreferredWidth := Max(PreferredWidth, lineW+FBlocks[b].level*scaled(self, FIndent)+scaled(self, FIndent));
    end;
    Canvas.Font := Font;
  end;
end;

procedure TMarkdownLabel.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TMarkdownLabel.Resize;
begin
  inherited Resize;
  // the height follows the width; a change of the height alone must not
  // ask for another size, or the layout loops
  if FWordWrap and AutoSize and (Width <> FLaidWidth) then begin
    FLaidWidth := Width;
    InvalidatePreferredSize;
    AdjustSize;
  end;
  Invalidate;
end;

// -- links ----------------------

function TMarkdownLabel.linkAt(x, y: integer): integer;
begin
  for var i := 0 to high(FLinks) do if PtInRect(FLinks[i].rect, Point(x, y)) then exit(i);
  result := -1;
end;

procedure TMarkdownLabel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := linkAt(X, Y);
  if hot = FHotLink then exit;
  FHotLink := hot;
  Cursor := if hot >= 0 then crHandPoint else crDefault;
  Invalidate;
end;

procedure TMarkdownLabel.MouseLeave;
begin
  inherited MouseLeave;
  if FHotLink >= 0 then Invalidate;
  FHotLink := -1;
  Cursor := crDefault;
end;

procedure TMarkdownLabel.setHoverLinkColor(value: TColor);
begin
  if FHoverLinkColor = value then exit;
  FHoverLinkColor := value;
  Invalidate;
end;

procedure TMarkdownLabel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var hit := linkAt(X, Y);
  if hit < 0 then exit;
  var handled := false;
  if Assigned(FOnLinkClick) then FOnLinkClick(self, FLinks[hit].href, handled);
  if not handled and FOpenLinks then OpenURL(FLinks[hit].href);
end;

// -- properties ----------------------

procedure TMarkdownLabel.setCodeFont(value: TFont);
begin
  FCodeFont.Assign(value);
end;

procedure TMarkdownLabel.codeFontChanged(Sender: TObject);
begin
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TMarkdownLabel.setBulletText(const value: string);
begin
  if FBulletText = value then exit;
  FBulletText := value;
  Invalidate;
end;

procedure TMarkdownLabel.setLines(value: TStrings);
begin
  FLines.Assign(value);
end;

function TMarkdownLabel.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FLinkColor;
    1: FCodeColor;
    2: FCodeBackColor;
    3: FQuoteColor;
    4: FHeadingColor;
    5: FTextColor;
  else
    FRuleColor
  end;
end;

procedure TMarkdownLabel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FLinkColor := value;
    1: FCodeColor := value;
    2: FCodeBackColor := value;
    3: FQuoteColor := value;
    4: FHeadingColor := value;
    5: FTextColor := value;
  else
    FRuleColor := value;
  end;
  Invalidate;
end;

function TMarkdownLabel.getMetric(index: integer): integer;
begin
  result := match index of
    0: FParagraphSpacing;
    1: FLineSpacing;
    2: FIndent;
    3: FHeadingScale;
    4: FCodeRadius;
    5: FListSpacing;
  else
    FPadding
  end;
end;

procedure TMarkdownLabel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 3 then value := Max(value, 100);
  if getMetric(index) = value then exit;
  match index of
    0: FParagraphSpacing := value;
    1: FLineSpacing := value;
    2: FIndent := value;
    3: FHeadingScale := value;
    4: FCodeRadius := value;
    5: FListSpacing := value;
  else
    FPadding := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TMarkdownLabel.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FOpenLinks else FWordWrap;
end;

procedure TMarkdownLabel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FOpenLinks := value else FWordWrap := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TMarkdownLabel.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
