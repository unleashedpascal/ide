{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below.

  Unleashed Form Placer: IDE options page (Environment / Form Placer). }

unit FormPlacerOptionsFrame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  Forms, StdCtrls, Spin, ColorBox,
  // IdeIntf
  IDEOptionsIntf, IDEOptEditorIntf,
  // UnleashedFormplacer
  FormPlacerConfig, FormPlacerStrings, FormPlacerMap;

type

  { TFormPlacerOptionsFrame }

  TFormPlacerOptionsFrame = class(TAbstractIDEOptionsEditor)
    CheckBoxShowMap: TCheckBox;
    CheckBoxLiveUpdate: TCheckBox;
    LabelMapWidth: TLabel;
    SpinEditMapWidth: TSpinEdit;
    LabelNudgeStep: TLabel;
    SpinEditNudgeStep: TSpinEdit;
    LabelColors: TLabel;
    LabelMapBack: TLabel;
    ColorBoxMapBack: TColorBox;
    LabelMonitorEdge: TLabel;
    ColorBoxMonitorEdge: TColorBox;
    LabelFormFill: TLabel;
    ColorBoxFormFill: TColorBox;
    LabelFormEdge: TLabel;
    ColorBoxFormEdge: TColorBox;
    LabelTitleBar: TLabel;
    ColorBoxTitleBar: TColorBox;
  public
    function GetTitle: String; override;
    procedure Setup({%H-}ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings({%H-}AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings({%H-}AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

implementation

{$R *.lfm}

{ TFormPlacerOptionsFrame }

function TFormPlacerOptionsFrame.GetTitle: String;
begin
  Result := SPlacerOptionsTitle;
end;

procedure TFormPlacerOptionsFrame.Setup(ADialog: TAbstractOptionsEditorDialog);
begin
  CheckBoxShowMap.Caption    := SPlacerShowMap;
  CheckBoxLiveUpdate.Caption := SPlacerLiveUpdate;
  LabelMapWidth.Caption      := SPlacerMapWidth;
  LabelNudgeStep.Caption     := SPlacerNudgeStep;
  LabelColors.Caption        := SPlacerColors;
  LabelMapBack.Caption       := SPlacerMapBackColor;
  LabelMonitorEdge.Caption   := SPlacerMonitorEdgeColor;
  LabelFormFill.Caption      := SPlacerFormFillColor;
  LabelFormEdge.Caption      := SPlacerFormEdgeColor;
  LabelTitleBar.Caption      := SPlacerTitleBarColor;
end;

procedure TFormPlacerOptionsFrame.ReadSettings(AOptions: TAbstractIDEOptions);
begin
  CheckBoxShowMap.Checked      := FormPlacerOptions.ShowMap;
  CheckBoxLiveUpdate.Checked   := FormPlacerOptions.LiveUpdate;
  SpinEditMapWidth.Value       := FormPlacerOptions.MapWidth;
  SpinEditNudgeStep.Value      := FormPlacerOptions.NudgeStep;
  ColorBoxMapBack.Selected     := FormPlacerOptions.MapBackColor;
  ColorBoxMonitorEdge.Selected := FormPlacerOptions.MonitorEdgeColor;
  ColorBoxFormFill.Selected    := FormPlacerOptions.FormFillColor;
  ColorBoxFormEdge.Selected    := FormPlacerOptions.FormEdgeColor;
  ColorBoxTitleBar.Selected    := FormPlacerOptions.TitleBarColor;
end;

procedure TFormPlacerOptionsFrame.WriteSettings(AOptions: TAbstractIDEOptions);
begin
  FormPlacerOptions.ShowMap          := CheckBoxShowMap.Checked;
  FormPlacerOptions.LiveUpdate       := CheckBoxLiveUpdate.Checked;
  FormPlacerOptions.MapWidth         := SpinEditMapWidth.Value;
  FormPlacerOptions.NudgeStep        := SpinEditNudgeStep.Value;
  FormPlacerOptions.MapBackColor     := ColorBoxMapBack.Selected;
  FormPlacerOptions.MonitorEdgeColor := ColorBoxMonitorEdge.Selected;
  FormPlacerOptions.FormFillColor    := ColorBoxFormFill.Selected;
  FormPlacerOptions.FormEdgeColor    := ColorBoxFormEdge.Selected;
  FormPlacerOptions.TitleBarColor    := ColorBoxTitleBar.Selected;
  FormPlacerOptions.SaveSafe;
  ApplyOptionsToAllMaps;
end;

class function TFormPlacerOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result := IDEEditorGroups.GetByIndex(GroupEnvironment)^.GroupClass;
end;

end.
