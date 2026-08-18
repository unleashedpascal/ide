{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit MiniMapSetupDlg;

{$mode unleashed}

interface

uses
  Classes, Controls, Forms, StdCtrls, Spin, ColorBox, Graphics, MiniMapConfig, MiniMapStrings;

// runs the setup dialog; returns True and the edited settings when accepted
function editMapSettings(var src: TMapSettings): boolean;

implementation

const
  MARGIN     = 12;
  ROW_GAP    = 8;
  LABEL_WIDE = 230;
  EDIT_WIDE  = 120;

type

  { TSetupForm }

  TSetupForm = class(TForm)
  private
    fWidth: TSpinEdit;
    fFontSize: TSpinEdit;
    fBandColor: TColorBox;
    fBandTint: TSpinEdit;
    fRow: integer;
    function addSpin(const title: string; low, high: integer): TSpinEdit;
    procedure addColor(const title: string);
    procedure addButtons;
  public
    constructor CreateNew(aOwner: TComponent; num: Integer = 0); override;
    procedure loadFrom(const src: TMapSettings);
    procedure storeInto(var dst: TMapSettings);
  end;

function labelAt(parent: TWinControl; top: integer; const caption: string): TLabel;
begin
  result := TLabel.Create(parent);
  result.Parent := parent;
  result.Left := MARGIN;
  result.Top := top+3;
  result.Width := LABEL_WIDE;
  result.Caption := caption;
end;

constructor TSetupForm.CreateNew(aOwner: TComponent; num: Integer);
begin
  inherited CreateNew(aOwner, num);
  Caption := SETUP_CAPTION;
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  ClientWidth := MARGIN*2+LABEL_WIDE+EDIT_WIDE;
  fRow := MARGIN;

  fWidth := addSpin(SETUP_WIDTH, MAP_WIDTH_MIN, MAP_WIDTH_MAX);
  fWidth.Increment := 10;
  fFontSize := addSpin(SETUP_FONT_SIZE, FONT_SIZE_MIN, FONT_SIZE_MAX);
  addColor(SETUP_BAND_COLOR);
  fBandTint := addSpin(SETUP_BAND_TINT, BAND_TINT_MIN, BAND_TINT_MAX);
  addButtons;
end;

function TSetupForm.addSpin(const title: string; low, high: integer): TSpinEdit;
begin
  labelAt(self, fRow, title);
  result := TSpinEdit.Create(self);
  result.Parent := self;
  result.Left := MARGIN+LABEL_WIDE;
  result.Top := fRow;
  result.Width := EDIT_WIDE;
  result.MinValue := low;
  result.MaxValue := high;
  inc(fRow, result.Height+ROW_GAP);
end;

procedure TSetupForm.addColor(const title: string);
begin
  labelAt(self, fRow, title);
  fBandColor := TColorBox.Create(self);
  fBandColor.Parent := self;
  fBandColor.Left := MARGIN+LABEL_WIDE;
  fBandColor.Top := fRow;
  fBandColor.Width := EDIT_WIDE;
  fBandColor.DefaultColorColor := clDefault;
  fBandColor.Style := [cbStandardColors, cbExtendedColors, cbIncludeDefault, cbCustomColor, cbPrettyNames];
  fBandColor.Hint := SETUP_COLOR_HINT;
  fBandColor.ShowHint := True;
  inc(fRow, fBandColor.Height+ROW_GAP);
end;

procedure TSetupForm.addButtons;
begin
  inc(fRow, ROW_GAP);
  var ok := TButton.Create(self);
  ok.Parent := self;
  ok.Caption := SETUP_OK;
  ok.ModalResult := mrOk;
  ok.Default := True;
  ok.Top := fRow;
  ok.Width := 90;
  ok.Left := ClientWidth-MARGIN-90*2-ROW_GAP;

  var cancel := TButton.Create(self);
  cancel.Parent := self;
  cancel.Caption := SETUP_CANCEL;
  cancel.ModalResult := mrCancel;
  cancel.Cancel := True;
  cancel.Top := fRow;
  cancel.Width := 90;
  cancel.Left := ClientWidth-MARGIN-90;

  ClientHeight := fRow+ok.Height+MARGIN;
end;

procedure TSetupForm.loadFrom(const src: TMapSettings);
begin
  fWidth.Value := src.mapWidth;
  fFontSize.Value := src.fontSize;
  fBandColor.Selected := src.bandColor;
  fBandTint.Value := src.bandTint;
end;

procedure TSetupForm.storeInto(var dst: TMapSettings);
begin
  dst.mapWidth := fWidth.Value;
  dst.fontSize := fFontSize.Value;
  dst.bandColor := fBandColor.Selected;
  dst.bandTint := fBandTint.Value;
end;

function editMapSettings(var src: TMapSettings): boolean;
begin
  result := False;
  var form := autofree TSetupForm.CreateNew(Application);
  form.loadFrom(src);
  if form.ShowModal <> mrOk then exit;
  form.storeInto(src);
  src := clampMapSettings(src);
  result := True;
end;

end.
