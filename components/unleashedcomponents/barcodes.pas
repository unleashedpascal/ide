{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Barcodes;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  // Code 128 switches between its three code sets by itself; EAN and UPC
  // add the check digit to 12, 7 or 11 digits and verify a given one; ITF
  // takes digits in pairs and puts a 0 in front of an odd count
  TBarcodeSymbology = (bsCode128, bsEAN13, bsEAN8, bsUPCA, bsCode39, bsITF);

// the modules of `text` from the first bar to the last, one character per
// module: '1' a bar, '0' a space, '2' a bar of the guards that reaches into
// the text. `shown` is the text printed under the bars, check digits
// included. False when the symbology cannot hold the text
function encodeBarcode(const text: string; symbology: TBarcodeSymbology; checksum: boolean; wideRatio: integer; out modules, shown: string): boolean;

// the tables of the symbologies, shared with the reader
const
  // the widths of bar, space, bar, space, bar, space of the 107 symbols of
  // Code 128; the stop symbol has a seventh, a last bar
  CODE128: array[0..106] of string[7] = (
    '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213',
    '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211', '221132',
    '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211',
    '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113', '132311', '211313',
    '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331',
    '231131', '213113', '213311', '213131', '311123', '311321', '331121', '312113', '312311', '332111',
    '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214',
    '112412', '122114', '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111',
    '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141',
    '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141',
    '114131', '311141', '411131', '211412', '211214', '211232', '2331112');
  START_A = 103;
  START_B = 104;
  START_C = 105;
  STOP_128 = 106;
  CODE_A = 101; // in B; in C as well
  CODE_B = 100; // in A and in C
  CODE_C = 99;  // in A and in B

  // the seven modules of the digits on the left in odd parity; the even
  // parity mirrors them, the right side inverts them
  EAN_L: array[0..9] of string[7] = ('0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011');
  // the parity of the six left digits of EAN-13, picked by the first digit
  EAN_PARITY: array[0..9] of string[6] = ('LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL');

  CODE39_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%*';
  // bar, space, bar ... of each character, narrow or wide
  CODE39: array[1..44] of string[9] = (
    'nnnwwnwnn', 'wnnwnnnnw', 'nnwwnnnnw', 'wnwwnnnnn', 'nnnwwnnnw', 'wnnwwnnnn', 'nnwwwnnnn', 'nnnwnnwnw', 'wnnwnnwnn', 'nnwwnnwnn',
    'wnnnnwnnw', 'nnwnnwnnw', 'wnwnnwnnn', 'nnnnwwnnw', 'wnnnwwnnn', 'nnwnwwnnn', 'nnnnnwwnw', 'wnnnnwwnn', 'nnwnnwwnn', 'nnnnwwwnn',
    'wnnnnnnww', 'nnwnnnnww', 'wnwnnnnwn', 'nnnnwnnww', 'wnnnwnnwn', 'nnwnwnnwn', 'nnnnnnwww', 'wnnnnnwwn', 'nnwnnnwwn', 'nnnnwnwwn',
    'wwnnnnnnw', 'nwwnnnnnw', 'wwwnnnnnn', 'nwnnwnnnw', 'wwnnwnnnn', 'nwwnwnnnn', 'nwnnnnwnw', 'wwnnnnwnn', 'nwwnnnwnn', 'nwnwnwnnn',
    'nwnwnnnwn', 'nwnnnwnwn', 'nnnwnwnwn', 'nwnnwnwnn');

  // the five elements of a digit of interleaved 2 of 5
  ITF_DIGITS: array[0..9] of string[5] = ('nnwwn', 'wnnnw', 'nwnnw', 'wwnnn', 'nnwnw', 'wnwnn', 'nwwnn', 'nnnww', 'wnnwn', 'nwnwn');

type
  { TBarcode }

  // a linear barcode of Text with the text under it. The bars fill the
  // width in whole pixels per module where they fit, so scanners read
  // them; ModuleWidth fixes the pixels instead
  TBarcode = class(TGraphicControl)
  private
    FText, FModules, FShown: string;
    FSymbology: TBarcodeSymbology;
    FValid, FStale, FShowText, FChecksum, FTransparentLight: boolean;
    FModuleWidth, FBarHeight, FQuietZone, FWideRatio, FTextSpacing: integer;
    FDarkColor, FLightColor: TColor;
    FAntialiasing: TAntialiasSetting;
    procedure setText(const value: string);
    procedure setSymbology(value: TBarcodeSymbology);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure rebuild;
    procedure changed;
    function quietModules: integer;
    procedure render(target: TCanvas; const area: TRect; module: double; barsHeight: integer; light: TColor);
  protected
    procedure Paint; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the text fits the symbology
    function Valid: boolean;
    // the modules from the first bar to the last, as encodeBarcode gives them
    function Modules: string;
    // the text under the bars, with the check digits
    function ShownText: string;
    // the code into a bitmap, `module` pixels per module and bars `height`
    // pixels high, the quiet zone and the text included
    procedure SaveToBitmap(bitmap: TBitmap; module, height: integer);
    procedure SaveToFile(const fileName: string; module, height: integer);
  published
    property Text: string read FText write setText;
    property Symbology: TBarcodeSymbology read FSymbology write setSymbology default bsCode128;
    property ShowText: boolean index 0 read getFlag write setFlag default true;
    // a check character for Code 39 (modulo 43) and ITF (modulo 10); the
    // others always carry one
    property Checksum: boolean index 1 read getFlag write setFlag default false;
    // the spaces show the parent; off, LightColor fills the control
    property TransparentLight: boolean index 2 read getFlag write setFlag default false;
    // pixels per module; 0 fits the control
    property ModuleWidth: integer index 0 read getMetric write setMetric default 0;
    // the height of the bars; 0 fills the control
    property BarHeight: integer index 1 read getMetric write setMetric default 0;
    // the light modules on both sides, as the standards ask; EAN and UPC
    // keep at least 11 for the digit printed outside
    property QuietZone: integer index 2 read getMetric write setMetric default 10;
    // a wide element of Code 39 and ITF in narrow ones, 2 or 3
    property WideRatio: integer index 3 read getMetric write setMetric default 3;
    // between the bars and the text
    property TextSpacing: integer index 4 read getMetric write setMetric default 2;
    property DarkColor: TColor index 0 read getPartColor write setPartColor default clBlack;
    property LightColor: TColor index 1 read getPartColor write setPartColor default clWhite;
    // smooths the bars when a module gets less than a pixel
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
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

function allDigits(const s: string): boolean;
begin
  result := s <> '';
  for var ch in s do
    if not (ch in ['0'..'9']) then exit(false);
end;

// the check digit of EAN, UPC and ITF: weights 3 and 1 from the right
function mod10Check(const digits: string): char;
begin
  var sum := 0;
  for var k := length(digits) downto 1 do
    sum += (ord(digits[k])-ord('0'))*(if odd(length(digits)-k) then 1 else 3);
  result := chr(ord('0')+(10-sum mod 10) mod 10);
end;

// the elements as modules, the first a bar: '1'..'4' module widths
procedure addWidths(var modules: string; const widths: string);
begin
  var bar := true;
  for var w in widths do begin
    modules += StringOfChar(if bar then '1' else '0', ord(w)-ord('0'));
    bar := not bar;
  end;
end;

procedure addNarrowWide(var modules: string; const elements: string; wide: integer; bar: boolean);
begin
  for var e in elements do begin
    modules += StringOfChar(if bar then '1' else '0', if e = 'w' then wide else 1);
    bar := not bar;
  end;
end;

function encode128(const text: string; out modules: string): boolean;
begin
  modules := '';
  for var ch in text do
    if ord(ch) > 127 then exit(false);
  if text = '' then exit(false);
  var n := length(text);
  var digitRun := function(p: integer): integer
  begin
    result := 0;
    while (p+result <= n) and (text[p+result] in ['0'..'9']) do inc(result);
  end;
  var valueIn := function(codeSet: char; ch: char): integer
  begin
    if (codeSet = 'A') and (ord(ch) < 32) then result := ord(ch)+64 else result := ord(ch)-32;
  end;
  var values: array of integer := [];
  var codeSet: char;
  var run := digitRun(1);
  if (run >= 4) or ((run = n) and (n >= 2) and not odd(n)) then codeSet := 'C'
  else if ord(text[1]) < 32 then codeSet := 'A'
  else codeSet := 'B';
  values += [match codeSet of 'A': START_A; 'B': START_B; else START_C end];
  var i := 1;
  while i <= n do begin
    if codeSet = 'C' then begin
      if digitRun(i) >= 2 then begin
        values += [(ord(text[i])-ord('0'))*10+ord(text[i+1])-ord('0')];
        i += 2;
        continue;
      end;
      codeSet := if ord(text[i]) < 32 then 'A' else 'B';
      values += [if codeSet = 'A' then CODE_A else CODE_B];
      continue;
    end;
    // a long run of digits goes in pairs; an odd one leaves its first
    // digit in the set it starts in
    run := digitRun(i);
    if (run >= 6) or ((run >= 4) and (i+run-1 = n)) then begin
      if odd(run) then begin
        values += [valueIn(codeSet, text[i])];
        inc(i);
      end;
      codeSet := 'C';
      values += [CODE_C];
      continue;
    end;
    var ch := text[i];
    if (codeSet = 'B') and (ord(ch) < 32) then begin
      codeSet := 'A';
      values += [CODE_A];
    end else if (codeSet = 'A') and (ord(ch) >= 96) then begin
      codeSet := 'B';
      values += [CODE_B];
    end;
    values += [valueIn(codeSet, ch)];
    inc(i);
  end;
  var sum := values[0];
  for var k := 1 to length(values)-1 do sum += values[k]*k;
  values += [sum mod 103, STOP_128];
  for var v in values do addWidths(modules, CODE128[v]);
  result := true;
end;

// the digits of an EAN or UPC: one short of `size` gets its check digit,
// a full one has to carry the right one
function eanDigits(const text: string; size: integer; out digits: string): boolean;
begin
  digits := text;
  if not allDigits(text) then exit(false);
  if length(text) = size-1 then digits := text+mod10Check(text)
  else if (length(text) <> size) or (mod10Check(Copy(text, 1, size-1)) <> text[size]) then exit(false);
  result := true;
end;

procedure addEanRight(var modules: string; digit: char);
begin
  // the right digits are the left odd ones with bars and spaces swapped
  for var m in EAN_L[ord(digit)-ord('0')] do modules += (if m = '1' then '0' else '1');
end;

function encodeEan13(const digits: string): string;
begin
  result := '202';
  var parity := EAN_PARITY[ord(digits[1])-ord('0')];
  for var k := 2 to 7 do begin
    var code := EAN_L[ord(digits[k])-ord('0')];
    // the even parity is the odd one inverted and read backwards
    if parity[k-1] = 'G' then
      for var j := 7 downto 1 do result += (if code[j] = '1' then '0' else '1')
    else result += code;
  end;
  result += '02020';
  for var k := 8 to 13 do addEanRight(result, digits[k]);
  result += '202';
end;

function encodeBarcode(const text: string; symbology: TBarcodeSymbology; checksum: boolean; wideRatio: integer; out modules, shown: string): boolean;
begin
  modules := '';
  shown := text;
  var wide := EnsureRange(wideRatio, 2, 3);
  match symbology of
    bsCode128: begin
      result := encode128(text, modules);
      shown := '';
      for var ch in text do
        if ord(ch) >= 32 then shown += ch;
    end;
    bsEAN13: begin
      result := eanDigits(text, 13, shown);
      if result then modules := encodeEan13(shown);
    end;
    bsUPCA: begin
      result := eanDigits(text, 12, shown);
      if result then begin
        // UPC-A is EAN-13 with a 0 in front; the bars of its first and
        // its last digit reach down like the guards
        modules := encodeEan13('0'+shown);
        for var k := 4 to 10 do
          if modules[k] = '1' then modules[k] := '2';
        for var k := 86 to 92 do
          if modules[k] = '1' then modules[k] := '2';
      end;
    end;
    bsEAN8: begin
      result := eanDigits(text, 8, shown);
      if result then begin
        modules := '202';
        for var k := 1 to 4 do modules += EAN_L[ord(shown[k])-ord('0')];
        modules += '02020';
        for var k := 5 to 8 do addEanRight(modules, shown[k]);
        modules += '202';
      end;
    end;
    bsCode39: begin
      var data := UpperCase(text);
      result := data <> '';
      for var ch in data do
        if (ch = '*') or (Pos(ch, CODE39_CHARS) = 0) then exit(false);
      if checksum then begin
        var sum := 0;
        for var ch in data do sum += Pos(ch, CODE39_CHARS)-1;
        data += CODE39_CHARS[sum mod 43+1];
      end;
      shown := data;
      data := '*'+data+'*';
      for var k := 1 to length(data) do begin
        if k > 1 then modules += '0';
        addNarrowWide(modules, CODE39[Pos(data[k], CODE39_CHARS)], wide, true);
      end;
    end;
  else
    begin
      result := allDigits(text);
      if not result then exit;
      var data := text;
      if checksum then data += mod10Check(data);
      if odd(length(data)) then data := '0'+data;
      shown := data;
      modules := '1010';
      var k := 1;
      while k < length(data) do begin
        // the first digit of a pair in the bars, the second in the spaces
        var bars := ITF_DIGITS[ord(data[k])-ord('0')];
        var spaces := ITF_DIGITS[ord(data[k+1])-ord('0')];
        for var j := 1 to 5 do begin
          modules += StringOfChar('1', if bars[j] = 'w' then wide else 1);
          modules += StringOfChar('0', if spaces[j] = 'w' then wide else 1);
        end;
        k += 2;
      end;
      modules += StringOfChar('1', wide)+'01';
    end;
  end;
  if not result then modules := '';
end;

{ TBarcode }

constructor TBarcode.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  FText := 'UNLEASHED-128';
  FShowText := true;
  FQuietZone := 10;
  FWideRatio := 3;
  FTextSpacing := 2;
  FDarkColor := clBlack;
  FLightColor := clWhite;
  FStale := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TBarcode.GetControlClassDefaultSize: TSize;
begin
  result.cx := 220;
  result.cy := 80;
end;

procedure TBarcode.rebuild;
begin
  if not FStale then exit;
  FStale := false;
  FValid := encodeBarcode(FText, FSymbology, FChecksum, FWideRatio, FModules, FShown);
end;

function TBarcode.Valid: boolean;
begin
  rebuild;
  result := FValid;
end;

function TBarcode.Modules: string;
begin
  rebuild;
  result := FModules;
end;

function TBarcode.ShownText: string;
begin
  rebuild;
  result := FShown;
end;

function TBarcode.quietModules: integer;
begin
  result := FQuietZone;
  if FSymbology in [bsEAN13, bsUPCA] then result := Max(result, 11);
end;

// -- painting ----------------------

// the bars over `area`, the quiet zone and the text included
procedure TBarcode.render(target: TCanvas; const area: TRect; module: double; barsHeight: integer; light: TColor);
begin
  rebuild;
  var dark := ColorToRGB(FDarkColor);
  if not Enabled then dark := blend(dark, light, 50);
  target.Font := Font;
  applyTextQuality(target);
  var th := if FShowText then target.TextHeight('0') else 0;
  var gap := if FShowText then scaled(self, FTextSpacing) else 0;
  var total := length(FModules)+2*quietModules;
  // a whole pixel for the first bar: Round takes halves to the even side,
  // which would eat the spaces of one module
  var x0 := area.Left+Floor((area.Width-total*module)/2+quietModules*module);
  var top := area.Top+Max((area.Height-barsHeight-gap-th) div 2, 0);
  var bottom := top+barsHeight;
  var guards := FSymbology in [bsEAN13, bsEAN8, bsUPCA];
  var whole := Frac(module) = 0;
  // shapes of a fraction of a pixel go through the smooth painter
  var sp := if whole then TSmoothPaint.CreateDirect(target) else beginShapes(target, area, light, FAntialiasing);
  try
    var k := 1;
    while k <= length(FModules) do begin
      if FModules[k] = '0' then begin
        inc(k);
        continue;
      end;
      var kind := FModules[k];
      var first := k;
      while (k <= length(FModules)) and (FModules[k] = kind) do inc(k);
      var y2 := if (kind = '2') and FShowText then bottom+gap+th div 2 else bottom;
      sp.FillRectF(x0+(first-1)*module, top, x0+(k-1)*module, y2, dark);
    end;
  finally
    sp.Free;
  end;
  if not FShowText then exit;
  target.Brush.Style := bsClear;
  target.Font.Color := dark;
  var style := target.TextStyle;
  style.Alignment := taCenter;
  style.Layout := tlTop;
  style.SingleLine := true;
  style.Clipping := false;
  style.Opaque := false;
  style.ShowPrefix := false;
  var textTop := bottom+gap;
  var put := procedure(fromModule, toModule: double; const s: string)
  begin
    var r := Rect(Round(x0+fromModule*module), textTop, Round(x0+toModule*module), textTop+th);
    target.TextRect(r, r.Left, r.Top, s, style);
  end;
  // the digits of EAN and UPC sit in groups between the guards, the outer
  // ones of EAN-13 and UPC-A in the quiet zone
  if guards and (FSymbology = bsEAN13) and (length(FShown) = 13) then begin
    put(-quietModules, -1, FShown[1]);
    put(3, 45, Copy(FShown, 2, 6));
    put(50, 92, Copy(FShown, 8, 6));
  end else if guards and (FSymbology = bsUPCA) and (length(FShown) = 12) then begin
    put(-quietModules, -1, FShown[1]);
    put(10, 45, Copy(FShown, 2, 5));
    put(50, 85, Copy(FShown, 7, 5));
    put(96, 95+quietModules, FShown[12]);
  end else if guards and (FSymbology = bsEAN8) and (length(FShown) = 8) then begin
    put(3, 31, Copy(FShown, 1, 4));
    put(36, 64, Copy(FShown, 5, 4));
  end else put(0, length(FModules), FShown);
  target.Brush.Style := bsSolid;
end;

procedure TBarcode.Paint;
begin
  rebuild;
  var back := GetRGBColorResolvingParent;
  var light := if FTransparentLight then back else ColorToRGB(FLightColor);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := light;
  Canvas.FillRect(ClientRect);
  if not FValid then begin
    // a dashed frame and the reason
    Canvas.Pen.Color := ColorToRGB(clGrayText);
    Canvas.Pen.Style := psDash;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
    Canvas.Pen.Style := psSolid;
    Canvas.Font := Font;
    applyTextQuality(Canvas);
    var names: array[TBarcodeSymbology] of string := ('Code 128', 'EAN-13', 'EAN-8', 'UPC-A', 'Code 39', 'ITF');
    paintCenteredText(Canvas, ClientRect, (if FText = '' then 'No text' else 'Not valid for '+names[FSymbology]), ColorToRGB(clGrayText));
    Canvas.Brush.Style := bsSolid;
    exit;
  end;
  Canvas.Font := Font;
  var th := if FShowText then Canvas.TextHeight('0')+scaled(self, FTextSpacing) else 0;
  var total := length(FModules)+2*quietModules;
  var module: double := if FModuleWidth > 0 then scaled(self, FModuleWidth) else ClientWidth/Max(total, 1);
  // whole pixels per module wherever they fit
  if (FModuleWidth = 0) and (module >= 1) then module := Floor(module);
  var bars := if FBarHeight > 0 then Min(scaled(self, FBarHeight), ClientHeight-th) else ClientHeight-th-2;
  render(Canvas, ClientRect, module, Max(bars, 1), light);
end;

procedure TBarcode.SaveToBitmap(bitmap: TBitmap; module, height: integer);
begin
  rebuild;
  module := Max(module, 1);
  bitmap.PixelFormat := pf24bit;
  bitmap.Canvas.Font := Font;
  var th := if FShowText then bitmap.Canvas.TextHeight('0')+scaled(self, FTextSpacing) else 0;
  bitmap.SetSize((length(FModules)+2*quietModules)*module, Max(height, 1)+th);
  bitmap.Canvas.Brush.Color := ColorToRGB(FLightColor);
  bitmap.Canvas.FillRect(0, 0, bitmap.Width, bitmap.Height);
  if FValid then render(bitmap.Canvas, Rect(0, 0, bitmap.Width, bitmap.Height), module, Max(height, 1), ColorToRGB(FLightColor));
end;

procedure TBarcode.SaveToFile(const fileName: string; module, height: integer);
begin
  var bmp := autofree TBitmap.Create;
  SaveToBitmap(bmp, module, height);
  var png := autofree TPortableNetworkGraphic.Create;
  png.Assign(bmp);
  png.SaveToFile(fileName);
end;

procedure TBarcode.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  rebuild;
  var module := Max(scaled(self, FModuleWidth), 1);
  if FModuleWidth = 0 then module := scaled(self, 2);
  PreferredWidth := (length(FModules)+2*quietModules)*module;
  Canvas.Font := Font;
  var th := if FShowText then Canvas.TextHeight('0')+scaled(self, FTextSpacing) else 0;
  PreferredHeight := (if FBarHeight > 0 then scaled(self, FBarHeight) else scaled(self, 50))+th+2;
end;

// -- properties ----------------------

procedure TBarcode.changed;
begin
  FStale := true;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TBarcode.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  changed;
end;

procedure TBarcode.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  changed;
end;

procedure TBarcode.setSymbology(value: TBarcodeSymbology);
begin
  if FSymbology = value then exit;
  FSymbology := value;
  changed;
end;

function TBarcode.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowText;
    1: FChecksum;
  else
    FTransparentLight
  end;
end;

procedure TBarcode.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowText := value;
    1: FChecksum := value;
  else
    FTransparentLight := value;
  end;
  changed;
end;

function TBarcode.getMetric(index: integer): integer;
begin
  result := match index of
    0: FModuleWidth;
    1: FBarHeight;
    2: FQuietZone;
    3: FWideRatio;
  else
    FTextSpacing
  end;
end;

procedure TBarcode.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FModuleWidth := value;
    1: FBarHeight := value;
    2: FQuietZone := value;
    3: FWideRatio := EnsureRange(value, 2, 3);
  else
    FTextSpacing := value;
  end;
  changed;
end;

function TBarcode.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FDarkColor else FLightColor;
end;

procedure TBarcode.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FDarkColor := value else FLightColor := value;
  Invalidate;
end;

procedure TBarcode.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
