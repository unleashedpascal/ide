{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit QRCode;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics;

type
  // how much of the code may be lost and still read: 7, 15, 25 or 30 percent
  TQRErrorLevel = (qrLow, qrMedium, qrQuartile, qrHigh);
  TQRModules = array of array of boolean;

// encodes `text` in byte mode into the smallest version that holds it;
// returns the module grid, empty when the text does not fit
function encodeQR(const text: string; level: TQRErrorLevel; out modules: TQRModules): boolean;
// the mask pattern `mask` covers module x, y
function maskBit(mask, x, y: integer): boolean;

// the tables of the standard, shared with the reader
const
  // data codewords per version and level, versions 1..40
  DATA_CODEWORDS: array[1..40, TQRErrorLevel] of integer = (
    (19, 16, 13, 9), (34, 28, 22, 16), (55, 44, 34, 26), (80, 64, 48, 36), (108, 86, 62, 46),
    (136, 108, 76, 60), (156, 124, 88, 66), (194, 154, 110, 86), (232, 182, 132, 100), (274, 216, 154, 122),
    (324, 254, 180, 140), (370, 290, 206, 158), (428, 334, 244, 180), (461, 365, 261, 197), (523, 415, 295, 223),
    (589, 453, 325, 253), (647, 507, 367, 283), (721, 563, 397, 313), (795, 627, 445, 341), (861, 669, 485, 385),
    (932, 714, 512, 406), (1006, 782, 568, 442), (1094, 860, 614, 464), (1174, 914, 664, 514), (1276, 1000, 718, 538),
    (1370, 1062, 754, 596), (1468, 1128, 808, 628), (1531, 1193, 871, 661), (1631, 1267, 911, 701), (1735, 1373, 985, 745),
    (1843, 1455, 1033, 793), (1955, 1541, 1115, 845), (2071, 1631, 1171, 901), (2191, 1725, 1231, 961), (2306, 1812, 1286, 986),
    (2434, 1914, 1354, 1054), (2566, 1992, 1426, 1096), (2702, 2102, 1502, 1142), (2812, 2216, 1582, 1222), (2956, 2334, 1666, 1276));
  // error correction codewords per block
  EC_PER_BLOCK: array[1..40, TQRErrorLevel] of integer = (
    (7, 10, 13, 17), (10, 16, 22, 28), (15, 26, 18, 22), (20, 18, 26, 16), (26, 24, 18, 22),
    (18, 16, 24, 28), (20, 18, 18, 26), (24, 22, 22, 26), (30, 22, 20, 24), (18, 26, 24, 28),
    (20, 30, 28, 24), (24, 22, 26, 28), (26, 22, 24, 22), (30, 24, 20, 24), (22, 24, 30, 24),
    (24, 28, 24, 30), (28, 28, 28, 28), (30, 26, 28, 28), (28, 26, 26, 26), (28, 26, 30, 28),
    (28, 26, 28, 30), (28, 28, 30, 24), (30, 28, 30, 30), (30, 28, 30, 30), (26, 28, 30, 30),
    (28, 28, 28, 30), (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30),
    (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30),
    (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30), (30, 28, 30, 30));
  // number of error correction blocks
  BLOCKS: array[1..40, TQRErrorLevel] of integer = (
    (1, 1, 1, 1), (1, 1, 1, 1), (1, 1, 2, 2), (1, 2, 2, 4), (1, 2, 4, 4),
    (2, 4, 4, 4), (2, 4, 6, 5), (2, 4, 6, 6), (2, 5, 8, 8), (4, 5, 8, 8),
    (4, 5, 8, 11), (4, 8, 10, 11), (4, 9, 12, 16), (4, 9, 16, 16), (6, 10, 12, 18),
    (6, 10, 17, 16), (6, 11, 16, 19), (6, 13, 18, 21), (7, 14, 21, 25), (8, 16, 20, 25),
    (8, 17, 23, 25), (9, 17, 23, 34), (9, 18, 25, 30), (10, 20, 27, 32), (12, 21, 29, 35),
    (12, 23, 34, 37), (12, 25, 34, 40), (13, 26, 35, 42), (14, 28, 38, 45), (15, 29, 40, 48),
    (16, 31, 43, 51), (17, 33, 45, 54), (18, 35, 48, 57), (19, 37, 51, 60), (19, 38, 53, 63),
    (20, 40, 56, 66), (21, 43, 59, 70), (22, 45, 62, 74), (24, 47, 65, 77), (25, 49, 68, 81));
  // alignment pattern center coordinates per version
  ALIGN_POS: array[1..40] of array[0..6] of integer = (
    (0, 0, 0, 0, 0, 0, 0), (6, 18, 0, 0, 0, 0, 0), (6, 22, 0, 0, 0, 0, 0), (6, 26, 0, 0, 0, 0, 0), (6, 30, 0, 0, 0, 0, 0),
    (6, 34, 0, 0, 0, 0, 0), (6, 22, 38, 0, 0, 0, 0), (6, 24, 42, 0, 0, 0, 0), (6, 26, 46, 0, 0, 0, 0), (6, 28, 50, 0, 0, 0, 0),
    (6, 30, 54, 0, 0, 0, 0), (6, 32, 58, 0, 0, 0, 0), (6, 34, 62, 0, 0, 0, 0), (6, 26, 46, 66, 0, 0, 0), (6, 26, 48, 70, 0, 0, 0),
    (6, 26, 50, 74, 0, 0, 0), (6, 30, 54, 78, 0, 0, 0), (6, 30, 56, 82, 0, 0, 0), (6, 30, 58, 86, 0, 0, 0), (6, 34, 62, 90, 0, 0, 0),
    (6, 28, 50, 72, 94, 0, 0), (6, 26, 50, 74, 98, 0, 0), (6, 30, 54, 78, 102, 0, 0), (6, 28, 54, 80, 106, 0, 0), (6, 32, 58, 84, 110, 0, 0),
    (6, 30, 58, 86, 114, 0, 0), (6, 34, 62, 90, 118, 0, 0), (6, 26, 50, 74, 98, 122, 0), (6, 30, 54, 78, 102, 126, 0), (6, 26, 52, 78, 104, 130, 0),
    (6, 30, 56, 82, 108, 134, 0), (6, 34, 60, 86, 112, 138, 0), (6, 30, 58, 86, 114, 142, 0), (6, 34, 62, 90, 118, 146, 0), (6, 30, 54, 78, 102, 126, 150),
    (6, 24, 50, 76, 102, 128, 154), (6, 28, 54, 80, 106, 132, 158), (6, 32, 58, 84, 110, 136, 162), (6, 26, 54, 82, 110, 138, 166), (6, 30, 58, 86, 114, 142, 170));
  // the level bits in the format information
  LEVEL_BITS: array[TQRErrorLevel] of integer = (1, 0, 3, 2);


type

  { TQRCode }

  // a QR code of Text, drawn to fill the control. The modules stay square;
  // ModuleSize fixes their size instead of the fit
  TQRCode = class(TGraphicControl)
  private
    FText: string;
    FLevel: TQRErrorLevel;
    FModuleSize, FQuietZone: integer;
    FDarkColor, FLightColor: TColor;
    FRounded, FTransparentLight: boolean;
    FModules: TQRModules;
    FValid, FStale: boolean;
    procedure setText(const value: string);
    procedure setLevel(value: TQRErrorLevel);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure rebuild;
  protected
    procedure Paint; override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the text fits a code
    function Valid: boolean;
    // modules on a side, 0 without a code
    function Size: integer;
    // the code into a bitmap, `scale` pixels per module
    procedure SaveToBitmap(bitmap: TBitmap; scale: integer);
    procedure SaveToFile(const fileName: string; scale: integer);
  published
    property Text: string read FText write setText;
    property ErrorLevel: TQRErrorLevel read FLevel write setLevel default qrMedium;
    // pixels per module; 0 fits the control
    property ModuleSize: integer index 0 read getMetric write setMetric default 0;
    // light modules around the code, as the standard asks
    property QuietZone: integer index 1 read getMetric write setMetric default 4;
    property DarkColor: TColor index 0 read getPartColor write setPartColor default clBlack;
    property LightColor: TColor index 1 read getPartColor write setPartColor default clWhite;
    // the dark modules as dots instead of squares; scanners still read it
    property Rounded: boolean index 0 read getFlag write setFlag default false;
    // the light modules show the parent; off, LightColor fills them
    property TransparentLight: boolean index 1 read getFlag write setFlag default false;
    property Align;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Hint;
    property ParentColor;
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
  Math, ControlPaint;

// -- the encoder ----------------------

var
  gfExp: array[256] of byte;
  gfLog: array[256] of byte;

procedure initGaloisField;
begin
  var x := 1;
  for var i := 0 to 254 do begin
    gfExp[i] := x;
    gfLog[x] := i;
    x := x shl 1;
    if x >= 256 then x := x xor $11D;
  end;
  gfExp[255] := gfExp[0];
end;

function gfMul(a, b: byte): byte;
begin
  if (a = 0) or (b = 0) then exit(0);
  result := gfExp[(gfLog[a]+gfLog[b]) mod 255];
end;

// the generator polynomial of `degree` error correction codewords
function generator(degree: integer): TBytes;
begin
  SetLength(result, degree+1);
  result[0] := 1;
  for var i := 1 to degree do result[i] := 0;
  for var i := 0 to degree-1 do begin
    for var j := degree downto 1 do result[j] := result[j-1] xor gfMul(result[j], gfExp[i]);
    result[0] := gfMul(result[0], gfExp[i]);
  end;
end;

// the error correction codewords of a data block
function remainder(const data: TBytes; const gen: TBytes): TBytes;
begin
  var degree := length(gen)-1;
  SetLength(result, degree);
  for var i := 0 to degree-1 do result[i] := 0;
  for var b in data do begin
    var factor := b xor result[0];
    Move(result[1], result[0], degree-1);
    result[degree-1] := 0;
    // result[0] is the highest power, so it takes the generator from x^(degree-1)
    // down; gen runs from x^0 up and its leading 1 stays out
    for var i := 0 to degree-1 do result[i] := result[i] xor gfMul(gen[degree-1-i], factor);
  end;
end;

function sizeOfVersion(version: integer): integer;
begin
  result := version*4+17;
end;

// the capacity of a version in bytes of a byte mode segment
function byteCapacity(version: integer; level: TQRErrorLevel): integer;
begin
  var bits := DATA_CODEWORDS[version, level]*8;
  var lengthBits := if version <= 9 then 8 else 16;
  result := (bits-4-lengthBits) div 8;
end;

type
  TBitBuffer = record
    bits: array of byte;
    count: integer;
  end;

procedure appendBits(var buf: TBitBuffer; value: cardinal; bitCount: integer);
begin
  for var i := bitCount-1 downto 0 do begin
    if buf.count >= length(buf.bits) then SetLength(buf.bits, buf.count+256);
    buf.bits[buf.count] := (value shr i) and 1;
    inc(buf.count);
  end;
end;

type
  TGrid = record
    size: integer;
    dark: array of array of boolean;
    fixed: array of array of boolean; // function patterns, not masked
  end;

procedure setModule(var g: TGrid; x, y: integer; dark, fixed: boolean);
begin
  if (x < 0) or (y < 0) or (x >= g.size) or (y >= g.size) then exit;
  g.dark[y][x] := dark;
  g.fixed[y][x] := fixed;
end;

procedure drawFinder(var g: TGrid; cx, cy: integer);
begin
  for var dy := -4 to 4 do for var dx := -4 to 4 do begin
    var d := Max(Abs(dx), Abs(dy));
    setModule(g, cx+dx, cy+dy, (d <> 2) and (d <> 4), true);
  end;
end;

procedure drawAlignment(var g: TGrid; cx, cy: integer);
begin
  for var dy := -2 to 2 do for var dx := -2 to 2 do setModule(g, cx+dx, cy+dy, Max(Abs(dx), Abs(dy)) <> 1, true);
end;

procedure drawFormat(var g: TGrid; level: TQRErrorLevel; mask: integer);
begin
  var data := (LEVEL_BITS[level] shl 3) or mask;
  var rem := data;
  for var i := 0 to 9 do rem := (rem shl 1) xor ((rem shr 9)*$537);
  var bits := ((data shl 10) or rem) xor $5412;
  for var i := 0 to 5 do setModule(g, 8, i, ((bits shr i) and 1) <> 0, true);
  setModule(g, 8, 7, ((bits shr 6) and 1) <> 0, true);
  setModule(g, 8, 8, ((bits shr 7) and 1) <> 0, true);
  setModule(g, 7, 8, ((bits shr 8) and 1) <> 0, true);
  for var i := 9 to 14 do setModule(g, 14-i, 8, ((bits shr i) and 1) <> 0, true);
  for var i := 0 to 7 do setModule(g, g.size-1-i, 8, ((bits shr i) and 1) <> 0, true);
  for var i := 8 to 14 do setModule(g, 8, g.size-15+i, ((bits shr i) and 1) <> 0, true);
  setModule(g, 8, g.size-8, true, true);
end;

procedure drawVersion(var g: TGrid; version: integer);
begin
  if version < 7 then exit;
  var rem := version;
  for var i := 0 to 11 do rem := (rem shl 1) xor ((rem shr 11)*$1F25);
  var bits := (version shl 12) or rem;
  for var i := 0 to 17 do begin
    var bit := ((bits shr i) and 1) <> 0;
    var a := g.size-11+i mod 3;
    var b := i div 3;
    setModule(g, a, b, bit, true);
    setModule(g, b, a, bit, true);
  end;
end;

procedure drawFunctionPatterns(var g: TGrid; version: integer; level: TQRErrorLevel);
begin
  for var i := 0 to g.size-1 do begin
    setModule(g, 6, i, i mod 2 = 0, true);
    setModule(g, i, 6, i mod 2 = 0, true);
  end;
  drawFinder(g, 3, 3);
  drawFinder(g, g.size-4, 3);
  drawFinder(g, 3, g.size-4);
  var pos := ALIGN_POS[version];
  var n := 0;
  while (n < 7) and (pos[n] <> 0) do inc(n);
  for var i := 0 to n-1 do for var j := 0 to n-1 do begin
    // the alignments skip the three finders
    if ((i = 0) and (j = 0)) or ((i = 0) and (j = n-1)) or ((i = n-1) and (j = 0)) then continue;
    drawAlignment(g, pos[i], pos[j]);
  end;
  drawFormat(g, level, 0);
  drawVersion(g, version);
end;

function maskBit(mask, x, y: integer): boolean;
begin
  result := match mask of
    0: (x+y) mod 2 = 0;
    1: y mod 2 = 0;
    2: x mod 3 = 0;
    3: (x+y) mod 3 = 0;
    4: (x div 3+y div 2) mod 2 = 0;
    5: (x*y) mod 2+(x*y) mod 3 = 0;
    6: ((x*y) mod 2+(x*y) mod 3) mod 2 = 0;
  else
    ((x+y) mod 2+(x*y) mod 3) mod 2 = 0
  end;
end;

// the codewords into the grid, zigzagging up and down two columns at a time
procedure placeData(var g: TGrid; const codewords: TBytes);
begin
  var bitIndex := 0;
  var total := length(codewords)*8;
  var right := g.size-1;
  while right >= 1 do begin
    if right = 6 then right := 5;
    for var vert := 0 to g.size-1 do begin
      for var j := 0 to 1 do begin
        var x := right-j;
        var upward := ((right+1) and 2) = 0;
        var y := if upward then g.size-1-vert else vert;
        if g.fixed[y][x] or (bitIndex >= total) then continue;
        g.dark[y][x] := ((codewords[bitIndex shr 3] shr (7-(bitIndex and 7))) and 1) <> 0;
        inc(bitIndex);
      end;
    end;
    right -= 2;
  end;
end;

procedure applyMask(var g: TGrid; mask: integer);
begin
  for var y := 0 to g.size-1 do for var x := 0 to g.size-1 do if not g.fixed[y][x] and maskBit(mask, x, y) then g.dark[y][x] := not g.dark[y][x];
end;

// the penalty of the standard: runs, blocks, finder-like patterns, balance
function penalty(const g: TGrid): integer;
begin
  result := 0;
  var n := g.size;
  for var y := 0 to n-1 do begin
    var run := 1;
    for var x := 1 to n-1 do begin
      if g.dark[y][x] = g.dark[y][x-1] then begin
        inc(run);
        if run = 5 then result += 3 else if run > 5 then inc(result);
      end else run := 1;
    end;
  end;
  for var x := 0 to n-1 do begin
    var run := 1;
    for var y := 1 to n-1 do begin
      if g.dark[y][x] = g.dark[y-1][x] then begin
        inc(run);
        if run = 5 then result += 3 else if run > 5 then inc(result);
      end else run := 1;
    end;
  end;
  for var y := 0 to n-2 do for var x := 0 to n-2 do begin
    var c := g.dark[y][x];
    if (g.dark[y][x+1] = c) and (g.dark[y+1][x] = c) and (g.dark[y+1][x+1] = c) then result += 3;
  end;
  const PATTERN: array[11] of boolean = (true, false, true, true, true, false, true, false, false, false, false);
  for var y := 0 to n-1 do for var x := 0 to n-11 do begin
    var hit := true;
    var hitRev := true;
    for var k := 0 to 10 do begin
      if g.dark[y][x+k] <> PATTERN[k] then hit := false;
      if g.dark[y][x+k] <> PATTERN[10-k] then hitRev := false;
    end;
    if hit or hitRev then result += 40;
  end;
  for var x := 0 to n-1 do for var y := 0 to n-11 do begin
    var hit := true;
    var hitRev := true;
    for var k := 0 to 10 do begin
      if g.dark[y+k][x] <> PATTERN[k] then hit := false;
      if g.dark[y+k][x] <> PATTERN[10-k] then hitRev := false;
    end;
    if hit or hitRev then result += 40;
  end;
  var darkCount := 0;
  for var y := 0 to n-1 do for var x := 0 to n-1 do if g.dark[y][x] then inc(darkCount);
  // the smallest k with (45-5k)% <= dark <= (55+5k)%
  var k := 0;
  while (darkCount*20 < (9-k)*n*n) or (darkCount*20 > (11+k)*n*n) do inc(k);
  result += k*10;
end;

function encodeQR(const text: string; level: TQRErrorLevel; out modules: TQRModules): boolean;
begin
  result := false;
  modules := nil;
  var version := 0;
  for var v := 1 to 40 do if byteCapacity(v, level) >= length(text) then begin
    version := v;
    break;
  end;
  if version = 0 then exit;
  // the data: mode, count, the bytes, the terminator, padding
  var buf := Default(TBitBuffer);
  appendBits(buf, 4, 4);
  appendBits(buf, length(text), (if version <= 9 then 8 else 16));
  for var c in text do appendBits(buf, ord(c), 8);
  var capacity := DATA_CODEWORDS[version, level]*8;
  appendBits(buf, 0, Min(4, capacity-buf.count));
  while buf.count mod 8 <> 0 do appendBits(buf, 0, 1);
  var pad := $EC;
  while buf.count < capacity do begin
    appendBits(buf, pad, 8);
    pad := if pad = $EC then $11 else $EC;
  end;
  var data: TBytes;
  SetLength(data, capacity div 8);
  for var i := 0 to high(data) do begin
    var b := 0;
    for var k := 0 to 7 do b := (b shl 1) or buf.bits[i*8+k];
    data[i] := b;
  end;
  // the blocks: the short ones first, the long ones one byte more
  var blockCount := BLOCKS[version, level];
  var ecLen := EC_PER_BLOCK[version, level];
  var total := length(data)+blockCount*ecLen;
  var shortLen := length(data) div blockCount;
  var longBlocks := length(data) mod blockCount;
  var gen := generator(ecLen);
  var dataBlocks: array of TBytes;
  var ecBlocks: array of TBytes;
  SetLength(dataBlocks, blockCount);
  SetLength(ecBlocks, blockCount);
  var offset := 0;
  for var b := 0 to blockCount-1 do begin
    var len := shortLen+(if b >= blockCount-longBlocks then 1 else 0);
    dataBlocks[b] := Copy(data, offset, len);
    ecBlocks[b] := remainder(dataBlocks[b], gen);
    offset += len;
  end;
  var codewords: TBytes;
  SetLength(codewords, total);
  var k := 0;
  for var i := 0 to shortLen do for var b := 0 to blockCount-1 do if i < length(dataBlocks[b]) then begin
    codewords[k] := dataBlocks[b][i];
    inc(k);
  end;
  for var i := 0 to ecLen-1 do for var b := 0 to blockCount-1 do begin
    codewords[k] := ecBlocks[b][i];
    inc(k);
  end;
  // the grid, then the mask with the lowest penalty
  var g: TGrid;
  g.size := sizeOfVersion(version);
  SetLength(g.dark, g.size, g.size);
  SetLength(g.fixed, g.size, g.size);
  drawFunctionPatterns(g, version, level);
  placeData(g, codewords);
  var best := -1;
  var bestScore := MaxInt;
  var saved := g;
  SetLength(saved.dark, g.size, g.size);
  for var y := 0 to g.size-1 do for var x := 0 to g.size-1 do saved.dark[y][x] := g.dark[y][x];
  for var mask := 0 to 7 do begin
    for var y := 0 to g.size-1 do for var x := 0 to g.size-1 do g.dark[y][x] := saved.dark[y][x];
    drawFormat(g, level, mask);
    applyMask(g, mask);
    var score := penalty(g);
    if score < bestScore then begin
      bestScore := score;
      best := mask;
    end;
  end;
  for var y := 0 to g.size-1 do for var x := 0 to g.size-1 do g.dark[y][x] := saved.dark[y][x];
  drawFormat(g, level, best);
  applyMask(g, best);
  SetLength(modules, g.size, g.size);
  for var y := 0 to g.size-1 do for var x := 0 to g.size-1 do modules[y][x] := g.dark[y][x];
  result := true;
end;

// -- the control ----------------------

constructor TQRCode.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FLevel := qrMedium;
  FQuietZone := 4;
  FDarkColor := clBlack;
  FLightColor := clWhite;
  FStale := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TQRCode.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 120;
end;

procedure TQRCode.rebuild;
begin
  if not FStale then exit;
  FStale := false;
  FValid := (FText <> '') and encodeQR(FText, FLevel, FModules);
  if not FValid then FModules := nil;
end;

function TQRCode.Valid: boolean;
begin
  rebuild;
  result := FValid;
end;

function TQRCode.Size: integer;
begin
  rebuild;
  result := length(FModules);
end;

procedure TQRCode.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var n := Size+FQuietZone*2;
  var m := if FModuleSize > 0 then scaled(self, FModuleSize) else 2;
  PreferredWidth := n*m;
  PreferredHeight := n*m;
end;

procedure TQRCode.SaveToBitmap(bitmap: TBitmap; scale: integer);
begin
  rebuild;
  var n := length(FModules);
  if scale < 1 then scale := 1;
  var total := (n+FQuietZone*2)*scale;
  bitmap.PixelFormat := pf24bit;
  bitmap.SetSize(total, total);
  bitmap.Canvas.Brush.Style := bsSolid;
  bitmap.Canvas.Brush.Color := ColorToRGB(FLightColor);
  bitmap.Canvas.FillRect(0, 0, total, total);
  bitmap.Canvas.Brush.Color := ColorToRGB(FDarkColor);
  for var y := 0 to n-1 do for var x := 0 to n-1 do if FModules[y][x] then bitmap.Canvas.FillRect((x+FQuietZone)*scale, (y+FQuietZone)*scale, (x+FQuietZone+1)*scale, (y+FQuietZone+1)*scale);
end;

procedure TQRCode.SaveToFile(const fileName: string; scale: integer);
begin
  var bmp := autofree TBitmap.Create;
  SaveToBitmap(bmp, scale);
  if LowerCase(ExtractFileExt(fileName)) = '.png' then begin
    var png := autofree TPortableNetworkGraphic.Create;
    png.Assign(bmp);
    png.SaveToFile(fileName);
  end else bmp.SaveToFile(fileName);
end;

procedure TQRCode.Paint;
begin
  rebuild;
  var light := ColorToRGB(FLightColor);
  var dark := ColorToRGB(FDarkColor);
  if not Enabled then dark := blend(dark, light, 50);
  Canvas.Brush.Style := bsSolid;
  if not FTransparentLight then begin
    Canvas.Brush.Color := light;
    Canvas.FillRect(ClientRect);
  end;
  var n := length(FModules);
  if n = 0 then begin
    if FText <> '' then paintCenteredText(Canvas, ClientRect, 'too long', ColorToRGB(clGrayText));
    exit;
  end;
  var cells := n+FQuietZone*2;
  var m := if FModuleSize > 0 then scaled(self, FModuleSize) else Max(Min(ClientWidth, ClientHeight) div cells, 1);
  var left := (ClientWidth-cells*m) div 2+FQuietZone*m;
  var top := (ClientHeight-cells*m) div 2+FQuietZone*m;
  if not FTransparentLight then begin
    Canvas.Brush.Color := light;
    Canvas.FillRect(left-FQuietZone*m, top-FQuietZone*m, left+(n+FQuietZone)*m, top+(n+FQuietZone)*m);
  end;
  Canvas.Brush.Color := dark;
  Canvas.Pen.Style := psClear;
  for var y := 0 to n-1 do for var x := 0 to n-1 do if FModules[y][x] then begin
    if FRounded and (m >= 4) then Canvas.Ellipse(left+x*m, top+y*m, left+(x+1)*m, top+(y+1)*m)
    else Canvas.FillRect(left+x*m, top+y*m, left+(x+1)*m, top+(y+1)*m);
  end;
  Canvas.Pen.Style := psSolid;
end;

// -- properties ----------------------

procedure TQRCode.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  FStale := true;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TQRCode.setLevel(value: TQRErrorLevel);
begin
  if FLevel = value then exit;
  FLevel := value;
  FStale := true;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TQRCode.getMetric(index: integer): integer;
begin
  result := if index = 0 then FModuleSize else FQuietZone;
end;

procedure TQRCode.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FModuleSize := value else FQuietZone := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TQRCode.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FRounded else FTransparentLight;
end;

procedure TQRCode.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FRounded := value else FTransparentLight := value;
  Invalidate;
end;

function TQRCode.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FDarkColor else FLightColor;
end;

procedure TQRCode.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FDarkColor := value else FLightColor := value;
  Invalidate;
end;

initialization
  initGaloisField;
end.
