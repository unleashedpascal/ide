{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit CodeReaders;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Graphics, QRCode, Barcodes;

type
  // what the picture held: a QR code, or a linear barcode of one of the
  // symbologies TBarcode writes
  TCodeFormat = (cfNone, cfQR, cfEAN13, cfEAN8, cfUPCA, cfCode39, cfCode128, cfITF);
  TCodeFormats = set of TCodeFormat;

  { TCodeReader }

  // reads a QR code or a linear barcode out of a picture: a file, a
  // graphic or a bitmap, as the camera or a scanner saved it, turned any
  // way. The text, the raw bytes and the format come out, a QR code tells
  // how much of its error correction the read spent
  TCodeReader = class(TComponent)
  private
    FFormats: TCodeFormats;
    FFound: boolean;
    FFormat: TCodeFormat;
    FText: string;
    FBytes: TBytes;
    FVersion, FMask, FCorrected, FCapacity: integer;
    FLevel: TQRErrorLevel;
    FArea: TRect;
    FOnDecoded: TNotifyEvent;
    function getErrorCorrectionUsed: integer;
  public
    constructor Create(AOwner: TComponent); override;
    function ReadFile(const fileName: string): boolean;
    function ReadGraphic(graphic: TGraphic): boolean;
    function ReadBitmap(bitmap: TRasterImage): boolean;
    // forgets the last read
    procedure Clear;
    // the last read found a code
    property Found: boolean read FFound;
    property Format: TCodeFormat read FFormat;
    // the content; bytes outside UTF-8 come as Latin-1
    property Text: string read FText;
    // the content as the code carries it, byte for byte
    property Bytes: TBytes read FBytes;
    // of a QR code: its version 1..40, its error correction level and mask
    property Version: integer read FVersion;
    property ErrorLevel: TQRErrorLevel read FLevel;
    property Mask: integer read FMask;
    // of a QR code: the codewords the error correction had to repair
    property CorrectedCodewords: integer read FCorrected;
    // of a QR code: percent of the correction capacity the repair took; 0
    // for a clean code, 100 for one just on the edge of being unreadable
    property ErrorCorrectionUsed: integer read getErrorCorrectionUsed;
    // where the code sits in the picture
    property Area: TRect read FArea;
  published
    // the formats looked for
    property Formats: TCodeFormats read FFormats write FFormats default [cfQR, cfEAN13, cfEAN8, cfUPCA, cfCode39, cfCode128, cfITF];
    // after a read, found or not
    property OnDecoded: TNotifyEvent read FOnDecoded write FOnDecoded;
  end;

implementation

uses
  Math, IntfGraphics, FPImage, GraphType, LazUTF8;

type
  // the picture as light and dark pixels
  TBits = record
    width, height: integer;
    dark: array of boolean;
  end;

  TPointD = record
    x, y: double;
  end;

  TFinder = record
    x, y, module: double;
    count: integer;
  end;

function pointD(x, y: double): TPointD;
begin
  result.x := x;
  result.y := y;
end;

function distance(const a, b: TPointD): double;
begin
  result := Sqrt(Sqr(a.x-b.x)+Sqr(a.y-b.y));
end;

// -- the picture ----------------------

// the gray of every pixel, 0 dark to 255 light
function grayOf(image: TLazIntfImage): TBytes;
begin
  var w := image.Width;
  var h := image.Height;
  SetLength(result, w*h);
  var d := image.DataDescription;
  var fast := (d.BitsPerPixel = 32) and (d.ByteOrder = riboLSBFirst) and (d.RedPrec = 8) and (d.GreenPrec = 8) and (d.BluePrec = 8);
  for var y := 0 to h-1 do
    if fast then begin
      var line := PCardinal(image.GetDataLineStart(y));
      for var x := 0 to w-1 do begin
        var v := line[x];
        result[y*w+x] := (((v shr d.RedShift) and $FF)*299+((v shr d.GreenShift) and $FF)*587+((v shr d.BlueShift) and $FF)*114) div 1000;
      end;
    end else
      for var x := 0 to w-1 do begin
        var c := image.Colors[x, y];
        result[y*w+x] := ((c.Red shr 8)*299+(c.Green shr 8)*587+(c.Blue shr 8)*114) div 1000;
      end;
end;

// the threshold between the two groups of gray that keeps them furthest apart
function otsu(const gray: TBytes): integer;
begin
  var hist: array[0..255] of integer;
  FillChar(hist, sizeof(hist), 0);
  for var g in gray do inc(hist[g]);
  var total := length(gray);
  var sum := 0.0;
  for var i := 0 to 255 do sum += i*hist[i];
  var sumB := 0.0;
  var wB := 0;
  var best := 0.0;
  result := 128;
  for var t := 0 to 255 do begin
    wB += hist[t];
    if wB = 0 then continue;
    var wF := total-wB;
    if wF = 0 then break;
    sumB += t*hist[t];
    var mB := sumB/wB;
    var mF := (sum-sumB)/wF;
    var between := wB*wF*Sqr(mB-mF);
    if between > best then begin
      best := between;
      result := t;
    end;
  end;
end;

procedure binarizeGlobal(const gray: TBytes; w, h: integer; out bits: TBits);
begin
  bits.width := w;
  bits.height := h;
  SetLength(bits.dark, w*h);
  var t := otsu(gray);
  for var i := 0 to w*h-1 do bits.dark[i] := gray[i] < t;
end;

// every pixel against the mean of the window around it, for pictures lit
// unevenly
procedure binarizeLocal(const gray: TBytes; w, h: integer; out bits: TBits);
begin
  bits.width := w;
  bits.height := h;
  SetLength(bits.dark, w*h);
  var sums: array of int64;
  SetLength(sums, (w+1)*(h+1));
  for var y := 1 to h do begin
    var row: int64 := 0;
    for var x := 1 to w do begin
      row += gray[(y-1)*w+x-1];
      sums[y*(w+1)+x] := sums[(y-1)*(w+1)+x]+row;
    end;
  end;
  var r := Max(Min(w, h) div 16, 8);
  for var y := 0 to h-1 do begin
    var y0 := Max(y-r, 0);
    var y1 := Min(y+r+1, h);
    for var x := 0 to w-1 do begin
      var x0 := Max(x-r, 0);
      var x1 := Min(x+r+1, w);
      var area := (x1-x0)*(y1-y0);
      var mean := (sums[y1*(w+1)+x1]-sums[y0*(w+1)+x1]-sums[y1*(w+1)+x0]+sums[y0*(w+1)+x0]) div area;
      bits.dark[y*w+x] := gray[y*w+x] < mean*92 div 100;
    end;
  end;
end;

function darkAt(const bits: TBits; x, y: integer): boolean;
begin
  if (x < 0) or (y < 0) or (x >= bits.width) or (y >= bits.height) then exit(false);
  result := bits.dark[y*bits.width+x];
end;

// -- QR: the finder patterns ----------------------

// the five runs of a finder pattern read 1:1:3:1:1
function finderRatio(const runs: array of integer; from: integer; out module: double): boolean;
begin
  result := false;
  var total := 0;
  for var i := 0 to 4 do begin
    if runs[from+i] = 0 then exit;
    total += runs[from+i];
  end;
  if total < 7 then exit;
  module := total/7;
  var v := module/2;
  result := (Abs(runs[from]-module) < v) and (Abs(runs[from+1]-module) < v) and (Abs(runs[from+2]-3*module) < 3*v) and (Abs(runs[from+3]-module) < v) and (Abs(runs[from+4]-module) < v);
end;

// walks from (cx, cy) along one axis and reads the five runs around it
function crossCheck(const bits: TBits; cx, cy: integer; vertical: boolean; maxRun: integer; out center: double; out module: double): boolean;
begin
  result := false;
  var runs: array[0..4] of integer;
  FillChar(runs, sizeof(runs), 0);
  var limit := if vertical then bits.height else bits.width;
  var at := function(i: integer): boolean
  begin
    result := if vertical then darkAt(bits, cx, i) else darkAt(bits, i, cy);
  end;
  var i := if vertical then cy else cx;
  // from the middle outward: the dark center, then light, then dark
  while (i >= 0) and at(i) do begin
    inc(runs[2]);
    dec(i);
  end;
  if i < 0 then exit;
  while (i >= 0) and not at(i) and (runs[1] <= maxRun) do begin
    inc(runs[1]);
    dec(i);
  end;
  if (i < 0) or (runs[1] > maxRun) then exit;
  while (i >= 0) and at(i) and (runs[0] <= maxRun) do begin
    inc(runs[0]);
    dec(i);
  end;
  if runs[0] > maxRun then exit;
  var start := i+1;
  i := (if vertical then cy else cx)+1;
  while (i < limit) and at(i) do begin
    inc(runs[2]);
    inc(i);
  end;
  if i = limit then exit;
  while (i < limit) and not at(i) and (runs[3] < maxRun) do begin
    inc(runs[3]);
    inc(i);
  end;
  if (i = limit) or (runs[3] >= maxRun) then exit;
  while (i < limit) and at(i) and (runs[4] < maxRun) do begin
    inc(runs[4]);
    inc(i);
  end;
  if runs[4] >= maxRun then exit;
  if not finderRatio(runs, 0, module) then exit;
  center := start+runs[0]+runs[1]+runs[2]/2;
  result := true;
end;

// every finder pattern of the picture, each the average of the rows it
// showed up on
function findFinders(const bits: TBits): array of TFinder;
begin
  result := nil;
  var runs: array of integer;
  SetLength(runs, bits.width+1);
  for var y := 0 to bits.height-1 do begin
    // the runs of the row: light, dark, light...
    var n := 0;
    var x := 0;
    var dark := false;
    runs[0] := 0;
    while x < bits.width do begin
      if darkAt(bits, x, y) = dark then inc(runs[n])
      else begin
        dark := not dark;
        inc(n);
        runs[n] := 1;
      end;
      inc(x);
    end;
    inc(n);
    // a dark run sits at every odd index
    var pos := 0;
    for var i := 0 to n-1 do begin
      if (i >= 1) and odd(i) and (i+4 < n) then begin
        var module: double;
        if finderRatio(runs, i, module) then begin
          var cx := pos+runs[i]+runs[i+1]+runs[i+2] div 2;
          var cy: double;
          var m2: double;
          var maxRun := Round(module*6);
          if crossCheck(bits, cx, y, true, maxRun, cy, m2) then begin
            var cxd: double;
            var m3: double;
            if crossCheck(bits, cx, Round(cy), false, maxRun, cxd, m3) then begin
              var m := (module+m2+m3)/3;
              var merged := false;
              for var k := 0 to high(result) do
                if (Abs(result[k].x-cxd) < m*2) and (Abs(result[k].y-cy) < m*2) then begin
                  var c := result[k].count;
                  result[k].x := (result[k].x*c+cxd)/(c+1);
                  result[k].y := (result[k].y*c+cy)/(c+1);
                  result[k].module := (result[k].module*c+m)/(c+1);
                  inc(result[k].count);
                  merged := true;
                  break;
                end;
              if not merged then begin
                SetLength(result, length(result)+1);
                result[high(result)].x := cxd;
                result[high(result)].y := cy;
                result[high(result)].module := m;
                result[high(result)].count := 1;
              end;
            end;
          end;
        end;
      end;
      pos += runs[i];
    end;
  end;
end;

// the three finders of one code, ordered top left, top right, bottom left
function pickFinders(const all: array of TFinder; out tl, tr, bl: TFinder): boolean;
begin
  result := false;
  var best := MaxDouble;
  for var a := 0 to high(all) do for var b := a+1 to high(all) do for var c := b+1 to high(all) do begin
    var fa := all[a];
    var fb := all[b];
    var fc := all[c];
    // alike modules, a right angle with two equal legs
    var m := (fa.module+fb.module+fc.module)/3;
    if (Abs(fa.module-m) > m*0.35) or (Abs(fb.module-m) > m*0.35) or (Abs(fc.module-m) > m*0.35) then continue;
    var pa := pointD(fa.x, fa.y);
    var pb := pointD(fb.x, fb.y);
    var pc := pointD(fc.x, fc.y);
    var dab := distance(pa, pb);
    var dbc := distance(pb, pc);
    var dca := distance(pc, pa);
    // the corner is the one between the two shorter sides
    var corner, p1, p2: TFinder;
    var leg1, leg2, hyp: double;
    if (dbc >= dab) and (dbc >= dca) then begin
      corner := fa;
      p1 := fb;
      p2 := fc;
      leg1 := dab;
      leg2 := dca;
      hyp := dbc;
    end else if (dca >= dab) and (dca >= dbc) then begin
      corner := fb;
      p1 := fa;
      p2 := fc;
      leg1 := dab;
      leg2 := dbc;
      hyp := dca;
    end else begin
      corner := fc;
      p1 := fa;
      p2 := fb;
      leg1 := dca;
      leg2 := dbc;
      hyp := dab;
    end;
    if (leg1 < m*10) or (leg2 < m*10) then continue;
    var err := Abs(leg1-leg2)/Max(leg1, leg2)+Abs(hyp-Sqrt(leg1*leg1+leg2*leg2))/hyp;
    // the sides should hold a whole number of modules each
    err += Abs(leg1/m-Round(leg1/m))/20;
    if err >= best then continue;
    best := err;
    tl := corner;
    // the cross product tells which leg turns clockwise on the screen
    var cross := (p1.x-corner.x)*(p2.y-corner.y)-(p1.y-corner.y)*(p2.x-corner.x);
    if cross > 0 then begin
      tr := p1;
      bl := p2;
    end else begin
      tr := p2;
      bl := p1;
    end;
    result := true;
  end;
  if result and (best > 0.6) then result := false;
end;

// -- QR: the sampling grid ----------------------

type
  // a perspective map between two quadrilaterals
  TPerspective = record
    a11, a12, a13, a21, a22, a23, a31, a32, a33: double;
  end;

function squareToQuad(x0, y0, x1, y1, x2, y2, x3, y3: double): TPerspective;
begin
  var dx3 := x0-x1+x2-x3;
  var dy3 := y0-y1+y2-y3;
  if (dx3 = 0) and (dy3 = 0) then begin
    result.a11 := x1-x0;
    result.a21 := x2-x1;
    result.a31 := x0;
    result.a12 := y1-y0;
    result.a22 := y2-y1;
    result.a32 := y0;
    result.a13 := 0;
    result.a23 := 0;
    result.a33 := 1;
    exit;
  end;
  var dx1 := x1-x2;
  var dx2 := x3-x2;
  var dy1 := y1-y2;
  var dy2 := y3-y2;
  var denominator := dx1*dy2-dx2*dy1;
  var a13 := (dx3*dy2-dx2*dy3)/denominator;
  var a23 := (dx1*dy3-dx3*dy1)/denominator;
  result.a11 := x1-x0+a13*x1;
  result.a21 := x3-x0+a23*x3;
  result.a31 := x0;
  result.a12 := y1-y0+a13*y1;
  result.a22 := y3-y0+a23*y3;
  result.a32 := y0;
  result.a13 := a13;
  result.a23 := a23;
  result.a33 := 1;
end;

function adjoint(const p: TPerspective): TPerspective;
begin
  result.a11 := p.a22*p.a33-p.a23*p.a32;
  result.a21 := p.a23*p.a31-p.a21*p.a33;
  result.a31 := p.a21*p.a32-p.a22*p.a31;
  result.a12 := p.a13*p.a32-p.a12*p.a33;
  result.a22 := p.a11*p.a33-p.a13*p.a31;
  result.a32 := p.a12*p.a31-p.a11*p.a32;
  result.a13 := p.a12*p.a23-p.a13*p.a22;
  result.a23 := p.a13*p.a21-p.a11*p.a23;
  result.a33 := p.a11*p.a22-p.a12*p.a21;
end;

function times(const a, b: TPerspective): TPerspective;
begin
  result.a11 := a.a11*b.a11+a.a21*b.a12+a.a31*b.a13;
  result.a21 := a.a11*b.a21+a.a21*b.a22+a.a31*b.a23;
  result.a31 := a.a11*b.a31+a.a21*b.a32+a.a31*b.a33;
  result.a12 := a.a12*b.a11+a.a22*b.a12+a.a32*b.a13;
  result.a22 := a.a12*b.a21+a.a22*b.a22+a.a32*b.a23;
  result.a32 := a.a12*b.a31+a.a22*b.a32+a.a32*b.a33;
  result.a13 := a.a13*b.a11+a.a23*b.a12+a.a33*b.a13;
  result.a23 := a.a13*b.a21+a.a23*b.a22+a.a33*b.a23;
  result.a33 := a.a13*b.a31+a.a23*b.a32+a.a33*b.a33;
end;

// the map taking the first quadrilateral onto the second
function quadToQuad(x0, y0, x1, y1, x2, y2, x3, y3, x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p: double): TPerspective;
begin
  result := times(squareToQuad(x0p, y0p, x1p, y1p, x2p, y2p, x3p, y3p), adjoint(squareToQuad(x0, y0, x1, y1, x2, y2, x3, y3)));
end;

function transform(const p: TPerspective; x, y: double): TPointD;
begin
  var denominator := p.a13*x+p.a23*y+p.a33;
  result.x := (p.a11*x+p.a21*y+p.a31)/denominator;
  result.y := (p.a12*x+p.a22*y+p.a32)/denominator;
end;

// the width of a module measured along the line from the center of a
// finder toward another point: the dark middle, the light ring and the
// dark ring span 3.5 modules whichever way the code is turned
function moduleAlong(const bits: TBits; const from, toward: TPointD): double;
begin
  result := 0;
  var len := distance(from, toward);
  if len = 0 then exit;
  var dx := (toward.x-from.x)/len;
  var dy := (toward.y-from.y)/len;
  var changes := 0;
  var dark := true;
  var d := 0.0;
  while (d < len) and (changes < 3) do begin
    d += 0.25;
    var now := darkAt(bits, Floor(from.x+dx*d), Floor(from.y+dy*d));
    if now <> dark then begin
      inc(changes);
      dark := now;
    end;
  end;
  if changes = 3 then result := d/3.5;
end;

// the center of the alignment pattern near where the finders put it: the
// spot where the 5 by 5 template, sampled through the map of the finders,
// fits best
function findAlignment(const bits: TBits; const p: TPerspective; cx, cy: double; out center: TPointD): boolean;
begin
  result := false;
  var best := 0;
  var bestX := 0.0;
  var bestY := 0.0;
  for var oy := -8 to 8 do for var ox := -8 to 8 do begin
    var x := cx+ox/4;
    var y := cy+oy/4;
    var score := 0;
    for var j := -2 to 2 do for var i := -2 to 2 do begin
      var pt := transform(p, x+i, y+j);
      var dark := darkAt(bits, Floor(pt.x), Floor(pt.y));
      if dark = (Max(Abs(i), Abs(j)) <> 1) then inc(score);
    end;
    // the nearest of the equally good spots
    if (score > best) or ((score = best) and (ox*ox+oy*oy < Round(Sqr((bestX-cx)*4)+Sqr((bestY-cy)*4)))) then begin
      best := score;
      bestX := x;
      bestY := y;
    end;
  end;
  if best < 23 then exit;
  center := transform(p, bestX, bestY);
  result := true;
end;

// the modules of the code sampled through the map; false when the grid
// leaves the picture
function sampleGrid(const bits: TBits; const p: TPerspective; dim: integer; out modules: TQRModules): boolean;
begin
  SetLength(modules, dim, dim);
  for var y := 0 to dim-1 do for var x := 0 to dim-1 do begin
    // the pixel the middle of the module falls into
    var pt := transform(p, x+0.5, y+0.5);
    var px := Floor(pt.x);
    var py := Floor(pt.y);
    if (px < -1) or (py < -1) or (px > bits.width) or (py > bits.height) then exit(false);
    modules[y][x] := darkAt(bits, px, py);
  end;
  result := true;
end;

// -- QR: the bits of the grid ----------------------

// the format word of a level and a mask as the code carries it
function formatWord(level, mask: integer): integer;
begin
  var data := (level shl 3) or mask;
  var rem := data;
  for var i := 0 to 9 do rem := (rem shl 1) xor ((rem shr 9)*$537);
  result := ((data shl 10) or rem) xor $5412;
end;

function versionWord(version: integer): integer;
begin
  var rem := version;
  for var i := 0 to 11 do rem := (rem shl 1) xor ((rem shr 11)*$1F25);
  result := (version shl 12) or rem;
end;

function bitCount(v: cardinal): integer;
begin
  result := 0;
  while v <> 0 do begin
    inc(result, v and 1);
    v := v shr 1;
  end;
end;

// the format information from either copy, the one with fewer wrong bits
function readFormat(const m: TQRModules; out level: TQRErrorLevel; out mask: integer): boolean;
begin
  var n := length(m);
  var at := function(x, y: integer): integer
  begin
    result := ord(m[y][x]);
  end;
  var first := 0;
  for var i := 0 to 5 do first := first or (at(8, i) shl i);
  first := first or (at(8, 7) shl 6) or (at(8, 8) shl 7) or (at(7, 8) shl 8);
  for var i := 9 to 14 do first := first or (at(14-i, 8) shl i);
  var second := 0;
  for var i := 0 to 7 do second := second or (at(n-1-i, 8) shl i);
  for var i := 8 to 14 do second := second or (at(8, n-15+i) shl i);
  var best := 4;
  var found := -1;
  for var w := 0 to 31 do begin
    var code := formatWord(w shr 3, w and 7);
    var d := Min(bitCount(code xor first), bitCount(code xor second));
    if d < best then begin
      best := d;
      found := w;
    end;
  end;
  result := found >= 0;
  if not result then exit;
  mask := found and 7;
  // the level bits of the standard: 1 low, 0 medium, 3 quartile, 2 high
  level := match found shr 3 of
    1: qrLow;
    0: qrMedium;
    3: qrQuartile;
  else
    qrHigh
  end;
end;

// the version from its information blocks, 0 when neither copy reads
function readVersion(const m: TQRModules): integer;
begin
  var n := length(m);
  var first := 0;
  var second := 0;
  for var i := 0 to 17 do begin
    var a := n-11+i mod 3;
    var b := i div 3;
    first := first or (ord(m[b][a]) shl i);
    second := second or (ord(m[a][b]) shl i);
  end;
  result := 0;
  var best := 4;
  for var v := 7 to 40 do begin
    var code := versionWord(v);
    var d := Min(bitCount(code xor first), bitCount(code xor second));
    if d < best then begin
      best := d;
      result := v;
    end;
  end;
end;

// the modules taken by the finders, the timing, the alignments, the format
// and the version information
function functionMask(version: integer): TQRModules;
begin
  var n := version*4+17;
  var taken: TQRModules;
  SetLength(taken, n, n);
  var box := procedure(x0, y0, x1, y1: integer)
  begin
    for var y := Max(y0, 0) to Min(y1, n-1) do for var x := Max(x0, 0) to Min(x1, n-1) do taken[y][x] := true;
  end;
  box(0, 0, 8, 8);
  box(n-8, 0, n-1, 8);
  box(0, n-8, 8, n-1);
  for var i := 0 to n-1 do begin
    taken[6][i] := true;
    taken[i][6] := true;
  end;
  var pos := ALIGN_POS[version];
  var count := 0;
  while (count < 7) and (pos[count] <> 0) do inc(count);
  for var i := 0 to count-1 do for var j := 0 to count-1 do begin
    if ((i = 0) and (j = 0)) or ((i = 0) and (j = count-1)) or ((i = count-1) and (j = 0)) then continue;
    box(pos[i]-2, pos[j]-2, pos[i]+2, pos[j]+2);
  end;
  if version >= 7 then begin
    box(n-11, 0, n-9, 5);
    box(0, n-11, 5, n-9);
  end;
  result := taken;
end;

// the codewords in the order they were placed, the mask taken off
function readCodewords(const m: TQRModules; version, mask: integer): TBytes;
begin
  var n := length(m);
  var fixed := functionMask(version);
  var total := DATA_CODEWORDS[version, qrLow]+BLOCKS[version, qrLow]*EC_PER_BLOCK[version, qrLow];
  SetLength(result, total);
  for var i := 0 to total-1 do result[i] := 0;
  var bitIndex := 0;
  var right := n-1;
  while right >= 1 do begin
    if right = 6 then right := 5;
    for var vert := 0 to n-1 do
      for var j := 0 to 1 do begin
        var x := right-j;
        var upward := ((right+1) and 2) = 0;
        var y := if upward then n-1-vert else vert;
        if fixed[y][x] or (bitIndex >= total*8) then continue;
        var dark := m[y][x] xor maskBit(mask, x, y);
        if dark then result[bitIndex shr 3] := result[bitIndex shr 3] or (1 shl (7-(bitIndex and 7)));
        inc(bitIndex);
      end;
    right -= 2;
  end;
end;

// -- QR: Reed-Solomon over GF(256) ----------------------

var
  gfExp: array[0..511] of byte;
  gfLog: array[0..255] of byte;
  gfReady: boolean = false;

procedure initField;
begin
  var x := 1;
  for var i := 0 to 254 do begin
    gfExp[i] := x;
    gfLog[x] := i;
    x := x shl 1;
    if x >= 256 then x := x xor $11D;
  end;
  for var i := 255 to 511 do gfExp[i] := gfExp[i-255];
  gfReady := true;
end;

function gfMul(a, b: integer): integer;
begin
  if (a = 0) or (b = 0) then exit(0);
  result := gfExp[gfLog[a]+gfLog[b]];
end;

function gfInverse(a: integer): integer;
begin
  result := gfExp[255-gfLog[a]];
end;

type
  // a polynomial with the highest power first
  TPoly = array of integer;

function polyDegree(const p: TPoly): integer;
begin
  result := length(p)-1;
end;

function polyIsZero(const p: TPoly): boolean;
begin
  result := (length(p) = 0) or ((length(p) = 1) and (p[0] = 0));
end;

// drops the leading zeros
function polyTrim(const p: TPoly): TPoly;
begin
  var first := 0;
  while (first < length(p)-1) and (p[first] = 0) do inc(first);
  result := Copy(p, first, length(p)-first);
  if length(result) = 0 then result := [0];
end;

function polyCoeff(const p: TPoly; degree: integer): integer;
begin
  result := p[length(p)-1-degree];
end;

function polyAt(const p: TPoly; a: integer): integer;
begin
  if a = 0 then exit(polyCoeff(p, 0));
  result := 0;
  for var c in p do result := gfMul(result, a) xor c;
end;

function polyAdd(const a, b: TPoly): TPoly;
begin
  if polyIsZero(a) then exit(b);
  if polyIsZero(b) then exit(a);
  var small := a;
  var large := b;
  if length(small) > length(large) then begin
    small := b;
    large := a;
  end;
  SetLength(result, length(large));
  var diff := length(large)-length(small);
  for var i := 0 to diff-1 do result[i] := large[i];
  for var i := diff to high(large) do result[i] := small[i-diff] xor large[i];
  result := polyTrim(result);
end;

function polyMul(const a, b: TPoly): TPoly;
begin
  if polyIsZero(a) or polyIsZero(b) then exit([0]);
  SetLength(result, length(a)+length(b)-1);
  for var i := 0 to high(result) do result[i] := 0;
  for var i := 0 to high(a) do for var j := 0 to high(b) do result[i+j] := result[i+j] xor gfMul(a[i], b[j]);
  result := polyTrim(result);
end;

function polyScale(const a: TPoly; s: integer): TPoly;
begin
  SetLength(result, length(a));
  for var i := 0 to high(a) do result[i] := gfMul(a[i], s);
  result := polyTrim(result);
end;

// a times scale times x^degree
function polyMulMonomial(const a: TPoly; degree, scale: integer): TPoly;
begin
  if scale = 0 then exit([0]);
  SetLength(result, length(a)+degree);
  for var i := 0 to high(result) do result[i] := 0;
  for var i := 0 to high(a) do result[i] := gfMul(a[i], scale);
  result := polyTrim(result);
end;

function monomial(degree, scale: integer): TPoly;
begin
  if scale = 0 then exit([0]);
  SetLength(result, degree+1);
  for var i := 0 to degree do result[i] := 0;
  result[0] := scale;
end;

// repairs a block of data and error correction codewords in place; the
// number of codewords changed, -1 when there are too many errors
function correctBlock(var block: TBytes; ecLen: integer): integer;
begin
  if not gfReady then initField;
  var n := length(block);
  var received: TPoly;
  SetLength(received, n);
  for var i := 0 to n-1 do received[i] := block[i];
  // the syndromes: zero all over for a clean block
  var syndromes: TPoly;
  SetLength(syndromes, ecLen);
  var clean := true;
  for var i := 0 to ecLen-1 do begin
    var s := polyAt(received, gfExp[i]);
    syndromes[ecLen-1-i] := s;
    if s <> 0 then clean := false;
  end;
  if clean then exit(0);
  // the euclidean algorithm: the error locator sigma and the evaluator omega
  var a := monomial(ecLen, 1);
  var b := polyTrim(syndromes);
  if polyDegree(a) < polyDegree(b) then begin
    var t := a;
    a := b;
    b := t;
  end;
  var rLast := a;
  var r := b;
  var tLast: TPoly := [0];
  var t: TPoly := [1];
  while polyDegree(r) >= ecLen div 2 do begin
    var rLastLast := rLast;
    var tLastLast := tLast;
    rLast := r;
    tLast := t;
    if polyIsZero(rLast) then exit(-1);
    r := rLastLast;
    var q: TPoly := [0];
    var dltInverse := gfInverse(polyCoeff(rLast, polyDegree(rLast)));
    while (polyDegree(r) >= polyDegree(rLast)) and not polyIsZero(r) do begin
      var degreeDiff := polyDegree(r)-polyDegree(rLast);
      var scale := gfMul(polyCoeff(r, polyDegree(r)), dltInverse);
      q := polyAdd(q, monomial(degreeDiff, scale));
      r := polyAdd(r, polyMulMonomial(rLast, degreeDiff, scale));
    end;
    t := polyAdd(polyMul(q, tLast), tLastLast);
    if polyDegree(r) >= polyDegree(rLast) then exit(-1);
  end;
  var sigmaTildeAtZero := polyCoeff(t, 0);
  if sigmaTildeAtZero = 0 then exit(-1);
  var inv := gfInverse(sigmaTildeAtZero);
  var sigma := polyScale(t, inv);
  var omega := polyScale(r, inv);
  // the error locations: the roots of sigma, found by trying every element
  var errors := polyDegree(sigma);
  var locations: array of integer;
  if errors = 1 then locations := [polyCoeff(sigma, 1)]
  else begin
    for var i := 1 to 255 do
      if polyAt(sigma, i) = 0 then begin
        SetLength(locations, length(locations)+1);
        locations[high(locations)] := gfInverse(i);
      end;
    if length(locations) <> errors then exit(-1);
  end;
  // the magnitudes by Forney, the generator starting at alpha^0
  for var i := 0 to errors-1 do begin
    var xiInverse := gfInverse(locations[i]);
    var denominator := 1;
    for var j := 0 to errors-1 do
      if i <> j then begin
        var term := gfMul(locations[j], xiInverse);
        var termPlus1 := if (term and 1) = 0 then term or 1 else term and not 1;
        denominator := gfMul(denominator, termPlus1);
      end;
    var magnitude := gfMul(polyAt(omega, xiInverse), gfInverse(denominator));
    var position := n-1-gfLog[locations[i]];
    if position < 0 then exit(-1);
    block[position] := block[position] xor magnitude;
  end;
  result := errors;
end;

// -- QR: the content ----------------------

type
  TBitReader = record
    data: TBytes;
    pos: integer; // in bits
  end;

function readBits(var r: TBitReader; count: integer): integer;
begin
  result := 0;
  for var i := 1 to count do begin
    var bit := (r.data[r.pos shr 3] shr (7-(r.pos and 7))) and 1;
    result := (result shl 1) or bit;
    inc(r.pos);
  end;
end;

function bitsLeft(const r: TBitReader): integer;
begin
  result := length(r.data)*8-r.pos;
end;

function validUTF8(const s: string): boolean;
begin
  result := FindInvalidUTF8Codepoint(PChar(s), length(s)) < 0;
end;

const
  ALPHANUMERIC = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:';

// the segments of the data codewords as text and as bytes; false on a
// mode the standard does not know
function decodeData(const data: TBytes; version: integer; out text: string; out bytes: TBytes): boolean;
begin
  result := false;
  text := '';
  bytes := nil;
  var r: TBitReader;
  r.data := data;
  r.pos := 0;
  var raw := '';
  var eci := false;
  var push := procedure(const s: string)
  begin
    raw += s;
  end;
  while bitsLeft(r) >= 4 do begin
    var mode := readBits(r, 4);
    if mode = 0 then break;
    match mode of
      // numeric: three digits in ten bits
      1: begin
        var count := readBits(r, (if version <= 9 then 10 else if version <= 26 then 12 else 14));
        while count >= 3 do begin
          if bitsLeft(r) < 10 then exit;
          push(SysUtils.Format('%.3d', [readBits(r, 10)]));
          count -= 3;
        end;
        if count = 2 then begin
          if bitsLeft(r) < 7 then exit;
          push(SysUtils.Format('%.2d', [readBits(r, 7)]));
        end else if count = 1 then begin
          if bitsLeft(r) < 4 then exit;
          push(IntToStr(readBits(r, 4)));
        end;
      end;
      // alphanumeric: two characters in eleven bits
      2: begin
        var count := readBits(r, (if version <= 9 then 9 else if version <= 26 then 11 else 13));
        while count >= 2 do begin
          if bitsLeft(r) < 11 then exit;
          var v := readBits(r, 11);
          push(ALPHANUMERIC[v div 45+1]+ALPHANUMERIC[v mod 45+1]);
          count -= 2;
        end;
        if count = 1 then begin
          if bitsLeft(r) < 6 then exit;
          push(ALPHANUMERIC[readBits(r, 6)+1]);
        end;
      end;
      // bytes as they are
      4: begin
        var count := readBits(r, (if version <= 9 then 8 else 16));
        if bitsLeft(r) < count*8 then exit;
        for var i := 1 to count do push(chr(readBits(r, 8)));
      end;
      // kanji: the two bytes of Shift JIS packed into thirteen bits
      8: begin
        var count := readBits(r, (if version <= 9 then 8 else if version <= 26 then 10 else 12));
        if bitsLeft(r) < count*13 then exit;
        for var i := 1 to count do begin
          var v := readBits(r, 13);
          var code := (v div $C0) shl 8 or (v mod $C0);
          code += if code < $1F00 then $8140 else $C140;
          push(chr(code shr 8)+chr(code and $FF));
        end;
      end;
      // ECI names the character set; the text is taken as UTF-8 after it
      7: begin
        var first := readBits(r, 8);
        if (first and $80) = 0 then
        else if (first and $C0) = $80 then readBits(r, 8)
        else if (first and $E0) = $C0 then readBits(r, 16)
        else exit;
        eci := true;
      end;
      // structured append: the position and the parity of a split code
      3: readBits(r, 16);
      // FNC1 in either position
      5, 9: ;
    else
      exit;
    end;
  end;
  SetLength(bytes, length(raw));
  if raw <> '' then Move(raw[1], bytes[0], length(raw));
  // UTF-8 when it reads as such, Latin-1 otherwise
  text := if eci or validUTF8(raw) then raw else WinCPToUTF8(raw);
  result := true;
end;

// -- QR: the whole read ----------------------

type
  TQRRead = record
    ok: boolean;
    text: string;
    bytes: TBytes;
    version, mask, corrected, capacity: integer;
    level: TQRErrorLevel;
    area: TRect;
  end;

function decodeModules(const m: TQRModules; out r: TQRRead): boolean;
begin
  result := false;
  var n := length(m);
  if (n < 21) or ((n-17) mod 4 <> 0) then exit;
  var version := (n-17) div 4;
  var level: TQRErrorLevel;
  var mask: integer;
  if not readFormat(m, level, mask) then exit;
  var codewords := readCodewords(m, version, mask);
  // the blocks: the short ones first, the long ones one byte more, data
  // and error correction interleaved by column
  var blockCount := BLOCKS[version, level];
  var ecLen := EC_PER_BLOCK[version, level];
  var dataLen := DATA_CODEWORDS[version, level];
  var shortLen := dataLen div blockCount;
  var longBlocks := dataLen mod blockCount;
  var blocks: array of TBytes;
  SetLength(blocks, blockCount);
  for var b := 0 to blockCount-1 do SetLength(blocks[b], shortLen+(if b >= blockCount-longBlocks then 1 else 0)+ecLen);
  var k := 0;
  for var i := 0 to shortLen do for var b := 0 to blockCount-1 do
    if i < length(blocks[b])-ecLen then begin
      blocks[b][i] := codewords[k];
      inc(k);
    end;
  for var i := 0 to ecLen-1 do for var b := 0 to blockCount-1 do begin
    blocks[b][length(blocks[b])-ecLen+i] := codewords[k];
    inc(k);
  end;
  var data: TBytes;
  SetLength(data, dataLen);
  var corrected := 0;
  var at := 0;
  for var b := 0 to blockCount-1 do begin
    var fixed := correctBlock(blocks[b], ecLen);
    if fixed < 0 then exit;
    corrected += fixed;
    var len := length(blocks[b])-ecLen;
    Move(blocks[b][0], data[at], len);
    at += len;
  end;
  if not decodeData(data, version, r.text, r.bytes) then exit;
  r.version := version;
  r.level := level;
  r.mask := mask;
  r.corrected := corrected;
  r.capacity := blockCount*(ecLen div 2);
  r.ok := true;
  result := true;
end;

function readQR(const bits: TBits; out r: TQRRead): boolean;
begin
  result := false;
  r := Default(TQRRead);
  var finders := findFinders(bits);
  var tl, tr, bl: TFinder;
  if not pickFinders(finders, tl, tr, bl) then exit;
  var ptl := pointD(tl.x, tl.y);
  var ptr := pointD(tr.x, tr.y);
  var pbl := pointD(bl.x, bl.y);
  // the module along the lines between the finders, which the turn of the
  // code does not stretch
  var module := 0.0;
  var measured := 0;
  for var m in [moduleAlong(bits, ptl, ptr), moduleAlong(bits, ptr, ptl), moduleAlong(bits, ptl, pbl), moduleAlong(bits, pbl, ptl)] do
    if m > 0 then begin
      module += m;
      inc(measured);
    end;
  if measured = 0 then exit;
  module /= measured;
  // the modules between the finders give the size; a size reads 1 mod 4
  var raw := (distance(ptl, ptr)+distance(ptl, pbl))/2/module+7;
  var dim := Round((raw-1)/4)*4+1;
  var guess := pointD(tr.x+bl.x-tl.x, tr.y+bl.y-tl.y);
  var tries := 0;
  while (dim >= 21) and (dim <= 177) and (tries < 3) do begin
    inc(tries);
    var version := (dim-17) div 4;
    var far := dim-3.5;
    // the map of the three finders alone, the corner where they put it
    var plain := quadToQuad(3.5, 3.5, far, 3.5, far, far, 3.5, far, ptl.x, ptl.y, ptr.x, ptr.y, guess.x, guess.y, pbl.x, pbl.y);
    var modules: TQRModules;
    var retry := false;
    // first with the alignment pattern near the bottom right corner as the
    // fourth point, then without it
    for var pass := 0 to 1 do begin
      var p := plain;
      if pass = 0 then begin
        if version < 2 then continue;
        var pbr: TPointD;
        if not findAlignment(bits, plain, far-3, far-3, pbr) then continue;
        p := quadToQuad(3.5, 3.5, far, 3.5, far-3, far-3, 3.5, far, ptl.x, ptl.y, ptr.x, ptr.y, pbr.x, pbr.y, pbl.x, pbl.y);
      end;
      if not sampleGrid(bits, p, dim, modules) then continue;
      // the version information of a big code says the real size
      if version >= 7 then begin
        var read := readVersion(modules);
        if (read > 0) and (read <> version) then begin
          dim := read*4+17;
          retry := true;
          break;
        end;
      end;
      if decodeModules(modules, r) then begin
        var xs := [ptl.x, ptr.x, pbl.x, guess.x];
        var ys := [ptl.y, ptr.y, pbl.y, guess.y];
        r.area := Rect(Floor(MinValue(xs)-module*3.5), Floor(MinValue(ys)-module*3.5), Ceil(MaxValue(xs)+module*3.5), Ceil(MaxValue(ys)+module*3.5));
        exit(true);
      end;
    end;
    if not retry then exit;
  end;
end;

// -- barcodes ----------------------

type
  TBarRead = record
    ok: boolean;
    text: string;
    format: TCodeFormat;
    area: TRect;
  end;
  TRuns = array of integer; // the widths of light, dark, light... along a row

// the runs of a row, the first one light (empty when the row starts dark)
function rowRuns(const bits: TBits; y: integer; out starts: TRuns): TRuns;
begin
  result := nil;
  starts := nil;
  var dark := false;
  var x := 0;
  while x < bits.width do begin
    var x0 := x;
    while (x < bits.width) and (darkAt(bits, x, y) = dark) do inc(x);
    SetLength(result, length(result)+1);
    SetLength(starts, length(starts)+1);
    result[high(result)] := x-x0;
    starts[high(starts)] := x0;
    dark := not dark;
  end;
end;

// how far `runs` from `from` are from a pattern of module widths, in
// modules; large when a run is off by more than half a module
function patternVariance(const runs: TRuns; from: integer; const pattern: array of integer; maxIndividual: double): double;
begin
  var n := length(pattern);
  var total := 0;
  var patternTotal := 0;
  for var i := 0 to n-1 do begin
    total += runs[from+i];
    patternTotal += pattern[i];
  end;
  if (total < patternTotal) or (patternTotal = 0) then exit(MaxDouble);
  var per := total/patternTotal;
  result := 0;
  for var i := 0 to n-1 do begin
    var v := Abs(runs[from+i]-pattern[i]*per)/per;
    if v > maxIndividual then exit(MaxDouble);
    result += v;
  end;
  result /= n;
end;

// the seven modules of a string pattern like '0001101' as runs: 4 of them
// starting with a space
function digitRuns(const code: string): array of integer;
begin
  result := [0, 0, 0, 0];
  var k := 0;
  for var i := 1 to length(code) do begin
    if (i > 1) and (code[i] <> code[i-1]) then inc(k);
    inc(result[k]);
  end;
end;

// the digit whose pattern fits the four runs best: 0..9, plus 10 when it
// is one of the even parity patterns of EAN-13
function eanDigit(const runs: TRuns; from: integer; withParity: boolean; out parity: char): integer;
begin
  result := -1;
  var best := 0.7;
  parity := 'L';
  for var d := 0 to 9 do begin
    var v := patternVariance(runs, from, digitRuns(EAN_L[d]), 0.7);
    if v < best then begin
      best := v;
      result := d;
      parity := 'L';
    end;
    if withParity then begin
      var g := '';
      for var i := 7 downto 1 do g += (if EAN_L[d][i] = '1' then '0' else '1');
      v := patternVariance(runs, from, digitRuns(g), 0.7);
      if v < best then begin
        best := v;
        result := d;
        parity := 'G';
      end;
    end;
  end;
end;

function mod10Ok(const digits: string): boolean;
begin
  var sum := 0;
  for var i := 1 to length(digits)-1 do sum += (ord(digits[i])-ord('0'))*(if odd(length(digits)-i) then 3 else 1);
  result := (10-sum mod 10) mod 10 = ord(digits[length(digits)])-ord('0');
end;

// EAN-13, UPC-A and EAN-8 from a guard at `from`: 1:1:1 guards, six or four
// digits a side, the middle guard between
function readEan(const runs: TRuns; from: integer; formats: TCodeFormats; out text: string; out format: TCodeFormat; out last: integer): boolean;
begin
  result := false;
  if from+2 >= length(runs) then exit;
  if patternVariance(runs, from, [1, 1, 1], 0.5) > 0.5 then exit;
  var per := (runs[from]+runs[from+1]+runs[from+2])/3;
  // the quiet zone before the guard
  if (from = 0) or (runs[from-1] < per*5) then exit;
  for var half in [6, 4] do begin
    var at := from+3;
    var digits := '';
    var parities := '';
    var good := true;
    for var i := 1 to half do begin
      if at+3 >= length(runs) then begin
        good := false;
        break;
      end;
      var parity: char;
      var d := eanDigit(runs, at, half = 6, parity);
      if d < 0 then begin
        good := false;
        break;
      end;
      digits += chr(ord('0')+d);
      parities += parity;
      at += 4;
    end;
    if not good then continue;
    if (at+4 >= length(runs)) or (patternVariance(runs, at, [1, 1, 1, 1, 1], 0.5) > 0.5) then continue;
    at += 5;
    for var i := 1 to half do begin
      if at+3 >= length(runs) then begin
        good := false;
        break;
      end;
      var parity: char;
      // the right digits read as spaces and bars swapped, which the runs
      // starting on a bar already are
      var d := eanDigit(runs, at, false, parity);
      if d < 0 then begin
        good := false;
        break;
      end;
      digits += chr(ord('0')+d);
      at += 4;
    end;
    if not good then continue;
    if (at+2 >= length(runs)) or (patternVariance(runs, at, [1, 1, 1], 0.5) > 0.5) then continue;
    if half = 6 then begin
      var first := -1;
      for var f := 0 to 9 do
        if EAN_PARITY[f] = parities then first := f;
      if first < 0 then continue;
      digits := chr(ord('0')+first)+digits;
      if not mod10Ok(digits) then continue;
      if (first = 0) and (cfUPCA in formats) then begin
        format := cfUPCA;
        text := Copy(digits, 2, 12);
      end else if cfEAN13 in formats then begin
        format := cfEAN13;
        text := digits;
      end else continue;
    end else begin
      if not mod10Ok(digits) or not (cfEAN8 in formats) then continue;
      format := cfEAN8;
      text := digits;
    end;
    last := at+2;
    exit(true);
  end;
end;

// Code 128 from a start symbol at `from`: six runs a symbol, the check
// symbol before the stop
function readCode128(const runs: TRuns; from: integer; out text: string; out last: integer): boolean;
begin
  result := false;
  if from+5 >= length(runs) then exit;
  var symbolAt := function(at: integer; stop: boolean): integer
  begin
    result := -1;
    var best := 0.7;
    var first := if stop then STOP_128 else 0;
    var lastCode := if stop then STOP_128 else STOP_128-1;
    var count := if stop then 7 else 6;
    if at+count-1 >= length(runs) then exit;
    for var s := first to lastCode do begin
      var pattern: array of integer;
      SetLength(pattern, count);
      for var i := 0 to count-1 do pattern[i] := ord(CODE128[s][i+1])-ord('0');
      var v := patternVariance(runs, at, pattern, 0.7);
      if v < best then begin
        best := v;
        result := s;
      end;
    end;
  end;
  var start := symbolAt(from, false);
  if not (start in [START_A, START_B, START_C]) then exit;
  var per := 0;
  for var i := 0 to 5 do per += runs[from+i];
  if (from = 0) or (runs[from-1]*11 < per*8) then exit;
  var codeSet := start-START_A; // 0 A, 1 B, 2 C
  var at := from+6;
  var sum := start;
  var index := 1;
  var values: array of integer;
  var shift := -1;
  while true do begin
    if at+6 >= length(runs) then exit;
    var stop := symbolAt(at, true);
    if stop = STOP_128 then break;
    var v := symbolAt(at, false);
    if v < 0 then exit;
    SetLength(values, length(values)+1);
    values[high(values)] := v;
    sum += v*index;
    inc(index);
    at += 6;
  end;
  if length(values) < 1 then exit;
  // the last value is the check symbol
  var check := values[high(values)];
  sum -= check*(length(values));
  if sum mod 103 <> check then exit;
  SetLength(values, length(values)-1);
  text := '';
  for var v in values do begin
    var current := if shift >= 0 then shift else codeSet;
    shift := -1;
    match current of
      2: begin
        if v < 100 then text += SysUtils.Format('%.2d', [v])
        else if v = CODE_A then codeSet := 0
        else if v = CODE_B then codeSet := 1;
      end;
    else
      if v < 64 then text += chr(v+32)
      else if (v < 96) and (current = 1) then text += chr(v+32)
      else if (v < 96) and (current = 0) then text += chr(v-64)
      else if v = 98 then shift := 1-current
      else if v = CODE_A then codeSet := 0
      else if v = CODE_B then codeSet := 1
      else if v = CODE_C then codeSet := 2;
    end;
  end;
  last := at+6;
  result := text <> '';
end;

// the character whose nine elements, three of them wide, match the runs
function code39Char(const runs: TRuns; from: integer): char;
begin
  result := #0;
  if from+8 >= length(runs) then exit;
  var low := MaxInt;
  var high := 0;
  for var i := 0 to 8 do begin
    low := Min(low, runs[from+i]);
    high := Max(high, runs[from+i]);
  end;
  if high < low*3 div 2 then exit;
  var threshold := (low+high)/2;
  var pattern := '';
  var wide := 0;
  for var i := 0 to 8 do
    if runs[from+i] > threshold then begin
      pattern += 'w';
      inc(wide);
    end else pattern += 'n';
  if wide <> 3 then exit;
  for var i := 1 to 44 do
    if CODE39[i] = pattern then exit(CODE39_CHARS[i]);
end;

// Code 39 from a start asterisk at `from`: nine runs a character, a narrow
// gap between, an asterisk at the end
function readCode39(const runs: TRuns; from: integer; out text: string; out last: integer): boolean;
begin
  result := false;
  if code39Char(runs, from) <> '*' then exit;
  var narrow := MaxInt;
  for var i := 0 to 8 do narrow := Min(narrow, runs[from+i]);
  if (from = 0) or (runs[from-1] < narrow*8) then exit;
  text := '';
  var at := from+10;
  while true do begin
    var ch := code39Char(runs, at);
    if ch = #0 then exit;
    if ch = '*' then break;
    text += ch;
    at += 10;
  end;
  last := at+8;
  result := text <> '';
end;

// interleaved 2 of 5 from the 1010 start at `from`: five bars and five
// spaces a pair of digits, a wide bar and a narrow one at the end
function readITF(const runs: TRuns; from: integer; out text: string; out last: integer): boolean;
begin
  result := false;
  if from+3 >= length(runs) then exit;
  if patternVariance(runs, from, [1, 1, 1, 1], 0.5) > 0.5 then exit;
  var narrow := (runs[from]+runs[from+1]+runs[from+2]+runs[from+3])/4;
  if (from = 0) or (runs[from-1] < narrow*8) then exit;
  var at := from+4;
  text := '';
  var digitOf := function(const elements: string): integer
  begin
    result := -1;
    for var d := 0 to 9 do
      if ITF_DIGITS[d] = elements then exit(d);
  end;
  while true do begin
    // the stop: a wide bar, a narrow space, a narrow bar
    if (at+2 < length(runs)) and (runs[at] > narrow*2) and (runs[at+1] < narrow*2) and (runs[at+2] < narrow*2) and ((at+3 >= length(runs)) or (runs[at+3] > narrow*5)) then break;
    if at+9 >= length(runs) then exit;
    var bars := '';
    var spaces := '';
    for var i := 0 to 4 do begin
      bars += if runs[at+i*2] > narrow*2 then 'w' else 'n';
      spaces += if runs[at+i*2+1] > narrow*2 then 'w' else 'n';
    end;
    var a := digitOf(bars);
    var b := digitOf(spaces);
    if (a < 0) or (b < 0) then exit;
    text += chr(ord('0')+a)+chr(ord('0')+b);
    at += 10;
  end;
  last := at+2;
  result := length(text) >= 6;
end;

// one row of the picture for a barcode, read left to right or the other way
function readBarcodeRow(const bits: TBits; y: integer; reversed: boolean; formats: TCodeFormats; out r: TBarRead): boolean;
begin
  result := false;
  var starts: TRuns;
  var runs := rowRuns(bits, y, starts);
  if length(runs) < 8 then exit;
  if reversed then begin
    // the runs the other way round; a row that ends dark gets an empty
    // light run in front, so the dark runs keep their odd indexes
    var n := length(runs);
    var lead := if odd(n) then 0 else 1;
    var flipped: TRuns;
    var flippedStarts: TRuns;
    SetLength(flipped, n+lead);
    SetLength(flippedStarts, n+lead);
    if lead = 1 then begin
      flipped[0] := 0;
      flippedStarts[0] := bits.width;
    end;
    for var i := 0 to n-1 do begin
      flipped[i+lead] := runs[n-1-i];
      flippedStarts[i+lead] := bits.width-starts[n-1-i]-runs[n-1-i];
    end;
    runs := flipped;
    starts := flippedStarts;
  end;
  // every dark run after a light one may start a code
  var i := 1;
  while i < length(runs)-1 do begin
    var last: integer;
    var text: string;
    var format: TCodeFormat;
    var ok := false;
    if (formats*[cfEAN13, cfEAN8, cfUPCA] <> []) and readEan(runs, i, formats, text, format, last) then ok := true
    else if (cfCode128 in formats) and readCode128(runs, i, text, last) then begin
      ok := true;
      format := cfCode128;
    end else if (cfCode39 in formats) and readCode39(runs, i, text, last) then begin
      ok := true;
      format := cfCode39;
    end else if (cfITF in formats) and readITF(runs, i, text, last) then begin
      ok := true;
      format := cfITF;
    end;
    if ok then begin
      r.ok := true;
      r.text := text;
      r.format := format;
      r.area := if reversed then Rect(bits.width-starts[last]-runs[last], y, bits.width-starts[i], y+1) else Rect(starts[i], y, starts[last]+runs[last], y+1);
      exit(true);
    end;
    i += 2;
  end;
end;

// the rows from the middle outward until one reads the same code twice
function readBarcode(const bits: TBits; formats: TCodeFormats; out r: TBarRead): boolean;
begin
  result := false;
  r := Default(TBarRead);
  var first := Default(TBarRead);
  var h := bits.height;
  var step := Max(h div 32, 1);
  for var k := 0 to h div step do begin
    var y := h div 2+(if odd(k) then (k+1) div 2*step else -(k div 2)*step);
    if (y < 0) or (y >= h) then continue;
    var row: TBarRead;
    if not readBarcodeRow(bits, y, false, formats, row) and not readBarcodeRow(bits, y, true, formats, row) then continue;
    if not first.ok then begin
      first := row;
      continue;
    end;
    if (row.text = first.text) and (row.format = first.format) then begin
      r := first;
      r.area.Top := Min(first.area.Top, row.area.Top);
      r.area.Bottom := Max(first.area.Bottom, row.area.Bottom);
      exit(true);
    end;
  end;
  // a code read on one row only still counts
  if first.ok then begin
    r := first;
    result := true;
  end;
end;

{ TCodeReader }

constructor TCodeReader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFormats := [cfQR, cfEAN13, cfEAN8, cfUPCA, cfCode39, cfCode128, cfITF];
end;

procedure TCodeReader.Clear;
begin
  FFound := false;
  FFormat := cfNone;
  FText := '';
  FBytes := nil;
  FVersion := 0;
  FMask := 0;
  FCorrected := 0;
  FCapacity := 0;
  FLevel := qrLow;
  FArea := Rect(0, 0, 0, 0);
end;

function TCodeReader.getErrorCorrectionUsed: integer;
begin
  result := if FCapacity > 0 then Min(FCorrected*100 div FCapacity, 100) else 0;
end;

function TCodeReader.ReadFile(const fileName: string): boolean;
begin
  var pic := TPicture.Create;
  try
    pic.LoadFromFile(fileName);
    result := ReadGraphic(pic.Graphic);
  finally
    pic.Free;
  end;
end;

function TCodeReader.ReadGraphic(graphic: TGraphic): boolean;
begin
  if graphic is TRasterImage then exit(ReadBitmap(TRasterImage(graphic)));
  var bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf24bit;
    bmp.SetSize(Max(graphic.Width, 1), Max(graphic.Height, 1));
    bmp.Canvas.Brush.Color := clWhite;
    bmp.Canvas.FillRect(0, 0, bmp.Width, bmp.Height);
    bmp.Canvas.Draw(0, 0, graphic);
    result := ReadBitmap(bmp);
  finally
    bmp.Free;
  end;
end;

function TCodeReader.ReadBitmap(bitmap: TRasterImage): boolean;
begin
  Clear;
  var img := bitmap.CreateIntfImage;
  try
    var w := img.Width;
    var h := img.Height;
    if (w >= 8) and (h >= 8) then begin
      var gray := grayOf(img);
      // the whole picture against one threshold, then each pixel against
      // its surroundings
      for var pass := 0 to 1 do begin
        var bits: TBits;
        if pass = 0 then binarizeGlobal(gray, w, h, bits) else binarizeLocal(gray, w, h, bits);
        if cfQR in FFormats then begin
          var qr: TQRRead;
          if readQR(bits, qr) then begin
            FFound := true;
            FFormat := cfQR;
            FText := qr.text;
            FBytes := qr.bytes;
            FVersion := qr.version;
            FLevel := qr.level;
            FMask := qr.mask;
            FCorrected := qr.corrected;
            FCapacity := qr.capacity;
            FArea := qr.area;
            break;
          end;
        end;
        if FFormats-[cfQR] <> [] then begin
          var bar: TBarRead;
          if readBarcode(bits, FFormats, bar) then begin
            FFound := true;
            FFormat := bar.format;
            FText := bar.text;
            SetLength(FBytes, length(bar.text));
            if bar.text <> '' then Move(bar.text[1], FBytes[0], length(bar.text));
            FArea := bar.area;
            break;
          end;
        end;
      end;
    end;
  finally
    img.Free;
  end;
  result := FFound;
  if Assigned(FOnDecoded) then FOnDecoded(self);
end;

end.
