{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ChatView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, LCLType, LMessages, ControlPaint, Avatar;

type
  TChatView = class;

  // where the bubbles of a participant go; sdAuto puts the own ones on the
  // side of OwnSide and everyone else on the other
  TChatSide = (sdAuto, sdLeft, sdRight);

  { TChatParticipant }

  // somebody in the conversation: the name the messages carry as their
  // sender, what to show for it, the color and the picture of their bubbles
  // and avatar. A sender without an entry gets everything from the name
  TChatParticipant = class(TCollectionItem)
  private
    FName, FCaption, FInitials: string;
    FColor, FTextColor: TColor;
    FPicture: TPicture;
    FIsSelf: boolean;
    FSide: TChatSide;
    FStatus: TAvatarStatus;
    FTag: PtrInt;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setPicture(value: TPicture);
    procedure pictureChanged(Sender: TObject);
    procedure setIsSelf(value: boolean);
    procedure setSide(value: TChatSide);
    procedure setStatus(value: TAvatarStatus);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    // the name shown: Caption, or Name
    function ShownName: string;
    function HasPicture: boolean;
  published
    // the key the messages name as their sender; case does not matter
    property Name: string index 0 read getText write setText;
    // shown instead of Name
    property Caption: string index 1 read getText write setText;
    // the letters of a generated avatar; empty takes the first letters of
    // the first and the last word of the name
    property Initials: string index 2 read getText write setText;
    // the color of the participant: their name, their generated avatar and
    // the tint of their bubbles; clDefault picks one from the name
    property Color: TColor index 0 read getPartColor write setPartColor default clDefault;
    // the text in their bubbles; clDefault contrasts with the bubble
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // the avatar
    property Picture: TPicture read FPicture write setPicture;
    // the messages of this participant are the own ones
    property IsSelf: boolean read FIsSelf write setIsSelf default false;
    property Side: TChatSide read FSide write setSide default sdAuto;
    // the presence dot on the avatar
    property Status: TAvatarStatus read FStatus write setStatus default stNone;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TChatParticipants }

  TChatParticipants = class(TOwnedCollection)
  private
    function getItem(index: integer): TChatParticipant;
    procedure setItem(index: integer; value: TChatParticipant);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(owner: TChatView);
    function Add: TChatParticipant;
    function AddParticipant(const name: string; isSelf: boolean = false): TChatParticipant;
    // the entry of a name, nil without one
    function Find(const name: string): TChatParticipant;
    property Items[index: integer]: TChatParticipant read getItem write setItem; default;
  end;

  // a message in a bubble, or a line of the system in the middle
  TChatMessageKind = (mkMessage, mkSystem);
  // the mark after the time of an own message: a clock, a check, two
  // checks, two checks in the accent, a failure mark
  TChatMessageStatus = (msNone, msSending, msSent, msDelivered, msRead, msFailed);

  { TChatMessage }

  TChatMessage = class(TCollectionItem)
  private
    FSender, FText: string;
    FTime: TDateTime;
    FKind: TChatMessageKind;
    FStatus: TChatMessageStatus;
    FEdited: boolean;
    FColor, FTextColor: TColor;
    FPicture: TPicture;
    FTag: PtrInt;
    // the layout, in the coordinates of the content
    FLines: array of string;
    FBubble, FAvatar, FNameRect, FTimeRect, FStatusRect, FSeparator, FPictureRect: TRect;
    FHasSeparator, FGroupFirst, FGroupLast, FShowName, FShowAvatar, FNameInside: boolean;
    FRight: boolean;
    FTop, FBottom: integer;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setTime(value: TDateTime);
    procedure setKind(value: TChatMessageKind);
    procedure setStatus(value: TChatMessageStatus);
    procedure setEdited(value: boolean);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setPicture(value: TPicture);
    procedure pictureChanged(Sender: TObject);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    function HasPicture: boolean;
    // the rectangle of the bubble in the content, after a layout
    property Bubble: TRect read FBubble;
  published
    // the name of the participant who wrote it
    property Sender: string index 0 read getText write setText;
    property Text: string index 1 read getText write setText;
    property Time: TDateTime read FTime write setTime;
    property Kind: TChatMessageKind read FKind write setKind default mkMessage;
    property Status: TChatMessageStatus read FStatus write setStatus default msNone;
    // shows the edited caption after the time
    property Edited: boolean read FEdited write setEdited default false;
    // the bubble of this one message; clDefault takes the participant's
    property Color: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // an image in the bubble, above the text
    property Picture: TPicture read FPicture write setPicture;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TChatMessages }

  TChatMessages = class(TOwnedCollection)
  private
    function getItem(index: integer): TChatMessage;
    procedure setItem(index: integer; value: TChatMessage);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(owner: TChatView);
    function Add: TChatMessage;
    property Items[index: integer]: TChatMessage read getItem write setItem; default;
  end;

  // the shape of a bubble: rounded corners, rounded with a tail toward the
  // speaker on the last of their messages in a row, square, a pill
  TChatBubbleShape = (shRounded, shTailed, shSquare, shPill);

  { TChatBubbles }

  TChatBubbles = class(TPersistent)
  private
    FOwner: TChatView;
    FShape: TChatBubbleShape;
    FCornerRadius, FPadding, FSpacing, FGroupSpacing, FMaxWidth, FMinWidth, FBorderWidth, FTailSize, FGroupInterval, FLineSpacing, FMaxPictureHeight: integer;
    FGroupMessages: boolean;
    procedure setShape(value: TChatBubbleShape);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setGroupMessages(value: boolean);
  public
    constructor Create(owner: TChatView);
    procedure Assign(Source: TPersistent); override;
  published
    property Shape: TChatBubbleShape read FShape write setShape default shTailed;
    property CornerRadius: integer index 0 read getMetric write setMetric default 14;
    // between the edge of a bubble and its text
    property Padding: integer index 1 read getMetric write setMetric default 10;
    // between the messages of different senders
    property Spacing: integer index 2 read getMetric write setMetric default 10;
    // between the messages of one sender in a row
    property GroupSpacing: integer index 3 read getMetric write setMetric default 3;
    // percent of the room a bubble may take
    property MaxWidth: integer index 4 read getMetric write setMetric default 70;
    property MinWidth: integer index 5 read getMetric write setMetric default 0;
    property BorderWidth: integer index 6 read getMetric write setMetric default 0;
    property TailSize: integer index 7 read getMetric write setMetric default 7;
    // minutes between two messages of one sender that still make a row
    property GroupInterval: integer index 8 read getMetric write setMetric default 5;
    property LineSpacing: integer index 9 read getMetric write setMetric default 0;
    // a picture in a message is scaled down to this height
    property MaxPictureHeight: integer index 10 read getMetric write setMetric default 200;
    // messages of one sender in a row share the name and the avatar and
    // sit closer, with smaller corners between them
    property GroupMessages: boolean read FGroupMessages write setGroupMessages default true;
  end;

  // vsAuto shows the part for the other participants of a group chat and
  // hides it in a conversation of two
  TChatVisibility = (vsAuto, vsAlways, vsNever);
  // what an avatar shows: the picture of the participant, the initials on
  // their color, or the picture when there is one and the initials otherwise
  TChatAvatarSource = (avPicture, avGenerated, avPictureOrGenerated);
  // the avatar sits at the first or at the last bubble of a row
  TChatAvatarPlacement = (apTop, apBottom);

  { TChatAvatars }

  TChatAvatars = class(TPersistent)
  private
    FOwner: TChatView;
    FVisibility: TChatVisibility;
    FSource: TChatAvatarSource;
    FShape: TAvatarShape;
    FPlacement: TChatAvatarPlacement;
    FSize, FSpacing, FBorderWidth: integer;
    FShowForSelf, FShowStatus: boolean;
    procedure setVisibility(value: TChatVisibility);
    procedure setSource(value: TChatAvatarSource);
    procedure setShape(value: TAvatarShape);
    procedure setPlacement(value: TChatAvatarPlacement);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
  public
    constructor Create(owner: TChatView);
    procedure Assign(Source: TPersistent); override;
  published
    property Visibility: TChatVisibility read FVisibility write setVisibility default vsAuto;
    // the own messages get an avatar too
    property ShowForSelf: boolean index 0 read getFlag write setFlag default false;
    // the presence dot of the participant on the avatar
    property ShowStatus: boolean index 1 read getFlag write setFlag default false;
    property Source: TChatAvatarSource read FSource write setSource default avPictureOrGenerated;
    property Shape: TAvatarShape read FShape write setShape default asCircle;
    property Placement: TChatAvatarPlacement read FPlacement write setPlacement default apBottom;
    property Size: integer index 0 read getMetric write setMetric default 32;
    // between the avatar and the bubble
    property Spacing: integer index 1 read getMetric write setMetric default 8;
    // a ring in the color of the participant
    property BorderWidth: integer index 2 read getMetric write setMetric default 0;
  end;

  // the time inside the bubble after the last line, beside the bubble at
  // its bottom, or under it
  TChatTimePlacement = (tmInside, tmBeside, tmBelow);
  // the name above the bubble or on its first line
  TChatNamePlacement = (npAbove, npInside);

  { TChatLabels }

  // the texts around the bubbles: names, times, marks, the separators
  // between days
  TChatLabels = class(TPersistent)
  private
    FOwner: TChatView;
    FNames: TChatVisibility;
    FNamePlacement: TChatNamePlacement;
    FTimePlacement: TChatTimePlacement;
    FShowTime, FShowStatus, FShowEdited, FDateSeparators, FSeparatorLines, FTimeHints: boolean;
    FTimeFormat, FDateFormat, FEditedCaption, FTodayCaption, FYesterdayCaption, FEmptyText, FTypingCaption: string;
    procedure setNames(value: TChatVisibility);
    procedure setNamePlacement(value: TChatNamePlacement);
    procedure setTimePlacement(value: TChatTimePlacement);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
  public
    constructor Create(owner: TChatView);
    procedure Assign(Source: TPersistent); override;
  published
    property Names: TChatVisibility read FNames write setNames default vsAuto;
    property NamePlacement: TChatNamePlacement read FNamePlacement write setNamePlacement default npAbove;
    property ShowTime: boolean index 0 read getFlag write setFlag default true;
    // the mark of the status after the time of an own message
    property ShowStatus: boolean index 1 read getFlag write setFlag default true;
    property ShowEdited: boolean index 2 read getFlag write setFlag default true;
    // a line with the day between the messages of different days
    property DateSeparators: boolean index 3 read getFlag write setFlag default true;
    // the separator runs a line to each edge
    property SeparatorLines: boolean index 4 read getFlag write setFlag default true;
    // the hint over a bubble names the sender and the full time
    property TimeHints: boolean index 5 read getFlag write setFlag default true;
    property TimePlacement: TChatTimePlacement read FTimePlacement write setTimePlacement default tmInside;
    // FormatDateTime patterns
    property TimeFormat: string index 0 read getText write setText;
    property DateFormat: string index 1 read getText write setText;
    property EditedCaption: string index 2 read getText write setText;
    // the separators of today and yesterday; empty shows the date
    property TodayCaption: string index 3 read getText write setText;
    property YesterdayCaption: string index 4 read getText write setText;
    // shown in the middle of an empty chat
    property EmptyText: string index 5 read getText write setText;
    // beside the dots of the typing bubble, %s is the name
    property TypingCaption: string index 6 read getText write setText;
  end;

  { TChatColors }

  // clDefault takes the colors of the theme
  TChatColors = class(TPersistent)
  private
    FOwner: TChatView;
    FAuto: boolean;
    FAutoStrength: integer;
    FColors: array[0..11] of TColor;
    procedure setAuto(value: boolean);
    procedure setAutoStrength(value: integer);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
  public
    constructor Create(owner: TChatView);
    procedure Assign(Source: TPersistent); override;
    property Chat: TChatView read FOwner;
  published
    // every participant gets the color their name picks; a group chat
    // always does this, a conversation of two uses OwnBubble and
    // OtherBubble without it
    property Auto: boolean read FAuto write setAuto default false;
    // percent of the color of a participant in the fill of their bubbles,
    // 100 for the full color
    property AutoStrength: integer read FAutoStrength write setAutoStrength default 25;
    property OwnBubble: TColor index 0 read getPartColor write setPartColor default clDefault;
    property OtherBubble: TColor index 1 read getPartColor write setPartColor default clDefault;
    property OwnText: TColor index 2 read getPartColor write setPartColor default clDefault;
    property OtherText: TColor index 3 read getPartColor write setPartColor default clDefault;
    // the names above the bubbles; clDefault takes the color of each participant
    property Names: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Time: TColor index 5 read getPartColor write setPartColor default clDefault;
    property Border: TColor index 6 read getPartColor write setPartColor default clDefault;
    // the pill of a system message
    property System: TColor index 7 read getPartColor write setPartColor default clDefault;
    property SystemText: TColor index 8 read getPartColor write setPartColor default clDefault;
    property Separator: TColor index 9 read getPartColor write setPartColor default clDefault;
    property SeparatorText: TColor index 10 read getPartColor write setPartColor default clDefault;
    // the outline of the selected bubble
    property Selection: TColor index 11 read getPartColor write setPartColor default clDefault;
  end;

  // a conversation of two, or a group where everyone has a color
  TChatMode = (cmDirect, cmGroup);
  TChatMessageEvent = procedure(Sender: TObject; msg: TChatMessage) of object;
  TChatParticipantEvent = procedure(Sender: TObject; participant: TChatParticipant) of object;

  { TChatView }

  // a conversation as bubbles under each other: the own ones on one side,
  // the others on the other with a name, an avatar and a time, days apart by
  // a separator, with a typing bubble at the end. A conversation of two
  // paints two colors; a group gives every participant the color of their
  // name, which the Participants override
  TChatView = class(TScrollingWinControl)
  private
    FMode: TChatMode;
    FOwnName, FTyping: string;
    FOwnSide: TChatSide;
    FParticipants: TChatParticipants;
    FMessages: TChatMessages;
    FBubbles: TChatBubbles;
    FAvatars: TChatAvatars;
    FLabels: TChatLabels;
    FColors: TChatColors;
    FMaxMessages, FPadding, FSelected, FHot: integer;
    FHotAvatar: boolean;
    FAutoScroll: boolean;
    FLanguage: TFormatLanguage;
    FAntialiasing: TAntialiasSetting;
    FNameFont, FTimeFont, FAvatarFont: TFont;
    FTimer: TTimer;
    FTypingPhase, FTypingRight: integer;
    FTypingRect: TRect;
    FLaidWidth, FContentHeight: integer;
    FLayoutDirty: boolean;
    FMousePos: TPoint;
    FOnMessageClick, FOnMessageDblClick, FOnMessageAdded, FOnSelectionChange: TChatMessageEvent;
    FOnAvatarClick: TChatParticipantEvent;
    FOnDrawBubble, FOnDrawAvatar: TCustomDrawEvent;
    procedure setMode(value: TChatMode);
    procedure setOwnName(const value: string);
    procedure setOwnSide(value: TChatSide);
    procedure setTyping(const value: string);
    procedure setParticipants(value: TChatParticipants);
    procedure setMessages(value: TChatMessages);
    procedure setBubbles(value: TChatBubbles);
    procedure setAvatars(value: TChatAvatars);
    procedure setLabels(value: TChatLabels);
    procedure setColors(value: TChatColors);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setSelected(value: integer);
    procedure setFollow(value: boolean);
    procedure setLanguage(value: TFormatLanguage);
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure settingsChanged;
    procedure messagesChanged;
    procedure participantsChanged;
    procedure invalidateLayout;
    procedure ensureLayout;
    procedure measure;
    procedure updateRange;
    procedure updateFonts;
    procedure trimMessages;
    procedure tick(Sender: TObject);
    function selfName: string;
    function autoIndexOf(const name: string): integer;
    function shownNameOf(const name: string): string;
    function initialsOf(const name: string): string;
    function isRight(msg: TChatMessage): boolean;
    function avatarWanted(msg: TChatMessage): boolean;
    function nameWanted(msg: TChatMessage): boolean;
    function stampOf(msg: TChatMessage): string;
    function statusWidth(msg: TChatMessage): integer;
    function wrap(font: TFont; const text: string; maxWidth: integer): TStringArray;
    function widest(font: TFont; const lines: TStringArray): integer;
    function separatorText(day: TDateTime): string;
    function messageAt(x, y: integer; out onAvatar: boolean): integer;
    procedure paintAvatar(sp: TSmoothPaint; const r: TRect; const name: string; back: TColor; var texts: TStringList);
    procedure paintStatus(sp: TSmoothPaint; msg: TChatMessage; fill, txt: TColor);
    function bubbleOutlineOf(msg: TChatMessage): TOutline;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoOnResize; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure FontChanged(Sender: TObject); override;
    procedure WMVScroll(var Message: TLMVScroll); message LM_VSCROLL;
    procedure CMHintShow(var Message: TLMessage); message CM_HINTSHOW;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // a message from a sender, now
    function Add(const sender, text: string): TChatMessage;
    function AddAt(const sender, text: string; time: TDateTime): TChatMessage;
    // a line of the system in the middle, like "Alice joined"
    function AddSystem(const text: string): TChatMessage;
    procedure Clear;
    // the entry of a sender, nil without one
    function ParticipantOf(const name: string): TChatParticipant;
    // the entry of a sender, made when there is none
    function EnsureParticipant(const name: string): TChatParticipant;
    // the sender is the own side: its participant has IsSelf, or it is OwnName
    function IsSelf(const name: string): boolean;
    // the color of a participant: their own, or the one their name picks
    function NameColorOf(const name: string): TColor;
    // the fill of the bubbles of a message
    function BubbleColorOf(msg: TChatMessage): TColor;
    function TextColorOf(msg: TChatMessage): TColor;
    // the message under a point of the client area, nil between them
    function MessageAt(x, y: integer): TChatMessage;
    function SelectedMessage: TChatMessage;
    procedure ScrollToEnd;
    procedure ScrollToMessage(index: integer);
    // the conversation as lines of time, name and text
    function AsText: string;
    procedure CopyToClipboard;
  published
    property Mode: TChatMode read FMode write setMode default cmDirect;
    // the sender whose messages are the own ones when no participant has
    // IsSelf
    property OwnName: string read FOwnName write setOwnName;
    // the side of the own messages; sdAuto is the right
    property OwnSide: TChatSide read FOwnSide write setOwnSide default sdAuto;
    property Participants: TChatParticipants read FParticipants write setParticipants;
    property Messages: TChatMessages read FMessages write setMessages;
    property Bubbles: TChatBubbles read FBubbles write setBubbles;
    property Avatars: TChatAvatars read FAvatars write setAvatars;
    property Labels: TChatLabels read FLabels write setLabels;
    property Colors: TChatColors read FColors write setColors;
    // the name of the one typing; a bubble of moving dots shows at the
    // end while it is not empty
    property Typing: string read FTyping write setTyping;
    // the view follows a new message
    property AutoScroll: boolean read FAutoScroll write setFollow default true;
    // the oldest messages go when there are more, 0 for no limit
    property MaxMessages: integer index 0 read getMetric write setMetric default 0;
    // around the whole conversation
    property Padding: integer index 1 read getMetric write setMetric default 8;
    property SelectedIndex: integer read FSelected write setSelected default -1;
    // the names and separators of dates and times: those of the locale of
    // the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnMessageClick: TChatMessageEvent read FOnMessageClick write FOnMessageClick;
    property OnMessageDblClick: TChatMessageEvent read FOnMessageDblClick write FOnMessageDblClick;
    property OnMessageAdded: TChatMessageEvent read FOnMessageAdded write FOnMessageAdded;
    property OnSelectionChange: TChatMessageEvent read FOnSelectionChange write FOnSelectionChange;
    // a click on an avatar; the participant is made for a sender without one
    property OnAvatarClick: TChatParticipantEvent read FOnAvatarClick write FOnAvatarClick;
    // paints over the bubble of a message, text included, in its rectangle:
    // index is the message, dsSelected and dsHover tell its state
    property OnDrawBubble: TCustomDrawEvent read FOnDrawBubble write FOnDrawBubble;
    // paints over the avatar of a message, in its square
    property OnDrawAvatar: TCustomDrawEvent read FOnDrawAvatar write FOnDrawAvatar;
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
  Math, LazUTF8, LCLIntf, Clipbrd;

type
  // a text to paint after the shapes
  TChatText = class
    x, y, limit: integer;
    s: string;
    font: TFont;
    color: TColor;
  end;

procedure push(var arr: TStringArray; const s: string);
begin
  SetLength(arr, length(arr)+1);
  arr[high(arr)] := s;
end;

{ TChatParticipant }

constructor TChatParticipant.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clDefault;
  FTextColor := clDefault;
  FPicture := TPicture.Create;
  FPicture.OnChange := @pictureChanged;
end;

destructor TChatParticipant.Destroy;
begin
  FPicture.Free;
  inherited Destroy;
end;

procedure TChatParticipant.Assign(Source: TPersistent);
begin
  if Source is TChatParticipant then begin
    var src := TChatParticipant(Source);
    FName := src.FName;
    FCaption := src.FCaption;
    FInitials := src.FInitials;
    FColor := src.FColor;
    FTextColor := src.FTextColor;
    FPicture.Assign(src.FPicture);
    FIsSelf := src.FIsSelf;
    FSide := src.FSide;
    FStatus := src.FStatus;
    FTag := src.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TChatParticipant.GetDisplayName: string;
begin
  result := if FName <> '' then FName else inherited GetDisplayName;
end;

function TChatParticipant.ShownName: string;
begin
  result := if FCaption <> '' then FCaption else FName;
end;

function TChatParticipant.HasPicture: boolean;
begin
  result := (FPicture.Graphic <> nil) and not FPicture.Graphic.Empty;
end;

function TChatParticipant.getText(index: integer): string;
begin
  result := match index of
    0: FName;
    1: FCaption;
  else
    FInitials
  end;
end;

procedure TChatParticipant.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FName := value;
    1: FCaption := value;
  else
    FInitials := value;
  end;
  Changed(false);
end;

function TChatParticipant.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FColor else FTextColor;
end;

procedure TChatParticipant.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FColor := value else FTextColor := value;
  Changed(false);
end;

procedure TChatParticipant.setPicture(value: TPicture);
begin
  FPicture.Assign(value);
end;

procedure TChatParticipant.pictureChanged(Sender: TObject);
begin
  Changed(false);
end;

procedure TChatParticipant.setIsSelf(value: boolean);
begin
  if FIsSelf = value then exit;
  FIsSelf := value;
  Changed(false);
end;

procedure TChatParticipant.setSide(value: TChatSide);
begin
  if FSide = value then exit;
  FSide := value;
  Changed(false);
end;

procedure TChatParticipant.setStatus(value: TAvatarStatus);
begin
  if FStatus = value then exit;
  FStatus := value;
  Changed(false);
end;

{ TChatParticipants }

constructor TChatParticipants.Create(owner: TChatView);
begin
  inherited Create(owner, TChatParticipant);
end;

function TChatParticipants.getItem(index: integer): TChatParticipant;
begin
  result := TChatParticipant(inherited Items[index]);
end;

procedure TChatParticipants.setItem(index: integer; value: TChatParticipant);
begin
  inherited Items[index] := value;
end;

procedure TChatParticipants.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TChatView then TChatView(Owner).participantsChanged;
end;

function TChatParticipants.Add: TChatParticipant;
begin
  result := TChatParticipant(inherited Add);
end;

function TChatParticipants.AddParticipant(const name: string; isSelf: boolean): TChatParticipant;
begin
  result := Add;
  result.FName := name;
  result.FIsSelf := isSelf;
  result.Changed(false);
end;

function TChatParticipants.Find(const name: string): TChatParticipant;
begin
  for var i := 0 to Count-1 do
    if SameText(Items[i].FName, name) then exit(Items[i]);
  result := nil;
end;

{ TChatMessage }

constructor TChatMessage.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FTime := Now;
  FColor := clDefault;
  FTextColor := clDefault;
  FPicture := TPicture.Create;
  FPicture.OnChange := @pictureChanged;
end;

destructor TChatMessage.Destroy;
begin
  FPicture.Free;
  inherited Destroy;
end;

procedure TChatMessage.Assign(Source: TPersistent);
begin
  if Source is TChatMessage then begin
    var src := TChatMessage(Source);
    FSender := src.FSender;
    FText := src.FText;
    FTime := src.FTime;
    FKind := src.FKind;
    FStatus := src.FStatus;
    FEdited := src.FEdited;
    FColor := src.FColor;
    FTextColor := src.FTextColor;
    FPicture.Assign(src.FPicture);
    FTag := src.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TChatMessage.GetDisplayName: string;
begin
  var head := FText.Split([#10])[0];
  if UTF8Length(head) > 24 then head := UTF8Copy(head, 1, 24)+'...';
  result := if FKind = mkSystem then '* '+head
    else if FSender <> '' then FSender+': '+head
    else if head <> '' then head
    else inherited GetDisplayName;
end;

function TChatMessage.HasPicture: boolean;
begin
  result := (FPicture.Graphic <> nil) and not FPicture.Graphic.Empty;
end;

function TChatMessage.getText(index: integer): string;
begin
  result := if index = 0 then FSender else FText;
end;

procedure TChatMessage.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  if index = 0 then FSender := value else FText := value;
  Changed(false);
end;

procedure TChatMessage.setTime(value: TDateTime);
begin
  if FTime = value then exit;
  FTime := value;
  Changed(false);
end;

procedure TChatMessage.setKind(value: TChatMessageKind);
begin
  if FKind = value then exit;
  FKind := value;
  Changed(false);
end;

procedure TChatMessage.setStatus(value: TChatMessageStatus);
begin
  if FStatus = value then exit;
  FStatus := value;
  Changed(false);
end;

procedure TChatMessage.setEdited(value: boolean);
begin
  if FEdited = value then exit;
  FEdited := value;
  Changed(false);
end;

function TChatMessage.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FColor else FTextColor;
end;

procedure TChatMessage.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FColor := value else FTextColor := value;
  Changed(false);
end;

procedure TChatMessage.setPicture(value: TPicture);
begin
  FPicture.Assign(value);
end;

procedure TChatMessage.pictureChanged(Sender: TObject);
begin
  Changed(false);
end;

{ TChatMessages }

constructor TChatMessages.Create(owner: TChatView);
begin
  inherited Create(owner, TChatMessage);
end;

function TChatMessages.getItem(index: integer): TChatMessage;
begin
  result := TChatMessage(inherited Items[index]);
end;

procedure TChatMessages.setItem(index: integer; value: TChatMessage);
begin
  inherited Items[index] := value;
end;

procedure TChatMessages.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TChatView then TChatView(Owner).messagesChanged;
end;

function TChatMessages.Add: TChatMessage;
begin
  result := TChatMessage(inherited Add);
end;

{ TChatBubbles }

constructor TChatBubbles.Create(owner: TChatView);
begin
  inherited Create;
  FOwner := owner;
  FShape := shTailed;
  FCornerRadius := 14;
  FPadding := 10;
  FSpacing := 10;
  FGroupSpacing := 3;
  FMaxWidth := 70;
  FTailSize := 7;
  FGroupInterval := 5;
  FMaxPictureHeight := 200;
  FGroupMessages := true;
end;

procedure TChatBubbles.Assign(Source: TPersistent);
begin
  if Source is TChatBubbles then begin
    var src := TChatBubbles(Source);
    FShape := src.FShape;
    FCornerRadius := src.FCornerRadius;
    FPadding := src.FPadding;
    FSpacing := src.FSpacing;
    FGroupSpacing := src.FGroupSpacing;
    FMaxWidth := src.FMaxWidth;
    FMinWidth := src.FMinWidth;
    FBorderWidth := src.FBorderWidth;
    FTailSize := src.FTailSize;
    FGroupInterval := src.FGroupInterval;
    FLineSpacing := src.FLineSpacing;
    FMaxPictureHeight := src.FMaxPictureHeight;
    FGroupMessages := src.FGroupMessages;
    FOwner.settingsChanged;
  end else inherited Assign(Source);
end;

procedure TChatBubbles.setShape(value: TChatBubbleShape);
begin
  if FShape = value then exit;
  FShape := value;
  FOwner.settingsChanged;
end;

function TChatBubbles.getMetric(index: integer): integer;
begin
  result := match index of
    0: FCornerRadius;
    1: FPadding;
    2: FSpacing;
    3: FGroupSpacing;
    4: FMaxWidth;
    5: FMinWidth;
    6: FBorderWidth;
    7: FTailSize;
    8: FGroupInterval;
    9: FLineSpacing;
  else
    FMaxPictureHeight
  end;
end;

procedure TChatBubbles.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 4 then value := Max(Min(value, 100), 10);
  if getMetric(index) = value then exit;
  match index of
    0: FCornerRadius := value;
    1: FPadding := value;
    2: FSpacing := value;
    3: FGroupSpacing := value;
    4: FMaxWidth := value;
    5: FMinWidth := value;
    6: FBorderWidth := value;
    7: FTailSize := value;
    8: FGroupInterval := value;
    9: FLineSpacing := value;
  else
    FMaxPictureHeight := value;
  end;
  FOwner.settingsChanged;
end;

procedure TChatBubbles.setGroupMessages(value: boolean);
begin
  if FGroupMessages = value then exit;
  FGroupMessages := value;
  FOwner.settingsChanged;
end;

{ TChatAvatars }

constructor TChatAvatars.Create(owner: TChatView);
begin
  inherited Create;
  FOwner := owner;
  FSource := avPictureOrGenerated;
  FPlacement := apBottom;
  FSize := 32;
  FSpacing := 8;
end;

procedure TChatAvatars.Assign(Source: TPersistent);
begin
  if Source is TChatAvatars then begin
    var src := TChatAvatars(Source);
    FVisibility := src.FVisibility;
    FSource := src.FSource;
    FShape := src.FShape;
    FPlacement := src.FPlacement;
    FSize := src.FSize;
    FSpacing := src.FSpacing;
    FBorderWidth := src.FBorderWidth;
    FShowForSelf := src.FShowForSelf;
    FShowStatus := src.FShowStatus;
    FOwner.settingsChanged;
  end else inherited Assign(Source);
end;

procedure TChatAvatars.setVisibility(value: TChatVisibility);
begin
  if FVisibility = value then exit;
  FVisibility := value;
  FOwner.settingsChanged;
end;

procedure TChatAvatars.setSource(value: TChatAvatarSource);
begin
  if FSource = value then exit;
  FSource := value;
  FOwner.settingsChanged;
end;

procedure TChatAvatars.setShape(value: TAvatarShape);
begin
  if FShape = value then exit;
  FShape := value;
  FOwner.settingsChanged;
end;

procedure TChatAvatars.setPlacement(value: TChatAvatarPlacement);
begin
  if FPlacement = value then exit;
  FPlacement := value;
  FOwner.settingsChanged;
end;

function TChatAvatars.getMetric(index: integer): integer;
begin
  result := match index of
    0: FSize;
    1: FSpacing;
  else
    FBorderWidth
  end;
end;

procedure TChatAvatars.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if (index = 0) and (value < 8) then value := 8;
  if getMetric(index) = value then exit;
  match index of
    0: FSize := value;
    1: FSpacing := value;
  else
    FBorderWidth := value;
  end;
  FOwner.settingsChanged;
end;

function TChatAvatars.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FShowForSelf else FShowStatus;
end;

procedure TChatAvatars.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FShowForSelf := value else FShowStatus := value;
  FOwner.settingsChanged;
end;

{ TChatLabels }

constructor TChatLabels.Create(owner: TChatView);
begin
  inherited Create;
  FOwner := owner;
  FShowTime := true;
  FShowStatus := true;
  FShowEdited := true;
  FDateSeparators := true;
  FSeparatorLines := true;
  FTimeHints := true;
  FTimeFormat := 'hh:nn';
  FDateFormat := 'dddd, mmmm d';
  FEditedCaption := '(edited)';
  FTodayCaption := 'Today';
  FYesterdayCaption := 'Yesterday';
  FEmptyText := 'No messages yet';
end;

procedure TChatLabels.Assign(Source: TPersistent);
begin
  if Source is TChatLabels then begin
    var src := TChatLabels(Source);
    FNames := src.FNames;
    FNamePlacement := src.FNamePlacement;
    FTimePlacement := src.FTimePlacement;
    FShowTime := src.FShowTime;
    FShowStatus := src.FShowStatus;
    FShowEdited := src.FShowEdited;
    FDateSeparators := src.FDateSeparators;
    FSeparatorLines := src.FSeparatorLines;
    FTimeHints := src.FTimeHints;
    FTimeFormat := src.FTimeFormat;
    FDateFormat := src.FDateFormat;
    FEditedCaption := src.FEditedCaption;
    FTodayCaption := src.FTodayCaption;
    FYesterdayCaption := src.FYesterdayCaption;
    FEmptyText := src.FEmptyText;
    FTypingCaption := src.FTypingCaption;
    FOwner.settingsChanged;
  end else inherited Assign(Source);
end;

procedure TChatLabels.setNames(value: TChatVisibility);
begin
  if FNames = value then exit;
  FNames := value;
  FOwner.settingsChanged;
end;

procedure TChatLabels.setNamePlacement(value: TChatNamePlacement);
begin
  if FNamePlacement = value then exit;
  FNamePlacement := value;
  FOwner.settingsChanged;
end;

procedure TChatLabels.setTimePlacement(value: TChatTimePlacement);
begin
  if FTimePlacement = value then exit;
  FTimePlacement := value;
  FOwner.settingsChanged;
end;

function TChatLabels.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowTime;
    1: FShowStatus;
    2: FShowEdited;
    3: FDateSeparators;
    4: FSeparatorLines;
  else
    FTimeHints
  end;
end;

procedure TChatLabels.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowTime := value;
    1: FShowStatus := value;
    2: FShowEdited := value;
    3: FDateSeparators := value;
    4: FSeparatorLines := value;
  else
    FTimeHints := value;
  end;
  FOwner.settingsChanged;
end;

function TChatLabels.getText(index: integer): string;
begin
  result := match index of
    0: FTimeFormat;
    1: FDateFormat;
    2: FEditedCaption;
    3: FTodayCaption;
    4: FYesterdayCaption;
    5: FEmptyText;
  else
    FTypingCaption
  end;
end;

procedure TChatLabels.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FTimeFormat := value;
    1: FDateFormat := value;
    2: FEditedCaption := value;
    3: FTodayCaption := value;
    4: FYesterdayCaption := value;
    5: FEmptyText := value;
  else
    FTypingCaption := value;
  end;
  FOwner.settingsChanged;
end;

{ TChatColors }

constructor TChatColors.Create(owner: TChatView);
begin
  inherited Create;
  FOwner := owner;
  FAutoStrength := 25;
  for var i := low(FColors) to high(FColors) do FColors[i] := clDefault;
end;

procedure TChatColors.Assign(Source: TPersistent);
begin
  if Source is TChatColors then begin
    var src := TChatColors(Source);
    FAuto := src.FAuto or (FOwner.FMode = cmGroup);
    FAutoStrength := src.FAutoStrength;
    FColors := src.FColors;
    FOwner.settingsChanged;
  end else inherited Assign(Source);
end;

procedure TChatColors.setAuto(value: boolean);
begin
  // a group chat keeps it on
  if FOwner.FMode = cmGroup then value := true;
  if FAuto = value then exit;
  FAuto := value;
  FOwner.settingsChanged;
end;

procedure TChatColors.setAutoStrength(value: integer);
begin
  value := Max(Min(value, 100), 0);
  if FAutoStrength = value then exit;
  FAutoStrength := value;
  FOwner.settingsChanged;
end;

function TChatColors.getPartColor(index: integer): TColor;
begin
  result := FColors[index];
end;

procedure TChatColors.setPartColor(index: integer; value: TColor);
begin
  if FColors[index] = value then exit;
  FColors[index] := value;
  FOwner.settingsChanged;
end;

{ TChatView }

constructor TChatView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FParticipants := TChatParticipants.Create(self);
  FMessages := TChatMessages.Create(self);
  FBubbles := TChatBubbles.Create(self);
  FAvatars := TChatAvatars.Create(self);
  FLabels := TChatLabels.Create(self);
  FColors := TChatColors.Create(self);
  FNameFont := TFont.Create;
  FTimeFont := TFont.Create;
  FAvatarFont := TFont.Create;
  FPadding := 8;
  FSelected := -1;
  FHot := -1;
  FAutoScroll := true;
  FLayoutDirty := true;
  Color := clWindow;
  BorderStyle := bsNone;
  TabStop := true;
  DoubleBuffered := true;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Visible := false;
  ParentShowHint := false;
  ShowHint := true;
  Hint := 'message'; // replaced per bubble when the hint shows
  FTimer := TTimer.Create(self);
  FTimer.Interval := 400;
  FTimer.Enabled := false;
  FTimer.OnTimer := @tick;
  updateFonts;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TChatView.Destroy;
begin
  FMessages.Free;
  FParticipants.Free;
  FBubbles.Free;
  FAvatars.Free;
  FLabels.Free;
  FColors.Free;
  FNameFont.Free;
  FTimeFont.Free;
  FAvatarFont.Free;
  inherited Destroy;
end;

class function TChatView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 320;
  result.cy := 240;
end;

procedure TChatView.Loaded;
begin
  inherited Loaded;
  if FMode = cmGroup then FColors.FAuto := true;
  updateFonts;
  invalidateLayout;
end;

// -- messages ----------------------

function TChatView.Add(const sender, text: string): TChatMessage;
begin
  result := AddAt(sender, text, Now);
end;

function TChatView.AddAt(const sender, text: string; time: TDateTime): TChatMessage;
begin
  FMessages.BeginUpdate;
  try
    result := FMessages.Add;
    result.FSender := sender;
    result.FText := text;
    result.FTime := time;
    trimMessages;
  finally
    FMessages.EndUpdate;
  end;
  if Assigned(FOnMessageAdded) then FOnMessageAdded(self, result);
  if FAutoScroll then ScrollToEnd;
end;

function TChatView.AddSystem(const text: string): TChatMessage;
begin
  FMessages.BeginUpdate;
  try
    result := FMessages.Add;
    result.FText := text;
    result.FKind := mkSystem;
    trimMessages;
  finally
    FMessages.EndUpdate;
  end;
  if Assigned(FOnMessageAdded) then FOnMessageAdded(self, result);
  if FAutoScroll then ScrollToEnd;
end;

procedure TChatView.trimMessages;
begin
  if FMaxMessages <= 0 then exit;
  while FMessages.Count > FMaxMessages do begin
    FMessages.Delete(0);
    if FSelected >= 0 then dec(FSelected);
  end;
end;

procedure TChatView.Clear;
begin
  FSelected := -1;
  FHot := -1;
  FMessages.Clear;
end;

function TChatView.ParticipantOf(const name: string): TChatParticipant;
begin
  result := FParticipants.Find(name);
end;

function TChatView.EnsureParticipant(const name: string): TChatParticipant;
begin
  result := FParticipants.Find(name);
  if result = nil then result := FParticipants.AddParticipant(name, (FOwnName <> '') and SameText(name, FOwnName));
end;

function TChatView.selfName: string;
begin
  if FOwnName <> '' then exit(FOwnName);
  for var i := 0 to FParticipants.Count-1 do
    if FParticipants[i].FIsSelf then exit(FParticipants[i].FName);
  result := '';
end;

function TChatView.IsSelf(const name: string): boolean;
begin
  var p := FParticipants.Find(name);
  if p <> nil then exit(p.FIsSelf or ((FOwnName <> '') and SameText(name, FOwnName)));
  result := (FOwnName <> '') and SameText(name, FOwnName);
end;

function TChatView.shownNameOf(const name: string): string;
begin
  var p := FParticipants.Find(name);
  result := if p <> nil then p.ShownName else name;
end;

function TChatView.initialsOf(const name: string): string;
begin
  var p := FParticipants.Find(name);
  if (p <> nil) and (p.FInitials <> '') then exit(p.FInitials);
  var words := shownNameOf(name).Split([' ', '.', '-', '_', #9], TStringSplitOptions.ExcludeEmpty);
  if length(words) = 0 then exit('');
  result := UTF8Copy(words[0], 1, 1);
  if length(words) > 1 then result += UTF8Copy(words[length(words)-1], 1, 1);
  result := UTF8UpperCase(result);
end;

function TChatView.autoIndexOf(const name: string): integer;
begin
  result := TAvatar.ColorIndexOfName(name);
  // in a conversation of two the other side never shares the own color
  if (FMode = cmDirect) and not IsSelf(name) then begin
    var own := selfName;
    if (own <> '') and (TAvatar.ColorIndexOfName(own) = result) then result := (result+TAvatar.PaletteSize div 2) mod TAvatar.PaletteSize;
  end;
end;

function TChatView.NameColorOf(const name: string): TColor;
begin
  var p := FParticipants.Find(name);
  if (p <> nil) and (p.FColor <> clDefault) then exit(ColorToRGB(p.FColor));
  result := TAvatar.PaletteColor(autoIndexOf(name));
end;

function TChatView.BubbleColorOf(msg: TChatMessage): TColor;
begin
  if msg.FColor <> clDefault then exit(ColorToRGB(msg.FColor));
  var back := ColorToRGB(Color);
  var p := FParticipants.Find(msg.FSender);
  var own := IsSelf(msg.FSender);
  if FColors.FAuto or (FMode = cmGroup) or ((p <> nil) and (p.FColor <> clDefault)) then
    exit(blend(back, NameColorOf(msg.FSender), FColors.FAutoStrength));
  result := if own then pick(FColors.FColors[0], clHighlight) else pick(FColors.FColors[1], blend(back, clWindowText, 8));
end;

function TChatView.TextColorOf(msg: TChatMessage): TColor;
begin
  if msg.FTextColor <> clDefault then exit(ColorToRGB(msg.FTextColor));
  var p := FParticipants.Find(msg.FSender);
  if (p <> nil) and (p.FTextColor <> clDefault) then exit(ColorToRGB(p.FTextColor));
  var fill := BubbleColorOf(msg);
  if FColors.FAuto or (FMode = cmGroup) then exit(contrastText(fill));
  result := if IsSelf(msg.FSender) then pick(FColors.FColors[2], contrastText(fill)) else pick(FColors.FColors[3], contrastText(fill));
end;

function TChatView.isRight(msg: TChatMessage): boolean;
begin
  var p := FParticipants.Find(msg.FSender);
  if (p <> nil) and (p.FSide <> sdAuto) then exit(p.FSide = sdRight);
  var ownRight := FOwnSide <> sdLeft;
  result := IsSelf(msg.FSender) = ownRight;
end;

function TChatView.avatarWanted(msg: TChatMessage): boolean;
begin
  if msg.FKind = mkSystem then exit(false);
  var own := IsSelf(msg.FSender);
  if own and not FAvatars.FShowForSelf then exit(false);
  result := match FAvatars.FVisibility of
    vsAlways: true;
    vsNever: false;
  else
    FMode = cmGroup
  end;
end;

function TChatView.nameWanted(msg: TChatMessage): boolean;
begin
  if msg.FKind = mkSystem then exit(false);
  result := match FLabels.FNames of
    vsAlways: true;
    vsNever: false;
  else
    (FMode = cmGroup) and not IsSelf(msg.FSender)
  end;
end;

function TChatView.stampOf(msg: TChatMessage): string;
begin
  result := '';
  if FLabels.FShowTime then result := FormatDateTime(FLabels.FTimeFormat, msg.FTime, formatSettingsOf(FLanguage));
  if msg.FEdited and FLabels.FShowEdited and (FLabels.FEditedCaption <> '') then
    result := if result = '' then FLabels.FEditedCaption else result+' '+FLabels.FEditedCaption;
end;

// the room for the status mark after the stamp, the height of the small text
function TChatView.statusWidth(msg: TChatMessage): integer;
begin
  result := 0;
  if FLabels.FShowStatus and (msg.FStatus <> msNone) and IsSelf(msg.FSender) then result := lineHeightOf(FTimeFont)+scaled(self, 3);
end;

function TChatView.separatorText(day: TDateTime): string;
begin
  var today := Trunc(Now);
  var d := Trunc(day);
  if (d = today) and (FLabels.FTodayCaption <> '') then exit(FLabels.FTodayCaption);
  if (d = today-1) and (FLabels.FYesterdayCaption <> '') then exit(FLabels.FYesterdayCaption);
  result := FormatDateTime(FLabels.FDateFormat, day, formatSettingsOf(FLanguage));
end;

function TChatView.SelectedMessage: TChatMessage;
begin
  result := if (FSelected >= 0) and (FSelected < FMessages.Count) then FMessages[FSelected] else nil;
end;

function TChatView.AsText: string;
begin
  var sb := TStringList.Create;
  try
    var fs := formatSettingsOf(FLanguage);
    for var i := 0 to FMessages.Count-1 do begin
      var m := FMessages[i];
      if m.FKind = mkSystem then sb.Add('* '+m.FText)
      else sb.Add('['+FormatDateTime('yyyy-mm-dd hh:nn', m.FTime, fs)+'] '+shownNameOf(m.FSender)+': '+m.FText);
    end;
    result := sb.Text;
  finally
    sb.Free;
  end;
end;

procedure TChatView.CopyToClipboard;
begin
  var m := SelectedMessage;
  Clipboard.AsText := if m <> nil then m.FText else AsText;
end;

// -- layout ----------------------

procedure TChatView.settingsChanged;
begin
  invalidateLayout;
  if HandleAllocated and not (csLoading in ComponentState) then measure;
  Invalidate;
end;

procedure TChatView.messagesChanged;
begin
  // the inherited constructor resizes before the collections exist
  if (FMessages = nil) or (csDestroying in ComponentState) then exit;
  if FSelected >= FMessages.Count then FSelected := -1;
  if FHot >= FMessages.Count then FHot := -1;
  settingsChanged;
end;

procedure TChatView.participantsChanged;
begin
  if (FParticipants = nil) or (csDestroying in ComponentState) then exit;
  settingsChanged;
end;

procedure TChatView.invalidateLayout;
begin
  FLayoutDirty := true;
end;

procedure TChatView.ensureLayout;
begin
  if FLayoutDirty or (FLaidWidth <> ClientWidth) then measure;
end;

procedure TChatView.updateFonts;
begin
  FNameFont.Assign(Font);
  FNameFont.Style := Font.Style+[fsBold];
  FTimeFont.Assign(Font);
  FTimeFont.Height := -Max(Round(lineHeightOf(Font)*0.7), 6);
  FAvatarFont.Assign(Font);
  FAvatarFont.Style := Font.Style+[fsBold];
  FAvatarFont.Height := -Max(scaled(self, FAvatars.FSize)*40 div 100, 6);
end;

function TChatView.wrap(font: TFont; const text: string; maxWidth: integer): TStringArray;
begin
  result := nil;
  if maxWidth < 4 then maxWidth := 4;
  for var para in StringReplace(text, #13, '', [rfReplaceAll]).Split([#10]) do begin
    var line := '';
    for var piece in para.Split([' ']) do begin
      var candidate := if line = '' then piece else line+' '+piece;
      if (line <> '') and (textWidthOf(font, candidate) > maxWidth) then begin
        push(result, line);
        line := piece;
      end else line := candidate;
      // a word wider than the room breaks between its letters
      while (textWidthOf(font, line) > maxWidth) and (UTF8Length(line) > 1) do begin
        var lo := 1;
        var hi := UTF8Length(line)-1;
        while lo < hi do begin
          var mid := (lo+hi+1) div 2;
          if textWidthOf(font, UTF8Copy(line, 1, mid)) <= maxWidth then lo := mid else hi := mid-1;
        end;
        push(result, UTF8Copy(line, 1, lo));
        line := UTF8Copy(line, lo+1, MaxInt);
      end;
    end;
    push(result, line);
  end;
end;

function TChatView.widest(font: TFont; const lines: TStringArray): integer;
begin
  result := 0;
  for var s in lines do result := Max(result, textWidthOf(font, s));
end;

procedure TChatView.measure;
begin
  FLayoutDirty := false;
  var w := ClientWidth;
  FLaidWidth := w;
  if (w <= 0) or (FMessages = nil) then exit;
  var pad := scaled(self, FPadding);
  var padIn := scaled(self, FBubbles.FPadding);
  var padV := Max(padIn*7 div 10, 2);
  var gap := scaled(self, 6);
  var lh := lineHeightOf(Font)+scaled(self, FBubbles.FLineSpacing);
  var nameH := lineHeightOf(FNameFont);
  var timeH := lineHeightOf(FTimeFont);
  var av := scaled(self, FAvatars.FSize);
  var avGap := scaled(self, FAvatars.FSpacing);
  var spacing := scaled(self, FBubbles.FSpacing);
  var groupSpacing := scaled(self, FBubbles.FGroupSpacing);
  // a side keeps the room of the avatars when any of its messages wants
  // one, so the bubbles of the side line up
  var reserve: array[boolean] of integer;
  reserve[false] := 0;
  reserve[true] := 0;
  for var i := 0 to FMessages.Count-1 do begin
    var m := FMessages[i];
    if avatarWanted(m) then reserve[isRight(m)] := av+avGap;
  end;
  var y := pad;
  var prev: TChatMessage := nil;
  var prevDay := -1;
  for var i := 0 to FMessages.Count-1 do begin
    var m := FMessages[i];
    m.FGroupFirst := true;
    m.FGroupLast := true;
    m.FHasSeparator := false;
    m.FShowAvatar := false;
    m.FShowName := false;
    m.FAvatar := Rect(0, 0, 0, 0);
    m.FNameRect := Rect(0, 0, 0, 0);
    m.FTimeRect := Rect(0, 0, 0, 0);
    m.FStatusRect := Rect(0, 0, 0, 0);
    m.FPictureRect := Rect(0, 0, 0, 0);
    if m.FKind = mkSystem then begin
      if i > 0 then y += spacing;
      m.FLines := wrap(FTimeFont, m.FText, Max(w-2*pad-2*padIn, 10));
      var bw := widest(FTimeFont, m.FLines)+2*padIn;
      var bh := length(m.FLines)*timeH+padV;
      m.FTop := y;
      m.FBubble := Rect((w-bw) div 2, y, (w-bw) div 2+bw, y+bh);
      y := m.FBubble.Bottom;
      m.FBottom := y;
      prev := nil;
      continue;
    end;
    var day := Trunc(m.FTime);
    if FLabels.FDateSeparators and (day <> prevDay) then begin
      if i > 0 then y += spacing;
      m.FHasSeparator := true;
      m.FSeparator := Rect(pad, y, w-pad, y+timeH+padV);
      y := m.FSeparator.Bottom;
      prev := nil;
    end;
    var grouped := FBubbles.FGroupMessages and (prev <> nil) and SameText(m.FSender, prev.FSender) and (Abs(m.FTime-prev.FTime)*1440 <= FBubbles.FGroupInterval);
    if grouped then begin
      m.FGroupFirst := false;
      prev.FGroupLast := false;
    end;
    if m.FHasSeparator then y += spacing div 2
    else if i > 0 then y += (if grouped then groupSpacing else spacing);
    m.FTop := y;
    m.FRight := isRight(m);
    m.FShowName := nameWanted(m) and m.FGroupFirst;
    m.FNameInside := m.FShowName and (FLabels.FNamePlacement = npInside);
    var x0 := pad+reserve[false];
    var x1 := w-pad-reserve[true];
    var room := Max(x1-x0, 20);
    var maxW := Max(room*FBubbles.FMaxWidth div 100, 2*padIn+10);
    var inner := maxW-2*padIn;
    m.FLines := if m.FText <> '' then wrap(Font, m.FText, inner) else nil;
    var contentW := widest(Font, m.FLines);
    var contentH := length(m.FLines)*lh;
    if m.HasPicture then begin
      // the picture in its proportions, to the width of the room and the
      // height allowed
      var pw := Max(m.FPicture.Graphic.Width, 1);
      var ph := Max(m.FPicture.Graphic.Height, 1);
      if pw > inner then begin
        ph := Max(ph*inner div pw, 1);
        pw := inner;
      end;
      var maxPh := Max(scaled(self, FBubbles.FMaxPictureHeight), 8);
      if ph > maxPh then begin
        pw := Max(pw*maxPh div ph, 1);
        ph := maxPh;
      end;
      m.FPictureRect := Rect(0, 0, pw, ph);
      contentW := Max(contentW, pw);
      contentH += ph+(if length(m.FLines) > 0 then padV div 2 else 0);
    end;
    var nameW := if m.FShowName then textWidthOf(FNameFont, shownNameOf(m.FSender)) else 0;
    if m.FNameInside then begin
      contentW := Max(contentW, nameW);
      contentH += nameH+scaled(self, 2);
    end;
    var stamp := stampOf(m);
    var stampW := if stamp <> '' then textWidthOf(FTimeFont, stamp) else 0;
    var statusW := statusWidth(m);
    if (stampW = 0) and (statusW > 0) then statusW -= scaled(self, 3);
    var markW := stampW+statusW;
    var timeInside := (markW > 0) and (FLabels.FTimePlacement = tmInside);
    if timeInside then begin
      // after the last line when it fits there, else on a row of its own
      var lastW := if length(m.FLines) > 0 then textWidthOf(Font, m.FLines[high(m.FLines)]) else 0;
      if (length(m.FLines) > 0) and (lastW+gap+markW <= inner) then contentW := Max(contentW, lastW+gap+markW)
      else begin
        contentW := Max(contentW, markW);
        contentH += timeH;
      end;
    end;
    var bw := Min(Max(contentW+2*padIn, Min(scaled(self, FBubbles.FMinWidth), maxW)), maxW);
    var bh := contentH+2*padV;
    if avatarWanted(m) and m.FGroupFirst then bh := Max(bh, av);
    var bx := if m.FRight then x1-bw else x0;
    if m.FShowName and not m.FNameInside then begin
      var nx := if m.FRight then x1-nameW else x0;
      m.FNameRect := Rect(nx, y, nx+nameW, y+nameH);
      y += nameH+scaled(self, 2);
    end;
    m.FBubble := Rect(bx, y, bx+bw, y+bh);
    if m.FNameInside then m.FNameRect := Rect(bx+padIn, y+padV, bx+padIn+nameW, y+padV+nameH);
    if m.HasPicture then OffsetRect(m.FPictureRect, bx+padIn, y+padV+(if m.FNameInside then nameH+scaled(self, 2) else 0));
    var extra := 0;
    if markW > 0 then begin
      var tx: integer;
      var ty: integer;
      match FLabels.FTimePlacement of
        tmInside: begin
          tx := m.FBubble.Right-padIn-markW;
          ty := m.FBubble.Bottom-padV-timeH;
        end;
        tmBeside: begin
          tx := if m.FRight then m.FBubble.Left-gap-markW else m.FBubble.Right+gap;
          ty := m.FBubble.Bottom-timeH;
        end;
      else
        tx := if m.FRight then m.FBubble.Right-markW else m.FBubble.Left;
        ty := m.FBubble.Bottom+scaled(self, 2);
        extra := timeH+scaled(self, 2);
      end;
      m.FTimeRect := Rect(tx, ty, tx+stampW, ty+timeH);
      if statusW > 0 then m.FStatusRect := Rect(tx+markW-timeH, ty, tx+markW, ty+timeH);
    end;
    y := m.FBubble.Bottom+extra;
    m.FBottom := y;
    prev := m;
    prevDay := day;
  end;
  // the avatar of a row sits at its first or its last bubble
  for var i := 0 to FMessages.Count-1 do begin
    var m := FMessages[i];
    if not avatarWanted(m) then continue;
    if (FAvatars.FPlacement = apBottom) and not m.FGroupLast then continue;
    if (FAvatars.FPlacement = apTop) and not m.FGroupFirst then continue;
    m.FShowAvatar := true;
    var ax := if m.FRight then m.FBubble.Right+avGap else m.FBubble.Left-avGap-av;
    var ay := if FAvatars.FPlacement = apTop then (if m.FShowName and not m.FNameInside then m.FNameRect.Top else m.FBubble.Top) else m.FBubble.Bottom-av;
    m.FAvatar := Rect(ax, ay, ax+av, ay+av);
  end;
  // the typing bubble, on the side of the one typing
  FTypingRect := Rect(0, 0, 0, 0);
  if FTyping <> '' then begin
    if FMessages.Count > 0 then y += spacing;
    var probe := TChatMessage.Create(nil);
    try
      probe.FSender := FTyping;
      FTypingRight := ord(isRight(probe));
      var right := isRight(probe);
      var dots := 3*(lh div 2)+2*scaled(self, 3);
      var capW := if FLabels.FTypingCaption <> '' then textWidthOf(FTimeFont, Format(FLabels.FTypingCaption, [shownNameOf(FTyping)]))+gap else 0;
      var bw := dots+capW+2*padIn;
      var bh := lh+2*padV;
      var x0 := pad+reserve[false];
      var x1 := w-pad-reserve[true];
      var bx := if right then x1-bw else x0;
      FTypingRect := Rect(bx, y, bx+bw, y+bh);
      y := FTypingRect.Bottom;
    finally
      probe.Free;
    end;
  end;
  FContentHeight := y+pad;
  updateRange;
end;

procedure TChatView.updateRange;
begin
  if not HandleAllocated then exit;
  VertScrollBar.Increment := lineHeightOf(Font)+scaled(self, FBubbles.FLineSpacing);
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := FContentHeight;
end;

procedure TChatView.ScrollToEnd;
begin
  ensureLayout;
  updateRange;
  VertScrollBar.Position := Max(VertScrollBar.Range-VertScrollBar.Page, 0);
  Invalidate;
end;

procedure TChatView.ScrollToMessage(index: integer);
begin
  if (index < 0) or (index >= FMessages.Count) then exit;
  ensureLayout;
  updateRange;
  var m := FMessages[index];
  if m.FTop-scaled(self, FPadding) < VertScrollBar.Position then VertScrollBar.Position := Max(m.FTop-scaled(self, FPadding), 0)
  else if m.FBottom > VertScrollBar.Position+ClientHeight then VertScrollBar.Position := Max(m.FBottom-ClientHeight+scaled(self, FPadding), 0);
  Invalidate;
end;

procedure TChatView.WMVScroll(var Message: TLMVScroll);
begin
  inherited WMVScroll(Message);
  Invalidate;
end;

// a scroll repaints everything: shifting the pixels would carry the
// outline of the selection into the content
procedure TChatView.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TChatView.DoOnResize;
begin
  inherited DoOnResize;
  if FMessages = nil then exit;
  var atEnd := VertScrollBar.Position >= VertScrollBar.Range-VertScrollBar.Page-1;
  if ClientWidth <> FLaidWidth then invalidateLayout;
  ensureLayout;
  updateRange;
  if FAutoScroll and atEnd then ScrollToEnd;
end;

procedure TChatView.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  if FNameFont = nil then exit;
  updateFonts;
  settingsChanged;
end;

procedure TChatView.tick(Sender: TObject);
begin
  FTypingPhase := (FTypingPhase+1) mod 3;
  if not HandleAllocated or (FTypingRect.Bottom = 0) then exit;
  var r := FTypingRect;
  OffsetRect(r, 0, -VertScrollBar.Position);
  InvalidateRect(Handle, @r, false);
end;

// -- painting ----------------------

// the outline of a bubble: corners of their own radii, clockwise from the
// top left, with a tail at the bottom corner of the near side when asked
function bubbleOutline(const r: TRect; rtl, rtr, rbr, rbl, tail: single; tailRight: boolean): TOutline;
var
  pts: array of TPointF;
  n: integer;

  procedure add(x, y: single);
  begin
    if n >= length(pts) then SetLength(pts, n*2+16);
    pts[n] := PointF(x, y);
    inc(n);
  end;

  // angles in degrees, growing clockwise on the screen
  procedure arc(cx, cy, rad, a0, a1: single);
  begin
    if rad <= 0.5 then begin
      add(cx, cy);
      exit;
    end;
    var steps := Max(Round(rad/2), 2)+2;
    for var i := 0 to steps do begin
      var a := (a0+(a1-a0)*i/steps)*pi/180;
      add(cx+rad*cos(a), cy+rad*sin(a));
    end;
  end;

  procedure curve(x0, y0, cx, cy, x1, y1: single);
  begin
    for var i := 1 to 5 do begin
      var s := i/5;
      var q := 1-s;
      add(q*q*x0+2*q*s*cx+s*s*x1, q*q*y0+2*q*s*cy+s*s*y1);
    end;
  end;

begin
  n := 0;
  SetLength(pts, 64);
  var l := r.Left;
  var t := r.Top;
  var rt := r.Right;
  var b := r.Bottom;
  arc(l+rtl, t+rtl, rtl, 180, 270);
  arc(rt-rtr, t+rtr, rtr, 270, 360);
  if tailRight and (tail > 0) then begin
    add(rt, b-tail*2);
    curve(rt, b-tail*2, rt, b, rt+tail, b);
    add(rt-tail*0.6, b);
  end else arc(rt-rbr, b-rbr, rbr, 0, 90);
  if (not tailRight) and (tail > 0) then begin
    add(l+tail*0.6, b);
    add(l-tail, b);
    curve(l-tail, b, l, b, l, b-tail*2);
  end else arc(l+rbl, b-rbl, rbl, 90, 180);
  SetLength(pts, n);
  result := pts;
end;

function TChatView.bubbleOutlineOf(msg: TChatMessage): TOutline;
begin
  var r := msg.FBubble;
  var radius: single := match FBubbles.FShape of
    shSquare: 0;
    shPill: r.Height/2;
  else
    Min(scaled(self, FBubbles.FCornerRadius), Min(r.Width, r.Height)/2)
  end;
  var small: single := if FBubbles.FShape = shSquare then 0 else Max(radius/4, 2);
  var tail: single := if (FBubbles.FShape = shTailed) and msg.FGroupLast then scaled(self, FBubbles.FTailSize) else 0;
  if tail > r.Height/2.5 then tail := r.Height/2.5;
  // the corners toward the speaker shrink between the bubbles of a row
  var topNear := if msg.FGroupFirst then radius else small;
  var bottomNear := if msg.FGroupLast then radius else small;
  result := if msg.FRight then bubbleOutline(r, radius, topNear, bottomNear, radius, tail, true)
    else bubbleOutline(r, topNear, radius, radius, bottomNear, tail, false);
end;

procedure TChatView.paintStatus(sp: TSmoothPaint; msg: TChatMessage; fill, txt: TColor);
begin
  var r := msg.FStatusRect;
  if r.Right <= r.Left then exit;
  var color := pick(FColors.FColors[5], blend(txt, fill, 35));
  var size := r.Height-scaled(self, 2);
  var cx := (r.Left+r.Right)/2;
  var cy := (r.Top+r.Bottom)/2;
  var thick := Max(size div 7, 1);
  match msg.FStatus of
    msSending: begin
      sp.FrameEllipse(cx, cy, size/2-1, size/2-1, thick, color);
      sp.StrokePolyline([PointF(cx, cy-size/4), PointF(cx, cy), PointF(cx+size/5, cy+size/8)], thick, color);
    end;
    msSent: paintCheck(sp, r, size*3 div 4, color, thick);
    msDelivered, msRead: begin
      // two checks, the second a third of the size to the right
      var c := if msg.FStatus = msRead then (if isDark(fill) then RGBToColor(140, 220, 255) else ColorToRGB(clHighlight)) else color;
      var shift := Max(size div 3, 2);
      var one := r;
      OffsetRect(one, -shift div 2, 0);
      paintCheck(sp, one, size*3 div 4, c, thick);
      OffsetRect(one, shift, 0);
      paintCheck(sp, one, size*3 div 4, c, thick);
    end;
    msFailed: begin
      var red := RGBToColor(229, 57, 53);
      sp.FillEllipse(cx, cy, size/2, size/2, red);
      sp.StrokePolyline([PointF(cx, cy-size/4), PointF(cx, cy+size/12)], thick, clWhite);
      sp.FillEllipse(cx, cy+size/4, thick/2+0.5, thick/2+0.5, clWhite);
    end;
  else
    ;
  end;
end;

procedure TChatView.paintAvatar(sp: TSmoothPaint; const r: TRect; const name: string; back: TColor; var texts: TStringList);
begin
  var p := FParticipants.Find(name);
  var tone := NameColorOf(name);
  var usePicture := (FAvatars.FSource <> avGenerated) and (p <> nil) and p.HasPicture;
  var ring := scaled(self, FAvatars.FBorderWidth);
  var face := r;
  face.Inflate(-ring, -ring);
  var shape := FAvatars.FShape;
  var radius: single := match shape of
    asCircle: face.Width/2;
    asRounded: Min(scaled(self, 8), face.Width/2);
  else
    0
  end;
  var polygonal := shape in [asHexagon, asDiamond, asSquircle, asShield];
  // the outline of a shape that is no rectangle, in a box
  var outlineOf := function(const box: TRect; reverse: boolean): TOutline
  begin
    var cx := (box.Left+box.Right)/2;
    var cy := (box.Top+box.Bottom)/2;
    var rad := box.Width/2;
    match shape of
      asHexagon: result := polygonOutline(cx, cy, rad, 6, 30);
      asDiamond: result := polygonOutline(cx, cy, rad, 4, 90);
      asSquircle: begin
        SetLength(result, 64);
        for var i := 0 to 63 do begin
          var a := i*2*pi/64;
          result[i] := PointF(cx+rad*Sign(cos(a))*power(Abs(cos(a)), 0.5), cy+rad*Sign(sin(a))*power(Abs(sin(a)), 0.5));
        end;
      end;
    else
      result := [PointF(box.Left, box.Top), PointF(box.Right, box.Top), PointF(box.Right, cy), PointF(cx, box.Bottom), PointF(box.Left, cy)];
    end;
    if reverse then
      for var i := 0 to length(result) div 2-1 do begin
        var q := result[i];
        result[i] := result[high(result)-i];
        result[high(result)-i] := q;
      end;
  end;
  if ring > 0 then
    if polygonal then sp.FillPolygon(outlineOf(r, false), tone)
    else paintRoundRect(sp, r, (if radius > 0 then Round(radius)+ring else 0), tone, clNone);
  if usePicture then begin
    var g := p.FPicture.Graphic;
    var src := autofree TBitmap.Create;
    src.SetSize(Max(g.Width, 1), Max(g.Height, 1));
    src.Canvas.Brush.Color := tone;
    src.Canvas.FillRect(0, 0, src.Width, src.Height);
    src.Canvas.Draw(0, 0, g);
    // the middle of the picture in the proportions of the face
    var part := Rect(0, 0, src.Width, src.Height);
    if src.Width*face.Height > src.Height*face.Width then begin
      var pw := src.Height*face.Width div Max(face.Height, 1);
      part := Rect((src.Width-pw) div 2, 0, (src.Width-pw) div 2+pw, src.Height);
    end else begin
      var ph := src.Width*face.Height div Max(face.Width, 1);
      part := Rect(0, (src.Height-ph) div 2, src.Width, (src.Height-ph) div 2+ph);
    end;
    sp.DrawImage(src, part, face);
    if (radius > 0) or polygonal then begin
      var frame: TOutline := [PointF(face.Left, face.Top), PointF(face.Right, face.Top), PointF(face.Right, face.Bottom), PointF(face.Left, face.Bottom)];
      // the shape runs the other way, so it cuts a hole in the frame
      var hole := if polygonal then outlineOf(face, true)
        else if shape = asCircle then ellipseOutline((face.Left+face.Right)/2, (face.Top+face.Bottom)/2, face.Width/2, face.Height/2, true)
        else roundRectOutline(face.Left, face.Top, face.Right, face.Bottom, radius, true);
      sp.FillOutlines([frame, hole], if ring > 0 then tone else back);
    end;
  end else begin
    var fill := if FAvatars.FSource = avPicture then blend(back, clWindowText, 12) else tone;
    if polygonal then sp.FillPolygon(outlineOf(face, false), fill)
    else paintRoundRect(sp, face, Round(radius), fill, clNone);
    if FAvatars.FSource <> avPicture then begin
      var letters := initialsOf(name);
      if letters <> '' then begin
        var t := TChatText.Create;
        t.font := FAvatarFont;
        t.s := letters;
        t.color := contrastText(fill);
        t.x := face.Left+(face.Width-textWidthOf(FAvatarFont, letters)) div 2;
        t.y := face.Top+(face.Height-lineHeightOf(FAvatarFont)) div 2;
        t.limit := face.Right;
        texts.AddObject('', t);
      end;
    end;
  end;
  // the presence dot at the bottom right, in a ring of the background
  if FAvatars.FShowStatus and (p <> nil) and (p.FStatus <> stNone) then begin
    var dot := match p.FStatus of
      stOnline: RGBToColor(67, 160, 71);
      stAway: RGBToColor(255, 179, 0);
      stBusy: RGBToColor(229, 57, 53);
    else
      RGBToColor(158, 158, 158)
    end;
    var dr := Max(r.Width*14 div 100, 3);
    var cx := r.Right-dr;
    var cy := r.Bottom-dr;
    if shape = asCircle then begin
      var off := Round((r.Width/2)*0.7071);
      cx := r.Left+r.Width div 2+off;
      cy := r.Top+r.Height div 2+off;
    end;
    paintCircle(sp, cx, cy, dr+Max(r.Width div 20, 2), back, clNone);
    paintCircle(sp, cx, cy, dr, dot, clNone);
    match p.FStatus of
      stBusy: paintLine(sp, cx-dr div 2, cy, cx+dr div 2, cy, back, Max(dr div 3, 1));
      stOffline: paintCircle(sp, cx, cy, dr div 2, back, clNone);
    else
      ;
    end;
  end;
end;

procedure TChatView.Paint;
begin
  ensureLayout;
  var back := ColorToRGB(Color);
  // the canvas origin already sits at the scroll position, so everything
  // paints in the coordinates of the content and the view is the visible part
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  var padIn := scaled(self, FBubbles.FPadding);
  var padV := Max(padIn*7 div 10, 2);
  var lh := lineHeightOf(Font)+scaled(self, FBubbles.FLineSpacing);
  var nameH := lineHeightOf(FNameFont);
  var timeH := lineHeightOf(FTimeFont);
  var borderW := scaled(self, FBubbles.FBorderWidth);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var texts := autofree TStringList.Create;
  texts.OwnsObjects := true;
  var addText := procedure(x, y: integer; const s: string; font: TFont; color: TColor; limit: integer)
  begin
    var t := TChatText.Create;
    t.x := x;
    t.y := y;
    t.s := s;
    t.font := font;
    t.color := color;
    t.limit := limit;
    texts.AddObject('', t);
  end;
  var first := -1;
  var last := -1;
  for var i := 0 to FMessages.Count-1 do begin
    var m := FMessages[i];
    if (m.FBottom < view.Top) or (m.FTop > view.Bottom) then continue;
    if first < 0 then first := i;
    last := i;
    if m.FHasSeparator then begin
      var caption := separatorText(m.FTime);
      var tw := textWidthOf(FTimeFont, caption);
      var pill := m.FSeparator;
      pill.Left := (pill.Left+pill.Right-tw) div 2-padIn;
      pill.Right := pill.Left+tw+2*padIn;
      var fill := FColors.FColors[9];
      if fill = clDefault then fill := blend(back, clWindowText, 5);
      if fill <> clNone then paintPill(sp, pill, fill, clNone);
      if FLabels.FSeparatorLines then begin
        var ly := (pill.Top+pill.Bottom) div 2;
        var lineColor := blend(back, clWindowText, 15);
        if pill.Left-scaled(self, 8) > m.FSeparator.Left then paintLine(sp, m.FSeparator.Left, ly, pill.Left-scaled(self, 8), ly, lineColor);
        if pill.Right+scaled(self, 8) < m.FSeparator.Right then paintLine(sp, pill.Right+scaled(self, 8), ly, m.FSeparator.Right, ly, lineColor);
      end;
      addText(pill.Left+padIn, pill.Top+(pill.Height-timeH) div 2, caption, FTimeFont, pick(FColors.FColors[10], clGrayText), pill.Right);
    end;
    if m.FKind = mkSystem then begin
      var fill := pick(FColors.FColors[7], blend(back, clWindowText, 6));
      paintRoundRect(sp, m.FBubble, Min(scaled(self, FBubbles.FCornerRadius), m.FBubble.Height div 2), fill, clNone);
      var ty := m.FBubble.Top+padV div 2;
      var txt := pick(FColors.FColors[8], clGrayText);
      for var s in m.FLines do begin
        addText(m.FBubble.Left+(m.FBubble.Width-textWidthOf(FTimeFont, s)) div 2, ty, s, FTimeFont, txt, m.FBubble.Right);
        ty += timeH;
      end;
      continue;
    end;
    var fill := BubbleColorOf(m);
    var txt := TextColorOf(m);
    if (i = FHot) and hoverEnabled then fill := blend(fill, contrastText(fill), 6);
    if not Enabled then fill := blend(fill, back, 40);
    var outline := bubbleOutlineOf(m);
    sp.FillPolygon(outline, fill);
    if borderW > 0 then sp.StrokePolyline(outline, borderW, pick(FColors.FColors[6], blend(fill, contrastText(fill), 25)), true);
    if i = FSelected then sp.StrokePolyline(outline, Max(scaled(self, 2), 2), pick(FColors.FColors[11], ringColor), true);
    if m.HasPicture then begin
      var g := m.FPicture.Graphic;
      var src := autofree TBitmap.Create;
      src.SetSize(Max(g.Width, 1), Max(g.Height, 1));
      src.Canvas.Brush.Color := fill;
      src.Canvas.FillRect(0, 0, src.Width, src.Height);
      src.Canvas.Draw(0, 0, g);
      sp.DrawImage(src, Rect(0, 0, src.Width, src.Height), m.FPictureRect);
    end;
    var ty := m.FBubble.Top+padV;
    if m.FShowName then addText(m.FNameRect.Left, m.FNameRect.Top, shownNameOf(m.FSender), FNameFont, pick(FColors.FColors[4], (if m.FNameInside then txt else NameColorOf(m.FSender))), m.FNameRect.Right);
    if m.FNameInside then ty += nameH+scaled(self, 2);
    if m.HasPicture then ty += m.FPictureRect.Height+(if length(m.FLines) > 0 then padV div 2 else 0);
    for var s in m.FLines do begin
      addText(m.FBubble.Left+padIn, ty, s, Font, txt, m.FBubble.Right-padIn);
      ty += lh;
    end;
    if m.FTimeRect.Right > m.FTimeRect.Left then begin
      var inside := FLabels.FTimePlacement = tmInside;
      var tone := pick(FColors.FColors[5], (if inside then blend(txt, fill, 35) else ColorToRGB(clGrayText)));
      addText(m.FTimeRect.Left, m.FTimeRect.Top, stampOf(m), FTimeFont, tone, m.FTimeRect.Right+1);
    end;
    paintStatus(sp, m, fill, txt);
    if m.FShowAvatar then paintAvatar(sp, m.FAvatar, m.FSender, back, texts);
  end;
  // the typing bubble: three dots, the current one raised and darker
  if (FTyping <> '') and (FTypingRect.Bottom >= view.Top) and (FTypingRect.Top <= view.Bottom) then begin
    var probe := TChatMessage.Create(nil);
    try
      probe.FSender := FTyping;
      probe.FBubble := FTypingRect;
      probe.FRight := FTypingRight = 1;
      probe.FGroupFirst := true;
      probe.FGroupLast := true;
      var fill := BubbleColorOf(probe);
      var txt := TextColorOf(probe);
      sp.FillPolygon(bubbleOutlineOf(probe), fill);
      var dot := Max(lh div 6, 2);
      var step := lh div 2;
      var cy := (FTypingRect.Top+FTypingRect.Bottom) div 2;
      for var k := 0 to 2 do begin
        var cx := FTypingRect.Left+padIn+step div 2+k*step;
        var active := (k = FTypingPhase) and not (csDesigning in ComponentState);
        var rad := if active then dot+1 else dot;
        sp.FillEllipse(cx, (if active then cy-dot div 2 else cy), rad, rad, (if active then txt else blend(txt, fill, 45)));
      end;
      if FLabels.FTypingCaption <> '' then
        addText(FTypingRect.Left+padIn+3*step+scaled(self, 6), cy-timeH div 2, Format(FLabels.FTypingCaption, [shownNameOf(FTyping)]), FTimeFont, blend(txt, fill, 25), FTypingRect.Right);
    finally
      probe.Free;
    end;
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.Layout := tlTop;
  style.Alignment := taLeftJustify;
  style.Wordbreak := false;
  var current: TFont := nil;
  for var i := 0 to texts.Count-1 do begin
    var t := TChatText(texts.Objects[i]);
    if t.font <> current then begin
      Canvas.Font := t.font;
      current := t.font;
    end;
    Canvas.Font.Color := t.color;
    var r := Rect(t.x, t.y, Max(t.limit, t.x+1), t.y+lineHeightOf(t.font)+2);
    Canvas.TextRect(r, t.x, t.y, t.s, style);
  end;
  if (FMessages.Count = 0) and (FTyping = '') and (FLabels.FEmptyText <> '') then begin
    Canvas.Font := Font;
    paintCenteredText(Canvas, view, FLabels.FEmptyText, pick(FColors.FColors[8], clGrayText));
  end;
  Canvas.Font := Font;
  Canvas.Brush.Style := bsSolid;
  // the handlers paint over the bubbles and the avatars on show
  if (first >= 0) and (Assigned(FOnDrawBubble) or Assigned(FOnDrawAvatar)) then
    for var i := first to last do begin
      var m := FMessages[i];
      if m.FKind = mkSystem then continue;
      var state: TDrawState := [];
      if i = FSelected then state += [dsSelected];
      if i = FHot then state += [dsHover];
      if not Enabled then state += [dsDisabled];
      var handled := false;
      if Assigned(FOnDrawBubble) then FOnDrawBubble(self, Canvas, m.FBubble, i, state, handled);
      if m.FShowAvatar and Assigned(FOnDrawAvatar) then FOnDrawAvatar(self, Canvas, m.FAvatar, i, state, handled);
    end;
end;

// -- input ----------------------

function TChatView.messageAt(x, y: integer; out onAvatar: boolean): integer;
begin
  onAvatar := false;
  ensureLayout;
  var p := Point(x, y+VertScrollBar.Position);
  for var i := 0 to FMessages.Count-1 do begin
    var m := FMessages[i];
    if (p.Y < m.FTop) or (p.Y > m.FBottom) then continue;
    if m.FShowAvatar and PtInRect(m.FAvatar, p) then begin
      onAvatar := true;
      exit(i);
    end;
    if PtInRect(m.FBubble, p) then exit(i);
  end;
  result := -1;
end;

function TChatView.MessageAt(x, y: integer): TChatMessage;
begin
  var onAvatar: boolean;
  var i := messageAt(x, y, onAvatar);
  result := if i >= 0 then FMessages[i] else nil;
end;

procedure TChatView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  FMousePos := Point(X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  var onAvatar: boolean;
  var i := messageAt(X, Y, onAvatar);
  if onAvatar then begin
    if Assigned(FOnAvatarClick) then FOnAvatarClick(self, EnsureParticipant(FMessages[i].FSender));
    exit;
  end;
  setSelected(i);
  if (i >= 0) and Assigned(FOnMessageClick) then FOnMessageClick(self, FMessages[i]);
end;

procedure TChatView.DblClick;
begin
  inherited DblClick;
  var onAvatar: boolean;
  var i := messageAt(FMousePos.X, FMousePos.Y, onAvatar);
  if (i >= 0) and not onAvatar and Assigned(FOnMessageDblClick) then FOnMessageDblClick(self, FMessages[i]);
end;

procedure TChatView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  FMousePos := Point(X, Y);
  var onAvatar: boolean;
  var i := messageAt(X, Y, onAvatar);
  if onAvatar then begin
    Cursor := if Assigned(FOnAvatarClick) then crHandPoint else crDefault;
    i := -1;
  end else Cursor := crDefault;
  if (i = FHot) and (onAvatar = FHotAvatar) then exit;
  FHot := i;
  FHotAvatar := onAvatar;
  if hoverEnabled then Invalidate;
end;

procedure TChatView.MouseLeave;
begin
  inherited MouseLeave;
  Cursor := crDefault;
  if FHot < 0 then exit;
  FHot := -1;
  if hoverEnabled then Invalidate;
end;

procedure TChatView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var n := FMessages.Count;
  var pressed := Key;
  match Key of
    VK_UP: if n > 0 then setSelected(if FSelected < 0 then n-1 else Max(FSelected-1, 0));
    VK_DOWN: if n > 0 then setSelected(if FSelected < 0 then 0 else Min(FSelected+1, n-1));
    VK_HOME: if n > 0 then setSelected(0);
    VK_END: if n > 0 then setSelected(n-1);
    VK_PRIOR: VertScrollBar.Position := Max(VertScrollBar.Position-ClientHeight, 0);
    VK_NEXT: VertScrollBar.Position := Min(VertScrollBar.Position+ClientHeight, Max(VertScrollBar.Range-VertScrollBar.Page, 0));
    VK_ESCAPE: setSelected(-1);
    VK_C: if ssCtrl in Shift then CopyToClipboard else exit;
  else
    exit;
  end;
  Key := 0;
  if pressed in [VK_UP, VK_DOWN, VK_HOME, VK_END] then ScrollToMessage(FSelected);
  Invalidate;
end;

procedure TChatView.CMHintShow(var Message: TLMessage);
begin
  var info := PHintInfo(Message.LParam);
  var onAvatar: boolean;
  var i := messageAt(info^.CursorPos.X, info^.CursorPos.Y, onAvatar);
  if (i < 0) or not FLabels.FTimeHints or (FMessages[i].FKind = mkSystem) then begin
    Message.Result := 1; // nothing under the mouse
    exit;
  end;
  var m := FMessages[i];
  info^.HintStr := if onAvatar then shownNameOf(m.FSender)
    else shownNameOf(m.FSender)+', '+FormatDateTime('yyyy-mm-dd hh:nn:ss', m.FTime, formatSettingsOf(FLanguage));
  // the hint goes when the mouse leaves the bubble, so the next one gets its own
  var r := if onAvatar then m.FAvatar else m.FBubble;
  OffsetRect(r, 0, -VertScrollBar.Position);
  info^.CursorRect := r;
end;

// -- properties ----------------------

procedure TChatView.setMode(value: TChatMode);
begin
  if FMode = value then exit;
  FMode := value;
  if FMode = cmGroup then FColors.FAuto := true;
  settingsChanged;
end;

procedure TChatView.setOwnName(const value: string);
begin
  if FOwnName = value then exit;
  FOwnName := value;
  settingsChanged;
end;

procedure TChatView.setOwnSide(value: TChatSide);
begin
  if FOwnSide = value then exit;
  FOwnSide := value;
  settingsChanged;
end;

procedure TChatView.setTyping(const value: string);
begin
  if FTyping = value then exit;
  var wasAtEnd := VertScrollBar.Position >= VertScrollBar.Range-VertScrollBar.Page-1;
  FTyping := value;
  FTypingPhase := 0;
  FTimer.Enabled := (FTyping <> '') and not (csDesigning in ComponentState);
  settingsChanged;
  if FAutoScroll and wasAtEnd then ScrollToEnd;
end;

procedure TChatView.setParticipants(value: TChatParticipants);
begin
  FParticipants.Assign(value);
end;

procedure TChatView.setMessages(value: TChatMessages);
begin
  FMessages.Assign(value);
end;

procedure TChatView.setBubbles(value: TChatBubbles);
begin
  FBubbles.Assign(value);
end;

procedure TChatView.setAvatars(value: TChatAvatars);
begin
  FAvatars.Assign(value);
end;

procedure TChatView.setLabels(value: TChatLabels);
begin
  FLabels.Assign(value);
end;

procedure TChatView.setColors(value: TChatColors);
begin
  FColors.Assign(value);
end;

function TChatView.getMetric(index: integer): integer;
begin
  result := if index = 0 then FMaxMessages else FPadding;
end;

procedure TChatView.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then begin
    FMaxMessages := value;
    FMessages.BeginUpdate;
    try
      trimMessages;
    finally
      FMessages.EndUpdate;
    end;
  end else FPadding := value;
  settingsChanged;
end;

procedure TChatView.setSelected(value: integer);
begin
  if (value < -1) or (value >= FMessages.Count) then value := -1;
  if FSelected = value then exit;
  FSelected := value;
  Invalidate;
  if Assigned(FOnSelectionChange) then FOnSelectionChange(self, SelectedMessage);
end;

procedure TChatView.setFollow(value: boolean);
begin
  if FAutoScroll = value then exit;
  FAutoScroll := value;
  if value then ScrollToEnd;
end;

procedure TChatView.setLanguage(value: TFormatLanguage);
begin
  if FLanguage = value then exit;
  FLanguage := value;
  settingsChanged;
end;

procedure TChatView.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
