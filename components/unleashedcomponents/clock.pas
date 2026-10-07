{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Clock;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  TClockMode = (cmAnalog, cmDigital);
  TClockNumerals = (cnNone, cnQuarters, cnAll);
  // the face: classic ticks and hands, a bare minimal face, bold hands and
  // ticks, or dots for the ticks
  TClockStyle = (csClassic, csMinimal, csBold, csDotted);

  { TClock }

  // a clock face or a digital readout. Live follows the system time, with
  // an offset in minutes for another zone; off, it shows Time
  TClock = class(TGraphicControl)
  private
    FTimer: TTimer;
    FMode: TClockMode;
    FTime: TDateTime;
    FLive, FShowSeconds, FShowDate, FShowTicks, FSmoothSeconds, FTwentyFourHours: boolean;
    FOffsetMinutes: integer;
    FNumerals: TClockNumerals;
    FDigitalFormat, FDateFormat: string;
    FFaceColor, FBorderColor, FHourColor, FMinuteColor, FSecondColor, FTickColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FStyle: TClockStyle;
    FLanguage: TFormatLanguage;
    FOnTick: TNotifyEvent;
    procedure setMode(value: TClockMode);
    procedure setTime(value: TDateTime);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setOffset(value: integer);
    procedure setNumerals(value: TClockNumerals);
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setStyle(value: TClockStyle);
    procedure setLanguage(value: TFormatLanguage);
    procedure tick(Sender: TObject);
    procedure syncTimer;
    function timeStored: boolean;
  protected
    procedure Paint; override;
    procedure VisibleChanged; override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the time on the face: the system time with the offset when Live
    function Shown: TDateTime;
  published
    property Mode: TClockMode read FMode write setMode default cmAnalog;
    // the time shown while not Live
    property Time: TDateTime read FTime write setTime stored timeStored;
    property Live: boolean index 0 read getFlag write setFlag default true;
    property ShowSeconds: boolean index 1 read getFlag write setFlag default true;
    // the date under the digital readout
    property ShowDate: boolean index 2 read getFlag write setFlag default false;
    property ShowTicks: boolean index 3 read getFlag write setFlag default true;
    // the second hand sweeps instead of stepping
    property SmoothSeconds: boolean index 4 read getFlag write setFlag default false;
    property TwentyFourHours: boolean index 5 read getFlag write setFlag default true;
    // minutes added to the system time when Live
    property OffsetMinutes: integer read FOffsetMinutes write setOffset default 0;
    property Numerals: TClockNumerals read FNumerals write setNumerals default cnQuarters;
    // FormatDateTime patterns; empty takes hh:nn:ss and the long date
    property DigitalFormat: string index 0 read getText write setText;
    property DateFormat: string index 1 read getText write setText;
    // clDefault takes the colors of the theme
    property FaceColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property HourColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property MinuteColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property SecondColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property TickColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property Style: TClockStyle read FStyle write setStyle default csClassic;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    // every second while Live
    property OnTick: TNotifyEvent read FOnTick write FOnTick;
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
  Math, DateUtils;

constructor TClock.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle-[csOpaque, csSetCaption];
  FMode := cmAnalog;
  FLive := true;
  FShowSeconds := true;
  FShowTicks := true;
  FTwentyFourHours := true;
  FNumerals := cnQuarters;
  FFaceColor := clDefault;
  FBorderColor := clDefault;
  FHourColor := clDefault;
  FMinuteColor := clDefault;
  FSecondColor := clDefault;
  FTickColor := clDefault;
  FTime := EncodeTime(10, 10, 30, 0);
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TClock.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

class function TClock.GetControlClassDefaultSize: TSize;
begin
  result.cx := 100;
  result.cy := 100;
end;

procedure TClock.Loaded;
begin
  inherited Loaded;
  syncTimer;
end;

function TClock.timeStored: boolean;
begin
  result := not FLive;
end;

function TClock.Shown: TDateTime;
begin
  result := if FLive then IncMinute(Now, FOffsetMinutes) else FTime;
end;

// -- painting ----------------------

procedure TClock.Paint;
begin
  var face := pick(FFaceColor, clWindow);
  var border := pick(FBorderColor, clBtnShadow);
  var hourColor := pick(FHourColor, clWindowText);
  var minuteColor := pick(FMinuteColor, clWindowText);
  var secondColor := pick(FSecondColor, clHighlight);
  var tickColor := pick(FTickColor, clGrayText);
  var textColor := ColorToRGB(if Enabled then clWindowText else clGrayText);
  var t := Shown;
  var h, m, s, ms: word;
  DecodeTime(t, h, m, s, ms);
  if FMode = cmDigital then begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := GetRGBColorResolvingParent;
    Canvas.FillRect(ClientRect);
    applyTextQuality(Canvas);
    var fmt := FDigitalFormat;
    if fmt = '' then fmt := (if FTwentyFourHours then 'hh:nn' else 'h:nn')+(if FShowSeconds then ':ss' else '')+(if FTwentyFourHours then '' else ' am/pm');
    var text := FormatDateTime(fmt, t, formatSettingsOf(FLanguage));
    var th := Canvas.TextHeight(text);
    if FShowDate then begin
      var dfmt := if FDateFormat = '' then 'dddd, d mmmm yyyy' else FDateFormat;
      var dateText := FormatDateTime(dfmt, t, formatSettingsOf(FLanguage));
      var dh := Canvas.TextHeight(dateText);
      var top := (ClientHeight-th-dh) div 2;
      paintCenteredText(Canvas, Rect(0, top, ClientWidth, top+th), text, textColor);
      paintCenteredText(Canvas, Rect(0, top+th, ClientWidth, top+th+dh), dateText, ColorToRGB(clGrayText));
    end else paintCenteredText(Canvas, ClientRect, text, textColor);
    exit;
  end;

  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var size := Math.Min(ClientWidth, ClientHeight);
  var cx := ClientWidth div 2;
  var cy := ClientHeight div 2;
  var radius := size div 2-2;
  if radius < 6 then exit;
  paintCircle(sp, cx, cy, radius, face, (if FStyle = csMinimal then clNone else border));
  // the weight of the hands and the ticks after the style
  var heavy := if FStyle = csBold then 2 else 1;
  if FShowTicks then for var i := 0 to 59 do begin
    var major := i mod 5 = 0;
    if not major and ((radius < 30) or (FStyle = csMinimal)) then continue;
    if (FStyle = csMinimal) and (i mod 15 <> 0) then continue;
    var a := DegToRad(90-i*6);
    var len := if major then radius div 8 else radius div 16;
    if FStyle = csDotted then paintCircle(sp, cx+Round(cos(a)*(radius-len)), cy-Round(sin(a)*(radius-len)), (if major then Math.Max(radius div 20, 2) else Math.Max(radius div 40, 1)), tickColor, clNone)
    else paintLine(sp, cx+Round(cos(a)*(radius-len-2)), cy-Round(sin(a)*(radius-len-2)), cx+Round(cos(a)*(radius-2)), cy-Round(sin(a)*(radius-2)), tickColor, (if major then 2 else 1)*heavy);
  end;
  // the hands: hour, minute, then the thin second hand on top
  var hourAngle := DegToRad(90-((h mod 12)*30+m/2));
  var minuteAngle := DegToRad(90-(m*6+s/10));
  var hubR := Math.Max(radius div 14, 2);
  var hourW := match FStyle of csBold: Math.Max(radius div 7, 3); csMinimal: Math.Max(radius div 20, 2); else Math.Max(radius div 12, 2) end;
  var minuteW := match FStyle of csBold: Math.Max(radius div 10, 3); csMinimal: Math.Max(radius div 30, 1); else Math.Max(radius div 18, 2) end;
  paintLine(sp, cx-Round(cos(hourAngle)*hubR), cy+Round(sin(hourAngle)*hubR), cx+Round(cos(hourAngle)*radius*0.5), cy-Round(sin(hourAngle)*radius*0.5), hourColor, hourW);
  paintLine(sp, cx-Round(cos(minuteAngle)*hubR), cy+Round(sin(minuteAngle)*hubR), cx+Round(cos(minuteAngle)*radius*0.75), cy-Round(sin(minuteAngle)*radius*0.75), minuteColor, minuteW);
  if FShowSeconds then begin
    var sec: double := s;
    if FSmoothSeconds then sec += ms/1000;
    var secondAngle := DegToRad(90-sec*6);
    paintLine(sp, cx-Round(cos(secondAngle)*hubR*2), cy+Round(sin(secondAngle)*hubR*2), cx+Round(cos(secondAngle)*radius*0.85), cy-Round(sin(secondAngle)*radius*0.85), secondColor, heavy);
  end;
  if FStyle <> csMinimal then paintCircle(sp, cx, cy, hubR, hourColor, clNone)
  else paintCircle(sp, cx, cy, Math.Max(hubR div 2, 1), secondColor, clNone);
  sp.Flush;
  if FNumerals <> cnNone then begin
    applyTextQuality(Canvas);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := textColor;
    var th := Canvas.TextHeight('12');
    for var i := 1 to 12 do begin
      if (FNumerals = cnQuarters) and (i mod 3 <> 0) then continue;
      var a := DegToRad(90-i*30);
      var text := IntToStr(i);
      var tw := Canvas.TextWidth(text);
      var r := radius-radius div 5-th div 2;
      Canvas.TextOut(cx+Round(cos(a)*r)-tw div 2, cy-Round(sin(a)*r)-th div 2, text);
    end;
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- behavior ----------------------

procedure TClock.tick(Sender: TObject);
begin
  Invalidate;
  if Assigned(FOnTick) then FOnTick(self);
end;

procedure TClock.syncTimer;
begin
  FTimer.Interval := if FSmoothSeconds and (FMode = cmAnalog) then 50 else 1000;
  FTimer.Enabled := FLive and Visible and not (csDesigning in ComponentState) and not (csLoading in ComponentState);
end;

procedure TClock.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

// -- properties ----------------------

procedure TClock.setMode(value: TClockMode);
begin
  if FMode = value then exit;
  FMode := value;
  syncTimer;
  Invalidate;
end;

procedure TClock.setTime(value: TDateTime);
begin
  if FTime = value then exit;
  FTime := value;
  Invalidate;
end;

function TClock.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FLive;
    1: result := FShowSeconds;
    2: result := FShowDate;
    3: result := FShowTicks;
    4: result := FSmoothSeconds;
    _: result := FTwentyFourHours;
  end;
end;

procedure TClock.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FLive := value;
    1: FShowSeconds := value;
    2: FShowDate := value;
    3: FShowTicks := value;
    4: FSmoothSeconds := value;
    _: FTwentyFourHours := value;
  end;
  syncTimer;
  Invalidate;
end;

procedure TClock.setOffset(value: integer);
begin
  if FOffsetMinutes = value then exit;
  FOffsetMinutes := value;
  Invalidate;
end;

procedure TClock.setNumerals(value: TClockNumerals);
begin
  if FNumerals = value then exit;
  FNumerals := value;
  Invalidate;
end;

function TClock.getText(index: integer): string;
begin
  result := if index = 0 then FDigitalFormat else FDateFormat;
end;

procedure TClock.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  if index = 0 then FDigitalFormat := value else FDateFormat := value;
  Invalidate;
end;

function TClock.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FFaceColor;
    1: result := FBorderColor;
    2: result := FHourColor;
    3: result := FMinuteColor;
    4: result := FSecondColor;
    _: result := FTickColor;
  end;
end;

procedure TClock.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FFaceColor := value;
    1: FBorderColor := value;
    2: FHourColor := value;
    3: FMinuteColor := value;
    4: FSecondColor := value;
    _: FTickColor := value;
  end;
  Invalidate;
end;

procedure TClock.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TClock.setStyle(value: TClockStyle);
begin
  if FStyle = value then exit;
  FStyle := value;
  Invalidate;
end;

procedure TClock.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
