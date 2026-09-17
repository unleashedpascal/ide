{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit RegUnleashedPanes;

{$mode unleashed}

interface

procedure Register;

implementation

uses
  Classes, SysUtils, Forms, Controls, Menus, LazFileUtils, IDECommands, IDEWindowIntf, MenuIntf, LazIDEIntf, SrcEditorIntf, ProjectIntf, ProjPackIntf, IDEOptionsIntf, IDEOptEditorIntf, MiniMapManager, PanesLayout, PanesMaster, PanesStrings, PanesConfig, PanesOptionsFrame;

const
  // right behind the Code Minimap page of the editor group
  OPTIONS_FRAME_ID = 1012;

type

  { TMenuGlue }

  TMenuGlue = class(TComponent)
    procedure menuShow(Sender: TObject);
    procedure identifyClick(Sender: TObject);
    procedure headersClick(Sender: TObject);
    procedure paneClick(Sender: TObject);
    procedure newPaneWindowClick(Sender: TObject);
    procedure newEditorWindowClick(Sender: TObject);
    procedure newDesignerWindowClick(Sender: TObject);
    procedure windowViewShow(Sender: TObject);
    procedure windowCodeMapClick(Sender: TObject);
    procedure windowFormsShow(Sender: TObject);
    procedure windowFormClick(Sender: TObject);
    procedure windowCreated(Sender: TObject);
    procedure windowPanesShow(Sender: TObject);
    procedure windowPaneClick(Sender: TObject);
  end;

const
  // Tag of the fixed items of a window menu; the pane items carry their index in names
  TAG_NONE = -1;
  TAG_IDENTIFY = -2;
  TAG_DEBUG = -3;
  TAG_HEADERS = -4;
  TAG_DESIGNER = -5;
  // Tag of the Forms and Frames menus: the base class of the units they list
  TAG_FORMS = -6;
  TAG_FRAMES = -7;
  TAG_CODE_MAP = -8;
  // the separator closing the pane list; new panes go in front of it
  TAG_LIST_END = -9;

var
  glue: TMenuGlue = nil;
  panesMenu: TIDEMenuSection = nil;
  listSection: TIDEMenuSection = nil;
  debugSection: TIDEMenuSection = nil;
  identifyItem: TIDEMenuCommand = nil;
  headersItem: TIDEMenuCommand = nil;
  designerItem: TIDEMenuCommand = nil;
  // pane name per command, the command index is the UserTag
  names: TStringList = nil;

function designerAvailable: boolean; forward;
function runEditorCommand(command: word): boolean; forward;

function isDebugPane(const descriptor: TPaneDescriptor): boolean;
begin
  result := pfDebug in descriptor.flags;
end;

procedure ensureCommand(const name, caption: string; parent: TIDEMenuSection);
begin
  if names.IndexOf(name) >= 0 then exit;
  var command := RegisterIDEMenuCommand(parent, 'itmPane'+name, caption, @glue.paneClick);
  command.UserTag := names.AddObject(name, command);
end;

// the IDE registers its window creators after the packages, so the list grows on every show
procedure buildList;
begin
  for var i := 0 to descriptorCount-1 do begin
    var descriptor := descriptors(i);
    ensureCommand(descriptor.name, descriptor.caption, if isDebugPane(descriptor) then debugSection else listSection);
  end;
  for var i := 0 to IDEWindowCreators.Count-1 do begin
    var creator := IDEWindowCreators[i];
    if creator.Multi or SameText(creator.FormName, 'MainIDE') or SameText(creator.FormName, 'SourceNotebook') then continue;
    var caption := creator.FormName;
    var form := Screen.FindForm(creator.FormName);
    if (form <> nil) and (form.Caption <> '') then caption := form.Caption;
    ensureCommand(creator.FormName, caption, listSection);
  end;
end;

// the instance of the pane docked inside the given window; a pane that
// allows copies may sit there as ProjectInspector2 and so on
function instanceIn(const name: string; window: TCustomForm): TCustomForm;
begin
  result := nil;
  if dockMaster = nil then exit;
  for var i := 0 to Screen.CustomFormCount-1 do begin
    var form := Screen.CustomForms[i];
    if not SameText(copy(form.Name, 1, Length(name)), name) then continue;
    var tail := copy(form.Name, Length(name)+1, MaxInt);
    if (tail <> '') and ((StrToIntDef(tail, -1) < 0) or not (pfCanDuplicate in descriptorOf(name).flags)) then continue;
    if dockMaster.isDocked(form) and (GetParentForm(form) = window) then exit(form);
  end;
end;

function shownIn(const name: string; window: TCustomForm): boolean;
begin
  result := instanceIn(name, window) <> nil;
end;

// checked = shown inside the given window
procedure refreshChecks(window: TCustomForm);
begin
  for var i := 0 to names.Count-1 do TIDEMenuCommand(names.Objects[i]).Checked := shownIn(names[i], window);
end;

// closes the pane when it is in the window, otherwise opens it there
procedure togglePane(const name: string; window: TCustomForm; host: TPaneHost);
begin
  if dockMaster = nil then exit;
  var form := instanceIn(name, window);
  if form <> nil then begin
    if TPaneFrame(form.Parent).closable then form.Close;
    exit;
  end;
  var target := name;
  form := Screen.FindForm(name);
  // a pane that allows copies opens another instance instead of pulling the first one over
  if (form <> nil) and dockMaster.isDocked(form) and (pfCanDuplicate in descriptorOf(name).flags) then begin
    var n := 2;
    while Screen.FindForm(name+IntToStr(n)) <> nil do inc(n);
    if IDEWindowCreators.GetForm(name+IntToStr(n), true, false) <> nil then target := name+IntToStr(n);
  end;
  dockMaster.targetHost := host;
  try
    IDEWindowCreators.ShowForm(target, true);
  finally
    dockMaster.targetHost := nil;
  end;
end;

procedure TMenuGlue.menuShow(Sender: TObject);
begin
  buildList;
  if dockMaster = nil then exit;
  refreshChecks(dockMaster.mainBar);
  identifyItem.Checked := dockMaster.identify;
  headersItem.Checked := paneSettings.headerShown;
  designerItem.Enabled := designerAvailable;
end;

// the active editor edits a unit with a form that no designer window shows yet
function designerAvailable: boolean;
begin
  result := false;
  if (SourceEditorManagerIntf = nil) or (LazarusIDE = nil) or (IDETabMaster = nil) or (dockMaster = nil) then exit;
  var editor := SourceEditorManagerIntf.ActiveEditor;
  if editor = nil then exit;
  var projectFile := editor.GetProjectFile;
  result := (projectFile <> nil) and (LazarusIDE.GetDesignerWithProjectFile(projectFile, false) <> nil) and (dockMaster.designerWindowOf(editor.FileName) = nil);
end;

// editor window commands run through the active editor, the IDE command list
// does not route them
function runEditorCommand(command: word): boolean;
begin
  result := false;
  if SourceEditorManagerIntf = nil then exit;
  var editor := SourceEditorManagerIntf.ActiveEditor;
  if editor = nil then exit;
  if editor.EditorControl.CanFocus then editor.EditorControl.SetFocus;
  editor.DoEditorExecuteCommand(command);
  result := true;
end;

procedure TMenuGlue.identifyClick(Sender: TObject);
begin
  if dockMaster <> nil then dockMaster.identify := not dockMaster.identify;
end;

procedure TMenuGlue.headersClick(Sender: TObject);
begin
  var next := paneSettings;
  next.headerShown := not next.headerShown;
  applyPaneSettings(next);
end;

procedure TMenuGlue.paneClick(Sender: TObject);
begin
  var command := TIDEMenuCommand(Sender);
  if command.UserTag >= names.Count then exit;
  if dockMaster = nil then exit;
  togglePane(names[command.UserTag], dockMaster.mainBar, dockMaster.mainHost);
end;

procedure TMenuGlue.newPaneWindowClick(Sender: TObject);
begin
  if dockMaster = nil then exit;
  dockMaster.createWindow.Show;
end;

procedure TMenuGlue.newEditorWindowClick(Sender: TObject);
begin
  runEditorCommand(ecCopyEditorNewWindow);
end;

// a copy of the active editor in a designer window, switched to its form
procedure TMenuGlue.newDesignerWindowClick(Sender: TObject);
begin
  if (dockMaster = nil) or not designerAvailable then exit;
  dockMaster.pendingDesigner := true;
  try
    if not runEditorCommand(ecCopyEditorNewWindow) then exit;
  finally
    dockMaster.pendingDesigner := false;
  end;
  runEditorCommand(ecToggleFormUnit);
end;

function windowOf(Sender: TObject): TDockWindow;
begin
  result := nil;
  if (Sender is TComponent) and (TComponent(Sender).Owner is TDockWindow) then result := TDockWindow(TComponent(Sender).Owner);
end;

function addItem(window: TDockWindow; parent: TMenuItem; const caption: string; onClick: TNotifyEvent; tag: integer): TMenuItem;
begin
  result := TMenuItem.Create(window);
  result.Caption := caption;
  result.OnClick := onClick;
  result.Tag := tag;
  parent.Add(result);
end;

function itemByTag(parent: TMenuItem; tag: integer): TMenuItem;
begin
  result := nil;
  for var i := 0 to parent.Count-1 do if parent[i].Tag = tag then exit(parent[i]);
end;

procedure TMenuGlue.windowViewShow(Sender: TObject);
begin
  var window := windowOf(Sender);
  if (window = nil) or (window.notebook = nil) or (mapManager = nil) then exit;
  var top := TMenuItem(Sender);
  for var i := 0 to top.Count-1 do if top[i].Tag = TAG_CODE_MAP then top[i].Checked := mapManager.windowShown(window.notebook);
end;

procedure TMenuGlue.windowCodeMapClick(Sender: TObject);
begin
  var window := windowOf(Sender);
  if (window = nil) or (window.notebook = nil) or (mapManager = nil) then exit;
  mapManager.setWindowShown(window.notebook, not mapManager.windowShown(window.notebook));
end;

// the Forms and Frames menus list the units of the project that design one;
// the items are reused and the surplus hidden, a rebuild while the menu opens
// leaves paint garbage
procedure TMenuGlue.windowFormsShow(Sender: TObject);
begin
  var window := windowOf(Sender);
  var top := TMenuItem(Sender);
  if (window = nil) or (LazarusIDE = nil) or (LazarusIDE.ActiveProject = nil) then exit;
  var wanted: set of TPFComponentBaseClass := if top.Tag = TAG_FRAMES then [pfcbcFrame] else [pfcbcForm, pfcbcCustomForm];
  var n := 0;
  var project := LazarusIDE.ActiveProject;
  for var i := 0 to project.FileCount-1 do begin
    var projectFile := project.Files[i];
    if not projectFile.IsPartOfProject or not (projectFile.GetResourceBaseClass in wanted) then continue;
    var caption := projectFile.GetComponentName;
    if caption = '' then caption := ExtractFileNameOnly(projectFile.Filename);
    var item := if n < top.Count then top[n] else addItem(window, top, '', @windowFormClick, 0);
    if item.Caption <> caption then item.Caption := caption;
    item.Hint := projectFile.Filename;
    item.Tag := i;
    // a form shown in another designer window stays there
    var owner := dockMaster.designerWindowOf(projectFile.Filename);
    var enabled := (owner = nil) or (owner = window);
    if item.Enabled <> enabled then item.Enabled := enabled;
    if not item.Visible then item.Visible := true;
    inc(n);
  end;
  for var i := n to top.Count-1 do if top[i].Visible then top[i].Visible := false;
end;

// opens the unit in the editor of the window and shows its form
procedure TMenuGlue.windowFormClick(Sender: TObject);
begin
  var window := windowOf(Sender);
  if (window = nil) or (window.notebook = nil) or (LazarusIDE = nil) or (IDETabMaster = nil) then exit;
  var index := -1;
  for var i := 0 to SourceEditorManagerIntf.SourceWindowCount-1 do if SourceEditorManagerIntf.SourceWindows[i] = window.notebook then index := i;
  if index < 0 then exit;
  if LazarusIDE.DoOpenEditorFile(TMenuItem(Sender).Hint, -1, index, [ofOnlyIfExists, ofRegularFile]) <> mrOk then exit;
  var editor := window.notebook.ActiveEditor;
  if editor <> nil then IDETabMaster.ShowDesigner(editor);
end;

// every extra window gets its own Panes menu: the fixed commands around the
// pane list, which fills in on every open. An editor window adds View with
// the code map switch, a designer window the Forms and Frames menus
procedure TMenuGlue.windowCreated(Sender: TObject);
begin
  var window := TDockWindow(Sender);
  var menu := TMainMenu.Create(window);
  if (window.center <> nil) and not window.designer then begin
    var view := addItem(window, menu.Items, MENU_VIEW, @windowViewShow, TAG_NONE);
    addItem(window, view, MENU_CODE_MAP, @windowCodeMapClick, TAG_CODE_MAP);
  end;
  if window.designer then begin
    addItem(window, menu.Items, MENU_FORMS, @windowFormsShow, TAG_FORMS);
    addItem(window, menu.Items, MENU_FRAMES, @windowFormsShow, TAG_FRAMES);
  end;
  var panes := addItem(window, menu.Items, MENU_PANES, @windowPanesShow, 0);
  addItem(window, panes, MENU_IDENTIFY, @identifyClick, TAG_IDENTIFY);
  addItem(window, panes, '-', nil, TAG_NONE);
  addItem(window, panes, MENU_DEBUG, nil, TAG_DEBUG);
  addItem(window, panes, '-', nil, TAG_LIST_END);
  addItem(window, panes, MENU_NEW_PANE_WINDOW, @newPaneWindowClick, TAG_NONE);
  addItem(window, panes, MENU_NEW_EDITOR_WINDOW, @newEditorWindowClick, TAG_NONE);
  addItem(window, panes, MENU_NEW_DESIGNER_WINDOW, @newDesignerWindowClick, TAG_DESIGNER);
  addItem(window, panes, '-', nil, TAG_NONE);
  addItem(window, panes, MENU_SHOW_HEADERS, @headersClick, TAG_HEADERS);
  windowPanesShow(panes);
  window.Menu := menu;
end;

// adds the panes registered since the last open and syncs the marks; the
// items stay in place, as a rebuild while the menu opens leaves paint garbage
procedure TMenuGlue.windowPanesShow(Sender: TObject);

  procedure syncPanes(parent: TMenuItem; window: TCustomForm);
  begin
    for var i := 0 to parent.Count-1 do if parent[i].Tag >= 0 then parent[i].Checked := shownIn(names[parent[i].Tag], window);
  end;

begin
  var window := windowOf(Sender);
  if window = nil then exit;
  var top := TMenuItem(Sender);
  buildList;
  var debug := itemByTag(top, TAG_DEBUG);
  // Tag of the top item counts the panes listed so far
  for var i := top.Tag to names.Count-1 do begin
    var caption := TIDEMenuCommand(names.Objects[i]).Caption;
    if isDebugPane(descriptorOf(names[i])) then addItem(window, debug, caption, @windowPaneClick, i) else begin
      var item := TMenuItem.Create(window);
      item.Caption := caption;
      item.OnClick := @windowPaneClick;
      item.Tag := i;
      top.Insert(top.IndexOf(itemByTag(top, TAG_LIST_END)), item);
    end;
  end;
  top.Tag := names.Count;
  syncPanes(top, window);
  syncPanes(debug, window);
  itemByTag(top, TAG_IDENTIFY).Checked := (dockMaster <> nil) and dockMaster.identify;
  itemByTag(top, TAG_DESIGNER).Enabled := designerAvailable;
  itemByTag(top, TAG_HEADERS).Checked := paneSettings.headerShown;
end;

procedure TMenuGlue.windowPaneClick(Sender: TObject);
begin
  var window := windowOf(Sender);
  var item := TMenuItem(Sender);
  if (window = nil) or (item.Tag >= names.Count) then exit;
  togglePane(names[item.Tag], window, window.host);
end;

// the pane entries of the View menu live in the Panes menu now
procedure hideMovedViewItems;

  procedure hide(section: TIDEMenuSection; const itemNames: array of string);
  begin
    if section = nil then exit;
    for var i := 0 to High(itemNames) do begin
      var item := section.FindByName(itemNames[i]);
      if item <> nil then item.Visible := false;
    end;
  end;

  function subsection(const name: string): TIDEMenuSection;
  begin
    var item := mnuView.FindByName(name);
    result := if item is TIDEMenuSection then TIDEMenuSection(item) else nil;
  end;

begin
  if mnuView = nil then exit;
  hide(subsection('itmViewMainWindows'), ['itmViewInspector', 'itmViewSourceEditor', 'itmViewMessage', 'itmViewCodeExplorer', 'itmViewFPDocEditor', 'itmViewCodeBrowser', 'itmSourceUnitDependencies', 'itmViewRestrictionBrowser', 'itmViewComponents', 'itmJumpHistory', 'itmMacroListView']);
  hide(mnuView, ['itmViewDesignerWindows']);
  hide(subsection('itmViewSecondaryWindows'), ['itmViewSearchResults', 'itmViewDebugWindows']);
end;

procedure Register;
begin
  glue := TMenuGlue.Create(Application);
  names := TStringList.Create;
  panesMenu := TIDEMenuSection.Create('itmPanes');
  panesMenu.ChildrenAsSubMenu := true;
  panesMenu.Caption := MENU_PANES;
  // before the Window menu
  var index := if mnuWindow <> nil then mnuMain.IndexOf(mnuWindow) else -1;
  if index < 0 then mnuMain.AddLast(panesMenu) else mnuMain.Insert(index, panesMenu);
  panesMenu.AddHandlerOnShow(@glue.menuShow);
  var topSection := RegisterIDEMenuSection(panesMenu, 'itmPanesTop');
  identifyItem := RegisterIDEMenuCommand(topSection, 'itmPanesIdentify', MENU_IDENTIFY, @glue.identifyClick);
  listSection := RegisterIDEMenuSection(panesMenu, 'itmPanesList');
  debugSection := RegisterIDESubMenu(listSection, 'itmPanesDebug', MENU_DEBUG);
  var windowsSection := RegisterIDEMenuSection(panesMenu, 'itmPanesWindows');
  RegisterIDEMenuCommand(windowsSection, 'itmPanesNewPaneWindow', MENU_NEW_PANE_WINDOW, @glue.newPaneWindowClick);
  RegisterIDEMenuCommand(windowsSection, 'itmPanesNewEditorWindow', MENU_NEW_EDITOR_WINDOW, @glue.newEditorWindowClick);
  designerItem := RegisterIDEMenuCommand(windowsSection, 'itmPanesNewDesignerWindow', MENU_NEW_DESIGNER_WINDOW, @glue.newDesignerWindowClick);
  var optionsSection := RegisterIDEMenuSection(panesMenu, 'itmPanesOptions');
  headersItem := RegisterIDEMenuCommand(optionsSection, 'itmPanesHeaders', MENU_SHOW_HEADERS, @glue.headersClick);
  buildList;
  hideMovedViewItems;
  if dockMaster = nil then exit;
  dockMaster.onWindowCreated := @glue.windowCreated;
  OnPickDesignerEditor := @dockMaster.pickDesignerEditor;
  paneSettings := loadPaneSettings;
  dockMaster.applySettings(paneSettings.headerShown, paneSettings.padding);
  RegisterIDEOptionsEditor(GroupEditor, TPanesOptionsFrame, OPTIONS_FRAME_ID);
end;

procedure provideDockMaster;
begin
  OnIDEDockMasterNeeded := nil;
  IDEDockMaster := TPanesDockMaster.Create;
end;

initialization
  if OnIDEDockMasterNeeded = nil then OnIDEDockMasterNeeded := @provideDockMaster;

finalization
  FreeAndNil(dockMaster);
  FreeAndNil(names);
end.
