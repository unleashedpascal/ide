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
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Dialogs, Graphics, ComponentEditors,
  ThemesPalette, ThemesSeed, AppTheme;

type

  { TAppThemeEditorForm }

  // the look of a TAppTheme on a painted mock window: a preset to start from,
  // then hue, saturation and lightness of each seed color
  TAppThemeEditorForm = class(TForm)
  private
    FPreset: TThemePreset;
    FSeed: TThemeSeed;
    FColor: integer; // seed color under the sliders: 0 surface .. 4 mark
    FFilling: boolean; // the controls are being set from the seed, not by the user
    FPresetBox: TComboBox;
    FColors: TRadioGroup;
    FPick: TColorButton;
    FHex: TEdit;
    FHue, FSat, FLight, FWindow, FHover: TTrackBar;
    FHueValue, FSatValue, FLightValue, FWindowValue, FHoverValue: TLabel;
    // the whole look: hue turn, saturation and lightness moves
    FTuneHue, FTuneSat, FTuneLight: TTrackBar;
    FTuneHueValue, FTuneSatValue, FTuneLightValue: TLabel;
    FPreview: TPaintBox;
    procedure build;
    function addSlider(parent: TWinControl; const title: string; lo, hi: integer; out value: TLabel): TTrackBar;
    function seedColor: TColor;
    procedure setSeedColor(value: TColor);
    procedure fillControls;
    procedure presetChanged(Sender: TObject);
    procedure colorChanged(Sender: TObject);
    procedure sliderChanged(Sender: TObject);
    procedure shiftChanged(Sender: TObject);
    procedure tuneChanged(Sender: TObject);
    // the palette of the preset or the seed before the whole-theme moves
    function basePalette: TPalette;
    procedure pickChanged(Sender: TObject);
    procedure hexChanged(Sender: TObject);
    procedure resetClicked(Sender: TObject);
    procedure previewPaint(Sender: TObject);
    procedure wentCustom;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    // the preview of the current choice
    function palette: TPalette;
    property Preset: TThemePreset read FPreset write FPreset;
    property Seed: TThemeSeed read FSeed write FSeed;
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
  Math, LCLType, LCLIntf, Themes, ThemesIcons;

resourcestring
  VERB_EDIT = 'Edit Theme...';
  CAPTION_EDITOR = 'Theme Editor';
  LABEL_PRESET = 'Preset';
  LABEL_COLOR = 'Seed color';
  LABEL_HUE = 'Hue';
  LABEL_SATURATION = 'Saturation';
  LABEL_LIGHTNESS = 'Lightness';
  LABEL_WINDOW = 'Field lightness (edits, lists) against the surface';
  LABEL_HOVER = 'Hover strength';
  LABEL_TUNE_HUE = 'Whole theme: hue turn';
  LABEL_TUNE_SAT = 'Whole theme: saturation';
  LABEL_TUNE_LIGHT = 'Whole theme: lightness';
  BUTTON_RESET = 'Reset to preset';
  BUTTON_OK = 'OK';
  BUTTON_CANCEL = 'Cancel';

const
  PRESET_NAMES: array[TThemePreset] of string = ('None', 'Follow system', 'Light', 'Dark', 'Ocean', 'Frost', 'Paper', 'Ember', 'Midnight', 'Dusk', 'Custom');
  COLOR_NAMES: array[0..4] of string = ('Surface', 'Text', 'Accent', 'Link', 'Mark');
  MENU_ITEMS: array[0..3] of string = ('File', 'Edit', 'View', 'Help');
  TAB_NAMES: array[0..2] of string = ('main.pas', 'utils.pas', 'notes.txt');
  BUTTON_CAPTIONS: array[0..2] of string = ('OK', 'Hot', 'Off');
  LINK_TEXT = 'A link in the text';
  // a control appended below the ones aligned to the top so far
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
  FSeed := seedOf(lightPalette);
  build;
end;

function TAppThemeEditorForm.addSlider(parent: TWinControl; const title: string; lo, hi: integer; out value: TLabel): TTrackBar;
begin
  var box := TPanel.Create(self);
  box.Parent := parent;
  box.BevelOuter := bvNone;
  box.Height := 50;
  box.Top := BELOW;
  box.Align := alTop;
  var head := TLabel.Create(self);
  head.Parent := box;
  head.Caption := title;
  head.Left := 4;
  head.Top := 2;
  value := TLabel.Create(self);
  value.Parent := box;
  value.Caption := '0';
  value.AutoSize := false;
  value.Alignment := taRightJustify;
  value.SetBounds(box.Width-64, 2, 60, head.Height);
  value.Anchors := [akTop, akRight];
  result := TTrackBar.Create(self);
  result.Parent := box;
  result.Min := lo;
  result.Max := hi;
  result.Frequency := Math.Max(1, (hi-lo) div 10);
  result.ShowSelRange := false;
  result.TickStyle := tsNone;
  result.SetBounds(0, 20, box.Width, 28);
  result.Anchors := [akLeft, akTop, akRight];
end;

procedure TAppThemeEditorForm.build;
begin
  Caption := CAPTION_EDITOR;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  Width := 820;
  Height := 720;
  Constraints.MinWidth := 640;
  Constraints.MinHeight := 640;

  var left := TPanel.Create(self);
  left.Parent := self;
  left.Align := alLeft;
  left.Width := 300;
  left.BevelOuter := bvNone;
  left.BorderSpacing.Around := 8;

  var buttons := TPanel.Create(self);
  buttons.Parent := left;
  buttons.Align := alBottom;
  buttons.Height := 34;
  buttons.BevelOuter := bvNone;
  var ok := TButton.Create(self);
  ok.Parent := buttons;
  ok.Caption := BUTTON_OK;
  ok.ModalResult := mrOK;
  ok.Default := true;
  ok.Width := 80;
  ok.Align := alRight;
  ok.BorderSpacing.Left := 6;
  var cancel := TButton.Create(self);
  cancel.Parent := buttons;
  cancel.Caption := BUTTON_CANCEL;
  cancel.ModalResult := mrCancel;
  cancel.Cancel := true;
  cancel.Width := 80;
  cancel.Left := BELOW; // right of the OK button
  cancel.Align := alRight;
  var reset := TButton.Create(self);
  reset.Parent := buttons;
  reset.Caption := BUTTON_RESET;
  reset.AutoSize := true;
  reset.Align := alLeft;
  reset.OnClick := @resetClicked;

  var presetLabel := TLabel.Create(self);
  presetLabel.Parent := left;
  presetLabel.Caption := LABEL_PRESET;
  presetLabel.BorderSpacing.Left := 4;
  presetLabel.Top := BELOW;
  presetLabel.Align := alTop;
  FPresetBox := TComboBox.Create(self);
  FPresetBox.Parent := left;
  FPresetBox.Style := csDropDownList;
  FPresetBox.BorderSpacing.Top := 2;
  for var p := low(TThemePreset) to high(TThemePreset) do FPresetBox.Items.Add(PRESET_NAMES[p]);
  FPresetBox.OnChange := @presetChanged;
  FPresetBox.Top := BELOW;
  FPresetBox.Align := alTop;

  FTuneHue := addSlider(left, LABEL_TUNE_HUE, -180, 180, FTuneHueValue);
  FTuneSat := addSlider(left, LABEL_TUNE_SAT, -100, 100, FTuneSatValue);
  FTuneLight := addSlider(left, LABEL_TUNE_LIGHT, -50, 50, FTuneLightValue);
  FTuneHue.OnChange := @tuneChanged;
  FTuneSat.OnChange := @tuneChanged;
  FTuneLight.OnChange := @tuneChanged;

  FColors := TRadioGroup.Create(self);
  FColors.Parent := left;
  FColors.Caption := LABEL_COLOR;
  FColors.Columns := 3;
  FColors.AutoSize := true;
  FColors.BorderSpacing.Top := 8;
  for var i := low(COLOR_NAMES) to high(COLOR_NAMES) do FColors.Items.Add(COLOR_NAMES[i]);
  FColors.OnClick := @colorChanged;
  FColors.Top := BELOW;
  FColors.Align := alTop;

  var pickRow := TPanel.Create(self);
  pickRow.Parent := left;
  pickRow.Height := 30;
  pickRow.BevelOuter := bvNone;
  pickRow.BorderSpacing.Top := 4;
  pickRow.Top := BELOW;
  pickRow.Align := alTop;
  FPick := TColorButton.Create(self);
  FPick.Parent := pickRow;
  FPick.Width := 60;
  FPick.Align := alLeft;
  FPick.OnColorChanged := @pickChanged;
  FHex := TEdit.Create(self);
  FHex.Parent := pickRow;
  FHex.Width := 90;
  FHex.BorderSpacing.Left := 6;
  FHex.Left := BELOW;
  FHex.Align := alLeft;
  FHex.OnEditingDone := @hexChanged;

  FHue := addSlider(left, LABEL_HUE, 0, 359, FHueValue);
  FSat := addSlider(left, LABEL_SATURATION, 0, 100, FSatValue);
  FLight := addSlider(left, LABEL_LIGHTNESS, 0, 100, FLightValue);
  FWindow := addSlider(left, LABEL_WINDOW, -30, 30, FWindowValue);
  FHover := addSlider(left, LABEL_HOVER, 0, 40, FHoverValue);
  FHue.OnChange := @sliderChanged;
  FSat.OnChange := @sliderChanged;
  FLight.OnChange := @sliderChanged;
  FWindow.OnChange := @shiftChanged;
  FHover.OnChange := @shiftChanged;

  FPreview := TPaintBox.Create(self);
  FPreview.Parent := self;
  FPreview.Align := alClient;
  FPreview.BorderSpacing.Around := 8;
  FPreview.OnPaint := @previewPaint;
end;

function TAppThemeEditorForm.palette: TPalette;
begin
  result := adjustPalette(basePalette, FTuneHue.Position, FTuneSat.Position, FTuneLight.Position);
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

procedure TAppThemeEditorForm.tuneChanged(Sender: TObject);
begin
  FTuneHueValue.Caption := IntToStr(FTuneHue.Position);
  FTuneSatValue.Caption := IntToStr(FTuneSat.Position);
  FTuneLightValue.Caption := IntToStr(FTuneLight.Position);
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
    tpSystem: result := if ThemeServices.IsDarkTheme then darkPalette else lightPalette;
    tpCustom: result := buildPalette(FSeed);
    _: result := presetPalette(FPreset);
  end;
end;

function TAppThemeEditorForm.seedColor: TColor;
begin
  match FColor of
    0: result := FSeed.Surface;
    1: result := FSeed.Text;
    2: result := FSeed.Accent;
    3: result := FSeed.Link;
    _: result := FSeed.Mark;
  end;
end;

procedure TAppThemeEditorForm.setSeedColor(value: TColor);
begin
  match FColor of
    0: FSeed.Surface := value;
    1: FSeed.Text := value;
    2: FSeed.Accent := value;
    3: FSeed.Link := value;
    _: FSeed.Mark := value;
  end;
end;

// the controls show the preset and the seed; a fixed preset leaves the
// sliders on the seed it grew from
procedure TAppThemeEditorForm.fillControls;
begin
  FFilling := true;
  try
    FPresetBox.ItemIndex := ord(FPreset);
    if FColors.ItemIndex < 0 then FColors.ItemIndex := 0;
    FColor := FColors.ItemIndex;
    var color := ColorToRGB(seedColor);
    var r, g, b: byte;
    RedGreenBlue(color, r, g, b);
    var h, s, l: single;
    rgbToHsl(r, g, b, h, s, l);
    FHue.Position := round(h*60) mod 360;
    FSat.Position := round(s*100);
    FLight.Position := round(l*100);
    FWindow.Position := FSeed.FieldLightness;
    FHover.Position := FSeed.HoverStrength;
    FHueValue.Caption := IntToStr(FHue.Position);
    FSatValue.Caption := IntToStr(FSat.Position)+'%';
    FLightValue.Caption := IntToStr(FLight.Position)+'%';
    FWindowValue.Caption := IntToStr(FWindow.Position);
    FHoverValue.Caption := IntToStr(FHover.Position)+'%';
    FPick.ButtonColor := color;
    FHex.Text := '#'+IntToHex(r, 2)+IntToHex(g, 2)+IntToHex(b, 2);
  finally
    FFilling := false;
  end;
  FPreview.Invalidate;
end;

// a touched slider makes the look custom
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

procedure TAppThemeEditorForm.colorChanged(Sender: TObject);
begin
  if FFilling then exit;
  fillControls;
end;

procedure TAppThemeEditorForm.sliderChanged(Sender: TObject);
begin
  if FFilling then exit;
  var r, g, b: byte;
  hslToRgb(FHue.Position/60, FSat.Position/100, FLight.Position/100, r, g, b);
  setSeedColor(RGBToColor(r, g, b));
  wentCustom;
  // the labels and the swatch follow; the sliders keep their positions
  var hue := FHue.Position;
  var sat := FSat.Position;
  var light := FLight.Position;
  fillControls;
  FFilling := true;
  FHue.Position := hue;
  FSat.Position := sat;
  FLight.Position := light;
  FHueValue.Caption := IntToStr(hue);
  FSatValue.Caption := IntToStr(sat)+'%';
  FLightValue.Caption := IntToStr(light)+'%';
  FFilling := false;
end;

procedure TAppThemeEditorForm.shiftChanged(Sender: TObject);
begin
  if FFilling then exit;
  FSeed.FieldLightness := FWindow.Position;
  FSeed.HoverStrength := FHover.Position;
  FWindowValue.Caption := IntToStr(FWindow.Position);
  FHoverValue.Caption := IntToStr(FHover.Position)+'%';
  wentCustom;
end;

procedure TAppThemeEditorForm.pickChanged(Sender: TObject);
begin
  if FFilling then exit;
  setSeedColor(FPick.ButtonColor);
  wentCustom;
  fillControls;
end;

procedure TAppThemeEditorForm.hexChanged(Sender: TObject);
begin
  if FFilling then exit;
  var s := Trim(FHex.Text);
  if (s <> '') and (s[1] = '#') then Delete(s, 1, 1);
  var value: longint;
  if (length(s) <> 6) or not TryStrToInt('$'+s, value) then begin
    fillControls;
    exit;
  end;
  setSeedColor(RGBToColor((value shr 16) and $FF, (value shr 8) and $FF, value and $FF));
  wentCustom;
  fillControls;
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
  paintMockup(FPreview.Canvas, r, palette);
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
  dlg.Preset := theme.Preset;
  dlg.Seed := theme.Custom.Seed;
  dlg.SetShifts(theme.Shift.Hue, theme.Shift.Saturation, theme.Shift.Lightness);
  dlg.fillControls;
  if dlg.ShowModal <> mrOK then exit;
  if dlg.Preset = tpCustom then begin
    theme.Custom.Seed := dlg.Seed;
    theme.Preset := tpCustom;
  end else theme.Preset := dlg.Preset;
  theme.Shift.Hue := dlg.HueShift;
  theme.Shift.Saturation := dlg.SaturationShift;
  theme.Shift.Lightness := dlg.LightnessShift;
  Modified;
end;

end.
