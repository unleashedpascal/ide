{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PasswordEdit;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, StdCtrls, LCLType, LMessages, ControlPaint;

type
  // psNone for an empty field, then four steps of a password getting harder to guess
  TPasswordStrength = (psNone, psWeak, psFair, psGood, psStrong);
  TStrengthPosition = (spBelow, spInside, spNone);
  TStrengthEvent = procedure(Sender: TObject; const password: string; var strength: TPasswordStrength) of object;

  { TPasswordEdit }

  // a password field with an eye that reveals the text, a strength bar and a
  // caps lock warning. The strength counts length and the kinds of
  // characters; OnGetStrength replaces that
  TPasswordEdit = class(TCustomControl)
  private
    FEdit: TEdit;
    FRevealed, FShowReveal, FShowCapsLock, FCapsLockOn: boolean;
    FStrengthPosition: TStrengthPosition;
    FMinLength, FCornerRadius, FPadding, FIconSize: integer;
    FPasswordChar: char;
    FHotReveal: boolean;
    FIconColor, FBorderColor, FFocusBorderColor, FWeakColor, FFairColor, FGoodColor, FStrongColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnChange: TNotifyEvent;
    FOnGetStrength: TStrengthEvent;
    function getText: string;
    procedure setText(const value: string);
    function getTextHint: string;
    procedure setTextHint(const value: string);
    function getMaxLength: integer;
    procedure setMaxLength(value: integer);
    procedure setRevealed(value: boolean);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setStrengthPosition(value: TStrengthPosition);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPasswordChar(value: char);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function iconSizePx: integer;
    function revealRect: TRect;
    function capsRect: TRect;
    function fieldRect: TRect;
    function barRect: TRect;
    procedure layout;
    procedure editChange(Sender: TObject);
    procedure editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure editEnter(Sender: TObject);
    procedure editExit(Sender: TObject);
    procedure pollCapsLock;
  protected
    procedure Paint; override;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure DoOnResize; override;
    procedure CreateWnd; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetFocus; override;
    function Focused: Boolean; override;
    // the strength of the text now
    function Strength: TPasswordStrength;
    procedure Clear;
    property Edit: TEdit read FEdit;
  published
    property Text: string read getText write setText;
    property TextHint: string read getTextHint write setTextHint;
    property MaxLength: integer read getMaxLength write setMaxLength default 0;
    // the text shows in the clear
    property Revealed: boolean read FRevealed write setRevealed default false;
    property ShowRevealButton: boolean index 0 read getFlag write setFlag default true;
    // a mark while caps lock is on and the field has the focus
    property ShowCapsLockWarning: boolean index 1 read getFlag write setFlag default true;
    property StrengthPosition: TStrengthPosition read FStrengthPosition write setStrengthPosition default spBelow;
    // shorter passwords count as weak
    property MinLength: integer index 0 read getMetric write setMetric default 8;
    property CornerRadius: integer index 1 read getMetric write setMetric default 4;
    property Padding: integer index 2 read getMetric write setMetric default 6;
    property IconSize: integer index 3 read getMetric write setMetric default 0;
    property PasswordChar: char read FPasswordChar write setPasswordChar default '*';
    // clDefault takes the colors of the theme
    property IconColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property WeakColor: TColor index 3 read getPartColor write setPartColor default clRed;
    property FairColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property GoodColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property StrongColor: TColor index 6 read getPartColor write setPartColor default clGreen;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnGetStrength: TStrengthEvent read FOnGetStrength write FOnGetStrength;
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
  Math, LCLIntf;

constructor TPasswordEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop]-[csSetCaption];
  FShowReveal := true;
  FShowCapsLock := true;
  FStrengthPosition := spBelow;
  FMinLength := 8;
  FCornerRadius := 4;
  FPadding := 6;
  FPasswordChar := '*';
  FIconColor := clDefault;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FWeakColor := clRed;
  FFairColor := clDefault;
  FGoodColor := clDefault;
  FStrongColor := clGreen;
  FEdit := TEdit.Create(self);
  FEdit.Parent := self;
  FEdit.BorderStyle := bsNone;
  FEdit.ParentFont := true;
  FEdit.Color := clWindow;
  FEdit.PasswordChar := FPasswordChar;
  FEdit.ControlStyle := FEdit.ControlStyle+[csNoDesignSelectable];
  FEdit.SetSubComponent(true);
  FEdit.OnChange := @editChange;
  FEdit.OnKeyDown := @editKeyDown;
  FEdit.OnEnter := @editEnter;
  FEdit.OnExit := @editExit;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TPasswordEdit.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 32;
end;

procedure TPasswordEdit.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := Max(Canvas.TextHeight('Hg'), iconSizePx)+scaled(self, FPadding)*2-scaled(self, 2);
  if FStrengthPosition = spBelow then PreferredHeight += scaled(self, 5);
end;

// -- geometry ----------------------

function TPasswordEdit.iconSizePx: integer;
begin
  result := if FIconSize > 0 then scaled(self, FIconSize) else Canvas.TextHeight('Hg')-scaled(self, 2);
end;

function TPasswordEdit.fieldRect: TRect;
begin
  result := ClientRect;
  if FStrengthPosition = spBelow then result.Bottom -= scaled(self, 5);
end;

function TPasswordEdit.barRect: TRect;
begin
  var f := fieldRect;
  var pad := scaled(self, FPadding);
  match FStrengthPosition of
    spBelow: result := Rect(f.Left+pad, f.Bottom+scaled(self, 1), f.Right-pad, ClientHeight);
    spInside: result := Rect(f.Left+pad, f.Bottom-scaled(self, 4), f.Right-pad, f.Bottom-scaled(self, 2));
  else
    result := Rect(0, 0, 0, 0);
  end;
end;

function TPasswordEdit.revealRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FShowReveal then exit;
  var f := fieldRect;
  var size := iconSizePx;
  var pad := scaled(self, FPadding);
  var top := f.Top+(f.Height-size) div 2;
  result := Rect(f.Right-pad-size, top, f.Right-pad, top+size);
end;

function TPasswordEdit.capsRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not (FShowCapsLock and FCapsLockOn) then exit;
  var f := fieldRect;
  var size := iconSizePx;
  var pad := scaled(self, FPadding);
  var top := f.Top+(f.Height-size) div 2;
  var right := if FShowReveal then revealRect.Left-pad div 2 else f.Right-pad;
  result := Rect(right-size, top, right, top+size);
end;

procedure TPasswordEdit.layout;
begin
  if (FEdit = nil) or not HandleAllocated then exit;
  var f := fieldRect;
  var pad := scaled(self, FPadding);
  var right := f.Right-pad;
  if FShowReveal then right := revealRect.Left-pad div 2;
  if FShowCapsLock and FCapsLockOn then right := capsRect.Left-pad div 2;
  var h := FEdit.Height;
  if h <= 0 then h := Canvas.TextHeight('Hg');
  FEdit.SetBounds(f.Left+pad, f.Top+(f.Height-h) div 2, Max(right-f.Left-pad, 10), h);
end;

procedure TPasswordEdit.DoOnResize;
begin
  inherited DoOnResize;
  layout;
end;

procedure TPasswordEdit.CreateWnd;
begin
  inherited CreateWnd;
  layout;
end;

// -- strength ----------------------

function TPasswordEdit.Strength: TPasswordStrength;
begin
  var s := FEdit.Text;
  result := psNone;
  if s = '' then exit;
  var lower := false;
  var upper := false;
  var digit := false;
  var other := false;
  for var c in s do
    if c in ['a'..'z'] then lower := true
    else if c in ['A'..'Z'] then upper := true
    else if c in ['0'..'9'] then digit := true
    else other := true;
  var kinds := ord(lower)+ord(upper)+ord(digit)+ord(other);
  // the length sets the ceiling, the kinds of characters fill it
  var score := kinds;
  if length(s) >= FMinLength then inc(score);
  if length(s) >= FMinLength+4 then inc(score);
  if length(s) < FMinLength then score := Min(score, 1);
  result := match score of
    0, 1: psWeak;
    2, 3: psFair;
    4: psGood;
  else
    psStrong
  end;
  if Assigned(FOnGetStrength) then FOnGetStrength(self, s, result);
end;

// -- painting ----------------------

// the field goes gray with the rest of the control
procedure TPasswordEdit.CMEnabledChanged(var Message: TLMessage);
begin
  inherited CMEnabledChanged(Message);
  FEdit.Color := if Enabled then clWindow else clBtnFace;
  Invalidate;
end;

procedure TPasswordEdit.Paint;
begin
  var icon := pick(FIconColor, clGrayText);
  var border := pick(FBorderColor, clBtnShadow);
  if FEdit.Focused and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := ColorToRGB(clWindow);
  if not Enabled then begin
    field := ColorToRGB(clBtnFace);
    icon := blend(icon, field, 40);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, fieldRect, scaled(self, FCornerRadius), field, border);
  if FShowReveal then begin
    var r := revealRect;
    var size := iconSizePx;
    var cx := (r.Left+r.Right) div 2;
    var cy := (r.Top+r.Bottom) div 2;
    var glyph := if Enabled and hoverEnabled and FHotReveal then blend(icon, clWindowText, 50) else icon;
    // an eye: two arcs and the pupil; a stroke through it while revealed
    var w := size div 2;
    var h := Max(size div 4, 2);
    // the outline 2 pixels wide on the edge of the eye
    sp.FrameEllipse(cx, cy, w+1, h+1, 2, glyph);
    paintCircle(sp, cx, cy, Max(size div 6, 2), glyph, clNone);
    if FRevealed then paintLine(sp, cx-w, cy+h, cx+w, cy-h, glyph, 2);
  end;
  if FShowCapsLock and FCapsLockOn then begin
    // an up arrow in a box
    var r := capsRect;
    paintRoundRect(sp, r, scaled(self, 2), clNone, ColorToRGB(clHotLight));
    paintChevron(sp, r, cdUp, Max(r.Width div 2, 4), ColorToRGB(clHotLight));
  end;
  if FStrengthPosition <> spNone then begin
    var bar := barRect;
    var level := Strength;
    var segments := 4;
    var gap := scaled(self, 2);
    var segW := (bar.Width-gap*(segments-1)) div segments;
    var fairColor := pick(FFairColor, clHotLight);
    var goodColor := pick(FGoodColor, clHighlight);
    var colorOf := match level of
      psWeak: ColorToRGB(FWeakColor);
      psFair: fairColor;
      psGood: goodColor;
      psStrong: ColorToRGB(FStrongColor);
    else
      ColorToRGB(clBtnShadow)
    end;
    for var i := 0 to segments-1 do begin
      var x := bar.Left+i*(segW+gap);
      var lit := i < ord(level);
      paintRoundRect(sp, Rect(x, bar.Top, x+segW, bar.Bottom), 1, (if lit then colorOf else blend(clBtnFace, clBtnShadow, 30)), clNone);
    end;
  end;
end;

// -- input ----------------------

procedure TPasswordEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if FShowReveal and revealRect.Contains(Point(X, Y)) then setRevealed(not FRevealed);
  FEdit.SetFocus;
end;

procedure TPasswordEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := FShowReveal and revealRect.Contains(Point(X, Y));
  if hot <> FHotReveal then begin
    FHotReveal := hot;
    Invalidate;
  end;
end;

procedure TPasswordEdit.MouseLeave;
begin
  inherited MouseLeave;
  if FHotReveal then begin
    FHotReveal := false;
    Invalidate;
  end;
end;

procedure TPasswordEdit.pollCapsLock;
begin
  var state := (GetKeyState(VK_CAPITAL) and 1) <> 0;
  if state = FCapsLockOn then exit;
  FCapsLockOn := state;
  layout;
  Invalidate;
end;

procedure TPasswordEdit.editChange(Sender: TObject);
begin
  if csDestroying in ComponentState then exit;
  pollCapsLock;
  Invalidate;
  if Assigned(FOnChange) then FOnChange(self);
end;

procedure TPasswordEdit.editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  KeyDown(Key, Shift);
  pollCapsLock;
end;

procedure TPasswordEdit.editEnter(Sender: TObject);
begin
  pollCapsLock;
  Invalidate;
  DoEnter;
end;

procedure TPasswordEdit.editExit(Sender: TObject);
begin
  Invalidate;
  DoExit;
end;

procedure TPasswordEdit.SetFocus;
begin
  if FEdit.CanFocus then FEdit.SetFocus else inherited SetFocus;
end;

function TPasswordEdit.Focused: Boolean;
begin
  result := FEdit.Focused or inherited Focused;
end;

procedure TPasswordEdit.Clear;
begin
  FEdit.Text := '';
end;

procedure TPasswordEdit.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  layout;
end;

// -- properties ----------------------

function TPasswordEdit.getText: string;
begin
  result := FEdit.Text;
end;

procedure TPasswordEdit.setText(const value: string);
begin
  FEdit.Text := value;
end;

function TPasswordEdit.getTextHint: string;
begin
  result := FEdit.TextHint;
end;

procedure TPasswordEdit.setTextHint(const value: string);
begin
  FEdit.TextHint := value;
end;

function TPasswordEdit.getMaxLength: integer;
begin
  result := FEdit.MaxLength;
end;

procedure TPasswordEdit.setMaxLength(value: integer);
begin
  FEdit.MaxLength := value;
end;

procedure TPasswordEdit.setRevealed(value: boolean);
begin
  if FRevealed = value then exit;
  FRevealed := value;
  FEdit.PasswordChar := if FRevealed then #0 else FPasswordChar;
  Invalidate;
end;

function TPasswordEdit.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FShowReveal else FShowCapsLock;
end;

procedure TPasswordEdit.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FShowReveal := value else FShowCapsLock := value;
  layout;
  Invalidate;
end;

procedure TPasswordEdit.setStrengthPosition(value: TStrengthPosition);
begin
  if FStrengthPosition = value then exit;
  FStrengthPosition := value;
  InvalidatePreferredSize;
  AdjustSize;
  layout;
  Invalidate;
end;

function TPasswordEdit.getMetric(index: integer): integer;
begin
  match index of
    0: result := FMinLength;
    1: result := FCornerRadius;
    2: result := FPadding;
    _: result := FIconSize;
  end;
end;

procedure TPasswordEdit.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FMinLength := value;
    1: FCornerRadius := value;
    2: FPadding := value;
    _: FIconSize := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  layout;
  Invalidate;
end;

procedure TPasswordEdit.setPasswordChar(value: char);
begin
  if FPasswordChar = value then exit;
  FPasswordChar := value;
  if not FRevealed then FEdit.PasswordChar := value;
end;

function TPasswordEdit.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FIconColor;
    1: result := FBorderColor;
    2: result := FFocusBorderColor;
    3: result := FWeakColor;
    4: result := FFairColor;
    5: result := FGoodColor;
    _: result := FStrongColor;
  end;
end;

procedure TPasswordEdit.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FIconColor := value;
    1: FBorderColor := value;
    2: FFocusBorderColor := value;
    3: FWeakColor := value;
    4: FFairColor := value;
    5: FGoodColor := value;
    _: FStrongColor := value;
  end;
  Invalidate;
end;

procedure TPasswordEdit.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
