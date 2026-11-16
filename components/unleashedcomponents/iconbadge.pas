{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit IconBadge;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Math, Types, LCLType, LCLIntf, Graphics, IntfGraphics, Forms, ExtCtrls;

const
  BADGE_RED = TColor($003539E5);

type
  // what is painted over the icon: a plain dot, Value as a number, Text in
  // a pill, Text on a strip across the icon, a frame around the icon, a
  // bar showing Progress
  TIconBadgeStyle = (ibsDot, ibsNumber, ibsText, ibsBanner, ibsFrame, ibsProgress);
  // where the badge sits on the icon
  TIconBadgePosition = (ibpTopLeft, ibpTop, ibpTopRight, ibpLeft, ibpCenter, ibpRight, ibpBottomLeft, ibpBottom, ibpBottomRight);
  // the outline: fully round ends, corners rounded by a quarter, square
  TIconBadgeShape = (ibhRound, ibhRounded, ibhSquare);
  // how the badge moves: shown and hidden in turns, shrinking and growing,
  // fading out and in
  TIconBadgeEffect = (ibeNone, ibeBlink, ibePulse, ibeFade);

  // the pixels of a square picture, row by row, as $AARRGGBB
  TIconPixels = array of dword;

  { TIconBadge }

  // paints a badge over the icon of the application, so it shows on the
  // taskbar button, and over a tray icon when one is linked: a dot, a
  // counter, a short text, a frame or a progress bar, still or animated.
  // The icons get their own pictures back when Visible goes off
  TIconBadge = class(TComponent)
  private
    FIcon, FAppIcon, FFormIcon, FTrayOwnIcon: TIcon;
    FTrayIcon: TCustomTrayIcon;
    FTimer: TTimer;
    FStyle: TIconBadgeStyle;
    FPosition: TIconBadgePosition;
    FShape: TIconBadgeShape;
    FEffect: TIconBadgeEffect;
    FValue, FMax, FProgress, FSize, FPeriod, FTick, FUpdating: integer;
    FText, FFontName: string;
    FVisible, FTaskbar, FShowZero, FGrayscale, FBold, FOwnButton, FTaskbarOn, FTrayOn, FPainting, FDirty: boolean;
    FBadgeColor, FTextColor, FBorderColor: TColor;
    FStarted: QWord;
    FButtonWindow: PtrUInt;
    procedure setIcon(value: TIcon);
    procedure setTrayIcon(value: TCustomTrayIcon);
    procedure setStyle(value: TIconBadgeStyle);
    procedure setPosition(value: TIconBadgePosition);
    procedure setShape(value: TIconBadgeShape);
    procedure setEffect(value: TIconBadgeEffect);
    procedure setInt(index: integer; value: integer);
    function getInt(index: integer): integer;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure iconChanged(Sender: TObject);
    procedure tick(Sender: TObject);
    function running: boolean;
    function ownerForm: TCustomForm;
    function badgeShown: boolean;
    function active: boolean;
    function badgeText: string;
    function phase: single;
    function taskbarBase: TIcon;
    function trayBase: TIcon;
    procedure captureTaskbar;
    function taskbarWindow: PtrUInt;
    procedure claimButton(claim: boolean);
    function wantsButton: boolean;
    function buttonPending: boolean;
    procedure restoreTaskbar;
    procedure restoreTray;
    procedure paintIcons;
    procedure changed;
    function render(base: TIcon; side: integer): TIconPixels;
    function buildIcon(base: TIcon; const sides: array of integer): TIcon;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the icon with the badge as it is right now, side pixels wide and
    // high; the caller frees it
    function MakeIcon(side: integer): TIcon;
    // starts the effect over from its first frame
    procedure Restart;
    // several properties set between the two repaint the icons once
    procedure BeginUpdate;
    procedure EndUpdate;
  published
    // the picture under the badge; empty takes the icon of the form, or of
    // the application when the form has none
    property Icon: TIcon read FIcon write setIcon;
    // a tray icon that gets the same badge
    property TrayIcon: TCustomTrayIcon read FTrayIcon write setTrayIcon;
    property Style: TIconBadgeStyle read FStyle write setStyle default ibsDot;
    // a banner takes the row only, a progress bar goes to the top or the
    // bottom, a frame ignores it
    property Position: TIconBadgePosition read FPosition write setPosition default ibpTopRight;
    property Shape: TIconBadgeShape read FShape write setShape default ibhRound;
    property Effect: TIconBadgeEffect read FEffect write setEffect default ibeNone;
    // the number of ibsNumber
    property Value: integer index 0 read getInt write setInt default 0;
    // values past this show as "Max+"
    property Max: integer index 1 read getInt write setInt default 99;
    // percent done, the bar of ibsProgress
    property Progress: integer index 2 read getInt write setInt default 0;
    // the height of the badge in percent of the icon
    property Size: integer index 3 read getInt write setInt default 50;
    // one round of the effect, in milliseconds
    property Period: integer index 4 read getInt write setInt default 1000;
    // the words of ibsText and ibsBanner; a few letters fit
    property Text: string index 0 read getText write setText;
    // empty takes the default font
    property FontName: string index 1 read getText write setText;
    // off, the icons show their own pictures
    property Visible: boolean index 0 read getFlag write setFlag default true;
    // the icon of the application and of the form carries the badge; off,
    // only the tray icon does
    property Taskbar: boolean index 1 read getFlag write setFlag default true;
    // a zero shows; off, ibsNumber has no badge at zero
    property ShowZero: boolean index 2 read getFlag write setFlag default false;
    // the picture under the badge loses its colors
    property Grayscale: boolean index 3 read getFlag write setFlag default false;
    property Bold: boolean index 4 read getFlag write setFlag default true;
    // Windows shows the icon of the shortcut for a pinned application,
    // whatever icon its window has. On, the window takes a taskbar button
    // of its own while Visible and Taskbar are on; off, it stays with the
    // pinned one and the badge shows only where the taskbar draws the
    // window icon
    property OwnButton: boolean index 5 read getFlag write setFlag default true;
    property BadgeColor: TColor index 0 read getPartColor write setPartColor default BADGE_RED;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clWhite;
    // the rim that keeps the badge apart from the picture; clNone for none
    property BorderColor: TColor index 2 read getPartColor write setPartColor default clWhite;
  end;

implementation

{$ifdef WINDOWS}
uses
  Windows, ActiveX, ShlObj, InterfaceBase;
{$endif}

const
  // the pause between two frames of a moving badge
  FRAME_MS = 80;
  // the text is drawn this many times larger and shrunk back, which
  // smooths its edges the same way on every system
  OVERSAMPLE = 4;

function clamp01(value: single): single;
begin
  result := if value < 0 then 0 else if value > 1 then 1 else value;
end;

// lays a color over one pixel; coverage 0..1
procedure blendPixel(var pixel: dword; color: TColor; coverage: single);
begin
  var a := Round(clamp01(coverage)*255);
  if a = 0 then exit;
  var rgb := ColorToRGB(color);
  var under := (pixel shr 24)*(255-a) div 255;
  var total := a+under;
  var r := ((rgb and $FF)*a+((pixel shr 16) and $FF)*under) div total;
  var g := (((rgb shr 8) and $FF)*a+((pixel shr 8) and $FF)*under) div total;
  var b := (((rgb shr 16) and $FF)*a+(pixel and $FF)*under) div total;
  pixel := (dword(total) shl 24) or (dword(r) shl 16) or (dword(g) shl 8) or dword(b);
end;

// the distance from a point to the edge of a rounded box, negative inside
function boxDistance(x, y, cx, cy, halfWidth, halfHeight, radius: single): single;
begin
  var qx := abs(x-cx)-(halfWidth-radius);
  var qy := abs(y-cy)-(halfHeight-radius);
  result := hypot(Math.Max(qx, 0.0), Math.Max(qy, 0.0))+Math.Min(Math.Max(qx, qy), 0.0)-radius;
end;

// fills a rounded box with smooth edges; ring above zero leaves only a
// band that wide along the edge
procedure fillBox(var pixels: TIconPixels; side: integer; cx, cy, halfWidth, halfHeight, radius: single; color: TColor; opacity: single; ring: single=0);
begin
  if (halfWidth <= 0) or (halfHeight <= 0) then exit;
  radius := Math.Min(radius, Math.Min(halfWidth, halfHeight));
  for var y := Math.Max(0, Floor(cy-halfHeight)-1) to Math.Min(side-1, Ceil(cy+halfHeight)) do for var x := Math.Max(0, Floor(cx-halfWidth)-1) to Math.Min(side-1, Ceil(cx+halfWidth)) do begin
    var distance := boxDistance(x+0.5, y+0.5, cx, cy, halfWidth, halfHeight, radius);
    var cover := clamp01(0.5-distance);
    if ring > 0 then cover -= clamp01(0.5-(distance+ring));
    if cover > 0 then blendPixel(pixels[y*side+x], color, cover*opacity);
  end;
end;

// the ink of a text as coverage 0..255 per pixel, width by height, cut to
// the bounds of the ink; empty when nothing was drawn
function textInk(const fontName: string; bold: boolean; const text: string; fontHeight: single; out width, height: integer): TBytes;
begin
  result := nil;
  width := 0;
  height := 0;
  if text = '' then exit;
  var bmp := autofree Graphics.TBitmap.Create;
  bmp.SetSize(1, 1);
  if fontName <> '' then bmp.Canvas.Font.Name := fontName;
  bmp.Canvas.Font.Style := if bold then [fsBold] else [];
  bmp.Canvas.Font.Height := -Math.Max(OVERSAMPLE, Round(fontHeight*OVERSAMPLE));
  bmp.Canvas.Font.Quality := fqNonAntialiased;
  var extent := bmp.Canvas.TextExtent(text);
  if (extent.cx <= 0) or (extent.cy <= 0) then exit;
  bmp.SetSize(extent.cx+2*OVERSAMPLE, extent.cy+2*OVERSAMPLE);
  bmp.Canvas.Brush.Color := clBlack;
  bmp.Canvas.FillRect(0, 0, bmp.Width, bmp.Height);
  bmp.Canvas.Font.Color := clWhite;
  bmp.Canvas.Brush.Style := bsClear;
  bmp.Canvas.TextOut(OVERSAMPLE, OVERSAMPLE, text);
  var img := autofree bmp.CreateIntfImage;
  var left := img.Width;
  var top := img.Height;
  var right := -1;
  var bottom := -1;
  for var y := 0 to img.Height-1 do for var x := 0 to img.Width-1 do if img.Colors[x, y].red >= $8000 then begin
    if x < left then left := x;
    if x > right then right := x;
    if y < top then top := y;
    if y > bottom then bottom := y;
  end;
  if right < left then exit;
  width := (right-left+OVERSAMPLE) div OVERSAMPLE;
  height := (bottom-top+OVERSAMPLE) div OVERSAMPLE;
  SetLength(result, width*height);
  for var y := 0 to height-1 do for var x := 0 to width-1 do begin
    var lit := 0;
    for var sy := 0 to OVERSAMPLE-1 do for var sx := 0 to OVERSAMPLE-1 do begin
      var px := left+x*OVERSAMPLE+sx;
      var py := top+y*OVERSAMPLE+sy;
      if (px <= right) and (py <= bottom) and (img.Colors[px, py].red >= $8000) then lit += 1;
    end;
    result[y*width+x] := lit*255 div (OVERSAMPLE*OVERSAMPLE);
  end;
end;

// paints the ink of a text with its middle at cx, cy
procedure drawInk(var pixels: TIconPixels; side: integer; const ink: TBytes; width, height: integer; cx, cy: single; color: TColor; opacity: single);
begin
  var left := Round(cx-width/2);
  var top := Round(cy-height/2);
  for var y := 0 to height-1 do for var x := 0 to width-1 do begin
    var px := left+x;
    var py := top+y;
    if (px < 0) or (py < 0) or (px >= side) or (py >= side) then continue;
    var cover := ink[y*width+x];
    if cover > 0 then blendPixel(pixels[py*side+px], color, cover/255*opacity);
  end;
end;

// a square picture brought to another size: shrinking averages the pixels
// under each new one, enlarging blends the neighbours
function resample(const source: TIconPixels; width, height, side: integer): TIconPixels;
begin
  result := nil;
  SetLength(result, side*side);
  var stepX := width/side;
  var stepY := height/side;
  for var dy := 0 to side-1 do for var dx := 0 to side-1 do begin
    var x0 := dx*stepX;
    var x1 := x0+stepX;
    var y0 := dy*stepY;
    var y1 := y0+stepY;
    if stepX < 1 then begin
      x0 := (dx+0.5)*stepX-0.5;
      x1 := x0+1;
    end;
    if stepY < 1 then begin
      y0 := (dy+0.5)*stepY-0.5;
      y1 := y0+1;
    end;
    var a: double := 0;
    var r: double := 0;
    var g: double := 0;
    var b: double := 0;
    var total: double := 0;
    for var sy := Math.Max(0, Floor(y0)) to Math.Min(height-1, Ceil(y1)-1) do for var sx := Math.Max(0, Floor(x0)) to Math.Min(width-1, Ceil(x1)-1) do begin
      var weight := (Math.Min(x1, sx+1.0)-Math.Max(x0, sx+0.0))*(Math.Min(y1, sy+1.0)-Math.Max(y0, sy+0.0));
      if weight <= 0 then continue;
      var pixel := source[sy*width+sx];
      var alpha := (pixel shr 24)*weight;
      a += alpha;
      r += ((pixel shr 16) and $FF)*alpha;
      g += ((pixel shr 8) and $FF)*alpha;
      b += (pixel and $FF)*alpha;
      total += weight;
    end;
    if (total > 0) and (a > 0) then result[dy*side+dx] := (dword(Math.Min(255, Round(a/total))) shl 24) or (dword(Math.Min(255, Round(r/a))) shl 16) or (dword(Math.Min(255, Round(g/a))) shl 8) or dword(Math.Min(255, Round(b/a)));
  end;
end;

// the picture of an icon closest to side pixels, brought to exactly that
// size; all clear when the icon is empty
function iconPixels(icon: TIcon; side: integer): TIconPixels;
begin
  result := nil;
  SetLength(result, side*side);
  if (icon = nil) or (icon.Count = 0) then exit;
  var best := icon.GetBestIndexForSize(Types.Size(side, side));
  icon.Current := if best < 0 then 0 else best;
  var img := autofree TLazIntfImage.Create(icon.RawImage, false);
  var width := img.Width;
  var height := img.Height;
  if (width <= 0) or (height <= 0) then exit;
  var source: TIconPixels := nil;
  SetLength(source, width*height);
  for var y := 0 to height-1 do for var x := 0 to width-1 do begin
    var color := img.Colors[x, y];
    var alpha: dword := if img.Masked[x, y] then 0 else color.alpha shr 8;
    source[y*width+x] := (alpha shl 24) or (dword(color.red shr 8) shl 16) or (dword(color.green shr 8) shl 8) or dword(color.blue shr 8);
  end;
  result := if (width = side) and (height = side) then source else resample(source, width, height, side);
end;

{$ifdef WINDOWS}
const
  // the properties of a window that tell the shell which application it
  // belongs to and how to start that application again
  APP_MODEL: TGUID = '{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}';
  APP_MODEL_COMMAND = 2;
  APP_MODEL_NAME = 4;
  APP_MODEL_ID = 5;

type
  TStoreForWindow = function(wnd: HWND; const iid: TGUID; out store: IPropertyStore): HResult; stdcall;

procedure putAppValue(store: IPropertyStore; id: dword; const value: UnicodeString);
begin
  var key: PROPERTYKEY;
  key.fmtid := APP_MODEL;
  key.pid := id;
  var item: PROPVARIANT;
  FillChar(item, SizeOf(item), 0);
  if value <> '' then begin
    item.vt := VT_LPWSTR;
    item.pwszVal := PWideChar(value);
  end;
  store.SetValue(@key, @item);
end;

// gives the window a taskbar button of its own, which shows the icon of the
// window; an empty id gives the window back
function setAppIdentity(wnd: HWND; const id: UnicodeString): boolean;
begin
  result := false;
  if wnd = 0 then exit;
  var storeForWindow := TStoreForWindow(GetProcAddress(GetModuleHandle('shell32.dll'), 'SHGetPropertyStoreForWindow'));
  if storeForWindow = nil then exit;
  var store: IPropertyStore;
  if (storeForWindow(wnd, IPropertyStore, store) <> S_OK) or (store = nil) then exit;
  var exe := UnicodeString(ParamStr(0));
  // pinning the button of the window starts the program the usual way; no
  // icon is named, so the button keeps showing the one of the window
  putAppValue(store, APP_MODEL_COMMAND, if id <> '' then '"'+exe+'"' else '');
  putAppValue(store, APP_MODEL_NAME, if id <> '' then UnicodeString(Application.Title) else '');
  putAppValue(store, APP_MODEL_ID, id);
  store.Commit;
  result := true;
end;
{$endif}

constructor TIconBadge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIcon := TIcon.Create;
  FIcon.OnChange := @iconChanged;
  FAppIcon := TIcon.Create;
  FFormIcon := TIcon.Create;
  FTrayOwnIcon := TIcon.Create;
  FPosition := ibpTopRight;
  FMax := 99;
  FSize := 50;
  FPeriod := 1000;
  FVisible := true;
  FTaskbar := true;
  FBold := true;
  FOwnButton := true;
  FBadgeColor := BADGE_RED;
  FTextColor := clWhite;
  FBorderColor := clWhite;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.OnTimer := @tick;
end;

destructor TIconBadge.Destroy;
begin
  FTimer.Enabled := false;
  // an application on its way out keeps whatever icons it has
  if (Application <> nil) and not Application.Terminated and not (csDestroying in Application.ComponentState) then begin
    claimButton(false);
    restoreTaskbar;
    restoreTray;
  end;
  FIcon.Free;
  FAppIcon.Free;
  FFormIcon.Free;
  FTrayOwnIcon.Free;
  inherited Destroy;
end;

procedure TIconBadge.Loaded;
begin
  inherited Loaded;
  changed;
end;

procedure TIconBadge.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FTrayIcon) then begin
    FTrayIcon := nil;
    FTrayOn := false;
  end;
end;

function TIconBadge.running: boolean;
begin
  result := ComponentState*[csDesigning, csLoading, csDestroying] = [];
end;

function TIconBadge.ownerForm: TCustomForm;
begin
  result := if (Owner is TCustomForm) and not (csDestroying in Owner.ComponentState) then TCustomForm(Owner) else nil;
end;

function TIconBadge.badgeShown: boolean;
begin
  result := case FStyle of
    ibsNumber: (FValue <> 0) or FShowZero;
    ibsText, ibsBanner: FText <> '';
  else
    true
  end;
end;

// there is something to paint; otherwise the icons keep their own pictures
function TIconBadge.active: boolean;
begin
  result := FVisible and (badgeShown or FGrayscale or (FIcon.Count > 0));
end;

function TIconBadge.badgeText: string;
begin
  result := if FStyle <> ibsNumber then FText else if FValue > FMax then IntToStr(FMax)+'+' else IntToStr(FValue);
end;

function TIconBadge.phase: single;
begin
  result := if FPeriod > 0 then ((GetTickCount64-FStarted) mod FPeriod)/FPeriod else 0;
end;

function TIconBadge.taskbarBase: TIcon;
begin
  result := if FIcon.Count > 0 then FIcon else if FFormIcon.Count > 0 then FFormIcon else FAppIcon;
end;

function TIconBadge.trayBase: TIcon;
begin
  result := if FIcon.Count > 0 then FIcon else if FTrayOwnIcon.Count > 0 then FTrayOwnIcon else taskbarBase;
end;

// keeps the pictures the application and the form show without a badge
procedure TIconBadge.captureTaskbar;
begin
  if FTaskbarOn then exit;
  FAppIcon.Assign(Application.Icon);
  var form := ownerForm;
  if (form <> nil) and (form.Icon.Count > 0) then FFormIcon.Assign(form.Icon) else FFormIcon.Clear;
end;

// the window behind the taskbar button; zero while it does not exist yet
function TIconBadge.taskbarWindow: PtrUInt;
begin
  result := 0;
  {$ifdef WINDOWS}
  {$push}
  {$warn SYMBOL_PLATFORM off}
  if not Application.MainFormOnTaskBar then exit(Widgetset.AppHandle);
  {$pop}
  if (Application.MainForm <> nil) and Application.MainForm.HandleAllocated then result := Application.MainForm.Handle;
  {$endif}
end;

// gives the taskbar button to the window while the badge shows, and back
procedure TIconBadge.claimButton(claim: boolean);
begin
  {$ifdef WINDOWS}
  if not claim then begin
    if FButtonWindow <> 0 then setAppIdentity(FButtonWindow, '');
    FButtonWindow := 0;
    exit;
  end;
  var wnd := taskbarWindow;
  if (wnd = 0) or (wnd = FButtonWindow) then exit;
  if setAppIdentity(wnd, UnicodeString('IconBadge.'+ChangeFileExt(ExtractFileName(ParamStr(0)), ''))) then FButtonWindow := wnd;
  {$endif}
end;

// the window keeps a button of its own for as long as a badge may show
function TIconBadge.wantsButton: boolean;
begin
  result := FVisible and FTaskbar and FOwnButton;
end;

// the button is still to be claimed: the window comes after the form loads
function TIconBadge.buttonPending: boolean;
begin
  result := false;
  {$ifdef WINDOWS}
  result := wantsButton and (FButtonWindow = 0);
  {$endif}
end;

procedure TIconBadge.restoreTaskbar;
begin
  if not FTaskbarOn then exit;
  FTaskbarOn := false;
  Application.Icon.Assign(FAppIcon);
  var form := ownerForm;
  if (form <> nil) and (FFormIcon.Count > 0) then form.Icon.Assign(FFormIcon);
end;

procedure TIconBadge.restoreTray;
begin
  if not FTrayOn then exit;
  FTrayOn := false;
  if FTrayIcon <> nil then FTrayIcon.Icon.Assign(FTrayOwnIcon);
end;

procedure TIconBadge.paintIcons;
begin
  var small := GetSystemMetrics(SM_CXSMICON);
  if small <= 0 then small := 16;
  var big := GetSystemMetrics(SM_CXICON);
  if big <= 0 then big := 32;
  // picking a picture of the base icon reports a change of it
  if FPainting then exit;
  FPainting := true;
  try
    claimButton(wantsButton);
    if active and FTaskbar then begin
      captureTaskbar;
      var picture := autofree buildIcon(taskbarBase, [small, big]);
      FTaskbarOn := true;
      Application.Icon.Assign(picture);
      var form := ownerForm;
      if (form <> nil) and (FFormIcon.Count > 0) then form.Icon.Assign(picture);
    end else restoreTaskbar;
    if active and (FTrayIcon <> nil) then begin
      if not FTrayOn then begin
        // the tray keeps the base picture here even when the taskbar is off
        captureTaskbar;
        FTrayOwnIcon.Assign(FTrayIcon.Icon);
        FTrayOn := true;
      end;
      var picture := autofree buildIcon(trayBase, [small]);
      FTrayIcon.Icon.Assign(picture);
    end else restoreTray;
  finally
    FPainting := false;
  end;
end;

// a property changed: the timer follows the effect, the icons are redrawn
procedure TIconBadge.BeginUpdate;
begin
  FUpdating += 1;
end;

procedure TIconBadge.EndUpdate;
begin
  if FUpdating > 0 then FUpdating -= 1;
  if (FUpdating = 0) and FDirty then changed;
end;

procedure TIconBadge.changed;
begin
  if not running then exit;
  if FUpdating > 0 then begin
    FDirty := true;
    exit;
  end;
  FDirty := false;
  var moving := FVisible and (FEffect <> ibeNone) and badgeShown and (FTaskbar or (FTrayIcon <> nil));
  FTimer.Interval := if FEffect = ibeBlink then Math.Max(50, FPeriod div 2) else FRAME_MS;
  if moving and not FTimer.Enabled then Restart;
  if not moving then FTick := 0;
  paintIcons;
  FTimer.Enabled := moving or buttonPending;
end;

procedure TIconBadge.tick(Sender: TObject);
begin
  var moving := FVisible and (FEffect <> ibeNone) and badgeShown;
  if moving then begin
    FTick += 1;
    paintIcons;
  end else claimButton(wantsButton);
  FTimer.Enabled := moving or buttonPending;
end;

procedure TIconBadge.Restart;
begin
  FStarted := GetTickCount64;
  FTick := 0;
end;

function TIconBadge.render(base: TIcon; side: integer): TIconPixels;
begin
  result := iconPixels(base, side);
  if FGrayscale then for var i := 0 to High(result) do begin
    var pixel := result[i];
    var gray := (((pixel shr 16) and $FF)*77+((pixel shr 8) and $FF)*150+(pixel and $FF)*29) shr 8;
    result[i] := (pixel and $FF000000) or (gray shl 16) or (gray shl 8) or gray;
  end;
  if not badgeShown then exit;
  var opacity: single := 1;
  var scale: single := 1;
  // one at the start of a round, zero in its middle
  var wave := 0.5+0.5*cos(phase*2*pi);
  case FEffect of
    ibeBlink: if Odd(FTick) then exit;
    ibePulse: scale := 0.7+0.3*wave;
    ibeFade: opacity := 0.15+0.85*wave;
  else
    ;
  end;
  var column := Ord(FPosition) mod 3;
  var row := Ord(FPosition) div 3;
  var border: single := if FBorderColor <> clNone then Math.Max(1.0, side/20) else 0;
  var height: single := side*FSize/100*scale;
  var half := side/2;
  case FStyle of
    ibsFrame: begin
      var radius := if FShape = ibhRound then half else if FShape = ibhRounded then side*0.22 else 0;
      fillBox(result, side, half, half, half, half, radius, FBadgeColor, opacity, Math.Max(1.5, height*0.22));
    end;
    ibsProgress: begin
      var bar := Math.Max(2.0, height*0.4);
      var margin := side*0.06;
      var cy := if row = 0 then margin+bar/2 else side-margin-bar/2;
      var radius := if FShape = ibhRound then bar/2 else if FShape = ibhRounded then bar/4 else 0;
      var filled := (side-2*margin)*EnsureRange(FProgress, 0, 100)/100;
      fillBox(result, side, half, cy, half-margin, bar/2, radius, clBlack, 0.55*opacity);
      fillBox(result, side, margin+filled/2, cy, filled/2, bar/2, radius, FBadgeColor, opacity);
    end;
    ibsBanner: begin
      var cy := if row = 0 then height/2 else if row = 1 then half else side-height/2;
      fillBox(result, side, half, cy, half, height/2, 0, FBadgeColor, opacity);
      var room := side*0.9;
      var inkWidth, inkHeight: integer;
      var ink := textInk(FFontName, FBold, FText, height*0.78, inkWidth, inkHeight);
      if inkWidth > room then ink := textInk(FFontName, FBold, FText, height*0.78*room/inkWidth, inkWidth, inkHeight);
      drawInk(result, side, ink, inkWidth, inkHeight, half, cy, FTextColor, opacity);
    end;
  else
    var width := height;
    var ink: TBytes := nil;
    var inkWidth := 0;
    var inkHeight := 0;
    if FStyle = ibsDot then begin
      height := height*0.7;
      width := height;
    end else begin
      var padding := height*0.22;
      var room := side-2*border-2*padding;
      ink := textInk(FFontName, FBold, badgeText, height*0.78, inkWidth, inkHeight);
      if inkWidth > room then ink := textInk(FFontName, FBold, badgeText, height*0.78*room/inkWidth, inkWidth, inkHeight);
      width := Math.Max(height, Math.Min(side-2*border, inkWidth+2*padding));
    end;
    var cx := if column = 0 then border+width/2 else if column = 1 then half else side-border-width/2;
    var cy := if row = 0 then border+height/2 else if row = 1 then half else side-border-height/2;
    var radius := if FShape = ibhRound then height/2 else if FShape = ibhRounded then height/4 else 0;
    if border > 0 then fillBox(result, side, cx, cy, width/2+border, height/2+border, if radius > 0 then radius+border else 0, FBorderColor, opacity);
    fillBox(result, side, cx, cy, width/2, height/2, radius, FBadgeColor, opacity);
    drawInk(result, side, ink, inkWidth, inkHeight, cx, cy, FTextColor, opacity);
  end;
end;

// the pictures go through the icon file format, one image per size, which
// every widgetset reads with its alpha channel
function TIconBadge.buildIcon(base: TIcon; const sides: array of integer): TIcon;
begin
  var list: array of integer := nil;
  for var side in sides do begin
    var edge := EnsureRange(side, 8, 256);
    var known := false;
    for var have in list do if have = edge then known := true;
    if not known then begin
      SetLength(list, Length(list)+1);
      list[High(list)] := edge;
    end;
  end;
  var stream := autofree TMemoryStream.Create;
  stream.WriteWord(NtoLE(word(0)));
  stream.WriteWord(NtoLE(word(1)));
  stream.WriteWord(NtoLE(word(Length(list))));
  var offset: dword := 6+16*Length(list);
  for var edge in list do begin
    // the color rows and the one bit mask, its rows padded to 32 bits
    var bytes: dword := 40+edge*edge*4+((edge+31) div 32)*4*edge;
    stream.WriteByte(edge and $FF);
    stream.WriteByte(edge and $FF);
    stream.WriteByte(0);
    stream.WriteByte(0);
    stream.WriteWord(NtoLE(word(1)));
    stream.WriteWord(NtoLE(word(32)));
    stream.WriteDWord(NtoLE(bytes));
    stream.WriteDWord(NtoLE(offset));
    offset += bytes;
  end;
  for var edge in list do begin
    var pixels := render(base, edge);
    stream.WriteDWord(NtoLE(dword(40)));
    stream.WriteDWord(NtoLE(dword(edge)));
    stream.WriteDWord(NtoLE(dword(edge*2)));
    stream.WriteWord(NtoLE(word(1)));
    stream.WriteWord(NtoLE(word(32)));
    for var i := 1 to 6 do stream.WriteDWord(0);
    // rows run from the bottom up
    for var y := edge-1 downto 0 do for var x := 0 to edge-1 do stream.WriteDWord(NtoLE(pixels[y*edge+x]));
    var maskRow: TBytes := nil;
    SetLength(maskRow, ((edge+31) div 32)*4);
    for var y := edge-1 downto 0 do begin
      FillChar(maskRow[0], Length(maskRow), 0);
      for var x := 0 to edge-1 do if pixels[y*edge+x] shr 24 = 0 then maskRow[x div 8] := maskRow[x div 8] or ($80 shr (x mod 8));
      stream.WriteBuffer(maskRow[0], Length(maskRow));
    end;
  end;
  stream.Position := 0;
  result := TIcon.Create;
  try
    result.LoadFromStream(stream);
  except
    result.Free;
    raise;
  end;
end;

function TIconBadge.MakeIcon(side: integer): TIcon;
begin
  if running then captureTaskbar;
  result := buildIcon(taskbarBase, [side]);
end;

procedure TIconBadge.setIcon(value: TIcon);
begin
  FIcon.Assign(value);
end;

procedure TIconBadge.iconChanged(Sender: TObject);
begin
  changed;
end;

procedure TIconBadge.setTrayIcon(value: TCustomTrayIcon);
begin
  if FTrayIcon = value then exit;
  if running then restoreTray;
  if FTrayIcon <> nil then FTrayIcon.RemoveFreeNotification(self);
  FTrayIcon := value;
  FTrayOn := false;
  if FTrayIcon <> nil then FTrayIcon.FreeNotification(self);
  changed;
end;

procedure TIconBadge.setStyle(value: TIconBadgeStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  changed;
end;

procedure TIconBadge.setPosition(value: TIconBadgePosition);
begin
  if FPosition = value then exit;
  FPosition := value;
  changed;
end;

procedure TIconBadge.setShape(value: TIconBadgeShape);
begin
  if FShape = value then exit;
  FShape := value;
  changed;
end;

procedure TIconBadge.setEffect(value: TIconBadgeEffect);
begin
  if FEffect = value then exit;
  FEffect := value;
  // the timer starts over with the pace of the new effect
  FTimer.Enabled := false;
  changed;
end;

function TIconBadge.getInt(index: integer): integer;
begin
  result := case index of
    0: FValue;
    1: FMax;
    2: FProgress;
    3: FSize;
  else
    FPeriod
  end;
end;

procedure TIconBadge.setInt(index: integer; value: integer);
begin
  case index of
    2: value := EnsureRange(value, 0, 100);
    3: value := EnsureRange(value, 10, 100);
    4: value := Math.Max(100, value);
  else
    ;
  end;
  if getInt(index) = value then exit;
  case index of
    0: FValue := value;
    1: FMax := value;
    2: FProgress := value;
    3: FSize := value;
  else
    FPeriod := value;
  end;
  changed;
end;

function TIconBadge.getText(index: integer): string;
begin
  result := if index = 0 then FText else FFontName;
end;

procedure TIconBadge.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  if index = 0 then FText := value else FFontName := value;
  changed;
end;

function TIconBadge.getFlag(index: integer): boolean;
begin
  result := case index of
    0: FVisible;
    1: FTaskbar;
    2: FShowZero;
    3: FGrayscale;
    4: FBold;
  else
    FOwnButton
  end;
end;

procedure TIconBadge.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  case index of
    0: FVisible := value;
    1: FTaskbar := value;
    2: FShowZero := value;
    3: FGrayscale := value;
    4: FBold := value;
  else
    FOwnButton := value;
  end;
  changed;
end;

function TIconBadge.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FBadgeColor else if index = 1 then FTextColor else FBorderColor;
end;

procedure TIconBadge.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  case index of
    0: FBadgeColor := value;
    1: FTextColor := value;
  else
    FBorderColor := value;
  end;
  changed;
end;

end.
