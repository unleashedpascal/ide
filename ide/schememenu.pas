{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SchemeMenu;

{$mode unleashed}

interface

// the color group at the end of View: Syntax Highlight Profile with one entry per registered color
// scheme, and Misc Look; a theme package puts its menu in front. Call once after the main menu exists
procedure setupSchemeMenu;
// appends an entry for a scheme registered after the menu was built
procedure addSchemeMenuItem(const name: string);
procedure renameSchemeMenuItem(const oldName, newName: string);
procedure removeSchemeMenuItem(const name: string);
// makes the scheme current for every highlighter and repaints the open editors
procedure activateColorScheme(const name: string);
// pushes the stored color settings back onto the open editors
procedure reloadEditorColors;

implementation

uses
  Classes, SysUtils, Forms, MenuIntf, LazIDEIntf, EditorSyntaxHighlighterDef, EditorOptions, SourceEditor, MainIntf, LazarusIDEStrConsts, SchemeCreator, SchemeManager, SchemeIdeColors, MiscLook;

type

  { TMenuGlue }

  TMenuGlue = class(TComponent)
    procedure schemeClicked(Sender: TObject);
    procedure createClicked({%H-}Sender: TObject);
    procedure manageClicked({%H-}Sender: TObject);
    procedure miscClicked({%H-}Sender: TObject);
    procedure menuShown({%H-}Sender: TObject);
    procedure optionsWritten({%H-}Sender: TObject; Restore: boolean);
  end;

var
  glue: TMenuGlue = nil;
  schemeList: TIDEMenuSection = nil;
  schemeItemCount: integer = 0; // numbers the item names, which stay unique after a removal
  activeScheme: string; // the pascal scheme whose IDE colors are in place

procedure reloadEditorColors;
begin
  dropSchemePreview;
  SourceEditorManager.BeginGlobalUpdate;
  defer SourceEditorManager.EndGlobalUpdate;
  MainIDEInterface.UpdateHighlighters(true);
  SourceEditorManager.ReloadEditorOptions;
end;

procedure activateColorScheme(const name: string);
begin
  if ColorSchemeFactory.ColorSchemeGroup[name] = nil then exit;
  for var i := IdeHighlighterStartId to HighlighterList.Count-1 do EditorOpts.WriteColorScheme(HighlighterList[i].SynInstance.LanguageName, name);
  activeScheme := name;
  if applySchemeIdeColors(name) then MainIDEInterface.SaveEnvironment;
  EditorOpts.Save;
  reloadEditorColors;
end;

procedure addSchemeMenuItem(const name: string);
begin
  RegisterIDEMenuCommand(schemeList, 'itmViewScheme'+IntToStr(schemeItemCount), name, @glue.schemeClicked);
  inc(schemeItemCount);
end;

function findSchemeMenuItem(const name: string): TIDEMenuItem;
begin
  for var i := 0 to schemeList.Count-1 do if schemeList[i].Caption = name then exit(schemeList[i]);
  result := nil;
end;

procedure renameSchemeMenuItem(const oldName, newName: string);
begin
  var item := findSchemeMenuItem(oldName);
  if item <> nil then item.Caption := newName;
end;

procedure removeSchemeMenuItem(const name: string);
begin
  findSchemeMenuItem(name).Free;
end;

procedure setupSchemeMenu;
begin
  glue := TMenuGlue.Create(Application);
  var colors := RegisterIDEMenuSection(mnuView, 'itmViewColors');
  var menu := RegisterIDESubMenu(colors, 'itmViewSchemeMenu', lisMenuSyntaxHighlightProfile);
  schemeList := RegisterIDEMenuSection(menu, 'itmViewSchemeList');
  var names := autofree TStringList.Create;
  ColorSchemeFactory.GetRegisteredSchemes(names);
  for var i := 0 to names.Count-1 do addSchemeMenuItem(names[i]);
  var tools := RegisterIDEMenuSection(menu, 'itmViewSchemeCreate');
  RegisterIDEMenuCommand(tools, 'itmViewSchemeCreateNew', lisMenuCreateNewScheme, @glue.createClicked);
  RegisterIDEMenuCommand(tools, 'itmViewSchemeManage', lisMenuManageSchemes, @glue.manageClicked);
  menu.AddHandlerOnShow(@glue.menuShown);
  RegisterIDEMenuCommand(colors, 'itmViewMiscLook', lisMenuMiscLook, @glue.miscClicked);
  activeScheme := EditorOpts.ReadPascalColorScheme;
  EditorOpts.AddHandlerAfterWrite(@glue.optionsWritten);
  OnRollThemeScheme := @rollThemeScheme;
  OnRollThemeColors := @rollThemeMiscColors;
end;

{ TMenuGlue }

procedure TMenuGlue.schemeClicked(Sender: TObject);
begin
  activateColorScheme((Sender as TIDEMenuCommand).Caption);
end;

procedure TMenuGlue.createClicked(Sender: TObject);
begin
  showSchemeCreator;
end;

procedure TMenuGlue.manageClicked(Sender: TObject);
begin
  showSchemeManager;
end;

procedure TMenuGlue.miscClicked(Sender: TObject);
begin
  showMiscLook;
end;

procedure TMenuGlue.menuShown(Sender: TObject);
begin
  var current := EditorOpts.ReadPascalColorScheme;
  for var i := 0 to schemeList.Count-1 do schemeList[i].Checked := SameText(schemeList[i].Caption, current);
end;

// a scheme picked in the options dialog brings its IDE colors along like one picked from the menu;
// the editor options save themselves before the handlers run, so the dividers need a save of their own
procedure TMenuGlue.optionsWritten(Sender: TObject; Restore: boolean);
begin
  // the IDE reloads the stored colors after the handlers
  dropSchemePreview;
  if Restore then exit;
  var current := EditorOpts.ReadPascalColorScheme;
  if current = activeScheme then exit;
  activeScheme := current;
  if not applySchemeIdeColors(current) then exit;
  EditorOpts.Save;
  MainIDEInterface.SaveEnvironment;
end;

end.
