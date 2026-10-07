{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SuggestEdit;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, StdCtrls, Forms, ExtCtrls, LCLType, LMessages;

type
  // how a suggestion has to match the typed text
  TSuggestMatch = (smPrefix, smContains, smWords);
  TGetSuggestionsEvent = procedure(Sender: TObject; const text: string; suggestions: TStrings) of object;
  TSuggestSelectEvent = procedure(Sender: TObject; const suggestion: string) of object;
  TDrawSuggestionEvent = procedure(Sender: TObject; canvas: TCanvas; const r: TRect; index: integer; const suggestion: string; selected: boolean; var handled: boolean) of object;

  { TSuggestPopup }

  // the list lives in a hint window: every widgetset shows one without
  // activating it, so the edit keeps the focus and the main form its look
  TSuggestPopup = class(THintWindow)
  protected
    procedure Paint; override;
    // the stock version focuses the first control, which drags the keyboard
    // and the activation into the list
    procedure DoShowWindow; override;
    // the stock version hands the focus to the control that had it last,
    // the list after a click into it; the edit keeps it on every show
    procedure UpdateShowing; override;
    procedure CreateWnd; override;
    procedure WMNCHitTest(var Message: TLMessage); message LM_NCHITTEST;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { TSuggestEdit }

  // an edit with a list of suggestions dropping under it as the user types:
  // the matches from Items, or whatever OnGetSuggestions fills in. The arrows
  // walk the list, Enter, Tab and Space take the suggestion, Escape closes it
  TSuggestEdit = class(TCustomEdit)
  private
    FItems: TStrings;
    FPopup: TSuggestPopup;
    FList: TListBox;
    FTimer: TTimer;
    FMatch: TSuggestMatch;
    FCaseSensitive, FAutoSelectFirst, FHighlightMatch, FTabAccepts, FSpaceAccepts, FShowOnFocus: boolean;
    FMinChars, FMaxItems, FDelay, FPopupWidth, FMaxVisible: integer;
    FSelecting: boolean; // the text is set from a suggestion, not typed
    FHotItem: integer; // the suggestion under the mouse, -1 off
    FPopupFont: TFont;
    FPopupFontSet: boolean; // PopupFont was assigned, else the list takes Font
    FMatchStyle: TFontStyles;
    FPopupColor, FPopupTextColor, FSelectedColor, FSelectedTextColor, FHoverColor: TColor;
    FSwallowChar: boolean; // the key the list took still sends its character
    FLastShown: string; // the text the list was built for
    FOnGetSuggestions: TGetSuggestionsEvent;
    FOnSelect: TSuggestSelectEvent;
    FOnDrawSuggestion: TDrawSuggestionEvent;
    FOnPopupShow, FOnPopupHide: TNotifyEvent;
    procedure setItems(value: TStrings);
    procedure setMaxVisible(value: integer);
    function matches(const candidate, typed: string): boolean;
    procedure gather(list: TStrings);
    procedure timerFired(Sender: TObject);
    procedure showPopup;
    procedure placePopup;
    procedure listClick(Sender: TObject);
    procedure listDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure listMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure listMouseLeave(Sender: TObject);
    procedure setPopupFont(value: TFont);
    procedure setMatchStyle(value: TFontStyles);
    function getPopupColor(index: integer): TColor;
    procedure setPopupColor(index: integer; value: TColor);
    procedure accept(index: integer);
    procedure moveSelection(delta: integer);
  protected
    procedure Change; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: char); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoOnResize; override;
    procedure WMKillFocus(var Message: TLMKillFocus); message LM_KILLFOCUS;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // builds the list for the text now and shows it; nothing to show hides it
    procedure Suggest;
    procedure HidePopup;
    function PopupVisible: boolean;
  published
    // the suggestions matched against the typed text
    property Items: TStrings read FItems write setItems;
    property MatchMode: TSuggestMatch read FMatch write FMatch default smPrefix;
    property CaseSensitive: boolean read FCaseSensitive write FCaseSensitive default false;
    // the list waits for this many characters
    property MinChars: integer read FMinChars write FMinChars default 1;
    // the list keeps at most this many; 0 takes all
    property MaxItems: integer read FMaxItems write FMaxItems default 0;
    // rows on screen before the list scrolls
    property MaxVisibleItems: integer read FMaxVisible write setMaxVisible default 8;
    // milliseconds after the typing stops before the list updates
    property Delay: integer read FDelay write FDelay default 100;
    // the list; 0 matches the edit
    property PopupWidth: integer read FPopupWidth write FPopupWidth default 0;
    // the first suggestion starts selected, so Enter takes it at once
    property AutoSelectFirst: boolean read FAutoSelectFirst write FAutoSelectFirst default true;
    // the matched part of each suggestion in MatchStyle
    property HighlightMatch: boolean read FHighlightMatch write FHighlightMatch default true;
    // the style of the matched part
    property MatchStyle: TFontStyles read FMatchStyle write setMatchStyle default [fsBold];
    // the font of the list; left alone, the list takes the font of the edit
    property PopupFont: TFont read FPopupFont write setPopupFont stored FPopupFontSet;
    // the list; clDefault takes the colors of the theme
    property PopupColor: TColor index 0 read getPopupColor write setPopupColor default clDefault;
    property PopupTextColor: TColor index 1 read getPopupColor write setPopupColor default clDefault;
    // the selected suggestion
    property SelectedColor: TColor index 2 read getPopupColor write setPopupColor default clDefault;
    property SelectedTextColor: TColor index 3 read getPopupColor write setPopupColor default clDefault;
    // the suggestion under the mouse
    property HoverColor: TColor index 4 read getPopupColor write setPopupColor default clDefault;
    property TabAccepts: boolean read FTabAccepts write FTabAccepts default true;
    // Space takes the selected suggestion; off, it goes into the text, for
    // suggestions of several words
    property SpaceAccepts: boolean read FSpaceAccepts write FSpaceAccepts default true;
    // the list opens as the edit takes the focus, with what it holds
    property ShowOnFocus: boolean read FShowOnFocus write FShowOnFocus default false;
    // fills the suggestions for the text; set, Items is not consulted
    property OnGetSuggestions: TGetSuggestionsEvent read FOnGetSuggestions write FOnGetSuggestions;
    // a suggestion was picked from the list, with a click or a key
    property OnSelect: TSuggestSelectEvent read FOnSelect write FOnSelect;
    property OnDrawSuggestion: TDrawSuggestionEvent read FOnDrawSuggestion write FOnDrawSuggestion;
    property OnPopupShow: TNotifyEvent read FOnPopupShow write FOnPopupShow;
    property OnPopupHide: TNotifyEvent read FOnPopupHide write FOnPopupHide;
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
    property BorderStyle;
    property CharCase;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property MaxLength;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Text;
    property TextHint;
    property Visible;
    property OnChange;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEditingDone;
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
  Math, LCLIntf, ControlPaint;

{ TSuggestPopup }

constructor TSuggestPopup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csNoFocus];
  Color := clWindow;
end;

procedure TSuggestPopup.Paint;
begin
  // the list covers the window, the hint text has nothing to paint
end;

procedure TSuggestPopup.DoShowWindow;
begin
end;

procedure TSuggestPopup.UpdateShowing;
begin
  ActiveControl := nil;
  inherited UpdateShowing;
end;

// a hint window lets the mouse through to what is under it; the list
// takes its clicks
procedure TSuggestPopup.WMNCHitTest(var Message: TLMessage);
begin
  Message.Result := HTCLIENT;
end;

procedure TSuggestPopup.CreateWnd;
begin
  inherited CreateWnd;
  // a click into the list must not take the activation from the form
  keepInactive(Handle);
end;

{ TSuggestEdit }

constructor TSuggestEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FMatch := smPrefix;
  FMinChars := 1;
  FMaxVisible := 8;
  FDelay := 100;
  FAutoSelectFirst := true;
  FHighlightMatch := true;
  FTabAccepts := true;
  FSpaceAccepts := true;
  FHotItem := -1;
  FMatchStyle := [fsBold];
  FPopupFont := TFont.Create;
  FPopupColor := clDefault;
  FPopupTextColor := clDefault;
  FSelectedColor := clDefault;
  FSelectedTextColor := clDefault;
  FHoverColor := clDefault;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.OnTimer := @timerFired;
end;

destructor TSuggestEdit.Destroy;
begin
  FTimer.Enabled := false;
  FreeAndNil(FPopup);
  FItems.Free;
  FPopupFont.Free;
  inherited Destroy;
end;

// -- matching ----------------------

function TSuggestEdit.matches(const candidate, typed: string): boolean;
begin
  var c := if FCaseSensitive then candidate else LowerCase(candidate);
  var t := if FCaseSensitive then typed else LowerCase(typed);
  match FMatch of
    smPrefix: result := Pos(t, c) = 1;
    smContains: result := Pos(t, c) > 0;
  else
    begin
      // every typed word has to start a word of the candidate
      result := true;
      var words := t.Split([' '], TStringSplitOptions.ExcludeEmpty);
      for var w in words do begin
        var found := Pos(w, c) = 1;
        if not found then found := Pos(' '+w, c) > 0;
        if not found then exit(false);
      end;
    end;
  end;
end;

procedure TSuggestEdit.gather(list: TStrings);
begin
  list.Clear;
  var typed := Text;
  if Assigned(FOnGetSuggestions) then begin
    FOnGetSuggestions(self, typed, list);
  end else begin
    for var i := 0 to FItems.Count-1 do begin
      if (typed = '') or matches(FItems[i], typed) then list.Add(FItems[i]);
      if (FMaxItems > 0) and (list.Count >= FMaxItems) then break;
    end;
  end;
  if FMaxItems > 0 then while list.Count > FMaxItems do list.Delete(list.Count-1);
end;

// -- popup ----------------------

procedure TSuggestEdit.showPopup;
begin
  if FPopup = nil then begin
    FPopup := TSuggestPopup.Create(self);
    FList := TListBox.Create(FPopup);
    FList.Parent := FPopup;
    FList.Align := alClient;
    FList.BorderStyle := bsSingle;
    FList.Style := lbOwnerDrawFixed;
    FList.OnClick := @listClick;
    FList.OnDrawItem := @listDraw;
    FList.OnMouseMove := @listMouseMove;
    FList.OnMouseLeave := @listMouseLeave;
    FList.ParentFont := false;
    FList.TabStop := false;
  end;
  FList.Font.Assign(if FPopupFontSet then FPopupFont else Font);
  FList.Color := pick(FPopupColor, clWindow);
  FList.ItemHeight := FList.Canvas.TextHeight('Hg')+scaled(self, 6);
  var wasVisible := FPopup.Visible;
  placePopup;
  if not wasVisible then begin
    // not Show: that ends in a ShowWindow that activates the window
    FPopup.Visible := true;
    if Assigned(FOnPopupShow) then FOnPopupShow(self);
  end;
end;

procedure TSuggestEdit.placePopup;
begin
  var rows := Min(Max(FList.Items.Count, 1), Max(FMaxVisible, 1));
  var h := rows*FList.ItemHeight+scaled(self, 4);
  var w := if FPopupWidth > 0 then scaled(self, FPopupWidth) else Width;
  var origin := ClientToScreen(Point(0, Height));
  var area := Screen.MonitorFromPoint(origin).WorkareaRect;
  var top := origin.Y;
  // under the edit when it fits, over it otherwise
  if top+h > area.Bottom then top := ClientToScreen(Point(0, 0)).Y-h;
  var left := Min(origin.X, area.Right-w);
  FPopup.SetBounds(left, top, w, h);
end;

procedure TSuggestEdit.Suggest;
begin
  FTimer.Enabled := false;
  if (csDesigning in ComponentState) or not HandleAllocated or ReadOnly then exit;
  if length(Text) < FMinChars then begin
    HidePopup;
    exit;
  end;
  var list := TStringList.Create;
  try
    gather(list);
    if list.Count = 0 then begin
      HidePopup;
      exit;
    end;
    showPopup;
    FList.Items.Assign(list);
    FList.ItemIndex := if FAutoSelectFirst then 0 else -1;
    FHotItem := -1;
    FLastShown := Text;
    placePopup;
  finally
    list.Free;
  end;
end;

procedure TSuggestEdit.HidePopup;
begin
  FTimer.Enabled := false;
  if (FPopup = nil) or not FPopup.Visible then exit;
  FPopup.Hide;
  if Assigned(FOnPopupHide) then FOnPopupHide(self);
end;

function TSuggestEdit.PopupVisible: boolean;
begin
  result := (FPopup <> nil) and FPopup.Visible;
end;

procedure TSuggestEdit.WMKillFocus(var Message: TLMKillFocus);
begin
  inherited;
  // a click into the list keeps it; anything else closes it
  if (FPopup <> nil) and (Message.FocusedWnd <> FList.Handle) and (Message.FocusedWnd <> FPopup.Handle) then HidePopup;
end;

procedure TSuggestEdit.listDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
  var canvas := FList.Canvas;
  var selected := odSelected in State;
  var item := FList.Items[Index];
  var handled := false;
  if Assigned(FOnDrawSuggestion) then FOnDrawSuggestion(self, canvas, ARect, Index, item, selected, handled);
  if handled then exit;
  var back := pick(FPopupColor, clWindow);
  var chosen := pick(FSelectedColor, clHighlight);
  canvas.Brush.Style := bsSolid;
  canvas.Brush.Color := if selected then chosen else if (Index = FHotItem) and hoverEnabled then pick(FHoverColor, ControlPaint.hoverColor(back)) else back;
  canvas.FillRect(ARect);
  canvas.Brush.Style := bsClear;
  var ink := if selected then pick(FSelectedTextColor, contrastText(chosen)) else pick(FPopupTextColor, clWindowText);
  var x := ARect.Left+scaled(self, 4);
  var y := ARect.Top+(ARect.Height-canvas.TextHeight('Hg')) div 2;
  var typed := self.Text;
  var at := 0;
  if FHighlightMatch and (typed <> '') then at := Pos(if FCaseSensitive then typed else LowerCase(typed), if FCaseSensitive then item else LowerCase(item));
  canvas.Font.Color := ink;
  var plain := canvas.Font.Style;
  var piece := procedure(const s: string; marked: boolean)
  begin
    if s = '' then exit;
    canvas.Font.Style := if marked then plain+FMatchStyle else plain;
    canvas.TextOut(x, y, s);
    x += canvas.TextWidth(s);
  end;
  if at = 0 then piece(item, false)
  else begin
    piece(Copy(item, 1, at-1), false);
    piece(Copy(item, at, length(typed)), true);
    piece(Copy(item, at+length(typed), MaxInt), false);
  end;
  canvas.Font.Style := plain;
  canvas.Brush.Style := bsSolid;
end;

procedure TSuggestEdit.listMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  var hot := FList.ItemAtPos(Point(X, Y), true);
  if hot = FHotItem then exit;
  FHotItem := hot;
  FList.Invalidate;
end;

procedure TSuggestEdit.listMouseLeave(Sender: TObject);
begin
  if FHotItem < 0 then exit;
  FHotItem := -1;
  FList.Invalidate;
end;

procedure TSuggestEdit.setPopupFont(value: TFont);
begin
  FPopupFont.Assign(value);
  FPopupFontSet := true;
  if FList <> nil then begin
    FList.Font.Assign(FPopupFont);
    FList.Invalidate;
  end;
end;

procedure TSuggestEdit.setMatchStyle(value: TFontStyles);
begin
  if FMatchStyle = value then exit;
  FMatchStyle := value;
  if FList <> nil then FList.Invalidate;
end;

function TSuggestEdit.getPopupColor(index: integer): TColor;
begin
  result := match index of
    0: FPopupColor;
    1: FPopupTextColor;
    2: FSelectedColor;
    3: FSelectedTextColor;
  else
    FHoverColor
  end;
end;

procedure TSuggestEdit.setPopupColor(index: integer; value: TColor);
begin
  if getPopupColor(index) = value then exit;
  match index of
    0: FPopupColor := value;
    1: FPopupTextColor := value;
    2: FSelectedColor := value;
    3: FSelectedTextColor := value;
  else
    FHoverColor := value;
  end;
  if FList <> nil then begin
    FList.Color := pick(FPopupColor, clWindow);
    FList.Invalidate;
  end;
end;

procedure TSuggestEdit.listClick(Sender: TObject);
begin
  if FList.ItemIndex >= 0 then accept(FList.ItemIndex);
end;

procedure TSuggestEdit.accept(index: integer);
begin
  if (FPopup = nil) or (index < 0) or (index >= FList.Items.Count) then exit;
  var s := FList.Items[index];
  FSelecting := true;
  try
    Text := s;
    SelStart := length(Text);
  finally
    FSelecting := false;
  end;
  HidePopup;
  if CanFocus then SetFocus;
  if Assigned(FOnSelect) then FOnSelect(self, s);
end;

procedure TSuggestEdit.moveSelection(delta: integer);
begin
  if not PopupVisible or (FList.Items.Count = 0) then exit;
  var n := FList.Items.Count;
  var i := FList.ItemIndex+delta;
  if i < 0 then i := n-1;
  if i >= n then i := 0;
  FList.ItemIndex := i;
end;

// -- input ----------------------

procedure TSuggestEdit.Change;
begin
  inherited Change;
  if FSelecting or (csLoading in ComponentState) or (csDesigning in ComponentState) then exit;
  FTimer.Enabled := false;
  if FDelay <= 0 then Suggest
  else begin
    FTimer.Interval := FDelay;
    FTimer.Enabled := true;
  end;
end;

procedure TSuggestEdit.timerFired(Sender: TObject);
begin
  FTimer.Enabled := false;
  if Focused then Suggest;
end;

procedure TSuggestEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if PopupVisible then begin
    match Key of
      VK_DOWN: begin
        moveSelection(1);
        Key := 0;
        FSwallowChar := true;
        exit;
      end;
      VK_UP: begin
        moveSelection(-1);
        Key := 0;
        FSwallowChar := true;
        exit;
      end;
      VK_NEXT: begin
        moveSelection(Max(FMaxVisible, 1));
        Key := 0;
        FSwallowChar := true;
        exit;
      end;
      VK_PRIOR: begin
        moveSelection(-Max(FMaxVisible, 1));
        Key := 0;
        FSwallowChar := true;
        exit;
      end;
      VK_RETURN: if FList.ItemIndex >= 0 then begin
        accept(FList.ItemIndex);
        Key := 0;
        FSwallowChar := true;
        exit;
      end else HidePopup;
      VK_TAB: if FTabAccepts and (FList.ItemIndex >= 0) then begin
        accept(FList.ItemIndex);
        Key := 0;
        FSwallowChar := true;
        exit;
      end;
      VK_SPACE: if FSpaceAccepts and (FList.ItemIndex >= 0) then begin
        accept(FList.ItemIndex);
        Key := 0;
        FSwallowChar := true;
        exit;
      end;
      VK_ESCAPE: begin
        HidePopup;
        Key := 0;
        FSwallowChar := true;
        exit;
      end;
    end;
  end else if (Key = VK_DOWN) and (ssAlt in Shift) then begin
    Key := 0;
    Suggest;
    exit;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TSuggestEdit.KeyPress(var Key: char);
begin
  // the key the list took leaves no beep behind
  if FSwallowChar then begin
    FSwallowChar := false;
    if Key in [#13, #27, #9, #32] then Key := #0;
  end;
  inherited KeyPress(Key);
end;

procedure TSuggestEdit.DoEnter;
begin
  inherited DoEnter;
  if FShowOnFocus and not (csDesigning in ComponentState) then Suggest;
end;

procedure TSuggestEdit.DoExit;
begin
  inherited DoExit;
  FTimer.Enabled := false;
end;

procedure TSuggestEdit.DoOnResize;
begin
  inherited DoOnResize;
  if PopupVisible then placePopup;
end;

// -- properties ----------------------

procedure TSuggestEdit.setItems(value: TStrings);
begin
  FItems.Assign(value);
end;

procedure TSuggestEdit.setMaxVisible(value: integer);
begin
  if value < 1 then value := 1;
  if FMaxVisible = value then exit;
  FMaxVisible := value;
  if PopupVisible then placePopup;
end;

end.
