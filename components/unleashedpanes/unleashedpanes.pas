{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit unleashedpanes;

{$warn 5023 off : no warning about unused units}
interface

uses
  RegUnleashedPanes, PanesLayout, PanesMaster, PanesStrings, PanesDrag, PanesConfig, PanesOptionsFrame, LazarusPackageIntf;

implementation

procedure register;
begin
  registerunit('RegUnleashedPanes', @regunleashedpanes.register);
end;

initialization
  registerpackage('UnleashedPanes', @register);
end.
