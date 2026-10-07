{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit DurationEdit;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  // the fields on show: hours, minutes and seconds, with or without the
  // milliseconds, or minutes and seconds only
  TDurationFormat = (dfHMS, dfHMSms, dfMS, dfMSms, dfHM);

  { TDurationEdit }

  // a duration typed field by field: digits fill the active field, Left and
  // Right move between fields, Up, Down and the wheel step the active one.
  // The value counts milliseconds
  TDurationEdit = class(TCustomControl)
  private
    FValue, FMin, FMax: int64;
    FFormat: TDurationFormat;
    FActive: integer; // the field the keys go to
    FTyped: string; // digits typed into the active field so far
    FReadOnly, FShowSpinButtons: boolean;
    FCornerRadius, FPadding: integer;
    FBorderColor, FFocusBorderColor, FFieldColor, FActiveFieldColor: TColor;
    FHotSpin: integer; // 1 up, 2 down, 0 none
    FAntialiasing: TAntialiasSetting;
    FOnChange: TNotifyEvent;
    procedure setValue(value: int64);
    procedure setRange(index: integer; value: int64);
    function getRange(index: integer): int64;
    procedure setFormat(value: TDurationFormat);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function fieldCount: integer;
    function fieldValue(index: integer): int64;
    function fieldLimit(index: integer): int64;
    function fieldUnit(index: integer): int64;
    function fieldWidthChars(index: integer): integer;
    function fieldText(index: integer): string;
    function fieldRect(index: integer): TRect;
    function spinRect(up: boolean): TRect;
    function fieldAt(x: integer): integer;
    procedure stepActive(delta: int64);
    procedure commitTyped;
    function valueStored: boolean;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the duration as text, like the field shows it
    function Text: string;
    // reads h:m:s, m:s, with an optional .ms part; false leaves the value
    function SetText(const text: string): boolean;
    // the value as a time of day fraction
    function AsDateTime: TDateTime;
  published
    // milliseconds
    property Value: int64 index 0 read getRange write setRange default 0;
    property MinValue: int64 index 1 read getRange write setRange default 0;
    // 0 for no ceiling
    property MaxValue: int64 index 2 read getRange write setRange default 0;
    property Format: TDurationFormat read FFormat write setFormat default dfHMS;
    property ReadOnly: boolean index 0 read getFlag write setFlag default false;
    property ShowSpinButtons: boolean index 1 read getFlag write setFlag default true;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    property Padding: integer index 1 read getMetric write setMetric default 6;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FieldColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property ActiveFieldColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
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
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnResize;
  end;

implementation

uses
  Math;

const
  MS_PER_SECOND = 1000;
  MS_PER_MINUTE = 60*MS_PER_SECOND;
  MS_PER_HOUR = 60*MS_PER_MINUTE;

constructor TDurationEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FFormat := dfHMS;
  FShowSpinButtons := true;
  FCornerRadius := 4;
  FPadding := 6;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FFieldColor := clDefault;
  FActiveFieldColor := clDefault;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TDurationEdit.GetControlClassDefaultSize: TSize;
begin
  result.cx := 110;
  result.cy := 27;
end;

function TDurationEdit.valueStored: boolean;
begin
  result := true;
end;

// -- fields ----------------------

function TDurationEdit.fieldCount: integer;
begin
  result := match FFormat of
    dfHMS: 3;
    dfHMSms: 4;
    dfMS: 2;
    dfMSms: 3;
  else
    2
  end;
end;

// the unit of a field in milliseconds: hours, minutes, seconds, milliseconds
function TDurationEdit.fieldUnit(index: integer): int64;
begin
  var units: array[4] of int64;
  match FFormat of
    dfHMS: units := [MS_PER_HOUR, MS_PER_MINUTE, MS_PER_SECOND, 1];
    dfHMSms: units := [MS_PER_HOUR, MS_PER_MINUTE, MS_PER_SECOND, 1];
    dfMS: units := [MS_PER_MINUTE, MS_PER_SECOND, 1, 1];
    dfMSms: units := [MS_PER_MINUTE, MS_PER_SECOND, 1, 1];
  else
    units := [MS_PER_HOUR, MS_PER_MINUTE, 1, 1];
  end;
  result := units[EnsureRange(index, 0, 3)];
end;

// the field wraps past this; the first field has no ceiling
function TDurationEdit.fieldLimit(index: integer): int64;
begin
  if index = 0 then exit(High(int64));
  result := match fieldUnit(index) of
    MS_PER_MINUTE, MS_PER_SECOND: 60;
  else
    1000
  end;
end;

function TDurationEdit.fieldValue(index: integer): int64;
begin
  var u := fieldUnit(index);
  result := FValue div u;
  if index > 0 then result := result mod fieldLimit(index);
end;

function TDurationEdit.fieldWidthChars(index: integer): integer;
begin
  result := if fieldUnit(index) = 1 then 3 else 2;
  if index = 0 then result := Max(result, length(IntToStr(fieldValue(0))));
end;

function TDurationEdit.fieldText(index: integer): string;
begin
  if (index = FActive) and (FTyped <> '') then exit(FTyped);
  var v := fieldValue(index);
  result := IntToStr(v);
  var width := if fieldUnit(index) = 1 then 3 else 2;
  while length(result) < width do result := '0'+result;
end;

function TDurationEdit.spinRect(up: boolean): TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FShowSpinButtons then exit;
  var w := scaled(self, 14);
  var r := ClientRect;
  r.Left := r.Right-w-scaled(self, 2);
  r.Right := r.Right-scaled(self, 2);
  r.Inflate(0, -scaled(self, 2));
  var mid := (r.Top+r.Bottom) div 2;
  result := if up then Rect(r.Left, r.Top, r.Right, mid) else Rect(r.Left, mid, r.Right, r.Bottom);
end;

function TDurationEdit.fieldRect(index: integer): TRect;
begin
  var pad := scaled(self, FPadding);
  var x := pad;
  var charW := Canvas.TextWidth('0');
  var sepW := Canvas.TextWidth(':')+scaled(self, 4);
  var h := Canvas.TextHeight('0');
  var top := (ClientHeight-h) div 2;
  for var i := 0 to fieldCount-1 do begin
    var w := fieldWidthChars(i)*charW;
    if i = index then exit(Rect(x-1, top-1, x+w+1, top+h+1));
    x += w+sepW;
  end;
  result := Rect(0, 0, 0, 0);
end;

function TDurationEdit.fieldAt(x: integer): integer;
begin
  result := -1;
  for var i := 0 to fieldCount-1 do begin
    var r := fieldRect(i);
    if x < r.Right+Canvas.TextWidth(':') div 2 then exit(i);
  end;
  result := fieldCount-1;
end;

procedure TDurationEdit.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var last := fieldRect(fieldCount-1);
  PreferredWidth := last.Right+scaled(self, FPadding)+(if FShowSpinButtons then scaled(self, 18) else 0);
  PreferredHeight := Canvas.TextHeight('Hg')+scaled(self, FPadding)*2-scaled(self, 2);
end;

// -- text ----------------------

function TDurationEdit.Text: string;
begin
  result := '';
  for var i := 0 to fieldCount-1 do begin
    if i > 0 then result += if fieldUnit(i) = 1 then '.' else ':';
    var v := fieldValue(i);
    var s := IntToStr(v);
    var width := if fieldUnit(i) = 1 then 3 else 2;
    if i > 0 then while length(s) < width do s := '0'+s;
    result += s;
  end;
end;

function TDurationEdit.SetText(const text: string): boolean;
begin
  result := false;
  var s := Trim(text);
  if s = '' then exit;
  var ms: int64 := 0;
  var dot := Pos('.', s);
  if dot > 0 then begin
    var frac := Copy(s, dot+1, 3);
    while length(frac) < 3 do frac += '0';
    if not TryStrToInt64(frac, ms) then exit;
    s := Copy(s, 1, dot-1);
  end;
  var parts := s.Split([':']);
  var total: int64 := ms;
  var mul: int64 := MS_PER_SECOND;
  if FFormat = dfHM then mul := MS_PER_MINUTE;
  for var i := high(parts) downto 0 do begin
    var v: int64;
    if not TryStrToInt64(Trim(parts[i]), v) then exit;
    total += v*mul;
    mul := mul*60;
  end;
  setValue(total);
  result := true;
end;

function TDurationEdit.AsDateTime: TDateTime;
begin
  result := FValue/MS_PER_HOUR/24;
end;

// -- painting ----------------------

procedure TDurationEdit.Paint;
begin
  var border := pick(FBorderColor, clBtnShadow);
  if Focused and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := pick(FFieldColor, clWindow);
  var activeFill := pick(FActiveFieldColor, clHighlight);
  if not Enabled then field := ColorToRGB(clBtnFace);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  if Focused and Enabled and not FReadOnly then paintRoundRect(sp, fieldRect(FActive), scaled(self, 2), activeFill, clNone);
  if FShowSpinButtons then begin
    var glyph := ColorToRGB(if Enabled then clGrayText else clBtnShadow);
    for var up in [true, false] do begin
      var r := spinRect(up);
      var hot := hoverEnabled and Enabled and (FHotSpin = (if up then 1 else 2));
      if hot then paintRoundRect(sp, r, scaled(self, 2), hoverColor(field), clNone);
      paintChevron(sp, r, (if up then cdUp else cdDown), Max(scaled(self, 7), 5), (if hot then ColorToRGB(clWindowText) else glyph));
    end;
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var plain := ColorToRGB(if Enabled then clWindowText else clGrayText);
  for var i := 0 to fieldCount-1 do begin
    var r := fieldRect(i);
    var active := Focused and Enabled and not FReadOnly and (i = FActive);
    Canvas.Font.Color := if active then contrastText(activeFill) else plain;
    var text := fieldText(i);
    var box := r;
    box.Inflate(-1, -1);
    paintCenteredText(Canvas, box, text, Canvas.Font.Color);
    if i < fieldCount-1 then begin
      var sep := if fieldUnit(i+1) = 1 then '.' else ':';
      // centered in the gap before the next field
      paintCenteredText(Canvas, Rect(r.Right, r.Top, fieldRect(i+1).Left, r.Bottom), sep, plain);
    end;
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TDurationEdit.stepActive(delta: int64);
begin
  if FReadOnly or not Enabled then exit;
  commitTyped;
  setValue(FValue+delta*fieldUnit(FActive));
end;

// the digits typed replace the field
procedure TDurationEdit.commitTyped;
begin
  if FTyped = '' then exit;
  var typed := StrToInt64Def(FTyped, 0);
  FTyped := '';
  var u := fieldUnit(FActive);
  var old := fieldValue(FActive);
  if FActive > 0 then typed := typed mod fieldLimit(FActive);
  setValue(FValue+(typed-old)*u);
  Invalidate;
end;

procedure TDurationEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_LEFT: begin
      commitTyped;
      FActive := Max(FActive-1, 0);
    end;
    VK_RIGHT: begin
      commitTyped;
      FActive := Min(FActive+1, fieldCount-1);
    end;
    VK_UP: stepActive(1);
    VK_DOWN: stepActive(-1);
    VK_PRIOR: stepActive(10);
    VK_NEXT: stepActive(-10);
    VK_HOME: begin commitTyped; FActive := 0; end;
    VK_END: begin commitTyped; FActive := fieldCount-1; end;
    VK_BACK: if FTyped <> '' then Delete(FTyped, length(FTyped), 1) else if not FReadOnly then stepActive(-fieldValue(FActive));
    VK_RETURN: commitTyped;
    VK_ESCAPE: FTyped := '';
  else
    exit;
  end;
  Key := 0;
  Invalidate;
end;

procedure TDurationEdit.KeyPress(var Key: char);
begin
  inherited KeyPress(Key);
  if FReadOnly or not (Key in ['0'..'9']) then begin
    if Key in [':', '.'] then begin
      commitTyped;
      FActive := Min(FActive+1, fieldCount-1);
      Invalidate;
      Key := #0;
    end;
    exit;
  end;
  FTyped += Key;
  // a full field moves on to the next one
  var width := if fieldUnit(FActive) = 1 then 3 else 2;
  if (FActive > 0) and (length(FTyped) >= width) then begin
    commitTyped;
    if FActive < fieldCount-1 then inc(FActive);
  end;
  Invalidate;
  Key := #0;
end;

procedure TDurationEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  if FShowSpinButtons and spinRect(true).Contains(Point(X, Y)) then begin
    stepActive(1);
    exit;
  end;
  if FShowSpinButtons and spinRect(false).Contains(Point(X, Y)) then begin
    stepActive(-1);
    exit;
  end;
  commitTyped;
  FActive := fieldAt(X);
  Invalidate;
end;

procedure TDurationEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := 0;
  if FShowSpinButtons then begin
    if spinRect(true).Contains(Point(X, Y)) then hot := 1
    else if spinRect(false).Contains(Point(X, Y)) then hot := 2;
  end;
  if hot <> FHotSpin then begin
    FHotSpin := hot;
    Invalidate;
  end;
end;

procedure TDurationEdit.MouseLeave;
begin
  inherited MouseLeave;
  if FHotSpin <> 0 then begin
    FHotSpin := 0;
    Invalidate;
  end;
end;

function TDurationEdit.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result then exit;
  var local := MousePos; // the wheel position comes in client coordinates
  var f := fieldAt(local.X);
  if f >= 0 then FActive := f;
  stepActive(if WheelDelta > 0 then 1 else -1);
  result := true;
end;

procedure TDurationEdit.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TDurationEdit.DoExit;
begin
  inherited DoExit;
  commitTyped;
  Invalidate;
end;

procedure TDurationEdit.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

procedure TDurationEdit.setValue(value: int64);
begin
  if value < FMin then value := FMin;
  if (FMax > 0) and (value > FMax) then value := FMax;
  if value < 0 then value := 0;
  if FValue = value then exit;
  FValue := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

function TDurationEdit.getRange(index: integer): int64;
begin
  match index of
    0: result := FValue;
    1: result := FMin;
    _: result := FMax;
  end;
end;

procedure TDurationEdit.setRange(index: integer; value: int64);
begin
  match index of
    0: setValue(value);
    1: begin
      FMin := Max(value, 0);
      setValue(FValue);
    end;
    _: begin
      FMax := Max(value, 0);
      setValue(FValue);
    end;
  end;
end;

procedure TDurationEdit.setFormat(value: TDurationFormat);
begin
  if FFormat = value then exit;
  FFormat := value;
  FActive := 0;
  FTyped := '';
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDurationEdit.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FReadOnly else FShowSpinButtons;
end;

procedure TDurationEdit.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FReadOnly := value else FShowSpinButtons := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDurationEdit.getMetric(index: integer): integer;
begin
  result := if index = 0 then FCornerRadius else FPadding;
end;

procedure TDurationEdit.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FCornerRadius := value else FPadding := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDurationEdit.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FBorderColor;
    1: result := FFocusBorderColor;
    2: result := FFieldColor;
    _: result := FActiveFieldColor;
  end;
end;

procedure TDurationEdit.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FFocusBorderColor := value;
    2: FFieldColor := value;
    _: FActiveFieldColor := value;
  end;
  Invalidate;
end;

procedure TDurationEdit.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
