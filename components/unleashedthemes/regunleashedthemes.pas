{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RegUnleashedThemes;

{$mode unleashed}

interface

procedure Register;

implementation

uses
  Classes, Forms, MenuIntf, LazIDEIntf, ThemesStrings, ThemesConfig, ThemesManager;

type

  { TMenuGlue }

  TMenuGlue = class(TComponent)
    procedure clicked(Sender: TObject);
  end;

var
  glue: TMenuGlue = nil;
  items: array[TThemeKind] of TIDEMenuCommand;

procedure syncChecks;
begin
  for var kind := low(TThemeKind) to high(TThemeKind) do if items[kind] <> nil then items[kind].Checked := kind = currentThemeKind;
end;

procedure choose(kind: TThemeKind);
begin
  applyThemeKind(kind);
  saveThemeKind(kind);
  syncChecks;
end;

procedure TMenuGlue.clicked(Sender: TObject);
begin
  for var kind := low(TThemeKind) to high(TThemeKind) do if items[kind] = Sender then choose(kind);
end;

function addItem(parent: TIDEMenuSection; kind: TThemeKind; const name, caption: string): TIDEMenuCommand;
begin
  result := RegisterIDEMenuCommand(parent, name, caption, @glue.clicked);
  result.RadioItem := True;
  result.GroupIndex := 1;
  items[kind] := result;
end;

procedure Register;
begin
  glue := TMenuGlue.Create(Application);
  var section := RegisterIDEMenuSection(mnuView, 'itmViewTheme');
  var menu := RegisterIDESubMenu(section, 'itmViewThemeMenu', MENU_THEME);
  // sections draw the separators: basic choices, light themes, dark themes
  var basic := RegisterIDEMenuSection(menu, 'itmViewThemeBasic');
  addItem(basic, tkDefault, 'itmViewThemeDefault', MENU_DEFAULT);
  addItem(basic, tkSystem, 'itmViewThemeSystem', MENU_SYSTEM);
  addItem(basic, tkLight, 'itmViewThemeLight', MENU_LIGHT);
  addItem(basic, tkDark, 'itmViewThemeDark', MENU_DARK);
  var light := RegisterIDEMenuSection(menu, 'itmViewThemeLights');
  addItem(light, tkFrost, 'itmViewThemeFrost', MENU_FROST);
  addItem(light, tkPaper, 'itmViewThemePaper', MENU_PAPER);
  var dark := RegisterIDEMenuSection(menu, 'itmViewThemeDarks');
  addItem(dark, tkOcean, 'itmViewThemeOcean', MENU_OCEAN);
  addItem(dark, tkEmber, 'itmViewThemeEmber', MENU_EMBER);
  addItem(dark, tkMidnight, 'itmViewThemeMidnight', MENU_MIDNIGHT);
  addItem(dark, tkDusk, 'itmViewThemeDusk', MENU_DUSK);
  syncChecks;
end;

// runs before the main window exists, so the first paint already has the theme
procedure applySavedTheme;
begin
  applyThemeKind(loadThemeKind);
end;

initialization
  AddBootHandler(libhEnvironmentOptionsLoaded, @applySavedTheme);
end.
