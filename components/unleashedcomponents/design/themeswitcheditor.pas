{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ThemeSwitchEditor;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, StdCtrls, ExtCtrls, Graphics, LCLType, PropEdits, ComponentEditors,
  AppTheme, ThemeSwitch;

type

  { TThemeChoiceForm }

  // the themes a TThemeSwitch offers: a row per preset of the TAppTheme with
  // a check box to show it, the icon picked from a list that draws the
  // icons, its caption and its place in the order; a live switch below
  TThemeChoiceForm = class(TForm)
  private
    type
      TChoiceRow = record
        Preset: TThemePreset;
        Shown: boolean;
        Glyph: TThemeGlyph;
        Caption: string;
        // an item of the switch the row came from keeps its other settings
        Existing: boolean;
        ImageIndex: integer;
        IconColor: TColor;
        Hint: string;
      end;
  private
    FSwitch: TThemeSwitch;
    FRows: array of TChoiceRow;
    FChecks: array of TCheckBox;
    FIcons: array of TComboBox;
    FCaptions: array of TEdit;
    FUps, FDowns: array of TButton;
    FPreview: TThemeSwitch;
    FNote: TLabel;
    FFilling: boolean;
    procedure build;
    procedure stack(page: TWinControl; var prev: TControl; c: TControl; space: integer);
    procedure loadRows;
    procedure fillRow(k: integer);
    procedure readRow(k: integer);
    procedure swapRows(a, b: integer);
    procedure rowChanged(Sender: TObject);
    procedure upClicked(Sender: TObject);
    procedure downClicked(Sender: TObject);
    procedure resetClicked(Sender: TObject);
    procedure iconDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure updatePreview;
    procedure writeItems(items: TThemeSwitchItems);
  public
    constructor CreateFor(switch: TThemeSwitch);
    // the rows into the themes of the switch
    procedure Apply;
  end;

  { TThemeSwitchComponentEditor }

  // a double click on the switch opens the choice of its themes
  TThemeSwitchComponentEditor = class(TComponentEditor)
  public
    procedure Edit; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

  { TThemeSwitchThemesEditor }

  // Themes in the inspector: the shown themes by name, the button opens the choice
  TThemeSwitchThemesEditor = class(TClassPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: string; override;
    procedure Edit; override;
  end;

  { TThemeGlyphPropertyEditor }

  // Glyph of an item: the list draws every icon beside its name
  TThemeGlyphPropertyEditor = class(TEnumPropertyEditor)
  private
    function presetOf: TThemePreset;
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure ListMeasureHeight(const AValue: ansistring; Index: Integer; ACanvas: TCanvas; var AHeight: Integer); override;
    procedure ListDrawValue(const AValue: ansistring; Index: Integer; ACanvas: TCanvas; const ARect: TRect; AState: TPropEditDrawState); override;
    procedure PropDrawValue(ACanvas: TCanvas; const ARect: TRect; AState: TPropEditDrawState); override;
  end;

// shows the choice for a switch; true when the themes changed
function editThemes(switch: TThemeSwitch): boolean;

// an icon and its name in one line of a list
procedure drawGlyphLine(canvas: TCanvas; const r: TRect; glyph: TThemeGlyph; const text: string; textColor, background: TColor);

implementation

uses
  Math, TypInfo, ControlPaint;

resourcestring
  CAPTION_CHOICE = 'Themes of %s';
  LABEL_INTRO = 'Check the themes the switch offers and pick an icon for each. The order of the rows is the order in the switch.';
  LABEL_ATTACHED = 'The themes are the presets of %s.';
  LABEL_UNATTACHED = 'No TAppTheme on this form: the switch drives the TAppTheme of the application.';
  LABEL_SWITCH_NOTE = 'Style twSwitch shows the first two checked themes: the first one on the left, the second one on the right.';
  HEADER_THEME = 'Theme';
  HEADER_ICON = 'Icon';
  HEADER_CAPTION = 'Caption';
  HEADER_ORDER = 'Order';
  HEADER_PREVIEW = 'Preview';
  BUTTON_UP = 'Up';
  BUTTON_DOWN = 'Down';
  BUTTON_RESET = 'Light and Dark';
  BUTTON_OK = 'OK';
  BUTTON_CANCEL = 'Cancel';
  VERB_CHOOSE = 'Choose Themes...';
  AUTO_GLYPH = 'Auto (%s)';

const
  // a control appended right of the ones aligned so far
  AFTER = 10000;

procedure drawGlyphLine(canvas: TCanvas; const r: TRect; glyph: TThemeGlyph; const text: string; textColor, background: TColor);
begin
  var side := Math.Max(r.Height-6, 8);
  var box := Rect(r.Left+3, r.Top+(r.Height-side) div 2, r.Left+3+side, r.Top+(r.Height-side) div 2+side);
  if glyph <> tgNone then begin
    var sp := autofree beginShapes(canvas, box, ColorToRGB(background), asOn);
    paintThemeGlyph(sp, box, glyph, ColorToRGB(textColor), ColorToRGB(background));
    sp.Flush;
  end;
  var style := canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  canvas.Brush.Style := bsClear;
  canvas.Font.Color := textColor;
  canvas.TextRect(Rect(box.Right+6, r.Top, r.Right, r.Bottom), box.Right+6, r.Top, text, style);
  canvas.Brush.Style := bsSolid;
end;

function editThemes(switch: TThemeSwitch): boolean;
begin
  var dlg := autofree TThemeChoiceForm.CreateFor(switch);
  result := dlg.ShowModal = mrOK;
  if result then dlg.Apply;
end;

{ TThemeChoiceForm }

constructor TThemeChoiceForm.CreateFor(switch: TThemeSwitch);
begin
  inherited CreateNew(nil);
  FSwitch := switch;
  loadRows;
  build;
  FFilling := true;
  try
    for var k := 0 to high(FRows) do fillRow(k);
  finally
    FFilling := false;
  end;
  updatePreview;
end;

procedure TThemeChoiceForm.loadRows;
begin
  FRows := [];
  // the items of the switch first, in their order, then the other presets
  var seen: set of TThemePreset := [];
  for var i := 0 to FSwitch.Themes.Count-1 do begin
    var item := FSwitch.Themes[i];
    var row: TChoiceRow;
    row.Preset := item.Preset;
    row.Shown := item.Visible;
    row.Glyph := item.Glyph;
    row.Caption := item.Caption;
    row.Existing := true;
    row.ImageIndex := item.ImageIndex;
    row.IconColor := item.IconColor;
    row.Hint := item.Hint;
    FRows += [row];
    seen += [item.Preset];
  end;
  for var p := low(TThemePreset) to high(TThemePreset) do begin
    if p in seen then continue;
    var row: TChoiceRow;
    row.Preset := p;
    row.Shown := false;
    row.Glyph := tgAuto;
    row.Caption := '';
    row.Existing := false;
    row.ImageIndex := -1;
    row.IconColor := clDefault;
    row.Hint := '';
    FRows += [row];
  end;
end;

procedure TThemeChoiceForm.build;
begin
  var theme := FSwitch.Theme;
  Caption := Format(CAPTION_CHOICE, [FSwitch.Name]);
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  AutoSize := true;
  // the columns at 96 dpi
  var checkW := Scale96ToScreen(140);
  var iconW := Scale96ToScreen(170);
  var captionW := Scale96ToScreen(190);
  var orderW := Scale96ToScreen(56);
  var gap := Scale96ToScreen(8);
  var margin := Scale96ToScreen(12);
  var rowH := Scale96ToScreen(30);
  var totalW := checkW+iconW+captionW+orderW*2+gap*4;

  var prev: TControl := nil;
  var page := TPanel.Create(self);
  page.Parent := self;
  page.BevelOuter := bvNone;
  page.AutoSize := true;
  page.BorderSpacing.Around := margin;

  var intro := TLabel.Create(self);
  intro.Parent := page;
  intro.Caption := LABEL_INTRO+LineEnding+(if theme <> nil then Format(LABEL_ATTACHED, [theme.Name]) else LABEL_UNATTACHED);
  intro.WordWrap := true;
  intro.AutoSize := true;
  intro.Constraints.MinWidth := totalW;
  intro.Constraints.MaxWidth := totalW;
  stack(page, prev, intro, 0);

  // the header over the columns
  var header := TPanel.Create(self);
  header.Parent := page;
  header.BevelOuter := bvNone;
  header.SetBounds(0, 0, totalW, Scale96ToScreen(20));
  stack(page, prev, header, gap);
  var titles: array of string := [HEADER_THEME, HEADER_ICON, HEADER_CAPTION, HEADER_ORDER];
  var widths: array of integer := [checkW, iconW, captionW, orderW*2+gap];
  // each title over its column
  var x := 0;
  for var i := 0 to high(titles) do begin
    var title := TLabel.Create(self);
    title.Parent := header;
    title.Caption := titles[i];
    title.Font.Style := [fsBold];
    title.Left := x;
    title.AnchorVerticalCenterTo(header);
    x += widths[i]+gap;
  end;

  var n := length(FRows);
  SetLength(FChecks, n);
  SetLength(FIcons, n);
  SetLength(FCaptions, n);
  SetLength(FUps, n);
  SetLength(FDowns, n);
  for var k := 0 to n-1 do begin
    var row := TPanel.Create(self);
    row.Parent := page;
    row.BevelOuter := bvNone;
    row.SetBounds(0, 0, totalW, rowH);
    stack(page, prev, row, 0);
    var check := TCheckBox.Create(self);
    check.Parent := row;
    check.Left := 0;
    check.Constraints.MaxWidth := checkW;
    check.AnchorVerticalCenterTo(row);
    check.OnChange := @rowChanged;
    check.Tag := k;
    FChecks[k] := check;
    var icons := TComboBox.Create(self);
    icons.Parent := row;
    icons.Style := csOwnerDrawFixed;
    icons.ItemHeight := Scale96ToScreen(20);
    for var g := low(TThemeGlyph) to high(TThemeGlyph) do icons.Items.Add(glyphCaption(g));
    icons.Left := checkW+gap;
    icons.Width := iconW;
    icons.AnchorVerticalCenterTo(row);
    icons.OnDrawItem := @iconDraw;
    icons.OnChange := @rowChanged;
    icons.Tag := k;
    FIcons[k] := icons;
    var caption := TEdit.Create(self);
    caption.Parent := row;
    caption.Left := checkW+iconW+gap*2;
    caption.Width := captionW;
    caption.AnchorVerticalCenterTo(row);
    caption.OnChange := @rowChanged;
    caption.Tag := k;
    FCaptions[k] := caption;
    var up := TButton.Create(self);
    up.Parent := row;
    up.Caption := BUTTON_UP;
    up.SetBounds(checkW+iconW+captionW+gap*3, 0, orderW, Scale96ToScreen(24));
    up.AnchorVerticalCenterTo(row);
    up.OnClick := @upClicked;
    up.Tag := k;
    up.Enabled := k > 0;
    FUps[k] := up;
    var down := TButton.Create(self);
    down.Parent := row;
    down.Caption := BUTTON_DOWN;
    down.SetBounds(up.Left+orderW+gap, 0, orderW, up.Height);
    down.AnchorVerticalCenterTo(row);
    down.OnClick := @downClicked;
    down.Tag := k;
    down.Enabled := k < n-1;
    FDowns[k] := down;
  end;

  FNote := TLabel.Create(self);
  FNote.Parent := page;
  FNote.Caption := LABEL_SWITCH_NOTE;
  FNote.WordWrap := true;
  FNote.AutoSize := true;
  FNote.Constraints.MinWidth := totalW;
  FNote.Constraints.MaxWidth := totalW;
  FNote.Visible := FSwitch.Style = twSwitch;
  if FNote.Visible then stack(page, prev, FNote, gap);

  // the switch as it will look, its style and its colors kept
  var box := TGroupBox.Create(self);
  box.Parent := page;
  box.Caption := HEADER_PREVIEW;
  box.AutoSize := true;
  box.Constraints.MinWidth := totalW;
  stack(page, prev, box, gap);
  box.ChildSizing.LeftRightSpacing := margin;
  box.ChildSizing.TopBottomSpacing := gap;
  FPreview := TThemeSwitch.Create(self);
  FPreview.AutoApply := false;
  FPreview.Style := FSwitch.Style;
  FPreview.Content := FSwitch.Content;
  FPreview.Images := FSwitch.Images;
  FPreview.ImageWidth := FSwitch.ImageWidth;
  FPreview.IconSize := FSwitch.IconSize;
  FPreview.Spacing := FSwitch.Spacing;
  FPreview.Padding := FSwitch.Padding;
  FPreview.Gap := FSwitch.Gap;
  FPreview.CornerRadius := FSwitch.CornerRadius;
  FPreview.Pill := FSwitch.Pill;
  FPreview.Vertical := FSwitch.Vertical;
  FPreview.Flat := FSwitch.Flat;
  FPreview.ColoredIcons := FSwitch.ColoredIcons;
  FPreview.SelectedColor := FSwitch.SelectedColor;
  FPreview.SelectedTextColor := FSwitch.SelectedTextColor;
  FPreview.BarColor := FSwitch.BarColor;
  FPreview.BorderColor := FSwitch.BorderColor;
  FPreview.TextColor := FSwitch.TextColor;
  FPreview.Font := FSwitch.Font;
  FPreview.AttachTo := theme;
  FPreview.Parent := box;

  var buttons := TPanel.Create(self);
  buttons.Parent := page;
  buttons.BevelOuter := bvNone;
  buttons.SetBounds(0, 0, totalW, Scale96ToScreen(30));
  stack(page, prev, buttons, margin);
  var ok := TButton.Create(self);
  ok.Parent := buttons;
  ok.Caption := BUTTON_OK;
  ok.ModalResult := mrOK;
  ok.Default := true;
  ok.Width := Scale96ToScreen(80);
  ok.Align := alRight;
  ok.BorderSpacing.Left := gap;
  var cancel := TButton.Create(self);
  cancel.Parent := buttons;
  cancel.Caption := BUTTON_CANCEL;
  cancel.ModalResult := mrCancel;
  cancel.Cancel := true;
  cancel.Width := Scale96ToScreen(80);
  cancel.Left := AFTER; // right of the OK button
  cancel.Align := alRight;
  var reset := TButton.Create(self);
  reset.Parent := buttons;
  reset.Caption := BUTTON_RESET;
  reset.AutoSize := true;
  reset.Align := alLeft;
  reset.OnClick := @resetClicked;
end;

// puts `c` under `prev` on the page, or at the top of the page as the first one
procedure TThemeChoiceForm.stack(page: TWinControl; var prev: TControl; c: TControl; space: integer);
begin
  c.AnchorSideLeft.Control := page;
  c.AnchorSideLeft.Side := asrTop;
  c.AnchorSideTop.Control := if prev = nil then page else prev;
  c.AnchorSideTop.Side := if prev = nil then asrTop else asrBottom;
  c.Anchors := [akLeft, akTop];
  c.BorderSpacing.Top := space;
  prev := c;
end;

procedure TThemeChoiceForm.fillRow(k: integer);
begin
  var row := FRows[k];
  FChecks[k].Checked := row.Shown;
  FChecks[k].Caption := presetCaption(row.Preset);
  FIcons[k].ItemIndex := ord(row.Glyph);
  FCaptions[k].Text := row.Caption;
  FCaptions[k].TextHint := presetCaption(row.Preset);
  FIcons[k].Invalidate;
end;

procedure TThemeChoiceForm.readRow(k: integer);
begin
  FRows[k].Shown := FChecks[k].Checked;
  if FIcons[k].ItemIndex >= 0 then FRows[k].Glyph := TThemeGlyph(FIcons[k].ItemIndex);
  FRows[k].Caption := FCaptions[k].Text;
end;

procedure TThemeChoiceForm.swapRows(a, b: integer);
begin
  if (a < 0) or (b < 0) or (a > high(FRows)) or (b > high(FRows)) then exit;
  readRow(a);
  readRow(b);
  var t := FRows[a];
  FRows[a] := FRows[b];
  FRows[b] := t;
  FFilling := true;
  try
    fillRow(a);
    fillRow(b);
  finally
    FFilling := false;
  end;
  updatePreview;
end;

procedure TThemeChoiceForm.rowChanged(Sender: TObject);
begin
  if FFilling then exit;
  readRow(TComponent(Sender).Tag);
  updatePreview;
end;

procedure TThemeChoiceForm.upClicked(Sender: TObject);
begin
  var k := TComponent(Sender).Tag;
  swapRows(k, k-1);
  // the focus moves with the row, so a repeated press keeps moving it
  if k > 1 then FUps[k-1].SetFocus else FDowns[k-1].SetFocus;
end;

procedure TThemeChoiceForm.downClicked(Sender: TObject);
begin
  var k := TComponent(Sender).Tag;
  swapRows(k, k+1);
  if k+1 < high(FRows) then FDowns[k+1].SetFocus else FUps[k+1].SetFocus;
end;

procedure TThemeChoiceForm.resetClicked(Sender: TObject);
begin
  // Light and Dark on top with their own icons, everything else unchecked
  for var k := 0 to high(FRows) do readRow(k);
  var order: array of TChoiceRow := [];
  for var p in [tpLight, tpDark] do
    for var k := 0 to high(FRows) do
      if FRows[k].Preset = p then begin
        var row := FRows[k];
        row.Shown := true;
        row.Glyph := tgAuto;
        row.Caption := '';
        order += [row];
        break;
      end;
  for var k := 0 to high(FRows) do
    if not (FRows[k].Preset in [tpLight, tpDark]) then begin
      var row := FRows[k];
      row.Shown := false;
      order += [row];
    end;
  FRows := order;
  FFilling := true;
  try
    for var k := 0 to high(FRows) do fillRow(k);
  finally
    FFilling := false;
  end;
  updatePreview;
end;

procedure TThemeChoiceForm.iconDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
  var combo := TComboBox(Control);
  var canvas := combo.Canvas;
  var selected := (odSelected in State) and not (odComboBoxEdit in State);
  var back := ColorToRGB(if selected then clHighlight else clWindow);
  var text := ColorToRGB(if selected then clHighlightText else clWindowText);
  canvas.Brush.Color := back;
  canvas.FillRect(ARect);
  if (Index < 0) or (Index > ord(high(TThemeGlyph))) then exit;
  var glyph := TThemeGlyph(Index);
  var name := glyphCaption(glyph);
  // Auto shows the icon it stands for
  if glyph = tgAuto then begin
    var k := combo.Tag;
    var meant := if (k >= 0) and (k <= high(FRows)) then defaultGlyphOf(FRows[k].Preset) else tgNone;
    name := Format(AUTO_GLYPH, [glyphCaption(meant)]);
    glyph := meant;
  end;
  drawGlyphLine(canvas, ARect, glyph, name, text, back);
end;

procedure TThemeChoiceForm.writeItems(items: TThemeSwitchItems);
begin
  items.BeginUpdate;
  try
    items.Clear;
    for var row in FRows do begin
      // an unchecked theme stays as a hidden item when it came from one, so
      // its settings survive
      if not row.Shown and not row.Existing then continue;
      var item := items.Add;
      item.Preset := row.Preset;
      item.Glyph := row.Glyph;
      item.Caption := row.Caption;
      item.ImageIndex := row.ImageIndex;
      item.IconColor := row.IconColor;
      item.Hint := row.Hint;
      item.Visible := row.Shown;
    end;
  finally
    items.EndUpdate;
  end;
end;

procedure TThemeChoiceForm.updatePreview;
begin
  if FPreview = nil then exit;
  writeItems(FPreview.Themes);
end;

procedure TThemeChoiceForm.Apply;
begin
  for var k := 0 to high(FRows) do readRow(k);
  writeItems(FSwitch.Themes);
end;

{ TThemeSwitchComponentEditor }

procedure TThemeSwitchComponentEditor.Edit;
begin
  if editThemes(Component as TThemeSwitch) then Modified;
end;

procedure TThemeSwitchComponentEditor.ExecuteVerb(Index: Integer);
begin
  if Index = 0 then Edit;
end;

function TThemeSwitchComponentEditor.GetVerb(Index: Integer): string;
begin
  result := if Index = 0 then VERB_CHOOSE else '';
end;

function TThemeSwitchComponentEditor.GetVerbCount: Integer;
begin
  result := 1;
end;

{ TThemeSwitchThemesEditor }

function TThemeSwitchThemesEditor.GetAttributes: TPropertyAttributes;
begin
  result := [paDialog, paReadOnly];
end;

function TThemeSwitchThemesEditor.GetValue: string;
begin
  result := '';
  var items := TThemeSwitchItems(GetObjectValue);
  if items = nil then exit;
  for var i := 0 to items.Count-1 do begin
    if not items[i].Visible then continue;
    if result <> '' then result += ', ';
    result += items[i].ShownCaption;
  end;
  result := '('+result+')';
end;

procedure TThemeSwitchThemesEditor.Edit;
begin
  var target := GetComponent(0);
  if not (target is TThemeSwitch) then exit;
  if editThemes(TThemeSwitch(target)) then Modified;
end;

{ TThemeGlyphPropertyEditor }

function TThemeGlyphPropertyEditor.GetAttributes: TPropertyAttributes;
begin
  // the icons keep the order of the type, not the order of their names
  result := inherited GetAttributes-[paSortList]+[paCustomDrawn];
end;

function TThemeGlyphPropertyEditor.presetOf: TThemePreset;
begin
  var item := GetComponent(0);
  result := if item is TThemeSwitchItem then TThemeSwitchItem(item).Preset else tpLight;
end;

procedure TThemeGlyphPropertyEditor.ListMeasureHeight(const AValue: ansistring; Index: Integer; ACanvas: TCanvas; var AHeight: Integer);
begin
  AHeight := Math.Max(AHeight, ACanvas.TextHeight('Hg')+8);
end;

procedure TThemeGlyphPropertyEditor.ListDrawValue(const AValue: ansistring; Index: Integer; ACanvas: TCanvas; const ARect: TRect; AState: TPropEditDrawState);
begin
  var value := GetEnumValue(GetPropType, AValue);
  if (value < ord(low(TThemeGlyph))) or (value > ord(high(TThemeGlyph))) then begin
    inherited ListDrawValue(AValue, Index, ACanvas, ARect, AState);
    exit;
  end;
  var glyph := TThemeGlyph(value);
  var name := glyphCaption(glyph);
  if glyph = tgAuto then begin
    glyph := defaultGlyphOf(presetOf);
    name := Format(AUTO_GLYPH, [glyphCaption(glyph)]);
  end;
  var back := ACanvas.Brush.Color;
  var text := ACanvas.Font.Color;
  // the open list: the stock colors of a list, the selected row highlighted
  if (pedsInComboList in AState) and not (pedsInEdit in AState) then begin
    back := if pedsSelected in AState then clHighlight else clWindow;
    text := if pedsSelected in AState then clHighlightText else clWindowText;
    ACanvas.Brush.Color := back;
    ACanvas.FillRect(ARect);
  end;
  drawGlyphLine(ACanvas, ARect, glyph, name, text, back);
end;

procedure TThemeGlyphPropertyEditor.PropDrawValue(ACanvas: TCanvas; const ARect: TRect; AState: TPropEditDrawState);
begin
  ListDrawValue(GetValue, -1, ACanvas, ARect, AState);
end;

end.
