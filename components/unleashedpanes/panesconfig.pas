{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PanesConfig;

{$mode unleashed}

interface

uses
  LazConfigStorage, BaseIDEIntf;

const
  CONFIG_FILE = 'unleashedpanes.xml';
  PADDING_MIN = 0;
  PADDING_MAX = 16;

type

  TPaneSettings = record
    headerShown: boolean;
    padding: integer;
  end;

function defaultPaneSettings: TPaneSettings;
function clampPaneSettings(const src: TPaneSettings): TPaneSettings;
function loadPaneSettings: TPaneSettings;
procedure savePaneSettings(const src: TPaneSettings);

implementation

const
  KEY_HEADER_SHOWN = 'HeaderShown';
  KEY_PADDING = 'Padding';

function defaultPaneSettings: TPaneSettings;
begin
  result.headerShown := true;
  result.padding := 4;
end;

function clampPaneSettings(const src: TPaneSettings): TPaneSettings;
begin
  result := src;
  if result.padding < PADDING_MIN then result.padding := PADDING_MIN;
  if result.padding > PADDING_MAX then result.padding := PADDING_MAX;
end;

function loadPaneSettings: TPaneSettings;
begin
  result := defaultPaneSettings;
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, true);
  result.headerShown := cfg.GetValue(KEY_HEADER_SHOWN, result.headerShown);
  result.padding := cfg.GetValue(KEY_PADDING, result.padding);
  result := clampPaneSettings(result);
end;

procedure savePaneSettings(const src: TPaneSettings);
begin
  if not Assigned(GetIDEConfigStorage) then exit;
  var def := defaultPaneSettings;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, true);
  cfg.SetDeleteValue(KEY_HEADER_SHOWN, src.headerShown, def.headerShown);
  cfg.SetDeleteValue(KEY_PADDING, src.padding, def.padding);
  cfg.WriteToDisk;
end;

end.
