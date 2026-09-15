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
    ButtonResetDefaults: TButton;
    CheckBoxFollowTheme: TCheckBox;
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
    ButtonResetColors: TButton;
    procedure CheckBoxFollowThemeChange(Sender: TObject);
    procedure ButtonResetColorsClick(Sender: TObject);
    procedure ButtonResetDefaultsClick(Sender: TObject);
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
  CheckBoxFollowTheme.Caption := SPlacerFollowTheme;
  ButtonResetColors.Caption  := SPlacerResetColors;
  ButtonResetDefaults.Caption := SPlacerResetDefaults;
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
  CheckBoxFollowTheme.Checked  := FormPlacerOptions.FollowTheme;
  ColorBoxMapBack.Selected     := FormPlacerOptions.MapBackColor;
  ColorBoxMonitorEdge.Selected := FormPlacerOptions.MonitorEdgeColor;
  ColorBoxFormFill.Selected    := FormPlacerOptions.FormFillColor;
  ColorBoxFormEdge.Selected    := FormPlacerOptions.FormEdgeColor;
  ColorBoxTitleBar.Selected    := FormPlacerOptions.TitleBarColor;
  CheckBoxFollowThemeChange(nil);
end;

procedure TFormPlacerOptionsFrame.WriteSettings(AOptions: TAbstractIDEOptions);
begin
  FormPlacerOptions.ShowMap          := CheckBoxShowMap.Checked;
  FormPlacerOptions.LiveUpdate       := CheckBoxLiveUpdate.Checked;
  FormPlacerOptions.MapWidth         := SpinEditMapWidth.Value;
  FormPlacerOptions.NudgeStep        := SpinEditNudgeStep.Value;
  FormPlacerOptions.FollowTheme      := CheckBoxFollowTheme.Checked;
  FormPlacerOptions.MapBackColor     := ColorBoxMapBack.Selected;
  FormPlacerOptions.MonitorEdgeColor := ColorBoxMonitorEdge.Selected;
  FormPlacerOptions.FormFillColor    := ColorBoxFormFill.Selected;
  FormPlacerOptions.FormEdgeColor    := ColorBoxFormEdge.Selected;
  FormPlacerOptions.TitleBarColor    := ColorBoxTitleBar.Selected;
  FormPlacerOptions.SaveSafe;
  ApplyOptionsToAllMaps;
end;

// the own colors only matter while the map does not follow the theme
procedure TFormPlacerOptionsFrame.CheckBoxFollowThemeChange(Sender: TObject);
begin
  ColorBoxMapBack.Enabled     := not CheckBoxFollowTheme.Checked;
  ColorBoxMonitorEdge.Enabled := not CheckBoxFollowTheme.Checked;
  ColorBoxFormFill.Enabled    := not CheckBoxFollowTheme.Checked;
  ColorBoxFormEdge.Enabled    := not CheckBoxFollowTheme.Checked;
  ColorBoxTitleBar.Enabled    := not CheckBoxFollowTheme.Checked;
  ButtonResetColors.Enabled   := not CheckBoxFollowTheme.Checked;
end;

// the settings apart from the own colors, which have their own button
procedure TFormPlacerOptionsFrame.ButtonResetDefaultsClick(Sender: TObject);
begin
  CheckBoxShowMap.Checked     := TFormPlacerOptions.DefShowMap;
  CheckBoxLiveUpdate.Checked  := TFormPlacerOptions.DefLiveUpdate;
  SpinEditMapWidth.Value      := TFormPlacerOptions.DefMapWidth;
  SpinEditNudgeStep.Value     := TFormPlacerOptions.DefNudgeStep;
  CheckBoxFollowTheme.Checked := TFormPlacerOptions.DefFollowTheme;
end;

procedure TFormPlacerOptionsFrame.ButtonResetColorsClick(Sender: TObject);
begin
  ColorBoxMapBack.Selected     := TFormPlacerOptions.DefMapBackColor;
  ColorBoxMonitorEdge.Selected := TFormPlacerOptions.DefMonitorEdgeColor;
  ColorBoxFormFill.Selected    := TFormPlacerOptions.DefFormFillColor;
  ColorBoxFormEdge.Selected    := TFormPlacerOptions.DefFormEdgeColor;
  ColorBoxTitleBar.Selected    := TFormPlacerOptions.DefTitleBarColor;
end;

class function TFormPlacerOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result := IDEEditorGroups.GetByIndex(GroupEnvironment)^.GroupClass;
end;

end.
