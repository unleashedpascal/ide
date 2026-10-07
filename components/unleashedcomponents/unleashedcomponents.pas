{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit UnleashedComponents;

{$warn 5023 off : no warning about unused units}
interface

uses
  AppTheme, RangeSlider, ControlPaint, ToggleSwitch, SearchEdit, SplitButton, 
  LinkLabel, SegmentedControl, ColorPicker, BusyIndicator, ProgressRing, 
  SuggestEdit, Badge, Rating, Led, Sparkline, Marquee, Knob, Gauge, Clock, 
  RichLabel, PasswordEdit, HotKeyEdit, DurationEdit, ImageViewer, QRCode, 
  JsonTreeView, TagEditor, LogView, DropZone, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('UnleashedComponents', @Register);
end.
