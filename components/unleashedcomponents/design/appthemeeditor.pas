{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit AppThemeEditor;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Graphics, ComponentEditors,
  ThemesPalette, ThemesSeed, AppTheme, ColorSwatchButton;

type

  { TAppThemeEditorForm }

  // the look of a TAppTheme on a painted mock window, set top down: a preset
  // to start from, the colors the look grows from, then moves of the whole look
  TAppThemeEditorForm = class(TForm)
  private
    FPreset: TThemePreset;
    FSeed: TThemeSeed;
    FHoverStrength: integer; // of every look, not a part of the seed
    FFilling: boolean; // the controls are being set from the seed, not by the user
    FPlaced: integer; // controls aligned to the top so far
    FPresetBox: TComboBox;
    FSwatches: array[5] of TColorSwatchButton; // surface, text, accent, link, mark
    FWindow, FHover: TTrackBar;
    FWindowValue, FHoverValue: TLabel;
    // the whole look: hue turn, saturation and lightness moves
    FTuneHue, FTuneSat, FTuneLight: TTrackBar;
    FTuneHueValue, FTuneSatValue, FTuneLightValue: TLabel;
    FPreview: TPaintBox;
    procedure build;
    function nextBelow: integer;
    function addGroup(parent: TWinControl; const title: string): TGroupBox;
    function addSlider(parent: TWinControl; const title: string; lo, hi: integer; out value: TLabel): TTrackBar;
    function seedColor(index: integer): TColor;
    procedure setSeedColor(index: integer; value: TColor);
    procedure fillControls;
    procedure showValues;
    procedure presetChanged(Sender: TObject);
    procedure swatchChanged(Sender: TObject);
    procedure shiftChanged(Sender: TObject);
    procedure hoverChanged(Sender: TObject);
    procedure tuneChanged(Sender: TObject);
    // the palette of the preset or the seed before the whole-theme moves
    function basePalette: TPalette;
    procedure resetClicked(Sender: TObject);
    procedure previewPaint(Sender: TObject);
    procedure wentCustom;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    // shows the look of the theme; under a fixed preset the colors are the preset's own
    procedure load(theme: TAppTheme);
    // the preview of the current choice
    function palette: TPalette;
    property Preset: TThemePreset read FPreset;
    property Seed: TThemeSeed read FSeed;
    property HoverStrength: integer read FHoverStrength;
    function HueShift: integer;
    function SaturationShift: integer;
    function LightnessShift: integer;
    procedure SetShifts(hue, sat, light: integer);
  end;

  { TAppThemeComponentEditor }

  TAppThemeComponentEditor = class(TComponentEditor)
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

// paints a mock window in the palette: menu, tool bar, tabs, list, edit,
// buttons, check marks, progress, scroll bar, status bar
procedure paintMockup(canvas: TCanvas; const r: TRect; const pal: TPalette);

implementation

uses
  Math, LCLType, LCLIntf, ThemesEngine, ThemesIcons;

resourcestring
  VERB_EDIT = 'Edit Theme...';
  CAPTION_EDITOR = 'Theme Editor';
  GROUP_PRESET = 'Preset';
  GROUP_COLORS = 'Colors';
  GROUP_WHOLE = 'Whole theme';
  LABEL_WINDOW = 'Edits and lists against the background';
  LABEL_HOVER = 'Hover highlight';
  LABEL_TUNE_HUE = 'Hue turn';
  LABEL_TUNE_SAT = 'Saturation';
  LABEL_TUNE_LIGHT = 'Lightness';
  HINT_PRESET = 'The look to start from; changing a color below makes it Custom';
  HINT_WHOLE = 'Moves every color of the theme at once, the preset stays';
  BUTTON_RESET = 'Reset';
  HINT_RESET = 'Back to the preset as it comes, with the whole theme moves at zero';
  BUTTON_OK = 'OK';
  BUTTON_CANCEL = 'Cancel';

const
  PRESET_NAMES: array[TThemePreset] of string = ('None', 'Follow system', 'Light', 'Dark', 'Ocean', 'Frost', 'Paper', 'Ember', 'Midnight', 'Dusk', 'Custom');
  COLOR_NAMES: array[5] of string = ('Background', 'Text', 'Selection', 'Links, active tab', 'Changed items');
  COLOR_HINTS: array[5] of string = (
    'Forms, panels, buttons and tool bars',
    'The text on the background',
    'Selected items in lists, trees and edits',
    'Links and the strip of the active tab',
    'An item that was changed or is not saved yet');
  // the space around the groups and inside them, and between rows of a group
  MARGIN = 8;
  ROW_GAP = 6;
  MENU_ITEMS: array[0..3] of string = ('File', 'Edit', 'View', 'Help');
  TAB_NAMES: array[0..2] of string = ('main.pas', 'utils.pas', 'notes.txt');
  BUTTON_CAPTIONS: array[0..2] of string = ('OK', 'Hot', 'Off');
  LINK_TEXT = 'A link in the text';
  // controls aligned to the top start this far down, each one lower than the one before
  BELOW = 10000;

{ mock window }

procedure fill(canvas: TCanvas; const r: TRect; color: TColor);
begin
  canvas.Brush.Color := color;
  canvas.FillRect(r);
end;

procedure frame(canvas: TCanvas; const r: TRect; color: TColor);
begin
  canvas.Pen.Color := color;
  canvas.Brush.Style := bsClear;
  canvas.Rectangle(r);
  canvas.Brush.Style := bsSolid;
end;

procedure drawText(canvas: TCanvas; x, y: integer; const s: string; color: TColor);
begin
  canvas.Font.Color := color;
  canvas.Brush.Style := bsClear;
  canvas.TextOut(x, y, s);
  canvas.Brush.Style := bsSolid;
end;

procedure paintMockup(canvas: TCanvas; const r: TRect; const pal: TPalette);
begin
  var h := canvas.TextHeight('Xg');
  var row := h+8;
  var face := pal[COLOR_BTNFACE];
  var win := pal[COLOR_WINDOW];
  var txt := pal[COLOR_BTNTEXT];
  fill(canvas, r, face);
  frame(canvas, r, pal[COLOR_WINDOWFRAME]);
  var x := r.Left+1;
  var y := r.Top+1;
  var w := r.Width-2;
  // menu bar with one open item
  fill(canvas, Rect(x, y, x+w, y+row), pal[COLOR_MENUBAR]);
  var mx := x+8;
  for var i := 0 to 3 do begin
    var item := MENU_ITEMS[i];
    var iw := canvas.TextWidth(item)+16;
    if i = 2 then fill(canvas, Rect(mx, y+2, mx+iw, y+row-2), pal[COLOR_MENUHILIGHT]);
    drawText(canvas, mx+8, y+4, item, pal[COLOR_MENUTEXT]);
    mx += iw;
  end;
  y += row;
  canvas.Pen.Color := pal[COLOR_3DLIGHT];
  canvas.Line(x, y, x+w, y);
  // tool bar: squares for icons, one under the mouse
  y += 1;
  var bx := x+6;
  var side := row-4;
  for var i := 0 to 5 do begin
    if i = 3 then begin
      canvas.Pen.Color := pal[COLOR_3DLIGHT];
      canvas.Line(bx+2, y+4, bx+2, y+row-4);
      bx += 8;
      continue;
    end;
    var br := Rect(bx, y+2, bx+side, y+2+side);
    if i = 1 then fill(canvas, br, pal[COLOR_HOVER]);
    var glyph := Rect(br.Left+5, br.Top+5, br.Right-5, br.Bottom-5);
    fill(canvas, glyph, if i = 4 then pal[COLOR_GRAYTEXT] else mix(txt, face, 25));
    bx += side+2;
  end;
  y += row+2;
  // tabs: the active page with the accent strip, an unsaved one with the mark
  var tx := x+6;
  var tabH := row+2;
  for var i := 0 to 2 do begin
    var name := TAB_NAMES[i];
    var tw := canvas.TextWidth(name)+20;
    var tr := Rect(tx, y, tx+tw, y+tabH);
    fill(canvas, tr, if i = 0 then face else win);
    frame(canvas, Rect(tr.Left, tr.Top, tr.Right, tr.Bottom+1), pal[COLOR_3DLIGHT]);
    if i = 0 then fill(canvas, Rect(tr.Left, tr.Top, tr.Right, tr.Top+2), pal[COLOR_HOTLIGHT]);
    if i = 2 then fill(canvas, Rect(tr.Left, tr.Top, tr.Right, tr.Top+2), pal[COLOR_MARK]);
    drawText(canvas, tr.Left+10, tr.Top+5, name, if i = 0 then txt else pal[COLOR_GRAYTEXT]);
    tx += tw+2;
  end;
  y += tabH;
  canvas.Pen.Color := pal[COLOR_3DLIGHT];
  canvas.Line(x, y, x+w, y);
  y += 10;
  var bottom := r.Bottom-1-row;
  // list with a selection and a scroll bar
  var listW := (w-30) div 2;
  var list := Rect(x+10, y, x+10+listW, bottom-10);
  fill(canvas, list, win);
  frame(canvas, list, pal[COLOR_BTNSHADOW]);
  var bar := Rect(list.Right-1-row+4, list.Top+1, list.Right-1, list.Bottom-1);
  fill(canvas, bar, pal[COLOR_SCROLLBAR]);
  fill(canvas, Rect(bar.Left+3, bar.Top+bar.Height div 4, bar.Right-3, bar.Top+bar.Height div 2), pal[COLOR_BTNSHADOW]);
  for var i := 0 to 6 do begin
    var ir := Rect(list.Left+1, list.Top+1+i*row, bar.Left, list.Top+1+(i+1)*row);
    if ir.Bottom > list.Bottom-1 then break;
    var color := pal[COLOR_WINDOWTEXT];
    if i = 2 then begin
      fill(canvas, ir, pal[COLOR_HIGHLIGHT]);
      color := pal[COLOR_HIGHLIGHTTEXT];
    end else if i = 4 then fill(canvas, ir, pal[COLOR_HOVER])
    else if i = 6 then color := pal[COLOR_GRAYTEXT];
    drawText(canvas, ir.Left+6, ir.Top+4, 'Item '+IntToStr(i+1), color);
  end;
  // the right column: edit, buttons, check marks, progress, link, tooltip
  var cx := list.Right+10;
  var cw := r.Right-1-10-cx;
  var cy := y;
  var edit := Rect(cx, cy, cx+cw, cy+row);
  fill(canvas, edit, win);
  frame(canvas, edit, pal[COLOR_BTNSHADOW]);
  drawText(canvas, edit.Left+5, edit.Top+4, 'Edit text', pal[COLOR_WINDOWTEXT]);
  cy += row+8;
  var bw := (cw-8) div 3;
  for var i := 0 to 2 do begin
    var btn := Rect(cx+i*(bw+4), cy, cx+i*(bw+4)+bw, cy+row);
    fill(canvas, btn, if i = 1 then pal[COLOR_HOVER] else pal[COLOR_BTNHIGHLIGHT]);
    frame(canvas, btn, pal[COLOR_BTNSHADOW]);
    var caption := BUTTON_CAPTIONS[i];
    drawText(canvas, btn.Left+(bw-canvas.TextWidth(caption)) div 2, btn.Top+4, caption, if i = 2 then pal[COLOR_GRAYTEXT] else txt);
  end;
  cy += row+8;
  var box := Rect(cx, cy+2, cx+h-2, cy+h);
  fill(canvas, box, win);
  frame(canvas, box, pal[COLOR_BTNHIGHLIGHT]);
  canvas.Pen.Color := pal[COLOR_HOTLIGHT];
  canvas.Pen.Width := 2;
  canvas.Line(box.Left+3, box.Top+box.Height div 2, box.Left+box.Width div 2, box.Bottom-3);
  canvas.Line(box.Left+box.Width div 2, box.Bottom-3, box.Right-2, box.Top+2);
  canvas.Pen.Width := 1;
  drawText(canvas, box.Right+6, cy, 'Checked', txt);
  var dot := Rect(cx+cw div 2, cy+2, cx+cw div 2+h-2, cy+h);
  canvas.Brush.Color := win;
  canvas.Pen.Color := pal[COLOR_BTNHIGHLIGHT];
  canvas.Ellipse(dot);
  canvas.Brush.Color := pal[COLOR_HOTLIGHT];
  canvas.Pen.Color := pal[COLOR_HOTLIGHT];
  canvas.Ellipse(Rect(dot.Left+4, dot.Top+4, dot.Right-4, dot.Bottom-4));
  drawText(canvas, dot.Right+6, cy, 'Radio', txt);
  cy += row+4;
  var track := Rect(cx, cy+4, cx+cw, cy+12);
  fill(canvas, track, pal[COLOR_3DLIGHT]);
  fill(canvas, Rect(track.Left, track.Top, track.Left+track.Width*2 div 3, track.Bottom), pal[COLOR_HIGHLIGHT]);
  cy += row;
  drawText(canvas, cx, cy, LINK_TEXT, pal[COLOR_HOTLIGHT]);
  canvas.Pen.Color := pal[COLOR_HOTLIGHT];
  canvas.Line(cx, cy+h, cx+canvas.TextWidth(LINK_TEXT), cy+h);
  cy += row;
  drawText(canvas, cx, cy, 'Disabled text', pal[COLOR_GRAYTEXT]);
  cy += row;
  var tip := Rect(cx, cy, cx+canvas.TextWidth('Tooltip')+16, cy+row);
  if tip.Bottom < bottom-6 then begin
    fill(canvas, tip, pal[COLOR_INFOBK]);
    frame(canvas, tip, pal[COLOR_WINDOWFRAME]);
    drawText(canvas, tip.Left+8, tip.Top+4, 'Tooltip', pal[COLOR_INFOTEXT]);
  end;
  // status bar
  canvas.Pen.Color := pal[COLOR_3DLIGHT];
  canvas.Line(x, bottom, x+w, bottom);
  drawText(canvas, x+8, bottom+4, 'Ready', txt);
  canvas.Pen.Color := pal[COLOR_3DLIGHT];
  canvas.Line(x+w*2 div 3, bottom+3, x+w*2 div 3, r.Bottom-3);
  drawText(canvas, x+w*2 div 3+8, bottom+4, 'Ln 12, Col 4', txt);
end;

{ TAppThemeEditorForm }

constructor TAppThemeEditorForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  FPreset := tpSystem;
  FHoverStrength := DEFAULT_HOVER;
  FSeed := seedOf(lightPalette);
  build;
end;

// a Top under every control placed so far: alTop controls added before the
// form aligns keep the order they were made in, not the reverse
function TAppThemeEditorForm.nextBelow: integer;
begin
  inc(FPlaced);
  result := BELOW+FPlaced;
end;

function TAppThemeEditorForm.addGroup(parent: TWinControl; const title: string): TGroupBox;
begin
  result := TGroupBox.Create(self);
  result.Parent := parent;
  result.Caption := title;
  result.AutoSize := true;
  result.ChildSizing.LeftRightSpacing := MARGIN;
  result.ChildSizing.TopBottomSpacing := MARGIN;
  // the first group sits at the top of the column, the next ones a margin below
  if parent.ControlCount > 1 then result.BorderSpacing.Top := MARGIN;
  result.Top := nextBelow;
  result.Align := alTop;
end;

// a titled slider: the title on the left, the value on the right, the bar under them
function TAppThemeEditorForm.addSlider(parent: TWinControl; const title: string; lo, hi: integer; out value: TLabel): TTrackBar;
begin
  var box := TPanel.Create(self);
  box.Parent := parent;
  box.BevelOuter := bvNone;
  box.AutoSize := true;
  box.BorderSpacing.Top := ROW_GAP;
  box.Top := nextBelow;
  box.Align := alTop;
  var head := TLabel.Create(self);
  head.Parent := box;
  head.Caption := title;
  head.AnchorSideLeft.Control := box;
  head.AnchorSideTop.Control := box;
  value := TLabel.Create(self);
  value.Parent := box;
  value.Caption := '0';
  value.AnchorSideTop.Control := box;
  value.AnchorSideRight.Control := box;
  value.AnchorSideRight.Side := asrBottom;
  value.Anchors := [akTop, akRight];
  result := TTrackBar.Create(self);
  result.Parent := box;
  result.Min := lo;
  result.Max := hi;
  result.Frequency := Math.Max(1, (hi-lo) div 10);
  result.ShowSelRange := false;
  result.TickStyle := tsNone;
  result.Height := 21;
  result.AnchorSideLeft.Control := box;
  result.AnchorSideTop.Control := head;
  result.AnchorSideTop.Side := asrBottom;
  result.AnchorSideRight.Control := box;
  result.AnchorSideRight.Side := asrBottom;
  result.BorderSpacing.Top := 2;
  result.Anchors := [akLeft, akTop, akRight];
end;

procedure TAppThemeEditorForm.build;
begin
  Caption := CAPTION_EDITOR;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  Width := 840;
  Height := 660;
  Constraints.MinWidth := 680;
  Constraints.MinHeight := 640;
  ChildSizing.LeftRightSpacing := MARGIN;
  ChildSizing.TopBottomSpacing := MARGIN;
  ShowHint := true;

  // OK and Cancel on a bar under both columns, at the right
  var buttons := TPanel.Create(self);
  buttons.Parent := self;
  buttons.BevelOuter := bvNone;
  buttons.AutoSize := true;
  buttons.BorderSpacing.Top := MARGIN;
  buttons.Align := alBottom;
  var cancel := TButton.Create(self);
  cancel.Parent := buttons;
  cancel.Caption := BUTTON_CANCEL;
  cancel.ModalResult := mrCancel;
  cancel.Cancel := true;
  cancel.Width := 88;
  cancel.AnchorSideTop.Control := buttons;
  cancel.AnchorSideRight.Control := buttons;
  cancel.AnchorSideRight.Side := asrBottom;
  cancel.Anchors := [akTop, akRight];
  var ok := TButton.Create(self);
  ok.Parent := buttons;
  ok.Caption := BUTTON_OK;
  ok.ModalResult := mrOK;
  ok.Default := true;
  ok.Width := 88;
  ok.AnchorSideTop.Control := buttons;
  ok.AnchorSideRight.Control := cancel;
  ok.BorderSpacing.Right := ROW_GAP;
  ok.Anchors := [akTop, akRight];

  var left := TPanel.Create(self);
  left.Parent := self;
  left.Align := alLeft;
  left.Width := 320;
  left.BevelOuter := bvNone;
  left.BorderSpacing.Right := MARGIN;

  FPreview := TPaintBox.Create(self);
  FPreview.Parent := self;
  FPreview.Align := alClient;
  FPreview.OnPaint := @previewPaint;

  // 1. the preset: it sets every color, so it comes first
  var presetGroup := addGroup(left, GROUP_PRESET);
  presetGroup.Hint := HINT_PRESET;
  var reset := TButton.Create(self);
  reset.Parent := presetGroup;
  reset.Caption := BUTTON_RESET;
  reset.Hint := HINT_RESET;
  reset.AutoSize := true;
  reset.Constraints.MinWidth := 88;
  reset.OnClick := @resetClicked;
  FPresetBox := TComboBox.Create(self);
  FPresetBox.Parent := presetGroup;
  FPresetBox.Style := csDropDownList;
  FPresetBox.DropDownCount := ord(high(TThemePreset))+1;
  for var p := low(TThemePreset) to high(TThemePreset) do FPresetBox.Items.Add(PRESET_NAMES[p]);
  FPresetBox.OnChange := @presetChanged;
  FPresetBox.AnchorSideLeft.Control := presetGroup;
  FPresetBox.AnchorSideTop.Control := presetGroup;
  FPresetBox.AnchorSideRight.Control := reset;
  FPresetBox.BorderSpacing.Right := ROW_GAP;
  FPresetBox.Anchors := [akLeft, akTop, akRight];
  reset.AnchorSideRight.Control := presetGroup;
  reset.AnchorSideRight.Side := asrBottom;
  reset.AnchorVerticalCenterTo(FPresetBox);
  reset.Anchors := [akTop, akRight];

  // 2. the colors the look grows from, each with its own drop-down picker
  var colorGroup := addGroup(left, GROUP_COLORS);
  for var i := 0 to high(FSwatches) do begin
    var row := TPanel.Create(self);
    row.Parent := colorGroup;
    row.BevelOuter := bvNone;
    row.AutoSize := true;
    row.BorderSpacing.Top := ROW_GAP;
    row.Top := nextBelow;
    row.Align := alTop;
    var swatch := TColorSwatchButton.Create(self);
    swatch.Parent := row;
    swatch.Tag := i;
    swatch.ShowSwatches := false; // the picker brings swatches of its own
    swatch.Hint := COLOR_HINTS[i];
    swatch.Width := 150;
    swatch.AnchorSideTop.Control := row;
    swatch.AnchorSideRight.Control := row;
    swatch.AnchorSideRight.Side := asrBottom;
    swatch.Anchors := [akTop, akRight];
    swatch.OnChange := @swatchChanged;
    FSwatches[i] := swatch;
    var nameLabel := TLabel.Create(self);
    nameLabel.Parent := row;
    nameLabel.Caption := COLOR_NAMES[i];
    nameLabel.Hint := COLOR_HINTS[i];
    nameLabel.FocusControl := swatch;
    nameLabel.AnchorSideLeft.Control := row;
    nameLabel.AnchorVerticalCenterTo(swatch);
  end;
  FWindow := addSlider(colorGroup, LABEL_WINDOW, -30, 30, FWindowValue);
  FWindow.OnChange := @shiftChanged;

  // 3. moves of the whole look on top of the preset and the colors
  var wholeGroup := addGroup(left, GROUP_WHOLE);
  wholeGroup.Hint := HINT_WHOLE;
  FTuneHue := addSlider(wholeGroup, LABEL_TUNE_HUE, -180, 180, FTuneHueValue);
  FTuneSat := addSlider(wholeGroup, LABEL_TUNE_SAT, -100, 100, FTuneSatValue);
  FTuneLight := addSlider(wholeGroup, LABEL_TUNE_LIGHT, -50, 50, FTuneLightValue);
  FHover := addSlider(wholeGroup, LABEL_HOVER, 0, 100, FHoverValue);
  FTuneHue.OnChange := @tuneChanged;
  FTuneSat.OnChange := @tuneChanged;
  FTuneLight.OnChange := @tuneChanged;
  FHover.OnChange := @hoverChanged;
end;

procedure TAppThemeEditorForm.load(theme: TAppTheme);
begin
  FPreset := theme.Preset;
  FSeed := if FPreset = tpCustom then theme.Custom.Seed else seedOf(basePalette);
  FHoverStrength := theme.Effects.HoverStrength;
  SetShifts(theme.Shift.Hue, theme.Shift.Saturation, theme.Shift.Lightness);
  fillControls;
end;

function TAppThemeEditorForm.palette: TPalette;
begin
  result := adjustPalette(basePalette, FTuneHue.Position, FTuneSat.Position, FTuneLight.Position);
  result[COLOR_HOVER] := mix(result[COLOR_BTNFACE], result[COLOR_BTNTEXT], FHoverStrength);
end;

function TAppThemeEditorForm.HueShift: integer;
begin
  result := FTuneHue.Position;
end;

function TAppThemeEditorForm.SaturationShift: integer;
begin
  result := FTuneSat.Position;
end;

function TAppThemeEditorForm.LightnessShift: integer;
begin
  result := FTuneLight.Position;
end;

procedure TAppThemeEditorForm.SetShifts(hue, sat, light: integer);
begin
  FFilling := true;
  FTuneHue.Position := hue;
  FTuneSat.Position := sat;
  FTuneLight.Position := light;
  FFilling := false;
  tuneChanged(nil);
end;

function signed(value: integer): string;
begin
  result := if value > 0 then '+'+IntToStr(value) else IntToStr(value);
end;

procedure TAppThemeEditorForm.showValues;
begin
  FWindowValue.Caption := signed(FWindow.Position);
  FTuneHueValue.Caption := signed(FTuneHue.Position);
  FTuneSatValue.Caption := signed(FTuneSat.Position);
  FTuneLightValue.Caption := signed(FTuneLight.Position);
  FHoverValue.Caption := IntToStr(FHover.Position)+'%';
end;

procedure TAppThemeEditorForm.tuneChanged(Sender: TObject);
begin
  showValues;
  if not FFilling then FPreview.Invalidate;
end;

function TAppThemeEditorForm.basePalette: TPalette;
begin
  match FPreset of
    tpNone: begin
      for var i := 0 to COLOR_ENDCOLORS do result[i] := GetSysColor(i);
      result[COLOR_MARK] := result[COLOR_HIGHLIGHT];
      result[COLOR_HOVER] := result[COLOR_3DLIGHT];
    end;
    tpSystem: result := if systemDark then darkPalette else lightPalette;
    tpCustom: result := buildPalette(FSeed);
    _: result := presetPalette(FPreset);
  end;
end;

function TAppThemeEditorForm.seedColor(index: integer): TColor;
begin
  match index of
    0: result := FSeed.Surface;
    1: result := FSeed.Text;
    2: result := FSeed.Accent;
    3: result := FSeed.Link;
    _: result := FSeed.Mark;
  end;
end;

procedure TAppThemeEditorForm.setSeedColor(index: integer; value: TColor);
begin
  match index of
    0: FSeed.Surface := value;
    1: FSeed.Text := value;
    2: FSeed.Accent := value;
    3: FSeed.Link := value;
    _: FSeed.Mark := value;
  end;
end;

procedure TAppThemeEditorForm.fillControls;
begin
  FFilling := true;
  try
    FPresetBox.ItemIndex := ord(FPreset);
    for var i := 0 to high(FSwatches) do FSwatches[i].Color := ColorToRGB(seedColor(i));
    FWindow.Position := FSeed.FieldLightness;
    FHover.Position := FHoverStrength;
    showValues;
  finally
    FFilling := false;
  end;
  FPreview.Invalidate;
end;

// a changed color makes the look custom, grown from the colors on screen
procedure TAppThemeEditorForm.wentCustom;
begin
  if FPreset <> tpCustom then begin
    FPreset := tpCustom;
    FFilling := true;
    FPresetBox.ItemIndex := ord(tpCustom);
    FFilling := false;
  end;
  FPreview.Invalidate;
end;

procedure TAppThemeEditorForm.presetChanged(Sender: TObject);
begin
  if FFilling then exit;
  FPreset := TThemePreset(FPresetBox.ItemIndex);
  if FPreset <> tpCustom then FSeed := seedOf(basePalette);
  fillControls;
end;

procedure TAppThemeEditorForm.swatchChanged(Sender: TObject);
begin
  if FFilling then exit;
  var swatch := Sender as TColorSwatchButton;
  setSeedColor(swatch.Tag, swatch.Color);
  wentCustom;
end;

procedure TAppThemeEditorForm.shiftChanged(Sender: TObject);
begin
  if FFilling then exit;
  FSeed.FieldLightness := FWindow.Position;
  showValues;
  wentCustom;
end;

// the hover strength works on every preset, so the preset stays
procedure TAppThemeEditorForm.hoverChanged(Sender: TObject);
begin
  if FFilling then exit;
  FHoverStrength := FHover.Position;
  showValues;
  FPreview.Invalidate;
end;

procedure TAppThemeEditorForm.resetClicked(Sender: TObject);
begin
  var preset := TThemePreset(FPresetBox.ItemIndex);
  if preset = tpCustom then preset := tpSystem;
  FPreset := preset;
  FSeed := seedOf(basePalette);
  SetShifts(0, 0, 0);
  fillControls;
end;

procedure TAppThemeEditorForm.previewPaint(Sender: TObject);
begin
  var r := FPreview.ClientRect;
  // a frame of the form color keeps the mock window apart from the dialog
  FPreview.Canvas.Brush.Color := clBtnFace;
  FPreview.Canvas.FillRect(r);
  InflateRect(r, -1, -1);
  // the shades as the engine puts them on screen
  paintMockup(FPreview.Canvas, r, legiblePalette(palette));
end;

{ TAppThemeComponentEditor }

function TAppThemeComponentEditor.GetVerbCount: Integer;
begin
  result := 1;
end;

function TAppThemeComponentEditor.GetVerb(Index: Integer): string;
begin
  result := VERB_EDIT;
end;

procedure TAppThemeComponentEditor.ExecuteVerb(Index: Integer);
begin
  var theme := Component as TAppTheme;
  var dlg := autofree TAppThemeEditorForm.CreateNew(nil);
  dlg.load(theme);
  if dlg.ShowModal <> mrOK then exit;
  if dlg.Preset = tpCustom then begin
    theme.Custom.Seed := dlg.Seed;
    theme.Preset := tpCustom;
  end else theme.Preset := dlg.Preset;
  theme.Shift.Hue := dlg.HueShift;
  theme.Shift.Saturation := dlg.SaturationShift;
  theme.Shift.Lightness := dlg.LightnessShift;
  theme.Effects.HoverStrength := dlg.HoverStrength;
  Modified;
end;

end.
