{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit AppInstance;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Forms, ExtCtrls, SimpleIPC;

type
  TOtherInstanceEvent = procedure(Sender: TObject; params: TStrings) of object;

  { TSingleInstance }

  // keeps the application to one running copy: a second start hands its
  // command line to the first one through OnOtherInstance and leaves.
  // Check runs on load; a call before Application.Run works as well
  TSingleInstance = class(TComponent)
  private
    FId: string;
    FActive, FAllowOnlyOne, FGlobal: boolean;
    FServer: TSimpleIPCServer;
    FTimer: TTimer;
    FOtherRunning: boolean;
    FOnOtherInstance: TOtherInstanceEvent;
    FOnStarted, FOnAlreadyRunning: TNotifyEvent;
    function idOrDefault: string;
    procedure poll(Sender: TObject);
    procedure gotMessage(Sender: TObject);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // looks for a running copy; true when this is the only one. Otherwise
    // the parameters went to the other copy, OnAlreadyRunning fired and,
    // with AllowOnlyOne, the application leaves
    function Check: boolean;
    // another copy was running at the check
    property OtherRunning: boolean read FOtherRunning;
  published
    // the name the copies know each other by; empty takes the executable
    property Id: string read FId write FId;
    property Active: boolean read FActive write FActive default true;
    // a second copy hands its parameters over and leaves; off, it keeps
    // running after the hand-over
    property AllowOnlyOne: boolean read FAllowOnlyOne write FAllowOnlyOne default true;
    // one copy for every user of the machine; off, one per session
    property Global: boolean read FGlobal write FGlobal default false;
    // the first copy got the command line of a second one
    property OnOtherInstance: TOtherInstanceEvent read FOnOtherInstance write FOnOtherInstance;
    // this copy is the one
    property OnStarted: TNotifyEvent read FOnStarted write FOnStarted;
    // this copy found another one running: its parameters went there
    property OnAlreadyRunning: TNotifyEvent read FOnAlreadyRunning write FOnAlreadyRunning;
  end;

implementation

constructor TSingleInstance.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FActive := true;
  FAllowOnlyOne := true;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 200;
  FTimer.OnTimer := @poll;
end;

destructor TSingleInstance.Destroy;
begin
  FTimer.Enabled := false;
  FServer.Free;
  inherited Destroy;
end;

function TSingleInstance.idOrDefault: string;
begin
  result := if FId <> '' then FId else ChangeFileExt(ExtractFileName(ParamStr(0)), '')+'_instance';
end;

procedure TSingleInstance.Loaded;
begin
  inherited Loaded;
  if FActive and not (csDesigning in ComponentState) then Check;
end;

function TSingleInstance.Check: boolean;
begin
  result := true;
  if (FServer <> nil) or (csDesigning in ComponentState) then exit;
  var client := TSimpleIPCClient.Create(nil);
  try
    client.ServerID := idOrDefault;
    client.SystemGlobal := FGlobal;
    if client.ServerRunning then begin
      // the other copy gets the parameters, one per line
      FOtherRunning := true;
      var params := '';
      for var i := 1 to ParamCount do params += ParamStr(i)+LineEnding;
      try
        client.Connect;
        client.SendStringMessage(params);
      except
        // the other copy went away between the look and the send
      end;
      if Assigned(FOnAlreadyRunning) then FOnAlreadyRunning(self);
      if FAllowOnlyOne then Application.Terminate;
      exit(false);
    end;
  finally
    client.Free;
  end;
  FServer := TSimpleIPCServer.Create(nil);
  FServer.ServerID := idOrDefault;
  // a server that is not Global hides behind a name of its own process, so
  // the next copy would never find it; SystemGlobal reaches the other users
  FServer.Global := true;
  FServer.SystemGlobal := FGlobal;
  FServer.OnMessage := @gotMessage;
  FServer.StartServer;
  FTimer.Enabled := true;
  if Assigned(FOnStarted) then FOnStarted(self);
end;

procedure TSingleInstance.poll(Sender: TObject);
begin
  if FServer <> nil then FServer.PeekMessage(0, true);
end;

procedure TSingleInstance.gotMessage(Sender: TObject);
begin
  var params := TStringList.Create;
  try
    params.Text := FServer.StringMessage;
    if Assigned(FOnOtherInstance) then FOnOtherInstance(self, params);
  finally
    params.Free;
  end;
end;

end.
