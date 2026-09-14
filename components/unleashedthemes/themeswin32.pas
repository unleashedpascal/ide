{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesWin32;

{$mode unleashed}

interface

{$ifdef LCLWin32}
uses
  ThemesPalette;

// repaints every IDE window with the palette; the hooks install on first use
// and stay. A dark palette also turns on the dark title bars and menus
procedure applyPalette(const newPal: TPalette);
// hands every window back to the stock look
procedure dropPalette;

var
  // fired on the UI thread when the desktop switches between light and dark apps
  onSystemThemeChange: procedure = nil;

const
  TAB_BAND = 4; // pixels kept free on the tab side of a tab control
  TAB_PAD_X = 8; // text padding inside a tab
  TAB_PAD_Y = 3;
{$endif}

implementation

{$ifdef LCLWin32}
uses
  Windows, CommCtrl, UxTheme, TmSchema, Classes, SysUtils, Math, Forms, Controls, Graphics, LCLType, Themes, Dialogs, StdCtrls, ComCtrls, fgl,
  InterfaceBase, Win32Int, Win32Proc, Win32Extra, Win32WSControls, WSControls;

type
  // theme classes with a custom dark rendering
  TThemeClass = (tcOther, tcButton, tcEdit, tcComboBox, tcTab, tcScrollBar, tcMenu, tcHeader, tcListView, tcToolBar, tcRebar, tcProgress, tcTreeView, tcToolTip, tcStatus, tcTrackBar);
  // uxtheme hands the same handle to every opener of a class, so an entry
  // lives until the last of them closes it
  TThemeEntry = record
    kind: TThemeClass;
    refs: integer;
    own: boolean; // an IDE window opened it; a handle only foreign windows hold paints natively
  end;
  TThemeMap = TFPGMap<HTHEME, TThemeEntry>;
  TArrowDir = (adUp, adDown, adLeft, adRight);
  TBarPart = (bpNone, bpLineUp, bpPageUp, bpThumb, bpPageDown, bpLineDown); // scroll bar parts, numbered like rgstate
  PNCCalcSizeParams = ^NCCALCSIZE_PARAMS;
  PCWPSTRUCT = ^CWPSTRUCT;
  PCWPRETSTRUCT = ^CWPRETSTRUCT;

  {$ifdef CPU64}
  PNtHeaders = PIMAGE_NT_HEADERS64;
  {$else}
  PNtHeaders = PIMAGE_NT_HEADERS32;
  {$endif}

const
  TAG_NAME: PWideChar = 'UnleashedThemes';
  DARK_EXPLORER: PWideChar = 'DarkMode_Explorer';
  DARK_CFD: PWideChar = 'DarkMode_CFD';
  SUB_TOPLEVEL = 1;
  SUB_CHROME = 2;
  SUB_STATUS = 3;
  SUB_UPDOWN = 4;
  SUB_TAB = 5;
  SUB_MENUPOPUP = 6;
  SUB_FOREIGN = 7;
  DWMWA_DARK_TITLE_OLD = 19; // builds before 19041
  DWMWA_DARK_TITLE = 20;
  MENU_BAND_LINE = 2; // rule below the menu bar of the main window
  MENU_BAND_GAP = 3;  // breathing room between the rule and the client area
  MENU_BAND = MENU_BAND_LINE+MENU_BAND_GAP;
  PAM_DEFAULT = 0;
  PAM_FORCE_DARK = 2;
  BUTTON_ID_BASE = $1000; // keeps task dialog button ids apart from the LCL modal results
  PENDING_NAME: PWideChar = 'UnleashedThemesPending'; // set until the window got its subclasses
  EDGE_NAME: PWideChar = 'UnleashedThemesEdge'; // inner edge color last painted, plus one

var
  active: boolean = false;
  darkLook: boolean = false; // the palette is dark: dark title bars, menus and native parts
  hooked: boolean = false;
  pal: TPalette;
  palBrush: array[0..COLOR_ENDCOLORS] of HBRUSH;
  palBrushColor: array[0..COLOR_ENDCOLORS] of TColor;
  menuBrush: HBRUSH = 0;
  themeMap: TThemeMap = nil;
  callWndHook: HHOOK = 0;
  callWndRetHook: HHOOK = 0;
  // the windows inside their paint messages, innermost last; a control that
  // paints through a memory DC is found here
  paintStack: array[0..63] of HWND;
  paintDepth: integer = 0;
  ownCreations: integer = 0;     // depth of CreateWindowExW calls that build IDE windows
  foreignCreations: integer = 0; // depth of CreateWindowExW calls that build designer windows

  uxSetPreferredAppMode: function(mode: integer): integer; stdcall = nil;
  uxAllowDarkModeForApp: function(allow: BOOL): BOOL; stdcall = nil;
  uxAllowDarkModeForWindow: function(wnd: HWND; allow: BOOL): BOOL; stdcall = nil;
  uxFlushMenuThemes: procedure; stdcall = nil;
  uxRefreshImmersiveColorPolicyState: procedure; stdcall = nil;
  dwmSetWindowAttribute: function(wnd: HWND; attr: DWORD; value: pointer; size: DWORD): HRESULT; stdcall = nil;

  origGetSysColor: function(index: longint): DWORD; stdcall = nil;
  origGetSysColorBrush: function(index: longint): HBRUSH; stdcall = nil;
  origDrawEdge: function(dc: HDC; var rect: TRect; edge, flags: UINT): BOOL; stdcall = nil;
  origDeleteObject: function(obj: HGDIOBJ): BOOL; stdcall = nil;
  origCreateWindowExW: function(exStyle: DWORD; cls, title: LPCWSTR; style: DWORD; x, y, w, h: longint; parent: HWND; menu: HMENU; inst: HINST; param: LPVOID): HWND; stdcall = nil;
  origSetScrollInfo: function(wnd: HWND; bar: longint; const info: SCROLLINFO; redraw: BOOL): longint; stdcall = nil;
  origSetScrollPos: function(wnd: HWND; bar, pos: longint; redraw: BOOL): longint; stdcall = nil;
  origSetScrollRange: function(wnd: HWND; bar, minPos, maxPos: longint; redraw: BOOL): BOOL; stdcall = nil;
  origShowScrollBar: function(wnd: HWND; bar: longint; show: BOOL): BOOL; stdcall = nil;
  origEnableScrollBar: function(wnd: HWND; flags, arrows: UINT): BOOL; stdcall = nil;
  origOpenThemeData: function(wnd: HWND; classList: LPCWSTR): HTHEME; stdcall = nil;
  origOpenThemeDataForDpi: function(wnd: HWND; classList: LPCWSTR; dpi: UINT): HTHEME; stdcall = nil;
  origOpenThemeDataEx: function(wnd: HWND; classList: LPCWSTR; flags: DWORD): HTHEME; stdcall = nil;
  origCloseThemeData: function(theme: HTHEME): HRESULT; stdcall = nil;
  origDrawThemeBackground: function(theme: HTHEME; dc: HDC; part, state: integer; const rect: TRect; clip: PRect): HRESULT; stdcall = nil;
  origDrawThemeText: function(theme: HTHEME; dc: HDC; part, state: integer; text: LPCWSTR; count: integer; flags, flags2: DWORD; const rect: TRect): HRESULT; stdcall = nil;
  origDrawThemeTextEx: function(theme: HTHEME; dc: HDC; part, state: integer; text: LPCWSTR; count: integer; flags: DWORD; rect: PRect; options: PDTTOPTS): HRESULT; stdcall = nil;
  origGetThemeColor: function(theme: HTHEME; part, state, prop: integer; var color: DWORD): HRESULT; stdcall = nil;
  origDrawThemeEdge: function(theme: HTHEME; dc: HDC; part, state: integer; const dest: TRect; edge, flags: UINT; content: PRect): HRESULT; stdcall = nil;
  origGetThemeSysColor: function(theme: HTHEME; colorId: integer): COLORREF; stdcall = nil;
  origGetThemeSysColorBrush: function(theme: HTHEME; colorId: integer): HBRUSH; stdcall = nil;
  origTaskDialogIndirect: function(const config: PTASKDIALOGCONFIG; button, radioButton: PInteger; verify: PBOOL): HRESULT; stdcall = nil;

// -- palette --------------------------------------------------------------

function palBrushOf(index: integer): HBRUSH;
begin
  // a superseded brush may still be selected into a DC somewhere, so it stays alive
  if (palBrush[index] = 0) or (palBrushColor[index] <> pal[index]) then begin
    palBrush[index] := CreateSolidBrush(pal[index]);
    palBrushColor[index] := pal[index];
  end;
  result := palBrush[index];
end;

function isPalBrush(obj: HGDIOBJ): boolean;
begin
  result := true;
  if obj = menuBrush then exit;
  for var i := low(palBrush) to high(palBrush) do if palBrush[i] = obj then exit;
  result := false;
end;

// -- gdi helpers ----------------------------------------------------------

procedure fillRect(dc: HDC; const r: TRect; color: TColor);
begin
  SetDCBrushColor(dc, color);
  Windows.FillRect(dc, r, GetStockObject(DC_BRUSH));
end;

procedure frameRect(dc: HDC; const r: TRect; color: TColor);
begin
  SetDCBrushColor(dc, color);
  Windows.FrameRect(dc, r, GetStockObject(DC_BRUSH));
end;

procedure drawLine(dc: HDC; x1, y1, x2, y2: integer; color: TColor);
begin
  SelectObject(dc, GetStockObject(DC_PEN));
  SetDCPenColor(dc, color);
  MoveToEx(dc, x1, y1, nil);
  LineTo(dc, x2, y2);
end;

procedure drawArrow(dc: HDC; const r: TRect; dir: TArrowDir; color: TColor);
begin
  var cx := (r.Left+r.Right) div 2;
  var cy := (r.Top+r.Bottom) div 2;
  var s := Max(3, Min(r.Width, r.Height) div 4);
  var pts: array[3] of TPoint;
  match dir of
    adUp: begin
      pts[0] := Point(cx-s, cy+s div 2);
      pts[1] := Point(cx+s, cy+s div 2);
      pts[2] := Point(cx, cy-s div 2);
    end;
    adDown: begin
      pts[0] := Point(cx-s, cy-s div 2);
      pts[1] := Point(cx+s, cy-s div 2);
      pts[2] := Point(cx, cy+s div 2);
    end;
    adLeft: begin
      pts[0] := Point(cx+s div 2, cy-s);
      pts[1] := Point(cx+s div 2, cy+s);
      pts[2] := Point(cx-s div 2, cy);
    end;
    adRight: begin
      pts[0] := Point(cx-s div 2, cy-s);
      pts[1] := Point(cx-s div 2, cy+s);
      pts[2] := Point(cx+s div 2, cy);
    end;
  end;
  SelectObject(dc, GetStockObject(DC_PEN));
  SelectObject(dc, GetStockObject(DC_BRUSH));
  SetDCPenColor(dc, color);
  SetDCBrushColor(dc, color);
  Windows.Polygon(dc, pts, 3);
end;

procedure drawCheckMark(dc: HDC; const r: TRect; color: TColor);
begin
  var w := r.Width;
  var h := r.Height;
  var pen := CreatePen(PS_SOLID, Max(1, Min(w, h) div 7), color);
  var old := SelectObject(dc, pen);
  MoveToEx(dc, r.Left+w div 5, r.Top+h div 2, nil);
  LineTo(dc, r.Left+w*2 div 5, r.Top+h*7 div 10);
  LineTo(dc, r.Left+w*4 div 5, r.Top+h*3 div 10);
  SelectObject(dc, old);
  DeleteObject(pen);
end;

procedure drawEllipse(dc: HDC; const r: TRect; fill, border: TColor);
begin
  SelectObject(dc, GetStockObject(DC_PEN));
  SelectObject(dc, GetStockObject(DC_BRUSH));
  SetDCPenColor(dc, border);
  SetDCBrushColor(dc, fill);
  Windows.Ellipse(dc, r.Left, r.Top, r.Right, r.Bottom);
end;

// square glyph box centered in the part rectangle
function glyphBox(const r: TRect): TRect;
begin
  var s := Min(r.Width, r.Height);
  result.Left := r.Left+(r.Width-s) div 2;
  result.Top := r.Top+(r.Height-s) div 2;
  result.Right := result.Left+s;
  result.Bottom := result.Top+s;
end;

// flat stand-in for DrawEdge: the 3D rings paint nothing, the layout they
// occupied stays so callers keep their content offsets
function drawEdgeDark(dc: HDC; var r: TRect; edge, flags: UINT): boolean;
begin
  result := not IsRectEmpty(r);
  if not result then exit;
  var box := r;
  if (edge and (BDR_RAISEDOUTER or BDR_SUNKENOUTER)) <> 0 then InflateRect(box, -1, -1);
  if (edge and (BDR_RAISEDINNER or BDR_SUNKENINNER)) <> 0 then InflateRect(box, -1, -1);
  if (flags and BF_MIDDLE) <> 0 then fillRect(dc, box, pal[COLOR_BTNFACE]);
  if (flags and BF_ADJUST) <> 0 then r := box;
end;

// -- scroll bars ----------------------------------------------------------

function classNameOf(wnd: HWND): string; forward;

// the non-client scroll bars are painted by uxtheme itself, out of reach of
// the import hooks, so they are painted over after every native refresh

type
  TScrollBarInfo = record
    cbSize: DWORD;
    rcScrollBar: TRect;
    dxyLineButton: longint;
    xyThumbTop: longint;
    xyThumbBottom: longint;
    reserved: longint;
    rgstate: array[6] of DWORD;
  end;

const
  OBJID_CLIENT = DWORD($FFFFFFFC);
  OBJID_VSCROLL = DWORD($FFFFFFFB);
  OBJID_HSCROLL = DWORD($FFFFFFFA);
  STATE_SYSTEM_UNAVAILABLE = $0001;
  STATE_SYSTEM_PRESSED = $0008;
  STATE_SYSTEM_INVISIBLE = $8000;
  STATE_SYSTEM_OFFSCREEN = $10000;
  SBM_SETSCROLLINFO = $00E9;
  THUMB_INSET = 3; // pixels between the thumb and the track edges
  TME_NONCLIENT = $00000010;

function GetScrollBarInfo(wnd: HWND; idObject: DWORD; var info: TScrollBarInfo): BOOL; stdcall; external 'user32' name 'GetScrollBarInfo';
// the Windows unit declares a record of the same name, so the import gets its own
function startMouseTracking(var track: TTrackMouseEvent): BOOL; stdcall; external 'user32' name 'TrackMouseEvent';

var
  // the bar part under the mouse; the native hot tracking is suppressed
  hover: record
    wnd: HWND;
    bar: integer;
    part: integer; // 1 first arrow, 3 thumb, 5 second arrow, matching rgstate
  end;
  // the scroll bar interaction in progress; the native tracking loops would
  // repaint the bar themselves, so presses are handled here instead
  drag: record
    wnd: HWND; // 0 when idle
    bar: integer; // SB_VERT, SB_HORZ or SB_CTL
    part: TBarPart;
    vertical: boolean;
    startMouse: integer; // screen coordinate along the bar at the press
    startPos: integer;
    unitsPerPixel: double;
  end;

procedure drawScrollBar(dc: HDC; const info: TScrollBarInfo; const origin: TPoint; vertical: boolean; hot: integer);
begin
  if (info.rgstate[0] and (STATE_SYSTEM_INVISIBLE or STATE_SYSTEM_OFFSCREEN)) <> 0 then exit;
  var r := info.rcScrollBar;
  OffsetRect(r, -origin.X, -origin.Y);
  fillRect(dc, r, pal[COLOR_SCROLLBAR]);
  var btn := info.dxyLineButton;
  var first := r;
  var second := r;
  if vertical then begin
    first.Bottom := r.Top+btn;
    second.Top := r.Bottom-btn;
  end else begin
    first.Right := r.Left+btn;
    second.Left := r.Right-btn;
  end;
  var firstDir := adUp;
  var secondDir := adDown;
  if not vertical then begin
    firstDir := adLeft;
    secondDir := adRight;
  end;
  var arrow := pal[COLOR_GRAYTEXT];
  if (info.rgstate[1] and STATE_SYSTEM_UNAVAILABLE) <> 0 then arrow := pal[COLOR_3DLIGHT] else if hot = 1 then arrow := pal[COLOR_BTNTEXT];
  drawArrow(dc, first, firstDir, arrow);
  arrow := pal[COLOR_GRAYTEXT];
  if (info.rgstate[5] and STATE_SYSTEM_UNAVAILABLE) <> 0 then arrow := pal[COLOR_3DLIGHT] else if hot = 5 then arrow := pal[COLOR_BTNTEXT];
  drawArrow(dc, second, secondDir, arrow);
  // the thumb offsets count from the start of the bar
  if ((info.rgstate[3] and (STATE_SYSTEM_UNAVAILABLE or STATE_SYSTEM_INVISIBLE)) <> 0) or (info.xyThumbBottom <= info.xyThumbTop) then exit;
  var thumb := r;
  if vertical then begin
    thumb.Top := r.Top+info.xyThumbTop;
    thumb.Bottom := r.Top+info.xyThumbBottom;
    InflateRect(thumb, -THUMB_INSET, 0);
  end else begin
    thumb.Left := r.Left+info.xyThumbTop;
    thumb.Right := r.Left+info.xyThumbBottom;
    InflateRect(thumb, 0, -THUMB_INSET);
  end;
  var color := pal[COLOR_BTNHIGHLIGHT];
  if ((info.rgstate[3] and STATE_SYSTEM_PRESSED) <> 0) or (hot = 3) then color := pal[COLOR_GRAYTEXT];
  SelectObject(dc, GetStockObject(DC_PEN));
  SelectObject(dc, GetStockObject(DC_BRUSH));
  SetDCPenColor(dc, color);
  SetDCBrushColor(dc, color);
  Windows.RoundRect(dc, thumb.Left, thumb.Top, thumb.Right, thumb.Bottom, 4, 4);
end;

function hotPartOf(wnd: HWND; bar: integer): integer;
begin
  result := 0;
  // a pressed part keeps the highlight until the button goes up, wherever the mouse went
  if (drag.wnd = wnd) and (drag.bar = bar) then exit(ord(drag.part));
  if (hover.wnd = wnd) and (hover.bar = bar) then result := hover.part;
end;

// repaints the scroll bars of a window: the non-client ones of a control, or
// the whole client of a stand-alone scroll bar control
procedure paintScrollBars(wnd: HWND);
begin
  var info := Default(TScrollBarInfo);
  info.cbSize := sizeof(info);
  if classNameOf(wnd) = 'ScrollBar' then begin
    if not GetScrollBarInfo(wnd, OBJID_CLIENT, info) then exit;
    var origin: TPoint := Point(0, 0);
    ClientToScreen(wnd, origin);
    var dc := GetDC(wnd);
    drawScrollBar(dc, info, origin, (GetWindowLongPtrW(wnd, GWL_STYLE) and SBS_VERT) <> 0, hotPartOf(wnd, SB_CTL));
    ReleaseDC(wnd, dc);
    exit;
  end;
  var style := GetWindowLongPtrW(wnd, GWL_STYLE);
  if (style and (WS_VSCROLL or WS_HSCROLL)) = 0 then exit;
  var win: TRect;
  GetWindowRect(wnd, @win);
  var dc := GetWindowDC(wnd);
  var vert := Default(TScrollBarInfo);
  var horz := Default(TScrollBarInfo);
  vert.cbSize := sizeof(vert);
  horz.cbSize := sizeof(horz);
  var hasVert := ((style and WS_VSCROLL) <> 0) and GetScrollBarInfo(wnd, OBJID_VSCROLL, vert);
  var hasHorz := ((style and WS_HSCROLL) <> 0) and GetScrollBarInfo(wnd, OBJID_HSCROLL, horz);
  if hasVert then drawScrollBar(dc, vert, win.TopLeft, true, hotPartOf(wnd, SB_VERT));
  if hasHorz then drawScrollBar(dc, horz, win.TopLeft, false, hotPartOf(wnd, SB_HORZ));
  // the corner where both bars meet
  if hasVert and hasHorz and (((vert.rgstate[0] or horz.rgstate[0]) and STATE_SYSTEM_INVISIBLE) = 0) then begin
    var corner := Rect(vert.rcScrollBar.Left-win.Left, horz.rcScrollBar.Top-win.Top, vert.rcScrollBar.Right-win.Left, horz.rcScrollBar.Bottom-win.Top);
    fillRect(dc, corner, pal[COLOR_BTNFACE]);
  end;
  ReleaseDC(wnd, dc);
end;

// -- window tagging -------------------------------------------------------

procedure tagWindow(wnd: HWND);
begin
  SetPropW(wnd, TAG_NAME, HANDLE(1));
end;

// true for windows the IDE created and for their descendants; owners do not
// count, so dialogs from other modules keep their own look, and a designed
// form keeps the stock look inside the editor window that docks it
function isTagged(wnd: HWND): boolean;
begin
  result := false;
  var desktop := GetDesktopWindow;
  while (wnd <> 0) and (wnd <> desktop) do begin
    var control := GetWin32WindowInfo(wnd)^.WinControl;
    if (control <> nil) and (csDesigning in control.ComponentState) then exit;
    if GetPropW(wnd, TAG_NAME) <> 0 then exit(true);
    wnd := GetAncestor(wnd, GA_PARENT);
  end;
end;

function ours(wnd: HWND): boolean;
begin
  result := (wnd = 0) or ((foreignCreations = 0) and ((ownCreations > 0) or isTagged(wnd)));
end;

function paintMessage(msg: UINT): boolean;
begin
  result := msg in [WM_PAINT, WM_PRINTCLIENT, WM_ERASEBKGND, WM_NCPAINT];
end;

// a sent paint message is seen by the thread hook, a dispatched one only by
// the subclass of the window, so both push; the depth keeps counting past
// the stack so the pops stay balanced
procedure pushPaint(wnd: HWND);
begin
  if paintDepth < length(paintStack) then paintStack[paintDepth] := wnd;
  inc(paintDepth);
end;

procedure popPaint(painting: boolean);
begin
  if painting and (paintDepth > 0) then dec(paintDepth);
end;

// the window a paint call draws for: the one behind the DC, or the innermost
// window inside its paint message when the DC is an off-screen buffer
function paintedWindow(dc: HDC): HWND;
begin
  result := WindowFromDC(dc);
  if (result = 0) and (paintDepth > 0) then result := paintStack[Min(paintDepth, length(paintStack))-1];
  if not IsWindow(result) then result := 0;
end;

function classNameOf(wnd: HWND): string;
begin
  var buf: array[64] of WideChar;
  var len := GetClassNameW(wnd, @buf[0], length(buf));
  var name: UnicodeString;
  SetString(name, PWideChar(@buf[0]), len);
  result := UTF8Encode(name);
end;

// -- theme handle bookkeeping ---------------------------------------------

function classOfName(classList: LPCWSTR): TThemeClass;
begin
  var s := LowerCase(UTF8Encode(UnicodeString(classList)));
  // "Explorer::ListView;ListView" -> "listview"
  var p := Pos(';', s);
  if p > 0 then s := copy(s, 1, p-1);
  p := Pos('::', s);
  if p > 0 then delete(s, 1, p+1);
  match s of
    'button': result := tcButton;
    'edit': result := tcEdit;
    'combobox': result := tcComboBox;
    'tab': result := tcTab;
    'scrollbar': result := tcScrollBar;
    'menu': result := tcMenu;
    'header': result := tcHeader;
    'listview': result := tcListView;
    'toolbar': result := tcToolBar;
    'rebar': result := tcRebar;
    'progress': result := tcProgress;
    'treeview': result := tcTreeView;
    'tooltip': result := tcToolTip;
    'status': result := tcStatus;
    'trackbar': result := tcTrackBar;
    _: result := tcOther;
  end;
end;

// dark variants shipped with Windows for themes opened without a window
function darkClassList(kind: TThemeClass; classList: LPCWSTR): UnicodeString;
begin
  match kind of
    tcButton: result := 'DarkMode_Explorer::Button';
    tcEdit: result := 'DarkMode_CFD::Edit';
    tcComboBox: result := 'DarkMode_CFD::Combobox';
    tcScrollBar: result := 'DarkMode_Explorer::ScrollBar';
    tcTreeView: result := 'DarkMode_Explorer::TreeView';
    tcListView: result := 'DarkMode_Explorer::ListView';
    _: result := classList;
  end;
end;

// every opener counts, since any of them may close the shared handle; only
// an IDE window decides the rendering of the class
procedure remember(theme: HTHEME; kind: TThemeClass; own: boolean);
begin
  if (theme = 0) or (themeMap = nil) then exit;
  var entry: TThemeEntry;
  if not themeMap.TryGetData(theme, entry) then begin
    entry.refs := 0;
    entry.kind := tcOther;
    entry.own := false;
  end;
  if own then begin
    entry.kind := kind;
    entry.own := true;
  end;
  inc(entry.refs);
  themeMap.AddOrSetData(theme, entry);
end;

// an opener the hooks never saw may be the one closing, so the entry stays
// even at zero; the next open of the handle sets its kind afresh
procedure forget(theme: HTHEME);
begin
  if (theme = 0) or (themeMap = nil) then exit;
  var entry: TThemeEntry;
  if not themeMap.TryGetData(theme, entry) then exit;
  if entry.refs > 0 then dec(entry.refs);
  themeMap.AddOrSetData(theme, entry);
end;

function kindOf(theme: HTHEME; out kind: TThemeClass): boolean;
begin
  var entry: TThemeEntry;
  result := active and (themeMap <> nil) and themeMap.TryGetData(theme, entry) and entry.own;
  if result then kind := entry.kind;
end;

function menuTextDisabled(part, state: integer): boolean;
begin
  if part = MENU_BARITEM then exit(state in [MBI_DISABLED, MBI_DISABLEDHOT, MBI_DISABLEDPUSHED]);
  result := (part = MENU_POPUPITEM) and (state in [MPI_DISABLED, MPI_DISABLEDHOT]);
end;

function buttonTextDisabled(part, state: integer): boolean;
begin
  match part of
    BP_PUSHBUTTON: result := state = PBS_DISABLED;
    BP_CHECKBOX: result := (state-1) mod 4 = 3;
    BP_RADIOBUTTON: result := state in [RBS_UNCHECKEDDISABLED, RBS_CHECKEDDISABLED];
    BP_GROUPBOX: result := state = GBS_DISABLED;
    _: result := false;
  end;
end;

// -- part painters --------------------------------------------------------

procedure drawMenuPart(dc: HDC; part, state: integer; const r: TRect);
begin
  match part of
    MENU_BARBACKGROUND, MENU_POPUPBACKGROUND, MENU_POPUPGUTTER: fillRect(dc, r, pal[COLOR_MENU]);
    MENU_BARITEM: fillRect(dc, r, if state in [MBI_HOT, MBI_PUSHED, MBI_DISABLEDHOT, MBI_DISABLEDPUSHED] then pal[COLOR_MENUHILIGHT] else pal[COLOR_MENU]);
    MENU_POPUPITEM: fillRect(dc, r, if state in [MPI_HOT, MPI_DISABLEDHOT] then pal[COLOR_MENUHILIGHT] else pal[COLOR_MENU]);
    MENU_POPUPBORDERS: begin
      fillRect(dc, r, pal[COLOR_MENU]);
      frameRect(dc, r, pal[COLOR_3DLIGHT]);
    end;
    MENU_POPUPSEPARATOR: begin
      var y := (r.Top+r.Bottom) div 2;
      drawLine(dc, r.Left, y, r.Right, y, pal[COLOR_3DLIGHT]);
    end;
    MENU_POPUPCHECKBACKGROUND: frameRect(dc, r, pal[COLOR_BTNHIGHLIGHT]);
    MENU_POPUPCHECK: begin
      var color := if state in [MC_CHECKMARKDISABLED, MC_BULLETDISABLED] then pal[COLOR_GRAYTEXT] else pal[COLOR_MENUTEXT];
      var box := glyphBox(r);
      if state in [MC_BULLETNORMAL, MC_BULLETDISABLED] then begin
        InflateRect(box, -box.Width*3 div 10, -box.Height*3 div 10);
        drawEllipse(dc, box, color, color);
      end else drawCheckMark(dc, box, color);
    end;
    MENU_POPUPSUBMENU: drawArrow(dc, r, adRight, if state = MSM_DISABLED then pal[COLOR_GRAYTEXT] else pal[COLOR_MENUTEXT]);
  end;
end;

// the tab of the control painted on `dc` under the middle of `r`, -1 when
// there is none; `item` is its rectangle without the growth of the selection
function tabItemAt(dc: HDC; const r: TRect; out wnd: HWND; out item: TRect): integer;
begin
  result := -1;
  item := Rect(0, 0, 0, 0);
  wnd := paintedWindow(dc);
  if wnd = 0 then exit;
  var center := Point((r.Left+r.Right) div 2, (r.Top+r.Bottom) div 2);
  for var i := 0 to SendMessage(wnd, TCM_GETITEMCOUNT, 0, 0)-1 do
    if (SendMessage(wnd, TCM_GETITEMRECT, i, LPARAM(@item)) <> 0) and PtInRect(item, center) then exit(i);
end;

// the caption of an unsaved editor page starts with an asterisk; the tab
// painted into `r` shows a strip for it instead
function tabMarked(dc: HDC; const r: TRect): boolean;
begin
  result := false;
  var wnd: HWND;
  var item: TRect;
  var index := tabItemAt(dc, r, wnd, item);
  if index < 0 then exit;
  var buf: array[0..1] of WideChar;
  var info := Default(TTCITEMW);
  info.mask := TCIF_TEXT;
  info.pszText := @buf[0];
  info.cchTextMax := length(buf);
  result := (SendMessage(wnd, TCM_GETITEMW, index, LPARAM(@info)) <> 0) and (buf[0] = '*');
end;

// the text of a tab sits in the middle of its item in every state; the control
// hands over a rectangle that moves with the selection
procedure centerTabText(dc: HDC; var r: TRect; var flags: DWORD);
begin
  var wnd: HWND;
  var item: TRect;
  if tabItemAt(dc, r, wnd, item) < 0 then exit;
  r.Top := item.Top;
  r.Bottom := item.Bottom;
  flags := flags or DT_VCENTER or DT_SINGLELINE;
end;

function drawTabPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := true;
  match part of
    TABP_TABITEM..TABP_TOPTABITEMBOTHEDGE: begin
      var selected := state in [TIS_SELECTED, TIS_FOCUSED];
      var fill := pal[COLOR_WINDOW];
      if selected then fill := pal[COLOR_BTNFACE] else if state = TIS_HOT then fill := pal[COLOR_HOVER];
      fillRect(dc, r, fill);
      var border := pal[COLOR_3DLIGHT];
      drawLine(dc, r.Left, r.Top, r.Right, r.Top, border);
      drawLine(dc, r.Left, r.Top, r.Left, r.Bottom, border);
      drawLine(dc, r.Right-1, r.Top, r.Right-1, r.Bottom, border);
      // the selected top tab stays open toward the pane below it
      if not selected or (part < TABP_TOPTABITEM) then drawLine(dc, r.Left, r.Bottom-1, r.Right, r.Bottom-1, border);
      // a strip along the outer edge: the accent on the selected page, the mark on an unsaved one
      var strip := clNone;
      if tabMarked(dc, r) then strip := pal[COLOR_MARK] else if selected then strip := pal[COLOR_HOTLIGHT];
      if strip = clNone then exit;
      if part >= TABP_TOPTABITEM then fillRect(dc, Rect(r.Left, r.Top, r.Right, r.Top+2), strip)
      else fillRect(dc, Rect(r.Left, r.Bottom-2, r.Right, r.Bottom), strip);
    end;
    // the pane carries no frame of its own; the page border below it is enough
    TABP_PANE, TABP_BODY: fillRect(dc, r, pal[COLOR_BTNFACE]);
    _: result := false;
  end;
end;

procedure drawCheckBoxPart(dc: HDC; state: integer; const r: TRect);
begin
  var slot := (state-1) mod 4; // 0 normal, 1 hot, 2 pressed, 3 disabled
  var group := (state-1) div 4; // 0 unchecked, 1 checked, 2 mixed
  var box := glyphBox(r);
  var fill := pal[COLOR_WINDOW];
  var border := pal[COLOR_BTNHIGHLIGHT];
  var glyph := pal[COLOR_BTNTEXT];
  match slot of
    1, 2: border := pal[COLOR_HOTLIGHT];
    3: begin
      fill := pal[COLOR_BTNFACE];
      border := pal[COLOR_3DLIGHT];
      glyph := pal[COLOR_GRAYTEXT];
    end;
  end;
  if slot = 2 then fill := pal[COLOR_3DLIGHT];
  fillRect(dc, box, fill);
  frameRect(dc, box, border);
  if group = 1 then drawCheckMark(dc, box, glyph)
  else if group = 2 then begin
    var inner := box;
    InflateRect(inner, -box.Width div 4, -box.Height div 4);
    fillRect(dc, inner, glyph);
  end;
end;

procedure drawRadioPart(dc: HDC; state: integer; const r: TRect);
begin
  var slot := (state-1) mod 4;
  var checked := state >= RBS_CHECKEDNORMAL;
  var box := glyphBox(r);
  var fill := pal[COLOR_WINDOW];
  var border := pal[COLOR_BTNHIGHLIGHT];
  var glyph := pal[COLOR_BTNTEXT];
  match slot of
    1, 2: border := pal[COLOR_HOTLIGHT];
    3: begin
      fill := pal[COLOR_BTNFACE];
      border := pal[COLOR_3DLIGHT];
      glyph := pal[COLOR_GRAYTEXT];
    end;
  end;
  if slot = 2 then fill := pal[COLOR_3DLIGHT];
  drawEllipse(dc, box, fill, border);
  if not checked then exit;
  InflateRect(box, -box.Width*3 div 10, -box.Height*3 div 10);
  drawEllipse(dc, box, glyph, glyph);
end;

procedure drawPushButtonPart(dc: HDC; state: integer; const r: TRect);
begin
  var fill := pal[COLOR_3DLIGHT];
  var border := pal[COLOR_BTNHIGHLIGHT];
  match state of
    PBS_HOT: fill := pal[COLOR_BTNHIGHLIGHT];
    PBS_PRESSED: fill := pal[COLOR_BTNSHADOW];
    PBS_DISABLED: begin
      fill := pal[COLOR_BTNFACE];
      border := pal[COLOR_3DLIGHT];
    end;
    PBS_DEFAULTED, PBS_DEFAULTED_ANIMATING: border := pal[COLOR_HOTLIGHT];
  end;
  fillRect(dc, r, pal[COLOR_BTNFACE]);
  SelectObject(dc, GetStockObject(DC_PEN));
  SelectObject(dc, GetStockObject(DC_BRUSH));
  SetDCPenColor(dc, border);
  SetDCBrushColor(dc, fill);
  Windows.RoundRect(dc, r.Left, r.Top, r.Right, r.Bottom, 5, 5);
end;

function drawComboBoxPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := true;
  match part of
    CP_BORDER: begin
      var fill := pal[COLOR_WINDOW];
      var frame := pal[COLOR_3DLIGHT];
      match state of
        CBB_HOT: frame := pal[COLOR_BTNHIGHLIGHT];
        CBB_FOCUSED: frame := pal[COLOR_HOTLIGHT];
        CBB_DISABLED: fill := pal[COLOR_BTNFACE];
      end;
      fillRect(dc, r, fill);
      frameRect(dc, r, frame);
    end;
    CP_READONLY, CP_BACKGROUND, CP_TRANSPARENTBACKGROUND: fillRect(dc, r, if state = CBRO_DISABLED then pal[COLOR_BTNFACE] else pal[COLOR_WINDOW]);
    CP_DROPDOWNBUTTON, CP_DROPDOWNBUTTONRIGHT, CP_DROPDOWNBUTTONLEFT: begin
      var inner := r;
      InflateRect(inner, -1, -1);
      fillRect(dc, inner, if state = CBXS_DISABLED then pal[COLOR_BTNFACE] else pal[COLOR_WINDOW]);
      drawArrow(dc, r, adDown, if state = CBXS_DISABLED then pal[COLOR_3DLIGHT] else pal[COLOR_GRAYTEXT]);
    end;
    _: result := false;
  end;
end;

function drawButtonPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := true;
  match part of
    BP_PUSHBUTTON: drawPushButtonPart(dc, state, r);
    BP_CHECKBOX: drawCheckBoxPart(dc, state, r);
    BP_RADIOBUTTON: drawRadioPart(dc, state, r);
    BP_GROUPBOX: begin
      SelectObject(dc, GetStockObject(DC_PEN));
      SelectObject(dc, GetStockObject(NULL_BRUSH));
      SetDCPenColor(dc, pal[COLOR_3DLIGHT]);
      Windows.RoundRect(dc, r.Left, r.Top, r.Right-1, r.Bottom-1, 4, 4);
    end;
    _: result := false;
  end;
end;

function drawHeaderPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := true;
  match part of
    0: begin
      fillRect(dc, r, pal[COLOR_BTNFACE]);
      drawLine(dc, r.Left, r.Bottom-1, r.Right, r.Bottom-1, pal[COLOR_3DLIGHT]);
    end;
    HP_HEADERITEM, HP_HEADERITEMLEFT, HP_HEADERITEMRIGHT: begin
      var fill := pal[COLOR_BTNFACE];
      if state in [HIS_HOT, HIS_SORTEDHOT, HIS_ICONHOT, HIS_ICONSORTEDHOT] then fill := pal[COLOR_HOVER]
      else if state in [HIS_PRESSED, HIS_SORTEDPRESSED, HIS_ICONPRESSED, HIS_ICONSORTEDPRESSED] then fill := pal[COLOR_BTNSHADOW];
      fillRect(dc, r, fill);
      drawLine(dc, r.Right-1, r.Top, r.Right-1, r.Bottom, pal[COLOR_BTNHIGHLIGHT]);
      drawLine(dc, r.Left, r.Bottom-1, r.Right, r.Bottom-1, pal[COLOR_3DLIGHT]);
    end;
    HP_HEADERSORTARROW: drawArrow(dc, r, if state = HSAS_SORTEDUP then adUp else adDown, pal[COLOR_GRAYTEXT]);
    HP_HEADERDROPDOWN, HP_HEADERDROPDOWNFILTER, HP_HEADEROVERFLOW: drawArrow(dc, r, adDown, pal[COLOR_GRAYTEXT]);
    _: result := false;
  end;
end;

function drawToolBarPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := true;
  match part of
    TP_BUTTON, TP_DROPDOWNBUTTON, TP_SPLITBUTTON, TP_SPLITBUTTONDROPDOWN: begin
      if state in [TS_HOT, TS_NEARHOT, TS_OTHERSIDEHOT] then begin
        fillRect(dc, r, pal[COLOR_HOVER]);
        frameRect(dc, r, pal[COLOR_BTNHIGHLIGHT]);
      end else if state in [TS_PRESSED, TS_CHECKED, TS_HOTCHECKED] then begin
        fillRect(dc, r, pal[COLOR_BTNSHADOW]);
        frameRect(dc, r, if state = TS_HOTCHECKED then pal[COLOR_HOTLIGHT] else pal[COLOR_BTNHIGHLIGHT]);
      end;
      if part = TP_SPLITBUTTONDROPDOWN then drawArrow(dc, r, adDown, if state = TS_DISABLED then pal[COLOR_GRAYTEXT] else pal[COLOR_BTNTEXT]);
    end;
    TP_DROPDOWNBUTTONGLYPH: drawArrow(dc, r, adDown, if state = TS_DISABLED then pal[COLOR_GRAYTEXT] else pal[COLOR_BTNTEXT]);
    TP_SEPARATOR: begin
      var x := (r.Left+r.Right) div 2;
      drawLine(dc, x, r.Top+2, x, r.Bottom-2, pal[COLOR_BTNHIGHLIGHT]);
    end;
    TP_SEPARATORVERT: begin
      var y := (r.Top+r.Bottom) div 2;
      drawLine(dc, r.Left+2, y, r.Right-2, y, pal[COLOR_BTNHIGHLIGHT]);
    end;
    _: result := false;
  end;
end;

function drawEditPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := part in [EP_EDITBORDER_NOSCROLL, EP_EDITBORDER_HSCROLL, EP_EDITBORDER_VSCROLL, EP_EDITBORDER_HVSCROLL];
  if not result then exit;
  var frame := pal[COLOR_3DLIGHT];
  if state = EPSN_FOCUSED then frame := pal[COLOR_HOTLIGHT] else if state = EPSN_HOT then frame := pal[COLOR_BTNHIGHLIGHT];
  frameRect(dc, r, frame);
  var inner := r;
  InflateRect(inner, -1, -1);
  frameRect(dc, inner, if state = EPSN_DISABLED then pal[COLOR_BTNFACE] else pal[COLOR_WINDOW]);
end;

function drawProgressPart(dc: HDC; part: integer; const r: TRect): boolean;
begin
  result := true;
  match part of
    PP_BAR, PP_BARVERT, PP_TRANSPARENTBAR, PP_TRANSPARENTBARVERT: begin
      fillRect(dc, r, pal[COLOR_WINDOW]);
      frameRect(dc, r, pal[COLOR_3DLIGHT]);
    end;
    PP_FILL, PP_FILLVERT, PP_CHUNK, PP_CHUNKVERT: fillRect(dc, r, pal[COLOR_HIGHLIGHT]);
    // the glow sliding over the fill stays off
    PP_MOVEOVERLAY, PP_MOVEOVERLAYVERT: ;
    _: result := false;
  end;
end;

// selection and hover rows of LCL tree views; glyphs come from the dark theme
function drawTreeViewPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := part = TVP_TREEITEM;
  if not result then exit;
  match state of
    TREIS_SELECTED, TREIS_HOTSELECTED: fillRect(dc, r, pal[COLOR_HIGHLIGHT]);
    TREIS_SELECTEDNOTFOCUS: fillRect(dc, r, pal[COLOR_BTNHIGHLIGHT]);
    TREIS_HOT: fillRect(dc, r, pal[COLOR_3DLIGHT]);
    _: result := false;
  end;
end;

function drawTrackBarPart(dc: HDC; part, state: integer; const r: TRect): boolean;
begin
  result := true;
  match part of
    TKP_TRACK, TKP_TRACKVERT: begin
      fillRect(dc, r, pal[COLOR_WINDOW]);
      frameRect(dc, r, pal[COLOR_3DLIGHT]);
    end;
    TKP_THUMB, TKP_THUMBBOTTOM, TKP_THUMBTOP, TKP_THUMBVERT, TKP_THUMBLEFT, TKP_THUMBRIGHT: begin
      var color := pal[COLOR_BTNHIGHLIGHT];
      if state in [TUS_HOT, TUS_PRESSED] then color := pal[COLOR_GRAYTEXT] else if state = TUS_DISABLED then color := pal[COLOR_3DLIGHT];
      SelectObject(dc, GetStockObject(DC_PEN));
      SelectObject(dc, GetStockObject(DC_BRUSH));
      SetDCPenColor(dc, color);
      SetDCBrushColor(dc, color);
      Windows.RoundRect(dc, r.Left, r.Top, r.Right, r.Bottom, 4, 4);
    end;
    TKP_TICS, TKP_TICSVERT: fillRect(dc, r, pal[COLOR_GRAYTEXT]);
    _: result := false;
  end;
end;

function drawToolTipPart(dc: HDC; part: integer; const r: TRect): boolean;
begin
  result := part in [TTP_STANDARD, TTP_STANDARDTITLE];
  if not result then exit;
  fillRect(dc, r, pal[COLOR_INFOBK]);
  frameRect(dc, r, pal[COLOR_BTNHIGHLIGHT]); // tooltips float over other windows and keep a visible edge
end;

// -- uxtheme hooks --------------------------------------------------------

function hookOpenThemeData(wnd: HWND; classList: LPCWSTR): HTHEME; stdcall;
begin
  var kind := classOfName(classList);
  var own := active and ours(wnd);
  result := 0;
  // a window styled with SetWindowTheme resolves the dark class by itself
  if own and (wnd = 0) and darkLook then result := origOpenThemeData(wnd, PWideChar(darkClassList(kind, classList)));
  if result = 0 then result := origOpenThemeData(wnd, classList);
  remember(result, kind, own);
end;

function hookOpenThemeDataEx(wnd: HWND; classList: LPCWSTR; flags: DWORD): HTHEME; stdcall;
begin
  var kind := classOfName(classList);
  var own := active and ours(wnd);
  result := 0;
  if own and (wnd = 0) and darkLook then result := origOpenThemeDataEx(wnd, PWideChar(darkClassList(kind, classList)), flags);
  if result = 0 then result := origOpenThemeDataEx(wnd, classList, flags);
  remember(result, kind, own);
end;

function hookOpenThemeDataForDpi(wnd: HWND; classList: LPCWSTR; dpi: UINT): HTHEME; stdcall;
begin
  var kind := classOfName(classList);
  var own := active and ours(wnd);
  result := 0;
  if own and (wnd = 0) and darkLook then result := origOpenThemeDataForDpi(wnd, PWideChar(darkClassList(kind, classList)), dpi);
  if result = 0 then result := origOpenThemeDataForDpi(wnd, classList, dpi);
  remember(result, kind, own);
end;

function hookCloseThemeData(theme: HTHEME): HRESULT; stdcall;
begin
  forget(theme);
  result := origCloseThemeData(theme);
end;

// a window outside the IDE, like a common dialog, shares the theme handles
// but paints natively; menus and tool tips are popups of the IDE itself
function foreignCanvas(dc: HDC; kind: TThemeClass): boolean;
begin
  if kind in [tcMenu, tcToolTip] then exit(false);
  var wnd := paintedWindow(dc);
  result := (wnd <> 0) and not isTagged(wnd);
end;

// a system color request carries no DC; it is for the stock look while a
// designed window is inside its paint message
function paintingForeign: boolean;
begin
  result := foreignCanvas(0, tcOther);
end;

// paints the part with the palette; false leaves it to uxtheme
function paintThemePart(theme: HTHEME; dc: HDC; part, state: integer; const rect: TRect): boolean;
begin
  var kind: TThemeClass;
  if not kindOf(theme, kind) or foreignCanvas(dc, kind) then exit(false);
  var saved := SaveDC(dc);
  defer RestoreDC(dc, saved);
  var handled := true;
  match kind of
    tcMenu: drawMenuPart(dc, part, state, rect);
    tcTab: handled := drawTabPart(dc, part, state, rect);
    tcButton: handled := drawButtonPart(dc, part, state, rect);
    tcComboBox: handled := drawComboBoxPart(dc, part, state, rect);
    tcHeader: handled := drawHeaderPart(dc, part, state, rect);
    tcToolBar: handled := drawToolBarPart(dc, part, state, rect);
    tcEdit: handled := drawEditPart(dc, part, state, rect);
    tcProgress: handled := drawProgressPart(dc, part, rect);
    tcToolTip: handled := drawToolTipPart(dc, part, rect);
    tcTreeView: handled := drawTreeViewPart(dc, part, state, rect);
    tcTrackBar: handled := drawTrackBarPart(dc, part, state, rect);
    tcRebar: fillRect(dc, rect, pal[COLOR_BTNFACE]);
    _: handled := false;
  end;
  result := handled;
end;

function hookDrawThemeBackground(theme: HTHEME; dc: HDC; part, state: integer; const rect: TRect; clip: PRect): HRESULT; stdcall;
begin
  if paintThemePart(theme, dc, part, state, rect) then exit(S_OK);
  result := origDrawThemeBackground(theme, dc, part, state, rect, clip);
end;


// the palette color of themed text; the edit theme keeps its own colors
function themeTextColor(kind: TThemeClass; part, state: integer): TColor;
begin
  result := pal[COLOR_BTNTEXT];
  match kind of
    tcMenu: result := if menuTextDisabled(part, state) then pal[COLOR_GRAYTEXT] else pal[COLOR_MENUTEXT];
    tcToolTip: result := pal[COLOR_INFOTEXT];
    tcComboBox: result := if ((part = CP_BORDER) and (state = CBB_DISABLED)) or ((part = CP_READONLY) and (state = CBRO_DISABLED)) then pal[COLOR_GRAYTEXT] else pal[COLOR_WINDOWTEXT];
    tcButton: if buttonTextDisabled(part, state) then result := pal[COLOR_GRAYTEXT];
    tcToolBar: if state = TS_DISABLED then result := pal[COLOR_GRAYTEXT];
    // the pages not on top read dimmer
    tcTab: if state in [TIS_NORMAL, TIS_DISABLED] then result := pal[COLOR_GRAYTEXT];
    tcTreeView, tcListView: begin
      // item states share their numbering between the two classes
      result := pal[COLOR_WINDOWTEXT];
      if state in [TREIS_SELECTED, TREIS_HOTSELECTED] then result := pal[COLOR_HIGHLIGHTTEXT]
      else if state = TREIS_DISABLED then result := pal[COLOR_GRAYTEXT];
    end;
  end;
end;

// text of a themed class that takes the palette color on this canvas
function paletteText(theme: HTHEME; dc: HDC; out kind: TThemeClass): boolean;
begin
  result := kindOf(theme, kind) and (kind <> tcEdit) and not foreignCanvas(dc, kind);
end;

// the asterisk of an unsaved page is a strip on the tab already
procedure skipTabMark(kind: TThemeClass; var text: LPCWSTR; var count: integer);
begin
  if (kind <> tcTab) or (count = 0) or (text^ <> '*') then exit;
  inc(text);
  if count > 0 then dec(count);
end;

function hookDrawThemeText(theme: HTHEME; dc: HDC; part, state: integer; text: LPCWSTR; count: integer; flags, flags2: DWORD; const rect: TRect): HRESULT; stdcall;
begin
  var kind: TThemeClass;
  if not paletteText(theme, dc, kind) then exit(origDrawThemeText(theme, dc, part, state, text, count, flags, flags2, rect));
  skipTabMark(kind, text, count);
  var oldColor := SetTextColor(dc, themeTextColor(kind, part, state));
  var oldMode := SetBkMode(dc, TRANSPARENT);
  var r := rect;
  if (kind = tcTab) and (part in [TABP_TABITEM..TABP_TOPTABITEMBOTHEDGE]) then centerTabText(dc, r, flags);
  DrawTextExW(dc, LPWSTR(text), count, @r, flags, nil);
  SetBkMode(dc, oldMode);
  SetTextColor(dc, oldColor);
  result := S_OK;
end;

// the composited variant keeps its options, only the color is forced
function hookDrawThemeTextEx(theme: HTHEME; dc: HDC; part, state: integer; text: LPCWSTR; count: integer; flags: DWORD; rect: PRect; options: PDTTOPTS): HRESULT; stdcall;
begin
  var kind: TThemeClass;
  if not paletteText(theme, dc, kind) then exit(origDrawThemeTextEx(theme, dc, part, state, text, count, flags, rect, options));
  skipTabMark(kind, text, count);
  var opts := Default(TDTTOpts);
  opts.dwSize := sizeof(opts);
  if options <> nil then opts := options^;
  opts.dwFlags := opts.dwFlags or DTT_TEXTCOLOR;
  opts.crText := COLORREF(themeTextColor(kind, part, state));
  if (kind = tcTab) and (part in [TABP_TABITEM..TABP_TOPTABITEMBOTHEDGE]) and (rect <> nil) then centerTabText(dc, rect^, flags);
  result := origDrawThemeTextEx(theme, dc, part, state, text, count, flags, rect, @opts);
end;

// a control that reads the text color and draws by itself gets the palette one
function hookGetThemeColor(theme: HTHEME; part, state, prop: integer; var color: DWORD): HRESULT; stdcall;
begin
  var kind: TThemeClass;
  if (prop = TMT_TEXTCOLOR) and kindOf(theme, kind) and (kind <> tcEdit) and not paintingForeign then begin
    color := DWORD(themeTextColor(kind, part, state));
    exit(S_OK);
  end;
  result := origGetThemeColor(theme, part, state, prop, color);
end;

function hookDrawThemeEdge(theme: HTHEME; dc: HDC; part, state: integer; const dest: TRect; edge, flags: UINT; content: PRect): HRESULT; stdcall;
begin
  var kind: TThemeClass;
  if not kindOf(theme, kind) or foreignCanvas(dc, kind) then exit(origDrawThemeEdge(theme, dc, part, state, dest, edge, flags, content));
  var r := dest;
  drawEdgeDark(dc, r, edge, flags);
  if ((flags and BF_ADJUST) <> 0) and (content <> nil) then content^ := r;
  result := S_OK;
end;

function hookGetThemeSysColor(theme: HTHEME; colorId: integer): COLORREF; stdcall;
begin
  var kind: TThemeClass;
  if kindOf(theme, kind) and (colorId >= 0) and (colorId <= COLOR_ENDCOLORS) then exit(COLORREF(pal[colorId]));
  result := origGetThemeSysColor(theme, colorId);
end;

function hookGetThemeSysColorBrush(theme: HTHEME; colorId: integer): HBRUSH; stdcall;
begin
  var kind: TThemeClass;
  if kindOf(theme, kind) and (colorId >= 0) and (colorId <= COLOR_ENDCOLORS) then exit(palBrushOf(colorId));
  result := origGetThemeSysColorBrush(theme, colorId);
end;

// -- user32 / gdi32 hooks -------------------------------------------------

// a designed form resolves to the stock colors; the LCL keys its brush and
// pen caches on the resolved color, so each look keeps its own handles
function hookGetSysColor(index: longint): DWORD; stdcall;
begin
  if active and (index >= 0) and (index <= COLOR_ENDCOLORS) and not paintingForeign then exit(COLORREF(pal[index]));
  result := origGetSysColor(index);
end;

function hookGetSysColorBrush(index: longint): HBRUSH; stdcall;
begin
  if active and (index >= 0) and (index <= COLOR_ENDCOLORS) and not paintingForeign then exit(palBrushOf(index));
  result := origGetSysColorBrush(index);
end;

function hookDrawEdge(dc: HDC; var rect: TRect; edge, flags: UINT): BOOL; stdcall;
begin
  var wnd := WindowFromDC(dc);
  if active and ((wnd = 0) or isTagged(wnd)) then exit(drawEdgeDark(dc, rect, edge, flags));
  result := origDrawEdge(dc, rect, edge, flags);
end;

function hookDeleteObject(obj: HGDIOBJ): BOOL; stdcall;
begin
  if (obj <> 0) and isPalBrush(obj) then exit(true);
  result := origDeleteObject(obj);
end;

procedure styleWindow(wnd: HWND; control: TWinControl; themed: boolean); forward;
procedure refreshTabFrame(wnd: HWND; themed: boolean); forward;
procedure subclassWindow(wnd: HWND; control: TWinControl); forward;
procedure pushControlColors(control: TWinControl); forward;

function hookCreateWindowExW(exStyle: DWORD; cls, title: LPCWSTR; style: DWORD; x, y, w, h: longint; parent: HWND; menu: HMENU; inst: HINST; param: LPVOID): HWND; stdcall;
begin
  // the LCL passes its create record; a designed form keeps the stock look
  var control: TWinControl := nil;
  if param <> nil then control := PNCCreateParams(param)^.WinControl;
  var designing := (control <> nil) and (csDesigning in control.ComponentState);
  if designing then inc(foreignCreations) else inc(ownCreations);
  result := origCreateWindowExW(exStyle, cls, title, style, x, y, w, h, parent, menu, inst, param);
  if designing then dec(foreignCreations) else dec(ownCreations);
  if result = 0 then exit;
  if designing then begin
    // the stock look stays; the window only joins the paint stack
    if active then SetPropW(result, PENDING_NAME, HANDLE(1));
    exit;
  end;
  tagWindow(result);
  if not active then exit;
  styleWindow(result, control, true);
  // the LCL still replaces the window procedure after this call returns; a
  // subclass installed now would end up calling the LCL procedure from
  // both ends of the chain, so it waits for the first message sent to the
  // window, which the LCL does only after that replacement
  SetPropW(result, PENDING_NAME, HANDLE(1));
end;

// completes the styling once the LCL has installed its final window procedure
procedure finishWindow(wnd: HWND);
begin
  RemovePropW(wnd, PENDING_NAME);
  var control := GetWin32WindowInfo(wnd)^.WinControl;
  subclassWindow(wnd, control);
  if not isTagged(wnd) then exit;
  if (control <> nil) and control.HandleAllocated then pushControlColors(control);
  // the frame band needs the subclass, which was not there when the window was styled
  if control is TCustomTabControl then refreshTabFrame(wnd, true);
end;

// Windows frames a popup menu with the same gray in every look; the frame
// takes the subtle palette line instead, the system shadow stays
procedure paintMenuFrame(wnd: HWND; dc: HDC);
begin
  var win: TRect;
  GetWindowRect(wnd, win);
  var own := dc = 0;
  if own then dc := GetWindowDC(wnd);
  frameRect(dc, Rect(0, 0, win.Right-win.Left, win.Bottom-win.Top), pal[COLOR_3DLIGHT]);
  if own then ReleaseDC(wnd, dc);
end;

function menuPopupProc(wnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM; id: UINT_PTR; data: DWORD_PTR): LRESULT; stdcall;
begin
  result := DefSubclassProc(wnd, msg, wParam, lParam);
  if not active then exit;
  match msg of
    WM_NCPAINT, WM_PAINT: paintMenuFrame(wnd, 0);
    // the fade-in renders through this one into a bitmap
    WM_PRINT: if (lParam and PRF_NONCLIENT) <> 0 then paintMenuFrame(wnd, HDC(wParam));
  end;
end;

function callWndProcHook(code: longint; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  if code >= 0 then begin
    var wnd := PCWPSTRUCT(lParam)^.hwnd;
    var msg := PCWPSTRUCT(lParam)^.message;
    if GetPropW(wnd, PENDING_NAME) <> 0 then finishWindow(wnd);
    if paintMessage(msg) then pushPaint(wnd);
    if msg = WM_NCCREATE then begin
      var cls := classNameOf(wnd);
      // popup menus are windows of user32; they get their frame subclass at birth
      if cls = '#32768' then SetWindowSubclass(wnd, @menuPopupProc, SUB_MENUPOPUP, 0)
      // the arrows a tab control adds once its tabs overflow are made by
      // comctl32 itself, out of reach of the import hook on the executable
      else if (cls = 'msctls_updown32') and (ownCreations = 0) and (foreignCreations = 0) then subclassWindow(wnd, nil);
    end;
  end;
  result := CallNextHookEx(callWndHook, code, wParam, lParam);
end;

function callWndProcRetHook(code: longint; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  if code >= 0 then popPaint(paintMessage(PCWPRETSTRUCT(lParam)^.message));
  result := CallNextHookEx(callWndRetHook, code, wParam, lParam);
end;

// scroll position changes redraw the bar natively; paint over it again
procedure afterScrollChange(wnd: HWND);
begin
  if active and isTagged(wnd) then paintScrollBars(wnd);
end;

function hookSetScrollInfo(wnd: HWND; bar: longint; const info: SCROLLINFO; redraw: BOOL): longint; stdcall;
begin
  result := origSetScrollInfo(wnd, bar, info, redraw);
  if redraw then afterScrollChange(wnd);
end;

function hookSetScrollPos(wnd: HWND; bar, pos: longint; redraw: BOOL): longint; stdcall;
begin
  result := origSetScrollPos(wnd, bar, pos, redraw);
  if redraw then afterScrollChange(wnd);
end;

function hookSetScrollRange(wnd: HWND; bar, minPos, maxPos: longint; redraw: BOOL): BOOL; stdcall;
begin
  result := origSetScrollRange(wnd, bar, minPos, maxPos, redraw);
  if redraw then afterScrollChange(wnd);
end;

function hookShowScrollBar(wnd: HWND; bar: longint; show: BOOL): BOOL; stdcall;
begin
  result := origShowScrollBar(wnd, bar, show);
  afterScrollChange(wnd);
end;

function hookEnableScrollBar(wnd: HWND; flags, arrows: UINT): BOOL; stdcall;
begin
  result := origEnableScrollBar(wnd, flags, arrows);
  afterScrollChange(wnd);
end;

// message boxes go through the LCL dialog instead of the native task dialog;
// a config with radio buttons, common buttons, a footer, a verification
// line, expandable text or a callback fails instead, so the LCL falls back
// to its own emulated task dialog
function hookTaskDialogIndirect(const config: PTASKDIALOGCONFIG; button, radioButton: PInteger; verify: PBOOL): HRESULT; stdcall;
begin
  if (not active) or (config = nil) or (config^.cbSize <> sizeof(TASKDIALOGCONFIG)) then exit(origTaskDialogIndirect(config, button, radioButton, verify));
  if (config^.cRadioButtons <> 0) or (config^.dwCommonButtons <> 0) or (config^.pszFooter <> nil) or (config^.pszVerificationText <> nil) or (config^.pszExpandedInformation <> nil) or (config^.pfCallback <> nil) then exit(E_NOTIMPL);
  var kind := idDialogInfo;
  if (config^.dwFlags and TDF_USE_HICON_MAIN) <> 0 then kind := idDialogConfirm
  else if config^.pszMainIcon = TD_WARNING_ICON then kind := idDialogWarning
  else if config^.pszMainIcon = TD_ERROR_ICON then kind := idDialogError
  else if config^.pszMainIcon = TD_SHIELD_ICON then kind := idDialogShield
  else if config^.pszMainIcon = TD_QUESTION_ICON then kind := idDialogConfirm;
  var buttons := autofree TDialogButtons.Create(TDialogButton);
  for var i := 0 to integer(config^.cButtons)-1 do begin
    var src := config^.pButtons+i;
    var item := buttons.Add;
    item.Caption := UTF8Encode(UnicodeString(src^.pszButtonText));
    item.ModalResult := src^.nButtonID+BUTTON_ID_BASE;
    item.Default := src^.nButtonID = config^.nDefaultButton;
  end;
  if buttons.Count = 0 then begin
    var item := buttons.Add;
    item.Caption := 'OK';
    item.ModalResult := IDOK+BUTTON_ID_BASE;
    item.Default := true;
  end;
  var text := UTF8Encode(UnicodeString(config^.pszContent));
  if text = '' then text := UTF8Encode(UnicodeString(config^.pszMainInstruction));
  var chosen := DefaultQuestionDialog(UTF8Encode(UnicodeString(config^.pszWindowTitle)), text, kind, buttons, 0);
  if chosen >= BUTTON_ID_BASE then chosen -= BUTTON_ID_BASE;
  if button <> nil then button^ := chosen;
  if radioButton <> nil then radioButton^ := 0;
  if verify <> nil then verify^ := false;
  result := S_OK;
end;

// -- window subclasses ----------------------------------------------------

procedure setMenuBackground(menu: HMENU; dark: boolean);
begin
  var info := Default(MENUINFO);
  info.cbSize := sizeof(info);
  info.fMask := MIM_BACKGROUND or MIM_APPLYTOSUBMENUS;
  if dark then info.hbrBack := menuBrush; // 0 restores the default
  SetMenuInfo(menu, @info);
end;

// the band between the menu bar and the client area: the pixel row Windows
// leaves under the menu, then the rule and its gap reserved in WM_NCCALCSIZE
procedure paintMenuBand(wnd: HWND);
begin
  var client: TRect;
  var win: TRect;
  GetClientRect(wnd, @client);
  MapWindowPoints(wnd, 0, @client, 2);
  GetWindowRect(wnd, @win);
  var left := client.Left-win.Left;
  var right := client.Right-win.Left;
  var top := client.Top-win.Top-MENU_BAND;
  var dc := GetWindowDC(wnd);
  fillRect(dc, Rect(left, top-1, right, top), pal[COLOR_MENU]);
  fillRect(dc, Rect(left, top, right, top+MENU_BAND_LINE), pal[COLOR_BTNHIGHLIGHT]);
  fillRect(dc, Rect(left, top+MENU_BAND_LINE, right, top+MENU_BAND), pal[COLOR_BTNFACE]);
  ReleaseDC(wnd, dc);
end;

// native controls keep the real system colors until the LCL sends theirs,
// which it only does for an explicitly assigned color. The font goes only
// to list views, where it carries the text color; a combo box answers
// WM_SETFONT by reloading its edit with everything selected
procedure pushControlColors(control: TWinControl);
begin
  TWSWinControlClass(control.WidgetSetClass).SetColor(control);
  if control is TCustomListView then TWSWinControlClass(control.WidgetSetClass).SetFont(control, control.Font);
end;

function topLevelProc(wnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM; id: UINT_PTR; data: DWORD_PTR): LRESULT; stdcall;
begin
  var painting := paintMessage(msg);
  if painting then pushPaint(wnd);
  defer popPaint(painting);
  match msg of
    WM_NCPAINT, WM_NCACTIVATE: begin
      result := DefSubclassProc(wnd, msg, wParam, lParam);
      if active and (GetMenu(wnd) <> 0) then paintMenuBand(wnd);
    end;
    WM_NCCALCSIZE: begin
      result := DefSubclassProc(wnd, msg, wParam, lParam);
      // reserve the band under the menu bar; the client area starts below it
      if active and (GetMenu(wnd) <> 0) then
        if wParam <> 0 then inc(PNCCalcSizeParams(lParam)^.rgrc[0].Top, MENU_BAND) else inc(PRect(lParam)^.Top, MENU_BAND);
    end;
    WM_INITMENUPOPUP: begin
      // popup menus opened from this window follow the current look
      setMenuBackground(HMENU(wParam), active);
      result := DefSubclassProc(wnd, msg, wParam, lParam);
    end;
    WM_SETTINGCHANGE: begin
      result := DefSubclassProc(wnd, msg, wParam, lParam);
      if (lParam <> 0) and (lstrcmpiW(PWideChar(lParam), 'ImmersiveColorSet') = 0) and Assigned(onSystemThemeChange) then onSystemThemeChange;
    end;
    _: result := DefSubclassProc(wnd, msg, wParam, lParam);
  end;
end;

// the inner pixel of the edge takes the control's own background so the
// border does not read as a double frame
function innerEdgeColor(wnd: HWND): TColor;
begin
  result := pal[COLOR_WINDOW];
  var control := GetWin32WindowInfo(wnd)^.WinControl;
  if control = nil then exit;
  var color := control.Color;
  if color = clDefault then color := control.GetDefaultColor(dctBrush);
  result := ColorToRGB(color);
end;

// repaints the sunken client edge of bordered controls
procedure paintClientEdge(wnd: HWND);
begin
  if (GetWindowLongPtrW(wnd, GWL_EXSTYLE) and WS_EX_CLIENTEDGE) = 0 then exit;
  var win: TRect;
  GetWindowRect(wnd, @win);
  OffsetRect(win, -win.Left, -win.Top);
  var inner := innerEdgeColor(wnd);
  var dc := GetWindowDC(wnd);
  frameRect(dc, win, pal[COLOR_3DLIGHT]);
  InflateRect(win, -1, -1);
  frameRect(dc, win, inner);
  ReleaseDC(wnd, dc);
  SetPropW(wnd, EDGE_NAME, HANDLE(inner+1));
end;

// a new control color repaints the client area only, the edge keeps the old one
procedure refreshClientEdge(wnd: HWND);
begin
  if (GetWindowLongPtrW(wnd, GWL_EXSTYLE) and WS_EX_CLIENTEDGE) = 0 then exit;
  if GetPropW(wnd, EDGE_NAME) <> HANDLE(innerEdgeColor(wnd)+1) then paintClientEdge(wnd);
end;

const
  SCROLL_TIMER = $5A2;
  REPEAT_DELAY = 300; // ms before a held arrow or track click repeats
  REPEAT_RATE = 50;

function scrollBarInfo(wnd: HWND; bar: integer; out info: TScrollBarInfo): boolean;
begin
  info := Default(TScrollBarInfo);
  info.cbSize := sizeof(info);
  var id := OBJID_CLIENT;
  if bar = SB_VERT then id := OBJID_VSCROLL else if bar = SB_HORZ then id := OBJID_HSCROLL;
  result := GetScrollBarInfo(wnd, id, info) and ((info.rgstate[0] and STATE_SYSTEM_INVISIBLE) = 0);
end;

// the highest position the thumb can take
function scrollTop(const si: SCROLLINFO): integer;
begin
  result := si.nMax;
  if si.nPage > 0 then result := result-integer(si.nPage)+1;
  if result < si.nMin then result := si.nMin;
end;

// the part of a bar under a screen point
function barPartAt(const info: TScrollBarInfo; vertical: boolean; const pt: TPoint): TBarPart;
begin
  result := bpNone;
  if not PtInRect(info.rcScrollBar, pt) then exit;
  var along := if vertical then pt.Y-info.rcScrollBar.Top else pt.X-info.rcScrollBar.Left;
  var len := if vertical then info.rcScrollBar.Height else info.rcScrollBar.Width;
  if along < info.dxyLineButton then exit(bpLineUp);
  if along >= len-info.dxyLineButton then exit(bpLineDown);
  if along < info.xyThumbTop then exit(bpPageUp);
  if along >= info.xyThumbBottom then exit(bpPageDown);
  result := bpThumb;
end;

// scroll notifications go to the window itself, those of a scroll bar
// control to its parent
procedure sendScroll(code, pos: integer);
begin
  var target := drag.wnd;
  var lp: LPARAM := 0;
  if drag.bar = SB_CTL then begin
    target := GetParent(drag.wnd);
    lp := LPARAM(drag.wnd);
  end;
  var msg: UINT := if drag.vertical then WM_VSCROLL else WM_HSCROLL;
  SendMessage(target, msg, WPARAM(code or ((pos and $FFFF) shl 16)), lp);
end;

// one line or page step of a held arrow or track press; paging stops once
// the thumb reaches the mouse, as the native bar does
procedure stepScroll;
begin
  var pt: TPoint;
  var info: TScrollBarInfo;
  GetCursorPos(pt);
  if (drag.part in [bpPageUp, bpPageDown]) and scrollBarInfo(drag.wnd, drag.bar, info) and (barPartAt(info, drag.vertical, pt) <> drag.part) then exit;
  match drag.part of
    bpLineUp: sendScroll(SB_LINEUP, 0);
    bpLineDown: sendScroll(SB_LINEDOWN, 0);
    bpPageUp: sendScroll(SB_PAGEUP, 0);
    bpPageDown: sendScroll(SB_PAGEDOWN, 0);
  end;
  paintScrollBars(drag.wnd);
end;

// takes over a press on a bar; false when the point misses the bar
function beginScroll(wnd: HWND; bar: integer; const pt: TPoint): boolean;
begin
  result := false;
  var info: TScrollBarInfo;
  if not scrollBarInfo(wnd, bar, info) then exit;
  var vertical := bar = SB_VERT;
  if bar = SB_CTL then vertical := (GetWindowLongPtrW(wnd, GWL_STYLE) and SBS_VERT) <> 0;
  var part := barPartAt(info, vertical, pt);
  if part = bpNone then exit;
  result := true;
  if (info.rgstate[ord(part)] and STATE_SYSTEM_UNAVAILABLE) <> 0 then exit;
  drag.wnd := wnd;
  drag.bar := bar;
  drag.part := part;
  drag.vertical := vertical;
  SetCapture(wnd);
  if part <> bpThumb then begin
    stepScroll;
    SetTimer(wnd, SCROLL_TIMER, REPEAT_DELAY, nil);
    exit;
  end;
  var si := Default(SCROLLINFO);
  si.cbSize := sizeof(si);
  si.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  GetScrollInfo(wnd, bar, si);
  var track := if vertical then info.rcScrollBar.Height else info.rcScrollBar.Width;
  track := track-2*info.dxyLineButton-(info.xyThumbBottom-info.xyThumbTop);
  var span := scrollTop(si)-si.nMin;
  drag.startMouse := if vertical then pt.Y else pt.X;
  drag.startPos := si.nPos;
  drag.unitsPerPixel := if (track > 0) and (span > 0) then span/track else 0;
end;

procedure moveThumbDrag(const pt: TPoint; final: boolean);
begin
  var mouse := if drag.vertical then pt.Y else pt.X;
  var si := Default(SCROLLINFO);
  si.cbSize := sizeof(si);
  si.fMask := SIF_RANGE or SIF_PAGE;
  GetScrollInfo(drag.wnd, drag.bar, si);
  var pos := EnsureRange(drag.startPos+round((mouse-drag.startMouse)*drag.unitsPerPixel), si.nMin, scrollTop(si));
  // the position is stored first: the LCL reads the full 32-bit value back
  // from the bar, the low word in the message only seeds it
  si.fMask := SIF_POS;
  si.nPos := pos;
  origSetScrollInfo(drag.wnd, drag.bar, si, false);
  sendScroll(SB_THUMBPOSITION, pos);
  if final then sendScroll(SB_ENDSCROLL, 0);
  paintScrollBars(drag.wnd);
end;

procedure endScroll(const pt: TPoint);
begin
  var wnd := drag.wnd;
  KillTimer(wnd, SCROLL_TIMER);
  if drag.part = bpThumb then moveThumbDrag(pt, true) else sendScroll(SB_ENDSCROLL, 0);
  drag.wnd := 0;
  ReleaseCapture;
  paintScrollBars(wnd);
end;

function screenPoint(wnd: HWND; lParam: LPARAM; client: boolean): TPoint;
begin
  result := Point(smallint(lParam and $FFFF), smallint((lParam shr 16) and $FFFF));
  if client then ClientToScreen(wnd, result);
end;

// records the bar part under the mouse and repaints when it changed; asks
// for the leave message so the highlight goes away again
procedure trackHover(wnd: HWND; bar: integer; const pt: TPoint; nonClient: boolean);
begin
  var part := 0;
  var info: TScrollBarInfo;
  if scrollBarInfo(wnd, bar, info) then begin
    var vertical := bar = SB_VERT;
    if bar = SB_CTL then vertical := (GetWindowLongPtrW(wnd, GWL_STYLE) and SBS_VERT) <> 0;
    part := ord(barPartAt(info, vertical, pt));
  end;
  if (hover.wnd = wnd) and (hover.bar = bar) and (hover.part = part) then exit;
  hover.wnd := wnd;
  hover.bar := bar;
  hover.part := part;
  var track := Default(TTrackMouseEvent);
  track.cbSize := sizeof(track);
  track.dwFlags := TME_LEAVE;
  if nonClient then track.dwFlags := track.dwFlags or TME_NONCLIENT;
  track.hwndTrack := wnd;
  startMouseTracking(track);
  paintScrollBars(wnd);
end;

procedure clearHover(wnd: HWND);
begin
  if hover.wnd <> wnd then exit;
  hover.wnd := 0;
  hover.part := 0;
  paintScrollBars(wnd);
end;

// child windows: client edge and scroll bars painted over after the native
// pass; the messages listed are the ones after which Windows redraws a bar
function chromeProc(wnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM; id: UINT_PTR; data: DWORD_PTR): LRESULT; stdcall;
begin
  var painting := paintMessage(msg);
  if painting then pushPaint(wnd);
  defer popPaint(painting);
  if active then begin
    var scrollControl := classNameOf(wnd) = 'ScrollBar';
    match msg of
      WM_NCLBUTTONDOWN: if ((wParam = HTVSCROLL) or (wParam = HTHSCROLL)) and beginScroll(wnd, if wParam = HTVSCROLL then SB_VERT else SB_HORZ, screenPoint(wnd, lParam, false)) then exit(0);
      WM_LBUTTONDOWN: if scrollControl and beginScroll(wnd, SB_CTL, screenPoint(wnd, lParam, true)) then exit(0);
      WM_MOUSEMOVE: begin
        if drag.wnd = wnd then begin
          if drag.part = bpThumb then moveThumbDrag(screenPoint(wnd, lParam, true), false);
          exit(0);
        end;
        // the native hot tracking would animate over the painted bar
        if scrollControl then begin
          trackHover(wnd, SB_CTL, screenPoint(wnd, lParam, true), false);
          exit(0);
        end;
      end;
      WM_LBUTTONUP: if drag.wnd = wnd then begin
        endScroll(screenPoint(wnd, lParam, true));
        exit(0);
      end;
      WM_TIMER: if (wParam = SCROLL_TIMER) and (drag.wnd = wnd) then begin
        SetTimer(wnd, SCROLL_TIMER, REPEAT_RATE, nil);
        stepScroll;
        exit(0);
      end;
      WM_CAPTURECHANGED: if drag.wnd = wnd then begin
        KillTimer(wnd, SCROLL_TIMER);
        drag.wnd := 0;
      end;
      WM_NCMOUSEMOVE: begin
        if (wParam = HTVSCROLL) or (wParam = HTHSCROLL) then begin
          if drag.wnd = 0 then trackHover(wnd, if wParam = HTVSCROLL then SB_VERT else SB_HORZ, screenPoint(wnd, lParam, false), true);
          exit(0);
        end;
        clearHover(wnd);
      end;
      WM_NCMOUSELEAVE, WM_MOUSELEAVE: if scrollControl or ((GetWindowLongPtrW(wnd, GWL_STYLE) and (WS_VSCROLL or WS_HSCROLL)) <> 0) then begin
        clearHover(wnd);
        exit(0);
      end;
      // the edit and the list inside a combo box are not LCL controls, so the
      // LCL answers their color requests with the stock brush
      WM_CTLCOLOREDIT, WM_CTLCOLORLISTBOX, WM_CTLCOLORSTATIC: if GetWin32WindowInfo(wnd)^.WinControl is TCustomComboBox then begin
        SetTextColor(HDC(wParam), pal[COLOR_WINDOWTEXT]);
        SetBkColor(HDC(wParam), pal[COLOR_WINDOW]);
        exit(LRESULT(palBrushOf(COLOR_WINDOW)));
      end;
    end;
  end;
  result := DefSubclassProc(wnd, msg, wParam, lParam);
  if not active then exit;
  match msg of
    WM_NCPAINT: begin
      paintClientEdge(wnd);
      paintScrollBars(wnd);
    end;
    WM_VSCROLL, WM_HSCROLL, WM_NCMOUSEMOVE, WM_NCMOUSELEAVE, WM_NCLBUTTONDOWN, WM_NCLBUTTONUP, WM_SIZE: paintScrollBars(wnd);
    WM_PAINT: begin
      refreshClientEdge(wnd);
      if classNameOf(wnd) = 'ScrollBar' then paintScrollBars(wnd);
    end;
    // stand-alone scroll bar controls paint in their client area
    WM_MOUSEMOVE, WM_MOUSELEAVE, WM_LBUTTONDOWN, WM_LBUTTONUP, SBM_SETSCROLLINFO, SBM_SETPOS, SBM_SETRANGE, SBM_ENABLE_ARROWS: if classNameOf(wnd) = 'ScrollBar' then paintScrollBars(wnd);
  end;
end;

function tabsAtBottom(wnd: HWND): boolean;
begin
  result := (GetWindowLongPtrW(wnd, GWL_STYLE) and TCS_BOTTOM) <> 0;
end;

// the band between the tabs and the edge of the control is non-client area
procedure paintTabBand(wnd: HWND);
begin
  var win: TRect;
  GetWindowRect(wnd, win);
  var band := Rect(0, 0, win.Right-win.Left, TAB_BAND);
  if tabsAtBottom(wnd) then band := Rect(0, win.Bottom-win.Top-TAB_BAND, win.Right-win.Left, win.Bottom-win.Top);
  var dc := GetWindowDC(wnd);
  fillRect(dc, band, pal[COLOR_BTNFACE]);
  ReleaseDC(wnd, dc);
end;

// the tab height for the padded text and the strip above it
function tabHeightFor(wnd: HWND): integer;
begin
  var dc := GetDC(wnd);
  var old := SelectObject(dc, HGDIOBJ(SendMessage(wnd, WM_GETFONT, 0, 0)));
  var tm: TTextMetricW;
  GetTextMetricsW(dc, @tm);
  SelectObject(dc, old);
  ReleaseDC(wnd, dc);
  result := tm.tmHeight+2*TAB_PAD_Y+2;
end;

// the page area of tab controls: no room reserved for the pane border, so
// the pages meet the tabs and the neighbours directly; a band stays free
// above the tabs and the tabs take the padded height
function tabProc(wnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM; id: UINT_PTR; data: DWORD_PTR): LRESULT; stdcall;
begin
  var sideways := (GetWindowLongPtrW(wnd, GWL_STYLE) and TCS_VERTICAL) <> 0;
  match msg of
    WM_NCCALCSIZE: begin
      result := DefSubclassProc(wnd, msg, wParam, lParam);
      // the first rectangle of either parameter form is the one to shrink
      if active and not sideways then if tabsAtBottom(wnd) then dec(PRect(lParam)^.Bottom, TAB_BAND) else inc(PRect(lParam)^.Top, TAB_BAND);
      exit;
    end;
    WM_NCPAINT: begin
      result := DefSubclassProc(wnd, msg, wParam, lParam);
      if active and not sideways then paintTabBand(wnd);
      exit;
    end;
    // the default height asked by the LCL becomes the padded one
    TCM_SETITEMSIZE: if active and (HiWord(DWORD(lParam)) = 0) then lParam := MakeLong(LoWord(DWORD(lParam)), tabHeightFor(wnd));
  end;
  result := DefSubclassProc(wnd, msg, wParam, lParam);
  if (msg <> TCM_ADJUSTRECT) or (wParam <> 0) or (not active) or (lParam = 0) then exit;
  var client: TRect;
  GetClientRect(wnd, @client);
  var r := PRect(lParam);
  // the side holding the tabs keeps its big inset minus the pane border, the
  // three others drop the border entirely
  if r^.Top-client.Top > 6 then dec(r^.Top, 2) else r^.Top := client.Top;
  if client.Bottom-r^.Bottom > 6 then inc(r^.Bottom, 2) else r^.Bottom := client.Bottom;
  if r^.Left-client.Left > 6 then dec(r^.Left, 2) else r^.Left := client.Left;
  if client.Right-r^.Right > 6 then inc(r^.Right, 2) else r^.Right := client.Right;
end;

procedure paintStatusBar(wnd: HWND; bar: TStatusBar);
const
  ALIGN_FLAGS: array[TAlignment] of UINT = (DT_LEFT, DT_RIGHT, DT_CENTER);

  procedure drawText(dc: HDC; const cell: TRect; const text: string; alignment: TAlignment);
  begin
    var r := cell;
    InflateRect(r, -3, 0);
    var wide := UTF8Decode(text);
    DrawTextExW(dc, PWideChar(wide), length(wide), @r, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS or ALIGN_FLAGS[alignment], nil);
  end;

begin
  var ps: TPaintStruct;
  var dc := BeginPaint(wnd, @ps);
  var client: TRect;
  GetClientRect(wnd, @client);
  fillRect(dc, client, pal[COLOR_BTNFACE]);
  drawLine(dc, client.Left, client.Top, client.Right, client.Top, pal[COLOR_3DLIGHT]);
  var oldFont := SelectObject(dc, HGDIOBJ(SendMessage(wnd, WM_GETFONT, 0, 0)));
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, pal[COLOR_BTNTEXT]);
  if bar.SimplePanel then drawText(dc, client, bar.SimpleText, taLeftJustify)
  else begin
    var x := client.Left;
    for var i := 0 to bar.Panels.Count-1 do begin
      var panel := bar.Panels[i];
      var last := i = bar.Panels.Count-1;
      // a collapsed panel is hidden; the last one takes the remaining width
      if (panel.Width <= 0) and not last then continue;
      var cell := Rect(x, client.Top, x+panel.Width, client.Bottom);
      if last then cell.Right := client.Right;
      if panel.Style = psOwnerDraw then begin
        if Assigned(bar.OnDrawPanel) then begin
          // the LCL canvas leaves its own font, colors and opaque text mode in the DC
          var saved := SaveDC(dc);
          bar.Canvas.Handle := dc;
          bar.OnDrawPanel(bar, panel, cell);
          bar.Canvas.Handle := 0;
          RestoreDC(dc, saved);
        end;
      end else drawText(dc, cell, panel.Text, panel.Alignment);
      if i < bar.Panels.Count-1 then drawLine(dc, cell.Right-1, cell.Top+2, cell.Right-1, cell.Bottom-2, pal[COLOR_3DLIGHT]);
      x := cell.Right;
    end;
  end;
  if bar.SizeGrip then for var i := 1 to 3 do drawLine(dc, client.Right-4*i, client.Bottom-1, client.Right, client.Bottom-1-4*i, pal[COLOR_GRAYTEXT]);
  SelectObject(dc, oldFont);
  EndPaint(wnd, @ps);
end;

function statusProc(wnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM; id: UINT_PTR; data: DWORD_PTR): LRESULT; stdcall;
begin
  if active then begin
    var control := GetWin32WindowInfo(wnd)^.WinControl;
    if control is TStatusBar then match msg of
      WM_ERASEBKGND: exit(1);
      WM_PAINT: begin
        paintStatusBar(wnd, TStatusBar(control));
        exit(0);
      end;
    end;
  end;
  result := DefSubclassProc(wnd, msg, wParam, lParam);
end;

var
  // the arrow of an up-down control under the mouse; a held arrow keeps
  // the highlight until the button goes up
  upDownHot: record
    wnd: HWND; // 0 when none
    half: integer; // 1 first arrow, 2 second
    pressed: boolean;
  end;

// the arrow under a client point, 0 outside the control
function upDownHalfAt(wnd: HWND; lParam: LPARAM): integer;
begin
  var client: TRect;
  GetClientRect(wnd, @client);
  var pt := Point(smallint(lParam and $FFFF), smallint((lParam shr 16) and $FFFF));
  if not PtInRect(client, pt) then exit(0);
  if (GetWindowLongPtrW(wnd, GWL_STYLE) and UDS_HORZ) <> 0 then result := if pt.X < (client.Left+client.Right) div 2 then 1 else 2
  else result := if pt.Y < (client.Top+client.Bottom) div 2 then 1 else 2;
end;

procedure setUpDownHot(wnd: HWND; half: integer; pressed: boolean);
begin
  if half = 0 then begin
    wnd := 0;
    pressed := false;
  end;
  if (upDownHot.wnd = wnd) and (upDownHot.half = half) and (upDownHot.pressed = pressed) then exit;
  var old := upDownHot.wnd;
  upDownHot.wnd := wnd;
  upDownHot.half := half;
  upDownHot.pressed := pressed;
  if (old <> 0) and (old <> wnd) then InvalidateRect(old, nil, false);
  if wnd <> 0 then InvalidateRect(wnd, nil, false);
end;

procedure paintUpDown(wnd: HWND);
begin
  var ps: TPaintStruct;
  var dc := BeginPaint(wnd, @ps);
  var client: TRect;
  GetClientRect(wnd, @client);
  fillRect(dc, client, pal[COLOR_BTNFACE]);
  var color := if IsWindowEnabled(wnd) then pal[COLOR_BTNTEXT] else pal[COLOR_GRAYTEXT];
  var first := client;
  var second := client;
  var firstDir := adUp;
  var secondDir := adDown;
  if (GetWindowLongPtrW(wnd, GWL_STYLE) and UDS_HORZ) <> 0 then begin
    first.Right := (client.Left+client.Right) div 2;
    second.Left := first.Right;
    firstDir := adLeft;
    secondDir := adRight;
  end else begin
    first.Bottom := (client.Top+client.Bottom) div 2;
    second.Top := first.Bottom;
  end;
  if upDownHot.wnd = wnd then fillRect(dc, if upDownHot.half = 1 then first else second, if upDownHot.pressed then pal[COLOR_BTNSHADOW] else pal[COLOR_HOVER]);
  frameRect(dc, first, pal[COLOR_BTNHIGHLIGHT]);
  frameRect(dc, second, pal[COLOR_BTNHIGHLIGHT]);
  drawArrow(dc, first, firstDir, color);
  drawArrow(dc, second, secondDir, color);
  EndPaint(wnd, @ps);
end;

function upDownProc(wnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM; id: UINT_PTR; data: DWORD_PTR): LRESULT; stdcall;
begin
  if active then match msg of
    WM_ERASEBKGND: exit(1);
    WM_PAINT: begin
      paintUpDown(wnd);
      exit(0);
    end;
    WM_MOUSEMOVE: begin
      // asks for the leave message every time: the one armed before a press
      // may have fired while the mouse was held outside
      var track := Default(TTrackMouseEvent);
      track.cbSize := sizeof(track);
      track.dwFlags := TME_LEAVE;
      track.hwndTrack := wnd;
      startMouseTracking(track);
      if not ((upDownHot.wnd = wnd) and upDownHot.pressed) then setUpDownHot(wnd, upDownHalfAt(wnd, lParam), false);
    end;
    WM_LBUTTONDOWN: setUpDownHot(wnd, upDownHalfAt(wnd, lParam), true);
    WM_LBUTTONUP: setUpDownHot(wnd, upDownHalfAt(wnd, lParam), false);
    WM_MOUSELEAVE: if not ((upDownHot.wnd = wnd) and upDownHot.pressed) then setUpDownHot(wnd, 0, false);
    WM_CAPTURECHANGED: if upDownHot.wnd = wnd then setUpDownHot(wnd, upDownHot.half, false);
  end;
  result := DefSubclassProc(wnd, msg, wParam, lParam);
end;

// -- window styling -------------------------------------------------------

// theme, title bar and menu of one window; `control` is its LCL owner, nil
// for windows without one. `themed` false restores the stock look
// the padding, the item height and the band of a tab control follow the look;
// the stock values come back with the stock look
procedure refreshTabFrame(wnd: HWND; themed: boolean);
begin
  SendMessage(wnd, TCM_SETPADDING, 0, MakeLong(if themed then TAB_PAD_X else 6, if themed then TAB_PAD_Y else 3));
  SendMessage(wnd, TCM_SETITEMSIZE, 0, 0);
  SetWindowPos(wnd, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED);
end;

procedure styleWindow(wnd: HWND; control: TWinControl; themed: boolean);
begin
  var dark := themed and darkLook;
  if Assigned(uxAllowDarkModeForWindow) then uxAllowDarkModeForWindow(wnd, dark);
  var combo := control is TCustomComboBox;
  var app: PWideChar := nil;
  if dark then app := if combo then DARK_CFD else DARK_EXPLORER;
  // a combo box reloads its edit on the theme change and selects the whole
  // text while doing so; the selection is put back afterwards
  var editSel: LRESULT := 0;
  if combo then editSel := SendMessage(wnd, CB_GETEDITSEL, 0, 0);
  // a page window paints nothing native, and the theme change it would get
  // makes the LCL drop and reopen every theme handle it holds
  if control is not TCustomPage then SetWindowTheme(wnd, app, nil);
  if combo then SendMessage(wnd, CB_SETEDITSEL, 0, editSel);
  if control is TCustomTabControl then refreshTabFrame(wnd, themed);
  if (GetWindowLongPtrW(wnd, GWL_STYLE) and WS_CHILD) = 0 then begin
    var flag: BOOL := dark;
    // the attribute number moved in build 19041; the older one still answers there
    if Assigned(dwmSetWindowAttribute) and Failed(dwmSetWindowAttribute(wnd, DWMWA_DARK_TITLE, @flag, sizeof(flag))) then dwmSetWindowAttribute(wnd, DWMWA_DARK_TITLE_OLD, @flag, sizeof(flag));
    var menu := GetMenu(wnd);
    if menu <> 0 then setMenuBackground(menu, dark);
    // a window still under construction picks the frame up when it shows
    if IsWindowVisible(wnd) then begin
      SetWindowPos(wnd, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED);
      // DWM repaints the caption only on an activation change, so toggle it
      // and settle on the real state
      var foreground := GetForegroundWindow = wnd;
      SendMessage(wnd, WM_NCACTIVATE, WPARAM(ord(not foreground)), 0);
      SendMessage(wnd, WM_NCACTIVATE, WPARAM(ord(foreground)), 0);
      SendMessage(wnd, WM_NCPAINT, 1, 0);
      RedrawWindow(wnd, nil, 0, RDW_INVALIDATE or RDW_FRAME or RDW_UPDATENOW);
      if menu <> 0 then DrawMenuBar(wnd);
    end;
    exit;
  end;
  if combo then begin
    var info := Default(TComboboxInfo);
    info.cbSize := sizeof(info);
    if GetComboBoxInfo(wnd, @info) and (info.hwndList <> 0) then begin
      if Assigned(uxAllowDarkModeForWindow) then uxAllowDarkModeForWindow(info.hwndList, dark);
      var listApp: PWideChar := nil;
      if dark then listApp := DARK_EXPLORER;
      SetWindowTheme(info.hwndList, listApp, nil);
    end;
  end;
  RedrawWindow(wnd, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_FRAME);
end;

// a designed form and everything inside it keeps the stock look; the subclass
// only tells the paint stack when such a window paints, so the colors asked
// for meanwhile resolve to the stock ones
// a brush the control made outside its paint carries the palette color and
// stays cached; dropped, it is made again with the stock one when the paint
// asks for it
procedure dropPaletteBrush(brush: TBrush);
begin
  if not isPalBrush(HGDIOBJ(brush.Reference.Handle)) then exit;
  var color := brush.Color;
  brush.Color := clNone;
  brush.Color := color;
end;

// the background color a designed control shows when its program runs: its
// own, or that of the first parent it lets through, in the stock system colors
function stockBackgroundOf(control: TWinControl): COLORREF;
begin
  var c: TControl := control;
  while (c.Parent <> nil) and (csParentBackground in c.ControlStyle) do c := c.Parent;
  var color := c.Color;
  if color = clDefault then color := c.GetDefaultColor(dctBrush);
  var index := SysColorToSysColorIndex(color);
  if index < 0 then exit(COLORREF(color and $FFFFFF));
  if index = COLOR_FORM then index := COLOR_BTNFACE;
  result := origGetSysColor(index);
end;

function foreignProc(wnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM; id: UINT_PTR; data: DWORD_PTR): LRESULT; stdcall;
begin
  var painting := paintMessage(msg);
  if painting then pushPaint(wnd);
  defer popPaint(painting);
  if painting and active then begin
    var info := GetWin32WindowInfo(wnd);
    var control := info^.WinControl;
    // the designer overlay is registered under the form it covers, but it is
    // transparent and paints no background of its own
    if (control <> nil) and not (control.HandleAllocated and (control.Handle = wnd)) then control := nil;
    if (control <> nil) and control.BrushCreated then dropPaletteBrush(control.Brush);
    // a panel fills its background from its canvas
    if control is TCustomControl then dropPaletteBrush(TCustomControl(control).Canvas.Brush);
    // the background is filled here in the stock colors, whatever brush the
    // LCL holds for the control; a tab page keeps the erase command the LCL
    // queued for it, so it stays with the LCL
    if (msg = WM_ERASEBKGND) and (control <> nil) and not info^.isTabPage then begin
      var r: TRect;
      GetClipBox(HDC(wParam), @r);
      fillRect(HDC(wParam), r, stockBackgroundOf(control));
      exit(1);
    end;
  end;
  result := DefSubclassProc(wnd, msg, wParam, lParam);
end;

// the subclasses pass every message through when the theme is off, so they
// are installed once and stay; the window procedure must already be the
// final one the LCL installs
procedure subclassWindow(wnd: HWND; control: TWinControl);
begin
  if not isTagged(wnd) then begin
    SetWindowSubclass(wnd, @foreignProc, SUB_FOREIGN, 0);
    // under a tab page the LCL hands the background painting down to every
    // child window, which would put the IDE colors behind a designed one
    var info := GetWin32WindowInfo(wnd);
    if info^.WinControl <> nil then info^.needParentPaint := false;
    exit;
  end;
  if (GetWindowLongPtrW(wnd, GWL_STYLE) and WS_CHILD) = 0 then begin
    SetWindowSubclass(wnd, @topLevelProc, SUB_TOPLEVEL, 0);
    exit;
  end;
  if control is TStatusBar then SetWindowSubclass(wnd, @statusProc, SUB_STATUS, 0)
  else if control is TCustomTabControl then SetWindowSubclass(wnd, @tabProc, SUB_TAB, 0)
  else if classNameOf(wnd) = 'msctls_updown32' then SetWindowSubclass(wnd, @upDownProc, SUB_UPDOWN, 0);
  SetWindowSubclass(wnd, @chromeProc, SUB_CHROME, 0);
end;

function styleChild(wnd: HWND; lParam: LPARAM): BOOL; stdcall;
begin
  result := true;
  var control := GetWin32WindowInfo(wnd)^.WinControl;
  // the parent is tagged by now unless a designed form is on the way up
  var own := isTagged(wnd);
  if own then tagWindow(wnd);
  subclassWindow(wnd, control);
  if own then styleWindow(wnd, control, lParam <> 0);
end;

function styleTopLevel(wnd: HWND; lParam: LPARAM): BOOL; stdcall;
begin
  result := true;
  var control := GetWin32WindowInfo(wnd)^.WinControl;
  // only LCL windows and the hidden application window belong to the IDE
  if (control = nil) and (wnd <> Win32WidgetSet.AppHandle) then exit;
  var own := (control = nil) or not (csDesigning in control.ComponentState);
  if own then tagWindow(wnd);
  subclassWindow(wnd, control);
  if own then styleWindow(wnd, control, lParam <> 0);
  EnumChildWindows(wnd, @styleChild, lParam);
end;

// the windows repaint before the call returns: a palette swap during a mouse
// drag would otherwise reach the windows one by one, as the moves between
// them let the paint messages through
function redrawTopLevel(wnd: HWND; lParam: LPARAM): BOOL; stdcall;
begin
  result := true;
  if not isTagged(wnd) then exit;
  RedrawWindow(wnd, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or RDW_ALLCHILDREN or RDW_UPDATENOW);
  if GetMenu(wnd) <> 0 then DrawMenuBar(wnd);
end;

// re-sends the colors and fonts the widgetset cached in the native controls
procedure refreshControl(control: TWinControl);
begin
  if control.HandleAllocated then begin
    pushControlColors(control);
    // the page inset differs between the looks
    if control is TCustomTabControl then begin
      control.InvalidateClientRectCache(true);
      control.ReAlign;
    end;
  end;
  for var i := 0 to control.ControlCount-1 do if control.Controls[i] is TWinControl then refreshControl(TWinControl(control.Controls[i]));
end;

procedure refreshLCL;
begin
  var app := Win32WidgetSet.AppHandle;
  SendMessage(app, WM_THEMECHANGED, 0, 0); // the LCL reopens its theme handles
  SendMessage(app, WM_SYSCOLORCHANGE, 0, 0); // and drops the cached system color brushes
  for var i := 0 to Screen.CustomFormCount-1 do begin
    var form := Screen.CustomForms[i];
    if not (csDesigning in form.ComponentState) then refreshControl(form);
  end;
  EnumThreadWindows(GetCurrentThreadId, @redrawTopLevel, 0);
end;

// -- hook installation ----------------------------------------------------

// the true build number; the version the RTL reports follows the manifest
// and reads as Windows 8 for a process without a compatibility entry
type
  TVersionQuery = procedure(major, minor, build: PDWORD); stdcall;

function windowsBuild: DWORD;
begin
  result := Win32BuildNumber;
  var query: TVersionQuery;
  pointer(query) := GetProcAddress(GetModuleHandleW('ntdll.dll'), 'RtlGetNtVersionNumbers');
  if not Assigned(query) then exit;
  var major, minor, build: DWORD;
  query(@major, @minor, @build);
  result := build and $0FFFFFFF;
end;

procedure loadDarkApi;
begin
  var build := windowsBuild;
  if build < 17763 then exit;
  var ux := GetModuleHandleW('uxtheme.dll');
  if ux = 0 then exit;
  pointer(uxRefreshImmersiveColorPolicyState) := GetProcAddress(ux, PAnsiChar(104));
  pointer(uxAllowDarkModeForWindow) := GetProcAddress(ux, PAnsiChar(133));
  // ordinal 135 changed meaning in build 18362
  if build >= 18362 then pointer(uxSetPreferredAppMode) := GetProcAddress(ux, PAnsiChar(135))
  else pointer(uxAllowDarkModeForApp) := GetProcAddress(ux, PAnsiChar(135));
  pointer(uxFlushMenuThemes) := GetProcAddress(ux, PAnsiChar(136));
  var dwm := LoadLibraryW('dwmapi.dll');
  if dwm <> 0 then pointer(dwmSetWindowAttribute) := GetProcAddress(dwm, 'DwmSetWindowAttribute');
end;

procedure setAppMode(dark: boolean);
begin
  if Assigned(uxSetPreferredAppMode) then uxSetPreferredAppMode(if dark then PAM_FORCE_DARK else PAM_DEFAULT)
  else if Assigned(uxAllowDarkModeForApp) then uxAllowDarkModeForApp(dark);
  if Assigned(uxRefreshImmersiveColorPolicyState) then uxRefreshImmersiveColorPolicyState;
  if Assigned(uxFlushMenuThemes) then uxFlushMenuThemes;
end;

function writeSlot(slot: PPointer; value: pointer): boolean;
begin
  var old: DWORD := 0;
  result := VirtualProtect(slot, sizeof(pointer), PAGE_READWRITE, old);
  if not result then exit;
  slot^ := value;
  VirtualProtect(slot, sizeof(pointer), old, old);
end;

function imageDirectory(module: HMODULE; index: integer; out size: DWORD): PByte;
begin
  result := nil;
  size := 0;
  if module = 0 then exit;
  var base := PByte(module);
  var dos := PIMAGE_DOS_HEADER(base);
  if dos^.e_magic <> IMAGE_DOS_SIGNATURE then exit;
  var nt := PNtHeaders(base+dos^.e_lfanew);
  if nt^.Signature <> IMAGE_NT_SIGNATURE then exit;
  var dir := nt^.OptionalHeader.DataDirectory[index];
  if dir.VirtualAddress = 0 then exit;
  size := dir.Size;
  result := base+dir.VirtualAddress;
end;

// repoints every import thunk of `module` that resolves to `target`
procedure patchImport(module: HMODULE; const dll: string; target, replacement: pointer);
begin
  var size: DWORD;
  var desc := PIMAGE_IMPORT_DESCRIPTOR(imageDirectory(module, IMAGE_DIRECTORY_ENTRY_IMPORT, size));
  if (desc = nil) or (target = nil) then exit;
  var base := PByte(module);
  while desc^.FirstThunk <> 0 do begin
    if SameText(PAnsiChar(base+desc^.Name), dll) then begin
      var slot := PPointer(base+desc^.FirstThunk);
      while slot^ <> nil do begin
        if slot^ = target then writeSlot(slot, replacement);
        inc(slot);
      end;
    end;
    inc(desc);
  end;
end;

// repoints a delay-loaded import of `module`; `name` is a string or an ordinal below $10000
procedure patchDelayImport(module: HMODULE; const dll: string; name: PAnsiChar; replacement: pointer);
begin
  var size: DWORD;
  var desc := PIMAGE_DELAYLOAD_DESCRIPTOR(imageDirectory(module, IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT, size));
  if desc = nil then exit;
  var base := PByte(module);
  var byOrdinal := PtrUInt(name) < $10000;
  while desc^.DllNameRVA <> 0 do begin
    if SameText(PAnsiChar(base+desc^.DllNameRVA), dll) then begin
      var names := PIMAGE_THUNK_DATA(base+desc^.ImportNameTableRVA);
      var slot := PPointer(base+desc^.ImportAddressTableRVA);
      while names^.u1.AddressOfData <> 0 do begin
        var hit: boolean;
        if IMAGE_SNAP_BY_ORDINAL(names^.u1.Ordinal) then hit := byOrdinal and ((names^.u1.Ordinal and $FFFF) = PtrUInt(name))
        else hit := (not byOrdinal) and (StrIComp(PAnsiChar(base+names^.u1.AddressOfData+2), name) = 0);
        if hit then writeSlot(slot, replacement);
        inc(names);
        inc(slot);
      end;
    end;
    inc(desc);
  end;
end;

procedure ensureHooks;
begin
  if hooked then exit;
  hooked := true;
  themeMap := TThemeMap.Create;
  themeMap.Sorted := true;
  loadDarkApi;
  var exe := GetModuleHandleW(nil);
  var user32 := GetModuleHandleW('user32.dll');
  var gdi32 := GetModuleHandleW('gdi32.dll');
  var comctl := GetModuleHandleW('comctl32.dll');
  var ux := GetModuleHandleW('uxtheme.dll');

  pointer(origGetSysColor) := GetProcAddress(user32, 'GetSysColor');
  pointer(origGetSysColorBrush) := GetProcAddress(user32, 'GetSysColorBrush');
  pointer(origDrawEdge) := GetProcAddress(user32, 'DrawEdge');
  pointer(origCreateWindowExW) := GetProcAddress(user32, 'CreateWindowExW');
  pointer(origDeleteObject) := GetProcAddress(gdi32, 'DeleteObject');
  pointer(origSetScrollInfo) := GetProcAddress(user32, 'SetScrollInfo');
  pointer(origSetScrollPos) := GetProcAddress(user32, 'SetScrollPos');
  pointer(origSetScrollRange) := GetProcAddress(user32, 'SetScrollRange');
  pointer(origShowScrollBar) := GetProcAddress(user32, 'ShowScrollBar');
  pointer(origEnableScrollBar) := GetProcAddress(user32, 'EnableScrollBar');
  patchImport(exe, 'user32.dll', origSetScrollInfo, @hookSetScrollInfo);
  patchImport(exe, 'user32.dll', origSetScrollPos, @hookSetScrollPos);
  patchImport(exe, 'user32.dll', origSetScrollRange, @hookSetScrollRange);
  patchImport(exe, 'user32.dll', origShowScrollBar, @hookShowScrollBar);
  patchImport(exe, 'user32.dll', origEnableScrollBar, @hookEnableScrollBar);
  patchImport(exe, 'user32.dll', origGetSysColor, @hookGetSysColor);
  patchImport(exe, 'user32.dll', origGetSysColorBrush, @hookGetSysColorBrush);
  patchImport(exe, 'user32.dll', origDrawEdge, @hookDrawEdge);
  patchImport(exe, 'user32.dll', origCreateWindowExW, @hookCreateWindowExW);
  patchImport(exe, 'gdi32.dll', origDeleteObject, @hookDeleteObject);
  patchImport(comctl, 'user32.dll', origDrawEdge, @hookDrawEdge);
  patchImport(comctl, 'gdi32.dll', origDeleteObject, @hookDeleteObject);

  pointer(origOpenThemeData) := GetProcAddress(ux, 'OpenThemeData');
  pointer(origOpenThemeDataForDpi) := GetProcAddress(ux, 'OpenThemeDataForDpi');
  pointer(origOpenThemeDataEx) := GetProcAddress(ux, 'OpenThemeDataEx');
  pointer(origCloseThemeData) := GetProcAddress(ux, 'CloseThemeData');
  pointer(origDrawThemeBackground) := GetProcAddress(ux, 'DrawThemeBackground');
  pointer(origDrawThemeText) := GetProcAddress(ux, 'DrawThemeText');
  pointer(origDrawThemeTextEx) := GetProcAddress(ux, 'DrawThemeTextEx');
  pointer(origGetThemeColor) := GetProcAddress(ux, 'GetThemeColor');
  pointer(origDrawThemeEdge) := GetProcAddress(ux, 'DrawThemeEdge');
  pointer(origGetThemeSysColor) := GetProcAddress(ux, 'GetThemeSysColor');
  pointer(origGetThemeSysColorBrush) := GetProcAddress(ux, 'GetThemeSysColorBrush');
  // native controls reach uxtheme through the delay imports of comctl32
  patchDelayImport(comctl, 'uxtheme.dll', 'OpenThemeData', @hookOpenThemeData);
  patchDelayImport(comctl, 'uxtheme.dll', PAnsiChar(49), @hookOpenThemeData); // OpenNcThemeData
  patchDelayImport(comctl, 'uxtheme.dll', 'CloseThemeData', @hookCloseThemeData);
  patchDelayImport(comctl, 'uxtheme.dll', 'DrawThemeBackground', @hookDrawThemeBackground);
  patchDelayImport(comctl, 'uxtheme.dll', 'DrawThemeText', @hookDrawThemeText);
  patchDelayImport(comctl, 'uxtheme.dll', 'DrawThemeTextEx', @hookDrawThemeTextEx);
  patchDelayImport(comctl, 'uxtheme.dll', 'GetThemeColor', @hookGetThemeColor);
  patchDelayImport(comctl, 'uxtheme.dll', 'DrawThemeEdge', @hookDrawThemeEdge);
  patchDelayImport(comctl, 'uxtheme.dll', 'GetThemeSysColor', @hookGetThemeSysColor);
  patchDelayImport(comctl, 'uxtheme.dll', 'GetThemeSysColorBrush', @hookGetThemeSysColorBrush);
  if Assigned(origOpenThemeDataForDpi) then patchDelayImport(comctl, 'uxtheme.dll', 'OpenThemeDataForDpi', @hookOpenThemeDataForDpi);
  if Assigned(origOpenThemeDataEx) then patchDelayImport(comctl, 'uxtheme.dll', 'OpenThemeDataEx', @hookOpenThemeDataEx);
  // the LCL binds uxtheme itself
  UxTheme.OpenThemeData := @hookOpenThemeData;
  UxTheme.CloseThemeData := @hookCloseThemeData;
  UxTheme.DrawThemeBackground := @hookDrawThemeBackground;
  UxTheme.DrawThemeText := @hookDrawThemeText;
  UxTheme.DrawThemeEdge := @hookDrawThemeEdge;
  UxTheme.GetThemeSysColor := @hookGetThemeSysColor;
  UxTheme.GetThemeSysColorBrush := @hookGetThemeSysColorBrush;
  UxTheme.DrawThemeTextEx := @hookDrawThemeTextEx;
  UxTheme.GetThemeColor := @hookGetThemeColor;
  // the message boxes bind the Win32Extra copy, TTaskDialog the CommCtrl one
  origTaskDialogIndirect := CommCtrl.TaskDialogIndirect;
  CommCtrl.TaskDialogIndirect := @hookTaskDialogIndirect;
  Win32Extra.TaskDialogIndirect := @hookTaskDialogIndirect;
  callWndHook := SetWindowsHookExW(WH_CALLWNDPROC, @callWndProcHook, 0, GetCurrentThreadId);
  callWndRetHook := SetWindowsHookExW(WH_CALLWNDPROCRET, @callWndProcRetHook, 0, GetCurrentThreadId);
end;

// a track bar keeps a rendering of its channel between paints and shows the
// old colors after a plain repaint; the theme change makes it draw anew
function recolorChild(wnd: HWND; lParam: LPARAM): BOOL; stdcall;
begin
  result := true;
  if classNameOf(wnd) = 'msctls_trackbar32' then SendMessage(wnd, WM_THEMECHANGED, 0, 0);
end;

// puts the menu brush of the new palette on the menu bars and clears the
// caches of the children
function remenuTopLevel(wnd: HWND; lParam: LPARAM): BOOL; stdcall;
begin
  result := true;
  if not isTagged(wnd) then exit;
  EnumChildWindows(wnd, @recolorChild, 0);
  var menu := GetMenu(wnd);
  if menu = 0 then exit;
  setMenuBackground(menu, darkLook);
  DrawMenuBar(wnd);
end;

procedure applyPalette(const newPal: TPalette);
begin
  ensureHooks;
  pal := newPal;
  var r, g, b: byte;
  RedGreenBlue(pal[COLOR_BTNFACE], r, g, b);
  var dark := (r*299+g*587+b*114) div 1000 < 128;
  // a swap between two looks of the same darkness keeps the window frames:
  // restyling them flashes the client area white under DWM, and the sliders
  // of a theme editor swap the palette many times a second
  var restyle := (not active) or (dark <> darkLook);
  darkLook := dark;
  var oldMenuBrush := menuBrush;
  menuBrush := CreateSolidBrush(pal[COLOR_MENU]);
  active := true;
  if restyle then begin
    setAppMode(darkLook);
    EnumThreadWindows(GetCurrentThreadId, @styleTopLevel, 1);
  end else EnumThreadWindows(GetCurrentThreadId, @remenuTopLevel, 0);
  if oldMenuBrush <> 0 then origDeleteObject(oldMenuBrush);
  refreshLCL;
end;

procedure dropPalette;
begin
  if not active then exit;
  active := false;
  darkLook := false;
  setAppMode(false);
  EnumThreadWindows(GetCurrentThreadId, @styleTopLevel, 0);
  refreshLCL;
end;

finalization
  // the hooks stay installed until the process ends; without the map they
  // pass everything through
  active := false;
  FreeAndNil(themeMap);
{$endif}

end.
