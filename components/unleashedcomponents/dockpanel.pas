{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit DockPanel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint;

type
  TDockPanel = class;
  TDockZone = (dzCenter, dzLeft, dzRight, dzTop, dzBottom);
  TDockItem = class;
  TDockItemEvent = procedure(Sender: TObject; item: TDockItem) of object;
  // an item is about to close; allow false keeps it
  TDockCloseEvent = procedure(Sender: TObject; item: TDockItem; var allow: boolean) of object;

  { TDockItem }

  // a control docked in a zone, under a tab with a caption
  TDockItem = class(TCollectionItem)
  private
    FControl: TControl;
    FCaption: string;
    FZone: TDockZone;
    FClosable, FVisible: boolean;
    FTag: PtrInt;
    FTab: TRect; // where its tab was painted last
    procedure setControl(value: TControl);
    procedure setCaption(const value: string);
    procedure setZone(value: TDockZone);
    procedure setVisible(value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // brings the item to the front of its zone
    procedure Activate;
  published
    // the control shown under the tab; it becomes a child of the panel
    property Control: TControl read FControl write setControl;
    property Caption: string read FCaption write setCaption;
    property Zone: TDockZone read FZone write setZone default dzCenter;
    // a cross on the tab
    property Closable: boolean read FClosable write FClosable default true;
    // a hidden item keeps its place but shows no tab
    property Visible: boolean read FVisible write setVisible default true;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TDockItems }

  TDockItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TDockItem;
    procedure setItem(index: integer; value: TDockItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TDockItem;
    property Items[index: integer]: TDockItem read getItem write setItem; default;
  end;

  { TDockPanel }

  // five zones around a center, each a stack of tabbed panels: a tab
  // brings its panel up, a drag of a tab moves it to another zone, the
  // splitters between the zones resize them, a cross closes. The layout
  // saves to a string and loads back, so it survives a restart
  TDockPanel = class(TCustomControl)
  private
    FItems: TDockItems;
    FActive: array[TDockZone] of TDockItem;
    FSizes: array[TDockZone] of integer; // the width or height of the side zones
    FLaying: boolean;
    FTabHeight, FSplitterWidth, FMinZoneSize, FCornerRadius, FPadding: integer;
    FShowSingleTab, FAllowDrag, FAllowClose, FAllowResize: boolean;
    FTabColor, FActiveTabColor, FTabTextColor, FBorderColor, FSplitterColor, FBackColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FHotItem, FHotClose, FDragItem: TDockItem;
    FDragging: boolean;
    FDragStart, FMouse: TPoint;
    FDropZone: TDockZone;
    FDropValid: boolean;
    FResizeZone: TDockZone;
    FResizing: boolean;
    FResizeStart, FResizeSize: integer;
    FOnActivate, FOnDocked, FOnClosed: TDockItemEvent;
    FOnClose: TDockCloseEvent;
    FOnLayoutChange: TNotifyEvent;
    procedure setItems(value: TDockItems);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function getZoneSize(zone: TDockZone): integer;
    procedure setZoneSize(zone: TDockZone; value: integer);
    function zoneRect(zone: TDockZone): TRect;
    function splitterRect(zone: TDockZone): TRect;
    function tabBarRect(zone: TDockZone): TRect;
    function contentRect(zone: TDockZone): TRect;
    function zoneCount(zone: TDockZone): integer;
    function activeOf(zone: TDockZone): TDockItem;
    function zoneAt(x, y: integer): TDockZone;
    function itemAt(x, y: integer; out closeHit: boolean): TDockItem;
    function splitterAt(x, y: integer): TDockZone;
    function tabsShown(zone: TDockZone): boolean;
    procedure layout;
    procedure layoutChanged;
    procedure paintTabs(sp: TSmoothPaint; zone: TDockZone);
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Loaded; override;
    procedure Resize; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // docks a control: it becomes a child and shows under a tab in the zone
    function DockControl(control: TControl; const caption: string; zone: TDockZone = dzCenter): TDockItem;
    // the item of a control, nil when it is not docked
    function ItemOf(control: TControl): TDockItem;
    procedure Activate(item: TDockItem);
    // closes an item the way its cross does, with the events
    function Close(item: TDockItem): boolean;
    procedure MoveTo(item: TDockItem; zone: TDockZone; index: integer = -1);
    // the layout as text: zone, order and sizes, by the names of the controls
    function SaveLayout: string;
    procedure LoadLayout(const layout: string);
    property ActiveItem[zone: TDockZone]: TDockItem read activeOf;
    property ZoneSize[zone: TDockZone]: integer read getZoneSize write setZoneSize;
  published
    property Items: TDockItems read FItems write setItems;
    property LeftWidth: integer index 0 read getMetric write setMetric default 200;
    property RightWidth: integer index 1 read getMetric write setMetric default 200;
    property TopHeight: integer index 2 read getMetric write setMetric default 120;
    property BottomHeight: integer index 3 read getMetric write setMetric default 160;
    // 0 takes it from the font
    property TabHeight: integer index 4 read getMetric write setMetric default 0;
    property SplitterWidth: integer index 5 read getMetric write setMetric default 5;
    property MinZoneSize: integer index 6 read getMetric write setMetric default 60;
    property CornerRadius: integer index 7 read getMetric write setMetric default 4;
    property Padding: integer index 8 read getMetric write setMetric default 4;
    // a tab bar even when a zone holds one item
    property ShowSingleTab: boolean index 0 read getFlag write setFlag default true;
    property AllowDrag: boolean index 1 read getFlag write setFlag default true;
    property AllowClose: boolean index 2 read getFlag write setFlag default true;
    property AllowResize: boolean index 3 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property TabColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ActiveTabColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TabTextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property SplitterColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnActivate: TDockItemEvent read FOnActivate write FOnActivate;
    // an item landed in a zone, by a drag or by MoveTo
    property OnDocked: TDockItemEvent read FOnDocked write FOnDocked;
    property OnClose: TDockCloseEvent read FOnClose write FOnClose;
    property OnClosed: TDockItemEvent read FOnClosed write FOnClosed;
    // a zone was resized or an item moved
    property OnLayoutChange: TNotifyEvent read FOnLayoutChange write FOnLayoutChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property ClientHeight;
    property ClientWidth;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
  end;

implementation

uses
  Math;

{ TDockItem }

constructor TDockItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FClosable := true;
  FVisible := true;
end;

procedure TDockItem.Assign(Source: TPersistent);
begin
  if Source is TDockItem then begin
    var s := TDockItem(Source);
    FControl := s.FControl;
    FCaption := s.FCaption;
    FZone := s.FZone;
    FClosable := s.FClosable;
    FVisible := s.FVisible;
    FTag := s.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TDockItem.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TDockItem.Activate;
begin
  if Collection.Owner is TDockPanel then TDockPanel(Collection.Owner).Activate(self);
end;

procedure TDockItem.setControl(value: TControl);
begin
  if FControl = value then exit;
  var panel := Collection.Owner as TDockPanel;
  if FControl <> nil then FControl.RemoveFreeNotification(panel);
  FControl := value;
  if FControl <> nil then begin
    FControl.FreeNotification(panel);
    if not (csLoading in panel.ComponentState) then FControl.Parent := panel;
    if FCaption = '' then FCaption := FControl.Name;
  end;
  Changed(false);
end;

procedure TDockItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TDockItem.setZone(value: TDockZone);
begin
  if FZone = value then exit;
  FZone := value;
  Changed(false);
end;

procedure TDockItem.setVisible(value: boolean);
begin
  if FVisible = value then exit;
  FVisible := value;
  Changed(false);
end;

{ TDockItems }

function TDockItems.getItem(index: integer): TDockItem;
begin
  result := TDockItem(inherited Items[index]);
end;

procedure TDockItems.setItem(index: integer; value: TDockItem);
begin
  inherited Items[index] := value;
end;

function TDockItems.Add: TDockItem;
begin
  result := TDockItem(inherited Add);
end;

procedure TDockItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TDockPanel then TDockPanel(Owner).layoutChanged;
end;

{ TDockPanel }

constructor TDockPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csNoFocus]-[csSetCaption];
  FItems := TDockItems.Create(self, TDockItem);
  FSizes[dzLeft] := 200;
  FSizes[dzRight] := 200;
  FSizes[dzTop] := 120;
  FSizes[dzBottom] := 160;
  FSplitterWidth := 5;
  FMinZoneSize := 60;
  FCornerRadius := 4;
  FPadding := 4;
  FShowSingleTab := true;
  FAllowDrag := true;
  FAllowClose := true;
  FAllowResize := true;
  FTabColor := clDefault;
  FActiveTabColor := clDefault;
  FTabTextColor := clDefault;
  FBorderColor := clDefault;
  FSplitterColor := clDefault;
  FBackColor := clDefault;
  FAntialiasing := asTheme;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TDockPanel.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

class function TDockPanel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 480;
  result.cy := 320;
end;

procedure TDockPanel.Loaded;
begin
  inherited Loaded;
  for var i := 0 to FItems.Count-1 do if (FItems[i].Control <> nil) and (FItems[i].Control.Parent <> self) then FItems[i].Control.Parent := self;
  layoutChanged;
end;

procedure TDockPanel.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  for var i := FItems.Count-1 downto 0 do if FItems[i].FControl = AComponent then begin
    FItems[i].FControl := nil;
    FItems[i].Free;
  end;
  for var z := low(TDockZone) to high(TDockZone) do if (FActive[z] <> nil) and (FActive[z].Collection = nil) then FActive[z] := nil;
  if FHotItem <> nil then FHotItem := nil;
  if FDragItem <> nil then FDragItem := nil;
end;

// -- items ----------------------

function TDockPanel.DockControl(control: TControl; const caption: string; zone: TDockZone): TDockItem;
begin
  result := ItemOf(control);
  if result = nil then begin
    result := FItems.Add;
    result.FZone := zone;
    result.Control := control;
  end else result.FZone := zone;
  if caption <> '' then result.FCaption := caption;
  FActive[zone] := result;
  layoutChanged;
  if Assigned(FOnDocked) then FOnDocked(self, result);
end;

function TDockPanel.ItemOf(control: TControl): TDockItem;
begin
  for var i := 0 to FItems.Count-1 do if FItems[i].Control = control then exit(FItems[i]);
  result := nil;
end;

function TDockPanel.zoneCount(zone: TDockZone): integer;
begin
  result := 0;
  for var i := 0 to FItems.Count-1 do if (FItems[i].Zone = zone) and FItems[i].Visible then inc(result);
end;

function TDockPanel.activeOf(zone: TDockZone): TDockItem;
begin
  result := FActive[zone];
  if (result <> nil) and ((result.Zone <> zone) or not result.Visible) then result := nil;
  if result = nil then
    for var i := 0 to FItems.Count-1 do if (FItems[i].Zone = zone) and FItems[i].Visible then begin
      result := FItems[i];
      break;
    end;
  FActive[zone] := result;
end;

procedure TDockPanel.Activate(item: TDockItem);
begin
  if (item = nil) or not item.Visible then exit;
  if FActive[item.Zone] = item then exit;
  FActive[item.Zone] := item;
  layoutChanged;
  if Assigned(FOnActivate) then FOnActivate(self, item);
end;

function TDockPanel.Close(item: TDockItem): boolean;
begin
  result := false;
  if item = nil then exit;
  var allow := true;
  if Assigned(FOnClose) then FOnClose(self, item, allow);
  if not allow then exit;
  var control := item.Control;
  if FHotItem = item then FHotItem := nil;
  if FHotClose = item then FHotClose := nil;
  if FActive[item.Zone] = item then FActive[item.Zone] := nil;
  if control <> nil then begin
    control.RemoveFreeNotification(self);
    control.Visible := false;
  end;
  if Assigned(FOnClosed) then FOnClosed(self, item);
  item.FControl := nil;
  item.Free;
  layoutChanged;
  result := true;
end;

procedure TDockPanel.MoveTo(item: TDockItem; zone: TDockZone; index: integer);
begin
  if item = nil then exit;
  item.FZone := zone;
  if index >= 0 then begin
    // the index counts the items of the zone; find the collection place
    var k := 0;
    var at := FItems.Count-1;
    for var i := 0 to FItems.Count-1 do begin
      if (FItems[i] = item) or (FItems[i].Zone <> zone) then continue;
      if k = index then begin at := i; break; end;
      inc(k);
    end;
    item.Index := at;
  end;
  FActive[zone] := item;
  layoutChanged;
  if Assigned(FOnDocked) then FOnDocked(self, item);
  if Assigned(FOnLayoutChange) then FOnLayoutChange(self);
end;

function TDockPanel.SaveLayout: string;
begin
  result := Format('sizes=%d,%d,%d,%d', [FSizes[dzLeft], FSizes[dzRight], FSizes[dzTop], FSizes[dzBottom]]);
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    var name := if item.Control <> nil then item.Control.Name else item.Caption;
    result += Format(';%s=%d,%d,%d', [name, ord(item.Zone), ord(item.Visible), ord(activeOf(item.Zone) = item)]);
  end;
end;

procedure TDockPanel.LoadLayout(const layout: string);
begin
  var parts := layout.Split([';']);
  var order := 0;
  for var part in parts do begin
    var eq := Pos('=', part);
    if eq = 0 then continue;
    var name := Copy(part, 1, eq-1);
    var values := Copy(part, eq+1, MaxInt).Split([',']);
    if name = 'sizes' then begin
      if length(values) >= 4 then begin
        FSizes[dzLeft] := StrToIntDef(values[0], FSizes[dzLeft]);
        FSizes[dzRight] := StrToIntDef(values[1], FSizes[dzRight]);
        FSizes[dzTop] := StrToIntDef(values[2], FSizes[dzTop]);
        FSizes[dzBottom] := StrToIntDef(values[3], FSizes[dzBottom]);
      end;
      continue;
    end;
    for var i := 0 to FItems.Count-1 do begin
      var item := FItems[i];
      var itemName := if item.Control <> nil then item.Control.Name else item.Caption;
      if itemName <> name then continue;
      if length(values) >= 1 then item.FZone := TDockZone(EnsureRange(StrToIntDef(values[0], 0), 0, ord(high(TDockZone))));
      if length(values) >= 2 then item.FVisible := values[1] = '1';
      if (length(values) >= 3) and (values[2] = '1') then FActive[item.Zone] := item;
      item.Index := Min(order, FItems.Count-1);
      inc(order);
      break;
    end;
  end;
  layoutChanged;
end;

// -- geometry ----------------------

function TDockPanel.getZoneSize(zone: TDockZone): integer;
begin
  result := FSizes[zone];
end;

procedure TDockPanel.setZoneSize(zone: TDockZone; value: integer);
begin
  if zone = dzCenter then exit;
  value := Max(value, FMinZoneSize);
  if FSizes[zone] = value then exit;
  FSizes[zone] := value;
  layoutChanged;
end;

function TDockPanel.tabsShown(zone: TDockZone): boolean;
begin
  var n := zoneCount(zone);
  result := (n > 1) or ((n = 1) and FShowSingleTab);
end;

// the zones: the sides take their size when they hold something, the
// center the rest; top and bottom run the full width
function TDockPanel.zoneRect(zone: TDockZone): TRect;
begin
  var gap := scaled(self, FSplitterWidth);
  var leftW := if zoneCount(dzLeft) > 0 then scaled(self, FSizes[dzLeft]) else 0;
  var rightW := if zoneCount(dzRight) > 0 then scaled(self, FSizes[dzRight]) else 0;
  var topH := if zoneCount(dzTop) > 0 then scaled(self, FSizes[dzTop]) else 0;
  var bottomH := if zoneCount(dzBottom) > 0 then scaled(self, FSizes[dzBottom]) else 0;
  var midTop := if topH > 0 then topH+gap else 0;
  var midBottom := if bottomH > 0 then ClientHeight-bottomH-gap else ClientHeight;
  result := match zone of
    dzTop: Rect(0, 0, ClientWidth, topH);
    dzBottom: Rect(0, ClientHeight-bottomH, ClientWidth, ClientHeight);
    dzLeft: Rect(0, midTop, leftW, midBottom);
    dzRight: Rect(ClientWidth-rightW, midTop, ClientWidth, midBottom);
  else
    Rect((if leftW > 0 then leftW+gap else 0), midTop, (if rightW > 0 then ClientWidth-rightW-gap else ClientWidth), midBottom)
  end;
end;

function TDockPanel.splitterRect(zone: TDockZone): TRect;
begin
  var gap := scaled(self, FSplitterWidth);
  var r := zoneRect(zone);
  if zoneCount(zone) = 0 then exit(Rect(0, 0, 0, 0));
  result := match zone of
    dzLeft: Rect(r.Right, r.Top, r.Right+gap, r.Bottom);
    dzRight: Rect(r.Left-gap, r.Top, r.Left, r.Bottom);
    dzTop: Rect(r.Left, r.Bottom, r.Right, r.Bottom+gap);
    dzBottom: Rect(r.Left, r.Top-gap, r.Right, r.Top);
  else
    Rect(0, 0, 0, 0)
  end;
end;

function TDockPanel.tabBarRect(zone: TDockZone): TRect;
begin
  var r := zoneRect(zone);
  if not tabsShown(zone) then exit(Rect(r.Left, r.Top, r.Right, r.Top));
  var th := if FTabHeight > 0 then scaled(self, FTabHeight) else lineHeightOf(Font)+scaled(self, 10);
  result := Rect(r.Left, r.Top, r.Right, r.Top+th);
end;

function TDockPanel.contentRect(zone: TDockZone): TRect;
begin
  var r := zoneRect(zone);
  var tabs := tabBarRect(zone);
  var pad := scaled(self, FPadding);
  result := Rect(r.Left+pad, tabs.Bottom+pad, r.Right-pad, r.Bottom-pad);
  if result.Right < result.Left then result.Right := result.Left;
  if result.Bottom < result.Top then result.Bottom := result.Top;
end;

function TDockPanel.zoneAt(x, y: integer): TDockZone;
begin
  // the sides by position; an empty side zone still takes a strip at the edge
  var p := Point(x, y);
  var edge := scaled(self, 40);
  for var z in [dzLeft, dzRight, dzTop, dzBottom] do if (zoneCount(z) > 0) and PtInRect(zoneRect(z), p) then exit(z);
  if x < edge then exit(dzLeft);
  if x > ClientWidth-edge then exit(dzRight);
  if y < edge then exit(dzTop);
  if y > ClientHeight-edge then exit(dzBottom);
  result := dzCenter;
end;

function TDockPanel.itemAt(x, y: integer; out closeHit: boolean): TDockItem;
begin
  closeHit := false;
  var p := Point(x, y);
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if item.FTab.IsEmpty or not PtInRect(item.FTab, p) then continue;
    var size := scaled(self, 14);
    closeHit := item.Closable and FAllowClose and (x >= item.FTab.Right-size-scaled(self, 4));
    exit(item);
  end;
  result := nil;
end;

function TDockPanel.splitterAt(x, y: integer): TDockZone;
begin
  for var z in [dzLeft, dzRight, dzTop, dzBottom] do if PtInRect(splitterRect(z), Point(x, y)) then exit(z);
  result := dzCenter;
end;

// -- layout ----------------------

procedure TDockPanel.layoutChanged;
begin
  if csLoading in ComponentState then exit;
  layout;
  Invalidate;
end;

procedure TDockPanel.AlignControls(AControl: TControl; var ARect: TRect);
begin
  layout;
end;

procedure TDockPanel.layout;
begin
  if FLaying or (csDestroying in ComponentState) or (csLoading in ComponentState) then exit;
  FLaying := true;
  try
    for var z := low(TDockZone) to high(TDockZone) do begin
      var active := activeOf(z);
      var content := contentRect(z);
      for var i := 0 to FItems.Count-1 do begin
        var item := FItems[i];
        if (item.Zone <> z) or (item.Control = nil) then continue;
        var c := item.Control;
        if c.Parent <> self then c.Parent := self;
        var show := (item = active) and item.Visible;
        // a placement only goes through when it changes something, since even
        // an unchanged one asks for another pass
        if show and (c.BoundsRect <> content) then c.BoundsRect := content;
        if c.Visible <> show then c.Visible := show;
      end;
    end;
  finally
    FLaying := false;
  end;
end;

procedure TDockPanel.Resize;
begin
  inherited Resize;
  layout;
  Invalidate;
end;

// -- painting ----------------------

procedure TDockPanel.paintTabs(sp: TSmoothPaint; zone: TDockZone);
begin
  var bar := tabBarRect(zone);
  if bar.Height = 0 then exit;
  var back := pick(FBackColor, clBtnFace);
  var tab := pick(FTabColor, blend(back, clBtnShadow, 25));
  var activeTab := pick(FActiveTabColor, clWindow);
  var border := pick(FBorderColor, blend(back, clBtnText, 20));
  var radius := scaled(self, FCornerRadius);
  var pad := scaled(self, 10);
  var closeW := scaled(self, 14);
  var x := bar.Left+scaled(self, 2);
  var active := activeOf(zone);
  sp.FillRect(Rect(bar.Left, bar.Bottom-1, bar.Right, bar.Bottom), border);
  sp.SetClip(Rect(bar.Left, bar.Top, bar.Right, bar.Bottom));
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if item.Zone <> zone then continue;
    if not item.Visible then begin item.FTab := Rect(0, 0, 0, 0); continue; end;
    var w := textWidthOf(Font, item.Caption)+2*pad;
    if item.Closable and FAllowClose then w += closeW;
    if x+w > bar.Right then w := Max(bar.Right-x, scaled(self, 20));
    var r := Rect(x, bar.Top+scaled(self, 3), x+w, bar.Bottom);
    item.FTab := r;
    var fill := if item = active then activeTab else if (item = FHotItem) and hoverEnabled then hoverColor(tab) else tab;
    if item = FDragItem then fill := blend(fill, clHighlight, 20);
    // a tab is a rounded shape whose bottom runs under the bar line; the
    // active one carries the outline and opens into the content below
    sp.FillRoundRect(r.Left, r.Top, r.Right, r.Bottom+radius+2, radius, fill);
    if item = active then begin
      sp.FrameRoundRect(r.Left, r.Top, r.Right, r.Bottom+radius+2, radius, 1, border);
      sp.FillRect(Rect(r.Left+1, r.Bottom-1, r.Right-1, r.Bottom+1), fill);
    end;

    if item.Closable and FAllowClose then begin
      var c := Rect(r.Right-closeW-scaled(self, 4), r.Top+(r.Height-closeW) div 2, r.Right-scaled(self, 4), r.Top+(r.Height+closeW) div 2);
      if item = FHotClose then paintRoundRect(sp, c, scaled(self, 3), hoverColor(fill), clNone);
      paintCross(sp, c, scaled(self, 7), blend(pick(FTabTextColor, clBtnText), fill, (if item = FHotClose then 0 else 35)), 1);
    end;
    x += w+scaled(self, 2);
  end;
  sp.ResetClip;
end;

procedure TDockPanel.Paint;
begin
  var back := pick(FBackColor, clBtnFace);
  var border := pick(FBorderColor, blend(back, clBtnText, 20));
  var splitter := pick(FSplitterColor, blend(back, clBtnShadow, 30));
  var activeTab := pick(FActiveTabColor, clWindow);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  for var z := low(TDockZone) to high(TDockZone) do begin
    if zoneCount(z) = 0 then begin
      for var i := 0 to FItems.Count-1 do if FItems[i].Zone = z then FItems[i].FTab := Rect(0, 0, 0, 0);
      continue;
    end;
    var r := zoneRect(z);
    var tabs := tabBarRect(z);
    // the content area under the tabs; the control inside brings its own edge
    sp.FillRect(Rect(r.Left, tabs.Bottom, r.Right, r.Bottom), activeTab);
    paintTabs(sp, z);
    var s := splitterRect(z);
    if not s.IsEmpty then begin
      var hot := FResizing and (FResizeZone = z);
      sp.FillRect(s, (if hot then blend(splitter, clHighlight, 40) else back));
      // a grip in the middle
      if z in [dzLeft, dzRight] then sp.FillRoundRect((s.Left+s.Right)/2-1, (s.Top+s.Bottom)/2-scaled(self, 12), (s.Left+s.Right)/2+1, (s.Top+s.Bottom)/2+scaled(self, 12), 1, splitter)
      else sp.FillRoundRect((s.Left+s.Right)/2-scaled(self, 12), (s.Top+s.Bottom)/2-1, (s.Left+s.Right)/2+scaled(self, 12), (s.Top+s.Bottom)/2+1, 1, splitter);
    end;
  end;
  // the drop target while a tab is dragged
  if FDragging and FDropValid then begin
    var r := zoneRect(FDropZone);
    if zoneCount(FDropZone) = 0 then begin
      var edge := scaled(self, 40);
      r := match FDropZone of
        dzLeft: Rect(0, 0, edge, ClientHeight);
        dzRight: Rect(ClientWidth-edge, 0, ClientWidth, ClientHeight);
        dzTop: Rect(0, 0, ClientWidth, edge);
        dzBottom: Rect(0, ClientHeight-edge, ClientWidth, ClientHeight);
      else
        ClientRect
      end;
    end;
    sp.DashRoundRect(r.Left+1, r.Top+1, r.Right-1, r.Bottom-1, scaled(self, FCornerRadius), 2, 6, 4, ColorToRGB(clHighlight));
    sp.FillRect(r, TSmoothPaint.PackColor(clHighlight) and $00FFFFFF or ($30 shl 24));
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var text := pick(FTabTextColor, clBtnText);
  for var z := low(TDockZone) to high(TDockZone) do begin
    var active := activeOf(z);
    for var i := 0 to FItems.Count-1 do begin
      var item := FItems[i];
      if (item.Zone <> z) or item.FTab.IsEmpty then continue;
      Canvas.Font.Style := if item = active then Font.Style+[fsBold] else Font.Style;
      Canvas.Font.Color := if item = active then text else blend(text, back, 25);
      var r := item.FTab;
      r.Left += scaled(self, 10);
      r.Right -= scaled(self, 4)+(if item.Closable and FAllowClose then scaled(self, 14) else 0);
      if r.Right <= r.Left then continue;
      Canvas.ClipRect := r;
      Canvas.Clipping := true;
      Canvas.TextOut(r.Left, r.Top+(r.Height-Canvas.TextHeight('Hg')) div 2, item.Caption);
      Canvas.Clipping := false;
    end;
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TDockPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var z := splitterAt(X, Y);
  if (z <> dzCenter) and FAllowResize then begin
    FResizing := true;
    FResizeZone := z;
    FResizeStart := if z in [dzLeft, dzRight] then X else Y;
    FResizeSize := FSizes[z];
    Invalidate;
    exit;
  end;
  var closeHit: boolean;
  var item := itemAt(X, Y, closeHit);
  if item = nil then exit;
  if closeHit then begin
    Close(item);
    exit;
  end;
  Activate(item);
  if FAllowDrag then begin
    FDragItem := item;
    FDragStart := Point(X, Y);
    FDragging := false;
  end;
end;

procedure TDockPanel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  FMouse := Point(X, Y);
  if FResizing then begin
    var delta := (if FResizeZone in [dzLeft, dzRight] then X else Y)-FResizeStart;
    if FResizeZone in [dzRight, dzBottom] then delta := -delta;
    var size := Max(FResizeSize+Round(delta*100/Max(scaled(self, 100), 1)), FMinZoneSize);
    if size <> FSizes[FResizeZone] then begin
      FSizes[FResizeZone] := size;
      // the children move in one pass, the panel repaints before the next move
      DisableAutoSizing;
      try
        layout;
      finally
        EnableAutoSizing;
      end;
      Invalidate;
      paintNow(self);
    end;
    exit;
  end;
  if (FDragItem <> nil) and (ssLeft in Shift) then begin
    if not FDragging and ((Abs(X-FDragStart.X) > 5) or (Abs(Y-FDragStart.Y) > 5)) then FDragging := true;
    if FDragging then begin
      FDropZone := zoneAt(X, Y);
      FDropValid := (FDropZone <> FDragItem.Zone) or (zoneCount(FDragItem.Zone) > 1);
      Invalidate;
    end;
    exit;
  end;
  Cursor := match splitterAt(X, Y) of
    dzLeft, dzRight: crHSplit;
    dzTop, dzBottom: crVSplit;
  else
    crDefault
  end;
  var closeHit: boolean;
  var hot := itemAt(X, Y, closeHit);
  var hotClose := if closeHit then hot else nil;
  if (hot = FHotItem) and (hotClose = FHotClose) then exit;
  FHotItem := hot;
  FHotClose := hotClose;
  Invalidate;
end;

procedure TDockPanel.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FResizing then begin
    FResizing := false;
    Invalidate;
    if Assigned(FOnLayoutChange) then FOnLayoutChange(self);
    exit;
  end;
  if FDragItem = nil then exit;
  var item := FDragItem;
  var dragging := FDragging;
  FDragItem := nil;
  FDragging := false;
  if dragging then begin
    var zone := zoneAt(X, Y);
    if zone <> item.Zone then MoveTo(item, zone)
    else begin
      // a drop on another tab of the same zone reorders
      var closeHit: boolean;
      var over := itemAt(X, Y, closeHit);
      if (over <> nil) and (over <> item) and (over.Zone = zone) then begin
        item.Index := over.Index;
        layoutChanged;
        if Assigned(FOnLayoutChange) then FOnLayoutChange(self);
      end;
    end;
  end;
  Invalidate;
end;

procedure TDockPanel.MouseLeave;
begin
  inherited MouseLeave;
  if (FHotItem = nil) and (FHotClose = nil) then exit;
  FHotItem := nil;
  FHotClose := nil;
  Invalidate;
end;

// -- properties ----------------------

procedure TDockPanel.setItems(value: TDockItems);
begin
  FItems.Assign(value);
  layoutChanged;
end;

function TDockPanel.getMetric(index: integer): integer;
begin
  result := match index of
    0: FSizes[dzLeft];
    1: FSizes[dzRight];
    2: FSizes[dzTop];
    3: FSizes[dzBottom];
    4: FTabHeight;
    5: FSplitterWidth;
    6: FMinZoneSize;
    7: FCornerRadius;
  else
    FPadding
  end;
end;

procedure TDockPanel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index in [0..3] then value := Max(value, 20);
  if getMetric(index) = value then exit;
  match index of
    0: FSizes[dzLeft] := value;
    1: FSizes[dzRight] := value;
    2: FSizes[dzTop] := value;
    3: FSizes[dzBottom] := value;
    4: FTabHeight := value;
    5: FSplitterWidth := value;
    6: FMinZoneSize := value;
    7: FCornerRadius := value;
  else
    FPadding := value;
  end;
  layoutChanged;
end;

function TDockPanel.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowSingleTab;
    1: FAllowDrag;
    2: FAllowClose;
  else
    FAllowResize
  end;
end;

procedure TDockPanel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowSingleTab := value;
    1: FAllowDrag := value;
    2: FAllowClose := value;
  else
    FAllowResize := value;
  end;
  layoutChanged;
end;

function TDockPanel.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FTabColor;
    1: FActiveTabColor;
    2: FTabTextColor;
    3: FBorderColor;
    4: FSplitterColor;
  else
    FBackColor
  end;
end;

procedure TDockPanel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FTabColor := value;
    1: FActiveTabColor := value;
    2: FTabTextColor := value;
    3: FBorderColor := value;
    4: FSplitterColor := value;
  else
    FBackColor := value;
  end;
  Invalidate;
end;

procedure TDockPanel.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
