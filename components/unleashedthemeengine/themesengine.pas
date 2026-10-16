{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesEngine;

{$mode unleashed}

interface

uses
  ThemesPalette;

// puts the palette on every window of the process and on the windows made
// later. The hooks of the widgetset install on the first call and stay until
// the process ends; a later call swaps the palette in place
procedure applyTheme(const pal: TPalette);
// hands every window back to the stock look of the widgetset
procedure dropTheme;
// a palette is on screen
function themeActive: boolean;
// the palette put on screen last; meaningful while themeActive
function currentPalette: TPalette;
// the widgetset has an engine; elsewhere applyTheme and dropTheme do nothing
function themeSupported: boolean;
// the hover and active feedback; a change shows at once
procedure setThemeEffects(const value: TThemeEffects);
function themeEffects: TThemeEffects;
// the desktop asks applications for the dark look
function systemDark: boolean;

var
  // fired on the UI thread, outside any window message, when the desktop
  // switches between light and dark
  onSystemThemeChange: procedure = nil;

implementation

uses
  Classes, Forms, Themes{$ifdef LCLWin32}, Windows, Registry, ThemesWin32{$endif}{$ifdef LCLGtk3}, ThemesGtk3{$endif};

type

  { TSystemGlue }

  TSystemGlue = class(TComponent)
    procedure changed(data: PtrInt);
  end;

var
  active: boolean = false;
  current: TPalette;
  glue: TSystemGlue = nil;

procedure applyTheme(const pal: TPalette);
begin
  current := pal;
  active := true;
  {$if defined(LCLWin32) or defined(LCLGtk3)}
  applyPalette(pal);
  {$endif}
end;

procedure dropTheme;
begin
  active := false;
  {$if defined(LCLWin32) or defined(LCLGtk3)}
  dropPalette;
  {$endif}
end;

function themeActive: boolean;
begin
  result := active;
end;

function currentPalette: TPalette;
begin
  result := current;
end;

function themeSupported: boolean;
begin
  result := {$if defined(LCLWin32) or defined(LCLGtk3)}true{$else}false{$endif};
end;

procedure setThemeEffects(const value: TThemeEffects);
begin
  {$if defined(LCLWin32) or defined(LCLGtk3)}
  if (effects.Hover = value.Hover) and (effects.Active = value.Active) then exit;
  effects := value;
  redrawAll;
  {$endif}
end;

function themeEffects: TThemeEffects;
begin
  result := {$if defined(LCLWin32) or defined(LCLGtk3)}effects{$else}DefaultEffects{$endif};
end;

function systemDark: boolean;
begin
  {$ifdef LCLWin32}
  // ThemeServices trusts the reported Windows version, which stays 6.2 when
  // the manifest does not name Windows 10; the value exists from Windows 10 on
  var reg := TRegistry.Create(KEY_READ);
  try
    reg.RootKey := HKEY_CURRENT_USER;
    result := reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize')
      and reg.ValueExists('AppsUseLightTheme') and (reg.ReadInteger('AppsUseLightTheme') = 0);
  finally
    reg.Free;
  end;
  {$else}
  result := ThemeServices.IsDarkTheme;
  {$endif}
end;

procedure TSystemGlue.changed(data: PtrInt);
begin
  if Assigned(onSystemThemeChange) then onSystemThemeChange;
end;

// the desktop notification arrives inside a window message, so the repaint of
// every window waits until the message loop is idle
procedure queueSystemChange;
begin
  if glue = nil then glue := TSystemGlue.Create(Application);
  Application.QueueAsyncCall(@glue.changed, 0);
end;

initialization
  {$ifdef LCLWin32}
  ThemesWin32.onSystemThemeChange := @queueSystemChange;
  {$endif}
  {$ifdef LCLGtk3}
  ThemesGtk3.onSystemThemeChange := @queueSystemChange;
  {$endif}
end.
