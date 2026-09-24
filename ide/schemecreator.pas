{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SchemeCreator;

{$mode unleashed}

interface

uses
  Classes, Graphics, Forms, Controls, StdCtrls, ExtCtrls, Dialogs;

type
  // the parts of a scheme a roll derives from the IDE theme instead of the palette
  TSchemeMatch = (smBackground, smDividers, smInspector);
  TSchemeMatches = set of TSchemeMatch;

  TDividerSeed = record
    enabled: boolean;
    color: TColor;
  end;

  // the colors a whole scheme is derived from; strFill is the background behind string literals
  TSchemeSeed = record
    background, foreground, keyword, str, number, comment, directive: TColor;
    strFill: TDividerSeed;
    oiReference, oiValue: TColor;
    sections, usesClause, types: TDividerSeed;
  end;

  { TSchemeCreatorForm }

  // stay-on-top tool: every change previews on the open editors, Save writes a user scheme file
  TSchemeCreatorForm = class(TForm)
    LabelName: TLabel;
    EditName: TEdit;
    LineSyntax: TPaintBox;
    LabelBackground: TLabel;
    ButtonBackground: TColorButton;
    LabelText: TLabel;
    ButtonText: TColorButton;
    LabelKeyword: TLabel;
    ButtonKeyword: TColorButton;
    LabelString: TLabel;
    ButtonString: TColorButton;
    CheckBoxStringFill: TCheckBox;
    ButtonStringFill: TColorButton;
    LabelNumber: TLabel;
    ButtonNumber: TColorButton;
    LabelComment: TLabel;
    ButtonComment: TColorButton;
    LabelDirective: TLabel;
    ButtonDirective: TColorButton;
    LineInspector: TPaintBox;
    LabelReference: TLabel;
    ButtonReference: TColorButton;
    LabelValue: TLabel;
    ButtonValue: TColorButton;
    LineDividers: TPaintBox;
    CheckBoxSections: TCheckBox;
    ButtonSections: TColorButton;
    CheckBoxUses: TCheckBox;
    ButtonUses: TColorButton;
    CheckBoxTypes: TCheckBox;
    ButtonTypes: TColorButton;
    LineRoll: TPaintBox;
    ButtonRandomDark: TButton;
    ButtonRandomLight: TButton;
    ButtonPrevious: TButton;
    ButtonNext: TButton;
    CheckBoxMatchTheme: TCheckBox;
    CheckBoxMatchDividers: TCheckBox;
    CheckBoxMatchInspector: TCheckBox;
    CheckBoxApply: TCheckBox;
    LineButtons: TPaintBox;
    ButtonSave: TButton;
    ButtonClose: TButton;
    procedure FormCreate({%H-}Sender: TObject);
    procedure FormClose({%H-}Sender: TObject; var CloseAction: TCloseAction);
    procedure ColorChanged({%H-}Sender: TObject);
    procedure LinePaint(Sender: TObject);
    procedure DividerToggled(Sender: TObject);
    procedure CheckBoxMatchThemeChange({%H-}Sender: TObject);
    procedure ButtonRandomClick(Sender: TObject);
    procedure ButtonPreviousClick({%H-}Sender: TObject);
    procedure ButtonNextClick({%H-}Sender: TObject);
    procedure ButtonSaveClick({%H-}Sender: TObject);
    procedure ButtonCloseClick({%H-}Sender: TObject);
  private
    fLoading: boolean;
    fPreviewed: boolean;
    fHistory: array of TSchemeSeed;
    fHistPos: integer; // entry on screen, -1 before the first roll
    function seed: TSchemeSeed;
    procedure showSeed(const value: TSchemeSeed);
    function matches: TSchemeMatches;
    procedure preview;
    procedure restorePreview;
    procedure pushHistory(const value: TSchemeSeed);
    procedure walkHistory(step: integer);
    procedure updateHistoryButtons;
    procedure updateRollButtons;
    procedure updateDividerButtons;
  end;

// shows the single creator window
procedure showSchemeCreator;
// forgets the unsaved scheme; the caller brings the stored colors back
procedure dropSchemePreview;

implementation

uses
  SysUtils, Math, TypInfo, GraphUtil, LazFileUtils, Laz2_XMLCfg, SynEditStrConst, SrcEditorIntf, SourceMarks, EditorOptions, SourceEditor, LazarusIDEStrConsts, SchemeMenu, SchemeIdeColors;

{$R *.lfm}

const
  SCHEME_PATH = 'Lazarus/ColorSchemes/';
  PREVIEW_NAME = 'SchemePreview';
  HISTORY_SIZE = 100;
  ERROR_RED = TColor($3C3CD8);
  RUN_GREEN = TColor($50A050);
  WARN_AMBER = TColor($30A0D8);
  DEFAULT_SEED: TSchemeSeed = (background: $242018; foreground: $E2DEDC; keyword: $5A96C8; str: $78BE8C; number: $DCB478; comment: $888078; directive: $C88CBE;
    strFill: (enabled: false; color: $262D24); oiReference: $C87850; oiValue: $3C8CD2; sections: (enabled: true; color: $4A7293); usesClause: (enabled: true; color: $527758); types: (enabled: true; color: $5D5953));

type
  TPreviewGlue = class(TComponent)
    procedure editorChanged(Sender: TObject);
  end;

var
  creator: TSchemeCreatorForm = nil;
  previewScheme: TColorScheme = nil; // shown on the editors, unsaved
  previewGlue: TPreviewGlue = nil;

// percent of tint blended into base, per channel
function mix(base, tint: TColor; percent: integer): TColor;
begin
  var b := ColorToRGB(base);
  var t := ColorToRGB(tint);
  result := RGBToColor(Red(b)+(integer(Red(t))-Red(b))*percent div 100, Green(b)+(integer(Green(t))-Green(b))*percent div 100, Blue(b)+(integer(Blue(t))-Blue(b))*percent div 100);
end;

// the editor draws its caret as NOT(color XOR screen), so this color shows as `shown` over `under`
function caretMask(shown, under: TColor): TColor;
begin
  result := TColor((ColorToRGB(shown) xor ColorToRGB(under)) xor $FFFFFF);
end;

function between(lo, hi: integer): integer;
begin
  result := lo+random(hi-lo+1);
end;

// hue wraps around, luminance and saturation are 0..255
function hls(h, l, s: integer): TColor;
begin
  result := HLStoColor(byte(h and 255), byte(l), byte(s));
end;

// the color nudged a little, so a roll matched to the theme still varies
function nearTheme(c: TColor): TColor;
begin
  ColorToHLS(c, var h, var l, var s);
  result := hls(h+between(-8, 8), EnsureRange(l+between(-8, 8), 0, 255), EnsureRange(s+between(-20, 20), 0, 255));
end;

// a color for the object inspector, which draws on the theme window color rather than the editor
// background: the hue of c turned by shift, lit for that surface
function inspectorColor(c: TColor; shift: integer): TColor;
begin
  ColorToHLS(c, var h, _, var s);
  result := if ColorToGray(clWindow) < 128 then hls(h+shift, between(160, 190), max(s, 120)) else hls(h+shift, between(70, 100), max(s, 140));
end;

// a random scheme around one base hue: four accents a quarter turn apart, comments on the opposite side;
// matched to the theme, the surface follows the window colors and the accents start from the highlight hue.
// The divider lines and the inspector colors follow the accents, or the highlight color when matched
function rollSeed(const current: TSchemeSeed; dark: boolean; themed: TSchemeMatches): TSchemeSeed;
begin
  result := current;
  var base := random(256);
  if smBackground in themed then begin
    ColorToHLS(clHighlight, var h, _, _);
    base := h;
  end;
  var accent: array[4] of TColor;
  var spin := random(4);
  for var i := 0 to 3 do begin
    var hue := base+64*((i+spin) mod 4)+between(-18, 18);
    accent[i] := if dark then hls(hue, between(150, 190), between(110, 200)) else hls(hue, between(70, 110), between(120, 220));
  end;
  if smBackground in themed then begin
    result.background := nearTheme(clWindow);
    result.foreground := nearTheme(clWindowText);
  end else if dark then begin
    result.background := hls(base, between(16, 36), between(20, 60));
    result.foreground := hls(base, between(215, 235), between(10, 40));
  end else begin
    result.background := hls(base, between(232, 248), between(30, 90));
    result.foreground := hls(base, between(25, 50), between(20, 60));
  end;
  result.comment := if dark then hls(base+128+between(-30, 30), between(115, 145), between(30, 70)) else hls(base+128+between(-30, 30), between(100, 130), between(30, 70));
  result.keyword := accent[0];
  result.str := accent[1];
  result.number := accent[2];
  result.directive := accent[3];
  // most rolls tint the background behind strings a little toward their color
  result.strFill.enabled := random(4) < 3;
  result.strFill.color := mix(result.background, result.str, between(10, 22));
  // divider lines are tints on the editor background
  if smDividers in themed then begin
    result.sections.color := mix(result.background, clHighlight, 70);
    result.usesClause.color := mix(result.background, clHighlight, 45);
    result.types.color := mix(result.background, clHighlight, 30);
  end else begin
    result.sections.color := mix(result.background, result.keyword, 70);
    result.usesClause.color := mix(result.background, result.str, 55);
    result.types.color := mix(result.background, result.foreground, 30);
  end;
  if smInspector in themed then begin
    result.oiReference := inspectorColor(clHighlight, 0);
    result.oiValue := inspectorColor(clHighlight, 128);
  end else begin
    result.oiReference := inspectorColor(result.keyword, 0);
    result.oiValue := inspectorColor(result.number, 0);
  end;
end;

// writes the scheme derived from the seed in the layout the scheme loader reads
procedure writeSchemeXml(cfg: TRttiXMLConfig; const name: string; const seed: TSchemeSeed);
var
  globals, pascal: string;

  // the colors of one attribute; clNone leaves the key out
  procedure attr(const path: string; fg: TColor; bg: TColor=clNone; frame: TColor=clNone; const style: string='');
  begin
    if fg <> clNone then cfg.SetValue(path+'Foreground', longint(fg));
    if bg <> clNone then cfg.SetValue(path+'Background', longint(bg));
    if frame <> clNone then cfg.SetValue(path+'FrameColor', longint(frame));
    if style <> '' then cfg.SetValue(path+'Style', style);
  end;

  function g(aha: TAdditionalHilightAttribute): string;
  begin
    result := globals+GetEnumName(TypeInfo(TAdditionalHilightAttribute), ord(aha))+'/';
  end;

  function p(const stored: string): string;
  begin
    result := pascal+validXmlName(stored)+'/';
  end;

  procedure outline(level: integer; c: TColor);
  begin
    var path := globals+$'ahaOutlineLevel{level}Color/';
    attr(path, c);
    cfg.SetValue(path+'MarkupFoldLineColor', longint(c));
  end;

begin
  var key := 'Scheme'+validXmlName(name)+'/';
  globals := SCHEME_PATH+'Globals/'+key;
  pascal := SCHEME_PATH+'LangObjectPascal/'+key;
  cfg.SetValue(SCHEME_PATH+'Version', EditorOptsFormatVersion);
  cfg.SetValue(SCHEME_PATH+'Names/Count', 1);
  cfg.SetValue(SCHEME_PATH+'Names/Item1/Value', name);
  cfg.SetValue(SCHEME_PATH+'Globals/Version', EditorOptsFormatVersion);
  cfg.SetValue(SCHEME_PATH+'LangObjectPascal/Version', EditorOptsFormatVersion);
  var bg := seed.background;
  var fg := seed.foreground;

  // editor surface
  attr(globals+'ahaDefault/', fg, bg);
  attr(g(ahaTextBlock), clNone, mix(bg, seed.keyword, 30));
  var lineBg := mix(bg, fg, 6);
  attr(g(ahaLineHighlight), clNone, lineBg);
  // the caret always sits on the highlighted line; the second color is for the extra carets
  attr(g(ahaCaretColor), caretMask(fg, lineBg), caretMask(fg, lineBg));
  attr(g(ahaRightMargin), mix(bg, fg, 15));
  attr(g(ahaSpecialVisibleChars), mix(bg, fg, 30));
  attr(g(ahaTopInfoHint), fg, mix(bg, fg, 6));

  // gutter and folding
  attr(g(ahaGutter), clNone, mix(bg, fg, 3));
  attr(g(ahaGutterSeparator), mix(bg, fg, 15), mix(bg, fg, 3));
  attr(g(ahaLineNumber), mix(bg, fg, 45));
  attr(g(ahaGutterCurrentLine), clNone, mix(bg, fg, 8));
  attr(g(ahaGutterNumberCurrentLine), mix(bg, fg, 80));
  attr(g(ahaOverviewGutter), clNone, mix(bg, fg, 4));
  attr(g(ahaModifiedLine), mix(fg, RUN_GREEN, 60), clNone, seed.number);
  attr(g(ahaCodeFoldingTree), mix(bg, fg, 35));
  attr(g(ahaCodeFoldingTreeCurrent), seed.keyword);
  attr(g(ahaFoldedCode), seed.comment, clNone, mix(bg, fg, 30));
  attr(g(ahaFoldedCodeLine), clNone, mix(bg, fg, 8));
  attr(g(ahaHiddenCodeLine), clNone, mix(bg, fg, 8));

  // markup
  attr(g(ahaBracketMatch), clNone, clNone, seed.keyword, 'fsBold');
  attr(g(ahaHighlightWord), clNone, mix(bg, fg, 12));
  attr(g(ahaHighlightAll), clNone, mix(bg, seed.number, 45));
  attr(g(ahaIncrementalSearch), fg, mix(bg, seed.str, 45));
  attr(g(ahaMouseLink), seed.keyword, clNone, seed.keyword);
  attr(g(ahaWordGroup), clNone, clNone, mix(bg, seed.str, 50));
  attr(g(ahaTemplateEditCur), clNone, clNone, seed.keyword);
  attr(g(ahaTemplateEditSync), clNone, clNone, seed.str);
  attr(g(ahaTemplateEditOther), clNone, clNone, seed.directive);
  attr(g(ahaSyncroEditCur), clNone, clNone, seed.keyword);
  attr(g(ahaSyncroEditSync), clNone, clNone, seed.str);
  attr(g(ahaSyncroEditOther), clNone, clNone, seed.directive);
  attr(g(ahaSyncroEditArea), clNone, mix(bg, fg, 8));
  attr(g(ahaIfDefBlockInactive), mix(bg, fg, 40));
  attr(g(ahaIfDefNodeInactive), mix(bg, fg, 40));

  // debugger lines
  attr(g(ahaErrorLine), clNone, mix(bg, ERROR_RED, 30));
  attr(g(ahaExecutionPoint), clNone, mix(bg, RUN_GREEN, 35));
  attr(g(ahaEnabledBreakpoint), clNone, mix(bg, ERROR_RED, 40));
  attr(g(ahaDisabledBreakpoint), clNone, mix(bg, ERROR_RED, 15));
  attr(g(ahaInvalidBreakpoint), clNone, mix(bg, WARN_AMBER, 30));
  attr(g(ahaUnknownBreakpoint), clNone, mix(bg, WARN_AMBER, 20));

  // identifier completion window
  attr(g(ahaIdentComplWindow), fg, mix(bg, fg, 3));
  attr(g(ahaIdentComplWindowBorder), mix(bg, fg, 30));
  attr(g(ahaIdentComplWindowSelection), clNone, mix(bg, seed.keyword, 35));
  attr(g(ahaIdentComplWindowHighlight), seed.keyword);
  attr(g(ahaIdentComplRecent), seed.str);
  attr(g(ahaIdentComplWindowEntryVar), mix(fg, seed.number, 50));
  attr(g(ahaIdentComplWindowEntryType), seed.directive);
  attr(g(ahaIdentComplWindowEntryConst), seed.number);
  attr(g(ahaIdentComplWindowEntryProc), seed.keyword);
  attr(g(ahaIdentComplWindowEntryFunc), seed.keyword);
  attr(g(ahaIdentComplWindowEntryMethAbstract), mix(seed.keyword, bg, 30));
  attr(g(ahaIdentComplWindowEntryMethodLowVis), mix(seed.keyword, bg, 50));
  attr(g(ahaIdentComplWindowEntryProp), seed.str);
  attr(g(ahaIdentComplWindowEntryIdent), fg);
  attr(g(ahaIdentComplWindowEntryLabel), seed.number);
  attr(g(ahaIdentComplWindowEntryEnum), seed.directive);
  attr(g(ahaIdentComplWindowEntryUnit), seed.comment);
  attr(g(ahaIdentComplWindowEntryNameSpace), seed.comment);
  attr(g(ahaIdentComplWindowEntryText), mix(bg, fg, 60));
  attr(g(ahaIdentComplWindowEntryTempl), seed.str);
  attr(g(ahaIdentComplWindowEntryKeyword), seed.keyword);
  attr(g(ahaIdentComplWindowEntryUnknown), mix(bg, fg, 50));

  // outline levels cycle through the accents, the second half softened
  var ramp := [seed.keyword, seed.str, seed.number, seed.directive, seed.comment];
  for var i := 0 to 4 do outline(i+1, ramp[i]);
  for var i := 0 to 4 do outline(i+6, mix(ramp[i], fg, 40));

  // pascal syntax; the other languages map their attributes onto these
  attr(p(SYNS_XML_AttrComment), seed.comment, clNone, clNone, 'fsItalic');
  attr(p(SYNS_XML_AttrReservedWord), seed.keyword, clNone, clNone, 'fsBold');
  attr(p(SYNS_XML_AttrModifier), seed.keyword);
  attr(p(SYNS_XML_AttrString), seed.str, if seed.strFill.enabled then seed.strFill.color else clNone);
  attr(p(SYNS_XML_AttrNumber), seed.number);
  attr(p(SYNS_XML_AttrSymbol), mix(fg, seed.keyword, 25));
  attr(p(SYNS_XML_AttrIdentifier), fg);
  attr(p(SYNS_XML_AttrDirective), seed.directive, clNone, clNone, 'fsItalic');
  attr(p(SYNS_XML_AttrIDEDirective), mix(seed.directive, fg, 30));
  attr(p(SYNS_XML_AttrAssembler), mix(fg, seed.number, 40));
  attr(p(SYNS_XML_AttrProcedureHeaderName), mix(fg, seed.keyword, 40), clNone, clNone, 'fsBold');

  // the IDE colors beside the syntax attributes; class and routine dividers share one color
  writeSchemeOiColors(cfg, name, seed.oiReference, seed.oiValue);
  writeSchemeDivider(cfg, name, 'Sect', ord(seed.sections.enabled), seed.sections.color);
  writeSchemeDivider(cfg, name, 'Uses', ord(seed.usesClause.enabled), seed.usesClause.color);
  writeSchemeDivider(cfg, name, 'GStruct', ord(seed.types.enabled), seed.types.color);
  writeSchemeDivider(cfg, name, 'Proc', ord(seed.types.enabled), seed.types.color);
end;

procedure applyPreviewTo(editor: TSourceEditor);
begin
  var synEdit := editor.EditorComponent;
  if synEdit.Highlighter = nil then exit;
  var lang := previewScheme.ColorSchemeBySynHl[synEdit.Highlighter];
  if lang = nil then exit;
  lang.ApplyTo(synEdit.Highlighter);
  lang.ApplyTo(synEdit);
end;

// an editor opened or reconfigured later gets the stored colors, so the preview goes onto it again
procedure TPreviewGlue.editorChanged(Sender: TObject);
begin
  if (previewScheme <> nil) and (Sender is TSourceEditor) then applyPreviewTo(TSourceEditor(Sender));
end;

// pushes a throwaway scheme built from the seed onto the open editors and the object inspector
procedure previewSeed(const value: TSchemeSeed);
begin
  var cfg := autofree TRttiXMLConfig.CreateClean('');
  writeSchemeXml(cfg, PREVIEW_NAME, value);
  previewScheme.Free;
  previewScheme := TColorScheme.CreateFromXml(cfg, PREVIEW_NAME, SCHEME_PATH);
  if previewGlue = nil then begin
    previewGlue := TPreviewGlue.Create(Application);
    SourceEditorManager.RegisterChangeEvent(semEditorCreate, @previewGlue.editorChanged);
    SourceEditorManager.RegisterChangeEvent(semEditorReConfigured, @previewGlue.editorChanged);
  end;
  for var i := 0 to SourceEditorManager.SourceEditorCount-1 do applyPreviewTo(SourceEditorManager.SourceEditors[i]);
  previewSchemeIdeColors(cfg, PREVIEW_NAME);
end;

procedure dropSchemePreview;
begin
  FreeAndNil(previewScheme);
  restorePreviewOiColors;
end;

procedure showSchemeCreator;
begin
  if creator = nil then creator := TSchemeCreatorForm.Create(Application);
  creator.Show;
  creator.BringToFront;
end;

{ TSchemeCreatorForm }

procedure TSchemeCreatorForm.FormCreate(Sender: TObject);
begin
  Caption := lisSchemeCreatorTitle;
  LabelName.Caption := lisSchemeCreatorName;
  LineSyntax.Caption := lisSchemeCreatorSyntax;
  LabelBackground.Caption := lisSchemeCreatorBackground;
  LabelText.Caption := lisSchemeCreatorText;
  LabelKeyword.Caption := lisSchemeCreatorKeywords;
  LabelString.Caption := lisSchemeCreatorStrings;
  CheckBoxStringFill.Caption := lisSchemeCreatorStringFill;
  LabelNumber.Caption := lisSchemeCreatorNumbers;
  LabelComment.Caption := lisSchemeCreatorComments;
  LabelDirective.Caption := lisSchemeCreatorDirectives;
  LineInspector.Caption := lisSchemeCreatorInspector;
  LabelReference.Caption := lisSchemeCreatorReference;
  LabelValue.Caption := lisSchemeCreatorValue;
  LineDividers.Caption := lisSchemeCreatorDividers;
  CheckBoxSections.Caption := lisSchemeCreatorUnitSections;
  CheckBoxUses.Caption := lisSchemeCreatorUsesClause;
  CheckBoxTypes.Caption := lisSchemeCreatorTypesAndRoutines;
  ButtonRandomDark.Caption := lisSchemeCreatorRandomDark;
  ButtonRandomLight.Caption := lisSchemeCreatorRandomLight;
  ButtonPrevious.Caption := lisSchemeCreatorPrevious;
  ButtonNext.Caption := lisSchemeCreatorNext;
  CheckBoxMatchTheme.Caption := lisSchemeCreatorMatchTheme;
  CheckBoxMatchDividers.Caption := lisSchemeCreatorMatchDividers;
  CheckBoxMatchInspector.Caption := lisSchemeCreatorMatchInspector;
  CheckBoxApply.Caption := lisSchemeCreatorApply;
  ButtonSave.Caption := lisSave;
  ButtonClose.Caption := lisClose;
  Randomize;
  fHistPos := -1;
  updateHistoryButtons;
  updateRollButtons;
  showSeed(DEFAULT_SEED);
end;

procedure TSchemeCreatorForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if fPreviewed then restorePreview;
  creator := nil;
  CloseAction := caFree;
end;

function TSchemeCreatorForm.seed: TSchemeSeed;
begin
  result.background := ButtonBackground.ButtonColor;
  result.foreground := ButtonText.ButtonColor;
  result.keyword := ButtonKeyword.ButtonColor;
  result.str := ButtonString.ButtonColor;
  result.strFill.enabled := CheckBoxStringFill.Checked;
  result.strFill.color := ButtonStringFill.ButtonColor;
  result.number := ButtonNumber.ButtonColor;
  result.comment := ButtonComment.ButtonColor;
  result.directive := ButtonDirective.ButtonColor;
  result.oiReference := ButtonReference.ButtonColor;
  result.oiValue := ButtonValue.ButtonColor;
  result.sections.enabled := CheckBoxSections.Checked;
  result.sections.color := ButtonSections.ButtonColor;
  result.usesClause.enabled := CheckBoxUses.Checked;
  result.usesClause.color := ButtonUses.ButtonColor;
  result.types.enabled := CheckBoxTypes.Checked;
  result.types.color := ButtonTypes.ButtonColor;
end;

procedure TSchemeCreatorForm.showSeed(const value: TSchemeSeed);
begin
  fLoading := true;
  defer fLoading := false;
  ButtonBackground.ButtonColor := value.background;
  ButtonText.ButtonColor := value.foreground;
  ButtonKeyword.ButtonColor := value.keyword;
  ButtonString.ButtonColor := value.str;
  CheckBoxStringFill.Checked := value.strFill.enabled;
  ButtonStringFill.ButtonColor := value.strFill.color;
  ButtonNumber.ButtonColor := value.number;
  ButtonComment.ButtonColor := value.comment;
  ButtonDirective.ButtonColor := value.directive;
  ButtonReference.ButtonColor := value.oiReference;
  ButtonValue.ButtonColor := value.oiValue;
  CheckBoxSections.Checked := value.sections.enabled;
  ButtonSections.ButtonColor := value.sections.color;
  CheckBoxUses.Checked := value.usesClause.enabled;
  ButtonUses.ButtonColor := value.usesClause.color;
  CheckBoxTypes.Checked := value.types.enabled;
  ButtonTypes.ButtonColor := value.types.color;
  updateDividerButtons;
end;

function TSchemeCreatorForm.matches: TSchemeMatches;
begin
  result := [];
  if CheckBoxMatchTheme.Checked then include(result, smBackground);
  if CheckBoxMatchDividers.Checked then include(result, smDividers);
  if CheckBoxMatchInspector.Checked then include(result, smInspector);
end;

procedure TSchemeCreatorForm.ColorChanged(Sender: TObject);
begin
  if not fLoading then preview;
end;

// a group line with its name set into it, in plain colors so it shows under any theme
procedure TSchemeCreatorForm.LinePaint(Sender: TObject);
const
  INDENT = 10;
  GAP = 6;
begin
  var box := Sender as TPaintBox;
  var canvas := box.Canvas;
  var y := box.Height div 2;
  canvas.Pen.Color := mix(box.Color, clWindowText, 35);
  if box.Caption = '' then begin
    canvas.Line(0, y, box.Width, y);
    exit;
  end;
  canvas.Font.Style := [fsBold];
  canvas.Brush.Style := bsClear;
  var text := canvas.TextExtent(box.Caption);
  canvas.Line(0, y, INDENT, y);
  canvas.TextOut(INDENT+GAP, (box.Height-text.cy) div 2, box.Caption);
  canvas.Line(INDENT+GAP+text.cx+GAP, y, box.Width, y);
end;

procedure TSchemeCreatorForm.DividerToggled(Sender: TObject);
begin
  updateDividerButtons;
  ColorChanged(Sender);
end;

procedure TSchemeCreatorForm.preview;
begin
  previewSeed(seed);
  fPreviewed := true;
end;

// the stored colors come back onto the editors and the object inspector
procedure TSchemeCreatorForm.restorePreview;
begin
  reloadEditorColors;
end;

procedure TSchemeCreatorForm.pushHistory(const value: TSchemeSeed);
begin
  // a roll after walking back drops the entries ahead, like an undo stack
  SetLength(fHistory, fHistPos+1);
  if length(fHistory) = HISTORY_SIZE then Delete(fHistory, 0, 1);
  SetLength(fHistory, length(fHistory)+1);
  fHistory[high(fHistory)] := value;
  fHistPos := high(fHistory);
  updateHistoryButtons;
end;

procedure TSchemeCreatorForm.walkHistory(step: integer);
begin
  fHistPos += step;
  showSeed(fHistory[fHistPos]);
  updateHistoryButtons;
  preview;
end;

procedure TSchemeCreatorForm.updateHistoryButtons;
begin
  ButtonPrevious.Enabled := fHistPos > 0;
  ButtonNext.Enabled := fHistPos < high(fHistory);
end;

// a matched roll can only go the way the theme goes, so the other button waits
procedure TSchemeCreatorForm.updateRollButtons;
begin
  var darkTheme := ColorToGray(clWindow) < 128;
  ButtonRandomDark.Enabled := (not CheckBoxMatchTheme.Checked) or darkTheme;
  ButtonRandomLight.Enabled := (not CheckBoxMatchTheme.Checked) or (not darkTheme);
end;

// an unchecked divider or string fill keeps its color, shown disabled
procedure TSchemeCreatorForm.updateDividerButtons;
begin
  ButtonStringFill.Enabled := CheckBoxStringFill.Checked;
  ButtonSections.Enabled := CheckBoxSections.Checked;
  ButtonUses.Enabled := CheckBoxUses.Checked;
  ButtonTypes.Enabled := CheckBoxTypes.Checked;
end;

procedure TSchemeCreatorForm.CheckBoxMatchThemeChange(Sender: TObject);
begin
  updateRollButtons;
end;

procedure TSchemeCreatorForm.ButtonRandomClick(Sender: TObject);
begin
  var value := rollSeed(seed, Sender = ButtonRandomDark, matches);
  showSeed(value);
  pushHistory(value);
  preview;
end;

procedure TSchemeCreatorForm.ButtonPreviousClick(Sender: TObject);
begin
  walkHistory(-1);
end;

procedure TSchemeCreatorForm.ButtonNextClick(Sender: TObject);
begin
  walkHistory(1);
end;

procedure TSchemeCreatorForm.ButtonSaveClick(Sender: TObject);
begin
  var name := Trim(EditName.Text);
  if name = '' then begin
    MessageDlg(lisSchemeCreatorTitle, lisSchemeCreatorNameEmpty, mtError, [mbOK], 0);
    exit;
  end;
  var existing := ColorSchemeFactory.ColorSchemeGroup[name];
  // built-in schemes come back on every start, so a same-name file would only get renamed
  if (existing <> nil) and (existing is not TColorSchemeFromFile) then begin
    MessageDlg(lisSchemeCreatorTitle, Format(lisSchemeCreatorBuiltIn, [name]), mtError, [mbOK], 0);
    exit;
  end;
  if (existing <> nil) and (MessageDlg(lisSchemeCreatorTitle, Format(lisSchemeCreatorOverwrite, [name]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then exit;
  var fileName := AppendPathDelim(UserSchemeDirectory(true))+validXmlName(name)+'.xml';
  var cfg := autofree TRttiXMLConfig.CreateClean(fileName);
  writeSchemeXml(cfg, name, seed);
  cfg.Flush;
  if existing <> nil then begin
    ColorSchemeFactory.UnregisterScheme(name);
    EditorOpts.UserColorSchemeGroup.UnregisterScheme(name);
  end;
  // registered in both factories: the global list and the working copy the editors read
  var scheme := TColorSchemeFromFile.CreateFrom(cfg, fileName, name, SCHEME_PATH);
  ColorSchemeFactory.RegisterScheme(scheme);
  var working := TColorScheme.Create(name);
  working.Assign(scheme);
  EditorOpts.UserColorSchemeGroup.RegisterScheme(working);
  if existing = nil then addSchemeMenuItem(name);
  fPreviewed := false;
  if CheckBoxApply.Checked then activateColorScheme(name) else restorePreview;
  Close;
end;

procedure TSchemeCreatorForm.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
