{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SerialPort;

{$mode unleashed}

// FPC builds its Serial unit for these systems only; elsewhere the
// component is there, but Open reports that it is not supported
{$if defined(WINDOWS) or defined(LINUX) or defined(ANDROID) or defined(NETBSD) or defined(OPENBSD)}
  {$define HAS_SERIAL}
{$else}
  {$warning TSerialPort has no serial backend on this system; Open reports "not supported"}
{$endif}

interface

uses
  Classes, SysUtils, ExtCtrls, SyncObjs{$ifdef HAS_SERIAL}, Serial{$endif};

type
  {$ifndef HAS_SERIAL}
  TSerialHandle = PtrInt;
  {$endif}
  TSerialParity = (spNone, spOdd, spEven);
  TSerialFlowControl = (sfNone, sfRtsCts);
  TSerialLineEnding = (sleLF, sleCR, sleCRLF);
  TSerialDataEvent = procedure(Sender: TObject; const data: RawByteString) of object;
  TSerialLineEvent = procedure(Sender: TObject; const line: string) of object;
  TSerialErrorEvent = procedure(Sender: TObject; const message: string) of object;

  { TSerialReader }

  // reads the port into a buffer the component polls
  TSerialReader = class(TThread)
  private
    FHandle: TSerialHandle;
    FLock: TCriticalSection;
    FData: RawByteString;
    FFailed: boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(handle: TSerialHandle);
    destructor Destroy; override;
    function Take: RawByteString;
    property Failed: boolean read FFailed;
  end;

  { TSerialPort }

  // a serial port, read in the background: OnData gets every chunk, OnLine
  // every whole line. The same calls and events on every system; only the
  // port names differ, COM3 on Windows and /dev/ttyUSB0 on Linux, and
  // AvailablePorts lists the ones there are. Works on Windows, Linux, Android,
  // NetBSD and OpenBSD, where FPC has its Serial unit; on macOS and FreeBSD
  // Open fails with OnError saying not supported and AvailablePorts is empty
  TSerialPort = class(TComponent)
  private
    FPort: string;
    FBaudRate, FDataBits, FStopBits: integer;
    FParity: TSerialParity;
    FFlowControl: TSerialFlowControl;
    FLineEnding: TSerialLineEnding;
    FActive, FDTR, FRTS: boolean;
    FHandle: TSerialHandle;
    FOpen: boolean;
    FReader: TSerialReader;
    FPoll: TTimer;
    FLine, FUnread: RawByteString;
    FReceived, FSent: Int64;
    FOnData: TSerialDataEvent;
    FOnLine: TSerialLineEvent;
    FOnError: TSerialErrorEvent;
    FOnOpen, FOnClose: TNotifyEvent;
    procedure setActive(value: boolean);
    procedure setSignal(index: integer; value: boolean);
    function getSignal(index: integer): boolean;
    procedure setPort(const value: string);
    procedure poll(Sender: TObject);
    procedure fail(const message: string);
    function lineEnd: RawByteString;
    function deviceName: string;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the ports this system has
    class procedure AvailablePorts(list: TStrings);
    // opens the port with the settings; false and OnError when it fails
    function Open: boolean;
    procedure Close;
    // the bytes written
    function Write(const data: RawByteString): integer;
    // the text and LineEnding
    function WriteLine(const text: string): integer;
    // the bytes received and not taken by OnData
    function ReadAvailable: RawByteString;
    property IsOpen: boolean read FOpen;
    property BytesReceived: Int64 read FReceived;
    property BytesSent: Int64 read FSent;
    // the input lines of the port
    property CTS: boolean index 2 read getSignal;
    property DSR: boolean index 3 read getSignal;
    property CD: boolean index 4 read getSignal;
    property RI: boolean index 5 read getSignal;
  published
    // COM3 or \\.\COM12 on Windows, /dev/ttyUSB0 or /dev/ttyS0 on Linux
    property Port: string read FPort write setPort;
    property BaudRate: integer read FBaudRate write FBaudRate default 9600;
    property DataBits: integer read FDataBits write FDataBits default 8;
    property Parity: TSerialParity read FParity write FParity default spNone;
    // 1 or 2
    property StopBits: integer read FStopBits write FStopBits default 1;
    property FlowControl: TSerialFlowControl read FFlowControl write FFlowControl default sfNone;
    // what ends a line for OnLine and WriteLine
    property LineEnding: TSerialLineEnding read FLineEnding write FLineEnding default sleLF;
    // the port opens as the form loads, and opens or closes on a change
    property Active: boolean read FActive write setActive default false;
    // the output lines of the port while it is open
    property DTR: boolean index 0 read getSignal write setSignal default true;
    property RTS: boolean index 1 read getSignal write setSignal default true;
    // every chunk read; without a handler the bytes wait for ReadAvailable
    property OnData: TSerialDataEvent read FOnData write FOnData;
    // every whole line read, without its end
    property OnLine: TSerialLineEvent read FOnLine write FOnLine;
    property OnError: TSerialErrorEvent read FOnError write FOnError;
    property OnOpen: TNotifyEvent read FOnOpen write FOnOpen;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

implementation

uses
  {$ifdef WINDOWS}Registry,{$endif} Math;

{ TSerialReader }

constructor TSerialReader.Create(handle: TSerialHandle);
begin
  FHandle := handle;
  FLock := TCriticalSection.Create;
  inherited Create(false);
end;

destructor TSerialReader.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TSerialReader.Execute;
{$ifdef HAS_SERIAL}
var
  buffer: array[0..4095] of byte;
{$endif}
begin
  {$ifdef HAS_SERIAL}
  // the short timeout lets Terminate end the loop soon
  while not Terminated do begin
    var n := SerReadTimeout(FHandle, buffer, sizeof(buffer), 50);
    if n < 0 then begin
      FFailed := true;
      break;
    end;
    if n = 0 then continue;
    FLock.Enter;
    try
      var old := length(FData);
      SetLength(FData, old+n);
      Move(buffer[0], FData[old+1], n);
    finally
      FLock.Leave;
    end;
  end;
  {$else}
  FFailed := true;
  {$endif}
end;

function TSerialReader.Take: RawByteString;
begin
  FLock.Enter;
  try
    result := FData;
    FData := '';
  finally
    FLock.Leave;
  end;
end;

{ TSerialPort }

constructor TSerialPort.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBaudRate := 9600;
  FDataBits := 8;
  FStopBits := 1;
  FDTR := true;
  FRTS := true;
end;

destructor TSerialPort.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TSerialPort.Loaded;
begin
  inherited Loaded;
  if FActive and not (csDesigning in ComponentState) then Open;
end;

class procedure TSerialPort.AvailablePorts(list: TStrings);
begin
  list.Clear;
  {$ifdef WINDOWS}
  // the ports the drivers registered, as COM3
  var reg := autofree TRegistry.Create(KEY_READ);
  reg.RootKey := HKEY_LOCAL_MACHINE;
  if reg.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') then begin
    var names := autofree TStringList.Create;
    reg.GetValueNames(names);
    for var name in names do list.Add(reg.ReadString(name));
  end;
  {$elseif defined(HAS_SERIAL)}
  // the tty devices with hardware behind them; a ttyS without a chip
  // reports the type 0
  var info: TSearchRec;
  if FindFirst('/sys/class/tty/*', faAnyFile, info) = 0 then
    try
      repeat
        var name: string := info.Name;
        if (name = '.') or (name = '..') then continue;
        var sys := '/sys/class/tty/'+name;
        if not DirectoryExists(sys+'/device') then continue;
        if name.StartsWith('ttyS') then begin
          var kind := autofree TStringList.Create;
          try
            kind.LoadFromFile(sys+'/type');
          except
            continue;
          end;
          if (kind.Count = 0) or (Trim(kind[0]) = '0') then continue;
        end;
        list.Add('/dev/'+name);
      until FindNext(info) <> 0;
    finally
      FindClose(info);
    end;
  {$endif}
  if list is TStringList then TStringList(list).Sort;
end;

function TSerialPort.deviceName: string;
begin
  result := FPort;
  {$ifdef WINDOWS}
  // COM10 and up open only by their device path
  if not result.StartsWith('\\.\') then result := '\\.\'+result;
  {$endif}
end;

function TSerialPort.Open: boolean;
begin
  if FOpen then exit(true);
  result := false;
  if csDesigning in ComponentState then exit;
  {$ifndef HAS_SERIAL}
  fail('Serial ports are not supported on this system');
  exit;
  {$else}
  if FPort = '' then begin
    fail('No port set');
    exit;
  end;
  var h := SerOpen(deviceName);
  // Windows reports a failure as 0, Unix as -1
  if (h = 0) or (h = TSerialHandle(-1)) then begin
    fail(Format('Cannot open %s: %s', [FPort, SysErrorMessage(GetLastOSError)]));
    exit;
  end;
  FHandle := h;
  SerSetParams(h, FBaudRate, EnsureRange(FDataBits, 5, 8), TParityType(ord(FParity)), EnsureRange(FStopBits, 1, 2), (if FFlowControl = sfRtsCts then [RtsCtsFlowControl] else []));
  SerSetDTR(h, FDTR);
  if FFlowControl = sfNone then SerSetRTS(h, FRTS);
  SerFlushInput(h);
  FOpen := true;
  FActive := true;
  FLine := '';
  FUnread := '';
  FReader := TSerialReader.Create(h);
  if FPoll = nil then begin
    FPoll := TTimer.Create(self);
    FPoll.Interval := 20;
    FPoll.OnTimer := @poll;
  end;
  FPoll.Enabled := true;
  result := true;
  if Assigned(FOnOpen) then FOnOpen(self);
  {$endif}
end;

procedure TSerialPort.Close;
begin
  if not FOpen then exit;
  FOpen := false;
  if FPoll <> nil then FPoll.Enabled := false;
  FReader.Terminate;
  FReader.WaitFor;
  // what came in before the stop still goes out
  var rest := FReader.Take;
  FreeAndNil(FReader);
  {$ifdef HAS_SERIAL}
  SerClose(FHandle);
  {$endif}
  FHandle := 0;
  if not (csDestroying in ComponentState) then begin
    if rest <> '' then begin
      FReceived += length(rest);
      if Assigned(FOnData) then FOnData(self, rest) else FUnread += rest;
    end;
    if Assigned(FOnClose) then FOnClose(self);
  end;
end;

procedure TSerialPort.fail(const message: string);
begin
  if Assigned(FOnError) then FOnError(self, message);
end;

function TSerialPort.lineEnd: RawByteString;
begin
  result := match FLineEnding of
    sleCR: #13;
    sleCRLF: #13#10;
  else
    #10
  end;
end;

procedure TSerialPort.poll(Sender: TObject);
begin
  if FReader = nil then exit;
  var data := FReader.Take;
  if data <> '' then begin
    FReceived += length(data);
    if Assigned(FOnData) then FOnData(self, data) else if not Assigned(FOnLine) then FUnread += data;
    if Assigned(FOnLine) then begin
      FLine += data;
      var stop := lineEnd;
      var at := Pos(stop, FLine);
      while at > 0 do begin
        var line := Copy(FLine, 1, at-1);
        Delete(FLine, 1, at+length(stop)-1);
        // a lone CR before an LF ending goes as well
        if (FLineEnding = sleLF) and (line <> '') and (line[length(line)] = #13) then SetLength(line, length(line)-1);
        FOnLine(self, line);
        at := Pos(stop, FLine);
      end;
    end;
  end;
  if FReader.Failed then begin
    fail(Format('%s stopped answering', [FPort]));
    Close;
    FActive := false;
  end;
end;

function TSerialPort.Write(const data: RawByteString): integer;
begin
  result := 0;
  if not FOpen or (data = '') then exit;
  {$ifdef HAS_SERIAL}
  result := SerWrite(FHandle, data[1], length(data));
  {$endif}
  if result > 0 then FSent += result;
  if result < length(data) then fail(Format('%s took %d of %d bytes', [FPort, Max(result, 0), length(data)]));
end;

function TSerialPort.WriteLine(const text: string): integer;
begin
  result := Write(RawByteString(text)+lineEnd);
end;

function TSerialPort.ReadAvailable: RawByteString;
begin
  result := FUnread;
  FUnread := '';
end;

procedure TSerialPort.setActive(value: boolean);
begin
  if csLoading in ComponentState then begin
    FActive := value;
    exit;
  end;
  if value = FActive then exit;
  if csDesigning in ComponentState then begin
    FActive := value;
    exit;
  end;
  if value then Open else begin
    Close;
    FActive := false;
  end;
end;

procedure TSerialPort.setPort(const value: string);
begin
  if FPort = value then exit;
  // a new port reopens an open one
  var reopen := FOpen;
  if reopen then Close;
  FPort := value;
  if reopen then Open;
end;

function TSerialPort.getSignal(index: integer): boolean;
begin
  result := match index of
    0: FDTR;
    1: FRTS;
    {$ifdef HAS_SERIAL}
    2: FOpen and SerGetCTS(FHandle);
    3: FOpen and SerGetDSR(FHandle);
    4: FOpen and SerGetCD(FHandle);
  else
    FOpen and SerGetRI(FHandle)
    {$else}
  else
    false
    {$endif}
  end;
end;

procedure TSerialPort.setSignal(index: integer; value: boolean);
begin
  if index = 0 then begin
    FDTR := value;
    {$ifdef HAS_SERIAL}
    if FOpen then SerSetDTR(FHandle, value);
    {$endif}
  end else begin
    FRTS := value;
    {$ifdef HAS_SERIAL}
    if FOpen and (FFlowControl = sfNone) then SerSetRTS(FHandle, value);
    {$endif}
  end;
end;

end.
