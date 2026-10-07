{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SearchEdit;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, StdCtrls, ExtCtrls, LCLType, ControlPaint;

type
  TClearButtonMode = (cbWhenText, cbAlways, cbNever);
  TSearchIconPosition = (ipLeft, ipRight, ipNone);
  TSearchEvent = procedure(Sender: TObject; const text: string) of object;

  { TSearchEdit }

  // a search field: a magnifier, the text, a cross that clears it. The
  // search fires on Enter and, after a pause in the typing, by itself
  TSearchEdit = class(TCustomControl)
  private
    FEdit: TEdit;
    FTimer: TTimer;
    FDelay: integer;
    FAutoSearch, FSearchOnEnter, FClearOnEscape: boolean;
    FIconPosition: TSearchIconPosition;
    FClearMode: TClearButtonMode;
    FCornerRadius, FPadding, FIconSize: integer;
    FIconColor, FBorderColor, FFocusBorderColor: TColor;
    FHotClear, FPressedClear: boolean;
    FSearched: string; // the text the last search ran with
    FOnSearch: TSearchEvent;
    FOnClear, FOnChange: TNotifyEvent;
    function getText: string;
    procedure setText(const value: string);
    function getTextHint: string;
    procedure setTextHint(const value: string);
    function getMaxLength: integer;
    procedure setMaxLength(value: integer);
    function getCharCase: TEditCharCase;
    procedure setCharCase(value: TEditCharCase);
    function getReadOnly: boolean;
    procedure setReadOnly(value: boolean);
    procedure setIconPosition(value: TSearchIconPosition);
    procedure setClearMode(value: TClearButtonMode);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setHotClear(value: boolean);
    function iconSizePx: integer;
    function iconRect: TRect;
    function clearRect: TRect;
    function clearVisible: boolean;
    procedure layout;
    procedure editChange(Sender: TObject);
    procedure editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure editKeyPress(Sender: TObject; var Key: char);
    procedure editEnter(Sender: TObject);
    procedure editExit(Sender: TObject);
    procedure timerFired(Sender: TObject);
    procedure runSearch;
  private
    FAntialiasing: TAntialiasSetting;
    procedure setAntialiasing(value: TAntialiasSetting);
  protected
    procedure Paint; override;
    procedure DoOnResize; override;
    procedure CreateWnd; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure FontChanged(Sender: TObject); override;
    procedure SetEnabled(Value: Boolean); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetFocus; override;
    function Focused: Boolean; override;
    // empties the field; fires OnClear and, with AutoSearch, a search for ''
    procedure Clear;
    // fires OnSearch with the text now, whatever the timing says
    procedure Search;
    procedure SelectAll;
    // the field inside
    property Edit: TEdit read FEdit;
  published
    property Text: string read getText write setText;
    // the gray prompt in the empty field
    property TextHint: string read getTextHint write setTextHint;
    property MaxLength: integer read getMaxLength write setMaxLength default 0;
    property CharCase: TEditCharCase read getCharCase write setCharCase default ecNormal;
    property ReadOnly: boolean read getReadOnly write setReadOnly default false;
    // a search runs by itself SearchDelay milliseconds after the typing stops
    property AutoSearch: boolean read FAutoSearch write FAutoSearch default true;
    property SearchDelay: integer read FDelay write FDelay default 300;
    property SearchOnEnter: boolean read FSearchOnEnter write FSearchOnEnter default true;
    property ClearOnEscape: boolean read FClearOnEscape write FClearOnEscape default true;
    property IconPosition: TSearchIconPosition read FIconPosition write setIconPosition default ipLeft;
    property ClearButton: TClearButtonMode read FClearMode write setClearMode default cbWhenText;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    // between the frame and the text
    property Padding: integer index 1 read getMetric write setMetric default 6;
    // the glyphs; 0 takes the size from the font
    property IconSize: integer index 2 read getMetric write setMetric default 0;
    // clDefault takes the colors of the theme
    property IconColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    // the text to search for; fires on Enter, after a typing pause and after a clear
    property OnSearch: TSearchEvent read FOnSearch write FOnSearch;
    property OnClear: TNotifyEvent read FOnClear write FOnClear;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
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

constructor TSearchEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop]-[csSetCaption];
  FDelay := 300;
  FAutoSearch := true;
  FSearchOnEnter := true;
  FClearOnEscape := true;
  FIconPosition := ipLeft;
  FClearMode := cbWhenText;
  FCornerRadius := 4;
  FPadding := 6;
  FIconColor := clDefault;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FEdit := TEdit.Create(self);
  FEdit.Parent := self;
  FEdit.BorderStyle := bsNone;
  FEdit.ParentFont := true;
  FEdit.Color := clWindow;
  FEdit.ControlStyle := FEdit.ControlStyle+[csNoDesignSelectable];
  FEdit.SetSubComponent(true);
  FEdit.OnChange := @editChange;
  FEdit.OnKeyDown := @editKeyDown;
  FEdit.OnKeyPress := @editKeyPress;
  FEdit.OnEnter := @editEnter;
  FEdit.OnExit := @editExit;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.OnTimer := @timerFired;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TSearchEdit.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 27;
end;

procedure TSearchEdit.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := Max(Canvas.TextHeight('Hg'), iconSizePx)+scaled(self, FPadding)*2-scaled(self, 2);
end;

// -- geometry ----------------------

function TSearchEdit.iconSizePx: integer;
begin
  result := if FIconSize > 0 then scaled(self, FIconSize) else Canvas.TextHeight('Hg')-scaled(self, 2);
end;

function TSearchEdit.iconRect: TRect;
begin
  var size := iconSizePx;
  var pad := scaled(self, FPadding);
  var top := (ClientHeight-size) div 2;
  result := if FIconPosition = ipLeft then Rect(pad, top, pad+size, top+size) else Rect(ClientWidth-pad-size, top, ClientWidth-pad, top+size);
  if FIconPosition = ipNone then result := Rect(0, 0, 0, 0);
end;

function TSearchEdit.clearVisible: boolean;
begin
  result := (FClearMode = cbAlways) or ((FClearMode = cbWhenText) and (FEdit.Text <> ''));
end;

function TSearchEdit.clearRect: TRect;
begin
  var size := iconSizePx;
  var pad := scaled(self, FPadding);
  var top := (ClientHeight-size) div 2;
  var right := ClientWidth-pad;
  // the cross keeps the right end; a right hand magnifier moves in before it
  if FIconPosition = ipRight then right := iconRect.Left-pad;
  result := Rect(right-size, top, right, top+size);
  if not clearVisible then result := Rect(0, 0, 0, 0);
end;

procedure TSearchEdit.layout;
begin
  // the metrics come from the canvas, which needs the window
  if (FEdit = nil) or not HandleAllocated then exit;
  var pad := scaled(self, FPadding);
  var left := pad;
  var right := ClientWidth-pad;
  if FIconPosition = ipLeft then left := iconRect.Right+pad div 2+scaled(self, 2);
  if FIconPosition = ipRight then right := iconRect.Left-pad div 2;
  if FClearMode <> cbNever then right := Min(right, (if FIconPosition = ipRight then iconRect.Left-pad else ClientWidth-pad)-iconSizePx-pad div 2);
  var h := FEdit.Height;
  if h <= 0 then h := Canvas.TextHeight('Hg');
  FEdit.SetBounds(left, (ClientHeight-h) div 2, Max(right-left, 10), h);
end;

procedure TSearchEdit.DoOnResize;
begin
  inherited DoOnResize;
  layout;
end;

procedure TSearchEdit.CreateWnd;
begin
  inherited CreateWnd;
  layout;
end;

// -- painting ----------------------

procedure TSearchEdit.Paint;
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
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  if FIconPosition <> ipNone then paintMagnifier(sp, iconRect, iconSizePx, icon);
  if clearVisible then begin
    var r := clearRect;
    var size := iconSizePx;
    if Enabled and hoverEnabled and FHotClear then begin
      var fill := if FPressedClear then blend(hoverColor(field), clWindowText, 15) else hoverColor(field);
      paintCircle(sp, (r.Left+r.Right) div 2, (r.Top+r.Bottom) div 2, size div 2, fill, clNone);
    end;
    paintCross(sp, r, size div 2, icon);
  end;
end;

// -- input ----------------------

procedure TSearchEdit.setHotClear(value: boolean);
begin
  if FHotClear = value then exit;
  FHotClear := value;
  Invalidate;
end;

procedure TSearchEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if clearVisible and clearRect.Contains(Point(X, Y)) then begin
    FPressedClear := true;
    Invalidate;
  end else FEdit.SetFocus;
end;

procedure TSearchEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  setHotClear(clearVisible and clearRect.Contains(Point(X, Y)));
end;

procedure TSearchEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FPressedClear then exit;
  FPressedClear := false;
  Invalidate;
  if clearRect.Contains(Point(X, Y)) then begin
    Clear;
    FEdit.SetFocus;
  end;
end;

procedure TSearchEdit.MouseLeave;
begin
  inherited MouseLeave;
  FPressedClear := false;
  setHotClear(false);
end;

procedure TSearchEdit.editChange(Sender: TObject);
begin
  if csDestroying in ComponentState then exit;
  Invalidate;
  if Assigned(FOnChange) then FOnChange(self);
  FTimer.Enabled := false;
  if FAutoSearch and not (csDesigning in ComponentState) then begin
    if FDelay <= 0 then runSearch
    else begin
      FTimer.Interval := FDelay;
      FTimer.Enabled := true;
    end;
  end;
end;

procedure TSearchEdit.editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  KeyDown(Key, Shift);
  if Key = 0 then exit;
  if (Key = VK_RETURN) and FSearchOnEnter then begin
    Key := 0;
    Search;
  end else if (Key = VK_ESCAPE) and FClearOnEscape and (FEdit.Text <> '') then begin
    Key := 0;
    Clear;
  end;
end;

procedure TSearchEdit.editKeyPress(Sender: TObject; var Key: char);
begin
  KeyPress(Key);
  // the beep of the native field on Enter and Escape
  if Key in [#13, #27] then Key := #0;
end;

procedure TSearchEdit.editEnter(Sender: TObject);
begin
  Invalidate;
  DoEnter;
end;

procedure TSearchEdit.editExit(Sender: TObject);
begin
  Invalidate;
  DoExit;
end;

procedure TSearchEdit.timerFired(Sender: TObject);
begin
  FTimer.Enabled := false;
  runSearch;
end;

procedure TSearchEdit.runSearch;
begin
  FTimer.Enabled := false;
  // the pause after a search that already ran brings nothing new
  if FSearched = FEdit.Text then exit;
  Search;
end;

procedure TSearchEdit.Search;
begin
  FTimer.Enabled := false;
  FSearched := FEdit.Text;
  if Assigned(FOnSearch) then FOnSearch(self, FEdit.Text);
end;

procedure TSearchEdit.Clear;
begin
  FTimer.Enabled := false;
  var had := FEdit.Text <> '';
  FEdit.Text := '';
  Invalidate;
  if Assigned(FOnClear) then FOnClear(self);
  if had and FAutoSearch then Search;
end;

procedure TSearchEdit.SelectAll;
begin
  FEdit.SelectAll;
end;

procedure TSearchEdit.SetFocus;
begin
  if FEdit.CanFocus then FEdit.SetFocus else inherited SetFocus;
end;

function TSearchEdit.Focused: Boolean;
begin
  result := FEdit.Focused or inherited Focused;
end;

procedure TSearchEdit.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  layout;
end;

procedure TSearchEdit.SetEnabled(Value: Boolean);
begin
  inherited SetEnabled(Value);
  Invalidate;
end;

// -- properties ----------------------

function TSearchEdit.getText: string;
begin
  result := FEdit.Text;
end;

procedure TSearchEdit.setText(const value: string);
begin
  FEdit.Text := value;
end;

function TSearchEdit.getTextHint: string;
begin
  result := FEdit.TextHint;
end;

procedure TSearchEdit.setTextHint(const value: string);
begin
  FEdit.TextHint := value;
end;

function TSearchEdit.getMaxLength: integer;
begin
  result := FEdit.MaxLength;
end;

procedure TSearchEdit.setMaxLength(value: integer);
begin
  FEdit.MaxLength := value;
end;

function TSearchEdit.getCharCase: TEditCharCase;
begin
  result := FEdit.CharCase;
end;

procedure TSearchEdit.setCharCase(value: TEditCharCase);
begin
  FEdit.CharCase := value;
end;

function TSearchEdit.getReadOnly: boolean;
begin
  result := FEdit.ReadOnly;
end;

procedure TSearchEdit.setReadOnly(value: boolean);
begin
  FEdit.ReadOnly := value;
end;

procedure TSearchEdit.setIconPosition(value: TSearchIconPosition);
begin
  if FIconPosition = value then exit;
  FIconPosition := value;
  layout;
  Invalidate;
end;

procedure TSearchEdit.setClearMode(value: TClearButtonMode);
begin
  if FClearMode = value then exit;
  FClearMode := value;
  layout;
  Invalidate;
end;

function TSearchEdit.getMetric(index: integer): integer;
begin
  match index of
    0: result := FCornerRadius;
    1: result := FPadding;
    _: result := FIconSize;
  end;
end;

procedure TSearchEdit.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FCornerRadius := value;
    1: FPadding := value;
    _: FIconSize := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  layout;
  Invalidate;
end;

function TSearchEdit.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FIconColor;
    1: result := FBorderColor;
    _: result := FFocusBorderColor;
  end;
end;

procedure TSearchEdit.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FIconColor := value;
    1: FBorderColor := value;
    _: FFocusBorderColor := value;
  end;
  Invalidate;
end;

procedure TSearchEdit.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
