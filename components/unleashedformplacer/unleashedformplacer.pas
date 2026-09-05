{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit unleashedformplacer;

{$warn 5023 off : no warning about unused units}
interface

uses
  RegUnleashedFormplacer, FormPlacerConfig, FormPlacerMap, FormPlacerOptionsFrame,
  FormPlacerStrings, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('RegUnleashedFormplacer', @RegUnleashedFormplacer.Register);
end;

initialization
  RegisterPackage('UnleashedFormplacer', @Register);
end.
