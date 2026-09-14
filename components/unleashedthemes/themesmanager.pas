{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesManager;

{$mode unleashed}

interface

uses
  ThemesConfig;

// switches the IDE look at once; tkSystem follows the desktop setting
procedure applyThemeKind(kind: TThemeKind);
function currentThemeKind: TThemeKind;

implementation

uses
  Classes, Forms, Themes{$ifdef LCLWin32}, ThemesPalette, ThemesWin32{$endif};

type

  { TThemeGlue }

  TThemeGlue = class(TComponent)
    procedure systemChanged(data: PtrInt);
  end;

var
  current: TThemeKind = tkSystem;
  shown: TThemeKind = tkDefault; // palette on screen; the system choice resolves to one of the others
  glue: TThemeGlue = nil;

// the palette a choice puts on screen; tkDefault means the stock look
function paletteKind(kind: TThemeKind): TThemeKind;
begin
  result := kind;
  if kind = tkSystem then result := if ThemeServices.IsDarkTheme then tkDark else tkLight;
end;

procedure applyThemeKind(kind: TThemeKind);
begin
  current := kind;
  var want := paletteKind(kind);
  if want = shown then exit;
  shown := want;
  {$ifdef LCLWin32}
  match want of
    tkLight: applyPalette(lightPalette);
    tkDark: applyPalette(darkPalette);
    tkOcean: applyPalette(oceanPalette);
    tkFrost: applyPalette(frostPalette);
    tkPaper: applyPalette(paperPalette);
    tkEmber: applyPalette(emberPalette);
    tkMidnight: applyPalette(midnightPalette);
    tkDusk: applyPalette(duskPalette);
    _: dropPalette;
  end;
  {$endif}
end;

function currentThemeKind: TThemeKind;
begin
  result := current;
end;

procedure TThemeGlue.systemChanged(data: PtrInt);
begin
  if current = tkSystem then applyThemeKind(tkSystem);
end;

// the desktop notification arrives inside a window message, so the repaint of
// every window waits until the message loop is idle
procedure queueSystemChange;
begin
  if glue = nil then glue := TThemeGlue.Create(Application);
  Application.QueueAsyncCall(@glue.systemChanged, 0);
end;

initialization
  {$ifdef LCLWin32}
  onSystemThemeChange := @queueSystemChange;
  {$endif}
end.
