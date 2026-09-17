{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PanesOptionsFrame;

{$mode unleashed}

interface

uses
  Classes, Forms, StdCtrls, Spin, IDEOptionsIntf, IDEOptEditorIntf, PanesConfig, PanesMaster, PanesStrings;

type

  { TPanesOptionsFrame }

  // the Panes page of the IDE options, under Editor
  TPanesOptionsFrame = class(TAbstractIDEOptionsEditor)
    CheckBoxHeaders: TCheckBox;
    LabelPadding: TLabel;
    SpinEditPadding: TSpinEdit;
    ButtonResetDefaults: TButton;
    procedure ButtonResetDefaultsClick(Sender: TObject);
  private
    procedure showSettings(const src: TPaneSettings);
  public
    function GetTitle: string; override;
    procedure Setup({%H-}ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings({%H-}AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings({%H-}AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

var
  // the live settings, applied to the frames and saved on every change
  paneSettings: TPaneSettings;

// pushes the settings into the frames and stores them
procedure applyPaneSettings(const src: TPaneSettings);

implementation

{$R *.lfm}

procedure applyPaneSettings(const src: TPaneSettings);
begin
  paneSettings := clampPaneSettings(src);
  if dockMaster <> nil then dockMaster.applySettings(paneSettings.headerShown, paneSettings.padding);
  savePaneSettings(paneSettings);
end;

{ TPanesOptionsFrame }

function TPanesOptionsFrame.GetTitle: string;
begin
  result := OPTIONS_TITLE;
end;

procedure TPanesOptionsFrame.Setup(ADialog: TAbstractOptionsEditorDialog);
begin
  CheckBoxHeaders.Caption := OPTIONS_HEADERS;
  LabelPadding.Caption := OPTIONS_PADDING;
  ButtonResetDefaults.Caption := OPTIONS_RESET;
  SpinEditPadding.MinValue := PADDING_MIN;
  SpinEditPadding.MaxValue := PADDING_MAX;
end;

procedure TPanesOptionsFrame.showSettings(const src: TPaneSettings);
begin
  CheckBoxHeaders.Checked := src.headerShown;
  SpinEditPadding.Value := src.padding;
end;

procedure TPanesOptionsFrame.ReadSettings(AOptions: TAbstractIDEOptions);
begin
  showSettings(paneSettings);
end;

procedure TPanesOptionsFrame.WriteSettings(AOptions: TAbstractIDEOptions);
begin
  var next := paneSettings;
  next.headerShown := CheckBoxHeaders.Checked;
  next.padding := SpinEditPadding.Value;
  applyPaneSettings(next);
end;

class function TPanesOptionsFrame.SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  result := IDEEditorGroups.GetByIndex(GroupEditor)^.GroupClass;
end;

procedure TPanesOptionsFrame.ButtonResetDefaultsClick(Sender: TObject);
begin
  showSettings(defaultPaneSettings);
end;

end.
