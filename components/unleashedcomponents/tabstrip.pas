{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit TabStrip;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ImgList, LCLType, ControlPaint;

type
  TTabStrip = class;
  // the look of the tabs: an underline under the active one, pills, boxes
  // open at the bottom, framed cards, buttons, a frame around the active one
  TTabStripStyle = (tssUnderline, tssPills, tssBoxes, tssCards, tssButtons, tssOutline);
  TTabCloseButtons = (tcbNone, tcbActive, tcbHover, tcbAll);
  TTabCloseEvent = procedure(Sender: TObject; index: integer; var canClose: boolean) of object;
  TTabMovedEvent = procedure(Sender: TObject; fromIndex, toIndex: integer) of object;

  { TTabStripItem }

  TTabStripItem = class(TCollectionItem)
  private
    FCaption, FHint: string;
    FImageIndex: TImageIndex;
    FClosable, FModified, FEnabled: boolean;
    FTag: PtrInt;
    procedure setCaption(const value: string);
    procedure setImageIndex(value: TImageIndex);
    procedure setFlag(index: integer; value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Caption: string read FCaption write setCaption;
    property Hint: string read FHint write FHint;
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    // the tab shows a close button, after CloseButtons
    property Closable: boolean index 0 read FClosable write setFlag default true;
    // a dot in place of the close button until the mouse comes
    property Modified: boolean index 1 read FModified write setFlag default false;
    property Enabled: boolean index 2 read FEnabled write setFlag default true;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TTabStripItems }

  TTabStripItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TTabStripItem;
    procedure setItem(index: integer; value: TTabStripItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TTabStripItem;
    function AddTab(const caption: string; imageIndex: TImageIndex = -1): TTabStripItem;
    property Items[index: integer]: TTabStripItem read getItem write setItem; default;
  end;

  { TTabStrip }

  // a row of tabs without pages, for documents or views: one is active, a
  // tab can close, a drag moves it, the wheel or the arrows scroll the row
  // when it does not fit, and a plus button asks for a new one
  TTabStrip = class(TCustomControl)
  private
    FTabs: TTabStripItems;
    FTabIndex, FHot, FHotClose, FPressedClose, FScroll: integer;
    FStyle: TTabStripStyle;
    FCloseButtons: TTabCloseButtons;
    FShowAddButton, FAllowReorder, FHotAdd, FHotLeft, FHotRight: boolean;
    FMinTabWidth, FMaxTabWidth, FTabPadding, FSpacing, FCornerRadius: integer;
    FAccentColor, FTabColor, FActiveTabColor, FTextColor: TColor;
    FImages: TCustomImageList;
    FImagesWidth: integer;
    FDragIndex, FDragStartX: integer;
    FDragging: boolean;
    FAntialiasing: TAntialiasSetting;
    FOnDrawTab: TCustomDrawEvent;
    FOnChange, FOnAddClick: TNotifyEvent;
    FOnChanging: TTabCloseEvent;
    FOnTabClose: TTabCloseEvent;
    FOnTabMoved: TTabMovedEvent;
    procedure setTabs(value: TTabStripItems);
    procedure setTabIndex(value: integer);
    procedure setStyle(value: TTabStripStyle);
    procedure setCloseButtons(value: TTabCloseButtons);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setImages(value: TCustomImageList);
    procedure setAntialiasing(value: TAntialiasSetting);
    function tabWidth(index: integer): integer;
    function arrowsShown: boolean;
    function tabsArea: TRect;
    function tabRect(index: integer): TRect;
    function closeRect(index: integer): TRect;
    function addRect: TRect;
    function leftArrowRect: TRect;
    function rightArrowRect: TRect;
    function contentWidth: integer;
    function tabAt(X, Y: integer): integer;
    function closeShown(index: integer): boolean;
    procedure clampScroll;
    procedure scrollTo(index: integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoOnShowHint(HintInfo: PHintInfo); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoOnResize; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure tabsChanged;
    // closes a tab the way its close button does, OnTabClose included
    function CloseTab(index: integer): boolean;
    procedure MoveTab(fromIndex, toIndex: integer);
    // the active tab item, nil without one
    function ActiveTab: TTabStripItem;
  published
    property Tabs: TTabStripItems read FTabs write setTabs;
    property TabIndex: integer read FTabIndex write setTabIndex default -1;
    property Style: TTabStripStyle read FStyle write setStyle default tssUnderline;
    property CloseButtons: TTabCloseButtons read FCloseButtons write setCloseButtons default tcbHover;
    // a plus after the tabs; OnAddClick does the rest
    property ShowAddButton: boolean index 0 read getFlag write setFlag default false;
    // a drag moves a tab
    property AllowReorder: boolean index 1 read getFlag write setFlag default true;
    property MinTabWidth: integer index 0 read getMetric write setMetric default 60;
    // 0 lets a tab grow with its caption
    property MaxTabWidth: integer index 1 read getMetric write setMetric default 200;
    property TabPadding: integer index 2 read getMetric write setMetric default 12;
    property Spacing: integer index 3 read getMetric write setMetric default 2;
    property CornerRadius: integer index 4 read getMetric write setMetric default 6;
    property ImagesWidth: integer index 5 read getMetric write setMetric default 0;
    property Images: TCustomImageList read FImages write setImages;
    // clDefault takes the colors of the theme
    property AccentColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TabColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property ActiveTabColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over the stock tab shape: dsSelected for the active tab, dsHover
    // under the mouse; `handled` true leaves the caption and the icon out
    property OnDrawTab: TCustomDrawEvent read FOnDrawTab write FOnDrawTab;
    // after TabIndex changed
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // before a tab gets active; canClose false keeps the old one
    property OnChanging: TTabCloseEvent read FOnChanging write FOnChanging;
    // before a tab goes; canClose false keeps it
    property OnTabClose: TTabCloseEvent read FOnTabClose write FOnTabClose;
    property OnTabMoved: TTabMovedEvent read FOnTabMoved write FOnTabMoved;
    property OnAddClick: TNotifyEvent read FOnAddClick write FOnAddClick;
    property Align;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default true;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
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

{ TTabStripItem }

constructor TTabStripItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FImageIndex := -1;
  FClosable := true;
  FEnabled := true;
end;

procedure TTabStripItem.Assign(Source: TPersistent);
begin
  if Source is TTabStripItem then begin
    var s := TTabStripItem(Source);
    FCaption := s.FCaption;
    FHint := s.FHint;
    FImageIndex := s.FImageIndex;
    FClosable := s.FClosable;
    FModified := s.FModified;
    FEnabled := s.FEnabled;
    FTag := s.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TTabStripItem.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TTabStripItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TTabStripItem.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Changed(false);
end;

procedure TTabStripItem.setFlag(index: integer; value: boolean);
begin
  match index of
    0: FClosable := value;
    1: FModified := value;
  else
    FEnabled := value;
  end;
  Changed(false);
end;

{ TTabStripItems }

function TTabStripItems.getItem(index: integer): TTabStripItem;
begin
  result := TTabStripItem(inherited Items[index]);
end;

procedure TTabStripItems.setItem(index: integer; value: TTabStripItem);
begin
  inherited Items[index] := value;
end;

procedure TTabStripItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TTabStrip then TTabStrip(Owner).tabsChanged;
end;

function TTabStripItems.Add: TTabStripItem;
begin
  result := TTabStripItem(inherited Add);
end;

function TTabStripItems.AddTab(const caption: string; imageIndex: TImageIndex): TTabStripItem;
begin
  result := Add;
  result.FCaption := caption;
  result.FImageIndex := imageIndex;
  result.Changed(false);
end;

{ TTabStrip }

constructor TTabStrip.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FTabs := TTabStripItems.Create(self, TTabStripItem);
  FTabIndex := -1;
  FHot := -1;
  FHotClose := -1;
  FPressedClose := -1;
  FDragIndex := -1;
  FCloseButtons := tcbHover;
  FAllowReorder := true;
  FMinTabWidth := 60;
  FMaxTabWidth := 200;
  FTabPadding := 12;
  FSpacing := 2;
  FCornerRadius := 6;
  FAccentColor := clDefault;
  FTabColor := clDefault;
  FActiveTabColor := clDefault;
  FTextColor := clDefault;
  TabStop := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TTabStrip.Destroy;
begin
  FreeAndNil(FTabs);
  inherited Destroy;
end;

class function TTabStrip.GetControlClassDefaultSize: TSize;
begin
  result.cx := 400;
  result.cy := 34;
end;

procedure TTabStrip.tabsChanged;
begin
  if (FTabs = nil) or (csDestroying in ComponentState) then exit;
  if FTabIndex >= FTabs.Count then FTabIndex := FTabs.Count-1;
  clampScroll;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TTabStrip.ActiveTab: TTabStripItem;
begin
  result := if (FTabIndex >= 0) and (FTabIndex < FTabs.Count) then FTabs[FTabIndex] else nil;
end;

// -- geometry ----------------------

function TTabStrip.tabWidth(index: integer): integer;
begin
  Canvas.Font := Font;
  var t := FTabs[index];
  var w := Canvas.TextWidth(t.FCaption)+2*scaled(self, FTabPadding);
  if (FImages <> nil) and (t.FImageIndex >= 0) then w += FImages.ResolutionForControl[FImagesWidth, self].Width+scaled(self, 6);
  if t.FClosable and (FCloseButtons <> tcbNone) or t.FModified then w += scaled(self, 20);
  w := Max(w, scaled(self, FMinTabWidth));
  if FMaxTabWidth > 0 then w := Min(w, scaled(self, FMaxTabWidth));
  result := w;
end;

function TTabStrip.contentWidth: integer;
begin
  result := 0;
  for var i := 0 to FTabs.Count-1 do result += tabWidth(i)+scaled(self, FSpacing);
end;

function TTabStrip.arrowsShown: boolean;
begin
  var room := ClientWidth-(if FShowAddButton then ClientHeight else 0);
  result := contentWidth > room;
end;

// the part the tabs scroll in: the arrows and the plus stay at the right
function TTabStrip.tabsArea: TRect;
begin
  var right := ClientWidth;
  if arrowsShown then right -= 2*scaled(self, 22);
  if FShowAddButton then right -= ClientHeight;
  result := Rect(0, 0, Max(right, 0), ClientHeight);
end;

function TTabStrip.tabRect(index: integer): TRect;
begin
  var x := -FScroll;
  for var i := 0 to index-1 do x += tabWidth(i)+scaled(self, FSpacing);
  var inset := if FStyle = tssPills then scaled(self, 4) else 0;
  result := Rect(x, inset, x+tabWidth(index), ClientHeight-inset);
end;

function TTabStrip.closeRect(index: integer): TRect;
begin
  var r := tabRect(index);
  var size := scaled(self, 16);
  var right := r.Right-scaled(self, 6);
  result := Rect(right-size, (r.Top+r.Bottom-size) div 2, right, (r.Top+r.Bottom-size) div 2+size);
end;

function TTabStrip.addRect: TRect;
begin
  if not FShowAddButton then exit(Rect(0, 0, 0, 0));
  // the plus follows the last tab while they fit, then keeps to the right
  var area := tabsArea;
  var x := if arrowsShown then ClientWidth-ClientHeight else Min(contentWidth-FScroll, area.Right);
  result := Rect(x, 0, x+ClientHeight, ClientHeight);
end;

function TTabStrip.leftArrowRect: TRect;
begin
  if not arrowsShown then exit(Rect(0, 0, 0, 0));
  var w := scaled(self, 22);
  var right := ClientWidth-(if FShowAddButton then ClientHeight else 0);
  result := Rect(right-2*w, 0, right-w, ClientHeight);
end;

function TTabStrip.rightArrowRect: TRect;
begin
  if not arrowsShown then exit(Rect(0, 0, 0, 0));
  var w := scaled(self, 22);
  var right := ClientWidth-(if FShowAddButton then ClientHeight else 0);
  result := Rect(right-w, 0, right, ClientHeight);
end;

function TTabStrip.tabAt(X, Y: integer): integer;
begin
  result := -1;
  if not tabsArea.Contains(Point(X, Y)) then exit;
  for var i := 0 to FTabs.Count-1 do
    if tabRect(i).Contains(Point(X, Y)) then exit(i);
end;

function TTabStrip.closeShown(index: integer): boolean;
begin
  var t := FTabs[index];
  if not t.FClosable or not t.FEnabled then exit(false);
  result := match FCloseButtons of
    tcbAll: true;
    tcbActive: index = FTabIndex;
    tcbHover: (index = FTabIndex) or (index = FHot);
  else
    false
  end;
end;

procedure TTabStrip.clampScroll;
begin
  if not HandleAllocated then exit;
  FScroll := EnsureRange(FScroll, 0, Max(contentWidth-tabsArea.Width, 0));
end;

procedure TTabStrip.scrollTo(index: integer);
begin
  if not HandleAllocated or (index < 0) or (index >= FTabs.Count) then exit;
  var r := tabRect(index);
  var area := tabsArea;
  if r.Left < 0 then FScroll += r.Left
  else if r.Right > area.Right then FScroll += r.Right-area.Right;
  clampScroll;
  Invalidate;
end;

procedure TTabStrip.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  Canvas.Font := Font;
  PreferredWidth := contentWidth+(if FShowAddButton then Canvas.TextHeight('Hg')+scaled(self, 16) else 0);
  PreferredHeight := Canvas.TextHeight('Hg')+scaled(self, 16);
end;

// -- painting ----------------------

procedure TTabStrip.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var accent := pick(FAccentColor, clHighlight);
  var tabColor := pick(FTabColor, blend(back, clWindowText, 6));
  var activeColor := pick(FActiveTabColor, match FStyle of
    tssUnderline, tssOutline: back;
    tssButtons: accent;
  else
    blend(back, clWindowText, 14)
  end);
  var outline := blend(back, clWindowText, 22);
  var text := pick(FTextColor, clWindowText);
  var dim := blend(back, text, 60);
  var radius := scaled(self, FCornerRadius);
  var area := tabsArea;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  if FStyle = tssUnderline then paintLine(sp, 0, ClientHeight-1, ClientWidth, ClientHeight-1, blend(back, clWindowText, 14), 1);
  for var i := 0 to FTabs.Count-1 do begin
    var r := tabRect(i);
    if (r.Right <= 0) or (r.Left >= area.Right) then continue;
    var active := i = FTabIndex;
    var hot := (i = FHot) and hoverEnabled and FTabs[i].FEnabled;
    match FStyle of
      tssPills: if active then paintRoundRect(sp, r, radius, activeColor, clNone)
        else if hot then paintRoundRect(sp, r, radius, hoverColor(back), clNone);
      tssBoxes: begin
        // the tab is open at the bottom and joins the line under the row
        var fill := if active then activeColor else if hot then hoverColor(tabColor) else tabColor;
        paintRoundRect(sp, Rect(r.Left, r.Top+scaled(self, 3), r.Right, r.Bottom+radius), radius, fill, clNone);
      end;
      // framed cards, the active one taller and joined to the content
      tssCards: begin
        var fill := if active then activeColor else if hot then hoverColor(tabColor) else tabColor;
        var top := if active then r.Top else r.Top+scaled(self, 3);
        paintRoundRect(sp, Rect(r.Left, top, r.Right, r.Bottom+radius), radius, fill, outline);
        if active then paintRoundRect(sp, Rect(r.Left+1, r.Bottom-1, r.Right-1, r.Bottom+radius+1), 0, fill, clNone);
      end;
      // every tab a button, the active one in the accent
      tssButtons: begin
        var box := r;
        box.Inflate(-scaled(self, 2), -scaled(self, 3));
        var fill := if active then activeColor else if hot then hoverColor(tabColor) else tabColor;
        paintRoundRect(sp, box, radius, fill, clNone);
      end;
      // the active tab framed in the accent, the others bare
      tssOutline: begin
        var box := r;
        box.Inflate(-scaled(self, 2), -scaled(self, 3));
        if active then paintRoundRect(sp, box, radius, activeColor, accent, Max(scaled(self, 1), 1))
        else if hot then paintRoundRect(sp, box, radius, hoverColor(back), clNone);
      end;
    else
      begin
        if hot and not active then paintRoundRect(sp, Rect(r.Left, r.Top+scaled(self, 3), r.Right, r.Bottom-scaled(self, 3)), radius, hoverColor(back), clNone);
        // the focused tab runs its underline the whole width
        if active then paintRoundRect(sp, Rect(r.Left+(if Focused and ringEnabled then 0 else scaled(self, 4)), r.Bottom-scaled(self, 3), r.Right-(if Focused and ringEnabled then 0 else scaled(self, 4)), r.Bottom), scaled(self, 2), accent, clNone);
      end;
    end;
    var c := closeRect(i);
    if closeShown(i) or (FTabs[i].FModified and (i <> FHotClose)) then begin
      if FTabs[i].FModified and (i <> FHot) and (i <> FHotClose) then
        paintCircle(sp, (c.Left+c.Right) div 2, (c.Top+c.Bottom) div 2, Max(scaled(self, 4), 2), dim, clNone)
      else begin
        if i = FHotClose then paintRoundRect(sp, c, scaled(self, 3), hoverColor(if active then activeColor else back), clNone);
        paintCross(sp, c, scaled(self, 8), (if i = FHotClose then text else dim), Max(scaled(self, 1), 1)+(if i = FHotClose then 1 else 0));
      end;
    end;
  end;
  // the arrows and the plus sit on the background, over the tabs scrolled
  // under them
  if arrowsShown or FShowAddButton then paintRoundRect(sp, Rect(area.Right, 0, ClientWidth, ClientHeight-(if FStyle = tssUnderline then 1 else 0)), 0, back, clNone);
  if arrowsShown then begin
    var l := leftArrowRect;
    var rr := rightArrowRect;
    if FHotLeft and hoverEnabled then paintRoundRect(sp, l, scaled(self, 4), hoverColor(back), clNone);
    if FHotRight and hoverEnabled then paintRoundRect(sp, rr, scaled(self, 4), hoverColor(back), clNone);
    paintChevron(sp, l, cdLeft, scaled(self, 8), (if FScroll > 0 then text else dim));
    paintChevron(sp, rr, cdRight, scaled(self, 8), (if FScroll < contentWidth-area.Width then text else dim));
  end;
  if FShowAddButton then begin
    var a := addRect;
    var inner := a;
    inner.Inflate(-scaled(self, 6), -scaled(self, 6));
    if FHotAdd and hoverEnabled then paintRoundRect(sp, inner, scaled(self, 4), hoverColor(back), clNone);
    var cx := (a.Left+a.Right) div 2;
    var cy := (a.Top+a.Bottom) div 2;
    var arm := scaled(self, 5);
    paintLine(sp, cx-arm, cy, cx+arm, cy, text, Max(scaled(self, 2), 1));
    paintLine(sp, cx, cy-arm, cx, cy+arm, text, Max(scaled(self, 2), 1));
  end;
  sp.Flush;

  // the application paints over the stock shapes; a handled tab keeps its
  // caption and icon away
  var custom: array of boolean := [];
  SetLength(custom, FTabs.Count);
  if Assigned(FOnDrawTab) then
    for var i := 0 to FTabs.Count-1 do begin
      var r := tabRect(i);
      if (r.Right <= 0) or (r.Left >= area.Right) then continue;
      var state: TDrawState := if i = FTabIndex then [dsSelected] else [];
      if (i = FHot) and hoverEnabled then state += [dsHover];
      if not (FTabs[i].FEnabled and Enabled) then state += [dsDisabled];
      if Focused and (i = FTabIndex) then state += [dsFocused];
      FOnDrawTab(self, Canvas, r, i, state, custom[i]);
    end;

  // the captions and icons, clipped to the room of each tab
  applyTextQuality(Canvas);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  Canvas.Brush.Style := bsClear;
  for var i := 0 to FTabs.Count-1 do begin
    var r := tabRect(i);
    if (r.Right <= 0) or (r.Left >= area.Right) or custom[i] then continue;
    var t := FTabs[i];
    var x := r.Left+scaled(self, FTabPadding);
    if (FImages <> nil) and (t.FImageIndex >= 0) and (t.FImageIndex < FImages.Count) then begin
      var res := FImages.ResolutionForControl[FImagesWidth, self];
      if x+res.Width <= area.Right then res.Draw(Canvas, x, (r.Top+r.Bottom-res.Height) div 2, t.FImageIndex, t.FEnabled and Enabled);
      x += res.Width+scaled(self, 6);
    end;
    var right := r.Right-scaled(self, FTabPadding);
    if t.FClosable and (FCloseButtons <> tcbNone) or t.FModified then right := closeRect(i).Left-scaled(self, 4);
    var box := Rect(x, r.Top, Min(right, area.Right), r.Bottom);
    Canvas.Font := Font;
    if i = FTabIndex then Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.Font.Color := if not (t.FEnabled and Enabled) then ColorToRGB(clGrayText) else if (i = FTabIndex) and (FStyle = tssButtons) then contrastText(activeColor) else if i = FTabIndex then text else dim;
    // the bold active caption keeps the width of the regular one
    if box.Right > box.Left then Canvas.TextRect(box, box.Left, box.Top, t.FCaption, style);
  end;
  Canvas.Font := Font;
  Canvas.Brush.Style := bsSolid;
end;

// -- actions ----------------------

procedure TTabStrip.setTabIndex(value: integer);
begin
  if csLoading in ComponentState then begin
    FTabIndex := value;
    exit;
  end;
  value := EnsureRange(value, -1, FTabs.Count-1);
  if value = FTabIndex then exit;
  if (value >= 0) and not FTabs[value].FEnabled then exit;
  var allow := true;
  if Assigned(FOnChanging) then FOnChanging(self, value, allow);
  if not allow then exit;
  FTabIndex := value;
  scrollTo(value);
  Invalidate;
  if Assigned(FOnChange) then FOnChange(self);
end;

function TTabStrip.CloseTab(index: integer): boolean;
begin
  result := false;
  if (index < 0) or (index >= FTabs.Count) then exit;
  var allow := true;
  if Assigned(FOnTabClose) then FOnTabClose(self, index, allow);
  if not allow then exit;
  var wasActive := index = FTabIndex;
  FHot := -1;
  FHotClose := -1;
  FTabs.Delete(index);
  // the next tab takes the place of a closed active one, else the one before
  if wasActive then begin
    FTabIndex := -1;
    if FTabs.Count > 0 then setTabIndex(Min(index, FTabs.Count-1))
    else if Assigned(FOnChange) then FOnChange(self);
  end else if index < FTabIndex then dec(FTabIndex);
  tabsChanged;
  result := true;
end;

procedure TTabStrip.MoveTab(fromIndex, toIndex: integer);
begin
  if (fromIndex < 0) or (fromIndex >= FTabs.Count) or (toIndex < 0) or (toIndex >= FTabs.Count) or (fromIndex = toIndex) then exit;
  var active := ActiveTab;
  FTabs[fromIndex].Index := toIndex;
  if active <> nil then FTabIndex := active.Index;
  tabsChanged;
  if Assigned(FOnTabMoved) then FOnTabMoved(self, fromIndex, toIndex);
end;

// -- input ----------------------

procedure TTabStrip.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if not Enabled or (csDesigning in ComponentState) then exit;
  if TabStop and CanSetFocus and not Focused then SetFocus;
  var p := Point(X, Y);
  if Button = mbLeft then begin
    if leftArrowRect.Contains(p) then begin
      FScroll -= tabsArea.Width div 2;
      clampScroll;
      Invalidate;
      exit;
    end;
    if rightArrowRect.Contains(p) then begin
      FScroll += tabsArea.Width div 2;
      clampScroll;
      Invalidate;
      exit;
    end;
    if FShowAddButton and addRect.Contains(p) then begin
      if Assigned(FOnAddClick) then FOnAddClick(self);
      exit;
    end;
  end;
  var i := tabAt(X, Y);
  if i < 0 then exit;
  // a middle click closes
  if (Button = mbMiddle) and FTabs[i].FClosable then begin
    CloseTab(i);
    exit;
  end;
  if Button <> mbLeft then exit;
  if closeShown(i) and closeRect(i).Contains(p) then begin
    FPressedClose := i;
    exit;
  end;
  setTabIndex(i);
  if FAllowReorder and (FTabIndex = i) then begin
    FDragIndex := i;
    FDragStartX := X;
  end;
end;

procedure TTabStrip.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var p := Point(X, Y);
  if FDragIndex >= 0 then begin
    if not FDragging and (Abs(X-FDragStartX) > scaled(self, 6)) then FDragging := true;
    if FDragging then begin
      // the tab moves once the mouse passes the middle of a neighbour
      var target := tabAt(EnsureRange(X, 0, tabsArea.Right-1), ClientHeight div 2);
      if (target >= 0) and (target <> FDragIndex) then begin
        var r := tabRect(target);
        var middle := (r.Left+r.Right) div 2;
        if ((target > FDragIndex) and (X > middle)) or ((target < FDragIndex) and (X < middle)) then begin
          MoveTab(FDragIndex, target);
          FDragIndex := target;
        end;
      end;
      exit;
    end;
  end;
  var hot := tabAt(X, Y);
  var hotClose := if (hot >= 0) and closeShown(hot) and closeRect(hot).Contains(p) then hot else -1;
  // the close button shows on hover, so the hot tab decides it as well
  if (hot >= 0) and (hotClose < 0) and FTabs[hot].FClosable and (FCloseButtons = tcbHover) and closeRect(hot).Contains(p) then hotClose := hot;
  var hotAdd := FShowAddButton and addRect.Contains(p);
  var hotLeft := leftArrowRect.Contains(p);
  var hotRight := rightArrowRect.Contains(p);
  if (hot <> FHot) or (hotClose <> FHotClose) or (hotAdd <> FHotAdd) or (hotLeft <> FHotLeft) or (hotRight <> FHotRight) then begin
    FHot := hot;
    FHotClose := hotClose;
    FHotAdd := hotAdd;
    FHotLeft := hotLeft;
    FHotRight := hotRight;
    Invalidate;
  end;
end;

procedure TTabStrip.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragIndex := -1;
  FDragging := false;
  if FPressedClose >= 0 then begin
    var i := FPressedClose;
    FPressedClose := -1;
    if (i < FTabs.Count) and closeRect(i).Contains(Point(X, Y)) then CloseTab(i);
  end;
end;

procedure TTabStrip.MouseLeave;
begin
  inherited MouseLeave;
  if (FHot >= 0) or (FHotClose >= 0) or FHotAdd or FHotLeft or FHotRight then begin
    FHot := -1;
    FHotClose := -1;
    FHotAdd := false;
    FHotLeft := false;
    FHotRight := false;
    Invalidate;
  end;
end;

function TTabStrip.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or not arrowsShown then exit;
  FScroll -= Sign(WheelDelta)*scaled(self, 40);
  clampScroll;
  Invalidate;
  result := true;
end;

procedure TTabStrip.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FTabs.Count = 0 then exit;
  // the arrows skip the disabled tabs
  var step := procedure(delta: integer)
  begin
    var i := FTabIndex;
    for var n := 1 to FTabs.Count do begin
      i := (i+delta+FTabs.Count) mod FTabs.Count;
      if FTabs[i].FEnabled then begin
        setTabIndex(i);
        break;
      end;
    end;
  end;
  match Key of
    VK_LEFT: step(-1);
    VK_RIGHT: step(1);
    VK_HOME: setTabIndex(0);
    VK_END: setTabIndex(FTabs.Count-1);
    VK_DELETE: if FTabIndex >= 0 then CloseTab(FTabIndex) else exit;
  else
    exit;
  end;
  Key := 0;
end;

// a tab with a hint of its own shows it; the hint goes again when the
// mouse leaves the tab
procedure TTabStrip.DoOnShowHint(HintInfo: PHintInfo);
begin
  var i := tabAt(HintInfo^.CursorPos.X, HintInfo^.CursorPos.Y);
  if (i >= 0) and (FTabs[i].FHint <> '') then begin
    HintInfo^.HintStr := FTabs[i].FHint;
    HintInfo^.CursorRect := tabRect(i);
  end;
  inherited DoOnShowHint(HintInfo);
end;

procedure TTabStrip.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TTabStrip.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TTabStrip.DoOnResize;
begin
  inherited DoOnResize;
  clampScroll;
  Invalidate;
end;

procedure TTabStrip.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  tabsChanged;
end;

procedure TTabStrip.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then begin
    FImages := nil;
    tabsChanged;
  end;
end;

// -- properties ----------------------

procedure TTabStrip.setTabs(value: TTabStripItems);
begin
  FTabs.Assign(value);
end;

procedure TTabStrip.setStyle(value: TTabStripStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TTabStrip.setCloseButtons(value: TTabCloseButtons);
begin
  if FCloseButtons = value then exit;
  FCloseButtons := value;
  tabsChanged;
end;

function TTabStrip.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FShowAddButton else FAllowReorder;
end;

procedure TTabStrip.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FShowAddButton := value else FAllowReorder := value;
  tabsChanged;
end;

function TTabStrip.getMetric(index: integer): integer;
begin
  result := match index of
    0: FMinTabWidth;
    1: FMaxTabWidth;
    2: FTabPadding;
    3: FSpacing;
    4: FCornerRadius;
  else
    FImagesWidth
  end;
end;

procedure TTabStrip.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FMinTabWidth := value;
    1: FMaxTabWidth := value;
    2: FTabPadding := value;
    3: FSpacing := value;
    4: FCornerRadius := value;
  else
    FImagesWidth := value;
  end;
  tabsChanged;
end;

function TTabStrip.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FAccentColor;
    1: FTabColor;
    2: FActiveTabColor;
  else
    FTextColor
  end;
end;

procedure TTabStrip.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FAccentColor := value;
    1: FTabColor := value;
    2: FActiveTabColor := value;
  else
    FTextColor := value;
  end;
  Invalidate;
end;

procedure TTabStrip.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  tabsChanged;
end;

procedure TTabStrip.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
