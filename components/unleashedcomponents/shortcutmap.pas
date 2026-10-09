{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ShortcutMap;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Controls, Forms, LCLType, LCLProc;

type
  TShortcutMap = class;
  TShortcutScope = (ssOwnerForm, ssApplication);
  TShortcutItem = class;
  TShortcutExecuteEvent = procedure(Sender: TObject; item: TShortcutItem) of object;
  // a key with no shortcut of its own; handled true swallows it
  TShortcutUnhandledEvent = procedure(Sender: TObject; shortcut: TShortCut; var handled: boolean) of object;

  { TShortcutItem }

  TShortcutItem = class(TCollectionItem)
  private
    FName, FCaption, FCategory: string;
    FShortcut, FSecondary: TShortCut;
    FEnabled: boolean;
    FTag: PtrInt;
    FOnExecute: TNotifyEvent;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // the shortcut as text, like Ctrl+S
    function ShortcutText: string;
    function Matches(shortcut: TShortCut): boolean;
  published
    // the key the item goes by in Find and Execute
    property Name: string read FName write FName;
    // the text for a menu or a help page
    property Caption: string read FCaption write FCaption;
    property Category: string read FCategory write FCategory;
    property Shortcut: TShortCut read FShortcut write FShortcut default 0;
    // a second key for the same thing
    property Secondary: TShortCut read FSecondary write FSecondary default 0;
    property Enabled: boolean read FEnabled write FEnabled default true;
    property Tag: PtrInt read FTag write FTag default 0;
    property OnExecute: TNotifyEvent read FOnExecute write FOnExecute;
  end;

  { TShortcutItems }

  TShortcutItems = class(TOwnedCollection)
  private
    function getItem(index: integer): TShortcutItem;
    procedure setItem(index: integer; value: TShortcutItem);
  public
    function Add: TShortcutItem;
    function ByName(const name: string): TShortcutItem;
    property Items[index: integer]: TShortcutItem read getItem write setItem; default;
  end;

  { TShortcutMap }

  // the keyboard shortcuts of a form or the application in one list: a
  // name, a caption and a key per item, a handler each or one for all.
  // The map sees the keys before the focused control, so a shortcut works
  // wherever the focus is. Save and Load keep the keys the user changed
  TShortcutMap = class(TComponent)
  private
    FItems: TShortcutItems;
    FEnabled, FHooked: boolean;
    FScope: TShortcutScope;
    FOnExecute: TShortcutExecuteEvent;
    FOnUnhandled: TShortcutUnhandledEvent;
    procedure setItems(value: TShortcutItems);
    procedure keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure hook(active: boolean);
    function ownerForm: TCustomForm;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Find(const name: string): TShortcutItem;
    // the item with that key, nil for none
    function FindShortcut(shortcut: TShortCut): TShortcutItem;
    // runs the item by name; false when there is none
    function Execute(const name: string): boolean;
    // runs the item for the key; false when none matches
    function Handle(shortcut: TShortCut): boolean;
    function Add(const name, caption: string; shortcut: TShortCut; handler: TNotifyEvent = nil): TShortcutItem;
    // the keys as name=shortcut lines, to keep in a settings file
    procedure SaveToStrings(lines: TStrings);
    procedure LoadFromStrings(lines: TStrings);
    // caption, tab, shortcut per line, grouped by category, for a help page
    procedure Describe(lines: TStrings);
    // the items whose keys collide, as pairs of names
    procedure FindConflicts(lines: TStrings);
  published
    property Items: TShortcutItems read FItems write setItems;
    property Enabled: boolean read FEnabled write FEnabled default true;
    // the form that owns the map, or every form of the application
    property Scope: TShortcutScope read FScope write FScope default ssOwnerForm;
    // every item, after its own handler
    property OnExecute: TShortcutExecuteEvent read FOnExecute write FOnExecute;
    property OnUnhandled: TShortcutUnhandledEvent read FOnUnhandled write FOnUnhandled;
  end;

implementation

{ TShortcutItem }

constructor TShortcutItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FEnabled := true;
end;

procedure TShortcutItem.Assign(Source: TPersistent);
begin
  if Source is TShortcutItem then begin
    FName := TShortcutItem(Source).FName;
    FCaption := TShortcutItem(Source).FCaption;
    FCategory := TShortcutItem(Source).FCategory;
    FShortcut := TShortcutItem(Source).FShortcut;
    FSecondary := TShortcutItem(Source).FSecondary;
    FEnabled := TShortcutItem(Source).FEnabled;
    FTag := TShortcutItem(Source).FTag;
    FOnExecute := TShortcutItem(Source).FOnExecute;
  end else inherited Assign(Source);
end;

function TShortcutItem.GetDisplayName: string;
begin
  result := FName;
  if result = '' then result := FCaption;
  if result = '' then result := inherited GetDisplayName
  else if FShortcut <> 0 then result += ' ('+ShortcutText+')';
end;

function TShortcutItem.ShortcutText: string;
begin
  result := ShortCutToText(FShortcut);
end;

function TShortcutItem.Matches(shortcut: TShortCut): boolean;
begin
  result := (shortcut <> 0) and ((shortcut = FShortcut) or (shortcut = FSecondary));
end;

{ TShortcutItems }

function TShortcutItems.getItem(index: integer): TShortcutItem;
begin
  result := TShortcutItem(inherited Items[index]);
end;

procedure TShortcutItems.setItem(index: integer; value: TShortcutItem);
begin
  inherited Items[index] := value;
end;

function TShortcutItems.Add: TShortcutItem;
begin
  result := TShortcutItem(inherited Add);
end;

function TShortcutItems.ByName(const name: string): TShortcutItem;
begin
  for var i := 0 to Count-1 do if SameText(Items[i].Name, name) then exit(Items[i]);
  result := nil;
end;

{ TShortcutMap }

constructor TShortcutMap.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TShortcutItems.Create(self, TShortcutItem);
  FEnabled := true;
  if not (csDesigning in ComponentState) then hook(true);
end;

destructor TShortcutMap.Destroy;
begin
  hook(false);
  FItems.Free;
  inherited Destroy;
end;

procedure TShortcutMap.Loaded;
begin
  inherited Loaded;
end;

procedure TShortcutMap.hook(active: boolean);
begin
  if active = FHooked then exit;
  FHooked := active;
  if active then Application.AddOnKeyDownBeforeHandler(@keyBefore)
  else Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
end;

function TShortcutMap.ownerForm: TCustomForm;
begin
  var o := Owner;
  while (o <> nil) and not (o is TCustomForm) do o := o.Owner;
  result := TCustomForm(o);
end;

procedure TShortcutMap.keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if not FEnabled or (Key = 0) or (Key in [VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN]) then exit;
  if FScope = ssOwnerForm then begin
    // only the keys of the form that owns the map, or of a control on it
    var form := ownerForm;
    if form = nil then exit;
    var active := Screen.ActiveCustomForm;
    if active <> form then exit;
  end;
  var shortcut := KeyToShortCut(Key, Shift);
  if Handle(shortcut) then begin
    Key := 0;
    exit;
  end;
  if Assigned(FOnUnhandled) then begin
    var handled := false;
    FOnUnhandled(self, shortcut, handled);
    if handled then Key := 0;
  end;
end;

function TShortcutMap.Find(const name: string): TShortcutItem;
begin
  result := FItems.ByName(name);
end;

function TShortcutMap.FindShortcut(shortcut: TShortCut): TShortcutItem;
begin
  for var i := 0 to FItems.Count-1 do if FItems[i].Enabled and FItems[i].Matches(shortcut) then exit(FItems[i]);
  result := nil;
end;

function TShortcutMap.Execute(const name: string): boolean;
begin
  var item := Find(name);
  result := (item <> nil) and item.Enabled;
  if not result then exit;
  if Assigned(item.OnExecute) then item.OnExecute(item);
  if Assigned(FOnExecute) then FOnExecute(self, item);
end;

function TShortcutMap.Handle(shortcut: TShortCut): boolean;
begin
  var item := FindShortcut(shortcut);
  result := item <> nil;
  if not result then exit;
  if Assigned(item.OnExecute) then item.OnExecute(item);
  if Assigned(FOnExecute) then FOnExecute(self, item);
end;

function TShortcutMap.Add(const name, caption: string; shortcut: TShortCut; handler: TNotifyEvent): TShortcutItem;
begin
  result := FItems.Add;
  result.Name := name;
  result.Caption := caption;
  result.Shortcut := shortcut;
  result.OnExecute := handler;
end;

procedure TShortcutMap.SaveToStrings(lines: TStrings);
begin
  for var i := 0 to FItems.Count-1 do begin
    var item := FItems[i];
    if item.Name = '' then continue;
    var text := ShortCutToTextRaw(item.Shortcut);
    if item.Secondary <> 0 then text += ','+ShortCutToTextRaw(item.Secondary);
    lines.Add(item.Name+'='+text);
  end;
end;

procedure TShortcutMap.LoadFromStrings(lines: TStrings);
begin
  for var i := 0 to lines.Count-1 do begin
    var item := Find(lines.Names[i]);
    if item = nil then continue;
    var text := lines.ValueFromIndex[i];
    var comma := Pos(',', text);
    if comma > 0 then begin
      item.Secondary := TextToShortCutRaw(Trim(Copy(text, comma+1, MaxInt)));
      text := Copy(text, 1, comma-1);
    end else item.Secondary := 0;
    item.Shortcut := TextToShortCutRaw(Trim(text));
  end;
end;

procedure TShortcutMap.Describe(lines: TStrings);
begin
  var categories := autofree TStringList.Create;
  categories.Sorted := true;
  categories.Duplicates := dupIgnore;
  for var i := 0 to FItems.Count-1 do categories.Add(FItems[i].Category);
  for var c := 0 to categories.Count-1 do begin
    if categories[c] <> '' then begin
      if lines.Count > 0 then lines.Add('');
      lines.Add(categories[c]);
    end;
    for var i := 0 to FItems.Count-1 do begin
      var item := FItems[i];
      if item.Category <> categories[c] then continue;
      var caption := if item.Caption <> '' then item.Caption else item.Name;
      var keys := item.ShortcutText;
      if item.Secondary <> 0 then keys += ', '+ShortCutToText(item.Secondary);
      lines.Add(caption+#9+keys);
    end;
  end;
end;

procedure TShortcutMap.FindConflicts(lines: TStrings);
begin
  for var i := 0 to FItems.Count-2 do
    for var k := i+1 to FItems.Count-1 do begin
      var a := FItems[i];
      var b := FItems[k];
      if not a.Enabled or not b.Enabled then continue;
      if (a.Shortcut <> 0) and (b.Matches(a.Shortcut)) or (a.Secondary <> 0) and (b.Matches(a.Secondary)) then
        lines.Add(a.Name+'='+b.Name);
    end;
end;

procedure TShortcutMap.setItems(value: TShortcutItems);
begin
  FItems.Assign(value);
end;

end.
