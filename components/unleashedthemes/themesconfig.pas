{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesConfig;

{$mode unleashed}

interface

uses
  LazConfigStorage, BaseIDEIntf, LazIDEIntf, ThemesPalette;

const
  CONFIG_FILE = 'unleashedthemes.xml';

type
  // tkDefault leaves the stock widgetset look untouched; tkSystem picks the
  // light or the dark palette after the desktop setting
  TThemeKind = (tkDefault, tkSystem, tkLight, tkDark, tkOcean, tkFrost, tkPaper, tkEmber, tkMidnight, tkDusk);

function loadThemeKind: TThemeKind;
procedure saveThemeKind(kind: TThemeKind);
// a theme picked from the menu rolls a new syntax highlight profile
function loadAutoScheme: boolean;
procedure saveAutoScheme(enabled: boolean);
function loadIconFit: TIconFit;
procedure saveIconFit(const fit: TIconFit);
// the hover and active feedback of the controls; the IDE keeps the hover it
// always had and leaves the rings off
function loadEffects: TThemeEffects;
procedure saveEffects(const effects: TThemeEffects);

implementation

const
  KEY_THEME = 'Theme';
  KEY_AUTO_SCHEME = 'AutoScheme';
  KEY_ICON_FIT = 'IconFit/';
  KEY_HOVER = 'Effects/Hover';
  KEY_ACTIVE = 'Effects/Active';
  KIND_NAMES: array[TThemeKind] of string = ('default', 'system', 'light', 'dark', 'ocean', 'frost', 'paper', 'ember', 'midnight', 'dusk');

function loadThemeKind: TThemeKind;
begin
  result := tkSystem;
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  var name := cfg.GetValue(KEY_THEME, KIND_NAMES[tkSystem]);
  for var kind := low(TThemeKind) to high(TThemeKind) do if KIND_NAMES[kind] = name then exit(kind);
end;

procedure saveThemeKind(kind: TThemeKind);
begin
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  cfg.SetDeleteValue(KEY_THEME, KIND_NAMES[kind], KIND_NAMES[tkSystem]);
  cfg.WriteToDisk;
end;

function loadAutoScheme: boolean;
begin
  result := true;
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  result := cfg.GetValue(KEY_AUTO_SCHEME, true);
end;

procedure saveAutoScheme(enabled: boolean);
begin
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  cfg.SetDeleteValue(KEY_AUTO_SCHEME, enabled, true);
  cfg.WriteToDisk;
end;

function loadEffects: TThemeEffects;
begin
  result.Hover := true;
  result.Active := false;
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  result.Hover := cfg.GetValue(KEY_HOVER, true);
  result.Active := cfg.GetValue(KEY_ACTIVE, false);
end;

procedure saveEffects(const effects: TThemeEffects);
begin
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  cfg.SetDeleteValue(KEY_HOVER, effects.Hover, true);
  cfg.SetDeleteValue(KEY_ACTIVE, effects.Active, false);
  cfg.WriteToDisk;
end;

function loadIconFit: TIconFit;
begin
  result := DefaultIconFit;
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  with result do begin
    Enabled := cfg.GetValue(KEY_ICON_FIT+'Enabled', DefaultIconFit.Enabled);
    Strength := cfg.GetValue(KEY_ICON_FIT+'Strength', DefaultIconFit.Strength);
    MinContrast := cfg.GetValue(KEY_ICON_FIT+'MinContrast', DefaultIconFit.MinContrast);
    MaxLightness := cfg.GetValue(KEY_ICON_FIT+'MaxLightness', DefaultIconFit.MaxLightness);
    DisabledContrast := cfg.GetValue(KEY_ICON_FIT+'DisabledContrast', DefaultIconFit.DisabledContrast);
    DisabledSaturation := cfg.GetValue(KEY_ICON_FIT+'DisabledSaturation', DefaultIconFit.DisabledSaturation);
  end;
end;

procedure saveIconFit(const fit: TIconFit);
begin
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  cfg.SetDeleteValue(KEY_ICON_FIT+'Enabled', fit.Enabled, DefaultIconFit.Enabled);
  cfg.SetDeleteValue(KEY_ICON_FIT+'Strength', fit.Strength, DefaultIconFit.Strength);
  cfg.SetDeleteValue(KEY_ICON_FIT+'MinContrast', fit.MinContrast, DefaultIconFit.MinContrast);
  cfg.SetDeleteValue(KEY_ICON_FIT+'MaxLightness', fit.MaxLightness, DefaultIconFit.MaxLightness);
  cfg.SetDeleteValue(KEY_ICON_FIT+'DisabledContrast', fit.DisabledContrast, DefaultIconFit.DisabledContrast);
  cfg.SetDeleteValue(KEY_ICON_FIT+'DisabledSaturation', fit.DisabledSaturation, DefaultIconFit.DisabledSaturation);
  cfg.WriteToDisk;
end;

end.
