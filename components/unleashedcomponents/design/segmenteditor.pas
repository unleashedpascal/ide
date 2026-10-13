{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SegmentEditor;

{$mode unleashed}

interface

uses
  Classes, SysUtils, ComponentEditors, PropEdits, SegmentedControl;

type

  { TSegmentedControlEditor }

  // the designer menu of a TSegmentedControl: segments come and go without
  // the collection editor, which stays a click away
  TSegmentedControlEditor = class(TComponentEditor)
  private
    function control: TSegmentedControl;
  public
    procedure Edit; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
  end;

implementation

function TSegmentedControlEditor.control: TSegmentedControl;
begin
  result := TSegmentedControl(GetComponent);
end;

procedure TSegmentedControlEditor.Edit;
begin
  TCollectionPropertyEditor.ShowCollectionEditor(control.Items, control, 'Items');
end;

function TSegmentedControlEditor.GetVerbCount: Integer;
begin
  result := 4;
end;

function TSegmentedControlEditor.GetVerb(Index: Integer): string;
begin
  result := match Index of
    0: 'Add Segment';
    1: 'Delete Last Segment';
    2: 'Select Next Segment';
  else
    'Edit Segments...'
  end;
end;

procedure TSegmentedControlEditor.ExecuteVerb(Index: Integer);
begin
  var c := control;
  match Index of
    0: begin
      var item := c.Items.Add;
      item.Caption := 'Segment '+IntToStr(c.Items.Count);
      if c.ItemIndex < 0 then c.ItemIndex := 0;
    end;
    1: if c.Items.Count > 0 then c.Items.Delete(c.Items.Count-1);
    2: if c.Items.Count > 0 then c.ItemIndex := (c.ItemIndex+1) mod c.Items.Count;
  else
    begin
      Edit;
      exit;
    end;
  end;
  Modified;
end;

end.
