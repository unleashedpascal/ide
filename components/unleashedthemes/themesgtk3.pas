{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemesGtk3;

{$mode unleashed}

interface

{$ifdef LCLGtk3}
uses
  ThemesPalette;

// restyles every IDE window with the palette: a css provider on the screen
// covers the gtk widgets, the LCL system colors follow for the custom drawn ones
procedure applyPalette(const newPal: TPalette);
// hands every window back to the stock gtk theme
procedure dropPalette;
{$endif}

implementation

{$ifdef LCLGtk3}
uses
  Classes, SysUtils, Forms, Controls, Graphics, LCLType, LCLIntf, WSControls,
  LazGtk3, LazGdk3, LazGObject2, LazGLib2, Gtk3Int, Gtk3Procs, Gtk3Objects;

var
  provider: PGtkCssProvider = nil;
  stockColors: array[0..MAX_SYS_COLORS] of DWORD;
  palColors: array[0..MAX_SYS_COLORS] of DWORD;
  stockDark: gboolean = False;
  // designed controls painting right now, nested
  designDepth: integer = 0;

function hex(color: TColor): string;
begin
  var rgb := ColorToRGB(color);
  result := Format('#%.2x%.2x%.2x', [Red(rgb), Green(rgb), Blue(rgb)]);
end;

// every selector of the comma separated list, under the scope
function scoped(const scope, selectors: string): string;
begin
  result := '';
  for var sel in selectors.Split([',']) do begin
    if result <> '' then result := result + ', ';
    result := result + scope + sel.Trim;
  end;
end;

// the named colors the LCL reads back for its system colors
function namedColors(const pal: TPalette): string;
begin
  var face := hex(pal[COLOR_BTNFACE]);
  var fore := hex(pal[COLOR_BTNTEXT]);
  var base := hex(pal[COLOR_WINDOW]);
  var highlight := hex(pal[COLOR_HIGHLIGHT]);
  var highlightText := hex(pal[COLOR_HIGHLIGHTTEXT]);
  result :=
    '@define-color theme_bg_color '+face+';'+
    '@define-color theme_fg_color '+fore+';'+
    '@define-color theme_base_color '+base+';'+
    '@define-color theme_text_color '+hex(pal[COLOR_WINDOWTEXT])+';'+
    '@define-color theme_selected_bg_color '+highlight+';'+
    '@define-color theme_selected_fg_color '+highlightText+';'+
    '@define-color theme_unfocused_bg_color '+face+';'+
    '@define-color theme_unfocused_fg_color '+fore+';'+
    '@define-color theme_unfocused_base_color '+base+';'+
    '@define-color theme_unfocused_selected_bg_color '+highlight+';'+
    '@define-color theme_unfocused_selected_fg_color '+highlightText+';'+
    '@define-color theme_tooltip_bg_color '+hex(pal[COLOR_INFOBK])+';'+
    '@define-color theme_tooltip_fg_color '+hex(pal[COLOR_INFOTEXT])+';'+
    '@define-color borders '+hex(pal[COLOR_WINDOWFRAME])+';'+
    '@define-color unfocused_borders '+hex(pal[COLOR_WINDOWFRAME])+';'+
    '@define-color insensitive_fg_color '+hex(pal[COLOR_GRAYTEXT])+';'+
    '@define-color insensitive_bg_color '+face+';'+
    '@define-color insensitive_base_color '+base+';';
end;

// the rules for a palette, covering the widgets the stock theme paints. The
// scope goes in front of every selector: none for the IDE, the designer class
// for the designed forms, which get the stock colors this way
function styleSheet(const pal: TPalette; const scope: string): string;

  function s(const selectors: string): string;
  begin
    result := scoped(scope, selectors);
  end;

begin
  var face := hex(pal[COLOR_BTNFACE]);
  var fore := hex(pal[COLOR_BTNTEXT]);
  var base := hex(pal[COLOR_WINDOW]);
  var baseText := hex(pal[COLOR_WINDOWTEXT]);
  var shadow := hex(pal[COLOR_BTNSHADOW]);
  var highlight := hex(pal[COLOR_HIGHLIGHT]);
  var highlightText := hex(pal[COLOR_HIGHLIGHTTEXT]);
  var hover := hex(pal[COLOR_HOVER]);
  var gray := hex(pal[COLOR_GRAYTEXT]);
  var menuBack := hex(pal[COLOR_MENU]);
  var menuText := hex(pal[COLOR_MENUTEXT]);
  result :=
    // containers and everything windowless inside them
    s('window, dialog, .background, popover, popover > *, toolbar, headerbar, .titlebar, '+
    'paned, box, grid, fixed, layout, stack, scrolledwindow, viewport, frame, frame > border, '+
    'notebook, notebook > header, notebook > header > tabs, notebook > stack, expander, '+
    'statusbar, actionbar, searchbar, revealer, overlay, infobar, infobar > revealer > box')+
    ' { background-color: '+face+'; color: '+fore+'; background-image: none; }'+
    // inside a widget whose background follows its state (a hovered button, the
    // current tab) the containers around the text show through instead of
    // keeping the plain face color
    s('button box, button grid, button label, button image, button arrow, button cellview, '+
    'tab box, tab grid, tab label, tab image, '+
    'menuitem box, menuitem grid, menuitem label, menuitem image, menuitem arrow, '+
    'checkbutton box, checkbutton label, radiobutton box, radiobutton label, '+
    'expander title box, expander title label, treeview header button box, treeview header button label')+
    ' { background-color: transparent; background-image: none; }'+
    // gtk dashes the edges a scrolled window can still scroll past; an LCL
    // control scrolls on its own, so the dashes only frame it
    s('undershoot')+' { background-image: none; }'+
    // data views
    s('entry, entry > text, spinbutton, spinbutton > text, textview, textview > text, text, '+
    'treeview, treeview.view, list, listbox, row, iconview, .view, calendar, combobox entry')+
    ' { background-color: '+base+'; color: '+baseText+'; background-image: none; caret-color: '+baseText+'; }'+
    s('entry, spinbutton')+' { border-color: '+shadow+'; box-shadow: none; }'+
    s('entry:focus, spinbutton:focus')+' { border-color: '+highlight+'; }'+
    s('treeview header button, treeview.view header button')+
    ' { background-color: '+face+'; color: '+fore+'; border-color: '+shadow+'; background-image: none; }'+
    // buttons and tabs
    s('button, button.text-button, button.image-button, button.flat, spinbutton button, combobox button, '+
    'notebook > header tab, toolbar button, scale slider')+
    ' { background-color: '+face+'; color: '+fore+'; border-color: '+shadow+'; '+
    '  background-image: none; box-shadow: none; text-shadow: none; -gtk-icon-shadow: none; }'+
    s('button:hover, notebook > header tab:hover, toolbar button:hover')+' { background-color: '+hover+'; }'+
    s('button:active, button:checked')+' { background-color: '+hex(pal[COLOR_BTNHIGHLIGHT])+'; }'+
    s('notebook > header tab:checked')+' { background-color: '+base+'; color: '+baseText+'; }'+
    s('check, radio')+' { background-color: '+base+'; color: '+baseText+'; border-color: '+shadow+'; '+
    '  background-image: none; box-shadow: none; -gtk-icon-shadow: none; }'+
    s('check:checked, radio:checked, check:indeterminate')+
    ' { background-color: '+highlight+'; color: '+highlightText+'; border-color: '+highlight+'; }'+
    // the radio node is square; the fill stays inside the ring, and an empty
    // ring shows only its border
    s('radio')+' { background-color: transparent; border-radius: 100%; }'+
    // menus
    s('menubar')+' { background-color: '+hex(pal[COLOR_MENUBAR])+'; color: '+fore+'; background-image: none; box-shadow: none; }'+
    s('menu, .menu, .context-menu, popover.menu')+
    ' { background-color: '+menuBack+'; color: '+menuText+'; border-color: '+shadow+'; background-image: none; }'+
    s('menuitem')+' { background-color: transparent; color: '+menuText+'; }'+
    s('menuitem:hover, menubar > menuitem:hover')+' { background-color: '+hex(pal[COLOR_MENUHILIGHT])+'; color: '+menuText+'; box-shadow: none; }'+
    s('menu separator, .menu separator')+' { background-color: '+shadow+'; }'+
    // scroll bars, sliders and progress
    s('scrollbar, scrollbar trough, scrollbar contents')+' { background-color: '+hex(pal[COLOR_SCROLLBAR])+'; background-image: none; border-color: '+hex(pal[COLOR_SCROLLBAR])+'; }'+
    s('scrollbar slider')+' { background-color: '+shadow+'; border-color: '+hex(pal[COLOR_SCROLLBAR])+'; }'+
    s('scrollbar slider:hover, scrollbar slider:active')+' { background-color: '+gray+'; }'+
    // the corner where the two bars meet
    s('scrolledwindow junction')+' { background-color: '+hex(pal[COLOR_SCROLLBAR])+'; border-color: '+hex(pal[COLOR_SCROLLBAR])+'; border-image: none; }'+
    s('scale trough, progressbar trough')+' { background-color: '+hex(pal[COLOR_SCROLLBAR])+'; border-color: '+shadow+'; background-image: none; }'+
    s('scale highlight, progressbar progress')+' { background-color: '+highlight+'; border-color: '+highlight+'; background-image: none; }'+
    // separators and tooltips
    s('separator, paned > separator')+' { background-color: '+shadow+'; background-image: none; }'+
    s('tooltip, tooltip.background, tooltip *')+' { background-color: '+hex(pal[COLOR_INFOBK])+'; color: '+hex(pal[COLOR_INFOTEXT])+'; '+
    '  border-color: '+shadow+'; background-image: none; }'+
    // selection and disabled state
    s('*:selected, treeview:selected, treeview.view:selected, row:selected, row:selected label, '+
    'entry selection, textview selection, textview > text selection, label selection, '+
    'iconview:selected, calendar:selected')+
    ' { background-color: '+highlight+'; color: '+highlightText+'; }'+
    s('*:disabled')+' { color: '+gray+'; -gtk-icon-effect: dim; }';
end;

// the stock system colors as a palette, for the designed forms
function stockPalette: TPalette;
begin
  for var i := 0 to MAX_SYS_COLORS do result[i] := TColor(stockColors[i]);
  result[COLOR_MARK] := result[COLOR_HIGHLIGHT];
  result[COLOR_HOVER] := result[COLOR_3DLIGHT];
end;

// the LCL keeps its system colors in a table filled once from the theme; the
// palette goes in there and into the cached brushes made from it
procedure pushSysColors(const colors: array of DWORD);
begin
  for var i := 0 to MAX_SYS_COLORS do begin
    SysColorMap[i] := colors[i];
    var brush := GetSysColorBrush(i);
    if brush = 0 then continue;
    // the brush still points at the last device context it was selected
    // into, which is gone by now; the color setter would draw into it
    TGtk3Brush(brush).Context := nil;
    TGtk3Brush(brush).Color := colors[i];
  end;
end;

// serves the stock system colors while a designed control paints or takes
// its color, so the designed form looks like the running program. Designed
// controls paint inside each other, so only the outermost one switches
procedure designColorHook(active: boolean);
begin
  if active then begin
    if designDepth = 0 then pushSysColors(stockColors);
    inc(designDepth);
  end else begin
    dec(designDepth);
    if designDepth = 0 then pushSysColors(palColors);
  end;
end;

// a control with its own color got a gtk rule from the color it resolved back
// then, so it resolves again against the new table
procedure refreshControl(control: TWinControl);
begin
  if control.HandleAllocated then begin
    if control.Color <> clDefault then TWSWinControlClass(control.WidgetSetClass).SetColor(control);
    control.Invalidate;
  end;
  for var i := 0 to control.ControlCount-1 do if control.Controls[i] is TWinControl then refreshControl(TWinControl(control.Controls[i]));
end;

procedure refreshLCL;
begin
  // every brush and pen resolves its color again; the caches key on the
  // resolved color, so the old handles only linger there. Clearing them would
  // free objects that live brushes still point at
  UpdateHandleObjects(false);
  gtk_style_context_reset_widgets(gdk_screen_get_default);
  for var i := 0 to Screen.CustomFormCount-1 do begin
    var form := Screen.CustomForms[i];
    if not (csDesigning in form.ComponentState) then refreshControl(form);
  end;
end;

procedure setPreferDark(dark: boolean);
begin
  g_object_set(PGObject(gtk_settings_get_default), 'gtk-application-prefer-dark-theme', [ord(dark), nil]);
end;

procedure applyPalette(const newPal: TPalette);
begin
  if provider = nil then begin
    Move(SysColorMap, stockColors, SizeOf(stockColors));
    g_object_get(PGObject(gtk_settings_get_default), 'gtk-application-prefer-dark-theme', [@stockDark, nil]);
    provider := gtk_css_provider_new;
  end else
    gtk_style_context_remove_provider_for_screen(gdk_screen_get_default, PGtkStyleProvider(provider));
  var r, g, b: byte;
  RedGreenBlue(newPal[COLOR_BTNFACE], r, g, b);
  // the dark variant of the gtk theme brings the matching icons and shadows
  setPreferDark((r*299+g*587+b*114) div 1000 < 128);
  // the sheet loads while the provider is off the screen, so no widget keeps
  // style values from the old sheet during the reload. The designed forms
  // get the stock colors, like the running program shows them
  var css := namedColors(newPal) + styleSheet(newPal, '') + styleSheet(stockPalette, '.designer ');
  gtk_css_provider_load_from_data(provider, PChar(css), length(css), nil);
  gtk_style_context_add_provider_for_screen(gdk_screen_get_default, PGtkStyleProvider(provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  for var i := 0 to MAX_SYS_COLORS do palColors[i] := newPal[i];
  pushSysColors(palColors);
  // the palette paints flat, like the win32 engine: no 3D rings on tool bars
  Gtk3WidgetSet.FlatEdges := true;
  Gtk3WidgetSet.DesignColorHook := @designColorHook;
  refreshLCL;
end;

procedure dropPalette;
begin
  if provider = nil then exit;
  gtk_style_context_remove_provider_for_screen(gdk_screen_get_default, PGtkStyleProvider(provider));
  g_object_unref(PGObject(provider));
  provider := nil;
  setPreferDark(stockDark);
  Gtk3WidgetSet.DesignColorHook := nil;
  pushSysColors(stockColors);
  Gtk3WidgetSet.FlatEdges := false;
  refreshLCL;
end;
{$endif}

end.
