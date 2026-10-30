{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ColorSwatchButton;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint, PopupWindow, ColorPickers;

type
  TSwatchTextMode = (stNone, stHex, stName, stCaption);
  TColorSwatchButton = class;

  { TSwatchGrid }

  // the grid of preset colors inside the drop-down
  TSwatchGrid = class(TCustomControl)
  private
    FOwner: TColorSwatchButton;
    FHot: integer;
    function cellAt(x, y: integer): integer;
    function cellRect(index: integer): TRect;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  end;

  { TColorSwatchButton }

  // a button that shows a color and drops a palette of swatches, a picker
  // or both to change it. The color shows as a hex code, a name or a
  // caption of its own next to the swatch
  TColorSwatchButton = class(TCustomControl)
  private
    FColor: TColor;
    FSwatches: TStrings;
    FPopup: TDropPopup;
    FGrid: TSwatchGrid;
    FPicker: TColorPicker;
    FShowPicker, FShowSwatches, FShowAlpha, FDown, FHot: boolean;
    FAlpha: byte;
    FTextMode: TSwatchTextMode;
    FColumns, FSwatchSize, FCornerRadius, FBorderWidth: integer;
    FBorderColor, FTextColor, FBackColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnChange, FOnDropDown, FOnCloseUp: TNotifyEvent;
    procedure setShownColor(value: TColor);
    procedure setSwatches(value: TStrings);
    procedure setAlpha(value: byte);
    procedure setTextMode(value: TSwatchTextMode);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure swatchesChanged(Sender: TObject);
    procedure popupDismiss(Sender: TObject);
    procedure pickerChange(Sender: TObject);
    procedure buildPopup;
    function shownText: string;
    procedure pickSwatch(index: integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DropDown;
    procedure CloseUp;
    function DroppedDown: boolean;
    // the color with the alpha in the top byte, for painters that take it
    function ColorWithAlpha: cardinal;
  published
    // the color shown; clDefault is not a color here and shows as black
    property Color: TColor read FColor write setShownColor default clBlack;
    property Alpha: byte read FAlpha write setAlpha default 255;
    // the preset colors, one per line, as names or hex like $RRGGBB or #RRGGBB
    property Swatches: TStrings read FSwatches write setSwatches;
    property ShowPicker: boolean index 0 read getFlag write setFlag default true;
    property ShowSwatches: boolean index 1 read getFlag write setFlag default true;
    property ShowAlpha: boolean index 2 read getFlag write setFlag default false;
    property TextMode: TSwatchTextMode read FTextMode write setTextMode default stHex;
    property Columns: integer index 0 read getMetric write setMetric default 8;
    property SwatchSize: integer index 1 read getMetric write setMetric default 20;
    property CornerRadius: integer index 2 read getMetric write setMetric default 4;
    property BorderWidth: integer index 3 read getMetric write setMetric default 1;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property Align;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
    // the text next to the swatch in TextMode stCaption
    property Caption;
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
  Math;

function parseColor(const text: string; out color: TColor): boolean;
begin
  var s := Trim(text);
  result := false;
  if s = '' then exit;
  if s[1] = '#' then s := '$'+Copy(s, 2, MaxInt);
  if s[1] = '$' then begin
    // the hex is RRGGBB, as on the web; TColor stores it as BGR
    var v: longint;
    if not TryStrToInt(s, v) then exit;
    color := RGBToColor((v shr 16) and $FF, (v shr 8) and $FF, v and $FF);
    exit(true);
  end;
  result := IdentToColor(s, longint(color));
  if not result and not SameText(Copy(s, 1, 2), 'cl') then result := IdentToColor('cl'+s, longint(color));
end;

{ TSwatchGrid }

function TSwatchGrid.cellRect(index: integer): TRect;
begin
  var size := scaled(self, FOwner.FSwatchSize);
  var gap := scaled(self, 4);
  var cols := Max(FOwner.FColumns, 1);
  result.Left := gap+(index mod cols)*(size+gap);
  result.Top := gap+(index div cols)*(size+gap);
  result.Right := result.Left+size;
  result.Bottom := result.Top+size;
end;

function TSwatchGrid.cellAt(x, y: integer): integer;
begin
  for var i := 0 to FOwner.FSwatches.Count-1 do if PtInRect(cellRect(i), Point(x, y)) then exit(i);
  result := -1;
end;

procedure TSwatchGrid.Paint;
begin
  var back := ColorToRGB(clWindow);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FOwner.FAntialiasing);
  var radius := scaled(self, 3);
  for var i := 0 to FOwner.FSwatches.Count-1 do begin
    var c: TColor;
    if not parseColor(FOwner.FSwatches[i], c) then continue;
    var r := cellRect(i);
    var border := blend(back, clWindowText, 30);
    if ColorToRGB(c) = ColorToRGB(FOwner.FColor) then border := ColorToRGB(clHighlight);
    if i = FHot then r.Inflate(1, 1);
    paintRoundRect(sp, r, radius, ColorToRGB(c), border, (if (i = FHot) or (border = ColorToRGB(clHighlight)) then 2 else 1));
  end;
  sp.Flush;
end;

procedure TSwatchGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := cellAt(X, Y);
  if hot = FHot then exit;
  FHot := hot;
  Invalidate;
end;

procedure TSwatchGrid.MouseLeave;
begin
  inherited MouseLeave;
  if FHot < 0 then exit;
  FHot := -1;
  Invalidate;
end;

procedure TSwatchGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var index := cellAt(X, Y);
  if index >= 0 then FOwner.pickSwatch(index);
end;

{ TColorSwatchButton }

constructor TColorSwatchButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csAcceptsControls];
  FColor := clBlack;
  FAlpha := 255;
  FShowPicker := true;
  FShowSwatches := true;
  FTextMode := stHex;
  FColumns := 8;
  FSwatchSize := 20;
  FCornerRadius := 4;
  FBorderWidth := 1;
  FBorderColor := clDefault;
  FTextColor := clDefault;
  FBackColor := clDefault;
  FAntialiasing := asTheme;
  FSwatches := TStringList.Create;
  TStringList(FSwatches).Text :=
    '#000000'#10'#444444'#10'#888888'#10'#BBBBBB'#10'#FFFFFF'#10'#7F0000'#10'#FF0000'#10'#FF7F7F'#10+
    '#7F3F00'#10'#FF7F00'#10'#FFBF7F'#10'#7F7F00'#10'#FFFF00'#10'#FFFF7F'#10'#007F00'#10'#00FF00'#10+
    '#7FFF7F'#10'#007F7F'#10'#00FFFF'#10'#7FFFFF'#10'#00007F'#10'#0000FF'#10'#7F7FFF'#10'#7F007F'#10+
    '#FF00FF'#10'#FF7FFF'#10'#3B8BD9'#10'#5CB85C'#10'#F0AD4E'#10'#D9534F'#10'#17A2B8'#10'#6C757D';
  TStringList(FSwatches).OnChange := @swatchesChanged;
  TabStop := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TColorSwatchButton.Destroy;
begin
  FreeAndNil(FPopup);
  FSwatches.Free;
  inherited Destroy;
end;

class function TColorSwatchButton.GetControlClassDefaultSize: TSize;
begin
  result.cx := 110;
  result.cy := 26;
end;

function TColorSwatchButton.ColorWithAlpha: cardinal;
begin
  result := cardinal(ColorToRGB(FColor)) or (cardinal(FAlpha) shl 24);
end;

function TColorSwatchButton.shownText: string;
begin
  var c := ColorToRGB(FColor);
  result := match FTextMode of
    stHex: Format('#%.2x%.2x%.2x', [Red(c), Green(c), Blue(c)]);
    stName: (if ColorToIdent(FColor, result) then result else Format('#%.2x%.2x%.2x', [Red(c), Green(c), Blue(c)]));
    stCaption: Caption;
  else
    ''
  end;
  if (FTextMode = stHex) and FShowAlpha and (FAlpha < 255) then result += Format('%.2x', [FAlpha]);
end;

// -- drop down ----------------------

procedure TColorSwatchButton.buildPopup;
begin
  if FPopup <> nil then exit;
  FPopup := TDropPopup.Create(self);
  FPopup.OnDismiss := @popupDismiss;
  FGrid := TSwatchGrid.Create(FPopup);
  FGrid.FOwner := self;
  FGrid.FHot := -1;
  FGrid.Parent := FPopup;
  FPicker := TColorPicker.Create(FPopup);
  FPicker.Parent := FPopup;
  FPicker.OnChange := @pickerChange;
end;

procedure TColorSwatchButton.DropDown;
begin
  if (csDesigning in ComponentState) or not Enabled or DroppedDown then exit;
  buildPopup;
  var size := scaled(self, FSwatchSize);
  var gap := scaled(self, 4);
  var cols := Max(FColumns, 1);
  var rows := (FSwatches.Count+cols-1) div cols;
  var gridW := if FShowSwatches then cols*(size+gap)+gap else 0;
  var gridH := if FShowSwatches and (rows > 0) then rows*(size+gap)+gap else 0;
  var pickW, pickH: integer;
  FPicker.ShowAlpha := FShowAlpha;
  FPicker.GetPreferredSize(pickW, pickH);
  if not FShowPicker then begin pickW := 0; pickH := 0; end;
  var w := Max(gridW, pickW);
  if w = 0 then exit;
  FGrid.Visible := FShowSwatches and (gridH > 0);
  FGrid.SetBounds(1, 1, w, gridH);
  FPicker.Visible := FShowPicker;
  FPicker.SelectedColor := FColor;
  FPicker.Alpha := FAlpha;
  FPicker.SetBounds(1, 1+gridH, w, pickH);
  FPopup.Drop(self, w+2, gridH+pickH+2);
  FDown := true;
  Invalidate;
  if Assigned(FOnDropDown) then FOnDropDown(self);
end;

procedure TColorSwatchButton.CloseUp;
begin
  if not DroppedDown then exit;
  FPopup.Close;
  FDown := false;
  Invalidate;
  if Assigned(FOnCloseUp) then FOnCloseUp(self);
end;

function TColorSwatchButton.DroppedDown: boolean;
begin
  result := (FPopup <> nil) and FPopup.Visible;
end;

procedure TColorSwatchButton.popupDismiss(Sender: TObject);
begin
  FPopup.Close;
  FDown := false;
  Invalidate;
  if Assigned(FOnCloseUp) then FOnCloseUp(self);
end;

procedure TColorSwatchButton.pickerChange(Sender: TObject);
begin
  // one OnChange for both: the alpha rides along with the color, and on
  // its own goes through the setter so the change still fires
  if FColor <> FPicker.SelectedColor then begin
    FAlpha := FPicker.Alpha;
    Color := FPicker.SelectedColor;
  end else Alpha := FPicker.Alpha;
  if FGrid.Visible then FGrid.Invalidate;
end;

procedure TColorSwatchButton.pickSwatch(index: integer);
begin
  var c: TColor;
  if not parseColor(FSwatches[index], c) then exit;
  Color := c;
  if FShowPicker then begin
    FPicker.SelectedColor := c;
    FGrid.Invalidate;
  end else CloseUp;
end;

// -- painting ----------------------

procedure TColorSwatchButton.Paint;
begin
  var back := pick(FBackColor, clBtnFace);
  var border := pick(FBorderColor, blend(back, clBtnText, 35));
  if FHot and Enabled then back := hoverColor(back);
  if FDown then back := blend(back, clBtnText, 10);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var radius := scaled(self, FCornerRadius);
  var r := ClientRect;
  if (Focused or FDown) and ringEnabled then border := ringColor;
  paintRoundRect(sp, r, radius, back, border, Max(scaled(self, FBorderWidth), (if Focused and ringEnabled then 1 else 0)));
  // the swatch on the left, a checker under it when the alpha shows
  var pad := scaled(self, 4);
  var swatch := Rect(r.Left+pad, r.Top+pad, r.Left+pad+(r.Height-2*pad), r.Bottom-pad);
  if FTextMode = stNone then swatch := Rect(r.Left+pad, r.Top+pad, r.Right-pad-scaled(self, 14), r.Bottom-pad);
  var shown := ColorToRGB(FColor);
  if FShowAlpha and (FAlpha < 255) then begin
    var cell := scaled(self, 4);
    var y := swatch.Top;
    while y < swatch.Bottom do begin
      var x := swatch.Left;
      while x < swatch.Right do begin
        var dark := (((x-swatch.Left) div cell)+((y-swatch.Top) div cell)) mod 2 = 0;
        sp.FillRect(Rect(x, y, Min(x+cell, swatch.Right), Min(y+cell, swatch.Bottom)), (if dark then $999999 else $DDDDDD));
        x += cell;
      end;
      y += cell;
    end;
    shown := blend(shown, $CCCCCC, 100-FAlpha*100 div 255);
  end;
  if not Enabled then shown := blend(shown, back, 60);
  paintRoundRect(sp, swatch, Max(radius-1, 0), shown, blend(back, clBtnText, 30));
  var chevron := Rect(r.Right-pad-scaled(self, 12), r.Top, r.Right-pad, r.Bottom);
  paintChevron(sp, chevron, cdDown, scaled(self, 8), (if Enabled then pick(FTextColor, clBtnText) else ColorToRGB(clGrayText)));
  sp.Flush;
  if FTextMode = stNone then exit;
  applyTextQuality(Canvas);
  var text := Rect(swatch.Right+pad+scaled(self, 2), r.Top, chevron.Left-pad, r.Bottom);
  Canvas.Font.Color := if Enabled then pick(FTextColor, clBtnText) else ColorToRGB(clGrayText);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.EndEllipsis := true;
  style.ShowPrefix := false;
  style.Opaque := false;
  if text.Right > text.Left then Canvas.TextRect(text, text.Left, text.Top, shownText, style);
end;

procedure TColorSwatchButton.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  applyTextQuality(Canvas);
  var h := Canvas.TextHeight('Hg')+scaled(self, 10);
  PreferredHeight := Max(h, scaled(self, 24));
  var textW := if FTextMode = stNone then 0 else Canvas.TextWidth(shownText)+scaled(self, 6);
  PreferredWidth := (PreferredHeight-scaled(self, 8))+textW+scaled(self, 28);
end;

// -- input ----------------------

procedure TColorSwatchButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if TabStop and CanSetFocus then SetFocus;
  if DroppedDown then CloseUp else DropDown;
end;

procedure TColorSwatchButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TColorSwatchButton.MouseEnter;
begin
  inherited MouseEnter;
  FHot := true;
  Invalidate;
end;

procedure TColorSwatchButton.MouseLeave;
begin
  inherited MouseLeave;
  FHot := false;
  Invalidate;
end;

procedure TColorSwatchButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_SPACE, VK_RETURN, VK_F4: begin
      if DroppedDown then CloseUp else DropDown;
      Key := 0;
    end;
    VK_DOWN: if ssAlt in Shift then begin DropDown; Key := 0; end;
    VK_ESCAPE: if DroppedDown then begin CloseUp; Key := 0; end;
  end;
end;

procedure TColorSwatchButton.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TColorSwatchButton.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

procedure TColorSwatchButton.setShownColor(value: TColor);
begin
  if value = clDefault then value := clBlack;
  if FColor = value then exit;
  FColor := value;
  if AutoSize then InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TColorSwatchButton.setAlpha(value: byte);
begin
  if FAlpha = value then exit;
  FAlpha := value;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TColorSwatchButton.setSwatches(value: TStrings);
begin
  FSwatches.Assign(value);
end;

procedure TColorSwatchButton.swatchesChanged(Sender: TObject);
begin
  if (FGrid <> nil) and FGrid.Visible then FGrid.Invalidate;
end;

procedure TColorSwatchButton.setTextMode(value: TSwatchTextMode);
begin
  if FTextMode = value then exit;
  FTextMode := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TColorSwatchButton.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowPicker;
    1: FShowSwatches;
  else
    FShowAlpha
  end;
end;

procedure TColorSwatchButton.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowPicker := value;
    1: FShowSwatches := value;
  else
    FShowAlpha := value;
  end;
  Invalidate;
end;

function TColorSwatchButton.getMetric(index: integer): integer;
begin
  result := match index of
    0: FColumns;
    1: FSwatchSize;
    2: FCornerRadius;
  else
    FBorderWidth
  end;
end;

procedure TColorSwatchButton.setMetric(index: integer; value: integer);
begin
  if index < 2 then value := Max(value, 1) else value := Max(value, 0);
  if getMetric(index) = value then exit;
  match index of
    0: FColumns := value;
    1: FSwatchSize := value;
    2: FCornerRadius := value;
  else
    FBorderWidth := value;
  end;
  Invalidate;
end;

function TColorSwatchButton.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBorderColor;
    1: FTextColor;
  else
    FBackColor
  end;
end;

procedure TColorSwatchButton.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FTextColor := value;
  else
    FBackColor := value;
  end;
  Invalidate;
end;

procedure TColorSwatchButton.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
