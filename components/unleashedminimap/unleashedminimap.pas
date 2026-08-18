{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit unleashedminimap;

{$warn 5023 off : no warning about unused units}
interface

uses
  RegUnleashedMiniMap, MiniMapConfig, MiniMapManager, MiniMapSetupDlg, MiniMapStrings, MiniMapView, LazarusPackageIntf;

implementation

procedure register;
begin
  registerunit('RegUnleashedMinimap', @regunleashedminimap.register);
end;

initialization
  registerpackage('UnleashedMinimap', @register);
end.
