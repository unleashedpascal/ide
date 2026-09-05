{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below.

  Unleashed Form Placer: IDE registration.

  Attaches a desktop map to the resizer area of every docked form designer
  page. Does nothing when the docked form editor is disabled. }

unit RegUnleashedFormplacer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  LCLIntf, LCLType, Controls, Forms,
  // IdeIntf
  LazIDEIntf, IDEOptEditorIntf, IDEOptionsIntf,
  // DockedFormEditor
  DockedSourceWindow, DockedSourcePageControl, DockedResizer,
  // UnleashedFormplacer
  FormPlacerConfig, FormPlacerMap, FormPlacerOptionsFrame;

var
  PlacerOptionsFrameID: Integer = 1010;

procedure Register;

implementation

type

  { TPlacerManager }

  { A single instance created in Register. Maps are attached and kept in
    sync from an idle handler: the docked form editor assigns the design
    form of a page from its own editor handlers and from tab changes, so
    there is no single event that fires once the page is complete. }
  TPlacerManager = class
  private
    procedure AppIdle({%H-}Sender: TObject; var {%H-}Done: Boolean);
    procedure OptionsChanged({%H-}Sender: TObject);
    procedure OpenOptions({%H-}Sender: TObject);
    procedure AttachTo(APageCtrl: TSourcePageControl);
    procedure SyncAllPages;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  PlacerManager: TPlacerManager = nil;

constructor TPlacerManager.Create;
begin
  inherited Create;
  FormPlacerOptions.OnChanged := @OptionsChanged;
  Application.AddOnIdleHandler(@AppIdle);
end;

destructor TPlacerManager.Destroy;
begin
  if Assigned(Application) then
    Application.RemoveOnIdleHandler(@AppIdle);
  if Assigned(FormPlacerOptions) then
    FormPlacerOptions.OnChanged := nil;
  inherited Destroy;
end;

procedure TPlacerManager.AttachTo(APageCtrl: TSourcePageControl);
var
  LResizer: TResizer;
  LMap: TFormPlacerMap;
  i: Integer;
begin
  if APageCtrl = nil then Exit;
  LResizer := APageCtrl.Resizer;
  if LResizer = nil then Exit;

  LMap := nil;
  for i := 0 to LResizer.ControlCount - 1 do
    if LResizer.Controls[i] is TFormPlacerMap then
    begin
      LMap := TFormPlacerMap(LResizer.Controls[i]);
      Break;
    end;

  if LMap = nil then
  begin
    LMap := TFormPlacerMap.Create(LResizer);
    LMap.Parent := LResizer;
    LMap.AnchorSideRight.Control := LResizer;
    LMap.AnchorSideRight.Side := asrBottom;
    LMap.AnchorSideBottom.Control := LResizer;
    LMap.AnchorSideBottom.Side := asrBottom;
    LMap.Anchors := [akRight, akBottom];
    LMap.BorderSpacing.Right := 6 + GetSystemMetrics(SM_CXVSCROLL);
    LMap.BorderSpacing.Bottom := 6 + GetSystemMetrics(SM_CYHSCROLL);
    LMap.OnOpenOptions := @OpenOptions;
    LMap.BringToFront;
  end;

  LMap.BindDesignForm(APageCtrl.DesignForm);
end;

procedure TPlacerManager.SyncAllPages;
var
  LSourceWindow: TSourceWindow;
  LPageCtrl: TSourcePageControl;
begin
  if SourceWindows = nil then Exit;
  for LSourceWindow in SourceWindows do
    for LPageCtrl in LSourceWindow.PageControlList do
      AttachTo(LPageCtrl);
end;

procedure TPlacerManager.AppIdle(Sender: TObject; var Done: Boolean);
begin
  SyncAllPages;
end;

procedure TPlacerManager.OptionsChanged(Sender: TObject);
begin
  ApplyOptionsToAllMaps;
end;

procedure TPlacerManager.OpenOptions(Sender: TObject);
begin
  LazarusIDE.DoOpenIDEOptions(TFormPlacerOptionsFrame);
end;

procedure Register;
begin
  // Static packages register in unit initialization order, which can put
  // this package before DockedFormEditor. SourceWindows may therefore not
  // exist yet; the idle handler waits for it (and stays idle when the docked
  // designer is disabled).
  FormPlacerOptions.LoadSafe;
  PlacerManager := TPlacerManager.Create;

  PlacerOptionsFrameID := RegisterIDEOptionsEditor(GroupEnvironment,
    TFormPlacerOptionsFrame, PlacerOptionsFrameID)^.Index;
end;

finalization
  FreeAndNil(PlacerManager);

end.
