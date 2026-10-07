{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit HotKeyEdit;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Menus, LCLType, ControlPaint;

type
  THotKeyEvent = procedure(Sender: TObject; var hotKey: TShortCut; var accept: boolean) of object;

  { THotKeyEdit }

  // a field that takes a keyboard shortcut: press the keys and they show as
  // text. Backspace, Delete or Escape clear it, Tab moves on
  THotKeyEdit = class(TCustomControl)
  private
    FHotKey: TShortCut;
    FRequireModifier, FAllowEmpty, FReadOnly, FShowClear: boolean;
    FEmptyText: string;
    FCornerRadius, FPadding: integer;
    FBorderColor, FFocusBorderColor, FFieldColor: TColor;
    FHotClear: boolean;
    FAntialiasing: TAntialiasSetting;
    FOnChange: TNotifyEvent;
    FOnHotKey: THotKeyEvent;
    procedure setHotKey(value: TShortCut);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setEmptyText(const value: string);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function clearRect: TRect;
    function clearVisible: boolean;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the shortcut as text, empty for none
    function Text: string;
    procedure Clear;
  published
    property HotKey: TShortCut read FHotKey write setHotKey default 0;
    // a plain key without Ctrl, Alt or Shift is refused; function keys pass
    property RequireModifier: boolean index 0 read getFlag write setFlag default false;
    property AllowEmpty: boolean index 1 read getFlag write setFlag default true;
    property ReadOnly: boolean index 2 read getFlag write setFlag default false;
    // a cross that clears the shortcut
    property ShowClearButton: boolean index 3 read getFlag write setFlag default true;
    // shown while no shortcut is set
    property EmptyText: string read FEmptyText write setEmptyText;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    property Padding: integer index 1 read getMetric write setMetric default 6;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FieldColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // a shortcut was pressed; accept = false keeps the old one
    property OnHotKey: THotKeyEvent read FOnHotKey write FOnHotKey;
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
  Math, LCLProc;

constructor THotKeyEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FAllowEmpty := true;
  FShowClear := true;
  FEmptyText := 'Press keys...';
  FCornerRadius := 4;
  FPadding := 6;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FFieldColor := clDefault;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function THotKeyEdit.GetControlClassDefaultSize: TSize;
begin
  result.cx := 160;
  result.cy := 27;
end;

procedure THotKeyEdit.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := Canvas.TextHeight('Hg')+scaled(self, FPadding)*2-scaled(self, 2);
end;

function THotKeyEdit.Text: string;
begin
  result := if FHotKey = 0 then '' else ShortCutToText(FHotKey);
end;

procedure THotKeyEdit.Clear;
begin
  setHotKey(0);
end;

function THotKeyEdit.clearVisible: boolean;
begin
  result := FShowClear and (FHotKey <> 0) and not FReadOnly and Enabled;
end;

function THotKeyEdit.clearRect: TRect;
begin
  var size := Canvas.TextHeight('Hg')-scaled(self, 2);
  var pad := scaled(self, FPadding);
  result := Rect(ClientWidth-pad-size, (ClientHeight-size) div 2, ClientWidth-pad, (ClientHeight-size) div 2+size);
end;

// -- painting ----------------------

procedure THotKeyEdit.Paint;
begin
  var border := pick(FBorderColor, clBtnShadow);
  if Focused and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := pick(FFieldColor, clWindow);
  if not Enabled then field := ColorToRGB(clBtnFace);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  if clearVisible then begin
    var r := clearRect;
    var icon := ColorToRGB(clGrayText);
    if hoverEnabled and FHotClear then paintCircle(sp, (r.Left+r.Right) div 2, (r.Top+r.Bottom) div 2, r.Width div 2, hoverColor(field), clNone);
    paintCross(sp, r, r.Width div 2, icon);
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  var pad := scaled(self, FPadding);
  var right := if clearVisible then clearRect.Left-pad div 2 else ClientWidth-pad;
  var box := Rect(pad, 0, right, ClientHeight);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  Canvas.Brush.Style := bsClear;
  if FHotKey = 0 then begin
    Canvas.Font.Color := ColorToRGB(clGrayText);
    Canvas.TextRect(box, box.Left, box.Top, FEmptyText, style);
  end else begin
    Canvas.Font.Color := ColorToRGB(if Enabled then clWindowText else clGrayText);
    Canvas.TextRect(box, box.Left, box.Top, Text, style);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure THotKeyEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then exit;
  if (Key = VK_TAB) and not (ssCtrl in Shift) then exit;
  if FReadOnly then begin
    Key := 0;
    exit;
  end;
  // a modifier alone waits for the key that goes with it
  if Key in [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL, VK_RCONTROL, VK_LMENU, VK_RMENU] then begin
    Key := 0;
    exit;
  end;
  if (Key in [VK_BACK, VK_DELETE, VK_ESCAPE]) and (Shift*[ssCtrl, ssAlt, ssShift] = []) then begin
    if FAllowEmpty then Clear;
    Key := 0;
    exit;
  end;
  var modifiers: TShiftState := Shift*[ssCtrl, ssAlt, ssShift, ssMeta];
  var functionKey := Key in [VK_F1..VK_F24];
  if FRequireModifier and (modifiers = []) and not functionKey then begin
    Key := 0;
    exit;
  end;
  var sc: TShortCut := KeyToShortCut(Key, modifiers);
  var accept: boolean := true;
  if Assigned(FOnHotKey) then FOnHotKey(self, sc, accept);
  if accept then setHotKey(sc);
  Key := 0;
end;

procedure THotKeyEdit.KeyUp(var Key: Word; Shift: TShiftState);
begin
  inherited KeyUp(Key, Shift);
  if Key <> VK_TAB then Key := 0;
end;

procedure THotKeyEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if TabStop and CanSetFocus then SetFocus;
  if clearVisible and clearRect.Contains(Point(X, Y)) then Clear;
end;

procedure THotKeyEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := clearVisible and clearRect.Contains(Point(X, Y));
  if hot <> FHotClear then begin
    FHotClear := hot;
    Invalidate;
  end;
end;

procedure THotKeyEdit.MouseLeave;
begin
  inherited MouseLeave;
  if FHotClear then begin
    FHotClear := false;
    Invalidate;
  end;
end;

procedure THotKeyEdit.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure THotKeyEdit.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure THotKeyEdit.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

procedure THotKeyEdit.setHotKey(value: TShortCut);
begin
  if FHotKey = value then exit;
  FHotKey := value;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

function THotKeyEdit.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FRequireModifier;
    1: result := FAllowEmpty;
    2: result := FReadOnly;
    _: result := FShowClear;
  end;
end;

procedure THotKeyEdit.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FRequireModifier := value;
    1: FAllowEmpty := value;
    2: FReadOnly := value;
    _: FShowClear := value;
  end;
  Invalidate;
end;

procedure THotKeyEdit.setEmptyText(const value: string);
begin
  if FEmptyText = value then exit;
  FEmptyText := value;
  Invalidate;
end;

function THotKeyEdit.getMetric(index: integer): integer;
begin
  result := if index = 0 then FCornerRadius else FPadding;
end;

procedure THotKeyEdit.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FCornerRadius := value else FPadding := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function THotKeyEdit.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FBorderColor;
    1: result := FFocusBorderColor;
    _: result := FFieldColor;
  end;
end;

procedure THotKeyEdit.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FFocusBorderColor := value;
    _: FFieldColor := value;
  end;
  Invalidate;
end;

procedure THotKeyEdit.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
