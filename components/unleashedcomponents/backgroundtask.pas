{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit BackgroundTask;

{$mode unleashed}

interface

uses
  Classes, SysUtils;

type
  TBackgroundTask = class;

  // the work itself; it runs on its own thread and reports through the task
  TTaskWork = procedure(task: TBackgroundTask) of object;
  TTaskProgressEvent = procedure(Sender: TObject; percent: integer; const text: string) of object;
  TTaskErrorEvent = procedure(Sender: TObject; const message: string) of object;

  { TBackgroundTask }

  // runs a method on a thread and brings its progress, its end and its
  // errors back to the main thread as events. The work checks Cancelled
  // now and then and leaves when it is set
  TBackgroundTask = class(TComponent)
  private
    FThread: TThread;
    FWork: TTaskWork;
    FOnWork: TTaskWork;
    FRunning, FCancelled, FFailed: boolean;
    FPercent: integer;
    FStatusText, FErrorText: string;
    FOnStart, FOnDone, FOnCancelled: TNotifyEvent;
    FOnProgress: TTaskProgressEvent;
    FOnError: TTaskErrorEvent;
    procedure threadDone(Sender: TObject);
    procedure reportProgress;
    procedure reportDone;
  public
    destructor Destroy; override;
    // starts the work; a second call while one runs is ignored
    procedure Run(work: TTaskWork); overload;
    // runs OnWork
    procedure Run; overload;
    // asks the work to stop; OnCancelled follows once it has
    procedure Cancel;
    // blocks until the work is over
    procedure WaitFor;
    // for the work: the state shown to the main thread
    procedure Progress(percent: integer; const text: string = '');
    property Running: boolean read FRunning;
    property Cancelled: boolean read FCancelled;
    // the last run ended in an exception
    property Failed: boolean read FFailed;
    property Percent: integer read FPercent;
    property StatusText: string read FStatusText;
    property ErrorText: string read FErrorText;
  published
    property OnWork: TTaskWork read FOnWork write FOnWork;
    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    property OnProgress: TTaskProgressEvent read FOnProgress write FOnProgress;
    // the work returned on its own
    property OnDone: TNotifyEvent read FOnDone write FOnDone;
    // the work returned after Cancel
    property OnCancelled: TNotifyEvent read FOnCancelled write FOnCancelled;
    property OnError: TTaskErrorEvent read FOnError write FOnError;
  end;

implementation

type
  { TTaskThread }

  TTaskThread = class(TThread)
  private
    FTask: TBackgroundTask;
  protected
    procedure Execute; override;
  public
    constructor Create(task: TBackgroundTask);
  end;

constructor TTaskThread.Create(task: TBackgroundTask);
begin
  FTask := task;
  FreeOnTerminate := false;
  inherited Create(true);
end;

procedure TTaskThread.Execute;
begin
  try
    FTask.FWork(FTask);
  except
    on E: Exception do begin
      FTask.FFailed := true;
      FTask.FErrorText := E.Message;
    end;
  end;
end;

{ TBackgroundTask }

destructor TBackgroundTask.Destroy;
begin
  // the work gets its chance to leave before the component goes
  Cancel;
  WaitFor;
  inherited Destroy;
end;

procedure TBackgroundTask.Run(work: TTaskWork);
begin
  if FRunning or not Assigned(work) or (csDesigning in ComponentState) then exit;
  WaitFor;
  FWork := work;
  FRunning := true;
  FCancelled := false;
  FFailed := false;
  FPercent := 0;
  FStatusText := '';
  FErrorText := '';
  if Assigned(FOnStart) then FOnStart(self);
  FThread := TTaskThread.Create(self);
  FThread.OnTerminate := @threadDone;
  FThread.Start;
end;

procedure TBackgroundTask.Run;
begin
  Run(FOnWork);
end;

procedure TBackgroundTask.Cancel;
begin
  if FRunning then FCancelled := true;
end;

procedure TBackgroundTask.WaitFor;
begin
  if FThread = nil then exit;
  FThread.WaitFor;
  FreeAndNil(FThread);
end;

// called on the work thread; the event fires on the main one
procedure TBackgroundTask.Progress(percent: integer; const text: string);
begin
  FPercent := percent;
  FStatusText := text;
  if (FThread <> nil) and Assigned(FOnProgress) then TThread.Queue(FThread, @reportProgress);
end;

procedure TBackgroundTask.reportProgress;
begin
  if Assigned(FOnProgress) then FOnProgress(self, FPercent, FStatusText);
end;

// OnTerminate arrives on the main thread
procedure TBackgroundTask.threadDone(Sender: TObject);
begin
  FRunning := false;
  reportDone;
end;

procedure TBackgroundTask.reportDone;
begin
  if FFailed then begin
    if Assigned(FOnError) then FOnError(self, FErrorText);
  end else if FCancelled then begin
    if Assigned(FOnCancelled) then FOnCancelled(self);
  end else if Assigned(FOnDone) then FOnDone(self);
end;

end.
