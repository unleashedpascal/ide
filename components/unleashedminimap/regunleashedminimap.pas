{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RegUnleashedMinimap;

{$mode unleashed}

interface

procedure Register;

implementation

uses
  Classes, Forms, MenuIntf, MiniMapStrings, MiniMapConfig, MiniMapManager, MiniMapSetupDlg;

type

  { TMenuGlue }

  TMenuGlue = class(TComponent)
    procedure toggleClicked(Sender: TObject);
    procedure setupClicked(Sender: TObject);
  end;

var
  glue: TMenuGlue = nil;
  toggleItem: TIDEMenuCommand = nil;

// prefers the appearance group of the View menu and falls back to the window
// group, which every build of the menu has
function menuHost: TIDEMenuSection;
begin
  result := itmViewMainWindows;
  if IDEMenuRoots = nil then exit;
  var found := IDEMenuRoots.FindByPath('IDEMainMenu/View/itmViewAppearance', False);
  if found is TIDEMenuSection then result := TIDEMenuSection(found);
end;

procedure syncToggle;
begin
  if (toggleItem <> nil) and (mapManager <> nil) then toggleItem.Checked := mapManager.settings.shown;
end;

procedure TMenuGlue.toggleClicked(Sender: TObject);
begin
  if mapManager = nil then exit;
  mapManager.toggleShown;
  syncToggle;
end;

procedure TMenuGlue.setupClicked(Sender: TObject);
begin
  if mapManager = nil then exit;
  var edited := mapManager.settings;
  if not editMapSettings(edited) then exit;
  mapManager.applySettings(edited);
  mapManager.saveConfig;
  syncToggle;
end;

procedure Register;
begin
  mapManager := TMiniMapManager.Create(Application);
  mapManager.loadConfig;
  glue := TMenuGlue.Create(Application);
  var host := menuHost;
  toggleItem := RegisterIDEMenuCommand(host, 'itmViewCodeMapToggle', MENU_SHOW_MAP, @glue.toggleClicked);
  syncToggle;
  RegisterIDEMenuCommand(host, 'itmViewCodeMapSetup', MENU_MAP_SETUP, @glue.setupClicked);
end;

end.
