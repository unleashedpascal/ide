{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Debouncer;

{$mode unleashed}

interface

uses
  Classes, SysUtils, ExtCtrls;

type
  // dmTrailing: fires once the triggers stop for Delay; dmLeading: fires on
  // the first trigger and ignores the rest for Delay; dmThrottle: fires at
  // once and then at most once per Delay while the triggers keep coming
  TDebounceMode = (dmTrailing, dmLeading, dmThrottle);

  { TDebouncer }

  // turns a burst of triggers into a single OnFire: typing in a search box,
  // resize messages, a sensor sending too often. The last trigger's data
  // and tag are there for the handler
  TDebouncer = class(TComponent)
  private
    FTimer: TTimer;
    FDelay: integer;
    FMode: TDebounceMode;
    FEnabled: boolean;
    FLastData: string;
    FLastTag: PtrInt;
    FCount: integer; // triggers since the last fire
    FPending: boolean;
    FTrailingDue: boolean; // a throttled trigger waits for the next slot
    FOnFire: TNotifyEvent;
    procedure setDelay(value: integer);
    procedure timerFired(Sender: TObject);
    procedure fire;
  public
    constructor Create(AOwner: TComponent); override;
    // one more trigger; what it carries reaches OnFire through LastData and LastTag
    procedure Trigger(const data: string = ''; tag: PtrInt = 0);
    // drops what is pending without firing
    procedure Cancel;
    // fires what is pending right now
    procedure Flush;
    // a trigger is waiting for its moment
    property Pending: boolean read FPending;
    property LastData: string read FLastData;
    property LastTag: PtrInt read FLastTag;
    property Count: integer read FCount;
  published
    // milliseconds
    property Delay: integer read FDelay write setDelay default 300;
    property Mode: TDebounceMode read FMode write FMode default dmTrailing;
    // off, a trigger fires at once
    property Enabled: boolean read FEnabled write FEnabled default true;
    property OnFire: TNotifyEvent read FOnFire write FOnFire;
  end;

implementation

uses
  Math;

constructor TDebouncer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDelay := 300;
  FEnabled := true;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.OnTimer := @timerFired;
end;

procedure TDebouncer.Trigger(const data: string; tag: PtrInt);
begin
  FLastData := data;
  FLastTag := tag;
  inc(FCount);
  if not FEnabled or (FDelay <= 0) or (csDesigning in ComponentState) then begin
    fire;
    exit;
  end;
  match FMode of
    dmTrailing: begin
      // every trigger restarts the wait
      FPending := true;
      FTimer.Enabled := false;
      FTimer.Interval := FDelay;
      FTimer.Enabled := true;
    end;
    dmLeading: begin
      if FTimer.Enabled then exit;
      fire;
      FTimer.Interval := FDelay;
      FTimer.Enabled := true;
    end;
  else
    begin
      if FTimer.Enabled then begin
        FTrailingDue := true;
        FPending := true;
        exit;
      end;
      fire;
      FTimer.Interval := FDelay;
      FTimer.Enabled := true;
    end;
  end;
end;

procedure TDebouncer.timerFired(Sender: TObject);
begin
  FTimer.Enabled := false;
  match FMode of
    dmTrailing: fire;
    dmLeading: ;
  else
    if FTrailingDue then begin
      // the triggers during the slot fire once, and open a new slot
      FTrailingDue := false;
      fire;
      FTimer.Enabled := true;
    end;
  end;
end;

procedure TDebouncer.fire;
begin
  FPending := false;
  var count := FCount;
  FCount := 0;
  if (count > 0) and Assigned(FOnFire) then FOnFire(self);
end;

procedure TDebouncer.Cancel;
begin
  FTimer.Enabled := false;
  FPending := false;
  FTrailingDue := false;
  FCount := 0;
end;

procedure TDebouncer.Flush;
begin
  if not FPending then exit;
  FTimer.Enabled := false;
  FTrailingDue := false;
  fire;
end;

procedure TDebouncer.setDelay(value: integer);
begin
  FDelay := Max(value, 0);
end;

end.
