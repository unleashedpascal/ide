{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SideNav;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ImgList, LCLType, ControlPaint;

type
  TSideNav = class;

  { TSideNavItem }

  TSideNavItem = class(TCollectionItem)
  private
    FCaption, FHint: string;
    FImageIndex: TImageIndex;
    FTag: PtrInt;
    FEnabled, FVisible, FSeparator: boolean;
    FBadge: string;
    procedure setCaption(const value: string);
    procedure setImageIndex(value: TImageIndex);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setBadge(const value: string);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Caption: string read FCaption write setCaption;
    property Hint: string read FHint write FHint;
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    property Tag: PtrInt read FTag write FTag default 0;
    property Enabled: boolean index 0 read getFlag write setFlag default true;
    property Visible: boolean index 1 read getFlag write setFlag default true;
    // a gap with a line instead of an entry
    property Separator: boolean index 2 read getFlag write setFlag default false;
    // a short mark at the right end, a count for example
    property Badge: string read FBadge write setBadge;
  end;

  { TSideNavItems }

  TSideNavItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TSideNavItem;
    procedure setItem(index: integer; value: TSideNavItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TSideNavItem;
    function AddItem(const caption: string; imageIndex: TImageIndex = -1): TSideNavItem;
    function AddSeparator: TSideNavItem;
    property Items[index: integer]: TSideNavItem read getItem write setItem; default;
  end;

  // how the chosen entry shows: a tinted row with a bar at its left, a filled
  // pill, the full row filled, a bar under the caption, a frame
  TSideNavSelection = (nsBar, nsPill, nsFill, nsUnderline, nsOutline);
  TSideNavItemEvent = procedure(Sender: TObject; item: TSideNavItem) of object;

  { TSideNav }

  // a column of entries for the sections of a window, with an icon and a
  // caption each. Collapsed, it narrows to the icons; the toggle at the top
  // switches between the two widths
  TSideNav = class(TCustomControl)
  private
    FItems: TSideNavItems;
    FImages: TCustomImageList;
    FItemIndex, FHot: integer;
    FCollapsed, FShowToggle, FAnimated: boolean;
    FItemHeight, FCollapsedWidth, FExpandedWidth, FPadding, FCornerRadius, FHeaderHeight, FAnimationTime: integer;
    FSelection: TSideNavSelection;
    FBackColor, FTextColor, FSelectedColor, FSelectedTextColor, FBadgeColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnDrawItem: TCustomDrawEvent;
    FTimer: TTimer;
    FFrom, FTo: integer;
    FStarted: QWord;
    FOnChange: TNotifyEvent;
    FOnItemClick: TSideNavItemEvent;
    FOnToggle: TNotifyEvent;
    procedure setItems(value: TSideNavItems);
    procedure setImages(value: TCustomImageList);
    procedure setItemIndex(value: integer);
    procedure setCollapsed(value: boolean);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setSelection(value: TSideNavSelection);
    procedure setAntialiasing(value: TAntialiasSetting);
    function itemRect(index: integer): TRect;
    function itemAt(x, y: integer): integer;
    function toggleRect: TRect;
    function headerPx: integer;
    function iconPx: integer;
    procedure setHot(value: integer);
    procedure settle(animate: boolean);
    procedure tick(Sender: TObject);
    procedure itemsChanged;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Toggle;
    function SelectedItem: TSideNavItem;
  published
    property Items: TSideNavItems read FItems write setItems;
    property Images: TCustomImageList read FImages write setImages;
    property ItemIndex: integer read FItemIndex write setItemIndex default -1;
    // the icons alone, at CollapsedWidth
    property Collapsed: boolean index 0 read getFlag write setFlag default false;
    // the button at the top that folds the column
    property ShowToggle: boolean index 1 read getFlag write setFlag default true;
    property Animated: boolean index 2 read getFlag write setFlag default true;
    property ItemHeight: integer index 0 read getMetric write setMetric default 40;
    property CollapsedWidth: integer index 1 read getMetric write setMetric default 48;
    property ExpandedWidth: integer index 2 read getMetric write setMetric default 200;
    property Padding: integer index 3 read getMetric write setMetric default 6;
    property CornerRadius: integer index 4 read getMetric write setMetric default 6;
    // the room above the entries; 0 shows only the toggle
    property HeaderHeight: integer index 5 read getMetric write setMetric default 0;
    property AnimationTime: integer index 6 read getMetric write setMetric default 150;
    // nsBar: a strip of the accent beside the selected entry; nsPill: a filled pill
    property Selection: TSideNavSelection read FSelection write setSelection default nsBar;
    // clDefault takes the colors of the theme
    property BackColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property SelectedColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property SelectedTextColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property BadgeColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over the stock entry: dsSelected for the chosen one, dsHover
    // under the mouse; `handled` true leaves the icon, the caption and the
    // badge out
    property OnDrawItem: TCustomDrawEvent read FOnDrawItem write FOnDrawItem;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnItemClick: TSideNavItemEvent read FOnItemClick write FOnItemClick;
    property OnToggle: TNotifyEvent read FOnToggle write FOnToggle;
    property Align;
    property Anchors;
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

const
  HOT_NONE = -1;
  HOT_TOGGLE = -2;

{ TSideNavItem }

constructor TSideNavItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FImageIndex := -1;
  FEnabled := true;
  FVisible := true;
end;

procedure TSideNavItem.Assign(Source: TPersistent);
begin
  if Source is TSideNavItem then begin
    var other := TSideNavItem(Source);
    FCaption := other.FCaption;
    FHint := other.FHint;
    FImageIndex := other.FImageIndex;
    FTag := other.FTag;
    FEnabled := other.FEnabled;
    FVisible := other.FVisible;
    FSeparator := other.FSeparator;
    FBadge := other.FBadge;
    Changed(false);
  end else inherited Assign(Source);
end;

function TSideNavItem.GetDisplayName: string;
begin
  result := if FSeparator then '-' else if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TSideNavItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TSideNavItem.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Changed(false);
end;

function TSideNavItem.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FEnabled;
    1: FVisible;
  else
    FSeparator
  end;
end;

procedure TSideNavItem.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FEnabled := value;
    1: FVisible := value;
  else
    FSeparator := value;
  end;
  Changed(false);
end;

procedure TSideNavItem.setBadge(const value: string);
begin
  if FBadge = value then exit;
  FBadge := value;
  Changed(false);
end;

{ TSideNavItems }

function TSideNavItems.getItem(index: integer): TSideNavItem;
begin
  result := TSideNavItem(inherited Items[index]);
end;

procedure TSideNavItems.setItem(index: integer; value: TSideNavItem);
begin
  inherited Items[index] := value;
end;

procedure TSideNavItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TSideNav then TSideNav(Owner).itemsChanged;
end;

function TSideNavItems.Add: TSideNavItem;
begin
  result := TSideNavItem(inherited Add);
end;

function TSideNavItems.AddItem(const caption: string; imageIndex: TImageIndex): TSideNavItem;
begin
  result := Add;
  result.FCaption := caption;
  result.FImageIndex := imageIndex;
  result.Changed(false);
end;

function TSideNavItems.AddSeparator: TSideNavItem;
begin
  result := Add;
  result.FSeparator := true;
  result.Changed(false);
end;

{ TSideNav }

constructor TSideNav.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  TabStop := true;
  FItems := TSideNavItems.Create(self, TSideNavItem);
  FItemIndex := -1;
  FHot := HOT_NONE;
  FShowToggle := true;
  FAnimated := true;
  FItemHeight := 40;
  FCollapsedWidth := 48;
  FExpandedWidth := 200;
  FPadding := 6;
  FCornerRadius := 6;
  FAnimationTime := 150;
  FBackColor := clDefault;
  FTextColor := clDefault;
  FSelectedColor := clDefault;
  FSelectedTextColor := clDefault;
  FBadgeColor := clDefault;
  FAntialiasing := asTheme;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 16;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TSideNav.Destroy;
begin
  FTimer.Enabled := false;
  FItems.Free;
  inherited Destroy;
end;

class function TSideNav.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 320;
end;

// -- geometry ----------------------

function TSideNav.headerPx: integer;
begin
  result := scaled(self, FHeaderHeight);
  if FShowToggle then result := Max(result, scaled(self, FItemHeight));
end;

function TSideNav.iconPx: integer;
begin
  result := if FImages <> nil then FImages.WidthForPPI[0, Font.PixelsPerInch] else scaled(self, 20);
end;

function TSideNav.toggleRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FShowToggle then exit;
  var pad := scaled(self, FPadding);
  var h := scaled(self, FItemHeight);
  var w := scaled(self, FCollapsedWidth)-pad*2;
  result := Rect(pad, pad, pad+w, pad+h-pad);
end;

function TSideNav.itemRect(index: integer): TRect;
begin
  var pad := scaled(self, FPadding);
  var y := headerPx+pad;
  var h := scaled(self, FItemHeight);
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if not item.Visible then continue;
    var rowH := if item.Separator then pad*2+1 else h;
    if i = index then exit(Rect(pad, y, ClientWidth-pad, y+rowH));
    y += rowH;
  end;
  result := Rect(0, 0, 0, 0);
end;

function TSideNav.itemAt(x, y: integer): integer;
begin
  if FShowToggle and toggleRect.Contains(Point(x, y)) then exit(HOT_TOGGLE);
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if not item.Visible or item.Separator then continue;
    if itemRect(i).Contains(Point(x, y)) then exit(i);
  end;
  result := HOT_NONE;
end;

// -- folding ----------------------

procedure TSideNav.Toggle;
begin
  Collapsed := not FCollapsed;
end;

procedure TSideNav.setCollapsed(value: boolean);
begin
  if FCollapsed = value then exit;
  FCollapsed := value;
  settle(FAnimated and not (csDesigning in ComponentState) and not (csLoading in ComponentState));
  if not (csLoading in ComponentState) and Assigned(FOnToggle) then FOnToggle(self);
end;

procedure TSideNav.settle(animate: boolean);
begin
  var target := scaled(self, if FCollapsed then FCollapsedWidth else FExpandedWidth);
  FTimer.Enabled := false;
  if animate and HandleAllocated and (FAnimationTime > 0) then begin
    FFrom := Width;
    FTo := target;
    FStarted := GetTickCount64;
    FTimer.Enabled := true;
  end else Width := target;
  Invalidate;
end;

procedure TSideNav.tick(Sender: TObject);
begin
  var elapsed := GetTickCount64-FStarted;
  if elapsed >= QWord(FAnimationTime) then begin
    FTimer.Enabled := false;
    Width := FTo;
    exit;
  end;
  var t := elapsed/FAnimationTime;
  t := 1-(1-t)*(1-t);
  Width := FFrom+Round((FTo-FFrom)*t);
end;

procedure TSideNav.Loaded;
begin
  inherited Loaded;
  settle(false);
end;

// -- painting ----------------------

procedure TSideNav.Paint;
begin
  var back := pick(FBackColor, blend(clBtnFace, clBtnShadow, 8));
  var text := pick(FTextColor, clWindowText);
  var accent := pick(FSelectedColor, clHighlight);
  var selectedText := pick(FSelectedTextColor, (if FSelection in [nsPill, nsFill] then contrastText(accent) else text));
  var badgeFill := pick(FBadgeColor, clHighlight);
  var radius := scaled(self, FCornerRadius);
  var pad := scaled(self, FPadding);
  var icon := iconPx;
  // the captions show while the column is wider than the icons alone
  var showText := ClientWidth > scaled(self, FCollapsedWidth)+pad*2;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  var t := toggleRect;
  if FShowToggle then begin
    if (FHot = HOT_TOGGLE) and hoverEnabled then paintRoundRect(sp, t, radius, hoverColor(back), clNone);
    // three bars
    var cx := (t.Left+t.Right) div 2;
    var cy := (t.Top+t.Bottom) div 2;
    var half := Max(scaled(self, 8), 6);
    for var k := -1 to 1 do paintLine(sp, cx-half, cy+k*scaled(self, 5), cx+half, cy+k*scaled(self, 5), text, 2);
  end;
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if not item.Visible then continue;
    var r := itemRect(i);
    if item.Separator then begin
      paintLine(sp, r.Left+pad, (r.Top+r.Bottom) div 2, r.Right-pad, (r.Top+r.Bottom) div 2, blend(back, text, 20), 1);
      continue;
    end;
    var selected := i = FItemIndex;
    if selected then
      match FSelection of
        nsPill: paintRoundRect(sp, r, radius, accent, clNone);
        nsFill: paintRoundRect(sp, Rect(0, r.Top, ClientWidth, r.Bottom), 0, accent, clNone);
        nsUnderline: begin
          paintRoundRect(sp, r, radius, blend(back, accent, 12), clNone);
          paintRoundRect(sp, Rect(r.Left+pad, r.Bottom-scaled(self, 3), r.Right-pad, r.Bottom), 1, accent, clNone);
        end;
        nsOutline: paintRoundRect(sp, r, radius, blend(back, accent, 12), accent);
      else
        paintRoundRect(sp, r, radius, blend(back, accent, 18), clNone);
        paintRoundRect(sp, Rect(r.Left, r.Top+pad, r.Left+scaled(self, 3), r.Bottom-pad), 1, accent, clNone);
      end
    else if (i = FHot) and item.Enabled and hoverEnabled then paintRoundRect(sp, r, radius, hoverColor(back), clNone);
    if (FImages <> nil) and (item.ImageIndex >= 0) then continue;
    // no image: a dot stands in for the icon
    var ix := r.Left+(scaled(self, FCollapsedWidth)-pad*2) div 2;
    var dotColor := if selected then selectedText else if item.Enabled then text else ColorToRGB(clGrayText);
    paintCircle(sp, ix, (r.Top+r.Bottom) div 2, Max(icon div 6, 2), blend(dotColor, back, 40), clNone);
  end;
  if Focused and ringEnabled and (FItemIndex >= 0) then paintRing(sp, itemRect(FItemIndex), radius);
  sp.Flush;

  var custom: array of boolean := [];
  SetLength(custom, FItems.Count);
  if Assigned(FOnDrawItem) then
    for var i := 0 to FItems.Count-1 do begin
      if not FItems[i].Visible or FItems[i].Separator then continue;
      var state: TDrawState := if i = FItemIndex then [dsSelected] else [];
      if (i = FHot) and hoverEnabled then state += [dsHover];
      if not (Enabled and FItems[i].Enabled) then state += [dsDisabled];
      FOnDrawItem(self, Canvas, itemRect(i), i, state, custom[i]);
    end;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var slot := scaled(self, FCollapsedWidth)-pad*2;
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if not item.Visible or item.Separator or custom[i] then continue;
    var r := itemRect(i);
    var selected := i = FItemIndex;
    var color := if selected then selectedText else if item.Enabled then text else ColorToRGB(clGrayText);
    if (FImages <> nil) and (item.ImageIndex >= 0) then
      FImages.DrawForPPI(Canvas, r.Left+(slot-icon) div 2, r.Top+(r.Height-icon) div 2, item.ImageIndex, 0, Font.PixelsPerInch, GetCanvasScaleFactor, item.Enabled);
    if showText then begin
      var box := Rect(r.Left+slot+pad, r.Top, r.Right-pad, r.Bottom);
      if item.Badge <> '' then begin
        Canvas.Font.Style := Font.Style+[fsBold];
        var bw := Canvas.TextWidth(item.Badge)+scaled(self, 12);
        var bh := Canvas.TextHeight('0')+scaled(self, 4);
        var b := Rect(r.Right-pad-bw, (r.Top+r.Bottom-bh) div 2, r.Right-pad, (r.Top+r.Bottom+bh) div 2);
        var direct := autofree TSmoothPaint.CreateDirect(Canvas);
        paintPill(direct, b, badgeFill, clNone);
        paintCenteredText(Canvas, b, item.Badge, contrastText(badgeFill));
        Canvas.Font.Style := Font.Style;
        box.Right := b.Left-pad;
      end;
      Canvas.Font.Style := if selected then Font.Style+[fsBold] else Font.Style;
      var style := Canvas.TextStyle;
      style.Alignment := taLeftJustify;
      style.Layout := tlCenter;
      style.SingleLine := true;
      style.Clipping := true;
      style.Opaque := false;
      style.ShowPrefix := false;
      style.EndEllipsis := true;
      Canvas.Font.Color := color;
      Canvas.TextRect(box, box.Left, box.Top, item.Caption, style);
    end;
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TSideNav.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  var hit := itemAt(X, Y);
  if hit = HOT_TOGGLE then Toggle
  else if (hit >= 0) and FItems[hit].Enabled then begin
    ItemIndex := hit;
    if Assigned(FOnItemClick) then FOnItemClick(self, FItems[hit]);
  end;
end;

procedure TSideNav.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  setHot(itemAt(X, Y));
end;

procedure TSideNav.MouseLeave;
begin
  inherited MouseLeave;
  setHot(HOT_NONE);
end;

procedure TSideNav.setHot(value: integer);
begin
  if FHot = value then exit;
  FHot := value;
  // collapsed, the caption comes up as the hint
  if value >= 0 then Hint := if FItems[value].Hint <> '' then FItems[value].Hint else if FCollapsed then FItems[value].Caption else ''
  else Hint := '';
  Invalidate;
end;

procedure TSideNav.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var delta := match Key of
    VK_UP: -1;
    VK_DOWN: 1;
    VK_HOME: -FItems.Count;
    VK_END: FItems.Count;
  else
    0
  end;
  if delta = 0 then exit;
  Key := 0;
  var i := EnsureRange(FItemIndex+delta, 0, FItems.Count-1);
  // the move skips what cannot be picked
  while (i >= 0) and (i < FItems.Count) and (FItems[i].Separator or not FItems[i].Visible or not FItems[i].Enabled) do i += Sign(delta);
  if (i >= 0) and (i < FItems.Count) then ItemIndex := i;
end;

procedure TSideNav.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TSideNav.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TSideNav.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then begin
    FImages := nil;
    Invalidate;
  end;
end;

procedure TSideNav.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  Invalidate;
end;

procedure TSideNav.itemsChanged;
begin
  if FItemIndex >= FItems.Count then FItemIndex := -1;
  Invalidate;
end;

function TSideNav.SelectedItem: TSideNavItem;
begin
  result := if (FItemIndex >= 0) and (FItemIndex < FItems.Count) then FItems[FItemIndex] else nil;
end;

// -- properties ----------------------

procedure TSideNav.setItems(value: TSideNavItems);
begin
  FItems.Assign(value);
end;

procedure TSideNav.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  Invalidate;
end;

procedure TSideNav.setItemIndex(value: integer);
begin
  if value < -1 then value := -1;
  if value >= FItems.Count then value := FItems.Count-1;
  if FItemIndex = value then exit;
  FItemIndex := value;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

function TSideNav.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FCollapsed;
    1: FShowToggle;
  else
    FAnimated
  end;
end;

procedure TSideNav.setFlag(index: integer; value: boolean);
begin
  match index of
    0: setCollapsed(value);
    1: begin
      if FShowToggle = value then exit;
      FShowToggle := value;
      Invalidate;
    end;
  else
    FAnimated := value;
  end;
end;

function TSideNav.getMetric(index: integer): integer;
begin
  result := match index of
    0: FItemHeight;
    1: FCollapsedWidth;
    2: FExpandedWidth;
    3: FPadding;
    4: FCornerRadius;
    5: FHeaderHeight;
  else
    FAnimationTime
  end;
end;

procedure TSideNav.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FItemHeight := value;
    1: FCollapsedWidth := value;
    2: FExpandedWidth := value;
    3: FPadding := value;
    4: FCornerRadius := value;
    5: FHeaderHeight := value;
  else
    FAnimationTime := value;
  end;
  if (index in [1, 2]) and not (csLoading in ComponentState) then settle(false);
  Invalidate;
end;

function TSideNav.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBackColor;
    1: FTextColor;
    2: FSelectedColor;
    3: FSelectedTextColor;
  else
    FBadgeColor
  end;
end;

procedure TSideNav.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBackColor := value;
    1: FTextColor := value;
    2: FSelectedColor := value;
    3: FSelectedTextColor := value;
  else
    FBadgeColor := value;
  end;
  Invalidate;
end;

procedure TSideNav.setSelection(value: TSideNavSelection);
begin
  if FSelection = value then exit;
  FSelection := value;
  Invalidate;
end;

procedure TSideNav.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
