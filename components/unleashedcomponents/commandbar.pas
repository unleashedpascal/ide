{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit CommandBar;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Menus, ImgList, LCLType, ControlPaint;

type
  TCommandBar = class;
  // a push button, a toggle, a button dropping a menu, a separator
  TCommandKind = (ckButton, ckToggle, ckDropDown, ckSeparator);
  TCommandCaptions = (ccRight, ccBelow, ccNone);
  TCommandEvent = procedure(Sender: TObject; index: integer) of object;

  { TCommandItem }

  TCommandItem = class(TCollectionItem)
  private
    FCaption, FHint: string;
    FImageIndex: TImageIndex;
    FKind: TCommandKind;
    FEnabled, FVisible, FChecked, FSecondary, FShowCaption: boolean;
    FDropDownMenu: TPopupMenu;
    FTag: PtrInt;
    FOnClick: TNotifyEvent;
    procedure setCaption(const value: string);
    procedure setImageIndex(value: TImageIndex);
    procedure setKind(value: TCommandKind);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setDropDownMenu(value: TPopupMenu);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Caption: string read FCaption write setCaption;
    property Hint: string read FHint write FHint;
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    property Kind: TCommandKind read FKind write setKind default ckButton;
    property Enabled: boolean index 0 read getFlag write setFlag default true;
    property Visible: boolean index 1 read getFlag write setFlag default true;
    // a toggle shows pressed while checked
    property Checked: boolean index 2 read getFlag write setFlag default false;
    // the command sits in the overflow menu from the start
    property Secondary: boolean index 3 read getFlag write setFlag default false;
    // the caption next to the icon; off, the icon alone with the caption as hint
    property ShowCaption: boolean index 4 read getFlag write setFlag default true;
    // what a drop-down command opens
    property DropDownMenu: TPopupMenu read FDropDownMenu write setDropDownMenu;
    property Tag: PtrInt read FTag write FTag default 0;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  { TCommandItems }

  TCommandItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TCommandItem;
    procedure setItem(index: integer; value: TCommandItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TCommandItem;
    function AddCommand(const caption: string; imageIndex: TImageIndex = -1; onClick: TNotifyEvent = nil): TCommandItem;
    function AddSeparator: TCommandItem;
    property Items[index: integer]: TCommandItem read getItem write setItem; default;
  end;

  { TCommandBar }

  // a row of commands with icons and captions: buttons, toggles that stay
  // pressed, drop-downs that open a menu and separators between groups.
  // What does not fit, and every Secondary command, goes to the menu of the
  // button with the three dots at the end
  TCommandBar = class(TCustomControl)
  private
    FItems: TCommandItems;
    FImages: TCustomImageList;
    FImagesWidth: integer;
    FCaptions: TCommandCaptions;
    FHot, FPressed, FFocusIndex, FButtonPadding, FSpacing, FCornerRadius: integer;
    FHotMore: boolean;
    FPlaced: array of TRect; // per item; empty when the item is not on the bar
    FOverflow: array of integer;
    FMoreRect: TRect;
    FMoreMenu: TPopupMenu;
    FAccentColor, FTextColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnItemClick: TCommandEvent;
    FOnDrawItem: TCustomDrawEvent;
    procedure setItems(value: TCommandItems);
    procedure setImages(value: TCustomImageList);
    procedure setCaptions(value: TCommandCaptions);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function itemWidth(index: integer): integer;
    function captionShown(index: integer): boolean;
    procedure layout;
    function itemAt(X, Y: integer): integer;
    procedure openMore;
    procedure moreClick(Sender: TObject);
    procedure focusStep(delta: integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
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
    procedure itemsChanged;
    // what a click on a command does
    procedure Execute(index: integer);
    // the commands in the overflow menu right now
    function OverflowCount: integer;
  published
    property Items: TCommandItems read FItems write setItems;
    property Images: TCustomImageList read FImages write setImages;
    property ImagesWidth: integer index 0 read getMetric write setMetric default 0;
    property Captions: TCommandCaptions read FCaptions write setCaptions default ccRight;
    property ButtonPadding: integer index 1 read getMetric write setMetric default 8;
    property Spacing: integer index 2 read getMetric write setMetric default 2;
    property CornerRadius: integer index 3 read getMetric write setMetric default 4;
    // clDefault takes the colors of the theme
    property AccentColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // after any command, with its index, after its own OnClick
    property OnItemClick: TCommandEvent read FOnItemClick write FOnItemClick;
    // paints over the stock button: dsChecked for a toggle that is on,
    // dsHover, dsPressed; `handled` true leaves the caption and the icon out
    property OnDrawItem: TCustomDrawEvent read FOnDrawItem write FOnDrawItem;
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
    property ShowHint default true;
    property TabOrder;
    property TabStop default true;
    property Visible;
    property OnContextPopup;
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

{ TCommandItem }

constructor TCommandItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FImageIndex := -1;
  FEnabled := true;
  FVisible := true;
  FShowCaption := true;
end;

procedure TCommandItem.Assign(Source: TPersistent);
begin
  if Source is TCommandItem then begin
    var s := TCommandItem(Source);
    FCaption := s.FCaption;
    FHint := s.FHint;
    FImageIndex := s.FImageIndex;
    FKind := s.FKind;
    FEnabled := s.FEnabled;
    FVisible := s.FVisible;
    FChecked := s.FChecked;
    FSecondary := s.FSecondary;
    FShowCaption := s.FShowCaption;
    setDropDownMenu(s.FDropDownMenu);
    FTag := s.FTag;
    FOnClick := s.FOnClick;
    Changed(false);
  end else inherited Assign(Source);
end;

function TCommandItem.GetDisplayName: string;
begin
  result := if FKind = ckSeparator then '-' else if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TCommandItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TCommandItem.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Changed(false);
end;

procedure TCommandItem.setKind(value: TCommandKind);
begin
  if FKind = value then exit;
  FKind := value;
  Changed(false);
end;

function TCommandItem.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FEnabled;
    1: FVisible;
    2: FChecked;
    3: FSecondary;
  else
    FShowCaption
  end;
end;

procedure TCommandItem.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FEnabled := value;
    1: FVisible := value;
    2: FChecked := value;
    3: FSecondary := value;
  else
    FShowCaption := value;
  end;
  Changed(false);
end;

procedure TCommandItem.setDropDownMenu(value: TPopupMenu);
begin
  if FDropDownMenu = value then exit;
  var bar := TCommandItems(Collection).Owner as TCommandBar;
  if (FDropDownMenu <> nil) and (bar <> nil) then FDropDownMenu.RemoveFreeNotification(bar);
  FDropDownMenu := value;
  if (FDropDownMenu <> nil) and (bar <> nil) then FDropDownMenu.FreeNotification(bar);
end;

{ TCommandItems }

function TCommandItems.getItem(index: integer): TCommandItem;
begin
  result := TCommandItem(inherited Items[index]);
end;

procedure TCommandItems.setItem(index: integer; value: TCommandItem);
begin
  inherited Items[index] := value;
end;

procedure TCommandItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TCommandBar then TCommandBar(Owner).itemsChanged;
end;

function TCommandItems.Add: TCommandItem;
begin
  result := TCommandItem(inherited Add);
end;

function TCommandItems.AddCommand(const caption: string; imageIndex: TImageIndex; onClick: TNotifyEvent): TCommandItem;
begin
  result := Add;
  result.FCaption := caption;
  result.FImageIndex := imageIndex;
  result.FOnClick := onClick;
  result.Changed(false);
end;

function TCommandItems.AddSeparator: TCommandItem;
begin
  result := Add;
  result.Kind := ckSeparator;
end;

{ TCommandBar }

constructor TCommandBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FItems := TCommandItems.Create(self, TCommandItem);
  FHot := -1;
  FPressed := -1;
  FFocusIndex := -1;
  FButtonPadding := 8;
  FSpacing := 2;
  FCornerRadius := 4;
  FAccentColor := clDefault;
  FTextColor := clDefault;
  ShowHint := true;
  TabStop := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TCommandBar.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

class function TCommandBar.GetControlClassDefaultSize: TSize;
begin
  result.cx := 400;
  result.cy := 36;
end;

procedure TCommandBar.itemsChanged;
begin
  if (FItems = nil) or (csDestroying in ComponentState) then exit;
  InvalidatePreferredSize;
  AdjustSize;
  layout;
  Invalidate;
end;

function TCommandBar.OverflowCount: integer;
begin
  layout;
  result := length(FOverflow);
end;

// -- layout ----------------------

function TCommandBar.captionShown(index: integer): boolean;
begin
  result := (FCaptions <> ccNone) and FItems[index].FShowCaption and (FItems[index].FCaption <> '');
end;

function TCommandBar.itemWidth(index: integer): integer;
begin
  var item := FItems[index];
  if item.FKind = ckSeparator then exit(scaled(self, 9));
  Canvas.Font := Font;
  var pad := scaled(self, FButtonPadding);
  var icon := if (FImages <> nil) and (item.FImageIndex >= 0) then FImages.ResolutionForControl[FImagesWidth, self].Width else 0;
  var text := if captionShown(index) then Canvas.TextWidth(item.FCaption) else 0;
  result := match FCaptions of
    ccBelow: Max(icon, text);
  else
    icon+text+(if (icon > 0) and (text > 0) then scaled(self, 6) else 0)
  end;
  if item.FKind = ckDropDown then result += scaled(self, 14);
  result := Max(result, scaled(self, 16))+2*pad;
end;

// the commands left to right while they fit; the rest and the secondary ones
// go to the overflow, and the dots button shows when it has any
procedure TCommandBar.layout;
begin
  // the widths are measured on the canvas, which needs the handle
  if (FItems = nil) or not HandleAllocated then exit;
  SetLength(FPlaced, FItems.Count);
  FOverflow := [];
  FMoreRect := Rect(0, 0, 0, 0);
  var gap := scaled(self, FSpacing);
  var moreW := ClientHeight;
  var visible: array of integer := [];
  var secondary := false;
  for var i := 0 to FItems.Count-1 do begin
    FPlaced[i] := Rect(0, 0, 0, 0);
    if not FItems[i].FVisible then continue;
    if FItems[i].FSecondary then secondary := true
    else visible += [i];
  end;
  var total := 0;
  for var i in visible do total += itemWidth(i)+gap;
  var room := ClientWidth-(if secondary or (total > ClientWidth) then moreW+gap else 0);
  var x := 0;
  var spilled := false;
  for var i in visible do begin
    var w := itemWidth(i);
    if spilled or (x+w > room) then begin
      spilled := true;
      if FItems[i].FKind <> ckSeparator then FOverflow += [i];
      continue;
    end;
    FPlaced[i] := Rect(x, 0, x+w, ClientHeight);
    x += w+gap;
  end;
  // a separator at the end of the bar has nothing to separate
  for var k := FItems.Count-1 downto 0 do
    if FPlaced[k].Width > 0 then begin
      if FItems[k].FKind = ckSeparator then FPlaced[k] := Rect(0, 0, 0, 0);
      break;
    end;
  for var i := 0 to FItems.Count-1 do
    if FItems[i].FVisible and FItems[i].FSecondary and (FItems[i].FKind <> ckSeparator) then FOverflow += [i];
  if length(FOverflow) > 0 then FMoreRect := Rect(ClientWidth-moreW, 0, ClientWidth, ClientHeight);
end;

function TCommandBar.itemAt(X, Y: integer): integer;
begin
  result := -1;
  for var i := 0 to length(FPlaced)-1 do
    if (FPlaced[i].Width > 0) and FPlaced[i].Contains(Point(X, Y)) and (FItems[i].FKind <> ckSeparator) then exit(i);
end;

procedure TCommandBar.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  var icon := if FImages <> nil then FImages.ResolutionForControl[FImagesWidth, self].Height else 0;
  PreferredHeight := (if FCaptions = ccBelow then icon+th+scaled(self, 4) else Max(icon, th))+scaled(self, 14);
  var w := 0;
  for var i := 0 to FItems.Count-1 do
    if FItems[i].FVisible and not FItems[i].FSecondary then w += itemWidth(i)+scaled(self, FSpacing);
  PreferredWidth := w;
end;

// -- painting ----------------------

procedure TCommandBar.Paint;
begin
  layout;
  var back := GetRGBColorResolvingParent;
  var accent := pick(FAccentColor, clHighlight);
  var text := pick(FTextColor, clWindowText);
  var radius := scaled(self, FCornerRadius);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  for var i := 0 to FItems.Count-1 do begin
    var r := FPlaced[i];
    if r.Width = 0 then continue;
    var item := FItems[i];
    if item.FKind = ckSeparator then begin
      var cx := (r.Left+r.Right) div 2;
      paintLine(sp, cx, r.Top+scaled(self, 8), cx, r.Bottom-scaled(self, 8), blend(back, text, 22), 1);
      continue;
    end;
    var inner := r;
    inner.Inflate(0, -scaled(self, 3));
    var usable := item.FEnabled and Enabled;
    if (item.FKind = ckToggle) and item.FChecked then
      paintRoundRect(sp, inner, radius, blend(back, accent, (if (i = FPressed) and hoverEnabled then 45 else 28)), clNone)
    else if usable and (i = FPressed) and hoverEnabled then
      paintRoundRect(sp, inner, radius, blend(back, text, 16), clNone)
    else if usable and (i = FHot) and hoverEnabled then
      paintRoundRect(sp, inner, radius, hoverColor(back), clNone);
    if item.FKind = ckDropDown then
      paintChevron(sp, Rect(inner.Right-scaled(self, FButtonPadding)-scaled(self, 10), inner.Top, inner.Right-scaled(self, FButtonPadding), inner.Bottom), cdDown, scaled(self, 7), (if usable then text else ColorToRGB(clGrayText)));
    if Focused and (i = FFocusIndex) and ringEnabled then paintRing(sp, inner, radius);
  end;
  if FMoreRect.Width > 0 then begin
    var inner := FMoreRect;
    inner.Inflate(-scaled(self, 3), -scaled(self, 3));
    if FHotMore and hoverEnabled then paintRoundRect(sp, inner, radius, hoverColor(back), clNone);
    var cy := (inner.Top+inner.Bottom) div 2;
    var cx := (inner.Left+inner.Right) div 2;
    var dot := Max(scaled(self, 2), 1);
    for var k := -1 to 1 do paintCircle(sp, cx+k*scaled(self, 6), cy, dot, text, clNone);
    if Focused and (FFocusIndex = FItems.Count) and ringEnabled then paintRing(sp, inner, radius);
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  var res := if FImages <> nil then FImages.ResolutionForControl[FImagesWidth, self] else default(TScaledImageListResolution);
  for var i := 0 to FItems.Count-1 do begin
    var r := FPlaced[i];
    var item := FItems[i];
    if (r.Width = 0) or (item.FKind = ckSeparator) then continue;
    var usable := item.FEnabled and Enabled;
    if Assigned(FOnDrawItem) then begin
      var state: TDrawState := [];
      if (item.FKind = ckToggle) and item.FChecked then state += [dsChecked];
      if (i = FHot) and hoverEnabled then state += [dsHover];
      if i = FPressed then state += [dsPressed];
      if not usable then state += [dsDisabled];
      if Focused and (i = FFocusIndex) then state += [dsFocused];
      var handled := false;
      FOnDrawItem(self, Canvas, r, i, state, handled);
      if handled then continue;
    end;
    var pad := scaled(self, FButtonPadding);
    var content := Rect(r.Left+pad, r.Top, r.Right-pad-(if item.FKind = ckDropDown then scaled(self, 14) else 0), r.Bottom);
    var hasIcon := (FImages <> nil) and (item.FImageIndex >= 0) and (item.FImageIndex < FImages.Count);
    Canvas.Font := Font;
    Canvas.Font.Color := if usable then text else ColorToRGB(clGrayText);
    if FCaptions = ccBelow then begin
      var th := Canvas.TextHeight('Hg');
      var iconH := if hasIcon then res.Height else 0;
      var top := (r.Top+r.Bottom-(iconH+(if captionShown(i) then th+scaled(self, 2) else 0))) div 2;
      if hasIcon then res.Draw(Canvas, (content.Left+content.Right-res.Width) div 2, top, item.FImageIndex, usable);
      if captionShown(i) then begin
        style.Alignment := taCenter;
        style.Layout := tlTop;
        var box := Rect(content.Left, top+iconH+scaled(self, 2), content.Right, top+iconH+scaled(self, 2)+th);
        Canvas.TextRect(box, box.Left, box.Top, item.FCaption, style);
      end;
    end else begin
      var x := content.Left;
      if hasIcon then begin
        res.Draw(Canvas, x, (r.Top+r.Bottom-res.Height) div 2, item.FImageIndex, usable);
        x += res.Width+scaled(self, 6);
      end;
      if captionShown(i) then begin
        style.Alignment := taLeftJustify;
        style.Layout := tlCenter;
        var box := Rect(x, r.Top, content.Right, r.Bottom);
        Canvas.TextRect(box, box.Left, box.Top, item.FCaption, style);
      end;
    end;
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- commands ----------------------

procedure TCommandBar.Execute(index: integer);
begin
  if (index < 0) or (index >= FItems.Count) then exit;
  var item := FItems[index];
  if not item.FEnabled or (item.FKind = ckSeparator) then exit;
  if item.FKind = ckToggle then item.Checked := not item.FChecked;
  if item.FKind = ckDropDown then begin
    if item.FDropDownMenu <> nil then begin
      var r := FPlaced[index];
      // from the overflow the menu opens under the dots button
      if r.Width = 0 then r := FMoreRect;
      var p := ClientToScreen(Point(r.Left, r.Bottom));
      item.FDropDownMenu.PopupComponent := self;
      item.FDropDownMenu.Popup(p.X, p.Y);
    end;
  end;
  if Assigned(item.FOnClick) then item.FOnClick(item);
  if Assigned(FOnItemClick) then FOnItemClick(self, index);
end;

procedure TCommandBar.moreClick(Sender: TObject);
begin
  Execute(TMenuItem(Sender).Tag);
end;

procedure TCommandBar.openMore;
begin
  layout;
  if FMoreMenu = nil then FMoreMenu := TPopupMenu.Create(self);
  FMoreMenu.Items.Clear;
  FMoreMenu.Images := FImages;
  for var i in FOverflow do begin
    var item := FItems[i];
    var m := TMenuItem.Create(FMoreMenu);
    m.Caption := item.FCaption;
    m.ImageIndex := item.FImageIndex;
    m.Enabled := item.FEnabled;
    m.Checked := (item.FKind = ckToggle) and item.FChecked;
    m.Hint := item.FHint;
    m.Tag := i;
    // a drop-down hands its own menu over as a submenu
    if (item.FKind = ckDropDown) and (item.FDropDownMenu <> nil) then begin
      for var k := 0 to item.FDropDownMenu.Items.Count-1 do begin
        var src := item.FDropDownMenu.Items[k];
        var sub := TMenuItem.Create(m);
        sub.Caption := src.Caption;
        sub.Enabled := src.Enabled;
        sub.Checked := src.Checked;
        sub.ImageIndex := src.ImageIndex;
        sub.OnClick := src.OnClick;
        sub.Tag := src.Tag;
        m.Add(sub);
      end;
    end else m.OnClick := @moreClick;
    FMoreMenu.Items.Add(m);
  end;
  var p := ClientToScreen(Point(FMoreRect.Left, FMoreRect.Bottom));
  FMoreMenu.PopupComponent := self;
  FMoreMenu.Popup(p.X, p.Y);
end;

// -- input ----------------------

procedure TCommandBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled or (csDesigning in ComponentState) then exit;
  if FMoreRect.Contains(Point(X, Y)) then begin
    openMore;
    exit;
  end;
  var i := itemAt(X, Y);
  if (i >= 0) and FItems[i].FEnabled then begin
    FPressed := i;
    Invalidate;
    // a drop-down opens on the press, as menus do
    if FItems[i].FKind = ckDropDown then begin
      FPressed := -1;
      Execute(i);
    end;
  end;
end;

procedure TCommandBar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := itemAt(X, Y);
  var hotMore := FMoreRect.Contains(Point(X, Y));
  if (hot <> FHot) or (hotMore <> FHotMore) then begin
    FHot := hot;
    FHotMore := hotMore;
    Invalidate;
  end;
end;

procedure TCommandBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FPressed < 0 then exit;
  var i := FPressed;
  FPressed := -1;
  Invalidate;
  if itemAt(X, Y) = i then Execute(i);
end;

procedure TCommandBar.MouseLeave;
begin
  inherited MouseLeave;
  if (FHot >= 0) or FHotMore then begin
    FHot := -1;
    FHotMore := false;
    Invalidate;
  end;
end;

// the focus walks the commands on the bar and the dots button after them
procedure TCommandBar.focusStep(delta: integer);
begin
  layout;
  var stops: array of integer := [];
  for var i := 0 to FItems.Count-1 do
    if (FPlaced[i].Width > 0) and (FItems[i].FKind <> ckSeparator) and FItems[i].FEnabled then stops += [i];
  if FMoreRect.Width > 0 then stops += [FItems.Count];
  if length(stops) = 0 then exit;
  var at := -1;
  for var k := 0 to length(stops)-1 do if stops[k] = FFocusIndex then at := k;
  at := if at < 0 then (if delta > 0 then 0 else length(stops)-1) else (at+delta+length(stops)) mod length(stops);
  FFocusIndex := stops[at];
  Invalidate;
end;

procedure TCommandBar.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_LEFT: focusStep(-1);
    VK_RIGHT: focusStep(1);
    VK_HOME: begin
      FFocusIndex := -1;
      focusStep(1);
    end;
    VK_END: begin
      FFocusIndex := -1;
      focusStep(-1);
    end;
    VK_RETURN, VK_SPACE, VK_DOWN:
      if FFocusIndex = FItems.Count then openMore
      else if (FFocusIndex >= 0) and ((Key <> VK_DOWN) or (FItems[FFocusIndex].FKind = ckDropDown)) then Execute(FFocusIndex)
      else exit;
  else
    exit;
  end;
  Key := 0;
end;

// a command shows its hint, or its caption when the caption is hidden
procedure TCommandBar.DoOnShowHint(HintInfo: PHintInfo);
begin
  var i := itemAt(HintInfo^.CursorPos.X, HintInfo^.CursorPos.Y);
  if i >= 0 then begin
    var s := if FItems[i].FHint <> '' then FItems[i].FHint else if not captionShown(i) then FItems[i].FCaption else '';
    if s <> '' then begin
      HintInfo^.HintStr := s;
      HintInfo^.CursorRect := FPlaced[i];
    end;
  end;
  inherited DoOnShowHint(HintInfo);
end;

procedure TCommandBar.DoEnter;
begin
  inherited DoEnter;
  if FFocusIndex < 0 then focusStep(1);
  Invalidate;
end;

procedure TCommandBar.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TCommandBar.DoOnResize;
begin
  inherited DoOnResize;
  layout;
  Invalidate;
end;

procedure TCommandBar.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  itemsChanged;
end;

procedure TCommandBar.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  if AComponent = FImages then begin
    FImages := nil;
    itemsChanged;
  end;
  if FItems <> nil then
    for var i := 0 to FItems.Count-1 do
      if FItems[i].FDropDownMenu = AComponent then FItems[i].FDropDownMenu := nil;
end;

// -- properties ----------------------

procedure TCommandBar.setItems(value: TCommandItems);
begin
  FItems.Assign(value);
end;

procedure TCommandBar.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  itemsChanged;
end;

procedure TCommandBar.setCaptions(value: TCommandCaptions);
begin
  if FCaptions = value then exit;
  FCaptions := value;
  itemsChanged;
end;

function TCommandBar.getMetric(index: integer): integer;
begin
  result := match index of
    0: FImagesWidth;
    1: FButtonPadding;
    2: FSpacing;
  else
    FCornerRadius
  end;
end;

procedure TCommandBar.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FImagesWidth := value;
    1: FButtonPadding := value;
    2: FSpacing := value;
  else
    FCornerRadius := value;
  end;
  itemsChanged;
end;

function TCommandBar.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FAccentColor else FTextColor;
end;

procedure TCommandBar.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FAccentColor := value else FTextColor := value;
  Invalidate;
end;

procedure TCommandBar.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
