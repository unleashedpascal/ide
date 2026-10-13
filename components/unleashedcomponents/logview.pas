{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit LogView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, LMessages, ControlPaint;

type
  TLogLevel = (llDebug, llInfo, llSuccess, llWarning, llError);
  TLogLevels = set of TLogLevel;
  TLogLineEvent = procedure(Sender: TObject; index: integer; const text: string; level: TLogLevel) of object;

  TLogLine = record
    time: TDateTime;
    level: TLogLevel;
    text: string;
  end;

  { TLogView }

  // an append-only log: a line per message with its level in color, the
  // time before it, the newest at the bottom and the view following them.
  // Lines past MaxLines go first; a filter hides levels
  TLogView = class(TScrollingWinControl)
  private
    FLines: array of TLogLine;
    FCount: integer;
    FMaxLines, FPadding: integer;
    FLanguage: TFormatLanguage;
    FAutoScroll, FShowTime, FShowLevel, FAlternate: boolean;
    FTimeFormat: string;
    FFilter: TLogLevels;
    FVisible: array of integer; // indexes of the lines the filter keeps
    FSelected: integer; // index into FVisible
    FColors: array[TLogLevel] of TColor;
    FTimeColor: TColor;
    FOnLineClick: TLogLineEvent;
    FOnLineAdded: TLogLineEvent;
    procedure setMetric(index: integer; value: integer);
    procedure setLanguage(value: TFormatLanguage);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setTimeFormat(const value: string);
    procedure setFilter(value: TLogLevels);
    procedure setLevelColor(index: integer; value: TColor);
    function getLevelColor(index: integer): TColor;
    procedure setTimeColor(value: TColor);
    function lineHeight: integer;
    procedure refilter;
    procedure updateRange;
    function lineAt(y: integer): integer;
    function levelName(level: TLogLevel): string;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoOnResize; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure FontChanged(Sender: TObject); override;
    procedure WMVScroll(var Message: TLMVScroll); message LM_VSCROLL;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Add(const text: string; level: TLogLevel=llInfo);
    procedure Debug(const text: string);
    procedure Info(const text: string);
    procedure Success(const text: string);
    procedure Warning(const text: string);
    procedure Error(const text: string);
    procedure Clear;
    function Count: integer;
    function Line(index: integer): TLogLine;
    // the lines as text, the filter applied
    function AsText: string;
    procedure CopyToClipboard;
    procedure SaveToFile(const fileName: string);
    procedure ScrollToEnd;
  published
    // lines kept; 0 keeps every one
    property MaxLines: integer index 0 read getMetric write setMetric default 1000;
    property Padding: integer index 1 read getMetric write setMetric default 4;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    // the view follows the newest line
    property AutoScroll: boolean index 0 read getFlag write setFlag default true;
    property ShowTime: boolean index 1 read getFlag write setFlag default true;
    // the level name before the text
    property ShowLevel: boolean index 2 read getFlag write setFlag default false;
    // every other line on a lighter band
    property AlternateRows: boolean index 3 read getFlag write setFlag default false;
    property TimeFormat: string read FTimeFormat write setTimeFormat;
    // the levels on show
    property Filter: TLogLevels read FFilter write setFilter default [llDebug, llInfo, llSuccess, llWarning, llError];
    // clDefault takes the colors of the theme
    property DebugColor: TColor index 0 read getLevelColor write setLevelColor default clDefault;
    property InfoColor: TColor index 1 read getLevelColor write setLevelColor default clDefault;
    property SuccessColor: TColor index 2 read getLevelColor write setLevelColor default clDefault;
    property WarningColor: TColor index 3 read getLevelColor write setLevelColor default clDefault;
    property ErrorColor: TColor index 4 read getLevelColor write setLevelColor default clDefault;
    property TimeColor: TColor read FTimeColor write setTimeColor default clDefault;
    property OnLineClick: TLogLineEvent read FOnLineClick write FOnLineClick;
    property OnLineAdded: TLogLineEvent read FOnLineAdded write FOnLineAdded;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsSingle;
    // the background, which the frame of the theme takes for its inner line
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
  Math, Clipbrd;

constructor TLogView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FMaxLines := 1000;
  FPadding := 4;
  FAutoScroll := true;
  FShowTime := true;
  FTimeFormat := 'hh:nn:ss';
  FFilter := [llDebug, llInfo, llSuccess, llWarning, llError];
  FSelected := -1;
  for var l := low(TLogLevel) to high(TLogLevel) do FColors[l] := clDefault;
  FTimeColor := clDefault;
  Color := clWindow;
  BorderStyle := bsSingle;
  TabStop := true;
  DoubleBuffered := true;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Visible := false;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TLogView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 300;
  result.cy := 150;
end;

// -- lines ----------------------

procedure TLogView.Add(const text: string; level: TLogLevel);
begin
  if (FMaxLines > 0) and (FCount >= FMaxLines) then begin
    Move(FLines[1], FLines[0], (FCount-1)*SizeOf(TLogLine));
    // the moved slot kept its string reference; the last slot is reset below
    FillChar(FLines[FCount-1], SizeOf(TLogLine), 0);
    dec(FCount);
  end;
  if FCount >= length(FLines) then SetLength(FLines, Max(FCount*2, 64));
  FLines[FCount].time := Now;
  FLines[FCount].level := level;
  FLines[FCount].text := text;
  inc(FCount);
  refilter;
  if Assigned(FOnLineAdded) then FOnLineAdded(self, FCount-1, text, level);
  if FAutoScroll then ScrollToEnd else Invalidate;
end;

procedure TLogView.Debug(const text: string);
begin
  Add(text, llDebug);
end;

procedure TLogView.Info(const text: string);
begin
  Add(text, llInfo);
end;

procedure TLogView.Success(const text: string);
begin
  Add(text, llSuccess);
end;

procedure TLogView.Warning(const text: string);
begin
  Add(text, llWarning);
end;

procedure TLogView.Error(const text: string);
begin
  Add(text, llError);
end;

procedure TLogView.Clear;
begin
  for var i := 0 to FCount-1 do FLines[i].text := '';
  FCount := 0;
  FSelected := -1;
  refilter;
  Invalidate;
end;

function TLogView.Count: integer;
begin
  result := FCount;
end;

function TLogView.Line(index: integer): TLogLine;
begin
  result := FLines[index];
end;

function TLogView.levelName(level: TLogLevel): string;
begin
  result := match level of
    llDebug: 'DEBUG';
    llInfo: 'INFO';
    llSuccess: 'OK';
    llWarning: 'WARN';
  else
    'ERROR'
  end;
end;

function TLogView.AsText: string;
begin
  var sb := TStringList.Create;
  try
    for var v in FVisible do begin
      var s := '';
      if FShowTime then s += FormatDateTime(FTimeFormat, FLines[v].time, formatSettingsOf(FLanguage))+' ';
      if FShowLevel then s += '['+levelName(FLines[v].level)+'] ';
      sb.Add(s+FLines[v].text);
    end;
    result := sb.Text;
  finally
    sb.Free;
  end;
end;

procedure TLogView.CopyToClipboard;
begin
  Clipboard.AsText := AsText;
end;

procedure TLogView.SaveToFile(const fileName: string);
begin
  var f := TStringList.Create;
  try
    f.Text := AsText;
    f.SaveToFile(fileName);
  finally
    f.Free;
  end;
end;

procedure TLogView.refilter;
begin
  SetLength(FVisible, FCount);
  var n := 0;
  for var i := 0 to FCount-1 do if FLines[i].level in FFilter then begin
    FVisible[n] := i;
    inc(n);
  end;
  SetLength(FVisible, n);
  if FSelected >= n then FSelected := -1;
  updateRange;
end;

// -- scrolling ----------------------

function TLogView.lineHeight: integer;
begin
  result := Canvas.TextHeight('Hg')+scaled(self, 2);
end;

procedure TLogView.updateRange;
begin
  if not HandleAllocated then exit;
  VertScrollBar.Increment := lineHeight;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := length(FVisible)*lineHeight+scaled(self, FPadding)*2;
end;

procedure TLogView.ScrollToEnd;
begin
  updateRange;
  VertScrollBar.Position := Max(VertScrollBar.Range-VertScrollBar.Page, 0);
  Invalidate;
end;

procedure TLogView.WMVScroll(var Message: TLMVScroll);
begin
  inherited WMVScroll(Message);
  Invalidate;
end;

function TLogView.lineAt(y: integer): integer;
begin
  var i := (y+VertScrollBar.Position-scaled(self, FPadding)) div lineHeight;
  result := if (i >= 0) and (i < length(FVisible)) then i else -1;
end;

// a scroll repaints everything: shifting the pixels would carry the ring of
// the focus and the row bands into the content
procedure TLogView.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TLogView.DoOnResize;
begin
  inherited DoOnResize;
  updateRange;
  if FAutoScroll then ScrollToEnd;
end;

// -- painting ----------------------

procedure TLogView.Paint;
begin
  var back := ColorToRGB(Color);
  var timeColor := pick(FTimeColor, clGrayText);
  var levelColors: array[TLogLevel] of TColor;
  levelColors[llDebug] := pick(FColors[llDebug], clGrayText);
  levelColors[llInfo] := pick(FColors[llInfo], clWindowText);
  levelColors[llSuccess] := pick(FColors[llSuccess], clGreen);
  levelColors[llWarning] := pick(FColors[llWarning], blend(clHotLight, clYellow, 50));
  levelColors[llError] := pick(FColors[llError], clRed);
  // the canvas origin already sits at the scroll position, so everything
  // paints in unscrolled coordinates and the view is the visible part
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := back;
  Canvas.FillRect(view);
  applyTextQuality(Canvas);
  var h := lineHeight;
  var pad := scaled(self, FPadding);
  var top := pad;
  var first := Max((VertScrollBar.Position-pad) div h, 0);
  var timeW := if FShowTime then Canvas.TextWidth(FormatDateTime(FTimeFormat, Now, formatSettingsOf(FLanguage)))+scaled(self, 8) else 0;
  var levelW := if FShowLevel then Canvas.TextWidth('[ERROR]')+scaled(self, 8) else 0;
  for var i := first to high(FVisible) do begin
    var y := top+i*h;
    if y > view.Bottom then break;
    var line := FLines[FVisible[i]];
    var row := Rect(0, y, ClientWidth, y+h);
    if i = FSelected then begin
      Canvas.Brush.Color := blend(back, clHighlight, 35);
      Canvas.FillRect(row);
    end else if FAlternate and (i mod 2 = 1) then begin
      Canvas.Brush.Color := blend(back, clWindowText, 4);
      Canvas.FillRect(row);
    end;
    Canvas.Brush.Style := bsClear;
    var x := pad;
    if FShowTime then begin
      Canvas.Font.Color := timeColor;
      Canvas.TextOut(x, y+1, FormatDateTime(FTimeFormat, line.time, formatSettingsOf(FLanguage)));
      x += timeW;
    end;
    if FShowLevel then begin
      Canvas.Font.Color := levelColors[line.level];
      Canvas.TextOut(x, y+1, '['+levelName(line.level)+']');
      x += levelW;
    end;
    Canvas.Font.Color := levelColors[line.level];
    Canvas.TextOut(x, y+1, line.text);
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- input ----------------------

procedure TLogView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  var i := lineAt(Y);
  FSelected := i;
  Invalidate;
  if (i >= 0) and Assigned(FOnLineClick) then FOnLineClick(self, FVisible[i], FLines[FVisible[i]].text, FLines[FVisible[i]].level);
end;

procedure TLogView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var h := lineHeight;
  match Key of
    VK_UP: FSelected := Max(FSelected-1, 0);
    VK_DOWN: FSelected := Min(FSelected+1, high(FVisible));
    VK_PRIOR: FSelected := Max(FSelected-ClientHeight div h, 0);
    VK_NEXT: FSelected := Min(FSelected+ClientHeight div h, high(FVisible));
    VK_HOME: FSelected := 0;
    VK_END: FSelected := high(FVisible);
    VK_C: if ssCtrl in Shift then CopyToClipboard;
  else
    exit;
  end;
  Key := 0;
  // the selection stays in view
  if FSelected >= 0 then begin
    var y := scaled(self, FPadding)+FSelected*h;
    if y < VertScrollBar.Position then VertScrollBar.Position := y
    else if y+h > VertScrollBar.Position+ClientHeight then VertScrollBar.Position := y+h-ClientHeight;
  end;
  Invalidate;
end;

procedure TLogView.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

// -- properties ----------------------

function TLogView.getMetric(index: integer): integer;
begin
  result := if index = 0 then FMaxLines else FPadding;
end;

procedure TLogView.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TLogView.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then begin
    FMaxLines := value;
    if (value > 0) and (FCount > value) then begin
      var drop := FCount-value;
      for var i := 0 to FCount-drop-1 do FLines[i] := FLines[i+drop];
      for var i := FCount-drop to FCount-1 do FLines[i].text := '';
      FCount := value;
      refilter;
    end;
  end else FPadding := value;
  updateRange;
  Invalidate;
end;

function TLogView.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FAutoScroll;
    1: result := FShowTime;
    2: result := FShowLevel;
    _: result := FAlternate;
  end;
end;

procedure TLogView.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAutoScroll := value;
    1: FShowTime := value;
    2: FShowLevel := value;
    _: FAlternate := value;
  end;
  Invalidate;
end;

procedure TLogView.setTimeFormat(const value: string);
begin
  if FTimeFormat = value then exit;
  FTimeFormat := value;
  Invalidate;
end;

procedure TLogView.setFilter(value: TLogLevels);
begin
  if FFilter = value then exit;
  FFilter := value;
  refilter;
  Invalidate;
end;

function TLogView.getLevelColor(index: integer): TColor;
begin
  result := FColors[TLogLevel(index)];
end;

procedure TLogView.setLevelColor(index: integer; value: TColor);
begin
  if FColors[TLogLevel(index)] = value then exit;
  FColors[TLogLevel(index)] := value;
  Invalidate;
end;

procedure TLogView.setTimeColor(value: TColor);
begin
  if FTimeColor = value then exit;
  FTimeColor := value;
  Invalidate;
end;

end.
