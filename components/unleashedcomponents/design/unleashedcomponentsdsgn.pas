{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit UnleashedComponentsDsgn;

{$warn 5023 off : no warning about unused units}
interface

uses
  RegisterUnleashedComponents, AppThemeEditor, SegmentEditor, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('RegisterUnleashedComponents', 
    @RegisterUnleashedComponents.Register);
end;

initialization
  RegisterPackage('UnleashedComponentsDsgn', @Register);
end.
