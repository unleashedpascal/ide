{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit AppTheme;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Graphics, ThemesPalette, ThemesSeed, ThemesIcons;

type
  // tpNone keeps the stock look of the widgetset; tpSystem picks the light or
  // the dark look after the desktop setting; tpCustom grows the look from Custom
  TThemePreset = (tpNone, tpSystem, tpLight, tpDark, tpOcean, tpFrost, tpPaper, tpEmber, tpMidnight, tpDusk, tpCustom);

  TAppTheme = class;

  { TThemeColors }

  // the seed of a custom look; a change switches the owner to tpCustom
  TThemeColors = class(TPersistent)
  private
    FOwner: TAppTheme;
    FSeed: TThemeSeed;
    function getColor(index: integer): TColor;
    procedure setColor(index: integer; value: TColor);
    function getShift(index: integer): integer;
    procedure setShift(index: integer; value: integer);
  public
    constructor Create(owner: TAppTheme);
    procedure Assign(Source: TPersistent); override;
    property Seed: TThemeSeed read FSeed write FSeed;
  published
    // forms, panels, buttons and tool bars
    property Surface: TColor index 0 read getColor write setColor;
    // text on the surface and in windows
    property Text: TColor index 1 read getColor write setColor;
    // the selection
    property Accent: TColor index 2 read getColor write setColor;
    // links and the strip of the active tab
    property Link: TColor index 3 read getColor write setColor;
    // a changed or unsaved item
    property Mark: TColor index 4 read getColor write setColor;
    // lightness of the fields (edits, lists, pages) against the surface in
    // percent points: positive brighter, negative deeper
    property FieldLightness: integer index 0 read getShift write setShift;
    // share of the text blended into the surface under the mouse, percent
    property HoverStrength: integer index 1 read getShift write setShift;
  end;

  { TIconFitting }

  // how the icons of the application are fitted to the surface they sit on
  TIconFitting = class(TPersistent)
  private
    FOwner: TAppTheme;
    FFit: TIconFit;
    function getValue(index: integer): integer;
    procedure setValue(index: integer; value: integer);
    procedure setEnabled(value: boolean);
  public
    constructor Create(owner: TAppTheme);
    procedure Assign(Source: TPersistent); override;
    property Fit: TIconFit read FFit write FFit;
  published
    property Enabled: boolean read FFit.Enabled write setEnabled default true;
    // share of the lightness remap applied on a dark surface
    property Strength: integer index 0 read getValue write setValue default 100;
    // the icons stay at least this far above a dark surface
    property MinContrast: integer index 1 read getValue write setValue default 30;
    // the icons stay at most this light on a dark surface
    property MaxLightness: integer index 2 read getValue write setValue default 88;
    // contrast a disabled icon keeps to the surface
    property DisabledContrast: integer index 3 read getValue write setValue default 45;
    // color a disabled icon keeps
    property DisabledSaturation: integer index 4 read getValue write setValue default 40;
  end;

  { TThemeEffectSettings }

  // the feedback the controls paint on top of the palette
  TThemeEffectSettings = class(TPersistent)
  private
    FOwner: TAppTheme;
    FEffects: TThemeEffects;
    procedure setHover(value: boolean);
    procedure setActive(value: boolean);
  public
    constructor Create(owner: TAppTheme);
    procedure Assign(Source: TPersistent); override;
    property Effects: TThemeEffects read FEffects write FEffects;
  published
    // the controls answer the mouse over them; off, only menus do
    property Hover: boolean read FEffects.Hover write setHover default true;
    // the focused control carries a ring; off, a control looks the same
    // with and without the focus
    property Active: boolean read FEffects.Active write setActive default true;
  end;

  { TThemeShift }

  // the whole look moved: turned on the hue wheel, more or less colorful,
  // lighter or darker; works on the presets as well as on a custom look
  TThemeShift = class(TPersistent)
  private
    FOwner: TAppTheme;
    FHue, FSaturation, FLightness: integer;
    procedure setValue(index: integer; value: integer);
  public
    constructor Create(owner: TAppTheme);
    procedure Assign(Source: TPersistent); override;
  published
    // degrees on the hue wheel
    property Hue: integer index 0 read FHue write setValue default 0;
    // percent points
    property Saturation: integer index 1 read FSaturation write setValue default 0;
    // percent points; the text keeps its lightness
    property Lightness: integer index 2 read FLightness write setValue default 0;
  end;

  { TThemeScrolling }

  // how the mouse wheel moves the scroll boxes and the scrolling forms of
  // the application
  TThemeScrolling = class(TPersistent)
  private
    FOwner: TAppTheme;
    FSpeed, FGlideTime: integer;
    FSmooth: boolean;
    procedure setSpeed(value: integer);
    procedure setSmooth(value: boolean);
    procedure setGlideTime(value: integer);
  public
    constructor Create(owner: TAppTheme);
    procedure Assign(Source: TPersistent); override;
  published
    // percent of the pace; at 100 a notch moves ten steps of the scroll bar
    property Speed: integer read FSpeed write setSpeed default 100;
    // the content glides to the new position instead of jumping
    property Smooth: boolean read FSmooth write setSmooth default true;
    // milliseconds of the glide
    property GlideTime: integer read FGlideTime write setGlideTime default 150;
  end;

  { TAppTheme }

  // puts a color theme on every window of the application, native controls
  // included, and keeps it on the windows made later. One per application,
  // a second one raises as it applies; dropped on the main form it takes
  // effect as the form loads. At design time it changes nothing, the designed
  // forms keep the stock look
  TAppTheme = class(TComponent)
  private
    FActive: boolean;
    FPreset: TThemePreset;
    FCustom: TThemeColors;
    FIconFit: TIconFitting;
    FEffects: TThemeEffectSettings;
    FShift: TThemeShift;
    FScrolling: TThemeScrolling;
    FOnChange: TNotifyEvent;
    procedure setActive(value: boolean);
    procedure setPreset(value: TThemePreset);
    procedure setCustom(value: TThemeColors);
    procedure setIconFit(value: TIconFitting);
    procedure setEffects(value: TThemeEffectSettings);
    procedure setShift(value: TThemeShift);
    procedure setScrolling(value: TThemeScrolling);
    procedure applyScrolling;
    function customStored: boolean;
    procedure customChanged;
    procedure iconFitChanged;
    procedure systemChanged;
    // the preset a choice puts on screen; tpSystem resolves to light or dark
    function resolved: TThemePreset;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // puts the current choice on screen; runs by itself after every change
    procedure Apply;
    // the palette the current choice resolves to; the system colors for tpNone
    function Palette: TPalette;
    // the look on screen is dark
    function IsDark: boolean;
    // the widgetset has a theme engine; elsewhere only the icons are fitted
    class function Supported: boolean;
    // the one instance of the application, nil before it is created
    class function Instance: TAppTheme;
  published
    // false keeps the stock look whatever the preset says
    property Active: boolean read FActive write setActive default true;
    property Preset: TThemePreset read FPreset write setPreset default tpSystem;
    // the seed of the look; picking a preset fills it with the seed of that
    // preset, so a custom look starts from the preset it is closest to
    property Custom: TThemeColors read FCustom write setCustom stored customStored;
    property IconFit: TIconFitting read FIconFit write setIconFit;
    property Effects: TThemeEffectSettings read FEffects write setEffects;
    property Shift: TThemeShift read FShift write setShift;
    // the wheel settings hold whatever the preset, Active included
    property Scrolling: TThemeScrolling read FScrolling write setScrolling;
    // after the look on screen changed
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

// the palette of a fixed preset; tpNone, tpSystem and tpCustom give the light one
function presetPalette(preset: TThemePreset): TPalette;

implementation

uses
  LCLType, LCLIntf, Forms, Themes, ThemesEngine;

var
  theInstance: TAppTheme = nil;

function presetPalette(preset: TThemePreset): TPalette;
begin
  match preset of
    tpDark: result := darkPalette;
    tpOcean: result := oceanPalette;
    tpFrost: result := frostPalette;
    tpPaper: result := paperPalette;
    tpEmber: result := emberPalette;
    tpMidnight: result := midnightPalette;
    tpDusk: result := duskPalette;
    _: result := lightPalette;
  end;
end;

// the colors the widgetset shows right now
function systemPalette: TPalette;
begin
  for var i := 0 to COLOR_ENDCOLORS do result[i] := GetSysColor(i);
  result[COLOR_MARK] := result[COLOR_HIGHLIGHT];
  result[COLOR_HOVER] := result[COLOR_3DLIGHT];
end;

{ TThemeColors }

constructor TThemeColors.Create(owner: TAppTheme);
begin
  inherited Create;
  FOwner := owner;
  FSeed := seedOf(lightPalette);
end;

procedure TThemeColors.Assign(Source: TPersistent);
begin
  if Source is TThemeColors then begin
    FSeed := TThemeColors(Source).FSeed;
    FOwner.customChanged;
  end else inherited Assign(Source);
end;

function TThemeColors.getColor(index: integer): TColor;
begin
  match index of
    0: result := FSeed.Surface;
    1: result := FSeed.Text;
    2: result := FSeed.Accent;
    3: result := FSeed.Link;
    _: result := FSeed.Mark;
  end;
end;

procedure TThemeColors.setColor(index: integer; value: TColor);
begin
  if getColor(index) = value then exit;
  match index of
    0: FSeed.Surface := value;
    1: FSeed.Text := value;
    2: FSeed.Accent := value;
    3: FSeed.Link := value;
    _: FSeed.Mark := value;
  end;
  FOwner.customChanged;
end;

function TThemeColors.getShift(index: integer): integer;
begin
  result := if index = 0 then FSeed.FieldLightness else FSeed.HoverStrength;
end;

procedure TThemeColors.setShift(index: integer; value: integer);
begin
  if getShift(index) = value then exit;
  if index = 0 then FSeed.FieldLightness := value else FSeed.HoverStrength := value;
  FOwner.customChanged;
end;

{ TIconFitting }

constructor TIconFitting.Create(owner: TAppTheme);
begin
  inherited Create;
  FOwner := owner;
  FFit := DefaultIconFit;
end;

procedure TIconFitting.Assign(Source: TPersistent);
begin
  if Source is TIconFitting then begin
    FFit := TIconFitting(Source).FFit;
    FOwner.iconFitChanged;
  end else inherited Assign(Source);
end;

function TIconFitting.getValue(index: integer): integer;
begin
  match index of
    0: result := FFit.Strength;
    1: result := FFit.MinContrast;
    2: result := FFit.MaxLightness;
    3: result := FFit.DisabledContrast;
    _: result := FFit.DisabledSaturation;
  end;
end;

procedure TIconFitting.setValue(index: integer; value: integer);
begin
  if getValue(index) = value then exit;
  match index of
    0: FFit.Strength := value;
    1: FFit.MinContrast := value;
    2: FFit.MaxLightness := value;
    3: FFit.DisabledContrast := value;
    _: FFit.DisabledSaturation := value;
  end;
  FOwner.iconFitChanged;
end;

procedure TIconFitting.setEnabled(value: boolean);
begin
  if FFit.Enabled = value then exit;
  FFit.Enabled := value;
  FOwner.iconFitChanged;
end;

{ TThemeEffectSettings }

constructor TThemeEffectSettings.Create(owner: TAppTheme);
begin
  inherited Create;
  FOwner := owner;
  FEffects := DefaultEffects;
end;

procedure TThemeEffectSettings.Assign(Source: TPersistent);
begin
  if Source is TThemeEffectSettings then begin
    FEffects := TThemeEffectSettings(Source).FEffects;
    FOwner.Apply;
  end else inherited Assign(Source);
end;

procedure TThemeEffectSettings.setHover(value: boolean);
begin
  if FEffects.Hover = value then exit;
  FEffects.Hover := value;
  FOwner.Apply;
end;

procedure TThemeEffectSettings.setActive(value: boolean);
begin
  if FEffects.Active = value then exit;
  FEffects.Active := value;
  FOwner.Apply;
end;

{ TThemeShift }

constructor TThemeShift.Create(owner: TAppTheme);
begin
  inherited Create;
  FOwner := owner;
end;

procedure TThemeShift.Assign(Source: TPersistent);
begin
  if Source is TThemeShift then begin
    FHue := TThemeShift(Source).FHue;
    FSaturation := TThemeShift(Source).FSaturation;
    FLightness := TThemeShift(Source).FLightness;
    FOwner.Apply;
  end else inherited Assign(Source);
end;

procedure TThemeShift.setValue(index: integer; value: integer);
begin
  match index of
    0: begin
      if FHue = value then exit;
      FHue := value;
    end;
    1: begin
      if FSaturation = value then exit;
      FSaturation := value;
    end;
    _: begin
      if FLightness = value then exit;
      FLightness := value;
    end;
  end;
  FOwner.Apply;
end;

{ TThemeScrolling }

constructor TThemeScrolling.Create(owner: TAppTheme);
begin
  inherited Create;
  FOwner := owner;
  FSpeed := 100;
  FSmooth := true;
  FGlideTime := 150;
end;

procedure TThemeScrolling.Assign(Source: TPersistent);
begin
  if Source is TThemeScrolling then begin
    FSpeed := TThemeScrolling(Source).FSpeed;
    FSmooth := TThemeScrolling(Source).FSmooth;
    FGlideTime := TThemeScrolling(Source).FGlideTime;
    FOwner.applyScrolling;
  end else inherited Assign(Source);
end;

procedure TThemeScrolling.setSpeed(value: integer);
begin
  if value < 1 then value := 1;
  if FSpeed = value then exit;
  FSpeed := value;
  FOwner.applyScrolling;
end;

procedure TThemeScrolling.setSmooth(value: boolean);
begin
  if FSmooth = value then exit;
  FSmooth := value;
  FOwner.applyScrolling;
end;

procedure TThemeScrolling.setGlideTime(value: integer);
begin
  if value < 0 then value := 0;
  if FGlideTime = value then exit;
  FGlideTime := value;
  FOwner.applyScrolling;
end;

{ TAppTheme }

// the engine calls a plain procedure
procedure instanceSystemChanged;
begin
  if theInstance <> nil then theInstance.systemChanged;
end;

constructor TAppTheme.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // designed forms may each carry one; the live application gets one only,
  // checked when it applies
  if theInstance = nil then theInstance := self;
  FActive := true;
  FPreset := tpSystem;
  FCustom := TThemeColors.Create(self);
  FIconFit := TIconFitting.Create(self);
  FEffects := TThemeEffectSettings.Create(self);
  FShift := TThemeShift.Create(self);
  FScrolling := TThemeScrolling.Create(self);
end;

destructor TAppTheme.Destroy;
begin
  // the look stays on screen: the component usually dies with the main form
  if (theInstance = self) and not (csDesigning in ComponentState) then onSystemThemeChange := nil;
  if theInstance = self then theInstance := nil;
  FCustom.Free;
  FIconFit.Free;
  FEffects.Free;
  FShift.Free;
  FScrolling.Free;
  inherited Destroy;
end;

class function TAppTheme.Instance: TAppTheme;
begin
  result := theInstance;
end;

class function TAppTheme.Supported: boolean;
begin
  result := themeSupported;
end;

procedure TAppTheme.Loaded;
begin
  inherited Loaded;
  // a preset not stored with its seed gets the seed back
  if FPreset <> tpCustom then FCustom.FSeed := seedOf(presetPalette(resolved));
  Apply;
end;

function TAppTheme.resolved: TThemePreset;
begin
  result := FPreset;
  if result = tpSystem then result := if ThemeServices.IsDarkTheme then tpDark else tpLight;
end;

function TAppTheme.Palette: TPalette;
begin
  if not FActive or (FPreset = tpNone) then exit(systemPalette);
  result := if FPreset = tpCustom then buildPalette(FCustom.FSeed) else presetPalette(resolved);
  result := adjustPalette(result, FShift.FHue, FShift.FSaturation, FShift.FLightness);
end;

function TAppTheme.IsDark: boolean;
begin
  result := isDarkColor(Palette[COLOR_BTNFACE]);
end;

procedure TAppTheme.Apply;
begin
  if csDesigning in ComponentState then exit;
  if csLoading in ComponentState then exit;
  if theInstance <> self then raise EComponentError.Create('Only one TAppTheme per application');
  applyScrolling;
  setThemeEffects(FEffects.FEffects);
  if FActive and (FPreset <> tpNone) then applyTheme(Palette) else dropTheme;
  useIconFit(FIconFit.FFit);
  themeIcons(clBtnFace);
  // the desktop switch between light and dark is followed only by the live
  // application; the IDE keeps its own handler
  onSystemThemeChange := @instanceSystemChanged;
  if Assigned(FOnChange) then FOnChange(self);
end;

procedure TAppTheme.systemChanged;
begin
  if FActive and (FPreset = tpSystem) then Apply;
end;

procedure TAppTheme.setActive(value: boolean);
begin
  if FActive = value then exit;
  FActive := value;
  Apply;
end;

// the wheel settings go to the LCL; a live application only, the IDE keeps its own
procedure TAppTheme.applyScrolling;
begin
  if csDesigning in ComponentState then exit;
  if csLoading in ComponentState then exit;
  WheelScrolling.Speed := FScrolling.FSpeed;
  WheelScrolling.Smooth := FScrolling.FSmooth;
  WheelScrolling.GlideTime := FScrolling.FGlideTime;
end;

procedure TAppTheme.setEffects(value: TThemeEffectSettings);
begin
  FEffects.Assign(value);
end;

procedure TAppTheme.setShift(value: TThemeShift);
begin
  FShift.Assign(value);
end;

procedure TAppTheme.setScrolling(value: TThemeScrolling);
begin
  FScrolling.Assign(value);
end;

procedure TAppTheme.setPreset(value: TThemePreset);
begin
  if FPreset = value then exit;
  FPreset := value;
  if value <> tpCustom then FCustom.FSeed := seedOf(presetPalette(resolved));
  Apply;
end;

procedure TAppTheme.setCustom(value: TThemeColors);
begin
  FCustom.Assign(value);
end;

procedure TAppTheme.setIconFit(value: TIconFitting);
begin
  FIconFit.Assign(value);
end;

function TAppTheme.customStored: boolean;
begin
  result := FPreset = tpCustom;
end;

procedure TAppTheme.customChanged;
begin
  // the seed streams in after the preset, which stays what the form says
  if not (csLoading in ComponentState) then FPreset := tpCustom;
  Apply;
end;

procedure TAppTheme.iconFitChanged;
begin
  Apply;
end;

end.
