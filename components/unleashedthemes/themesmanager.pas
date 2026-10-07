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
  Graphics, Themes, ThemesPalette, ThemesEngine, ThemesIcons{$ifdef LCLWin32}, ThemesWin32{$endif};

var
  current: TThemeKind = tkSystem;
  shown: TThemeKind = tkDefault; // palette on screen; the system choice resolves to one of the others

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
  if want <> shown then begin
    shown := want;
    match want of
      tkLight: applyTheme(lightPalette);
      tkDark: applyTheme(darkPalette);
      tkOcean: applyTheme(oceanPalette);
      tkFrost: applyTheme(frostPalette);
      tkPaper: applyTheme(paperPalette);
      tkEmber: applyTheme(emberPalette);
      tkMidnight: applyTheme(midnightPalette);
      tkDusk: applyTheme(duskPalette);
      _: dropTheme;
    end;
  end;
  // the stock look needs the icon pass as well, so it runs on the first call too
  themeIcons(clBtnFace);
end;

function currentThemeKind: TThemeKind;
begin
  result := current;
end;

procedure systemChanged;
begin
  if current = tkSystem then applyThemeKind(tkSystem);
end;

initialization
  onSystemThemeChange := @systemChanged;
  {$ifdef LCLWin32}
  tabMarks := true;
  {$endif}
end.
