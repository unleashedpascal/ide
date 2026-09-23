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
  Classes, Graphics, Forms, Controls, StdCtrls, Dialogs;

type
  // the colors a whole scheme is derived from
  TSchemeSeed = record
    background, foreground, keyword, str, number, comment, directive: TColor;
  end;

  { TSchemeCreatorForm }

  // stay-on-top tool: every change previews on the open editors, Save writes a user scheme file
  TSchemeCreatorForm = class(TForm)
    LabelName: TLabel;
    EditName: TEdit;
    LabelBackground: TLabel;
    ButtonBackground: TColorButton;
    LabelText: TLabel;
    ButtonText: TColorButton;
    LabelKeyword: TLabel;
    ButtonKeyword: TColorButton;
    LabelString: TLabel;
    ButtonString: TColorButton;
    LabelNumber: TLabel;
    ButtonNumber: TColorButton;
    LabelComment: TLabel;
    ButtonComment: TColorButton;
    LabelDirective: TLabel;
    ButtonDirective: TColorButton;
    CheckBoxApply: TCheckBox;
    ButtonSave: TButton;
    ButtonClose: TButton;
    procedure FormCreate({%H-}Sender: TObject);
    procedure FormClose({%H-}Sender: TObject; var CloseAction: TCloseAction);
    procedure ColorChanged({%H-}Sender: TObject);
    procedure ButtonSaveClick({%H-}Sender: TObject);
    procedure ButtonCloseClick({%H-}Sender: TObject);
  private
    fLoading: boolean;
    fPreviewed: boolean;
    function seed: TSchemeSeed;
    procedure showSeed(const value: TSchemeSeed);
    procedure preview;
  end;

// shows the single creator window
procedure showSchemeCreator;

implementation

uses
  SysUtils, TypInfo, LazFileUtils, Laz2_XMLCfg, SynEditStrConst, SourceMarks, EditorOptions, SourceEditor, LazarusIDEStrConsts, SchemeMenu;

{$R *.lfm}

const
  SCHEME_PATH = 'Lazarus/ColorSchemes/';
  PREVIEW_NAME = 'SchemePreview';
  ERROR_RED = TColor($3C3CD8);
  RUN_GREEN = TColor($50A050);
  WARN_AMBER = TColor($30A0D8);
  DEFAULT_SEED: TSchemeSeed = (background: $242018; foreground: $E2DEDC; keyword: $5A96C8; str: $78BE8C; number: $DCB478; comment: $888078; directive: $C88CBE);

var
  creator: TSchemeCreatorForm = nil;

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

// the mapping the scheme loader applies to stored names
function validXmlName(const s: string): string;
begin
  result := s;
  for var i := 1 to length(result) do if result[i] not in ['a'..'z', 'A'..'Z', '_', '0'..'9'] then result[i] := '_';
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
  attr(p(SYNS_XML_AttrString), seed.str);
  attr(p(SYNS_XML_AttrNumber), seed.number);
  attr(p(SYNS_XML_AttrSymbol), mix(fg, seed.keyword, 25));
  attr(p(SYNS_XML_AttrIdentifier), fg);
  attr(p(SYNS_XML_AttrDirective), seed.directive, clNone, clNone, 'fsItalic');
  attr(p(SYNS_XML_AttrIDEDirective), mix(seed.directive, fg, 30));
  attr(p(SYNS_XML_AttrAssembler), mix(fg, seed.number, 40));
  attr(p(SYNS_XML_AttrProcedureHeaderName), mix(fg, seed.keyword, 40), clNone, clNone, 'fsBold');
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
  LabelBackground.Caption := lisSchemeCreatorBackground;
  LabelText.Caption := lisSchemeCreatorText;
  LabelKeyword.Caption := lisSchemeCreatorKeywords;
  LabelString.Caption := lisSchemeCreatorStrings;
  LabelNumber.Caption := lisSchemeCreatorNumbers;
  LabelComment.Caption := lisSchemeCreatorComments;
  LabelDirective.Caption := lisSchemeCreatorDirectives;
  CheckBoxApply.Caption := lisSchemeCreatorApply;
  ButtonSave.Caption := lisSave;
  ButtonClose.Caption := lisClose;
  showSeed(DEFAULT_SEED);
end;

procedure TSchemeCreatorForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if fPreviewed then reloadEditorColors;
  creator := nil;
  CloseAction := caFree;
end;

function TSchemeCreatorForm.seed: TSchemeSeed;
begin
  result.background := ButtonBackground.ButtonColor;
  result.foreground := ButtonText.ButtonColor;
  result.keyword := ButtonKeyword.ButtonColor;
  result.str := ButtonString.ButtonColor;
  result.number := ButtonNumber.ButtonColor;
  result.comment := ButtonComment.ButtonColor;
  result.directive := ButtonDirective.ButtonColor;
end;

procedure TSchemeCreatorForm.showSeed(const value: TSchemeSeed);
begin
  fLoading := true;
  defer fLoading := false;
  ButtonBackground.ButtonColor := value.background;
  ButtonText.ButtonColor := value.foreground;
  ButtonKeyword.ButtonColor := value.keyword;
  ButtonString.ButtonColor := value.str;
  ButtonNumber.ButtonColor := value.number;
  ButtonComment.ButtonColor := value.comment;
  ButtonDirective.ButtonColor := value.directive;
end;

procedure TSchemeCreatorForm.ColorChanged(Sender: TObject);
begin
  if not fLoading then preview;
end;

// pushes a throwaway scheme built from the current seed onto the open editors
procedure TSchemeCreatorForm.preview;
begin
  var cfg := autofree TRttiXMLConfig.CreateClean('');
  writeSchemeXml(cfg, PREVIEW_NAME, seed);
  var scheme := autofree TColorScheme.CreateFromXml(cfg, PREVIEW_NAME, SCHEME_PATH);
  for var i := 0 to SourceEditorManager.SourceEditorCount-1 do begin
    var editor := SourceEditorManager.SourceEditors[i].EditorComponent;
    if editor.Highlighter = nil then continue;
    var lang := scheme.ColorSchemeBySynHl[editor.Highlighter];
    if lang = nil then continue;
    lang.ApplyTo(editor.Highlighter);
    lang.ApplyTo(editor);
  end;
  fPreviewed := true;
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
  if CheckBoxApply.Checked then activateColorScheme(name) else reloadEditorColors;
  Close;
end;

procedure TSchemeCreatorForm.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
