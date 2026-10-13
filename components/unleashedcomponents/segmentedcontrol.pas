{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SegmentedControl;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ImgList, LCLType, ControlPaint;

type
  TSegmentedControl = class;

  { TSegmentItem }

  TSegmentItem = class(TCollectionItem)
  private
    FCaption: string;
    FImageIndex: TImageIndex;
    FEnabled, FVisible: boolean;
    FWidth: integer;
    FHint: string;
    FTag: PtrInt;
    procedure setCaption(const value: string);
    procedure setImageIndex(value: TImageIndex);
    procedure setEnabled(value: boolean);
    procedure setVisible(value: boolean);
    procedure setWidth(value: integer);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // the segment is the selected one
    function Selected: boolean;
  published
    property Caption: string read FCaption write setCaption;
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    property Enabled: boolean read FEnabled write setEnabled default true;
    property Visible: boolean read FVisible write setVisible default true;
    // 0 shares the width with the other segments
    property Width: integer read FWidth write setWidth default 0;
    property Hint: string read FHint write FHint;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TSegmentItems }

  TSegmentItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TSegmentItem;
    procedure setItem(index: integer; value: TSegmentItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(owner: TSegmentedControl);
    function Add: TSegmentItem;
    function AddCaption(const caption: string; imageIndex: TImageIndex=-1): TSegmentItem;
    property Items[index: integer]: TSegmentItem read getItem write setItem; default;
  end;

  TSegmentRects = array of TRect;
  // the bar: rounded corners, a pill, square corners, an underline under the
  // choice, a frame only, flat with a tint under the choice
  TSegmentShape = (ssRounded, ssPill, ssSquare, ssUnderline, ssOutline, ssFlat);
  TSegmentChangeEvent = procedure(Sender: TObject; index: integer) of object;

  { TSegmentedControl }

  // a row of segments with one selected, a radio group drawn as one bar.
  // The arrow keys move the selection, Home and End jump to the ends
  TSegmentedControl = class(TCustomControl)
  private
    FItems: TSegmentItems;
    FItemIndex: integer;
    FImages: TCustomImageList;
    FImageWidth: integer;
    FShape: TSegmentShape;
    FCornerRadius, FPadding, FSpacing, FSeparatorWidth: integer;
    FAllowNone, FShowSeparators, FFlat, FEqualWidths: boolean;
    FSelectedColor, FSelectedTextColor, FBarColor, FBorderColor: TColor;
    FHot, FPressed: integer;
    FOnChange: TSegmentChangeEvent;
    FOnSegmentClick: TSegmentChangeEvent;
    procedure setItems(value: TSegmentItems);
    procedure setItemIndex(value: integer);
    procedure setImages(value: TCustomImageList);
    procedure setImageWidth(value: integer);
    procedure setShape(value: TSegmentShape);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setHot(value: integer);
    function imageSize: TSize;
    function contentWidth(item: TSegmentItem): integer;
    // the box of each visible segment; an invisible one gets an empty rect
    function segmentRects: TSegmentRects;
    function segmentAt(x, y: integer): integer;
    function cornerPx: integer;
    procedure itemsChanged;
    procedure select(index: integer; byUser: boolean);
    function nextEnabled(from, step: integer): integer;
  private
    FAntialiasing: TAntialiasSetting;
    FOnDrawSegment: TCustomDrawEvent;
    procedure setAntialiasing(value: TAntialiasSetting);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the selected item, nil with nothing selected
    function SelectedItem: TSegmentItem;
    // the box of a segment, for a popup placed under it
    function SegmentRect(index: integer): TRect;
  published
    property Items: TSegmentItems read FItems write setItems;
    property ItemIndex: integer read FItemIndex write setItemIndex default 0;
    property Images: TCustomImageList read FImages write setImages;
    // the images at 96 dpi; 0 takes the size of the list
    property ImageWidth: integer read FImageWidth write setImageWidth default 0;
    property Shape: TSegmentShape read FShape write setShape default ssRounded;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    // inside each segment, around the content
    property Padding: integer index 1 read getMetric write setMetric default 10;
    // between an image and its caption
    property Spacing: integer index 2 read getMetric write setMetric default 4;
    property SeparatorWidth: integer index 3 read getMetric write setMetric default 1;
    // a click on the selected segment clears the selection
    property AllowNoSelection: boolean index 0 read getFlag write setFlag default false;
    property ShowSeparators: boolean index 1 read getFlag write setFlag default true;
    // no bar behind the segments, only the selected one shows a face
    property Flat: boolean index 2 read getFlag write setFlag default false;
    // every segment as wide as the widest one; off, each fits its content
    property EqualWidths: boolean index 3 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property SelectedColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property SelectedTextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BarColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    // after the selection moved, by the user or by code
    property OnChange: TSegmentChangeEvent read FOnChange write FOnChange;
    // a segment was clicked, selected already or not
    property OnSegmentClick: TSegmentChangeEvent read FOnSegmentClick write FOnSegmentClick;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over the stock segment: dsSelected for the chosen one, dsHover
    // under the mouse; `handled` true leaves the caption and the icon out
    property OnDrawSegment: TCustomDrawEvent read FOnDrawSegment write FOnDrawSegment;
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

{ TSegmentItem }

constructor TSegmentItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FImageIndex := -1;
  FEnabled := true;
  FVisible := true;
end;

procedure TSegmentItem.Assign(Source: TPersistent);
begin
  if Source is TSegmentItem then begin
    var src := TSegmentItem(Source);
    FCaption := src.FCaption;
    FImageIndex := src.FImageIndex;
    FEnabled := src.FEnabled;
    FVisible := src.FVisible;
    FWidth := src.FWidth;
    FHint := src.FHint;
    FTag := src.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TSegmentItem.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

function TSegmentItem.Selected: boolean;
begin
  result := (Collection is TSegmentItems) and (TSegmentedControl(TSegmentItems(Collection).Owner).ItemIndex = Index);
end;

procedure TSegmentItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TSegmentItem.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Changed(false);
end;

procedure TSegmentItem.setEnabled(value: boolean);
begin
  if FEnabled = value then exit;
  FEnabled := value;
  Changed(false);
end;

procedure TSegmentItem.setVisible(value: boolean);
begin
  if FVisible = value then exit;
  FVisible := value;
  Changed(false);
end;

procedure TSegmentItem.setWidth(value: integer);
begin
  if value < 0 then value := 0;
  if FWidth = value then exit;
  FWidth := value;
  Changed(false);
end;

{ TSegmentItems }

constructor TSegmentItems.Create(owner: TSegmentedControl);
begin
  inherited Create(owner, TSegmentItem);
end;

function TSegmentItems.getItem(index: integer): TSegmentItem;
begin
  result := TSegmentItem(inherited Items[index]);
end;

procedure TSegmentItems.setItem(index: integer; value: TSegmentItem);
begin
  inherited Items[index] := value;
end;

function TSegmentItems.Add: TSegmentItem;
begin
  result := TSegmentItem(inherited Add);
end;

function TSegmentItems.AddCaption(const caption: string; imageIndex: TImageIndex): TSegmentItem;
begin
  result := Add;
  result.FCaption := caption;
  result.FImageIndex := imageIndex;
  result.Changed(false);
end;

procedure TSegmentItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TSegmentedControl then TSegmentedControl(Owner).itemsChanged;
end;

{ TSegmentedControl }

constructor TSegmentedControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FItems := TSegmentItems.Create(self);
  FShape := ssRounded;
  FCornerRadius := 4;
  FPadding := 10;
  FSpacing := 4;
  FSeparatorWidth := 1;
  FShowSeparators := true;
  FEqualWidths := true;
  FSelectedColor := clDefault;
  FSelectedTextColor := clDefault;
  FBarColor := clDefault;
  FBorderColor := clDefault;
  FHot := -1;
  FPressed := -1;
  TabStop := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TSegmentedControl.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

class function TSegmentedControl.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 26;
end;

procedure TSegmentedControl.Loaded;
begin
  inherited Loaded;
  if FItemIndex >= FItems.Count then FItemIndex := FItems.Count-1;
end;

// -- geometry ----------------------

function TSegmentedControl.imageSize: TSize;
begin
  result := Size(0, 0);
  if FImages = nil then exit;
  result := FImages.SizeForPPI[FImageWidth, Font.PixelsPerInch];
end;

function TSegmentedControl.contentWidth(item: TSegmentItem): integer;
begin
  var img := if (FImages <> nil) and (item.ImageIndex >= 0) then imageSize.cx else 0;
  var tw := if item.Caption = '' then 0 else Canvas.TextWidth(item.Caption);
  result := img+tw;
  if (img > 0) and (tw > 0) then result += scaled(self, FSpacing);
  result += scaled(self, FPadding)*2;
end;

function TSegmentedControl.segmentRects: TSegmentRects;
begin
  result := nil;
  SetLength(result, FItems.Count);
  var widths: array of integer;
  SetLength(widths, FItems.Count);
  var visible := 0;
  var widest := 0;
  var fixed := 0;
  for var i := 0 to FItems.Count-1 do begin
    widths[i] := 0;
    if not FItems[i].Visible then continue;
    inc(visible);
    if FItems[i].Width > 0 then begin
      widths[i] := scaled(self, FItems[i].Width);
      fixed += widths[i];
    end else begin
      widths[i] := contentWidth(FItems[i]);
      widest := Max(widest, widths[i]);
    end;
  end;
  if visible = 0 then exit;
  var sep := if FShowSeparators and not FFlat then scaled(self, FSeparatorWidth) else 0;
  var flexible := 0;
  for var i := 0 to FItems.Count-1 do if FItems[i].Visible and (FItems[i].Width = 0) then inc(flexible);
  // the flexible segments share the width left by the fixed ones; with
  // EqualWidths each gets the same share, otherwise its content plus an
  // equal part of the slack
  var room := ClientWidth-fixed-sep*(visible-1);
  var natural := 0;
  for var i := 0 to FItems.Count-1 do if FItems[i].Visible and (FItems[i].Width = 0) then natural += (if FEqualWidths then widest else widths[i]);
  var slack := if flexible > 0 then Max(room-natural, 0) div flexible else 0;
  // less room than the content wants: the flexible segments shrink alike
  var squeeze := (flexible > 0) and (room < natural);
  var x := 0;
  var last := -1;
  for var i := 0 to FItems.Count-1 do begin
    if not FItems[i].Visible then begin
      result[i] := Rect(0, 0, 0, 0);
      continue;
    end;
    var w := widths[i];
    if FItems[i].Width = 0 then
      w := if squeeze then Max(MulDiv((if FEqualWidths then widest else widths[i]), room, natural), scaled(self, FPadding)*2)
      else (if FEqualWidths then widest else widths[i])+slack;
    result[i] := Rect(x, 0, x+w, ClientHeight);
    x += w+sep;
    last := i;
  end;
  // rounding leftovers go to the last segment so the bar ends at the edge
  if (last >= 0) and (flexible > 0) then result[last].Right := ClientWidth;
end;

function TSegmentedControl.SegmentRect(index: integer): TRect;
begin
  result := Rect(0, 0, 0, 0);
  if (index < 0) or (index >= FItems.Count) then exit;
  result := segmentRects[index];
end;

function TSegmentedControl.segmentAt(x, y: integer): integer;
begin
  result := -1;
  var rects := segmentRects;
  for var i := 0 to high(rects) do if FItems[i].Visible and rects[i].Contains(Point(x, y)) then exit(i);
end;

function TSegmentedControl.cornerPx: integer;
begin
  result := match FShape of
    ssPill: ClientHeight div 2;
    ssSquare: 0;
  else
    scaled(self, FCornerRadius)
  end;
end;

procedure TSegmentedControl.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var w := 0;
  var widest := 0;
  var visible := 0;
  for var i := 0 to FItems.Count-1 do if FItems[i].Visible then begin
    inc(visible);
    if FItems[i].Width > 0 then w += scaled(self, FItems[i].Width)
    else begin
      var cw := contentWidth(FItems[i]);
      if FEqualWidths then widest := Max(widest, cw) else w += cw;
    end;
  end;
  if FEqualWidths then for var i := 0 to FItems.Count-1 do if FItems[i].Visible and (FItems[i].Width = 0) then w += widest;
  var sep := if FShowSeparators and not FFlat then scaled(self, FSeparatorWidth) else 0;
  PreferredWidth := w+sep*Max(visible-1, 0)+2;
  PreferredHeight := Max(Canvas.TextHeight('Hg'), imageSize.cy)+scaled(self, 8);
end;

// -- painting ----------------------

procedure TSegmentedControl.Paint;
begin
  var bar := pick(FBarColor, blend(clBtnFace, clBtnShadow, 25));
  var border := pick(FBorderColor, clBtnShadow);
  var selected := pick(FSelectedColor, clHighlight);
  // the shapes that mark the choice without filling it color its text instead
  var marked := FShape in [ssUnderline, ssOutline, ssFlat];
  var selectedText := pick(FSelectedTextColor, (if marked then selected else contrastText(selected)));
  var text := ColorToRGB(clBtnText);
  if not Enabled then begin
    selected := blend(selected, clBtnFace, 50);
    text := ColorToRGB(clGrayText);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var radius := cornerPx;
  if Focused and ringEnabled then border := ringColor;
  if FShape = ssOutline then paintRoundRect(sp, ClientRect, radius, clNone, border)
  else if (FShape <> ssUnderline) and (FShape <> ssFlat) and not FFlat then paintRoundRect(sp, ClientRect, radius, bar, border)
  else if Focused and ringEnabled then paintRoundRect(sp, ClientRect, radius, clNone, border);
  var rects := segmentRects;
  var img := imageSize;
  var sepColor := blend(border, bar, 30);
  var lastVisible := -1;
  for var i := 0 to high(rects) do if FItems[i].Visible then lastVisible := i;
  for var i := 0 to high(rects) do begin
    var item := FItems[i];
    if not item.Visible then continue;
    var r := rects[i];
    var inner := r;
    inner.Inflate(-scaled(self, 2), -scaled(self, 2));
    var isSelected := i = FItemIndex;
    var itemEnabled := Enabled and item.Enabled;
    var hot := itemEnabled and hoverEnabled and (i = FHot);
    if isSelected then
      match FShape of
        ssUnderline: paintRoundRect(sp, Rect(inner.Left, r.Bottom-scaled(self, 3), inner.Right, r.Bottom), 1, selected, clNone);
        ssOutline: paintRoundRect(sp, inner, Max(radius-scaled(self, 2), 0), blend(bar, selected, 18), selected);
        ssFlat: paintRoundRect(sp, inner, Max(radius-scaled(self, 2), 0), blend(bar, selected, 22), clNone);
      else
        paintRoundRect(sp, inner, Max(radius-scaled(self, 2), 0), selected, clNone);
      end
    else if hot or (i = FPressed) then paintRoundRect(sp, inner, Max(radius-scaled(self, 2), 0), (if i = FPressed then blend(hoverColor(bar), clWindowText, 10) else hoverColor(bar)), clNone);
    if FShowSeparators and not FFlat and not marked and (i <> lastVisible) and not isSelected then begin
      var next := nextEnabled(i, 1);
      if (next <> FItemIndex) or (next < 0) then begin
        var sx := r.Right+scaled(self, FSeparatorWidth) div 2;
        paintLine(sp, sx, r.Top+scaled(self, 5), sx, r.Bottom-scaled(self, 5), sepColor, Max(scaled(self, FSeparatorWidth), 1));
      end;
    end;
  end;
  sp.Flush;

  var custom: array of boolean := [];
  SetLength(custom, length(rects));
  if Assigned(FOnDrawSegment) then
    for var i := 0 to high(rects) do begin
      if not FItems[i].Visible then continue;
      var state: TDrawState := if i = FItemIndex then [dsSelected] else [];
      if (i = FHot) and hoverEnabled then state += [dsHover];
      if i = FPressed then state += [dsPressed];
      if not (Enabled and FItems[i].Enabled) then state += [dsDisabled];
      FOnDrawSegment(self, Canvas, rects[i], i, state, custom[i]);
    end;

  // the content centers in each segment
  applyTextQuality(Canvas);
  for var i := 0 to high(rects) do begin
    var item := FItems[i];
    if not item.Visible or custom[i] then continue;
    var r := rects[i];
    var isSelected := i = FItemIndex;
    var itemEnabled := Enabled and item.Enabled;
    var hasImg := (FImages <> nil) and (item.ImageIndex >= 0) and (item.ImageIndex < FImages.Count);
    var tw := if item.Caption = '' then 0 else Canvas.TextWidth(item.Caption);
    var th := Canvas.TextHeight('Hg');
    var gap := if hasImg and (tw > 0) then scaled(self, FSpacing) else 0;
    // a caption wider than its segment ends in an ellipsis
    var avail := r.Width-scaled(self, FPadding)*2-(if hasImg then img.cx+gap else 0);
    if tw > avail then tw := Max(avail, 0);
    var cw := (if hasImg then img.cx else 0)+gap+tw;
    var x := r.Left+(r.Width-cw) div 2;
    if hasImg then begin
      FImages.DrawForPPI(Canvas, x, r.Top+(r.Height-img.cy) div 2, item.ImageIndex, FImageWidth, Font.PixelsPerInch, GetCanvasScaleFactor, itemEnabled);
      x += img.cx+gap;
    end;
    if tw > 0 then begin
      var style := Canvas.TextStyle;
      style.Alignment := taLeftJustify;
      style.Layout := tlTop;
      style.SingleLine := true;
      style.Clipping := true;
      style.EndEllipsis := true;
      style.Opaque := false;
      style.ShowPrefix := false;
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := if not itemEnabled then ColorToRGB(clGrayText) else if isSelected then selectedText else text;
      Canvas.TextRect(Rect(x, r.Top, x+tw, r.Bottom), x, r.Top+(r.Height-th) div 2, item.Caption, style);
      Canvas.Brush.Style := bsSolid;
    end;
  end;
end;

// -- input ----------------------

function TSegmentedControl.nextEnabled(from, step: integer): integer;
begin
  result := -1;
  var i := from+step;
  while (i >= 0) and (i < FItems.Count) do begin
    if FItems[i].Visible and FItems[i].Enabled then exit(i);
    i += step;
  end;
end;

procedure TSegmentedControl.setHot(value: integer);
begin
  if FHot = value then exit;
  FHot := value;
  if (value >= 0) and (FItems[value].Hint <> '') then Hint := FItems[value].Hint;
  Invalidate;
end;

procedure TSegmentedControl.select(index: integer; byUser: boolean);
begin
  if byUser and Assigned(FOnSegmentClick) and (index >= 0) then FOnSegmentClick(self, index);
  if byUser and (index = FItemIndex) then begin
    if not FAllowNone then exit;
    index := -1;
  end;
  if FItemIndex = index then exit;
  FItemIndex := index;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self, FItemIndex);
end;

procedure TSegmentedControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  var i := segmentAt(X, Y);
  if (i < 0) or not FItems[i].Enabled then exit;
  FPressed := i;
  Invalidate;
end;

procedure TSegmentedControl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  setHot(segmentAt(X, Y));
end;

procedure TSegmentedControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FPressed < 0) then exit;
  var i := segmentAt(X, Y);
  var pressed := FPressed;
  FPressed := -1;
  Invalidate;
  if (i = pressed) and FItems[i].Enabled then select(i, true);
end;

procedure TSegmentedControl.MouseLeave;
begin
  inherited MouseLeave;
  FPressed := -1;
  setHot(-1);
end;

procedure TSegmentedControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not Enabled then exit;
  var target := -1;
  match Key of
    VK_LEFT, VK_UP: target := nextEnabled(if FItemIndex < 0 then FItems.Count else FItemIndex, -1);
    VK_RIGHT, VK_DOWN: target := nextEnabled(FItemIndex, 1);
    VK_HOME: target := nextEnabled(-1, 1);
    VK_END: target := nextEnabled(FItems.Count, -1);
    VK_SPACE, VK_RETURN: if FItemIndex >= 0 then begin
      if Assigned(FOnSegmentClick) then FOnSegmentClick(self, FItemIndex);
      Key := 0;
      exit;
    end;
  else
    exit;
  end;
  Key := 0;
  if target >= 0 then select(target, false);
end;

procedure TSegmentedControl.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TSegmentedControl.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TSegmentedControl.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  itemsChanged;
end;

procedure TSegmentedControl.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then begin
    FImages := nil;
    itemsChanged;
  end;
end;

procedure TSegmentedControl.itemsChanged;
begin
  if csDestroying in ComponentState then exit;
  if FItemIndex >= FItems.Count then FItemIndex := FItems.Count-1;
  FHot := -1;
  FPressed := -1;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TSegmentedControl.SelectedItem: TSegmentItem;
begin
  result := if (FItemIndex >= 0) and (FItemIndex < FItems.Count) then FItems[FItemIndex] else nil;
end;

// -- properties ----------------------

procedure TSegmentedControl.setItems(value: TSegmentItems);
begin
  FItems.Assign(value);
end;

procedure TSegmentedControl.setItemIndex(value: integer);
begin
  if value < -1 then value := -1;
  if not (csLoading in ComponentState) and (value >= FItems.Count) then value := FItems.Count-1;
  select(value, false);
end;

procedure TSegmentedControl.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  itemsChanged;
end;

procedure TSegmentedControl.setImageWidth(value: integer);
begin
  if value < 0 then value := 0;
  if FImageWidth = value then exit;
  FImageWidth := value;
  itemsChanged;
end;

procedure TSegmentedControl.setShape(value: TSegmentShape);
begin
  if FShape = value then exit;
  FShape := value;
  Invalidate;
end;

function TSegmentedControl.getMetric(index: integer): integer;
begin
  match index of
    0: result := FCornerRadius;
    1: result := FPadding;
    2: result := FSpacing;
    _: result := FSeparatorWidth;
  end;
end;

procedure TSegmentedControl.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FCornerRadius := value;
    1: FPadding := value;
    2: FSpacing := value;
    _: FSeparatorWidth := value;
  end;
  itemsChanged;
end;

function TSegmentedControl.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FAllowNone;
    1: result := FShowSeparators;
    2: result := FFlat;
    _: result := FEqualWidths;
  end;
end;

procedure TSegmentedControl.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAllowNone := value;
    1: FShowSeparators := value;
    2: FFlat := value;
    _: FEqualWidths := value;
  end;
  itemsChanged;
end;

function TSegmentedControl.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FSelectedColor;
    1: result := FSelectedTextColor;
    2: result := FBarColor;
    _: result := FBorderColor;
  end;
end;

procedure TSegmentedControl.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FSelectedColor := value;
    1: FSelectedTextColor := value;
    2: FBarColor := value;
    _: FBorderColor := value;
  end;
  Invalidate;
end;

procedure TSegmentedControl.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
