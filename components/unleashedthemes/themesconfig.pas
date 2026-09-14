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
  LazConfigStorage, BaseIDEIntf;

const
  CONFIG_FILE = 'unleashedthemes.xml';

type
  // tkDefault leaves the stock widgetset look untouched; tkSystem picks the
  // light or the dark palette after the desktop setting
  TThemeKind = (tkDefault, tkSystem, tkLight, tkDark, tkOcean, tkFrost, tkPaper, tkEmber, tkMidnight, tkDusk);

function loadThemeKind: TThemeKind;
procedure saveThemeKind(kind: TThemeKind);

implementation

const
  KEY_THEME = 'Theme';
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

end.
