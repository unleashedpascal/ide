{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PanesLayout;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Math, Controls, Forms, Graphics, LCLType, LCLIntf, Themes{$ifdef LCLWin32}, ThemesConfig, ThemesManager, ThemesWin32{$endif};

const
  SPLITTER_SIZE = 5;
  HEADER_HEIGHT = 22;
  BODY_PADDING = 4;
  BUTTON_SIZE = 18;
  MIN_PANE_SIZE = 48;
  // strip along a window edge that takes a dragged pane
  EDGE_ZONE_SIZE = 24;
  // square in the middle of an empty window that takes a dragged pane
  FILL_ZONE_SIZE = 80;
  // band along the side of a leaf that splits it, a quarter of the leaf within these
  LEAF_ZONE_MIN = 16;
  LEAF_ZONE_MAX = 60;

type
  TPaneSplit = class;
  TPaneHost = class;
  TPaneFrame = class;

  // side of a window or of a leaf a pane goes to
  TDockSide = (dsLeft, dsRight, dsBottom, dsTop);
  // horizontal lines the items up, vertical stacks them
  TSplitOrientation = (soHorizontal, soVertical);
  // where a dragged pane may land: along a window edge, beside a leaf, as a
  // tab of a frame, or as the whole content of an empty window
  TDropKind = (dzNone, dzEdge, dzSplit, dzTab, dzFill);
  TDropZone = record
    kind: TDropKind;
    side: TDockSide;
    target: TControl;
    rect: TRect;
    // where the pane ends up, for the preview
    landing: TRect;
  end;
  TDropZones = array of TDropZone;
  TPaneButton = (pbNone, pbClose, pbMove);
  TPaneButtonEvent = procedure(Sender: TObject; button: TPaneButton) of object;
  TSplitterDragEvent = procedure(Sender: TObject; delta: integer) of object;
  TPaneDragEvent = procedure(Sender: TObject; const screenPos: TPoint) of object;
  // right click on the tab strip; tab is -1 outside the tabs
  TTabPopupEvent = procedure(Sender: TObject; tab: integer; const screenPos: TPoint) of object;
  // a tab pulled off the strip; the strip keeps the mouse and reports the drag
  TTabDragEvent = procedure(Sender: TObject; tab: integer) of object;

  { TPaneOverlay }

  // cover laid over the body of a pane while the panes identify themselves
  TPaneOverlay = class(TCustomControl)
  private
    fText: string;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property text: string read fText write fText;
  end;

  { TPaneTabBar }

  // tab strip of a frame with several forms, drawn like the tabs of a page
  // control; tabs switch on click and reorder by dragging
  TPaneTabBar = class(TCustomControl)
  private
    fFrame: TPaneFrame;
    fPressed: integer;
    fPressX: integer;
    fDragging: boolean;
    fDragOut: boolean;
    fHot: integer;
    function tabRect(index: integer): TRect;
    function tabAt(x: integer): integer;
    procedure drawTab(index: integer; selected: boolean);
    procedure setHot(value: integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    // height of the strip for the font of the control
    function stripHeight: integer;
    property frame: TPaneFrame read fFrame write fFrame;
  end;

  { TPaneFrame }

  // frame around the hosted forms: a title bar with the buttons over a padded
  // body; a tabbed frame keeps a tab strip at the top of the body
  TPaneFrame = class(TCustomControl)
  private
    fForms: TFPList;
    fActive: TCustomForm;
    fOverlay: TPaneOverlay;
    fTabs: TPaneTabBar;
    fTitle: string;
    fHot: TPaneButton;
    fPressed: TPaneButton;
    fShownCaption: string;
    fSwitching: boolean;
    fDragging: boolean;
    fClosable: boolean;
    fMovable: boolean;
    fOnButton: TPaneButtonEvent;
    fOnTabPopup: TTabPopupEvent;
    fOnTabDrag: TTabDragEvent;
    fOnDrag: TPaneDragEvent;
    fOnDrop: TPaneDragEvent;
    fOnCancel: TNotifyEvent;
    function getForm(index: integer): TCustomForm;
    function getFormCount: integer;
    function getTabbed: boolean;
    procedure setTabbed(value: boolean);
    procedure setTitle(const value: string);
    function headerRect: TRect;
    function buttonRect(button: TPaneButton): TRect;
    function buttonAt(x, y: integer): TPaneButton;
    function captions: string;
    function headerHeight: integer;
    function bodyRect: TRect;
    procedure setHot(value: TPaneButton);
    procedure setIdentify(value: boolean);
    function getIdentify: boolean;
    procedure layoutForms;
    procedure drawButton(button: TPaneButton);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // puts the form inside the body as the active tab; the form keeps its owner
    procedure attach(aForm: TCustomForm);
    // takes the form out of the body without freeing it
    procedure detach(aForm: TCustomForm);
    procedure activate(aForm: TCustomForm);
    function contains(aForm: TCustomForm): boolean;
    // changes the tab order
    procedure moveForm(fromIndex, toIndex: integer);
    // repaints the title when a hosted form renamed itself
    procedure syncCaption;
    // relayouts after the title bar or padding settings changed
    procedure applyGeometry;
    // puts a hosted form back into the body after it resized itself
    procedure ensureLayout;
    // caption of the frame; empty means the caption of the active form
    property title: string read fTitle write setTitle;
    // shows the name over the body, the title bar stays usable
    property identify: boolean read getIdentify write setIdentify;
    // a tab strip in the body, whatever the number of forms
    property tabbed: boolean read getTabbed write setTabbed;
    property forms[index: integer]: TCustomForm read getForm;
    property formCount: integer read getFormCount;
    property form: TCustomForm read fActive;
    // true while the frame itself hides and shows forms to switch tabs
    property switching: boolean read fSwitching;
    property onButton: TPaneButtonEvent read fOnButton write fOnButton;
    property onTabPopup: TTabPopupEvent read fOnTabPopup write fOnTabPopup;
    // a tab pulled off the strip; the drag events that follow carry it alone
    property onTabDrag: TTabDragEvent read fOnTabDrag write fOnTabDrag;
    // mouse travel while the move button is held, then the release
    property onDrag: TPaneDragEvent read fOnDrag write fOnDrag;
    property onDrop: TPaneDragEvent read fOnDrop write fOnDrop;
    // the right button pressed during the drag
    property onCancel: TNotifyEvent read fOnCancel write fOnCancel;
    // without the close button the frame stays until its window goes
    property closable: boolean read fClosable write fClosable;
    property movable: boolean read fMovable write fMovable;
  end;

  { TPaneSplitter }

  // bar between two neighbors; reports the mouse travel, the owner resizes
  TPaneSplitter = class(TCustomControl)
  private
    fVertical: boolean;
    fDragging: boolean;
    fDragStart: integer;
    fOnDrag: TSplitterDragEvent;
    procedure setVertical(value: boolean);
    function mousePos: integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    // an upright bar moves left and right
    property vertical: boolean read fVertical write setVertical;
    property onDrag: TSplitterDragEvent read fOnDrag write fOnDrag;
  end;

  { TPaneSplit }

  // node of the layout tree: lines its items up or stacks them with a
  // splitter between neighbors; an item is a frame, the center or a split
  TPaneSplit = class(TCustomControl)
  private
    fOrientation: TSplitOrientation;
    fItems: TFPList;
    fWeights: array of double;
    fSplitters: TFPList;
    fArranging: boolean;
    function getItem(index: integer): TControl;
    function getItemCount: integer;
    function getWeight(index: integer): double;
    procedure setWeight(index: integer; value: double);
    procedure splitterDrag(Sender: TObject; delta: integer);
  protected
    procedure Resize; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent; anOrientation: TSplitOrientation); reintroduce;
    destructor Destroy; override;
    // index -1 appends
    procedure insertItem(control: TControl; index: integer; weight: double);
    procedure removeItem(control: TControl);
    // the new control takes the place and the weight of the old one
    procedure replaceItem(old, control: TControl);
    function indexOf(control: TControl): integer;
    function weightSum: double;
    procedure arrange;
    property orientation: TSplitOrientation read fOrientation;
    property items[index: integer]: TControl read getItem;
    property itemCount: integer read getItemCount;
    // share of the length an item takes, relative to its siblings
    property weights[index: integer]: double read getWeight write setWeight;
  end;

  { TPaneCenter }

  // flat area between the docks of a window; the source editor lives in it
  TPaneCenter = class(TCustomControl)
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the form hosted inside, nil when empty
    function hostedForm: TCustomForm;
  end;

  { TPaneHost }

  // the layout tree of one window: a root control filling the host, nil while
  // the window is empty; the center of an editor window is a leaf of the tree
  TPaneHost = class(TCustomControl)
  private
    fRoot: TControl;
    fCenter: TWinControl;
    fTopEdge: boolean;
    procedure replaceNode(old, control: TControl);
    // a split of the same orientation as its parent hands its items over
    procedure flatten(split: TPaneSplit);
    procedure collectLeaves(control: TControl; list: TFPList);
    function rectOf(control: TControl): TRect;
  protected
    procedure Resize; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the whole tree; nil empties the host without freeing anything
    procedure setRoot(control: TControl);
    // the center fills an empty host on its own
    procedure setCenter(control: TWinControl);
    // puts the center back into the tree when a layout left it out
    procedure ensureCenter;
    // the frames and the center, in layout order
    function leaves: TFPList;
    function frames: TFPList;
    function containsCenter(control: TControl): boolean;
    // another frame of the host shows the same window as the frame, or a copy of it
    function holdsCopyOf(frame: TPaneFrame): boolean;
    // a frame other than `source` shows a copy of the form
    function holdsCopyOf(aForm: TCustomForm; source: TPaneFrame): boolean;
    // the control becomes the whole content of an empty host
    procedure fill(control: TControl);
    // a new outermost split along the side of the window
    procedure insertAtEdge(control: TControl; side: TDockSide);
    // the control takes a third of the target on that side
    procedure splitBeside(target, control: TControl; side: TDockSide);
    // takes the control out of the tree; a split left with one item collapses
    procedure detach(control: TControl);
    // the window edges and the middle of an empty host
    function outerZones: TDropZones;
    // the sides of the leaf and, for a frame, its middle
    function zonesOf(leaf, dragged: TControl): TDropZones;
    // the zone under the client point while the control is dragged
    function zoneAt(x, y: integer; dragged: TControl; out zone: TDropZone): boolean;
    // puts the control where the zone says; a tab zone is for the caller
    procedure drop(const zone: TDropZone; control: TControl);
    procedure arrange;
    property root: TControl read fRoot;
    property center: TWinControl read fCenter;
    // drops along the top edge and above the center are allowed
    property topEdge: boolean read fTopEdge write fTopEdge;
  end;

var
  // title bars of every pane; without them the tabs switch through the menu
  paneHeaderShown: boolean = true;
  // gap between the frame and the hosted form
  panePadding: integer = BODY_PADDING;

// resets everything the previous parent may have set on the form
procedure clearLayoutProperties(control: TControl);
// strips the window frame so the form sits flat inside a parent; the frame
// comes back with releaseForm
procedure embedForm(aForm: TCustomForm);
procedure releaseForm(aForm: TCustomForm);
// the host whose tree holds the control
function hostOf(control: TControl): TPaneHost;
function parentSplit(control: TControl): TPaneSplit;
function orientationOf(side: TDockSide): TSplitOrientation;
function sameZone(const a, b: TDropZone): boolean;
// design pixels at 96 dpi to screen pixels
function px(value: integer): integer;
function splitterSize: integer;
// percent of the tint blended into the base
function mix(base, tint: TColor; percent: integer): TColor;
// percent > 0 moves the color toward white, < 0 toward black
function shade(color: TColor; percent: integer): TColor;
function isDark(color: TColor): boolean;
function faceColor: TColor;
function bodyColor: TColor;
function headerColor: TColor;

implementation

procedure clearLayoutProperties(control: TControl);
begin
  control.AutoSize := false;
  control.Align := alNone;
  control.BorderSpacing.Around := 0;
  control.BorderSpacing.Left := 0;
  control.BorderSpacing.Top := 0;
  control.BorderSpacing.Right := 0;
  control.BorderSpacing.Bottom := 0;
  control.BorderSpacing.InnerBorder := 0;
  for var a := low(TAnchorKind) to high(TAnchorKind) do control.AnchorSide[a].Control := nil;
  control.Anchors := [akLeft, akTop];
end;

var
  // forms stripped of their frame, with the border style to give back
  embedded: TFPList = nil;
  embeddedStyles: TFPList = nil;

procedure embedForm(aForm: TCustomForm);
begin
  if embedded = nil then begin
    embedded := TFPList.Create;
    embeddedStyles := TFPList.Create;
  end;
  if embedded.IndexOf(aForm) >= 0 then exit;
  embedded.Add(aForm);
  embeddedStyles.Add(Pointer(PtrUInt(ord(aForm.BorderStyle))));
  aForm.BorderStyle := bsNone;
end;

procedure releaseForm(aForm: TCustomForm);
begin
  if embedded = nil then exit;
  var i := embedded.IndexOf(aForm);
  if i < 0 then exit;
  aForm.BorderStyle := TFormBorderStyle(PtrUInt(embeddedStyles[i]));
  embedded.Delete(i);
  embeddedStyles.Delete(i);
end;

function hostOf(control: TControl): TPaneHost;
begin
  result := nil;
  while control <> nil do begin
    if control is TPaneHost then exit(TPaneHost(control));
    control := control.Parent;
  end;
end;

function parentSplit(control: TControl): TPaneSplit;
begin
  result := if (control <> nil) and (control.Parent is TPaneSplit) then TPaneSplit(control.Parent) else nil;
end;

function orientationOf(side: TDockSide): TSplitOrientation;
begin
  result := if side in [dsLeft, dsRight] then soHorizontal else soVertical;
end;

function sameZone(const a, b: TDropZone): boolean;
begin
  result := (a.kind = b.kind) and (a.side = b.side) and (a.target = b.target);
end;

function mix(base, tint: TColor; percent: integer): TColor;

  function channel(a, b: integer): integer;
  begin
    result := a+(b-a)*percent div 100;
  end;

begin
  var c := ColorToRGB(base);
  var t := ColorToRGB(tint);
  result := RGBToColor(channel(Red(c), Red(t)), channel(Green(c), Green(t)), channel(Blue(c), Blue(t)));
end;

function shade(color: TColor; percent: integer): TColor;

  function channel(value: integer): integer;
  begin
    if percent >= 0 then result := value+(255-value)*percent div 100 else result := value+value*percent div 100;
  end;

begin
  var c := ColorToRGB(color);
  result := RGBToColor(channel(Red(c)), channel(Green(c)), channel(Blue(c)));
end;

function px(value: integer): integer;
begin
  result := MulDiv(value, Screen.PixelsPerInch, 96);
end;

function splitterSize: integer;
begin
  result := px(SPLITTER_SIZE);
end;

function isDark(color: TColor): boolean;
begin
  var c := ColorToRGB(color);
  result := (Red(c)*299+Green(c)*587+Blue(c)*114) div 1000 < 128;
end;

function faceColor: TColor;
begin
  result := ColorToRGB(clBtnFace);
end;

function bodyColor: TColor;
begin
  result := shade(faceColor, if isDark(faceColor) then 5 else 50);
end;

function headerColor: TColor;
begin
  result := shade(faceColor, if isDark(faceColor) then 12 else -8);
end;

function dimText: TColor;
begin
  result := shade(ColorToRGB(clBtnText), if isDark(headerColor) then -25 else 35);
end;

// -- TPaneTabBar ---------------------------------------------------------------

const
  DRAG_THRESHOLD = 4;

type
  // geometry of the tabs of a page control, in pixels of the screen
  TTabMetrics = record
    padX: integer;       // text padding inside a tab
    band: integer;       // free strip above the tabs
    inflate: integer;    // the selected tab grows this much over its neighbors and the strip
    itemHeight: integer; // height of a tab that is not selected
    minWidth: integer;
  end;

// the tabs of a page control with the font of the canvas: the theme engine
// pads the tabs of the IDE and keeps a band above them, the stock look keeps
// the defaults of the widgetset
function tabMetrics(aCanvas: TCanvas): TTabMetrics;
begin
  var tm := Default(TTextMetric);
  GetTextMetrics(aCanvas.Handle, tm);
  {$ifdef LCLWin32}
  result.inflate := 2;
  if currentThemeKind = tkDefault then begin
    result.padX := 6;
    result.band := 0;
    result.itemHeight := tm.tmHeight+5;
  end else begin
    result.padX := TAB_PAD_X;
    result.band := TAB_BAND;
    result.itemHeight := tm.tmHeight+2*TAB_PAD_Y+2;
  end;
  // a tab is at least six average characters wide
  result.minWidth := 6*tm.tmAveCharWidth+2*result.padX;
  {$else}
  result.padX := 8;
  result.band := 0;
  result.inflate := 0;
  result.itemHeight := tm.tmHeight+6;
  result.minWidth := 0;
  {$endif}
end;

// the part of the tab theme for a tab of the row
function tabElement(first, last, selected, hot: boolean): TThemedTab;
begin
  if selected then
    result := if first and last then ttTopTabItemBothEdgeSelected else if first then ttTopTabItemLeftEdgeSelected else if last then ttTopTabItemRightEdgeSelected else ttTopTabItemSelected
  else if hot then
    result := if first and last then ttTabItemBothEdgeHot else if first then ttTabItemLeftEdgeHot else if last then ttTabItemRightEdgeHot else ttTabItemHot
  else
    result := if first and last then ttTabItemBothEdgeNormal else if first then ttTabItemLeftEdgeNormal else if last then ttTabItemRightEdgeNormal else ttTabItemNormal;
end;

constructor TPaneTabBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  fPressed := -1;
  fHot := -1;
end;

procedure TPaneTabBar.setHot(value: integer);
begin
  if value = fHot then exit;
  fHot := value;
  Invalidate;
end;

function TPaneTabBar.stripHeight: integer;
begin
  // measured off screen, the frame lays out before the strip has a window
  var bmp := TBitmap.Create;
  try
    bmp.SetSize(1, 1);
    bmp.Canvas.Font := Font;
    var m := tabMetrics(bmp.Canvas);
    result := m.band+2*m.inflate+m.itemHeight;
  finally
    bmp.Free;
  end;
end;

// the tabs that are not selected; they run from the left edge after the room
// the selected one grows into
function TPaneTabBar.tabRect(index: integer): TRect;
begin
  result := Rect(0, 0, 0, 0);
  if fFrame = nil then exit;
  var m := tabMetrics(Canvas);
  var x := m.inflate;
  var top := m.band+m.inflate;
  for var i := 0 to fFrame.formCount-1 do begin
    var w := Max(Canvas.TextWidth(fFrame.forms[i].Caption)+2*m.padX, m.minWidth);
    if i = index then exit(Rect(x, top, x+w, top+m.itemHeight));
    x += w;
  end;
end;

function TPaneTabBar.tabAt(x: integer): integer;
begin
  result := -1;
  if fFrame = nil then exit;
  for var i := 0 to fFrame.formCount-1 do begin
    var r := tabRect(i);
    if (x >= r.Left) and (x < r.Right) then exit(i);
  end;
end;

// the selected tab grows over its neighbors on three sides; its text stays in
// the middle of the tab
procedure TPaneTabBar.drawTab(index: integer; selected: boolean);
begin
  var r := tabRect(index);
  if r.Left >= ClientWidth then exit;
  var text := r;
  if selected then begin
    var m := tabMetrics(Canvas);
    r.Inflate(m.inflate, m.inflate);
  end;
  var details := ThemeServices.GetElementDetails(tabElement(index = 0, index = fFrame.formCount-1, selected, index = fHot));
  ThemeServices.DrawElement(Canvas.Handle, details, r);
  Canvas.Font.Color := if selected then clBtnText else clGrayText;
  ThemeServices.DrawText(Canvas, details, fFrame.forms[index].Caption, text, DT_CENTER or DT_VCENTER or DT_SINGLELINE, 0);
end;

procedure TPaneTabBar.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);
  if fFrame = nil then exit;
  Canvas.Font := Font;
  var selected := -1;
  for var i := 0 to fFrame.formCount-1 do
    if fFrame.forms[i] = fFrame.form then selected := i else drawTab(i, false);
  // the selected tab comes last, it covers the edges of its neighbors
  if selected >= 0 then drawTab(selected, true);
end;

procedure TPaneTabBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if fFrame = nil then exit;
  if (Button = mbRight) and fDragOut then begin
    fDragOut := false;
    fPressed := -1;
    if Assigned(fFrame.onCancel) then fFrame.onCancel(fFrame);
    exit;
  end;
  var tab := tabAt(X);
  if Button = mbRight then begin
    if Assigned(fFrame.onTabPopup) then fFrame.onTabPopup(fFrame, tab, ClientToScreen(Point(X, Y)));
    exit;
  end;
  if (Button <> mbLeft) or (tab < 0) then exit;
  fFrame.activate(fFrame.forms[tab]);
  fPressed := tab;
  fPressX := X;
  fDragging := false;
end;

// a held tab slides over its neighbors and swaps places with them; pulled off
// the strip it goes on a drag of its own
procedure TPaneTabBar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if fFrame = nil then exit;
  if fDragOut then begin
    if Assigned(fFrame.onDrag) then fFrame.onDrag(fFrame, Mouse.CursorPos);
    exit;
  end;
  var hot := tabAt(X);
  if (hot >= 0) and not tabRect(hot).Contains(Point(X, Y)) then hot := -1;
  setHot(hot);
  if fPressed < 0 then exit;
  if ((Y < 0) or (Y >= ClientHeight)) and Assigned(fFrame.onTabDrag) then begin
    fDragOut := true;
    fDragging := false;
    fFrame.onTabDrag(fFrame, fPressed);
    if Assigned(fFrame.onDrag) then fFrame.onDrag(fFrame, Mouse.CursorPos);
    exit;
  end;
  if not fDragging and (Abs(X-fPressX) < px(DRAG_THRESHOLD)) then exit;
  fDragging := true;
  var target := tabAt(X);
  if target < 0 then target := if X < 0 then 0 else fFrame.formCount-1;
  if target = fPressed then exit;
  fFrame.moveForm(fPressed, target);
  fPressed := target;
  Invalidate;
end;

procedure TPaneTabBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  fPressed := -1;
  fDragging := false;
  if not fDragOut then exit;
  fDragOut := false;
  if Assigned(fFrame.onDrop) then fFrame.onDrop(fFrame, Mouse.CursorPos);
end;

procedure TPaneTabBar.MouseLeave;
begin
  inherited MouseLeave;
  setHot(-1);
end;

// -- TPaneFrame ----------------------------------------------------------------

constructor TPaneFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  fForms := TFPList.Create;
  fClosable := true;
  fMovable := true;
  fHot := pbNone;
  fPressed := pbNone;
end;

destructor TPaneFrame.Destroy;
begin
  fForms.Free;
  inherited Destroy;
end;

function TPaneFrame.getForm(index: integer): TCustomForm;
begin
  result := TCustomForm(fForms[index]);
end;

function TPaneFrame.getFormCount: integer;
begin
  result := fForms.Count;
end;

function TPaneFrame.getTabbed: boolean;
begin
  result := fTabs <> nil;
end;

procedure TPaneFrame.setTabbed(value: boolean);
begin
  if value = getTabbed then exit;
  if value then begin
    fTabs := TPaneTabBar.Create(Self);
    fTabs.frame := Self;
    fTabs.Parent := Self;
  end else FreeAndNil(fTabs);
  layoutForms;
  Invalidate;
end;

procedure TPaneFrame.setTitle(const value: string);
begin
  if value = fTitle then exit;
  fTitle := value;
  Invalidate;
end;

function TPaneFrame.headerHeight: integer;
begin
  result := if paneHeaderShown then px(HEADER_HEIGHT) else 0;
end;

function TPaneFrame.headerRect: TRect;
begin
  result := Rect(0, 0, ClientWidth, headerHeight);
end;

function TPaneFrame.bodyRect: TRect;
begin
  var pad := px(panePadding);
  var top := headerHeight+pad;
  if fTabs <> nil then top += fTabs.stripHeight;
  result := Rect(pad, top, Max(pad, ClientWidth-pad), Max(top, ClientHeight-pad));
end;

function TPaneFrame.buttonRect(button: TPaneButton): TRect;
begin
  // the shown buttons pack against the right edge: close, then move
  result := Rect(0, 0, 0, 0);
  if ((button = pbClose) and not fClosable) or ((button = pbMove) and not fMovable) then exit;
  var size := px(BUTTON_SIZE);
  var top := (px(HEADER_HEIGHT)-size) div 2;
  var right := ClientWidth-2;
  if (button = pbMove) and fClosable then right -= size+2;
  result := Rect(right-size, top, right, top+size);
end;

function TPaneFrame.buttonAt(x, y: integer): TPaneButton;
begin
  result := pbNone;
  if not paneHeaderShown then exit;
  if buttonRect(pbClose).Contains(Point(x, y)) then exit(pbClose);
  if buttonRect(pbMove).Contains(Point(x, y)) then exit(pbMove);
end;

function TPaneFrame.captions: string;
begin
  result := '';
  for var i := 0 to fForms.Count-1 do result += forms[i].Caption+#1;
end;

procedure TPaneFrame.setHot(value: TPaneButton);
begin
  if value = fHot then exit;
  fHot := value;
  Invalidate;
end;

procedure TPaneFrame.layoutForms;
begin
  var r := bodyRect;
  for var i := 0 to fForms.Count-1 do forms[i].BoundsRect := r;
  if fTabs <> nil then begin
    var h := fTabs.stripHeight;
    fTabs.SetBounds(r.Left, r.Top-h, r.Width, h);
  end;
  if fOverlay <> nil then begin
    fOverlay.BoundsRect := r;
    fOverlay.BringToFront;
  end;
end;

procedure TPaneFrame.applyGeometry;
begin
  layoutForms;
  Invalidate;
end;

procedure TPaneFrame.ensureLayout;
begin
  var r := bodyRect;
  for var i := 0 to fForms.Count-1 do if forms[i].BoundsRect <> r then forms[i].BoundsRect := r;
end;

function TPaneFrame.getIdentify: boolean;
begin
  result := fOverlay <> nil;
end;

procedure TPaneFrame.setIdentify(value: boolean);
begin
  if value = getIdentify then exit;
  if value then begin
    fOverlay := TPaneOverlay.Create(Self);
    fOverlay.text := if fTitle <> '' then fTitle else if fActive <> nil then fActive.Caption else '';
    fOverlay.Parent := Self;
    layoutForms;
  end else FreeAndNil(fOverlay);
end;

procedure TPaneFrame.drawButton(button: TPaneButton);
begin
  var r := buttonRect(button);
  if r.Right <= r.Left then exit;
  if fHot = button then begin
    Canvas.Brush.Color := if fPressed = button then shade(headerColor, -15) else shade(headerColor, if isDark(headerColor) then 14 else -12);
    Canvas.FillRect(r);
  end;
  Canvas.Pen.Color := if fHot = button then ColorToRGB(clBtnText) else dimText;
  Canvas.Pen.Width := 1;
  var cx := (r.Left+r.Right) div 2;
  var cy := (r.Top+r.Bottom) div 2;
  if button = pbClose then begin
    Canvas.Line(cx-4, cy-4, cx+4, cy+4);
    Canvas.Line(cx-4, cy+3, cx+3, cy-4);
  end else begin
    Canvas.Brush.Color := Canvas.Pen.Color;
    // three rows of two dots, centered on the button
    for var row := 0 to 2 do for var col := 0 to 1 do Canvas.FillRect(cx-3+col*4, cy-5+row*4, cx-1+col*4, cy-3+row*4);
  end;
end;

procedure TPaneFrame.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := bodyColor;
  Canvas.FillRect(ClientRect);
  if not paneHeaderShown then exit;
  var h := headerRect;
  Canvas.Brush.Color := headerColor;
  Canvas.FillRect(h);
  Canvas.Font := Font;
  Canvas.Font.Color := clBtnText;
  var textRect := h;
  textRect.Left += 6;
  textRect.Right := buttonRect(pbMove).Left-4;
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.EndEllipsis := true;
  style.Wordbreak := false;
  style.Opaque := false;
  var caption := fTitle;
  if (caption = '') and (fActive <> nil) then caption := fActive.Caption;
  Canvas.TextRect(textRect, textRect.Left, textRect.Top, caption, style);
  drawButton(pbMove);
  drawButton(pbClose);
end;

procedure TPaneFrame.Resize;
begin
  inherited Resize;
  layoutForms;
  Invalidate;
end;

procedure TPaneFrame.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if fDragging then begin
    if Assigned(fOnDrag) then fOnDrag(Self, Mouse.CursorPos);
    exit;
  end;
  setHot(buttonAt(X, Y));
end;

procedure TPaneFrame.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbRight) and fDragging then begin
    fDragging := false;
    fPressed := pbNone;
    if Assigned(fOnCancel) then fOnCancel(Self);
    exit;
  end;
  if Button <> mbLeft then exit;
  fPressed := buttonAt(X, Y);
  Invalidate;
  // the move starts on the press, the drag needs the button held down
  if fPressed = pbMove then begin
    fDragging := true;
    if Assigned(fOnButton) then fOnButton(Self, pbMove);
  end;
end;

procedure TPaneFrame.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var released := fPressed;
  fPressed := pbNone;
  Invalidate;
  if fDragging then begin
    fDragging := false;
    if Assigned(fOnDrop) then fOnDrop(Self, Mouse.CursorPos);
    exit;
  end;
  if (released = pbClose) and (buttonAt(X, Y) = pbClose) and Assigned(fOnButton) then fOnButton(Self, pbClose);
end;

procedure TPaneFrame.MouseLeave;
begin
  inherited MouseLeave;
  setHot(pbNone);
end;

procedure TPaneFrame.attach(aForm: TCustomForm);
begin
  if fForms.IndexOf(aForm) < 0 then begin
    fForms.Add(aForm);
    aForm.DisableAutoSizing;
    try
      clearLayoutProperties(aForm);
      // the frame comes off after the parent change: on a visible toplevel
      // it would map a bare window that the parent change destroys at once,
      // while the compositor may still be taking that window over
      aForm.Parent := Self;
      embedForm(aForm);
      layoutForms;
    finally
      aForm.EnableAutoSizing;
    end;
  end;
  activate(aForm);
end;

procedure TPaneFrame.detach(aForm: TCustomForm);
begin
  var index := fForms.IndexOf(aForm);
  if index < 0 then exit;
  fForms.Delete(index);
  // the frame comes back while the form is still a child, for the same reason
  releaseForm(aForm);
  if aForm.Parent = Self then aForm.Parent := nil;
  if fActive = aForm then begin
    fActive := nil;
    if fForms.Count > 0 then activate(forms[Min(index, fForms.Count-1)]);
  end;
  if fTabs <> nil then fTabs.Invalidate;
  Invalidate;
end;

procedure TPaneFrame.activate(aForm: TCustomForm);
begin
  if fForms.IndexOf(aForm) < 0 then exit;
  var previous := fActive;
  fActive := aForm;
  fSwitching := true;
  try
    if (previous <> nil) and (previous <> aForm) then previous.Visible := false;
    aForm.Visible := true;
    aForm.BringToFront;
  finally
    fSwitching := false;
  end;
  if fTabs <> nil then fTabs.Invalidate;
  Invalidate;
end;

function TPaneFrame.contains(aForm: TCustomForm): boolean;
begin
  result := fForms.IndexOf(aForm) >= 0;
end;

procedure TPaneFrame.moveForm(fromIndex, toIndex: integer);
begin
  if (fromIndex < 0) or (fromIndex >= fForms.Count) or (toIndex < 0) or (toIndex >= fForms.Count) then exit;
  fForms.Move(fromIndex, toIndex);
  if fTabs <> nil then fTabs.Invalidate;
end;

procedure TPaneFrame.syncCaption;
begin
  var current := captions;
  if current = fShownCaption then exit;
  fShownCaption := current;
  if fOverlay <> nil then begin
    fOverlay.text := if fTitle <> '' then fTitle else if fActive <> nil then fActive.Caption else '';
    fOverlay.Invalidate;
  end;
  if fTabs <> nil then fTabs.Invalidate;
  Invalidate;
end;

// -- TPaneOverlay --------------------------------------------------------------

constructor TPaneOverlay.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
end;

procedure TPaneOverlay.Paint;
begin
  var accent := ColorToRGB(clHighlight);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := mix(bodyColor, accent, 30);
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color := accent;
  Canvas.Pen.Width := 2;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(1, 1, ClientWidth-1, ClientHeight-1);
  Canvas.Font := Font;
  Canvas.Font.Size := 14;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clBtnText;
  var style := Canvas.TextStyle;
  style.Alignment := taCenter;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.EndEllipsis := true;
  style.Opaque := false;
  Canvas.TextRect(ClientRect, 0, 0, fText, style);
end;

// -- TPaneSplitter -------------------------------------------------------------

constructor TPaneSplitter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  vertical := true;
end;

procedure TPaneSplitter.setVertical(value: boolean);
begin
  fVertical := value;
  Cursor := if value then crHSplit else crVSplit;
end;

function TPaneSplitter.mousePos: integer;
begin
  var p := Mouse.CursorPos;
  result := if fVertical then p.X else p.Y;
end;

procedure TPaneSplitter.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := faceColor;
  Canvas.FillRect(ClientRect);
end;

procedure TPaneSplitter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  fDragging := true;
  fDragStart := mousePos;
end;

procedure TPaneSplitter.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not fDragging then exit;
  var pos := mousePos;
  var delta := pos-fDragStart;
  if delta = 0 then exit;
  fDragStart := pos;
  if Assigned(fOnDrag) then fOnDrag(Self, delta);
end;

procedure TPaneSplitter.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then fDragging := false;
end;

// -- TPaneSplit ----------------------------------------------------------------

constructor TPaneSplit.Create(AOwner: TComponent; anOrientation: TSplitOrientation);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  fOrientation := anOrientation;
  fItems := TFPList.Create;
  fSplitters := TFPList.Create;
end;

destructor TPaneSplit.Destroy;
begin
  fItems.Free;
  fSplitters.Free;
  inherited Destroy;
end;

function TPaneSplit.getItem(index: integer): TControl;
begin
  result := TControl(fItems[index]);
end;

function TPaneSplit.getItemCount: integer;
begin
  result := fItems.Count;
end;

function TPaneSplit.getWeight(index: integer): double;
begin
  result := fWeights[index];
end;

procedure TPaneSplit.setWeight(index: integer; value: double);
begin
  fWeights[index] := value;
  arrange;
end;

function TPaneSplit.indexOf(control: TControl): integer;
begin
  result := fItems.IndexOf(control);
end;

function TPaneSplit.weightSum: double;
begin
  result := 0;
  for var i := 0 to High(fWeights) do begin
    if fWeights[i] <= 0 then fWeights[i] := 1;
    result += fWeights[i];
  end;
end;

procedure TPaneSplit.insertItem(control: TControl; index: integer; weight: double);
begin
  if (index < 0) or (index > fItems.Count) then index := fItems.Count;
  fItems.Insert(index, control);
  Insert(weight, fWeights, index);
  control.Parent := Self;
  control.Visible := true;
  arrange;
end;

procedure TPaneSplit.removeItem(control: TControl);
begin
  var index := fItems.IndexOf(control);
  if index < 0 then exit;
  fItems.Delete(index);
  Delete(fWeights, index, 1);
  if control.Parent = Self then control.Parent := nil;
  arrange;
end;

procedure TPaneSplit.replaceItem(old, control: TControl);
begin
  var index := fItems.IndexOf(old);
  if index < 0 then exit;
  fItems[index] := control;
  if old.Parent = Self then old.Parent := nil;
  control.Parent := Self;
  control.Visible := true;
  arrange;
end;

// every item gets its share of the length, the last one takes the rounding
procedure TPaneSplit.arrange;
begin
  if fArranging then exit;
  fArranging := true;
  try
    var n := fItems.Count;
    while fSplitters.Count > Max(0, n-1) do begin
      TPaneSplitter(fSplitters.Last).Free;
      fSplitters.Delete(fSplitters.Count-1);
    end;
    while fSplitters.Count < n-1 do begin
      var splitter := TPaneSplitter.Create(Self);
      splitter.vertical := fOrientation = soHorizontal;
      splitter.onDrag := @splitterDrag;
      splitter.Parent := Self;
      fSplitters.Add(splitter);
    end;
    if n = 0 then exit;
    var stacked := fOrientation = soVertical;
    var along := if stacked then ClientHeight else ClientWidth;
    var across := if stacked then ClientWidth else ClientHeight;
    var avail := Max(0, along-(n-1)*splitterSize);
    var sum := weightSum;
    var pos := 0;
    var used := 0;
    for var i := 0 to n-1 do begin
      var len := if i = n-1 then avail-used else Round(avail*fWeights[i]/sum);
      if len < 0 then len := 0;
      if stacked then items[i].SetBounds(0, pos, across, len) else items[i].SetBounds(pos, 0, len, across);
      pos += len;
      used += len;
      if i < n-1 then begin
        var splitter := TPaneSplitter(fSplitters[i]);
        if stacked then splitter.SetBounds(0, pos, across, splitterSize) else splitter.SetBounds(pos, 0, splitterSize, across);
        pos += splitterSize;
      end;
    end;
  finally
    fArranging := false;
  end;
end;

procedure TPaneSplit.splitterDrag(Sender: TObject; delta: integer);
begin
  var index := fSplitters.IndexOf(Sender);
  if (index < 0) or (index+1 >= fItems.Count) then exit;
  var a := items[index];
  var b := items[index+1];
  var lenA := if fOrientation = soVertical then a.Height else a.Width;
  var lenB := if fOrientation = soVertical then b.Height else b.Width;
  var total := lenA+lenB;
  if total < 2*MIN_PANE_SIZE then exit;
  var newA := EnsureRange(lenA+delta, MIN_PANE_SIZE, total-MIN_PANE_SIZE);
  var pair := fWeights[index]+fWeights[index+1];
  fWeights[index] := pair*newA/total;
  fWeights[index+1] := pair-fWeights[index];
  arrange;
end;

procedure TPaneSplit.Resize;
begin
  inherited Resize;
  arrange;
end;

procedure TPaneSplit.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := faceColor;
  Canvas.FillRect(ClientRect);
end;

// -- TPaneCenter ---------------------------------------------------------------

constructor TPaneCenter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
end;

procedure TPaneCenter.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := faceColor;
  Canvas.FillRect(ClientRect);
end;

function TPaneCenter.hostedForm: TCustomForm;
begin
  result := nil;
  for var i := 0 to ControlCount-1 do if Controls[i] is TCustomForm then exit(TCustomForm(Controls[i]));
end;

// -- TPaneHost -----------------------------------------------------------------

constructor TPaneHost.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  fTopEdge := true;
end;

procedure TPaneHost.setRoot(control: TControl);
begin
  if (fRoot <> nil) and (fRoot <> control) and (fRoot.Parent = Self) then fRoot.Parent := nil;
  fRoot := control;
  if control <> nil then begin
    control.Parent := Self;
    control.Visible := true;
  end;
  arrange;
end;

procedure TPaneHost.setCenter(control: TWinControl);
begin
  fCenter := control;
  if control = nil then exit;
  control.Parent := Self;
  if fRoot = nil then setRoot(control);
end;

procedure TPaneHost.ensureCenter;
begin
  if (fCenter = nil) or containsCenter(fRoot) then exit;
  if fRoot = nil then setRoot(fCenter) else insertAtEdge(fCenter, dsRight);
end;

procedure TPaneHost.collectLeaves(control: TControl; list: TFPList);
begin
  if control = nil then exit;
  if control is TPaneSplit then for var i := 0 to TPaneSplit(control).itemCount-1 do collectLeaves(TPaneSplit(control).items[i], list)
  else list.Add(control);
end;

function TPaneHost.leaves: TFPList;
begin
  result := TFPList.Create;
  collectLeaves(fRoot, result);
end;

function TPaneHost.frames: TFPList;
begin
  result := leaves;
  for var i := result.Count-1 downto 0 do if not (TObject(result[i]) is TPaneFrame) then result.Delete(i);
end;

// the name without the number of an extra instance (ComponentList2)
function baseName(const name: string): string;
begin
  result := name;
  while (result <> '') and (result[Length(result)] in ['0'..'9']) do Delete(result, Length(result), 1);
end;

function TPaneHost.holdsCopyOf(frame: TPaneFrame): boolean;
begin
  result := false;
  for var k := 0 to frame.formCount-1 do if holdsCopyOf(frame.forms[k], frame) then exit(true);
end;

function TPaneHost.holdsCopyOf(aForm: TCustomForm; source: TPaneFrame): boolean;
begin
  result := false;
  var list := frames;
  try
    for var i := 0 to list.Count-1 do begin
      var other := TPaneFrame(list[i]);
      if other = source then continue;
      for var j := 0 to other.formCount-1 do
        if SameText(baseName(other.forms[j].Name), baseName(aForm.Name)) then exit(true);
    end;
  finally
    list.Free;
  end;
end;

function TPaneHost.containsCenter(control: TControl): boolean;
begin
  result := false;
  if (control = nil) or (fCenter = nil) then exit;
  if control = fCenter then exit(true);
  if control is TPaneSplit then for var i := 0 to TPaneSplit(control).itemCount-1 do if containsCenter(TPaneSplit(control).items[i]) then exit(true);
end;

procedure TPaneHost.replaceNode(old, control: TControl);
begin
  var split := parentSplit(old);
  if split <> nil then split.replaceItem(old, control) else if old = fRoot then setRoot(control);
end;

procedure TPaneHost.flatten(split: TPaneSplit);
begin
  var grand := parentSplit(split);
  if (grand = nil) or (grand.orientation <> split.orientation) then exit;
  var at := grand.indexOf(split);
  var share := grand.weights[at];
  var sum := split.weightSum;
  var moved := TFPList.Create;
  try
    var shares: array of double := nil;
    for var i := 0 to split.itemCount-1 do begin
      moved.Add(split.items[i]);
      Insert(share*split.weights[i]/sum, shares, Length(shares));
    end;
    for var i := 0 to moved.Count-1 do split.removeItem(TControl(moved[i]));
    grand.removeItem(split);
    for var i := 0 to moved.Count-1 do grand.insertItem(TControl(moved[i]), at+i, shares[i]);
  finally
    moved.Free;
  end;
  split.Free;
end;

procedure TPaneHost.fill(control: TControl);
begin
  if fRoot = nil then setRoot(control) else insertAtEdge(control, dsRight);
end;

procedure TPaneHost.insertAtEdge(control: TControl; side: TDockSide);
begin
  if fRoot = nil then begin
    setRoot(control);
    exit;
  end;
  var before := side in [dsLeft, dsTop];
  if (fRoot is TPaneSplit) and (TPaneSplit(fRoot).orientation = orientationOf(side)) then begin
    var split := TPaneSplit(fRoot);
    split.insertItem(control, if before then 0 else -1, split.weightSum/2);
    exit;
  end;
  splitBeside(fRoot, control, side);
end;

procedure TPaneHost.splitBeside(target, control: TControl; side: TDockSide);
begin
  var o := orientationOf(side);
  var before := side in [dsLeft, dsTop];
  // a split running the same way takes the control at its end
  if (target is TPaneSplit) and (TPaneSplit(target).orientation = o) then begin
    var split := TPaneSplit(target);
    split.insertItem(control, if before then 0 else -1, split.weightSum/2);
    exit;
  end;
  var parent := parentSplit(target);
  if (parent <> nil) and (parent.orientation = o) then begin
    var at := parent.indexOf(target);
    parent.insertItem(control, if before then at else at+1, parent.weights[at]/2);
    exit;
  end;
  var node := TPaneSplit.Create(Self, o);
  replaceNode(target, node);
  node.insertItem(target, -1, 2);
  node.insertItem(control, if before then 0 else -1, 1);
end;

procedure TPaneHost.detach(control: TControl);
begin
  var split := parentSplit(control);
  if split = nil then begin
    if control = fRoot then setRoot(nil) else if control.Parent = Self then control.Parent := nil;
    exit;
  end;
  split.removeItem(control);
  if split.itemCount <> 1 then exit;
  var child := split.items[0];
  split.removeItem(child);
  replaceNode(split, child);
  split.Free;
  if child is TPaneSplit then flatten(TPaneSplit(child));
end;

// bounds of a control of the tree in host client coordinates
function TPaneHost.rectOf(control: TControl): TRect;
begin
  var origin := ScreenToClient(control.Parent.ClientToScreen(control.BoundsRect.TopLeft));
  result := Rect(origin.X, origin.Y, origin.X+control.Width, origin.Y+control.Height);
end;

procedure addZone(var zones: TDropZones; kind: TDropKind; side: TDockSide; target: TControl; const rect, landing: TRect);
begin
  SetLength(zones, Length(zones)+1);
  zones[High(zones)].kind := kind;
  zones[High(zones)].side := side;
  zones[High(zones)].target := target;
  zones[High(zones)].rect := rect;
  zones[High(zones)].landing := landing;
end;

// the strip of the given thickness along a side of r, and the third of r behind it
procedure sideRects(const r: TRect; side: TDockSide; thickness: integer; out strip, landing: TRect);
begin
  match side of
    dsLeft: begin
      strip := Rect(r.Left, r.Top, r.Left+thickness, r.Bottom);
      landing := Rect(r.Left, r.Top, r.Left+r.Width div 3, r.Bottom);
    end;
    dsRight: begin
      strip := Rect(r.Right-thickness, r.Top, r.Right, r.Bottom);
      landing := Rect(r.Right-r.Width div 3, r.Top, r.Right, r.Bottom);
    end;
    dsTop: begin
      strip := Rect(r.Left, r.Top, r.Right, r.Top+thickness);
      landing := Rect(r.Left, r.Top, r.Right, r.Top+r.Height div 3);
    end;
    dsBottom: begin
      strip := Rect(r.Left, r.Bottom-thickness, r.Right, r.Bottom);
      landing := Rect(r.Left, r.Bottom-r.Height div 3, r.Right, r.Bottom);
    end;
  end;
end;

function TPaneHost.outerZones: TDropZones;
begin
  result := nil;
  var r := ClientRect;
  var strip, landing: TRect;
  for var side in [dsLeft, dsRight, dsTop, dsBottom] do begin
    if (side = dsTop) and not fTopEdge then continue;
    sideRects(r, side, px(EDGE_ZONE_SIZE), strip, landing);
    addZone(result, dzEdge, side, nil, strip, if fRoot = nil then r else landing);
  end;
  if fRoot <> nil then exit;
  var half := px(FILL_ZONE_SIZE) div 2;
  var cx := (r.Left+r.Right) div 2;
  var cy := (r.Top+r.Bottom) div 2;
  addZone(result, dzFill, dsLeft, nil, Rect(cx-half, cy-half, cx+half, cy+half), r);
end;

function TPaneHost.zonesOf(leaf, dragged: TControl): TDropZones;
begin
  result := nil;
  if (leaf = nil) or (leaf = dragged) then exit;
  var r := rectOf(leaf);
  var band := EnsureRange(Min(r.Width, r.Height) div 4, px(LEAF_ZONE_MIN), px(LEAF_ZONE_MAX));
  var strip, landing: TRect;
  for var side in [dsLeft, dsRight, dsTop, dsBottom] do begin
    // nothing goes above the center of the main window
    if (side = dsTop) and (leaf = fCenter) and not fTopEdge then continue;
    sideRects(r, side, band, strip, landing);
    addZone(result, dzSplit, side, leaf, strip, landing);
  end;
  if leaf is TPaneFrame then addZone(result, dzTab, dsLeft, leaf, Rect(r.Left+band, r.Top+band, r.Right-band, r.Bottom-band), r);
end;

function TPaneHost.zoneAt(x, y: integer; dragged: TControl; out zone: TDropZone): boolean;

  function hit(const zones: TDropZones): boolean;
  begin
    for var i := 0 to High(zones) do if zones[i].rect.Contains(Point(x, y)) then begin
      zone := zones[i];
      exit(true);
    end;
    result := false;
  end;

begin
  zone := Default(TDropZone);
  if hit(outerZones) then exit(true);
  var list := leaves;
  try
    for var i := 0 to list.Count-1 do if hit(zonesOf(TControl(list[i]), dragged)) then exit(true);
  finally
    list.Free;
  end;
  result := false;
end;

procedure TPaneHost.drop(const zone: TDropZone; control: TControl);
begin
  match zone.kind of
    dzFill: fill(control);
    dzEdge: insertAtEdge(control, zone.side);
    dzSplit: if zone.target <> nil then splitBeside(zone.target, control, zone.side);
    _: ;
  end;
end;

procedure TPaneHost.arrange;
begin
  if fRoot <> nil then fRoot.BoundsRect := ClientRect;
end;

procedure TPaneHost.Resize;
begin
  inherited Resize;
  arrange;
end;

procedure TPaneHost.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := faceColor;
  Canvas.FillRect(ClientRect);
end;

finalization
  FreeAndNil(embedded);
  FreeAndNil(embeddedStyles);
end.
