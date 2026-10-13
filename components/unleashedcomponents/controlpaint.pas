{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ControlPaint;

{$mode unleashed}
// the rasterizer runs its loops for every pixel of every paint
{$optimization level3}

// the colors, the smoothing and the small glyphs the custom drawn controls
// share. Every color resolves through the system colors, so a theme put on
// the application by TAppTheme reaches the controls the same way it reaches
// the native ones; without a theme the stock colors of the widgetset come back

interface

uses
  Classes, SysUtils, Types, Graphics, Controls, LCLType;

type
  TChevronDirection = (cdUp, cdDown, cdLeft, cdRight);
  // how the edges of the shapes blend into what is under them: not at all,
  // or with the share of each pixel they cover in 4, 9 or 256 steps
  TShapeAntialiasing = (aaOff, aaLow, aaMedium, aaHigh);
  // the smoothing of one control: after the theme, or its own choice
  TAntialiasSetting = (asTheme, asOff, asOn);
  // the names and separators a control formats dates, times and numbers
  // with: those of the locale of the system, or English with ISO dates and
  // a decimal point whatever the locale
  TFormatLanguage = (flSystem, flEnglish);
  // what a part painted by the application is in
  TDrawState = set of (dsHover, dsActive, dsSelected, dsPressed, dsDisabled, dsFocused, dsChecked);
  // paints one part of a control in place of the control; `handled` left
  // false lets the control paint the part as usual
  TCustomDrawEvent = procedure(Sender: TObject; canvas: TCanvas; const r: TRect; index: integer; state: TDrawState; var handled: boolean) of object;
  // a closed outline in the coordinates of the target canvas
  TOutline = array of TPointF;

  { TSmoothPaint }

  // shapes painted straight into memory a line at a time, each with the
  // exact share of every pixel it covers, so the edges blend into what is
  // under them alike on every widgetset. Flush puts the whole area onto the
  // target at once; text and images go onto the target after it and keep
  // their native look. A direct painter draws with the canvas of the target
  // instead, without smoothing, for a shape over a native element
  TSmoothPaint = class
  private
    FTarget: TCanvas;
    FRect, FClip: TRect; // the area on the target, the clip in the memory
    FWidth, FHeight, FSteps: integer;
    FPixels: array of cardinal;
    FDirect, FFlushed: boolean;
    function box(const outlines: array of TOutline; out ox, oy, w, h: integer): boolean;
    procedure accumulate(const outlines: array of TOutline; ox, oy, w, h: integer);
    procedure rasterize(const outlines: array of TOutline; color: TColor);
    procedure rasterizeUnion(const pieces: array of TOutline; color: TColor);
    procedure directPen(color: TColor; width: single);
  public
    constructor Create(target: TCanvas; const r: TRect; background: TColor; quality: TShapeAntialiasing);
    constructor CreateDirect(target: TCanvas);
    destructor Destroy; override;
    // a color as the memory holds it
    class function PackColor(color: TColor): cardinal;
    // a rectangle on whole pixels, its edges not blended
    procedure FillRect(const r: TRect; color: TColor);
    // a rectangle anywhere, its edge pixels blended
    procedure FillRectF(left, top, right, bottom: single; color: TColor);
    procedure FillPolygon(const points: array of TPointF; color: TColor);
    // the area inside the outlines; an outline running the other way inside
    // another cuts a hole
    procedure FillOutlines(const outlines: array of TOutline; color: TColor);
    // a line through the points, round at its bends; a closed one returns
    // to the first point
    procedure StrokePolyline(const points: array of TPointF; width: single; color: TColor; closed: boolean = false; roundCaps: boolean = true);
    procedure FillEllipse(cx, cy, rx, ry: single; color: TColor);
    // the band of `width` inside the edge of the ellipse
    procedure FrameEllipse(cx, cy, rx, ry, width: single; color: TColor);
    procedure FillRoundRect(left, top, right, bottom, radius: single; color: TColor);
    // the band of `width` inside the edge of the round rect
    procedure FrameRoundRect(left, top, right, bottom, radius, width: single; color: TColor);
    // dashes along the middle of the band a frame of `width` would take
    procedure DashRoundRect(left, top, right, bottom, radius, width, dash, gap: single; color: TColor);
    // a line along an ellipse, angles in degrees counterclockwise from 3 o'clock
    procedure StrokeArc(cx, cy, rx, ry, startDeg, sweepDeg, width: single; color: TColor; roundCaps: boolean);
    // the part `from` of the image scaled into `into`
    procedure DrawImage(image: TRasterImage; const from, into: TRect);
    // `w` by `h` pixels in the layout of the memory, a row after another,
    // with their top left corner at x, y
    procedure DrawPixels(x, y, w, h: integer; pixels: PCardinal);
    // the memory of row `y` from the left of the area, for code that writes
    // its pixels itself; nil outside the area and for a direct painter
    function Row(y: integer): PCardinal;
    // the shapes reach only into `r`
    procedure SetClip(const r: TRect);
    procedure ResetClip;
    // puts the area onto the target
    procedure Flush;
    property Direct: boolean read FDirect;
    property Area: TRect read FRect;
  end;

var
  // the smoothing of the controls that follow the theme; TAppTheme sets it
  shapeAntialiasing: TShapeAntialiasing = aaHigh;
  // the font quality of the text the controls draw; fqDefault leaves the
  // system choice
  textQuality: TFontQuality = fqDefault;

// a smooth painter over `r` of `canvas`, filled with `background`
function beginShapes(canvas: TCanvas; const r: TRect; background: TColor; setting: TAntialiasSetting): TSmoothPaint;
// the font quality of the theme onto a canvas before its text
procedure applyTextQuality(canvas: TCanvas);

// the fill under the mouse: the palette slot of the theme, otherwise the
// surface blended a little toward the text
function hoverColor(surface: TColor = clBtnFace): TColor;
// a border or a glyph under the mouse: `normal` moved toward `strong` as far
// as the theme lets a hover go; `strong` without a theme
function hoverShade(normal, strong: TColor): TColor;
// the ring of the focused control
function ringColor: TColor;
// the controls answer the mouse over them; a theme can switch that off
function hoverEnabled: boolean;
// the focused control carries a ring; a theme can switch that off
function ringEnabled: boolean;
// `color` unless it is clDefault, then `fallback`; both resolved to RGB
function pick(color, fallback: TColor): TColor;
// `a` moved `percent` of the way toward `b`
function blend(a, b: TColor; percent: integer): TColor;
// text that reads on `fill`: the window text on a light fill, white on a dark one
function contrastText(fill: TColor): TColor;
// the fill is on the dark side
function isDark(color: TColor): boolean;
// a pixel size at the control's DPI
function scaled(control: TControl; size: integer): integer;
// the format settings of a language, for FormatDateTime, Format and FloatToStr
function formatSettingsOf(language: TFormatLanguage): TFormatSettings;
// hands a part of a control to its custom draw handler over the painted
// background; true when the handler painted the part
function customDraw(control: TControl; canvas: TCanvas; handler: TCustomDrawEvent; const r: TRect; index: integer; state: TDrawState; background: TColor; antialiasing: TAntialiasSetting): boolean;
// a regular polygon of `sides` corners around a center, the first corner at
// `startDeg` (0 is to the right, 90 is up)
function polygonOutline(cx, cy, radius: single; sides: integer; startDeg: single): TOutline;

// the outlines of the shapes, in the coordinates of the target
function ellipseOutline(cx, cy, rx, ry: single; reverse: boolean = false): TOutline;
function roundRectOutline(left, top, right, bottom, radius: single; reverse: boolean = false): TOutline;

// fills `r` and frames it; a border of clNone leaves no frame
procedure paintRoundRect(sp: TSmoothPaint; const r: TRect; radius: integer; fill, border: TColor; borderWidth: integer=1);
// a pill: a round rect with the radius of its shorter side
procedure paintPill(sp: TSmoothPaint; const r: TRect; fill, border: TColor);
// a circle around the middle of pixel cx, cy
procedure paintCircle(sp: TSmoothPaint; cx, cy, radius: integer; fill, border: TColor; borderWidth: integer=1);
// a line through the middles of the two pixels
procedure paintLine(sp: TSmoothPaint; x1, y1, x2, y2: integer; color: TColor; width: integer=1);
// a chevron glyph centered in `r`, `size` wide
procedure paintChevron(sp: TSmoothPaint; const r: TRect; dir: TChevronDirection; size: integer; color: TColor);
// a cross glyph centered in `r`
procedure paintCross(sp: TSmoothPaint; const r: TRect; size: integer; color: TColor; thickness: integer=2);
// a check mark glyph centered in `r`
procedure paintCheck(sp: TSmoothPaint; const r: TRect; size: integer; color: TColor; thickness: integer=2);
// a magnifier glyph centered in `r`
procedure paintMagnifier(sp: TSmoothPaint; const r: TRect; size: integer; color: TColor);
// the ring around a focused control, one pixel inside `r`
procedure paintRing(sp: TSmoothPaint; const r: TRect; radius: integer);
// an arc of a circle, angles in degrees counterclockwise from 3 o'clock
procedure paintArc(sp: TSmoothPaint; const box: TRect; startDeg, sweepDeg: integer; color: TColor; width: integer; roundCaps: boolean);
// text centered in `r`, clipped to it
procedure paintCenteredText(canvas: TCanvas; const r: TRect; const text: string; color: TColor);
// the height of a line in `font` and the width of `text` in it, measured
// once and then remembered; a layout asks for them on every pass
function lineHeightOf(font: TFont): integer;
function textWidthOf(font: TFont; const text: string): integer;
// the first fixed pitch face the system has, from the ones that render well
function monospaceFontName: string;
// a popup window the clicks never activate, so the form behind keeps its
// look and the focus; nothing to do outside Windows
procedure keepInactive(wnd: HWND);
// a translucent top level window whose pixels of `keyColor` are see-through;
// a layered window ignores its region, so the key cuts its corners instead.
// Call it again after every change of the alpha, the LCL resets the key.
// False where the window system has no such windows
function layeredWindow(wnd: HWND; alpha: byte; keyColor: TColor): boolean;
// paints at once what waits to be painted in the control and the windows in
// it; while the mouse keeps moving, the paint messages wait for it to stop
procedure paintNow(control: TWinControl);

implementation

uses
  Math, LCLIntf, IntfGraphics, GraphType, FPImage, Forms, ThemesPalette, ThemesEngine;

// -- the rasterizer ----------------------

// The memory of a shape's box holds the signed area every edge leaves in
// each cell; the running sum along a row is then the share of each pixel
// inside the shape. A mark for every 16 cells of a row tells where the
// edges are, so a row goes over the cells between them at once. The
// buffers are left zeroed after each use
const
  BLOCK_SHIFT = 4;
  BLOCK_MASK = 15;

var
  areaBuf: array of single;
  markBuf: array of byte;
  unionBuf: array of single;
  spanBuf: array of integer; // the first and the last cell taken in each row of the union

procedure needArea(cells, marks: integer);
begin
  if length(areaBuf) < cells then begin
    areaBuf := nil;
    SetLength(areaBuf, cells);
  end;
  if length(markBuf) < marks then begin
    markBuf := nil;
    SetLength(markBuf, marks);
  end;
end;

procedure needUnion(cells, rows: integer);
begin
  if length(unionBuf) < cells then begin
    unionBuf := nil;
    SetLength(unionBuf, cells);
  end;
  if length(spanBuf) < 2*rows then SetLength(spanBuf, 2*rows);
end;

// adds the area an edge from x0,y0 to x1,y1 leaves in the cells of a box of
// `w` cells by `h` rows, and marks the blocks it touches; the rows are
// `stride` cells apart, two more than w, and have `blocks` marks each
procedure addEdge(acc: PSingle; marks: PByte; stride, blocks, w, h: integer; x0, y0, x1, y1: single);
var
  dir, dxdy, x, xnext, d, dy, xa, xb, x0f, x1f, s, a0, a1, a2, am, top: single;
  y, ystart, yend, x0i, x1i, i: integer;
  row: PSingle;
begin
  if y0 = y1 then exit;
  if y0 < y1 then dir := 1
  else begin
    dir := -1;
    s := x0;
    x0 := x1;
    x1 := s;
    s := y0;
    y0 := y1;
    y1 := s;
  end;
  if (y1 <= 0) or (y0 >= h) then exit;
  dxdy := (x1-x0)/(y1-y0);
  x := x0;
  ystart := 0;
  if y0 < 0 then x := x0-y0*dxdy
  else ystart := Trunc(y0);
  yend := Trunc(y1);
  if yend < y1 then inc(yend);
  if yend > h then yend := h;
  for y := ystart to yend-1 do begin
    row := acc+y*stride;
    top := if y > y0 then y else y0;
    dy := (if y+1 < y1 then y+1 else y1)-top;
    xnext := x+dxdy*dy;
    d := dy*dir;
    if x < xnext then begin
      xa := x;
      xb := xnext;
    end else begin
      xa := xnext;
      xb := x;
    end;
    // an edge beside the box counts at its side
    if xa < 0 then xa := 0 else if xa > w then xa := w;
    if xb < 0 then xb := 0 else if xb > w then xb := w;
    x0i := Trunc(xa);
    x1i := Trunc(xb);
    if x1i < xb then inc(x1i);
    if x1i <= x0i+1 then begin
      s := 0.5*(xa+xb)-x0i;
      row[x0i] += d-d*s;
      row[x0i+1] += d*s;
      x1i := x0i+1;
    end else begin
      s := 1/(xb-xa);
      x0f := xa-x0i;
      a0 := 0.5*s*(1-x0f)*(1-x0f);
      x1f := xb-x1i+1;
      am := 0.5*s*x1f*x1f;
      row[x0i] += d*a0;
      if x1i = x0i+2 then row[x0i+1] += d*(1-a0-am)
      else begin
        a1 := s*(1.5-x0f);
        row[x0i+1] += d*(a1-a0);
        for i := x0i+2 to x1i-2 do row[i] += d*s;
        a2 := a1+(x1i-x0i-3)*s;
        row[x1i-1] += d*(1-a2-am);
      end;
      row[x1i] += d*am;
    end;
    for i := x0i shr BLOCK_SHIFT to x1i shr BLOCK_SHIFT do marks[y*blocks+i] := 1;
    x := xnext;
  end;
end;

// the weight of a coverage after the smoothing steps, 0 to 256
function weight(cover: single; steps: integer): cardinal; inline;
begin
  if cover < 0 then cover := -cover;
  if cover >= 1 then exit(256);
  match steps of
    0: result := Trunc(cover*256+0.5);
    1: result := if cover >= 0.5 then 256 else 0;
  else
    result := Trunc(Round(cover*steps)/steps*256+0.5);
  end;
end;

// `color` laid over `pixel` with `a` of 256; two channels go at once
function mixPixel(pixel, color, a: cardinal): cardinal; inline;
begin
  var b := 256-a;
  result := (((color and $FF00FF)*a+(pixel and $FF00FF)*b) shr 8) and $FF00FF;
  result := result or ((((color and $FF00)*a+(pixel and $FF00)*b) shr 8) and $FF00) or $FF000000;
end;

class function TSmoothPaint.PackColor(color: TColor): cardinal;
begin
  var c := cardinal(ColorToRGB(color));
  result := $FF000000 or ((c and $FF) shl 16) or (c and $FF00) or ((c shr 16) and $FF);
end;

constructor TSmoothPaint.Create(target: TCanvas; const r: TRect; background: TColor; quality: TShapeAntialiasing);
begin
  inherited Create;
  FTarget := target;
  FRect := r;
  FWidth := Max(r.Width, 0);
  FHeight := Max(r.Height, 0);
  FSteps := match quality of
    aaOff: 1;
    aaLow: 4;
    aaMedium: 9;
  else
    0
  end;
  ResetClip;
  if (FWidth = 0) or (FHeight = 0) then exit;
  SetLength(FPixels, FWidth*FHeight);
  var c := PackColor(background);
  var p := PCardinal(@FPixels[0]);
  for var i := 0 to FWidth*FHeight-1 do p[i] := c;
end;

constructor TSmoothPaint.CreateDirect(target: TCanvas);
begin
  inherited Create;
  FTarget := target;
  FDirect := true;
end;

destructor TSmoothPaint.Destroy;
begin
  Flush;
  inherited Destroy;
end;

procedure TSmoothPaint.SetClip(const r: TRect);
begin
  FClip := Rect(Max(r.Left-FRect.Left, 0), Max(r.Top-FRect.Top, 0), Min(r.Right-FRect.Left, FWidth), Min(r.Bottom-FRect.Top, FHeight));
end;

procedure TSmoothPaint.ResetClip;
begin
  FClip := Rect(0, 0, FWidth, FHeight);
end;

function TSmoothPaint.Row(y: integer): PCardinal;
begin
  if FDirect or (y < FRect.Top) or (y >= FRect.Bottom) or (FWidth = 0) then exit(nil);
  result := @FPixels[(y-FRect.Top)*FWidth];
end;

// the pixels the outlines may touch, in the memory, within the clip
function TSmoothPaint.box(const outlines: array of TOutline; out ox, oy, w, h: integer): boolean;
begin
  var minX := MaxSingle;
  var minY := MaxSingle;
  var maxX := -MaxSingle;
  var maxY := -MaxSingle;
  for var o in outlines do
    for var p in o do begin
      if p.X < minX then minX := p.X;
      if p.X > maxX then maxX := p.X;
      if p.Y < minY then minY := p.Y;
      if p.Y > maxY then maxY := p.Y;
    end;
  if minX > maxX then exit(false);
  ox := Max(Floor(minX)-FRect.Left, FClip.Left);
  oy := Max(Floor(minY)-FRect.Top, FClip.Top);
  w := Min(Ceil(maxX)-FRect.Left, FClip.Right)-ox;
  h := Min(Ceil(maxY)-FRect.Top, FClip.Bottom)-oy;
  result := (w > 0) and (h > 0);
end;

// the edges of the outlines into the cells of the box at ox, oy of the
// memory, w by h
procedure TSmoothPaint.accumulate(const outlines: array of TOutline; ox, oy, w, h: integer);
begin
  var stride := w+2;
  var blocks := (stride-1) shr BLOCK_SHIFT+1;
  needArea(stride*h, blocks*h);
  var acc := PSingle(@areaBuf[0]);
  var marks := PByte(@markBuf[0]);
  var fx: single := FRect.Left+ox;
  var fy: single := FRect.Top+oy;
  for var o in outlines do begin
    var n := length(o);
    if n < 3 then continue;
    for var i := 0 to n-1 do begin
      var a := o[i];
      var b := o[if i = n-1 then 0 else i+1];
      addEdge(acc, marks, stride, blocks, w, h, a.X-fx, a.Y-fy, b.X-fx, b.Y-fy);
    end;
  end;
end;

procedure TSmoothPaint.rasterize(const outlines: array of TOutline; color: TColor);
var
  ox, oy, w, h: integer;
begin
  if not box(outlines, ox, oy, w, h) then exit;
  accumulate(outlines, ox, oy, w, h);
  var stride := w+2;
  var blocks := (stride-1) shr BLOCK_SHIFT+1;
  var c := PackColor(color);
  for var y := 0 to h-1 do begin
    var row := PSingle(@areaBuf[y*stride]);
    var marks := PByte(@markBuf[y*blocks]);
    var pix := PCardinal(@FPixels[(oy+y)*FWidth+ox]);
    var sum: single := 0;
    var a: cardinal := 0;
    var x := 0;
    while x < w do begin
      var e := Min((x or BLOCK_MASK)+1, w);
      if marks[x shr BLOCK_SHIFT] <> 0 then
        for var i := x to e-1 do begin
          if row[i] <> 0 then begin
            sum += row[i];
            row[i] := 0;
            a := weight(sum, FSteps);
          end;
          if a >= 256 then pix[i] := c
          else if a > 0 then pix[i] := mixPixel(pix[i], c, a);
        end
      else begin
        // no edge in these cells and the ones after, the share stays
        while (e < w) and (marks[e shr BLOCK_SHIFT] = 0) do e := Min(e+BLOCK_MASK+1, w);
        if a >= 256 then FillDWord(pix[x], e-x, c)
        else if a > 0 then
          for var i := x to e-1 do pix[i] := mixPixel(pix[i], c, a);
      end;
      x := e;
    end;
    row[w] := 0;
    row[w+1] := 0;
    FillChar(marks^, blocks, 0);
  end;
end;

// pieces that overlap, as the parts of a stroke, joined by their larger
// coverage so the overlaps do not darken the edges
procedure TSmoothPaint.rasterizeUnion(const pieces: array of TOutline; color: TColor);
var
  ux, uy, uw, uh, ox, oy, w, h: integer;
begin
  if not box(pieces, ux, uy, uw, uh) then exit;
  needUnion(uw*uh, uh);
  var union := PSingle(@unionBuf[0]);
  var spans := PInteger(@spanBuf[0]);
  for var y := 0 to uh-1 do begin
    spans[2*y] := uw;
    spans[2*y+1] := -1;
  end;
  for var piece in pieces do begin
    if length(piece) < 3 then continue;
    if not box([piece], ox, oy, w, h) then continue;
    accumulate([piece], ox, oy, w, h);
    var stride := w+2;
    var blocks := (stride-1) shr BLOCK_SHIFT+1;
    for var y := 0 to h-1 do begin
      var row := PSingle(@areaBuf[y*stride]);
      var marks := PByte(@markBuf[y*blocks]);
      var line := oy-uy+y;
      var dst := union+line*uw+(ox-ux);
      var sum: single := 0;
      var cover: single := 0;
      var first := w;
      var last := -1;
      var x := 0;
      while x < w do begin
        var e := Min((x or BLOCK_MASK)+1, w);
        if marks[x shr BLOCK_SHIFT] <> 0 then
          for var i := x to e-1 do begin
            if row[i] <> 0 then begin
              sum += row[i];
              row[i] := 0;
              cover := Abs(sum);
              // what the rounding leaves past a shape is nothing
              if cover < 1/1024 then cover := 0;
            end;
            if cover > 0 then begin
              if cover > dst[i] then dst[i] := cover;
              if i < first then first := i;
              last := i;
            end;
          end
        else if cover > 0 then begin
          for var i := x to e-1 do if cover > dst[i] then dst[i] := cover;
          if x < first then first := x;
          last := e-1;
        end;
        x := e;
      end;
      row[w] := 0;
      row[w+1] := 0;
      FillChar(marks^, blocks, 0);
      if last >= first then begin
        spans[2*line] := Min(spans[2*line], first+ox-ux);
        spans[2*line+1] := Max(spans[2*line+1], last+ox-ux);
      end;
    end;
  end;
  var c := PackColor(color);
  for var y := 0 to uh-1 do begin
    var src := union+y*uw;
    var pix := PCardinal(@FPixels[(uy+y)*FWidth+ux]);
    for var x := spans[2*y] to spans[2*y+1] do begin
      var a := weight(src[x], FSteps);
      src[x] := 0;
      if a >= 256 then pix[x] := c
      else if a > 0 then pix[x] := mixPixel(pix[x], c, a);
    end;
  end;
end;

// -- outlines ----------------------

// chords of a curve of radius `r` stay within a tenth of a pixel of it
function segmentsFor(r, sweepRad: single): integer;
begin
  if r < 0.5 then exit(Max(Ceil(Abs(sweepRad)/(Pi/4)), 2));
  var stepAngle := 2*ArcCos(Max(1-0.1/r, -1));
  result := Max(Ceil(Abs(sweepRad)/stepAngle), Max(Ceil(Abs(sweepRad)/(Pi/4)), 2));
end;

function ellipseOutline(cx, cy, rx, ry: single; reverse: boolean): TOutline;
begin
  var n := segmentsFor(Max(rx, ry), 2*Pi);
  SetLength(result, n);
  for var i := 0 to n-1 do begin
    var a := 2*Pi*i/n;
    if reverse then a := -a;
    result[i] := PointF(cx+rx*Cos(a), cy+ry*Sin(a));
  end;
end;

// the four corners as quarter circles, clockwise on the screen
function roundRectOutline(left, top, right, bottom, radius: single; reverse: boolean): TOutline;
begin
  radius := Min(radius, Min(right-left, bottom-top)/2);
  if radius <= 0.01 then result := [PointF(left, top), PointF(right, top), PointF(right, bottom), PointF(left, bottom)]
  else begin
    var n := segmentsFor(radius, Pi/2);
    SetLength(result, 4*(n+1));
    var centers: array of TPointF := [PointF(left+radius, top+radius), PointF(right-radius, top+radius), PointF(right-radius, bottom-radius), PointF(left+radius, bottom-radius)];
    var k := 0;
    for var corner := 0 to 3 do
      for var i := 0 to n do begin
        // from 180 degrees on, a quarter for each corner
        var a := Pi+corner*Pi/2+(Pi/2)*i/n;
        result[k] := PointF(centers[corner].X+radius*Cos(a), centers[corner].Y+radius*Sin(a));
        inc(k);
      end;
  end;
  if reverse then
    for var i := 0 to length(result) div 2-1 do begin
      var t := result[i];
      result[i] := result[length(result)-1-i];
      result[length(result)-1-i] := t;
    end;
end;

// the pieces of a stroke: a quad for every segment, a disc at every bend
// and at the ends when the caps are round
function strokePieces(const points: array of TPointF; width: single; closed, roundCaps: boolean): array of TOutline;
begin
  result := [];
  var n := length(points);
  if n = 0 then exit;
  var hw := width/2;
  var segments := if closed then n else n-1;
  for var i := 0 to segments-1 do begin
    var a := points[i];
    var b := points[(i+1) mod n];
    var dx := b.X-a.X;
    var dy := b.Y-a.Y;
    var len := Sqrt(dx*dx+dy*dy);
    if len < 1e-4 then continue;
    var nx := -dy/len*hw;
    var ny := dx/len*hw;
    var quad: TOutline := [PointF(a.X+nx, a.Y+ny), PointF(b.X+nx, b.Y+ny), PointF(b.X-nx, b.Y-ny), PointF(a.X-nx, a.Y-ny)];
    result += [quad];
  end;
  for var i := 0 to n-1 do begin
    var bend := closed or ((i > 0) and (i < n-1));
    if bend or roundCaps then result += [ellipseOutline(points[i].X, points[i].Y, hw, hw)];
  end;
end;

// -- painting ----------------------

procedure TSmoothPaint.directPen(color: TColor; width: single);
begin
  FTarget.Pen.Style := psSolid;
  FTarget.Pen.Color := color;
  FTarget.Pen.Width := Max(Round(width), 1);
end;

procedure TSmoothPaint.FillRect(const r: TRect; color: TColor);
begin
  if FDirect then begin
    FTarget.Brush.Style := bsSolid;
    FTarget.Brush.Color := color;
    FTarget.FillRect(r);
    exit;
  end;
  var x0 := Max(r.Left-FRect.Left, FClip.Left);
  var x1 := Min(r.Right-FRect.Left, FClip.Right);
  var y0 := Max(r.Top-FRect.Top, FClip.Top);
  var y1 := Min(r.Bottom-FRect.Top, FClip.Bottom);
  if (x1 <= x0) or (y1 <= y0) then exit;
  var c := PackColor(color);
  for var y := y0 to y1-1 do begin
    var pix := PCardinal(@FPixels[y*FWidth]);
    for var x := x0 to x1-1 do pix[x] := c;
  end;
end;

procedure TSmoothPaint.FillRectF(left, top, right, bottom: single; color: TColor);
begin
  if FDirect then FillRect(Rect(Round(left), Round(top), Round(right), Round(bottom)), color)
  else begin
    var r: TOutline := [PointF(left, top), PointF(right, top), PointF(right, bottom), PointF(left, bottom)];
    rasterize([r], color);
  end;
end;

procedure TSmoothPaint.FillPolygon(const points: array of TPointF; color: TColor);
begin
  if FDirect then begin
    var pts: array of TPoint := [];
    for var p in points do pts += [Point(Trunc(p.X), Trunc(p.Y))];
    FTarget.Brush.Style := bsSolid;
    FTarget.Brush.Color := color;
    directPen(color, 1);
    FTarget.Polygon(pts);
    exit;
  end;
  var o: TOutline := [];
  for var p in points do o += [p];
  rasterize([o], color);
end;

procedure TSmoothPaint.FillOutlines(const outlines: array of TOutline; color: TColor);
begin
  if FDirect then begin
    for var o in outlines do FillPolygon(o, color);
    exit;
  end;
  rasterize(outlines, color);
end;

procedure TSmoothPaint.StrokePolyline(const points: array of TPointF; width: single; color: TColor; closed, roundCaps: boolean);
begin
  if FDirect then begin
    var pts: array of TPoint := [];
    for var p in points do pts += [Point(Trunc(p.X), Trunc(p.Y))];
    if closed and (length(pts) > 0) then pts += [pts[0]];
    directPen(color, width);
    FTarget.Pen.EndCap := if roundCaps then pecRound else pecFlat;
    FTarget.Polyline(pts);
    FTarget.Pen.EndCap := pecRound;
    FTarget.Pen.Width := 1;
    exit;
  end;
  rasterizeUnion(strokePieces(points, width, closed, roundCaps), color);
end;

procedure TSmoothPaint.FillEllipse(cx, cy, rx, ry: single; color: TColor);
begin
  if FDirect then begin
    FTarget.Brush.Style := bsSolid;
    FTarget.Brush.Color := color;
    FTarget.Pen.Style := psClear;
    FTarget.Ellipse(Round(cx-rx), Round(cy-ry), Round(cx+rx), Round(cy+ry));
    FTarget.Pen.Style := psSolid;
    exit;
  end;
  rasterize([ellipseOutline(cx, cy, rx, ry)], color);
end;

procedure TSmoothPaint.FrameEllipse(cx, cy, rx, ry, width: single; color: TColor);
begin
  if FDirect then begin
    var half := Max(Round(width), 1) div 2;
    FTarget.Brush.Style := bsClear;
    directPen(color, width);
    FTarget.Ellipse(Round(cx-rx)+half, Round(cy-ry)+half, Round(cx+rx)-half, Round(cy+ry)-half);
    FTarget.Brush.Style := bsSolid;
    FTarget.Pen.Width := 1;
    exit;
  end;
  if (rx-width <= 0) or (ry-width <= 0) then rasterize([ellipseOutline(cx, cy, rx, ry)], color)
  else rasterize([ellipseOutline(cx, cy, rx, ry), ellipseOutline(cx, cy, rx-width, ry-width, true)], color);
end;

procedure TSmoothPaint.FillRoundRect(left, top, right, bottom, radius: single; color: TColor);
begin
  if FDirect then begin
    FTarget.Brush.Style := bsSolid;
    FTarget.Brush.Color := color;
    FTarget.Pen.Style := psClear;
    if radius <= 0 then FTarget.Rectangle(Round(left), Round(top), Round(right), Round(bottom))
    else FTarget.RoundRect(Round(left), Round(top), Round(right), Round(bottom), Round(radius*2), Round(radius*2));
    FTarget.Pen.Style := psSolid;
    exit;
  end;
  // a rectangle on whole pixels needs no blending at all
  if (radius <= 0) and (Frac(left) = 0) and (Frac(top) = 0) and (Frac(right) = 0) and (Frac(bottom) = 0) then
    FillRect(Rect(Trunc(left), Trunc(top), Trunc(right), Trunc(bottom)), color)
  else rasterize([roundRectOutline(left, top, right, bottom, radius)], color);
end;

procedure TSmoothPaint.FrameRoundRect(left, top, right, bottom, radius, width: single; color: TColor);
begin
  if FDirect then begin
    var half := Max(Round(width), 1) div 2;
    FTarget.Brush.Style := bsClear;
    directPen(color, width);
    if radius <= 0 then FTarget.Rectangle(Round(left)+half, Round(top)+half, Round(right)-half, Round(bottom)-half)
    else FTarget.RoundRect(Round(left)+half, Round(top)+half, Round(right)-half, Round(bottom)-half, Round(radius*2), Round(radius*2));
    FTarget.Brush.Style := bsSolid;
    FTarget.Pen.Width := 1;
    exit;
  end;
  if (right-left <= 2*width) or (bottom-top <= 2*width) then rasterize([roundRectOutline(left, top, right, bottom, radius)], color)
  else rasterize([roundRectOutline(left, top, right, bottom, radius), roundRectOutline(left+width, top+width, right-width, bottom-width, Max(radius-width, 0), true)], color);
end;

procedure TSmoothPaint.DashRoundRect(left, top, right, bottom, radius, width, dash, gap: single; color: TColor);
begin
  if FDirect or (dash <= 0) then begin
    FrameRoundRect(left, top, right, bottom, radius, width, color);
    exit;
  end;
  // the middle line of the band, cut into dashes along its length
  var half := width/2;
  var path := roundRectOutline(left+half, top+half, right-half, bottom-half, Max(radius-half, 0));
  if length(path) < 2 then exit;
  path += [path[0]];
  // the pattern stretched a little, so it closes on itself
  var total: single := 0;
  for var i := 0 to length(path)-2 do total += Sqrt(Sqr(path[i+1].X-path[i].X)+Sqr(path[i+1].Y-path[i].Y));
  var stretch := total/(Max(Round(total/(dash+gap)), 1)*(dash+gap));
  dash *= stretch;
  gap *= stretch;
  var pieces: array of TOutline := [];
  var run: array of TPointF := [];
  var inDash := true;
  var remaining := dash;
  for var i := 0 to length(path)-2 do begin
    var a := path[i];
    var b := path[i+1];
    var len := Sqrt(Sqr(b.X-a.X)+Sqr(b.Y-a.Y));
    var pos: single := 0;
    if inDash and (length(run) = 0) then run := [a];
    while len-pos > remaining do begin
      pos += remaining;
      var t := pos/len;
      var p := PointF(a.X+(b.X-a.X)*t, a.Y+(b.Y-a.Y)*t);
      if inDash then begin
        run += [p];
        for var piece in strokePieces(run, width, false, false) do pieces += [piece];
        run := [];
        remaining := gap;
      end else begin
        run := [p];
        remaining := dash;
      end;
      inDash := not inDash;
    end;
    remaining -= len-pos;
    if inDash then run += [b];
  end;
  if inDash and (length(run) > 1) then
    for var piece in strokePieces(run, width, false, false) do pieces += [piece];
  rasterizeUnion(pieces, color);
end;

procedure TSmoothPaint.StrokeArc(cx, cy, rx, ry, startDeg, sweepDeg, width: single; color: TColor; roundCaps: boolean);
begin
  if FDirect then begin
    var half := Max(Round(width), 1) div 2;
    directPen(color, width);
    FTarget.Pen.EndCap := if roundCaps then pecRound else pecFlat;
    FTarget.Arc(Round(cx-rx-half), Round(cy-ry-half), Round(cx+rx+half), Round(cy+ry+half), Round(startDeg*16), Round(sweepDeg*16));
    FTarget.Pen.EndCap := pecRound;
    FTarget.Pen.Width := 1;
    exit;
  end;
  var hw := width/2;
  var a0 := DegToRad(startDeg);
  var sweep := DegToRad(sweepDeg);
  var n := segmentsFor(Max(rx, ry)+hw, sweep);
  // the outer edge forward and the inner one back; y grows downward, so the
  // angle turns counterclockwise with a minus on the sine
  var band: TOutline := [];
  for var i := 0 to n do begin
    var a := a0+sweep*i/n;
    band += [PointF(cx+(rx+hw)*Cos(a), cy-(ry+hw)*Sin(a))];
  end;
  var irx := Max(rx-hw, 0);
  var iry := Max(ry-hw, 0);
  for var i := n downto 0 do begin
    var a := a0+sweep*i/n;
    band += [PointF(cx+irx*Cos(a), cy-iry*Sin(a))];
  end;
  if not roundCaps then rasterize([band], color)
  else rasterizeUnion([band, ellipseOutline(cx+rx*Cos(a0), cy-ry*Sin(a0), hw, hw), ellipseOutline(cx+rx*Cos(a0+sweep), cy-ry*Sin(a0+sweep), hw, hw)], color);
end;

// each pixel of `into` takes the mean of the source area it covers, or the
// blend of the four nearest source pixels when the image grows
procedure TSmoothPaint.DrawImage(image: TRasterImage; const from, into: TRect);
begin
  if (from.Width <= 0) or (from.Height <= 0) or (into.Width <= 0) or (into.Height <= 0) then exit;
  if FDirect then begin
    FTarget.CopyRect(into, image.Canvas, from);
    exit;
  end;
  var src := image.CreateIntfImage;
  try
    var sw := src.Width;
    var sh := src.Height;
    var cells: array of cardinal := [];
    SetLength(cells, sw*sh);
    // the source in the layout of the memory, a row at a time
    var d := src.DataDescription;
    var fast := (d.BitsPerPixel = 32) and (d.ByteOrder = riboLSBFirst) and (d.RedPrec = 8) and (d.GreenPrec = 8) and (d.BluePrec = 8);
    for var y := 0 to sh-1 do
      if fast then begin
        var line := PCardinal(src.GetDataLineStart(y));
        for var x := 0 to sw-1 do begin
          var v := line[x];
          cells[y*sw+x] := $FF000000 or (((v shr d.RedShift) and $FF) shl 16) or (((v shr d.GreenShift) and $FF) shl 8) or ((v shr d.BlueShift) and $FF);
        end;
      end else
        for var x := 0 to sw-1 do begin
          var c := src.Colors[x, y];
          cells[y*sw+x] := $FF000000 or (cardinal(c.Red shr 8) shl 16) or (cardinal(c.Green shr 8) shl 8) or cardinal(c.Blue shr 8);
        end;
    var scaleX := from.Width/into.Width;
    var scaleY := from.Height/into.Height;
    var x0 := Max(into.Left-FRect.Left, FClip.Left);
    var x1 := Min(into.Right-FRect.Left, FClip.Right);
    var y0 := Max(into.Top-FRect.Top, FClip.Top);
    var y1 := Min(into.Bottom-FRect.Top, FClip.Bottom);
    for var y := y0 to y1-1 do begin
      var pix := PCardinal(@FPixels[y*FWidth]);
      var sy0 := from.Top+(y+FRect.Top-into.Top)*scaleY;
      var sy1 := sy0+scaleY;
      for var x := x0 to x1-1 do begin
        var sx0 := from.Left+(x+FRect.Left-into.Left)*scaleX;
        var sx1 := sx0+scaleX;
        var r, g, b, total: single;
        r := 0;
        g := 0;
        b := 0;
        total := 0;
        if (scaleX >= 1) and (scaleY >= 1) then begin
          // the mean of the covered source pixels, the cut ones by their share
          for var yy := Max(Floor(sy0), 0) to Min(Ceil(sy1), sh)-1 do begin
            var wy := Min(sy1, yy+1)-Max(sy0, yy);
            if wy <= 0 then continue;
            for var xx := Max(Floor(sx0), 0) to Min(Ceil(sx1), sw)-1 do begin
              var wx := Min(sx1, xx+1)-Max(sx0, xx);
              if wx <= 0 then continue;
              var v := cells[yy*sw+xx];
              var wgt := wx*wy;
              r += ((v shr 16) and $FF)*wgt;
              g += ((v shr 8) and $FF)*wgt;
              b += (v and $FF)*wgt;
              total += wgt;
            end;
          end;
        end else begin
          // the blend of the four source pixels around the middle
          var cx := (sx0+sx1)/2-0.5;
          var cy := (sy0+sy1)/2-0.5;
          var ix := Floor(cx);
          var iy := Floor(cy);
          var fx := cx-ix;
          var fy := cy-iy;
          for var k := 0 to 3 do begin
            var px := EnsureRange(ix+(k and 1), 0, sw-1);
            var py := EnsureRange(iy+(k shr 1), 0, sh-1);
            var wgt := (if (k and 1) = 0 then 1-fx else fx)*(if (k shr 1) = 0 then 1-fy else fy);
            var v := cells[py*sw+px];
            r += ((v shr 16) and $FF)*wgt;
            g += ((v shr 8) and $FF)*wgt;
            b += (v and $FF)*wgt;
            total += wgt;
          end;
        end;
        if total > 0 then pix[x] := $FF000000 or (cardinal(Round(r/total)) shl 16) or (cardinal(Round(g/total)) shl 8) or cardinal(Round(b/total));
      end;
    end;
  finally
    src.Free;
  end;
end;

{$ifdef WINDOWS}
type
  // BITMAPINFOHEADER
  TDibHeader = record
    size: longword;
    width, height: longint;
    planes, bitCount: word;
    compression, sizeImage: longword;
    xPelsPerMeter, yPelsPerMeter: longint;
    clrUsed, clrImportant: longword;
  end;

function setDIBitsToDevice(dc: HDC; x, y: longint; w, h: longword; srcX, srcY: longint; startScan, lines: longword; bits, info: Pointer; usage: longword): longint; stdcall; external 'gdi32' name 'SetDIBitsToDevice';
{$endif}

// the pixels onto the canvas at x, y
procedure drawRaw(canvas: TCanvas; x, y, w, h: integer; pixels: PCardinal);
begin
  {$ifdef WINDOWS}
  // straight from the memory; a bitmap of the LCL made for every paint
  // costs many times more
  var header := Default(TDibHeader);
  header.size := SizeOf(header);
  header.width := w;
  header.height := -h; // top down
  header.planes := 1;
  header.bitCount := 32;
  canvas.Changing;
  setDIBitsToDevice(canvas.Handle, x, y, w, h, 0, 0, 0, h, pixels, @header, 0);
  canvas.Changed;
  {$else}
  var raw: TRawImage;
  raw.Init;
  raw.Description.Init_BPP32_B8G8R8_BIO_TTB(w, h);
  raw.Data := PByte(pixels);
  raw.DataSize := PtrUInt(w)*PtrUInt(h)*4;
  var bmp := autofree TBitmap.Create;
  bmp.LoadFromRawImage(raw, false);
  canvas.Draw(x, y, bmp);
  {$endif}
end;

procedure TSmoothPaint.DrawPixels(x, y, w, h: integer; pixels: PCardinal);
begin
  if (w <= 0) or (h <= 0) then exit;
  if FDirect then begin
    drawRaw(FTarget, x, y, w, h, pixels);
    exit;
  end;
  var x0 := Max(x-FRect.Left, FClip.Left);
  var x1 := Min(x+w-FRect.Left, FClip.Right);
  var y0 := Max(y-FRect.Top, FClip.Top);
  var y1 := Min(y+h-FRect.Top, FClip.Bottom);
  if (x1 <= x0) or (y1 <= y0) then exit;
  for var row := y0 to y1-1 do
    Move(pixels[(row+FRect.Top-y)*w+x0+FRect.Left-x], FPixels[row*FWidth+x0], (x1-x0)*SizeOf(cardinal));
end;

procedure TSmoothPaint.Flush;
begin
  if FFlushed or FDirect then exit;
  FFlushed := true;
  if (FWidth = 0) or (FHeight = 0) then exit;
  drawRaw(FTarget, FRect.Left, FRect.Top, FWidth, FHeight, @FPixels[0]);
  FPixels := nil;
end;

function beginShapes(canvas: TCanvas; const r: TRect; background: TColor; setting: TAntialiasSetting): TSmoothPaint;
begin
  var quality := match setting of
    asOff: aaOff;
    asOn: aaHigh;
  else
    shapeAntialiasing
  end;
  result := TSmoothPaint.Create(canvas, r, background, quality);
end;

procedure applyTextQuality(canvas: TCanvas);
begin
  if textQuality <> fqDefault then canvas.Font.Quality := textQuality;
end;

// -- colors ----------------------

function hoverColor(surface: TColor): TColor;
begin
  result := if themeActive then currentPalette[COLOR_HOVER] else blend(surface, clWindowText, 20);
end;

function hoverShade(normal, strong: TColor): TColor;
begin
  result := if themeActive then ThemesPalette.hoverShade(currentPalette, normal, strong) else ColorToRGB(strong);
end;

function ringColor: TColor;
begin
  result := if themeActive then focusColor(currentPalette) else blend(clBtnShadow, clHotLight, 50);
end;

function hoverEnabled: boolean;
begin
  result := (not themeActive) or themeEffects.Hover;
end;

function ringEnabled: boolean;
begin
  result := (not themeActive) or themeEffects.Active;
end;

function pick(color, fallback: TColor): TColor;
begin
  result := ColorToRGB(if color = clDefault then fallback else color);
end;

function blend(a, b: TColor; percent: integer): TColor;
begin
  result := mix(ColorToRGB(a), ColorToRGB(b), percent);
end;

function isDark(color: TColor): boolean;
begin
  color := ColorToRGB(color);
  result := (Red(color)*299+Green(color)*587+Blue(color)*114) div 1000 < 128;
end;

function contrastText(fill: TColor): TColor;
begin
  result := if isDark(fill) then clWhite else ColorToRGB(clWindowText);
end;

function scaled(control: TControl; size: integer): integer;
begin
  result := control.Scale96ToFont(size);
end;

// -- shapes ----------------------

procedure paintRoundRect(sp: TSmoothPaint; const r: TRect; radius: integer; fill, border: TColor; borderWidth: integer);
begin
  var rad := Max(radius, 0);
  if fill <> clNone then sp.FillRoundRect(r.Left, r.Top, r.Right, r.Bottom, rad, fill);
  if border <> clNone then sp.FrameRoundRect(r.Left, r.Top, r.Right, r.Bottom, rad, Max(borderWidth, 1), border);
end;

procedure paintPill(sp: TSmoothPaint; const r: TRect; fill, border: TColor);
begin
  var d := if r.Width < r.Height then r.Width else r.Height;
  paintRoundRect(sp, r, d div 2, fill, border);
end;

procedure paintCircle(sp: TSmoothPaint; cx, cy, radius: integer; fill, border: TColor; borderWidth: integer);
begin
  var r := radius+0.5;
  if fill <> clNone then sp.FillEllipse(cx+0.5, cy+0.5, r, r, fill);
  if border <> clNone then sp.FrameEllipse(cx+0.5, cy+0.5, r, r, Max(borderWidth, 1), border);
end;

procedure paintLine(sp: TSmoothPaint; x1, y1, x2, y2: integer; color: TColor; width: integer);
begin
  sp.StrokePolyline([PointF(x1+0.5, y1+0.5), PointF(x2+0.5, y2+0.5)], Max(width, 1), color);
end;

procedure paintChevron(sp: TSmoothPaint; const r: TRect; dir: TChevronDirection; size: integer; color: TColor);
begin
  var cx := (r.Left+r.Right) div 2+0.5;
  var cy := (r.Top+r.Bottom) div 2+0.5;
  var h := size div 2;
  var q := Max(size div 4, 1);
  match dir of
    cdDown: sp.StrokePolyline([PointF(cx-h, cy-q), PointF(cx, cy+q), PointF(cx+h, cy-q)], 2, color);
    cdUp: sp.StrokePolyline([PointF(cx-h, cy+q), PointF(cx, cy-q), PointF(cx+h, cy+q)], 2, color);
    cdLeft: sp.StrokePolyline([PointF(cx+q, cy-h), PointF(cx-q, cy), PointF(cx+q, cy+h)], 2, color);
  else
    sp.StrokePolyline([PointF(cx-q, cy-h), PointF(cx+q, cy), PointF(cx-q, cy+h)], 2, color);
  end;
end;

procedure paintCross(sp: TSmoothPaint; const r: TRect; size: integer; color: TColor; thickness: integer);
begin
  var cx := (r.Left+r.Right) div 2;
  var cy := (r.Top+r.Bottom) div 2;
  var h := size div 2;
  paintLine(sp, cx-h, cy-h, cx+h+1, cy+h+1, color, thickness);
  paintLine(sp, cx-h, cy+h, cx+h+1, cy-h-1, color, thickness);
end;

procedure paintCheck(sp: TSmoothPaint; const r: TRect; size: integer; color: TColor; thickness: integer);
begin
  var cx := (r.Left+r.Right) div 2+0.5;
  var cy := (r.Top+r.Bottom) div 2+0.5;
  var h := size div 2;
  sp.StrokePolyline([PointF(cx-h, cy), PointF(cx-h div 3, cy+h-h div 3), PointF(cx+h, cy-h+h div 3)], Max(thickness, 1), color);
end;

procedure paintMagnifier(sp: TSmoothPaint; const r: TRect; size: integer; color: TColor);
begin
  var cx := (r.Left+r.Right) div 2;
  var cy := (r.Top+r.Bottom) div 2;
  // the lens sits up-left, the handle runs to the down-right corner
  var lens := Max(size*5 div 16, 3);
  var lx := cx-size div 8;
  var ly := cy-size div 8;
  paintCircle(sp, lx, ly, lens, clNone, color);
  var d := Round(lens*0.7);
  paintLine(sp, lx+d, ly+d, cx+size div 2, cy+size div 2, color, 2);
end;

procedure paintRing(sp: TSmoothPaint; const r: TRect; radius: integer);
begin
  var inner := r;
  inner.Inflate(-1, -1);
  paintRoundRect(sp, inner, radius, clNone, ringColor);
end;

procedure paintArc(sp: TSmoothPaint; const box: TRect; startDeg, sweepDeg: integer; color: TColor; width: integer; roundCaps: boolean);
begin
  var w := Max(width, 1);
  var cx := (box.Left+box.Right)/2;
  var cy := (box.Top+box.Bottom)/2;
  // the stroke stays inside the box
  if sweepDeg >= 360 then sp.FrameEllipse(cx, cy, box.Width/2, box.Height/2, w, color)
  else sp.StrokeArc(cx, cy, (box.Width-w)/2, (box.Height-w)/2, startDeg, sweepDeg, w, color, roundCaps);
end;

{$ifdef WINDOWS}
function getWindowLongPtr(wnd: THandle; index: longint): PtrInt; stdcall; external 'user32' name {$ifdef CPU64}'GetWindowLongPtrW'{$else}'GetWindowLongW'{$endif};
function setWindowLongPtr(wnd: THandle; index: longint; value: PtrInt): PtrInt; stdcall; external 'user32' name {$ifdef CPU64}'SetWindowLongPtrW'{$else}'SetWindowLongW'{$endif};
function setLayeredWindowAttributes(wnd: THandle; key: cardinal; alpha: byte; flags: cardinal): longbool; stdcall; external 'user32' name 'SetLayeredWindowAttributes';
{$endif}

function layeredWindow(wnd: HWND; alpha: byte; keyColor: TColor): boolean;
begin
  result := false;
  {$ifdef WINDOWS}
  // GWL_EXSTYLE and WS_EX_LAYERED, then LWA_COLORKEY or LWA_ALPHA
  setWindowLongPtr(wnd, -20, getWindowLongPtr(wnd, -20) or $00080000);
  result := setLayeredWindowAttributes(wnd, cardinal(ColorToRGB(keyColor)), alpha, 3);
  {$endif}
end;

procedure keepInactive(wnd: HWND);
begin
  {$ifdef WINDOWS}
  // GWL_EXSTYLE and WS_EX_NOACTIVATE
  setWindowLongPtr(wnd, -20, getWindowLongPtr(wnd, -20) or $08000000);
  {$endif}
end;

procedure paintNow(control: TWinControl);
begin
  if control.HandleAllocated then RedrawWindow(control.Handle, nil, 0, RDW_UPDATENOW or RDW_ALLCHILDREN);
end;

procedure paintCenteredText(canvas: TCanvas; const r: TRect; const text: string; color: TColor);
begin
  applyTextQuality(canvas);
  var style := canvas.TextStyle;
  style.Alignment := taCenter;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  canvas.Brush.Style := bsClear;
  canvas.Font.Color := color;
  canvas.TextRect(r, r.Left, r.Top, text, style);
  canvas.Brush.Style := bsSolid;
end;

var
  measureBitmap: TBitmap;
  measured: TStringList; // the sizes by font and text, sorted

function measure(font: TFont; const text: string; height: boolean): integer;
begin
  var style := 0;
  for var st in font.Style do style := style or (1 shl ord(st));
  var key := Format('%s|%d|%d|%d|%d|%d|%d|%d|%s|', [font.Name, font.Height, font.Size, font.PixelsPerInch, style, ord(font.Pitch), ord(font.Quality), font.CharSet, (if height then 'h' else 'w')])+text;
  if measured = nil then begin
    measured := TStringList.Create;
    measured.CaseSensitive := true;
    measured.Sorted := true;
  end;
  var i: integer;
  if measured.Find(key, i) then exit(integer(PtrInt(measured.Objects[i])));
  if measureBitmap = nil then begin
    measureBitmap := TBitmap.Create;
    measureBitmap.SetSize(1, 1);
  end;
  measureBitmap.Canvas.Font := font;
  result := if height then measureBitmap.Canvas.TextHeight(text) else measureBitmap.Canvas.TextWidth(text);
  if measured.Count >= 4096 then measured.Clear;
  measured.AddObject(key, TObject(PtrInt(result)));
end;

function lineHeightOf(font: TFont): integer;
begin
  result := measure(font, 'Hg', true);
end;

var
  monoFace: string = '';

function monospaceFontName: string;
begin
  if monoFace <> '' then exit(monoFace);
  monoFace := 'Courier New';
  for var name in ['Cascadia Mono', 'Consolas', 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono', 'Ubuntu Mono', 'Menlo', 'Courier New'] do
    for var i := 0 to Screen.Fonts.Count-1 do
      if SameText(Screen.Fonts[i], name) then begin
        monoFace := Screen.Fonts[i];
        exit(monoFace);
      end;
  result := monoFace;
end;

function textWidthOf(font: TFont; const text: string): integer;
begin
  result := measure(font, text, false);
end;

function customDraw(control: TControl; canvas: TCanvas; handler: TCustomDrawEvent; const r: TRect; index: integer; state: TDrawState; background: TColor; antialiasing: TAntialiasSetting): boolean;
begin
  result := false;
  if not Assigned(handler) then exit;
  var plain := autofree beginShapes(canvas, Rect(0, 0, control.Width, control.Height), background, antialiasing);
  plain.Flush;
  handler(control, canvas, r, index, state, result);
end;

function polygonOutline(cx, cy, radius: single; sides: integer; startDeg: single): TOutline;
begin
  SetLength(result, sides);
  for var i := 0 to sides-1 do begin
    var a := DegToRad(startDeg+i*360/sides);
    result[i] := PointF(cx+cos(a)*radius, cy-sin(a)*radius);
  end;
end;

var
  englishSettings: TFormatSettings;
  englishReady: boolean = false;

function formatSettingsOf(language: TFormatLanguage): TFormatSettings;
const
  MONTHS: array[1..12] of string = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
  DAYS: array[1..7] of string = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
begin
  if language = flSystem then exit(DefaultFormatSettings);
  if not englishReady then begin
    englishSettings := DefaultFormatSettings;
    with englishSettings do begin
      DateSeparator := '-';
      TimeSeparator := ':';
      ShortDateFormat := 'yyyy-mm-dd';
      LongDateFormat := 'dddd, d mmmm yyyy';
      ShortTimeFormat := 'hh:nn';
      LongTimeFormat := 'hh:nn:ss';
      TimeAMString := 'AM';
      TimePMString := 'PM';
      DecimalSeparator := '.';
      ThousandSeparator := ',';
      ListSeparator := ',';
      for var i := 1 to 12 do begin
        LongMonthNames[i] := MONTHS[i];
        ShortMonthNames[i] := Copy(MONTHS[i], 1, 3);
      end;
      for var i := 1 to 7 do begin
        LongDayNames[i] := DAYS[i];
        ShortDayNames[i] := Copy(DAYS[i], 1, 3);
      end;
    end;
    englishReady := true;
  end;
  result := englishSettings;
end;

finalization
  measured.Free;
  measureBitmap.Free;
end.
