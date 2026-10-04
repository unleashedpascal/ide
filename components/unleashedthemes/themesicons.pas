{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesIcons;

{$mode unleashed}

interface

uses
  Graphics, LazIDEIntf;

// fits every icon of the process to `surface`, the color under tool bars and
// menus, with the fit in use, and keeps fitting icons loaded later. The stock
// icons are drawn for a light surface: on a dark one their lightness is
// remapped into a band that stays readable without glare, and a disabled icon
// is a faded copy with the same math on every widgetset
procedure themeIcons(surface: TColor);
// the fit the next themeIcons uses
procedure useIconFit(const value: TIconFit);
// the fit, onto the screen at once
procedure applyIconFit(const value: TIconFit);
function currentIconFit: TIconFit;

implementation

uses
  Math, LCLType, GraphType, ImgList;

const
  // a surface below this lightness gets the dark remap
  DARK_SURFACE = 0.5;

var
  fit: TIconFit;
  lastSurface: TColor = clBtnFace;
  surfaceL: single = 1;
  darkSurface: boolean = false;
  // the fit as 0..1 factors
  strength, minContrast, maxLightness, disabledContrast, disabledSaturation: single;

// h in sixths of the hue circle, s and l in 0..1
procedure rgbToHsl(r, g, b: byte; out h, s, l: single);
begin
  var rf := r/255;
  var gf := g/255;
  var bf := b/255;
  var hi := max(rf, max(gf, bf));
  var lo := min(rf, min(gf, bf));
  l := (hi+lo)/2;
  h := 0;
  s := 0;
  if hi = lo then exit;
  var d := hi-lo;
  s := if l > 0.5 then d/(2-hi-lo) else d/(hi+lo);
  if hi = rf then h := (gf-bf)/d
  else if hi = gf then h := (bf-rf)/d+2
  else h := (rf-gf)/d+4;
  if h < 0 then h += 6;
end;

function channel(p, q, t: single): single;
begin
  if t < 0 then t += 6;
  if t >= 6 then t -= 6;
  if t < 1 then result := p+(q-p)*t
  else if t < 3 then result := q
  else if t < 4 then result := p+(q-p)*(4-t)
  else result := p;
end;

function toByte(v: single): byte;
begin
  result := EnsureRange(round(v*255), 0, 255);
end;

procedure hslToRgb(h, s, l: single; out r, g, b: byte);
begin
  if s = 0 then begin
    r := toByte(l);
    g := r;
    b := r;
    exit;
  end;
  var q := if l < 0.5 then l*(1+s) else l+s-l*s;
  var p := 2*l-q;
  r := toByte(channel(p, q, h+2));
  g := toByte(channel(p, q, h));
  b := toByte(channel(p, q, h-2));
end;

procedure fitPixels(data: PRGBAQuad; count: integer; effect: TGraphicsDrawEffect);
begin
  var h, s, l: single;
  for var i := 1 to count do begin
    if data^.Alpha <> 0 then begin
      rgbToHsl(data^.Red, data^.Green, data^.Blue, h, s, l);
      if darkSurface then begin
        // the whole 0..1 range lands between the readable floor and the glare
        // cap, so shading keeps its order; a lifted color loses some saturation
        // so it does not turn neon
        var base := surfaceL+minContrast;
        var lifted := base+l*(maxLightness-base);
        var lift := strength*(lifted-l);
        s := s*(1-0.5*max(lift, 0.0));
        l := l+lift;
      end;
      if effect = gdeDisabled then begin
        l := surfaceL+(l-surfaceL)*disabledContrast;
        s := s*disabledSaturation;
      end;
      hslToRgb(h, s, EnsureRange(l, 0, 1), data^.Red, data^.Green, data^.Blue);
    end;
    inc(data);
  end;
end;

procedure themeIcons(surface: TColor);
begin
  lastSurface := surface;
  var r, g, b: byte;
  RedGreenBlue(ColorToRGB(surface), r, g, b);
  var h, s: single;
  rgbToHsl(r, g, b, h, s, surfaceL);
  darkSurface := surfaceL < DARK_SURFACE;
  ImageListPixelFilter := if fit.Enabled then @fitPixels else nil;
  ImageListFilterChanged;
end;

procedure useIconFit(const value: TIconFit);
begin
  fit := value;
  strength := EnsureRange(value.Strength, 0, 100)/100;
  minContrast := EnsureRange(value.MinContrast, 0, 100)/100;
  maxLightness := EnsureRange(value.MaxLightness, 0, 100)/100;
  disabledContrast := EnsureRange(value.DisabledContrast, 0, 100)/100;
  disabledSaturation := EnsureRange(value.DisabledSaturation, 0, 100)/100;
end;

procedure applyIconFit(const value: TIconFit);
begin
  useIconFit(value);
  themeIcons(lastSurface);
end;

function currentIconFit: TIconFit;
begin
  result := fit;
end;

initialization
  useIconFit(DefaultIconFit);
end.
