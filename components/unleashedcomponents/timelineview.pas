{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit TimelineView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ImgList, LCLType, LMessages, ControlPaint;

type
  TTimelineView = class;

  { TTimelineItem }

  // an event on the line: a time, a title, a text under it
  TTimelineItem = class(TCollectionItem)
  private
    FTime: TDateTime;
    FCaption, FDescription: string;
    FColor: TColor;
    FImageIndex: integer;
    FTag: PtrInt;
    procedure setTime(value: TDateTime);
    procedure setCaption(const value: string);
    procedure setDescription(const value: string);
    procedure setColor(value: TColor);
    procedure setImageIndex(value: integer);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Time: TDateTime read FTime write setTime;
    property Caption: string read FCaption write setCaption;
    property Description: string read FDescription write setDescription;
    // the dot; clDefault takes the accent
    property Color: TColor read FColor write setColor default clDefault;
    property ImageIndex: integer read FImageIndex write setImageIndex default -1;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TTimelineItems }

  TTimelineItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TTimelineItem;
    procedure setItem(index: integer; value: TTimelineItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(owner: TTimelineView);
    function Add: TTimelineItem;
    function AddItem(time: TDateTime; const caption, description: string): TTimelineItem;
    property Items[index: integer]: TTimelineItem read getItem write setItem; default;
  end;

  // tlLeft keeps the line at the left with the text beside it; tlAlternate
  // puts the line in the middle and the entries left and right in turn
  TTimelineLayout = (tlLeft, tlAlternate);
  // the mark of an item on the line: a dot with a light middle, a ring, a
  // square, a diamond, or a circle with the number of the item
  TTimelineDotStyle = (tdDot, tdRing, tdSquare, tdDiamond, tdNumber);
  TTimelineItemEvent = procedure(Sender: TObject; item: TTimelineItem) of object;

  { TTimelineView }

  // events along a vertical line, each with a dot, a time, a title and a
  // description, newest first or last as sorted. Scrolls when they do not
  // fit; a click selects
  TTimelineView = class(TScrollingWinControl)
  private
    FItems: TTimelineItems;
    FImages: TCustomImageList;
    FLayout: TTimelineLayout;
    FSelected: integer;
    FShowTime, FSortNewestFirst, FShowDescription: boolean;
    FTimeFormat: string;
    FItemSpacing, FDotSize, FLineWidth, FPadding: integer;
    FLineColor, FTimeColor, FCaptionColor, FDescriptionColor, FSelectedColor: TColor;
    FOrder: array of integer; // item indexes in display order
    FTops: array of integer; // top of each entry in the order, plus the end
    FAntialiasing: TAntialiasSetting;
    FOnDrawDot: TCustomDrawEvent;
    FDotStyle: TTimelineDotStyle;
    FLanguage: TFormatLanguage;
    FOnItemClick, FOnSelectionChange: TTimelineItemEvent;
    procedure setItems(value: TTimelineItems);
    procedure setImages(value: TCustomImageList);
    procedure setLayout(value: TTimelineLayout);
    procedure setSelected(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setTimeFormat(const value: string);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setDotStyle(value: TTimelineDotStyle);
    procedure setLanguage(value: TFormatLanguage);
    procedure itemsChanged;
    procedure measure;
    function entryHeight(item: TTimelineItem; textWidth: integer): integer;
    function textWidthFor: integer;
    function lineX: integer;
    function entryAt(y: integer): integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoOnResize; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure FontChanged(Sender: TObject); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure WMVScroll(var Message: TLMVScroll); message LM_VSCROLL;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function SelectedItem: TTimelineItem;
    procedure ScrollToItem(index: integer);
  published
    property Items: TTimelineItems read FItems write setItems;
    property Images: TCustomImageList read FImages write setImages;
    property Layout: TTimelineLayout read FLayout write setLayout default tlLeft;
    property SelectedIndex: integer read FSelected write setSelected default -1;
    property ShowTime: boolean index 0 read getFlag write setFlag default true;
    property SortNewestFirst: boolean index 1 read getFlag write setFlag default false;
    property ShowDescription: boolean index 2 read getFlag write setFlag default true;
    // a FormatDateTime pattern
    property TimeFormat: string read FTimeFormat write setTimeFormat;
    property ItemSpacing: integer index 0 read getMetric write setMetric default 12;
    property DotSize: integer index 1 read getMetric write setMetric default 12;
    property LineWidth: integer index 2 read getMetric write setMetric default 2;
    property Padding: integer index 3 read getMetric write setMetric default 8;
    // clDefault takes the colors of the theme
    property LineColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TimeColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property CaptionColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property DescriptionColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property SelectedColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over the mark of an item, in the square of DotSize: index is the
    // item, dsSelected for the selected one
    property OnDrawDot: TCustomDrawEvent read FOnDrawDot write FOnDrawDot;
    property DotStyle: TTimelineDotStyle read FDotStyle write setDotStyle default tdDot;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnItemClick: TTimelineItemEvent read FOnItemClick write FOnItemClick;
    property OnSelectionChange: TTimelineItemEvent read FOnSelectionChange write FOnSelectionChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsNone;
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
    property OnMouseWheel;
    property OnResize;
  end;

implementation

uses
  Math;

{ TTimelineItem }

constructor TTimelineItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clDefault;
  FImageIndex := -1;
  FTime := Now;
end;

procedure TTimelineItem.Assign(Source: TPersistent);
begin
  if Source is TTimelineItem then begin
    var src := TTimelineItem(Source);
    FTime := src.FTime;
    FCaption := src.FCaption;
    FDescription := src.FDescription;
    FColor := src.FColor;
    FImageIndex := src.FImageIndex;
    FTag := src.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TTimelineItem.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TTimelineItem.setTime(value: TDateTime);
begin
  if FTime = value then exit;
  FTime := value;
  Changed(false);
end;

procedure TTimelineItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TTimelineItem.setDescription(const value: string);
begin
  if FDescription = value then exit;
  FDescription := value;
  Changed(false);
end;

procedure TTimelineItem.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TTimelineItem.setImageIndex(value: integer);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Changed(false);
end;

{ TTimelineItems }

constructor TTimelineItems.Create(owner: TTimelineView);
begin
  inherited Create(owner, TTimelineItem);
end;

function TTimelineItems.getItem(index: integer): TTimelineItem;
begin
  result := TTimelineItem(inherited Items[index]);
end;

procedure TTimelineItems.setItem(index: integer; value: TTimelineItem);
begin
  inherited Items[index] := value;
end;

function TTimelineItems.Add: TTimelineItem;
begin
  result := TTimelineItem(inherited Add);
end;

function TTimelineItems.AddItem(time: TDateTime; const caption, description: string): TTimelineItem;
begin
  result := Add;
  result.FTime := time;
  result.FCaption := caption;
  result.FDescription := description;
  result.Changed(false);
end;

procedure TTimelineItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TTimelineView then TTimelineView(Owner).itemsChanged;
end;

{ TTimelineView }

constructor TTimelineView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FItems := TTimelineItems.Create(self);
  FLayout := tlLeft;
  FSelected := -1;
  FShowTime := true;
  FShowDescription := true;
  FTimeFormat := 'yyyy-mm-dd hh:nn';
  FItemSpacing := 12;
  FDotSize := 12;
  FLineWidth := 2;
  FPadding := 8;
  FLineColor := clDefault;
  FTimeColor := clDefault;
  FCaptionColor := clDefault;
  FDescriptionColor := clDefault;
  FSelectedColor := clDefault;
  BorderStyle := bsNone;
  TabStop := true;
  DoubleBuffered := true;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Visible := false;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TTimelineView.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

class function TTimelineView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 260;
  result.cy := 200;
end;

procedure TTimelineView.Loaded;
begin
  inherited Loaded;
  itemsChanged;
end;

// -- layout ----------------------

function TTimelineView.lineX: integer;
begin
  result := if FLayout = tlAlternate then ClientWidth div 2 else scaled(self, FPadding)+scaled(self, FDotSize) div 2;
end;

function TTimelineView.textWidthFor: integer;
begin
  var pad := scaled(self, FPadding);
  var dot := scaled(self, FDotSize);
  result := if FLayout = tlAlternate then ClientWidth div 2-dot-pad*2 else ClientWidth-pad*2-dot-scaled(self, 8);
  result := Max(result, 40);
end;

function TTimelineView.entryHeight(item: TTimelineItem; textWidth: integer): integer;
begin
  var lineH := Canvas.TextHeight('Hg');
  result := 0;
  if FShowTime then result += lineH;
  if item.Caption <> '' then result += lineH;
  if FShowDescription and (item.Description <> '') then begin
    var style := Canvas.TextStyle;
    style.Wordbreak := true;
    style.SingleLine := false;
    var r := Rect(0, 0, textWidth, 10000);
    var box := r;
    Canvas.TextRect(box, 0, 0, item.Description, style);
    // the text height comes from a dry measure of the wrapped lines
    var lines := 1;
    var w := 0;
    for var word in item.Description.Split([' ']) do begin
      var ww := Canvas.TextWidth(word+' ');
      if (w > 0) and (w+ww > textWidth) then begin
        inc(lines);
        w := 0;
      end;
      w += ww;
    end;
    result += lines*lineH;
  end;
  result := Max(result, scaled(self, FDotSize));
end;

procedure TTimelineView.measure;
begin
  SetLength(FOrder, FItems.Count);
  for var i := 0 to FItems.Count-1 do FOrder[i] := i;
  // sorted by time, the ties in the order they were added
  for var i := 1 to high(FOrder) do begin
    var k := FOrder[i];
    var j := i-1;
    while (j >= 0) and ((FItems[FOrder[j]].Time > FItems[k].Time) xor FSortNewestFirst) and (FItems[FOrder[j]].Time <> FItems[k].Time) do begin
      FOrder[j+1] := FOrder[j];
      dec(j);
    end;
    FOrder[j+1] := k;
  end;
  SetLength(FTops, FItems.Count+1);
  var y := scaled(self, FPadding);
  var tw := textWidthFor;
  var gap := scaled(self, FItemSpacing);
  for var i := 0 to high(FOrder) do begin
    FTops[i] := y;
    y += entryHeight(FItems[FOrder[i]], tw)+gap;
  end;
  FTops[FItems.Count] := y;
  if HandleAllocated then begin
    VertScrollBar.Increment := Canvas.TextHeight('Hg');
    VertScrollBar.Page := Max(ClientHeight, 1);
    VertScrollBar.Range := y;
  end;
end;

function TTimelineView.entryAt(y: integer): integer;
begin
  result := -1;
  var ay := y+VertScrollBar.Position;
  for var i := 0 to high(FOrder) do if (ay >= FTops[i]) and (ay < FTops[i+1]) then exit(FOrder[i]);
end;

// -- painting ----------------------

procedure TTimelineView.Paint;
begin
  var line := pick(FLineColor, blend(clBtnFace, clBtnShadow, 50));
  var timeColor := pick(FTimeColor, clGrayText);
  var captionColor := pick(FCaptionColor, clWindowText);
  var descColor := pick(FDescriptionColor, blend(clWindowText, clGrayText, 40));
  var selectedFill := pick(FSelectedColor, blend(GetRGBColorResolvingParent, clHighlight, 25));
  measure;
  // the canvas origin already sits at the scroll position, so everything
  // paints in unscrolled coordinates and the view is the visible part
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, GetRGBColorResolvingParent, FAntialiasing);
  var lx := lineX;
  var dot := scaled(self, FDotSize);
  var pad := scaled(self, FPadding);
  if FItems.Count > 0 then paintLine(sp, lx, FTops[0]+dot div 2, lx, FTops[FItems.Count]-scaled(self, FItemSpacing)+dot div 2, line, FLineWidth);
  var tw := textWidthFor;
  for var i := 0 to high(FOrder) do begin
    var item := FItems[FOrder[i]];
    var top := FTops[i];
    var bottom := FTops[i+1]-scaled(self, FItemSpacing);
    if (bottom < view.Top) or (top > view.Bottom) then continue;
    var left := if (FLayout = tlAlternate) and (i mod 2 = 1) then lx-dot-pad-tw else (if FLayout = tlAlternate then lx+dot+pad else lx+dot div 2+scaled(self, 8));
    if FOrder[i] = FSelected then paintRoundRect(sp, Rect(left-scaled(self, 4), top-scaled(self, 2), left+tw+scaled(self, 4), bottom+scaled(self, 2)), scaled(self, 4), selectedFill, clNone);
    var dotColor := pick(item.Color, clHighlight);
    var dy := top+dot div 2;
    match FDotStyle of
      tdRing: paintCircle(sp, lx, dy, dot div 2, GetRGBColorResolvingParent, dotColor, Max(scaled(self, 2), 2));
      tdSquare: paintRoundRect(sp, Rect(lx-dot div 2, dy-dot div 2, lx+dot div 2+1, dy+dot div 2+1), 1, dotColor, clNone);
      tdDiamond: sp.FillPolygon(polygonOutline(lx+0.5, dy+0.5, dot/2+1, 4, 90), dotColor);
      tdNumber: paintCircle(sp, lx, dy, dot div 2+scaled(self, 2), dotColor, clNone);
    else
      paintCircle(sp, lx, dy, dot div 2, dotColor, clNone);
      paintCircle(sp, lx, dy, Max(dot div 2-scaled(self, 3), 1), blend(dotColor, clWhite, 70), clNone);
    end;
  end;
  sp.Flush;
  if FDotStyle = tdNumber then begin
    applyTextQuality(Canvas);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Style := Font.Style+[fsBold];
    for var i := 0 to high(FOrder) do begin
      var dy := FTops[i]+dot div 2;
      if (dy < view.Top-dot) or (dy > view.Bottom+dot) then continue;
      var ring := dot div 2+scaled(self, 2);
      paintCenteredText(Canvas, Rect(lx-ring, dy-ring, lx+ring, dy+ring), IntToStr(i+1), contrastText(pick(FItems[FOrder[i]].Color, clHighlight)));
    end;
    Canvas.Font.Style := Font.Style;
  end;
  if Assigned(FOnDrawDot) then
    for var i := 0 to high(FOrder) do begin
      var dy := FTops[i]+dot div 2;
      if (dy < view.Top-dot) or (dy > view.Bottom+dot) then continue;
      var state: TDrawState := if FOrder[i] = FSelected then [dsSelected] else [];
      if not Enabled then state += [dsDisabled];
      var handled := false;
      FOnDrawDot(self, Canvas, Rect(lx-dot div 2, dy-dot div 2, lx+dot div 2+1, dy+dot div 2+1), FOrder[i], state, handled);
    end;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var lineH := Canvas.TextHeight('Hg');
  for var i := 0 to high(FOrder) do begin
    var item := FItems[FOrder[i]];
    var top := FTops[i];
    var bottom := FTops[i+1]-scaled(self, FItemSpacing);
    if (bottom < view.Top) or (top > view.Bottom) then continue;
    var rightSide := (FLayout <> tlAlternate) or (i mod 2 = 0);
    var left := if rightSide then (if FLayout = tlAlternate then lx+dot+pad else lx+dot div 2+scaled(self, 8)) else lx-dot-pad-tw;
    var y := top;
    var style := Canvas.TextStyle;
    style.Alignment := if rightSide then taLeftJustify else taRightJustify;
    style.Layout := tlTop;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    if FShowTime then begin
      Canvas.Font.Color := timeColor;
      Canvas.TextRect(Rect(left, y, left+tw, y+lineH), left, y, FormatDateTime(FTimeFormat, item.Time, formatSettingsOf(FLanguage)), style);
      y += lineH;
    end;
    if item.Caption <> '' then begin
      Canvas.Font.Style := Font.Style+[fsBold];
      Canvas.Font.Color := captionColor;
      Canvas.TextRect(Rect(left, y, left+tw, y+lineH), left, y, item.Caption, style);
      Canvas.Font.Style := Font.Style;
      y += lineH;
    end;
    if FShowDescription and (item.Description <> '') then begin
      Canvas.Font.Color := descColor;
      var wrapStyle := style;
      wrapStyle.SingleLine := false;
      wrapStyle.Wordbreak := true;
      Canvas.TextRect(Rect(left, y, left+tw, bottom), left, y, item.Description, wrapStyle);
    end;
    if (FImages <> nil) and (item.ImageIndex >= 0) then begin
      var size := FImages.SizeForPPI[0, Font.PixelsPerInch];
      FImages.DrawForPPI(Canvas, lx-size.cx div 2, top+dot+scaled(self, 4), item.ImageIndex, 0, Font.PixelsPerInch, GetCanvasScaleFactor, Enabled);
    end;
  end;
  Canvas.Brush.Style := bsSolid;
  if Focused and ringEnabled then begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := ringColor;
    Canvas.Rectangle(view);
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- input ----------------------

procedure TTimelineView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  var i := entryAt(Y);
  setSelected(i);
  if (i >= 0) and Assigned(FOnItemClick) then FOnItemClick(self, FItems[i]);
end;

procedure TTimelineView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FItems.Count = 0 then exit;
  // the keys walk the display order
  var pos := -1;
  for var i := 0 to high(FOrder) do if FOrder[i] = FSelected then pos := i;
  match Key of
    VK_UP: pos := Max(pos-1, 0);
    VK_DOWN: pos := Min(pos+1, high(FOrder));
    VK_HOME: pos := 0;
    VK_END: pos := high(FOrder);
  else
    exit;
  end;
  Key := 0;
  setSelected(FOrder[pos]);
  ScrollToItem(FOrder[pos]);
end;

procedure TTimelineView.ScrollToItem(index: integer);
begin
  measure;
  for var i := 0 to high(FOrder) do if FOrder[i] = index then begin
    var top := FTops[i]-scaled(self, FPadding);
    var bottom := FTops[i+1];
    if top < VertScrollBar.Position then VertScrollBar.Position := top
    else if bottom > VertScrollBar.Position+ClientHeight then VertScrollBar.Position := bottom-ClientHeight;
    Invalidate;
    exit;
  end;
end;

procedure TTimelineView.WMVScroll(var Message: TLMVScroll);
begin
  inherited WMVScroll(Message);
  Invalidate;
end;

procedure TTimelineView.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TTimelineView.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// a scroll repaints everything: shifting the pixels would carry the ring of
// the focus into the content
procedure TTimelineView.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TTimelineView.DoOnResize;
begin
  inherited DoOnResize;
  itemsChanged;
end;

procedure TTimelineView.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  itemsChanged;
end;

procedure TTimelineView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then begin
    FImages := nil;
    Invalidate;
  end;
end;

procedure TTimelineView.itemsChanged;
begin
  // the inherited constructor resizes before the items exist
  if (FItems = nil) or (csDestroying in ComponentState) then exit;
  if FSelected >= FItems.Count then FSelected := -1;
  if HandleAllocated then measure;
  Invalidate;
end;

function TTimelineView.SelectedItem: TTimelineItem;
begin
  result := if (FSelected >= 0) and (FSelected < FItems.Count) then FItems[FSelected] else nil;
end;

// -- properties ----------------------

procedure TTimelineView.setItems(value: TTimelineItems);
begin
  FItems.Assign(value);
end;

procedure TTimelineView.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  Invalidate;
end;

procedure TTimelineView.setLayout(value: TTimelineLayout);
begin
  if FLayout = value then exit;
  FLayout := value;
  itemsChanged;
end;

procedure TTimelineView.setSelected(value: integer);
begin
  if value >= FItems.Count then value := -1;
  if value < -1 then value := -1;
  if FSelected = value then exit;
  FSelected := value;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnSelectionChange) then FOnSelectionChange(self, SelectedItem);
end;

function TTimelineView.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FShowTime;
    1: result := FSortNewestFirst;
    _: result := FShowDescription;
  end;
end;

procedure TTimelineView.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowTime := value;
    1: FSortNewestFirst := value;
    _: FShowDescription := value;
  end;
  itemsChanged;
end;

procedure TTimelineView.setTimeFormat(const value: string);
begin
  if FTimeFormat = value then exit;
  FTimeFormat := value;
  Invalidate;
end;

function TTimelineView.getMetric(index: integer): integer;
begin
  match index of
    0: result := FItemSpacing;
    1: result := FDotSize;
    2: result := FLineWidth;
    _: result := FPadding;
  end;
end;

procedure TTimelineView.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FItemSpacing := value;
    1: FDotSize := Max(value, 4);
    2: FLineWidth := Max(value, 1);
    _: FPadding := value;
  end;
  itemsChanged;
end;

function TTimelineView.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FLineColor;
    1: result := FTimeColor;
    2: result := FCaptionColor;
    3: result := FDescriptionColor;
    _: result := FSelectedColor;
  end;
end;

procedure TTimelineView.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FLineColor := value;
    1: FTimeColor := value;
    2: FCaptionColor := value;
    3: FDescriptionColor := value;
    _: FSelectedColor := value;
  end;
  Invalidate;
end;

procedure TTimelineView.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TTimelineView.setDotStyle(value: TTimelineDotStyle);
begin
  if FDotStyle = value then exit;
  FDotStyle := value;
  Invalidate;
end;

procedure TTimelineView.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
