{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesSeed;

{$mode unleashed}

interface

uses
  Graphics, LCLType, ThemesPalette;

type
  // the few colors a palette grows from; every other slot is a shade of the
  // surface or a blend of these
  TThemeSeed = record
    Surface: TColor; // COLOR_BTNFACE: forms, panels, buttons, tool bars
    Text: TColor;    // text on the surface and in windows
    Accent: TColor;  // COLOR_HIGHLIGHT: the selection
    Link: TColor;    // COLOR_HOTLIGHT: links, the strip of the active tab
    Mark: TColor;    // COLOR_MARK: a changed or unsaved item
    // lightness of the fields (COLOR_WINDOW: edits, lists, pages) against
    // the surface, in percent points: positive is brighter than the surface,
    // negative deeper. A light look keeps white fields on a gray surface, a
    // dark look sinks the fields below the panels
    FieldLightness: integer;
    // share of the text blended into the surface under the mouse
    HoverStrength: integer;
  end;

// grows a palette from the seed. The surface is dark when its luma is below
// half; the 3D shades then lift off the surface instead of sinking into it
function buildPalette(const seed: TThemeSeed): TPalette;
// the seed a palette grows back from: buildPalette of it keeps the seed
// colors and the window exactly and approximates the shades
function seedOf(const pal: TPalette): TThemeSeed;
// luma below half
function isDarkColor(color: TColor): boolean;
// the color with its lightness moved by `delta` percent points, hue and
// saturation kept
function shiftLightness(color: TColor; delta: integer): TColor;
// lightness of the color in percent
function lightnessOf(color: TColor): integer;
// the color turned on the hue wheel by `hue` degrees, its saturation moved
// by `sat` and its lightness by `light` percent points
function adjustColor(color: TColor; hue, sat, light: integer): TColor;
// the whole palette adjusted the same way; the text slots keep their
// lightness, so the contrast of the text survives the move
function adjustPalette(const pal: TPalette; hue, sat, light: integer): TPalette;

implementation

uses
  Math, ThemesIcons;

function isDarkColor(color: TColor): boolean;
begin
  var r, g, b: byte;
  RedGreenBlue(ColorToRGB(color), r, g, b);
  result := (r*299+g*587+b*114) div 1000 < 128;
end;

function lightnessOf(color: TColor): integer;
begin
  var r, g, b: byte;
  RedGreenBlue(ColorToRGB(color), r, g, b);
  var h, s, l: single;
  rgbToHsl(r, g, b, h, s, l);
  result := round(l*100);
end;

function adjustColor(color: TColor; hue, sat, light: integer): TColor;
begin
  if (hue = 0) and (sat = 0) and (light = 0) then exit(ColorToRGB(color));
  var r, g, b: byte;
  RedGreenBlue(ColorToRGB(color), r, g, b);
  var h, s, l: single;
  rgbToHsl(r, g, b, h, s, l);
  h := h+hue/60;
  while h < 0 do h += 6;
  while h >= 6 do h -= 6;
  hslToRgb(h, EnsureRange(s+sat/100, 0, 1), EnsureRange(l+light/100, 0, 1), r, g, b);
  result := RGBToColor(r, g, b);
end;

function adjustPalette(const pal: TPalette; hue, sat, light: integer): TPalette;
const
  TEXT_SLOTS = [COLOR_WINDOWTEXT, COLOR_MENUTEXT, COLOR_BTNTEXT, COLOR_CAPTIONTEXT, COLOR_INACTIVECAPTIONTEXT, COLOR_INFOTEXT, COLOR_GRAYTEXT, COLOR_HIGHLIGHTTEXT];
begin
  for var i := low(pal) to high(pal) do
    result[i] := adjustColor(pal[i], hue, sat, if i in TEXT_SLOTS then 0 else light);
end;

function shiftLightness(color: TColor; delta: integer): TColor;
begin
  var r, g, b: byte;
  RedGreenBlue(ColorToRGB(color), r, g, b);
  var h, s, l: single;
  rgbToHsl(r, g, b, h, s, l);
  hslToRgb(h, s, EnsureRange(l+delta/100, 0, 1), r, g, b);
  result := RGBToColor(r, g, b);
end;

// a shade of the surface for frames and bevels: the lightness moves by
// `delta` percent points and the saturation drops with the move, so a tinted
// surface gets grayish edges instead of vivid ones
function shade(color: TColor; delta: integer): TColor;
begin
  var r, g, b: byte;
  RedGreenBlue(color, r, g, b);
  var h, s, l: single;
  rgbToHsl(r, g, b, h, s, l);
  hslToRgb(h, s*(1-abs(delta)/100), EnsureRange(l+delta/100, 0, 1), r, g, b);
  result := RGBToColor(r, g, b);
end;

function buildPalette(const seed: TThemeSeed): TPalette;
begin
  var face := ColorToRGB(seed.Surface);
  var text := ColorToRGB(seed.Text);
  var dark := isDarkColor(face);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := shiftLightness(face, seed.FieldLightness);
  // menus sit a step above a dark surface and share the window on a light one
  result[COLOR_MENU] := if dark then shiftLightness(face, 2) else result[COLOR_WINDOW];
  result[COLOR_MENUBAR] := if dark then result[COLOR_MENU] else face;
  result[COLOR_SCROLLBAR] := shade(face, -2);
  result[COLOR_WINDOWFRAME] := shade(face, if dark then 25 else -32);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := shade(face, if dark then 18 else -20);
  result[COLOR_3DLIGHT] := shade(face, if dark then 6 else -5);
  result[COLOR_BTNHIGHLIGHT] := shade(face, if dark then 10 else -10);
  result[COLOR_HIGHLIGHT] := ColorToRGB(seed.Accent);
  result[COLOR_HOTLIGHT] := ColorToRGB(seed.Link);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], if dark then 25 else 16);
  result[COLOR_HOVER] := mix(face, text, seed.HoverStrength);
  result[COLOR_GRAYTEXT] := mix(face, text, 45);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_INFOTEXT] := text;
  // white on a deep selection; a pale selection takes dark ink, which is the
  // text on a light surface and the window on a dark one
  if isDarkColor(result[COLOR_HIGHLIGHT]) then result[COLOR_HIGHLIGHTTEXT] := clWhite
  else result[COLOR_HIGHLIGHTTEXT] := if dark then result[COLOR_WINDOW] else text;
  result[COLOR_INFOBK] := if dark then result[COLOR_MENU] else result[COLOR_WINDOW];
  result[COLOR_MARK] := ColorToRGB(seed.Mark);
end;

function seedOf(const pal: TPalette): TThemeSeed;
begin
  result.Surface := pal[COLOR_BTNFACE];
  result.Text := pal[COLOR_BTNTEXT];
  result.Accent := pal[COLOR_HIGHLIGHT];
  result.Link := pal[COLOR_HOTLIGHT];
  result.Mark := pal[COLOR_MARK];
  result.FieldLightness := lightnessOf(pal[COLOR_WINDOW])-lightnessOf(pal[COLOR_BTNFACE]);
  result.HoverStrength := 20;
end;

end.
