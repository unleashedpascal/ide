{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit StatCard;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ImgList, ControlPaint, Sparkline;

type
  { TStatCard }

  // a card with one figure: a title, the value in large type, its change
  // with an arrow, a line under it and a small chart of the trend
  TStatCard = class(TGraphicControl)
  private
    FValue, FFooter, FDeltaFormat: string;
    FDelta: double;
    FTrend: TStringList;
    FPoints: array of double;
    FTrendStyle: TSparklineStyle;
    FShowDelta, FShowTrend, FInvertDelta, FShadow: boolean;
    FValueSize, FCornerRadius, FPadding, FShadowSize, FTrendHeight, FMaxTrendPoints: integer;
    FCardColor, FBorderColor, FTitleColor, FValueColor, FUpColor, FDownColor, FTrendColor: TColor;
    FImages: TCustomImageList;
    FImageIndex: TImageIndex;
    FImagesWidth: integer;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setDelta(value: double);
    procedure setTrend(value: TStrings);
    function getTrend: TStrings;
    procedure trendChanged(Sender: TObject);
    procedure setTrendStyle(value: TSparklineStyle);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setImages(value: TCustomImageList);
    procedure setImageIndex(value: TImageIndex);
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    function deltaText: string;
    function hasTrend: boolean;
    procedure valueFont(target: TFont);
    procedure changed;
  protected
    procedure Paint; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // appends a point to the trend; past MaxTrendPoints the oldest goes
    procedure AddTrendValue(value: double);
    procedure SetTrendValues(const values: array of double);
    function TrendCount: integer;
  published
    // the title over the value
    property Caption;
    // the figure, formatted as it shows
    property Value: string index 0 read getText write setText;
    // the line under the change, as `vs last month`
    property Footer: string index 1 read getText write setText;
    // the format of the change; the arrow carries the sign
    property DeltaFormat: string index 2 read getText write setText;
    // the change: above zero an up arrow, below it a down arrow
    property Delta: double read FDelta write setDelta;
    property ShowDelta: boolean index 0 read getFlag write setFlag default true;
    // a fall is good news: down shows in the up color
    property InvertDelta: boolean index 1 read getFlag write setFlag default false;
    property ShowTrend: boolean index 2 read getFlag write setFlag default true;
    property Shadow: boolean index 3 read getFlag write setFlag default true;
    // the points of the trend chart, one number per line with a `.` decimal point
    property Trend: TStrings read getTrend write setTrend;
    property TrendStyle: TSparklineStyle read FTrendStyle write setTrendStyle default ssArea;
    // the size of the value in points; 0 is twice the font
    property ValueSize: integer index 0 read getMetric write setMetric default 0;
    property CornerRadius: integer index 1 read getMetric write setMetric default 8;
    property Padding: integer index 2 read getMetric write setMetric default 12;
    property ShadowSize: integer index 3 read getMetric write setMetric default 4;
    // the height of the chart; 0 takes the room left
    property TrendHeight: integer index 4 read getMetric write setMetric default 0;
    // 0 keeps every point
    property MaxTrendPoints: integer index 5 read getMetric write setMetric default 30;
    // an icon in the top right corner
    property Images: TCustomImageList read FImages write setImages;
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    property ImagesWidth: integer index 6 read getMetric write setMetric default 0;
    // clDefault takes the colors of the theme
    property CardColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property ValueColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property UpColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property DownColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property TrendColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property Align;
    property Anchors;
    property AutoSize;
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
    property OnContextPopup;
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

var
  pointFormat: TFormatSettings;

constructor TStatCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csSetCaption, csOpaque];
  FTrend := TStringList.Create;
  FTrend.OnChange := @trendChanged;
  FValue := '0';
  FDeltaFormat := '%.1f%%';
  FTrendStyle := ssArea;
  FShowDelta := true;
  FShowTrend := true;
  FShadow := true;
  FCornerRadius := 8;
  FPadding := 12;
  FShadowSize := 4;
  FMaxTrendPoints := 30;
  FImageIndex := -1;
  FCardColor := clDefault;
  FBorderColor := clDefault;
  FTitleColor := clDefault;
  FValueColor := clDefault;
  FUpColor := clDefault;
  FDownColor := clDefault;
  FTrendColor := clDefault;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TStatCard.Destroy;
begin
  FTrend.OnChange := nil;
  FTrend.Free;
  inherited Destroy;
end;

class function TStatCard.GetControlClassDefaultSize: TSize;
begin
  result.cx := 220;
  result.cy := 140;
end;

// -- data ----------------------

procedure TStatCard.trendChanged(Sender: TObject);
begin
  FPoints := [];
  for var line in FTrend do begin
    var v: double;
    if TryStrToFloat(Trim(StringReplace(line, ',', '.', [])), v, pointFormat) then FPoints += [v];
  end;
  changed;
end;

procedure TStatCard.AddTrendValue(value: double);
begin
  FTrend.BeginUpdate;
  try
    FTrend.Add(FloatToStr(value, pointFormat));
    if FMaxTrendPoints > 0 then
      while FTrend.Count > FMaxTrendPoints do FTrend.Delete(0);
  finally
    FTrend.EndUpdate;
  end;
end;

procedure TStatCard.SetTrendValues(const values: array of double);
begin
  FTrend.BeginUpdate;
  try
    FTrend.Clear;
    for var v in values do FTrend.Add(FloatToStr(v, pointFormat));
    if FMaxTrendPoints > 0 then
      while FTrend.Count > FMaxTrendPoints do FTrend.Delete(0);
  finally
    FTrend.EndUpdate;
  end;
end;

function TStatCard.TrendCount: integer;
begin
  result := length(FPoints);
end;

function TStatCard.hasTrend: boolean;
begin
  result := FShowTrend and (length(FPoints) >= 2);
end;

function TStatCard.deltaText: string;
begin
  try
    result := Format(FDeltaFormat, [Abs(FDelta)], formatSettingsOf(FLanguage));
  except
    on EConvertError do result := FloatToStr(Abs(FDelta), formatSettingsOf(FLanguage));
  end;
end;

procedure TStatCard.valueFont(target: TFont);
begin
  target.Assign(Font);
  target.Style := Font.Style+[fsBold];
  if FValueSize > 0 then target.Size := FValueSize
  else target.Height := -Abs(Canvas.TextHeight('Hg'))*2;
end;

// -- layout and painting ----------------------

procedure TStatCard.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var pad := scaled(self, FPadding);
  var shadow := if FShadow then scaled(self, FShadowSize) else 0;
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  var w := Canvas.TextWidth(Caption);
  if FShowDelta or (FFooter <> '') then w := Max(w, th+Canvas.TextWidth(deltaText+'  '+FFooter));
  var big := autofree TFont.Create;
  valueFont(big);
  Canvas.Font := big;
  w := Max(w, Canvas.TextWidth(FValue));
  var h := th+scaled(self, 4)+Canvas.TextHeight('Hg');
  Canvas.Font := Font;
  if FShowDelta or (FFooter <> '') then h += scaled(self, 6)+th;
  if hasTrend then h += scaled(self, 8)+(if FTrendHeight > 0 then scaled(self, FTrendHeight) else th*2);
  PreferredWidth := w+2*pad+shadow;
  PreferredHeight := h+2*pad+shadow;
end;

procedure TStatCard.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var card := pick(FCardColor, blend(clWindow, clBtnFace, 30));
  var border := pick(FBorderColor, blend(clBtnFace, clBtnShadow, 50));
  var dark := isDark(card);
  var up := pick(FUpColor, if dark then RGBToColor(102, 187, 106) else RGBToColor(46, 125, 50));
  var down := pick(FDownColor, if dark then RGBToColor(239, 83, 80) else RGBToColor(198, 40, 40));
  var good := (FDelta > 0) <> FInvertDelta;
  var deltaColor := if FDelta = 0 then ColorToRGB(clGrayText) else (if good then up else down);
  var trendColor := pick(FTrendColor, clHighlight);
  var title := pick(FTitleColor, blend(card, clWindowText, 65));
  var valueColor := pick(FValueColor, clWindowText);
  if not Enabled then begin
    title := ColorToRGB(clGrayText);
    valueColor := title;
    deltaColor := title;
    trendColor := blend(trendColor, card, 50);
  end;
  var radius := scaled(self, FCornerRadius);
  var shadow := if FShadow then scaled(self, FShadowSize) else 0;
  var pad := scaled(self, FPadding);
  var body := Rect(0, 0, ClientWidth-shadow, ClientHeight-shadow);
  var inner := body;
  inner.Inflate(-pad, -pad);

  // the rows from the top; the chart takes the room left at the bottom
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  var big := autofree TFont.Create;
  valueFont(big);
  Canvas.Font := big;
  var vh := Canvas.TextHeight('Hg');
  Canvas.Font := Font;
  var titleRow := Rect(inner.Left, inner.Top, inner.Right, inner.Top+th);
  var valueRow := Rect(inner.Left, titleRow.Bottom+scaled(self, 4), inner.Right, titleRow.Bottom+scaled(self, 4)+vh);
  var hasDeltaRow := FShowDelta or (FFooter <> '');
  var deltaRow := Rect(inner.Left, valueRow.Bottom+scaled(self, 6), inner.Right, valueRow.Bottom+scaled(self, 6)+(if hasDeltaRow then th else 0));
  var chart := Rect(inner.Left, deltaRow.Bottom+scaled(self, 8), inner.Right, inner.Bottom);
  if FTrendHeight > 0 then chart.Top := Max(chart.Top, chart.Bottom-scaled(self, FTrendHeight));

  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  // the shadow: rings of the card shape fading out behind it
  for var i := shadow downto 1 do begin
    var r := body;
    OffsetRect(r, i div 2+1, i div 2+1);
    r.Inflate(i div 2, i div 2);
    paintRoundRect(sp, r, radius+i div 2, blend(back, clBlack, 18-i*16 div Max(shadow, 1)), clNone);
  end;
  paintRoundRect(sp, body, radius, card, border);

  // the arrow of the change
  var arrowSize := th*6 div 10;
  if FShowDelta then begin
    var ax := deltaRow.Left;
    var ay := deltaRow.Top+(th-arrowSize) div 2;
    if FDelta > 0 then sp.FillPolygon([PointF(ax, ay+arrowSize), PointF(ax+arrowSize/2, ay), PointF(ax+arrowSize, ay+arrowSize)], deltaColor)
    else if FDelta < 0 then sp.FillPolygon([PointF(ax, ay), PointF(ax+arrowSize, ay), PointF(ax+arrowSize/2, ay+arrowSize)], deltaColor)
    else paintLine(sp, ax, ay+arrowSize div 2, ax+arrowSize, ay+arrowSize div 2, deltaColor, Max(scaled(self, 2), 1));
  end;

  // the trend: the lowest point at the bottom, the highest at the top
  if hasTrend and (chart.Height >= 8) then begin
    var lo := MinValue(FPoints);
    var hi := MaxValue(FPoints);
    if hi = lo then begin
      hi += 1;
      lo -= 1;
    end;
    var n := length(FPoints);
    var lw := Max(scaled(self, 2), 1);
    var top := chart.Top+lw;
    var bottom := chart.Bottom-lw;
    var yOf := function(v: double): integer
    begin
      result := bottom-Round((v-lo)/(hi-lo)*(bottom-top));
    end;
    if FTrendStyle = ssBars then begin
      var slot := chart.Width/n;
      for var i := 0 to n-1 do begin
        var x1 := chart.Left+Round(i*slot+slot*0.15);
        var x2 := chart.Left+Round((i+1)*slot-slot*0.15);
        paintRoundRect(sp, Rect(x1, yOf(FPoints[i]), Max(x2, x1+1), chart.Bottom), Min(scaled(self, 2), (x2-x1) div 2), (if i = n-1 then trendColor else blend(card, trendColor, 55)), clNone);
      end;
    end else begin
      var xOf := function(i: integer): integer
      begin
        result := chart.Left+lw+Round(i*(chart.Width-2*lw)/(n-1));
      end;
      if FTrendStyle = ssArea then begin
        var area: array of TPointF := [];
        area += [PointF(xOf(0), chart.Bottom)];
        for var i := 0 to n-1 do area += [PointF(xOf(i), yOf(FPoints[i]))];
        area += [PointF(xOf(n-1), chart.Bottom)];
        var fill := blend(card, trendColor, 22);
        sp.FillPolygon(area, fill);
      end;
      for var i := 1 to n-1 do paintLine(sp, xOf(i-1), yOf(FPoints[i-1]), xOf(i), yOf(FPoints[i]), trendColor, lw);
      paintCircle(sp, xOf(n-1), yOf(FPoints[n-1]), lw+1, trendColor, clNone);
    end;
  end;
  sp.Flush;

  // the texts and the icon go on natively
  applyTextQuality(Canvas);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  Canvas.Brush.Style := bsClear;
  var iconRoom := 0;
  if (FImages <> nil) and (FImageIndex >= 0) and (FImageIndex < FImages.Count) then begin
    var res := FImages.ResolutionForControl[FImagesWidth, self];
    iconRoom := res.Width+scaled(self, 6);
    res.Draw(Canvas, inner.Right-res.Width, inner.Top, FImageIndex, Enabled);
  end;
  Canvas.Font := Font;
  Canvas.Font.Color := title;
  var r := titleRow;
  r.Right -= iconRoom;
  Canvas.TextRect(r, r.Left, r.Top, Caption, style);
  Canvas.Font := big;
  Canvas.Font.Color := valueColor;
  r := valueRow;
  if iconRoom > 0 then r.Right -= Max(iconRoom-(valueRow.Top-titleRow.Top), 0);
  Canvas.TextRect(r, r.Left, r.Top, FValue, style);
  Canvas.Font := Font;
  if hasDeltaRow then begin
    var x := deltaRow.Left;
    if FShowDelta then begin
      x += arrowSize+scaled(self, 4);
      var dt := deltaText;
      Canvas.Font.Style := Font.Style+[fsBold];
      Canvas.Font.Color := deltaColor;
      r := Rect(x, deltaRow.Top, deltaRow.Right, deltaRow.Bottom);
      Canvas.TextRect(r, r.Left, r.Top, dt, style);
      x += Canvas.TextWidth(dt)+scaled(self, 6);
      Canvas.Font.Style := Font.Style;
    end;
    if FFooter <> '' then begin
      Canvas.Font.Color := title;
      r := Rect(x, deltaRow.Top, deltaRow.Right, deltaRow.Bottom);
      Canvas.TextRect(r, r.Left, r.Top, FFooter, style);
    end;
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- properties ----------------------

procedure TStatCard.changed;
begin
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

procedure TStatCard.TextChanged;
begin
  inherited TextChanged;
  changed;
end;

procedure TStatCard.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  changed;
end;

procedure TStatCard.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then begin
    FImages := nil;
    Invalidate;
  end;
end;

function TStatCard.getText(index: integer): string;
begin
  result := match index of
    0: FValue;
    1: FFooter;
  else
    FDeltaFormat
  end;
end;

procedure TStatCard.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FValue := value;
    1: FFooter := value;
  else
    FDeltaFormat := value;
  end;
  changed;
end;

procedure TStatCard.setDelta(value: double);
begin
  if FDelta = value then exit;
  FDelta := value;
  changed;
end;

function TStatCard.getTrend: TStrings;
begin
  result := FTrend;
end;

procedure TStatCard.setTrend(value: TStrings);
begin
  FTrend.Assign(value);
end;

procedure TStatCard.setTrendStyle(value: TSparklineStyle);
begin
  if FTrendStyle = value then exit;
  FTrendStyle := value;
  Invalidate;
end;

function TStatCard.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowDelta;
    1: FInvertDelta;
    2: FShowTrend;
  else
    FShadow
  end;
end;

procedure TStatCard.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowDelta := value;
    1: FInvertDelta := value;
    2: FShowTrend := value;
  else
    FShadow := value;
  end;
  changed;
end;

function TStatCard.getMetric(index: integer): integer;
begin
  result := match index of
    0: FValueSize;
    1: FCornerRadius;
    2: FPadding;
    3: FShadowSize;
    4: FTrendHeight;
    5: FMaxTrendPoints;
  else
    FImagesWidth
  end;
end;

procedure TStatCard.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FValueSize := value;
    1: FCornerRadius := value;
    2: FPadding := value;
    3: FShadowSize := value;
    4: FTrendHeight := value;
    5: begin
      FMaxTrendPoints := value;
      if value > 0 then begin
        FTrend.BeginUpdate;
        while FTrend.Count > value do FTrend.Delete(0);
        FTrend.EndUpdate;
      end;
    end;
  else
    FImagesWidth := value;
  end;
  changed;
end;

function TStatCard.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FCardColor;
    1: FBorderColor;
    2: FTitleColor;
    3: FValueColor;
    4: FUpColor;
    5: FDownColor;
  else
    FTrendColor
  end;
end;

procedure TStatCard.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FCardColor := value;
    1: FBorderColor := value;
    2: FTitleColor := value;
    3: FValueColor := value;
    4: FUpColor := value;
    5: FDownColor := value;
  else
    FTrendColor := value;
  end;
  Invalidate;
end;

procedure TStatCard.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  changed;
end;

procedure TStatCard.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Invalidate;
end;

procedure TStatCard.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TStatCard.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

initialization
  pointFormat := DefaultFormatSettings;
  pointFormat.DecimalSeparator := '.';
  pointFormat.ThousandSeparator := #0;
end.
