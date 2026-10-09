{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SchedulerView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint;

type
  TSchedulerView = class;
  TSchedulerEvent = class;
  TSchedulerMode = (smDay, smWeek, smMonth);
  TSchedulerEventEvent = procedure(Sender: TObject; event: TSchedulerEvent) of object;
  // an event was dragged or stretched; the times are already set
  TSchedulerChangeEvent = procedure(Sender: TObject; event: TSchedulerEvent; oldStart, oldFinish: TDateTime) of object;
  // a click on an empty slot
  TSchedulerSlotEvent = procedure(Sender: TObject; time: TDateTime) of object;

  { TSchedulerEvent }

  TSchedulerEvent = class(TCollectionItem)
  private
    FCaption, FText: string;
    FStart, FFinish: TDateTime;
    FColor: TColor;
    FAllDay: boolean;
    FTag: PtrInt;
    FRect: TRect; // where it was painted last, in view coordinates
    procedure setCaption(const value: string);
    procedure setText(const value: string);
    procedure setTime(index: integer; value: TDateTime);
    function getTime(index: integer): TDateTime;
    procedure setColor(value: TColor);
    procedure setAllDay(value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    function Minutes: integer;
  published
    property Caption: string read FCaption write setCaption;
    property Text: string read FText write setText;
    property Start: TDateTime index 0 read getTime write setTime;
    property Finish: TDateTime index 1 read getTime write setTime;
    // clDefault takes a color from the palette
    property Color: TColor read FColor write setColor default clDefault;
    // in the band above the hours instead of the grid
    property AllDay: boolean read FAllDay write setAllDay default false;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TSchedulerEvents }

  TSchedulerEvents = class(TOwnedCollection)
  private
    function getItem(index: integer): TSchedulerEvent;
    procedure setItem(index: integer; value: TSchedulerEvent);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TSchedulerEvent;
    property Items[index: integer]: TSchedulerEvent read getItem write setItem; default;
  end;

  { TSchedulerView }

  // a day, a week or a month of events: in the day and week views the hours
  // run down and the events are blocks that move and stretch with the
  // mouse, events that overlap share the column; the month view lists
  // them per day. Previous and Next page through the time
  TSchedulerView = class(TScrollingWinControl)
  private
    FEvents: TSchedulerEvents;
    FMode: TSchedulerMode;
    FDate: TDateTime; // the day shown, or a day of the week or the month
    FFirstHour, FLastHour, FHourHeight, FHeaderHeight, FTimeWidth, FSnapMinutes, FCornerRadius, FPadding: integer;
    FMondayFirst, FShowNow, FShowAllDay, FAllowDrag, FAllowResize, FShowWeekends, FShowGrid: boolean;
    FBackColor, FGridColor, FTextColor, FHeaderColor, FNowColor, FTodayColor, FEventColor, FWeekendColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FHot, FSelected, FDrag: TSchedulerEvent;
    FDragPart: integer; // 0 move, 1 start, 2 finish
    FDragY, FDragX: integer;
    FDragStart, FDragFinish: TDateTime;
    FOnEventClick, FOnEventDblClick, FOnSelect: TSchedulerEventEvent;
    FOnEventChange: TSchedulerChangeEvent;
    FOnSlotClick, FOnSlotDblClick: TSchedulerSlotEvent;
    FOnDateChange: TNotifyEvent;
    procedure setEvents(value: TSchedulerEvents);
    procedure setMode(value: TSchedulerMode);
    procedure setDate(value: TDateTime);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    procedure setSelected(value: TSchedulerEvent);
    function dayCount: integer;
    function firstDay: TDateTime;
    function headerPx: integer;
    function allDayPx: integer;
    function hourPx: integer;
    function timePx: integer;
    function columnRect(day: integer): TRect;
    function yOfTime(t: TDateTime): integer;
    function timeAt(x, y: integer; out day: integer): TDateTime;
    function eventAt(x, y: integer; out part: integer): TSchedulerEvent;
    function toneOf(e: TSchedulerEvent): TColor;
    procedure updateRange;
    procedure layoutDay(day: TDateTime; const column: TRect);
    procedure paintMonth(sp: TSmoothPaint; const view: TRect);
  protected
    procedure Paint; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddEvent(const caption: string; start, finish: TDateTime; color: TColor = clDefault): TSchedulerEvent;
    procedure Next;
    procedure Previous;
    procedure Today;
    // the events of a day, in order
    procedure EventsOn(day: TDateTime; list: TList);
    // the view scrolled so an hour shows at the top
    procedure ScrollToHour(hour: integer);
    // the title of the view, like a week or a month name
    function Title: string;
    property Selected: TSchedulerEvent read FSelected write setSelected;
  published
    property Events: TSchedulerEvents read FEvents write setEvents;
    property Mode: TSchedulerMode read FMode write setMode default smWeek;
    // the day shown, or one of the week or the month
    property Date: TDateTime read FDate write setDate;
    property FirstHour: integer index 0 read getMetric write setMetric default 0;
    property LastHour: integer index 1 read getMetric write setMetric default 24;
    property HourHeight: integer index 2 read getMetric write setMetric default 48;
    // 0 takes it from the font
    property HeaderHeight: integer index 3 read getMetric write setMetric default 0;
    property TimeWidth: integer index 4 read getMetric write setMetric default 48;
    // a drag lands on this many minutes
    property SnapMinutes: integer index 5 read getMetric write setMetric default 15;
    property CornerRadius: integer index 6 read getMetric write setMetric default 4;
    property Padding: integer index 7 read getMetric write setMetric default 2;
    property MondayFirst: boolean index 0 read getFlag write setFlag default true;
    // the line of the current time
    property ShowNow: boolean index 1 read getFlag write setFlag default true;
    property ShowAllDay: boolean index 2 read getFlag write setFlag default true;
    property AllowDrag: boolean index 3 read getFlag write setFlag default true;
    property AllowResize: boolean index 4 read getFlag write setFlag default true;
    property ShowWeekends: boolean index 5 read getFlag write setFlag default true;
    property ShowGrid: boolean index 6 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property BackColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property HeaderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property NowColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property TodayColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property EventColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property WeekendColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnEventClick: TSchedulerEventEvent read FOnEventClick write FOnEventClick;
    property OnEventDblClick: TSchedulerEventEvent read FOnEventDblClick write FOnEventDblClick;
    property OnSelect: TSchedulerEventEvent read FOnSelect write FOnSelect;
    property OnEventChange: TSchedulerChangeEvent read FOnEventChange write FOnEventChange;
    property OnSlotClick: TSchedulerSlotEvent read FOnSlotClick write FOnSlotClick;
    // a double click on an empty slot, the place to add an event
    property OnSlotDblClick: TSchedulerSlotEvent read FOnSlotDblClick write FOnSlotDblClick;
    property OnDateChange: TNotifyEvent read FOnDateChange write FOnDateChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsSingle;
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
  Math, DateUtils;

const
  PALETTE: array[0..5] of TColor = ($D98B3B, $5CB85C, $F0AD4E, $B35CA0, $17A2B8, $D9534F);

{ TSchedulerEvent }

constructor TSchedulerEvent.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clDefault;
  FStart := Trunc(Now)+EncodeTime(9, 0, 0, 0);
  FFinish := FStart+EncodeTime(1, 0, 0, 0);
end;

procedure TSchedulerEvent.Assign(Source: TPersistent);
begin
  if Source is TSchedulerEvent then begin
    var s := TSchedulerEvent(Source);
    FCaption := s.FCaption;
    FText := s.FText;
    FStart := s.FStart;
    FFinish := s.FFinish;
    FColor := s.FColor;
    FAllDay := s.FAllDay;
    FTag := s.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TSchedulerEvent.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

function TSchedulerEvent.Minutes: integer;
begin
  result := Max(MinutesBetween(FFinish, FStart), 0);
end;

procedure TSchedulerEvent.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TSchedulerEvent.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  Changed(false);
end;

function TSchedulerEvent.getTime(index: integer): TDateTime;
begin
  result := if index = 0 then FStart else FFinish;
end;

procedure TSchedulerEvent.setTime(index: integer; value: TDateTime);
begin
  if index = 0 then begin
    FStart := value;
    if FFinish < FStart then FFinish := FStart;
  end else begin
    FFinish := value;
    if FStart > FFinish then FStart := FFinish;
  end;
  Changed(false);
end;

procedure TSchedulerEvent.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TSchedulerEvent.setAllDay(value: boolean);
begin
  if FAllDay = value then exit;
  FAllDay := value;
  Changed(false);
end;

{ TSchedulerEvents }

function TSchedulerEvents.getItem(index: integer): TSchedulerEvent;
begin
  result := TSchedulerEvent(inherited Items[index]);
end;

procedure TSchedulerEvents.setItem(index: integer; value: TSchedulerEvent);
begin
  inherited Items[index] := value;
end;

function TSchedulerEvents.Add: TSchedulerEvent;
begin
  result := TSchedulerEvent(inherited Add);
end;

procedure TSchedulerEvents.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TSchedulerView then TSchedulerView(Owner).Invalidate;
end;

{ TSchedulerView }

constructor TSchedulerView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FEvents := TSchedulerEvents.Create(self, TSchedulerEvent);
  FMode := smWeek;
  FDate := Trunc(Now);
  FLastHour := 24;
  FHourHeight := 48;
  FTimeWidth := 48;
  FSnapMinutes := 15;
  FCornerRadius := 4;
  FPadding := 2;
  FMondayFirst := true;
  FShowNow := true;
  FShowAllDay := true;
  FAllowDrag := true;
  FAllowResize := true;
  FShowWeekends := true;
  FShowGrid := true;
  FBackColor := clDefault;
  FGridColor := clDefault;
  FTextColor := clDefault;
  FHeaderColor := clDefault;
  FNowColor := clDefault;
  FTodayColor := clDefault;
  FEventColor := clDefault;
  FWeekendColor := clDefault;
  FAntialiasing := asTheme;
  Color := clWindow;
  BorderStyle := bsSingle;
  TabStop := true;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Visible := false;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TSchedulerView.Destroy;
begin
  FEvents.Free;
  inherited Destroy;
end;

class function TSchedulerView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 600;
  result.cy := 320;
end;

function TSchedulerView.AddEvent(const caption: string; start, finish: TDateTime; color: TColor): TSchedulerEvent;
begin
  result := FEvents.Add;
  result.Caption := caption;
  result.Start := start;
  result.Finish := finish;
  result.Color := color;
end;

// -- time ----------------------

function TSchedulerView.dayCount: integer;
begin
  result := match FMode of
    smDay: 1;
    smWeek: (if FShowWeekends then 7 else 5);
  else
    7
  end;
end;

function TSchedulerView.firstDay: TDateTime;
begin
  var d := Trunc(FDate);
  match FMode of
    smDay: result := d;
    smWeek: begin
      var dow := DayOfWeek(d);
      var offset := if FMondayFirst then (dow+5) mod 7 else dow-1;
      result := d-offset;
    end;
  else
    begin
      var first := EncodeDate(YearOf(d), MonthOf(d), 1);
      var dow := DayOfWeek(first);
      var offset := if FMondayFirst then (dow+5) mod 7 else dow-1;
      result := first-offset;
    end;
  end;
end;

procedure TSchedulerView.Next;
begin
  Date := match FMode of
    smDay: FDate+1;
    smWeek: FDate+7;
  else
    IncMonth(FDate, 1)
  end;
end;

procedure TSchedulerView.Previous;
begin
  Date := match FMode of
    smDay: FDate-1;
    smWeek: FDate-7;
  else
    IncMonth(FDate, -1)
  end;
end;

procedure TSchedulerView.Today;
begin
  Date := Trunc(Now);
end;

function TSchedulerView.Title: string;
begin
  var first := firstDay;
  result := match FMode of
    smDay: FormatDateTime('dddd, yyyy-mm-dd', FDate, formatSettingsOf(FLanguage));
    smWeek: FormatDateTime('yyyy-mm-dd', first)+' to '+FormatDateTime('yyyy-mm-dd', first+dayCount-1);
  else
    formatSettingsOf(FLanguage).LongMonthNames[MonthOf(FDate)]+' '+IntToStr(YearOf(FDate))
  end;
end;

procedure TSchedulerView.EventsOn(day: TDateTime; list: TList);
begin
  day := Trunc(day);
  for var i := 0 to FEvents.Count-1 do begin
    var e := FEvents[i];
    if (Trunc(e.Start) <= day) and (Trunc(e.Finish) >= day) then list.Add(e);
  end;
end;

// -- geometry ----------------------

function TSchedulerView.headerPx: integer;
begin
  result := if FHeaderHeight > 0 then scaled(self, FHeaderHeight) else lineHeightOf(Font)+scaled(self, 10);
end;

function TSchedulerView.allDayPx: integer;
begin
  result := if FShowAllDay and (FMode <> smMonth) then lineHeightOf(Font)+scaled(self, 8) else 0;
end;

function TSchedulerView.hourPx: integer;
begin
  result := Max(scaled(self, FHourHeight), 12);
end;

function TSchedulerView.timePx: integer;
begin
  result := if FMode = smMonth then 0 else scaled(self, FTimeWidth);
end;

function TSchedulerView.columnRect(day: integer): TRect;
begin
  var left := timePx;
  var w := (ClientWidth-left)/Max(dayCount, 1);
  result := Rect(left+Round(day*w), headerPx+allDayPx, left+Round((day+1)*w), headerPx+allDayPx+(FLastHour-FFirstHour)*hourPx);
end;

function TSchedulerView.yOfTime(t: TDateTime): integer;
begin
  var minutes := HourOf(t)*60+MinuteOf(t);
  result := headerPx+allDayPx+Round((minutes-FFirstHour*60)*hourPx/60);
end;

function TSchedulerView.timeAt(x, y: integer; out day: integer): TDateTime;
begin
  var left := timePx;
  var w := (ClientWidth-left)/Max(dayCount, 1);
  day := EnsureRange(Floor((x-left)/w), 0, dayCount-1);
  var ly := y+VertScrollBar.Position-headerPx-allDayPx;
  var minutes := FFirstHour*60+ly*60/hourPx;
  minutes := Round(minutes/Max(FSnapMinutes, 1))*Max(FSnapMinutes, 1);
  minutes := EnsureRange(Round(minutes), FFirstHour*60, FLastHour*60);
  result := firstDay+day+minutes/(24*60);
end;

function TSchedulerView.eventAt(x, y: integer; out part: integer): TSchedulerEvent;
begin
  part := 0;
  result := nil;
  var p := Point(x, y+VertScrollBar.Position);
  var grip := scaled(self, 5);
  for var i := FEvents.Count-1 downto 0 do begin
    var e := FEvents[i];
    if e.FRect.IsEmpty or not PtInRect(e.FRect, p) then continue;
    result := e;
    if (FMode <> smMonth) and not e.AllDay then begin
      if p.Y <= e.FRect.Top+grip then part := 1
      else if p.Y >= e.FRect.Bottom-grip then part := 2;
    end;
    exit;
  end;
end;

function TSchedulerView.toneOf(e: TSchedulerEvent): TColor;
begin
  result := e.Color;
  if result = clDefault then result := pick(FEventColor, PALETTE[e.Index mod length(PALETTE)]);
  result := ColorToRGB(result);
end;

procedure TSchedulerView.updateRange;
begin
  if not HandleAllocated then exit;
  VertScrollBar.Increment := hourPx div 2;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := if FMode = smMonth then 0 else headerPx+allDayPx+(FLastHour-FFirstHour)*hourPx+scaled(self, 4);
end;

procedure TSchedulerView.ScrollToHour(hour: integer);
begin
  VertScrollBar.Position := Max((hour-FFirstHour)*hourPx, 0);
end;

procedure TSchedulerView.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TSchedulerView.Resize;
begin
  inherited Resize;
  updateRange;
  Invalidate;
end;

procedure TSchedulerView.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

// -- painting ----------------------

// the events of one day placed in its column: overlapping ones share
// the width, each in a lane of its own
procedure TSchedulerView.layoutDay(day: TDateTime; const column: TRect);
begin
  var list := autofree TList.Create;
  for var i := 0 to FEvents.Count-1 do begin
    var e := FEvents[i];
    if e.AllDay or (Trunc(e.Start) > day) or (Trunc(e.Finish) < day) then continue;
    if (Trunc(e.Finish) = day) and (Trunc(e.Start) < day) and (e.Finish = Trunc(e.Finish)) then continue;
    list.Add(e);
  end;
  // sorted by start, then the lanes: an event takes the first lane free at its start
  for var i := 1 to list.Count-1 do begin
    var k := i;
    while (k > 0) and (TSchedulerEvent(list[k-1]).Start > TSchedulerEvent(list[k]).Start) do begin
      list.Exchange(k-1, k);
      dec(k);
    end;
  end;
  var lanes: array of TDateTime := []; // the finish of the last event in each lane
  var laneOf: array of integer;
  SetLength(laneOf, list.Count);
  var groupStart := 0;
  var groupLanes := 0;
  var pad := scaled(self, FPadding);
  var place := procedure(fromIndex, toIndex, laneCount: integer)
  begin
    for var k := fromIndex to toIndex do begin
      var e := TSchedulerEvent(list[k]);
      var w := (column.Width-2*pad)/Max(laneCount, 1);
      var startDay := Max(e.Start, day);
      var finishDay := Min(e.Finish, day+1);
      var top := yOfTime(startDay);
      var bottom := if finishDay >= day+1 then yOfTime(day+1-1/1440)+hourPx div 60 else yOfTime(finishDay);
      if bottom-top < scaled(self, 14) then bottom := top+scaled(self, 14);
      e.FRect := Rect(column.Left+pad+Round(laneOf[k]*w), top, column.Left+pad+Round((laneOf[k]+1)*w)-pad, bottom);
    end;
  end;
  for var i := 0 to list.Count-1 do begin
    var e := TSchedulerEvent(list[i]);
    // a gap from every lane closes the group: the lanes so far share the width
    var free := true;
    for var l := 0 to high(lanes) do if lanes[l] > e.Start then free := false;
    if free and (i > groupStart) then begin
      place(groupStart, i-1, groupLanes);
      lanes := [];
      groupStart := i;
      groupLanes := 0;
    end;
    var lane := -1;
    for var l := 0 to high(lanes) do if lanes[l] <= e.Start then begin lane := l; break; end;
    if lane < 0 then begin
      lanes := lanes+[e.Finish];
      lane := high(lanes);
    end else lanes[lane] := e.Finish;
    laneOf[i] := lane;
    groupLanes := Max(groupLanes, length(lanes));
  end;
  if list.Count > 0 then place(groupStart, list.Count-1, groupLanes);
end;

procedure TSchedulerView.paintMonth(sp: TSmoothPaint; const view: TRect);
begin
  var back := pick(FBackColor, Color);
  var grid := pick(FGridColor, blend(back, clWindowText, 12));
  var header := pick(FHeaderColor, blend(back, clWindowText, 6));
  var todayColor := pick(FTodayColor, blend(back, clHighlight, 12));
  var weekend := pick(FWeekendColor, blend(back, clWindowText, 4));
  var hh := headerPx;
  var first := firstDay;
  var rows := 6;
  var cellW := ClientWidth/7;
  var cellH := (ClientHeight-hh)/rows;
  sp.FillRect(Rect(0, 0, ClientWidth, hh), header);
  for var i := 0 to FEvents.Count-1 do FEvents[i].FRect := Rect(0, 0, 0, 0);
  for var row := 0 to rows-1 do
    for var col := 0 to 6 do begin
      var d := first+row*7+col;
      var r := Rect(Round(col*cellW), hh+Round(row*cellH), Round((col+1)*cellW), hh+Round((row+1)*cellH));
      if MonthOf(d) <> MonthOf(FDate) then sp.FillRect(r, blend(back, clWindowText, 3))
      else if DayOfWeek(d) in [1, 7] then sp.FillRect(r, weekend);
      if Trunc(d) = Trunc(Now) then sp.FillRect(r, todayColor);
      if FShowGrid then begin
        sp.FillRect(Rect(r.Left, r.Top, r.Right, r.Top+1), grid);
        sp.FillRect(Rect(r.Left, r.Top, r.Left+1, r.Bottom), grid);
      end;
      // the events of the day as small bars under the number
      var list := autofree TList.Create;
      EventsOn(d, list);
      var y := r.Top+lineHeightOf(Font)+scaled(self, 4);
      var barH := lineHeightOf(Font)+scaled(self, 2);
      for var k := 0 to list.Count-1 do begin
        if y+barH > r.Bottom-2 then break;
        var e := TSchedulerEvent(list[k]);
        var er := Rect(r.Left+scaled(self, 3), y, r.Right-scaled(self, 3), y+barH);
        var c := toneOf(e);
        paintRoundRect(sp, er, scaled(self, 2), (if e = FSelected then c else blend(c, back, 30)), (if e = FSelected then ColorToRGB(clWindowText) else clNone));
        // the first day the event shows keeps its rectangle for hits; the rest get one too
        if e.FRect.IsEmpty then e.FRect := er;
        y += barH+scaled(self, 2);
      end;
    end;
end;

procedure TSchedulerView.Paint;
begin
  var back := pick(FBackColor, Color);
  var grid := pick(FGridColor, blend(back, clWindowText, 12));
  var text := pick(FTextColor, clWindowText);
  var header := pick(FHeaderColor, blend(back, clWindowText, 6));
  var nowColor := pick(FNowColor, $4F53D9);
  var todayColor := pick(FTodayColor, blend(back, clHighlight, 12));
  var weekend := pick(FWeekendColor, blend(back, clWindowText, 4));
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var lh := lineHeightOf(Font);
  if FMode = smMonth then begin
    paintMonth(sp, view);
    sp.Flush;
    applyTextQuality(Canvas);
    Canvas.Brush.Style := bsClear;
    var hh := headerPx;
    var first := firstDay;
    var cellW := ClientWidth/7;
    var cellH := (ClientHeight-hh)/6;
    Canvas.Font.Color := text;
    for var col := 0 to 6 do begin
      var name := formatSettingsOf(FLanguage).ShortDayNames[DayOfWeek(first+col)];
      Canvas.TextOut(Round(col*cellW)+scaled(self, 4), (hh-lh) div 2, name);
    end;
    for var row := 0 to 5 do
      for var col := 0 to 6 do begin
        var d := first+row*7+col;
        var r := Rect(Round(col*cellW), hh+Round(row*cellH), Round((col+1)*cellW), hh+Round((row+1)*cellH));
        Canvas.Font.Style := if Trunc(d) = Trunc(Now) then Font.Style+[fsBold] else Font.Style;
        Canvas.Font.Color := if MonthOf(d) <> MonthOf(FDate) then blend(text, back, 55) else text;
        Canvas.TextOut(r.Left+scaled(self, 4), r.Top+scaled(self, 2), IntToStr(DayOf(d)));
        var list := autofree TList.Create;
        EventsOn(d, list);
        var y := r.Top+lh+scaled(self, 4);
        var barH := lh+scaled(self, 2);
        Canvas.Font.Style := Font.Style;
        Canvas.Clipping := true;
        Canvas.ClipRect := Rect(r.Left, r.Top, r.Right-scaled(self, 3), r.Bottom);
        for var k := 0 to list.Count-1 do begin
          if y+barH > r.Bottom-2 then begin
            Canvas.Font.Color := blend(text, back, 40);
            Canvas.TextOut(r.Left+scaled(self, 4), y, Format('+%d more', [list.Count-k]));
            break;
          end;
          var e := TSchedulerEvent(list[k]);
          Canvas.Font.Color := if e = FSelected then contrastText(toneOf(e)) else text;
          Canvas.TextOut(r.Left+scaled(self, 6), y+1, (if e.AllDay then e.Caption else FormatDateTime('hh:nn', e.Start)+' '+e.Caption));
          y += barH+scaled(self, 2);
        end;
        Canvas.Clipping := false;
      end;
    Canvas.Brush.Style := bsSolid;
    exit;
  end;

  var hh := headerPx;
  var ad := allDayPx;
  var hp := hourPx;
  var tw := timePx;
  var first := firstDay;
  var dayN := dayCount;
  var gridTop := hh+ad;
  var gridBottom := gridTop+(FLastHour-FFirstHour)*hp;
  // the columns of the dayN
  for var day := 0 to dayN-1 do begin
    var col := columnRect(day);
    var d := first+day;
    if DayOfWeek(d) in [1, 7] then sp.FillRect(Rect(col.Left, gridTop, col.Right, gridBottom), weekend);
    if Trunc(d) = Trunc(Now) then sp.FillRect(Rect(col.Left, gridTop, col.Right, gridBottom), todayColor);
    if FShowGrid then sp.FillRect(Rect(col.Left, gridTop, col.Left+1, gridBottom), grid);
  end;
  // the hour lines
  if FShowGrid then
    for var h := FFirstHour to FLastHour do begin
      var y := gridTop+(h-FFirstHour)*hp;
      sp.FillRect(Rect(tw, y, ClientWidth, y+1), grid);
      if hp >= 36 then sp.FillRect(Rect(tw, y+hp div 2, ClientWidth, y+hp div 2+1), blend(grid, back, 50));
    end;
  // the events
  for var i := 0 to FEvents.Count-1 do FEvents[i].FRect := Rect(0, 0, 0, 0);
  for var day := 0 to dayN-1 do layoutDay(first+day, columnRect(day));
  for var i := 0 to FEvents.Count-1 do begin
    var e := FEvents[i];
    if e.AllDay or e.FRect.IsEmpty then continue;
    var c := toneOf(e);
    var fill := blend(c, back, (if e = FSelected then 0 else 25));
    if (e = FHot) and hoverEnabled and (e <> FSelected) then fill := blend(c, back, 10);
    paintRoundRect(sp, e.FRect, scaled(self, FCornerRadius), fill, (if e = FSelected then ColorToRGB(clWindowText) else blend(c, clWindowText, 20)), (if e = FSelected then 2 else 1));
    sp.FillRoundRect(e.FRect.Left+2, e.FRect.Top+3, e.FRect.Left+5, e.FRect.Bottom-3, 1.5, blend(c, clWindowText, 35));
  end;
  // the band of all day events and the header stay on top
  sp.FillRect(Rect(view.Left, view.Top, view.Right, view.Top+hh+ad), header);
  sp.FillRect(Rect(view.Left, view.Top+hh+ad-1, view.Right, view.Top+hh+ad), grid);
  if ad > 0 then begin
    sp.FillRect(Rect(view.Left, view.Top+hh-1, view.Right, view.Top+hh), grid);
    for var day := 0 to dayN-1 do begin
      var col := columnRect(day);
      var d := first+day;
      var x := col.Left+scaled(self, 2);
      for var i := 0 to FEvents.Count-1 do begin
        var e := FEvents[i];
        if not e.AllDay or (Trunc(e.Start) > d) or (Trunc(e.Finish) < d) then continue;
        var w := Min(col.Width-scaled(self, 4), textWidthOf(Font, e.Caption)+scaled(self, 10));
        if x+w > col.Right then w := col.Right-x-scaled(self, 2);
        if w < scaled(self, 8) then break;
        var c := toneOf(e);
        e.FRect := Rect(x, view.Top+hh+scaled(self, 2), x+w, view.Top+hh+ad-scaled(self, 2));
        paintRoundRect(sp, e.FRect, scaled(self, 3), (if e = FSelected then c else blend(c, back, 25)), (if e = FSelected then ColorToRGB(clWindowText) else clNone));
        x += w+scaled(self, 3);
      end;
    end;
  end;
  // the time column stays on the left
  sp.FillRect(Rect(view.Left, view.Top+hh+ad, view.Left+tw, view.Bottom), back);
  sp.FillRect(Rect(view.Left+tw-1, view.Top+hh+ad, view.Left+tw, view.Bottom), grid);
  // now
  if FShowNow then
    for var day := 0 to dayN-1 do
      if Trunc(first+day) = Trunc(Now) then begin
        var col := columnRect(day);
        var y := yOfTime(Now);
        if (y >= gridTop) and (y <= gridBottom) then begin
          sp.FillRect(Rect(col.Left, y, col.Right, y+scaled(self, 2)), nowColor);
          paintCircle(sp, col.Left+scaled(self, 3), y+1, scaled(self, 4), nowColor, clNone);
        end;
      end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Clipping := true;
  // the day names in the header
  Canvas.ClipRect := Rect(view.Left+tw, view.Top, view.Right, view.Top+hh);
  for var day := 0 to dayN-1 do begin
    var col := columnRect(day);
    var d := first+day;
    Canvas.Font.Style := if Trunc(d) = Trunc(Now) then Font.Style+[fsBold] else Font.Style;
    Canvas.Font.Color := text;
    var s: string;
    var fs := formatSettingsOf(FLanguage);
    if dayN = 1 then s := FormatDateTime('dddd, yyyy-mm-dd', d, fs) else s := fs.ShortDayNames[DayOfWeek(d)]+' '+IntToStr(DayOf(d));
    Canvas.TextOut(col.Left+(col.Width-Canvas.TextWidth(s)) div 2, view.Top+(hh-lh) div 2, s);
  end;
  Canvas.Font.Style := Font.Style;
  // the hours
  Canvas.ClipRect := Rect(view.Left, view.Top+hh+ad, view.Left+tw, view.Bottom);
  Canvas.Font.Color := blend(text, back, 35);
  for var h := FFirstHour to FLastHour-1 do begin
    var y := gridTop+(h-FFirstHour)*hp;
    var s := Format('%.2d:00', [h]);
    Canvas.TextOut(view.Left+tw-Canvas.TextWidth(s)-scaled(self, 4), y+scaled(self, 2), s);
  end;
  // the captions in the events
  for var i := 0 to FEvents.Count-1 do begin
    var e := FEvents[i];
    if e.FRect.IsEmpty then continue;
    var c := toneOf(e);
    Canvas.ClipRect := Rect(e.FRect.Left+1, e.FRect.Top+1, e.FRect.Right-1, e.FRect.Bottom-1);
    Canvas.Font.Color := if e = FSelected then contrastText(c) else text;
    Canvas.Font.Style := Font.Style+[fsBold];
    var x := e.FRect.Left+scaled(self, 8);
    Canvas.TextOut(x, e.FRect.Top+scaled(self, 2), e.Caption);
    Canvas.Font.Style := Font.Style;
    if not e.AllDay and (e.FRect.Height > lh*2+scaled(self, 4)) then begin
      Canvas.Font.Color := blend((if e = FSelected then contrastText(c) else text), c, 25);
      Canvas.TextOut(x, e.FRect.Top+scaled(self, 2)+lh, FormatDateTime('hh:nn', e.Start)+' - '+FormatDateTime('hh:nn', e.Finish));
      if (e.Text <> '') and (e.FRect.Height > lh*3+scaled(self, 4)) then Canvas.TextOut(x, e.FRect.Top+scaled(self, 2)+lh*2, e.Text);
    end;
  end;
  Canvas.Clipping := false;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TSchedulerView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  var part: integer;
  var e := eventAt(X, Y, part);
  if e <> nil then begin
    Selected := e;
    if Assigned(FOnEventClick) then FOnEventClick(self, e);
    if (FMode = smMonth) or e.AllDay then exit;
    if (part = 0) and not FAllowDrag then exit;
    if (part > 0) and not FAllowResize then exit;
    FDrag := e;
    FDragPart := part;
    FDragY := Y;
    FDragX := X;
    FDragStart := e.Start;
    FDragFinish := e.Finish;
    exit;
  end;
  if FSelected <> nil then Selected := nil;
  if (FMode <> smMonth) and (Y+VertScrollBar.Position >= headerPx+allDayPx) and Assigned(FOnSlotClick) then begin
    var day: integer;
    FOnSlotClick(self, timeAt(X, Y, day));
  end;
end;

procedure TSchedulerView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDrag <> nil then begin
    var snap := Max(FSnapMinutes, 1);
    var minutes := Round((Y-FDragY)*60/hourPx/snap)*snap;
    var dayShift := 0;
    if FMode = smWeek then begin
      var w := (ClientWidth-timePx)/Max(dayCount, 1);
      dayShift := Round((X-FDragX)/w);
    end;
    var delta := minutes/1440+dayShift;
    match FDragPart of
      1: FDrag.Start := Min(FDragStart+minutes/1440, FDragFinish-snap/1440);
      2: FDrag.Finish := Max(FDragFinish+minutes/1440, FDragStart+snap/1440);
    else
      begin
        FDrag.FStart := FDragStart+delta;
        FDrag.FFinish := FDragFinish+delta;
        Invalidate;
      end;
    end;
    exit;
  end;
  var part: integer;
  var hot := eventAt(X, Y, part);
  Cursor := if hot = nil then crDefault else if part > 0 then crSizeNS else crHandPoint;
  if hot = FHot then exit;
  FHot := hot;
  Invalidate;
end;

procedure TSchedulerView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FDrag = nil then exit;
  var e := FDrag;
  FDrag := nil;
  if (e.Start <> FDragStart) or (e.Finish <> FDragFinish) then begin
    Invalidate;
    if Assigned(FOnEventChange) then FOnEventChange(self, e, FDragStart, FDragFinish);
  end;
end;

procedure TSchedulerView.MouseLeave;
begin
  inherited MouseLeave;
  if FHot = nil then exit;
  FHot := nil;
  Invalidate;
end;

procedure TSchedulerView.DblClick;
begin
  inherited DblClick;
  var p := ScreenToClient(Mouse.CursorPos);
  var part: integer;
  var e := eventAt(p.X, p.Y, part);
  if e <> nil then begin
    if Assigned(FOnEventDblClick) then FOnEventDblClick(self, e);
    exit;
  end;
  if (FMode <> smMonth) and Assigned(FOnSlotDblClick) then begin
    var day: integer;
    FOnSlotDblClick(self, timeAt(p.X, p.Y, day));
  end;
end;

procedure TSchedulerView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_LEFT: Previous;
    VK_RIGHT: Next;
    VK_HOME: Today;
    VK_PRIOR: ScrollToHour(FFirstHour);
    VK_NEXT: ScrollToHour(FLastHour);
    VK_ESCAPE: Selected := nil;
  else
    exit;
  end;
  Key := 0;
end;

// -- properties ----------------------

procedure TSchedulerView.setEvents(value: TSchedulerEvents);
begin
  FEvents.Assign(value);
  Invalidate;
end;

procedure TSchedulerView.setSelected(value: TSchedulerEvent);
begin
  if FSelected = value then exit;
  FSelected := value;
  Invalidate;
  if Assigned(FOnSelect) then FOnSelect(self, value);
end;

procedure TSchedulerView.setMode(value: TSchedulerMode);
begin
  if FMode = value then exit;
  FMode := value;
  updateRange;
  Invalidate;
  if Assigned(FOnDateChange) then FOnDateChange(self);
end;

procedure TSchedulerView.setDate(value: TDateTime);
begin
  value := Trunc(value);
  if FDate = value then exit;
  FDate := value;
  Invalidate;
  if Assigned(FOnDateChange) then FOnDateChange(self);
end;

function TSchedulerView.getMetric(index: integer): integer;
begin
  result := match index of
    0: FFirstHour;
    1: FLastHour;
    2: FHourHeight;
    3: FHeaderHeight;
    4: FTimeWidth;
    5: FSnapMinutes;
    6: FCornerRadius;
  else
    FPadding
  end;
end;

procedure TSchedulerView.setMetric(index: integer; value: integer);
begin
  match index of
    0: value := EnsureRange(value, 0, 23);
    1: value := EnsureRange(value, 1, 24);
    5: value := EnsureRange(value, 1, 60);
  else
    value := Max(value, 0);
  end;
  if getMetric(index) = value then exit;
  match index of
    0: begin FFirstHour := value; if FLastHour <= FFirstHour then FLastHour := FFirstHour+1; end;
    1: begin FLastHour := value; if FFirstHour >= FLastHour then FFirstHour := FLastHour-1; end;
    2: FHourHeight := value;
    3: FHeaderHeight := value;
    4: FTimeWidth := value;
    5: FSnapMinutes := value;
    6: FCornerRadius := value;
  else
    FPadding := value;
  end;
  updateRange;
  Invalidate;
end;

function TSchedulerView.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FMondayFirst;
    1: FShowNow;
    2: FShowAllDay;
    3: FAllowDrag;
    4: FAllowResize;
    5: FShowWeekends;
  else
    FShowGrid
  end;
end;

procedure TSchedulerView.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FMondayFirst := value;
    1: FShowNow := value;
    2: FShowAllDay := value;
    3: FAllowDrag := value;
    4: FAllowResize := value;
    5: FShowWeekends := value;
  else
    FShowGrid := value;
  end;
  updateRange;
  Invalidate;
end;

function TSchedulerView.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBackColor;
    1: FGridColor;
    2: FTextColor;
    3: FHeaderColor;
    4: FNowColor;
    5: FTodayColor;
    6: FEventColor;
  else
    FWeekendColor
  end;
end;

procedure TSchedulerView.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBackColor := value;
    1: FGridColor := value;
    2: FTextColor := value;
    3: FHeaderColor := value;
    4: FNowColor := value;
    5: FTodayColor := value;
    6: FEventColor := value;
  else
    FWeekendColor := value;
  end;
  Invalidate;
end;

procedure TSchedulerView.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TSchedulerView.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
