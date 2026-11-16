{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemeSwitch;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ImgList, ExtCtrls, LCLType, LMessages, AppTheme, PopupWindow, ControlPaint;

type
  // the icon of a theme, painted as a shape in the color of the text;
  // tgAuto takes the icon that goes with the theme
  TThemeGlyph = (tgAuto, tgNone, tgSun, tgMoon, tgMonitor, tgContrast, tgDrop, tgSnowflake, tgPage, tgFlame, tgStar, tgSunset, tgPalette, tgLeaf, tgCloud, tgDot);

  // how the themes are shown:
  // twSwitch, a switch between the first two themes;
  // twSegmented, a bar of segments with the current theme selected;
  // twButtons, a row of separate buttons;
  // twCycle, one button that steps to the next theme on every click;
  // twDropDown, one button that opens the list of the themes;
  // twSplitButton, a button that steps to the next theme and an arrow that opens the list
  TThemeSwitchStyle = (twSwitch, twSegmented, twButtons, twCycle, twDropDown, twSplitButton);

  // what a theme shows: its icon, its icon with the name beside it, its icon
  // with the name under it, or its name alone
  TThemeSwitchContent = (tcIcon, tcIconAndName, tcIconOverName, tcName);

  TThemeSwitch = class;

  { TThemeSwitchItem }

  // one theme the switch offers: a preset of the attached TAppTheme with its icon
  TThemeSwitchItem = class(TCollectionItem)
  private
    FPreset: TThemePreset;
    FGlyph: TThemeGlyph;
    FCaption: string;
    FImageIndex: TImageIndex;
    FIconColor: TColor;
    FVisible: boolean;
    FHint: string;
    procedure setPreset(value: TThemePreset);
    procedure setGlyph(value: TThemeGlyph);
    procedure setCaption(const value: string);
    procedure setImageIndex(value: TImageIndex);
    procedure setIconColor(value: TColor);
    procedure setVisible(value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // the caption, or the name of the preset when the caption is empty
    function ShownCaption: string;
    // the glyph, tgAuto resolved to the one of the preset
    function ShownGlyph: TThemeGlyph;
  published
    property Preset: TThemePreset read FPreset write setPreset default tpLight;
    property Glyph: TThemeGlyph read FGlyph write setGlyph default tgAuto;
    // empty shows the name of the preset
    property Caption: string read FCaption write setCaption;
    // an image of Images in place of the glyph; -1 keeps the glyph
    property ImageIndex: TImageIndex read FImageIndex write setImageIndex default -1;
    // the glyph in its own color; clDefault follows the text, or the natural
    // color of the glyph with ColoredIcons
    property IconColor: TColor read FIconColor write setIconColor default clDefault;
    // false keeps the theme in the list but out of the switch
    property Visible: boolean read FVisible write setVisible default true;
    // the hint over the theme; empty shows its caption
    property Hint: string read FHint write FHint;
  end;

  { TThemeSwitchItems }

  TThemeSwitchItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TThemeSwitchItem;
    procedure setItem(index: integer; value: TThemeSwitchItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(owner: TThemeSwitch);
    function Add: TThemeSwitchItem;
    function AddTheme(preset: TThemePreset; glyph: TThemeGlyph = tgAuto): TThemeSwitchItem;
    // the first item of the preset, -1 without one
    function IndexOfPreset(preset: TThemePreset): integer;
    property Items[index: integer]: TThemeSwitchItem read getItem write setItem; default;
  end;

  TThemeSwitchEvent = procedure(Sender: TObject; preset: TThemePreset) of object;
  TThemeSwitchChangingEvent = procedure(Sender: TObject; preset: TThemePreset; var allow: boolean) of object;

  { TThemeSwitch }

  // switches the theme of the application between the themes chosen for it.
  // AttachTo names the TAppTheme to drive; dropped on a form that has one,
  // the switch fills it by itself. The current theme shows as selected and
  // follows every change of the TAppTheme, so the switch is right from the
  // start, also with Preset tpSystem. Themes holds the offered themes with
  // their icons; out of the box it offers Light and Dark
  TThemeSwitch = class(TCustomControl)
  private
    type
      // a name or an image that goes onto the canvas after the shapes
      TLater = record
        Image: integer; // -1 for a name
        Box: TRect;
        Color: TColor;
        Text: string;
      end;
      TLaters = array of TLater;
      TCellRects = array of TRect;
  private
    FAttachTo, FListening: TAppTheme;
    FThemes: TThemeSwitchItems;
    FStyle: TThemeSwitchStyle;
    FContent: TThemeSwitchContent;
    FImages: TCustomImageList;
    FImageWidth: integer;
    FIconSize, FSpacing, FPadding, FGap, FCornerRadius: integer;
    FPill, FVertical, FFlat, FColoredIcons, FAutoApply, FAnimated, FNameHints: boolean;
    FDuration: integer;
    FSelectedColor, FSelectedTextColor, FBarColor, FBorderColor, FTextColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FItemIndex: integer;
    FSynced: boolean;
    FHot, FPressed: integer; // the part under the mouse; see partAt
    FPos, FFrom, FTarget: single; // the position of the selection, in shown places
    FStarted: QWord;
    FTimer: TTimer;
    FPopup: TDropPopup;
    FList: TCustomControl;
    FListHot: integer;
    FOnChange: TThemeSwitchEvent;
    FOnChanging: TThemeSwitchChangingEvent;
    procedure setAttachTo(value: TAppTheme);
    procedure setThemes(value: TThemeSwitchItems);
    procedure setStyle(value: TThemeSwitchStyle);
    procedure setContent(value: TThemeSwitchContent);
    procedure setImages(value: TCustomImageList);
    procedure setImageWidth(value: integer);
    function getMetric(index: integer): integer;
    procedure setMetric(index: integer; value: integer);
    function getFlag(index: integer): boolean;
    procedure setFlag(index: integer; value: boolean);
    function getPartColor(index: integer): TColor;
    procedure setPartColor(index: integer; value: TColor);
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setItemIndex(value: integer);
    function getItemIndex: integer;
    function getSelectedPreset: TThemePreset;
    // the theme the switch drives: AttachTo, or the one of the form in the
    // designer, or the one of the application
    function resolvedTheme: TAppTheme;
    procedure listenTo(theme: TAppTheme);
    procedure themeChanged(Sender: TObject);
    // the item that shows the theme on screen
    function findCurrent: integer;
    procedure sync(animated: boolean);
    function presetDark(preset: TThemePreset): boolean;
    // the indexes of the visible items, in their order; the switch takes two
    function shown: TIntegerDynArray;
    function placeOf(index: integer): integer;
    procedure moveTo(animated: boolean);
    procedure tick(Sender: TObject);
    procedure choose(index: integer; byUser: boolean);
    procedure step(delta: integer);
    procedure itemsChanged;
    // sizes at the current DPI
    function iconPx: integer;
    function iconSizeOf(item: TThemeSwitchItem): TSize;
    function contentSize(item: TThemeSwitchItem): TSize;
    function cellSize: TSize;
    function arrowWidth: integer;
    function switchSize: TSize;
    function cellRects: TCellRects;
    function arrowRect: TRect;
    function partAt(x, y: integer): integer;
    function cornerFor(const r: TRect): integer;
    procedure paintContent(sp: TSmoothPaint; const r: TRect; item: TThemeSwitchItem; fg, fill: TColor; var later: TLaters);
    procedure laterImage(var later: TLaters; index, x, y: integer);
    procedure laterText(var later: TLaters; const box: TRect; color: TColor; const text: string);
    procedure paintLater(canvas: TCanvas; const later: TLaters);
    procedure paintSwitch(sp: TSmoothPaint; var later: TLaters);
    procedure paintCells(sp: TSmoothPaint; var later: TLaters);
    procedure paintButton(sp: TSmoothPaint; var later: TLaters);
    procedure faceColors(hot, pressed: boolean; out face, border: TColor);
    function glyphColor(item: TThemeSwitchItem; fallback: TColor): TColor;
    procedure buildPopup;
    procedure popupDismiss(Sender: TObject);
    procedure CMHintShow(var Message: TLMessage); message CM_HINTSHOW;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the next or the previous visible theme, round the end
    procedure Next;
    procedure Previous;
    // opens and closes the list of the drop down styles
    procedure DropDown;
    procedure CloseUp;
    function DroppedDown: boolean;
    // the TAppTheme the switch drives right now, nil without one
    function Theme: TAppTheme;
    // the box of an item in the control, empty for a hidden one
    function ItemRect(index: integer): TRect;
    // the item of the current theme, -1 when no visible item matches it;
    // setting it switches the theme
    property ItemIndex: integer read getItemIndex write setItemIndex;
    property SelectedPreset: TThemePreset read getSelectedPreset;
  published
    property AttachTo: TAppTheme read FAttachTo write setAttachTo;
    property Themes: TThemeSwitchItems read FThemes write setThemes;
    property Style: TThemeSwitchStyle read FStyle write setStyle default twSwitch;
    property Content: TThemeSwitchContent read FContent write setContent default tcIcon;
    // images the items take with their ImageIndex in place of a glyph
    property Images: TCustomImageList read FImages write setImages;
    // the images at 96 dpi; 0 takes the size of the list
    property ImageWidth: integer read FImageWidth write setImageWidth default 0;
    // the glyphs at 96 dpi; 0 takes the size from the font
    property IconSize: integer index 0 read getMetric write setMetric default 0;
    // between an icon and its name
    property Spacing: integer index 1 read getMetric write setMetric default 6;
    // inside each theme, left and right of its content
    property Padding: integer index 2 read getMetric write setMetric default 8;
    // between the buttons of twButtons
    property Gap: integer index 3 read getMetric write setMetric default 6;
    // the corners when Pill is off; 0 is square
    property CornerRadius: integer index 4 read getMetric write setMetric default 6;
    // the slide of the selection, in milliseconds
    property AnimationDuration: integer index 5 read getMetric write setMetric default 150;
    // round ends, the radius of half the height
    property Pill: boolean index 0 read getFlag write setFlag default true;
    // the segments and the buttons stacked from the top down
    property Vertical: boolean index 1 read getFlag write setFlag default false;
    // no face behind the themes; only the selected one and the one under
    // the mouse show a face
    property Flat: boolean index 2 read getFlag write setFlag default false;
    // every glyph in its own color: an amber sun, a blue moon, a red flame
    property ColoredIcons: boolean index 3 read getFlag write setFlag default false;
    // a choice goes to the attached TAppTheme; off, only OnChange fires
    property AutoApply: boolean index 4 read getFlag write setFlag default true;
    // the selection slides to the new theme; off, it jumps
    property Animated: boolean index 5 read getFlag write setFlag default true;
    // the name of the theme under the mouse as its hint while the names are
    // not on screen; it shows when ShowHint is on
    property NameHints: boolean index 6 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property SelectedColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property SelectedTextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BarColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    // the smoothing of the shapes: after the theme, or its own choice
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // before a choice of the user goes through; allow false keeps the theme
    property OnChanging: TThemeSwitchChangingEvent read FOnChanging write FOnChanging;
    // after the user or the code chose a theme
    property OnChange: TThemeSwitchEvent read FOnChange write FOnChange;
    property Align;
    property Anchors;
    property AutoSize default true;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Cursor;
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

// the glyph that goes with a preset
function defaultGlyphOf(preset: TThemePreset): TThemeGlyph;
// the name of a glyph, for lists and editors
function glyphCaption(glyph: TThemeGlyph): string;
// the natural color of a glyph: amber for the sun, blue for the drop
function naturalGlyphColor(glyph: TThemeGlyph): TColor;
// paints a glyph centered in `r` with `color`; `background` is the fill under
// it, for the details cut into some glyphs
procedure paintThemeGlyph(sp: TSmoothPaint; const r: TRect; glyph: TThemeGlyph; color, background: TColor);

implementation

uses
  Math, ThemesEngine, ThemesSeed;

const
  // the parts of the button styles; the cells take their item index
  PART_NONE = -1;
  PART_MAIN = -2;
  PART_ARROW = -3;

  GLYPH_NAMES: array[TThemeGlyph] of string = ('Auto', 'None', 'Sun', 'Moon', 'Monitor', 'Contrast', 'Drop', 'Snowflake', 'Page', 'Flame', 'Star', 'Sunset', 'Palette', 'Leaf', 'Cloud', 'Dot');

function defaultGlyphOf(preset: TThemePreset): TThemeGlyph;
begin
  match preset of
    tpNone: result := tgDot;
    tpSystem: result := tgMonitor;
    tpLight: result := tgSun;
    tpDark: result := tgMoon;
    tpOcean: result := tgDrop;
    tpFrost: result := tgSnowflake;
    tpPaper: result := tgPage;
    tpEmber: result := tgFlame;
    tpMidnight: result := tgStar;
    tpDusk: result := tgSunset;
    _: result := tgPalette;
  end;
end;

function glyphCaption(glyph: TThemeGlyph): string;
begin
  result := GLYPH_NAMES[glyph];
end;

function naturalGlyphColor(glyph: TThemeGlyph): TColor;
begin
  match glyph of
    tgSun: result := RGBToColor(242, 169, 0);
    tgMoon: result := RGBToColor(110, 128, 220);
    tgMonitor: result := RGBToColor(100, 125, 150);
    tgDrop: result := RGBToColor(30, 136, 229);
    tgSnowflake: result := RGBToColor(60, 175, 220);
    tgPage: result := RGBToColor(170, 132, 80);
    tgFlame: result := RGBToColor(235, 90, 35);
    tgStar: result := RGBToColor(140, 100, 225);
    tgSunset: result := RGBToColor(238, 115, 55);
    tgPalette: result := RGBToColor(200, 80, 150);
    tgLeaf: result := RGBToColor(60, 160, 75);
    tgCloud: result := RGBToColor(110, 150, 195);
  else
    result := RGBToColor(128, 128, 128)
  end;
end;

// -- glyphs ----------------------

// the angle `angle` lies on the way from `from` that `sweep` (positive) covers
function onSweep(from, sweep, angle: single): boolean;
begin
  var d := angle-from;
  while d < 0 do d += 2*Pi;
  while d >= 2*Pi do d -= 2*Pi;
  result := d <= sweep;
end;

// points of a circle from angle `a0` to `a1`, the way that passes `via`
procedure addArc(var o: TOutline; cx, cy, r, a0, a1, via: single);
begin
  var ccw := a1-a0;
  while ccw <= 0 do ccw += 2*Pi;
  while ccw > 2*Pi do ccw -= 2*Pi;
  var sweep := if onSweep(a0, ccw, via) then ccw else ccw-2*Pi;
  var n := Max(Ceil(Abs(sweep)/(Pi/24)), 2);
  for var i := 0 to n do begin
    var a := a0+sweep*i/n;
    o += [PointF(cx+r*Cos(a), cy+r*Sin(a))];
  end;
end;

// points of a quadratic curve from p0 over c to p1, p0 left out
procedure addCurve(var o: TOutline; const p0, c, p1: TPointF);
begin
  for var i := 1 to 16 do begin
    var t := i/16;
    var u := 1-t;
    o += [PointF(u*u*p0.X+2*u*t*c.X+t*t*p1.X, u*u*p0.Y+2*u*t*c.Y+t*t*p1.Y)];
  end;
end;

// a closed curve through the points, rounded with Catmull-Rom pieces
function smoothOutline(const pts: array of TPointF): TOutline;
begin
  result := [];
  var n := length(pts);
  for var i := 0 to n-1 do begin
    var p0 := pts[(i+n-1) mod n];
    var p1 := pts[i];
    var p2 := pts[(i+1) mod n];
    var p3 := pts[(i+2) mod n];
    for var k := 0 to 7 do begin
      var t := k/8;
      var t2 := t*t;
      var t3 := t2*t;
      result += [PointF(
        0.5*(2*p1.X+(p2.X-p0.X)*t+(2*p0.X-5*p1.X+4*p2.X-p3.X)*t2+(3*p1.X-p0.X-3*p2.X+p3.X)*t3),
        0.5*(2*p1.Y+(p2.Y-p0.Y)*t+(2*p0.Y-5*p1.Y+4*p2.Y-p3.Y)*t2+(3*p1.Y-p0.Y-3*p2.Y+p3.Y)*t3))];
    end;
  end;
end;

procedure paintThemeGlyph(sp: TSmoothPaint; const r: TRect; glyph: TThemeGlyph; color, background: TColor);
var
  cx, cy, s: single;

  function at(x, y: single): TPointF;
  begin
    result := PointF(cx+x*s, cy+y*s);
  end;

  procedure line(x1, y1, x2, y2, width: single);
  begin
    sp.StrokePolyline([at(x1, y1), at(x2, y2)], width, color);
  end;

begin
  if (glyph = tgNone) or (r.Width <= 0) or (r.Height <= 0) then exit;
  cx := (r.Left+r.Right)/2;
  cy := (r.Top+r.Bottom)/2;
  s := Min(r.Width, r.Height);
  var lw := Math.Max(s*0.09, 1.2);
  match glyph of
    tgSun: begin
      sp.FillEllipse(cx, cy, s*0.2, s*0.2, color);
      for var i := 0 to 7 do begin
        var a := i*Pi/4;
        line(0.31*Cos(a), 0.31*Sin(a), 0.45*Cos(a), 0.45*Sin(a), lw);
      end;
    end;
    // a disc with a smaller one bitten out of its upper right
    tgMoon: begin
      var ra := 0.42*s;
      var bx := 0.24*s;
      var by := -0.2*s;
      var rb := 0.34*s;
      var d := Sqrt(bx*bx+by*by);
      var a := (ra*ra-rb*rb+d*d)/(2*d);
      var h := Sqrt(Math.Max(ra*ra-a*a, 0));
      var px := a*bx/d;
      var py := a*by/d;
      var i1x := px-h*by/d;
      var i1y := py+h*bx/d;
      var i2x := px+h*by/d;
      var i2y := py-h*bx/d;
      var away := ArcTan2(-by, -bx);
      var o: TOutline := [];
      addArc(o, cx, cy, ra, ArcTan2(i1y, i1x), ArcTan2(i2y, i2x), away);
      addArc(o, cx+bx, cy+by, rb, ArcTan2(i2y-by, i2x-bx), ArcTan2(i1y-by, i1x-bx), away);
      sp.FillOutlines([o], color);
    end;
    tgMonitor: begin
      sp.FrameRoundRect(cx-0.45*s, cy-0.36*s, cx+0.45*s, cy+0.2*s, 0.07*s, lw, color);
      line(0, 0.22, 0, 0.36, lw);
      line(-0.22, 0.4, 0.22, 0.4, lw);
    end;
    tgContrast: begin
      sp.FrameEllipse(cx, cy, 0.43*s, 0.43*s, lw, color);
      var o: TOutline := [];
      addArc(o, cx, cy, 0.43*s, Pi/2, 3*Pi/2, Pi);
      sp.FillOutlines([o], color);
    end;
    // a circle below and the tip above, met by the tangents
    tgDrop: begin
      var ccy := cy+0.13*s;
      var rr := 0.29*s;
      var o: TOutline := [at(0, -0.46)];
      addArc(o, cx, ccy, rr, -Pi/6, -5*Pi/6, Pi/2);
      sp.FillOutlines([o], color);
    end;
    tgSnowflake: begin
      var w := lw*0.85;
      for var i := 0 to 5 do begin
        var a := i*Pi/3-Pi/2;
        var ca := Cos(a);
        var sa := Sin(a);
        line(0, 0, 0.45*ca, 0.45*sa, w);
        // a pair of twigs two thirds out on the arm
        for var k := 0 to 1 do begin
          var b := a+(k*2-1)*Pi/4;
          line(0.27*ca, 0.27*sa, 0.27*ca+0.15*Cos(b), 0.27*sa+0.15*Sin(b), w);
        end;
      end;
    end;
    // a sheet with its top right corner folded
    tgPage: begin
      var w := lw*0.9;
      sp.StrokePolyline([at(-0.32, -0.44), at(0.12, -0.44), at(0.32, -0.24), at(0.32, 0.44), at(-0.32, 0.44)], w, color, true);
      sp.StrokePolyline([at(0.12, -0.44), at(0.12, -0.24), at(0.32, -0.24)], w, color);
      line(-0.16, 0.0, 0.16, 0.0, w);
      line(-0.16, 0.2, 0.16, 0.2, w);
    end;
    // the outer flame and a lighter core
    tgFlame: begin
      sp.FillOutlines([smoothOutline([at(0.04, -0.48), at(0.2, -0.24), at(0.32, 0.02), at(0.3, 0.26), at(0.16, 0.42), at(0, 0.46),
        at(-0.17, 0.42), at(-0.3, 0.26), at(-0.31, 0.04), at(-0.22, -0.1), at(-0.14, 0.0), at(-0.1, -0.22)])], color);
      sp.FillOutlines([smoothOutline([at(0.0, -0.06), at(0.12, 0.12), at(0.11, 0.28), at(0, 0.35), at(-0.11, 0.28), at(-0.12, 0.12)])], blend(color, background, 55));
    end;
    tgStar: begin
      var o: TOutline := [];
      for var i := 0 to 9 do begin
        var a := -Pi/2+i*Pi/5;
        var rr := if odd(i) then 0.2 else 0.48;
        o += [at(rr*Cos(a), rr*Sin(a))];
      end;
      sp.FillOutlines([o], color);
    end;
    // half a sun on the horizon, the rays above it
    tgSunset: begin
      var hy := 0.14;
      var o: TOutline := [];
      addArc(o, cx, cy+hy*s, 0.21*s, Pi, 2*Pi, 3*Pi/2);
      sp.FillOutlines([o], color);
      for var k := 0 to 4 do begin
        var a := (-160+k*35)*Pi/180;
        line(0.31*Cos(a), hy+0.31*Sin(a), 0.44*Cos(a), hy+0.44*Sin(a), lw);
      end;
      line(-0.46, hy+0.02, 0.46, hy+0.02, lw);
      line(-0.24, hy+0.22, 0.24, hy+0.22, lw);
    end;
    // a painter's palette: the board with the thumb hole and the paint wells
    tgPalette: begin
      sp.FillOutlines([ellipseOutline(cx, cy+0.02*s, 0.46*s, 0.4*s), ellipseOutline(cx+0.18*s, cy+0.18*s, 0.08*s, 0.08*s, true),
        ellipseOutline(cx-0.23*s, cy-0.02*s, 0.07*s, 0.07*s, true), ellipseOutline(cx-0.08*s, cy-0.21*s, 0.07*s, 0.07*s, true),
        ellipseOutline(cx+0.14*s, cy-0.17*s, 0.07*s, 0.07*s, true), ellipseOutline(cx-0.17*s, cy+0.2*s, 0.07*s, 0.07*s, true)], color);
    end;
    // a pointed leaf from the lower left to the upper right, its vein cut in
    tgLeaf: begin
      var o: TOutline := [at(-0.34, 0.34)];
      addCurve(o, at(-0.34, 0.34), at(0.26, 0.24), at(0.42, -0.42));
      addCurve(o, at(0.42, -0.42), at(-0.24, -0.26), at(-0.34, 0.34));
      sp.FillOutlines([o], color);
      sp.StrokePolyline([at(-0.24, 0.24), at(0.24, -0.24)], lw*0.6, background);
      line(-0.34, 0.34, -0.46, 0.46, lw);
    end;
    tgCloud: begin
      sp.FillOutlines([ellipseOutline(cx-0.2*s, cy+0.06*s, 0.2*s, 0.2*s), ellipseOutline(cx+0.03*s, cy-0.07*s, 0.27*s, 0.27*s),
        ellipseOutline(cx+0.25*s, cy+0.08*s, 0.19*s, 0.19*s), roundRectOutline(cx-0.4*s, cy+0.06*s, cx+0.44*s, cy+0.27*s, 0.1*s)], color);
    end;
    tgDot: sp.FillEllipse(cx, cy, 0.24*s, 0.24*s, color);
  else
    ;
  end;
end;

{ TThemeSwitchItem }

constructor TThemeSwitchItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FPreset := tpLight;
  FGlyph := tgAuto;
  FImageIndex := -1;
  FIconColor := clDefault;
  FVisible := true;
end;

procedure TThemeSwitchItem.Assign(Source: TPersistent);
begin
  if Source is TThemeSwitchItem then begin
    var src := TThemeSwitchItem(Source);
    FPreset := src.FPreset;
    FGlyph := src.FGlyph;
    FCaption := src.FCaption;
    FImageIndex := src.FImageIndex;
    FIconColor := src.FIconColor;
    FVisible := src.FVisible;
    FHint := src.FHint;
    Changed(false);
  end else inherited Assign(Source);
end;

function TThemeSwitchItem.GetDisplayName: string;
begin
  result := ShownCaption;
end;

function TThemeSwitchItem.ShownCaption: string;
begin
  result := if FCaption <> '' then FCaption else presetCaption(FPreset);
end;

function TThemeSwitchItem.ShownGlyph: TThemeGlyph;
begin
  result := if FGlyph = tgAuto then defaultGlyphOf(FPreset) else FGlyph;
end;

procedure TThemeSwitchItem.setPreset(value: TThemePreset);
begin
  if FPreset = value then exit;
  FPreset := value;
  Changed(false);
end;

procedure TThemeSwitchItem.setGlyph(value: TThemeGlyph);
begin
  if FGlyph = value then exit;
  FGlyph := value;
  Changed(false);
end;

procedure TThemeSwitchItem.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TThemeSwitchItem.setImageIndex(value: TImageIndex);
begin
  if FImageIndex = value then exit;
  FImageIndex := value;
  Changed(false);
end;

procedure TThemeSwitchItem.setIconColor(value: TColor);
begin
  if FIconColor = value then exit;
  FIconColor := value;
  Changed(false);
end;

procedure TThemeSwitchItem.setVisible(value: boolean);
begin
  if FVisible = value then exit;
  FVisible := value;
  Changed(false);
end;

{ TThemeSwitchItems }

constructor TThemeSwitchItems.Create(owner: TThemeSwitch);
begin
  inherited Create(owner, TThemeSwitchItem);
end;

function TThemeSwitchItems.getItem(index: integer): TThemeSwitchItem;
begin
  result := TThemeSwitchItem(inherited Items[index]);
end;

procedure TThemeSwitchItems.setItem(index: integer; value: TThemeSwitchItem);
begin
  inherited Items[index] := value;
end;

function TThemeSwitchItems.Add: TThemeSwitchItem;
begin
  result := TThemeSwitchItem(inherited Add);
end;

function TThemeSwitchItems.AddTheme(preset: TThemePreset; glyph: TThemeGlyph): TThemeSwitchItem;
begin
  BeginUpdate;
  try
    result := Add;
    result.Preset := preset;
    result.Glyph := glyph;
  finally
    EndUpdate;
  end;
end;

function TThemeSwitchItems.IndexOfPreset(preset: TThemePreset): integer;
begin
  for var i := 0 to Count-1 do if Items[i].Preset = preset then exit(i);
  result := -1;
end;

procedure TThemeSwitchItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TThemeSwitch then TThemeSwitch(Owner).itemsChanged;
end;

{ TThemeSwitchList }

type
  // the list a drop down style opens: a row per visible theme, its icon and its name
  TThemeSwitchList = class(TCustomControl)
  private
    FSwitch: TThemeSwitch;
    function rowHeight: integer;
    function rowAt(y: integer): integer;
    function rowRect(row: integer): TRect;
    function iconBox(row: integer; item: TThemeSwitchItem): TRect;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    // the size the rows want
    function Measure: TSize;
  end;

function TThemeSwitchList.rowHeight: integer;
begin
  result := Math.Max(FSwitch.iconPx, lineHeightOf(FSwitch.Font))+scaled(FSwitch, 10);
end;

function TThemeSwitchList.Measure: TSize;
begin
  var places := FSwitch.shown;
  var w := 0;
  for var i in places do begin
    var item := FSwitch.FThemes[i];
    w := Math.Max(w, FSwitch.iconSizeOf(item).cx+scaled(FSwitch, FSwitch.FSpacing)+textWidthOf(FSwitch.Font, item.ShownCaption));
  end;
  // the edges, the room left of the icon and the check mark at the right
  result.cx := w+scaled(FSwitch, 4)*2+scaled(FSwitch, 8)+scaled(FSwitch, 12)+scaled(FSwitch, 22);
  result.cy := rowHeight*length(places)+scaled(FSwitch, 4)*2;
end;

function TThemeSwitchList.rowAt(y: integer): integer;
begin
  result := -1;
  var top := scaled(FSwitch, 4);
  if y < top then exit;
  var row := (y-top) div rowHeight;
  if row < length(FSwitch.shown) then result := row;
end;

function TThemeSwitchList.rowRect(row: integer): TRect;
begin
  var edge := scaled(FSwitch, 4);
  result := Rect(edge, edge+row*rowHeight, ClientWidth-edge, edge+(row+1)*rowHeight);
end;

function TThemeSwitchList.iconBox(row: integer; item: TThemeSwitchItem): TRect;
begin
  var r := rowRect(row);
  var icon := FSwitch.iconSizeOf(item);
  result.Left := r.Left+scaled(FSwitch, 8);
  result.Top := r.Top+(r.Height-icon.cy) div 2;
  result.Right := result.Left+icon.cx;
  result.Bottom := result.Top+icon.cy;
end;

procedure TThemeSwitchList.Paint;
begin
  var back := ColorToRGB(clWindow);
  var text := ColorToRGB(clWindowText);
  var accent := pick(FSwitch.FSelectedColor, clHighlight);
  var places := FSwitch.shown;
  var current := FSwitch.ItemIndex;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FSwitch.FAntialiasing);
  for var row := 0 to high(places) do begin
    var item := FSwitch.FThemes[places[row]];
    var r := rowRect(row);
    var isCurrent := places[row] = current;
    var fill := if isCurrent then blend(back, accent, 18) else back;
    if (row = FSwitch.FListHot) and hoverEnabled then fill := if isCurrent then blend(back, accent, 28) else hoverColor(back);
    if fill <> back then paintRoundRect(sp, r, scaled(FSwitch, 4), fill, clNone);
    if (FSwitch.FImages = nil) or (item.ImageIndex < 0) then paintThemeGlyph(sp, iconBox(row, item), item.ShownGlyph, FSwitch.glyphColor(item, text), fill);
    // the check mark of the current theme at the right end
    if isCurrent then paintCheck(sp, Rect(r.Right-scaled(FSwitch, 22), r.Top, r.Right-scaled(FSwitch, 4), r.Bottom), scaled(FSwitch, 10), accent, Math.Max(scaled(FSwitch, 2), 2));
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Font := FSwitch.Font;
  Canvas.Font.Color := text;
  Canvas.Brush.Style := bsClear;
  var th := lineHeightOf(FSwitch.Font);
  for var row := 0 to high(places) do begin
    var item := FSwitch.FThemes[places[row]];
    var box := iconBox(row, item);
    if (FSwitch.FImages <> nil) and (item.ImageIndex >= 0) then
      FSwitch.FImages.DrawForPPI(Canvas, box.Left, box.Top, item.ImageIndex, FSwitch.FImageWidth, FSwitch.Font.PixelsPerInch, GetCanvasScaleFactor, FSwitch.Enabled);
    var r := rowRect(row);
    Canvas.TextOut(box.Right+scaled(FSwitch, FSwitch.FSpacing), r.Top+(r.Height-th) div 2, item.ShownCaption);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TThemeSwitchList.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var row := rowAt(Y);
  if row = FSwitch.FListHot then exit;
  FSwitch.FListHot := row;
  Invalidate;
end;

procedure TThemeSwitchList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var row := rowAt(Y);
  if row < 0 then exit;
  var index := FSwitch.shown[row];
  FSwitch.CloseUp;
  FSwitch.choose(index, true);
end;

procedure TThemeSwitchList.MouseLeave;
begin
  inherited MouseLeave;
  FSwitch.FListHot := -1;
  Invalidate;
end;

{ TThemeSwitch }

constructor TThemeSwitch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 15;
  FTimer.OnTimer := @tick;
  FStyle := twSwitch;
  FContent := tcIcon;
  FSpacing := 6;
  FPadding := 8;
  FGap := 6;
  FCornerRadius := 6;
  FDuration := 150;
  FPill := true;
  FAutoApply := true;
  FAnimated := true;
  FNameHints := true;
  FSelectedColor := clDefault;
  FSelectedTextColor := clDefault;
  FBarColor := clDefault;
  FBorderColor := clDefault;
  FTextColor := clDefault;
  FItemIndex := -1;
  FHot := PART_NONE;
  FPressed := PART_NONE;
  FListHot := -1;
  FThemes := TThemeSwitchItems.Create(self);
  FThemes.AddTheme(tpLight);
  FThemes.AddTheme(tpDark);
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
  // dropped on a designed form that has its theme already
  if (AOwner <> nil) and (csDesigning in ComponentState) and not (csLoading in AOwner.ComponentState) then
    for var i := 0 to AOwner.ComponentCount-1 do
      if AOwner.Components[i] is TAppTheme then begin
        setAttachTo(TAppTheme(AOwner.Components[i]));
        break;
      end;
end;

destructor TThemeSwitch.Destroy;
begin
  FTimer.Enabled := false;
  listenTo(nil);
  FreeAndNil(FPopup);
  FThemes.Free;
  FThemes := nil;
  inherited Destroy;
end;

class function TThemeSwitch.GetControlClassDefaultSize: TSize;
begin
  result.cx := 60;
  result.cy := 28;
end;

procedure TThemeSwitch.Loaded;
begin
  inherited Loaded;
  FSynced := false;
  listenTo(resolvedTheme);
  sync(false);
end;

// -- the theme ----------------------

function TThemeSwitch.resolvedTheme: TAppTheme;
begin
  result := FAttachTo;
  if result <> nil then exit;
  if csDesigning in ComponentState then begin
    // the designer holds a theme per designed form; only the one of this form counts
    if Owner <> nil then
      for var i := 0 to Owner.ComponentCount-1 do
        if Owner.Components[i] is TAppTheme then exit(TAppTheme(Owner.Components[i]));
  end else result := TAppTheme.Instance;
end;

function TThemeSwitch.Theme: TAppTheme;
begin
  result := resolvedTheme;
end;

procedure TThemeSwitch.listenTo(theme: TAppTheme);
begin
  if FListening = theme then exit;
  if FListening <> nil then begin
    FListening.RemoveHandlerChange(@themeChanged);
    if FListening <> FAttachTo then FListening.RemoveFreeNotification(self);
  end;
  FListening := theme;
  if theme <> nil then begin
    theme.AddHandlerChange(@themeChanged);
    theme.FreeNotification(self);
  end;
end;

procedure TThemeSwitch.themeChanged(Sender: TObject);
begin
  if csDestroying in ComponentState then exit;
  sync(HandleAllocated);
  Invalidate;
end;

function TThemeSwitch.presetDark(preset: TThemePreset): boolean;
begin
  match preset of
    tpNone, tpSystem: result := systemDark;
    tpCustom: begin
      var t := resolvedTheme;
      result := (t <> nil) and isDarkColor(buildPalette(t.Custom.Seed)[COLOR_BTNFACE]);
    end;
  else
    result := isDarkColor(presetPalette(preset)[COLOR_BTNFACE]);
  end;
end;

function TThemeSwitch.findCurrent: integer;
begin
  var places := shown;
  if length(places) = 0 then exit(-1);
  var t := resolvedTheme;
  var preset := tpNone;
  var dark := systemDark;
  if t = nil then preset := if dark then tpDark else tpLight
  else begin
    if t.Active then preset := t.Preset;
    dark := t.IsDark;
  end;
  // a choice made here stays while it shows what is on screen, also when
  // two items carry the same preset
  for var i in places do if (i = FItemIndex) and (FThemes[i].Preset = preset) then exit(i);
  for var i in places do if FThemes[i].Preset = preset then exit(i);
  if preset = tpSystem then
    for var i in places do if FThemes[i].Preset = (if dark then tpDark else tpLight) then exit(i);
  // no item of the preset: the first one as light or as dark as the screen
  for var i in places do if presetDark(FThemes[i].Preset) = dark then exit(i);
  result := places[0];
end;

procedure TThemeSwitch.sync(animated: boolean);
begin
  FSynced := true;
  var index := findCurrent;
  var moved := index <> FItemIndex;
  FItemIndex := index;
  // the place of an unchanged item may still have moved with the items
  if moved or not FTimer.Enabled then moveTo(animated and moved);
end;

function TThemeSwitch.getItemIndex: integer;
begin
  listenTo(resolvedTheme);
  if not FSynced then sync(false);
  result := FItemIndex;
end;

procedure TThemeSwitch.setItemIndex(value: integer);
begin
  if (value < 0) or (value >= FThemes.Count) then exit;
  choose(value, false);
end;

function TThemeSwitch.getSelectedPreset: TThemePreset;
begin
  var index := ItemIndex;
  result := if index >= 0 then FThemes[index].Preset else tpNone;
end;

procedure TThemeSwitch.choose(index: integer; byUser: boolean);
begin
  if (index < 0) or (index >= FThemes.Count) or not FThemes[index].Visible then exit;
  if placeOf(index) < 0 then exit;
  var preset := FThemes[index].Preset;
  if byUser and Assigned(FOnChanging) then begin
    var allow: boolean := true;
    FOnChanging(self, preset, allow);
    if not allow then exit;
  end;
  var changed := index <> ItemIndex;
  FItemIndex := index;
  FSynced := true;
  moveTo(HandleAllocated);
  Invalidate;
  var t := resolvedTheme;
  if FAutoApply and (t <> nil) and not (csDesigning in ComponentState) then begin
    t.Preset := preset;
    t.Active := true;
  end;
  if changed and not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self, preset);
end;

procedure TThemeSwitch.step(delta: integer);
begin
  var places := shown;
  if length(places) = 0 then exit;
  var place := placeOf(ItemIndex);
  place := if place < 0 then 0 else (place+delta+length(places)) mod length(places);
  choose(places[place], true);
end;

procedure TThemeSwitch.Next;
begin
  step(1);
end;

procedure TThemeSwitch.Previous;
begin
  step(-1);
end;

// -- the items ----------------------

function TThemeSwitch.shown: TIntegerDynArray;
begin
  result := [];
  if FThemes = nil then exit;
  for var i := 0 to FThemes.Count-1 do begin
    if not FThemes[i].Visible then continue;
    result += [i];
    if (FStyle = twSwitch) and (length(result) = 2) then break;
  end;
end;

function TThemeSwitch.placeOf(index: integer): integer;
begin
  var places := shown;
  for var i := 0 to high(places) do if places[i] = index then exit(i);
  result := -1;
end;

procedure TThemeSwitch.itemsChanged;
begin
  if csDestroying in ComponentState then exit;
  FSynced := false;
  FHot := PART_NONE;
  FPressed := PART_NONE;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- animation ----------------------

// the selection toward the place of the current item; the caller repaints,
// as this runs from Paint too
procedure TThemeSwitch.moveTo(animated: boolean);
begin
  var place := placeOf(FItemIndex);
  FTarget := Math.Max(place, 0);
  if not animated or not FAnimated or (FDuration <= 0) or (csDesigning in ComponentState) or (FStyle in [twButtons, twCycle, twDropDown, twSplitButton]) then begin
    FPos := FTarget;
    FTimer.Enabled := false;
    exit;
  end;
  FFrom := FPos;
  FStarted := GetTickCount64;
  FTimer.Enabled := true;
end;

procedure TThemeSwitch.tick(Sender: TObject);
begin
  var t := (GetTickCount64-FStarted)/FDuration;
  if t >= 1 then begin
    FPos := FTarget;
    FTimer.Enabled := false;
  end else begin
    // eased: fast out of the start, slow into the end
    t := 1-(1-t)*(1-t);
    FPos := FFrom+(FTarget-FFrom)*t;
  end;
  Invalidate;
end;

// -- geometry ----------------------

function TThemeSwitch.iconPx: integer;
begin
  result := if FIconSize > 0 then scaled(self, FIconSize) else Math.Max(Round(lineHeightOf(Font)*1.15), 12);
end;

function TThemeSwitch.iconSizeOf(item: TThemeSwitchItem): TSize;
begin
  if (FImages <> nil) and (item.ImageIndex >= 0) then exit(FImages.SizeForPPI[FImageWidth, Font.PixelsPerInch]);
  result := Size(iconPx, iconPx);
end;

function TThemeSwitch.contentSize(item: TThemeSwitchItem): TSize;
begin
  var icon := iconSizeOf(item);
  var tw := textWidthOf(Font, item.ShownCaption);
  var th := lineHeightOf(Font);
  var gap := scaled(self, FSpacing);
  match FContent of
    tcIcon: result := icon;
    tcIconAndName: result := Size(icon.cx+gap+tw, Math.Max(icon.cy, th));
    tcIconOverName: result := Size(Math.Max(icon.cx, tw), icon.cy+gap div 2+th);
  else
    result := Size(tw, th)
  end;
end;

// one size for every theme, so the bar and the buttons stay even and the
// one button styles keep their size from theme to theme
function TThemeSwitch.cellSize: TSize;
begin
  result := Size(0, 0);
  for var i in shown do begin
    var c := contentSize(FThemes[i]);
    result.cx := Math.Max(result.cx, c.cx);
    result.cy := Math.Max(result.cy, c.cy);
  end;
  if (result.cx = 0) and (result.cy = 0) then result := Size(iconPx, iconPx);
  result.cx += scaled(self, FPadding)*2;
  result.cy += scaled(self, (if FContent = tcIconOverName then 7 else 5))*2;
end;

function TThemeSwitch.arrowWidth: integer;
begin
  result := if FStyle in [twDropDown, twSplitButton] then scaled(self, 8)+scaled(self, 7)*2 else 0;
end;

// the switch: a track with a slot per theme and the thumb over one of them
function TThemeSwitch.switchSize: TSize;
begin
  var m := scaled(self, 3);
  var d := if FContent = tcName then lineHeightOf(Font)+scaled(self, 4) else iconPx+scaled(self, 8);
  result := Size(d*2+m*2+scaled(self, 4), d+m*2);
end;

function TThemeSwitch.cellRects: TCellRects;
begin
  result := [];
  var places := shown;
  var n := length(places);
  if n = 0 then exit;
  SetLength(result, n);
  var inset := if (FStyle = twSegmented) and not FFlat then scaled(self, 2) else 0;
  var gap := if FStyle = twButtons then scaled(self, FGap) else 0;
  var room := Rect(inset, inset, ClientWidth-inset, ClientHeight-inset);
  // the cells share the room the control has, so a stretched control
  // stretches its cells
  if FVertical then begin
    var h := (room.Height-gap*(n-1)) div n;
    for var i := 0 to n-1 do result[i] := Rect(room.Left, room.Top+i*(h+gap), room.Right, room.Top+i*(h+gap)+h);
    result[n-1].Bottom := room.Bottom;
  end else begin
    var w := (room.Width-gap*(n-1)) div n;
    for var i := 0 to n-1 do result[i] := Rect(room.Left+i*(w+gap), room.Top, room.Left+i*(w+gap)+w, room.Bottom);
    result[n-1].Right := room.Right;
  end;
end;

function TThemeSwitch.ItemRect(index: integer): TRect;
begin
  result := Rect(0, 0, 0, 0);
  var place := placeOf(index);
  if place < 0 then exit;
  match FStyle of
    twSegmented, twButtons: result := cellRects[place];
    twSwitch: begin
      var sw := switchSize;
      var top := (ClientHeight-sw.cy) div 2;
      result := if place = 0 then Rect(0, top, sw.cx div 2, top+sw.cy) else Rect(sw.cx div 2, top, sw.cx, top+sw.cy);
    end;
  else
    result := ClientRect
  end;
end;

function TThemeSwitch.arrowRect: TRect;
begin
  result := Rect(ClientWidth-arrowWidth, 0, ClientWidth, ClientHeight);
end;

// the item index of a cell, PART_MAIN or PART_ARROW of a button, PART_NONE outside
function TThemeSwitch.partAt(x, y: integer): integer;
begin
  result := PART_NONE;
  if not ClientRect.Contains(Point(x, y)) then exit;
  match FStyle of
    twSegmented, twButtons: begin
      var places := shown;
      var rects := cellRects;
      for var i := 0 to high(rects) do if rects[i].Contains(Point(x, y)) then exit(places[i]);
    end;
    twSplitButton: result := if arrowRect.Contains(Point(x, y)) then PART_ARROW else PART_MAIN;
  else
    result := PART_MAIN
  end;
end;

// a cell with the name under the icon is tall: round ends would make a blob
// of it, so it keeps CornerRadius
function TThemeSwitch.cornerFor(const r: TRect): integer;
begin
  var half := Math.Min(r.Width, r.Height) div 2;
  result := if FPill and ((FContent <> tcIconOverName) or (FStyle = twSwitch)) then half else Math.Min(scaled(self, FCornerRadius), half);
end;

procedure TThemeSwitch.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var n := Math.Max(length(shown), 1);
  match FStyle of
    twSwitch: begin
      var sw := switchSize;
      PreferredWidth := sw.cx;
      PreferredHeight := sw.cy;
      if FContent <> tcIcon then begin
        var widest := 0;
        for var i in shown do widest := Math.Max(widest, textWidthOf(Font, FThemes[i].ShownCaption));
        PreferredWidth += scaled(self, FSpacing)+widest;
        PreferredHeight := Math.Max(PreferredHeight, lineHeightOf(Font));
      end;
    end;
    twSegmented, twButtons: begin
      var cell := cellSize;
      var inset := if (FStyle = twSegmented) and not FFlat then scaled(self, 2) else 0;
      var gap := if FStyle = twButtons then scaled(self, FGap) else 0;
      if FVertical then begin
        PreferredWidth := cell.cx+inset*2;
        PreferredHeight := cell.cy*n+gap*(n-1)+inset*2;
      end else begin
        PreferredWidth := cell.cx*n+gap*(n-1)+inset*2;
        PreferredHeight := cell.cy+inset*2;
      end;
    end;
  else
    begin
      var cell := cellSize;
      PreferredWidth := cell.cx+arrowWidth;
      PreferredHeight := cell.cy;
    end;
  end;
end;

// -- painting ----------------------

function TThemeSwitch.glyphColor(item: TThemeSwitchItem; fallback: TColor): TColor;
begin
  if item.IconColor <> clDefault then exit(ColorToRGB(item.IconColor));
  result := if FColoredIcons then naturalGlyphColor(item.ShownGlyph) else ColorToRGB(fallback);
  if not Enabled then result := blend(result, clBtnFace, 50);
end;

procedure TThemeSwitch.faceColors(hot, pressed: boolean; out face, border: TColor);
begin
  // the steps the engine paints the native buttons with
  if themeActive or (FBarColor <> clDefault) then begin
    face := pick(FBarColor, cl3DLight);
    border := pick(FBorderColor, clBtnHighlight);
    if pressed then begin
      face := if FBarColor = clDefault then ColorToRGB(clBtnShadow) else blend(face, clWindowText, 20);
      border := pick(FBorderColor, clWindowFrame);
    end else if hot then begin
      face := if FBarColor = clDefault then hoverShade(face, clBtnHighlight) else hoverBlend(face, clWindowText, 10);
      border := pick(FBorderColor, hoverShade(clBtnHighlight, clBtnShadow));
    end;
  end else begin
    face := blend(clBtnFace, clBtnShadow, (if pressed then 30 else if hot then 10+hoverAmount(10) else 10));
    border := pick(FBorderColor, blend(clBtnShadow, clBtnFace, 25));
  end;
end;

procedure TThemeSwitch.laterImage(var later: TLaters; index, x, y: integer);
begin
  var l: TLater;
  l.Image := index;
  l.Box := Rect(x, y, x, y);
  l.Color := clNone;
  l.Text := '';
  later += [l];
end;

procedure TThemeSwitch.laterText(var later: TLaters; const box: TRect; color: TColor; const text: string);
begin
  var l: TLater;
  l.Image := -1;
  l.Box := box;
  l.Color := color;
  l.Text := text;
  later += [l];
end;

// the shapes of the content: glyphs go into the painter, the names and the
// images wait in `later` for the canvas after the flush
procedure TThemeSwitch.paintContent(sp: TSmoothPaint; const r: TRect; item: TThemeSwitchItem; fg, fill: TColor; var later: TLaters);
begin
  var icon := iconSizeOf(item);
  var withIcon := FContent <> tcName;
  var withName := FContent <> tcIcon;
  var name := item.ShownCaption;
  var tw := if withName then textWidthOf(Font, name) else 0;
  var th := lineHeightOf(Font);
  var gap := scaled(self, FSpacing);
  var iconAt := Point(0, 0);
  var textAt := Point(0, 0);
  match FContent of
    tcIcon: iconAt := Point(r.Left+(r.Width-icon.cx) div 2, r.Top+(r.Height-icon.cy) div 2);
    tcIconAndName: begin
      // a name wider than the cell is cut with an ellipsis
      tw := Math.Min(tw, Math.Max(r.Width-scaled(self, FPadding)*2-icon.cx-gap, 0));
      var left := r.Left+(r.Width-icon.cx-gap-tw) div 2;
      iconAt := Point(left, r.Top+(r.Height-icon.cy) div 2);
      textAt := Point(left+icon.cx+gap, r.Top+(r.Height-th) div 2);
    end;
    tcIconOverName: begin
      tw := Math.Min(tw, Math.Max(r.Width-scaled(self, 4)*2, 0));
      var top := r.Top+(r.Height-icon.cy-gap div 2-th) div 2;
      iconAt := Point(r.Left+(r.Width-icon.cx) div 2, top);
      textAt := Point(r.Left+(r.Width-tw) div 2, top+icon.cy+gap div 2);
    end;
  else
    begin
      tw := Math.Min(tw, Math.Max(r.Width-scaled(self, 4)*2, 0));
      textAt := Point(r.Left+(r.Width-tw) div 2, r.Top+(r.Height-th) div 2);
    end;
  end;
  if withIcon then begin
    if (FImages <> nil) and (item.ImageIndex >= 0) then laterImage(later, item.ImageIndex, iconAt.X, iconAt.Y)
    else paintThemeGlyph(sp, Rect(iconAt.X, iconAt.Y, iconAt.X+icon.cx, iconAt.Y+icon.cy), item.ShownGlyph, glyphColor(item, fg), fill);
  end;
  if withName and (tw > 0) then laterText(later, Rect(textAt.X, textAt.Y, textAt.X+tw, textAt.Y+th), fg, name);
end;

procedure TThemeSwitch.paintLater(canvas: TCanvas; const later: TLaters);
begin
  applyTextQuality(canvas);
  for var l in later do begin
    if l.Image >= 0 then begin
      if FImages <> nil then FImages.DrawForPPI(canvas, l.Box.Left, l.Box.Top, l.Image, FImageWidth, Font.PixelsPerInch, GetCanvasScaleFactor, Enabled);
      continue;
    end;
    var style := canvas.TextStyle;
    style.Alignment := taLeftJustify;
    style.Layout := tlTop;
    style.SingleLine := true;
    style.Clipping := true;
    style.EndEllipsis := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    canvas.Brush.Style := bsClear;
    canvas.Font.Color := l.Color;
    canvas.TextRect(l.Box, l.Box.Left, l.Box.Top, l.Text, style);
    canvas.Brush.Style := bsSolid;
  end;
end;

procedure TThemeSwitch.paintSwitch(sp: TSmoothPaint; var later: TLaters);
begin
  var places := shown;
  if length(places) = 0 then exit;
  var back := GetRGBColorResolvingParent;
  var text := pick(FTextColor, clBtnText);
  if not Enabled then text := ColorToRGB(clGrayText);
  var sw := switchSize;
  var m := scaled(self, 3);
  var d := sw.cy-m*2;
  var top := (ClientHeight-sw.cy) div 2;
  var track := Rect(0, top, sw.cx, top+sw.cy);
  var trackFill := pick(FBarColor, blend(back, clWindowText, 14));
  if Enabled and hoverEnabled and (FHot <> PART_NONE) then trackFill := hoverBlend(trackFill, clWindowText, (if FPressed <> PART_NONE then 12 else 6));
  var border := pick(FBorderColor, blend(back, clWindowText, 26));
  if Focused and ringEnabled then border := ringColor;
  paintRoundRect(sp, track, cornerFor(track), trackFill, border);
  // a slot for each theme, the thumb sliding between the two
  var slot0 := Rect(track.Left+m, track.Top+m, track.Left+m+d, track.Top+m+d);
  var slot1 := Rect(track.Right-m-d, track.Top+m, track.Right-m, track.Top+m+d);
  var pos: single := if length(places) > 1 then FPos else 0;
  var thumb := slot0;
  thumb.Offset(Round(pos*(slot1.Left-slot0.Left)), 0);
  var showIcons := FContent <> tcName;
  var pad := Math.Max((d-iconPx) div 2, 0);
  if showIcons then
    for var k := 0 to high(places) do begin
      var item := FThemes[places[k]];
      if (FImages <> nil) and (item.ImageIndex >= 0) then continue;
      var slot := if k = 0 then slot0 else slot1;
      slot.Inflate(-pad, -pad);
      paintThemeGlyph(sp, slot, item.ShownGlyph, blend(glyphColor(item, text), trackFill, 45), trackFill);
    end;
  var thumbFill := pick(FSelectedColor, (if FColoredIcons then clWindow else clHighlight));
  if not Enabled then thumbFill := blend(thumbFill, clBtnFace, 50);
  var thumbRadius := if FPill then d div 2 else Math.Max(cornerFor(track)-m, 0);
  paintRoundRect(sp, thumb, thumbRadius, thumbFill, blend(thumbFill, clWindowText, 18));
  var onThumb := FThemes[places[(if (pos < 0.5) or (length(places) < 2) then 0 else 1)]];
  if showIcons then begin
    var fg := if FColoredIcons then text else pick(FSelectedTextColor, contrastText(thumbFill));
    if (FImages <> nil) and (onThumb.ImageIndex >= 0) then begin
      var img := iconSizeOf(onThumb);
      laterImage(later, onThumb.ImageIndex, thumb.Left+(thumb.Width-img.cx) div 2, thumb.Top+(thumb.Height-img.cy) div 2);
    end else begin
      var inner := thumb;
      inner.Inflate(-pad, -pad);
      paintThemeGlyph(sp, inner, onThumb.ShownGlyph, glyphColor(onThumb, fg), thumbFill);
    end;
  end;
  // the name of the current theme beside the track
  if FContent <> tcIcon then begin
    var place := Math.Max(placeOf(ItemIndex), 0);
    var x := track.Right+scaled(self, FSpacing);
    var th := lineHeightOf(Font);
    var y := (ClientHeight-th) div 2;
    laterText(later, Rect(x, y, ClientWidth, y+th), text, FThemes[places[place]].ShownCaption);
  end;
end;

procedure TThemeSwitch.paintCells(sp: TSmoothPaint; var later: TLaters);
begin
  var places := shown;
  var rects := cellRects;
  if length(rects) = 0 then exit;
  var back := GetRGBColorResolvingParent;
  var text := pick(FTextColor, clBtnText);
  if not Enabled then text := ColorToRGB(clGrayText);
  var selected := pick(FSelectedColor, clHighlight);
  if not Enabled then selected := blend(selected, clBtnFace, 50);
  // colored glyphs sit on a tint, a solid fill would swallow them
  var tinted := FColoredIcons and (FSelectedColor = clDefault);
  var selectedText := pick(FSelectedTextColor, (if tinted then text else contrastText(selected)));
  var current := placeOf(ItemIndex);
  if FStyle = twSegmented then begin
    var bar := pick(FBarColor, blend(clBtnFace, clBtnShadow, 25));
    var border := pick(FBorderColor, clBtnShadow);
    if Focused and ringEnabled then border := ringColor;
    var whole := ClientRect;
    if not FFlat then begin
      paintRoundRect(sp, whole, cornerFor(whole), bar, border);
      back := bar;
    end else if Focused and ringEnabled then paintRoundRect(sp, whole, cornerFor(whole), clNone, border);
    var tint := blend(back, selected, 22);
    for var k := 0 to high(rects) do
      if Enabled and hoverEnabled and (FHot = places[k]) and (k <> current) then begin
        var r := rects[k];
        paintRoundRect(sp, r, cornerFor(r), (if FPressed = places[k] then blend(hoverColor(back), clWindowText, 10) else hoverColor(back)), clNone);
      end;
    // the selection slides between the cells
    if current >= 0 then begin
      var lo := Math.Min(Math.Max(Floor(FPos), 0), high(rects));
      var hi := Math.Min(lo+1, high(rects));
      var f := FPos-lo;
      var a := rects[lo];
      var b := rects[hi];
      var sel := Rect(Round(a.Left+(b.Left-a.Left)*f), Round(a.Top+(b.Top-a.Top)*f), Round(a.Right+(b.Right-a.Right)*f), Round(a.Bottom+(b.Bottom-a.Bottom)*f));
      paintRoundRect(sp, sel, cornerFor(sel), (if tinted then tint else selected), (if tinted then selected else clNone));
    end;
    for var k := 0 to high(rects) do begin
      var isCurrent := k = current;
      var fill := if not isCurrent then back else if tinted then tint else selected;
      paintContent(sp, rects[k], FThemes[places[k]], (if isCurrent then selectedText else text), fill, later);
    end;
    exit;
  end;
  for var k := 0 to high(rects) do begin
    var r := rects[k];
    var isCurrent := k = current;
    var hot := Enabled and hoverEnabled and (FHot = places[k]);
    var face, border: TColor;
    faceColors(hot, FPressed = places[k], face, border);
    var fill := face;
    if isCurrent then begin
      fill := if tinted then blend(face, selected, 22) else selected;
      if hot and not tinted then fill := hoverBlend(fill, clWindowText, 8);
      border := if tinted then selected else clNone;
    end else if FFlat and not hot then begin
      fill := back;
      border := clNone;
    end;
    if Focused and ringEnabled and isCurrent then border := ringColor;
    if (fill <> back) or (border <> clNone) then paintRoundRect(sp, r, cornerFor(r), (if fill = back then clNone else fill), border);
    paintContent(sp, r, FThemes[places[k]], (if isCurrent then selectedText else text), fill, later);
  end;
end;

// one button with the current theme on it: twCycle, twDropDown, twSplitButton
procedure TThemeSwitch.paintButton(sp: TSmoothPaint; var later: TLaters);
begin
  var back := GetRGBColorResolvingParent;
  var text := pick(FTextColor, clBtnText);
  if not Enabled then text := ColorToRGB(clGrayText);
  var open := DroppedDown;
  var hot := Enabled and hoverEnabled and (FHot <> PART_NONE);
  var face, border: TColor;
  faceColors(hot and not open, open or (FPressed <> PART_NONE), face, border);
  var showFace := not FFlat or hot or open or Focused or (FPressed <> PART_NONE);
  if Focused and ringEnabled then border := ringColor;
  var r := ClientRect;
  if showFace then paintRoundRect(sp, r, cornerFor(r), face, border) else face := back;
  var main := Rect(0, 0, ClientWidth-arrowWidth, ClientHeight);
  var index := ItemIndex;
  if index >= 0 then paintContent(sp, main, FThemes[index], text, face, later);
  if arrowWidth > 0 then begin
    var a := arrowRect;
    if FStyle = twSplitButton then paintLine(sp, a.Left, a.Top+scaled(self, 6), a.Left, a.Bottom-scaled(self, 6), blend(text, face, 60));
    paintChevron(sp, a, (if open then cdUp else cdDown), Math.Max(scaled(self, 8), 6), text);
  end;
end;

procedure TThemeSwitch.Paint;
begin
  listenTo(resolvedTheme);
  if not FSynced then sync(false);
  var later: TLaters := [];
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  match FStyle of
    twSwitch: paintSwitch(sp, later);
    twSegmented, twButtons: paintCells(sp, later);
  else
    paintButton(sp, later);
  end;
  sp.Flush;
  paintLater(Canvas, later);
end;

// -- input ----------------------

procedure TThemeSwitch.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus then SetFocus;
  var part := partAt(X, Y);
  if part = PART_NONE then exit;
  // the list opens on the press, like the one of a combo box
  if (FStyle = twDropDown) or ((FStyle = twSplitButton) and (part = PART_ARROW)) then begin
    if DroppedDown then CloseUp else DropDown;
    exit;
  end;
  FPressed := part;
  Invalidate;
end;

procedure TThemeSwitch.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var part := partAt(X, Y);
  if part = FHot then exit;
  FHot := part;
  Invalidate;
end;

procedure TThemeSwitch.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FPressed = PART_NONE) then exit;
  var pressed := FPressed;
  FPressed := PART_NONE;
  Invalidate;
  if partAt(X, Y) <> pressed then exit;
  match FStyle of
    twSwitch, twCycle, twSplitButton: Next;
    twSegmented, twButtons: choose(pressed, true);
  else
    ;
  end;
end;

procedure TThemeSwitch.MouseLeave;
begin
  inherited MouseLeave;
  FHot := PART_NONE;
  FPressed := PART_NONE;
  Invalidate;
end;

procedure TThemeSwitch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not Enabled or (Key = 0) then exit;
  // the open list takes the arrows, Enter and Escape
  if DroppedDown then begin
    var places := shown;
    match Key of
      VK_UP: FListHot := Math.Max(FListHot-1, 0);
      VK_DOWN: FListHot := Math.Min(FListHot+1, high(places));
      VK_RETURN, VK_SPACE: begin
        var row := FListHot;
        CloseUp;
        if (row >= 0) and (row <= high(places)) then choose(places[row], true);
      end;
      VK_ESCAPE, VK_F4: CloseUp;
    else
      exit;
    end;
    if FList <> nil then FList.Invalidate;
    Key := 0;
    exit;
  end;
  if (FStyle in [twDropDown, twSplitButton]) and ((Key = VK_F4) or ((Key = VK_DOWN) and (ssAlt in Shift))) then begin
    DropDown;
    Key := 0;
    exit;
  end;
  var places := shown;
  match Key of
    VK_LEFT, VK_UP: step(-1);
    VK_RIGHT, VK_DOWN: step(1);
    VK_HOME: if length(places) > 0 then choose(places[0], true);
    VK_END: if length(places) > 0 then choose(places[high(places)], true);
    VK_SPACE, VK_RETURN: if FStyle = twDropDown then DropDown else if FStyle in [twSwitch, twCycle, twSplitButton] then Next else exit;
  else
    exit;
  end;
  Key := 0;
end;

procedure TThemeSwitch.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TThemeSwitch.DoExit;
begin
  inherited DoExit;
  CloseUp;
  Invalidate;
end;

procedure TThemeSwitch.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
end;

procedure TThemeSwitch.CMHintShow(var Message: TLMessage);
begin
  // the hint of the control wins; without one an icon names its theme
  var info := PHintInfo(Message.LParam);
  if Hint <> '' then exit;
  var index := if FStyle in [twSegmented, twButtons] then partAt(info^.CursorPos.X, info^.CursorPos.Y) else ItemIndex;
  if index < 0 then begin
    Message.Result := 1;
    exit;
  end;
  var item := FThemes[index];
  if item.Hint <> '' then info^.HintStr := item.Hint
  else if FNameHints and ((FContent = tcIcon) or (FStyle = twSwitch)) then info^.HintStr := item.ShownCaption
  else begin
    Message.Result := 1;
    exit;
  end;
  if FStyle in [twSegmented, twButtons] then info^.CursorRect := ItemRect(index);
end;

// -- the list ----------------------

procedure TThemeSwitch.buildPopup;
begin
  if FPopup <> nil then exit;
  FPopup := TDropPopup.Create(self);
  FPopup.OnDismiss := @popupDismiss;
  var list := TThemeSwitchList.Create(FPopup);
  list.FSwitch := self;
  list.Parent := FPopup;
  FList := list;
end;

procedure TThemeSwitch.DropDown;
begin
  if (csDesigning in ComponentState) or not Enabled or DroppedDown then exit;
  if length(shown) = 0 then exit;
  buildPopup;
  FListHot := Math.Max(placeOf(ItemIndex), 0);
  var size := TThemeSwitchList(FList).Measure;
  var w := Math.Max(size.cx, Width);
  FList.SetBounds(1, 1, w, size.cy);
  FPopup.Drop(self, w+2, size.cy+2);
  Invalidate;
end;

procedure TThemeSwitch.CloseUp;
begin
  if not DroppedDown then exit;
  FPopup.Close;
  Invalidate;
end;

function TThemeSwitch.DroppedDown: boolean;
begin
  result := (FPopup <> nil) and FPopup.Visible;
end;

procedure TThemeSwitch.popupDismiss(Sender: TObject);
begin
  CloseUp;
end;

procedure TThemeSwitch.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then begin
    if AComponent = FImages then begin
      FImages := nil;
      itemsChanged;
    end;
    // the theme is going: its handler list goes with it
    if AComponent = FListening then FListening := nil;
    if AComponent = FAttachTo then FAttachTo := nil;
    if AComponent is TAppTheme then begin
      FSynced := false;
      Invalidate;
    end;
  end else if (Operation = opInsert) and (AComponent is TAppTheme) and (FAttachTo = nil) and (csDesigning in ComponentState)
    and (AComponent.Owner = Owner) and not (csLoading in ComponentState) and not (csDestroying in ComponentState) then
    // a theme dropped after the switch; it is still in its constructor, so
    // only the reference is taken now
    setAttachTo(TAppTheme(AComponent));
end;

// -- properties ----------------------

procedure TThemeSwitch.setAttachTo(value: TAppTheme);
begin
  if FAttachTo = value then exit;
  var old := FAttachTo;
  FAttachTo := value;
  if value <> nil then value.FreeNotification(self);
  if (old <> nil) and (old <> FListening) then old.RemoveFreeNotification(self);
  listenTo(value);
  FSynced := false;
  Invalidate;
end;

procedure TThemeSwitch.setThemes(value: TThemeSwitchItems);
begin
  FThemes.Assign(value);
end;

procedure TThemeSwitch.setStyle(value: TThemeSwitchStyle);
begin
  if FStyle = value then exit;
  CloseUp;
  FStyle := value;
  itemsChanged;
end;

procedure TThemeSwitch.setContent(value: TThemeSwitchContent);
begin
  if FContent = value then exit;
  FContent := value;
  itemsChanged;
end;

procedure TThemeSwitch.setImages(value: TCustomImageList);
begin
  if FImages = value then exit;
  if FImages <> nil then FImages.RemoveFreeNotification(self);
  FImages := value;
  if FImages <> nil then FImages.FreeNotification(self);
  itemsChanged;
end;

procedure TThemeSwitch.setImageWidth(value: integer);
begin
  if value < 0 then value := 0;
  if FImageWidth = value then exit;
  FImageWidth := value;
  itemsChanged;
end;

function TThemeSwitch.getMetric(index: integer): integer;
begin
  match index of
    0: result := FIconSize;
    1: result := FSpacing;
    2: result := FPadding;
    3: result := FGap;
    4: result := FCornerRadius;
    _: result := FDuration;
  end;
end;

procedure TThemeSwitch.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FIconSize := value;
    1: FSpacing := value;
    2: FPadding := value;
    3: FGap := value;
    4: FCornerRadius := value;
    _: FDuration := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TThemeSwitch.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FPill;
    1: result := FVertical;
    2: result := FFlat;
    3: result := FColoredIcons;
    4: result := FAutoApply;
    5: result := FAnimated;
    _: result := FNameHints;
  end;
end;

procedure TThemeSwitch.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FPill := value;
    1: FVertical := value;
    2: FFlat := value;
    3: FColoredIcons := value;
    4: FAutoApply := value;
    5: FAnimated := value;
    _: FNameHints := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TThemeSwitch.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FSelectedColor;
    1: result := FSelectedTextColor;
    2: result := FBarColor;
    3: result := FBorderColor;
    _: result := FTextColor;
  end;
end;

procedure TThemeSwitch.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FSelectedColor := value;
    1: FSelectedTextColor := value;
    2: FBarColor := value;
    3: FBorderColor := value;
    _: FTextColor := value;
  end;
  Invalidate;
end;

procedure TThemeSwitch.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
