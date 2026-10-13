{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ChartLite;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  TChartLite = class;
  // bars side by side, bars stacked, lines, filled areas, a pie, a donut,
  // areas stacked, dots alone, stepped lines, a radar of polygons on spokes
  TChartKind = (ckBars, ckStackedBars, ckLines, ckArea, ckPie, ckDonut, ckStackedArea, ckDots, ckSteps, ckRadar);
  TChartLegend = (lgNone, lgRight, lgBottom, lgTop);
  TChartPointEvent = procedure(Sender: TObject; series, index: integer) of object;
  // the text of a value label; text comes in formatted and may change
  TChartValueTextEvent = procedure(Sender: TObject; series, index: integer; value: double; var text: string) of object;

  { TChartSeries }

  TChartSeries = class(TCollectionItem)
  private
    FTitle: string;
    FColor: TColor;
    FValues: TStrings;
    FVisible: boolean;
    FTag: PtrInt;
    procedure setTitle(const value: string);
    procedure setColor(value: TColor);
    procedure setValues(value: TStrings);
    procedure setVisible(value: boolean);
    procedure valuesChanged(Sender: TObject);
    function getCount: integer;
    function getValue(index: integer): double;
    procedure setValue(index: integer; value: double);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure Add(value: double);
    procedure Clear;
    property Count: integer read getCount;
    property Value[index: integer]: double read getValue write setValue; default;
  published
    property Title: string read FTitle write setTitle;
    // clDefault takes a color from the palette of the chart
    property Color: TColor read FColor write setColor default clDefault;
    // one number per line
    property Values: TStrings read FValues write setValues;
    property Visible: boolean read FVisible write setVisible default true;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TChartSeriesList }

  TChartSeriesList = class(TOwnedCollection)
  private
    function getItem(index: integer): TChartSeries;
    procedure setItem(index: integer; value: TChartSeries);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TChartSeries;
    property Items[index: integer]: TChartSeries read getItem write setItem; default;
  end;

  { TChartLite }

  // bars, lines, areas and pies from a few series of numbers: no axes
  // objects, no transformations, a chart in a minute. Categories name the
  // points, a legend names the series, the mouse picks out a point
  TChartLite = class(TGraphicControl)
  private
    type
      THit = record
        series, index: integer;
        rect: TRect; // the bar or the dot, or the pie slice box
        angle, sweep: double; // the pie slice
      end;
      TTextJob = record
        x, y: integer;
        text: string;
        color: TColor;
        bold: boolean;
      end;
    var
    FTexts: array of TTextJob; // painted after the shapes
    FSeries: TChartSeriesList;
    FCategories: TStrings;
    FKind: TChartKind;
    FLegend: TChartLegend;
    FTitle: string;
    FShowGrid, FShowValues, FShowAxes, FShowDots, FShowCategories, FAutoRange, FShowPercent: boolean;
    FMinValue, FMaxValue: double;
    FPadding, FBarGap, FLineWidth, FGridLines, FCornerRadius, FDotSize: integer;
    FValueFormat: string;
    FGridColor, FAxisColor, FTextColor, FBackColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FHits: array of THit;
    FHot: integer;
    FOnPointClick, FOnPointHover: TChartPointEvent;
    FOnValueText: TChartValueTextEvent;
    procedure setSeries(value: TChartSeriesList);
    procedure setCategories(value: TStrings);
    procedure setKind(value: TChartKind);
    procedure setLegend(value: TChartLegend);
    procedure setTitle(const value: string);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setRange(index: integer; value: double);
    function getRange(index: integer): double;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setValueFormat(const value: string);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure categoriesChanged(Sender: TObject);
    function seriesColor(index: integer): TColor;
    function pointCount: integer;
    function valueText(series, index: integer; value: double): string;
    function hitAt(x, y: integer): integer;
    procedure findRange(out low, high: double);
    procedure addText(x, y: integer; const text: string; color: TColor; bold: boolean);
    procedure paintLegend(sp: TSmoothPaint; var area: TRect);
    procedure paintPie(sp: TSmoothPaint; const area: TRect);
    procedure paintRadar(sp: TSmoothPaint; const area: TRect);
    procedure paintAxes(sp: TSmoothPaint; const area: TRect; low, high: double);
    procedure paintTexts;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // a series with a title and values in one call
    function AddSeries(const title: string; const values: array of double; color: TColor = clDefault): TChartSeries;
    procedure Clear;
    // the point under the mouse, -1 for none
    property HotSeries: integer read FHot;
  published
    property Series: TChartSeriesList read FSeries write setSeries;
    // the names of the points along the bottom, or of the slices
    property Categories: TStrings read FCategories write setCategories;
    property Kind: TChartKind read FKind write setKind default ckBars;
    property Legend: TChartLegend read FLegend write setLegend default lgNone;
    property Title: string read FTitle write setTitle;
    property ShowGrid: boolean index 0 read getFlag write setFlag default true;
    // the number over every bar or point
    property ShowValues: boolean index 1 read getFlag write setFlag default false;
    property ShowAxes: boolean index 2 read getFlag write setFlag default true;
    property ShowDots: boolean index 3 read getFlag write setFlag default true;
    property ShowCategories: boolean index 4 read getFlag write setFlag default true;
    // the range follows the values; off, MinValue and MaxValue hold it
    property AutoRange: boolean index 5 read getFlag write setFlag default true;
    // pie slices show their share instead of the value
    property ShowPercent: boolean index 6 read getFlag write setFlag default true;
    property MinValue: double index 0 read getRange write setRange;
    property MaxValue: double index 1 read getRange write setRange;
    property Padding: integer index 0 read getMetric write setMetric default 8;
    // the share of a bar slot left empty, in percent
    property BarGap: integer index 1 read getMetric write setMetric default 30;
    property LineWidth: integer index 2 read getMetric write setMetric default 2;
    property GridLines: integer index 3 read getMetric write setMetric default 5;
    property CornerRadius: integer index 4 read getMetric write setMetric default 2;
    property DotSize: integer index 5 read getMetric write setMetric default 6;
    // a Format pattern for one number
    property ValueFormat: string read FValueFormat write setValueFormat;
    // clDefault takes the colors of the theme
    property GridColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property AxisColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnPointClick: TChartPointEvent read FOnPointClick write FOnPointClick;
    // the mouse came over a point; series -1 once it left
    property OnPointHover: TChartPointEvent read FOnPointHover write FOnPointHover;
    property OnValueText: TChartValueTextEvent read FOnValueText write FOnValueText;
    property Align;
    property Anchors;
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
  Math;

const
  PALETTE: array[0..7] of TColor = ($D98B3B, $5CB85C, $F0AD4E, $D9534F, $B35CA0, $17A2B8, $6C757D, $343A40);

{ TChartSeries }

constructor TChartSeries.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FColor := clDefault;
  FVisible := true;
  FValues := TStringList.Create;
  TStringList(FValues).OnChange := @valuesChanged;
end;

destructor TChartSeries.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

procedure TChartSeries.Assign(Source: TPersistent);
begin
  if Source is TChartSeries then begin
    FTitle := TChartSeries(Source).FTitle;
    FColor := TChartSeries(Source).FColor;
    FVisible := TChartSeries(Source).FVisible;
    FTag := TChartSeries(Source).FTag;
    FValues.Assign(TChartSeries(Source).FValues);
    Changed(false);
  end else inherited Assign(Source);
end;

function TChartSeries.GetDisplayName: string;
begin
  result := if FTitle <> '' then FTitle else inherited GetDisplayName;
end;

function TChartSeries.getCount: integer;
begin
  result := FValues.Count;
end;

function TChartSeries.getValue(index: integer): double;
begin
  result := 0;
  if (index >= 0) and (index < FValues.Count) then result := StrToFloatDef(Trim(FValues[index]), 0, DefaultFormatSettings);
end;

procedure TChartSeries.setValue(index: integer; value: double);
begin
  while FValues.Count <= index do FValues.Add('0');
  FValues[index] := FloatToStr(value, DefaultFormatSettings);
end;

procedure TChartSeries.Add(value: double);
begin
  FValues.Add(FloatToStr(value, DefaultFormatSettings));
end;

procedure TChartSeries.Clear;
begin
  FValues.Clear;
end;

procedure TChartSeries.valuesChanged(Sender: TObject);
begin
  Changed(false);
end;

procedure TChartSeries.setTitle(const value: string);
begin
  if FTitle = value then exit;
  FTitle := value;
  Changed(false);
end;

procedure TChartSeries.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TChartSeries.setValues(value: TStrings);
begin
  FValues.Assign(value);
end;

procedure TChartSeries.setVisible(value: boolean);
begin
  if FVisible = value then exit;
  FVisible := value;
  Changed(false);
end;

{ TChartSeriesList }

function TChartSeriesList.getItem(index: integer): TChartSeries;
begin
  result := TChartSeries(inherited Items[index]);
end;

procedure TChartSeriesList.setItem(index: integer; value: TChartSeries);
begin
  inherited Items[index] := value;
end;

function TChartSeriesList.Add: TChartSeries;
begin
  result := TChartSeries(inherited Add);
end;

procedure TChartSeriesList.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TChartLite then TChartLite(Owner).Invalidate;
end;

{ TChartLite }

constructor TChartLite.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csSetCaption];
  FSeries := TChartSeriesList.Create(self, TChartSeries);
  FCategories := TStringList.Create;
  TStringList(FCategories).OnChange := @categoriesChanged;
  FShowGrid := true;
  FShowAxes := true;
  FShowDots := true;
  FShowCategories := true;
  FAutoRange := true;
  FShowPercent := true;
  FPadding := 8;
  FBarGap := 30;
  FLineWidth := 2;
  FGridLines := 5;
  FCornerRadius := 2;
  FDotSize := 6;
  FGridColor := clDefault;
  FAxisColor := clDefault;
  FTextColor := clDefault;
  FBackColor := clDefault;
  FAntialiasing := asTheme;
  FHot := -1;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TChartLite.Destroy;
begin
  FSeries.Free;
  FCategories.Free;
  inherited Destroy;
end;

class function TChartLite.GetControlClassDefaultSize: TSize;
begin
  result.cx := 280;
  result.cy := 180;
end;

function TChartLite.AddSeries(const title: string; const values: array of double; color: TColor): TChartSeries;
begin
  result := FSeries.Add;
  result.Title := title;
  result.Color := color;
  result.Values.BeginUpdate;
  try
    for var v in values do result.Add(v);
  finally
    result.Values.EndUpdate;
  end;
end;

procedure TChartLite.Clear;
begin
  FSeries.Clear;
  FCategories.Clear;
  Invalidate;
end;

// -- data ----------------------

function TChartLite.seriesColor(index: integer): TColor;
begin
  result := FSeries[index].Color;
  if result = clDefault then result := PALETTE[index mod length(PALETTE)];
  result := ColorToRGB(result);
end;

function TChartLite.pointCount: integer;
begin
  result := 0;
  for var i := 0 to FSeries.Count-1 do if FSeries[i].Visible then result := Max(result, FSeries[i].Count);
end;

// the lowest and the highest value shown, stacked bars summed, zero inside
procedure TChartLite.findRange(out low, high: double);
begin
  if not FAutoRange then begin
    low := FMinValue;
    high := FMaxValue;
    if high <= low then high := low+1;
    exit;
  end;
  low := 0;
  high := 0;
  var n := pointCount;
  for var p := 0 to n-1 do begin
    var up := 0.0;
    var down := 0.0;
    for var s := 0 to FSeries.Count-1 do begin
      if not FSeries[s].Visible or (p >= FSeries[s].Count) then continue;
      var v := FSeries[s][p];
      if FKind = ckStackedBars then begin
        if v >= 0 then up += v else down += v;
      end else begin
        up := Max(up, v);
        down := Min(down, v);
      end;
    end;
    high := Max(high, up);
    low := Min(low, down);
  end;
  if high = low then high := low+1;
  // a round top for the grid
  var span := high-low;
  var step := Power(10, Floor(Log10(span)));
  if span/step < 2 then step /= 5 else if span/step < 5 then step /= 2;
  high := Ceil(high/step)*step;
  low := Floor(low/step)*step;
end;

function TChartLite.valueText(series, index: integer; value: double): string;
begin
  var fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  result := if FValueFormat <> '' then Format(FValueFormat, [value], fs) else FloatToStrF(value, ffGeneral, 6, 2, fs);
  if Assigned(FOnValueText) then FOnValueText(self, series, index, value, result);
end;

function TChartLite.hitAt(x, y: integer): integer;
begin
  result := -1;
  for var i := high(FHits) downto 0 do begin
    var h := FHits[i];
    if h.sweep <> 0 then begin
      // a slice: inside the circle and inside its angle
      var cx := (h.rect.Left+h.rect.Right)/2;
      var cy := (h.rect.Top+h.rect.Bottom)/2;
      var r := h.rect.Width/2;
      var dx := x-cx;
      var dy := cy-y;
      var dist := Sqrt(dx*dx+dy*dy);
      if dist > r then continue;
      if (FKind = ckDonut) and (dist < r*0.55) then continue;
      var a := RadToDeg(ArcTan2(dy, dx));
      if a < 0 then a += 360;
      var from := h.angle-h.sweep; // clockwise from the start
      // the slice runs clockwise, so down in degrees
      var rel := h.angle-a;
      while rel < 0 do rel += 360;
      if rel <= h.sweep then exit(i);
    end else if PtInRect(h.rect, Point(x, y)) then exit(i);
  end;
end;

// -- painting ----------------------

procedure TChartLite.addText(x, y: integer; const text: string; color: TColor; bold: boolean);
begin
  SetLength(FTexts, length(FTexts)+1);
  FTexts[high(FTexts)].x := x;
  FTexts[high(FTexts)].y := y;
  FTexts[high(FTexts)].text := text;
  FTexts[high(FTexts)].color := color;
  FTexts[high(FTexts)].bold := bold;
end;

procedure TChartLite.paintLegend(sp: TSmoothPaint; var area: TRect);
begin
  if FLegend = lgNone then exit;
  var n := 0;
  var widest := 0;
  for var i := 0 to FSeries.Count-1 do if FSeries[i].Visible then begin
    inc(n);
    widest := Max(widest, textWidthOf(Font, FSeries[i].Title));
  end;
  if (FKind in [ckPie, ckDonut]) then begin
    n := FCategories.Count;
    widest := 0;
    for var i := 0 to n-1 do widest := Max(widest, textWidthOf(Font, FCategories[i]));
  end;
  if n = 0 then exit;
  var lh := lineHeightOf(Font)+scaled(self, 4);
  var box := scaled(self, 10);
  var pad := scaled(self, FPadding);
  var entryW := box+scaled(self, 6)+widest+scaled(self, 12);
  var legend: TRect;
  var columns: integer;
  if FLegend = lgRight then begin
    legend := Rect(area.Right-entryW, area.Top, area.Right, area.Bottom);
    area.Right := legend.Left-pad;
    columns := 1;
  end else begin
    columns := Max(Min(n, area.Width div Max(entryW, 1)), 1);
    var rows := (n+columns-1) div columns;
    if FLegend = lgBottom then begin
      legend := Rect(area.Left, area.Bottom-rows*lh, area.Right, area.Bottom);
      area.Bottom := legend.Top-pad;
    end else begin
      legend := Rect(area.Left, area.Top, area.Right, area.Top+rows*lh);
      area.Top := legend.Bottom+pad;
    end;
  end;
  var text := pick(FTextColor, clWindowText);
  var k := 0;
  var startX := if FLegend = lgRight then legend.Left else legend.Left+(legend.Width-columns*entryW) div 2;
  var count := if FKind in [ckPie, ckDonut] then FCategories.Count else FSeries.Count;
  for var i := 0 to count-1 do begin
    if not (FKind in [ckPie, ckDonut]) and not FSeries[i].Visible then continue;
    var x := startX+(k mod columns)*entryW;
    var y := legend.Top+(k div columns)*lh;
    var swatch := if FKind in [ckPie, ckDonut] then PALETTE[i mod length(PALETTE)] else seriesColor(i);
    paintRoundRect(sp, Rect(x, y+(lh-box) div 2, x+box, y+(lh+box) div 2), scaled(self, 2), swatch, clNone);
    var title := if FKind in [ckPie, ckDonut] then FCategories[i] else FSeries[i].Title;
    addText(x+box+scaled(self, 6), y+(lh-lineHeightOf(Font)) div 2, title, text, false);
    inc(k);
  end;
end;

procedure TChartLite.paintPie(sp: TSmoothPaint; const area: TRect);
begin
  // the first visible series makes the pie, its points the slices
  var s := -1;
  for var i := 0 to FSeries.Count-1 do if FSeries[i].Visible then begin s := i; break; end;
  if s < 0 then exit;
  var total := 0.0;
  for var p := 0 to FSeries[s].Count-1 do total += Max(FSeries[s][p], 0);
  if total <= 0 then exit;
  var size := Min(area.Width, area.Height);
  var box := Rect(area.Left+(area.Width-size) div 2, area.Top+(area.Height-size) div 2, 0, 0);
  box.Right := box.Left+size;
  box.Bottom := box.Top+size;
  var cx := (box.Left+box.Right)/2;
  var cy := (box.Top+box.Bottom)/2;
  var r := size/2-1;
  var angle := 90.0; // the top, clockwise from there
  var text := pick(FTextColor, clWindowText);
  var back := pick(FBackColor, GetRGBColorResolvingParent);
  for var p := 0 to FSeries[s].Count-1 do begin
    var v := Max(FSeries[s][p], 0);
    if v = 0 then continue;
    var sweep := 360*v/total;
    var fill := PALETTE[p mod length(PALETTE)];
    var hot := (FHot >= 0) and (FHot < length(FHits)) and (FHits[FHot].index = p);
    if hot then fill := blend(fill, clWhite, 20);
    // the slice as a polygon: the center and the arc
    var steps := Max(Round(sweep/4), 2);
    var poly: array of TPointF;
    SetLength(poly, steps+2);
    poly[0] := PointF(cx, cy);
    for var k := 0 to steps do begin
      var a := DegToRad(angle-sweep*k/steps);
      poly[k+1] := PointF(cx+r*Cos(a), cy-r*Sin(a));
    end;
    sp.FillPolygon(poly, fill);
    SetLength(FHits, length(FHits)+1);
    FHits[high(FHits)].series := s;
    FHits[high(FHits)].index := p;
    FHits[high(FHits)].rect := box;
    FHits[high(FHits)].angle := angle;
    FHits[high(FHits)].sweep := sweep;
    angle -= sweep;
  end;
  // a thin seam between the slices and the hole of the donut
  angle := 90;
  for var p := 0 to FSeries[s].Count-1 do begin
    var v := Max(FSeries[s][p], 0);
    if v = 0 then continue;
    var a := DegToRad(angle);
    paintLine(sp, Round(cx), Round(cy), Round(cx+r*Cos(a)), Round(cy-r*Sin(a)), back, 1);
    angle -= 360*v/total;
  end;
  if FKind = ckDonut then sp.FillEllipse(cx, cy, r*0.55, r*0.55, back);
  if not FShowValues then exit;
  // the share in the middle of every slice
  applyTextQuality(Canvas);
  angle := 90;
  for var p := 0 to FSeries[s].Count-1 do begin
    var v := Max(FSeries[s][p], 0);
    if v = 0 then continue;
    var sweep := 360*v/total;
    var a := DegToRad(angle-sweep/2);
    var dist := if FKind = ckDonut then r*0.78 else r*0.65;
    var label_ := if FShowPercent then Format('%d%%', [Round(100*v/total)]) else valueText(s, p, v);
    var w := Canvas.TextWidth(label_);
    var h := Canvas.TextHeight(label_);
    if sweep > 12 then addText(Round(cx+dist*Cos(a)-w/2), Round(cy-dist*Sin(a)-h/2), label_, contrastText(PALETTE[p mod length(PALETTE)]), false);
    angle -= sweep;
  end;
end;

// the series as polygons on spokes, one spoke per category
procedure TChartLite.paintRadar(sp: TSmoothPaint; const area: TRect);
begin
  var n := pointCount;
  if n < 3 then exit;
  var lo, hi: double;
  findRange(lo, hi);
  var back := pick(FBackColor, GetRGBColorResolvingParent);
  var size := Min(area.Width, area.Height);
  var cx := area.Left+area.Width/2;
  var cy := area.Top+area.Height/2;
  var r := size/2-lineHeightOf(Font)-scaled(self, 6);
  if r < 10 then exit;
  var grid := pick(FGridColor, blend(clBtnFace, clBtnShadow, 40));
  var text := pick(FTextColor, clWindowText);
  // the web: a ring per grid line and a spoke per category
  if FShowGrid then
    for var g := 1 to Max(FGridLines, 1) do sp.StrokePolyline(polygonOutline(cx, cy, r*g/Max(FGridLines, 1), n, 90), 1, grid, true);
  var axis := polygonOutline(cx, cy, r, n, 90);
  for var p := 0 to n-1 do paintLine(sp, Round(cx), Round(cy), Round(axis[p].x), Round(axis[p].y), grid, 1);
  for var s := 0 to FSeries.Count-1 do begin
    if not FSeries[s].Visible then continue;
    var pts: array of TPointF := [];
    for var p := 0 to n-1 do begin
      var v := if p < FSeries[s].Count then FSeries[s][p] else lo;
      var share := if hi > lo then (EnsureRange(v, lo, hi)-lo)/(hi-lo) else 0;
      pts += [PointF(cx+(axis[p].x-cx)*share, cy+(axis[p].y-cy)*share)];
    end;
    var line := seriesColor(s);
    sp.FillPolygon(pts, blend(line, back, 70));
    sp.StrokePolyline(pts, Max(scaled(self, FLineWidth), 1), line, true);
    if FShowDots then for var q in pts do paintCircle(sp, Round(q.x), Round(q.y), Max(scaled(self, FDotSize) div 2, 2), line, clNone);
  end;
  // the category names just outside the web
  if FShowCategories then
    for var p := 0 to Min(n, FCategories.Count)-1 do begin
      var w := Canvas.TextWidth(FCategories[p]);
      var h := lineHeightOf(Font);
      addText(Round(axis[p].x+(axis[p].x-cx)*0.14-w/2), Round(axis[p].y+(axis[p].y-cy)*0.14-h/2), FCategories[p], text, false);
    end;
end;

procedure TChartLite.paintAxes(sp: TSmoothPaint; const area: TRect; low, high: double);
begin
  var grid := pick(FGridColor, blend(GetRGBColorResolvingParent, clWindowText, 12));
  var axis := pick(FAxisColor, blend(GetRGBColorResolvingParent, clWindowText, 40));
  if FShowGrid then for var g := 0 to FGridLines do begin
    var y := area.Bottom-Round(area.Height*g/Max(FGridLines, 1));
    sp.FillRect(Rect(area.Left, y, area.Right, y+1), grid);
  end;
  if FShowAxes then begin
    sp.FillRect(Rect(area.Left, area.Top, area.Left+1, area.Bottom), axis);
    sp.FillRect(Rect(area.Left, area.Bottom-1, area.Right, area.Bottom), axis);
    // the zero line when the range crosses it
    if (low < 0) and (high > 0) then begin
      var y := area.Bottom-Round(area.Height*(0-low)/(high-low));
      sp.FillRect(Rect(area.Left, y, area.Right, y+1), axis);
    end;
  end;
end;

procedure TChartLite.paintTexts;
begin
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  for var job in FTexts do begin
    Canvas.Font.Style := if job.bold then Font.Style+[fsBold] else Font.Style;
    Canvas.Font.Color := job.color;
    Canvas.TextOut(job.x, job.y, job.text);
  end;
  Canvas.Font.Style := Font.Style;
  FTexts := nil;
end;

procedure TChartLite.Paint;
begin
  var back := pick(FBackColor, GetRGBColorResolvingParent);
  var text := pick(FTextColor, clWindowText);
  var pad := scaled(self, FPadding);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  FHits := nil;
  FTexts := nil;
  var area := ClientRect;
  area.Inflate(-pad, -pad);
  var lh := lineHeightOf(Font);
  applyTextQuality(Canvas);
  if FTitle <> '' then begin
    Canvas.Font.Style := Font.Style+[fsBold];
    addText(area.Left+(area.Width-Canvas.TextWidth(FTitle)) div 2, area.Top, FTitle, text, true);
    Canvas.Font.Style := Font.Style;
    area.Top += lh+scaled(self, 6);
  end;
  paintLegend(sp, area);
  if FKind in [ckPie, ckDonut] then begin
    paintPie(sp, area);
    sp.Flush;
    paintTexts;
    exit;
  end;
  if FKind = ckRadar then begin
    paintRadar(sp, area);
    sp.Flush;
    paintTexts;
    exit;
  end;

  var lo, hi: double;
  findRange(lo, hi);
  // room for the value labels on the left and the categories below
  applyTextQuality(Canvas);
  if FShowAxes then begin
    var widest := Max(Canvas.TextWidth(valueText(-1, -1, hi)), Canvas.TextWidth(valueText(-1, -1, lo)));
    area.Left += widest+scaled(self, 6);
  end;
  if FShowCategories and (FCategories.Count > 0) then area.Bottom -= lh+scaled(self, 4);
  if (area.Width < 10) or (area.Height < 10) then exit;
  paintAxes(sp, area, lo, hi);

  var n := pointCount;
  var span := hi-lo;
  var visible := 0;
  for var s := 0 to FSeries.Count-1 do if FSeries[s].Visible then inc(visible);
  if (n > 0) and (visible > 0) then begin
    var slot := area.Width/n;
    var yOf := function(v: double): integer
    begin
      result := area.Bottom-1-Round((area.Height-2)*(EnsureRange(v, lo, hi)-lo)/span);
    end;
    var zeroY := yOf(0);
    match FKind of
      ckBars, ckStackedBars: begin
        var gap := slot*FBarGap/100;
        var barsPerSlot := if FKind = ckBars then visible else 1;
        var barW := Max((slot-gap)/barsPerSlot, 1);
        for var p := 0 to n-1 do begin
          var k := 0;
          var upTop := 0.0;
          var downTop := 0.0;
          for var s := 0 to FSeries.Count-1 do begin
            if not FSeries[s].Visible then continue;
            var v := if p < FSeries[s].Count then FSeries[s][p] else 0;
            var x1, y1, y2: integer;
            if FKind = ckBars then begin
              x1 := area.Left+Round(p*slot+gap/2+k*barW);
              y1 := yOf(v);
              y2 := zeroY;
            end else begin
              x1 := area.Left+Round(p*slot+gap/2);
              if v >= 0 then begin
                y1 := yOf(upTop+v);
                y2 := yOf(upTop);
                upTop += v;
              end else begin
                y1 := yOf(downTop);
                y2 := yOf(downTop+v);
                downTop += v;
              end;
            end;
            var r := Rect(x1, Min(y1, y2), x1+Round(barW)-(if FKind = ckBars then 1 else 0), Max(y1, y2)+1);
            if r.Height < 2 then r.Bottom := r.Top+2;
            var fill := seriesColor(s);
            if (FHot >= 0) and (FHot < length(FHits)) and (FHits[FHot].series = s) and (FHits[FHot].index = p) then fill := blend(fill, clWhite, 20);
            paintRoundRect(sp, r, scaled(self, FCornerRadius), fill, clNone);
            SetLength(FHits, length(FHits)+1);
            FHits[high(FHits)] := Default(THit);
            FHits[high(FHits)].series := s;
            FHits[high(FHits)].index := p;
            FHits[high(FHits)].rect := r;
            inc(k);
          end;
        end;
      end;
      ckLines, ckArea, ckStackedArea, ckDots, ckSteps: begin
        // the stacked areas pile up on the base of the series before
        var base: array of double := [];
        SetLength(base, n);
        for var s := 0 to FSeries.Count-1 do begin
          if not FSeries[s].Visible or (FSeries[s].Count = 0) then continue;
          var m := FSeries[s].Count;
          var pts: array of TPointF;
          SetLength(pts, m);
          for var p := 0 to m-1 do pts[p] := PointF(area.Left+p*slot+slot/2, yOf(FSeries[s][p]+(if FKind = ckStackedArea then base[p] else 0))+0.5);
          var line := seriesColor(s);
          if FKind in [ckArea, ckStackedArea] then begin
            var poly: array of TPointF;
            SetLength(poly, m*2);
            for var p := 0 to m-1 do poly[p] := pts[p];
            for var p := 0 to m-1 do poly[m+p] := PointF(pts[m-1-p].X, (if FKind = ckStackedArea then yOf(base[m-1-p]) else zeroY)+0.5);
            sp.FillPolygon(poly, blend(line, back, (if FKind = ckStackedArea then 35 else 65)));
          end;
          if FKind = ckStackedArea then for var p := 0 to m-1 do base[p] += FSeries[s][p];
          if (m > 1) and (FKind <> ckDots) then begin
            // a step holds each value until the next one
            var path: array of TPointF := [];
            for var p := 0 to m-1 do begin
              if (FKind = ckSteps) and (p > 0) then path += [PointF(pts[p].X, pts[p-1].Y)];
              path += [pts[p]];
            end;
            sp.StrokePolyline(path, Max(scaled(self, FLineWidth), 1), line);
          end;
          var rad := Max(scaled(self, FDotSize) div 2, 2);
          for var p := 0 to m-1 do begin
            var hot := (FHot >= 0) and (FHot < length(FHits)) and (FHits[FHot].series = s) and (FHits[FHot].index = p);
            if FShowDots or hot or (FKind = ckDots) then paintCircle(sp, Round(pts[p].X), Round(pts[p].Y), (if hot then rad+1 else rad), (if hot or (FKind = ckDots) then line else back), line, Max(scaled(self, FLineWidth), 1));
            SetLength(FHits, length(FHits)+1);
            FHits[high(FHits)] := Default(THit);
            FHits[high(FHits)].series := s;
            FHits[high(FHits)].index := p;
            FHits[high(FHits)].rect := Rect(Round(pts[p].X)-rad-2, Round(pts[p].Y)-rad-2, Round(pts[p].X)+rad+3, Round(pts[p].Y)+rad+3);
          end;
        end;
      end;
    end;
  end;
  sp.Flush;
  paintTexts;

  // the labels
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := text;
  if FShowAxes then for var g := 0 to FGridLines do begin
    var y := area.Bottom-Round(area.Height*g/Max(FGridLines, 1));
    var s := valueText(-1, -1, lo+span*g/Max(FGridLines, 1));
    Canvas.TextOut(area.Left-Canvas.TextWidth(s)-scaled(self, 4), y-lh div 2, s);
  end;
  if FShowCategories and (n > 0) then begin
    var slot := area.Width/n;
    for var p := 0 to Min(n, FCategories.Count)-1 do begin
      var s := FCategories[p];
      var w := Canvas.TextWidth(s);
      if w > slot then continue;
      Canvas.TextOut(area.Left+Round(p*slot+(slot-w)/2), area.Bottom+scaled(self, 2), s);
    end;
  end;
  if FShowValues then for var h in FHits do begin
    var s := valueText(h.series, h.index, FSeries[h.series][h.index]);
    var w := Canvas.TextWidth(s);
    var x := (h.rect.Left+h.rect.Right-w) div 2;
    var y := h.rect.Top-lh-scaled(self, 1);
    // no room over a bar: the value sits inside it, under its top
    var inside := (y < area.Top) and (FKind in [ckBars, ckStackedBars]);
    if inside then y := h.rect.Top+scaled(self, 1)
    else if y < area.Top then y := h.rect.Bottom+scaled(self, 1);
    Canvas.Font.Color := if inside then contrastText(seriesColor(h.series)) else text;
    Canvas.TextOut(x, y, s);
  end;
end;

// -- input ----------------------

procedure TChartLite.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := hitAt(X, Y);
  if hot = FHot then exit;
  FHot := hot;
  Invalidate;
  if Assigned(FOnPointHover) then
    if hot >= 0 then FOnPointHover(self, FHits[hot].series, FHits[hot].index) else FOnPointHover(self, -1, -1);
end;

procedure TChartLite.MouseLeave;
begin
  inherited MouseLeave;
  if FHot < 0 then exit;
  FHot := -1;
  Invalidate;
  if Assigned(FOnPointHover) then FOnPointHover(self, -1, -1);
end;

procedure TChartLite.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var hit := hitAt(X, Y);
  if (hit >= 0) and Assigned(FOnPointClick) then FOnPointClick(self, FHits[hit].series, FHits[hit].index);
end;

// -- properties ----------------------

procedure TChartLite.categoriesChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TChartLite.setSeries(value: TChartSeriesList);
begin
  FSeries.Assign(value);
  Invalidate;
end;

procedure TChartLite.setCategories(value: TStrings);
begin
  FCategories.Assign(value);
end;

procedure TChartLite.setKind(value: TChartKind);
begin
  if FKind = value then exit;
  FKind := value;
  FHot := -1;
  Invalidate;
end;

procedure TChartLite.setLegend(value: TChartLegend);
begin
  if FLegend = value then exit;
  FLegend := value;
  Invalidate;
end;

procedure TChartLite.setTitle(const value: string);
begin
  if FTitle = value then exit;
  FTitle := value;
  Invalidate;
end;

function TChartLite.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowGrid;
    1: FShowValues;
    2: FShowAxes;
    3: FShowDots;
    4: FShowCategories;
    5: FAutoRange;
  else
    FShowPercent
  end;
end;

procedure TChartLite.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowGrid := value;
    1: FShowValues := value;
    2: FShowAxes := value;
    3: FShowDots := value;
    4: FShowCategories := value;
    5: FAutoRange := value;
  else
    FShowPercent := value;
  end;
  Invalidate;
end;

function TChartLite.getRange(index: integer): double;
begin
  result := if index = 0 then FMinValue else FMaxValue;
end;

procedure TChartLite.setRange(index: integer; value: double);
begin
  if index = 0 then FMinValue := value else FMaxValue := value;
  Invalidate;
end;

function TChartLite.getMetric(index: integer): integer;
begin
  result := match index of
    0: FPadding;
    1: FBarGap;
    2: FLineWidth;
    3: FGridLines;
    4: FCornerRadius;
  else
    FDotSize
  end;
end;

procedure TChartLite.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 1 then value := Min(value, 90);
  if index = 3 then value := Max(value, 1);
  if getMetric(index) = value then exit;
  match index of
    0: FPadding := value;
    1: FBarGap := value;
    2: FLineWidth := value;
    3: FGridLines := value;
    4: FCornerRadius := value;
  else
    FDotSize := value;
  end;
  Invalidate;
end;

procedure TChartLite.setValueFormat(const value: string);
begin
  if FValueFormat = value then exit;
  FValueFormat := value;
  Invalidate;
end;

function TChartLite.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FGridColor;
    1: FAxisColor;
    2: FTextColor;
  else
    FBackColor
  end;
end;

procedure TChartLite.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FGridColor := value;
    1: FAxisColor := value;
    2: FTextColor := value;
  else
    FBackColor := value;
  end;
  Invalidate;
end;

procedure TChartLite.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
