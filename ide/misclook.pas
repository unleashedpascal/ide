{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit MiscLook;

{$mode unleashed}

interface

uses
  Classes, Graphics, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Spin, Dialogs, EnvGuiOptions, LazIDEIntf;

type
  // the IDE colors outside the theme and the syntax scheme: the messages window, the headers of
  // its tool runs and the text of each message urgency
  TMiscSeed = record
    background, text, running, success, failed, autoHeader: TColor;
    hint, note, warning, error, fatal: TColor;
  end;

  { TMiscLookForm }

  // stay-on-top tool: every change previews on the messages window, Save stores the colors and
  // the text style in the environment options, Close puts the stored ones back
  TMiscLookForm = class(TForm)
    LineMessages: TPaintBox;
    LabelBackground: TLabel;
    ButtonBackground: TColorButton;
    LabelText: TLabel;
    ButtonText: TColorButton;
    LabelRunning: TLabel;
    ButtonRunning: TColorButton;
    LabelSuccess: TLabel;
    ButtonSuccess: TColorButton;
    LabelFailed: TLabel;
    ButtonFailed: TColorButton;
    LabelAutoHeader: TLabel;
    ButtonAutoHeader: TColorButton;
    LabelHint: TLabel;
    ButtonHint: TColorButton;
    LabelNote: TLabel;
    ButtonNote: TColorButton;
    LabelWarning: TLabel;
    ButtonWarning: TColorButton;
    LabelError: TLabel;
    ButtonError: TColorButton;
    LabelFatal: TLabel;
    ButtonFatal: TColorButton;
    CheckBoxAutoMatch: TCheckBox;
    LineRoll: TPaintBox;
    ButtonRandomDark: TButton;
    ButtonRandomLight: TButton;
    ButtonPrevious: TButton;
    ButtonNext: TButton;
    LineText: TPaintBox;
    LabelFont: TLabel;
    ComboFont: TComboBox;
    LabelSize: TLabel;
    SpinSize: TSpinEdit;
    LabelSpacing: TLabel;
    SpinSpacing: TSpinEdit;
    LabelPaddingTop: TLabel;
    SpinPaddingTop: TSpinEdit;
    LabelPaddingBottom: TLabel;
    SpinPaddingBottom: TSpinEdit;
    LabelPaddingLeft: TLabel;
    SpinPaddingLeft: TSpinEdit;
    LabelPaddingRight: TLabel;
    SpinPaddingRight: TSpinEdit;
    LineSplit: TPaintBox;
    LineIcons: TPaintBox;
    CheckBoxIconFit: TCheckBox;
    LabelStrength: TLabel;
    ValueStrength: TLabel;
    TrackStrength: TTrackBar;
    LabelMinContrast: TLabel;
    ValueMinContrast: TLabel;
    TrackMinContrast: TTrackBar;
    LabelMaxLightness: TLabel;
    ValueMaxLightness: TLabel;
    TrackMaxLightness: TTrackBar;
    LabelDisabledContrast: TLabel;
    ValueDisabledContrast: TLabel;
    TrackDisabledContrast: TTrackBar;
    LabelDisabledSaturation: TLabel;
    ValueDisabledSaturation: TLabel;
    TrackDisabledSaturation: TTrackBar;
    ButtonIconDefaults: TButton;
    LineButtons: TPaintBox;
    ButtonSave: TButton;
    ButtonClose: TButton;
    procedure FormCreate({%H-}Sender: TObject);
    procedure FormClose({%H-}Sender: TObject; var CloseAction: TCloseAction);
    procedure ColorChanged({%H-}Sender: TObject);
    procedure TextStyleChanged({%H-}Sender: TObject);
    procedure LinePaint(Sender: TObject);
    procedure CheckBoxAutoMatchChange({%H-}Sender: TObject);
    procedure ButtonRandomClick(Sender: TObject);
    procedure ButtonPreviousClick({%H-}Sender: TObject);
    procedure ButtonNextClick({%H-}Sender: TObject);
    procedure ButtonSaveClick({%H-}Sender: TObject);
    procedure ButtonCloseClick({%H-}Sender: TObject);
    procedure IconFitChanged({%H-}Sender: TObject);
    procedure ButtonIconDefaultsClick({%H-}Sender: TObject);
  private
    fLoading: boolean;
    fPreviewed: boolean;
    fIconsPreviewed: boolean;
    fHistory: array of TMiscSeed;
    fHistPos: integer; // entry on screen, -1 before the first roll
    function seed: TMiscSeed;
    procedure showSeed(const value: TMiscSeed);
    procedure preview;
    function textStyle: TMsgWndTextStyle;
    procedure showTextStyle(const value: TMsgWndTextStyle);
    procedure previewText;
    procedure pushHistory(const value: TMiscSeed);
    procedure walkHistory(step: integer);
    procedure updateHistoryButtons;
    procedure updateRollButtons;
    function iconFit: TIconFit;
    procedure showIconFit(const value: TIconFit);
    procedure previewIcons;
    procedure updateIconLabels;
  end;

// shows the single misc look window
procedure showMiscLook;
// rolls the colors for the current IDE theme and stores them, when they are set to follow the
// theme; with keepExisting colors rolled or saved earlier stay
procedure rollThemeMiscColors(keepExisting: boolean);

implementation

uses
  SysUtils, Math, GraphUtil, LazConfigStorage, BaseIDEIntf, IDEExternToolIntf, MainIntf, ExtTools, etMessageFrame, etMessagesWnd, LazarusIDEStrConsts, SchemeCreator;

{$R *.lfm}

const
  CONFIG_FILE = 'misccolors.xml';
  KEY_AUTO_MATCH = 'AutoMatch';
  KEY_ROLLED = 'Rolled';
  HISTORY_SIZE = 100;
  // hues on the 0..255 wheel
  HUE_RED = 0;
  HUE_AMBER = 30;
  HUE_YELLOW = 42;
  HUE_GREEN = 85;
  HUE_TEAL = 115;
  HUE_SKY = 150;
  HUE_CRIMSON = 240;

var
  window: TMiscLookForm = nil;

function loadAutoMatch: boolean;
begin
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, true);
  result := cfg.GetValue(KEY_AUTO_MATCH, true);
end;

procedure saveAutoMatch(enabled: boolean);
begin
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, true);
  cfg.SetDeleteValue(KEY_AUTO_MATCH, enabled, true);
  cfg.WriteToDisk;
end;

// true once the colors were stored by a roll or by the window, so a start does not roll them again
function loadRolled: boolean;
begin
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, true);
  result := cfg.GetValue(KEY_ROLLED, false);
end;

procedure saveRolled;
begin
  var cfg := autofree GetIDEConfigStorage(CONFIG_FILE, true);
  cfg.SetDeleteValue(KEY_ROLLED, true, false);
  cfg.WriteToDisk;
end;

// a stored default resolves to the color on screen, so the window shows what is there
function shownColor(c, fallback: TColor): TColor;
begin
  result := ColorToRGB(if (c = clDefault) or (c = clNone) then fallback else c);
end;

function currentSeed: TMiscSeed;
begin
  var o := EnvironmentGuiOpts;
  result.background := shownColor(o.MsgViewColors[mwBackground], clWindow);
  result.text := shownColor(o.MsgViewColors[mwTextColor], clWindowText);
  result.running := shownColor(o.MsgViewColors[mwRunning], MsgWndDefHeaderBackgroundRunning);
  result.success := shownColor(o.MsgViewColors[mwSuccess], MsgWndDefHeaderBackgroundSuccess);
  result.failed := shownColor(o.MsgViewColors[mwFailed], MsgWndDefHeaderBackgroundFailed);
  result.autoHeader := shownColor(o.MsgViewColors[mwAutoHeader], MsgWndDefAutoHeaderBackground);
  result.hint := shownColor(o.MsgColors[mluHint], result.text);
  result.note := shownColor(o.MsgColors[mluNote], result.text);
  result.warning := shownColor(o.MsgColors[mluWarning], result.text);
  result.error := shownColor(o.MsgColors[mluError], result.text);
  result.fatal := shownColor(o.MsgColors[mluFatal], result.text);
end;

procedure applySeedTo(ctrl: TMessagesCtrl; const value: TMiscSeed);
begin
  ctrl.BackgroundColor := value.background;
  ctrl.TextColor := value.text;
  ctrl.HeaderBackground[lmvtsRunning] := value.running;
  ctrl.HeaderBackground[lmvtsSuccess] := value.success;
  ctrl.HeaderBackground[lmvtsFailed] := value.failed;
  ctrl.AutoHeaderBackground := value.autoHeader;
  ctrl.UrgencyStyles[mluHint].Color := value.hint;
  ctrl.UrgencyStyles[mluNote].Color := value.note;
  ctrl.UrgencyStyles[mluWarning].Color := value.warning;
  ctrl.UrgencyStyles[mluError].Color := value.error;
  ctrl.UrgencyStyles[mluFatal].Color := value.fatal;
end;

// onto the messages window only, the options left as they are
procedure previewSeed(const value: TMiscSeed);
begin
  if MessagesView = nil then exit;
  applySeedTo(MessagesView.MessagesFrame1.MessagesCtrl, value);
end;

procedure previewTextStyle(const value: TMsgWndTextStyle);
begin
  if MessagesView = nil then exit;
  MessagesView.MessagesFrame1.MessagesCtrl.TextStyle := value;
end;

// the stored colors and text style come back onto the messages window
procedure restorePreview;
begin
  if MessagesView <> nil then MessagesView.ApplyIDEOptions;
end;

// into the environment options, saved, and onto the messages window
procedure storeSeed(const value: TMiscSeed);
begin
  var o := EnvironmentGuiOpts;
  o.MsgViewColors[mwBackground] := value.background;
  o.MsgViewColors[mwTextColor] := value.text;
  o.MsgViewColors[mwRunning] := value.running;
  o.MsgViewColors[mwSuccess] := value.success;
  o.MsgViewColors[mwFailed] := value.failed;
  o.MsgViewColors[mwAutoHeader] := value.autoHeader;
  o.MsgColors[mluHint] := value.hint;
  o.MsgColors[mluNote] := value.note;
  o.MsgColors[mluWarning] := value.warning;
  o.MsgColors[mluError] := value.error;
  o.MsgColors[mluFatal] := value.fatal;
  MainIDEInterface.SaveEnvironment;
  restorePreview;
end;

// a fill behind a run header: the hue reads at a glance, the lightness stays a step from the
// background, so the line belongs to the window instead of shouting
function headerFill(background: TColor; hue: integer; dark: boolean): TColor;
begin
  ColorToHLS(background, _, var l, _);
  var lum := if dark then l+between(30, 46) else l-between(30, 46);
  result := hls(hue+between(-8, 8), EnsureRange(lum, 0, 255), between(120, 170));
end;

// a text tone in the hue that stands out on a dark or a light background
function textTone(hue: integer; dark: boolean): TColor;
begin
  result := if dark then hls(hue+between(-8, 8), between(150, 185), between(130, 200)) else hls(hue+between(-8, 8), between(60, 95), between(150, 220));
end;

// matched to the theme the surface follows the window colors, otherwise it is a dark or a light
// shade of one hue; the headers and the urgencies keep their telling hues either way
function rollSeed(dark, matchTheme: boolean): TMiscSeed;
begin
  if matchTheme then begin
    result.background := nearTheme(clWindow);
    result.text := nearTheme(clWindowText);
  end else begin
    var base := random(256);
    result.background := if dark then hls(base, between(16, 36), between(20, 60)) else hls(base, between(232, 248), between(30, 90));
    result.text := if dark then hls(base, between(215, 235), between(10, 40)) else hls(base, between(25, 50), between(20, 60));
  end;
  result.running := headerFill(result.background, HUE_YELLOW, dark);
  result.success := headerFill(result.background, HUE_GREEN, dark);
  result.failed := headerFill(result.background, HUE_RED, dark);
  result.autoHeader := headerFill(result.background, HUE_SKY, dark);
  result.hint := textTone(HUE_SKY, dark);
  result.note := textTone(HUE_TEAL, dark);
  result.warning := textTone(HUE_AMBER, dark);
  result.error := textTone(HUE_RED, dark);
  result.fatal := textTone(HUE_CRIMSON, dark);
end;

procedure rollThemeMiscColors(keepExisting: boolean);
begin
  if not loadAutoMatch then exit;
  if keepExisting and loadRolled then exit;
  Randomize;
  storeSeed(rollSeed(ColorToGray(clWindow) < 128, true));
  saveRolled;
end;

procedure showMiscLook;
begin
  if window = nil then window := TMiscLookForm.Create(Application);
  window.Show;
  window.BringToFront;
end;

{ TMiscLookForm }

procedure TMiscLookForm.FormCreate(Sender: TObject);
begin
  Caption := lisMiscLookTitle;
  LineMessages.Caption := lisMiscLookMessagesColors;
  LabelBackground.Caption := lisMiscLookBackground;
  LabelText.Caption := lisMiscLookText;
  LabelRunning.Caption := lisMiscLookRunning;
  LabelSuccess.Caption := lisMiscLookSuccess;
  LabelFailed.Caption := lisMiscLookFailed;
  LabelAutoHeader.Caption := lisMiscLookAutoHeader;
  LabelHint.Caption := lisMiscLookHint;
  LabelNote.Caption := lisMiscLookNote;
  LabelWarning.Caption := lisMiscLookWarning;
  LabelError.Caption := lisMiscLookError;
  LabelFatal.Caption := lisMiscLookFatal;
  CheckBoxAutoMatch.Caption := lisMiscLookAutoMatch;
  ButtonRandomDark.Caption := lisSchemeCreatorRandomDark;
  ButtonRandomLight.Caption := lisSchemeCreatorRandomLight;
  ButtonPrevious.Caption := lisSchemeCreatorPrevious;
  ButtonNext.Caption := lisSchemeCreatorNext;
  LineText.Caption := lisMiscLookMessagesText;
  LabelFont.Caption := lisMiscLookFont;
  LabelSize.Caption := lisMiscLookSize;
  LabelSpacing.Caption := lisMiscLookLetterSpacing;
  LabelPaddingTop.Caption := lisMiscLookPaddingTop;
  LabelPaddingBottom.Caption := lisMiscLookPaddingBottom;
  LabelPaddingLeft.Caption := lisMiscLookPaddingLeft;
  LabelPaddingRight.Caption := lisMiscLookPaddingRight;
  LineIcons.Caption := lisMiscLookIcons;
  CheckBoxIconFit.Caption := lisMiscLookIconFit;
  LabelStrength.Caption := lisMiscLookIconStrength;
  LabelMinContrast.Caption := lisMiscLookIconMinContrast;
  LabelMaxLightness.Caption := lisMiscLookIconMaxLightness;
  LabelDisabledContrast.Caption := lisMiscLookIconDisabledContrast;
  LabelDisabledSaturation.Caption := lisMiscLookIconDisabledSaturation;
  ButtonIconDefaults.Caption := lisMiscLookIconDefaults;
  ButtonSave.Caption := lisSave;
  ButtonClose.Caption := lisClose;
  Randomize;
  fHistPos := -1;
  updateHistoryButtons;
  CheckBoxAutoMatch.Checked := loadAutoMatch;
  updateRollButtons;
  ComboFont.Items.Assign(Screen.Fonts);
  showSeed(currentSeed);
  showTextStyle(EnvironmentGuiOpts.MsgViewTextStyle);
  // the icon fit lives in the themes package; without it the section only shows the defaults
  var fitting := Assigned(OnIconFitCurrent) and Assigned(OnIconFitPreview) and Assigned(OnIconFitStore);
  CheckBoxIconFit.Enabled := fitting;
  TrackStrength.Enabled := fitting;
  TrackMinContrast.Enabled := fitting;
  TrackMaxLightness.Enabled := fitting;
  TrackDisabledContrast.Enabled := fitting;
  TrackDisabledSaturation.Enabled := fitting;
  ButtonIconDefaults.Enabled := fitting;
  showIconFit(if fitting then OnIconFitCurrent() else DefaultIconFit);
end;

procedure TMiscLookForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if fPreviewed then restorePreview;
  if fIconsPreviewed then OnIconFitPreview(OnIconFitCurrent());
  window := nil;
  CloseAction := caFree;
end;

function TMiscLookForm.seed: TMiscSeed;
begin
  result.background := ButtonBackground.ButtonColor;
  result.text := ButtonText.ButtonColor;
  result.running := ButtonRunning.ButtonColor;
  result.success := ButtonSuccess.ButtonColor;
  result.failed := ButtonFailed.ButtonColor;
  result.autoHeader := ButtonAutoHeader.ButtonColor;
  result.hint := ButtonHint.ButtonColor;
  result.note := ButtonNote.ButtonColor;
  result.warning := ButtonWarning.ButtonColor;
  result.error := ButtonError.ButtonColor;
  result.fatal := ButtonFatal.ButtonColor;
end;

procedure TMiscLookForm.showSeed(const value: TMiscSeed);
begin
  fLoading := true;
  defer fLoading := false;
  ButtonBackground.ButtonColor := value.background;
  ButtonText.ButtonColor := value.text;
  ButtonRunning.ButtonColor := value.running;
  ButtonSuccess.ButtonColor := value.success;
  ButtonFailed.ButtonColor := value.failed;
  ButtonAutoHeader.ButtonColor := value.autoHeader;
  ButtonHint.ButtonColor := value.hint;
  ButtonNote.ButtonColor := value.note;
  ButtonWarning.ButtonColor := value.warning;
  ButtonError.ButtonColor := value.error;
  ButtonFatal.ButtonColor := value.fatal;
end;

// the font name only once it is one the screen has, so a half typed name is not applied
function TMiscLookForm.textStyle: TMsgWndTextStyle;
begin
  var i := ComboFont.Items.IndexOf(ComboFont.Text);
  result.FontName := if i >= 0 then ComboFont.Items[i] else '';
  result.FontSize := SpinSize.Value;
  result.CharSpacing := SpinSpacing.Value;
  result.PaddingTop := SpinPaddingTop.Value;
  result.PaddingBottom := SpinPaddingBottom.Value;
  result.PaddingLeft := SpinPaddingLeft.Value;
  result.PaddingRight := SpinPaddingRight.Value;
end;

procedure TMiscLookForm.showTextStyle(const value: TMsgWndTextStyle);
begin
  fLoading := true;
  defer fLoading := false;
  ComboFont.Text := value.FontName;
  SpinSize.Value := value.FontSize;
  SpinSpacing.Value := value.CharSpacing;
  SpinPaddingTop.Value := value.PaddingTop;
  SpinPaddingBottom.Value := value.PaddingBottom;
  SpinPaddingLeft.Value := value.PaddingLeft;
  SpinPaddingRight.Value := value.PaddingRight;
end;

procedure TMiscLookForm.ColorChanged(Sender: TObject);
begin
  if not fLoading then preview;
end;

procedure TMiscLookForm.TextStyleChanged(Sender: TObject);
begin
  if not fLoading then previewText;
end;

procedure TMiscLookForm.LinePaint(Sender: TObject);
begin
  var box := Sender as TPaintBox;
  // the split between the columns is the only line taller than wide
  if box.Width < box.Height then begin
    box.Canvas.Brush.Color := mix(box.Color, clWindowText, 35);
    box.Canvas.FillRect(0, 0, box.Width, box.Height);
  end else paintGroupLine(box);
end;

procedure TMiscLookForm.preview;
begin
  previewSeed(seed);
  fPreviewed := true;
end;

procedure TMiscLookForm.previewText;
begin
  previewTextStyle(textStyle);
  fPreviewed := true;
end;

procedure TMiscLookForm.pushHistory(const value: TMiscSeed);
begin
  // a roll after walking back drops the entries ahead, like an undo stack
  SetLength(fHistory, fHistPos+1);
  if length(fHistory) = HISTORY_SIZE then Delete(fHistory, 0, 1);
  SetLength(fHistory, length(fHistory)+1);
  fHistory[high(fHistory)] := value;
  fHistPos := high(fHistory);
  updateHistoryButtons;
end;

procedure TMiscLookForm.walkHistory(step: integer);
begin
  fHistPos += step;
  showSeed(fHistory[fHistPos]);
  updateHistoryButtons;
  preview;
end;

procedure TMiscLookForm.updateHistoryButtons;
begin
  ButtonPrevious.Enabled := fHistPos > 0;
  ButtonNext.Enabled := fHistPos < high(fHistory);
end;

// a matched roll can only go the way the theme goes, so the other button waits
procedure TMiscLookForm.updateRollButtons;
begin
  var darkTheme := ColorToGray(clWindow) < 128;
  ButtonRandomDark.Enabled := (not CheckBoxAutoMatch.Checked) or darkTheme;
  ButtonRandomLight.Enabled := (not CheckBoxAutoMatch.Checked) or (not darkTheme);
end;

procedure TMiscLookForm.CheckBoxAutoMatchChange(Sender: TObject);
begin
  updateRollButtons;
end;

procedure TMiscLookForm.ButtonRandomClick(Sender: TObject);
begin
  var value := rollSeed(Sender = ButtonRandomDark, CheckBoxAutoMatch.Checked);
  showSeed(value);
  pushHistory(value);
  preview;
end;

procedure TMiscLookForm.ButtonPreviousClick(Sender: TObject);
begin
  walkHistory(-1);
end;

procedure TMiscLookForm.ButtonNextClick(Sender: TObject);
begin
  walkHistory(1);
end;

procedure TMiscLookForm.ButtonSaveClick(Sender: TObject);
begin
  // the text style rides along with the colors: storeSeed saves the environment
  EnvironmentGuiOpts.MsgViewTextStyle := textStyle;
  storeSeed(seed);
  saveAutoMatch(CheckBoxAutoMatch.Checked);
  saveRolled;
  fPreviewed := false;
  if Assigned(OnIconFitStore) then OnIconFitStore(iconFit);
  fIconsPreviewed := false;
  Close;
end;

procedure TMiscLookForm.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

function TMiscLookForm.iconFit: TIconFit;
begin
  result.Enabled := CheckBoxIconFit.Checked;
  result.Strength := TrackStrength.Position;
  result.MinContrast := TrackMinContrast.Position;
  result.MaxLightness := TrackMaxLightness.Position;
  result.DisabledContrast := TrackDisabledContrast.Position;
  result.DisabledSaturation := TrackDisabledSaturation.Position;
end;

procedure TMiscLookForm.showIconFit(const value: TIconFit);
begin
  fLoading := true;
  defer fLoading := false;
  CheckBoxIconFit.Checked := value.Enabled;
  TrackStrength.Position := value.Strength;
  TrackMinContrast.Position := value.MinContrast;
  TrackMaxLightness.Position := value.MaxLightness;
  TrackDisabledContrast.Position := value.DisabledContrast;
  TrackDisabledSaturation.Position := value.DisabledSaturation;
  updateIconLabels;
end;

procedure TMiscLookForm.updateIconLabels;
begin
  ValueStrength.Caption := Format('%d%%', [TrackStrength.Position]);
  ValueMinContrast.Caption := Format('%d%%', [TrackMinContrast.Position]);
  ValueMaxLightness.Caption := Format('%d%%', [TrackMaxLightness.Position]);
  ValueDisabledContrast.Caption := Format('%d%%', [TrackDisabledContrast.Position]);
  ValueDisabledSaturation.Caption := Format('%d%%', [TrackDisabledSaturation.Position]);
end;

// onto every icon on screen, the stored fit left as it is
procedure TMiscLookForm.previewIcons;
begin
  if not Assigned(OnIconFitPreview) then exit;
  OnIconFitPreview(iconFit);
  fIconsPreviewed := true;
end;

procedure TMiscLookForm.IconFitChanged(Sender: TObject);
begin
  updateIconLabels;
  if not fLoading then previewIcons;
end;

procedure TMiscLookForm.ButtonIconDefaultsClick(Sender: TObject);
begin
  showIconFit(DefaultIconFit);
  previewIcons;
end;

end.
