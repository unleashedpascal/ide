{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit unleashedcomponents;

{$warn 5023 off : no warning about unused units}
interface

uses
  AppTheme, LazarusPackageIntf;

implementation

procedure register;
begin
end;

initialization
  registerpackage('UnleashedComponents', @register);
end.
