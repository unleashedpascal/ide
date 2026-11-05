{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PageViewEditor;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Controls, Menus, ComponentEditors, PropEdits, PageView;

type

  { TPageViewEditor }

  // the designer menu of a TPageView: a page comes or goes, the next or the
  // previous one comes up and gets selected
  TPageViewEditor = class(TComponentEditor)
  protected
    function view: TPageView; virtual;
  public
    procedure ExecuteVerb(Index: Integer); override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure PrepareItem(Index: Integer; const AnItem: TMenuItem); override;
  end;

  { TPageSheetEditor }

  // the same menu on a page, for its view
  TPageSheetEditor = class(TPageViewEditor)
  protected
    function view: TPageView; override;
  end;

implementation

function TPageViewEditor.view: TPageView;
begin
  result := TPageView(GetComponent);
end;

function TPageSheetEditor.view: TPageView;
begin
  var parent := TControl(GetComponent).Parent;
  result := if parent is TPageView then TPageView(parent) else nil;
end;

function TPageViewEditor.GetVerbCount: Integer;
begin
  result := 4;
end;

function TPageViewEditor.GetVerb(Index: Integer): string;
begin
  result := match Index of
    0: 'Add Page';
    1: 'Delete Page';
    2: 'Next Page';
  else
    'Previous Page'
  end;
end;

procedure TPageViewEditor.PrepareItem(Index: Integer; const AnItem: TMenuItem);
begin
  inherited PrepareItem(Index, AnItem);
  if Index > 0 then AnItem.Enabled := (view <> nil) and (view.PageCount > 0);
end;

procedure TPageViewEditor.ExecuteVerb(Index: Integer);
begin
  var v := view;
  if v = nil then exit;
  var hook: TPropertyEditorHook := nil;
  if not GetHook(hook) then exit;
  match Index of
    0: begin
      var page := TPageSheet.Create(v.Owner);
      page.Name := GetDesigner.CreateUniqueComponentName(page.ClassName);
      page.Parent := v;
      v.PageIndex := v.PageCount-1;
      hook.PersistentAdded(page, true);
    end;
    1: begin
      // the page goes with its children; on a page this editor goes too
      var page: TPersistent := v.ActivePage;
      hook.DeletePersistent(page);
      exit;
    end;
    2: v.NextPage;
  else
    v.PreviousPage;
  end;
  if (Index >= 2) and (v.ActivePage <> nil) then GetDesigner.SelectOnlyThisComponent(v.ActivePage);
  Modified;
end;

end.
