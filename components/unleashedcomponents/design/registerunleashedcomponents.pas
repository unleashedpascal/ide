{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RegisterUnleashedComponents;

{$mode unleashed}

interface

const
  // the palette pages, placed right after Additional in this order
  PAGE_CONTROLS = 'Unleashed';
  PAGE_LAYOUT = 'Unleashed Layout';
  PAGE_TOOLS = 'Unleashed Tools';

procedure Register;

implementation

{$R ../unleashedcomponents.res}

uses
  Classes, ComponentReg, ComponentEditors, AppTheme, AppThemeEditor;

procedure Register;
begin
  RegisterComponents(PAGE_CONTROLS, [TAppTheme]);
  RegisterComponentEditor(TAppTheme, TAppThemeComponentEditor);
  IDEComponentPalette.AnchorPage(PAGE_CONTROLS, 'Additional');
  IDEComponentPalette.AnchorPage(PAGE_LAYOUT, 'Additional');
  IDEComponentPalette.AnchorPage(PAGE_TOOLS, 'Additional');
end;

end.
