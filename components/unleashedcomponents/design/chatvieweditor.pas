{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ChatViewEditor;

{$mode unleashed}

interface

uses
  Classes, PropEdits, ChatView;

type

  { TChatAutoColorsEditor }

  // Colors.Auto of a chat view: a group chat keeps it on, so the inspector
  // shows it read-only there
  TChatAutoColorsEditor = class(TBoolPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
  end;

implementation

function TChatAutoColorsEditor.GetAttributes: TPropertyAttributes;
begin
  result := inherited GetAttributes;
  var colors := GetComponent(0);
  if (colors is TChatColors) and (TChatColors(colors).Chat <> nil) and (TChatColors(colors).Chat.Mode = cmGroup) then result += [paReadOnly];
end;

end.
