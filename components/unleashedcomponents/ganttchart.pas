{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit GanttChart;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint;

type
  TGanttChart = class;
  TGanttTask = class;
  TGanttScale = (gsDays, gsWeeks, gsMonths);
  TGanttTaskEvent = procedure(Sender: TObject; task: TGanttTask) of object;
  // a bar was dragged or stretched; the dates are already set
  TGanttChangeEvent = procedure(Sender: TObject; task: TGanttTask; oldStart, oldFinish: TDateTime) of object;

  { TGanttTask }

  TGanttTask = class(TCollectionItem)
  private
    FCaption: string;
    FStart, FFinish: TDateTime;
    FProgress: integer; // percent
    FColor: TColor;
    FDependsOn: integer; // the index of the task that must end first, -1 none
    FMilestone, FCollapsed: boolean;
    FLevel: integer; // the depth under a group
    FTag: PtrInt;
    FBar: TRect; // where it was painted last, in chart coordinates
    procedure setCaption(const value: string);
    procedure setDate(index: integer; value: TDateTime);
    function getDate(index: integer): TDateTime;
    procedure setProgress(value: integer);
    procedure setColor(value: TColor);
    procedure setDependsOn(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setLevel(value: integer);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // the days the task takes, a milestone counts one
    function Days: integer;
  published
    property Caption: string read FCaption write setCaption;
    property Start: TDateTime index 0 read getDate write setDate;
    property Finish: TDateTime index 1 read getDate write setDate;
    property Progress: integer read FProgress write setProgress default 0;
    // clDefault takes a color from the palette of the chart
    property Color: TColor read FColor write setColor default clDefault;
    property DependsOn: integer read FDependsOn write setDependsOn default -1;
    // a diamond on one day instead of a bar
    property Milestone: boolean index 0 read getFlag write setFlag default false;
    // a group whose children are folded
    property Collapsed: boolean index 1 read getFlag write setFlag default false;
    // the depth under a group, which is the task above with a lower level
    property Level: integer read FLevel write setLevel default 0;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TGanttTasks }

  TGanttTasks = class(TOwnedCollection)
  private
    function getItem(index: integer): TGanttTask;
    procedure setItem(index: integer; value: TGanttTask);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TGanttTask;
    property Items[index: integer]: TGanttTask read getItem write setItem; default;
  end;

  { TGanttChart }

  // tasks as bars on a time scale: a name column on the left, days, weeks
  // or months across the top, progress inside the bars, arrows between
  // a task and the one it waits for, a line for today. The mouse moves a
  // bar or stretches its ends; a group folds its children
  TGanttChart = class(TScrollingWinControl)
  private
    FTasks: TGanttTasks;
    FScale: TGanttScale;
    FRangeStart, FRangeEnd: TDateTime;
    FDayWidth, FRowHeight, FNameWidth, FBarRadius, FPadding: integer;
    FShowToday, FShowGrid, FShowProgress, FShowDependencies, FShowWeekends, FAllowDrag, FAllowResize, FAutoRange, FShowCaptions: boolean;
    FBarColor, FProgressColor, FGridColor, FTextColor, FBackColor, FHeaderColor, FTodayColor, FWeekendColor, FArrowColor, FNameColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FHot, FSelected: TGanttTask;
    FDrag: TGanttTask;
    FDragPart: integer; // 0 the whole bar, 1 the start, 2 the finish
    FDragX: integer;
    FDragStart, FDragFinish: TDateTime;
    FShown: array of TGanttTask; // the tasks visible after folding
    FOnTaskClick, FOnTaskDblClick, FOnSelect: TGanttTaskEvent;
    FOnTaskChange: TGanttChangeEvent;
    procedure setTasks(value: TGanttTasks);
    procedure setScale(value: TGanttScale);
    procedure setRange(index: integer; value: TDateTime);
    function getRange(index: integer): TDateTime;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    procedure setSelected(value: TGanttTask);
    procedure rebuildShown;
    function headerPx: integer;
    function rowPx: integer;
    function dayPx: double;
    function rangeFirst: TDateTime;
    function rangeLast: TDateTime;
    function xOf(date: TDateTime): integer;
    function dateAt(x: integer): TDateTime;
    function taskAt(x, y: integer; out part: integer): TGanttTask;
    function taskColor(task: TGanttTask): TColor;
    function isGroup(task: TGanttTask): boolean;
    procedure updateRange;
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
    function AddTask(const caption: string; start, finish: TDateTime; level: integer = 0): TGanttTask;
    function AddMilestone(const caption: string; date: TDateTime; level: integer = 0): TGanttTask;
    // the view scrolled so a date shows
    procedure ScrollToDate(date: TDateTime);
    procedure ScrollToToday;
    // the first start and the last finish of the tasks
    procedure TaskSpan(out first, last: TDateTime);
    property Selected: TGanttTask read FSelected write setSelected;
  published
    property Tasks: TGanttTasks read FTasks write setTasks;
    property Scale: TGanttScale read FScale write setScale default gsDays;
    // the dates shown; AutoRange takes them from the tasks with a margin
    property RangeStart: TDateTime index 0 read getRange write setRange;
    property RangeEnd: TDateTime index 1 read getRange write setRange;
    property AutoRange: boolean index 7 read getFlag write setFlag default true;
    property DayWidth: integer index 0 read getMetric write setMetric default 24;
    // 0 takes it from the font
    property RowHeight: integer index 1 read getMetric write setMetric default 0;
    property NameWidth: integer index 2 read getMetric write setMetric default 160;
    property BarRadius: integer index 3 read getMetric write setMetric default 3;
    property Padding: integer index 4 read getMetric write setMetric default 4;
    property ShowToday: boolean index 0 read getFlag write setFlag default true;
    property ShowGrid: boolean index 1 read getFlag write setFlag default true;
    property ShowProgress: boolean index 2 read getFlag write setFlag default true;
    property ShowDependencies: boolean index 3 read getFlag write setFlag default true;
    property ShowWeekends: boolean index 4 read getFlag write setFlag default true;
    property AllowDrag: boolean index 5 read getFlag write setFlag default true;
    property AllowResize: boolean index 6 read getFlag write setFlag default true;
    // the caption inside the bar as well as in the name column
    property ShowCaptions: boolean index 8 read getFlag write setFlag default false;
    // clDefault takes the colors of the theme
    property BarColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ProgressColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property HeaderColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property TodayColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property WeekendColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property ArrowColor: TColor index 8 read getPartColor write setPartColor default clDefault;
    property NameColor: TColor index 9 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnTaskClick: TGanttTaskEvent read FOnTaskClick write FOnTaskClick;
    property OnTaskDblClick: TGanttTaskEvent read FOnTaskDblClick write FOnTaskDblClick;
    property OnSelect: TGanttTaskEvent read FOnSelect write FOnSelect;
    property OnTaskChange: TGanttChangeEvent read FOnTaskChange write FOnTaskChange;
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

{ TGanttTask }

constructor TGanttTask.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clDefault;
  FDependsOn := -1;
  FStart := Trunc(Date);
  FFinish := FStart+4;
end;

procedure TGanttTask.Assign(Source: TPersistent);
begin
  if Source is TGanttTask then begin
    var s := TGanttTask(Source);
    FCaption := s.FCaption;
    FStart := s.FStart;
    FFinish := s.FFinish;
    FProgress := s.FProgress;
    FColor := s.FColor;
    FDependsOn := s.FDependsOn;
    FMilestone := s.FMilestone;
    FCollapsed := s.FCollapsed;
    FLevel := s.FLevel;
    FTag := s.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TGanttTask.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

function TGanttTask.Days: integer;
begin
  result := if FMilestone then 1 else Max(Trunc(FFinish)-Trunc(FStart)+1, 1);
end;

procedure TGanttTask.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

function TGanttTask.getDate(index: integer): TDateTime;
begin
  result := if index = 0 then FStart else FFinish;
end;

procedure TGanttTask.setDate(index: integer; value: TDateTime);
begin
  value := Trunc(value);
  if index = 0 then begin
    FStart := value;
    if FFinish < FStart then FFinish := FStart;
  end else begin
    FFinish := value;
    if FStart > FFinish then FStart := FFinish;
  end;
  Changed(false);
end;

procedure TGanttTask.setProgress(value: integer);
begin
  value := EnsureRange(value, 0, 100);
  if FProgress = value then exit;
  FProgress := value;
  Changed(false);
end;

procedure TGanttTask.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TGanttTask.setDependsOn(value: integer);
begin
  if value < -1 then value := -1;
  if FDependsOn = value then exit;
  FDependsOn := value;
  Changed(false);
end;

function TGanttTask.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FMilestone else FCollapsed;
end;

procedure TGanttTask.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FMilestone := value else FCollapsed := value;
  Changed(false);
end;

procedure TGanttTask.setLevel(value: integer);
begin
  value := Max(value, 0);
  if FLevel = value then exit;
  FLevel := value;
  Changed(false);
end;

{ TGanttTasks }

function TGanttTasks.getItem(index: integer): TGanttTask;
begin
  result := TGanttTask(inherited Items[index]);
end;

procedure TGanttTasks.setItem(index: integer; value: TGanttTask);
begin
  inherited Items[index] := value;
end;

function TGanttTasks.Add: TGanttTask;
begin
  result := TGanttTask(inherited Add);
end;

procedure TGanttTasks.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TGanttChart then begin
    TGanttChart(Owner).rebuildShown;
    TGanttChart(Owner).updateRange;
    TGanttChart(Owner).Invalidate;
  end;
end;

{ TGanttChart }

constructor TGanttChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FTasks := TGanttTasks.Create(self, TGanttTask);
  FDayWidth := 24;
  FNameWidth := 160;
  FBarRadius := 3;
  FPadding := 4;
  FShowToday := true;
  FShowGrid := true;
  FShowProgress := true;
  FShowDependencies := true;
  FShowWeekends := true;
  FAllowDrag := true;
  FAllowResize := true;
  FAutoRange := true;
  FBarColor := clDefault;
  FProgressColor := clDefault;
  FGridColor := clDefault;
  FTextColor := clDefault;
  FBackColor := clDefault;
  FHeaderColor := clDefault;
  FTodayColor := clDefault;
  FWeekendColor := clDefault;
  FArrowColor := clDefault;
  FNameColor := clDefault;
  FAntialiasing := asTheme;
  Color := clWindow;
  BorderStyle := bsSingle;
  TabStop := true;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Tracking := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TGanttChart.Destroy;
begin
  FTasks.Free;
  inherited Destroy;
end;

class function TGanttChart.GetControlClassDefaultSize: TSize;
begin
  result.cx := 600;
  result.cy := 240;
end;

function TGanttChart.AddTask(const caption: string; start, finish: TDateTime; level: integer): TGanttTask;
begin
  result := FTasks.Add;
  result.Caption := caption;
  result.Start := start;
  result.Finish := finish;
  result.Level := level;
end;

function TGanttChart.AddMilestone(const caption: string; date: TDateTime; level: integer): TGanttTask;
begin
  result := AddTask(caption, date, date, level);
  result.Milestone := true;
end;

// -- data ----------------------

function TGanttChart.isGroup(task: TGanttTask): boolean;
begin
  var i := task.Index;
  result := (i+1 < FTasks.Count) and (FTasks[i+1].Level > task.Level);
end;

procedure TGanttChart.rebuildShown;
begin
  FShown := nil;
  var hideBelow := -1; // the level under which tasks are folded
  for var i := 0 to FTasks.Count-1 do begin
    var t := FTasks[i];
    if (hideBelow >= 0) and (t.Level > hideBelow) then continue;
    hideBelow := -1;
    FShown := FShown+[t];
    if t.Collapsed and isGroup(t) then hideBelow := t.Level;
  end;
end;

procedure TGanttChart.TaskSpan(out first, last: TDateTime);
begin
  first := 0;
  last := 0;
  for var i := 0 to FTasks.Count-1 do begin
    var t := FTasks[i];
    if (first = 0) or (t.Start < first) then first := t.Start;
    if (last = 0) or (t.Finish > last) then last := t.Finish;
  end;
  if first = 0 then begin
    first := Trunc(Date);
    last := first+30;
  end;
end;

function TGanttChart.rangeFirst: TDateTime;
begin
  if not FAutoRange and (FRangeStart <> 0) then exit(Trunc(FRangeStart));
  var first, last: TDateTime;
  TaskSpan(first, last);
  result := Trunc(first)-3;
end;

function TGanttChart.rangeLast: TDateTime;
begin
  if not FAutoRange and (FRangeEnd <> 0) then exit(Trunc(FRangeEnd));
  var first, last: TDateTime;
  TaskSpan(first, last);
  result := Trunc(last)+7;
end;

// -- geometry ----------------------

function TGanttChart.headerPx: integer;
begin
  result := lineHeightOf(Font)*2+scaled(self, 8);
end;

function TGanttChart.rowPx: integer;
begin
  result := if FRowHeight > 0 then scaled(self, FRowHeight) else lineHeightOf(Font)+scaled(self, 12);
end;

function TGanttChart.dayPx: double;
begin
  result := match FScale of
    gsWeeks: scaled(self, FDayWidth)/3;
    gsMonths: scaled(self, FDayWidth)/8;
  else
    scaled(self, FDayWidth)
  end;
end;

function TGanttChart.xOf(date: TDateTime): integer;
begin
  result := scaled(self, FNameWidth)+Round((Trunc(date)-rangeFirst)*dayPx);
end;

function TGanttChart.dateAt(x: integer): TDateTime;
begin
  result := rangeFirst+Floor((x+HorzScrollBar.Position-scaled(self, FNameWidth))/dayPx);
end;

function TGanttChart.taskAt(x, y: integer; out part: integer): TGanttTask;
begin
  part := 0;
  result := nil;
  var row := (y+VertScrollBar.Position-headerPx) div rowPx;
  if (row < 0) or (row >= length(FShown)) then exit;
  var t := FShown[row];
  var px := x+HorzScrollBar.Position;
  if px < scaled(self, FNameWidth) then exit(t);
  var grip := scaled(self, 5);
  if (px >= t.FBar.Left-grip) and (px <= t.FBar.Right+grip) then begin
    result := t;
    if not t.Milestone then begin
      if px <= t.FBar.Left+grip then part := 1
      else if px >= t.FBar.Right-grip then part := 2;
    end;
  end;
end;

function TGanttChart.taskColor(task: TGanttTask): TColor;
begin
  result := task.Color;
  if result = clDefault then result := pick(FBarColor, PALETTE[task.Level mod length(PALETTE)]);
  result := ColorToRGB(result);
end;

procedure TGanttChart.updateRange;
begin
  if not HandleAllocated then exit;
  VertScrollBar.Increment := rowPx;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := headerPx+length(FShown)*rowPx+scaled(self, FPadding);
  HorzScrollBar.Increment := Round(dayPx);
  HorzScrollBar.Page := Max(ClientWidth, 1);
  HorzScrollBar.Range := xOf(rangeLast)+Round(dayPx);
end;

procedure TGanttChart.ScrollToDate(date: TDateTime);
begin
  HorzScrollBar.Position := Max(xOf(date)-scaled(self, FNameWidth)-ClientWidth div 3, 0);
end;

procedure TGanttChart.ScrollToToday;
begin
  ScrollToDate(Date);
end;

procedure TGanttChart.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TGanttChart.Resize;
begin
  inherited Resize;
  updateRange;
  Invalidate;
end;

procedure TGanttChart.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

// -- painting ----------------------

procedure TGanttChart.Paint;
begin
  if length(FShown) <> FTasks.Count then rebuildShown;
  if length(FShown) = 0 then rebuildShown;
  var back := pick(FBackColor, Color);
  var text := pick(FTextColor, clWindowText);
  var names := pick(FNameColor, clWindowText);
  var grid := pick(FGridColor, blend(back, clWindowText, 10));
  var header := pick(FHeaderColor, blend(back, clWindowText, 6));
  var today := pick(FTodayColor, $4F53D9);
  var weekend := pick(FWeekendColor, blend(back, clWindowText, 4));
  var arrow := pick(FArrowColor, blend(clWindowText, back, 30));
  var progressColor := if FProgressColor = clDefault then clNone else ColorToRGB(FProgressColor);
  var view := ClientRect;
  OffsetRect(view, HorzScrollBar.Position, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var hh := headerPx;
  var rh := rowPx;
  var nameW := scaled(self, FNameWidth);
  var pad := scaled(self, FPadding);
  var radius := scaled(self, FBarRadius);
  var first := rangeFirst;
  var last := rangeLast;
  var dpx := dayPx;
  var lh := lineHeightOf(Font);
  // the weekends and the day grid across the rows
  var chartTop := hh;
  var chartBottom := Max(hh+length(FShown)*rh, view.Bottom);
  var d := first;
  while d <= last do begin
    var x := xOf(d);
    if FShowWeekends and (DayOfWeek(d) in [1, 7]) and (FScale = gsDays) then sp.FillRect(Rect(x, chartTop, x+Round(dpx), chartBottom), weekend);
    var boundary := match FScale of
      gsDays: true;
      gsWeeks: DayOfWeek(d) = 2;
    else
      DayOf(d) = 1
    end;
    if FShowGrid and boundary then sp.FillRect(Rect(x, chartTop, x+1, chartBottom), grid);
    d += 1;
  end;
  // the rows
  for var i := 0 to high(FShown) do begin
    var t := FShown[i];
    var top := hh+i*rh;
    if t = FSelected then sp.FillRect(Rect(view.Left, top, view.Right, top+rh), blend(back, clHighlight, 15))
    else if (t = FHot) and hoverEnabled then sp.FillRect(Rect(view.Left, top, view.Right, top+rh), hoverColor(back));
    if FShowGrid then sp.FillRect(Rect(view.Left, top+rh-1, view.Right, top+rh), grid);
    var color := taskColor(t);
    var x1 := xOf(t.Start);
    var x2 := xOf(t.Finish)+Round(dpx);
    var barTop := top+pad+scaled(self, 2);
    var barBottom := top+rh-pad-scaled(self, 2);
    if t.Milestone then begin
      var cx := x1+Round(dpx/2);
      var cy := (barTop+barBottom) div 2;
      var r := (barBottom-barTop) div 2;
      sp.FillPolygon([PointF(cx, cy-r), PointF(cx+r, cy), PointF(cx, cy+r), PointF(cx-r, cy)], color);
      t.FBar := Rect(cx-r, barTop, cx+r, barBottom);
    end else if isGroup(t) then begin
      // a group spans its children as a thin bracket
      var gs := t.Start;
      var gf := t.Finish;
      for var k := t.Index+1 to FTasks.Count-1 do begin
        if FTasks[k].Level <= t.Level then break;
        gs := Min(gs, FTasks[k].Start);
        gf := Max(gf, FTasks[k].Finish);
      end;
      x1 := xOf(gs);
      x2 := xOf(gf)+Round(dpx);
      var mid := (barTop+barBottom) div 2;
      sp.FillRoundRect(x1, mid-scaled(self, 3), x2, mid+scaled(self, 3), 1.5, blend(color, clWindowText, 30));
      sp.FillPolygon([PointF(x1, mid+scaled(self, 3)), PointF(x1+scaled(self, 6), mid+scaled(self, 3)), PointF(x1, mid+scaled(self, 9))], blend(color, clWindowText, 30));
      sp.FillPolygon([PointF(x2, mid+scaled(self, 3)), PointF(x2-scaled(self, 6), mid+scaled(self, 3)), PointF(x2, mid+scaled(self, 9))], blend(color, clWindowText, 30));
      t.FBar := Rect(x1, barTop, x2, barBottom);
    end else begin
      var r := Rect(x1, barTop, x2, barBottom);
      t.FBar := r;
      var fill := if t = FDrag then blend(color, clWhite, 20) else color;
      paintRoundRect(sp, r, radius, blend(fill, back, 45), clNone);
      if FShowProgress and (t.Progress > 0) then begin
        var pr := r;
        pr.Right := r.Left+Round(r.Width*t.Progress/100);
        paintRoundRect(sp, pr, radius, (if progressColor = clNone then fill else progressColor), clNone);
      end;
      paintRoundRect(sp, r, radius, clNone, blend(fill, clWindowText, 20), 1);
    end;
  end;
  // the arrows from a task to the one that waits for it
  if FShowDependencies then
    for var i := 0 to high(FShown) do begin
      var t := FShown[i];
      if (t.DependsOn < 0) or (t.DependsOn >= FTasks.Count) then continue;
      var from := FTasks[t.DependsOn];
      if from.FBar.IsEmpty then continue;
      var sx := from.FBar.Right;
      var sy := (from.FBar.Top+from.FBar.Bottom) div 2;
      var ex := t.FBar.Left;
      var ey := (t.FBar.Top+t.FBar.Bottom) div 2;
      var bend := sx+scaled(self, 8);
      if ex > bend then sp.StrokePolyline([PointF(sx, sy), PointF(bend, sy), PointF(bend, ey), PointF(ex-scaled(self, 4), ey)], 1.5, arrow)
      else sp.StrokePolyline([PointF(sx, sy), PointF(bend, sy), PointF(bend, (sy+ey) div 2), PointF(ex-scaled(self, 8), (sy+ey) div 2), PointF(ex-scaled(self, 8), ey), PointF(ex-scaled(self, 4), ey)], 1.5, arrow);
      sp.FillPolygon([PointF(ex, ey), PointF(ex-scaled(self, 6), ey-scaled(self, 4)), PointF(ex-scaled(self, 6), ey+scaled(self, 4))], arrow);
    end;
  // today
  if FShowToday and (Date >= first) and (Date <= last) then begin
    var x := xOf(Date)+Round(dpx/2);
    sp.FillRect(Rect(x, chartTop, x+scaled(self, 2), chartBottom), today);
  end;
  // the header and the name column sit still
  sp.FillRect(Rect(view.Left, view.Top, view.Right, view.Top+hh), header);
  sp.FillRect(Rect(view.Left, view.Top+hh-1, view.Right, view.Top+hh), grid);
  sp.FillRect(Rect(view.Left, view.Top+hh, view.Left+nameW, view.Bottom), back);
  sp.FillRect(Rect(view.Left+nameW-1, view.Top, view.Left+nameW, view.Bottom), grid);
  // the expand marks of the groups in the name column
  for var i := 0 to high(FShown) do begin
    var t := FShown[i];
    if not isGroup(t) then continue;
    var top := hh+i*rh;
    var cx := view.Left+pad+scaled(self, 6)+t.Level*scaled(self, 14);
    paintChevron(sp, Rect(cx-scaled(self, 5), top, cx+scaled(self, 5), top+rh), (if t.Collapsed then cdRight else cdDown), scaled(self, 7), names);
  end;
  // the scale marks in the header
  d := first;
  var lastLabelX := -MaxInt;
  while d <= last do begin
    var x := xOf(d);
    var major := match FScale of
      gsDays: DayOf(d) = 1;
      gsWeeks: DayOf(d) = 1;
    else
      MonthOf(d) = 1
    end;
    if major then sp.FillRect(Rect(x, view.Top, x+1, view.Top+hh), blend(grid, clWindowText, 20))
    else if FShowGrid and (FScale = gsDays) then sp.FillRect(Rect(x, view.Top+hh div 2, x+1, view.Top+hh), grid);
    d += 1;
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Clipping := true;
  // the names
  Canvas.ClipRect := Rect(view.Left, view.Top+hh, view.Left+nameW-1, view.Bottom);
  for var i := 0 to high(FShown) do begin
    var t := FShown[i];
    var top := hh+i*rh;
    Canvas.Font.Style := if isGroup(t) then Font.Style+[fsBold] else Font.Style;
    Canvas.Font.Color := names;
    var x := view.Left+pad+scaled(self, 14)+t.Level*scaled(self, 14);
    Canvas.TextOut(x, top+(rh-lh) div 2, t.Caption);
  end;
  Canvas.Font.Style := Font.Style;
  // the captions in the bars
  if FShowCaptions then begin
    Canvas.ClipRect := Rect(view.Left+nameW, view.Top+hh, view.Right, view.Bottom);
    for var i := 0 to high(FShown) do begin
      var t := FShown[i];
      if t.Milestone or isGroup(t) then continue;
      Canvas.Font.Color := contrastText(taskColor(t));
      var r := t.FBar;
      if Canvas.TextWidth(t.Caption)+scaled(self, 8) < r.Width then Canvas.TextOut(r.Left+scaled(self, 4), r.Top+(r.Height-lh) div 2, t.Caption);
    end;
  end;
  // the header: the days or weeks on the lower line, the months above
  Canvas.ClipRect := Rect(view.Left+nameW, view.Top, view.Right, view.Top+hh);
  Canvas.Font.Color := text;
  d := first;
  lastLabelX := -MaxInt;
  while d <= last do begin
    var x := xOf(d);
    match FScale of
      gsDays: begin
        var s := IntToStr(DayOf(d));
        if Canvas.TextWidth('00')+2 <= dpx then Canvas.TextOut(x+(Round(dpx)-Canvas.TextWidth(s)) div 2, view.Top+hh-lh-scaled(self, 2), s)
        else if DayOfWeek(d) = 2 then Canvas.TextOut(x+2, view.Top+hh-lh-scaled(self, 2), s);
      end;
      gsWeeks: if DayOfWeek(d) = 2 then Canvas.TextOut(x+2, view.Top+hh-lh-scaled(self, 2), IntToStr(DayOf(d)));
      gsMonths: ;
    end;
    if (DayOf(d) = 1) or (d = first) then begin
      var s := formatSettingsOf(FLanguage).ShortMonthNames[MonthOf(d)]+' '+IntToStr(YearOf(d));
      if x > lastLabelX+scaled(self, 6) then begin
        Canvas.TextOut(x+scaled(self, 3), view.Top+scaled(self, 3), s);
        lastLabelX := x+Canvas.TextWidth(s);
      end;
    end;
    d += 1;
  end;
  Canvas.Clipping := false;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TGanttChart.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  var part: integer;
  var t := taskAt(X, Y, part);
  if t = nil then exit;
  Selected := t;
  if Assigned(FOnTaskClick) then FOnTaskClick(self, t);
  // a click on the chevron of a group folds it
  var px := X+HorzScrollBar.Position;
  if isGroup(t) and (px < scaled(self, FNameWidth)) and (px < scaled(self, FPadding)+scaled(self, 14)+t.Level*scaled(self, 14)) then begin
    t.Collapsed := not t.Collapsed;
    exit;
  end;
  if px < scaled(self, FNameWidth) then exit;
  if isGroup(t) then exit;
  if (part = 0) and not FAllowDrag then exit;
  if (part > 0) and not FAllowResize then exit;
  FDrag := t;
  FDragPart := part;
  FDragX := X;
  FDragStart := t.Start;
  FDragFinish := t.Finish;
end;

procedure TGanttChart.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDrag <> nil then begin
    var days := Round((X-FDragX)/dayPx);
    match FDragPart of
      1: FDrag.Start := Min(FDragStart+days, FDragFinish);
      2: FDrag.Finish := Max(FDragFinish+days, FDragStart);
    else
      begin
        FDrag.FStart := FDragStart+days;
        FDrag.FFinish := FDragFinish+days;
        Invalidate;
      end;
    end;
    exit;
  end;
  var part: integer;
  var hot := taskAt(X, Y, part);
  var px := X+HorzScrollBar.Position;
  Cursor := if (hot <> nil) and (px >= scaled(self, FNameWidth)) and not isGroup(hot) then (if part > 0 then crSizeWE else crSizeAll) else crDefault;
  if hot = FHot then exit;
  FHot := hot;
  Invalidate;
end;

procedure TGanttChart.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FDrag = nil then exit;
  var t := FDrag;
  FDrag := nil;
  if (t.Start <> FDragStart) or (t.Finish <> FDragFinish) then begin
    updateRange;
    Invalidate;
    if Assigned(FOnTaskChange) then FOnTaskChange(self, t, FDragStart, FDragFinish);
  end else Invalidate;
end;

procedure TGanttChart.MouseLeave;
begin
  inherited MouseLeave;
  if FHot = nil then exit;
  FHot := nil;
  Invalidate;
end;

procedure TGanttChart.DblClick;
begin
  inherited DblClick;
  var p := ScreenToClient(Mouse.CursorPos);
  var part: integer;
  var t := taskAt(p.X, p.Y, part);
  if (t <> nil) and Assigned(FOnTaskDblClick) then FOnTaskDblClick(self, t);
end;

procedure TGanttChart.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var index := -1;
  for var i := 0 to high(FShown) do if FShown[i] = FSelected then index := i;
  match Key of
    VK_DOWN: if index+1 < length(FShown) then Selected := FShown[index+1] else if (index < 0) and (length(FShown) > 0) then Selected := FShown[0];
    VK_UP: if index > 0 then Selected := FShown[index-1];
    VK_LEFT: if (FSelected <> nil) and (ssCtrl in Shift) then begin FSelected.FStart -= 1; FSelected.FFinish -= 1; FSelected.Changed(false); end;
    VK_RIGHT: if (FSelected <> nil) and (ssCtrl in Shift) then begin FSelected.FStart += 1; FSelected.FFinish += 1; FSelected.Changed(false); end;
    VK_SPACE: if (FSelected <> nil) and isGroup(FSelected) then FSelected.Collapsed := not FSelected.Collapsed;
    VK_HOME: ScrollToToday;
  else
    exit;
  end;
  Key := 0;
end;

// -- properties ----------------------

procedure TGanttChart.setTasks(value: TGanttTasks);
begin
  FTasks.Assign(value);
  rebuildShown;
  updateRange;
  Invalidate;
end;

procedure TGanttChart.setSelected(value: TGanttTask);
begin
  if FSelected = value then exit;
  FSelected := value;
  Invalidate;
  if Assigned(FOnSelect) then FOnSelect(self, value);
end;

procedure TGanttChart.setScale(value: TGanttScale);
begin
  if FScale = value then exit;
  FScale := value;
  updateRange;
  Invalidate;
end;

function TGanttChart.getRange(index: integer): TDateTime;
begin
  result := if index = 0 then FRangeStart else FRangeEnd;
end;

procedure TGanttChart.setRange(index: integer; value: TDateTime);
begin
  if index = 0 then FRangeStart := Trunc(value) else FRangeEnd := Trunc(value);
  updateRange;
  Invalidate;
end;

function TGanttChart.getMetric(index: integer): integer;
begin
  result := match index of
    0: FDayWidth;
    1: FRowHeight;
    2: FNameWidth;
    3: FBarRadius;
  else
    FPadding
  end;
end;

procedure TGanttChart.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 0 then value := Max(value, 4);
  if getMetric(index) = value then exit;
  match index of
    0: FDayWidth := value;
    1: FRowHeight := value;
    2: FNameWidth := value;
    3: FBarRadius := value;
  else
    FPadding := value;
  end;
  updateRange;
  Invalidate;
end;

function TGanttChart.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowToday;
    1: FShowGrid;
    2: FShowProgress;
    3: FShowDependencies;
    4: FShowWeekends;
    5: FAllowDrag;
    6: FAllowResize;
    7: FAutoRange;
  else
    FShowCaptions
  end;
end;

procedure TGanttChart.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowToday := value;
    1: FShowGrid := value;
    2: FShowProgress := value;
    3: FShowDependencies := value;
    4: FShowWeekends := value;
    5: FAllowDrag := value;
    6: FAllowResize := value;
    7: FAutoRange := value;
  else
    FShowCaptions := value;
  end;
  updateRange;
  Invalidate;
end;

function TGanttChart.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBarColor;
    1: FProgressColor;
    2: FGridColor;
    3: FTextColor;
    4: FBackColor;
    5: FHeaderColor;
    6: FTodayColor;
    7: FWeekendColor;
    8: FArrowColor;
  else
    FNameColor
  end;
end;

procedure TGanttChart.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBarColor := value;
    1: FProgressColor := value;
    2: FGridColor := value;
    3: FTextColor := value;
    4: FBackColor := value;
    5: FHeaderColor := value;
    6: FTodayColor := value;
    7: FWeekendColor := value;
    8: FArrowColor := value;
  else
    FNameColor := value;
  end;
  Invalidate;
end;

procedure TGanttChart.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TGanttChart.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
