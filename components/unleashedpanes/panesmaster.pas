{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PanesMaster;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, ComCtrls, Menus, Graphics, LCLType, LCLIntf, LMessages, LazLoggerBase, LazFileUtils, Laz2_XMLCfg, IDEOptionsIntf, IDEWindowIntf, SrcEditorIntf, LazIDEIntf, MiniMapManager, PanesLayout, PanesDrag, PanesStrings;

type
  // debug: member of the tabbed Debug pane; canDuplicate: the IDE can make
  // another instance of the window (ComponentList2), so every window may show one
  TPaneFlag = (pfDebug, pfCanDuplicate);
  TPaneFlags = set of TPaneFlag;

  TPaneDescriptor = record
    name: string;
    caption: string;
    side: TDockSide;
    flags: TPaneFlags;
  end;

  TPaneEntry = record
    name: string;
    // the tab shown in a tabbed frame
    active: boolean;
  end;

  TNodeKind = (nkFrame, nkSplit, nkCenter);

  { TLayoutNode }

  // saved node of a layout tree
  TLayoutNode = class
    kind: TNodeKind;
    orientation: TSplitOrientation;
    weight: double;
    panes: array of TPaneEntry;
    children: array of TLayoutNode;
    destructor Destroy; override;
    function clone: TLayoutNode;
  end;

  TWindowData = record
    bounds: TRect;
    maximized: boolean;
    // nil for an empty window
    root: TLayoutNode;
  end;

  // an extra editor window, or a designer window built around the editor
  TEditorWindowData = record
    name: string;
    designer: boolean;
    codeMap: boolean;
    window: TWindowData;
  end;

  TLayoutData = record
    main: TWindowData;
    windows: array of TWindowData;
    editors: array of TEditorWindowData;
  end;

  { TDockWindow }

  // extra top-level window: panes only, or an editor in the middle
  TDockWindow = class(TForm)
  private
    fHost: TPaneHost;
    fCenter: TPaneCenter;
    fDesigner: boolean;
    fHiddenWithMain: boolean;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    procedure createCenter;
    property host: TPaneHost read fHost;
    // hidden by the dock master while the IDE is minimized
    property hiddenWithMain: boolean read fHiddenWithMain write fHiddenWithMain;
    // set for an editor window: the editor sits in the middle, the panes around it
    property center: TPaneCenter read fCenter;
    // the editor shows only the form designer, with the tabs to switch to the anchors
    property designer: boolean read fDesigner write fDesigner;
    // the editor hosted in the middle, nil for an empty window
    function notebook: TSourceEditorWindowInterface;
  end;

  { TPanesDockMaster }

  TPanesDockMaster = class(TIDEDockMaster)
  private
    fMainBar: TCustomForm;
    fMainHost: TPaneHost;
    fCenter: TPaneCenter;
    fWindows: TFPList;
    fFrames: TFPList;
    fPending: TFPList;
    fGroupFrame: TPaneFrame;
    fPendingDesigner: boolean;
    fMainBounds: TRect;
    fMainMaximized: boolean;
    fHaveMainBounds: boolean;
    fMainBoundsApplied: boolean;
    fTargetHost: TPaneHost;
    fOnWindowCreated: TNotifyEvent;
    fDrag: TDragSession;
    fIdentify: boolean;
    fTopHeight: integer;
    fTabMenu: TPopupMenu;
    fMenuFrame: TPaneFrame;
    fMenuTab: integer;
    // saved editor windows not shown yet; each entry goes to the first show of its window
    fEditorLayouts: array of TEditorWindowData;
    procedure mainResized(Sender: TObject);
    function estimateTopHeight: integer;
    procedure layoutMainHost;
    procedure setIdentify(value: boolean);
    procedure tabPopup(Sender: TObject; tab: integer; const screenPos: TPoint);
    procedure tabMenuMove(Sender: TObject);
    procedure tabMenuClose(Sender: TObject);
    procedure tabMenuToggle(Sender: TObject);
    procedure keyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure userInput(Sender: TObject; var Msg: TLMessage);
    procedure activeFormChanged(Sender: TObject; Form: TCustomForm);
    procedure appMinimize(Sender: TObject);
    procedure appRestore(Sender: TObject);
    procedure ensureMainHost;
    function frameOf(aForm: TCustomForm): TPaneFrame;
    function hostAlive(host: TPaneHost): boolean;
    function groupFrame: TPaneFrame;
    function newFrame(host: TPaneHost): TPaneFrame;
    function frameFor(aForm: TCustomForm; host: TPaneHost; into: TPaneFrame = nil): TPaneFrame;
    procedure placeDefault(host: TPaneHost; frame: TPaneFrame; side: TDockSide);
    procedure reown(frame: TPaneFrame; host: TPaneHost);
    procedure syncTabs(frame: TPaneFrame);
    procedure mergeFrames(source, target: TPaneFrame);
    procedure releaseFrame(frame: TPaneFrame);
    procedure releaseForm(aForm: TCustomForm);
    procedure releaseFormAsync(data: PtrInt);
    procedure closeFrame(frame: TPaneFrame);
    procedure frameButton(Sender: TObject; button: TPaneButton);
    // opens the drop zones in every window; with a form only that one travels
    procedure beginDrag(frame: TPaneFrame; aForm: TCustomForm = nil);
    procedure tabDrag(Sender: TObject; tab: integer);
    procedure frameDrag(Sender: TObject; const screenPos: TPoint);
    procedure frameDrop(Sender: TObject; const screenPos: TPoint);
    procedure frameCancel(Sender: TObject);
    procedure cancelDrag;
    function hostAt(const screenPos: TPoint): TPaneHost;
    function aliveHosts: TFPList;
    procedure formVisibleChanged(Sender: TObject);
    procedure formDestroying(Sender: TObject);
    procedure editorVisibleChanged(Sender: TObject);
    procedure closeEmptyEditorWindow(data: PtrInt);
    procedure clearHost(host: TPaneHost; dropExtras: boolean = false);
    procedure windowClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure idle(Sender: TObject; var Done: Boolean);
    procedure styleWindows;
    procedure showMain;
    procedure showEditor(aForm: TCustomForm; bringToFront: boolean);
    procedure showPane(aForm: TCustomForm; bringToFront: boolean);
    procedure applyMainBounds;
    function captureNode(control: TControl; weight: double): TLayoutNode;
    function captureWindow(host: TPaneHost; aForm: TCustomForm): TWindowData;
    function applyNode(host: TPaneHost; node: TLayoutNode): TControl;
    procedure applyTree(host: TPaneHost; node: TLayoutNode);
    procedure applyWindow(window: TDockWindow; const data: TWindowData);
    function takeEditorLayout(const name: string; out data: TEditorWindowData): boolean;
    procedure dropEditorLayouts;
    function createEditorWindow(editor: TCustomForm; designer, defaults: boolean): TDockWindow;
  public
    constructor Create;
    destructor Destroy; override;
    procedure MakeIDEWindowDockable(AControl: TWinControl); override;
    procedure MakeIDEWindowDockSite(AForm: TCustomForm; ASides: TDockSides = [alBottom]); override;
    procedure ShowForm(AForm: TCustomForm; BringToFront: boolean); override;
    function AddableInWindowMenu(AForm: TCustomForm): boolean; override;
    procedure AdjustMainIDEWindowHeight(const AIDEWindow: TCustomForm; const AAdjustHeight: Boolean; const ANewHeight: Integer); override;
    procedure CloseAll; override;
    procedure ResetSplitters; override;
    function DockedDesktopOptClass: TAbstractDesktopDockingOptClass; override;
    procedure SetMainDockWindow(AForm: TCustomForm); override;
    // an empty dock window, or one with an empty center for an editor
    function createWindow(withCenter: boolean = false; designer: boolean = false): TDockWindow;
    function captureLayout: TLayoutData;
    // drops every pane and window, then rebuilds them from the data
    procedure applyLayout(const data: TLayoutData);
    // the form is shown inside a pane of some window
    function isDocked(aForm: TCustomForm): boolean;
    function windowCount: integer;
    function windows(index: integer): TDockWindow;
    property mainHost: TPaneHost read fMainHost;
    property mainBar: TCustomForm read fMainBar;
    // every pane shows its name over its body; Esc or a click into the editor ends it
    property identify: boolean read fIdentify write setIdentify;
    // relayouts every frame after the title bar or padding settings changed
    procedure applySettings(headerShown: boolean; padding: integer);
    // window that receives the next pane opened from its own menu; nil means the defaults
    property targetHost: TPaneHost read fTargetHost write fTargetHost;
    property onWindowCreated: TNotifyEvent read fOnWindowCreated write fOnWindowCreated;
    // the next extra editor window opens as a designer window
    property pendingDesigner: boolean read fPendingDesigner write fPendingDesigner;
    // opens the pane in the window, as a copy when it is docked elsewhere and allows one
    procedure placePane(host: TPaneHost; const name: string; side: TDockSide);
    // the designer window whose editor shows the unit of the file; nil when none
    function designerWindowOf(const fileName: string): TDockWindow;
    // the form of a unit shown in a designer window opens there, and the window comes to the front
    function pickDesignerEditor(editor: TSourceEditorInterface): TSourceEditorInterface;
  end;

  { TPanesDesktopOpt }

  // the pane layout stored inside a desktop
  TPanesDesktopOpt = class(TAbstractDesktopDockingOpt)
  private
    fData: TLayoutData;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure StoreWindowPositions; override;
    procedure LoadDefaults; override;
    procedure Load(Path: String; aXMLCfg: TRttiXMLConfig); override;
    procedure Save(Path: String; aXMLCfg: TRttiXMLConfig); override;
    procedure ImportSettingsFromIDE; override;
    procedure ExportSettingsToIDE; override;
    function RestoreDesktop: Boolean; override;
    procedure Assign(Source: TAbstractDesktopDockingOpt); override;
  end;

function descriptorOf(const name: string): TPaneDescriptor;
function descriptorCount: integer;
function descriptors(index: integer): TPaneDescriptor;
function defaultLayout: TLayoutData;
procedure freeLayout(var data: TLayoutData);
function cloneLayout(const data: TLayoutData): TLayoutData;

var
  dockMaster: TPanesDockMaster = nil;

implementation

const
  LAYOUT_VERSION = 3;
  EDITOR_WINDOW_WIDTH = 1400;
  DESIGNER_WINDOW_HEIGHT = 700;
  // share of the width the editor keeps between the Object Inspector and the Components pane
  DESIGNER_CENTER_WEIGHT = 2.6;
  // share of the width the editor keeps beside the Project Inspector
  EDITOR_CENTER_WEIGHT = 3.5;

var
  table: array of TPaneDescriptor;

procedure addDescriptor(const name, caption: string; side: TDockSide; flags: TPaneFlags);
begin
  SetLength(table, Length(table)+1);
  table[High(table)].name := name;
  table[High(table)].caption := caption;
  table[High(table)].side := side;
  table[High(table)].flags := flags;
end;

// the number of an extra instance (ProjectInspector2) does not change the descriptor
function descriptorOf(const name: string): TPaneDescriptor;
begin
  var base := name;
  while (base <> '') and (base[Length(base)] in ['0'..'9']) do Delete(base, Length(base), 1);
  for var i := 0 to High(table) do if SameText(table[i].name, base) then exit(table[i]);
  result.name := name;
  result.caption := name;
  result.side := dsRight;
  result.flags := [];
end;

// a numbered copy of a pane (ObjectInspectorDlg2), made on demand
function isExtraInstance(aForm: TCustomForm): boolean;
begin
  var name := aForm.Name;
  result := (name <> '') and (name[Length(name)] in ['0'..'9']) and (pfCanDuplicate in descriptorOf(name).flags);
end;

function descriptorCount: integer;
begin
  result := Length(table);
end;

function descriptors(index: integer): TPaneDescriptor;
begin
  result := table[index];
end;

// -- TLayoutNode ---------------------------------------------------------------

destructor TLayoutNode.Destroy;
begin
  for var i := 0 to High(children) do children[i].Free;
  inherited Destroy;
end;

function TLayoutNode.clone: TLayoutNode;
begin
  result := TLayoutNode.Create;
  result.kind := kind;
  result.orientation := orientation;
  result.weight := weight;
  result.panes := copy(panes);
  SetLength(result.children, Length(children));
  for var i := 0 to High(children) do result.children[i] := children[i].clone;
end;

function frameNode(const names: array of string): TLayoutNode;
begin
  result := TLayoutNode.Create;
  result.kind := nkFrame;
  result.weight := 1;
  SetLength(result.panes, Length(names));
  for var i := 0 to High(names) do begin
    result.panes[i].name := names[i];
    result.panes[i].active := i = 0;
  end;
end;

function centerNode: TLayoutNode;
begin
  result := TLayoutNode.Create;
  result.kind := nkCenter;
  result.weight := 1;
end;

function splitNode(orientation: TSplitOrientation; const children: array of TLayoutNode; const weights: array of double): TLayoutNode;
begin
  result := TLayoutNode.Create;
  result.kind := nkSplit;
  result.orientation := orientation;
  result.weight := 1;
  SetLength(result.children, Length(children));
  for var i := 0 to High(children) do begin
    result.children[i] := children[i];
    result.children[i].weight := weights[i];
  end;
end;

function emptyWindow: TWindowData;
begin
  result.bounds := Rect(0, 0, 0, 0);
  result.maximized := false;
  result.root := nil;
end;

function defaultLayout: TLayoutData;
begin
  result.main := emptyWindow;
  result.main.root := splitNode(soHorizontal, [
    splitNode(soVertical, [frameNode(['CodeExplorerView']), frameNode(['ObjectInspectorDlg'])], [1, 1]),
    splitNode(soVertical, [centerNode, frameNode(['MessagesView', 'Locals', 'BreakPoints', 'Watches', 'Assembler', 'CallStack', 'DbgEvents'])], [3, 1]),
    splitNode(soVertical, [frameNode(['ProjectInspector']), frameNode(['ComponentList'])], [1, 1])], [1, 5, 1]);
  result.windows := nil;
  result.editors := nil;
end;

procedure freeLayout(var data: TLayoutData);
begin
  FreeAndNil(data.main.root);
  for var i := 0 to High(data.windows) do FreeAndNil(data.windows[i].root);
  for var i := 0 to High(data.editors) do FreeAndNil(data.editors[i].window.root);
  data.windows := nil;
  data.editors := nil;
end;

function cloneWindow(const src: TWindowData): TWindowData;
begin
  result := src;
  if src.root <> nil then result.root := src.root.clone;
end;

function cloneLayout(const data: TLayoutData): TLayoutData;
begin
  result.main := cloneWindow(data.main);
  SetLength(result.windows, Length(data.windows));
  for var i := 0 to High(data.windows) do result.windows[i] := cloneWindow(data.windows[i]);
  SetLength(result.editors, Length(data.editors));
  for var i := 0 to High(data.editors) do begin
    result.editors[i] := data.editors[i];
    result.editors[i].window := cloneWindow(data.editors[i].window);
  end;
end;

function validBounds(const r: TRect): boolean;
begin
  result := (r.Width >= 100) and (r.Height >= 100) and (Screen.MonitorFromRect(r, mdNull) <> nil);
end;

function restoredBounds(aForm: TCustomForm): TRect;
begin
  if aForm.WindowState = wsMaximized then result := Rect(aForm.RestoredLeft, aForm.RestoredTop, aForm.RestoredLeft+aForm.RestoredWidth, aForm.RestoredTop+aForm.RestoredHeight) else result := aForm.BoundsRect;
end;

// -- TDockWindow ---------------------------------------------------------------

constructor TDockWindow.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Caption := WINDOW_DOCK;
  Position := poDesigned;
  fHost := TPaneHost.Create(Self);
  fHost.Parent := Self;
  fHost.Align := alClient;
end;

procedure TDockWindow.createCenter;
begin
  if fCenter <> nil then exit;
  fCenter := TPaneCenter.Create(fHost);
  fHost.setCenter(fCenter);
end;

function TDockWindow.notebook: TSourceEditorWindowInterface;
begin
  result := nil;
  if fCenter = nil then exit;
  var hosted := fCenter.hostedForm;
  if hosted is TSourceEditorWindowInterface then result := TSourceEditorWindowInterface(hosted);
end;

// -- TPanesDockMaster ----------------------------------------------------------

constructor TPanesDockMaster.Create;
begin
  inherited Create;
  dockMaster := Self;
  fWindows := TFPList.Create;
  fFrames := TFPList.Create;
  fPending := TFPList.Create;
  Application.AddOnIdleHandler(@idle);
  Application.AddOnKeyDownHandler(@keyDown);
  Application.AddOnUserInputHandler(@userInput);
  Application.AddOnMinimizeHandler(@appMinimize);
  Application.AddOnRestoreHandler(@appRestore);
  Screen.AddHandlerActiveFormChanged(@activeFormChanged);
end;

destructor TPanesDockMaster.Destroy;
begin
  dropEditorLayouts;
  FreeAndNil(fDrag);
  FreeAndNil(fTabMenu);
  Screen.RemoveHandlerActiveFormChanged(@activeFormChanged);
  Application.RemoveOnIdleHandler(@idle);
  Application.RemoveOnKeyDownHandler(@keyDown);
  Application.RemoveOnUserInputHandler(@userInput);
  Application.RemoveOnMinimizeHandler(@appMinimize);
  Application.RemoveOnRestoreHandler(@appRestore);
  if IDEDockMaster = Self then IDEDockMaster := nil;
  if dockMaster = Self then dockMaster := nil;
  fWindows.Free;
  fFrames.Free;
  fPending.Free;
  inherited Destroy;
end;

// files open in the editor of the window in front; the IDE tracks that only
// through the focus of a floating editor, which a hosted one never gets
procedure TPanesDockMaster.activeFormChanged(Sender: TObject; Form: TCustomForm);
begin
  if (Form = nil) or (SourceEditorManagerIntf = nil) then exit;
  var top := GetParentForm(Form);
  var hosted: TCustomForm := nil;
  if top = fMainBar then hosted := if fCenter <> nil then fCenter.hostedForm else nil
  else if top is TDockWindow then hosted := TDockWindow(top).notebook;
  if not (hosted is TSourceEditorWindowInterface) or (SourceEditorManagerIntf.ActiveSourceWindow = hosted) then exit;
  SourceEditorManagerIntf.ActiveSourceWindow := TSourceEditorWindowInterface(hosted);
end;

// the windows are owned by the main window, which hides when the IDE
// minimizes, but the system leaves the owned windows on screen
procedure TPanesDockMaster.appMinimize(Sender: TObject);
begin
  for var i := 0 to fWindows.Count-1 do begin
    var window := windows(i);
    window.hiddenWithMain := window.HandleAllocated and IsWindowVisible(window.Handle);
    if window.hiddenWithMain then ShowWindow(window.Handle, SW_HIDE);
  end;
end;

procedure TPanesDockMaster.appRestore(Sender: TObject);
begin
  for var i := 0 to fWindows.Count-1 do begin
    var window := windows(i);
    if not window.hiddenWithMain then continue;
    window.hiddenWithMain := false;
    if window.HandleAllocated then ShowWindow(window.Handle, SW_SHOWNA);
  end;
end;

procedure TPanesDockMaster.ensureMainHost;
begin
  if (fMainHost <> nil) or (fMainBar = nil) then exit;
  fMainHost := TPaneHost.Create(fMainBar);
  fMainHost.Align := alBottom;
  fMainHost.Height := 0;
  fMainHost.Parent := fMainBar;
  fCenter := TPaneCenter.Create(fMainHost);
  fMainHost.setCenter(fCenter);
  fMainHost.topEdge := false;
  fTopHeight := -1;
  fMainBar.AddHandlerOnResize(@mainResized);
end;

// the IDE reports the height of its tool bar strip only on its own resize
// path, so until then the strip is measured here the same way
function TPanesDockMaster.estimateTopHeight: integer;
begin
  result := 0;
  for var i := 0 to fMainBar.ControlCount-1 do begin
    var control := fMainBar.Controls[i];
    if not control.Visible then continue;
    if control is TCoolBar then begin
      var bar := TCoolBar(control);
      for var j := 0 to bar.Bands.Count-1 do result := Max(result, bar.Bands[j].Top+bar.Bands[j].Height);
    end else if (control is TPageControl) and (TPageControl(control).ActivePage <> nil) then begin
      var page := TPageControl(control).ActivePage;
      for var j := 0 to page.ControlCount-1 do begin
        if not (page.Controls[j] is TScrollBox) then continue;
        var box := TScrollBox(page.Controls[j]);
        for var k := 0 to box.ControlCount-1 do result := Max(result, box.Controls[k].Top+box.Controls[k].Height+control.Height-box.ClientHeight);
      end;
    end;
  end;
end;

procedure TPanesDockMaster.layoutMainHost;
begin
  if (fMainHost = nil) or (fMainBar = nil) then exit;
  var top := if fTopHeight >= 0 then fTopHeight else estimateTopHeight;
  fMainHost.Height := Max(0, fMainBar.ClientHeight-top);
end;

procedure TPanesDockMaster.mainResized(Sender: TObject);
begin
  layoutMainHost;
end;

function TPanesDockMaster.frameOf(aForm: TCustomForm): TPaneFrame;
begin
  result := if (aForm <> nil) and (aForm.Parent is TPaneFrame) then TPaneFrame(aForm.Parent) else nil;
end;

function TPanesDockMaster.hostAlive(host: TPaneHost): boolean;
begin
  result := false;
  if host = nil then exit;
  if host = fMainHost then exit(true);
  for var i := 0 to fWindows.Count-1 do if windows(i).host = host then exit(true);
end;

function TPanesDockMaster.groupFrame: TPaneFrame;
begin
  result := if fFrames.IndexOf(fGroupFrame) >= 0 then fGroupFrame else nil;
end;

function TPanesDockMaster.newFrame(host: TPaneHost): TPaneFrame;
begin
  result := TPaneFrame.Create(host);
  result.onButton := @frameButton;
  result.onTabPopup := @tabPopup;
  result.onTabDrag := @tabDrag;
  result.onDrag := @frameDrag;
  result.onDrop := @frameDrop;
  result.onCancel := @frameCancel;
  result.identify := fIdentify;
  fFrames.Add(result);
end;

// the frame holding the form: the shared Debug frame for a debug pane, else
// the given one, else a new frame that still waits for its place in the tree
function TPanesDockMaster.frameFor(aForm: TCustomForm; host: TPaneHost; into: TPaneFrame): TPaneFrame;
begin
  aForm.RemoveHandlerOnVisibleChanged(@formVisibleChanged);
  aForm.AddHandlerOnVisibleChanged(@formVisibleChanged);
  aForm.RemoveHandlerOnBeforeDestruction(@formDestroying);
  aForm.AddHandlerOnBeforeDestruction(@formDestroying);
  var grouped := pfDebug in descriptorOf(aForm.Name).flags;
  result := if grouped then groupFrame else nil;
  if result = nil then result := into;
  if result = nil then begin
    result := newFrame(host);
    if grouped then begin
      fGroupFrame := result;
      result.title := PANE_DEBUG;
    end;
  end;
  result.attach(aForm);
  syncTabs(result);
end;

// where a pane opened from a menu goes: the main window keeps its columns
// beside the editor and its row under it, a dock window fills up rightward
procedure TPanesDockMaster.placeDefault(host: TPaneHost; frame: TPaneFrame; side: TDockSide);
begin
  var root := host.root;
  var center := host.center;
  if root = nil then begin
    host.fill(frame);
    exit;
  end;
  if center = nil then begin
    host.insertAtEdge(frame, dsRight);
    exit;
  end;
  if side in [dsLeft, dsRight] then begin
    // the outermost column on that side takes the pane at its bottom
    if (root is TPaneSplit) and (TPaneSplit(root).orientation = soHorizontal) then begin
      var split := TPaneSplit(root);
      var column := if side = dsLeft then split.items[0] else split.items[split.itemCount-1];
      if not host.containsCenter(column) then begin
        host.splitBeside(column, frame, dsBottom);
        exit;
      end;
    end;
    host.insertAtEdge(frame, side);
    exit;
  end;
  // the row under the center takes the pane at its right end
  var stack := parentSplit(center);
  if (stack <> nil) and (stack.orientation = soVertical) and (stack.indexOf(center) < stack.itemCount-1) then host.splitBeside(stack.items[stack.itemCount-1], frame, dsRight)
  else host.splitBeside(center, frame, dsBottom);
end;

// the frame follows its window for the ownership too
procedure TPanesDockMaster.reown(frame: TPaneFrame; host: TPaneHost);
begin
  if (host = nil) or (frame.Owner = host) then exit;
  if frame.Owner <> nil then frame.Owner.RemoveComponent(frame);
  host.InsertComponent(frame);
end;

// a tab strip for several forms; the Debug frame keeps its strip anyway
procedure TPanesDockMaster.syncTabs(frame: TPaneFrame);
begin
  frame.tabbed := (frame.formCount > 1) or (frame = fGroupFrame);
end;

// the forms of the source join the target as tabs; the Debug frame passes its role on
procedure TPanesDockMaster.mergeFrames(source, target: TPaneFrame);
begin
  var active := source.form;
  var list := TFPList.Create;
  try
    for var i := 0 to source.formCount-1 do list.Add(source.forms[i]);
    for var i := 0 to list.Count-1 do begin
      source.detach(TCustomForm(list[i]));
      target.attach(TCustomForm(list[i]));
    end;
  finally
    list.Free;
  end;
  if source = fGroupFrame then begin
    fGroupFrame := target;
    target.title := PANE_DEBUG;
  end;
  syncTabs(target);
  releaseFrame(source);
  if active <> nil then target.activate(active);
end;

procedure TPanesDockMaster.releaseFrame(frame: TPaneFrame);
begin
  if fFrames.IndexOf(frame) < 0 then exit;
  fFrames.Remove(frame);
  // a form leaves hidden, else it turns up on screen as a window of its own
  while frame.formCount > 0 do begin
    frame.forms[0].Visible := false;
    frame.detach(frame.forms[0]);
  end;
  var host := hostOf(frame);
  if host <> nil then host.detach(frame);
  if frame = fGroupFrame then fGroupFrame := nil;
  frame.Free;
end;

procedure TPanesDockMaster.releaseForm(aForm: TCustomForm);
begin
  fPending.Remove(aForm);
  var frame := frameOf(aForm);
  if frame = nil then exit;
  frame.detach(aForm);
  if frame.formCount = 0 then releaseFrame(frame) else syncTabs(frame);
end;

procedure TPanesDockMaster.releaseFormAsync(data: PtrInt);
begin
  var aForm := TCustomForm(data);
  if fPending.IndexOf(aForm) < 0 then exit;
  fPending.Remove(aForm);
  var frame := frameOf(aForm);
  // the form came back before the release ran
  if aForm.Visible then exit;
  if frame <> nil then releaseForm(aForm);
  // a numbered copy is made on demand, so a closed one goes for good
  if isExtraInstance(aForm) then aForm.Release;
end;

// closes every form of the frame; the last one to go takes the frame with it
procedure TPanesDockMaster.closeFrame(frame: TPaneFrame);
begin
  var list := TFPList.Create;
  try
    for var i := 0 to frame.formCount-1 do list.Add(frame.forms[i]);
    for var i := 0 to list.Count-1 do TCustomForm(list[i]).Close;
  finally
    list.Free;
  end;
end;

procedure TPanesDockMaster.frameButton(Sender: TObject; button: TPaneButton);
begin
  if button = pbClose then closeFrame(TPaneFrame(Sender));
  if button = pbMove then beginDrag(TPaneFrame(Sender));
end;

function TPanesDockMaster.aliveHosts: TFPList;
begin
  result := TFPList.Create;
  if fMainHost <> nil then result.Add(fMainHost);
  for var i := 0 to fWindows.Count-1 do result.Add(windows(i).host);
end;

procedure TPanesDockMaster.beginDrag(frame: TPaneFrame; aForm: TCustomForm);
begin
  FreeAndNil(fDrag);
  var hosts := aliveHosts;
  try
    fDrag := TDragSession.Create(frame, hosts);
  finally
    hosts.Free;
  end;
  // the Debug frame moves as a whole, its members have no frame of their own
  if (frame <> groupFrame) and (frame.formCount > 1) then fDrag.form := aForm;
  Screen.Cursor := crDrag;
end;

procedure TPanesDockMaster.tabDrag(Sender: TObject; tab: integer);
begin
  var frame := TPaneFrame(Sender);
  if (tab < 0) or (tab >= frame.formCount) then exit;
  beginDrag(frame, frame.forms[tab]);
end;

// the frame of the window on screen; BoundsRect of a form leaves out its caption
function windowRect(aForm: TCustomForm): TRect;
begin
  if not aForm.HandleAllocated or (GetWindowRect(aForm.Handle, result) = 0) then result := aForm.BoundsRect;
end;

// the window under the cursor wins over the windows behind it
function TPanesDockMaster.hostAt(const screenPos: TPoint): TPaneHost;
begin
  result := nil;
  var active := Screen.ActiveCustomForm;
  for var i := 0 to fWindows.Count-1 do if windowRect(windows(i)).Contains(screenPos) and (windows(i) = active) then exit(windows(i).host);
  for var i := 0 to fWindows.Count-1 do if windowRect(windows(i)).Contains(screenPos) then exit(windows(i).host);
  if (fMainHost <> nil) and windowRect(fMainBar).Contains(screenPos) then result := fMainHost;
end;

procedure TPanesDockMaster.frameDrag(Sender: TObject; const screenPos: TPoint);
begin
  if fDrag = nil then exit;
  var host := hostAt(screenPos);
  var zone: TDropZone;
  var hasZone := false;
  // a window that already shows the pane takes no drop
  if (host <> nil) and not fDrag.blockedIn(host) then begin
    var p := host.ScreenToClient(screenPos);
    hasZone := host.zoneAt(p.X, p.Y, fDrag.dragged, zone);
  end;
  fDrag.moveTo(screenPos, host, zone, hasZone);
end;

procedure TPanesDockMaster.frameDrop(Sender: TObject; const screenPos: TPoint);
begin
  if fDrag = nil then exit;
  var frame := fDrag.frame;
  var aForm := fDrag.form;
  var host := fDrag.host;
  var zone := fDrag.zone;
  var hasZone := fDrag.hasZone;
  FreeAndNil(fDrag);
  Screen.Cursor := crDefault;
  if (fFrames.IndexOf(frame) < 0) or not hasZone or not hostAlive(host) then exit;
  // a tab pulled out leaves its frame for one of its own, which then drops
  // like any frame; back onto its own strip it stays
  if aForm <> nil then begin
    if ((zone.kind = dzTab) and (zone.target = frame)) or not frame.contains(aForm) then exit;
    frame.detach(aForm);
    syncTabs(frame);
    var single := newFrame(host);
    single.attach(aForm);
    frame := single;
  end;
  if zone.kind = dzTab then begin
    if (zone.target is TPaneFrame) and (zone.target <> frame) then mergeFrames(frame, TPaneFrame(zone.target));
    exit;
  end;
  var active := frame.form;
  // out of the tree first, so the drop sees the tree without the moving pane
  var source := hostOf(frame);
  if source <> nil then source.detach(frame);
  reown(frame, host);
  host.drop(zone, frame);
  if active <> nil then frame.activate(active);
end;

// right click on the tab strip: the tab commands, then for the Debug frame
// its members with a mark on the open ones
procedure TPanesDockMaster.tabPopup(Sender: TObject; tab: integer; const screenPos: TPoint);
begin
  fMenuFrame := TPaneFrame(Sender);
  fMenuTab := tab;
  if fTabMenu = nil then fTabMenu := TPopupMenu.Create(nil);
  fTabMenu.Items.Clear;
  if tab >= 0 then begin
    var item := TMenuItem.Create(fTabMenu);
    item.Caption := MENU_MOVE_LEFT;
    item.Tag := -1;
    item.Enabled := tab > 0;
    item.OnClick := @tabMenuMove;
    fTabMenu.Items.Add(item);
    item := TMenuItem.Create(fTabMenu);
    item.Caption := MENU_MOVE_RIGHT;
    item.Tag := 1;
    item.Enabled := tab < fMenuFrame.formCount-1;
    item.OnClick := @tabMenuMove;
    fTabMenu.Items.Add(item);
    item := TMenuItem.Create(fTabMenu);
    item.Caption := MENU_CLOSE;
    item.OnClick := @tabMenuClose;
    fTabMenu.Items.Add(item);
  end;
  if fMenuFrame = groupFrame then begin
    if tab >= 0 then begin
      var item := TMenuItem.Create(fTabMenu);
      item.Caption := '-';
      fTabMenu.Items.Add(item);
    end;
    for var i := 0 to descriptorCount-1 do begin
      var descriptor := descriptors(i);
      if not (pfDebug in descriptor.flags) then continue;
      var item := TMenuItem.Create(fTabMenu);
      item.Caption := descriptor.caption;
      item.Tag := i;
      var aForm := Screen.FindForm(descriptor.name);
      item.Checked := (aForm <> nil) and fMenuFrame.contains(aForm);
      item.OnClick := @tabMenuToggle;
      fTabMenu.Items.Add(item);
    end;
  end;
  if fTabMenu.Items.Count > 0 then fTabMenu.PopUp(screenPos.X, screenPos.Y);
end;

procedure TPanesDockMaster.tabMenuMove(Sender: TObject);
begin
  if fFrames.IndexOf(fMenuFrame) < 0 then exit;
  fMenuFrame.moveForm(fMenuTab, fMenuTab+TMenuItem(Sender).Tag);
end;

procedure TPanesDockMaster.tabMenuClose(Sender: TObject);
begin
  if (fFrames.IndexOf(fMenuFrame) < 0) or (fMenuTab < 0) or (fMenuTab >= fMenuFrame.formCount) then exit;
  fMenuFrame.forms[fMenuTab].Close;
end;

procedure TPanesDockMaster.tabMenuToggle(Sender: TObject);
begin
  if fFrames.IndexOf(fMenuFrame) < 0 then exit;
  var descriptor := descriptors(TMenuItem(Sender).Tag);
  var aForm := Screen.FindForm(descriptor.name);
  if (aForm <> nil) and fMenuFrame.contains(aForm) then aForm.Close else IDEWindowCreators.ShowForm(descriptor.name, true);
end;

procedure TPanesDockMaster.formVisibleChanged(Sender: TObject);
begin
  var aForm := TCustomForm(Sender);
  if aForm.Visible then exit;
  var frame := frameOf(aForm);
  if (frame = nil) or frame.switching then exit;
  // the hide may come from inside the form's own close path, so leave it first
  if fPending.IndexOf(aForm) < 0 then fPending.Add(aForm);
  Application.QueueAsyncCall(@releaseFormAsync, PtrInt(aForm));
end;

procedure TPanesDockMaster.formDestroying(Sender: TObject);
begin
  releaseForm(TCustomForm(Sender));
end;

// drops every frame of the host; the forms end up hidden, with dropExtras the
// numbered copies among them are freed
procedure TPanesDockMaster.clearHost(host: TPaneHost; dropExtras: boolean);
begin
  var list := TFPList.Create;
  var frames := host.frames;
  try
    for var i := 0 to frames.Count-1 do begin
      var frame := TPaneFrame(frames[i]);
      for var j := 0 to frame.formCount-1 do list.Add(frame.forms[j]);
      releaseFrame(frame);
    end;
    for var i := 0 to list.Count-1 do begin
      var aForm := TCustomForm(list[i]);
      aForm.Visible := false;
      if dropExtras and isExtraInstance(aForm) then aForm.Release;
    end;
  finally
    frames.Free;
    list.Free;
  end;
end;

procedure TPanesDockMaster.windowClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  var window := TDockWindow(Sender);
  // the editor of an editor window closes on its own terms
  var editor := if window.center <> nil then window.center.hostedForm else nil;
  if (editor <> nil) and not editor.CloseQuery then begin
    CloseAction := caNone;
    exit;
  end;
  // off screen at once; the panes come apart behind it
  window.Hide;
  clearHost(window.host, true);
  fWindows.Remove(window);
  if editor <> nil then begin
    editor.Hide;
    editor.Parent := nil;
    PanesLayout.releaseForm(editor);
    editor.Close;
  end;
  CloseAction := caFree;
end;

// hosts the editor in a new window, not shown yet; defaults puts the Object
// Inspector and the Components pane beside a designer, the Project Inspector
// beside an editor
function TPanesDockMaster.createEditorWindow(editor: TCustomForm; designer, defaults: boolean): TDockWindow;
begin
  result := createWindow(true, designer);
  result.Caption := if designer then WINDOW_DESIGNER else WINDOW_EDITOR;
  result.Width := EDITOR_WINDOW_WIDTH;
  if designer then result.Height := DESIGNER_WINDOW_HEIGHT;
  editor.RemoveHandlerOnVisibleChanged(@editorVisibleChanged);
  editor.AddHandlerOnVisibleChanged(@editorVisibleChanged);
  editor.DisableAutoSizing;
  try
    embedForm(editor);
    editor.Parent := result.center;
    editor.Align := alClient;
    editor.Visible := true;
  finally
    editor.EnableAutoSizing;
  end;
  if not defaults then exit;
  if designer then begin
    placePane(result.host, 'ObjectInspectorDlg', dsLeft);
    placePane(result.host, 'ComponentList', dsRight);
  end else placePane(result.host, 'ProjectInspector', dsRight);
  if not (result.host.root is TPaneSplit) then exit;
  var split := TPaneSplit(result.host.root);
  var weight := if designer then DESIGNER_CENTER_WEIGHT else EDITOR_CENTER_WEIGHT;
  for var i := 0 to split.itemCount-1 do split.weights[i] := if split.items[i] = result.center then weight else 1;
end;

procedure TPanesDockMaster.placePane(host: TPaneHost; const name: string; side: TDockSide);
begin
  var target := name;
  var form := Screen.FindForm(name);
  if (form <> nil) and (frameOf(form) <> nil) and (hostOf(frameOf(form)) <> host) and (pfCanDuplicate in descriptorOf(name).flags) then begin
    var n := 2;
    while Screen.FindForm(name+IntToStr(n)) <> nil do inc(n);
    target := name+IntToStr(n);
  end;
  form := IDEWindowCreators.GetForm(target, true, false);
  if form = nil then exit;
  var frame := frameOf(form);
  if frame <> nil then begin
    var source := hostOf(frame);
    if source = host then exit;
    if source <> nil then source.detach(frame);
    reown(frame, host);
  end else frame := frameFor(form, host);
  placeDefault(host, frame, side);
  frame.activate(form);
end;

// an editor that lost its last page hides itself; its window goes with it, so
// the IDE forgets the window and opens the next file in the main editor
procedure TPanesDockMaster.editorVisibleChanged(Sender: TObject);
begin
  var editor := TCustomForm(Sender);
  if editor.Visible or not (editor is TSourceEditorWindowInterface) or (TSourceEditorWindowInterface(editor).Count > 0) then exit;
  Application.QueueAsyncCall(@closeEmptyEditorWindow, PtrInt(editor));
end;

procedure TPanesDockMaster.closeEmptyEditorWindow(data: PtrInt);
begin
  var editor := TCustomForm(data);
  for var i := 0 to fWindows.Count-1 do begin
    var window := windows(i);
    if (window.center = nil) or (window.center.hostedForm <> editor) then continue;
    if editor.Visible or (TSourceEditorWindowInterface(editor).Count > 0) then exit;
    window.Close;
    exit;
  end;
end;

// a hosted form may size itself from its own options (the Object Inspector
// does), so every frame puts its forms back on idle
procedure TPanesDockMaster.idle(Sender: TObject; var Done: Boolean);
begin
  for var i := 0 to fFrames.Count-1 do begin
    TPaneFrame(fFrames[i]).syncCaption;
    TPaneFrame(fFrames[i]).ensureLayout;
  end;
  styleWindows;
end;

// keeps the extra editor windows in their shape: no editor toolbar, in an
// editor window the code alone, in a designer window no unit tabs and no Code
// tab, the view tabs on top. The IDE rebuilds these controls as units come
// and go, so the shape is reapplied on idle
procedure TPanesDockMaster.styleWindows;

  procedure style(window: TDockWindow; notebook: TSourceEditorWindowInterface);
  begin
    for var i := 0 to notebook.ControlCount-1 do begin
      var control := notebook.Controls[i];
      if (control is TToolBar) and control.Visible then control.Visible := false;
      if window.designer and (control is TCustomTabControl) and TCustomTabControl(control).ShowTabs then TCustomTabControl(control).ShowTabs := false;
    end;
    var editor := notebook.ActiveEditor;
    if (editor = nil) or (editor.EditorControl = nil) then exit;
    // the editor sits in the Code page of the page control the form editor made
    var code := editor.EditorControl.Parent;
    if (code = nil) or not (code.Parent is TPageControl) then exit;
    var pages := TPageControl(code.Parent);
    // an editor window shows the code only, without the tabs to leave it
    if not window.designer then begin
      if pages.ShowTabs then pages.ShowTabs := false;
      if (code is TTabSheet) and (pages.ActivePage <> code) then pages.ActivePage := TTabSheet(code);
      exit;
    end;
    if pages.TabPosition <> tpTop then pages.TabPosition := tpTop;
    if (code is TTabSheet) and TTabSheet(code).TabVisible then TTabSheet(code).TabVisible := false;
    // the form editor shows the form on its own tab change only, which a page
    // index set from here does not raise, so the switch goes through it
    if (pages.PageCount > 1) and (pages.ActivePage = code) and (IDETabMaster <> nil) then IDETabMaster.ShowDesigner(editor);
  end;

  // the main window shows a unit as code alone while a designer window holds
  // its form; the form tabs come back once that window is gone
  procedure styleMain(notebook: TSourceEditorWindowInterface);
  begin
    var editor := notebook.ActiveEditor;
    if (editor = nil) or (editor.EditorControl = nil) then exit;
    var code := editor.EditorControl.Parent;
    if (code = nil) or not (code.Parent is TPageControl) then exit;
    var pages := TPageControl(code.Parent);
    if designerWindowOf(editor.FileName) = nil then begin
      if not pages.ShowTabs and (pages.PageCount > 1) then pages.ShowTabs := true;
      exit;
    end;
    if pages.ShowTabs then pages.ShowTabs := false;
    // a form that got here anyway goes to the window that owns it
    if (pages.ActivePage <> code) and (IDETabMaster <> nil) then IDETabMaster.ShowDesigner(editor);
  end;

begin
  for var i := 0 to fWindows.Count-1 do begin
    var notebook := windows(i).notebook;
    if notebook <> nil then style(windows(i), notebook);
  end;
  if (fCenter <> nil) and (fCenter.hostedForm is TSourceEditorWindowInterface) then styleMain(TSourceEditorWindowInterface(fCenter.hostedForm));
end;

procedure TPanesDockMaster.setIdentify(value: boolean);
begin
  if value = fIdentify then exit;
  fIdentify := value;
  for var i := 0 to fFrames.Count-1 do TPaneFrame(fFrames[i]).identify := value;
end;

procedure TPanesDockMaster.keyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key <> VK_ESCAPE then exit;
  if fIdentify then identify := false;
  if fDrag <> nil then begin
    cancelDrag;
    Key := 0;
  end;
end;

// the pane stays where it was; the release that follows finds no drag to finish
procedure TPanesDockMaster.cancelDrag;
begin
  FreeAndNil(fDrag);
  Screen.Cursor := crDefault;
end;

procedure TPanesDockMaster.frameCancel(Sender: TObject);
begin
  cancelDrag;
end;

// a click into the source editor ends the identification
procedure TPanesDockMaster.userInput(Sender: TObject; var Msg: TLMessage);
begin
  if not fIdentify or (Msg.Msg <> LM_LBUTTONDOWN) or (fCenter = nil) then exit;
  var control := FindLCLControl(Mouse.CursorPos);
  while control <> nil do begin
    if control = fCenter then begin
      identify := false;
      exit;
    end;
    control := control.Parent;
  end;
end;

procedure TPanesDockMaster.applySettings(headerShown: boolean; padding: integer);
begin
  paneHeaderShown := headerShown;
  panePadding := padding;
  for var i := 0 to fFrames.Count-1 do TPaneFrame(fFrames[i]).applyGeometry;
end;

procedure TPanesDockMaster.applyMainBounds;
begin
  if fMainBar = nil then exit;
  if fHaveMainBounds and validBounds(fMainBounds) then fMainBar.BoundsRect := fMainBounds else begin
    // no saved place: centered in the work area, which leaves the taskbar out, with a tenth of it
    // free on every side
    var wa := Screen.PrimaryMonitor.WorkareaRect;
    var w := wa.Width-wa.Width div 5;
    var h := wa.Height-wa.Height div 5;
    // the bounds are the client area and the window frame sits outside them, so the frame takes
    // its share of the room: the title bar everywhere, the padded edges on Windows as well
    var frame := GetSystemMetrics(SM_CYCAPTION);
    {$ifdef WINDOWS}
    const SM_CXPADDEDBORDER = 92;
    frame += 2*(GetSystemMetrics(SM_CYSIZEFRAME)+GetSystemMetrics(SM_CXPADDEDBORDER));
    {$endif}
    h -= frame;
    var top := wa.Top+(wa.Height-h-frame) div 2;
    fMainBar.SetBounds(wa.Left+(wa.Width-w) div 2, top, w, h);
  end;
  if fHaveMainBounds and fMainMaximized then fMainBar.WindowState := wsMaximized;
  fMainBoundsApplied := true;
end;

procedure TPanesDockMaster.showMain;
begin
  if not fMainBoundsApplied then applyMainBounds;
  fMainBar.Show;
  layoutMainHost;
end;

procedure TPanesDockMaster.showEditor(aForm: TCustomForm; bringToFront: boolean);
begin
  ensureMainHost;
  var hosted := if fCenter <> nil then fCenter.hostedForm else nil;
  if (fCenter <> nil) and ((hosted = nil) or (hosted = aForm)) then begin
    if aForm.Parent <> fCenter then begin
      aForm.DisableAutoSizing;
      try
        clearLayoutProperties(aForm);
        aForm.Parent := fCenter;
        embedForm(aForm);
        aForm.Align := alClient;
      finally
        aForm.EnableAutoSizing;
      end;
    end;
    aForm.Visible := true;
    if bringToFront and (fMainBar <> nil) and not fMainBar.Active then fMainBar.ShowOnTop;
    exit;
  end;
  if aForm.Parent <> nil then begin
    aForm.Visible := true;
    var window := GetParentForm(aForm);
    if bringToFront and (window <> nil) and not window.Active then window.ShowOnTop;
    exit;
  end;
  // another editor gets a window of its own, at the place saved for its name
  var saved: TEditorWindowData;
  var restored := takeEditorLayout(aForm.Name, saved);
  var designer := fPendingDesigner or (restored and saved.designer);
  fPendingDesigner := false;
  var window := createEditorWindow(aForm, designer, not restored);
  if restored then begin
    applyWindow(window, saved.window);
    saved.window.root.Free;
    if (mapManager <> nil) and (window.notebook <> nil) then mapManager.setWindowShown(window.notebook, saved.codeMap);
  end else window.Show;
  if bringToFront and not window.Active then window.ShowOnTop;
end;

procedure TPanesDockMaster.showPane(aForm: TCustomForm; bringToFront: boolean);
begin
  var side := descriptorOf(aForm.Name).side;
  var frame := frameOf(aForm);
  if frame = nil then begin
    ensureMainHost;
    var host := if hostAlive(fTargetHost) then fTargetHost else fMainHost;
    if host = nil then begin
      aForm.Show;
      exit;
    end;
    frame := frameFor(aForm, host);
    if hostOf(frame) = nil then placeDefault(host, frame, side);
  end;
  // the pane opened from the menu of another window moves over, tab mates included
  if hostAlive(fTargetHost) and (hostOf(frame) <> fTargetHost) then begin
    var source := hostOf(frame);
    if source <> nil then source.detach(frame);
    reown(frame, fTargetHost);
    placeDefault(fTargetHost, frame, side);
  end;
  fPending.Remove(aForm);
  frame.activate(aForm);
  var window := GetParentForm(frame);
  if window = nil then exit;
  if not window.Visible then window.Show;
  if bringToFront and not window.Active then window.ShowOnTop;
end;

procedure TPanesDockMaster.MakeIDEWindowDockable(AControl: TWinControl);
begin
  // panes get their frame when they are shown
end;

procedure TPanesDockMaster.MakeIDEWindowDockSite(AForm: TCustomForm; ASides: TDockSides);
begin
  fMainBar := AForm;
  ensureMainHost;
end;

procedure TPanesDockMaster.ShowForm(AForm: TCustomForm; BringToFront: boolean);
begin
  if AForm = fMainBar then showMain
  else if AForm is TDockWindow then AForm.Show
  else if AForm is TSourceEditorWindowInterface then showEditor(AForm, BringToFront)
  else showPane(AForm, BringToFront);
end;

function TPanesDockMaster.AddableInWindowMenu(AForm: TCustomForm): boolean;
begin
  result := not (AForm is TDockWindow) and AForm.IsVisible;
end;

procedure TPanesDockMaster.AdjustMainIDEWindowHeight(const AIDEWindow: TCustomForm; const AAdjustHeight: Boolean; const ANewHeight: Integer);
begin
  if (fMainHost = nil) or (AIDEWindow <> fMainBar) then exit;
  fTopHeight := ANewHeight;
  layoutMainHost;
end;

procedure TPanesDockMaster.CloseAll;
begin
  while fWindows.Count > 0 do windows(fWindows.Count-1).Close;
  inherited CloseAll;
end;

procedure TPanesDockMaster.ResetSplitters;
begin
  layoutMainHost;
  if fMainHost <> nil then fMainHost.arrange;
end;

function TPanesDockMaster.DockedDesktopOptClass: TAbstractDesktopDockingOptClass;
begin
  result := TPanesDesktopOpt;
end;

procedure TPanesDockMaster.SetMainDockWindow(AForm: TCustomForm);
begin
  fMainBar := AForm;
end;

function TPanesDockMaster.createWindow(withCenter: boolean; designer: boolean): TDockWindow;
begin
  var n := 1;
  while Screen.FindForm('PaneWindow'+IntToStr(n)) <> nil do inc(n);
  result := TDockWindow.CreateNew(Application);
  result.Name := 'PaneWindow'+IntToStr(n);
  if withCenter then result.createCenter;
  result.designer := designer;
  result.OnClose := @windowClose;
  // owned by the main window, so it stays above it without blocking it
  result.PopupParent := fMainBar;
  var r := Screen.WorkAreaRect;
  if fMainBar <> nil then r := fMainBar.BoundsRect;
  result.SetBounds(r.Left+60, r.Top+60, 700, 500);
  fWindows.Add(result);
  if Assigned(fOnWindowCreated) then fOnWindowCreated(result);
end;

function TPanesDockMaster.captureNode(control: TControl; weight: double): TLayoutNode;
begin
  result := nil;
  if control = nil then exit;
  result := TLayoutNode.Create;
  result.weight := weight;
  if control is TPaneSplit then begin
    var split := TPaneSplit(control);
    result.kind := nkSplit;
    result.orientation := split.orientation;
    SetLength(result.children, split.itemCount);
    for var i := 0 to split.itemCount-1 do result.children[i] := captureNode(split.items[i], split.weights[i]);
  end else if control is TPaneFrame then begin
    var frame := TPaneFrame(control);
    result.kind := nkFrame;
    SetLength(result.panes, frame.formCount);
    for var i := 0 to frame.formCount-1 do begin
      result.panes[i].name := frame.forms[i].Name;
      result.panes[i].active := frame.form = frame.forms[i];
    end;
  end else result.kind := nkCenter;
end;

function TPanesDockMaster.captureWindow(host: TPaneHost; aForm: TCustomForm): TWindowData;
begin
  result.bounds := restoredBounds(aForm);
  result.maximized := aForm.WindowState = wsMaximized;
  result.root := captureNode(host.root, 1);
end;

function TPanesDockMaster.captureLayout: TLayoutData;

  procedure addEditor(window: TDockWindow; notebook: TSourceEditorWindowInterface);
  begin
    SetLength(result.editors, Length(result.editors)+1);
    result.editors[High(result.editors)].name := notebook.Name;
    result.editors[High(result.editors)].designer := window.designer;
    result.editors[High(result.editors)].codeMap := (mapManager = nil) or mapManager.windowShown(notebook);
    result.editors[High(result.editors)].window := captureWindow(window.host, window);
  end;

begin
  result := defaultLayout;
  if (fMainHost = nil) or (fMainBar = nil) then exit;
  freeLayout(result);
  result.main := captureWindow(fMainHost, fMainBar);
  for var i := 0 to fWindows.Count-1 do begin
    var window := windows(i);
    var notebook := window.notebook;
    if notebook <> nil then addEditor(window, notebook) else begin
      SetLength(result.windows, Length(result.windows)+1);
      result.windows[High(result.windows)] := captureWindow(window.host, window);
    end;
  end;
end;

// saved editor window with the name, taken out of the list; the caller frees its tree
function TPanesDockMaster.takeEditorLayout(const name: string; out data: TEditorWindowData): boolean;
begin
  for var i := 0 to High(fEditorLayouts) do if SameText(fEditorLayouts[i].name, name) then begin
    data := fEditorLayouts[i];
    Delete(fEditorLayouts, i, 1);
    exit(true);
  end;
  result := false;
end;

procedure TPanesDockMaster.dropEditorLayouts;
begin
  for var i := 0 to High(fEditorLayouts) do fEditorLayouts[i].window.root.Free;
  fEditorLayouts := nil;
end;

// builds the control of a saved node; nil when nothing of it can be shown
function TPanesDockMaster.applyNode(host: TPaneHost; node: TLayoutNode): TControl;
begin
  result := nil;
  if node = nil then exit;
  match node.kind of
    nkCenter: result := host.center;
    nkFrame: begin
      var frame: TPaneFrame := nil;
      var active: TCustomForm := nil;
      for var i := 0 to High(node.panes) do begin
        if node.panes[i].name = '' then continue;
        var aForm: TCustomForm;
        // a pane the IDE cannot create anymore drops out; the rest of the layout still loads
        try
          aForm := IDEWindowCreators.GetForm(node.panes[i].name, true, false);
        except
          on E: Exception do begin
            DebugLn(['TPanesDockMaster.applyNode: skipping pane ', node.panes[i].name, ': ', E.Message]);
            continue;
          end;
        end;
        if (aForm = nil) or (aForm = fMainBar) or (aForm is TSourceEditorWindowInterface) or (frameOf(aForm) <> nil) then continue;
        // a debug pane goes to the Debug frame wherever the layout put that one
        var target := frameFor(aForm, host, frame);
        if (frame = nil) and (hostOf(target) = nil) then frame := target;
        if node.panes[i].active and (target = frame) then active := aForm;
      end;
      if frame = nil then exit;
      // every attach made its form the tab on top, so the saved one goes back on top
      if active <> nil then frame.activate(active);
      result := frame;
    end;
    nkSplit: begin
      var split := TPaneSplit.Create(host, node.orientation);
      for var i := 0 to High(node.children) do begin
        var child := applyNode(host, node.children[i]);
        if child <> nil then split.insertItem(child, -1, node.children[i].weight);
      end;
      if split.itemCount = 1 then begin
        result := split.items[0];
        split.removeItem(result);
      end else if split.itemCount > 1 then result := split;
      if result <> split then split.Free;
    end;
  end;
end;

// replaces the tree of the host with the saved one; the center stays in either way
procedure TPanesDockMaster.applyTree(host: TPaneHost; node: TLayoutNode);
begin
  host.setRoot(nil);
  host.setRoot(applyNode(host, node));
  host.ensureCenter;
  host.arrange;
end;

procedure TPanesDockMaster.applyWindow(window: TDockWindow; const data: TWindowData);
begin
  if validBounds(data.bounds) then window.BoundsRect := data.bounds;
  applyTree(window.host, data.root);
  window.Show;
  if data.maximized then window.WindowState := wsMaximized;
end;

procedure TPanesDockMaster.applyLayout(const data: TLayoutData);
begin
  ensureMainHost;
  if fMainHost = nil then exit;
  var editors := TFPList.Create;
  try
    // drop the live layout first; the editors of the editor windows stay for the rebuild
    clearHost(fMainHost);
    for var i := 0 to fWindows.Count-1 do clearHost(windows(i).host);
    while fWindows.Count > 0 do begin
      var window := windows(fWindows.Count-1);
      fWindows.Remove(window);
      var editor := if window.center <> nil then window.center.hostedForm else nil;
      if editor <> nil then begin
        editor.Parent := nil;
        PanesLayout.releaseForm(editor);
        editors.Add(editor);
      end;
      window.OnClose := nil;
      window.Free;
    end;
    dropEditorLayouts;
    for var i := 0 to High(data.editors) do begin
      Insert(data.editors[i], fEditorLayouts, Length(fEditorLayouts));
      fEditorLayouts[High(fEditorLayouts)].window := cloneWindow(data.editors[i].window);
    end;
    fMainBounds := data.main.bounds;
    fMainMaximized := data.main.maximized;
    fHaveMainBounds := validBounds(fMainBounds);
    if fMainBar.Visible then applyMainBounds;
    applyTree(fMainHost, data.main.root);
    for var i := 0 to High(data.windows) do applyWindow(createWindow, data.windows[i]);
    // the editors open now take their saved place; the others do when the IDE shows them
    for var i := 0 to Screen.CustomFormCount-1 do begin
      var aForm := Screen.CustomForms[i];
      if (aForm is TSourceEditorWindowInterface) and (aForm.Parent = nil) and aForm.Visible and (editors.IndexOf(aForm) < 0) then editors.Add(aForm);
    end;
    for var i := 0 to editors.Count-1 do showEditor(TCustomForm(editors[i]), false);
  finally
    editors.Free;
  end;
end;

function TPanesDockMaster.isDocked(aForm: TCustomForm): boolean;
begin
  result := frameOf(aForm) <> nil;
end;

function TPanesDockMaster.windowCount: integer;
begin
  result := fWindows.Count;
end;

function TPanesDockMaster.windows(index: integer): TDockWindow;
begin
  result := TDockWindow(fWindows[index]);
end;

function TPanesDockMaster.designerWindowOf(const fileName: string): TDockWindow;
begin
  result := nil;
  for var i := 0 to fWindows.Count-1 do begin
    var window := windows(i);
    var notebook := window.notebook;
    if not window.designer or (notebook = nil) or (notebook.ActiveEditor = nil) then continue;
    if CompareFilenames(notebook.ActiveEditor.FileName, fileName) = 0 then exit(window);
  end;
end;

function TPanesDockMaster.pickDesignerEditor(editor: TSourceEditorInterface): TSourceEditorInterface;
begin
  result := editor;
  if editor = nil then exit;
  var window := designerWindowOf(editor.FileName);
  if (window = nil) or (window.notebook.ActiveEditor = editor) then exit;
  result := window.notebook.ActiveEditor;
  window.Show;
end;

// -- TPanesDesktopOpt ----------------------------------------------------------

constructor TPanesDesktopOpt.Create;
begin
  inherited Create;
  fData := defaultLayout;
end;

destructor TPanesDesktopOpt.Destroy;
begin
  freeLayout(fData);
  inherited Destroy;
end;

procedure TPanesDesktopOpt.StoreWindowPositions;
begin
  if dockMaster = nil then exit;
  freeLayout(fData);
  fData := dockMaster.captureLayout;
end;

procedure TPanesDesktopOpt.LoadDefaults;
begin
  freeLayout(fData);
  fData := defaultLayout;
end;

function loadNode(cfg: TRttiXMLConfig; const path: string): TLayoutNode;
begin
  result := nil;
  var kind := cfg.GetValue(path+'Kind', -1);
  if (kind < 0) or (kind > ord(high(TNodeKind))) then exit;
  result := TLayoutNode.Create;
  result.kind := TNodeKind(kind);
  result.orientation := TSplitOrientation(EnsureRange(cfg.GetValue(path+'Orientation', 0), 0, ord(high(TSplitOrientation))));
  result.weight := cfg.GetExtendedValue(path+'Weight', 1);
  SetLength(result.panes, cfg.GetValue(path+'Panes/Count', 0));
  for var i := 0 to High(result.panes) do begin
    result.panes[i].name := cfg.GetValue($'{path}Panes/Item{i+1}/Name', '');
    result.panes[i].active := cfg.GetValue($'{path}Panes/Item{i+1}/Active', false);
  end;
  var count := cfg.GetValue(path+'Items/Count', 0);
  for var i := 0 to count-1 do begin
    var child := loadNode(cfg, $'{path}Items/Item{i+1}/');
    if child <> nil then Insert(child, result.children, Length(result.children));
  end;
end;

procedure saveNode(cfg: TRttiXMLConfig; const path: string; node: TLayoutNode);
begin
  if node = nil then exit;
  cfg.SetValue(path+'Kind', ord(node.kind));
  cfg.SetDeleteValue(path+'Orientation', ord(node.orientation), 0);
  cfg.SetExtendedValue(path+'Weight', node.weight);
  if Length(node.panes) > 0 then cfg.SetValue(path+'Panes/Count', Length(node.panes));
  for var i := 0 to High(node.panes) do begin
    cfg.SetValue($'{path}Panes/Item{i+1}/Name', node.panes[i].name);
    cfg.SetDeleteValue($'{path}Panes/Item{i+1}/Active', node.panes[i].active, false);
  end;
  if Length(node.children) > 0 then cfg.SetValue(path+'Items/Count', Length(node.children));
  for var i := 0 to High(node.children) do saveNode(cfg, $'{path}Items/Item{i+1}/', node.children[i]);
end;

procedure loadWindow(cfg: TRttiXMLConfig; const path: string; out data: TWindowData);
begin
  cfg.GetValue(path+'Bounds', data.bounds, Rect(0, 0, 0, 0));
  data.maximized := cfg.GetValue(path+'Maximized', false);
  data.root := loadNode(cfg, path+'Root/');
end;

procedure saveWindow(cfg: TRttiXMLConfig; const path: string; const data: TWindowData);
begin
  cfg.SetDeleteValue(path+'Bounds', data.bounds, Rect(0, 0, 0, 0));
  cfg.SetDeleteValue(path+'Maximized', data.maximized, false);
  saveNode(cfg, path+'Root/', data.root);
end;

procedure TPanesDesktopOpt.Load(Path: String; aXMLCfg: TRttiXMLConfig);
begin
  LoadDefaults;
  Path += 'Panes/';
  if aXMLCfg.GetValue(Path+'Version', 0) < LAYOUT_VERSION then exit;
  freeLayout(fData);
  loadWindow(aXMLCfg, Path+'Main/', fData.main);
  SetLength(fData.windows, aXMLCfg.GetValue(Path+'Windows/Count', 0));
  for var i := 0 to High(fData.windows) do loadWindow(aXMLCfg, $'{Path}Windows/Item{i+1}/', fData.windows[i]);
  SetLength(fData.editors, aXMLCfg.GetValue(Path+'Editors/Count', 0));
  for var i := 0 to High(fData.editors) do begin
    var p := $'{Path}Editors/Item{i+1}/';
    fData.editors[i].name := aXMLCfg.GetValue(p+'Name', '');
    fData.editors[i].designer := aXMLCfg.GetValue(p+'Designer', false);
    fData.editors[i].codeMap := aXMLCfg.GetValue(p+'CodeMap', true);
    loadWindow(aXMLCfg, p, fData.editors[i].window);
  end;
end;

procedure TPanesDesktopOpt.Save(Path: String; aXMLCfg: TRttiXMLConfig);
begin
  Path += 'Panes/';
  aXMLCfg.DeletePath(Copy(Path, 1, Length(Path)-1));
  aXMLCfg.SetValue(Path+'Version', LAYOUT_VERSION);
  saveWindow(aXMLCfg, Path+'Main/', fData.main);
  aXMLCfg.SetValue(Path+'Windows/Count', Length(fData.windows));
  for var i := 0 to High(fData.windows) do saveWindow(aXMLCfg, $'{Path}Windows/Item{i+1}/', fData.windows[i]);
  aXMLCfg.SetValue(Path+'Editors/Count', Length(fData.editors));
  for var i := 0 to High(fData.editors) do begin
    var p := $'{Path}Editors/Item{i+1}/';
    aXMLCfg.SetValue(p+'Name', fData.editors[i].name);
    aXMLCfg.SetDeleteValue(p+'Designer', fData.editors[i].designer, false);
    aXMLCfg.SetDeleteValue(p+'CodeMap', fData.editors[i].codeMap, true);
    saveWindow(aXMLCfg, p, fData.editors[i].window);
  end;
end;

procedure TPanesDesktopOpt.ImportSettingsFromIDE;
begin
  StoreWindowPositions;
end;

procedure TPanesDesktopOpt.ExportSettingsToIDE;
begin
  // RestoreDesktop applies the layout
end;

function TPanesDesktopOpt.RestoreDesktop: Boolean;
begin
  result := dockMaster <> nil;
  if result then dockMaster.applyLayout(fData);
end;

procedure TPanesDesktopOpt.Assign(Source: TAbstractDesktopDockingOpt);
begin
  if not (Source is TPanesDesktopOpt) then exit;
  freeLayout(fData);
  fData := cloneLayout(TPanesDesktopOpt(Source).fData);
end;

initialization
  addDescriptor('ObjectInspectorDlg', PANE_OBJECT_INSPECTOR, dsLeft, [pfCanDuplicate]);
  addDescriptor('CodeExplorerView', PANE_CODE_EXPLORER, dsLeft, [pfCanDuplicate]);
  addDescriptor('ProjectInspector', PANE_PROJECT_INSPECTOR, dsRight, [pfCanDuplicate]);
  addDescriptor('ComponentList', PANE_COMPONENTS, dsRight, [pfCanDuplicate]);
  addDescriptor('MessagesView', PANE_MESSAGES, dsBottom, [pfDebug]);
  addDescriptor('UnitDependencies', PANE_UNIT_DEPENDENCIES, dsRight, []);
  addDescriptor('FPDocEditor', PANE_FPDOC_EDITOR, dsBottom, []);
  addDescriptor('SearchResults', PANE_SEARCH_RESULTS, dsBottom, []);
  addDescriptor('AnchorEditor', PANE_ANCHOR_EDITOR, dsRight, []);
  addDescriptor('TabOrderEditor', PANE_TAB_ORDER, dsRight, []);
  addDescriptor('CodeBrowser', PANE_CODE_BROWSER, dsLeft, []);
  addDescriptor('IssueBrowser', PANE_RESTRICTION_BROWSER, dsBottom, []);
  addDescriptor('JumpHistory', PANE_JUMP_HISTORY, dsLeft, [pfCanDuplicate]);
  addDescriptor('EditorFileManager', PANE_EDITOR_FILE_MANAGER, dsLeft, []);
  addDescriptor('MacroListViewer', PANE_MACRO_LIST, dsRight, []);
  addDescriptor('Watches', PANE_WATCHES, dsBottom, [pfDebug]);
  addDescriptor('BreakPoints', PANE_BREAKPOINTS, dsBottom, [pfDebug]);
  addDescriptor('Locals', PANE_LOCALS, dsBottom, [pfDebug]);
  addDescriptor('CallStack', PANE_CALL_STACK, dsBottom, [pfDebug]);
  addDescriptor('Registers', PANE_REGISTERS, dsBottom, [pfDebug]);
  addDescriptor('Assembler', PANE_ASSEMBLER, dsBottom, [pfDebug]);
  addDescriptor('Threads', PANE_THREADS, dsBottom, [pfDebug]);
  addDescriptor('DbgOutput', PANE_DEBUG_OUTPUT, dsBottom, [pfDebug]);
  addDescriptor('DbgEvents', PANE_DEBUG_EVENTS, dsBottom, [pfDebug]);
  addDescriptor('EvaluateModify', PANE_EVALUATE, dsBottom, [pfDebug]);
  addDescriptor('MemViewer', PANE_MEM_VIEWER, dsBottom, [pfDebug]);
  addDescriptor('Inspect', PANE_INSPECT, dsBottom, [pfDebug]);
  // the IDE opens the console of the debugged program only where the debugger has a pty
  {$ifdef linux}
  addDescriptor('PseudoTerminal', PANE_TERMINAL, dsBottom, [pfDebug]);
  {$endif}
  addDescriptor('DbgHistory', PANE_HISTORY, dsBottom, [pfDebug]);
end.
