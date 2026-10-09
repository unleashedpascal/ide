{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit KanbanBoard;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint;

type
  TKanbanBoard = class;
  TKanbanCard = class;
  TKanbanCardEvent = procedure(Sender: TObject; card: TKanbanCard) of object;
  // paints over a finished card: dsSelected for the selected one, dsHover
  // under the mouse, dsPressed while it is dragged
  TKanbanDrawCardEvent = procedure(Sender: TObject; canvas: TCanvas; const r: TRect; card: TKanbanCard; state: TDrawState) of object;
  // a card went to another column or another place; fromColumn is the old one
  TKanbanMoveEvent = procedure(Sender: TObject; card: TKanbanCard; fromColumn, toColumn: integer) of object;
  // a card is about to move; allow false keeps it where it is
  TKanbanAllowMoveEvent = procedure(Sender: TObject; card: TKanbanCard; toColumn: integer; var allow: boolean) of object;
  TKanbanColumnEvent = procedure(Sender: TObject; column: integer) of object;

  { TKanbanColumn }

  TKanbanColumn = class(TCollectionItem)
  private
    FCaption: string;
    FColor: TColor;
    FLimit: integer;
    FCollapsed: boolean;
    FTag: PtrInt;
    FScroll: integer; // the vertical offset of the cards
    procedure setCaption(const value: string);
    procedure setColor(value: TColor);
    procedure setLimit(value: integer);
    procedure setCollapsed(value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // the cards in this column
    function CardCount: integer;
  published
    property Caption: string read FCaption write setCaption;
    // the strip under the header; clDefault takes a color from the palette
    property Color: TColor read FColor write setColor default clDefault;
    // the most cards the column takes, 0 for any number; over it the count shows red
    property Limit: integer read FLimit write setLimit default 0;
    // a collapsed column shows its header only
    property Collapsed: boolean read FCollapsed write setCollapsed default false;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TKanbanColumns }

  TKanbanColumns = class(TOwnedCollection)
  private
    function getItem(index: integer): TKanbanColumn;
    procedure setItem(index: integer; value: TKanbanColumn);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TKanbanColumn;
    property Items[index: integer]: TKanbanColumn read getItem write setItem; default;
  end;

  { TKanbanCard }

  TKanbanCard = class(TCollectionItem)
  private
    FTitle, FText, FLabelText, FAssignee: string;
    FColumn, FPriority: integer;
    FLabelColor: TColor;
    FTag: PtrInt;
    FData: TObject;
    FRect: TRect; // where it was painted last, in board coordinates
    procedure setTitle(const value: string);
    procedure setText(const value: string);
    procedure setLabelText(const value: string);
    procedure setAssignee(const value: string);
    procedure setColumn(value: integer);
    procedure setPriority(value: integer);
    procedure setLabelColor(value: TColor);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // an object of the application the card stands for; not owned
    property Data: TObject read FData write FData;
  published
    property Title: string read FTitle write setTitle;
    // a line or two under the title
    property Text: string read FText write setText;
    // a small tag in the corner, like a type or a milestone
    property LabelText: string read FLabelText write setLabelText;
    property LabelColor: TColor read FLabelColor write setLabelColor default clDefault;
    // initials or a name shown bottom right
    property Assignee: string read FAssignee write setAssignee;
    // the index of the column the card sits in
    property Column: integer read FColumn write setColumn default 0;
    // 0 none, 1 low, 2 medium, 3 high: a mark on the left edge
    property Priority: integer read FPriority write setPriority default 0;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TKanbanCards }

  TKanbanCards = class(TOwnedCollection)
  private
    function getItem(index: integer): TKanbanCard;
    procedure setItem(index: integer; value: TKanbanCard);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TKanbanCard;
    property Items[index: integer]: TKanbanCard read getItem write setItem; default;
  end;

  { TKanbanBoard }

  // columns of cards the mouse drags from one to another and up and down
  // inside one: a task board, a pipeline, a sorting tray. The columns and
  // the cards are collections, so a board can be filled in the designer;
  // every move fires an event with the card and both columns
  TKanbanBoard = class(TCustomControl)
  private
    type
      TTextJob = record
        r, clip: TRect;
        text: string;
        color: TColor;
        bold, small, center: boolean;
      end;
    var
    FColumns: TKanbanColumns;
    FTexts: array of TTextJob;
    FCards: TKanbanCards;
    FSelected, FHot, FHotColumn: TKanbanCard;
    FDragCard: TKanbanCard;
    FDragStart, FDragPos: TPoint;
    FDragging: boolean;
    FDropColumn, FDropIndex: integer;
    FColumnGap, FCardSpacing, FCardRadius, FHeaderHeight, FPadding, FMinColumnWidth, FScrollX: integer;
    FShowCounts, FShowText, FShowLabels, FShowAssignee, FShowPriority, FAllowDrag, FAllowReorder, FFitColumns: boolean;
    FBoardColor, FColumnColor, FCardColor, FBorderColor, FTitleColor, FTextColor, FHeaderColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnCardClick, FOnCardDblClick, FOnSelect: TKanbanCardEvent;
    FOnCardMove: TKanbanMoveEvent;
    FOnAllowMove: TKanbanAllowMoveEvent;
    FOnColumnClick: TKanbanColumnEvent;
    FOnDrawCard: TKanbanDrawCardEvent;
    procedure setColumns(value: TKanbanColumns);
    procedure setCards(value: TKanbanCards);
    procedure setSelected(value: TKanbanCard);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function columnWidth: integer;
    function columnRect(index: integer): TRect;
    function columnAt(x: integer): integer;
    function cardAt(x, y: integer): TKanbanCard;
    function cardHeight(card: TKanbanCard; width: integer): integer;
    function accentOf(index: integer): TColor;
    function contentHeight(column: integer; width: integer): integer;
    procedure layoutColumn(column: integer; out r: TRect; out cardsTop: integer);
    procedure dropAt(x, y: integer; out column, index: integer);
    procedure placeCard(card: TKanbanCard; toColumn, toIndex: integer);
    procedure addText(const r: TRect; const text: string; color: TColor; bold, small, center: boolean; const clip: TRect);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DblClick; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddColumn(const caption: string; color: TColor = clDefault): TKanbanColumn;
    function AddCard(column: integer; const title: string; const text: string = ''): TKanbanCard;
    // the cards of a column in their order
    procedure CardsOf(column: integer; list: TList);
    // moves a card as a drag would, with the events
    procedure MoveCard(card: TKanbanCard; toColumn: integer; toIndex: integer = -1);
    procedure ScrollColumn(column, delta: integer);
    property Selected: TKanbanCard read FSelected write setSelected;
  published
    property Columns: TKanbanColumns read FColumns write setColumns;
    property Cards: TKanbanCards read FCards write setCards;
    property ColumnGap: integer index 0 read getMetric write setMetric default 10;
    property CardSpacing: integer index 1 read getMetric write setMetric default 6;
    property CardRadius: integer index 2 read getMetric write setMetric default 5;
    // 0 takes it from the font
    property HeaderHeight: integer index 3 read getMetric write setMetric default 0;
    property Padding: integer index 4 read getMetric write setMetric default 8;
    // columns never get narrower; the board scrolls sideways instead
    property MinColumnWidth: integer index 5 read getMetric write setMetric default 140;
    // the number of cards next to the caption
    property ShowCounts: boolean index 0 read getFlag write setFlag default true;
    property ShowText: boolean index 1 read getFlag write setFlag default true;
    property ShowLabels: boolean index 2 read getFlag write setFlag default true;
    property ShowAssignee: boolean index 3 read getFlag write setFlag default true;
    property ShowPriority: boolean index 4 read getFlag write setFlag default true;
    // cards move between columns with the mouse
    property AllowDrag: boolean index 5 read getFlag write setFlag default true;
    // cards change their order inside a column with the mouse
    property AllowReorder: boolean index 6 read getFlag write setFlag default true;
    // the columns share the width; off, every column is MinColumnWidth wide
    property FitColumns: boolean index 7 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property BoardColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ColumnColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property CardColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property HeaderColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnCardClick: TKanbanCardEvent read FOnCardClick write FOnCardClick;
    property OnCardDblClick: TKanbanCardEvent read FOnCardDblClick write FOnCardDblClick;
    property OnSelect: TKanbanCardEvent read FOnSelect write FOnSelect;
    property OnCardMove: TKanbanMoveEvent read FOnCardMove write FOnCardMove;
    property OnAllowMove: TKanbanAllowMoveEvent read FOnAllowMove write FOnAllowMove;
    // a click on a header
    property OnColumnClick: TKanbanColumnEvent read FOnColumnClick write FOnColumnClick;
    // paints over every card once the board is painted; see TKanbanDrawCardEvent
    property OnDrawCard: TKanbanDrawCardEvent read FOnDrawCard write FOnDrawCard;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
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

const
  PALETTE: array[0..5] of TColor = ($D98B3B, $5CB85C, $F0AD4E, $D9534F, $B35CA0, $17A2B8);
  PRIORITY_COLORS: array[1..3] of TColor = ($5CB85C, $F0AD4E, $D9534F);

{ TKanbanColumn }

constructor TKanbanColumn.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clDefault;
end;

procedure TKanbanColumn.Assign(Source: TPersistent);
begin
  if Source is TKanbanColumn then begin
    FCaption := TKanbanColumn(Source).FCaption;
    FColor := TKanbanColumn(Source).FColor;
    FLimit := TKanbanColumn(Source).FLimit;
    FCollapsed := TKanbanColumn(Source).FCollapsed;
    FTag := TKanbanColumn(Source).FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TKanbanColumn.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

function TKanbanColumn.CardCount: integer;
begin
  result := 0;
  var board := Collection.Owner as TKanbanBoard;
  for var i := 0 to board.FCards.Count-1 do if board.FCards[i].Column = Index then inc(result);
end;

procedure TKanbanColumn.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TKanbanColumn.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TKanbanColumn.setLimit(value: integer);
begin
  value := Max(value, 0);
  if FLimit = value then exit;
  FLimit := value;
  Changed(false);
end;

procedure TKanbanColumn.setCollapsed(value: boolean);
begin
  if FCollapsed = value then exit;
  FCollapsed := value;
  Changed(false);
end;

{ TKanbanColumns }

function TKanbanColumns.getItem(index: integer): TKanbanColumn;
begin
  result := TKanbanColumn(inherited Items[index]);
end;

procedure TKanbanColumns.setItem(index: integer; value: TKanbanColumn);
begin
  inherited Items[index] := value;
end;

function TKanbanColumns.Add: TKanbanColumn;
begin
  result := TKanbanColumn(inherited Add);
end;

procedure TKanbanColumns.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TKanbanBoard then TKanbanBoard(Owner).Invalidate;
end;

{ TKanbanCard }

constructor TKanbanCard.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FLabelColor := clDefault;
end;

procedure TKanbanCard.Assign(Source: TPersistent);
begin
  if Source is TKanbanCard then begin
    FTitle := TKanbanCard(Source).FTitle;
    FText := TKanbanCard(Source).FText;
    FLabelText := TKanbanCard(Source).FLabelText;
    FLabelColor := TKanbanCard(Source).FLabelColor;
    FAssignee := TKanbanCard(Source).FAssignee;
    FColumn := TKanbanCard(Source).FColumn;
    FPriority := TKanbanCard(Source).FPriority;
    FTag := TKanbanCard(Source).FTag;
    FData := TKanbanCard(Source).FData;
    Changed(false);
  end else inherited Assign(Source);
end;

function TKanbanCard.GetDisplayName: string;
begin
  result := if FTitle <> '' then FTitle else inherited GetDisplayName;
end;

procedure TKanbanCard.setTitle(const value: string);
begin
  if FTitle = value then exit;
  FTitle := value;
  Changed(false);
end;

procedure TKanbanCard.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  Changed(false);
end;

procedure TKanbanCard.setLabelText(const value: string);
begin
  if FLabelText = value then exit;
  FLabelText := value;
  Changed(false);
end;

procedure TKanbanCard.setAssignee(const value: string);
begin
  if FAssignee = value then exit;
  FAssignee := value;
  Changed(false);
end;

procedure TKanbanCard.setColumn(value: integer);
begin
  value := Max(value, 0);
  if FColumn = value then exit;
  FColumn := value;
  Changed(false);
end;

procedure TKanbanCard.setPriority(value: integer);
begin
  value := EnsureRange(value, 0, 3);
  if FPriority = value then exit;
  FPriority := value;
  Changed(false);
end;

procedure TKanbanCard.setLabelColor(value: TColor);
begin
  if FLabelColor = value then exit;
  FLabelColor := value;
  Changed(false);
end;

{ TKanbanCards }

function TKanbanCards.getItem(index: integer): TKanbanCard;
begin
  result := TKanbanCard(inherited Items[index]);
end;

procedure TKanbanCards.setItem(index: integer; value: TKanbanCard);
begin
  inherited Items[index] := value;
end;

function TKanbanCards.Add: TKanbanCard;
begin
  result := TKanbanCard(inherited Add);
end;

procedure TKanbanCards.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TKanbanBoard then TKanbanBoard(Owner).Invalidate;
end;

{ TKanbanBoard }

constructor TKanbanBoard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FColumns := TKanbanColumns.Create(self, TKanbanColumn);
  FCards := TKanbanCards.Create(self, TKanbanCard);
  FColumnGap := 10;
  FCardSpacing := 6;
  FCardRadius := 5;
  FPadding := 8;
  FMinColumnWidth := 140;
  FShowCounts := true;
  FShowText := true;
  FShowLabels := true;
  FShowAssignee := true;
  FShowPriority := true;
  FAllowDrag := true;
  FAllowReorder := true;
  FFitColumns := true;
  FBoardColor := clDefault;
  FColumnColor := clDefault;
  FCardColor := clDefault;
  FBorderColor := clDefault;
  FTitleColor := clDefault;
  FTextColor := clDefault;
  FHeaderColor := clDefault;
  FAntialiasing := asTheme;
  FDropColumn := -1;
  TabStop := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TKanbanBoard.Destroy;
begin
  FCards.Free;
  FColumns.Free;
  inherited Destroy;
end;

class function TKanbanBoard.GetControlClassDefaultSize: TSize;
begin
  result.cx := 480;
  result.cy := 300;
end;

function TKanbanBoard.AddColumn(const caption: string; color: TColor): TKanbanColumn;
begin
  result := FColumns.Add;
  result.Caption := caption;
  result.Color := color;
end;

function TKanbanBoard.AddCard(column: integer; const title: string; const text: string): TKanbanCard;
begin
  result := FCards.Add;
  result.Column := column;
  result.Title := title;
  result.Text := text;
end;

procedure TKanbanBoard.CardsOf(column: integer; list: TList);
begin
  for var i := 0 to FCards.Count-1 do if FCards[i].Column = column then list.Add(FCards[i]);
end;

// -- geometry ----------------------

function TKanbanBoard.columnWidth: integer;
begin
  var n := Max(FColumns.Count, 1);
  var gap := scaled(self, FColumnGap);
  var pad := scaled(self, FPadding);
  result := (ClientWidth-2*pad-(n-1)*gap) div n;
  var least := scaled(self, FMinColumnWidth);
  if not FFitColumns or (result < least) then result := least;
end;

function TKanbanBoard.columnRect(index: integer): TRect;
begin
  var pad := scaled(self, FPadding);
  var gap := scaled(self, FColumnGap);
  var w := columnWidth;
  var collapsedW := scaled(self, 32);
  var x := pad-FScrollX;
  for var i := 0 to index-1 do x += (if FColumns[i].Collapsed then collapsedW else w)+gap;
  result := Rect(x, pad, x+(if FColumns[index].Collapsed then collapsedW else w), ClientHeight-pad);
end;

function TKanbanBoard.columnAt(x: integer): integer;
begin
  for var i := 0 to FColumns.Count-1 do begin
    var r := columnRect(i);
    if (x >= r.Left-scaled(self, FColumnGap) div 2) and (x < r.Right+scaled(self, FColumnGap) div 2) then exit(i);
  end;
  result := -1;
end;

function TKanbanBoard.accentOf(index: integer): TColor;
begin
  result := FColumns[index].Color;
  if result = clDefault then result := PALETTE[index mod length(PALETTE)];
  result := ColorToRGB(result);
end;

function TKanbanBoard.cardHeight(card: TKanbanCard; width: integer): integer;
begin
  var pad := scaled(self, 8);
  var lh := lineHeightOf(Font);
  result := 2*pad+lh;
  if FShowText and (card.Text <> '') then begin
    // the text wraps inside the card, at most three lines; the count is
    // an estimate by width, the paint clips whatever runs over
    var room := Max(width-2*pad-scaled(self, 6), 1);
    var lines := Min((textWidthOf(Font, card.Text)+room-1) div room, 3);
    result += Max(lines, 1)*lh+scaled(self, 2);
  end;
  if (FShowLabels and (card.LabelText <> '')) or (FShowAssignee and (card.Assignee <> '')) then result += lh+scaled(self, 4);
end;

function TKanbanBoard.contentHeight(column: integer; width: integer): integer;
begin
  result := 0;
  var spacing := scaled(self, FCardSpacing);
  for var i := 0 to FCards.Count-1 do if FCards[i].Column = column then result += cardHeight(FCards[i], width)+spacing;
end;

procedure TKanbanBoard.layoutColumn(column: integer; out r: TRect; out cardsTop: integer);
begin
  r := columnRect(column);
  var headerH := if FHeaderHeight > 0 then scaled(self, FHeaderHeight) else lineHeightOf(Font)+scaled(self, 14);
  cardsTop := r.Top+headerH+scaled(self, 4);
end;

function TKanbanBoard.cardAt(x, y: integer): TKanbanCard;
begin
  for var i := 0 to FCards.Count-1 do if PtInRect(FCards[i].FRect, Point(x, y)) then exit(FCards[i]);
  result := nil;
end;

// where a card dropped at x, y would land
procedure TKanbanBoard.dropAt(x, y: integer; out column, index: integer);
begin
  column := columnAt(x);
  index := -1;
  if column < 0 then exit;
  if FColumns[column].Collapsed then begin column := -1; exit; end;
  index := 0;
  for var i := 0 to FCards.Count-1 do begin
    var c := FCards[i];
    if (c.Column <> column) or (c = FDragCard) then continue;
    if y > (c.FRect.Top+c.FRect.Bottom) div 2 then inc(index);
  end;
end;

// puts a card at a place inside a column, moving the others of that column after it
procedure TKanbanBoard.placeCard(card: TKanbanCard; toColumn, toIndex: integer);
begin
  var list := autofree TList.Create;
  CardsOf(toColumn, list);
  list.Remove(card);
  if (toIndex < 0) or (toIndex > list.Count) then toIndex := list.Count;
  list.Insert(toIndex, card);
  // the cards of the column keep their collection order as the list says:
  // place them one after another at the slots the column already used
  var slots := autofree TList.Create;
  for var i := 0 to FCards.Count-1 do if (FCards[i].Column = toColumn) or (FCards[i] = card) then slots.Add(Pointer(PtrInt(i)));
  // the slots are sorted already, the list says who takes which
  card.FColumn := toColumn;
  FCards.BeginUpdate;
  try
    for var k := 0 to list.Count-1 do TKanbanCard(list[k]).Index := PtrInt(slots[k]);
  finally
    FCards.EndUpdate;
  end;
end;

procedure TKanbanBoard.MoveCard(card: TKanbanCard; toColumn: integer; toIndex: integer);
begin
  if (card = nil) or (toColumn < 0) or (toColumn >= FColumns.Count) then exit;
  var allow := true;
  if Assigned(FOnAllowMove) then FOnAllowMove(self, card, toColumn, allow);
  if not allow then exit;
  var from := card.Column;
  placeCard(card, toColumn, toIndex);
  Invalidate;
  if Assigned(FOnCardMove) then FOnCardMove(self, card, from, toColumn);
end;

procedure TKanbanBoard.ScrollColumn(column, delta: integer);
begin
  if (column < 0) or (column >= FColumns.Count) then exit;
  var r: TRect;
  var top: integer;
  layoutColumn(column, r, top);
  var most := Max(contentHeight(column, r.Width-2*scaled(self, 6))-(r.Bottom-top), 0);
  var value := EnsureRange(FColumns[column].FScroll+delta, 0, most);
  if value = FColumns[column].FScroll then exit;
  FColumns[column].FScroll := value;
  Invalidate;
end;

// -- painting ----------------------

procedure TKanbanBoard.addText(const r: TRect; const text: string; color: TColor; bold, small, center: boolean; const clip: TRect);
begin
  SetLength(FTexts, length(FTexts)+1);
  FTexts[high(FTexts)].r := r;
  FTexts[high(FTexts)].clip := clip;
  FTexts[high(FTexts)].text := text;
  FTexts[high(FTexts)].color := color;
  FTexts[high(FTexts)].bold := bold;
  FTexts[high(FTexts)].small := small;
  FTexts[high(FTexts)].center := center;
end;

procedure TKanbanBoard.Paint;
begin
  var board := pick(FBoardColor, blend(clBtnFace, clWindow, 30));
  var columnBack := pick(FColumnColor, blend(clBtnFace, clBtnShadow, 15));
  var cardBack := pick(FCardColor, clWindow);
  var border := pick(FBorderColor, blend(clBtnFace, clBtnText, 20));
  var titleColor := pick(FTitleColor, clWindowText);
  var textColor := pick(FTextColor, blend(clWindowText, clWindow, 35));
  var headerColor := pick(FHeaderColor, clBtnText);
  var sp := autofree beginShapes(Canvas, ClientRect, board, FAntialiasing);
  var radius := scaled(self, FCardRadius);
  var inner := scaled(self, 6);
  var spacing := scaled(self, FCardSpacing);
  var pad := scaled(self, 8);
  var lh := lineHeightOf(Font);
  for var i := 0 to FCards.Count-1 do FCards[i].FRect := Rect(0, 0, 0, 0);

  FTexts := nil;

  for var c := 0 to FColumns.Count-1 do begin
    var col := FColumns[c];
    var r: TRect;
    var cardsTop: integer;
    layoutColumn(c, r, cardsTop);
    if (r.Right < 0) or (r.Left > ClientWidth) then continue;
    var accent := accentOf(c);
    var dropHere := FDragging and (FDropColumn = c);
    paintRoundRect(sp, r, radius, (if dropHere then blend(columnBack, accent, 15) else columnBack), (if dropHere then accent else clNone));
    // the colored strip on top
    sp.FillRoundRect(r.Left, r.Top, r.Right, r.Top+scaled(self, 4)+radius, radius, accent);
    sp.FillRect(Rect(r.Left, r.Top+scaled(self, 4), r.Right, r.Top+scaled(self, 4)+radius), (if dropHere then blend(columnBack, accent, 15) else columnBack));
    var count := col.CardCount;
    var caption := col.Caption;
    if col.Collapsed then begin
      // the header only, the caption turned sideways would be hard to read: show the count
      addText(Rect(r.Left, r.Top+scaled(self, 8), r.Right, r.Top+scaled(self, 8)+lh), IntToStr(count), headerColor, true, false, true, r);
      continue;
    end;
    var countText := '';
    if FShowCounts then countText := if col.Limit > 0 then Format('%d/%d', [count, col.Limit]) else IntToStr(count);
    var overLimit := (col.Limit > 0) and (count > col.Limit);
    var header := Rect(r.Left+inner, r.Top+scaled(self, 6), r.Right-inner, cardsTop-scaled(self, 4));
    if countText <> '' then begin
      var cw := textWidthOf(Font, countText)+scaled(self, 12);
      var pill := Rect(header.Right-cw, header.Top+(header.Height-lh-scaled(self, 4)) div 2, header.Right, 0);
      pill.Bottom := pill.Top+lh+scaled(self, 4);
      paintPill(sp, pill, (if overLimit then $4040E0 else blend(columnBack, clBtnText, 12)), clNone);
      addText(pill, countText, (if overLimit then clWhite else headerColor), false, true, true, r);
      header.Right := pill.Left-scaled(self, 4);
    end;
    addText(header, caption, headerColor, true, false, false, r);

    // the cards
    sp.SetClip(Rect(r.Left, cardsTop, r.Right, r.Bottom));
    var y := cardsTop-col.FScroll;
    var cw := r.Width-2*inner;
    var dropIndex := 0;
    for var i := 0 to FCards.Count-1 do begin
      var card := FCards[i];
      if card.Column <> c then continue;
      if FDragging and (card = FDragCard) then continue;
      // the gap where the dragged card would land
      if dropHere and (dropIndex = FDropIndex) then begin
        var gh := cardHeight(FDragCard, cw);
        sp.DashRoundRect(r.Left+inner, y, r.Right-inner, y+gh, radius, 1, 4, 3, accent);
        y += gh+spacing;
      end;
      inc(dropIndex);
      var h := cardHeight(card, cw);
      var cr := Rect(r.Left+inner, y, r.Right-inner, y+h);
      card.FRect := cr;
      if (cr.Bottom > cardsTop) and (cr.Top < r.Bottom) then begin
        var fill := cardBack;
        if (card = FHot) and hoverEnabled then fill := hoverColor(cardBack);
        var edge := if card = FSelected then (if Focused and ringEnabled then ringColor else ColorToRGB(clHighlight)) else border;
        paintRoundRect(sp, cr, radius, fill, edge, (if card = FSelected then 2 else 1));
        if FShowPriority and (card.Priority > 0) then
          sp.FillRoundRect(cr.Left+scaled(self, 3), cr.Top+scaled(self, 8), cr.Left+scaled(self, 6), cr.Bottom-scaled(self, 8), 1.5, PRIORITY_COLORS[card.Priority]);
        var tx := cr.Left+pad+(if FShowPriority and (card.Priority > 0) then scaled(self, 4) else 0);
        var clip := Rect(cr.Left, Max(cr.Top, cardsTop), cr.Right, Min(cr.Bottom, r.Bottom));
        addText(Rect(tx, cr.Top+pad, cr.Right-pad, cr.Top+pad+lh), card.Title, titleColor, true, false, false, clip);
        var bottomRow := cr.Bottom-pad-lh;
        if FShowText and (card.Text <> '') then begin
          var tb := Rect(tx, cr.Top+pad+lh+scaled(self, 2), cr.Right-pad, bottomRow-(if (FShowLabels and (card.LabelText <> '')) or (FShowAssignee and (card.Assignee <> '')) then scaled(self, 2) else -lh));
          if tb.Bottom > cr.Bottom-pad then tb.Bottom := cr.Bottom-pad;
          addText(tb, card.Text, textColor, false, false, false, clip);
        end;
        if (FShowLabels and (card.LabelText <> '')) or (FShowAssignee and (card.Assignee <> '')) then begin
          if FShowLabels and (card.LabelText <> '') then begin
            var lw := textWidthOf(Font, card.LabelText)+scaled(self, 10);
            var lr := Rect(tx, bottomRow, tx+lw, bottomRow+lh);
            var lc := pick(card.LabelColor, accent);
            paintPill(sp, lr, blend(lc, cardBack, 75), clNone);
            addText(lr, card.LabelText, lc, false, true, true, clip);
          end;
          if FShowAssignee and (card.Assignee <> '') then begin
            var aw := textWidthOf(Font, card.Assignee)+scaled(self, 8);
            var ar := Rect(cr.Right-pad-aw, bottomRow, cr.Right-pad, bottomRow+lh);
            paintPill(sp, ar, blend(cardBack, clBtnText, 10), clNone);
            addText(ar, card.Assignee, textColor, false, true, true, clip);
          end;
        end;
      end;
      y += h+spacing;
    end;
    if dropHere and (dropIndex = FDropIndex) then begin
      var gh := cardHeight(FDragCard, cw);
      sp.DashRoundRect(r.Left+inner, y, r.Right-inner, y+gh, radius, 1, 4, 3, accent);
    end;
    sp.ResetClip;
  end;
  // the dragged card follows the mouse, a little lifted
  if FDragging and (FDragCard <> nil) then begin
    var w := columnWidth-2*inner;
    var h := cardHeight(FDragCard, w);
    var dr := Rect(FDragPos.X-FDragStart.X, FDragPos.Y-FDragStart.Y, 0, 0);
    dr.Right := dr.Left+w;
    dr.Bottom := dr.Top+h;
    sp.FillRoundRect(dr.Left+2, dr.Top+3, dr.Right+2, dr.Bottom+3, radius, blend(board, clBlack, 20));
    paintRoundRect(sp, dr, radius, cardBack, ColorToRGB(clHighlight), 1);
    addText(Rect(dr.Left+pad, dr.Top+pad, dr.Right-pad, dr.Top+pad+lh), FDragCard.Title, titleColor, true, false, false, dr);
  end;
  sp.Flush;

  // the texts last, so the rasterizer never paints over them
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  for var job in FTexts do begin
    if job.r.IsEmpty or (job.r.Right <= job.r.Left) then continue;
    Canvas.Font.Style := if job.bold then Font.Style+[fsBold] else Font.Style;
    Canvas.Font.Color := job.color;
    var style := Canvas.TextStyle;
    style.Alignment := if job.center then taCenter else taLeftJustify;
    style.Layout := tlCenter;
    style.SingleLine := job.r.Height <= lh+scaled(self, 6);
    style.Wordbreak := not style.SingleLine;
    if not style.SingleLine then style.Layout := tlTop;
    style.Clipping := true;
    style.EndEllipsis := style.SingleLine;
    style.ShowPrefix := false;
    style.Opaque := false;
    var r := job.r;
    IntersectRect(r, r, job.clip);
    if r.IsEmpty then continue;
    Canvas.ClipRect := job.clip;
    Canvas.Clipping := true;
    Canvas.TextRect(job.r, job.r.Left, job.r.Top, job.text, style);
    Canvas.Clipping := false;
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
  if Assigned(FOnDrawCard) then
    for var i := 0 to FCards.Count-1 do begin
      var card := FCards[i];
      if card.FRect.Width = 0 then continue;
      var state: TDrawState := [];
      if card = FSelected then state += [dsSelected];
      if card = FHot then state += [dsHover];
      if card = FDragCard then state += [dsPressed];
      FOnDrawCard(self, Canvas, card.FRect, card, state);
    end;
end;

// -- input ----------------------

procedure TKanbanBoard.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  var card := cardAt(X, Y);
  if card <> nil then begin
    Selected := card;
    FDragCard := card;
    FDragStart := Point(X-card.FRect.Left, Y-card.FRect.Top);
    FDragPos := Point(X, Y);
    FDragging := false;
    if Assigned(FOnCardClick) then FOnCardClick(self, card);
    exit;
  end;
  var c := columnAt(X);
  if c >= 0 then begin
    var r: TRect;
    var top: integer;
    layoutColumn(c, r, top);
    if (Y >= r.Top) and (Y < top) and Assigned(FOnColumnClick) then FOnColumnClick(self, c);
  end;
end;

procedure TKanbanBoard.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if (FDragCard <> nil) and (ssLeft in Shift) then begin
    if not FDragging then begin
      // a few pixels tell a drag from a click
      if (Abs(X-FDragPos.X) < 4) and (Abs(Y-FDragPos.Y) < 4) then exit;
      if not FAllowDrag and not FAllowReorder then exit;
      FDragging := true;
    end;
    FDragPos := Point(X, Y);
    var column, index: integer;
    dropAt(X, Y, column, index);
    if (column >= 0) and (column <> FDragCard.Column) and not FAllowDrag then column := -1;
    if (column >= 0) and (column = FDragCard.Column) and not FAllowReorder then index := -1;
    if (column >= 0) and Assigned(FOnAllowMove) and (column <> FDragCard.Column) then begin
      var allow := true;
      FOnAllowMove(self, FDragCard, column, allow);
      if not allow then column := -1;
    end;
    FDropColumn := column;
    FDropIndex := index;
    Invalidate;
    exit;
  end;
  var hot := cardAt(X, Y);
  if hot <> FHot then begin
    FHot := hot;
    Invalidate;
  end;
end;

procedure TKanbanBoard.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if FDragging and (FDragCard <> nil) and (FDropColumn >= 0) then begin
    var from := FDragCard.Column;
    var card := FDragCard;
    var toIndex := FDropIndex;
    if (FDropColumn = from) and (toIndex < 0) then toIndex := -1;
    if (FDropColumn <> from) or (toIndex >= 0) then begin
      placeCard(card, FDropColumn, toIndex);
      if Assigned(FOnCardMove) then FOnCardMove(self, card, from, FDropColumn);
    end;
  end;
  FDragging := false;
  FDragCard := nil;
  FDropColumn := -1;
  Invalidate;
end;

procedure TKanbanBoard.MouseLeave;
begin
  inherited MouseLeave;
  if FHot = nil then exit;
  FHot := nil;
  Invalidate;
end;

procedure TKanbanBoard.DblClick;
begin
  inherited DblClick;
  var p := ScreenToClient(Mouse.CursorPos);
  var card := cardAt(p.X, p.Y);
  if (card <> nil) and Assigned(FOnCardDblClick) then FOnCardDblClick(self, card);
end;

function TKanbanBoard.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result then exit;
  var p := MousePos; // client coordinates
  var c := columnAt(p.X);
  if c < 0 then exit;
  var step := lineHeightOf(Font)*3;
  ScrollColumn(c, (if WheelDelta > 0 then -step else step));
  result := true;
end;

procedure TKanbanBoard.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FSelected = nil then begin
    if (Key in [VK_DOWN, VK_RIGHT, VK_SPACE]) and (FCards.Count > 0) then begin
      Selected := FCards[0];
      Key := 0;
    end;
    exit;
  end;
  var list := autofree TList.Create;
  CardsOf(FSelected.Column, list);
  var at := list.IndexOf(FSelected);
  match Key of
    VK_DOWN: if ssCtrl in Shift then MoveCard(FSelected, FSelected.Column, at+1)
             else if at+1 < list.Count then Selected := TKanbanCard(list[at+1]);
    VK_UP: if ssCtrl in Shift then MoveCard(FSelected, FSelected.Column, Max(at-1, 0))
           else if at > 0 then Selected := TKanbanCard(list[at-1]);
    VK_RIGHT: if FSelected.Column+1 < FColumns.Count then begin
        if ssCtrl in Shift then MoveCard(FSelected, FSelected.Column+1)
        else begin
          var next := autofree TList.Create;
          CardsOf(FSelected.Column+1, next);
          if next.Count > 0 then Selected := TKanbanCard(next[Min(at, next.Count-1)]);
        end;
      end;
    VK_LEFT: if FSelected.Column > 0 then begin
        if ssCtrl in Shift then MoveCard(FSelected, FSelected.Column-1)
        else begin
          var prev := autofree TList.Create;
          CardsOf(FSelected.Column-1, prev);
          if prev.Count > 0 then Selected := TKanbanCard(prev[Min(at, prev.Count-1)]);
        end;
      end;
    VK_RETURN: if Assigned(FOnCardDblClick) then FOnCardDblClick(self, FSelected);
  else
    exit;
  end;
  Key := 0;
end;

procedure TKanbanBoard.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TKanbanBoard.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TKanbanBoard.Resize;
begin
  inherited Resize;
  Invalidate;
end;

// -- properties ----------------------

procedure TKanbanBoard.setColumns(value: TKanbanColumns);
begin
  FColumns.Assign(value);
  Invalidate;
end;

procedure TKanbanBoard.setCards(value: TKanbanCards);
begin
  FCards.Assign(value);
  Invalidate;
end;

procedure TKanbanBoard.setSelected(value: TKanbanCard);
begin
  if FSelected = value then exit;
  FSelected := value;
  Invalidate;
  if Assigned(FOnSelect) then FOnSelect(self, value);
end;

function TKanbanBoard.getMetric(index: integer): integer;
begin
  result := match index of
    0: FColumnGap;
    1: FCardSpacing;
    2: FCardRadius;
    3: FHeaderHeight;
    4: FPadding;
  else
    FMinColumnWidth
  end;
end;

procedure TKanbanBoard.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FColumnGap := value;
    1: FCardSpacing := value;
    2: FCardRadius := value;
    3: FHeaderHeight := value;
    4: FPadding := value;
  else
    FMinColumnWidth := Max(value, 40);
  end;
  Invalidate;
end;

function TKanbanBoard.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowCounts;
    1: FShowText;
    2: FShowLabels;
    3: FShowAssignee;
    4: FShowPriority;
    5: FAllowDrag;
    6: FAllowReorder;
  else
    FFitColumns
  end;
end;

procedure TKanbanBoard.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowCounts := value;
    1: FShowText := value;
    2: FShowLabels := value;
    3: FShowAssignee := value;
    4: FShowPriority := value;
    5: FAllowDrag := value;
    6: FAllowReorder := value;
  else
    FFitColumns := value;
  end;
  Invalidate;
end;

function TKanbanBoard.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBoardColor;
    1: FColumnColor;
    2: FCardColor;
    3: FBorderColor;
    4: FTitleColor;
    5: FTextColor;
  else
    FHeaderColor
  end;
end;

procedure TKanbanBoard.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBoardColor := value;
    1: FColumnColor := value;
    2: FCardColor := value;
    3: FBorderColor := value;
    4: FTitleColor := value;
    5: FTextColor := value;
  else
    FHeaderColor := value;
  end;
  Invalidate;
end;

procedure TKanbanBoard.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
