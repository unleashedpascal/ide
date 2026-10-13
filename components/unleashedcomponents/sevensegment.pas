{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SevenSegment;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  // the segments: beveled ends, round ends, square ends, rows of dots, slim
  // bars
  TSegmentStyle = (ssBeveled, ssRounded, ssSquare, ssDots, ssThin);

  // the segments of a character: bit 0 is the top one, bits 1 to 5 go round
  // clockwise (top right, bottom right, bottom, bottom left, top left) and
  // bit 6 is the middle one
  TSegmentsEvent = procedure(Sender: TObject; ch: char; var segments: byte) of object;

  { TSevenSegment }

  // a seven segment display: digits, the hex letters and the letters the
  // segments can form, a decimal point after any digit and colons between
  // them. The digits scale with the control
  TSevenSegment = class(TGraphicControl)
  private
    FText: string;
    FDigitCount, FThickness, FGap, FSlant, FSpacing, FPadding: integer;
    FAlignment: TAlignment;
    FStyle: TSegmentStyle;
    FShowInactive, FBlinkColons, FColonPhase: boolean;
    FColorOn, FColorOff: TColor;
    FTimer: TTimer;
    FAntialiasing: TAntialiasSetting;
    FOnGetSegments: TSegmentsEvent;
    procedure setText(const value: string);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setAlignment(value: TAlignment);
    procedure setStyle(value: TSegmentStyle);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure tick(Sender: TObject);
    procedure syncTimer;
  protected
    procedure Paint; override;
    procedure VisibleChanged; override;
    procedure Loaded; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the segments the display lights for a character, before OnGetSegments
    class function SegmentsOf(ch: char): byte;
  published
    // digits, letters, `-`, `_`, `=`, quotes and brackets; a `.` or `,` lights
    // the point of the digit before it, a `:` puts a colon between digits
    property Text: string read FText write setText;
    // the digit cells at least, the text aligned in them; 0 fits the text
    property DigitCount: integer index 0 read getMetric write setMetric default 0;
    // the width of a segment in percent of the digit height
    property Thickness: integer index 1 read getMetric write setMetric default 12;
    // the pixels between two segments
    property Gap: integer index 2 read getMetric write setMetric default 1;
    // the lean of the digits in degrees
    property Slant: integer index 3 read getMetric write setMetric default 6;
    // the room between two digits in percent of the digit width
    property Spacing: integer index 4 read getMetric write setMetric default 30;
    property Padding: integer index 5 read getMetric write setMetric default 4;
    property Alignment: TAlignment read FAlignment write setAlignment default taRightJustify;
    property SegmentStyle: TSegmentStyle read FStyle write setStyle default ssBeveled;
    // the unlit segments show faintly, as on a real display
    property ShowInactive: boolean index 0 read getFlag write setFlag default true;
    // the colons blink once a second
    property BlinkColons: boolean index 1 read getFlag write setFlag default false;
    // clDefault takes the colors of the theme
    property ColorOn: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ColorOff: TColor index 1 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the segments of each character, to change them or form new ones
    property OnGetSegments: TSegmentsEvent read FOnGetSegments write FOnGetSegments;
    property Align;
    property Anchors;
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
  Math;

type
  TCell = record
    segments: byte;
    point, colon: boolean;
  end;

  TFloatPoint = record
    x, y: double;
  end;

const
  // the digit width in parts of its height
  DIGIT_ASPECT = 0.52;
  // the corners a segment a to g runs between: 0 top left, 1 top right,
  // 2 and 3 the middle, 4 and 5 the bottom
  SEGMENT_ENDS: array[0..6, 0..1] of integer = ((0, 1), (1, 3), (3, 5), (4, 5), (2, 4), (0, 2), (2, 3));

constructor TSevenSegment.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  FThickness := 12;
  FGap := 1;
  FSlant := 6;
  FSpacing := 30;
  FPadding := 4;
  FAlignment := taRightJustify;
  FShowInactive := true;
  FColorOn := clDefault;
  FColorOff := clDefault;
  FColonPhase := true;
  FText := '12:34';
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 500;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TSevenSegment.GetControlClassDefaultSize: TSize;
begin
  result.cx := 160;
  result.cy := 52;
end;

procedure TSevenSegment.Loaded;
begin
  inherited Loaded;
  syncTimer;
end;

class function TSevenSegment.SegmentsOf(ch: char): byte;
begin
  result := match ch of
    '0', 'O': $3F;
    '1': $06;
    '2', 'Z', 'z': $5B;
    '3': $4F;
    '4': $66;
    '5', 'S', 's': $6D;
    '6': $7D;
    '7': $07;
    '8': $7F;
    '9', 'g': $6F;
    'A', 'a': $77;
    'B', 'b': $7C;
    'C', '[': $39;
    'c': $58;
    'D', 'd': $5E;
    'E': $79;
    'e': $7B;
    'F', 'f': $71;
    'G': $3D;
    'H', 'K', 'k', 'X', 'x': $76;
    'h': $74;
    'I', 'l': $30;
    'i': $10;
    'J', 'j': $1E;
    'L': $38;
    'M', 'm': $37;
    'N', 'n': $54;
    'o': $5C;
    'P', 'p': $73;
    'Q', 'q': $67;
    'R', 'r': $50;
    'T', 't': $78;
    'U', 'V', 'W', 'w': $3E;
    'u', 'v': $1C;
    'Y', 'y': $6E;
    ']': $0F;
    '-': $40;
    '_': $08;
    '=': $48;
    '''': $20;
    '"': $22;
    '*': $63;
  else
    0
  end;
end;

// -- painting ----------------------

procedure TSevenSegment.Paint;
begin
  var bg := GetRGBColorResolvingParent;
  var onColor := pick(FColorOn, clHighlight);
  var offColor := pick(FColorOff, blend(bg, onColor, 12));
  if not Enabled then onColor := blend(onColor, bg, 55);
  var sp := autofree beginShapes(Canvas, ClientRect, bg, FAntialiasing);

  // the cells of the text, padded to DigitCount
  var cells: array of TCell := [];
  var digits := 0;
  for var ch in FText do begin
    var last := length(cells)-1;
    if (ch in ['.', ',']) and (last >= 0) and not cells[last].colon and not cells[last].point then begin
      cells[last].point := true;
      continue;
    end;
    var cell := Default(TCell);
    if ch = ':' then cell.colon := true
    else if ch in ['.', ','] then cell.point := true
    else begin
      cell.segments := SegmentsOf(ch);
      if Assigned(FOnGetSegments) then FOnGetSegments(self, ch, cell.segments);
    end;
    if not cell.colon then inc(digits);
    cells += [cell];
  end;
  var missing := Max(FDigitCount-digits, 0);
  var before := match FAlignment of
    taLeftJustify: 0;
    taCenter: missing div 2;
  else
    missing
  end;
  var blank := Default(TCell);
  for var i := 1 to before do insert(blank, cells, 0);
  for var i := 1 to missing-before do cells += [blank];
  if length(cells) = 0 then begin
    sp.Flush;
    exit;
  end;

  // every length is a part of the digit height first, then scaled to fit
  var t := Max(FThickness, 2)/100;
  var w := DIGIT_ASPECT;
  var space := Max(w*FSpacing/100, t*1.5);
  var colonWidth := t*2.6;
  var lean := Tan(DegToRad(EnsureRange(FSlant, -20, 30)));
  var total := 0.0;
  for var cell in cells do total += (if cell.colon then colonWidth else w)+space;
  // the point of the last digit needs room after it
  total := total-space+t*1.4+Abs(lean);
  var pad := scaled(self, FPadding);
  var h := Min(ClientHeight-2*pad, (ClientWidth-2*pad)/total);
  if h < 4 then begin
    sp.Flush;
    exit;
  end;
  var width := total*h;
  var x := match FAlignment of
    taLeftJustify: pad;
    taCenter: (ClientWidth-width)/2;
  else
    ClientWidth-pad-width
  end;
  if lean < 0 then x := x-lean*h;
  var top := (ClientHeight-h)/2;
  var th := t*h;
  var half := th/2;
  var gap := scaled(self, FGap)+th*0.04;

  // a point of a digit at x0 to the canvas, leaning with the slant
  var toCanvas := function(x0, px, py: double): TPointF
  begin
    result := PointF(x0+px+(h-py)*lean, top+py);
  end;

  for var cell in cells do begin
    if cell.colon then begin
      var lit := FColonPhase or not FBlinkColons;
      var c := if lit then onColor else offColor;
      if lit or FShowInactive then
        for var py in [h*0.3, h*0.7] do begin
          var p := toCanvas(x, colonWidth*h/2, py);
          var r := Max(half*1.05, 1);
          sp.FillEllipse(p.X, p.Y, r, r, c);
        end;
      x += (colonWidth+space)*h;
      continue;
    end;
    var dw := w*h;
    var xl := half;
    var xr := dw-half;
    var yt := half;
    var ym := h/2;
    var yb := h-half;
    var cornerX := function(corner: integer): double
    begin
      result := if odd(corner) then xr else xl;
    end;
    var cornerY := function(corner: integer): double
    begin
      result := match corner shr 1 of 0: yt; 1: ym; else yb end;
    end;
    for var s := 0 to 6 do begin
      var lit := (cell.segments and (1 shl s)) <> 0;
      if not lit and not FShowInactive then continue;
      var x1 := cornerX(SEGMENT_ENDS[s, 0]);
      var y1 := cornerY(SEGMENT_ENDS[s, 0]);
      var x2 := cornerX(SEGMENT_ENDS[s, 1]);
      var y2 := cornerY(SEGMENT_ENDS[s, 1]);
      var horizontal := y1 = y2;
      if horizontal then begin
        x1 += gap;
        x2 -= gap;
      end else begin
        y1 += gap;
        y2 -= gap;
      end;
      // the outline along the center line, from its start round to its end
      var pts: array of TFloatPoint := [];
      var add := procedure(px, py: double)
      begin
        var p := Default(TFloatPoint);
        p.x := px;
        p.y := py;
        pts += [p];
      end;
      // a row of dots along the segment
      if FStyle = ssDots then begin
        var dots := 4;
        var dr := Max(half*0.7, 1);
        for var k := 0 to dots-1 do begin
          var f := (k+0.5)/dots;
          var p := toCanvas(x, x1+(x2-x1)*f, y1+(y2-y1)*f);
          sp.FillEllipse(p.X, p.Y, dr, dr, if lit then onColor else offColor);
        end;
        continue;
      end;
      var thin := half*0.45;
      match FStyle of
        ssSquare:
          if horizontal then begin
            add(x1+half, y1-half); add(x2-half, y1-half); add(x2-half, y1+half); add(x1+half, y1+half);
          end else begin
            add(x1-half, y1+half); add(x1+half, y1+half); add(x1+half, y2-half); add(x1-half, y2-half);
          end;
        // a slim bar with pointed ends
        ssThin:
          if horizontal then begin
            add(x1, y1); add(x1+thin, y1-thin); add(x2-thin, y1-thin); add(x2, y1); add(x2-thin, y1+thin); add(x1+thin, y1+thin);
          end else begin
            add(x1, y1); add(x1+thin, y1+thin); add(x1+thin, y2-thin); add(x1, y2); add(x1-thin, y2-thin); add(x1-thin, y1+thin);
          end;
        ssRounded: begin
          // the ends are half circles
          var steps := 8;
          var ax := if horizontal then x1+half else x1;
          var ay := if horizontal then y1 else y1+half;
          var bx := if horizontal then x2-half else x2;
          var by := if horizontal then y2 else y2-half;
          var base := if horizontal then Pi/2 else Pi;
          for var k := 0 to steps do begin
            var a := base+Pi*k/steps;
            add(ax+Cos(a)*half, ay+Sin(a)*half);
          end;
          for var k := 0 to steps do begin
            var a := base+Pi+Pi*k/steps;
            add(bx+Cos(a)*half, by+Sin(a)*half);
          end;
        end;
      else
        if horizontal then begin
          add(x1, y1); add(x1+half, y1-half); add(x2-half, y1-half); add(x2, y1); add(x2-half, y1+half); add(x1+half, y1+half);
        end else begin
          add(x1, y1); add(x1+half, y1+half); add(x1+half, y2-half); add(x1, y2); add(x1-half, y2-half); add(x1-half, y1+half);
        end;
      end;
      var poly: array of TPointF := [];
      SetLength(poly, length(pts));
      for var k := 0 to length(pts)-1 do poly[k] := toCanvas(x, pts[k].x, pts[k].y);
      var c := if lit then onColor else offColor;
      sp.FillPolygon(poly, c);
    end;
    // the decimal point sits in the room after the digit
    if cell.point or FShowInactive then begin
      var p := toCanvas(x, dw+Min(space*h, th*1.4)/2+half*0.2, yb);
      var c := if cell.point then onColor else offColor;
      var r := Max(half*1.05, 1);
      if FStyle = ssSquare then sp.FillRectF(p.X-r, p.Y-r, p.X+r, p.Y+r, c)
      else sp.FillEllipse(p.X, p.Y, r, r, c);
    end;
    x += (w+space)*h;
  end;
  sp.Flush;
end;

// -- behavior ----------------------

procedure TSevenSegment.tick(Sender: TObject);
begin
  FColonPhase := not FColonPhase;
  Invalidate;
end;

procedure TSevenSegment.syncTimer;
begin
  var run := FBlinkColons and (Pos(':', FText) > 0) and Visible and not (csDesigning in ComponentState) and not (csLoading in ComponentState);
  if not run then FColonPhase := true;
  FTimer.Enabled := run;
end;

procedure TSevenSegment.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

// -- properties ----------------------

procedure TSevenSegment.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  syncTimer;
  Invalidate;
end;

function TSevenSegment.getMetric(index: integer): integer;
begin
  result := match index of
    0: FDigitCount;
    1: FThickness;
    2: FGap;
    3: FSlant;
    4: FSpacing;
  else
    FPadding
  end;
end;

procedure TSevenSegment.setMetric(index: integer; value: integer);
begin
  if (index <> 3) and (value < 0) then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FDigitCount := value;
    1: FThickness := EnsureRange(value, 2, 30);
    2: FGap := value;
    3: FSlant := EnsureRange(value, -20, 30);
    4: FSpacing := value;
  else
    FPadding := value;
  end;
  Invalidate;
end;

procedure TSevenSegment.setAlignment(value: TAlignment);
begin
  if FAlignment = value then exit;
  FAlignment := value;
  Invalidate;
end;

procedure TSevenSegment.setStyle(value: TSegmentStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

function TSevenSegment.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FShowInactive else FBlinkColons;
end;

procedure TSevenSegment.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FShowInactive := value else FBlinkColons := value;
  syncTimer;
  Invalidate;
end;

function TSevenSegment.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FColorOn else FColorOff;
end;

procedure TSevenSegment.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FColorOn := value else FColorOff := value;
  Invalidate;
end;

procedure TSevenSegment.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
