{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit TagEditor;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LMessages, LCLType, SuggestEdit, ControlPaint;

type
  // the outline of a chip: a pill, a box rounded by ChipRadius, a square box,
  // or a tag with a point on the left
  TChipShape = (chPill, chRounded, chSquare, chTag);
  TTagEvent = procedure(Sender: TObject; const tag: string) of object;
  TTagAllowEvent = procedure(Sender: TObject; var tag: string; var allow: boolean) of object;

  { TTagEditor }

  // a field of tags: each one a chip with a cross, the typing goes into the
  // free end of the field. Enter, a delimiter or the focus leaving adds the
  // text as a tag; Backspace on the empty field takes the last tag back.
  // Suggestions offer tags while typing
  TTagEditor = class(TCustomControl)
  private
    FTags: TStrings;
    FEdit: TSuggestEdit;
    FDelimiters: string;
    FAllowDuplicates, FCaseSensitive, FReadOnly, FWordWrap, FShowClose: boolean;
    FMaxTags, FCornerRadius, FPadding, FSpacing, FChipRadius: integer;
    FChipColor, FChipTextColor, FCloseColor, FBorderColor, FFocusBorderColor, FFieldColor: TColor;
    FSelected, FHotClose: integer;
    FAntialiasing: TAntialiasSetting;
    FOnDrawChip: TCustomDrawEvent;
    FChipShape: TChipShape;
    FOnTagAdded, FOnTagRemoved, FOnTagClick: TTagEvent;
    FOnTagAllow: TTagAllowEvent;
    FOnChange: TNotifyEvent;
    function getSuggestions: TStrings;
    procedure setSuggestions(value: TStrings);
    function getTextHint: string;
    procedure setTextHint(const value: string);
    procedure setTags(value: TStrings);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setChipShape(value: TChipShape);
    procedure tagsChanged(Sender: TObject);
    function chipHeight: integer;
    function chipRect(index: integer): TRect;
    function closeRect(index: integer): TRect;
    function chipAt(x, y: integer; out onClose: boolean): integer;
    function editOrigin: TPoint;
    procedure layout;
    procedure editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure editKeyPress(Sender: TObject; var Key: char);
    procedure editSelect(Sender: TObject; const suggestion: string);
    procedure editEnter(Sender: TObject);
    procedure editExit(Sender: TObject);
    function indexOfTag(const tag: string): integer;
    procedure changed;
  protected
    procedure Paint; override;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
    procedure DoOnResize; override;
    procedure CreateWnd; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetFocus; override;
    function Focused: Boolean; override;
    // adds a tag unless refused; true when it went in
    function AddTag(const tag: string): boolean;
    procedure RemoveTag(index: integer);
    procedure Clear;
    // the text in the field, not yet a tag
    function PendingText: string;
    // the tags joined by the first delimiter
    function TagsAsText: string;
    property Edit: TSuggestEdit read FEdit;
  published
    property Tags: TStrings read FTags write setTags;
    // offered while typing
    property Suggestions: TStrings read getSuggestions write setSuggestions;
    property TextHint: string read getTextHint write setTextHint;
    // characters that end a tag while typing
    property Delimiters: string read FDelimiters write FDelimiters;
    property AllowDuplicates: boolean index 0 read getFlag write setFlag default false;
    property CaseSensitive: boolean index 1 read getFlag write setFlag default false;
    property ReadOnly: boolean index 2 read getFlag write setFlag default false;
    // the chips flow onto more lines and the control grows
    property WordWrap: boolean index 3 read getFlag write setFlag default true;
    property ShowCloseButtons: boolean index 4 read getFlag write setFlag default true;
    // 0 for no limit
    property MaxTags: integer index 0 read getMetric write setMetric default 0;
    property CornerRadius: integer index 1 read getMetric write setMetric default 4;
    property Padding: integer index 2 read getMetric write setMetric default 4;
    property Spacing: integer index 3 read getMetric write setMetric default 4;
    property ChipRadius: integer index 4 read getMetric write setMetric default 10;
    // clDefault takes the colors of the theme
    property ChipColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ChipTextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property CloseColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property FieldColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over a chip: dsSelected for the one the keyboard is on; `handled`
    // true leaves the text out
    property OnDrawChip: TCustomDrawEvent read FOnDrawChip write FOnDrawChip;
    property ChipShape: TChipShape read FChipShape write setChipShape default chRounded;
    property OnTagAdded: TTagEvent read FOnTagAdded write FOnTagAdded;
    property OnTagRemoved: TTagEvent read FOnTagRemoved write FOnTagRemoved;
    property OnTagClick: TTagEvent read FOnTagClick write FOnTagClick;
    // before a tag goes in; the text may be changed or refused
    property OnTagAllow: TTagAllowEvent read FOnTagAllow write FOnTagAllow;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
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
    property OnMouseEnter;
    property OnMouseLeave;
    property OnResize;
  end;

implementation

uses
  Math;

constructor TTagEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop]-[csSetCaption];
  FTags := TStringList.Create;
  TStringList(FTags).OnChange := @tagsChanged;
  FDelimiters := ',;';
  FWordWrap := true;
  FShowClose := true;
  FCornerRadius := 4;
  FPadding := 4;
  FSpacing := 4;
  FChipRadius := 10;
  FChipColor := clDefault;
  FChipTextColor := clDefault;
  FCloseColor := clDefault;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FFieldColor := clDefault;
  FSelected := -1;
  FHotClose := -1;
  FEdit := TSuggestEdit.Create(self);
  FEdit.Parent := self;
  FEdit.BorderStyle := bsNone;
  FEdit.ParentFont := true;
  FEdit.Color := clWindow;
  FEdit.ControlStyle := FEdit.ControlStyle+[csNoDesignSelectable];
  FEdit.SetSubComponent(true);
  FEdit.TabAccepts := false;
  FEdit.OnKeyDown := @editKeyDown;
  FEdit.OnKeyPress := @editKeyPress;
  FEdit.OnSelect := @editSelect;
  FEdit.OnEnter := @editEnter;
  FEdit.OnExit := @editExit;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TTagEditor.Destroy;
begin
  FTags.Free;
  inherited Destroy;
end;

class function TTagEditor.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 31;
end;

procedure TTagEditor.Loaded;
begin
  inherited Loaded;
  layout;
end;

// -- geometry ----------------------

function TTagEditor.chipHeight: integer;
begin
  result := Canvas.TextHeight('Hg')+scaled(self, 6);
end;

function TTagEditor.chipRect(index: integer): TRect;
begin
  var pad := scaled(self, FPadding);
  var gap := scaled(self, FSpacing);
  var h := chipHeight;
  var x := pad;
  var y := pad;
  var closeW := if FShowClose and not FReadOnly then h-scaled(self, 4) else 0;
  for var i := 0 to FTags.Count-1 do begin
    var w := Canvas.TextWidth(FTags[i])+scaled(self, 16)+closeW;
    if FWordWrap and (x > pad) and (x+w > ClientWidth-pad) then begin
      x := pad;
      y += h+gap;
    end;
    if i = index then exit(Rect(x, y, x+w, y+h));
    x += w+gap;
  end;
  result := Rect(x, y, x, y+h);
end;

function TTagEditor.closeRect(index: integer): TRect;
begin
  var r := chipRect(index);
  var size := r.Height-scaled(self, 8);
  result := Rect(r.Right-size-scaled(self, 6), r.Top+(r.Height-size) div 2, r.Right-scaled(self, 6), r.Top+(r.Height-size) div 2+size);
end;

function TTagEditor.chipAt(x, y: integer; out onClose: boolean): integer;
begin
  result := -1;
  onClose := false;
  for var i := 0 to FTags.Count-1 do if chipRect(i).Contains(Point(x, y)) then begin
    onClose := FShowClose and not FReadOnly and closeRect(i).Contains(Point(x, y));
    exit(i);
  end;
end;

// where the free end of the field starts: after the last chip, or on a new
// line when the rest of the line is too short
function TTagEditor.editOrigin: TPoint;
begin
  var pad := scaled(self, FPadding);
  var gap := scaled(self, FSpacing);
  var h := chipHeight;
  if FTags.Count = 0 then exit(Point(pad, pad));
  var last := chipRect(FTags.Count-1);
  var minEdit := scaled(self, 60);
  if FWordWrap and (last.Right+gap+minEdit > ClientWidth-pad) then exit(Point(pad, last.Bottom+gap));
  result := Point(last.Right+gap, last.Top);
end;

procedure TTagEditor.layout;
begin
  if (FEdit = nil) or not HandleAllocated then exit;
  var pad := scaled(self, FPadding);
  var o := editOrigin;
  var h := FEdit.Height;
  if h <= 0 then h := Canvas.TextHeight('Hg');
  var w := ClientWidth-pad-o.X;
  if not FWordWrap and (w < scaled(self, 60)) then w := scaled(self, 60);
  FEdit.SetBounds(o.X+scaled(self, 4), o.Y+(chipHeight-h) div 2, Max(w-scaled(self, 4), 10), h);
end;

procedure TTagEditor.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  var pad := scaled(self, FPadding);
  var o := editOrigin;
  PreferredHeight := o.Y+chipHeight+pad;
end;

procedure TTagEditor.DoOnResize;
begin
  inherited DoOnResize;
  layout;
end;

procedure TTagEditor.CreateWnd;
begin
  inherited CreateWnd;
  layout;
end;

// -- painting ----------------------

// the field goes gray with the rest of the control
procedure TTagEditor.CMEnabledChanged(var Message: TLMessage);
begin
  inherited CMEnabledChanged(Message);
  FEdit.Color := if Enabled then clWindow else clBtnFace;
  Invalidate;
end;

procedure TTagEditor.Paint;
begin
  var border := pick(FBorderColor, clBtnShadow);
  if FEdit.Focused and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := pick(FFieldColor, clWindow);
  var chip := pick(FChipColor, clHighlight);
  var chipText := pick(FChipTextColor, contrastText(chip));
  var closeColor := pick(FCloseColor, chipText);
  if not Enabled then begin
    field := ColorToRGB(clBtnFace);
    chip := blend(chip, clBtnFace, 50);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  for var i := 0 to FTags.Count-1 do begin
    var r := chipRect(i);
    var fill := if i = FSelected then blend(chip, clWindowText, 25) else chip;
    match FChipShape of
      chPill: paintRoundRect(sp, r, r.Height div 2, fill, clNone);
      chSquare: paintRoundRect(sp, r, 0, fill, clNone);
      chTag: begin
        var tip := r.Height div 3;
        sp.FillPolygon([PointF(r.Left+tip, r.Top), PointF(r.Right, r.Top), PointF(r.Right, r.Bottom), PointF(r.Left+tip, r.Bottom), PointF(r.Left, (r.Top+r.Bottom)/2)], fill);
      end;
    else
      paintRoundRect(sp, r, Min(scaled(self, FChipRadius), r.Height div 2), fill, clNone);
    end;
    if FShowClose and not FReadOnly then begin
      var c := closeRect(i);
      if Enabled and hoverEnabled and (i = FHotClose) then paintCircle(sp, (c.Left+c.Right) div 2, (c.Top+c.Bottom) div 2, c.Width div 2+1, blend(fill, clWhite, 30), clNone);
      paintCross(sp, c, Max(c.Width div 2, 4), closeColor);
    end;
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  for var i := 0 to FTags.Count-1 do begin
    var r := chipRect(i);
    var handled := false;
    if Assigned(FOnDrawChip) then begin
      var state: TDrawState := [];
      if i = FSelected then state += [dsSelected];
      if not Enabled then state += [dsDisabled];
      FOnDrawChip(self, Canvas, r, i, state, handled);
    end;
    if handled then continue;
    var box := Rect(r.Left+scaled(self, 8)+(if FChipShape = chTag then r.Height div 3 else 0), r.Top, r.Right-scaled(self, 8)-(if FShowClose and not FReadOnly then r.Height-scaled(self, 4) else 0), r.Bottom);
    paintCenteredText(Canvas, box, FTags[i], chipText);
  end;
end;

// -- input ----------------------

function TTagEditor.indexOfTag(const tag: string): integer;
begin
  result := -1;
  for var i := 0 to FTags.Count-1 do if (FCaseSensitive and (FTags[i] = tag)) or (not FCaseSensitive and SameText(FTags[i], tag)) then exit(i);
end;

function TTagEditor.AddTag(const tag: string): boolean;
begin
  result := false;
  var t := Trim(tag);
  if t = '' then exit;
  if (FMaxTags > 0) and (FTags.Count >= FMaxTags) then exit;
  if not FAllowDuplicates and (indexOfTag(t) >= 0) then exit;
  var allow := true;
  if Assigned(FOnTagAllow) then FOnTagAllow(self, t, allow);
  if not allow or (t = '') then exit;
  FTags.Add(t);
  if Assigned(FOnTagAdded) then FOnTagAdded(self, t);
  result := true;
end;

procedure TTagEditor.RemoveTag(index: integer);
begin
  if (index < 0) or (index >= FTags.Count) then exit;
  var t := FTags[index];
  FTags.Delete(index);
  FSelected := -1;
  if Assigned(FOnTagRemoved) then FOnTagRemoved(self, t);
end;

procedure TTagEditor.Clear;
begin
  FTags.Clear;
  FEdit.Text := '';
end;

function TTagEditor.PendingText: string;
begin
  result := FEdit.Text;
end;

function TTagEditor.TagsAsText: string;
begin
  var sep := if FDelimiters = '' then ',' else FDelimiters[1];
  result := '';
  for var i := 0 to FTags.Count-1 do begin
    if i > 0 then result += sep+' ';
    result += FTags[i];
  end;
end;

procedure TTagEditor.editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  KeyDown(Key, Shift);
  if Key = 0 then exit;
  if FReadOnly then exit;
  match Key of
    VK_RETURN: begin
      if FEdit.PopupVisible then exit;
      if AddTag(FEdit.Text) then FEdit.Text := '';
      Key := 0;
    end;
    VK_BACK: if FEdit.Text = '' then begin
      // the first press marks the last tag, the second takes it
      if FSelected = FTags.Count-1 then RemoveTag(FSelected) else FSelected := FTags.Count-1;
      Invalidate;
      Key := 0;
    end;
    VK_DELETE: if (FEdit.Text = '') and (FSelected >= 0) then begin
      RemoveTag(FSelected);
      Key := 0;
    end;
    VK_LEFT: if (FEdit.Text = '') and (FTags.Count > 0) then begin
      FSelected := if FSelected < 0 then FTags.Count-1 else Max(FSelected-1, 0);
      Invalidate;
      Key := 0;
    end;
    VK_RIGHT: if (FEdit.Text = '') and (FSelected >= 0) then begin
      FSelected := if FSelected >= FTags.Count-1 then -1 else FSelected+1;
      Invalidate;
      Key := 0;
    end;
    VK_ESCAPE: if FSelected >= 0 then begin
      FSelected := -1;
      Invalidate;
      Key := 0;
    end;
  end;
end;

procedure TTagEditor.editKeyPress(Sender: TObject; var Key: char);
begin
  KeyPress(Key);
  if Key = #0 then exit;
  if Key = #13 then begin
    Key := #0;
    exit;
  end;
  if (Key <> #0) and (Pos(Key, FDelimiters) > 0) and not FReadOnly then begin
    if AddTag(FEdit.Text) then FEdit.Text := '';
    Key := #0;
    exit;
  end;
  if (FSelected >= 0) and (Key >= ' ') then begin
    FSelected := -1;
    Invalidate;
  end;
end;

procedure TTagEditor.editSelect(Sender: TObject; const suggestion: string);
begin
  if AddTag(suggestion) then FEdit.Text := '';
end;

procedure TTagEditor.editEnter(Sender: TObject);
begin
  Invalidate;
  DoEnter;
end;

procedure TTagEditor.editExit(Sender: TObject);
begin
  // the text left in the field becomes a tag
  if not FReadOnly and (Trim(FEdit.Text) <> '') then if AddTag(FEdit.Text) then FEdit.Text := '';
  FSelected := -1;
  Invalidate;
  DoExit;
end;

procedure TTagEditor.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var onClose: boolean;
  var i := chipAt(X, Y, onClose);
  if i >= 0 then begin
    if onClose then RemoveTag(i)
    else begin
      FSelected := i;
      Invalidate;
      if Assigned(FOnTagClick) then FOnTagClick(self, FTags[i]);
    end;
  end;
  FEdit.SetFocus;
end;

procedure TTagEditor.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var onClose: boolean;
  var i := chipAt(X, Y, onClose);
  if not onClose then i := -1;
  if i <> FHotClose then begin
    FHotClose := i;
    Invalidate;
  end;
end;

procedure TTagEditor.MouseLeave;
begin
  inherited MouseLeave;
  if FHotClose >= 0 then begin
    FHotClose := -1;
    Invalidate;
  end;
end;

procedure TTagEditor.SetFocus;
begin
  if FEdit.CanFocus then FEdit.SetFocus else inherited SetFocus;
end;

function TTagEditor.Focused: Boolean;
begin
  result := FEdit.Focused or inherited Focused;
end;

procedure TTagEditor.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  layout;
end;

procedure TTagEditor.tagsChanged(Sender: TObject);
begin
  if csDestroying in ComponentState then exit;
  if FSelected >= FTags.Count then FSelected := -1;
  changed;
end;

procedure TTagEditor.changed;
begin
  InvalidatePreferredSize;
  AdjustSize;
  layout;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

// -- properties ----------------------

function TTagEditor.getSuggestions: TStrings;
begin
  result := FEdit.Items;
end;

procedure TTagEditor.setSuggestions(value: TStrings);
begin
  FEdit.Items := value;
end;

function TTagEditor.getTextHint: string;
begin
  result := FEdit.TextHint;
end;

procedure TTagEditor.setTextHint(const value: string);
begin
  FEdit.TextHint := value;
end;

procedure TTagEditor.setTags(value: TStrings);
begin
  FTags.Assign(value);
end;

function TTagEditor.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FAllowDuplicates;
    1: result := FCaseSensitive;
    2: result := FReadOnly;
    3: result := FWordWrap;
    _: result := FShowClose;
  end;
end;

procedure TTagEditor.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAllowDuplicates := value;
    1: FCaseSensitive := value;
    2: FReadOnly := value;
    3: FWordWrap := value;
    _: FShowClose := value;
  end;
  FEdit.ReadOnly := FReadOnly;
  changed;
end;

function TTagEditor.getMetric(index: integer): integer;
begin
  match index of
    0: result := FMaxTags;
    1: result := FCornerRadius;
    2: result := FPadding;
    3: result := FSpacing;
    _: result := FChipRadius;
  end;
end;

procedure TTagEditor.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FMaxTags := value;
    1: FCornerRadius := value;
    2: FPadding := value;
    3: FSpacing := value;
    _: FChipRadius := value;
  end;
  changed;
end;

function TTagEditor.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FChipColor;
    1: result := FChipTextColor;
    2: result := FCloseColor;
    3: result := FBorderColor;
    4: result := FFocusBorderColor;
    _: result := FFieldColor;
  end;
end;

procedure TTagEditor.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FChipColor := value;
    1: FChipTextColor := value;
    2: FCloseColor := value;
    3: FBorderColor := value;
    4: FFocusBorderColor := value;
    _: FFieldColor := value;
  end;
  Invalidate;
end;

procedure TTagEditor.setChipShape(value: TChipShape);
begin
  if FChipShape = value then exit;
  FChipShape := value;
  Invalidate;
end;

procedure TTagEditor.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
