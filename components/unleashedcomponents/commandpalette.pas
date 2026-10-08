{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit CommandPalette;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, StdCtrls, ActnList, Menus, LCLType, ControlPaint, PopupWindow;

type
  TCommandPalette = class;

  // a command the palette offers; the action or the handler runs it
  TCommandEvent = procedure(Sender: TObject; const name: string; tag: PtrInt) of object;
  TCollectCommandsEvent = procedure(Sender: TObject; names: TStrings) of object;

  { TCommandPalette }

  // a popup with a search box over the actions of an action list and the
  // commands added by hand: the shortcut opens it, typing filters, Enter
  // runs the command under the bar
  TCommandPalette = class(TComponent)
  private
    FActionList: TCustomActionList;
    FShortCut: TShortCut;
    FWidth, FMaxVisible: integer;
    FPlaceholder: string;
    FShowShortcuts, FShowCategories: boolean;
    FCommands: TStringList; // name = tag
    FForm: TDropPopup;
    FEdit: TEdit;
    FList: TListBox;
    FOnExecute: TCommandEvent;
    FOnCollect: TCollectCommandsEvent;
    procedure setActionList(value: TCustomActionList);
    procedure keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure buildForm;
    procedure fill;
    procedure editChange(Sender: TObject);
    procedure editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure listClick(Sender: TObject);
    procedure listDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure formDismiss(Sender: TObject);
    procedure run;
    function matches(const name, typed: string): boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Show;
    procedure Hide;
    // a command without an action; OnExecute gets its name and tag
    procedure AddCommand(const name: string; tag: PtrInt = 0);
    procedure ClearCommands;
    function Visible: boolean;
  published
    property ActionList: TCustomActionList read FActionList write setActionList;
    // opens the palette from any window of the application
    property ShortCut: TShortCut read FShortCut write FShortCut default 0;
    property Width: integer read FWidth write FWidth default 480;
    property MaxVisible: integer read FMaxVisible write FMaxVisible default 10;
    property Placeholder: string read FPlaceholder write FPlaceholder;
    property ShowShortcuts: boolean read FShowShortcuts write FShowShortcuts default true;
    property ShowCategories: boolean read FShowCategories write FShowCategories default true;
    // a command picked; the actions run themselves before this
    property OnExecute: TCommandEvent read FOnExecute write FOnExecute;
    // more names to offer, collected every time the palette opens
    property OnCollect: TCollectCommandsEvent read FOnCollect write FOnCollect;
  end;

implementation

uses
  Math, LCLProc;

{ TCommandPalette }

constructor TCommandPalette.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FWidth := 480;
  FMaxVisible := 10;
  FPlaceholder := 'Type a command';
  FShowShortcuts := true;
  FShowCategories := true;
  FCommands := TStringList.Create;
  if not (csDesigning in ComponentState) then Application.AddOnKeyDownBeforeHandler(@keyBefore);
end;

destructor TCommandPalette.Destroy;
begin
  if not (csDesigning in ComponentState) then Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
  FCommands.Free;
  FForm.Free;
  inherited Destroy;
end;

procedure TCommandPalette.keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (FShortCut = 0) or (Key = 0) then exit;
  if KeyToShortCut(Key, Shift) <> FShortCut then exit;
  Key := 0;
  if Visible then Hide else Show;
end;

// -- the commands ----------------------

procedure TCommandPalette.AddCommand(const name: string; tag: PtrInt);
begin
  FCommands.Values[name] := IntToStr(tag);
end;

procedure TCommandPalette.ClearCommands;
begin
  FCommands.Clear;
end;

function TCommandPalette.matches(const name, typed: string): boolean;
begin
  if typed = '' then exit(true);
  var lowerName := LowerCase(name);
  // every typed word has to be somewhere in the name
  for var w in LowerCase(typed).Split([' '], TStringSplitOptions.ExcludeEmpty) do if Pos(w, lowerName) = 0 then exit(false);
  result := true;
end;

// the list holds what fits the typed text: actions as objects, plain
// commands with a nil object and their name
procedure TCommandPalette.fill;
begin
  var typed := Trim(FEdit.Text);
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    if FActionList <> nil then
      for var i := 0 to FActionList.ActionCount-1 do begin
        var action := FActionList.Actions[i];
        if not (action is TCustomAction) then continue;
        var custom := TCustomAction(action);
        if not custom.Visible or not custom.Enabled or (custom.Caption = '') then continue;
        var name := StripHotkey(custom.Caption);
        if matches(name+' '+custom.Category, typed) then FList.Items.AddObject(name, custom);
      end;
    for var i := 0 to FCommands.Count-1 do
      if matches(FCommands.Names[i], typed) then FList.Items.AddObject(FCommands.Names[i], nil);
    var extra := TStringList.Create;
    try
      if Assigned(FOnCollect) then FOnCollect(self, extra);
      for var i := 0 to extra.Count-1 do if matches(extra[i], typed) then FList.Items.AddObject(extra[i], nil);
    finally
      extra.Free;
    end;
  finally
    FList.Items.EndUpdate;
  end;
  if FList.Items.Count > 0 then FList.ItemIndex := 0;
  var rows := Min(Max(FList.Items.Count, 1), Max(FMaxVisible, 1));
  FForm.ClientHeight := FEdit.Top+FEdit.Height+ControlPaint.scaled(FForm, 6)+rows*FList.ItemHeight+ControlPaint.scaled(FForm, 8);
end;

// -- the window ----------------------

procedure TCommandPalette.buildForm;
begin
  if FForm <> nil then exit;
  FForm := TDropPopup.Create(nil);
  FForm.Color := clWindow;
  FForm.OnDismiss := @formDismiss;
  FEdit := TEdit.Create(FForm);
  FEdit.Parent := FForm;
  FEdit.TextHint := FPlaceholder;
  FEdit.OnChange := @editChange;
  FEdit.OnKeyDown := @editKeyDown;
  FList := TListBox.Create(FForm);
  FList.Parent := FForm;
  FList.BorderStyle := bsNone;
  FList.Style := lbOwnerDrawFixed;
  FList.OnClick := @listClick;
  FList.OnDrawItem := @listDraw;
  FList.TabStop := false;
end;

procedure TCommandPalette.Show;
begin
  if csDesigning in ComponentState then exit;
  buildForm;
  var pad := ControlPaint.scaled(FForm, 8);
  FForm.ClientWidth := ControlPaint.scaled(FForm, FWidth);
  FEdit.SetBounds(pad, pad, FForm.ClientWidth-pad*2, FEdit.Height);
  FList.ItemHeight := FForm.Canvas.TextHeight('Hg')+ControlPaint.scaled(FForm, 10);
  FList.SetBounds(pad, FEdit.Top+FEdit.Height+ControlPaint.scaled(FForm, 6), FForm.ClientWidth-pad*2, 0);
  FEdit.Text := '';
  fill;
  FList.SetBounds(FList.Left, FList.Top, FList.Width, FForm.ClientHeight-FList.Top-pad);
  // over the active window, a fifth of the way down
  var host := Screen.ActiveForm;
  if host = nil then host := Application.MainForm;
  var area := if host <> nil then host.BoundsRect else Screen.PrimaryMonitor.WorkareaRect;
  var left := (area.Left+area.Right-FForm.Width) div 2;
  var top := area.Top+(area.Height-FForm.Height) div 5;
  FForm.ShowAt(nil, Rect(left, top, left+FForm.Width, top+FForm.Height));
  FEdit.SetFocus;
end;

procedure TCommandPalette.Hide;
begin
  if (FForm <> nil) and FForm.Visible then FForm.Close;
end;

function TCommandPalette.Visible: boolean;
begin
  result := (FForm <> nil) and FForm.Visible;
end;

procedure TCommandPalette.formDismiss(Sender: TObject);
begin
  Hide;
end;

procedure TCommandPalette.editChange(Sender: TObject);
begin
  fill;
  FList.SetBounds(FList.Left, FList.Top, FList.Width, FForm.ClientHeight-FList.Top-ControlPaint.scaled(FForm, 8));
end;

procedure TCommandPalette.editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  var n := FList.Items.Count;
  match Key of
    VK_DOWN: if n > 0 then FList.ItemIndex := (FList.ItemIndex+1) mod n;
    VK_UP: if n > 0 then FList.ItemIndex := (FList.ItemIndex+n-1) mod n;
    VK_NEXT: if n > 0 then FList.ItemIndex := Min(FList.ItemIndex+Max(FMaxVisible, 1), n-1);
    VK_PRIOR: if n > 0 then FList.ItemIndex := Max(FList.ItemIndex-Max(FMaxVisible, 1), 0);
    VK_RETURN: run;
    VK_ESCAPE: Hide;
  else
    exit;
  end;
  Key := 0;
end;

procedure TCommandPalette.listClick(Sender: TObject);
begin
  run;
end;

procedure TCommandPalette.run;
begin
  var i := FList.ItemIndex;
  if i < 0 then exit;
  var name := FList.Items[i];
  var action := FList.Items.Objects[i];
  Hide;
  var tag: PtrInt := 0;
  if action is TCustomAction then begin
    tag := TCustomAction(action).Tag;
    TCustomAction(action).Execute;
  end else if FCommands.IndexOfName(name) >= 0 then tag := StrToIntDef(FCommands.Values[name], 0);
  if Assigned(FOnExecute) then FOnExecute(self, name, tag);
end;

procedure TCommandPalette.listDraw(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
  var canvas := FList.Canvas;
  var selected := odSelected in State;
  canvas.Brush.Style := bsSolid;
  canvas.Brush.Color := if selected then ColorToRGB(clHighlight) else ColorToRGB(clWindow);
  canvas.FillRect(ARect);
  canvas.Brush.Style := bsClear;
  applyTextQuality(canvas);
  var pad := ControlPaint.scaled(FForm, 8);
  var action := FList.Items.Objects[Index];
  var right := ARect.Right-pad;
  canvas.Font.Color := if selected then ColorToRGB(clHighlightText) else ColorToRGB(clGrayText);
  canvas.Font.Style := [];
  if FShowShortcuts and (action is TCustomAction) and (TCustomAction(action).ShortCut <> 0) then begin
    var keys := ShortCutToText(TCustomAction(action).ShortCut);
    canvas.TextOut(right-canvas.TextWidth(keys), ARect.Top+(ARect.Height-canvas.TextHeight(keys)) div 2, keys);
    right -= canvas.TextWidth(keys)+pad;
  end;
  var x := ARect.Left+pad;
  if FShowCategories and (action is TCustomAction) and (TCustomAction(action).Category <> '') then begin
    var cat := TCustomAction(action).Category+': ';
    canvas.TextOut(x, ARect.Top+(ARect.Height-canvas.TextHeight(cat)) div 2, cat);
    x += canvas.TextWidth(cat);
  end;
  canvas.Font.Color := if selected then ColorToRGB(clHighlightText) else ColorToRGB(clWindowText);
  var name := FList.Items[Index];
  canvas.TextRect(Rect(x, ARect.Top, right, ARect.Bottom), x, ARect.Top+(ARect.Height-canvas.TextHeight(name)) div 2, name);
  canvas.Brush.Style := bsSolid;
end;

procedure TCommandPalette.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FActionList) then FActionList := nil;
end;

procedure TCommandPalette.setActionList(value: TCustomActionList);
begin
  if FActionList = value then exit;
  if FActionList <> nil then FActionList.RemoveFreeNotification(self);
  FActionList := value;
  if FActionList <> nil then FActionList.FreeNotification(self);
end;

end.
