{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit BreadcrumbBar;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Menus, ImgList, ControlPaint;

type
  TRectArray = array of TRect;
  TBreadcrumbBar = class;

  { TBreadcrumbItem }

  TBreadcrumbItem = class(TCollectionItem)
  private
    FCaption, FHint: string;
    FImageIndex: TImageIndex;
    FTag: PtrInt;
    procedure setCaption(const value: string);
    procedure setImageIndex(value: TImageIndex);
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
  end;

  { TBreadcrumbItems }

  TBreadcrumbItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TBreadcrumbItem;
    procedure setItem(index: integer; value: TBreadcrumbItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TBreadcrumbItem;
    function AddItem(const caption: string; tag: PtrInt = 0): TBreadcrumbItem;
    property Items[index: integer]: TBreadcrumbItem read getItem write setItem; default;
  end;

  // what sits between the parts: a chevron, a slash, a backslash, a
  // greater-than sign, two chevrons, a dot, a pipe
  TBreadcrumbSeparator = (bsChevron, bsSlash, bsBackslash, bsArrow, bsDoubleChevron, bsDot, bsPipe);
  TBreadcrumbClickEvent = procedure(Sender: TObject; index: integer) of object;

  { TBreadcrumbBar }

  // the path to the current place as a row of clickable parts. What does
  // not fit folds into a menu behind an ellipsis at the start
  TBreadcrumbBar = class(TCustomControl)
  private
    FItems: TBreadcrumbItems;
    FImages: TCustomImageList;
    FSeparator: TBreadcrumbSeparator;
    FSpacing, FPadding, FCornerRadius: integer;
    FHot: integer;
    FTextColor, FLastColor, FSeparatorColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnDrawItem: TCustomDrawEvent;
    FMenu: TPopupMenu;
    FFirstShown: integer; // the index of the first part on screen
    FOnItemClick: TBreadcrumbClickEvent;
    procedure setItems(value: TBreadcrumbItems);
    procedure setImages(value: TCustomImageList);
    procedure setSeparator(value: TBreadcrumbSeparator);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function getPath: string;
    procedure setPath(const value: string);
    function itemWidth(index: integer): integer;
    function separatorWidth: integer;
    function ellipsisWidth: integer;
    procedure measure(out rects: TRectArray; out ellipsis: TRect);
    function itemAt(x, y: integer): integer;
    procedure setHot(value: integer);
    procedure menuClick(Sender: TObject);
    procedure itemsChanged;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // drops every part after `index`
    procedure TruncateTo(index: integer);
  published
    property Items: TBreadcrumbItems read FItems write setItems;
    property Images: TCustomImageList read FImages write setImages;
    // the parts joined with the delimiter; set, it replaces the items
    property Path: string read getPath write setPath stored false;
    property Separator: TBreadcrumbSeparator read FSeparator write setSeparator default bsChevron;
    // around the separator
    property Spacing: integer index 0 read getMetric write setMetric default 6;
    // inside a part, around its caption
    property Padding: integer index 1 read getMetric write setMetric default 6;
    property CornerRadius: integer index 2 read getMetric write setMetric default 4;
    // clDefault takes the colors of the theme
    property TextColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    // the last part, the place itself
    property LastColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property SeparatorColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over the stock part: dsSelected for the last one, dsHover under
    // the mouse; `handled` true leaves the caption out
    property OnDrawItem: TCustomDrawEvent read FOnDrawItem write FOnDrawItem;
    property OnItemClick: TBreadcrumbClickEvent read FOnItemClick write FOnItemClick;
    property Align;
    property Anchors;
    property AutoSize default true;
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
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
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
  HOT_ELLIPSIS = -2;

{ TBreadcrumbItem }

constructor TBreadcrumbItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FImageIndex := -1;
end;

procedure TBreadcrumbItem.Assign(Source: TPersistent);
begin
  if Source is TBreadcrumbItem then begin
    FCaption := TBreadcrumbItem(Source).FCaption;
    FHint := TBreadcrumbItem(Source).FHint;
    FImageIndex := TBreadcrumbItem(Source).FImageIndex;
    FTag := TBreadcrumbItem(Source).FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TBreadcrumbItem.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TBreadcrumbItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TBreadcrumbItem.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Changed(false);
end;

{ TBreadcrumbItems }

function TBreadcrumbItems.getItem(index: integer): TBreadcrumbItem;
begin
  result := TBreadcrumbItem(inherited Items[index]);
end;

procedure TBreadcrumbItems.setItem(index: integer; value: TBreadcrumbItem);
begin
  inherited Items[index] := value;
end;

procedure TBreadcrumbItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TBreadcrumbBar then TBreadcrumbBar(Owner).itemsChanged;
end;

function TBreadcrumbItems.Add: TBreadcrumbItem;
begin
  result := TBreadcrumbItem(inherited Add);
end;

function TBreadcrumbItems.AddItem(const caption: string; tag: PtrInt): TBreadcrumbItem;
begin
  result := Add;
  result.FCaption := caption;
  result.FTag := tag;
  result.Changed(false);
end;

{ TBreadcrumbBar }

constructor TBreadcrumbBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  FItems := TBreadcrumbItems.Create(self, TBreadcrumbItem);
  FHot := HOT_NONE;
  FSpacing := 6;
  FPadding := 6;
  FCornerRadius := 4;
  FTextColor := clDefault;
  FLastColor := clDefault;
  FSeparatorColor := clDefault;
  FAntialiasing := asTheme;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TBreadcrumbBar.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

class function TBreadcrumbBar.GetControlClassDefaultSize: TSize;
begin
  result.cx := 300;
  result.cy := 26;
end;

// -- geometry ----------------------

function TBreadcrumbBar.itemWidth(index: integer): integer;
begin
  var item := FItems[index];
  // measured the way it is painted: the quality of the theme, the last part bold
  applyTextQuality(Canvas);
  Canvas.Font.Style := if index = FItems.Count-1 then Font.Style+[fsBold] else Font.Style;
  result := Canvas.TextWidth(item.Caption)+scaled(self, FPadding)*2;
  Canvas.Font.Style := Font.Style;
  if (FImages <> nil) and (item.ImageIndex >= 0) then result += FImages.WidthForPPI[0, Font.PixelsPerInch]+scaled(self, 4);
end;

function TBreadcrumbBar.separatorWidth: integer;
begin
  applyTextQuality(Canvas);
  result := scaled(self, FSpacing)*2+(if FSeparator = bsChevron then Max(scaled(self, 6), 4) else Canvas.TextWidth('/'));
end;

function TBreadcrumbBar.ellipsisWidth: integer;
begin
  applyTextQuality(Canvas);
  result := Canvas.TextWidth('...')+scaled(self, FPadding)*2;
end;

// the parts from the end back as far as they fit; the rest hides behind
// the ellipsis
procedure TBreadcrumbBar.measure(out rects: TRectArray; out ellipsis: TRect);
begin
  SetLength(rects, FItems.Count);
  ellipsis := Rect(0, 0, 0, 0);
  var sep := separatorWidth;
  var room := ClientWidth;
  var total := 0;
  FFirstShown := FItems.Count;
  for var i := FItems.Count-1 downto 0 do begin
    var w := itemWidth(i)+(if i < FItems.Count-1 then sep else 0);
    var need := total+w+(if i > 0 then ellipsisWidth+sep else 0);
    if (need > room) and (i < FItems.Count-1) then break;
    total += w;
    FFirstShown := i;
  end;
  var x := 0;
  if FFirstShown > 0 then begin
    ellipsis := Rect(0, 0, ellipsisWidth, ClientHeight);
    x := ellipsisWidth+sep;
  end;
  for var i := 0 to FItems.Count-1 do begin
    if i < FFirstShown then begin
      rects[i] := Rect(0, 0, 0, 0);
      continue;
    end;
    rects[i] := Rect(x, 0, x+itemWidth(i), ClientHeight);
    x += itemWidth(i)+sep;
  end;
end;

function TBreadcrumbBar.itemAt(x, y: integer): integer;
begin
  var rects: TRectArray;
  var ellipsis: TRect;
  measure(rects, ellipsis);
  if (ellipsis.Width > 0) and ellipsis.Contains(Point(x, y)) then exit(HOT_ELLIPSIS);
  for var i := 0 to high(rects) do if (rects[i].Width > 0) and rects[i].Contains(Point(x, y)) then exit(i);
  result := HOT_NONE;
end;

procedure TBreadcrumbBar.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := Canvas.TextHeight('Hg')+scaled(self, 10);
  if FImages <> nil then PreferredHeight := Max(PreferredHeight, FImages.HeightForPPI[0, Font.PixelsPerInch]+scaled(self, 8));
end;

// -- painting ----------------------

procedure TBreadcrumbBar.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var text := pick(FTextColor, clGrayText);
  var last := pick(FLastColor, clWindowText);
  var sepColor := pick(FSeparatorColor, blend(clGrayText, clBtnFace, 30));
  var rects: TRectArray;
  var ellipsis: TRect;
  measure(rects, ellipsis);
  var radius := scaled(self, FCornerRadius);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  if (FHot = HOT_ELLIPSIS) and hoverEnabled then paintRoundRect(sp, ellipsis, radius, hoverColor(back), clNone);
  // the separators drawn as shapes; the others are glyphs of the font
  var drawn := FSeparator in [bsChevron, bsDoubleChevron, bsDot];
  var shape := procedure(const s: TRect)
  begin
    var size := Max(scaled(self, 6), 4);
    match FSeparator of
      bsDoubleChevron: begin
        var cx := (s.Left+s.Right) div 2;
        paintChevron(sp, Rect(s.Left, s.Top, cx+1, s.Bottom), cdRight, size, sepColor);
        paintChevron(sp, Rect(cx-1, s.Top, s.Right, s.Bottom), cdRight, size, sepColor);
      end;
      bsDot: paintCircle(sp, (s.Left+s.Right) div 2, (s.Top+s.Bottom) div 2, Max(scaled(self, 2), 2), sepColor, clNone);
    else
      paintChevron(sp, s, cdRight, size, sepColor);
    end;
  end;
  for var i := FFirstShown to FItems.Count-1 do begin
    if (i = FHot) and (i < FItems.Count-1) and hoverEnabled and Enabled then paintRoundRect(sp, rects[i], radius, hoverColor(back), clNone);
    if (i < FItems.Count-1) and drawn then shape(Rect(rects[i].Right, 0, rects[i+1].Left, ClientHeight));
  end;
  if (FFirstShown > 0) and drawn and (FItems.Count > 0) then shape(Rect(ellipsis.Right, 0, rects[FFirstShown].Left, ClientHeight));
  sp.Flush;
  var custom: array of boolean := [];
  SetLength(custom, FItems.Count);
  if Assigned(FOnDrawItem) then
    for var i := FFirstShown to FItems.Count-1 do begin
      var state: TDrawState := if i = FItems.Count-1 then [dsSelected] else [];
      if (i = FHot) and hoverEnabled then state += [dsHover];
      if not Enabled then state += [dsDisabled];
      FOnDrawItem(self, Canvas, rects[i], i, state, custom[i]);
    end;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var glyph := match FSeparator of
    bsSlash: '/';
    bsBackslash: '\';
    bsArrow: '>';
    bsPipe: '|';
  else
    ''
  end;
  if ellipsis.Width > 0 then begin
    paintCenteredText(Canvas, ellipsis, '...', text);
    if glyph <> '' then paintCenteredText(Canvas, Rect(ellipsis.Right, 0, rects[FFirstShown].Left, ClientHeight), glyph, sepColor);
  end;
  for var i := FFirstShown to FItems.Count-1 do begin
    var item := FItems[i];
    var r := rects[i];
    if custom[i] then continue;
    var x := r.Left+scaled(self, FPadding);
    if (FImages <> nil) and (item.ImageIndex >= 0) then begin
      var size := FImages.HeightForPPI[0, Font.PixelsPerInch];
      FImages.DrawForPPI(Canvas, x, (ClientHeight-size) div 2, item.ImageIndex, 0, Font.PixelsPerInch, GetCanvasScaleFactor, Enabled);
      x += FImages.WidthForPPI[0, Font.PixelsPerInch]+scaled(self, 4);
    end;
    var isLast := i = FItems.Count-1;
    Canvas.Font.Style := if isLast then Font.Style+[fsBold] else Font.Style;
    var color := if not Enabled then ColorToRGB(clGrayText) else if isLast then last else if (i = FHot) and hoverEnabled then ColorToRGB(clWindowText) else text;
    paintCenteredText(Canvas, Rect(x, 0, r.Right-scaled(self, FPadding), ClientHeight), item.Caption, color);
    if (glyph <> '') and not isLast then paintCenteredText(Canvas, Rect(r.Right, 0, rects[i+1].Left, ClientHeight), glyph, sepColor);
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TBreadcrumbBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  var hit := itemAt(X, Y);
  if hit = HOT_ELLIPSIS then begin
    // the hidden parts come up as a menu
    if FMenu = nil then FMenu := TPopupMenu.Create(self);
    FMenu.Items.Clear;
    for var i := 0 to FFirstShown-1 do begin
      var entry := TMenuItem.Create(FMenu);
      entry.Caption := FItems[i].Caption;
      entry.Tag := i;
      entry.OnClick := @menuClick;
      FMenu.Items.Add(entry);
    end;
    var p := ClientToScreen(Point(0, ClientHeight));
    FMenu.PopUp(p.X, p.Y);
  end else if (hit >= 0) and Assigned(FOnItemClick) then FOnItemClick(self, hit);
end;

procedure TBreadcrumbBar.menuClick(Sender: TObject);
begin
  if Assigned(FOnItemClick) then FOnItemClick(self, TMenuItem(Sender).Tag);
end;

procedure TBreadcrumbBar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  setHot(itemAt(X, Y));
end;

procedure TBreadcrumbBar.MouseLeave;
begin
  inherited MouseLeave;
  setHot(HOT_NONE);
end;

procedure TBreadcrumbBar.setHot(value: integer);
begin
  if FHot = value then exit;
  FHot := value;
  Hint := if value >= 0 then FItems[value].Hint else '';
  Cursor := if (value >= 0) and (value < FItems.Count-1) or (value = HOT_ELLIPSIS) then crHandPoint else crDefault;
  Invalidate;
end;

procedure TBreadcrumbBar.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then begin
    FImages := nil;
    Invalidate;
  end;
end;

procedure TBreadcrumbBar.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TBreadcrumbBar.itemsChanged;
begin
  if FHot >= FItems.Count then FHot := HOT_NONE;
  Invalidate;
end;

procedure TBreadcrumbBar.TruncateTo(index: integer);
begin
  while FItems.Count > index+1 do FItems.Delete(FItems.Count-1);
end;

// -- properties ----------------------

function TBreadcrumbBar.getPath: string;
begin
  result := '';
  for var i := 0 to FItems.Count-1 do result += (if i > 0 then '/' else '')+FItems[i].Caption;
end;

procedure TBreadcrumbBar.setPath(const value: string);
begin
  FItems.BeginUpdate;
  try
    FItems.Clear;
    for var part in value.Split(['/', '\'], TStringSplitOptions.ExcludeEmpty) do FItems.AddItem(part);
  finally
    FItems.EndUpdate;
  end;
end;

procedure TBreadcrumbBar.setItems(value: TBreadcrumbItems);
begin
  FItems.Assign(value);
end;

procedure TBreadcrumbBar.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TBreadcrumbBar.setSeparator(value: TBreadcrumbSeparator);
begin
  if FSeparator = value then exit;
  FSeparator := value;
  Invalidate;
end;

function TBreadcrumbBar.getMetric(index: integer): integer;
begin
  result := match index of
    0: FSpacing;
    1: FPadding;
  else
    FCornerRadius
  end;
end;

procedure TBreadcrumbBar.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FSpacing := value;
    1: FPadding := value;
  else
    FCornerRadius := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TBreadcrumbBar.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FTextColor;
    1: FLastColor;
  else
    FSeparatorColor
  end;
end;

procedure TBreadcrumbBar.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FTextColor := value;
    1: FLastColor := value;
  else
    FSeparatorColor := value;
  end;
  Invalidate;
end;

procedure TBreadcrumbBar.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
