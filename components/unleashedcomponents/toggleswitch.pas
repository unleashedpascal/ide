{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ToggleSwitch;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ExtCtrls, ControlPaint;

type
  TCaptionPosition = (cpRight, cpLeft);
  TSwitchTextMode = (stNone, stInside, stBeside);
  // the look of the switch: a pill, a box, a thin track under a big thumb, a thumb with a check and a cross
  TSwitchStyle = (swPill, swSquare, swSlim, swIcons);

  { TToggleSwitch }

  // an on/off switch: a pill with a thumb sliding between the two ends,
  // the caption beside it. A click, the space bar and the keyboard arrows
  // flip it; the thumb animates across
  TToggleSwitch = class(TCustomControl)
  private
    FChecked: boolean;
    FCaptionPosition: TCaptionPosition;
    FTextMode: TSwitchTextMode;
    FTextOn, FTextOff: string;
    FAnimated: boolean;
    FDuration: integer;
    FSwitchWidth, FSwitchHeight, FSpacing: integer;
    FOnColor, FOffColor, FThumbColor, FBorderColor: TColor;
    FReadOnly: boolean;
    FHot, FPressed: boolean;
    FTimer: TTimer;
    FPos: single; // thumb position 0 off .. 1 on
    FStarted: QWord; // tick of the animation start
    FFrom: single;
    FOnChange: TNotifyEvent;
    FOnDraw: TCustomDrawEvent;
    procedure setChecked(value: boolean);
    procedure setCaptionPosition(value: TCaptionPosition);
    procedure setTextMode(value: TSwitchTextMode);
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setSize(index: integer; value: integer);
    function getSize(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setHot(value: boolean);
    procedure setPressed(value: boolean);
    function switchWidthPx: integer;
    function switchHeightPx: integer;
    function switchRect: TRect;
    procedure animate;
    procedure tick(Sender: TObject);
    procedure toggle;
  private
    FAntialiasing: TAntialiasSetting;
    FStyle: TSwitchStyle;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setStyle(value: TSwitchStyle);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Checked: boolean read FChecked write setChecked default false;
    property Caption;
    property CaptionPosition: TCaptionPosition read FCaptionPosition write setCaptionPosition default cpRight;
    // where the state words go: in the pill, next to it, or nowhere
    property StateText: TSwitchTextMode read FTextMode write setTextMode default stNone;
    property TextOn: string index 0 read getText write setText;
    property TextOff: string index 1 read getText write setText;
    // the thumb slides over; off, it jumps
    property Animated: boolean read FAnimated write FAnimated default true;
    // the slide, in milliseconds
    property AnimationDuration: integer read FDuration write FDuration default 150;
    // the pill; 0 takes its size from the font
    property SwitchWidth: integer index 0 read getSize write setSize default 0;
    property SwitchHeight: integer index 1 read getSize write setSize default 0;
    // between the pill and the caption
    property Spacing: integer index 2 read getSize write setSize default 8;
    // clDefault takes the colors of the theme
    property OnColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property OffColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property ThumbColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property ReadOnly: boolean read FReadOnly write FReadOnly default false;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // paints the switch (not the caption) by itself: dsChecked when on,
    // dsHover, dsPressed, dsFocused
    property OnDraw: TCustomDrawEvent read FOnDraw write FOnDraw;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Style: TSwitchStyle read FStyle write setStyle default swPill;
    property Align;
    property Anchors;
    property AutoSize default true;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Cursor;
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
    property OnDblClick;
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
  Math;

constructor TToggleSwitch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csSetCaption];
  FCaptionPosition := cpRight;
  FTextOn := 'ON';
  FTextOff := 'OFF';
  FAnimated := true;
  FDuration := 150;
  FSpacing := 8;
  FOnColor := clDefault;
  FOffColor := clDefault;
  FThumbColor := clDefault;
  FBorderColor := clDefault;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 15;
  FTimer.OnTimer := @tick;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TToggleSwitch.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

class function TToggleSwitch.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 24;
end;

function TToggleSwitch.switchHeightPx: integer;
begin
  result := if FSwitchHeight > 0 then scaled(self, FSwitchHeight) else Canvas.TextHeight('Hg')+scaled(self, 4);
end;

function TToggleSwitch.switchWidthPx: integer;
begin
  result := if FSwitchWidth > 0 then scaled(self, FSwitchWidth) else switchHeightPx*2-switchHeightPx div 4;
  if FTextMode = stInside then result := Math.Max(result, switchHeightPx+Math.Max(Canvas.TextWidth(FTextOn), Canvas.TextWidth(FTextOff))+scaled(self, 10));
end;

// the room the focus ring takes around the switch
const RING_ROOM = 2;

function TToggleSwitch.switchRect: TRect;
begin
  var w := switchWidthPx;
  var h := switchHeightPx;
  var top := (ClientHeight-h) div 2;
  var left := if FCaptionPosition = cpRight then RING_ROOM else ClientWidth-w-RING_ROOM;
  result := Rect(left, top, left+w, top+h);
end;

procedure TToggleSwitch.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var w := switchWidthPx;
  var h := switchHeightPx;
  var text := Caption;
  if FTextMode = stBeside then text := if text = '' then (if FChecked then FTextOn else FTextOff) else text+' '+(if FChecked then FTextOn else FTextOff);
  if text <> '' then w += scaled(self, FSpacing)+Canvas.TextWidth(text);
  PreferredWidth := w+RING_ROOM*2+2;
  PreferredHeight := Math.Max(h+RING_ROOM*2, Canvas.TextHeight('Hg'))+2;
end;

// -- painting ----------------------

procedure TToggleSwitch.Paint;
begin
  var onColor := pick(FOnColor, clHighlight);
  var offColor := pick(FOffColor, blend(clBtnFace, clBtnShadow, 60));
  var thumb := pick(FThumbColor, clWindow);
  var border := pick(FBorderColor, clBtnShadow);
  if not Enabled then begin
    onColor := blend(onColor, clBtnFace, 50);
    offColor := blend(offColor, clBtnFace, 50);
    thumb := blend(thumb, clBtnFace, 40);
  end;
  var r := switchRect;
  var fill := blend(offColor, onColor, Round(FPos*100));
  if Enabled and hoverEnabled and (FHot or FPressed) then fill := blend(fill, clWindowText, (if FPressed then 20 else 10));
  // the thumb runs inside a margin so it never touches the pill border
  var margin := Math.Max(scaled(self, 2), 2);
  var d := r.Height-margin*2;
  var x := r.Left+margin+Round(FPos*(r.Width-margin*2-d));
  var state: TDrawState := if FChecked then [dsChecked] else [];
  if FHot then state += [dsHover];
  if FPressed then state += [dsPressed];
  if Focused then state += [dsFocused];
  if not Enabled then state += [dsDisabled];
  if not customDraw(self, Canvas, FOnDraw, r, 0, state, GetRGBColorResolvingParent, FAntialiasing) then begin
    var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
    var frame := if Focused and ringEnabled then ringColor else if FChecked then clNone else border;
    match FStyle of
      swSquare: begin
        paintRoundRect(sp, r, scaled(self, 3), fill, frame);
        paintRoundRect(sp, Rect(x, r.Top+margin, x+d, r.Top+margin+d), scaled(self, 2), thumb, (if FChecked then clNone else border));
      end;
      // a thin track, the thumb bigger than it and tinted when on
      swSlim: begin
        var th := Math.Max(r.Height div 2, 4);
        paintRoundRect(sp, Rect(r.Left+d div 4, (r.Top+r.Bottom-th) div 2, r.Right-d div 4, (r.Top+r.Bottom+th) div 2), th div 2, fill, frame);
        paintCircle(sp, x+d div 2, r.Top+margin+d div 2, d div 2+margin-1, (if FChecked then blend(thumb, onColor, 60) else thumb), border);
      end;
      swIcons: begin
        paintPill(sp, r, fill, frame);
        paintCircle(sp, x+d div 2, r.Top+margin+d div 2, d div 2, thumb, (if FChecked then clNone else border));
        var glyph := Rect(x, r.Top+margin, x+d, r.Top+margin+d);
        if FChecked then paintCheck(sp, glyph, d*55 div 100, onColor, Math.Max(d div 8, 2))
        else paintCross(sp, glyph, d*40 div 100, offColor, Math.Max(d div 8, 2));
      end;
    else
      paintPill(sp, r, fill, frame);
      paintCircle(sp, x+d div 2, r.Top+margin+d div 2, d div 2, thumb, (if FChecked then clNone else border));
    end;
    sp.Flush;
  end;

  applyTextQuality(Canvas);
  if FTextMode = stInside then begin
    var text := if FChecked then FTextOn else FTextOff;
    var box := if FChecked then Rect(r.Left+margin, r.Top, r.Left+margin+(r.Width-d-margin*2), r.Bottom) else Rect(r.Left+margin+d, r.Top, r.Right-margin, r.Bottom);
    paintCenteredText(Canvas, box, text, contrastText(fill));
  end;
  var words := Caption;
  if FTextMode = stBeside then words := if words = '' then (if FChecked then FTextOn else FTextOff) else words+' '+(if FChecked then FTextOn else FTextOff);
  if words <> '' then begin
    var gap := scaled(self, FSpacing);
    var box := if FCaptionPosition = cpRight then Rect(r.Right+gap, 0, ClientWidth, ClientHeight) else Rect(0, 0, r.Left-gap, ClientHeight);
    var style := Canvas.TextStyle;
    style.Alignment := if FCaptionPosition = cpRight then taLeftJustify else taRightJustify;
    style.Layout := tlCenter;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := true;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := ColorToRGB(if Enabled then clWindowText else clGrayText);
    Canvas.TextRect(box, box.Left, box.Top, words, style);
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- animation ----------------------

procedure TToggleSwitch.animate;
begin
  var target: single := if FChecked then 1 else 0;
  if not FAnimated or (FDuration <= 0) or (csDesigning in ComponentState) or not HandleAllocated then begin
    FPos := target;
    FTimer.Enabled := false;
    Invalidate;
    exit;
  end;
  FFrom := FPos;
  FStarted := GetTickCount64;
  FTimer.Enabled := true;
end;

procedure TToggleSwitch.tick(Sender: TObject);
begin
  var target: single := if FChecked then 1 else 0;
  var t := (GetTickCount64-FStarted)/FDuration;
  if t >= 1 then begin
    FPos := target;
    FTimer.Enabled := false;
  end else begin
    // eased: fast out of the start, slow into the end
    t := 1-(1-t)*(1-t);
    FPos := FFrom+(target-FFrom)*t;
  end;
  Invalidate;
end;

// -- input ----------------------

procedure TToggleSwitch.toggle;
begin
  if FReadOnly or not Enabled then exit;
  setChecked(not FChecked);
end;

procedure TToggleSwitch.setHot(value: boolean);
begin
  if FHot = value then exit;
  FHot := value;
  Invalidate;
end;

procedure TToggleSwitch.setPressed(value: boolean);
begin
  if FPressed = value then exit;
  FPressed := value;
  Invalidate;
end;

procedure TToggleSwitch.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if TabStop and CanSetFocus then SetFocus;
  setPressed(true);
end;

procedure TToggleSwitch.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FPressed then exit;
  setPressed(false);
  if ClientRect.Contains(Point(X, Y)) then toggle;
end;

procedure TToggleSwitch.MouseEnter;
begin
  inherited MouseEnter;
  setHot(true);
end;

procedure TToggleSwitch.MouseLeave;
begin
  inherited MouseLeave;
  setHot(false);
  setPressed(false);
end;

procedure TToggleSwitch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_SPACE, VK_RETURN: toggle;
    VK_LEFT, VK_DOWN: if FChecked then toggle;
    VK_RIGHT, VK_UP: if not FChecked then toggle;
  else
    exit;
  end;
  Key := 0;
end;

procedure TToggleSwitch.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TToggleSwitch.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TToggleSwitch.TextChanged;
begin
  inherited TextChanged;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TToggleSwitch.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
end;

// -- properties ----------------------

procedure TToggleSwitch.setChecked(value: boolean);
begin
  if FChecked = value then exit;
  FChecked := value;
  if csLoading in ComponentState then FPos := if value then 1 else 0 else animate;
  if FTextMode = stBeside then begin
    InvalidatePreferredSize;
    AdjustSize;
  end;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TToggleSwitch.setCaptionPosition(value: TCaptionPosition);
begin
  if FCaptionPosition = value then exit;
  FCaptionPosition := value;
  Invalidate;
end;

procedure TToggleSwitch.setTextMode(value: TSwitchTextMode);
begin
  if FTextMode = value then exit;
  FTextMode := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TToggleSwitch.getText(index: integer): string;
begin
  result := if index = 0 then FTextOn else FTextOff;
end;

procedure TToggleSwitch.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  if index = 0 then FTextOn := value else FTextOff := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TToggleSwitch.getSize(index: integer): integer;
begin
  match index of
    0: result := FSwitchWidth;
    1: result := FSwitchHeight;
    _: result := FSpacing;
  end;
end;

procedure TToggleSwitch.setSize(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getSize(index) = value then exit;
  match index of
    0: FSwitchWidth := value;
    1: FSwitchHeight := value;
    _: FSpacing := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TToggleSwitch.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FOnColor;
    1: result := FOffColor;
    2: result := FThumbColor;
    _: result := FBorderColor;
  end;
end;

procedure TToggleSwitch.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FOnColor := value;
    1: FOffColor := value;
    2: FThumbColor := value;
    _: FBorderColor := value;
  end;
  Invalidate;
end;

procedure TToggleSwitch.setStyle(value: TSwitchStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TToggleSwitch.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
