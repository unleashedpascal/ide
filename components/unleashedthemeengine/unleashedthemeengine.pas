{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit unleashedthemeengine;

{$warn 5023 off : no warning about unused units}
interface

uses
  ThemesEngine, ThemesPalette, ThemesWin32, ThemesGtk3, ThemesIcons, LazarusPackageIntf;

implementation

procedure register;
begin
end;

initialization
  registerpackage('UnleashedThemeEngine', @register);
end.
