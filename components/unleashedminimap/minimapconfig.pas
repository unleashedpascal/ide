{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit MiniMapConfig;

{$mode unleashed}

interface

uses
  Graphics, LazConfigStorage, BaseIDEIntf;

const
  CONFIG_FILE = 'unleashedminimap.xml';

  MAP_WIDTH_MIN = 60;
  MAP_WIDTH_MAX = 600;
  FONT_SIZE_MIN = 1;
  FONT_SIZE_MAX = 12;
  BAND_TINT_MIN = 1;
  BAND_TINT_MAX = 100;

type

  TMapSettings = record
    shown: boolean;
    mapWidth: integer;
    fontSize: integer;  // point size of the map font
    bandColor: TColor;  // clDefault blends white into the editor background
    bandTint: integer;  // percent of bandColor mixed into the background
  end;

function defaultMapSettings: TMapSettings;
function clampMapSettings(const src: TMapSettings): TMapSettings;
function loadMapSettings: TMapSettings;
procedure saveMapSettings(const src: TMapSettings);

implementation

const
  KEY_SHOWN      = 'Shown';
  KEY_MAP_WIDTH  = 'MapWidth';
  KEY_FONT_SIZE  = 'FontSize';
  KEY_BAND_COLOR = 'BandColor';
  KEY_BAND_TINT  = 'BandTint';

function clampInt(value, low, high: integer): integer;
begin
  result := value;
  if result < low then result := low;
  if result > high then result := high;
end;

function defaultMapSettings: TMapSettings;
begin
  result.shown := True;
  result.mapWidth := 180;
  result.fontSize := 3;
  result.bandColor := clSilver;
  result.bandTint := 20;
end;

function clampMapSettings(const src: TMapSettings): TMapSettings;
begin
  result := src;
  result.mapWidth := clampInt(result.mapWidth, MAP_WIDTH_MIN, MAP_WIDTH_MAX);
  result.fontSize := clampInt(result.fontSize, FONT_SIZE_MIN, FONT_SIZE_MAX);
  result.bandTint := clampInt(result.bandTint, BAND_TINT_MIN, BAND_TINT_MAX);
end;

function loadMapSettings: TMapSettings;
begin
  result := defaultMapSettings;
  if not Assigned(GetIDEConfigStorage) then exit;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  result.shown := cfg.GetValue(KEY_SHOWN, result.shown);
  result.mapWidth := cfg.GetValue(KEY_MAP_WIDTH, result.mapWidth);
  result.fontSize := cfg.GetValue(KEY_FONT_SIZE, result.fontSize);
  result.bandColor := TColor(cfg.GetValue(KEY_BAND_COLOR, integer(result.bandColor)));
  result.bandTint := cfg.GetValue(KEY_BAND_TINT, result.bandTint);
  result := clampMapSettings(result);
end;

procedure saveMapSettings(const src: TMapSettings);
begin
  if not Assigned(GetIDEConfigStorage) then exit;
  var def := defaultMapSettings;
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, True);
  cfg.SetDeleteValue(KEY_SHOWN, src.shown, def.shown);
  cfg.SetDeleteValue(KEY_MAP_WIDTH, src.mapWidth, def.mapWidth);
  cfg.SetDeleteValue(KEY_FONT_SIZE, src.fontSize, def.fontSize);
  cfg.SetDeleteValue(KEY_BAND_COLOR, integer(src.bandColor), integer(def.bandColor));
  cfg.SetDeleteValue(KEY_BAND_TINT, src.bandTint, def.bandTint);
  cfg.WriteToDisk;
end;

end.
