{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit DatePicker;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint, PopupWindow, CalendarView;

type
  // the order of the day, the month and the year in the field; doLocale
  // follows the short date format of the format settings
  TDateOrder = (doLocale, doDMY, doMDY, doYMD);
  TDatePart = (dpDay, dpMonth, dpYear);

  TDatePicker = class;

  { TDatePickerFooter }

  // the row under the calendar of the drop down: Today and Clear
  TDatePickerFooter = class(TCustomControl)
  private
    FPicker: TDatePicker;
    FHot: integer; // 0 Today, 1 Clear, -1 none
    function buttonRect(index: integer): TRect;
    function buttonCount: integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(picker: TDatePicker); reintroduce;
  end;

  { TDatePicker }

  // a date typed part by part, or picked on the calendar it drops: digits
  // fill the active part, Left and Right move between the parts, Up, Down
  // and the wheel step it, Alt+Down and F4 open the calendar. While the
  // calendar is open the arrows walk its days and Enter takes one
  TDatePicker = class(TCustomControl)
  private
    FDate, FMinDate, FMaxDate: TDateTime;
    FDay, FMonthNum, FYear: integer; // the parts, 0 while not given
    FOrder: TDateOrder;
    FSeparator, FEmptyText, FTodayCaption, FClearCaption: string;
    FActive: integer; // the part the keys go to, by position
    FTyped: string; // digits typed into the active part so far
    FAllowEmpty, FReadOnly, FShowButton, FShowTodayButton, FShowWeekNumbers: boolean;
    FFirstDay: TCalendarFirstDay;
    FCornerRadius, FPadding: integer;
    FBorderColor, FFocusBorderColor, FFieldColor, FActiveFieldColor: TColor;
    FHotButton: boolean;
    FPopup: TDropPopup;
    FCalendar: TCalendarView;
    FFooter: TDatePickerFooter;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FOnChange, FOnDropDown, FOnCloseUp: TNotifyEvent;
    procedure setDate(index: integer; value: TDateTime);
    function getDate(index: integer): TDateTime;
    function dateStored(index: integer): boolean;
    procedure setOrder(value: TDateOrder);
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setFirstDay(value: TCalendarFirstDay);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    function partAt(position: integer): TDatePart;
    function separatorText: string;
    function partChars(part: TDatePart): integer;
    function partText(position: integer): string;
    function partRect(position: integer): TRect;
    function buttonRect: TRect;
    function positionAt(x: integer): integer;
    function isEmpty: boolean;
    procedure loadParts(day: TDateTime);
    procedure partsChanged;
    procedure stepActive(delta: integer);
    procedure commitTyped;
    procedure buildPopup;
    procedure calendarDayClick(Sender: TObject; day: TDateTime);
    procedure popupDismiss(Sender: TObject);
    procedure applyDate(value: TDateTime);
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
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
    function DroppedDown: boolean;
    // empties the field when AllowEmpty
    procedure Clear;
    procedure SelectToday;
    // the date as the field shows it, '' for none
    function Text: string;
    // reads a date written in the order of the field; false leaves the date
    function SetText(const value: string): boolean;
    // the calendar of the drop down, there to be set up further
    property Calendar: TCalendarView read FCalendar;
  published
    // 0 for none
    property Date: TDateTime index 0 read getDate write setDate stored dateStored;
    // 0 for no limit
    property MinDate: TDateTime index 1 read getDate write setDate stored dateStored;
    property MaxDate: TDateTime index 2 read getDate write setDate stored dateStored;
    property DateOrder: TDateOrder read FOrder write setOrder default doLocale;
    // between the parts; empty takes the date separator of the format settings
    property Separator: string index 0 read getText write setText;
    // the gray text of an empty field
    property EmptyText: string index 1 read getText write setText;
    property TodayCaption: string index 2 read getText write setText;
    property ClearCaption: string index 3 read getText write setText;
    property AllowEmpty: boolean index 0 read getFlag write setFlag default true;
    property ReadOnly: boolean index 1 read getFlag write setFlag default false;
    // the calendar button at the right end
    property ShowButton: boolean index 2 read getFlag write setFlag default true;
    // the row with Today and Clear under the calendar
    property ShowTodayButton: boolean index 3 read getFlag write setFlag default true;
    property ShowWeekNumbers: boolean index 4 read getFlag write setFlag default false;
    property FirstDayOfWeek: TCalendarFirstDay read FFirstDay write setFirstDay default fdMonday;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    property Padding: integer index 1 read getMetric write setMetric default 6;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FieldColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property ActiveFieldColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
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

{ TDatePickerFooter }

constructor TDatePickerFooter.Create(picker: TDatePicker);
begin
  inherited Create(picker);
  FPicker := picker;
  FHot := -1;
  ControlStyle := ControlStyle+[csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
end;

function TDatePickerFooter.buttonCount: integer;
begin
  result := if FPicker.FAllowEmpty then 2 else 1;
end;

function TDatePickerFooter.buttonRect(index: integer): TRect;
begin
  var half := ClientWidth div buttonCount;
  result := Rect(index*half, 0, (index+1)*half, ClientHeight);
  result.Inflate(-scaled(self, 6), -scaled(self, 4));
end;

procedure TDatePickerFooter.Paint;
begin
  var back := ColorToRGB(clWindow);
  var accent := ColorToRGB(clHighlight);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FPicker.FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  paintLine(sp, scaled(self, 6), 0, ClientWidth-scaled(self, 6), 0, blend(back, clWindowText, 15), 1);
  if (FHot >= 0) and hoverEnabled then paintRoundRect(sp, buttonRect(FHot), scaled(self, 4), hoverColor(back), clNone);
  sp.Flush;
  applyTextQuality(Canvas);
  paintCenteredText(Canvas, buttonRect(0), FPicker.FTodayCaption, accent);
  if buttonCount > 1 then paintCenteredText(Canvas, buttonRect(1), FPicker.FClearCaption, accent);
end;

procedure TDatePickerFooter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if buttonRect(0).Contains(Point(X, Y)) then FPicker.SelectToday
  else if (buttonCount > 1) and buttonRect(1).Contains(Point(X, Y)) then begin
    FPicker.Clear;
    FPicker.CloseUp;
  end;
end;

procedure TDatePickerFooter.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := -1;
  for var i := 0 to buttonCount-1 do if buttonRect(i).Contains(Point(X, Y)) then hot := i;
  if hot <> FHot then begin
    FHot := hot;
    Invalidate;
  end;
end;

procedure TDatePickerFooter.MouseLeave;
begin
  inherited MouseLeave;
  if FHot >= 0 then begin
    FHot := -1;
    Invalidate;
  end;
end;

{ TDatePicker }

constructor TDatePicker.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FAllowEmpty := true;
  FShowButton := true;
  FShowTodayButton := true;
  FEmptyText := 'Pick a date';
  FTodayCaption := 'Today';
  FClearCaption := 'Clear';
  FCornerRadius := 4;
  FPadding := 6;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FFieldColor := clDefault;
  FActiveFieldColor := clDefault;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TDatePicker.Destroy;
begin
  FreeAndNil(FPopup);
  inherited Destroy;
end;

class function TDatePicker.GetControlClassDefaultSize: TSize;
begin
  result.cx := 140;
  result.cy := 27;
end;

// -- parts ----------------------

// the part at a position of the field, after the order
function TDatePicker.partAt(position: integer): TDatePart;
begin
  var order := FOrder;
  if order = doLocale then begin
    // the first letter of the format that names a part decides
    var f := LowerCase(formatSettingsOf(FLanguage).ShortDateFormat);
    var d := Pos('d', f);
    var m := Pos('m', f);
    var y := Pos('y', f);
    if (y > 0) and (y < m) and (y < d) then order := doYMD
    else if (m > 0) and (m < d) then order := doMDY
    else order := doDMY;
  end;
  var parts: array[0..2] of TDatePart;
  match order of
    doMDY: parts := [dpMonth, dpDay, dpYear];
    doYMD: parts := [dpYear, dpMonth, dpDay];
  else
    parts := [dpDay, dpMonth, dpYear];
  end;
  result := parts[EnsureRange(position, 0, 2)];
end;

function TDatePicker.separatorText: string;
begin
  result := if FSeparator <> '' then FSeparator else formatSettingsOf(FLanguage).DateSeparator;
end;

function TDatePicker.partChars(part: TDatePart): integer;
begin
  result := if part = dpYear then 4 else 2;
end;

function TDatePicker.isEmpty: boolean;
begin
  result := (FDay = 0) and (FMonthNum = 0) and (FYear = 0) and (FTyped = '');
end;

function TDatePicker.partText(position: integer): string;
begin
  var part := partAt(position);
  if (position = FActive) and (FTyped <> '') then exit(FTyped);
  var v := match part of
    dpDay: FDay;
    dpMonth: FMonthNum;
  else
    FYear
  end;
  if v = 0 then exit(StringOfChar('-', partChars(part)));
  result := IntToStr(v);
  while length(result) < partChars(part) do result := '0'+result;
end;

function TDatePicker.partRect(position: integer): TRect;
begin
  var pad := scaled(self, FPadding);
  var x := pad;
  var charW := Canvas.TextWidth('0');
  var sepW := Canvas.TextWidth(separatorText)+scaled(self, 4);
  var h := Canvas.TextHeight('0');
  var top := (ClientHeight-h) div 2;
  for var i := 0 to 2 do begin
    var w := partChars(partAt(i))*charW;
    if i = position then exit(Rect(x-1, top-1, x+w+1, top+h+1));
    x += w+sepW;
  end;
  result := Rect(0, 0, 0, 0);
end;

function TDatePicker.buttonRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not FShowButton then exit;
  var size := Canvas.TextHeight('Hg');
  var pad := scaled(self, FPadding);
  result := Rect(ClientWidth-pad-size, (ClientHeight-size) div 2, ClientWidth-pad, (ClientHeight-size) div 2+size);
end;

function TDatePicker.positionAt(x: integer): integer;
begin
  for var i := 0 to 2 do
    if x < partRect(i).Right+Canvas.TextWidth(separatorText) div 2 then exit(i);
  result := 2;
end;

procedure TDatePicker.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var last := partRect(2);
  var pad := scaled(self, FPadding);
  PreferredWidth := Max(last.Right, Canvas.TextWidth(FEmptyText)+pad)+pad+(if FShowButton then Canvas.TextHeight('Hg')+pad else 0);
  PreferredHeight := Canvas.TextHeight('Hg')+pad*2-scaled(self, 2);
end;

procedure TDatePicker.loadParts(day: TDateTime);
begin
  if day = 0 then begin
    FDay := 0;
    FMonthNum := 0;
    FYear := 0;
  end else begin
    FDay := DayOf(day);
    FMonthNum := MonthOf(day);
    FYear := YearOf(day);
  end;
end;

// the parts make a date once all of them are there; a day past the end of
// its month falls back to the last one
procedure TDatePicker.partsChanged;
begin
  var value: TDateTime := 0;
  if (FDay > 0) and (FMonthNum > 0) and (FYear > 0) then begin
    FDay := Min(FDay, DaysInAMonth(FYear, FMonthNum));
    value := EncodeDate(FYear, FMonthNum, FDay);
  end;
  applyDate(value);
end;

// the limits hold; a date outside them moves to the nearer one
procedure TDatePicker.applyDate(value: TDateTime);
begin
  if value <> 0 then begin
    value := Trunc(value);
    if (FMinDate <> 0) and (value < FMinDate) then value := FMinDate;
    if (FMaxDate <> 0) and (value > FMaxDate) then value := FMaxDate;
    loadParts(value);
  end;
  if (value = 0) and not FAllowEmpty and (FDate <> 0) then begin
    // a field that cannot be empty keeps the last whole date
    loadParts(FDate);
    Invalidate;
    exit;
  end;
  Invalidate;
  if FDate = value then exit;
  FDate := value;
  InvalidatePreferredSize;
  AdjustSize;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TDatePicker.stepActive(delta: integer);
begin
  if FReadOnly or not Enabled then exit;
  commitTyped;
  var today := SysUtils.Date;
  // an empty part starts from today
  if FDay = 0 then FDay := DayOf(today);
  if FMonthNum = 0 then FMonthNum := MonthOf(today);
  if FYear = 0 then FYear := YearOf(today);
  match partAt(FActive) of
    dpDay: FDay := (FDay-1+delta+DaysInAMonth(FYear, FMonthNum)*10) mod DaysInAMonth(FYear, FMonthNum)+1;
    dpMonth: FMonthNum := (FMonthNum-1+delta+120) mod 12+1;
  else
    FYear := EnsureRange(FYear+delta, 1, 9999);
  end;
  partsChanged;
end;

// the digits typed replace the part
procedure TDatePicker.commitTyped;
begin
  if FTyped = '' then exit;
  var typed := StrToIntDef(FTyped, 0);
  FTyped := '';
  match partAt(FActive) of
    dpDay: FDay := EnsureRange(typed, 0, 31);
    dpMonth: FMonthNum := EnsureRange(typed, 0, 12);
  else
    begin
      // two digits mean the current century
      if (typed > 0) and (typed < 100) then typed += YearOf(SysUtils.Date) div 100*100;
      FYear := EnsureRange(typed, 0, 9999);
    end;
  end;
  partsChanged;
end;

// -- text ----------------------

function TDatePicker.Text: string;
begin
  if FDate = 0 then exit('');
  result := '';
  for var i := 0 to 2 do begin
    if i > 0 then result += separatorText;
    result += partText(i);
  end;
end;

function TDatePicker.SetText(const value: string): boolean;
begin
  result := false;
  var s := Trim(value);
  if s = '' then begin
    if FAllowEmpty then begin
      Clear;
      result := true;
    end;
    exit;
  end;
  // any run of other characters splits the parts
  var numbers: array of integer;
  var current := '';
  for var ch in s+' ' do
    if ch in ['0'..'9'] then current += ch
    else if current <> '' then begin
      numbers := numbers+[StrToInt(current)];
      current := '';
    end;
  if length(numbers) <> 3 then exit;
  var d, m, y: integer;
  for var i := 0 to 2 do
    match partAt(i) of
      dpDay: d := numbers[i];
      dpMonth: m := numbers[i];
    else
      y := numbers[i];
    end;
  if (y > 0) and (y < 100) then y += YearOf(SysUtils.Date) div 100*100;
  var parsed: TDateTime;
  if not TryEncodeDate(y, m, d, parsed) then exit;
  applyDate(parsed);
  result := true;
end;

// -- painting ----------------------

procedure TDatePicker.Paint;
begin
  var border := pick(FBorderColor, clBtnShadow);
  if (Focused or DroppedDown) and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := pick(FFieldColor, clWindow);
  var activeFill := pick(FActiveFieldColor, clHighlight);
  if not Enabled then field := ColorToRGB(clBtnFace);
  var editing := Focused and Enabled and not FReadOnly;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  if editing then paintRoundRect(sp, partRect(FActive), scaled(self, 2), activeFill, clNone);
  if FShowButton then begin
    var b := buttonRect;
    var glyph := ColorToRGB(if Enabled then clGrayText else clBtnShadow);
    if (FHotButton or DroppedDown) and hoverEnabled and Enabled then paintCircle(sp, (b.Left+b.Right) div 2, (b.Top+b.Bottom) div 2, b.Width div 2+scaled(self, 2), hoverColor(field), clNone);
    // a small sheet of a calendar: the bar on top and two rows of days
    var s := b.Width*3 div 4;
    var page := Rect((b.Left+b.Right-s) div 2, (b.Top+b.Bottom-s) div 2, (b.Left+b.Right+s) div 2, (b.Top+b.Bottom+s) div 2);
    paintRoundRect(sp, page, Max(s div 6, 1), clNone, glyph, Max(scaled(self, 1), 1));
    paintRoundRect(sp, Rect(page.Left, page.Top, page.Right, page.Top+Max(s div 4, 2)), 0, glyph, clNone);
    var dot := Max(s div 10, 1);
    for var row := 0 to 1 do
      for var col := 0 to 2 do
        paintCircle(sp, page.Left+s*(col+1) div 4, page.Top+s*(row+2) div 4+dot div 2, dot, glyph, clNone);
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  if isEmpty and not editing then begin
    var pad := scaled(self, FPadding);
    var right := if FShowButton then buttonRect.Left-pad div 2 else ClientWidth-pad;
    var style := Canvas.TextStyle;
    style.Alignment := taLeftJustify;
    style.Layout := tlCenter;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    style.EndEllipsis := true;
    Canvas.Font.Color := ColorToRGB(clGrayText);
    Canvas.TextRect(Rect(pad, 0, right, ClientHeight), pad, 0, FEmptyText, style);
  end else begin
    var plain := ColorToRGB(if Enabled then clWindowText else clGrayText);
    var sep := separatorText;
    for var i := 0 to 2 do begin
      var r := partRect(i);
      var active := editing and (i = FActive);
      var box := r;
      box.Inflate(-1, -1);
      paintCenteredText(Canvas, box, partText(i), (if active then contrastText(activeFill) else plain));
      if i < 2 then paintCenteredText(Canvas, Rect(r.Right, r.Top, partRect(i+1).Left, r.Bottom), sep, plain);
    end;
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- drop down ----------------------

procedure TDatePicker.buildPopup;
begin
  if FPopup <> nil then exit;
  FPopup := TDropPopup.Create(self);
  FPopup.OnDismiss := @popupDismiss;
  FCalendar := TCalendarView.Create(FPopup);
  FCalendar.Parent := FPopup;
  FCalendar.Language := FLanguage;
  FCalendar.TabStop := false;
  FCalendar.KeyboardCursor := true;
  FCalendar.ControlStyle := FCalendar.ControlStyle+[csNoFocus];
  FCalendar.OnDayClick := @calendarDayClick;
  FFooter := TDatePickerFooter.Create(self);
  FFooter.Parent := FPopup;
end;

procedure TDatePicker.DropDown;
begin
  if (csDesigning in ComponentState) or FReadOnly or not Enabled then exit;
  buildPopup;
  commitTyped;
  FCalendar.Font := Font;
  FCalendar.MinDate := FMinDate;
  FCalendar.MaxDate := FMaxDate;
  FCalendar.ShowWeekNumbers := FShowWeekNumbers;
  FCalendar.FirstDayOfWeek := FFirstDay;
  FCalendar.ViewMode := cvMonth;
  FCalendar.Date := FDate;
  FCalendar.Month := if FDate <> 0 then FDate else SysUtils.Date;
  var w, h: integer;
  FCalendar.GetPreferredSize(w, h);
  var footerH := if FShowTodayButton then Canvas.TextHeight('Hg')+scaled(self, 12) else 0;
  var inner := Rect(1, 1, 1+w, 1+h);
  FCalendar.BoundsRect := inner;
  FFooter.Visible := FShowTodayButton;
  FFooter.SetBounds(1, inner.Bottom, w, footerH);
  FPopup.Drop(self, w+2, h+footerH+2);
  Invalidate;
  if Assigned(FOnDropDown) then FOnDropDown(self);
end;

procedure TDatePicker.CloseUp;
begin
  if not DroppedDown then exit;
  FPopup.Close;
  Invalidate;
  if Assigned(FOnCloseUp) then FOnCloseUp(self);
end;

function TDatePicker.DroppedDown: boolean;
begin
  result := (FPopup <> nil) and FPopup.Visible;
end;

procedure TDatePicker.popupDismiss(Sender: TObject);
begin
  CloseUp;
end;

procedure TDatePicker.calendarDayClick(Sender: TObject; day: TDateTime);
begin
  FTyped := '';
  applyDate(day);
  CloseUp;
end;

procedure TDatePicker.SelectToday;
begin
  FTyped := '';
  applyDate(SysUtils.Date);
  CloseUp;
end;

procedure TDatePicker.Clear;
begin
  if not FAllowEmpty then exit;
  FTyped := '';
  loadParts(0);
  applyDate(0);
end;

// -- input ----------------------

procedure TDatePicker.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then exit;
  if DroppedDown then begin
    match Key of
      VK_ESCAPE, VK_F4, VK_TAB: begin
        CloseUp;
        if Key <> VK_TAB then Key := 0;
        exit;
      end;
      VK_UP: if ssAlt in Shift then begin
        CloseUp;
        Key := 0;
        exit;
      end;
    else
      ;
    end;
    // the rest moves through the calendar; Enter takes the day there
    if (Key = VK_RETURN) or (Key = VK_SPACE) then begin
      calendarDayClick(FCalendar, FCalendar.CursorDate);
      Key := 0;
      exit;
    end;
    if FCalendar.HandleKey(Key, Shift) then exit;
  end;
  match Key of
    VK_DOWN: if ssAlt in Shift then DropDown else stepActive(-1);
    VK_UP: stepActive(1);
    VK_F4: DropDown;
    VK_LEFT: begin
      commitTyped;
      FActive := Max(FActive-1, 0);
    end;
    VK_RIGHT: begin
      commitTyped;
      FActive := Min(FActive+1, 2);
    end;
    VK_HOME: begin
      commitTyped;
      FActive := 0;
    end;
    VK_END: begin
      commitTyped;
      FActive := 2;
    end;
    VK_PRIOR: stepActive(if partAt(FActive) = dpYear then 10 else 1);
    VK_NEXT: stepActive(if partAt(FActive) = dpYear then -10 else -1);
    VK_BACK: if FTyped <> '' then Delete(FTyped, length(FTyped), 1) else Clear;
    VK_DELETE: Clear;
    VK_RETURN: commitTyped;
    VK_ESCAPE: FTyped := '';
  else
    exit;
  end;
  Key := 0;
  Invalidate;
end;

procedure TDatePicker.KeyPress(var Key: char);
begin
  inherited KeyPress(Key);
  if Key = #0 then exit;
  if FReadOnly or DroppedDown then begin
    Key := #0;
    exit;
  end;
  if not (Key in ['0'..'9']) then begin
    // a separator moves on to the next part
    if (Key in ['.', '/', '-', ' ', ',']) or ((separatorText <> '') and (Key = separatorText[1])) then begin
      commitTyped;
      FActive := Min(FActive+1, 2);
      Invalidate;
    end;
    Key := #0;
    exit;
  end;
  FTyped += Key;
  // a full part moves on to the next one
  if length(FTyped) >= partChars(partAt(FActive)) then begin
    commitTyped;
    if FActive < 2 then inc(FActive);
  end;
  Invalidate;
  Key := #0;
end;

procedure TDatePicker.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus and not Focused then SetFocus;
  if FShowButton and buttonRect.Contains(Point(X, Y)) then begin
    if DroppedDown then CloseUp else DropDown;
    exit;
  end;
  commitTyped;
  FActive := positionAt(X);
  Invalidate;
end;

procedure TDatePicker.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := FShowButton and buttonRect.Contains(Point(X, Y));
  if hot <> FHotButton then begin
    FHotButton := hot;
    Invalidate;
  end;
end;

procedure TDatePicker.MouseLeave;
begin
  inherited MouseLeave;
  if FHotButton then begin
    FHotButton := false;
    Invalidate;
  end;
end;

function TDatePicker.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or DroppedDown then exit;
  var local := MousePos; // the wheel position comes in client coordinates
  FActive := positionAt(local.X);
  stepActive(if WheelDelta > 0 then 1 else -1);
  result := true;
end;

procedure TDatePicker.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TDatePicker.DoExit;
begin
  inherited DoExit;
  commitTyped;
  CloseUp;
  Invalidate;
end;

procedure TDatePicker.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

function TDatePicker.getDate(index: integer): TDateTime;
begin
  result := match index of
    0: FDate;
    1: FMinDate;
  else
    FMaxDate
  end;
end;

function TDatePicker.dateStored(index: integer): boolean;
begin
  result := getDate(index) <> 0;
end;

procedure TDatePicker.setDate(index: integer; value: TDateTime);
begin
  if value <> 0 then value := Trunc(value);
  match index of
    0: begin
      FTyped := '';
      loadParts(value);
      applyDate(value);
    end;
    1: begin
      FMinDate := value;
      if FDate <> 0 then applyDate(FDate);
    end;
  else
    begin
      FMaxDate := value;
      if FDate <> 0 then applyDate(FDate);
    end;
  end;
end;

procedure TDatePicker.setOrder(value: TDateOrder);
begin
  if FOrder = value then exit;
  FOrder := value;
  FActive := 0;
  FTyped := '';
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDatePicker.getText(index: integer): string;
begin
  result := match index of
    0: FSeparator;
    1: FEmptyText;
    2: FTodayCaption;
  else
    FClearCaption
  end;
end;

procedure TDatePicker.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FSeparator := value;
    1: FEmptyText := value;
    2: FTodayCaption := value;
  else
    FClearCaption := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDatePicker.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FAllowEmpty;
    1: FReadOnly;
    2: FShowButton;
    3: FShowTodayButton;
  else
    FShowWeekNumbers
  end;
end;

procedure TDatePicker.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: begin
      FAllowEmpty := value;
      // a field that cannot be empty starts at today
      if not value and (FDate = 0) and not (csLoading in ComponentState) then applyDate(SysUtils.Date);
    end;
    1: FReadOnly := value;
    2: FShowButton := value;
    3: FShowTodayButton := value;
  else
    FShowWeekNumbers := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TDatePicker.setFirstDay(value: TCalendarFirstDay);
begin
  FFirstDay := value;
end;

function TDatePicker.getMetric(index: integer): integer;
begin
  result := if index = 0 then FCornerRadius else FPadding;
end;

procedure TDatePicker.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FCornerRadius := value else FPadding := value;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TDatePicker.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBorderColor;
    1: FFocusBorderColor;
    2: FFieldColor;
  else
    FActiveFieldColor
  end;
end;

procedure TDatePicker.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FFocusBorderColor := value;
    2: FFieldColor := value;
  else
    FActiveFieldColor := value;
  end;
  Invalidate;
end;

procedure TDatePicker.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  if FPopup <> nil then FCalendar.Language := value;
  Invalidate;
end;

procedure TDatePicker.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
