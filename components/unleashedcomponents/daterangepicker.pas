{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit DateRangePicker;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, StdCtrls, LCLType, LMessages, ControlPaint, PopupWindow;

type
  TDateRangeEvent = procedure(Sender: TObject; startDate, endDate: TDateTime) of object;
  TPickDateEvent = procedure(Sender: TObject; date: TDateTime) of object;

  { TMonthGrid }

  // one month of days in the colors of the theme: the days from RangeStart
  // to RangeEnd are lit, and with Preview on the day under the mouse stands
  // in for a missing end. The weeks start on Monday
  TMonthGrid = class(TCustomControl)
  private
    FMonth: TDateTime; // the first day of the month
    FRangeStart, FRangeEnd, FHover, FMinDate, FMaxDate: TDateTime;
    FHot: integer; // the cell under the mouse, or one of the arrows
    FShowPrev, FShowNext, FPreview: boolean;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FOnPick: TPickDateEvent;
    FOnMonthChange: TNotifyEvent;
    function cellSizeOn(c: TCanvas): TSize;
    function headerHeightOn(c: TCanvas): integer;
    function gridTop: integer;
    function cellRect(index: integer): TRect;
    function cellDate(index: integer): TDateTime;
    function cellAt(x, y: integer): integer;
    function arrowRect(next: boolean): TRect;
    function firstCell: TDateTime;
    function allowed(date: TDateTime): boolean;
    procedure setMonth(value: TDateTime);
    procedure setHot(value: integer);
    procedure setFlag(index: integer; value: boolean);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the size for the font, with or without a handle
    function PreferredSize: TSize;
    procedure SetRange(a, b: TDateTime);
    property Month: TDateTime read FMonth write setMonth;
    property MinDate: TDateTime read FMinDate write FMinDate;
    property MaxDate: TDateTime read FMaxDate write FMaxDate;
    property ShowPrev: boolean index 0 read FShowPrev write setFlag;
    property ShowNext: boolean index 1 read FShowNext write setFlag;
    property Preview: boolean index 2 read FPreview write setFlag;
    property Antialiasing: TAntialiasSetting read FAntialiasing write FAntialiasing;
    property Language: TFormatLanguage read FLanguage write FLanguage;
    property OnPick: TPickDateEvent read FOnPick write FOnPick;
    property OnMonthChange: TNotifyEvent read FOnMonthChange write FOnMonthChange;
  end;

  { TDateRangePicker }

  // a field holding a range of dates: a drop down shows two calendars and
  // a list of presets; the first click picks the start, the second the end.
  // An empty range shows EmptyText
  TDateRangePicker = class(TCustomControl)
  private
    FStart, FEnd, FMinDate, FMaxDate: TDateTime;
    FDisplayFormat, FSeparator, FEmptyText: string;
    FAllowEmpty, FShowPresets, FShowClear: boolean;
    FCornerRadius, FPadding: integer;
    FBorderColor, FFocusBorderColor, FFieldColor: TColor;
    FPopup: TDropPopup;
    FFirst, FSecond: TMonthGrid;
    FPresets: TListBox;
    FPicking: boolean; // the start is picked, the next click ends the range
    FHotClear, FHotArrow: boolean;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FOnChange: TDateRangeEvent;
    procedure setDate(index: integer; value: TDateTime);
    function getDate(index: integer): TDateTime;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    function clearRect: TRect;
    function arrowRect: TRect;
    function hasRange: boolean;
    procedure buildPopup;
    procedure gridPick(Sender: TObject; date: TDateTime);
    procedure gridMonthChange(Sender: TObject);
    procedure showRangeOnGrids;
    procedure presetMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure popupDismiss(Sender: TObject);
    procedure applyRange(a, b: TDateTime);
    function dateStored(index: integer): boolean;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DropDown;
    procedure CloseUp;
    procedure Clear;
    // both dates at once, ordered
    procedure SetRange(a, b: TDateTime);
    // the range as the field shows it
    function Text: string;
    // days in the range, both ends counted; 0 for none
    function Days: integer;
    function PopupVisible: boolean;
  published
    property StartDate: TDateTime index 0 read getDate write setDate stored dateStored;
    property EndDate: TDateTime index 1 read getDate write setDate stored dateStored;
    // 0 for no limit
    property MinDate: TDateTime index 2 read getDate write setDate stored dateStored;
    property MaxDate: TDateTime index 3 read getDate write setDate stored dateStored;
    // a FormatDateTime pattern; empty takes the short date of the locale
    property DisplayFormat: string index 0 read getText write setText;
    property Separator: string index 1 read getText write setText;
    property EmptyText: string index 2 read getText write setText;
    property AllowEmpty: boolean index 0 read getFlag write setFlag default true;
    // the list of presets beside the calendars
    property ShowPresets: boolean index 1 read getFlag write setFlag default true;
    property ShowClearButton: boolean index 2 read getFlag write setFlag default true;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    property Padding: integer index 1 read getMetric write setMetric default 6;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FieldColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnChange: TDateRangeEvent read FOnChange write FOnChange;
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
  Math, DateUtils;

const
  HOT_NONE = -1;
  HOT_PREV = -2;
  HOT_NEXT = -3;

{ TMonthGrid }

constructor TMonthGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  FMonth := StartOfTheMonth(Date);
  FHot := HOT_NONE;
  FShowPrev := true;
  FShowNext := true;
  FPreview := true;
  FAntialiasing := asTheme;
end;

function TMonthGrid.cellSizeOn(c: TCanvas): TSize;
begin
  // wide enough for the widest name of a day in the locale
  var w := c.TextWidth('00')+scaled(self, 6);
  for var i := 1 to 7 do w := Max(w, c.TextWidth(formatSettingsOf(FLanguage).ShortDayNames[i]));
  result.cx := w+scaled(self, 8);
  result.cy := c.TextHeight('0')+scaled(self, 10);
end;

function TMonthGrid.headerHeightOn(c: TCanvas): integer;
begin
  result := c.TextHeight('0')+scaled(self, 14);
end;

function TMonthGrid.PreferredSize: TSize;
begin
  var probe := autofree TBitmap.Create;
  probe.Canvas.Font := Font;
  var cell := cellSizeOn(probe.Canvas);
  var pad := scaled(self, 6);
  result.cx := cell.cx*7+pad*2;
  // the header, the week day names and six weeks
  result.cy := headerHeightOn(probe.Canvas)+cell.cy*7+pad*2;
end;

// the first row of days starts under the names
function TMonthGrid.gridTop: integer;
begin
  result := scaled(self, 6)+headerHeightOn(Canvas)+cellSizeOn(Canvas).cy;
end;

function TMonthGrid.firstCell: TDateTime;
begin
  result := FMonth-(DayOfTheWeek(FMonth)-1);
end;

function TMonthGrid.cellDate(index: integer): TDateTime;
begin
  result := firstCell+index;
end;

function TMonthGrid.cellRect(index: integer): TRect;
begin
  var cell := cellSizeOn(Canvas);
  var pad := scaled(self, 6);
  var x := pad+(index mod 7)*cell.cx;
  var y := gridTop+(index div 7)*cell.cy;
  result := Rect(x, y, x+cell.cx, y+cell.cy);
end;

function TMonthGrid.cellAt(x, y: integer): integer;
begin
  result := HOT_NONE;
  if FShowPrev and arrowRect(false).Contains(Point(x, y)) then exit(HOT_PREV);
  if FShowNext and arrowRect(true).Contains(Point(x, y)) then exit(HOT_NEXT);
  var cell := cellSizeOn(Canvas);
  var pad := scaled(self, 6);
  if (x < pad) or (y < gridTop) then exit;
  var col := (x-pad) div cell.cx;
  var row := (y-gridTop) div cell.cy;
  if (col > 6) or (row > 5) then exit;
  result := row*7+col;
end;

function TMonthGrid.arrowRect(next: boolean): TRect;
begin
  var h := headerHeightOn(Canvas);
  var pad := scaled(self, 6);
  var size := h-scaled(self, 4);
  var top := pad+(h-size) div 2;
  result := if next then Rect(ClientWidth-pad-size, top, ClientWidth-pad, top+size) else Rect(pad, top, pad+size, top+size);
end;

function TMonthGrid.allowed(date: TDateTime): boolean;
begin
  result := ((FMinDate = 0) or (date >= FMinDate)) and ((FMaxDate = 0) or (date <= FMaxDate));
end;

procedure TMonthGrid.Paint;
begin
  var back := ColorToRGB(clWindow);
  var text := ColorToRGB(clWindowText);
  var dim := ColorToRGB(clGrayText);
  var accent := ColorToRGB(clHighlight);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  var pad := scaled(self, 6);
  var header := headerHeightOn(Canvas);
  var cell := cellSizeOn(Canvas);
  // the lit days: the picked ones, or the picked start up to the mouse
  var lo := FRangeStart;
  var hi := FRangeEnd;
  if (lo <> 0) and (hi = 0) and FPreview and (FHover <> 0) then hi := FHover;
  if (lo <> 0) and (hi <> 0) and (hi < lo) then begin
    var t := lo;
    lo := hi;
    hi := t;
  end;
  var today := Date;
  for var i := 0 to 41 do begin
    var r := cellRect(i);
    var d := cellDate(i);
    var inRange := (lo <> 0) and (((hi <> 0) and (d >= lo) and (d <= hi)) or ((hi = 0) and (d = lo)));
    var isEnd := (d = lo) or (d = hi);
    var radius := Min(r.Width, r.Height) div 2-scaled(self, 2);
    var cx := (r.Left+r.Right) div 2;
    var cy := (r.Top+r.Bottom) div 2;
    if inRange then begin
      // the band through the middle of the row stops at the picked ends
      var band := Rect(r.Left, cy-radius, r.Right, cy+radius);
      if d = lo then band.Left := cx;
      if (d = hi) or (hi = 0) then band.Right := cx;
      if band.Right > band.Left then paintRoundRect(sp, band, 0, blend(back, accent, 25), clNone);
      if isEnd then paintCircle(sp, cx, cy, radius, accent, clNone);
    end;
    if (i = FHot) and hoverEnabled and allowed(d) and not (inRange and isEnd) then paintCircle(sp, cx, cy, radius, hoverColor(back), clNone);
    if (d = today) and not (inRange and isEnd) then paintCircle(sp, cx, cy, radius, clNone, accent);
  end;
  for var next in [false, true] do begin
    if (next and not FShowNext) or (not next and not FShowPrev) then continue;
    var a := arrowRect(next);
    if (FHot = (if next then HOT_NEXT else HOT_PREV)) and hoverEnabled then paintCircle(sp, (a.Left+a.Right) div 2, (a.Top+a.Bottom) div 2, a.Width div 2, hoverColor(back), clNone);
    paintChevron(sp, a, (if next then cdRight else cdLeft), Max(scaled(self, 8), 6), dim);
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Style := Font.Style+[fsBold];
  paintCenteredText(Canvas, Rect(pad, pad, ClientWidth-pad, pad+header), FormatDateTime('mmmm yyyy', FMonth, formatSettingsOf(FLanguage)), text);
  Canvas.Font.Style := Font.Style;
  // the names of the days, Monday first
  for var col := 0 to 6 do begin
    var r := Rect(pad+col*cell.cx, pad+header, pad+(col+1)*cell.cx, pad+header+cell.cy);
    paintCenteredText(Canvas, r, formatSettingsOf(FLanguage).ShortDayNames[(col+1) mod 7+1], dim);
  end;
  for var i := 0 to 41 do begin
    var d := cellDate(i);
    var inMonth := MonthOf(d) = MonthOf(FMonth);
    var lit := (lo <> 0) and ((d = lo) or ((hi <> 0) and (d = hi)));
    var color := if lit then contrastText(accent) else if not allowed(d) then blend(dim, back, 50) else if inMonth then text else dim;
    paintCenteredText(Canvas, cellRect(i), IntToStr(DayOf(d)), color);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TMonthGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var hit := cellAt(X, Y);
  match hit of
    HOT_NONE: exit;
    HOT_PREV: Month := IncMonth(FMonth, -1);
    HOT_NEXT: Month := IncMonth(FMonth, 1);
  else
    if allowed(cellDate(hit)) and Assigned(FOnPick) then FOnPick(self, cellDate(hit));
  end;
end;

procedure TMonthGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  setHot(cellAt(X, Y));
end;

procedure TMonthGrid.MouseLeave;
begin
  inherited MouseLeave;
  setHot(HOT_NONE);
end;

function TMonthGrid.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result then exit;
  Month := IncMonth(FMonth, if WheelDelta < 0 then 1 else -1);
  result := true;
end;

procedure TMonthGrid.setHot(value: integer);
begin
  if FHot = value then exit;
  FHot := value;
  FHover := if value >= 0 then cellDate(value) else 0;
  Invalidate;
end;

procedure TMonthGrid.setMonth(value: TDateTime);
begin
  value := StartOfTheMonth(value);
  if FMonth = value then exit;
  FMonth := value;
  Invalidate;
  if Assigned(FOnMonthChange) then FOnMonthChange(self);
end;

procedure TMonthGrid.SetRange(a, b: TDateTime);
begin
  FRangeStart := a;
  FRangeEnd := b;
  Invalidate;
end;

procedure TMonthGrid.setFlag(index: integer; value: boolean);
begin
  match index of
    0: FShowPrev := value;
    1: FShowNext := value;
  else
    FPreview := value;
  end;
  Invalidate;
end;

constructor TDateRangePicker.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FSeparator := ' .. ';
  FEmptyText := 'Any time';
  FAllowEmpty := true;
  FShowPresets := true;
  FShowClear := true;
  FCornerRadius := 4;
  FPadding := 6;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FFieldColor := clDefault;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TDateRangePicker.Destroy;
begin
  FreeAndNil(FPopup);
  inherited Destroy;
end;

class function TDateRangePicker.GetControlClassDefaultSize: TSize;
begin
  result.cx := 220;
  result.cy := 27;
end;

function TDateRangePicker.dateStored(index: integer): boolean;
begin
  result := getDate(index) <> 0;
end;

procedure TDateRangePicker.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := Canvas.TextHeight('Hg')+scaled(self, FPadding)*2-scaled(self, 2);
end;

// -- range ----------------------

function TDateRangePicker.hasRange: boolean;
begin
  result := (FStart <> 0) and (FEnd <> 0);
end;

function TDateRangePicker.Text: string;
begin
  if not hasRange then exit(FEmptyText);
  var fs := formatSettingsOf(FLanguage);
  var fmt := if FDisplayFormat = '' then fs.ShortDateFormat else FDisplayFormat;
  result := FormatDateTime(fmt, FStart, fs);
  if Trunc(FStart) <> Trunc(FEnd) then result += FSeparator+FormatDateTime(fmt, FEnd, fs);
end;

function TDateRangePicker.Days: integer;
begin
  result := if hasRange then DaysBetween(Trunc(FStart), Trunc(FEnd))+1 else 0;
end;

procedure TDateRangePicker.SetRange(a, b: TDateTime);
begin
  if (a <> 0) and (b <> 0) and (a > b) then begin
    var t := a;
    a := b;
    b := t;
  end;
  applyRange(a, b);
end;

procedure TDateRangePicker.applyRange(a, b: TDateTime);
begin
  if (FMinDate <> 0) and (a <> 0) and (a < FMinDate) then a := FMinDate;
  if (FMaxDate <> 0) and (b <> 0) and (b > FMaxDate) then b := FMaxDate;
  if (FStart = a) and (FEnd = b) then exit;
  FStart := a;
  FEnd := b;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self, FStart, FEnd);
end;

procedure TDateRangePicker.Clear;
begin
  if not FAllowEmpty then exit;
  applyRange(0, 0);
end;

// -- popup ----------------------

procedure TDateRangePicker.buildPopup;
begin
  if FPopup <> nil then exit;
  FPopup := TDropPopup.Create(self);
  FPopup.OnDismiss := @popupDismiss;
  FPopup.Color := clBtnFace;
  FFirst := TMonthGrid.Create(FPopup);
  FFirst.Language := FLanguage;
  FFirst.Parent := FPopup;
  FFirst.Font := Font;
  FFirst.ShowNext := false;
  FFirst.TabStop := false;
  FFirst.OnPick := @gridPick;
  FFirst.OnMonthChange := @gridMonthChange;
  FSecond := TMonthGrid.Create(FPopup);
  FSecond.Language := FLanguage;
  FSecond.Parent := FPopup;
  FSecond.Font := Font;
  FSecond.ShowPrev := false;
  FSecond.TabStop := false;
  FSecond.OnPick := @gridPick;
  FSecond.OnMonthChange := @gridMonthChange;
  FPresets := TListBox.Create(FPopup);
  FPresets.Parent := FPopup;
  FPresets.BorderStyle := bsNone;
  FPresets.TabStop := false;
  FPresets.Items.Add('Today');
  FPresets.Items.Add('Yesterday');
  FPresets.Items.Add('Last 7 days');
  FPresets.Items.Add('Last 30 days');
  FPresets.Items.Add('This week');
  FPresets.Items.Add('This month');
  FPresets.Items.Add('Last month');
  FPresets.Items.Add('This year');
  // a click, not a selection change: the list reports those on its own
  FPresets.OnMouseUp := @presetMouseUp;
  var gap := scaled(self, 6);
  var size := FFirst.PreferredSize;
  var cw := size.cx;
  var ch := size.cy;
  var listW := if FShowPresets then scaled(self, 110) else 0;
  FPresets.Visible := FShowPresets;
  FPresets.SetBounds(gap, gap, listW, ch);
  FFirst.SetBounds(gap+listW+(if FShowPresets then gap else 0), gap, cw, ch);
  FSecond.SetBounds(FFirst.Left+cw+gap, gap, cw, ch);
  FPopup.SetBounds(0, 0, FSecond.Left+cw+gap, ch+gap*2);
end;

procedure TDateRangePicker.DropDown;
begin
  if csDesigning in ComponentState then exit;
  buildPopup;
  var base := if FStart <> 0 then FStart else Date;
  FFirst.MinDate := FMinDate;
  FFirst.MaxDate := FMaxDate;
  FSecond.MinDate := FMinDate;
  FSecond.MaxDate := FMaxDate;
  FFirst.Month := base;
  FSecond.Month := IncMonth(FFirst.Month, 1);
  FPicking := false;
  showRangeOnGrids;
  FPopup.Drop(self, FPopup.Width, FPopup.Height);
  Invalidate;
end;

procedure TDateRangePicker.CloseUp;
begin
  if (FPopup <> nil) and FPopup.Visible then FPopup.Close;
  FPicking := false;
  Invalidate;
end;

function TDateRangePicker.PopupVisible: boolean;
begin
  result := (FPopup <> nil) and FPopup.Visible;
end;

procedure TDateRangePicker.gridPick(Sender: TObject; date: TDateTime);
begin
  var picked := Trunc(date);
  if not FPicking then begin
    FStart := picked;
    FEnd := 0;
    FPicking := true;
    showRangeOnGrids;
    Invalidate;
    exit;
  end;
  SetRange(FStart, picked);
  CloseUp;
end;

// the second grid follows the first by a month
procedure TDateRangePicker.gridMonthChange(Sender: TObject);
begin
  if Sender = FFirst then FSecond.Month := IncMonth(FFirst.Month, 1)
  else FFirst.Month := IncMonth(FSecond.Month, -1);
end;

procedure TDateRangePicker.showRangeOnGrids;
begin
  FFirst.Preview := FPicking;
  FSecond.Preview := FPicking;
  FFirst.SetRange(FStart, FEnd);
  FSecond.SetRange(FStart, FEnd);
end;

procedure TDateRangePicker.presetMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then exit;
  var today := Date;
  match FPresets.ItemAtPos(Point(X, Y), true) of
    0: SetRange(today, today);
    1: SetRange(today-1, today-1);
    2: SetRange(today-6, today);
    3: SetRange(today-29, today);
    4: SetRange(StartOfTheWeek(today), EndOfTheWeek(today));
    5: SetRange(StartOfTheMonth(today), EndOfTheMonth(today));
    6: SetRange(StartOfTheMonth(IncMonth(today, -1)), EndOfTheMonth(IncMonth(today, -1)));
    7: SetRange(StartOfTheYear(today), EndOfTheYear(today));
  else
    exit;
  end;
  CloseUp;
end;

procedure TDateRangePicker.popupDismiss(Sender: TObject);
begin
  CloseUp;
end;

// -- painting ----------------------

function TDateRangePicker.arrowRect: TRect;
begin
  var size := Canvas.TextHeight('Hg');
  var pad := scaled(self, FPadding);
  result := Rect(ClientWidth-pad-size, (ClientHeight-size) div 2, ClientWidth-pad, (ClientHeight-size) div 2+size);
end;

function TDateRangePicker.clearRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not (FShowClear and FAllowEmpty and hasRange) then exit;
  var a := arrowRect;
  var size := a.Height-scaled(self, 2);
  result := Rect(a.Left-scaled(self, 4)-size, (ClientHeight-size) div 2, a.Left-scaled(self, 4), (ClientHeight-size) div 2+size);
end;

procedure TDateRangePicker.Paint;
begin
  var border := pick(FBorderColor, clBtnShadow);
  if (Focused or PopupVisible) and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := pick(FFieldColor, clWindow);
  if not Enabled then field := ColorToRGB(clBtnFace);
  var glyph := ColorToRGB(if Enabled then clGrayText else clBtnShadow);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  var a := arrowRect;
  if Enabled and hoverEnabled and FHotArrow then paintCircle(sp, (a.Left+a.Right) div 2, (a.Top+a.Bottom) div 2, a.Width div 2, hoverColor(field), clNone);
  paintChevron(sp, a, cdDown, Max(scaled(self, 8), 6), (if FHotArrow then ColorToRGB(clWindowText) else glyph));
  var c := clearRect;
  if c.Width > 0 then begin
    if Enabled and hoverEnabled and FHotClear then paintCircle(sp, (c.Left+c.Right) div 2, (c.Top+c.Bottom) div 2, c.Width div 2, hoverColor(field), clNone);
    paintCross(sp, c, c.Width div 2, glyph);
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  var pad := scaled(self, FPadding);
  var right := if c.Width > 0 then c.Left-pad div 2 else a.Left-pad div 2;
  var box := Rect(pad, 0, right, ClientHeight);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  Canvas.Brush.Style := bsClear;
  // not named text: the local would shadow the Text method in its own initializer
  var fs := formatSettingsOf(FLanguage);
  var shown := if FPicking and (FStart <> 0) then FormatDateTime((if FDisplayFormat = '' then fs.ShortDateFormat else FDisplayFormat), FStart, fs)+FSeparator+'?' else Text;
  Canvas.Font.Color := ColorToRGB(if not Enabled then clGrayText else if hasRange or FPicking then clWindowText else clGrayText);
  Canvas.TextRect(box, box.Left, box.Top, shown, style);
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TDateRangePicker.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  if clearRect.Contains(Point(X, Y)) then begin
    Clear;
    exit;
  end;
  if PopupVisible then CloseUp else DropDown;
end;

procedure TDateRangePicker.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hotClear := clearRect.Contains(Point(X, Y));
  var hotArrow := arrowRect.Contains(Point(X, Y));
  if (hotClear <> FHotClear) or (hotArrow <> FHotArrow) then begin
    FHotClear := hotClear;
    FHotArrow := hotArrow;
    Invalidate;
  end;
end;

procedure TDateRangePicker.MouseLeave;
begin
  inherited MouseLeave;
  if FHotClear or FHotArrow then begin
    FHotClear := false;
    FHotArrow := false;
    Invalidate;
  end;
end;

procedure TDateRangePicker.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_SPACE, VK_RETURN, VK_F4: DropDown;
    VK_DOWN: if ssAlt in Shift then DropDown else exit;
    VK_DELETE, VK_BACK: Clear;
    VK_ESCAPE: if PopupVisible then CloseUp else exit;
  else
    exit;
  end;
  Key := 0;
end;

procedure TDateRangePicker.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TDateRangePicker.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TDateRangePicker.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

function TDateRangePicker.getDate(index: integer): TDateTime;
begin
  match index of
    0: result := FStart;
    1: result := FEnd;
    2: result := FMinDate;
    _: result := FMaxDate;
  end;
end;

procedure TDateRangePicker.setDate(index: integer; value: TDateTime);
begin
  match index of
    0: SetRange(value, (if FEnd = 0 then value else FEnd));
    1: SetRange((if FStart = 0 then value else FStart), value);
    2: begin
      FMinDate := value;
      applyRange(FStart, FEnd);
    end;
    _: begin
      FMaxDate := value;
      applyRange(FStart, FEnd);
    end;
  end;
end;

function TDateRangePicker.getText(index: integer): string;
begin
  match index of
    0: result := FDisplayFormat;
    1: result := FSeparator;
    _: result := FEmptyText;
  end;
end;

procedure TDateRangePicker.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FDisplayFormat := value;
    1: FSeparator := value;
    _: FEmptyText := value;
  end;
  Invalidate;
end;

function TDateRangePicker.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FAllowEmpty;
    1: result := FShowPresets;
    _: result := FShowClear;
  end;
end;

procedure TDateRangePicker.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAllowEmpty := value;
    1: begin
      FShowPresets := value;
      FreeAndNil(FPopup);
    end;
    _: FShowClear := value;
  end;
  Invalidate;
end;

function TDateRangePicker.getMetric(index: integer): integer;
begin
  result := if index = 0 then FCornerRadius else FPadding;
end;

procedure TDateRangePicker.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FCornerRadius := value else FPadding := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDateRangePicker.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FBorderColor;
    1: result := FFocusBorderColor;
    _: result := FFieldColor;
  end;
end;

procedure TDateRangePicker.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FFocusBorderColor := value;
    _: FFieldColor := value;
  end;
  Invalidate;
end;

procedure TDateRangePicker.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  if FPopup <> nil then begin
    FFirst.Language := value;
    FSecond.Language := value;
  end;
  Invalidate;
end;

procedure TDateRangePicker.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
