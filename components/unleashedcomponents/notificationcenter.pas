{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit NotificationCenter;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, LCLType, ControlPaint;

type
  TNotificationCenter = class;
  // the icon and the color bar of a notice; nkPlain carries neither
  TNoticeKind = (nkInfo, nkSuccess, nkWarning, nkError, nkPlain);
  TNoticeItem = class;
  TNoticeEvent = procedure(Sender: TObject; item: TNoticeItem) of object;
  // an item is about to go; allow false keeps it
  TNoticeDismissEvent = procedure(Sender: TObject; item: TNoticeItem; var allow: boolean) of object;

  { TNoticeItem }

  TNoticeItem = class(TCollectionItem)
  private
    FTitle, FText, FActionText: string;
    FKind: TNoticeKind;
    FTime: TDateTime;
    FUnread: boolean;
    FTag: PtrInt;
    FRect, FCloseRect, FActionRect: TRect;
    procedure setTitle(const value: string);
    procedure setText(const value: string);
    procedure setActionText(const value: string);
    procedure setKind(value: TNoticeKind);
    procedure setUnread(value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // when the item was added
    property Time: TDateTime read FTime write FTime;
  published
    property Title: string read FTitle write setTitle;
    property Text: string read FText write setText;
    // a link under the text that fires OnAction
    property ActionText: string read FActionText write setActionText;
    property Kind: TNoticeKind read FKind write setKind default nkInfo;
    property Unread: boolean read FUnread write setUnread default true;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TNoticeItems }

  TNoticeItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TNoticeItem;
    procedure setItem(index: integer; value: TNoticeItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TNoticeItem;
    property Items[index: integer]: TNoticeItem read getItem write setItem; default;
  end;

  { TNotificationCenter }

  // the list of what happened: a card per notification with a title, a
  // text, the time it came and a close cross, unread ones marked. Add
  // puts the newest on top, a click reads it, the count of unread ones
  // feeds a badge somewhere else
  TNotificationCenter = class(TScrollingWinControl)
  private
    FItems: TNoticeItems;
    FHot: TNoticeItem;
    FHotPart: integer; // 0 the card, 1 the cross, 2 the action
    FMaxItems, FPadding, FCornerRadius, FSpacing, FMaxLines: integer;
    FShowTime, FShowKindBar, FShowClose, FNewestFirst, FMarkReadOnClick, FShowEmptyText: boolean;
    FEmptyText: string;
    FBackColor, FCardColor, FUnreadColor, FBorderColor, FTitleColor, FTextColor, FTimeColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FTimer: TTimer;
    FOnItemClick, FOnAction, FOnDismissed: TNoticeEvent;
    FOnDismiss: TNoticeDismissEvent;
    FOnUnreadChange: TNotifyEvent;
    procedure setItems(value: TNoticeItems);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setEmptyText(const value: string);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function itemHeight(item: TNoticeItem; width: integer): integer;
    function itemAt(x, y: integer; out part: integer): TNoticeItem;
    function kindColor(kind: TNoticeKind): TColor;
    function timeText(time: TDateTime): string;
    procedure updateRange;
    procedure tick(Sender: TObject);
    procedure unreadChanged;
  protected
    procedure Paint; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Add(const title, text: string; kind: TNoticeKind = nkInfo; tag: PtrInt = 0): TNoticeItem;
    // removes an item with the dismiss events
    procedure Dismiss(item: TNoticeItem);
    procedure Clear;
    procedure ClearRead;
    procedure MarkAllRead;
    function UnreadCount: integer;
  published
    property Items: TNoticeItems read FItems write setItems;
    // the oldest go when there are more, 0 for no limit
    property MaxItems: integer index 0 read getMetric write setMetric default 100;
    property Padding: integer index 1 read getMetric write setMetric default 10;
    property CornerRadius: integer index 2 read getMetric write setMetric default 6;
    property Spacing: integer index 3 read getMetric write setMetric default 6;
    // the lines of text shown per item
    property MaxLines: integer index 4 read getMetric write setMetric default 3;
    // "5 min ago" in the corner, kept fresh
    property ShowTime: boolean index 0 read getFlag write setFlag default true;
    // a strip in the color of the kind on the left
    property ShowKindBar: boolean index 1 read getFlag write setFlag default true;
    property ShowClose: boolean index 2 read getFlag write setFlag default true;
    property NewestFirst: boolean index 3 read getFlag write setFlag default true;
    property MarkReadOnClick: boolean index 4 read getFlag write setFlag default true;
    property ShowEmptyText: boolean index 5 read getFlag write setFlag default true;
    property EmptyText: string read FEmptyText write setEmptyText;
    // clDefault takes the colors of the theme
    property BackColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property CardColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // the card of an unread item
    property UnreadColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property TimeColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnItemClick: TNoticeEvent read FOnItemClick write FOnItemClick;
    // the action link of an item
    property OnAction: TNoticeEvent read FOnAction write FOnAction;
    property OnDismiss: TNoticeDismissEvent read FOnDismiss write FOnDismiss;
    property OnDismissed: TNoticeEvent read FOnDismissed write FOnDismissed;
    property OnUnreadChange: TNotifyEvent read FOnUnreadChange write FOnUnreadChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsNone;
    property Color default clWindow;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default false;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnEnter;
    property OnExit;
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
  Math, DateUtils;

{ TNoticeItem }

constructor TNoticeItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FTime := Now;
  FUnread := true;
end;

procedure TNoticeItem.Assign(Source: TPersistent);
begin
  if Source is TNoticeItem then begin
    FTitle := TNoticeItem(Source).FTitle;
    FText := TNoticeItem(Source).FText;
    FActionText := TNoticeItem(Source).FActionText;
    FKind := TNoticeItem(Source).FKind;
    FTime := TNoticeItem(Source).FTime;
    FUnread := TNoticeItem(Source).FUnread;
    FTag := TNoticeItem(Source).FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TNoticeItem.GetDisplayName: string;
begin
  result := if FTitle <> '' then FTitle else inherited GetDisplayName;
end;

procedure TNoticeItem.setTitle(const value: string);
begin
  if FTitle = value then exit;
  FTitle := value;
  Changed(false);
end;

procedure TNoticeItem.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  Changed(false);
end;

procedure TNoticeItem.setActionText(const value: string);
begin
  if FActionText = value then exit;
  FActionText := value;
  Changed(false);
end;

procedure TNoticeItem.setKind(value: TNoticeKind);
begin
  if FKind = value then exit;
  FKind := value;
  Changed(false);
end;

procedure TNoticeItem.setUnread(value: boolean);
begin
  if FUnread = value then exit;
  FUnread := value;
  Changed(false);
  if Collection.Owner is TNotificationCenter then TNotificationCenter(Collection.Owner).unreadChanged;
end;

{ TNoticeItems }

function TNoticeItems.getItem(index: integer): TNoticeItem;
begin
  result := TNoticeItem(inherited Items[index]);
end;

procedure TNoticeItems.setItem(index: integer; value: TNoticeItem);
begin
  inherited Items[index] := value;
end;

function TNoticeItems.Add: TNoticeItem;
begin
  result := TNoticeItem(inherited Add);
end;

procedure TNoticeItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TNotificationCenter then begin
    TNotificationCenter(Owner).updateRange;
    TNotificationCenter(Owner).Invalidate;
  end;
end;

{ TNotificationCenter }

constructor TNotificationCenter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FItems := TNoticeItems.Create(self, TNoticeItem);
  FMaxItems := 100;
  FPadding := 10;
  FCornerRadius := 6;
  FSpacing := 6;
  FMaxLines := 3;
  FShowTime := true;
  FShowKindBar := true;
  FShowClose := true;
  FNewestFirst := true;
  FMarkReadOnClick := true;
  FShowEmptyText := true;
  FEmptyText := 'No notifications';
  FBackColor := clDefault;
  FCardColor := clDefault;
  FUnreadColor := clDefault;
  FBorderColor := clDefault;
  FTitleColor := clDefault;
  FTextColor := clDefault;
  FTimeColor := clDefault;
  FAntialiasing := asTheme;
  Color := clWindow;
  BorderStyle := bsNone;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Visible := false;
  FTimer := TTimer.Create(self);
  FTimer.Interval := 30000;
  FTimer.OnTimer := @tick;
  FTimer.Enabled := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TNotificationCenter.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

class function TNotificationCenter.GetControlClassDefaultSize: TSize;
begin
  result.cx := 280;
  result.cy := 320;
end;

// -- the list ----------------------

function TNotificationCenter.Add(const title, text: string; kind: TNoticeKind; tag: PtrInt): TNoticeItem;
begin
  FItems.BeginUpdate;
  try
    result := FItems.Add;
    result.FTitle := title;
    result.FText := text;
    result.FKind := kind;
    result.FTag := tag;
    result.FTime := Now;
    if FNewestFirst then result.Index := 0;
    // the oldest go over the limit
    if FMaxItems > 0 then while FItems.Count > FMaxItems do
      if FNewestFirst then FItems.Delete(FItems.Count-1) else FItems.Delete(0);
  finally
    FItems.EndUpdate;
  end;
  unreadChanged;
end;

procedure TNotificationCenter.Dismiss(item: TNoticeItem);
begin
  if (item = nil) or (item.Collection <> FItems) then exit;
  var allow := true;
  if Assigned(FOnDismiss) then FOnDismiss(self, item, allow);
  if not allow then exit;
  var wasUnread := item.Unread;
  if Assigned(FOnDismissed) then FOnDismissed(self, item);
  if FHot = item then FHot := nil;
  item.Free;
  if wasUnread then unreadChanged;
  updateRange;
  Invalidate;
end;

procedure TNotificationCenter.Clear;
begin
  var had := UnreadCount > 0;
  FHot := nil;
  FItems.Clear;
  if had then unreadChanged;
  updateRange;
  Invalidate;
end;

procedure TNotificationCenter.ClearRead;
begin
  FItems.BeginUpdate;
  try
    for var i := FItems.Count-1 downto 0 do if not FItems[i].Unread then FItems.Delete(i);
  finally
    FItems.EndUpdate;
  end;
  FHot := nil;
  updateRange;
  Invalidate;
end;

procedure TNotificationCenter.MarkAllRead;
begin
  var any := false;
  for var i := 0 to FItems.Count-1 do if FItems[i].FUnread then begin
    FItems[i].FUnread := false;
    any := true;
  end;
  if not any then exit;
  unreadChanged;
  Invalidate;
end;

function TNotificationCenter.UnreadCount: integer;
begin
  result := 0;
  for var i := 0 to FItems.Count-1 do if FItems[i].Unread then inc(result);
end;

procedure TNotificationCenter.unreadChanged;
begin
  if Assigned(FOnUnreadChange) then FOnUnreadChange(self);
end;

procedure TNotificationCenter.tick(Sender: TObject);
begin
  if FShowTime and (FItems.Count > 0) then Invalidate;
end;

// -- geometry ----------------------

function TNotificationCenter.kindColor(kind: TNoticeKind): TColor;
begin
  result := match kind of
    nkInfo: $D98B3B;
    nkSuccess: $5CB85C;
    nkWarning: $4EADF0;
    nkError: $4F53D9;
  else
    blend(clWindow, clWindowText, 30)
  end;
end;

function TNotificationCenter.timeText(time: TDateTime): string;
begin
  var seconds := SecondsBetween(Now, time);
  if time > Now then seconds := 0;
  result := match true of
    seconds < 60: 'now';
    seconds < 3600: Format('%d min ago', [seconds div 60]);
    seconds < 86400: Format('%d h ago', [seconds div 3600]);
    seconds < 7*86400: Format('%d d ago', [seconds div 86400]);
  else
    FormatDateTime('yyyy-mm-dd', time)
  end;
end;

function TNotificationCenter.itemHeight(item: TNoticeItem; width: integer): integer;
begin
  var pad := scaled(self, FPadding);
  var lh := lineHeightOf(Font);
  result := 2*pad+lh;
  var room := Max(width-2*pad-scaled(self, 24), 1);
  if item.Text <> '' then begin
    var lines := Min((textWidthOf(Font, item.Text)+room-1) div room, FMaxLines);
    result += Max(lines, 1)*lh+scaled(self, 2);
  end;
  if item.ActionText <> '' then result += lh+scaled(self, 4);
end;

function TNotificationCenter.itemAt(x, y: integer; out part: integer): TNoticeItem;
begin
  part := 0;
  var p := Point(x, y+VertScrollBar.Position);
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if not PtInRect(item.FRect, p) then continue;
    if PtInRect(item.FCloseRect, p) then part := 1
    else if PtInRect(item.FActionRect, p) then part := 2;
    exit(item);
  end;
  result := nil;
end;

procedure TNotificationCenter.updateRange;
begin
  if not HandleAllocated then exit;
  var spacing := scaled(self, FSpacing);
  var total := spacing;
  var w := ClientWidth-2*spacing;
  for var i := 0 to FItems.Count-1 do total += itemHeight(FItems[i], w)+spacing;
  VertScrollBar.Increment := lineHeightOf(Font)*2;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := total;
end;

procedure TNotificationCenter.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TNotificationCenter.Resize;
begin
  inherited Resize;
  updateRange;
  Invalidate;
end;

procedure TNotificationCenter.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

// -- painting ----------------------

procedure TNotificationCenter.Paint;
begin
  var back := pick(FBackColor, Color);
  var card := pick(FCardColor, blend(back, clBtnFace, 40));
  var unread := pick(FUnreadColor, blend(back, clHighlight, 8));
  var border := pick(FBorderColor, blend(back, clWindowText, 15));
  var titleColor := pick(FTitleColor, clWindowText);
  var textColor := pick(FTextColor, blend(clWindowText, clWindow, 30));
  var timeColor := pick(FTimeColor, blend(clWindowText, clWindow, 50));
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var spacing := scaled(self, FSpacing);
  var pad := scaled(self, FPadding);
  var radius := scaled(self, FCornerRadius);
  var lh := lineHeightOf(Font);
  var w := ClientWidth-2*spacing;
  var y := spacing;
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    var h := itemHeight(item, w);
    item.FRect := Rect(spacing, y, spacing+w, y+h);
    item.FCloseRect := Rect(0, 0, 0, 0);
    item.FActionRect := Rect(0, 0, 0, 0);
    y += h+spacing;
    if (item.FRect.Bottom < view.Top) or (item.FRect.Top > view.Bottom) then continue;
    var fill := if item.Unread then unread else card;
    if (item = FHot) and hoverEnabled then fill := hoverColor(fill);
    paintRoundRect(sp, item.FRect, radius, fill, border, 1);
    if FShowKindBar then
      sp.FillRoundRect(item.FRect.Left+scaled(self, 4), item.FRect.Top+scaled(self, 8), item.FRect.Left+scaled(self, 7), item.FRect.Bottom-scaled(self, 8), 1.5, kindColor(item.Kind));
    if item.Unread then paintCircle(sp, item.FRect.Right-pad-scaled(self, 4), item.FRect.Top+pad+lh div 2, scaled(self, 4), ColorToRGB(clHighlight), clNone);
    if FShowClose then begin
      var size := scaled(self, 16);
      item.FCloseRect := Rect(item.FRect.Right-pad-size, item.FRect.Top+pad-scaled(self, 2), item.FRect.Right-pad, item.FRect.Top+pad-scaled(self, 2)+size);
      if item.Unread then item.FCloseRect.Offset(-scaled(self, 14), 0);
      if (item = FHot) and (FHotPart = 1) then paintCircle(sp, (item.FCloseRect.Left+item.FCloseRect.Right) div 2, (item.FCloseRect.Top+item.FCloseRect.Bottom) div 2, size div 2, blend(fill, clWindowText, 15), clNone);
      paintCross(sp, item.FCloseRect, scaled(self, 8), timeColor, scaled(self, 1));
    end;
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  if (FItems.Count = 0) and FShowEmptyText then begin
    Canvas.Font.Color := timeColor;
    paintCenteredText(Canvas, view, FEmptyText, timeColor);
    Canvas.Brush.Style := bsSolid;
    exit;
  end;
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if (item.FRect.Bottom < view.Top) or (item.FRect.Top > view.Bottom) then continue;
    var left := item.FRect.Left+pad+(if FShowKindBar then scaled(self, 6) else 0);
    var right := item.FRect.Right-pad;
    if FShowClose then right := item.FCloseRect.Left-scaled(self, 4);
    if item.Unread then right -= scaled(self, 12);
    var top := item.FRect.Top+pad;
    var style := Canvas.TextStyle;
    style.SingleLine := true;
    style.Clipping := true;
    style.EndEllipsis := true;
    style.ShowPrefix := false;
    style.Opaque := false;
    style.Layout := tlTop;
    style.Alignment := taLeftJustify;
    var timeW := 0;
    if FShowTime then begin
      Canvas.Font.Style := Font.Style;
      Canvas.Font.Color := timeColor;
      var t := timeText(item.Time);
      timeW := Canvas.TextWidth(t)+scaled(self, 6);
      Canvas.TextOut(right-timeW+scaled(self, 6), top, t);
    end;
    Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.Font.Color := titleColor;
    var tr := Rect(left, top, right-timeW, top+lh);
    if tr.Right > tr.Left then Canvas.TextRect(tr, tr.Left, tr.Top, item.Title, style);
    top += lh+scaled(self, 2);
    if item.Text <> '' then begin
      Canvas.Font.Style := Font.Style;
      Canvas.Font.Color := textColor;
      var room := Max(w-2*pad-scaled(self, 24), 1);
      var lines := Max(Min((Canvas.TextWidth(item.Text)+room-1) div room, FMaxLines), 1);
      var multi := style;
      multi.SingleLine := false;
      multi.Wordbreak := true;
      multi.EndEllipsis := false;
      var xr := Rect(left, top, item.FRect.Right-pad, top+lines*lh);
      Canvas.TextRect(xr, xr.Left, xr.Top, item.Text, multi);
      top += lines*lh;
    end;
    if item.ActionText <> '' then begin
      top += scaled(self, 4);
      Canvas.Font.Style := if (item = FHot) and (FHotPart = 2) then Font.Style+[fsUnderline] else Font.Style;
      Canvas.Font.Color := ColorToRGB(clHighlight);
      item.FActionRect := Rect(left, top, left+Canvas.TextWidth(item.ActionText), top+lh);
      Canvas.TextOut(left, top, item.ActionText);
    end;
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TNotificationCenter.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var part: integer;
  var hot := itemAt(X, Y, part);
  if (hot = FHot) and (part = FHotPart) then exit;
  FHot := hot;
  FHotPart := part;
  Cursor := if (hot <> nil) and (part > 0) then crHandPoint else crDefault;
  Invalidate;
end;

procedure TNotificationCenter.MouseLeave;
begin
  inherited MouseLeave;
  if FHot = nil then exit;
  FHot := nil;
  Invalidate;
end;

procedure TNotificationCenter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var part: integer;
  var item := itemAt(X, Y, part);
  if item = nil then exit;
  match part of
    1: Dismiss(item);
    2: begin
      if FMarkReadOnClick then item.Unread := false;
      if Assigned(FOnAction) then FOnAction(self, item);
    end;
  else
    begin
      if FMarkReadOnClick then item.Unread := false;
      if Assigned(FOnItemClick) then FOnItemClick(self, item);
    end;
  end;
end;

// -- properties ----------------------

procedure TNotificationCenter.setItems(value: TNoticeItems);
begin
  FItems.Assign(value);
  updateRange;
  Invalidate;
end;

function TNotificationCenter.getMetric(index: integer): integer;
begin
  result := match index of
    0: FMaxItems;
    1: FPadding;
    2: FCornerRadius;
    3: FSpacing;
  else
    FMaxLines
  end;
end;

procedure TNotificationCenter.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 4 then value := Max(value, 1);
  if getMetric(index) = value then exit;
  match index of
    0: FMaxItems := value;
    1: FPadding := value;
    2: FCornerRadius := value;
    3: FSpacing := value;
  else
    FMaxLines := value;
  end;
  updateRange;
  Invalidate;
end;

function TNotificationCenter.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowTime;
    1: FShowKindBar;
    2: FShowClose;
    3: FNewestFirst;
    4: FMarkReadOnClick;
  else
    FShowEmptyText
  end;
end;

procedure TNotificationCenter.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowTime := value;
    1: FShowKindBar := value;
    2: FShowClose := value;
    3: FNewestFirst := value;
    4: FMarkReadOnClick := value;
  else
    FShowEmptyText := value;
  end;
  Invalidate;
end;

procedure TNotificationCenter.setEmptyText(const value: string);
begin
  if FEmptyText = value then exit;
  FEmptyText := value;
  Invalidate;
end;

function TNotificationCenter.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBackColor;
    1: FCardColor;
    2: FUnreadColor;
    3: FBorderColor;
    4: FTitleColor;
    5: FTextColor;
  else
    FTimeColor
  end;
end;

procedure TNotificationCenter.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBackColor := value;
    1: FCardColor := value;
    2: FUnreadColor := value;
    3: FBorderColor := value;
    4: FTitleColor := value;
    5: FTextColor := value;
  else
    FTimeColor := value;
  end;
  Invalidate;
end;

procedure TNotificationCenter.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
