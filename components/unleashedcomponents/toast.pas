{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Toast;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, LCLType, LMessages, ControlPaint;

type
  // the icon and the accent of a notice; tkPlain carries neither
  TToastKind = (tkInfo, tkSuccess, tkWarning, tkError, tkPlain);
  // where the notices stack up
  TToastPosition = (tpTopLeft, tpTopCenter, tpTopRight, tpBottomLeft, tpBottomCenter, tpBottomRight, tpCenter);
  // the area the position refers to: the screen, or the form owning the component
  TToastAnchor = (taScreen, taOwnerForm);
  // where the color of the kind shows: a strip along one edge, the whole
  // border, a tint of the surface, or only the icon
  TToastAccentStyle = (acLeftStrip, acTopStrip, acRightStrip, acBottomStrip, acBorder, acTint, acNone);
  TToastEvent = procedure(Sender: TObject; const title, text: string; tag: PtrInt) of object;
  // what asks the notice to go
  TToastCloseReason = (crButton, crClick, crTimeout, crCode);
  // canClose false keeps the notice up; a timeout asks again after another Duration
  TToastCloseEvent = procedure(Sender: TObject; const title, text: string; tag: PtrInt; reason: TToastCloseReason; var canClose: boolean) of object;

  TToast = class;

  { TToastWindow }

  // one notice on screen: a hint window, so it never takes the focus
  TToastWindow = class(THintWindow)
  private
    FOwnerToast: TToast;
    FTitle, FText: string;
    FKind: TToastKind;
    FTag: PtrInt;
    FShown: QWord; // the tick the notice came up
    FPaused: QWord; // the tick the mouse came over it, 0 while it runs
    FAlpha: integer; // the opacity now, on its way up or down
    FClosing: boolean;
    FHotClose: boolean;
    FLayered: boolean; // the corners outside the rounding are see-through
    function closeRect: TRect;
    function iconRect: TRect;
    function accent: TColor;
    procedure applyShape;
    procedure applyLayer;
    procedure cutCorners(sp: TSmoothPaint; radius: integer);
  protected
    procedure Paint; override;
    procedure DoOnResize; override;
    procedure CreateWnd; override;
    procedure DoShowWindow; override;
    procedure WMNCHitTest(var Message: TLMessage); message LM_NCHITTEST;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    // asks OnClose, then starts the fade out; the owner frees the window
    // once it is gone
    procedure Close(reason: TToastCloseReason = crCode);
    property Title: string read FTitle;
    property Text: string read FText;
    property Kind: TToastKind read FKind;
    property Tag: PtrInt read FTag;
  end;

  { TToast }

  // shows notices in a corner of the screen or of its form: a title, a text,
  // an icon after the kind, a close button and a bar running out with the
  // time left. The notices stack and fade in and out
  TToast = class(TComponent)
  private
    FWindows: TList;
    FTimer: TTimer;
    FFont: TFont;
    FPosition: TToastPosition;
    FAnchor: TToastAnchor;
    FAccentStyle: TToastAccentStyle;
    FDuration, FWidth, FMargin, FSpacing, FMaxVisible, FCornerRadius, FPadding, FIconSize, FOpacity, FFadeTime, FAccentWidth, FBorderWidth: integer;
    FShowCloseButton, FShowIcon, FShowProgress, FAnimated, FClickToClose, FNewestFirst, FPauseOnHover: boolean;
    FSurfaceColor, FBorderColor, FTextColor, FTitleColor, FInfoColor, FSuccessColor, FWarningColor, FErrorColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnClick, FOnClosed: TToastEvent;
    FOnClose: TToastCloseEvent;
    procedure setFont(value: TFont);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setPosition(value: TToastPosition);
    procedure setAnchor(value: TToastAnchor);
    procedure setAccentStyle(value: TToastAccentStyle);
    function getCount: integer;
    function area: TRect;
    function measure(w: TToastWindow): integer;
    procedure arrange;
    procedure tick(Sender: TObject);
    procedure syncTimer;
    function mayClose(w: TToastWindow; reason: TToastCloseReason): boolean;
    procedure windowClosed(w: TToastWindow);
    procedure windowClicked(w: TToastWindow);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Show(const title, text: string; kind: TToastKind = tkInfo; tag: PtrInt = 0);
    procedure Info(const title, text: string);
    procedure Success(const title, text: string);
    procedure Warning(const title, text: string);
    procedure Error(const title, text: string);
    procedure CloseAll;
    property Count: integer read getCount;
  published
    property Position: TToastPosition read FPosition write setPosition default tpBottomRight;
    property Anchor: TToastAnchor read FAnchor write setAnchor default taScreen;
    // milliseconds a notice stays; 0 keeps it until closed
    property Duration: integer index 0 read getMetric write setMetric default 4000;
    property Width: integer index 1 read getMetric write setMetric default 320;
    // from the edge of the area
    property Margin: integer index 2 read getMetric write setMetric default 16;
    // between two notices
    property Spacing: integer index 3 read getMetric write setMetric default 8;
    // more notices wait their turn; 0 shows them all
    property MaxVisible: integer index 4 read getMetric write setMetric default 5;
    property CornerRadius: integer index 5 read getMetric write setMetric default 8;
    property Padding: integer index 6 read getMetric write setMetric default 12;
    property IconSize: integer index 7 read getMetric write setMetric default 22;
    // 0 to 255
    property Opacity: integer index 8 read getMetric write setMetric default 240;
    // milliseconds of the fade in and the fade out
    property FadeTime: integer index 9 read getMetric write setMetric default 200;
    property AccentStyle: TToastAccentStyle read FAccentStyle write setAccentStyle default acLeftStrip;
    // the strip of the accent, or the accent border
    property AccentWidth: integer index 10 read getMetric write setMetric default 4;
    // the plain border; 0 for none
    property BorderWidth: integer index 11 read getMetric write setMetric default 1;
    property ShowCloseButton: boolean index 0 read getFlag write setFlag default true;
    property ShowIcon: boolean index 1 read getFlag write setFlag default true;
    // the bar with the time left
    property ShowProgress: boolean index 2 read getFlag write setFlag default true;
    property Animated: boolean index 3 read getFlag write setFlag default true;
    // a click anywhere on the notice closes it, after OnClick
    property ClickToClose: boolean index 4 read getFlag write setFlag default true;
    // the newest notice sits next to the edge, the older ones move away
    property NewestFirst: boolean index 5 read getFlag write setFlag default true;
    // the time stands still while the mouse is on the notice
    property PauseOnHover: boolean index 6 read getFlag write setFlag default true;
    property Font: TFont read FFont write setFont;
    // clDefault takes the colors of the theme
    property SurfaceColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property InfoColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property SuccessColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property WarningColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property ErrorColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write FAntialiasing default asTheme;
    // a click on the notice outside its close button
    property OnClick: TToastEvent read FOnClick write FOnClick;
    // before a notice goes: the close button, a click with ClickToClose,
    // the timeout or CloseAll; canClose false keeps it
    property OnClose: TToastCloseEvent read FOnClose write FOnClose;
    // the notice is gone
    property OnClosed: TToastEvent read FOnClosed write FOnClosed;
  end;

implementation

uses
  Math, LCLIntf;

const
  // a color no notice paints, so the corners carrying it can be see-through
  KEY_COLOR = TColor($FE00FD);

{ TToastWindow }

constructor TToastWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csNoFocus];
  FOwnerToast := AOwner as TToast;
end;

procedure TToastWindow.CreateWnd;
begin
  inherited CreateWnd;
  // a click on the notice must not take the activation from the form
  keepInactive(Handle);
  applyShape;
end;

procedure TToastWindow.DoShowWindow;
begin
end;

// a hint window lets the mouse through to what is under it; the notice
// takes its clicks
procedure TToastWindow.WMNCHitTest(var Message: TLMessage);
begin
  Message.Result := HTCLIENT;
end;

procedure TToastWindow.DoOnResize;
begin
  inherited DoOnResize;
  applyShape;
end;

// the corners of the window follow the rounded panel
procedure TToastWindow.applyShape;
begin
  if not HandleAllocated or (Width <= 0) or (Height <= 0) then exit;
  var mask := autofree TBitmap.Create;
  mask.PixelFormat := pf24bit;
  mask.SetSize(Width, Height);
  mask.Canvas.Brush.Color := clBlack;
  mask.Canvas.FillRect(0, 0, Width, Height);
  mask.Canvas.Brush.Color := clWhite;
  mask.Canvas.Pen.Color := clWhite;
  var d := ControlPaint.scaled(self, FOwnerToast.FCornerRadius)*2;
  mask.Canvas.RoundRect(0, 0, Width, Height, d, d);
  SetShape(mask);
end;

// the translucency and the see-through key for the corners
procedure TToastWindow.applyLayer;
begin
  if HandleAllocated then FLayered := layeredWindow(Handle, FAlpha, KEY_COLOR);
end;

// the corners outside the rounded shape take the key, on whole pixels so no
// edge blends toward the key and shows it
procedure TToastWindow.cutCorners(sp: TSmoothPaint; radius: integer);
begin
  if radius <= 0 then exit;
  var key := TSmoothPaint.PackColor(KEY_COLOR);
  for var y := 0 to radius-1 do begin
    var row := sp.Row(y);
    var rowBottom := sp.Row(Height-1-y);
    for var x := 0 to radius-1 do begin
      // inside the quarter circle around the corner center the pixel stays
      var dx := radius-0.5-x;
      var dy := radius-0.5-y;
      if dx*dx+dy*dy <= radius*radius then continue;
      if row <> nil then begin
        row[x] := key;
        row[Width-1-x] := key;
      end else begin
        Canvas.Pixels[x, y] := KEY_COLOR;
        Canvas.Pixels[Width-1-x, y] := KEY_COLOR;
      end;
      if rowBottom <> nil then begin
        rowBottom[x] := key;
        rowBottom[Width-1-x] := key;
      end else begin
        Canvas.Pixels[x, Height-1-y] := KEY_COLOR;
        Canvas.Pixels[Width-1-x, Height-1-y] := KEY_COLOR;
      end;
    end;
  end;
end;

// `scaled` of ControlPaint is spelled out: the form has a Scaled property

function TToastWindow.accent: TColor;
begin
  result := match FKind of
    tkInfo: pick(FOwnerToast.FInfoColor, clHighlight);
    tkSuccess: pick(FOwnerToast.FSuccessColor, $47A043);
    tkWarning: pick(FOwnerToast.FWarningColor, $008CFB);
    tkError: pick(FOwnerToast.FErrorColor, $3539E5);
  else
    pick(FOwnerToast.FBorderColor, blend(clWindow, clWindowText, 25))
  end;
end;

function TToastWindow.closeRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FOwnerToast.FShowCloseButton then exit;
  var size := ControlPaint.scaled(self, 16);
  var pad := ControlPaint.scaled(self, FOwnerToast.FPadding);
  result := Rect(Width-pad-size, pad-ControlPaint.scaled(self, 2), Width-pad, pad-ControlPaint.scaled(self, 2)+size);
end;

function TToastWindow.iconRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FOwnerToast.FShowIcon or (FKind = tkPlain) then exit;
  var size := ControlPaint.scaled(self, FOwnerToast.FIconSize);
  var pad := ControlPaint.scaled(self, FOwnerToast.FPadding);
  result := Rect(pad+ControlPaint.scaled(self, 4), pad, pad+ControlPaint.scaled(self, 4)+size, pad+size);
end;

procedure TToastWindow.Paint;
begin
  var surface := pick(FOwnerToast.FSurfaceColor, blend(clWindow, clBtnFace, 40));
  var border := pick(FOwnerToast.FBorderColor, blend(surface, clWindowText, 20));
  var textColor := pick(FOwnerToast.FTextColor, clWindowText);
  var titleColor := pick(FOwnerToast.FTitleColor, clWindowText);
  var tone := accent;
  // without see-through corners the notice stays square
  var radius := if FLayered then ControlPaint.scaled(self, FOwnerToast.FCornerRadius) else 0;
  var pad := ControlPaint.scaled(self, FOwnerToast.FPadding);
  var accentStyle := if FKind = tkPlain then acNone else FOwnerToast.FAccentStyle;
  if accentStyle = acTint then surface := blend(surface, tone, 12);
  var sp := autofree beginShapes(Canvas, ClientRect, surface, FOwnerToast.FAntialiasing);
  var strip := ControlPaint.scaled(self, FOwnerToast.FAccentWidth);
  if accentStyle in [acLeftStrip, acTopStrip, acRightStrip, acBottomStrip] then begin
    // the strip is the edge of the rounded shape itself: the accent fills the
    // shape, the surface covers it again except for one edge, and a plain
    // rectangle smooths the corners that cover would leave
    paintRoundRect(sp, ClientRect, radius, tone, clNone);
    var inner := ClientRect;
    var smooth := ClientRect;
    match accentStyle of
      acLeftStrip: begin inner.Left := strip; smooth := Rect(strip, 0, strip+radius, Height); end;
      acTopStrip: begin inner.Top := strip; smooth := Rect(0, strip, Width, strip+radius); end;
      acRightStrip: begin inner.Right := Width-strip; smooth := Rect(Width-strip-radius, 0, Width-strip, Height); end;
    else
      begin inner.Bottom := Height-strip; smooth := Rect(0, Height-strip-radius, Width, Height-strip); end;
    end;
    paintRoundRect(sp, inner, radius, surface, clNone);
    paintRoundRect(sp, smooth, 0, surface, clNone);
  end else paintRoundRect(sp, ClientRect, radius, surface, clNone);
  var icon := iconRect;
  if icon.Width > 0 then begin
    var cx := (icon.Left+icon.Right) div 2;
    var cy := (icon.Top+icon.Bottom) div 2;
    paintCircle(sp, cx, cy, icon.Width div 2, tone, clNone);
    var glyph := contrastText(tone);
    match FKind of
      tkSuccess: paintCheck(sp, icon, icon.Width div 2, glyph, 2);
      tkError: paintCross(sp, icon, icon.Width div 3, glyph, 2);
    end;
  end;
  // the letters of the info and the warning icons go on after the shapes
  var c := closeRect;
  if c.Width > 0 then begin
    if FHotClose and hoverEnabled then paintCircle(sp, (c.Left+c.Right) div 2, (c.Top+c.Bottom) div 2, c.Width div 2+ControlPaint.scaled(self, 2), hoverColor(surface), clNone);
    paintCross(sp, c, c.Width div 2, (if FHotClose then textColor else ColorToRGB(clGrayText)), 2);
  end;
  // the bar with the time left runs along the bottom
  if FOwnerToast.FShowProgress and (FOwnerToast.FDuration > 0) then begin
    var elapsed := (if FPaused <> 0 then FPaused else GetTickCount64)-FShown;
    var share := 1-Min(elapsed/FOwnerToast.FDuration, 1);
    var bar := Rect(pad, Height-ControlPaint.scaled(self, 6), pad+Round((Width-pad*2)*share), Height-ControlPaint.scaled(self, 3));
    paintRoundRect(sp, Rect(pad, bar.Top, Width-pad, bar.Bottom), 1, blend(surface, textColor, 10), clNone);
    if bar.Right > bar.Left then paintRoundRect(sp, bar, 1, tone, clNone);
  end;
  if accentStyle = acBorder then paintRoundRect(sp, ClientRect, radius, clNone, tone, Max(FOwnerToast.FAccentWidth, 1))
  else if FOwnerToast.FBorderWidth > 0 then paintRoundRect(sp, ClientRect, radius, clNone, border, FOwnerToast.FBorderWidth);
  cutCorners(sp, radius);
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  if (icon.Width > 0) and (FKind in [tkInfo, tkWarning]) then begin
    Canvas.Font := FOwnerToast.FFont;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Height := -(icon.Height*2 div 3);
    paintCenteredText(Canvas, icon, (if FKind = tkInfo then 'i' else '!'), contrastText(tone));
  end;
  var left := if icon.Width > 0 then icon.Right+ControlPaint.scaled(self, 10) else pad+ControlPaint.scaled(self, 4);
  var right := if c.Width > 0 then c.Left-ControlPaint.scaled(self, 6) else Width-pad;
  var y := pad;
  if FTitle <> '' then begin
    Canvas.Font := FOwnerToast.FFont;
    Canvas.Font.Style := Canvas.Font.Style+[fsBold];
    Canvas.Font.Color := titleColor;
    var box := Rect(left, y, right, y+Canvas.TextHeight('Hg'));
    var style := Canvas.TextStyle;
    style.SingleLine := true;
    style.EndEllipsis := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    Canvas.TextRect(box, box.Left, box.Top, FTitle, style);
    y := box.Bottom+ControlPaint.scaled(self, 3);
  end;
  if FText <> '' then begin
    Canvas.Font := FOwnerToast.FFont;
    Canvas.Font.Color := textColor;
    var box := Rect(left, y, right, Height-pad);
    // the text alone sits level with the icon
    if (FTitle = '') and (icon.Width > 0) and (box.Height > Canvas.TextHeight('Hg')) then begin
      var h := box.Height;
      DrawText(Canvas.Handle, PChar(FText), length(FText), box, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
      box.Right := right;
      if box.Height < icon.Height then OffsetRect(box, 0, (icon.Height-box.Height) div 2);
      box.Bottom := Min(box.Bottom, y+h);
    end;
    DrawText(Canvas.Handle, PChar(FText), length(FText), box, DT_WORDBREAK or DT_NOPREFIX or DT_END_ELLIPSIS);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TToastWindow.Close(reason: TToastCloseReason);
begin
  if FClosing then exit;
  if not FOwnerToast.mayClose(self, reason) then exit;
  FClosing := true;
  FOwnerToast.syncTimer;
end;

procedure TToastWindow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if closeRect.Contains(Point(X, Y)) then Close(crButton)
  else FOwnerToast.windowClicked(self);
end;

procedure TToastWindow.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FOwnerToast.FPauseOnHover and (FPaused = 0) then FPaused := GetTickCount64;
  var hot := closeRect.Contains(Point(X, Y));
  if hot <> FHotClose then begin
    FHotClose := hot;
    Invalidate;
  end;
end;

procedure TToastWindow.MouseLeave;
begin
  inherited MouseLeave;
  // the time spent under the mouse does not count
  if FPaused <> 0 then begin
    FShown += GetTickCount64-FPaused;
    FPaused := 0;
  end;
  if FHotClose then begin
    FHotClose := false;
    Invalidate;
  end;
end;

{ TToast }

constructor TToast.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FWindows := TList.Create;
  FFont := TFont.Create;
  FPosition := tpBottomRight;
  FAnchor := taScreen;
  FDuration := 4000;
  FWidth := 320;
  FMargin := 16;
  FSpacing := 8;
  FMaxVisible := 5;
  FCornerRadius := 8;
  FPadding := 12;
  FIconSize := 22;
  FOpacity := 240;
  FFadeTime := 200;
  FAccentWidth := 4;
  FBorderWidth := 1;
  FShowCloseButton := true;
  FShowIcon := true;
  FShowProgress := true;
  FAnimated := true;
  FClickToClose := true;
  FNewestFirst := true;
  FPauseOnHover := true;
  FSurfaceColor := clDefault;
  FBorderColor := clDefault;
  FTextColor := clDefault;
  FTitleColor := clDefault;
  FInfoColor := clDefault;
  FSuccessColor := clDefault;
  FWarningColor := clDefault;
  FErrorColor := clDefault;
  FAntialiasing := asTheme;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 16;
  FTimer.OnTimer := @tick;
end;

destructor TToast.Destroy;
begin
  FTimer.Enabled := false;
  for var i := FWindows.Count-1 downto 0 do TToastWindow(FWindows[i]).Free;
  FWindows.Free;
  FFont.Free;
  inherited Destroy;
end;

// -- showing ----------------------

procedure TToast.Show(const title, text: string; kind: TToastKind; tag: PtrInt);
begin
  if csDesigning in ComponentState then exit;
  var w := TToastWindow.Create(self);
  w.FTitle := title;
  w.FText := text;
  w.FKind := kind;
  w.FTag := tag;
  w.FShown := GetTickCount64;
  w.FAlpha := if FAnimated then 0 else FOpacity;
  w.Font := FFont;
  w.Color := pick(FSurfaceColor, blend(clWindow, clBtnFace, 40));
  FWindows.Add(w);
  arrange;
  syncTimer;
end;

procedure TToast.Info(const title, text: string);
begin
  Show(title, text, tkInfo);
end;

procedure TToast.Success(const title, text: string);
begin
  Show(title, text, tkSuccess);
end;

procedure TToast.Warning(const title, text: string);
begin
  Show(title, text, tkWarning);
end;

procedure TToast.Error(const title, text: string);
begin
  Show(title, text, tkError);
end;

procedure TToast.CloseAll;
begin
  for var i := 0 to FWindows.Count-1 do TToastWindow(FWindows[i]).Close(crCode);
end;

function TToast.getCount: integer;
begin
  result := FWindows.Count;
end;

// -- placing ----------------------

function TToast.area: TRect;
begin
  var form: TCustomForm := nil;
  if Owner is TCustomForm then form := TCustomForm(Owner);
  if (FAnchor = taOwnerForm) and (form <> nil) and form.HandleAllocated then begin
    var tl := form.ClientToScreen(Point(0, 0));
    exit(Rect(tl.X, tl.Y, tl.X+form.ClientWidth, tl.Y+form.ClientHeight));
  end;
  var monitor := if (form <> nil) and form.HandleAllocated then form.Monitor else Screen.PrimaryMonitor;
  result := monitor.WorkareaRect;
end;

// the height the notice needs for its text at the width
function TToast.measure(w: TToastWindow): integer;
begin
  var probe := autofree TBitmap.Create;
  probe.Canvas.Font := FFont;
  var pad := ControlPaint.scaled(w, FPadding);
  var icon := if FShowIcon and (w.FKind <> tkPlain) then ControlPaint.scaled(w, FIconSize) else 0;
  var left := pad+ControlPaint.scaled(w, 4)+(if icon > 0 then icon+ControlPaint.scaled(w, 10) else 0);
  var right := ControlPaint.scaled(w, FWidth)-(if FShowCloseButton then pad+ControlPaint.scaled(w, 16)+ControlPaint.scaled(w, 6) else pad);
  var h := 0;
  if w.FTitle <> '' then begin
    probe.Canvas.Font.Style := FFont.Style+[fsBold];
    h += probe.Canvas.TextHeight('Hg')+ControlPaint.scaled(w, 3);
    probe.Canvas.Font.Style := FFont.Style;
  end;
  if w.FText <> '' then begin
    var box := Rect(0, 0, Max(right-left, 20), 0);
    DrawText(probe.Canvas.Handle, PChar(w.FText), length(w.FText), box, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
    h += box.Height;
  end;
  h := Max(h, icon);
  result := h+pad*2+(if FShowProgress and (FDuration > 0) then ControlPaint.scaled(w, 6) else 0);
end;

// every notice gets its place in the stack; the ones past MaxVisible wait
// hidden until a place frees up
procedure TToast.arrange;
begin
  var r := area;
  var heights: array of integer;
  SetLength(heights, FWindows.Count);
  var total := 0;
  var shown := 0;
  for var i := 0 to FWindows.Count-1 do begin
    var w := TToastWindow(FWindows[i]);
    heights[i] := measure(w);
    if (FMaxVisible > 0) and (shown >= FMaxVisible) then continue;
    inc(shown);
    total += heights[i]+(if shown > 1 then ControlPaint.scaled(w, FSpacing) else 0);
  end;
  var fromTop := FPosition in [tpTopLeft, tpTopCenter, tpTopRight];
  var y := if fromTop then r.Top+FMargin else if FPosition = tpCenter then (r.Top+r.Bottom-total) div 2 else r.Bottom-FMargin;
  var placed := 0;
  // the newest notice is the last one in the list; it goes first when it
  // sits next to the edge
  for var k := 0 to FWindows.Count-1 do begin
    var i := if FNewestFirst then FWindows.Count-1-k else k;
    var w := TToastWindow(FWindows[i]);
    var h := heights[i];
    var width := ControlPaint.scaled(w, FWidth);
    if (FMaxVisible > 0) and (placed >= FMaxVisible) then begin
      w.Visible := false;
      continue;
    end;
    var x := match FPosition of
      tpTopLeft, tpBottomLeft: r.Left+FMargin;
      tpTopRight, tpBottomRight: r.Right-FMargin-width;
    else
      (r.Left+r.Right-width) div 2
    end;
    var top := if fromTop or (FPosition = tpCenter) then y else y-h;
    w.SetBounds(x, top, width, h);
    if fromTop or (FPosition = tpCenter) then y += h+ControlPaint.scaled(w, FSpacing) else y -= h+ControlPaint.scaled(w, FSpacing);
    inc(placed);
    if not w.Visible then begin
      w.FShown := GetTickCount64;
      w.AlphaBlend := true;
      w.AlphaBlendValue := w.FAlpha;
      w.applyLayer;
      // not Show: that ends in a ShowWindow that activates the window
      w.Visible := true;
    end;
  end;
end;

// -- the clock ----------------------

procedure TToast.syncTimer;
begin
  FTimer.Enabled := FWindows.Count > 0;
end;

procedure TToast.tick(Sender: TObject);
begin
  var now := GetTickCount64;
  var step := if FAnimated and (FFadeTime > 0) then Max(FOpacity*integer(FTimer.Interval) div FFadeTime, 1) else FOpacity;
  var gone := false;
  for var i := FWindows.Count-1 downto 0 do begin
    var w := TToastWindow(FWindows[i]);
    if not w.Visible then continue;
    if w.FClosing then begin
      w.FAlpha -= step;
      if w.FAlpha <= 0 then begin
        FWindows.Delete(i);
        windowClosed(w);
        w.Free;
        gone := true;
        continue;
      end;
      w.AlphaBlendValue := w.FAlpha;
      w.applyLayer;
      continue;
    end;
    if w.FAlpha < FOpacity then begin
      w.FAlpha := Min(w.FAlpha+step, FOpacity);
      w.AlphaBlendValue := w.FAlpha;
      w.applyLayer;
    end;
    if (FDuration > 0) and (w.FPaused = 0) and (now-w.FShown >= QWord(FDuration)) then begin
      w.Close(crTimeout);
      // kept by the handler: the clock starts over
      if not w.FClosing then w.FShown := now;
    end else if FShowProgress and (FDuration > 0) then w.Invalidate;
  end;
  if gone then arrange;
  syncTimer;
end;

function TToast.mayClose(w: TToastWindow; reason: TToastCloseReason): boolean;
begin
  result := true;
  if Assigned(FOnClose) then FOnClose(self, w.FTitle, w.FText, w.FTag, reason, result);
end;

procedure TToast.windowClosed(w: TToastWindow);
begin
  if Assigned(FOnClosed) then FOnClosed(self, w.FTitle, w.FText, w.FTag);
end;

procedure TToast.windowClicked(w: TToastWindow);
begin
  if Assigned(FOnClick) then FOnClick(self, w.FTitle, w.FText, w.FTag);
  if FClickToClose then w.Close(crClick);
end;

// -- properties ----------------------

procedure TToast.setFont(value: TFont);
begin
  FFont.Assign(value);
  arrange;
end;

procedure TToast.setPosition(value: TToastPosition);
begin
  if FPosition = value then exit;
  FPosition := value;
  arrange;
end;

procedure TToast.setAccentStyle(value: TToastAccentStyle);
begin
  if FAccentStyle = value then exit;
  FAccentStyle := value;
  for var i := 0 to FWindows.Count-1 do TToastWindow(FWindows[i]).Invalidate;
end;

procedure TToast.setAnchor(value: TToastAnchor);
begin
  if FAnchor = value then exit;
  FAnchor := value;
  arrange;
end;

function TToast.getMetric(index: integer): integer;
begin
  result := match index of
    0: FDuration;
    1: FWidth;
    2: FMargin;
    3: FSpacing;
    4: FMaxVisible;
    5: FCornerRadius;
    6: FPadding;
    7: FIconSize;
    8: FOpacity;
    9: FFadeTime;
    10: FAccentWidth;
  else
    FBorderWidth
  end;
end;

procedure TToast.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 8 then value := Min(value, 255);
  if getMetric(index) = value then exit;
  match index of
    0: FDuration := value;
    1: FWidth := value;
    2: FMargin := value;
    3: FSpacing := value;
    4: FMaxVisible := value;
    5: FCornerRadius := value;
    6: FPadding := value;
    7: FIconSize := value;
    8: FOpacity := value;
    9: FFadeTime := value;
    10: FAccentWidth := value;
  else
    FBorderWidth := value;
  end;
  arrange;
  for var i := 0 to FWindows.Count-1 do TToastWindow(FWindows[i]).Invalidate;
end;

function TToast.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowCloseButton;
    1: FShowIcon;
    2: FShowProgress;
    3: FAnimated;
    4: FClickToClose;
    5: FNewestFirst;
  else
    FPauseOnHover
  end;
end;

procedure TToast.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowCloseButton := value;
    1: FShowIcon := value;
    2: FShowProgress := value;
    3: FAnimated := value;
    4: FClickToClose := value;
    5: FNewestFirst := value;
  else
    FPauseOnHover := value;
  end;
  arrange;
end;

function TToast.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FSurfaceColor;
    1: FBorderColor;
    2: FTextColor;
    3: FTitleColor;
    4: FInfoColor;
    5: FSuccessColor;
    6: FWarningColor;
  else
    FErrorColor
  end;
end;

procedure TToast.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FSurfaceColor := value;
    1: FBorderColor := value;
    2: FTextColor := value;
    3: FTitleColor := value;
    4: FInfoColor := value;
    5: FSuccessColor := value;
    6: FWarningColor := value;
  else
    FErrorColor := value;
  end;
  for var i := 0 to FWindows.Count-1 do TToastWindow(FWindows[i]).Invalidate;
end;

end.
