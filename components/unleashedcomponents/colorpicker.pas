{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ColorPicker;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, StdCtrls, LCLType, ControlPaint;

type
  TPickerPart = (ppNone, ppField, ppHue, ppAlpha, ppSwatch);
  // where the hue bar lies against the field
  TPickerBarSide = (bsRight, bsBottom);

  { TColorPicker }

  // a color picked in place: a saturation and value field under a hue bar,
  // an alpha bar when wanted, a row of swatches and the hex code of the
  // result. Every part drags with the mouse; the arrows nudge the field
  TColorPicker = class(TCustomControl)
  private
    FHue, FSat, FVal: double; // 0..1
    FAlpha: byte;
    FShowAlpha, FShowSwatches, FShowHex, FShowPreview: boolean;
    FBarSide: TPickerBarSide;
    FBarSize, FSpacing, FSwatchSize, FMarkerSize: integer;
    FSwatches: TStrings;
    FHex: TEdit;
    FField, FHueBar: array of cardinal; // the gradients as the painter's memory holds them, rebuilt on a change of size or hue
    FFieldSize, FHueSize: TSize;
    FFieldHue: double; // the hue the field was made for
    FDrag: TPickerPart;
    FHotSwatch: integer;
    FUpdating: boolean;
    FOnChange, FOnChanging: TNotifyEvent;
    function getSelected: TColor;
    procedure setSelected(value: TColor);
    procedure setAlpha(value: byte);
    procedure setHSV(index: integer; value: integer);
    function getHSV(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setBarSide(value: TPickerBarSide);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setSwatches(value: TStrings);
    procedure swatchesChanged(Sender: TObject);
    function fieldRect: TRect;
    function hueRect: TRect;
    function alphaRect: TRect;
    function swatchRect(index: integer): TRect;
    function swatchRowRect: TRect;
    function previewRect: TRect;
    function partAt(x, y: integer): TPickerPart;
    function swatchAt(x, y: integer): integer;
    procedure rebuildField;
    procedure rebuildHue;
    procedure dragTo(part: TPickerPart; x, y: integer);
    procedure layout;
    procedure hexChanged(Sender: TObject);
    procedure hexKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure syncHex;
    procedure changed(final: boolean);
  private
    FAntialiasing: TAntialiasSetting;
    procedure setAntialiasing(value: TAntialiasSetting);
  protected
    procedure Paint; override;
    procedure DoOnResize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the color with the alpha in the high byte, $AABBGGRR
    function ColorWithAlpha: cardinal;
    // the hex code: RRGGBB, with the alpha AARRGGBB
    function HexCode: string;
    // reads RRGGBB or AARRGGBB, with or without a leading # or $
    function SetHexCode(const code: string): boolean;
    // puts the color on the swatch row, dropping the oldest past the end
    procedure RememberColor(color: TColor);
  published
    property SelectedColor: TColor read getSelected write setSelected default clRed;
    property Alpha: byte read FAlpha write setAlpha default 255;
    property Hue: integer index 0 read getHSV write setHSV default 0;
    property Saturation: integer index 1 read getHSV write setHSV default 100;
    property Value: integer index 2 read getHSV write setHSV default 100;
    property ShowAlpha: boolean index 0 read getFlag write setFlag default false;
    property ShowSwatches: boolean index 1 read getFlag write setFlag default true;
    property ShowHex: boolean index 2 read getFlag write setFlag default true;
    property ShowPreview: boolean index 3 read getFlag write setFlag default true;
    property BarSide: TPickerBarSide read FBarSide write setBarSide default bsRight;
    // the hue and alpha bars
    property BarSize: integer index 0 read getMetric write setMetric default 16;
    property Spacing: integer index 1 read getMetric write setMetric default 8;
    property SwatchSize: integer index 2 read getMetric write setMetric default 18;
    property MarkerSize: integer index 3 read getMetric write setMetric default 10;
    // hex codes, one per line
    property Swatches: TStrings read FSwatches write setSwatches;
    // after the color settled
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // on every move while a part drags
    property OnChanging: TNotifyEvent read FOnChanging write FOnChanging;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
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
    property OnResize;
  end;

implementation

uses
  Math, GraphUtil;

const
  DEFAULT_SWATCHES: array[16] of string = ('FFFFFF', 'C0C0C0', '808080', '000000', 'E53935', 'FB8C00', 'FDD835', '43A047', '00ACC1', '1E88E5', '3949AB', '8E24AA', 'D81B60', '6D4C41', 'F5F5DC', '2D2D2D');

constructor TColorPicker.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop]-[csSetCaption];
  FSat := 1;
  FVal := 1;
  FAlpha := 255;
  FShowSwatches := true;
  FShowHex := true;
  FShowPreview := true;
  FBarSize := 16;
  FSpacing := 8;
  FSwatchSize := 18;
  FMarkerSize := 10;
  FFieldHue := -1;
  FHotSwatch := -1;
  FSwatches := TStringList.Create;
  for var s in DEFAULT_SWATCHES do FSwatches.Add(s);
  TStringList(FSwatches).OnChange := @swatchesChanged;
  FHex := TEdit.Create(self);
  FHex.Parent := self;
  FHex.ParentFont := true;
  FHex.CharCase := ecUpperCase;
  FHex.MaxLength := 9;
  FHex.ControlStyle := FHex.ControlStyle+[csNoDesignSelectable];
  FHex.SetSubComponent(true);
  FHex.OnChange := @hexChanged;
  FHex.OnKeyDown := @hexKeyDown;
  TabStop := true;
  Color := clBtnFace;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
  syncHex;
end;

destructor TColorPicker.Destroy;
begin
  FSwatches.Free;
  inherited Destroy;
end;

class function TColorPicker.GetControlClassDefaultSize: TSize;
begin
  result.cx := 220;
  result.cy := 220;
end;

procedure TColorPicker.Loaded;
begin
  inherited Loaded;
  syncHex;
  layout;
end;

procedure TColorPicker.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := 0;
end;

// -- geometry ----------------------

function TColorPicker.swatchRowRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FShowSwatches or (FSwatches.Count = 0) then exit;
  var size := scaled(self, FSwatchSize);
  var bottom := ClientHeight;
  if FShowHex or FShowPreview then bottom -= FHex.Height+scaled(self, FSpacing);
  result := Rect(0, bottom-size, ClientWidth, bottom);
end;

function TColorPicker.swatchRect(index: integer): TRect;
begin
  var row := swatchRowRect;
  var size := scaled(self, FSwatchSize);
  var gap := Max(scaled(self, 3), 2);
  var perRow := Max((row.Width+gap) div (size+gap), 1);
  var x := (index mod perRow)*(size+gap);
  var y := row.Top-(index div perRow)*(size+gap);
  result := Rect(x, y, x+size, y+size);
end;

function TColorPicker.previewRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FShowPreview then exit;
  var h := FHex.Height;
  result := Rect(0, ClientHeight-h, h*2, ClientHeight);
end;

function TColorPicker.fieldRect: TRect;
begin
  var gap := scaled(self, FSpacing);
  var bar := scaled(self, FBarSize);
  var bottom := ClientHeight;
  if FShowHex or FShowPreview then bottom -= FHex.Height+gap;
  if FShowSwatches and (FSwatches.Count > 0) then begin
    var size := scaled(self, FSwatchSize);
    var swGap := Max(scaled(self, 3), 2);
    var perRow := Max((ClientWidth+swGap) div (size+swGap), 1);
    var rows := (FSwatches.Count+perRow-1) div perRow;
    bottom -= rows*(size+swGap)-swGap+gap;
  end;
  var bars := 1+(if FShowAlpha then 1 else 0);
  if FBarSide = bsRight then result := Rect(0, 0, ClientWidth-bars*(bar+gap), bottom)
  else result := Rect(0, 0, ClientWidth, bottom-bars*(bar+gap));
  if result.Right < result.Left+10 then result.Right := result.Left+10;
  if result.Bottom < result.Top+10 then result.Bottom := result.Top+10;
end;

function TColorPicker.hueRect: TRect;
begin
  var f := fieldRect;
  var gap := scaled(self, FSpacing);
  var bar := scaled(self, FBarSize);
  result := if FBarSide = bsRight then Rect(f.Right+gap, f.Top, f.Right+gap+bar, f.Bottom) else Rect(f.Left, f.Bottom+gap, f.Right, f.Bottom+gap+bar);
end;

function TColorPicker.alphaRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FShowAlpha then exit;
  var h := hueRect;
  var gap := scaled(self, FSpacing);
  var bar := scaled(self, FBarSize);
  result := if FBarSide = bsRight then Rect(h.Right+gap, h.Top, h.Right+gap+bar, h.Bottom) else Rect(h.Left, h.Bottom+gap, h.Right, h.Bottom+gap+bar);
end;

function TColorPicker.partAt(x, y: integer): TPickerPart;
begin
  var p := Point(x, y);
  if fieldRect.Contains(p) then exit(ppField);
  if hueRect.Contains(p) then exit(ppHue);
  if FShowAlpha and alphaRect.Contains(p) then exit(ppAlpha);
  if swatchAt(x, y) >= 0 then exit(ppSwatch);
  result := ppNone;
end;

function TColorPicker.swatchAt(x, y: integer): integer;
begin
  result := -1;
  if not FShowSwatches then exit;
  for var i := 0 to FSwatches.Count-1 do if swatchRect(i).Contains(Point(x, y)) then exit(i);
end;

procedure TColorPicker.layout;
begin
  if FHex = nil then exit;
  FHex.Visible := FShowHex;
  var h := FHex.Height;
  var left := if FShowPreview then previewRect.Right+scaled(self, FSpacing) else 0;
  FHex.SetBounds(left, ClientHeight-h, Max(ClientWidth-left, 40), h);
  FFieldHue := -1;
  FHueSize.cx := -1;
end;

procedure TColorPicker.DoOnResize;
begin
  inherited DoOnResize;
  layout;
  Invalidate;
end;

// -- gradients ----------------------

procedure TColorPicker.rebuildField;
begin
  var r := fieldRect;
  if (FFieldSize.cx = r.Width) and (FFieldSize.cy = r.Height) and (FFieldHue = FHue) then exit;
  FFieldSize.cx := r.Width;
  FFieldSize.cy := r.Height;
  FFieldHue := FHue;
  var w := Max(r.Width, 0);
  var h := Max(r.Height, 0);
  SetLength(FField, w*h);
  if w*h = 0 then exit;
  var pure := HSVToColor(FHue, 1, 1);
  var pr := Red(pure);
  var pg := Green(pure);
  var pb := Blue(pure);
  for var y := 0 to h-1 do begin
    var v := 1-y/Max(h-1, 1);
    var row := PCardinal(@FField[y*w]);
    for var x := 0 to w-1 do begin
      var s := x/Max(w-1, 1);
      // white toward the pure hue across, then down to black
      var cr := Round((255+(pr-255)*s)*v);
      var cg := Round((255+(pg-255)*s)*v);
      var cb := Round((255+(pb-255)*s)*v);
      row[x] := $FF000000 or (cardinal(cr) shl 16) or (cardinal(cg) shl 8) or cardinal(cb);
    end;
  end;
end;

procedure TColorPicker.rebuildHue;
begin
  var r := hueRect;
  if (FHueSize.cx = r.Width) and (FHueSize.cy = r.Height) then exit;
  FHueSize.cx := r.Width;
  FHueSize.cy := r.Height;
  var w := Max(r.Width, 0);
  var h := Max(r.Height, 0);
  SetLength(FHueBar, w*h);
  if w*h = 0 then exit;
  var vertical := FBarSide = bsRight;
  var len := if vertical then h else w;
  for var i := 0 to len-1 do begin
    var c := TSmoothPaint.PackColor(HSVToColor(i/Max(len-1, 1), 1, 1));
    if vertical then for var x := 0 to w-1 do FHueBar[i*w+x] := c
    else FHueBar[i] := c;
  end;
  // across the bar every row repeats the first
  if not vertical then for var y := 1 to h-1 do Move(FHueBar[0], FHueBar[y*w], w*SizeOf(cardinal));
end;

// -- painting ----------------------

procedure TColorPicker.Paint;
begin
  var frame := ColorToRGB(clBtnShadow);
  if Focused and ringEnabled then frame := ringColor;
  var marker := scaled(self, FMarkerSize);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);

  // the field
  var f := fieldRect;
  rebuildField;
  sp.DrawPixels(f.Left, f.Top, FFieldSize.cx, FFieldSize.cy, PCardinal(FField));
  paintRoundRect(sp, f, 0, clNone, frame);
  var mx := f.Left+Round(FSat*(f.Width-1));
  var my := f.Top+Round((1-FVal)*(f.Height-1));
  paintCircle(sp, mx, my, marker div 2, clNone, (if FVal > 0.5 then clBlack else clWhite), 2);

  // the hue bar
  var h := hueRect;
  rebuildHue;
  sp.DrawPixels(h.Left, h.Top, FHueSize.cx, FHueSize.cy, PCardinal(FHueBar));
  paintRoundRect(sp, h, 0, clNone, frame);
  if FBarSide = bsRight then begin
    var y := h.Top+Round(FHue*(h.Height-1));
    paintRoundRect(sp, Rect(h.Left-1, y-2, h.Right+1, y+3), 0, clNone, clWhite, 2);
  end else begin
    var x := h.Left+Round(FHue*(h.Width-1));
    paintRoundRect(sp, Rect(x-2, h.Top-1, x+3, h.Bottom+1), 0, clNone, clWhite, 2);
  end;

  // the alpha bar: the color over a checkerboard, fading to nothing
  if FShowAlpha then begin
    var a := alphaRect;
    var cell := Max(scaled(self, 4), 2);
    var picked := getSelected;
    var len := if FBarSide = bsRight then a.Height else a.Width;
    // each step along the bar has its two colors, over the dark and over
    // the light cells
    var overDark: array of cardinal := [];
    var overLight: array of cardinal := [];
    SetLength(overDark, len);
    SetLength(overLight, len);
    for var i := 0 to len-1 do begin
      var t := Round((1-i/Max(len-1, 1))*100);
      overDark[i] := TSmoothPaint.PackColor(blend(RGBToColor(160, 160, 160), picked, t));
      overLight[i] := TSmoothPaint.PackColor(blend(RGBToColor(220, 220, 220), picked, t));
    end;
    var bar: array of cardinal := [];
    SetLength(bar, Max(a.Width, 0)*Max(a.Height, 0));
    for var y := 0 to a.Height-1 do begin
      var row := PCardinal(@bar[y*a.Width]);
      for var x := 0 to a.Width-1 do begin
        var i := if FBarSide = bsRight then y else x;
        row[x] := if ((x div cell)+(y div cell)) mod 2 = 0 then overDark[i] else overLight[i];
      end;
    end;
    sp.DrawPixels(a.Left, a.Top, a.Width, a.Height, PCardinal(bar));
    paintRoundRect(sp, a, 0, clNone, frame);
    if FBarSide = bsRight then begin
      var y := a.Top+Round((1-FAlpha/255)*(a.Height-1));
      paintRoundRect(sp, Rect(a.Left-1, y-2, a.Right+1, y+3), 0, clNone, clWhite, 2);
    end else begin
      var x := a.Left+Round((1-FAlpha/255)*(a.Width-1));
      paintRoundRect(sp, Rect(x-2, a.Top-1, x+3, a.Bottom+1), 0, clNone, clWhite, 2);
    end;
  end;

  // the swatches
  if FShowSwatches then for var i := 0 to FSwatches.Count-1 do begin
    var r := swatchRect(i);
    var c: TColor;
    if not TryStrToInt('$'+Trim(FSwatches[i]), longint(c)) then continue;
    c := RGBToColor((c shr 16) and $FF, (c shr 8) and $FF, c and $FF);
    var border := if (i = FHotSwatch) and hoverEnabled then hoverShade(frame, clHotLight) else frame;
    paintRoundRect(sp, r, scaled(self, 3), c, border);
  end;

  // the preview
  if FShowPreview then paintRoundRect(sp, previewRect, scaled(self, 3), getSelected, frame);
end;

// -- input ----------------------

procedure TColorPicker.dragTo(part: TPickerPart; x, y: integer);
begin
  match part of
    ppField: begin
      var f := fieldRect;
      FSat := EnsureRange((x-f.Left)/Max(f.Width-1, 1), 0, 1);
      FVal := 1-EnsureRange((y-f.Top)/Max(f.Height-1, 1), 0, 1);
    end;
    ppHue: begin
      var h := hueRect;
      FHue := if FBarSide = bsRight then EnsureRange((y-h.Top)/Max(h.Height-1, 1), 0, 1) else EnsureRange((x-h.Left)/Max(h.Width-1, 1), 0, 1);
      if FHue >= 1 then FHue := 0.9999;
    end;
    ppAlpha: begin
      var a := alphaRect;
      var t := if FBarSide = bsRight then (y-a.Top)/Max(a.Height-1, 1) else (x-a.Left)/Max(a.Width-1, 1);
      FAlpha := Round((1-EnsureRange(t, 0, 1))*255);
    end;
  end;
  syncHex;
  Invalidate;
  changed(false);
end;

procedure TColorPicker.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  var part := partAt(X, Y);
  if part = ppSwatch then begin
    var i := swatchAt(X, Y);
    var c: longint;
    if (i >= 0) and TryStrToInt('$'+Trim(FSwatches[i]), c) then begin
      setSelected(RGBToColor((c shr 16) and $FF, (c shr 8) and $FF, c and $FF));
    end;
    exit;
  end;
  if part = ppNone then exit;
  FDrag := part;
  dragTo(part, X, Y);
end;

procedure TColorPicker.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDrag <> ppNone then begin
    dragTo(FDrag, X, Y);
    exit;
  end;
  var i := swatchAt(X, Y);
  if i <> FHotSwatch then begin
    FHotSwatch := i;
    Invalidate;
  end;
end;

procedure TColorPicker.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FDrag = ppNone) then exit;
  FDrag := ppNone;
  changed(true);
end;

procedure TColorPicker.MouseLeave;
begin
  inherited MouseLeave;
  if FHotSwatch >= 0 then begin
    FHotSwatch := -1;
    Invalidate;
  end;
end;

procedure TColorPicker.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var step := if ssCtrl in Shift then 0.1 else 0.01;
  match Key of
    VK_LEFT: FSat := Max(FSat-step, 0);
    VK_RIGHT: FSat := Min(FSat+step, 1);
    VK_UP: FVal := Min(FVal+step, 1);
    VK_DOWN: FVal := Max(FVal-step, 0);
    VK_PRIOR: FHue := Max(FHue-step, 0);
    VK_NEXT: FHue := Min(FHue+step, 0.9999);
  else
    exit;
  end;
  Key := 0;
  syncHex;
  Invalidate;
  changed(true);
end;

procedure TColorPicker.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TColorPicker.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TColorPicker.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  layout;
  Invalidate;
end;

// -- hex ----------------------

procedure TColorPicker.syncHex;
begin
  if FHex = nil then exit;
  FUpdating := true;
  try
    FHex.Text := HexCode;
  finally
    FUpdating := false;
  end;
end;

procedure TColorPicker.hexChanged(Sender: TObject);
begin
  if FUpdating then exit;
  // a complete code applies as it is typed; a partial one waits
  var code := Trim(FHex.Text);
  if code <> '' then if code[1] in ['#', '$'] then Delete(code, 1, 1);
  if not (length(code) in [6, 8]) then exit;
  if SetHexCode(code) then changed(true);
end;

procedure TColorPicker.hexKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then begin
    Key := 0;
    if SetHexCode(FHex.Text) then changed(true) else syncHex;
  end;
end;

function TColorPicker.HexCode: string;
begin
  var c := getSelected;
  result := IntToHex(Red(c), 2)+IntToHex(Green(c), 2)+IntToHex(Blue(c), 2);
  if FShowAlpha then result := IntToHex(FAlpha, 2)+result;
end;

function TColorPicker.SetHexCode(const code: string): boolean;
begin
  result := false;
  var s := Trim(code);
  if s <> '' then if s[1] in ['#', '$'] then Delete(s, 1, 1);
  if not (length(s) in [6, 8]) then exit;
  var v: int64;
  if not TryStrToInt64('$'+s, v) then exit;
  if length(s) = 8 then begin
    FAlpha := (v shr 24) and $FF;
    v := v and $FFFFFF;
  end;
  var h, sat, val: double;
  ColorToHSV(RGBToColor((v shr 16) and $FF, (v shr 8) and $FF, v and $FF), h, sat, val);
  FHue := Min(h, 0.9999);
  FSat := sat;
  FVal := val;
  syncHex;
  Invalidate;
  result := true;
end;

function TColorPicker.ColorWithAlpha: cardinal;
begin
  result := cardinal(ColorToRGB(getSelected)) or (cardinal(FAlpha) shl 24);
end;

procedure TColorPicker.RememberColor(color: TColor);
begin
  var code := IntToHex(Red(color), 2)+IntToHex(Green(color), 2)+IntToHex(Blue(color), 2);
  var i := FSwatches.IndexOf(code);
  if i >= 0 then FSwatches.Delete(i);
  FSwatches.Insert(0, code);
  while FSwatches.Count > 32 do FSwatches.Delete(FSwatches.Count-1);
end;

procedure TColorPicker.changed(final: boolean);
begin
  if csLoading in ComponentState then exit;
  if final then begin
    if Assigned(FOnChange) then FOnChange(self);
  end else if Assigned(FOnChanging) then FOnChanging(self);
end;

// -- properties ----------------------

function TColorPicker.getSelected: TColor;
begin
  result := HSVToColor(FHue, FSat, FVal);
end;

procedure TColorPicker.setSelected(value: TColor);
begin
  value := ColorToRGB(value);
  if value = getSelected then exit;
  var h, s, v: double;
  ColorToHSV(value, h, s, v);
  // a gray keeps the hue the bar shows
  if s > 0 then FHue := Min(h, 0.9999);
  FSat := s;
  FVal := v;
  syncHex;
  Invalidate;
  changed(true);
end;

procedure TColorPicker.setAlpha(value: byte);
begin
  if FAlpha = value then exit;
  FAlpha := value;
  syncHex;
  Invalidate;
  changed(true);
end;

function TColorPicker.getHSV(index: integer): integer;
begin
  match index of
    0: result := Round(FHue*360) mod 360;
    1: result := Round(FSat*100);
    _: result := Round(FVal*100);
  end;
end;

procedure TColorPicker.setHSV(index: integer; value: integer);
begin
  if getHSV(index) = value then exit;
  match index of
    0: FHue := EnsureRange(((value mod 360)+360) mod 360, 0, 359)/360;
    1: FSat := EnsureRange(value, 0, 100)/100;
    _: FVal := EnsureRange(value, 0, 100)/100;
  end;
  syncHex;
  Invalidate;
  changed(true);
end;

function TColorPicker.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FShowAlpha;
    1: result := FShowSwatches;
    2: result := FShowHex;
    _: result := FShowPreview;
  end;
end;

procedure TColorPicker.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowAlpha := value;
    1: FShowSwatches := value;
    2: FShowHex := value;
    _: FShowPreview := value;
  end;
  layout;
  syncHex;
  Invalidate;
end;

procedure TColorPicker.setBarSide(value: TPickerBarSide);
begin
  if FBarSide = value then exit;
  FBarSide := value;
  layout;
  Invalidate;
end;

function TColorPicker.getMetric(index: integer): integer;
begin
  match index of
    0: result := FBarSize;
    1: result := FSpacing;
    2: result := FSwatchSize;
    _: result := FMarkerSize;
  end;
end;

procedure TColorPicker.setMetric(index: integer; value: integer);
begin
  if value < 1 then value := 1;
  if getMetric(index) = value then exit;
  match index of
    0: FBarSize := value;
    1: FSpacing := value;
    2: FSwatchSize := value;
    _: FMarkerSize := value;
  end;
  layout;
  Invalidate;
end;

procedure TColorPicker.setSwatches(value: TStrings);
begin
  FSwatches.Assign(value);
end;

procedure TColorPicker.swatchesChanged(Sender: TObject);
begin
  layout;
  Invalidate;
end;

procedure TColorPicker.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
