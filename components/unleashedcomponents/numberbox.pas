{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit NumberBox;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LMessages, StdCtrls, ExtCtrls, LCLType, ControlPaint;

type
  // the buttons: stacked arrows at the right end, minus and plus at the
  // two ends, or none
  TNumberSpinStyle = (nsUpDown, nsPlusMinus, nsNone);

  { TNumberBox }

  // a number typed, stepped or dragged: Up and Down step it, Page Up and
  // Page Down take the large step, the wheel steps it while the field has
  // the focus, a drag up or down on the buttons scrubs through the values.
  // With AllowExpressions the field takes arithmetic, 2*(3+4) gives 14.
  // The value counts once Enter, the end of the focus or a button sets it;
  // Escape brings back the last one
  TNumberBox = class(TCustomControl)
  private
    FEdit: TEdit;
    FValue, FMin, FMax, FIncrement, FLargeIncrement: double;
    FDecimals, FScrubPixels: integer;
    FPrefix, FSuffix: string;
    FAllowExpressions, FAllowEmpty, FShowThousands, FWrap, FScrubbing: boolean;
    FEmpty: boolean;
    FSpinStyle: TNumberSpinStyle;
    FCornerRadius, FPadding: integer;
    FBorderColor, FFocusBorderColor, FFieldColor, FGlyphColor, FAffixColor: TColor;
    FHotButton, FPressedButton: integer; // 1 up or plus, 2 down or minus
    FRepeat: TTimer;
    FDragStart, FDragSteps: integer; // the scrub: where it began, how far it went
    FDragging: boolean;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FOnChange: TNotifyEvent;
    procedure setNumber(index: integer; value: double);
    function getNumber(index: integer): double;
    function numberStored(index: integer): boolean;
    procedure setDecimals(value: integer);
    procedure setAffix(index: integer; const value: string);
    function getAffix(index: integer): string;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setSpinStyle(value: TNumberSpinStyle);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    function getText: string;
    procedure setText(const value: string);
    function getTextHint: string;
    procedure setTextHint(const value: string);
    function getReadOnly: boolean;
    procedure setReadOnly(value: boolean);
    function getAlignment: TAlignment;
    procedure setAlignment(value: TAlignment);
    function hasLimits: boolean;
    function limited(v: double): double;
    function formatted(v: double): string;
    function buttonRect(index: integer): TRect;
    function buttonAt(x, y: integer): integer;
    function affixWidth(const s: string): integer;
    procedure layout;
    procedure showValue;
    procedure assignValue(v: double; empty: boolean);
    procedure stepBy(steps: double);
    procedure repeatTick(Sender: TObject);
    procedure editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure editKeyPress(Sender: TObject; var Key: char);
    procedure editEnter(Sender: TObject);
    procedure editExit(Sender: TObject);
    procedure editChange(Sender: TObject);
  protected
    procedure Paint; override;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure DoOnResize; override;
    procedure CreateWnd; override;
    procedure Loaded; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure FontChanged(Sender: TObject); override;
    procedure SetEnabled(Value: Boolean); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetFocus; override;
    function Focused: Boolean; override;
    // reads the field now, as Enter would; false when it holds no number
    function Commit: boolean;
    procedure Increase;
    procedure Decrease;
    procedure Clear;
    // the field holds no number; only with AllowEmpty
    function IsEmpty: boolean;
    // arithmetic of + - * / % ^ and parentheses; false for anything else
    class function Evaluate(const expression: string; out number: double): boolean;
    property Edit: TEdit read FEdit;
  published
    property Value: double index 0 read getNumber write setNumber stored numberStored;
    // MinValue equal to MaxValue leaves the value free, as with TSpinEdit
    property MinValue: double index 1 read getNumber write setNumber stored numberStored;
    property MaxValue: double index 2 read getNumber write setNumber stored numberStored;
    property Increment: double index 3 read getNumber write setNumber stored numberStored;
    property LargeIncrement: double index 4 read getNumber write setNumber stored numberStored;
    // the digits after the decimal separator
    property DecimalPlaces: integer read FDecimals write setDecimals default 0;
    // gray text before and after the number, a unit for example
    property Prefix: string index 0 read getAffix write setAffix;
    property Suffix: string index 1 read getAffix write setAffix;
    property AllowExpressions: boolean index 0 read getFlag write setFlag default true;
    property AllowEmpty: boolean index 1 read getFlag write setFlag default false;
    property ShowThousands: boolean index 2 read getFlag write setFlag default false;
    // past one limit the steps come back at the other
    property Wrap: boolean index 3 read getFlag write setFlag default false;
    // a drag up or down on the buttons changes the value
    property Scrubbing: boolean index 4 read getFlag write setFlag default true;
    property SpinStyle: TNumberSpinStyle read FSpinStyle write setSpinStyle default nsUpDown;
    // the drag one step takes
    property ScrubPixels: integer index 2 read getMetric write setMetric default 4;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    property Padding: integer index 1 read getMetric write setMetric default 6;
    property Text: string read getText write setText stored false;
    property TextHint: string read getTextHint write setTextHint;
    property ReadOnly: boolean read getReadOnly write setReadOnly default false;
    property Alignment: TAlignment read getAlignment write setAlignment default taLeftJustify;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FieldColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property GlyphColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property AffixColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    // the value changed
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
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
    property TabStop default true;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnResize;
  end;

implementation

uses
  Math;

const
  BTN_NONE = 0;
  BTN_UP = 1;
  BTN_DOWN = 2;

{ the expression reader: a recursive descent over a string with the dot as
  the decimal separator }

type
  TReader = record
    s: string;
    at: integer;
    ok: boolean;
  end;

function peek(var r: TReader): char;
begin
  while (r.at <= length(r.s)) and (r.s[r.at] = ' ') do inc(r.at);
  result := if r.at <= length(r.s) then r.s[r.at] else #0;
end;

function readSum(var r: TReader): double; forward;

function readAtom(var r: TReader): double;
begin
  result := 0;
  var c := peek(r);
  match c of
    '(': begin
      inc(r.at);
      result := readSum(r);
      if peek(r) = ')' then inc(r.at) else r.ok := false;
    end;
    '-': begin
      inc(r.at);
      result := -readAtom(r);
    end;
    '+': begin
      inc(r.at);
      result := readAtom(r);
    end;
    '0'..'9', '.': begin
      var start := r.at;
      while (r.at <= length(r.s)) and (r.s[r.at] in ['0'..'9', '.']) do inc(r.at);
      // an exponent: 1e3, 2.5E-2
      if (r.at <= length(r.s)) and (r.s[r.at] in ['e', 'E']) then begin
        var save := r.at;
        inc(r.at);
        if (r.at <= length(r.s)) and (r.s[r.at] in ['+', '-']) then inc(r.at);
        if (r.at <= length(r.s)) and (r.s[r.at] in ['0'..'9']) then begin
          while (r.at <= length(r.s)) and (r.s[r.at] in ['0'..'9']) do inc(r.at);
        end else r.at := save;
      end;
      var invariant := DefaultFormatSettings;
      invariant.DecimalSeparator := '.';
      if not TryStrToFloat(Copy(r.s, start, r.at-start), result, invariant) then r.ok := false;
    end;
  else
    r.ok := false;
  end;
end;

// the power binds to the right: 2^3^2 is 2^9
function readPower(var r: TReader): double;
begin
  result := readAtom(r);
  if r.ok and (peek(r) = '^') then begin
    inc(r.at);
    var exponent := readPower(r);
    if r.ok then
      try
        result := Power(result, exponent);
      except
        r.ok := false;
      end;
  end;
end;

function readProduct(var r: TReader): double;
begin
  result := readPower(r);
  while r.ok and (peek(r) in ['*', '/', '%']) do begin
    var op := r.s[r.at];
    inc(r.at);
    var right := readPower(r);
    if not r.ok then exit;
    match op of
      '*': result := result*right;
      '/': if right = 0 then r.ok := false else result := result/right;
    else
      if right = 0 then r.ok := false else result := result-Floor(result/right)*right;
    end;
  end;
end;

function readSum(var r: TReader): double;
begin
  result := readProduct(r);
  while r.ok and (peek(r) in ['+', '-']) do begin
    var op := r.s[r.at];
    inc(r.at);
    var right := readProduct(r);
    if not r.ok then exit;
    result := if op = '+' then result+right else result-right;
  end;
end;

class function TNumberBox.Evaluate(const expression: string; out number: double): boolean;
begin
  var r: TReader;
  r.s := expression;
  r.at := 1;
  r.ok := true;
  number := readSum(r);
  result := r.ok and (peek(r) = #0) and not IsNan(number) and not IsInfinite(number);
end;

{ TNumberBox }

constructor TNumberBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop]-[csSetCaption];
  FIncrement := 1;
  FLargeIncrement := 10;
  FAllowExpressions := true;
  FScrubbing := true;
  FScrubPixels := 4;
  FCornerRadius := 4;
  FPadding := 6;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FFieldColor := clDefault;
  FGlyphColor := clDefault;
  FAffixColor := clDefault;
  FEdit := TEdit.Create(self);
  FEdit.Parent := self;
  FEdit.BorderStyle := bsNone;
  FEdit.ParentFont := true;
  FEdit.Color := clWindow;
  FEdit.ControlStyle := FEdit.ControlStyle+[csNoDesignSelectable];
  FEdit.SetSubComponent(true);
  FEdit.OnKeyDown := @editKeyDown;
  FEdit.OnKeyPress := @editKeyPress;
  FEdit.OnEnter := @editEnter;
  FEdit.OnExit := @editExit;
  FEdit.OnChange := @editChange;
  FRepeat := TTimer.Create(self);
  FRepeat.Enabled := false;
  FRepeat.OnTimer := @repeatTick;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
  showValue;
end;

class function TNumberBox.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 27;
end;

procedure TNumberBox.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := Canvas.TextHeight('Hg')+scaled(self, FPadding)*2-scaled(self, 2);
end;

procedure TNumberBox.Loaded;
begin
  inherited Loaded;
  FValue := limited(FValue);
  showValue;
end;

// -- numbers ----------------------

function TNumberBox.hasLimits: boolean;
begin
  result := FMin <> FMax;
end;

function TNumberBox.limited(v: double): double;
begin
  result := v;
  if hasLimits then result := EnsureRange(v, Min(FMin, FMax), Max(FMin, FMax));
  // the digits on show are the digits the value keeps
  result := RoundTo(result, -EnsureRange(FDecimals, 0, 15));
end;

function TNumberBox.formatted(v: double): string;
begin
  var mask := if FShowThousands then '#,##0' else '0';
  if FDecimals > 0 then mask += '.'+StringOfChar('0', FDecimals);
  result := FormatFloat(mask, v, formatSettingsOf(FLanguage));
end;

function TNumberBox.IsEmpty: boolean;
begin
  result := FEmpty;
end;

procedure TNumberBox.showValue;
begin
  if FEdit = nil then exit;
  FEdit.Text := if FEmpty then '' else formatted(FValue);
end;

procedure TNumberBox.assignValue(v: double; empty: boolean);
begin
  if not empty then v := limited(v);
  var changed := (empty <> FEmpty) or (not empty and (v <> FValue));
  FEmpty := empty;
  if not empty then FValue := v;
  showValue;
  if changed and not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

// the separators of the format settings go, the decimal one becomes a dot,
// so 1 234,5 and 1234.5 both read
function TNumberBox.Commit: boolean;
begin
  var s := Trim(FEdit.Text);
  if s = '' then begin
    if FAllowEmpty then begin
      assignValue(FValue, true);
      exit(true);
    end;
    showValue;
    exit(false);
  end;
  for var affix in [FPrefix, FSuffix] do
    if (affix <> '') and (Pos(affix, s) > 0) then s := StringReplace(s, affix, '', [rfReplaceAll]);
  var lang := formatSettingsOf(FLanguage);
  var thousands := lang.ThousandSeparator;
  if (thousands <> lang.DecimalSeparator) and (thousands <> '.') then s := StringReplace(s, thousands, '', [rfReplaceAll]);
  s := StringReplace(s, #$C2#$A0, '', [rfReplaceAll]);
  s := StringReplace(s, lang.DecimalSeparator, '.', [rfReplaceAll]);
  var number: double;
  var invariant := DefaultFormatSettings;
  invariant.DecimalSeparator := '.';
  var ok := if FAllowExpressions then Evaluate(s, number) else TryStrToFloat(StringReplace(s, ' ', '', [rfReplaceAll]), number, invariant);
  if not ok then begin
    // what reads as no number gives way to the last value
    showValue;
    exit(false);
  end;
  assignValue(number, false);
  result := true;
end;

procedure TNumberBox.stepBy(steps: double);
begin
  if ReadOnly or not Enabled then exit;
  Commit;
  var v := (if FEmpty then 0 else FValue)+steps;
  if hasLimits and FWrap then begin
    var lo := Min(FMin, FMax);
    var hi := Max(FMin, FMax);
    if v > hi then v := lo
    else if v < lo then v := hi;
  end;
  assignValue(v, false);
  if FEdit.Focused then FEdit.SelectAll;
end;

procedure TNumberBox.Increase;
begin
  stepBy(FIncrement);
end;

procedure TNumberBox.Decrease;
begin
  stepBy(-FIncrement);
end;

procedure TNumberBox.Clear;
begin
  if FAllowEmpty then assignValue(FValue, true);
end;

// -- geometry ----------------------

function TNumberBox.affixWidth(const s: string): integer;
begin
  result := if s = '' then 0 else Canvas.TextWidth(s)+scaled(self, 4);
end;

function TNumberBox.buttonRect(index: integer): TRect;
begin
  result := Rect(0, 0, 0, 0);
  var inset := scaled(self, 2);
  match FSpinStyle of
    nsUpDown: begin
      var w := scaled(self, 16);
      var r := Rect(ClientWidth-w-inset, inset, ClientWidth-inset, ClientHeight-inset);
      var mid := (r.Top+r.Bottom) div 2;
      result := if index = BTN_UP then Rect(r.Left, r.Top, r.Right, mid) else Rect(r.Left, mid, r.Right, r.Bottom);
    end;
    nsPlusMinus: begin
      var w := ClientHeight-inset*2;
      result := if index = BTN_UP then Rect(ClientWidth-inset-w, inset, ClientWidth-inset, ClientHeight-inset) else Rect(inset, inset, inset+w, ClientHeight-inset);
    end;
  else
    ;
  end;
end;

function TNumberBox.buttonAt(x, y: integer): integer;
begin
  if FSpinStyle = nsNone then exit(BTN_NONE);
  if buttonRect(BTN_UP).Contains(Point(x, y)) then exit(BTN_UP);
  if buttonRect(BTN_DOWN).Contains(Point(x, y)) then exit(BTN_DOWN);
  result := BTN_NONE;
end;

procedure TNumberBox.layout;
begin
  if (FEdit = nil) or not HandleAllocated then exit;
  var pad := scaled(self, FPadding);
  var left := pad;
  var right := ClientWidth-pad;
  match FSpinStyle of
    nsUpDown: right := buttonRect(BTN_UP).Left-scaled(self, 2);
    nsPlusMinus: begin
      left := buttonRect(BTN_DOWN).Right+scaled(self, 4);
      right := buttonRect(BTN_UP).Left-scaled(self, 4);
    end;
  else
    ;
  end;
  left += affixWidth(FPrefix);
  right -= affixWidth(FSuffix);
  var h := FEdit.Height;
  if h <= 0 then h := Canvas.TextHeight('Hg');
  FEdit.SetBounds(left, (ClientHeight-h) div 2, Max(right-left, 10), h);
end;

procedure TNumberBox.DoOnResize;
begin
  inherited DoOnResize;
  layout;
end;

procedure TNumberBox.CreateWnd;
begin
  inherited CreateWnd;
  layout;
end;

// -- painting ----------------------

// the field goes gray with the rest of the control
procedure TNumberBox.CMEnabledChanged(var Message: TLMessage);
begin
  inherited CMEnabledChanged(Message);
  FEdit.Color := if Enabled then clWindow else clBtnFace;
  Invalidate;
end;

procedure TNumberBox.Paint;
begin
  var border := pick(FBorderColor, clBtnShadow);
  if FEdit.Focused and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := pick(FFieldColor, clWindow);
  var glyph := pick(FGlyphColor, clGrayText);
  if not Enabled then begin
    field := ColorToRGB(clBtnFace);
    glyph := blend(glyph, field, 40);
  end;
  FEdit.Color := field;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  if FSpinStyle <> nsNone then
    for var index in [BTN_UP, BTN_DOWN] do begin
      var r := buttonRect(index);
      var hot := Enabled and not ReadOnly and hoverEnabled and ((FHotButton = index) or (FPressedButton = index));
      if hot then paintRoundRect(sp, r, scaled(self, 3), (if FPressedButton = index then blend(hoverColor(field), clWindowText, 12) else hoverColor(field)), clNone);
      var color := if hot then ColorToRGB(clWindowText) else glyph;
      if FSpinStyle = nsUpDown then paintChevron(sp, r, (if index = BTN_UP then cdUp else cdDown), Max(scaled(self, 7), 5), color)
      else begin
        var cx := (r.Left+r.Right) div 2;
        var cy := (r.Top+r.Bottom) div 2;
        var half := Max(r.Height div 5, 3);
        var thick := Max(scaled(self, 2), 2);
        paintLine(sp, cx-half, cy, cx+half, cy, color, thick);
        if index = BTN_UP then paintLine(sp, cx, cy-half, cx, cy+half, color, thick);
      end;
    end;
  sp.Flush;
  if (FPrefix = '') and (FSuffix = '') then exit;
  applyTextQuality(Canvas);
  var affix := pick(FAffixColor, clGrayText);
  if FPrefix <> '' then paintCenteredText(Canvas, Rect(FEdit.Left-affixWidth(FPrefix), 0, FEdit.Left, ClientHeight), FPrefix, affix);
  if FSuffix <> '' then paintCenteredText(Canvas, Rect(FEdit.Left+FEdit.Width, 0, FEdit.Left+FEdit.Width+affixWidth(FSuffix), ClientHeight), FSuffix, affix);
end;

// -- input ----------------------

procedure TNumberBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  var hit := buttonAt(X, Y);
  if hit = BTN_NONE then begin
    FEdit.SetFocus;
    exit;
  end;
  if FEdit.CanFocus and not FEdit.Focused then FEdit.SetFocus;
  FPressedButton := hit;
  FDragStart := Y;
  FDragSteps := 0;
  FDragging := false;
  if hit = BTN_UP then Increase else Decrease;
  // a held button repeats after a pause
  FRepeat.Interval := 400;
  FRepeat.Enabled := true;
  Invalidate;
end;

procedure TNumberBox.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if (FPressedButton <> BTN_NONE) and FScrubbing then begin
    // a drag up or down turns the press into a scrub
    var steps := (FDragStart-Y) div Max(scaled(self, FScrubPixels), 1);
    if not FDragging and (Abs(FDragStart-Y) > scaled(self, 3)) then begin
      FDragging := true;
      FRepeat.Enabled := false;
      Cursor := crSizeNS;
    end;
    if FDragging and (steps <> FDragSteps) then begin
      var factor := if ssShift in Shift then FLargeIncrement else FIncrement;
      stepBy((steps-FDragSteps)*factor);
      FDragSteps := steps;
    end;
    exit;
  end;
  var hot := buttonAt(X, Y);
  if hot <> FHotButton then begin
    FHotButton := hot;
    Invalidate;
  end;
end;

procedure TNumberBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  FRepeat.Enabled := false;
  FPressedButton := BTN_NONE;
  FDragging := false;
  Cursor := crDefault;
  Invalidate;
end;

procedure TNumberBox.MouseLeave;
begin
  inherited MouseLeave;
  if FHotButton <> BTN_NONE then begin
    FHotButton := BTN_NONE;
    Invalidate;
  end;
end;

procedure TNumberBox.repeatTick(Sender: TObject);
begin
  FRepeat.Interval := 60;
  if FPressedButton = BTN_UP then Increase
  else if FPressedButton = BTN_DOWN then Decrease
  else FRepeat.Enabled := false;
end;

// the wheel steps the value only while the field has the focus, so the
// scrolling of a page never changes it on the way
function TNumberBox.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or not FEdit.Focused then exit;
  var amount := if ssShift in Shift then FLargeIncrement else FIncrement;
  stepBy(if WheelDelta > 0 then amount else -amount);
  result := true;
end;

procedure TNumberBox.editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  KeyDown(Key, Shift);
  match Key of
    VK_UP: stepBy(FIncrement);
    VK_DOWN: stepBy(-FIncrement);
    VK_PRIOR: stepBy(FLargeIncrement);
    VK_NEXT: stepBy(-FLargeIncrement);
    VK_RETURN: begin
      Commit;
      FEdit.SelectAll;
    end;
    VK_ESCAPE: begin
      showValue;
      FEdit.SelectAll;
    end;
  else
    exit;
  end;
  Key := 0;
end;

procedure TNumberBox.editKeyPress(Sender: TObject; var Key: char);
begin
  KeyPress(Key);
  // the beep of the native field on Enter and Escape
  if Key in [#13, #27] then Key := #0;
end;

procedure TNumberBox.editEnter(Sender: TObject);
begin
  Invalidate;
  DoEnter;
end;

procedure TNumberBox.editExit(Sender: TObject);
begin
  Commit;
  Invalidate;
  DoExit;
end;

procedure TNumberBox.editChange(Sender: TObject);
begin
  Invalidate;
end;

procedure TNumberBox.SetFocus;
begin
  if FEdit.CanFocus then FEdit.SetFocus else inherited SetFocus;
end;

function TNumberBox.Focused: Boolean;
begin
  result := FEdit.Focused or inherited Focused;
end;

procedure TNumberBox.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  layout;
end;

procedure TNumberBox.SetEnabled(Value: Boolean);
begin
  inherited SetEnabled(Value);
  Invalidate;
end;

// -- properties ----------------------

function TNumberBox.getNumber(index: integer): double;
begin
  result := match index of
    0: FValue;
    1: FMin;
    2: FMax;
    3: FIncrement;
  else
    FLargeIncrement
  end;
end;

function TNumberBox.numberStored(index: integer): boolean;
begin
  result := match index of
    3: FIncrement <> 1;
    4: FLargeIncrement <> 10;
  else
    getNumber(index) <> 0
  end;
end;

procedure TNumberBox.setNumber(index: integer; value: double);
begin
  match index of
    0: begin
      if csLoading in ComponentState then begin
        FValue := value;
        FEmpty := false;
        exit;
      end;
      assignValue(value, false);
    end;
    1, 2: begin
      if index = 1 then FMin := value else FMax := value;
      if not (csLoading in ComponentState) and not FEmpty then assignValue(FValue, false);
    end;
    3: FIncrement := Abs(value);
  else
    FLargeIncrement := Abs(value);
  end;
end;

procedure TNumberBox.setDecimals(value: integer);
begin
  value := EnsureRange(value, 0, 15);
  if FDecimals = value then exit;
  FDecimals := value;
  if not (csLoading in ComponentState) then assignValue(FValue, FEmpty) else showValue;
end;

function TNumberBox.getAffix(index: integer): string;
begin
  result := if index = 0 then FPrefix else FSuffix;
end;

procedure TNumberBox.setAffix(index: integer; const value: string);
begin
  if getAffix(index) = value then exit;
  if index = 0 then FPrefix := value else FSuffix := value;
  layout;
  Invalidate;
end;

function TNumberBox.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FAllowExpressions;
    1: FAllowEmpty;
    2: FShowThousands;
    3: FWrap;
  else
    FScrubbing
  end;
end;

procedure TNumberBox.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAllowExpressions := value;
    1: begin
      FAllowEmpty := value;
      if not value and FEmpty then assignValue(FValue, false);
    end;
    2: begin
      FShowThousands := value;
      showValue;
    end;
    3: FWrap := value;
  else
    FScrubbing := value;
  end;
end;

procedure TNumberBox.setSpinStyle(value: TNumberSpinStyle);
begin
  if FSpinStyle = value then exit;
  FSpinStyle := value;
  layout;
  Invalidate;
end;

function TNumberBox.getMetric(index: integer): integer;
begin
  result := match index of
    0: FCornerRadius;
    1: FPadding;
  else
    FScrubPixels
  end;
end;

procedure TNumberBox.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if (index = 2) and (value < 1) then value := 1;
  if getMetric(index) = value then exit;
  match index of
    0: FCornerRadius := value;
    1: FPadding := value;
  else
    FScrubPixels := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  layout;
  Invalidate;
end;

function TNumberBox.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBorderColor;
    1: FFocusBorderColor;
    2: FFieldColor;
    3: FGlyphColor;
  else
    FAffixColor
  end;
end;

procedure TNumberBox.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FFocusBorderColor := value;
    2: FFieldColor := value;
    3: FGlyphColor := value;
  else
    FAffixColor := value;
  end;
  Invalidate;
end;

procedure TNumberBox.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  showValue;
  Invalidate;
end;

procedure TNumberBox.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

function TNumberBox.getText: string;
begin
  result := FEdit.Text;
end;

// text set from code counts at once, like a typed text after Enter
procedure TNumberBox.setText(const value: string);
begin
  FEdit.Text := value;
  if not (csLoading in ComponentState) then Commit;
end;

function TNumberBox.getTextHint: string;
begin
  result := FEdit.TextHint;
end;

procedure TNumberBox.setTextHint(const value: string);
begin
  FEdit.TextHint := value;
end;

function TNumberBox.getReadOnly: boolean;
begin
  result := FEdit.ReadOnly;
end;

procedure TNumberBox.setReadOnly(value: boolean);
begin
  FEdit.ReadOnly := value;
  Invalidate;
end;

function TNumberBox.getAlignment: TAlignment;
begin
  result := FEdit.Alignment;
end;

procedure TNumberBox.setAlignment(value: TAlignment);
begin
  FEdit.Alignment := value;
end;

end.
