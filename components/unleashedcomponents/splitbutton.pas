{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SplitButton;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Buttons, Menus, ImgList, Forms, LCLType, ControlPaint;

type
  // smSplit: the main part fires OnClick, the arrow opens the menu;
  // smMenu: the whole button opens the menu
  TSplitMode = (smSplit, smMenu);
  TDropDownEvent = procedure(Sender: TObject; var handled: boolean) of object;

  { TSplitButton }

  // a push button with a menu arrow at its end. The main part clicks, the
  // arrow drops DropDownMenu under the button; F4 and Alt+Down drop it from
  // the keyboard
  TSplitButton = class(TCustomControl)
  private
    FMenu: TPopupMenu;
    FImages: TCustomImageList;
    FImageIndex: TImageIndex;
    FImageWidth: integer;
    FLayout: TButtonLayout;
    FSpacing, FMargin, FArrowWidth, FCornerRadius, FArrowPadding: integer;
    FShowArrow, FFlat: boolean;
    FMode: TSplitMode;
    FModalResult: TModalResult;
    FButtonColor, FTextColor: TColor;
    FHot, FPressed, FMenuOpen: boolean;
    FPressedArrow: boolean;
    FOnDropDown: TDropDownEvent;
    FOnMenuClose: TNotifyEvent;
    procedure setMenu(value: TPopupMenu);
    procedure setImages(value: TCustomImageList);
    procedure setImageIndex(value: TImageIndex);
    procedure setImageWidth(value: integer);
    procedure setLayout(value: TButtonLayout);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setShowArrow(value: boolean);
    procedure setFlat(value: boolean);
    procedure setMode(value: TSplitMode);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setHot(value: boolean);
    function arrowWidthPx: integer;
    function arrowRect: TRect;
    function mainRect: TRect;
    function hasArrow: boolean;
    function imageSize: TSize;
    procedure menuClosed(Sender: TObject);
  private
    FAntialiasing: TAntialiasSetting;
    procedure setAntialiasing(value: TAntialiasSetting);
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
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // fires OnClick and closes a modal form with ModalResult
    procedure Click; override;
    // opens the menu under the button
    procedure DropDown;
    // the menu is on screen
    property MenuOpen: boolean read FMenuOpen;
  published
    property Caption;
    property DropDownMenu: TPopupMenu read FMenu write setMenu;
    property Images: TCustomImageList read FImages write setImages;
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    // the image at 96 dpi; 0 takes the size of the list
    property ImageWidth: integer read FImageWidth write setImageWidth default 0;
    property Layout: TButtonLayout read FLayout write setLayout default blGlyphLeft;
    // between the image and the caption
    property Spacing: integer index 0 read getMetric write setMetric default 4;
    // from the edge to the content; -1 centers it
    property Margin: integer index 1 read getMetric write setMetric default -1;
    // the arrow part; 0 takes it from the font
    property ArrowWidth: integer index 2 read getMetric write setMetric default 0;
    property CornerRadius: integer index 3 read getMetric write setMetric default 4;
    // on both sides of the arrow when ArrowWidth is 0
    property ArrowPadding: integer index 4 read getMetric write setMetric default 8;
    property ShowArrow: boolean read FShowArrow write setShowArrow default true;
    // no face until the mouse is over it
    property Flat: boolean read FFlat write setFlat default false;
    property SplitMode: TSplitMode read FMode write setMode default smSplit;
    property ModalResult: TModalResult read FModalResult write FModalResult default mrNone;
    // clDefault takes the colors of the theme
    property ButtonColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // before the menu drops; handled = true shows nothing
    property OnDropDown: TDropDownEvent read FOnDropDown write FOnDropDown;
    property OnMenuClose: TNotifyEvent read FOnMenuClose write FOnMenuClose;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Align;
    property Anchors;
    property AutoSize;
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
  Math, Themes, ThemesEngine;

constructor TSplitButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csSetCaption]-[csClickEvents];
  FImageIndex := -1;
  FLayout := blGlyphLeft;
  FSpacing := 4;
  FMargin := -1;
  FCornerRadius := 4;
  FArrowPadding := 8;
  FShowArrow := true;
  FButtonColor := clDefault;
  FTextColor := clDefault;
  TabStop := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TSplitButton.GetControlClassDefaultSize: TSize;
begin
  result.cx := 110;
  result.cy := 25;
end;

// -- geometry ----------------------

function TSplitButton.hasArrow: boolean;
begin
  result := FShowArrow;
end;

function TSplitButton.arrowWidthPx: integer;
begin
  if not hasArrow then exit(0);
  result := if FArrowWidth > 0 then scaled(self, FArrowWidth) else Max(scaled(self, 8), 6)+scaled(self, FArrowPadding)*2;
end;

function TSplitButton.arrowRect: TRect;
begin
  result := Rect(ClientWidth-arrowWidthPx, 0, ClientWidth, ClientHeight);
end;

function TSplitButton.mainRect: TRect;
begin
  result := Rect(0, 0, ClientWidth-arrowWidthPx, ClientHeight);
end;

function TSplitButton.imageSize: TSize;
begin
  result := Size(0, 0);
  if (FImages = nil) or (FImageIndex < 0) or (FImageIndex >= FImages.Count) then exit;
  result := FImages.SizeForPPI[FImageWidth, Font.PixelsPerInch];
end;

procedure TSplitButton.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var img := imageSize;
  var tw := if Caption = '' then 0 else Canvas.TextWidth(Caption);
  var th := Canvas.TextHeight('Hg');
  var gap := if (img.cx > 0) and (tw > 0) then scaled(self, FSpacing) else 0;
  var w, h: integer;
  if FLayout in [blGlyphLeft, blGlyphRight] then begin
    w := img.cx+gap+tw;
    h := Max(img.cy, th);
  end else begin
    w := Max(img.cx, tw);
    h := img.cy+gap+th;
  end;
  var pad := if FMargin < 0 then scaled(self, 10) else scaled(self, FMargin);
  PreferredWidth := w+pad*2+arrowWidthPx;
  PreferredHeight := h+scaled(self, 8);
end;

// -- painting ----------------------

procedure TSplitButton.Paint;

  // the separator and the arrow of the drop down part
  procedure arrowOn(painter: TSmoothPaint; textColor: TColor);
  begin
    var a := arrowRect;
    if FMode = smSplit then paintLine(painter, a.Left, a.Top+scaled(self, 5), a.Left, a.Bottom-scaled(self, 5), (if Enabled then blend(textColor, GetRGBColorResolvingParent, 60) else ColorToRGB(clGrayText)));
    paintChevron(painter, a, cdDown, Max(scaled(self, 8), 6), textColor);
  end;

begin
  var textColor := pick(FTextColor, clBtnText);
  if not Enabled then textColor := ColorToRGB(clGrayText);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var r := ClientRect;
  var active := FPressed or FMenuOpen;
  var showFace := Enabled and (not FFlat or FHot or active or Focused);
  // the stock look of the widgetset paints the native element after the shapes
  var native := false;
  var detail := tbPushButtonNormal;
  if showFace then begin
    if themeActive or (FButtonColor <> clDefault) then begin
      // flat, like the engine paints the native buttons: a step up on hover,
      // a step down when pressed, the ring of the focus on the border
      var face := pick(FButtonColor, cl3DLight);
      var border := ColorToRGB(clBtnHighlight);
      if hoverEnabled and FHot and not active then begin
        face := if FButtonColor = clDefault then ColorToRGB(clBtnHighlight) else blend(face, clWindowText, 10);
        border := ColorToRGB(clBtnShadow);
      end;
      if active then begin
        face := if FButtonColor = clDefault then ColorToRGB(clBtnShadow) else blend(face, clWindowText, 20);
        border := ColorToRGB(clWindowFrame);
      end;
      if Focused and ringEnabled then border := ringColor;
      paintRoundRect(sp, r, scaled(self, FCornerRadius), face, border);
    end else begin
      native := true;
      detail := if active then tbPushButtonPressed else if FHot and hoverEnabled then tbPushButtonHot else tbPushButtonNormal;
    end;
  end else if not Enabled and not FFlat then begin
    if themeActive then paintRoundRect(sp, r, scaled(self, FCornerRadius), ColorToRGB(clBtnFace), ColorToRGB(cl3DLight))
    else begin
      native := true;
      detail := tbPushButtonDisabled;
    end;
  end;
  if hasArrow and not native then arrowOn(sp, textColor);
  sp.Flush;
  if native then begin
    ThemeServices.DrawElement(Canvas.Handle, ThemeServices.GetElementDetails(detail), r);
    if Focused and ringEnabled and showFace then begin
      var ring := r;
      ring.Inflate(-3, -3);
      Canvas.DrawFocusRect(ring);
    end;
    if hasArrow then begin
      var direct := autofree TSmoothPaint.CreateDirect(Canvas);
      arrowOn(direct, textColor);
    end;
  end;

  // the content centers in the main part
  applyTextQuality(Canvas);
  var main := mainRect;
  var img := imageSize;
  var text := Caption;
  var tw := if text = '' then 0 else Canvas.TextWidth(text);
  var th := Canvas.TextHeight('Hg');
  var gap := if (img.cx > 0) and (tw > 0) then scaled(self, FSpacing) else 0;
  var cw := if FLayout in [blGlyphLeft, blGlyphRight] then img.cx+gap+tw else Max(img.cx, tw);
  var ch := if FLayout in [blGlyphLeft, blGlyphRight] then Max(img.cy, th) else img.cy+gap+th;
  var left := if FMargin < 0 then main.Left+(main.Width-cw) div 2 else main.Left+scaled(self, FMargin);
  var top := main.Top+(main.Height-ch) div 2;
  if active and native then begin
    inc(left);
    inc(top);
  end;
  var imgPos, textPos: TPoint;
  match FLayout of
    blGlyphLeft: begin
      imgPos := Point(left, top+(ch-img.cy) div 2);
      textPos := Point(left+img.cx+gap, top+(ch-th) div 2);
    end;
    blGlyphRight: begin
      textPos := Point(left, top+(ch-th) div 2);
      imgPos := Point(left+tw+gap, top+(ch-img.cy) div 2);
    end;
    blGlyphTop: begin
      imgPos := Point(left+(cw-img.cx) div 2, top);
      textPos := Point(left+(cw-tw) div 2, top+img.cy+gap);
    end;
    _: begin
      textPos := Point(left+(cw-tw) div 2, top);
      imgPos := Point(left+(cw-img.cx) div 2, top+th+gap);
    end;
  end;
  if img.cx > 0 then FImages.DrawForPPI(Canvas, imgPos.X, imgPos.Y, FImageIndex, FImageWidth, Font.PixelsPerInch, GetCanvasScaleFactor, Enabled);
  if tw > 0 then begin
    var style := Canvas.TextStyle;
    style.Alignment := taLeftJustify;
    style.Layout := tlTop;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := true;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := textColor;
    Canvas.TextRect(Rect(textPos.X, textPos.Y, main.Right, ClientHeight), textPos.X, textPos.Y, text, style);
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- input ----------------------

procedure TSplitButton.setHot(value: boolean);
begin
  if FHot = value then exit;
  FHot := value;
  Invalidate;
end;

procedure TSplitButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  var onArrow := hasArrow and arrowRect.Contains(Point(X, Y));
  if (FMode = smMenu) or onArrow then begin
    FPressedArrow := true;
    DropDown;
    exit;
  end;
  FPressed := true;
  Invalidate;
end;

procedure TSplitButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  FPressedArrow := false;
  if not FPressed then exit;
  FPressed := false;
  Invalidate;
  if mainRect.Contains(Point(X, Y)) then Click;
end;

procedure TSplitButton.MouseEnter;
begin
  inherited MouseEnter;
  setHot(true);
end;

procedure TSplitButton.MouseLeave;
begin
  inherited MouseLeave;
  FPressed := false;
  setHot(false);
end;

procedure TSplitButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not Enabled then exit;
  if (Key = VK_F4) or ((Key = VK_DOWN) and (ssAlt in Shift)) then begin
    Key := 0;
    DropDown;
  end else if Key in [VK_SPACE, VK_RETURN] then begin
    Key := 0;
    if FMode = smMenu then DropDown else Click;
  end;
end;

procedure TSplitButton.Click;
begin
  inherited Click;
  if FModalResult = mrNone then exit;
  var form := GetParentForm(self);
  if form <> nil then form.ModalResult := FModalResult;
end;

procedure TSplitButton.DropDown;
begin
  var handled := false;
  if Assigned(FOnDropDown) then FOnDropDown(self, handled);
  if handled or (FMenu = nil) then exit;
  FMenuOpen := true;
  Invalidate;
  Update;
  FMenu.OnClose := @menuClosed;
  var p := ClientToScreen(Point(0, Height));
  FMenu.PopUp(p.X, p.Y);
end;

procedure TSplitButton.menuClosed(Sender: TObject);
begin
  FMenuOpen := false;
  FPressedArrow := false;
  Invalidate;
  if Assigned(FOnMenuClose) then FOnMenuClose(self);
end;

procedure TSplitButton.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TSplitButton.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TSplitButton.TextChanged;
begin
  inherited TextChanged;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TSplitButton.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
end;

procedure TSplitButton.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  if AComponent = FMenu then FMenu := nil;
  if AComponent = FImages then begin
    FImages := nil;
    Invalidate;
  end;
end;

// -- properties ----------------------

procedure TSplitButton.setMenu(value: TPopupMenu);
begin
  if FMenu = value then exit;
  if FMenu <> nil then FMenu.RemoveFreeNotification(self);
  FMenu := value;
  if FMenu <> nil then FMenu.FreeNotification(self);
end;

procedure TSplitButton.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TSplitButton.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TSplitButton.setImageWidth(value: integer);
begin
  if value < 0 then value := 0;
  if FImageWidth = value then exit;
  FImageWidth := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TSplitButton.setLayout(value: TButtonLayout);
begin
  if FLayout = value then exit;
  FLayout := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TSplitButton.getMetric(index: integer): integer;
begin
  match index of
    0: result := FSpacing;
    1: result := FMargin;
    2: result := FArrowWidth;
    3: result := FCornerRadius;
    _: result := FArrowPadding;
  end;
end;

procedure TSplitButton.setMetric(index: integer; value: integer);
begin
  if (index <> 1) and (value < 0) then value := 0;
  if index = 1 then value := Max(value, -1);
  if getMetric(index) = value then exit;
  match index of
    0: FSpacing := value;
    1: FMargin := value;
    2: FArrowWidth := value;
    3: FCornerRadius := value;
    _: FArrowPadding := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TSplitButton.setShowArrow(value: boolean);
begin
  if FShowArrow = value then exit;
  FShowArrow := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TSplitButton.setFlat(value: boolean);
begin
  if FFlat = value then exit;
  FFlat := value;
  Invalidate;
end;

procedure TSplitButton.setMode(value: TSplitMode);
begin
  if FMode = value then exit;
  FMode := value;
  Invalidate;
end;

function TSplitButton.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FButtonColor else FTextColor;
end;

procedure TSplitButton.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FButtonColor := value else FTextColor := value;
  Invalidate;
end;

procedure TSplitButton.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
