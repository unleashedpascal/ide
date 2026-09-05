{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below.

  Unleashed Form Placer: persistent settings.

  Stored in unleashedformplacer.xml in the IDE configuration directory. }

unit FormPlacerConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  Graphics,
  // LazUtils
  LazConfigStorage, LazLoggerBase,
  // IdeIntf
  BaseIDEIntf;

const
  PlacerConfigFile = 'unleashedformplacer.xml';

type

  { TFormPlacerOptions }

  TFormPlacerOptions = class
  private const
    DefShowMap          = True;
    DefLiveUpdate       = True;
    DefMapWidth         = 160;
    DefNudgeStep        = 8;
    DefMapBackColor     = TColor($00404040);
    DefMonitorEdgeColor = TColor($00909090);
    DefFormFillColor    = clWhite;
    DefFormEdgeColor    = TColor($00606060);
    DefTitleBarColor    = TColor($00B26400);
  private
    FShowMap: Boolean;
    FLiveUpdate: Boolean;
    FMapWidth: Integer;
    FNudgeStep: Integer;
    FMapBackColor: TColor;
    FMonitorEdgeColor: TColor;
    FFormFillColor: TColor;
    FFormEdgeColor: TColor;
    FTitleBarColor: TColor;
    FOnChanged: TNotifyEvent;
    procedure DoChanged;
    procedure SetShowMap(AValue: Boolean);
    procedure SetLiveUpdate(AValue: Boolean);
    procedure SetMapWidth(AValue: Integer);
    procedure SetNudgeStep(AValue: Integer);
    procedure SetMapBackColor(AValue: TColor);
    procedure SetMonitorEdgeColor(AValue: TColor);
    procedure SetFormFillColor(AValue: TColor);
    procedure SetFormEdgeColor(AValue: TColor);
    procedure SetTitleBarColor(AValue: TColor);
  public
    constructor Create;
    procedure ResetToDefaults;
    procedure LoadSafe;
    procedure SaveSafe;
  public
    property ShowMap: Boolean read FShowMap write SetShowMap;
    property LiveUpdate: Boolean read FLiveUpdate write SetLiveUpdate;
    property MapWidth: Integer read FMapWidth write SetMapWidth;
    property NudgeStep: Integer read FNudgeStep write SetNudgeStep;
    property MapBackColor: TColor read FMapBackColor write SetMapBackColor;
    property MonitorEdgeColor: TColor read FMonitorEdgeColor write SetMonitorEdgeColor;
    property FormFillColor: TColor read FFormFillColor write SetFormFillColor;
    property FormEdgeColor: TColor read FFormEdgeColor write SetFormEdgeColor;
    property TitleBarColor: TColor read FTitleBarColor write SetTitleBarColor;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

var
  FormPlacerOptions: TFormPlacerOptions = nil;

implementation

{ TFormPlacerOptions }

constructor TFormPlacerOptions.Create;
begin
  inherited Create;
  ResetToDefaults;
end;

procedure TFormPlacerOptions.ResetToDefaults;
begin
  FShowMap          := DefShowMap;
  FLiveUpdate       := DefLiveUpdate;
  FMapWidth         := DefMapWidth;
  FNudgeStep        := DefNudgeStep;
  FMapBackColor     := DefMapBackColor;
  FMonitorEdgeColor := DefMonitorEdgeColor;
  FFormFillColor    := DefFormFillColor;
  FFormEdgeColor    := DefFormEdgeColor;
  FTitleBarColor    := DefTitleBarColor;
end;

procedure TFormPlacerOptions.DoChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TFormPlacerOptions.SetShowMap(AValue: Boolean);
begin
  if FShowMap = AValue then Exit;
  FShowMap := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetLiveUpdate(AValue: Boolean);
begin
  if FLiveUpdate = AValue then Exit;
  FLiveUpdate := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetMapWidth(AValue: Integer);
begin
  if AValue < 80 then AValue := 80;
  if AValue > 480 then AValue := 480;
  if FMapWidth = AValue then Exit;
  FMapWidth := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetNudgeStep(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  if AValue > 64 then AValue := 64;
  if FNudgeStep = AValue then Exit;
  FNudgeStep := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetMapBackColor(AValue: TColor);
begin
  if FMapBackColor = AValue then Exit;
  FMapBackColor := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetMonitorEdgeColor(AValue: TColor);
begin
  if FMonitorEdgeColor = AValue then Exit;
  FMonitorEdgeColor := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetFormFillColor(AValue: TColor);
begin
  if FFormFillColor = AValue then Exit;
  FFormFillColor := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetFormEdgeColor(AValue: TColor);
begin
  if FFormEdgeColor = AValue then Exit;
  FFormEdgeColor := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.SetTitleBarColor(AValue: TColor);
begin
  if FTitleBarColor = AValue then Exit;
  FTitleBarColor := AValue;
  DoChanged;
end;

procedure TFormPlacerOptions.LoadSafe;
var
  Cfg: TConfigStorage;
begin
  try
    Cfg := GetIDEConfigStorage(PlacerConfigFile, True);
    try
      FShowMap          := Cfg.GetValue('ShowMap/Value',          DefShowMap);
      FLiveUpdate       := Cfg.GetValue('LiveUpdate/Value',       DefLiveUpdate);
      FMapWidth         := Cfg.GetValue('MapWidth/Value',         DefMapWidth);
      FNudgeStep        := Cfg.GetValue('NudgeStep/Value',        DefNudgeStep);
      FMapBackColor     := Cfg.GetValue('MapBackColor/Value',     DefMapBackColor);
      FMonitorEdgeColor := Cfg.GetValue('MonitorEdgeColor/Value', DefMonitorEdgeColor);
      FFormFillColor    := Cfg.GetValue('FormFillColor/Value',    DefFormFillColor);
      FFormEdgeColor    := Cfg.GetValue('FormEdgeColor/Value',    DefFormEdgeColor);
      FTitleBarColor    := Cfg.GetValue('TitleBarColor/Value',    DefTitleBarColor);
    finally
      Cfg.Free;
    end;
  except
    on E: Exception do
      DebugLn(['Error: (UnleashedFormplacer) [TFormPlacerOptions.LoadSafe] ', E.Message]);
  end;
end;

procedure TFormPlacerOptions.SaveSafe;
var
  Cfg: TConfigStorage;
begin
  try
    Cfg := GetIDEConfigStorage(PlacerConfigFile, False);
    try
      Cfg.SetDeleteValue('ShowMap/Value',          FShowMap,          DefShowMap);
      Cfg.SetDeleteValue('LiveUpdate/Value',       FLiveUpdate,       DefLiveUpdate);
      Cfg.SetDeleteValue('MapWidth/Value',         FMapWidth,         DefMapWidth);
      Cfg.SetDeleteValue('NudgeStep/Value',        FNudgeStep,        DefNudgeStep);
      Cfg.SetDeleteValue('MapBackColor/Value',     FMapBackColor,     DefMapBackColor);
      Cfg.SetDeleteValue('MonitorEdgeColor/Value', FMonitorEdgeColor, DefMonitorEdgeColor);
      Cfg.SetDeleteValue('FormFillColor/Value',    FFormFillColor,    DefFormFillColor);
      Cfg.SetDeleteValue('FormEdgeColor/Value',    FFormEdgeColor,    DefFormEdgeColor);
      Cfg.SetDeleteValue('TitleBarColor/Value',    FTitleBarColor,    DefTitleBarColor);
    finally
      Cfg.Free;
    end;
  except
    on E: Exception do
      DebugLn(['Error: (UnleashedFormplacer) [TFormPlacerOptions.SaveSafe] ', E.Message]);
  end;
end;

initialization
  FormPlacerOptions := TFormPlacerOptions.Create;

finalization
  FreeAndNil(FormPlacerOptions);

end.
