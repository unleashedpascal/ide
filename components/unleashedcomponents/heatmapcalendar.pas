{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit HeatmapCalendar;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LMessages, ControlPaint;

type
  THeatmapCellEvent = procedure(Sender: TObject; date: TDateTime; value: double) of object;
  // the outline of a day: a box rounded by CornerRadius, a square, or a circle
  THeatmapCellShape = (hcRounded, hcSquare, hcCircle);
  // the text of the hint over a cell; text comes in as "date: value"
  THeatmapHintEvent = procedure(Sender: TObject; date: TDateTime; value: double; var text: string) of object;

  { THeatmapCalendar }

  // a year of days as a grid of squares, one column per week, the color of
  // a square growing with its value: commits, steps, sales, anything
  // counted per day. The mouse names the day and its value in a hint
  THeatmapCalendar = class(TGraphicControl)
  private
    type
      TEntry = record
        date: TDateTime; // the day, whole
        value: double;
      end;
    var
    FEntries: array of TEntry; // sorted by date
    FStartDate, FEndDate: TDateTime;
    FLevels, FCellSize, FCellGap, FCornerRadius: integer;
    FMaxValue: double;
    FAutoRange, FShowMonths, FShowWeekdays, FShowLegend, FMondayFirst, FShowEmptyOutline: boolean;
    FEmptyColor, FLowColor, FHighColor, FTextColor, FOutlineColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FCellShape: THeatmapCellShape;
    FLanguage: TFormatLanguage;
    FHotDate: TDateTime;
    FOnCellClick, FOnCellHover: THeatmapCellEvent;
    FOnHint: THeatmapHintEvent;
    FOnDrawCell: TCustomDrawEvent;
    procedure setRange(index: integer; value: TDateTime);
    function getRange(index: integer): TDateTime;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setMaxValue(value: double);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setCellShape(value: THeatmapCellShape);
    procedure setLanguage(value: TFormatLanguage);
    function find(date: TDateTime; out index: integer): boolean;
    function firstColumnDate: TDateTime;
    function cellRect(date: TDateTime): TRect;
    function dateAt(x, y: integer): TDateTime;
    function levelOf(value: double): integer;
    function levelColor(level: integer): TColor;
    function gridLeft: integer;
    function gridTop: integer;
    function cellPx: integer;
    function gapPx: integer;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    // the hint names the day under the mouse and ends at the edge of its cell
    procedure CMHintShow(var Message: TLMessage); message CM_HINTSHOW;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the value of a day; a day without one counts as zero
    procedure SetValue(date: TDateTime; value: double);
    function GetValue(date: TDateTime): double;
    // adds to the value of a day
    procedure Add(date: TDateTime; delta: double = 1);
    procedure Clear;
    // lines of yyyy-mm-dd=value
    procedure LoadFromStrings(lines: TStrings);
    procedure SaveToStrings(lines: TStrings);
    // the range set to one calendar year
    procedure ShowYear(year: integer);
    // the last twelve months up to today
    procedure ShowLastYear;
    function Total: double;
    function MaxOf: double;
    property HotDate: TDateTime read FHotDate;
  published
    // the first and the last day shown; 0 for the last twelve months
    property StartDate: TDateTime index 0 read getRange write setRange;
    property EndDate: TDateTime index 1 read getRange write setRange;
    // the number of color steps between empty and the strongest
    property Levels: integer index 0 read getMetric write setMetric default 4;
    property CellSize: integer index 1 read getMetric write setMetric default 11;
    property CellGap: integer index 2 read getMetric write setMetric default 3;
    property CornerRadius: integer index 3 read getMetric write setMetric default 2;
    // the value of the strongest color; AutoRange takes the highest value shown
    property MaxValue: double read FMaxValue write setMaxValue;
    property AutoRange: boolean index 0 read getFlag write setFlag default true;
    property ShowMonths: boolean index 1 read getFlag write setFlag default true;
    property ShowWeekdays: boolean index 2 read getFlag write setFlag default true;
    property ShowLegend: boolean index 3 read getFlag write setFlag default true;
    property MondayFirst: boolean index 4 read getFlag write setFlag default true;
    // a faint frame around days without a value
    property ShowEmptyOutline: boolean index 5 read getFlag write setFlag default false;
    // clDefault takes the colors of the theme; the levels run from Low to High
    property EmptyColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property LowColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property HighColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property OutlineColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property CellShape: THeatmapCellShape read FCellShape write setCellShape default hcRounded;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnCellClick: THeatmapCellEvent read FOnCellClick write FOnCellClick;
    // the mouse came over a day; date 0 once it left
    property OnCellHover: THeatmapCellEvent read FOnCellHover write FOnCellHover;
    property OnHint: THeatmapHintEvent read FOnHint write FOnHint;
    // paints over the square of a day: index counts the days from the first
    // one shown; dsHover under the mouse
    property OnDrawCell: TCustomDrawEvent read FOnDrawCell write FOnDrawCell;
    property Align;
    property Anchors;
    property AutoSize default true;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint default true;
    property Visible;
    property OnClick;
    property OnDblClick;
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
  DAYS_MONDAY: array[0..6] of string = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');
  DAYS_SUNDAY: array[0..6] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');

constructor THeatmapCalendar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FLevels := 4;
  FCellSize := 11;
  FCellGap := 3;
  FCornerRadius := 2;
  FAutoRange := true;
  FShowMonths := true;
  FShowWeekdays := true;
  FShowLegend := true;
  FMondayFirst := true;
  FEmptyColor := clDefault;
  FLowColor := clDefault;
  FHighColor := clDefault;
  FTextColor := clDefault;
  FOutlineColor := clDefault;
  FAntialiasing := asTheme;
  ParentColor := true;
  ParentShowHint := false;
  ShowHint := true;
  Hint := 'calendar'; // replaced per cell when the hint shows
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function THeatmapCalendar.GetControlClassDefaultSize: TSize;
begin
  result.cx := 760;
  result.cy := 130;
end;

// -- data ----------------------

function THeatmapCalendar.find(date: TDateTime; out index: integer): boolean;
begin
  // a binary search over the sorted days
  var lo := 0;
  var hi := high(FEntries);
  date := Trunc(date);
  while lo <= hi do begin
    var mid := (lo+hi) div 2;
    if FEntries[mid].date < date then lo := mid+1
    else if FEntries[mid].date > date then hi := mid-1
    else begin
      index := mid;
      exit(true);
    end;
  end;
  index := lo;
  result := false;
end;

procedure THeatmapCalendar.SetValue(date: TDateTime; value: double);
begin
  var index: integer;
  if find(date, index) then FEntries[index].value := value
  else begin
    SetLength(FEntries, length(FEntries)+1);
    for var k := high(FEntries) downto index+1 do FEntries[k] := FEntries[k-1];
    FEntries[index].date := Trunc(date);
    FEntries[index].value := value;
  end;
  Invalidate;
end;

function THeatmapCalendar.GetValue(date: TDateTime): double;
begin
  var index: integer;
  result := if find(date, index) then FEntries[index].value else 0;
end;

procedure THeatmapCalendar.Add(date: TDateTime; delta: double);
begin
  SetValue(date, GetValue(date)+delta);
end;

procedure THeatmapCalendar.Clear;
begin
  FEntries := nil;
  Invalidate;
end;

procedure THeatmapCalendar.LoadFromStrings(lines: TStrings);
begin
  FEntries := nil;
  var fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  for var i := 0 to lines.Count-1 do begin
    var name := Trim(lines.Names[i]);
    if length(name) <> 10 then continue;
    var y := StrToIntDef(Copy(name, 1, 4), 0);
    var m := StrToIntDef(Copy(name, 6, 2), 0);
    var d := StrToIntDef(Copy(name, 9, 2), 0);
    if (y = 0) or (m = 0) or (d = 0) then continue;
    SetValue(EncodeDate(y, m, d), StrToFloatDef(Trim(lines.ValueFromIndex[i]), 0, fs));
  end;
end;

procedure THeatmapCalendar.SaveToStrings(lines: TStrings);
begin
  var fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  for var e in FEntries do lines.Add(FormatDateTime('yyyy-mm-dd', e.date)+'='+FloatToStr(e.value, fs));
end;

procedure THeatmapCalendar.ShowYear(year: integer);
begin
  FStartDate := EncodeDate(year, 1, 1);
  FEndDate := EncodeDate(year, 12, 31);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure THeatmapCalendar.ShowLastYear;
begin
  FStartDate := 0;
  FEndDate := 0;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function THeatmapCalendar.Total: double;
begin
  result := 0;
  for var e in FEntries do result += e.value;
end;

function THeatmapCalendar.MaxOf: double;
begin
  result := 0;
  var first := getRange(0);
  var last := getRange(1);
  for var e in FEntries do if (e.date >= first) and (e.date <= last) then result := Max(result, e.value);
end;

// -- geometry ----------------------

function THeatmapCalendar.getRange(index: integer): TDateTime;
begin
  if index = 0 then begin
    result := FStartDate;
    if result = 0 then result := IncYear(Trunc(Date), -1)+1;
  end else begin
    result := FEndDate;
    if result = 0 then result := Trunc(Date);
  end;
end;

function THeatmapCalendar.cellPx: integer;
begin
  result := Max(scaled(self, FCellSize), 2);
end;

function THeatmapCalendar.gapPx: integer;
begin
  result := scaled(self, FCellGap);
end;

function THeatmapCalendar.gridLeft: integer;
begin
  result := if FShowWeekdays then textWidthOf(Font, 'Wed')+scaled(self, 6) else 0;
end;

function THeatmapCalendar.gridTop: integer;
begin
  result := if FShowMonths then lineHeightOf(Font)+scaled(self, 4) else 0;
end;

// the day in the top left cell: the start of the week the range begins in
function THeatmapCalendar.firstColumnDate: TDateTime;
begin
  var first := getRange(0);
  var dow := DayOfWeek(first); // 1 sunday .. 7 saturday
  var offset := if FMondayFirst then (dow+5) mod 7 else dow-1;
  result := first-offset;
end;

function THeatmapCalendar.cellRect(date: TDateTime): TRect;
begin
  var days := Trunc(date)-Trunc(firstColumnDate);
  var column := days div 7;
  var row := days mod 7;
  var step := cellPx+gapPx;
  result.Left := gridLeft+column*step;
  result.Top := gridTop+row*step;
  result.Right := result.Left+cellPx;
  result.Bottom := result.Top+cellPx;
end;

function THeatmapCalendar.dateAt(x, y: integer): TDateTime;
begin
  result := 0;
  var step := cellPx+gapPx;
  if (x < gridLeft) or (y < gridTop) then exit;
  var column := (x-gridLeft) div step;
  var row := (y-gridTop) div step;
  if (row > 6) or ((x-gridLeft) mod step >= cellPx) or ((y-gridTop) mod step >= cellPx) then exit;
  var d := firstColumnDate+column*7+row;
  if (d < getRange(0)) or (d > getRange(1)) then exit;
  result := d;
end;

function THeatmapCalendar.levelOf(value: double): integer;
begin
  if value <= 0 then exit(0);
  var top := if FAutoRange then MaxOf else FMaxValue;
  if top <= 0 then exit(1);
  result := EnsureRange(Ceil(value/top*FLevels), 1, FLevels);
end;

function THeatmapCalendar.levelColor(level: integer): TColor;
begin
  var back := GetRGBColorResolvingParent;
  var empty := pick(FEmptyColor, blend(back, clWindowText, 8));
  if level <= 0 then exit(empty);
  var low := pick(FLowColor, blend(clHighlight, back, 60));
  var high := pick(FHighColor, clHighlight);
  result := if FLevels <= 1 then high else blend(low, high, (level-1)*100 div (FLevels-1));
end;

// -- painting ----------------------

procedure THeatmapCalendar.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var text := pick(FTextColor, blend(clWindowText, back, 30));
  var outline := pick(FOutlineColor, blend(back, clWindowText, 18));
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  var radius := scaled(self, FCornerRadius);
  var first := getRange(0);
  var last := getRange(1);
  var d := first;
  var hot := Trunc(FHotDate);
  while d <= last do begin
    var r := cellRect(d);
    var value := GetValue(d);
    var level := levelOf(value);
    var fill := levelColor(level);
    if Trunc(d) = hot then fill := blend(fill, clWindowText, 25);
    var edge := if (level = 0) and FShowEmptyOutline then outline else clNone;
    if Trunc(d) = hot then edge := ColorToRGB(clWindowText);
    match FCellShape of
      hcSquare: paintRoundRect(sp, r, 0, fill, edge, 1);
      hcCircle: paintCircle(sp, (r.Left+r.Right) div 2, (r.Top+r.Bottom) div 2, r.Width div 2, fill, edge, 1);
    else
      paintRoundRect(sp, r, radius, fill, edge, 1);
    end;
    d += 1;
  end;
  // the legend: less to more
  var legendLeft := 0;
  if FShowLegend then begin
    var step := cellPx+gapPx;
    var x := gridLeft+((Trunc(last)-Trunc(firstColumnDate)) div 7+1)*step-(FLevels+1)*step;
    var y := gridTop+7*step+scaled(self, 4);
    legendLeft := x-textWidthOf(Font, 'Less')-scaled(self, 6);
    for var level := 0 to FLevels do begin
      paintRoundRect(sp, Rect(x, y, x+cellPx, y+cellPx), radius, levelColor(level), clNone);
      x += step;
    end;
  end;
  sp.Flush;
  if Assigned(FOnDrawCell) then begin
    d := first;
    while d <= last do begin
      var state: TDrawState := if Trunc(d) = hot then [dsHover] else [];
      if not Enabled then state += [dsDisabled];
      var handled := false;
      FOnDrawCell(self, Canvas, cellRect(d), Trunc(d)-Trunc(first), state, handled);
      d += 1;
    end;
  end;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := text;
  if FShowMonths then begin
    // a month label where its first week starts; crowded ones are skipped
    var lastRight := -MaxInt;
    d := first;
    while d <= last do begin
      if (DayOf(d) = 1) or (d = first) then begin
        var r := cellRect(d);
        var name := formatSettingsOf(FLanguage).ShortMonthNames[MonthOf(d)];
        if (r.Left > lastRight+scaled(self, 4)) and (r.Left+Canvas.TextWidth(name) <= ClientWidth) then begin
          Canvas.TextOut(r.Left, 0, name);
          lastRight := r.Left+Canvas.TextWidth(name);
        end;
      end;
      d += 1;
    end;
  end;
  if FShowWeekdays then begin
    var step := cellPx+gapPx;
    for var row := 0 to 6 do begin
      // every other row, Monday first: Mon, Wed, Fri
      if (row mod 2 = 1) or (row = 6) then continue;
      var name := if FMondayFirst then DAYS_MONDAY[row] else DAYS_SUNDAY[row];
      Canvas.TextOut(0, gridTop+row*step+(cellPx-lineHeightOf(Font)) div 2, name);
    end;
  end;
  if FShowLegend then begin
    var step := cellPx+gapPx;
    var y := gridTop+7*step+scaled(self, 4)+(cellPx-lineHeightOf(Font)) div 2;
    Canvas.TextOut(legendLeft, y, 'Less');
    var x := gridLeft+((Trunc(last)-Trunc(firstColumnDate)) div 7+1)*step+scaled(self, 2);
    Canvas.TextOut(x, y, 'More');
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure THeatmapCalendar.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var step := cellPx+gapPx;
  var columns := (Trunc(getRange(1))-Trunc(firstColumnDate)) div 7+1;
  PreferredWidth := gridLeft+columns*step+(if FShowLegend then textWidthOf(Font, 'More')+scaled(self, 4) else 0);
  PreferredHeight := gridTop+7*step;
  if FShowLegend then PreferredHeight += cellPx+scaled(self, 6);
end;

// -- input ----------------------

procedure THeatmapCalendar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var d := dateAt(X, Y);
  if Trunc(d) = Trunc(FHotDate) then exit;
  FHotDate := d;
  Invalidate;
  if Assigned(FOnCellHover) then FOnCellHover(self, d, GetValue(d));
end;

procedure THeatmapCalendar.CMHintShow(var Message: TLMessage);
begin
  var info := PHintInfo(Message.LParam);
  var d := dateAt(info^.CursorPos.X, info^.CursorPos.Y);
  if d = 0 then begin
    Message.Result := 1; // nothing under the mouse
    exit;
  end;
  var text := FormatDateTime('yyyy-mm-dd', d)+': '+FloatToStr(GetValue(d), formatSettingsOf(FLanguage));
  if Assigned(FOnHint) then FOnHint(self, d, GetValue(d), text);
  info^.HintStr := text;
  // the hint goes when the mouse leaves the cell, so the next cell gets its own
  info^.CursorRect := cellRect(d);
end;

procedure THeatmapCalendar.MouseLeave;
begin
  inherited MouseLeave;
  if FHotDate = 0 then exit;
  FHotDate := 0;
  Invalidate;
  if Assigned(FOnCellHover) then FOnCellHover(self, 0, 0);
end;

procedure THeatmapCalendar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var d := dateAt(X, Y);
  if (d <> 0) and Assigned(FOnCellClick) then FOnCellClick(self, d, GetValue(d));
end;

// -- properties ----------------------

procedure THeatmapCalendar.setRange(index: integer; value: TDateTime);
begin
  if index = 0 then FStartDate := Trunc(value) else FEndDate := Trunc(value);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function THeatmapCalendar.getMetric(index: integer): integer;
begin
  result := match index of
    0: FLevels;
    1: FCellSize;
    2: FCellGap;
  else
    FCornerRadius
  end;
end;

procedure THeatmapCalendar.setMetric(index: integer; value: integer);
begin
  if index = 0 then value := EnsureRange(value, 1, 12) else value := Max(value, 0);
  if getMetric(index) = value then exit;
  match index of
    0: FLevels := value;
    1: FCellSize := value;
    2: FCellGap := value;
  else
    FCornerRadius := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure THeatmapCalendar.setMaxValue(value: double);
begin
  FMaxValue := value;
  Invalidate;
end;

function THeatmapCalendar.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FAutoRange;
    1: FShowMonths;
    2: FShowWeekdays;
    3: FShowLegend;
    4: FMondayFirst;
  else
    FShowEmptyOutline
  end;
end;

procedure THeatmapCalendar.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FAutoRange := value;
    1: FShowMonths := value;
    2: FShowWeekdays := value;
    3: FShowLegend := value;
    4: FMondayFirst := value;
  else
    FShowEmptyOutline := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function THeatmapCalendar.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FEmptyColor;
    1: FLowColor;
    2: FHighColor;
    3: FTextColor;
  else
    FOutlineColor
  end;
end;

procedure THeatmapCalendar.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FEmptyColor := value;
    1: FLowColor := value;
    2: FHighColor := value;
    3: FTextColor := value;
  else
    FOutlineColor := value;
  end;
  Invalidate;
end;

procedure THeatmapCalendar.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure THeatmapCalendar.setCellShape(value: THeatmapCellShape);
begin
  if FCellShape = value then exit;
  FCellShape := value;
  Invalidate;
end;

procedure THeatmapCalendar.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
