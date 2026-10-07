{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit unleashedcomponentsdsgn;

{$warn 5023 off : no warning about unused units}
interface

uses
  RegisterUnleashedComponents, LazarusPackageIntf;

implementation

procedure register;
begin
  registerunit('RegisterUnleashedComponents', @registerunleashedcomponents.register);
end;

initialization
  registerpackage('UnleashedComponentsDsgn', @register);
end.
