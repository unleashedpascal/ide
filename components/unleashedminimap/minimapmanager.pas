{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit MiniMapManager;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Forms, SrcEditorIntf, MiniMapConfig, MiniMapView;

type

  { keeps one map per open source editor, driven by the editor lifecycle
    events of the source editor manager }

  TMiniMapManager = class(TComponent)
  private
    fViews: TFPList;
    fSettings: TMapSettings;
    fHooked: boolean;
    function viewCount: integer;
    function viewAt(index: integer): TMiniMapView;
    function viewFor(aEditor: TSourceEditorInterface): TMiniMapView;
    procedure configView(view: TMiniMapView);
    procedure hookEvents(enable: boolean);
    procedure attachOpenEditors;
    procedure detachAll;
    procedure editorCreated(Sender: TObject);
    procedure editorReconfigured(Sender: TObject);
    procedure editorDestroyed(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    procedure loadConfig;
    procedure saveConfig;
    procedure applySettings(const src: TMapSettings);
    procedure toggleShown;
    property settings: TMapSettings read fSettings;
  end;

var
  mapManager: TMiniMapManager = nil;

implementation

constructor TMiniMapManager.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fViews := TFPList.Create;
  fSettings := defaultMapSettings;
end;

destructor TMiniMapManager.Destroy;
begin
  hookEvents(False);
  fViews.Free;
  inherited Destroy;
end;

function TMiniMapManager.viewCount: integer;
begin
  result := fViews.Count;
end;

function TMiniMapManager.viewAt(index: integer): TMiniMapView;
begin
  result := TMiniMapView(fViews[index]);
end;

function TMiniMapManager.viewFor(aEditor: TSourceEditorInterface): TMiniMapView;
begin
  result := nil;
  for var i := 0 to viewCount-1 do
    if viewAt(i).editor = aEditor then exit(viewAt(i));
end;

procedure TMiniMapManager.configView(view: TMiniMapView);
begin
  view.Width := fSettings.mapWidth;
  view.bandColor := fSettings.bandColor;
  view.bandTint := fSettings.bandTint;
  view.fontSize := fSettings.fontSize;
  view.updateLayout;
end;

procedure TMiniMapManager.hookEvents(enable: boolean);
begin
  if (fHooked = enable) or (SourceEditorManagerIntf = nil) then exit;
  fHooked := enable;
  if enable then begin
    SourceEditorManagerIntf.RegisterChangeEvent(semEditorCreate, @editorCreated);
    SourceEditorManagerIntf.RegisterChangeEvent(semEditorMoved, @editorCreated);
    SourceEditorManagerIntf.RegisterChangeEvent(semEditorCloned, @editorCreated);
    SourceEditorManagerIntf.RegisterChangeEvent(semEditorReConfigured, @editorReconfigured);
    SourceEditorManagerIntf.RegisterChangeEvent(semEditorDestroy, @editorDestroyed);
  end else begin
    SourceEditorManagerIntf.UnRegisterChangeEvent(semEditorCreate, @editorCreated);
    SourceEditorManagerIntf.UnRegisterChangeEvent(semEditorMoved, @editorCreated);
    SourceEditorManagerIntf.UnRegisterChangeEvent(semEditorCloned, @editorCreated);
    SourceEditorManagerIntf.UnRegisterChangeEvent(semEditorReConfigured, @editorReconfigured);
    SourceEditorManagerIntf.UnRegisterChangeEvent(semEditorDestroy, @editorDestroyed);
  end;
end;

procedure TMiniMapManager.attachOpenEditors;
begin
  if SourceEditorManagerIntf = nil then exit;
  for var i := 0 to SourceEditorManagerIntf.SourceEditorCount-1 do
    editorCreated(SourceEditorManagerIntf.SourceEditors[i]);
end;

procedure TMiniMapManager.detachAll;
begin
  while viewCount > 0 do begin
    var view := viewAt(viewCount-1);
    fViews.Delete(viewCount-1);
    view.unhook;
    view.Hide;
    Application.ReleaseComponent(view);
  end;
end;

procedure TMiniMapManager.editorCreated(Sender: TObject);
begin
  var ed := TSourceEditorInterface(Sender);
  if viewFor(ed) <> nil then exit;
  var win := SourceEditorManagerIntf.SourceWindowWithEditor(ed);
  if win = nil then exit;
  var view := TMiniMapView.Create(win);
  fViews.Add(view);
  view.FreeNotification(self);
  configView(view);
  view.editor := ed; // parents the map inside the editor
end;

procedure TMiniMapManager.editorReconfigured(Sender: TObject);
begin
  var view := viewFor(TSourceEditorInterface(Sender));
  if view <> nil then view.reconfigure;
end;

procedure TMiniMapManager.editorDestroyed(Sender: TObject);
begin
  var view := viewFor(TSourceEditorInterface(Sender));
  if view = nil then exit;
  fViews.Remove(view);
  view.unhook;
  view.Hide;
  Application.ReleaseComponent(view);
end;

procedure TMiniMapManager.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent is TMiniMapView) then fViews.Remove(AComponent);
end;

procedure TMiniMapManager.loadConfig;
begin
  applySettings(loadMapSettings);
end;

procedure TMiniMapManager.saveConfig;
begin
  saveMapSettings(fSettings);
end;

procedure TMiniMapManager.applySettings(const src: TMapSettings);
begin
  fSettings := clampMapSettings(src);
  hookEvents(fSettings.shown);
  if not fSettings.shown then begin
    detachAll;
    exit;
  end;
  attachOpenEditors;
  for var i := 0 to viewCount-1 do begin
    configView(viewAt(i));
    viewAt(i).reconfigure;
  end;
end;

procedure TMiniMapManager.toggleShown;
begin
  var next := fSettings;
  next.shown := not next.shown;
  applySettings(next);
  saveConfig;
end;

end.
