{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Gtk3Startup;

{$mode unleashed}

interface

// classic scroll bars like on the other widget sets: an overlay bar hides when
// idle and leaves the band kept free for it as an empty margin. Call before
// Application.Initialize, which is where gtk reads the setting
procedure useClassicScrollBars;

implementation

uses
  SysUtils, Gtk3Int;

function setenv(name, value: PChar; overwrite: Integer): Integer; cdecl; external 'c';

procedure useClassicScrollBars;
begin
  // an explicit setting in the environment wins
  if GetEnvironmentVariable('GTK_OVERLAY_SCROLLING') <> '' then exit;
  // gtk reads the libc environment; the widget set read its own copy of the
  // environment when it was created, so its flag is set directly
  setenv('GTK_OVERLAY_SCROLLING', '0', 0);
  Gtk3WidgetSet.OverlayScrolling := False;
end;

end.
