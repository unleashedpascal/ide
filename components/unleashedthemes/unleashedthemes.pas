{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit unleashedthemes;

{$warn 5023 off : no warning about unused units}
interface

uses
  RegUnleashedThemes, ThemesConfig, ThemesManager, ThemesPalette, ThemesStrings, ThemesWin32, ThemesGtk3, ThemesIcons, LazarusPackageIntf;

implementation

procedure register;
begin
  registerunit('RegUnleashedThemes', @regunleashedthemes.register);
end;

initialization
  registerpackage('UnleashedThemes', @register);
end.
