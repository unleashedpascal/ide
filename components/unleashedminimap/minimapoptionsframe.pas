{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit MiniMapOptionsFrame;

{$mode unleashed}

interface

uses
  Classes, Forms, StdCtrls, Spin, ColorBox, IDEOptionsIntf, IDEOptEditorIntf, MiniMapConfig, MiniMapManager, MiniMapStrings;

type

  { TMiniMapOptionsFrame }

  // the Code Minimap page of the IDE options, under Editor
  TMiniMapOptionsFrame = class(TAbstractIDEOptionsEditor)
    CheckBoxShowMap: TCheckBox;
    LabelMapWidth: TLabel;
    SpinEditMapWidth: TSpinEdit;
    LabelFontSize: TLabel;
    SpinEditFontSize: TSpinEdit;
    ButtonResetDefaults: TButton;
    CheckBoxFollowTheme: TCheckBox;
    LabelViewport: TLabel;
    LabelBandColor: TLabel;
    ColorBoxBandColor: TColorBox;
    LabelBandTint: TLabel;
    SpinEditBandTint: TSpinEdit;
    procedure CheckBoxFollowThemeChange(Sender: TObject);
    procedure ButtonResetDefaultsClick(Sender: TObject);
  private
    procedure showSettings(const src: TMapSettings);
  public
    function GetTitle: string; override;
    procedure Setup({%H-}ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings({%H-}AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings({%H-}AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

implementation

{$R *.lfm}

{ TMiniMapOptionsFrame }

function TMiniMapOptionsFrame.GetTitle: string;
begin
  result := OPTIONS_TITLE;
end;

procedure TMiniMapOptionsFrame.Setup(ADialog: TAbstractOptionsEditorDialog);
begin
  CheckBoxShowMap.Caption := OPTIONS_SHOW_MAP;
  LabelMapWidth.Caption := OPTIONS_WIDTH;
  LabelFontSize.Caption := OPTIONS_FONT_SIZE;
  ButtonResetDefaults.Caption := OPTIONS_RESET;
  CheckBoxFollowTheme.Caption := OPTIONS_FOLLOW_THEME;
  LabelViewport.Caption := OPTIONS_VIEWPORT;
  LabelBandColor.Caption := OPTIONS_BAND_COLOR;
  LabelBandTint.Caption := OPTIONS_BAND_TINT;
  ColorBoxBandColor.Hint := OPTIONS_COLOR_HINT;
  SpinEditMapWidth.MinValue := MAP_WIDTH_MIN;
  SpinEditMapWidth.MaxValue := MAP_WIDTH_MAX;
  SpinEditFontSize.MinValue := FONT_SIZE_MIN;
  SpinEditFontSize.MaxValue := FONT_SIZE_MAX;
  SpinEditBandTint.MinValue := BAND_TINT_MIN;
  SpinEditBandTint.MaxValue := BAND_TINT_MAX;
end;

procedure TMiniMapOptionsFrame.showSettings(const src: TMapSettings);
begin
  SpinEditMapWidth.Value := src.mapWidth;
  SpinEditFontSize.Value := src.fontSize;
  CheckBoxFollowTheme.Checked := src.followTheme;
  ColorBoxBandColor.Selected := src.bandColor;
  SpinEditBandTint.Value := src.bandTint;
  CheckBoxFollowThemeChange(nil);
end;

procedure TMiniMapOptionsFrame.ReadSettings(AOptions: TAbstractIDEOptions);
begin
  if mapManager = nil then exit;
  // the reset to defaults keeps the map as it is, so shown stays out of showSettings
  CheckBoxShowMap.Checked := mapManager.settings.shown;
  showSettings(mapManager.settings);
end;

procedure TMiniMapOptionsFrame.WriteSettings(AOptions: TAbstractIDEOptions);
begin
  if mapManager = nil then exit;
  var next := mapManager.settings;
  next.shown := CheckBoxShowMap.Checked;
  next.mapWidth := SpinEditMapWidth.Value;
  next.fontSize := SpinEditFontSize.Value;
  next.followTheme := CheckBoxFollowTheme.Checked;
  next.bandColor := ColorBoxBandColor.Selected;
  next.bandTint := SpinEditBandTint.Value;
  mapManager.applySettings(next);
  mapManager.saveConfig;
end;

class function TMiniMapOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  result := IDEEditorGroups.GetByIndex(GroupEditor)^.GroupClass;
end;

// the own tint only matters while the band does not follow the theme
procedure TMiniMapOptionsFrame.CheckBoxFollowThemeChange(Sender: TObject);
begin
  ColorBoxBandColor.Enabled := not CheckBoxFollowTheme.Checked;
  SpinEditBandTint.Enabled := not CheckBoxFollowTheme.Checked;
end;

procedure TMiniMapOptionsFrame.ButtonResetDefaultsClick(Sender: TObject);
begin
  showSettings(defaultMapSettings);
end;

end.
