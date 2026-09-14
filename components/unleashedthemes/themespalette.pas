{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesPalette;

{$mode unleashed}

interface

uses
  Graphics, LCLType;

const
  // warm accent past the system range, marks unsaved editor pages
  COLOR_MARK = COLOR_ENDCOLORS+1;
  // fill under the mouse on toolbar buttons, tabs and header items
  COLOR_HOVER = COLOR_MARK+1;

type
  // system color table indexed by the COLOR_xxx constants
  TPalette = array[0..COLOR_HOVER] of TColor;

// neutral gray with a blue accent
function lightPalette: TPalette;
// neutral graphite
function darkPalette: TPalette;
// blue-gray with a frost accent
function oceanPalette: TPalette;
// light blue-gray, the day twin of ocean
function frostPalette: TPalette;
// warm cream with a teal accent
function paperPalette: TPalette;
// warm brown-graphite with an amber accent
function emberPalette: TPalette;
// near black
function midnightPalette: TPalette;
// violet-navy with a lavender accent
function duskPalette: TPalette;

implementation

// RRGGBB literal to TColor
function rgb(hex: cardinal): TColor;
begin
  result := RGBToColor((hex shr 16) and $FF, (hex shr 8) and $FF, hex and $FF);
end;

// `a` moved `percent` of the way toward `b`
function mix(a, b: TColor; percent: integer): TColor;
begin
  result := RGBToColor(Red(a)+(Red(b)-Red(a))*percent div 100, Green(a)+(Green(b)-Green(a))*percent div 100, Blue(a)+(Blue(b)-Blue(a))*percent div 100);
end;

function lightPalette: TPalette;
begin
  var face := rgb($F3F4F6);
  var text := rgb($1F2328);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($FFFFFF);
  result[COLOR_MENU] := rgb($FFFFFF);
  result[COLOR_MENUBAR] := face;
  result[COLOR_SCROLLBAR] := rgb($EEF0F3);
  result[COLOR_WINDOWFRAME] := rgb($9AA0A8);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($B6BAC0);
  result[COLOR_3DLIGHT] := rgb($E2E5E9);
  result[COLOR_BTNHIGHLIGHT] := rgb($D5D8DC);
  result[COLOR_HIGHLIGHT] := rgb($3D7BD9);
  result[COLOR_HOTLIGHT] := rgb($3D7BD9);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 16);
  result[COLOR_HOVER] := mix(face, text, 12);
  result[COLOR_GRAYTEXT] := rgb($9AA0A8);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := rgb($FFFFFF);
  result[COLOR_INFOTEXT] := text;
  result[COLOR_INFOBK] := rgb($FFFFFF);
  result[COLOR_MARK] := rgb($D9822B);
end;

// the 3D shades stay visible on the dark face instead of near-black: tree
// lines, bevels and separators draw with them
function darkPalette: TPalette;
begin
  var face := rgb($2D2D2D);
  var text := rgb($E6E6E6);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($1E1E1E);
  result[COLOR_MENU] := rgb($2B2B2B);
  result[COLOR_MENUBAR] := result[COLOR_MENU];
  result[COLOR_WINDOWFRAME] := rgb($6E6E6E);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($1C1C1C);
  result[COLOR_3DLIGHT] := rgb($383838);
  result[COLOR_BTNHIGHLIGHT] := rgb($464646);
  result[COLOR_HIGHLIGHT] := rgb($264F78);
  result[COLOR_HOTLIGHT] := rgb($569CD6);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 25);
  result[COLOR_HOVER] := mix(face, text, 14);
  result[COLOR_GRAYTEXT] := rgb($8C8C8C);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := text;
  result[COLOR_INFOTEXT] := text;
  result[COLOR_INFOBK] := result[COLOR_MENU];
  result[COLOR_MARK] := rgb($E0A458);
end;

function oceanPalette: TPalette;
begin
  var face := rgb($2E3440);
  var text := rgb($D8DEE9);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($272C36);
  result[COLOR_MENU] := rgb($333A47);
  result[COLOR_MENUBAR] := result[COLOR_MENU];
  result[COLOR_SCROLLBAR] := rgb($2A303B);
  result[COLOR_WINDOWFRAME] := rgb($606D88);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($566179);
  result[COLOR_3DLIGHT] := rgb($434C5E);
  result[COLOR_BTNHIGHLIGHT] := rgb($4C566A);
  result[COLOR_HIGHLIGHT] := rgb($3E5F8A);
  result[COLOR_HOTLIGHT] := rgb($5FA8C7);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 25);
  result[COLOR_HOVER] := mix(face, text, 15);
  result[COLOR_GRAYTEXT] := rgb($697386);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := rgb($FFFFFF);
  result[COLOR_INFOTEXT] := rgb($E5E9F0);
  result[COLOR_INFOBK] := rgb($3B4252);
  result[COLOR_MARK] := rgb($D08770);
end;

function frostPalette: TPalette;
begin
  var face := rgb($E5E9F0);
  var text := rgb($2E3440);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($F4F6F9);
  result[COLOR_MENU] := rgb($F4F6F9);
  result[COLOR_MENUBAR] := face;
  result[COLOR_SCROLLBAR] := rgb($E9EDF2);
  result[COLOR_WINDOWFRAME] := rgb($9AA3B5);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($B8C0CE);
  result[COLOR_3DLIGHT] := rgb($D8DEE9);
  result[COLOR_BTNHIGHLIGHT] := rgb($CBD2DE);
  result[COLOR_HIGHLIGHT] := rgb($5E81AC);
  result[COLOR_HOTLIGHT] := rgb($4A76A8);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 16);
  result[COLOR_HOVER] := mix(face, text, 14);
  result[COLOR_GRAYTEXT] := rgb($8A93A5);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := rgb($FFFFFF);
  result[COLOR_INFOTEXT] := text;
  result[COLOR_INFOBK] := rgb($FFFFFF);
  result[COLOR_MARK] := rgb($D08770);
end;

// the selection is a deep sand under dark text; white text on a warm
// accent reads poorly
function paperPalette: TPalette;
begin
  var face := rgb($EFE8D8);
  var text := rgb($3B3A36);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($FBF7EE);
  result[COLOR_MENU] := rgb($FBF7EE);
  result[COLOR_MENUBAR] := face;
  result[COLOR_SCROLLBAR] := rgb($F2ECDF);
  result[COLOR_WINDOWFRAME] := rgb($A89F8C);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($C4BBA7);
  result[COLOR_3DLIGHT] := rgb($E2D9C5);
  result[COLOR_BTNHIGHLIGHT] := rgb($D6CCB6);
  result[COLOR_HIGHLIGHT] := rgb($CFAA5E);
  result[COLOR_HOTLIGHT] := rgb($2E7D83);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 16);
  result[COLOR_HOVER] := mix(face, text, 15);
  result[COLOR_GRAYTEXT] := rgb($9A9282);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := text;
  result[COLOR_INFOTEXT] := text;
  result[COLOR_INFOBK] := rgb($FBF7EE);
  result[COLOR_MARK] := rgb($C0582B);
end;

function emberPalette: TPalette;
begin
  var face := rgb($32302F);
  var text := rgb($EBDBB2);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($282828);
  result[COLOR_MENU] := rgb($3A3735);
  result[COLOR_MENUBAR] := result[COLOR_MENU];
  result[COLOR_SCROLLBAR] := rgb($2C2A29);
  result[COLOR_WINDOWFRAME] := rgb($7C6F64);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($665C54);
  result[COLOR_3DLIGHT] := rgb($45403D);
  result[COLOR_BTNHIGHLIGHT] := rgb($504945);
  result[COLOR_HIGHLIGHT] := rgb($7C5B2C);
  result[COLOR_HOTLIGHT] := rgb($D79921);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 25);
  result[COLOR_HOVER] := mix(face, text, 15);
  result[COLOR_GRAYTEXT] := rgb($928374);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := rgb($FBF1C7);
  result[COLOR_INFOTEXT] := text;
  result[COLOR_INFOBK] := rgb($3C3836);
  result[COLOR_MARK] := rgb($E8643C);
end;

function midnightPalette: TPalette;
begin
  var face := rgb($141414);
  var text := rgb($D4D4D4);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($0A0A0A);
  result[COLOR_MENU] := rgb($181818);
  result[COLOR_MENUBAR] := result[COLOR_MENU];
  result[COLOR_SCROLLBAR] := rgb($101010);
  result[COLOR_WINDOWFRAME] := rgb($5A5A5A);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($3A3A3A);
  result[COLOR_3DLIGHT] := rgb($262626);
  result[COLOR_BTNHIGHLIGHT] := rgb($333333);
  result[COLOR_HIGHLIGHT] := rgb($224A7A);
  result[COLOR_HOTLIGHT] := rgb($4FA3FF);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 20);
  result[COLOR_HOVER] := mix(face, text, 13);
  result[COLOR_GRAYTEXT] := rgb($7A7A7A);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := rgb($FFFFFF);
  result[COLOR_INFOTEXT] := text;
  result[COLOR_INFOBK] := rgb($1C1C1C);
  result[COLOR_MARK] := rgb($E0A458);
end;

function duskPalette: TPalette;
begin
  var face := rgb($2B2640);
  var text := rgb($E0DEF4);
  for var i := low(result) to high(result) do result[i] := face;
  result[COLOR_WINDOW] := rgb($221E33);
  result[COLOR_MENU] := rgb($322C4A);
  result[COLOR_MENUBAR] := result[COLOR_MENU];
  result[COLOR_SCROLLBAR] := rgb($262137);
  result[COLOR_WINDOWFRAME] := rgb($6E6590);
  result[COLOR_3DDKSHADOW] := result[COLOR_WINDOWFRAME];
  result[COLOR_BTNSHADOW] := rgb($5A527A);
  result[COLOR_3DLIGHT] := rgb($3D3658);
  result[COLOR_BTNHIGHLIGHT] := rgb($4A4268);
  result[COLOR_HIGHLIGHT] := rgb($5B4B94);
  result[COLOR_HOTLIGHT] := rgb($C4A7E7);
  result[COLOR_MENUHILIGHT] := mix(result[COLOR_MENU], result[COLOR_HOTLIGHT], 20);
  result[COLOR_HOVER] := mix(face, text, 14);
  result[COLOR_GRAYTEXT] := rgb($7F7A99);
  result[COLOR_WINDOWTEXT] := text;
  result[COLOR_MENUTEXT] := text;
  result[COLOR_BTNTEXT] := text;
  result[COLOR_CAPTIONTEXT] := text;
  result[COLOR_INACTIVECAPTIONTEXT] := text;
  result[COLOR_HIGHLIGHTTEXT] := rgb($FFFFFF);
  result[COLOR_INFOTEXT] := text;
  result[COLOR_INFOBK] := rgb($3D3658);
  result[COLOR_MARK] := rgb($EBA96A);
end;

end.
