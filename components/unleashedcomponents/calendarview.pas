{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit CalendarView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  // what the grid shows: the days of a month, the months of a year, the
  // years of a decade
  TCalendarViewMode = (cvMonth, cvYear, cvDecade);
  // one day, a range from a start to an end, or any set of days
  TCalendarSelection = (selSingle, selRange, selMultiple);
  TCalendarFirstDay = (fdMonday, fdTuesday, fdWednesday, fdThursday, fdFriday, fdSaturday, fdSunday);
  // the mark of a picked day: a circle, a rounded square, the square cell,
  // the whole cell, a pill across the cell, a bar under the number
  TCalendarCellShape = (ccCircle, ccRounded, ccSquare, ccFill, ccPill, ccUnderline);
  TCalendarDateEvent = procedure(Sender: TObject; day: TDateTime) of object;
  // a day about to be painted: marked shows a dot, enabled false makes it
  // unpickable, a color other than clDefault paints its number
  TCalendarDayInfoEvent = procedure(Sender: TObject; day: TDateTime; var marked, enabled: boolean; var textColor: TColor) of object;

  { TCalendarView }

  // a calendar drawn in the colors of the theme. A click on the title goes
  // up to the months of the year and the years of the decade, a click on a
  // month or a year comes back down. The arrows, the wheel and the keys
  // move through it; Enter and Space pick the day under the cursor
  TCalendarView = class(TCustomControl)
  private
    FDate, FRangeStart, FRangeEnd, FMinDate, FMaxDate: TDateTime;
    FMonth: TDateTime; // the first day of the month on show
    FCursorDay: TDateTime; // the day the keys move
    FHover: TDateTime; // the day under the mouse
    FSelected: array of TDateTime; // sorted, for selMultiple
    FMarked: TStringList;
    FSelection: TCalendarSelection;
    FViewMode: TCalendarViewMode;
    FFirstDay: TCalendarFirstDay;
    FCellShape: TCalendarCellShape;
    FPicking: boolean; // a range has its start and waits for the end
    FNormalizing, FKeyboardCursor: boolean;
    FShowWeekNumbers, FShowToday, FShowOtherMonths, FShowHeader, FShowNavigation, FAllowViewChange, FHighlightWeekends: boolean;
    FHot: integer; // a cell, or one of the HOT_ values
    FAccentColor, FTodayColor, FMarkColor, FWeekendColor, FHeaderColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FOnChange, FOnViewChange: TNotifyEvent;
    FOnDayClick: TCalendarDateEvent;
    FOnGetDayInfo: TCalendarDayInfoEvent;
    FOnDrawDay: TCustomDrawEvent;
    procedure setDate(index: integer; value: TDateTime);
    function getDate(index: integer): TDateTime;
    function dateStored(index: integer): boolean;
    procedure setMonth(value: TDateTime);
    procedure setSelection(value: TCalendarSelection);
    procedure setViewMode(value: TCalendarViewMode);
    procedure setFirstDay(value: TCalendarFirstDay);
    procedure setCellShape(value: TCalendarCellShape);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    function getMarkedDates: TStrings;
    procedure setMarkedDates(value: TStrings);
    function getSelectedDate(index: integer): TDateTime;
    procedure markedChanged(Sender: TObject);
    function naturalCell: TSize;
    function headerHeight: integer;
    function columns: integer;
    function rows: integer;
    function gridRect: TRect;
    function cellSize: TSize;
    function cellRect(index: integer): TRect;
    function cellCount: integer;
    function firstCell: TDateTime;
    function cellDate(index: integer): TDateTime;
    function decadeStart: integer;
    function titleRect: TRect;
    function arrowRect(next: boolean): TRect;
    function hitAt(x, y: integer): integer;
    function dayOfWeekIndex(day: TDateTime): integer;
    function dayInfo(day: TDateTime; out marked: boolean; out textColor: TColor): boolean;
    function inRange(day: TDateTime; out isEnd: boolean): boolean;
    function rangeBounds(out lo, hi: TDateTime): boolean;
    procedure setHot(value: integer);
    procedure paintCell(sp: TSmoothPaint; const r: TRect; fill, frame: TColor);
    procedure pickDay(day: TDateTime);
    procedure moveCursor(day: TDateTime);
    procedure step(delta: integer);
    procedure changed;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the keys a calendar takes, also when they reach another control first,
    // like the field of a date picker; true when the key was used
    function HandleKey(var Key: Word; Shift: TShiftState): boolean;
    // the day under a point of the control, 0 for none
    function DateAt(x, y: integer): TDateTime;
    procedure GoToToday;
    procedure Mark(day: TDateTime);
    procedure Unmark(day: TDateTime);
    procedure ClearMarks;
    function IsMarked(day: TDateTime): boolean;
    function IsSelected(day: TDateTime): boolean;
    procedure ClearSelection;
    function SelectedCount: integer;
    // the first day of the month on show
    property Month: TDateTime read FMonth write setMonth;
    // the days picked with selMultiple, in order
    property SelectedDates[index: integer]: TDateTime read getSelectedDate;
    // the day the keyboard is on
    property CursorDate: TDateTime read FCursorDay;
    // the ring of the key cursor shows without the focus too, for a
    // calendar another control drives through HandleKey
    property KeyboardCursor: boolean read FKeyboardCursor write FKeyboardCursor;
  published
    // the picked day with selSingle; 0 for none
    property Date: TDateTime index 0 read getDate write setDate stored dateStored;
    property RangeStart: TDateTime index 1 read getDate write setDate stored dateStored;
    property RangeEnd: TDateTime index 2 read getDate write setDate stored dateStored;
    // 0 for no limit
    property MinDate: TDateTime index 3 read getDate write setDate stored dateStored;
    property MaxDate: TDateTime index 4 read getDate write setDate stored dateStored;
    property SelectionMode: TCalendarSelection read FSelection write setSelection default selSingle;
    property ViewMode: TCalendarViewMode read FViewMode write setViewMode default cvMonth;
    property FirstDayOfWeek: TCalendarFirstDay read FFirstDay write setFirstDay default fdMonday;
    property CellShape: TCalendarCellShape read FCellShape write setCellShape default ccCircle;
    // the ISO week numbers in a column on the left
    property ShowWeekNumbers: boolean index 0 read getFlag write setFlag default false;
    // a ring around the day of today
    property ShowToday: boolean index 1 read getFlag write setFlag default true;
    // the days of the months around, dimmed
    property ShowOtherMonths: boolean index 2 read getFlag write setFlag default true;
    property ShowHeader: boolean index 3 read getFlag write setFlag default true;
    // the arrows in the header
    property ShowNavigation: boolean index 4 read getFlag write setFlag default true;
    // a click on the title goes up to months and years
    property AllowViewChange: boolean index 5 read getFlag write setFlag default true;
    // Saturday and Sunday in WeekendColor
    property HighlightWeekends: boolean index 6 read getFlag write setFlag default false;
    // the days with a dot, one ISO date per line: 2026-10-31
    property MarkedDates: TStrings read getMarkedDates write setMarkedDates;
    // clDefault takes the colors of the theme
    property AccentColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TodayColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property MarkColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property WeekendColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property HeaderColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    // the selection changed
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDayClick: TCalendarDateEvent read FOnDayClick write FOnDayClick;
    // another month, year or decade, or another view
    property OnViewChange: TNotifyEvent read FOnViewChange write FOnViewChange;
    property OnGetDayInfo: TCalendarDayInfoEvent read FOnGetDayInfo write FOnGetDayInfo;
    // paints over a cell of the month: index is the cell, 0 at the top left;
    // dsSelected for a picked day, dsHover under the mouse, dsActive for
    // today, dsDisabled for a day outside the limits; `handled` true leaves the
    // number out
    property OnDrawDay: TCustomDrawEvent read FOnDrawDay write FOnDrawDay;
    property Align;
    property Anchors;
    property AutoSize default true;
    property BorderSpacing;
    property Color default clWindow;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentColor default false;
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
    property OnResize;
  end;

implementation

uses
  Math, DateUtils;

const
  HOT_NONE = -1;
  HOT_PREV = -2;
  HOT_NEXT = -3;
  HOT_TITLE = -4;

function isoText(day: TDateTime): string;
begin
  result := FormatDateTime('yyyy"-"mm"-"dd', day);
end;

// year, month and day split by dashes; the digits need no leading zeros
function parseIso(const s: string; out day: TDateTime): boolean;
begin
  var parts := Trim(s).Split(['-']);
  result := false;
  if length(parts) <> 3 then exit;
  var y, m, d: integer;
  if not (TryStrToInt(parts[0], y) and TryStrToInt(parts[1], m) and TryStrToInt(parts[2], d)) then exit;
  result := TryEncodeDate(y, m, d, day);
end;

constructor TCalendarView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FMonth := StartOfTheMonth(SysUtils.Date);
  FCursorDay := SysUtils.Date;
  FHot := HOT_NONE;
  FShowToday := true;
  FShowOtherMonths := true;
  FShowHeader := true;
  FShowNavigation := true;
  FAllowViewChange := true;
  FAccentColor := clDefault;
  FTodayColor := clDefault;
  FMarkColor := clDefault;
  FWeekendColor := clDefault;
  FHeaderColor := clDefault;
  FMarked := TStringList.Create;
  FMarked.Sorted := true;
  FMarked.Duplicates := dupIgnore;
  FMarked.OnChange := @markedChanged;
  Color := clWindow;
  ParentColor := false;
  TabStop := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TCalendarView.Destroy;
begin
  FMarked.Free;
  inherited Destroy;
end;

class function TCalendarView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 260;
  result.cy := 250;
end;

// -- geometry ----------------------

// a cell of the month grid at the size of the font
function TCalendarView.naturalCell: TSize;
begin
  var w := Canvas.TextWidth('00')+scaled(self, 6);
  for var i := 1 to 7 do w := Max(w, Canvas.TextWidth(formatSettingsOf(FLanguage).ShortDayNames[i]));
  result.cx := w+scaled(self, 8);
  result.cy := Canvas.TextHeight('0')+scaled(self, 10);
end;

function TCalendarView.headerHeight: integer;
begin
  result := if FShowHeader then Canvas.TextHeight('0')+scaled(self, 14) else 0;
end;

function TCalendarView.columns: integer;
begin
  result := if FViewMode = cvMonth then 7+(if FShowWeekNumbers then 1 else 0) else 4;
end;

// the month grid has a row for the names of the days over its six weeks
function TCalendarView.rows: integer;
begin
  result := if FViewMode = cvMonth then 7 else 3;
end;

function TCalendarView.gridRect: TRect;
begin
  var pad := scaled(self, 6);
  result := Rect(pad, pad+headerHeight, ClientWidth-pad, ClientHeight-pad);
end;

function TCalendarView.cellSize: TSize;
begin
  var g := gridRect;
  result.cx := Max(g.Width div columns, 1);
  result.cy := Max(g.Height div rows, 1);
end;

procedure TCalendarView.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var cell := naturalCell;
  var pad := scaled(self, 6);
  PreferredWidth := cell.cx*(7+(if FShowWeekNumbers then 1 else 0))+pad*2;
  PreferredHeight := headerHeight+cell.cy*7+pad*2;
end;

// the cells: 42 days under the row of names, or 12 months or years
function TCalendarView.cellCount: integer;
begin
  result := if FViewMode = cvMonth then 42 else 12;
end;

function TCalendarView.cellRect(index: integer): TRect;
begin
  var g := gridRect;
  var cell := cellSize;
  var col, row: integer;
  if FViewMode = cvMonth then begin
    col := index mod 7+(if FShowWeekNumbers then 1 else 0);
    row := index div 7+1;
  end else begin
    col := index mod 4;
    row := index div 4;
  end;
  // the grid takes the leftover pixels of the division as an even margin
  var x := g.Left+(g.Width-cell.cx*columns) div 2+col*cell.cx;
  var y := g.Top+(g.Height-cell.cy*rows) div 2+row*cell.cy;
  result := Rect(x, y, x+cell.cx, y+cell.cy);
end;

// the column of a day, counted from the first day of the week
function TCalendarView.dayOfWeekIndex(day: TDateTime): integer;
begin
  result := (DayOfTheWeek(day)-1-ord(FFirstDay)+7) mod 7;
end;

function TCalendarView.firstCell: TDateTime;
begin
  result := FMonth-dayOfWeekIndex(FMonth);
end;

function TCalendarView.decadeStart: integer;
begin
  result := YearOf(FMonth) div 10*10;
end;

function TCalendarView.cellDate(index: integer): TDateTime;
begin
  result := match FViewMode of
    cvMonth: firstCell+index;
    cvYear: EncodeDate(YearOf(FMonth), index+1, 1);
  else
    EncodeDate(EnsureRange(decadeStart-1+index, 1, 9999), 1, 1)
  end;
end;

function TCalendarView.titleRect: TRect;
begin
  var pad := scaled(self, 6);
  var h := headerHeight;
  var title := match FViewMode of
    cvMonth: FormatDateTime('mmmm yyyy', FMonth, formatSettingsOf(FLanguage));
    cvYear: IntToStr(YearOf(FMonth));
  else
    IntToStr(decadeStart)+' - '+IntToStr(decadeStart+9)
  end;
  Canvas.Font.Style := Font.Style+[fsBold];
  var w := Canvas.TextWidth(title)+scaled(self, 16);
  Canvas.Font.Style := Font.Style;
  result := Rect((ClientWidth-w) div 2, pad+scaled(self, 2), (ClientWidth+w) div 2, pad+h-scaled(self, 2));
end;

function TCalendarView.arrowRect(next: boolean): TRect;
begin
  var h := headerHeight;
  var pad := scaled(self, 6);
  var size := h-scaled(self, 4);
  var top := pad+(h-size) div 2;
  result := if next then Rect(ClientWidth-pad-size, top, ClientWidth-pad, top+size) else Rect(pad, top, pad+size, top+size);
end;

function TCalendarView.hitAt(x, y: integer): integer;
begin
  var p := Point(x, y);
  if FShowHeader then begin
    if FShowNavigation and arrowRect(false).Contains(p) then exit(HOT_PREV);
    if FShowNavigation and arrowRect(true).Contains(p) then exit(HOT_NEXT);
    if FAllowViewChange and (FViewMode <> cvDecade) and titleRect.Contains(p) then exit(HOT_TITLE);
  end;
  for var i := 0 to cellCount-1 do
    if cellRect(i).Contains(p) then begin
      if (FViewMode = cvMonth) and not FShowOtherMonths and (MonthOf(cellDate(i)) <> MonthOf(FMonth)) then exit(HOT_NONE);
      exit(i);
    end;
  result := HOT_NONE;
end;

function TCalendarView.DateAt(x, y: integer): TDateTime;
begin
  var hit := hitAt(x, y);
  result := if (hit >= 0) and (FViewMode = cvMonth) then cellDate(hit) else 0;
end;

// -- days ----------------------

// the day can be picked; marked and the color of its number come along
function TCalendarView.dayInfo(day: TDateTime; out marked: boolean; out textColor: TColor): boolean;
begin
  result := ((FMinDate = 0) or (day >= Trunc(FMinDate))) and ((FMaxDate = 0) or (day <= Trunc(FMaxDate)));
  marked := FMarked.IndexOf(isoText(day)) >= 0;
  textColor := clDefault;
  if Assigned(FOnGetDayInfo) then FOnGetDayInfo(self, day, marked, result, textColor);
end;

// the range on show: the picked one, or the start up to the day under the mouse
function TCalendarView.rangeBounds(out lo, hi: TDateTime): boolean;
begin
  lo := FRangeStart;
  hi := FRangeEnd;
  if FPicking and (FHover <> 0) then hi := FHover;
  if (lo <> 0) and (hi <> 0) and (hi < lo) then begin
    var t := lo;
    lo := hi;
    hi := t;
  end;
  result := lo <> 0;
end;

function TCalendarView.inRange(day: TDateTime; out isEnd: boolean): boolean;
begin
  var lo, hi: TDateTime;
  isEnd := false;
  if (FSelection <> selRange) or not rangeBounds(lo, hi) then exit(false);
  isEnd := (day = lo) or (day = hi);
  result := if hi = 0 then day = lo else (day >= lo) and (day <= hi);
end;

function TCalendarView.IsSelected(day: TDateTime): boolean;
begin
  day := Trunc(day);
  match FSelection of
    selSingle: result := (FDate <> 0) and (Trunc(FDate) = day);
    selRange: begin
      var isEnd: boolean;
      result := inRange(day, isEnd);
    end;
  else
    begin
      result := false;
      for var d in FSelected do if d = day then exit(true);
    end;
  end;
end;

function TCalendarView.SelectedCount: integer;
begin
  result := match FSelection of
    selSingle: (if FDate <> 0 then 1 else 0);
    selRange: (if (FRangeStart <> 0) and (FRangeEnd <> 0) then Trunc(FRangeEnd)-Trunc(FRangeStart)+1 else 0);
  else
    length(FSelected)
  end;
end;

function TCalendarView.getSelectedDate(index: integer): TDateTime;
begin
  result := FSelected[index];
end;

procedure TCalendarView.ClearSelection;
begin
  FDate := 0;
  FRangeStart := 0;
  FRangeEnd := 0;
  FPicking := false;
  SetLength(FSelected, 0);
  changed;
end;

procedure TCalendarView.changed;
begin
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TCalendarView.pickDay(day: TDateTime);
begin
  day := Trunc(day);
  var marked: boolean;
  var textColor: TColor;
  if not dayInfo(day, marked, textColor) then exit;
  FCursorDay := day;
  if MonthOf(day) <> MonthOf(FMonth) then Month := day;
  match FSelection of
    selSingle: FDate := day;
    selRange: if not FPicking then begin
      FRangeStart := day;
      FRangeEnd := 0;
      FPicking := true;
    end else begin
      FRangeEnd := day;
      if FRangeEnd < FRangeStart then begin
        FRangeEnd := FRangeStart;
        FRangeStart := day;
      end;
      FPicking := false;
    end;
  else
    begin
      // a picked day goes, a new one joins in its place in the order
      var at := 0;
      while (at < length(FSelected)) and (FSelected[at] < day) do inc(at);
      if (at < length(FSelected)) and (FSelected[at] = day) then Delete(FSelected, at, 1)
      else Insert([day], FSelected, at);
    end;
  end;
  if Assigned(FOnDayClick) then FOnDayClick(self, day);
  changed;
end;

procedure TCalendarView.moveCursor(day: TDateTime);
begin
  day := Trunc(day);
  if (FMinDate <> 0) and (day < Trunc(FMinDate)) then day := Trunc(FMinDate);
  if (FMaxDate <> 0) and (day > Trunc(FMaxDate)) then day := Trunc(FMaxDate);
  FCursorDay := day;
  // a single day follows the keys, like the native calendars do
  if FSelection = selSingle then begin
    var marked: boolean;
    var textColor: TColor;
    if dayInfo(day, marked, textColor) and (Trunc(FDate) <> day) then begin
      FDate := day;
      changed;
    end;
  end;
  if (FViewMode = cvMonth) and ((YearOf(day) <> YearOf(FMonth)) or (MonthOf(day) <> MonthOf(FMonth))) then Month := day;
  if (FViewMode = cvYear) and (YearOf(day) <> YearOf(FMonth)) then Month := day;
  if (FViewMode = cvDecade) and (YearOf(day) div 10 <> YearOf(FMonth) div 10) then Month := day;
  Invalidate;
end;

// the arrows of the header: a month, a year or a decade
procedure TCalendarView.step(delta: integer);
begin
  match FViewMode of
    cvMonth: Month := IncMonth(FMonth, delta);
    cvYear: Month := IncYear(FMonth, delta);
  else
    Month := IncYear(FMonth, delta*10);
  end;
end;

procedure TCalendarView.GoToToday;
begin
  FViewMode := cvMonth;
  Month := SysUtils.Date;
  FCursorDay := SysUtils.Date;
  Invalidate;
end;

// -- marks ----------------------

procedure TCalendarView.Mark(day: TDateTime);
begin
  FMarked.Add(isoText(day));
end;

procedure TCalendarView.Unmark(day: TDateTime);
begin
  var i := FMarked.IndexOf(isoText(day));
  if i >= 0 then FMarked.Delete(i);
end;

procedure TCalendarView.ClearMarks;
begin
  FMarked.Clear;
end;

function TCalendarView.IsMarked(day: TDateTime): boolean;
begin
  result := FMarked.IndexOf(isoText(day)) >= 0;
end;

// every line becomes an ISO date, also the ones a form file or a direct edit
// of the list brings, and what is no date goes
procedure TCalendarView.markedChanged(Sender: TObject);
begin
  if FNormalizing then exit;
  FNormalizing := true;
  try
    var clean := autofree TStringList.Create;
    clean.Sorted := true;
    clean.Duplicates := dupIgnore;
    for var line in FMarked do begin
      var day: TDateTime;
      if parseIso(line, day) then clean.Add(isoText(day));
    end;
    if not clean.Equals(FMarked) then FMarked.Assign(clean);
  finally
    FNormalizing := false;
  end;
  Invalidate;
end;

function TCalendarView.getMarkedDates: TStrings;
begin
  result := FMarked;
end;

procedure TCalendarView.setMarkedDates(value: TStrings);
begin
  FMarked.Assign(value);
end;

// -- painting ----------------------

procedure TCalendarView.Paint;
begin
  var back := ColorToRGB(Color);
  var text := ColorToRGB(if Enabled then clWindowText else clGrayText);
  var dim := ColorToRGB(clGrayText);
  var accent := pick(FAccentColor, clHighlight);
  var todayRing := pick(FTodayColor, accent);
  var markDot := pick(FMarkColor, accent);
  var weekend := pick(FWeekendColor, blend(clWindowText, clRed, 55));
  var header := pick(FHeaderColor, clWindowText);
  var radius := scaled(self, 4);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  var today := SysUtils.Date;
  var lo, hi: TDateTime;
  var hasRange := (FSelection = selRange) and rangeBounds(lo, hi);

  for var i := 0 to cellCount-1 do begin
    var r := cellRect(i);
    var d := cellDate(i);
    if FViewMode = cvMonth then begin
      if not FShowOtherMonths and (MonthOf(d) <> MonthOf(FMonth)) then continue;
      var marked: boolean;
      var custom: TColor;
      var allowed := dayInfo(d, marked, custom);
      var isEnd := false;
      var ranged := hasRange and inRange(d, isEnd);
      var picked := ((FSelection = selSingle) and (FDate <> 0) and (Trunc(FDate) = d)) or ((FSelection = selMultiple) and IsSelected(d)) or (ranged and isEnd);
      if ranged then begin
        // the band through the row stops at the ends of the range
        var cy := (r.Top+r.Bottom) div 2;
        var half := Min(r.Width, r.Height) div 2-scaled(self, 2);
        var band := Rect(r.Left, cy-half, r.Right, cy+half);
        if d = lo then band.Left := (r.Left+r.Right) div 2;
        if (d = hi) or (hi = 0) then band.Right := (r.Left+r.Right) div 2;
        if band.Right > band.Left then paintRoundRect(sp, band, 0, blend(back, accent, 25), clNone);
      end;
      if picked then paintCell(sp, r, accent, clNone)
      else if (i = FHot) and hoverEnabled and allowed and Enabled then paintCell(sp, r, hoverColor(back), clNone);
      if FShowToday and (d = today) and not picked then paintCell(sp, r, clNone, todayRing);
      if (Focused or FKeyboardCursor) and ringEnabled and (d = FCursorDay) then paintCell(sp, r, clNone, ringColor);
      if marked then begin
        var size := Max(scaled(self, 2), 2);
        paintCircle(sp, (r.Left+r.Right) div 2, r.Bottom-scaled(self, 5), size, (if picked then contrastText(accent) else markDot), clNone);
      end;
    end else begin
      var current := if FViewMode = cvYear then (YearOf(d) = YearOf(today)) and (MonthOf(d) = MonthOf(today)) else YearOf(d) = YearOf(today);
      var chosen := (FDate <> 0) and (if FViewMode = cvYear then (YearOf(d) = YearOf(FDate)) and (MonthOf(d) = MonthOf(FDate)) else YearOf(d) = YearOf(FDate));
      var box := r;
      box.Inflate(-scaled(self, 3), -scaled(self, 3));
      if chosen then paintRoundRect(sp, box, radius, accent, clNone)
      else if (i = FHot) and hoverEnabled and Enabled then paintRoundRect(sp, box, radius, hoverColor(back), clNone);
      if FShowToday and current and not chosen then paintRoundRect(sp, box, radius, clNone, todayRing);
      if (Focused or FKeyboardCursor) and ringEnabled and (if FViewMode = cvYear then (MonthOf(d) = MonthOf(FCursorDay)) and (YearOf(d) = YearOf(FCursorDay)) else YearOf(d) = YearOf(FCursorDay)) then paintRoundRect(sp, box, radius, clNone, ringColor);
    end;
  end;
  if FShowHeader then begin
    if FShowNavigation then
      for var next in [false, true] do begin
        var a := arrowRect(next);
        if (FHot = (if next then HOT_NEXT else HOT_PREV)) and hoverEnabled then paintCircle(sp, (a.Left+a.Right) div 2, (a.Top+a.Bottom) div 2, a.Width div 2, hoverColor(back), clNone);
        paintChevron(sp, a, (if next then cdRight else cdLeft), Max(scaled(self, 8), 6), dim);
      end;
    if (FHot = HOT_TITLE) and hoverEnabled then paintRoundRect(sp, titleRect, radius, hoverColor(back), clNone);
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var pad := scaled(self, 6);
  if FShowHeader then begin
    var title := match FViewMode of
      cvMonth: FormatDateTime('mmmm yyyy', FMonth, formatSettingsOf(FLanguage));
      cvYear: IntToStr(YearOf(FMonth));
    else
      IntToStr(decadeStart)+' - '+IntToStr(decadeStart+9)
    end;
    Canvas.Font.Style := Font.Style+[fsBold];
    paintCenteredText(Canvas, Rect(pad, pad, ClientWidth-pad, pad+headerHeight), title, header);
    Canvas.Font.Style := Font.Style;
  end;
  if FViewMode = cvMonth then begin
    var cell := cellSize;
    var first := cellRect(0);
    // the names of the days in the row over the first week
    for var col := 0 to 6 do begin
      var r := Rect(first.Left+col*cell.cx, first.Top-cell.cy, first.Left+(col+1)*cell.cx, first.Top);
      var dayIndex := (col+ord(FFirstDay)+1) mod 7+1; // 1 is Sunday in ShortDayNames
      var weekendName := FHighlightWeekends and (dayIndex in [1, 7]);
      paintCenteredText(Canvas, r, formatSettingsOf(FLanguage).ShortDayNames[dayIndex], (if weekendName then blend(weekend, back, 25) else dim));
    end;
    if FShowWeekNumbers then
      for var row := 0 to 5 do begin
        var r := cellRect(row*7);
        r := Rect(r.Left-cell.cx, r.Top, r.Left, r.Bottom);
        // the week of the Thursday, the way ISO counts
        var thursday := cellDate(row*7)+((3-ord(FFirstDay)+7) mod 7);
        paintCenteredText(Canvas, r, IntToStr(WeekOfTheYear(thursday)), blend(dim, back, 30));
      end;
  end;
  for var i := 0 to cellCount-1 do begin
    var r := cellRect(i);
    var d := cellDate(i);
    var caption: string;
    var color: TColor;
    if FViewMode = cvMonth then begin
      var inMonth := MonthOf(d) = MonthOf(FMonth);
      if not FShowOtherMonths and not inMonth then continue;
      var marked: boolean;
      var custom: TColor;
      var allowed := dayInfo(d, marked, custom);
      var isEnd := false;
      var ranged := hasRange and inRange(d, isEnd);
      var picked := ((FSelection = selSingle) and (FDate <> 0) and (Trunc(FDate) = d)) or ((FSelection = selMultiple) and IsSelected(d)) or (ranged and isEnd);
      caption := IntToStr(DayOf(d));
      if Assigned(FOnDrawDay) then begin
        var state: TDrawState := [];
        if picked then state += [dsSelected];
        if (i = FHot) and hoverEnabled then state += [dsHover];
        if d = today then state += [dsActive];
        if not allowed or not Enabled then state += [dsDisabled];
        var handled := false;
        FOnDrawDay(self, Canvas, cellRect(i), i, state, handled);
        if handled then continue;
      end;
      if picked and (FCellShape = ccUnderline) then color := text
      else if picked then color := contrastText(accent)
      else if not allowed then color := blend(dim, back, 50)
      else if custom <> clDefault then color := ColorToRGB(custom)
      else if not inMonth then color := dim
      else if FHighlightWeekends and (DayOfTheWeek(d) in [6, 7]) then color := weekend
      else color := text;
      // the mark keeps its room under the number
      if marked then r.Bottom -= scaled(self, 3);
    end else begin
      caption := if FViewMode = cvYear then formatSettingsOf(FLanguage).ShortMonthNames[MonthOf(d)] else IntToStr(YearOf(d));
      var chosen := (FDate <> 0) and (if FViewMode = cvYear then (YearOf(d) = YearOf(FDate)) and (MonthOf(d) = MonthOf(FDate)) else YearOf(d) = YearOf(FDate));
      var outside := (FViewMode = cvDecade) and ((i = 0) or (i = 11));
      color := if chosen then contrastText(accent) else if outside then dim else text;
    end;
    paintCenteredText(Canvas, r, caption, color);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// the shape of a day: a circle, a rounded or a plain square inside the cell
procedure TCalendarView.paintCell(sp: TSmoothPaint; const r: TRect; fill, frame: TColor);
begin
  var cx := (r.Left+r.Right) div 2;
  var cy := (r.Top+r.Bottom) div 2;
  var half := Min(r.Width, r.Height) div 2-scaled(self, 2);
  match FCellShape of
    ccCircle: paintCircle(sp, cx, cy, half, fill, frame);
    ccRounded: paintRoundRect(sp, Rect(cx-half, cy-half, cx+half, cy+half), scaled(self, 4), fill, frame);
    ccFill: paintRoundRect(sp, r, 0, fill, frame);
    ccPill: paintRoundRect(sp, Rect(r.Left+1, cy-half, r.Right-1, cy+half), half, fill, frame);
    // a bar under the number; a frame alone becomes a thin bar
    ccUnderline: paintRoundRect(sp, Rect(cx-half, cy+half-scaled(self, 3), cx+half, cy+half), 1, (if fill <> clNone then fill else frame), clNone);
  else
    paintRoundRect(sp, Rect(r.Left+1, r.Top+1, r.Right-1, r.Bottom-1), 0, fill, frame);
  end;
end;

// -- input ----------------------

procedure TCalendarView.setHot(value: integer);
begin
  if FHot = value then exit;
  FHot := value;
  FHover := if (value >= 0) and (FViewMode = cvMonth) then cellDate(value) else 0;
  Invalidate;
end;

procedure TCalendarView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus and not Focused then SetFocus;
  var hit := hitAt(X, Y);
  match hit of
    HOT_NONE: ;
    HOT_PREV: step(-1);
    HOT_NEXT: step(1);
    HOT_TITLE: ViewMode := succ(FViewMode);
  else
    match FViewMode of
      cvMonth: pickDay(cellDate(hit));
      cvYear: begin
        FMonth := cellDate(hit);
        ViewMode := cvMonth;
      end;
    else
      begin
        FMonth := EncodeDate(YearOf(cellDate(hit)), MonthOf(FMonth), 1);
        ViewMode := cvYear;
      end;
    end;
  end;
end;

procedure TCalendarView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  setHot(hitAt(X, Y));
end;

procedure TCalendarView.MouseLeave;
begin
  inherited MouseLeave;
  setHot(HOT_NONE);
end;

function TCalendarView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result then exit;
  step(if WheelDelta < 0 then 1 else -1);
  result := true;
end;

function TCalendarView.HandleKey(var Key: Word; Shift: TShiftState): boolean;
begin
  result := true;
  if FViewMode = cvMonth then
    match Key of
      VK_LEFT: moveCursor(FCursorDay-1);
      VK_RIGHT: moveCursor(FCursorDay+1);
      VK_UP: moveCursor(FCursorDay-7);
      VK_DOWN: moveCursor(FCursorDay+7);
      VK_PRIOR: moveCursor(if ssCtrl in Shift then IncYear(FCursorDay, -1) else IncMonth(FCursorDay, -1));
      VK_NEXT: moveCursor(if ssCtrl in Shift then IncYear(FCursorDay, 1) else IncMonth(FCursorDay, 1));
      VK_HOME: moveCursor(StartOfTheMonth(FCursorDay));
      VK_END: moveCursor(Trunc(EndOfTheMonth(FCursorDay)));
      VK_RETURN, VK_SPACE: if FSelection <> selSingle then pickDay(FCursorDay) else if Assigned(FOnDayClick) then FOnDayClick(self, FCursorDay);
    else
      result := false;
    end
  else begin
    var unitMonths := if FViewMode = cvYear then 1 else 12;
    match Key of
      VK_LEFT: moveCursor(IncMonth(FCursorDay, -unitMonths));
      VK_RIGHT: moveCursor(IncMonth(FCursorDay, unitMonths));
      VK_UP: moveCursor(IncMonth(FCursorDay, -4*unitMonths));
      VK_DOWN: moveCursor(IncMonth(FCursorDay, 4*unitMonths));
      VK_RETURN, VK_SPACE: begin
        FMonth := StartOfTheMonth(FCursorDay);
        ViewMode := pred(FViewMode);
      end;
    else
      result := false;
    end;
  end;
  if result then Key := 0;
end;

procedure TCalendarView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key <> 0 then HandleKey(Key, Shift);
end;

procedure TCalendarView.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TCalendarView.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TCalendarView.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

function TCalendarView.getDate(index: integer): TDateTime;
begin
  result := match index of
    0: FDate;
    1: FRangeStart;
    2: FRangeEnd;
    3: FMinDate;
  else
    FMaxDate
  end;
end;

function TCalendarView.dateStored(index: integer): boolean;
begin
  result := getDate(index) <> 0;
end;

procedure TCalendarView.setDate(index: integer; value: TDateTime);
begin
  if value <> 0 then value := Trunc(value);
  if getDate(index) = value then exit;
  match index of
    0: begin
      FDate := value;
      if value <> 0 then begin
        FCursorDay := value;
        if not (csLoading in ComponentState) then Month := value;
      end;
    end;
    1: begin
      FRangeStart := value;
      FPicking := false;
      if (value <> 0) and not (csLoading in ComponentState) then Month := value;
    end;
    2: begin
      FRangeEnd := value;
      FPicking := false;
    end;
    3: FMinDate := value;
  else
    FMaxDate := value;
  end;
  changed;
end;

procedure TCalendarView.setMonth(value: TDateTime);
begin
  value := StartOfTheMonth(value);
  if FMonth = value then exit;
  FMonth := value;
  Invalidate;
  if Assigned(FOnViewChange) then FOnViewChange(self);
end;

procedure TCalendarView.setSelection(value: TCalendarSelection);
begin
  if FSelection = value then exit;
  FSelection := value;
  FPicking := false;
  Invalidate;
end;

procedure TCalendarView.setViewMode(value: TCalendarViewMode);
begin
  if FViewMode = value then exit;
  FViewMode := value;
  FHot := HOT_NONE;
  Invalidate;
  if Assigned(FOnViewChange) then FOnViewChange(self);
end;

procedure TCalendarView.setFirstDay(value: TCalendarFirstDay);
begin
  if FFirstDay = value then exit;
  FFirstDay := value;
  Invalidate;
end;

procedure TCalendarView.setCellShape(value: TCalendarCellShape);
begin
  if FCellShape = value then exit;
  FCellShape := value;
  Invalidate;
end;

function TCalendarView.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowWeekNumbers;
    1: FShowToday;
    2: FShowOtherMonths;
    3: FShowHeader;
    4: FShowNavigation;
    5: FAllowViewChange;
  else
    FHighlightWeekends
  end;
end;

procedure TCalendarView.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowWeekNumbers := value;
    1: FShowToday := value;
    2: FShowOtherMonths := value;
    3: FShowHeader := value;
    4: FShowNavigation := value;
    5: FAllowViewChange := value;
  else
    FHighlightWeekends := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TCalendarView.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FAccentColor;
    1: FTodayColor;
    2: FMarkColor;
    3: FWeekendColor;
  else
    FHeaderColor
  end;
end;

procedure TCalendarView.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FAccentColor := value;
    1: FTodayColor := value;
    2: FMarkColor := value;
    3: FWeekendColor := value;
  else
    FHeaderColor := value;
  end;
  Invalidate;
end;

procedure TCalendarView.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TCalendarView.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
