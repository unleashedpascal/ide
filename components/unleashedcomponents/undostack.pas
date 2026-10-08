{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit UndoStack;

{$mode unleashed}

interface

uses
  Classes, SysUtils;

type
  TUndoProc = procedure of object;
  // applies an entry pushed with data: undo true takes it back
  TUndoApplyEvent = procedure(Sender: TObject; const caption, data: string; undo: boolean) of object;

  { TUndoStack }

  // a stack of reversible actions. An entry carries either two methods,
  // one to undo and one to redo, or a piece of data that OnApply knows
  // how to turn both ways. A group folds several entries into one
  TUndoStack = class(TComponent)
  private
    type
      TEntry = record
        caption, data: string;
        undo, redo: TUndoProc;
        groupId: integer; // 0 outside a group
      end;
    var
      FEntries: array of TEntry;
      FCount, FLimit: integer; // FCount entries done; the rest are redo
      FGroup, FNextGroup: integer;
      FGroupCaption: string;
      FSavedAt: integer; // FCount when MarkSaved ran, -1 never
      FApplying: boolean;
      FOnChange: TNotifyEvent;
      FOnApply: TUndoApplyEvent;
    procedure setLimit(value: integer);
    procedure apply(const entry: TEntry; undo: boolean);
    procedure changed;
    function groupEnd(index: integer; forward: boolean): integer;
  public
    constructor Create(AOwner: TComponent); override;
    // an entry with the methods that take it back and do it again
    procedure Push(const caption: string; undo, redo: TUndoProc); overload;
    // an entry with data for OnApply
    procedure Push(const caption, data: string); overload;
    // the entries pushed until EndGroup undo and redo together
    procedure BeginGroup(const caption: string);
    procedure EndGroup;
    function Undo: boolean;
    function Redo: boolean;
    procedure Clear;
    // the state now is the saved one
    procedure MarkSaved;
    function CanUndo: boolean;
    function CanRedo: boolean;
    function UndoCaption: string;
    function RedoCaption: string;
    // the state differs from the saved one
    function Modified: boolean;
    // an undo or redo runs right now
    property Applying: boolean read FApplying;
    property UndoCount: integer read FCount;
    function RedoCount: integer;
  published
    // entries kept; the oldest ones fall off. 0 keeps all
    property Limit: integer read FLimit write setLimit default 100;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnApply: TUndoApplyEvent read FOnApply write FOnApply;
  end;

implementation

uses
  Math;

constructor TUndoStack.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLimit := 100;
  FSavedAt := 0;
end;

procedure TUndoStack.changed;
begin
  if Assigned(FOnChange) then FOnChange(self);
end;

// -- pushing ----------------------

procedure TUndoStack.Push(const caption: string; undo, redo: TUndoProc);
begin
  if FApplying then exit;
  // a new entry drops the redo entries
  SetLength(FEntries, FCount+1);
  FEntries[FCount].caption := if (FGroup <> 0) and (FGroupCaption <> '') then FGroupCaption else caption;
  FEntries[FCount].data := '';
  FEntries[FCount].undo := undo;
  FEntries[FCount].redo := redo;
  FEntries[FCount].groupId := FGroup;
  inc(FCount);
  if FSavedAt >= FCount then FSavedAt := -1;
  if (FLimit > 0) and (FCount > FLimit) then begin
    // the oldest entry goes; a saved mark on it is lost too
    var drop := FCount-FLimit;
    for var i := 0 to FCount-drop-1 do FEntries[i] := FEntries[i+drop];
    SetLength(FEntries, FCount-drop);
    FCount -= drop;
    if FSavedAt >= 0 then FSavedAt := if FSavedAt >= drop then FSavedAt-drop else -1;
  end;
  changed;
end;

procedure TUndoStack.Push(const caption, data: string);
begin
  Push(caption, nil, nil);
  if FCount > 0 then FEntries[FCount-1].data := data;
end;

procedure TUndoStack.BeginGroup(const caption: string);
begin
  if FGroup <> 0 then exit;
  inc(FNextGroup);
  FGroup := FNextGroup;
  FGroupCaption := caption;
end;

procedure TUndoStack.EndGroup;
begin
  FGroup := 0;
  FGroupCaption := '';
end;

// -- moving ----------------------

procedure TUndoStack.apply(const entry: TEntry; undo: boolean);
begin
  if undo then begin
    if Assigned(entry.undo) then entry.undo
    else if Assigned(FOnApply) then FOnApply(self, entry.caption, entry.data, true);
  end else begin
    if Assigned(entry.redo) then entry.redo
    else if Assigned(FOnApply) then FOnApply(self, entry.caption, entry.data, false);
  end;
end;

// the index past the entries of the same group as `index`, in the direction
function TUndoStack.groupEnd(index: integer; forward: boolean): integer;
begin
  result := index;
  var id := FEntries[index].groupId;
  if id = 0 then exit(if forward then index+1 else index-1);
  if forward then while (result < length(FEntries)) and (FEntries[result].groupId = id) do inc(result)
  else while (result >= 0) and (FEntries[result].groupId = id) do dec(result);
end;

function TUndoStack.Undo: boolean;
begin
  result := CanUndo;
  if not result then exit;
  FApplying := true;
  try
    var stop := groupEnd(FCount-1, false);
    while FCount-1 > stop do begin
      dec(FCount);
      apply(FEntries[FCount], true);
    end;
  finally
    FApplying := false;
  end;
  changed;
end;

function TUndoStack.Redo: boolean;
begin
  result := CanRedo;
  if not result then exit;
  FApplying := true;
  try
    var stop := groupEnd(FCount, true);
    while FCount < stop do begin
      apply(FEntries[FCount], false);
      inc(FCount);
    end;
  finally
    FApplying := false;
  end;
  changed;
end;

procedure TUndoStack.Clear;
begin
  SetLength(FEntries, 0);
  FCount := 0;
  FSavedAt := 0;
  FGroup := 0;
  changed;
end;

procedure TUndoStack.MarkSaved;
begin
  FSavedAt := FCount;
  changed;
end;

// -- state ----------------------

function TUndoStack.CanUndo: boolean;
begin
  result := FCount > 0;
end;

function TUndoStack.CanRedo: boolean;
begin
  result := FCount < length(FEntries);
end;

function TUndoStack.UndoCaption: string;
begin
  result := if CanUndo then FEntries[FCount-1].caption else '';
end;

function TUndoStack.RedoCaption: string;
begin
  result := if CanRedo then FEntries[FCount].caption else '';
end;

function TUndoStack.Modified: boolean;
begin
  result := FSavedAt <> FCount;
end;

function TUndoStack.RedoCount: integer;
begin
  result := length(FEntries)-FCount;
end;

procedure TUndoStack.setLimit(value: integer);
begin
  FLimit := Max(value, 0);
end;

end.
