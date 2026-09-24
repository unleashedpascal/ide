{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SchemeIdeColors;

{$mode unleashed}

interface

uses
  Graphics, Laz2_XMLCfg, ObjectInspector;

// A scheme file can carry IDE colors the syntax attributes do not cover: the divider lines of the
// editor and the object inspector. They sit in a subtree of their own, which the scheme loader skips:
// Lazarus/ColorSchemes/IdeColors/Scheme<name>/ObjectInspector/References, Value
// Lazarus/ColorSchemes/IdeColors/Scheme<name>/Dividers/<type>/MaxDepth, Color
// <type> is the divider name of the editor options ('Sect', 'Uses', 'GStruct', 'Proc', ...).

// the mapping the scheme loader applies to stored names
function validXmlName(const s: string): string;
procedure writeSchemeOiColors(cfg: TRttiXMLConfig; const name: string; reference, value: TColor);
// depth 0 draws nothing
procedure writeSchemeDivider(cfg: TRttiXMLConfig; const name, divider: string; depth: integer; color: TColor);
// pushes the IDE colors stored for the scheme onto the open editors and the object inspector
procedure previewSchemeIdeColors(cfg: TRttiXMLConfig; const name: string);
// makes the IDE colors of a registered scheme the current settings, unsaved; false when it has none
function applySchemeIdeColors(const name: string): boolean;
// puts the colors into the object inspector options and onto the inspector
procedure pushOiColors(reference, value: TColor);
// the inspector shows the stored colors again after a preview
procedure restorePreviewOiColors;
// call right after the options took their colors from the inspector: a previewed pair goes back to the stored one
procedure keepStoredOiColors(options: TOIOptions);

implementation

uses
  EditorSyntaxHighlighterDef, EditorOptions, EnvGuiOptions, MainIntf;

type
  // reaches the protected XML access of a registered scheme
  TColorSchemeAccess = class(TColorScheme);

var
  // a preview puts its inspector colors on the inspector only; the options keep the stored ones
  oiPreview: record
    active: boolean;
    reference, value: TColor; // shown on the inspector
    storedReference, storedValue: TColor;
  end;

function validXmlName(const s: string): string;
begin
  result := s;
  for var i := 1 to length(result) do if result[i] not in ['a'..'z', 'A'..'Z', '_', '0'..'9'] then result[i] := '_';
end;

function schemePath(const name: string): string;
begin
  result := 'Lazarus/ColorSchemes/IdeColors/Scheme'+validXmlName(name)+'/';
end;

procedure writeSchemeOiColors(cfg: TRttiXMLConfig; const name: string; reference, value: TColor);
begin
  cfg.SetValue(schemePath(name)+'ObjectInspector/References', longint(reference));
  cfg.SetValue(schemePath(name)+'ObjectInspector/Value', longint(value));
end;

procedure writeSchemeDivider(cfg: TRttiXMLConfig; const name, divider: string; depth: integer; color: TColor);
begin
  var path := schemePath(name)+'Dividers/'+divider+'/';
  cfg.SetValue(path+'MaxDepth', depth);
  cfg.SetValue(path+'Color', longint(color));
end;

// applies the divider types stored under path to the highlighter; true when the scheme carries any
function pushDividers(cfg: TRttiXMLConfig; const path: string; syn: TSrcIDEHighlighter; const info: TEditorOptionsDividerRecord): boolean;
begin
  result := false;
  for var i := 0 to info.Count-1 do begin
    var divider := path+'Dividers/'+info.Info[i].Xml+'/';
    var color := TColor(cfg.GetValue(divider+'Color', longint(clNone)));
    if color = clNone then continue;
    var conf := syn.DividerDrawConfig[i];
    conf.MaxDrawDepth := cfg.GetValue(divider+'MaxDepth', conf.MaxDrawDepth);
    conf.TopColor := color;
    conf.NestColor := color;
    result := true;
  end;
end;

procedure pushOiColors(reference, value: TColor);
begin
  var options := EnvironmentGuiOpts.ObjectInspectorOptions;
  options.ReferencesColor := reference;
  options.ValueColor := value;
  if ObjectInspector1 <> nil then options.AssignTo(ObjectInspector1);
end;

// the colors on the inspector, the options left as they are
procedure previewOiColors(reference, value: TColor);
begin
  var options := EnvironmentGuiOpts.ObjectInspectorOptions;
  oiPreview.active := true;
  oiPreview.reference := reference;
  oiPreview.value := value;
  oiPreview.storedReference := options.ReferencesColor;
  oiPreview.storedValue := options.ValueColor;
  pushOiColors(reference, value);
  options.ReferencesColor := oiPreview.storedReference;
  options.ValueColor := oiPreview.storedValue;
end;

procedure restorePreviewOiColors;
begin
  if not oiPreview.active then exit;
  oiPreview.active := false;
  var options := EnvironmentGuiOpts.ObjectInspectorOptions;
  pushOiColors(options.ReferencesColor, options.ValueColor);
end;

procedure keepStoredOiColors(options: TOIOptions);
begin
  if not oiPreview.active then exit;
  // other colors on the inspector mean the options were put back onto it since the preview
  if (options.ReferencesColor <> oiPreview.reference) or (options.ValueColor <> oiPreview.value) then begin
    oiPreview.active := false;
    exit;
  end;
  options.ReferencesColor := oiPreview.storedReference;
  options.ValueColor := oiPreview.storedValue;
end;

// the editors share one highlighter per language, so the dividers land on all of them at once;
// store writes the divider settings into the editor options as well
function pushIdeColors(cfg: TRttiXMLConfig; const path: string; store: boolean): boolean;
begin
  result := false;
  for var h := IdeHighlighterStartId to HighlighterList.Count-1 do begin
    var syn := HighlighterList[h].SynInstance;
    var info := EditorOptionsDividerDefaults[HighlighterList[h].TheType];
    if (syn = nil) or (info.Count = 0) or not pushDividers(cfg, path, syn, info) then continue;
    if store then EditorOpts.WriteHighlighterDivDrawSettings(syn);
    result := true;
  end;
  var reference := TColor(cfg.GetValue(path+'ObjectInspector/References', longint(clNone)));
  var value := TColor(cfg.GetValue(path+'ObjectInspector/Value', longint(clNone)));
  if (reference = clNone) or (value = clNone) then exit;
  if store then begin
    oiPreview.active := false;
    pushOiColors(reference, value);
  end else previewOiColors(reference, value);
  result := true;
end;

procedure previewSchemeIdeColors(cfg: TRttiXMLConfig; const name: string);
begin
  pushIdeColors(cfg, schemePath(name), false);
end;

function applySchemeIdeColors(const name: string): boolean;
begin
  result := false;
  var scheme := ColorSchemeFactory.ColorSchemeGroup[name];
  if scheme = nil then exit;
  var cfg := TColorSchemeAccess(scheme).GetXmlConf;
  if cfg = nil then exit;
  defer TColorSchemeAccess(scheme).ReleaseXmlConf;
  result := pushIdeColors(cfg, schemePath(name), true);
end;

end.
