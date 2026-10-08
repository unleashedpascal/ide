{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit TerminalView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, LCLType, LMessages, SyncObjs, Process, ControlPaint;

type
  // how the bytes of a process become text: UTF-8, the console code page of
  // the system, or UTF-8 where they form it and the code page elsewhere
  TTerminalEncoding = (teAuto, teUTF8, teSystem);
  TTerminalInputEvent = procedure(Sender: TObject; const line: string; var handled: boolean) of object;
  TTerminalOutputEvent = procedure(Sender: TObject; const text: string) of object;
  TTerminalExitEvent = procedure(Sender: TObject; exitCode: integer) of object;

  // the look of a character: the colors are -1 for the default, 0 to 255
  // for the palette, or TERM_RGB with the color in the low bytes
  TTermAttr = packed record
    fg, bg: longint;
    style: byte;
  end;

  TTermLine = record
    text: UnicodeString;
    attrs: array of TTermAttr;
  end;
  PTermLine = ^TTermLine;

  { TTerminalReader }

  // reads the output of a process into a buffer the view polls
  TTerminalReader = class(TThread)
  private
    FProcess: TProcess;
    FLock: TCriticalSection;
    FData: RawByteString;
  protected
    procedure Execute; override;
  public
    constructor Create(process: TProcess);
    destructor Destroy; override;
    function Take: RawByteString;
  end;

  { TTerminalView }

  // a console: runs a command and shows what it writes, the ANSI colors and
  // styles included, and sends the lines typed into the input line at the
  // bottom to it. Without a process the lines go to OnInput, and Write puts
  // text of the application on the screen
  TTerminalView = class(TScrollingWinControl)
  private
    FLines: array of TTermLine;
    FCount: integer;
    FRowStart: array of integer;
    FCols: integer;
    FColumn: integer;
    FAttr: TTermAttr;
    FPendingBytes: RawByteString;
    FEscape: UnicodeString;
    FMaxLines, FPadding: integer;
    FAutoScroll, FShowInput, FEchoInput, FMonospace, FRunInShell, FShowExitCode: boolean;
    FPrompt, FInput, FCommand, FWorkingDirectory: string;
    FInputCaret, FInputShift: integer;
    FHistory: TStringList;
    FHistoryIndex: integer;
    FEncoding: TTerminalEncoding;
    FTextColor, FInputColor: TColor;
    FProcess: TProcess;
    FJob: THandle;
    FReader: TTerminalReader;
    FPoll: TTimer;
    FExitCode: integer;
    FKilled, FSelecting: boolean;
    FSelAnchor, FSelCaret: TPoint;
    FOnInput: TTerminalInputEvent;
    FOnOutput: TTerminalOutputEvent;
    FOnProcessExit: TTerminalExitEvent;
    FOnProcessStart: TNotifyEvent;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure poll(Sender: TObject);
    procedure forkChild(Sender: TObject);
    procedure killTree;
    procedure finishProcess;
    procedure feedBytes(const data: RawByteString);
    procedure feed(const s: UnicodeString);
    procedure putRun(const s: UnicodeString);
    procedure newLine;
    procedure applySgr(const params: UnicodeString);
    procedure eraseInLine(mode: integer);
    function rowsOf(index: integer): integer;
    procedure relayout;
    procedure trimLines;
    function totalRows: integer;
    function lineOfRow(row: integer): integer;
    function cellWidth: integer;
    function rowHeight: integer;
    function inputHeight: integer;
    procedure updateRange;
    function atEnd: boolean;
    procedure contentChanged(follow: boolean);
    function hit(X, Y: integer): TPoint;
    function hasSelection: boolean;
    procedure orderedSelection(out a, b: TPoint);
    function colorOf(value: longint; fallback: TColor): TColor;
    procedure setupFont(c: TCanvas);
    procedure submitInput;
    procedure insertInput(const s: string);
    procedure showInputCaret;
    procedure fitColumns;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoOnResize; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure FontChanged(Sender: TObject); override;
    procedure WMVScroll(var Message: TLMVScroll); message LM_VSCROLL;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // runs Command; false when a process still runs or it does not start
    function Run: boolean;
    function Execute(const command: string): boolean;
    // kills the process and every process it started; it ends with code 1
    procedure Terminate;
    function Running: boolean;
    // to the input of the process, as it is or with a line end
    procedure SendText(const text: string);
    procedure SendLine(const text: string);
    // ends the input of the process, as the end of a file does
    procedure CloseInput;
    // text of the application; the ANSI sequences work as from a process
    procedure Write(const text: string);
    procedure WriteLn(const text: string = '');
    procedure Clear;
    function LineCount: integer;
    function Lines(index: integer): string;
    // everything, without the colors
    function Text: string;
    function SelectedText: string;
    procedure SelectAll;
    // the selection, or everything without one
    procedure CopyToClipboard;
    procedure SaveToFile(const fileName: string);
    procedure ScrollToEnd;
    // the exit code of the last process
    property ExitCode: integer read FExitCode;
    property Input: string index 3 read getText write setText;
  published
    // run in the shell of the system: cmd on Windows, sh elsewhere
    property Command: string index 0 read getText write setText;
    property WorkingDirectory: string index 1 read getText write setText;
    property Prompt: string index 2 read getText write setText;
    property RunInShell: boolean index 0 read getFlag write setFlag default true;
    // the view follows the output while it sits at the end
    property AutoScroll: boolean index 1 read getFlag write setFlag default true;
    property ShowInput: boolean index 2 read getFlag write setFlag default true;
    // a line sent shows in the output after the prompt
    property EchoInput: boolean index 3 read getFlag write setFlag default true;
    // the font becomes a fixed pitch one of the system, at the size of Font
    property Monospace: boolean index 4 read getFlag write setFlag default true;
    // a line with the exit code after the process ends
    property ShowExitCode: boolean index 5 read getFlag write setFlag default true;
    property OutputEncoding: TTerminalEncoding read FEncoding write FEncoding default teAuto;
    // lines kept; 0 keeps every one
    property MaxLines: integer index 0 read getMetric write setMetric default 5000;
    property Padding: integer index 1 read getMetric write setMetric default 4;
    // the background, which the frame of the theme takes for its inner line
    property Color default clWindow;
    // clDefault takes the colors of the theme
    property TextColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property InputColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // a line typed; handled keeps it from the process
    property OnInput: TTerminalInputEvent read FOnInput write FOnInput;
    // text from the process as it comes, the sequences in it
    property OnOutput: TTerminalOutputEvent read FOnOutput write FOnOutput;
    property OnProcessStart: TNotifyEvent read FOnProcessStart write FOnProcessStart;
    property OnProcessExit: TTerminalExitEvent read FOnProcessExit write FOnProcessExit;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsSingle;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default true;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnResize;
  end;

implementation

uses
  Math, LazUTF8, LCLIntf, Clipbrd{$ifdef UNIX}, BaseUnix{$endif};

{$ifdef WINDOWS}
// a job holds the shell and everything it starts, so a kill reaches them all
function CreateJobObjectW(attributes: pointer; name: PWideChar): THandle; stdcall; external 'kernel32' name 'CreateJobObjectW';
function AssignProcessToJobObject(job, process: THandle): LongBool; stdcall; external 'kernel32' name 'AssignProcessToJobObject';
function TerminateJobObject(job: THandle; exitCode: cardinal): LongBool; stdcall; external 'kernel32' name 'TerminateJobObject';
function closeKernelHandle(handle: THandle): LongBool; stdcall; external 'kernel32' name 'CloseHandle';
{$endif}

type
  // the handle of the pipe end is protected
  TDescriptorAccess = class(TIODescriptor);

const
  TERM_RGB = $1000000;
  STYLE_BOLD = 1;
  STYLE_DIM = 2;
  STYLE_ITALIC = 4;
  STYLE_UNDERLINE = 8;
  STYLE_INVERSE = 16;

  // the sixteen colors on a dark and on a light background
  DARK_PALETTE: array[0..15] of TColor = ($0C0C0C, $1F0FC5, $0EA113, $009CC1, $DA3700, $981788, $DD963A, $CCCCCC,
    $767676, $5648E7, $0CC616, $A5F1F9, $FF783B, $9E00B4, $D6D661, $F2F2F2);
  LIGHT_PALETTE: array[0..15] of TColor = ($423A38, $4956E4, $4FA150, $0184C1, $BC8401, $A426A6, $B39709, $D0D0D0,
    $5D524F, $756CDF, $79C398, $7AC0E4, $EFAF61, $DD77C5, $C1B556, $FFFFFF);

var
  monoFace: string = '';

// the first fixed pitch font the system has
function monospaceFace: string;
begin
  if monoFace <> '' then exit(monoFace);
  monoFace := 'Courier New';
  for var name in ['Cascadia Mono', 'Consolas', 'DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono', 'Ubuntu Mono', 'Menlo', 'Courier New', 'Monospace'] do
    for var i := 0 to Screen.Fonts.Count-1 do
      if SameText(Screen.Fonts[i], name) then begin
        monoFace := Screen.Fonts[i];
        exit(monoFace);
      end;
  result := monoFace;
end;

function defaultAttr: TTermAttr;
begin
  result.fg := -1;
  result.bg := -1;
  result.style := 0;
end;

{ TTerminalReader }

constructor TTerminalReader.Create(process: TProcess);
begin
  FProcess := process;
  FLock := TCriticalSection.Create;
  inherited Create(false);
end;

destructor TTerminalReader.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TTerminalReader.Execute;
var
  buffer: array[0..8191] of byte;
begin
  while not Terminated do begin
    var n := FProcess.Output.Read(buffer, sizeof(buffer));
    if n <= 0 then break;
    FLock.Enter;
    try
      var old := length(FData);
      SetLength(FData, old+n);
      Move(buffer[0], FData[old+1], n);
    finally
      FLock.Leave;
    end;
  end;
end;

function TTerminalReader.Take: RawByteString;
begin
  FLock.Enter;
  try
    result := FData;
    FData := '';
  finally
    FLock.Leave;
  end;
end;

{ TTerminalView }

constructor TTerminalView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FMaxLines := 5000;
  FPadding := 4;
  FAutoScroll := true;
  FShowInput := true;
  FEchoInput := true;
  FMonospace := true;
  FRunInShell := true;
  FShowExitCode := true;
  FPrompt := '> ';
  Color := clWindow;
  FTextColor := clDefault;
  FInputColor := clDefault;
  FAttr := defaultAttr;
  FCols := 80;
  FHistory := TStringList.Create;
  FHistoryIndex := -1;
  FPoll := TTimer.Create(self);
  FPoll.Enabled := false;
  FPoll.Interval := 30;
  FPoll.OnTimer := @poll;
  BorderStyle := bsSingle;
  TabStop := true;
  HorzScrollBar.Visible := false;
  VertScrollBar.Tracking := true;
  Clear;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TTerminalView.Destroy;
begin
  FPoll.Enabled := false;
  if FProcess <> nil then begin
    killTree;
    FReader.WaitFor;
    FReader.Free;
    FProcess.Free;
    {$ifdef WINDOWS}
    if FJob <> 0 then closeKernelHandle(FJob);
    {$endif}
  end;
  FHistory.Free;
  inherited Destroy;
end;

// BaseUnix has a TSize of its own
class function TTerminalView.GetControlClassDefaultSize: Types.TSize;
begin
  result.cx := 420;
  result.cy := 220;
end;

// -- process ----------------------

function TTerminalView.Running: boolean;
begin
  result := FProcess <> nil;
end;

function TTerminalView.Run: boolean;
begin
  result := Execute(FCommand);
end;

function TTerminalView.Execute(const command: string): boolean;
begin
  result := false;
  if Running or (Trim(command) = '') or (csDesigning in ComponentState) then exit;
  FCommand := command;
  FPendingBytes := '';
  FKilled := false;
  var p := TProcess.Create(nil);
  try
    p.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    {$ifdef WINDOWS}
    // suspended until it sits in the job, so nothing it starts escapes
    p.Options := p.Options+[poRunSuspended];
    {$else}
    p.OnForkEvent := @forkChild;
    {$endif}
    if FRunInShell then begin
      {$ifdef WINDOWS}
      // `/s` makes cmd take everything between the outer quotes as it is
      p.Executable := GetEnvironmentVariable('COMSPEC');
      if p.Executable = '' then p.Executable := 'cmd.exe';
      p.Parameters.Add('/s');
      p.Parameters.Add('/c');
      p.Parameters.Add('"'+command+'"');
      p.SkipCommandLineQuotes := true;
      {$else}
      p.Executable := '/bin/sh';
      p.Parameters.Add('-c');
      p.Parameters.Add(command);
      {$endif}
    end else begin
      var parts := autofree TStringList.Create;
      CommandToList(command, parts);
      p.Executable := parts[0];
      for var i := 1 to parts.Count-1 do p.Parameters.Add(parts[i]);
    end;
    if FWorkingDirectory <> '' then p.CurrentDirectory := FWorkingDirectory;
    p.Execute;
    {$ifdef WINDOWS}
    FJob := CreateJobObjectW(nil, nil);
    if FJob <> 0 then AssignProcessToJobObject(FJob, p.ProcessHandle);
    p.Resume;
    {$endif}
  except
    on E: Exception do begin
      p.Free;
      Write(#27'[91m'+Format('Cannot run "%s" (%s)', [command, E.Message])+#27'[0m'+LineEnding);
      exit;
    end;
  end;
  FProcess := p;
  FReader := TTerminalReader.Create(p);
  FPoll.Enabled := true;
  result := true;
  Invalidate;
  if Assigned(FOnProcessStart) then FOnProcessStart(self);
end;

procedure TTerminalView.Terminate;
begin
  if not Running then exit;
  FKilled := true;
  killTree;
end;

// the child leads a process group of its own, so a kill reaches what it starts
procedure TTerminalView.forkChild(Sender: TObject);
begin
  {$ifdef UNIX}
  FpSetsid;
  {$endif}
end;

procedure TTerminalView.killTree;
begin
  {$ifdef WINDOWS}
  if FJob <> 0 then TerminateJobObject(FJob, 1)
  else if FProcess.Running then FProcess.Terminate(1);
  {$else}
  if FProcess.ProcessID > 0 then fpKill(-FProcess.ProcessID, SIGKILL);
  {$endif}
end;

procedure TTerminalView.poll(Sender: TObject);
begin
  if FReader = nil then exit;
  var data := FReader.Take;
  if data <> '' then feedBytes(data);
  if FReader.Finished then begin
    data := FReader.Take;
    if data <> '' then feedBytes(data);
    finishProcess;
  end;
end;

procedure TTerminalView.finishProcess;
begin
  FPoll.Enabled := false;
  FProcess.WaitOnExit;
  // a signal leaves no exit code on Unix; a kill reads 1 everywhere
  FExitCode := if FKilled then 1 else FProcess.ExitCode;
  FreeAndNil(FReader);
  FreeAndNil(FProcess);
  {$ifdef WINDOWS}
  if FJob <> 0 then closeKernelHandle(FJob);
  FJob := 0;
  {$endif}
  // what is left of an unfinished character or sequence goes out as it is
  if FPendingBytes <> '' then begin
    var rest := FPendingBytes;
    FPendingBytes := '';
    feed(UTF8Decode(rest));
  end;
  if FShowExitCode then begin
    if FColumn > 0 then newLine;
    Write(#27'[2m'+Format('[exit code %d]', [FExitCode])+#27'[0m'+LineEnding);
  end;
  Invalidate;
  if Assigned(FOnProcessExit) then FOnProcessExit(self, FExitCode);
end;

// the input goes through the handle and never through TProcess.Input: once
// that stream exists, CloseInput no longer closes the pipe
procedure TTerminalView.SendText(const text: string);
begin
  if not Running then exit;
  var handle := TDescriptorAccess(FProcess.InputDescriptor).OurHandle;
  if handle = THandle(-1) then exit;
  var data := if FEncoding = teSystem then UTF8ToConsole(text) else text;
  if data <> '' then FileWrite(handle, data[1], length(data));
end;

procedure TTerminalView.SendLine(const text: string);
begin
  SendText(text+LineEnding);
end;

procedure TTerminalView.CloseInput;
begin
  if Running then FProcess.CloseInput;
end;

// -- decoding ----------------------

procedure TTerminalView.feedBytes(const data: RawByteString);
begin
  var buf := FPendingBytes+data;
  FPendingBytes := '';
  // an unfinished UTF-8 character at the end waits for the rest
  if FEncoding <> teSystem then begin
    var tail := length(buf);
    var back := 0;
    while (back < 3) and (tail-back >= 1) and ((ord(buf[tail-back]) and $C0) = $80) do inc(back);
    if tail-back >= 1 then begin
      var lead := ord(buf[tail-back]);
      var need := if lead >= $F0 then 4 else if lead >= $E0 then 3 else if lead >= $C0 then 2 else 1;
      if need > back+1 then begin
        FPendingBytes := Copy(buf, tail-back, back+1);
        SetLength(buf, tail-back-1);
      end;
    end;
  end;
  if buf = '' then exit;
  var text: string;
  match FEncoding of
    teUTF8: text := buf;
    teSystem: text := ConsoleToUTF8(buf);
  else
    if FindInvalidUTF8Codepoint(PChar(buf), length(buf)) < 0 then text := buf else text := ConsoleToUTF8(buf);
  end;
  SetCodePage(RawByteString(text), CP_UTF8, false);
  if Assigned(FOnOutput) then FOnOutput(self, text);
  feed(UTF8Decode(text));
end;

procedure TTerminalView.Write(const text: string);
begin
  feed(UTF8Decode(text));
end;

procedure TTerminalView.WriteLn(const text: string);
begin
  feed(UTF8Decode(text)+#10);
end;

// -- the screen ----------------------

procedure TTerminalView.Clear;
begin
  FLines := [];
  SetLength(FLines, 1);
  FRowStart := [];
  SetLength(FRowStart, 1);
  FCount := 1;
  FColumn := 0;
  FSelAnchor := Point(0, 0);
  FSelCaret := Point(0, 0);
  contentChanged(true);
end;

function TTerminalView.rowsOf(index: integer): integer;
begin
  result := Max((length(FLines[index].text)+FCols-1) div Max(FCols, 1), 1);
end;

function TTerminalView.totalRows: integer;
begin
  result := FRowStart[FCount-1]+rowsOf(FCount-1);
end;

procedure TTerminalView.relayout;
begin
  var row := 0;
  for var i := 0 to FCount-1 do begin
    FRowStart[i] := row;
    row += rowsOf(i);
  end;
end;

function TTerminalView.lineOfRow(row: integer): integer;
begin
  var lo := 0;
  var hi := FCount-1;
  while lo < hi do begin
    var mid := (lo+hi+1) div 2;
    if FRowStart[mid] <= row then lo := mid else hi := mid-1;
  end;
  result := lo;
end;

procedure TTerminalView.newLine;
begin
  if FCount >= length(FLines) then begin
    SetLength(FLines, Max(FCount*2, 64));
    SetLength(FRowStart, length(FLines));
  end;
  FRowStart[FCount] := FRowStart[FCount-1]+rowsOf(FCount-1);
  FLines[FCount].text := '';
  FLines[FCount].attrs := nil;
  inc(FCount);
  FColumn := 0;
end;

// past MaxLines a twentieth goes at once, so the shift stays rare
procedure TTerminalView.trimLines;
begin
  if (FMaxLines <= 0) or (FCount <= FMaxLines) then exit;
  var drop := FCount-FMaxLines+FMaxLines div 20;
  drop := Min(drop, FCount-1);
  var rows := FRowStart[drop];
  for var i := 0 to drop-1 do begin
    FLines[i].text := '';
    FLines[i].attrs := nil;
  end;
  Move(FLines[drop], FLines[0], (FCount-drop)*SizeOf(TTermLine));
  FillChar(FLines[FCount-drop], drop*SizeOf(TTermLine), 0);
  FCount -= drop;
  for var i := 0 to FCount-1 do FRowStart[i] := FRowStart[i+drop]-rows;
  FSelAnchor.Y := Max(FSelAnchor.Y-drop, 0);
  FSelCaret.Y := Max(FSelCaret.Y-drop, 0);
  if HandleAllocated then VertScrollBar.Position := Max(VertScrollBar.Position-rows*rowHeight, 0);
end;

// a run of printable characters at the cursor, over what is there
procedure TTerminalView.putRun(const s: UnicodeString);
begin
  if s = '' then exit;
  var line: PTermLine := @FLines[FCount-1];
  var len := length(line^.text);
  if FColumn > len then begin
    line^.text += StringOfChar(WideChar(' '), FColumn-len);
    SetLength(line^.attrs, FColumn);
    for var i := len to FColumn-1 do line^.attrs[i] := defaultAttr;
    len := FColumn;
  end;
  var stop := FColumn+length(s);
  if stop > len then begin
    SetLength(line^.text, stop);
    SetLength(line^.attrs, stop);
  end;
  for var i := 0 to length(s)-1 do begin
    line^.text[FColumn+i+1] := s[i+1];
    line^.attrs[FColumn+i] := FAttr;
  end;
  FColumn := stop;
end;

procedure TTerminalView.eraseInLine(mode: integer);
begin
  var line: PTermLine := @FLines[FCount-1];
  match mode of
    0: if FColumn < length(line^.text) then begin
      SetLength(line^.text, FColumn);
      SetLength(line^.attrs, FColumn);
    end;
    1: for var i := 0 to Min(FColumn, length(line^.text)-1) do begin
      line^.text[i+1] := ' ';
      line^.attrs[i] := defaultAttr;
    end;
  else
    begin
      line^.text := '';
      line^.attrs := nil;
    end;
  end;
end;

procedure TTerminalView.applySgr(const params: UnicodeString);
begin
  var parts := string(params).Split([';', ':']);
  if length(parts) = 0 then parts := ['0'];
  var i := 0;
  while i < length(parts) do begin
    var p := StrToIntDef(parts[i], 0);
    match p of
      0: FAttr := defaultAttr;
      1: FAttr.style := FAttr.style or STYLE_BOLD;
      2: FAttr.style := FAttr.style or STYLE_DIM;
      3: FAttr.style := FAttr.style or STYLE_ITALIC;
      4: FAttr.style := FAttr.style or STYLE_UNDERLINE;
      7: FAttr.style := FAttr.style or STYLE_INVERSE;
      22: FAttr.style := FAttr.style and not (STYLE_BOLD or STYLE_DIM);
      23: FAttr.style := FAttr.style and not STYLE_ITALIC;
      24: FAttr.style := FAttr.style and not STYLE_UNDERLINE;
      27: FAttr.style := FAttr.style and not STYLE_INVERSE;
      30..37: FAttr.fg := p-30;
      39: FAttr.fg := -1;
      40..47: FAttr.bg := p-40;
      49: FAttr.bg := -1;
      90..97: FAttr.fg := p-90+8;
      100..107: FAttr.bg := p-100+8;
      38, 48: begin
        // 5;n picks the palette, 2;r;g;b a color
        var value := -1;
        if (i+2 < length(parts)) and (parts[i+1] = '5') then begin
          value := EnsureRange(StrToIntDef(parts[i+2], 0), 0, 255);
          i += 2;
        end else if (i+4 < length(parts)) and (parts[i+1] = '2') then begin
          value := TERM_RGB or RGBToColor(EnsureRange(StrToIntDef(parts[i+2], 0), 0, 255), EnsureRange(StrToIntDef(parts[i+3], 0), 0, 255), EnsureRange(StrToIntDef(parts[i+4], 0), 0, 255));
          i += 4;
        end;
        if p = 38 then FAttr.fg := value else FAttr.bg := value;
      end;
    else
      ;
    end;
    inc(i);
  end;
end;

// the text, the control characters and the escape sequences in it
procedure TTerminalView.feed(const s: UnicodeString);
begin
  var follow := atEnd;
  var src := FEscape+s;
  FEscape := '';
  var n := length(src);
  var i := 1;
  while i <= n do begin
    var ch := src[i];
    if ch >= ' ' then begin
      var start := i;
      while (i <= n) and (src[i] >= ' ') and (src[i] <> #127) do inc(i);
      putRun(Copy(src, start, i-start));
      if (i <= n) and (src[i] = #127) then inc(i);
      continue;
    end;
    match ch of
      #10: newLine;
      #13: FColumn := 0;
      #8: if FColumn > 0 then dec(FColumn);
      #9: putRun(StringOfChar(WideChar(' '), 8-FColumn mod 8));
      #27: begin
        // the sequence ends at its final character; an unfinished one waits
        // for the next text
        if i = n then begin
          FEscape := #27;
          break;
        end;
        var kind := src[i+1];
        if kind = '[' then begin
          var j := i+2;
          while (j <= n) and not (src[j] in ['@'..'~']) do inc(j);
          if j > n then begin
            FEscape := Copy(src, i, n-i+1);
            break;
          end;
          var params := Copy(src, i+2, j-i-2);
          var count := Max(StrToIntDef(string(params), 1), 1);
          match src[j] of
            'm': applySgr(params);
            'K': eraseInLine(StrToIntDef(string(params), 0));
            'J': if StrToIntDef(string(params), 0) >= 2 then begin
              Clear;
              follow := true;
            end else eraseInLine(0);
            'G': FColumn := count-1;
            'C': FColumn += count;
            'D': FColumn := Max(FColumn-count, 0);
          else
            ;
          end;
          i := j+1;
          continue;
        end else if kind = ']' then begin
          // a title or another command for the window, up to BEL or ESC \
          var j := i+2;
          while (j <= n) and (src[j] <> #7) and not ((src[j] = #27) and (j < n) and (src[j+1] = '\')) do inc(j);
          if j > n then begin
            FEscape := Copy(src, i, n-i+1);
            break;
          end;
          i := if src[j] = #7 then j+1 else j+2;
          continue;
        end else if kind in ['(', ')'] then begin
          i += 3;
          continue;
        end;
        i += 2;
        continue;
      end;
    else
      ;
    end;
    inc(i);
  end;
  trimLines;
  contentChanged(follow);
end;

function TTerminalView.LineCount: integer;
begin
  result := FCount;
end;

function TTerminalView.Lines(index: integer): string;
begin
  result := UTF8Encode(FLines[index].text);
end;

function TTerminalView.Text: string;
begin
  var sb := autofree TStringList.Create;
  for var i := 0 to FCount-1 do sb.Add(Lines(i));
  // the line being written stays out while it is empty
  if (FCount > 0) and (FLines[FCount-1].text = '') then sb.Delete(sb.Count-1);
  result := sb.Text;
end;

procedure TTerminalView.SaveToFile(const fileName: string);
begin
  var sl := autofree TStringList.Create;
  sl.Text := Text;
  sl.SaveToFile(fileName);
end;

// -- selection ----------------------

function TTerminalView.hasSelection: boolean;
begin
  result := (FSelAnchor.X <> FSelCaret.X) or (FSelAnchor.Y <> FSelCaret.Y);
end;

procedure TTerminalView.orderedSelection(out a, b: TPoint);
begin
  if (FSelAnchor.Y < FSelCaret.Y) or ((FSelAnchor.Y = FSelCaret.Y) and (FSelAnchor.X <= FSelCaret.X)) then begin
    a := FSelAnchor;
    b := FSelCaret;
  end else begin
    a := FSelCaret;
    b := FSelAnchor;
  end;
end;

function TTerminalView.SelectedText: string;
begin
  result := '';
  if not hasSelection then exit;
  var a, b: TPoint;
  orderedSelection(a, b);
  for var y := a.Y to Min(b.Y, FCount-1) do begin
    var s := FLines[y].text;
    var from := if y = a.Y then a.X else 0;
    var upto := if y = b.Y then b.X else length(s);
    result += UTF8Encode(Copy(s, from+1, upto-from));
    if y < b.Y then result += LineEnding;
  end;
end;

procedure TTerminalView.SelectAll;
begin
  FSelAnchor := Point(0, 0);
  FSelCaret := Point(length(FLines[FCount-1].text), FCount-1);
  Invalidate;
end;

procedure TTerminalView.CopyToClipboard;
begin
  Clipboard.AsText := if hasSelection then SelectedText else Text;
end;

// the line and the character under a point of the client area
function TTerminalView.hit(X, Y: integer): TPoint;
begin
  var pad := scaled(self, FPadding);
  var row := Max((Y+VertScrollBar.Position-pad) div rowHeight, 0);
  var line := lineOfRow(Min(row, totalRows-1));
  var inLine := Min(row-FRowStart[line], rowsOf(line)-1);
  var col := EnsureRange((X-pad+cellWidth div 2) div cellWidth, 0, FCols);
  result := Point(Min(inLine*FCols+col, length(FLines[line].text)), line);
end;

// -- layout ----------------------

procedure TTerminalView.setupFont(c: TCanvas);
begin
  c.Font := Font;
  if FMonospace then c.Font.Name := monospaceFace;
  applyTextQuality(c);
end;

function TTerminalView.cellWidth: integer;
begin
  setupFont(Canvas);
  result := Max(Canvas.TextWidth('MMMMMMMMMM') div 10, 1);
end;

function TTerminalView.rowHeight: integer;
begin
  setupFont(Canvas);
  result := Canvas.TextHeight('Hg')+2;
end;

function TTerminalView.inputHeight: integer;
begin
  result := if FShowInput then rowHeight+scaled(self, 6) else 0;
end;

procedure TTerminalView.updateRange;
begin
  if not HandleAllocated then exit;
  VertScrollBar.Increment := rowHeight;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := totalRows*rowHeight+scaled(self, FPadding)*2+inputHeight;
end;

function TTerminalView.atEnd: boolean;
begin
  result := not HandleAllocated or (VertScrollBar.Position >= VertScrollBar.Range-VertScrollBar.Page-rowHeight);
end;

procedure TTerminalView.contentChanged(follow: boolean);
begin
  if not HandleAllocated then exit;
  updateRange;
  if follow and FAutoScroll then VertScrollBar.Position := Max(VertScrollBar.Range-VertScrollBar.Page, 0);
  Invalidate;
end;

procedure TTerminalView.ScrollToEnd;
begin
  updateRange;
  VertScrollBar.Position := Max(VertScrollBar.Range-VertScrollBar.Page, 0);
  Invalidate;
end;

// the columns stay the same whether the scroll bar shows or not, so the
// wrap does not flip it on and off
procedure TTerminalView.fitColumns;
begin
  if not HandleAllocated then exit;
  var w := ClientWidth;
  if not VertScrollBar.IsScrollBarVisible then w -= GetSystemMetrics(SM_CXVSCROLL);
  var cols := Max((w-2*scaled(self, FPadding)) div cellWidth, 10);
  if cols <> FCols then begin
    var follow := atEnd;
    FCols := cols;
    relayout;
    contentChanged(follow);
  end else updateRange;
  showInputCaret;
end;

procedure TTerminalView.DoOnResize;
begin
  inherited DoOnResize;
  fitColumns;
end;

procedure TTerminalView.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TTerminalView.WMVScroll(var Message: TLMVScroll);
begin
  inherited WMVScroll(Message);
  Invalidate;
end;

procedure TTerminalView.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  FCols := 0;
  fitColumns;
end;

// -- painting ----------------------

function TTerminalView.colorOf(value: longint; fallback: TColor): TColor;
begin
  if value < 0 then exit(fallback);
  if value and TERM_RGB <> 0 then exit(value and $FFFFFF);
  if value < 16 then begin
    var back := ColorToRGB(Color);
    exit(if isDark(back) then DARK_PALETTE[value] else LIGHT_PALETTE[value]);
  end;
  if value < 232 then begin
    var v := value-16;
    var level := function(c: integer): integer
    begin
      result := if c = 0 then 0 else 55+c*40;
    end;
    exit(RGBToColor(level(v div 36), level(v div 6 mod 6), level(v mod 6)));
  end;
  var gray := 8+(value-232)*10;
  result := RGBToColor(gray, gray, gray);
end;

procedure TTerminalView.Paint;
begin
  var back := ColorToRGB(Color);
  var fore := pick(FTextColor, clWindowText);
  var selBack := blend(back, clHighlight, 45);
  // the canvas origin already sits at the scroll position, so everything
  // paints in unscrolled coordinates and the view is the visible part
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := back;
  Canvas.FillRect(view);
  setupFont(Canvas);
  var cw := cellWidth;
  var h := rowHeight;
  var pad := scaled(self, FPadding);
  var a, b: TPoint;
  orderedSelection(a, b);
  var selecting := hasSelection;
  var firstRow := Max((view.Top-pad) div h, 0);
  if FCount > 0 then begin
    var line := lineOfRow(Min(firstRow, totalRows-1));
    while line < FCount do begin
      var s := FLines[line].text;
      var rows := rowsOf(line);
      for var r := 0 to rows-1 do begin
        var y := pad+(FRowStart[line]+r)*h;
        if y+h < view.Top then continue;
        if y > view.Bottom then break;
        var from := r*FCols;
        var upto := Min(from+FCols, length(s));
        var k := from;
        while k < upto do begin
          // a run of characters that look the same
          var attr := FLines[line].attrs[k];
          var inSel := selecting and (((line > a.Y) or ((line = a.Y) and (k >= a.X))) and ((line < b.Y) or ((line = b.Y) and (k < b.X))));
          var j := k+1;
          while j < upto do begin
            var other := FLines[line].attrs[j];
            var otherSel := selecting and (((line > a.Y) or ((line = a.Y) and (j >= a.X))) and ((line < b.Y) or ((line = b.Y) and (j < b.X))));
            if (other.fg <> attr.fg) or (other.bg <> attr.bg) or (other.style <> attr.style) or (otherSel <> inSel) then break;
            inc(j);
          end;
          var fg := colorOf(attr.fg, fore);
          var bg := colorOf(attr.bg, clNone);
          if attr.style and STYLE_INVERSE <> 0 then begin
            var t := fg;
            fg := if bg = clNone then back else bg;
            bg := t;
          end;
          if attr.style and STYLE_DIM <> 0 then fg := blend(fg, back, 45);
          if inSel then begin
            bg := selBack;
            fg := contrastText(selBack);
          end;
          var x := pad+(k-from)*cw;
          if bg <> clNone then begin
            Canvas.Brush.Style := bsSolid;
            Canvas.Brush.Color := bg;
            Canvas.FillRect(x, y, x+(j-k)*cw, y+h);
          end;
          var style: TFontStyles := [];
          if attr.style and STYLE_BOLD <> 0 then Include(style, fsBold);
          if attr.style and STYLE_ITALIC <> 0 then Include(style, fsItalic);
          if attr.style and STYLE_UNDERLINE <> 0 then Include(style, fsUnderline);
          Canvas.Font.Style := style;
          Canvas.Font.Color := fg;
          Canvas.Brush.Style := bsClear;
          Canvas.TextOut(x, y+1, UTF8Encode(Copy(s, k+1, j-k)));
          k := j;
        end;
      end;
      if pad+FRowStart[line]*h > view.Bottom then break;
      inc(line);
    end;
  end;
  Canvas.Font.Style := [];
  Canvas.Brush.Style := bsSolid;

  // the input line keeps to the bottom of the view
  if FShowInput then begin
    var ih := inputHeight;
    var box := Rect(view.Left, view.Bottom-ih, view.Right, view.Bottom);
    var inputBack := pick(FInputColor, blend(back, fore, 6));
    Canvas.Brush.Color := inputBack;
    Canvas.FillRect(box);
    Canvas.Pen.Color := blend(back, fore, 18);
    Canvas.Line(box.Left, box.Top, box.Right, box.Top);
    var ty := box.Top+(ih-h) div 2+1;
    Canvas.Brush.Style := bsClear;
    var promptText := if Running then '' else FPrompt;
    var x := pad;
    if promptText <> '' then begin
      Canvas.Font.Color := blend(fore, inputBack, 40);
      Canvas.TextOut(x, ty, promptText);
      x += Canvas.TextWidth(promptText);
    end;
    var shown := UTF8Copy(FInput, FInputShift+1, MaxInt);
    Canvas.Font.Color := fore;
    Canvas.TextOut(x, ty, shown);
    if Focused then begin
      var cx := x+Canvas.TextWidth(UTF8Copy(FInput, FInputShift+1, FInputCaret-FInputShift));
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := if ringEnabled then ringColor else fore;
      Canvas.FillRect(cx, ty, cx+Max(scaled(self, 2), 1), ty+h-2);
    end;
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- input ----------------------

// the input scrolls sideways so the caret stays in view
procedure TTerminalView.showInputCaret;
begin
  if not HandleAllocated then exit;
  setupFont(Canvas);
  var room := ClientWidth-2*scaled(self, FPadding)-Canvas.TextWidth(FPrompt)-cellWidth;
  if FInputCaret < FInputShift then FInputShift := FInputCaret;
  while (FInputShift < FInputCaret) and (Canvas.TextWidth(UTF8Copy(FInput, FInputShift+1, FInputCaret-FInputShift)) > room) do inc(FInputShift);
end;

procedure TTerminalView.insertInput(const s: string);
begin
  FInput := UTF8Copy(FInput, 1, FInputCaret)+s+UTF8Copy(FInput, FInputCaret+1, MaxInt);
  FInputCaret += UTF8Length(s);
  showInputCaret;
  Invalidate;
end;

procedure TTerminalView.submitInput;
begin
  var line := FInput;
  FInput := '';
  FInputCaret := 0;
  FInputShift := 0;
  if (line <> '') and ((FHistory.Count = 0) or (FHistory[FHistory.Count-1] <> line)) then FHistory.Add(line);
  FHistoryIndex := -1;
  if FEchoInput then begin
    if FColumn > 0 then newLine;
    Write(#27'[2m'+(if Running then '' else FPrompt)+#27'[22m'+line+LineEnding);
  end;
  ScrollToEnd;
  var handled := false;
  if Assigned(FOnInput) then FOnInput(self, line, handled);
  if not handled and Running then SendLine(line);
end;

procedure TTerminalView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then exit;
  var ctrl := ssCtrl in Shift;
  var len := UTF8Length(FInput);
  match Key of
    VK_C: if ctrl then begin
      if hasSelection then CopyToClipboard else Terminate;
    end else exit;
    VK_A: if ctrl then SelectAll else exit;
    VK_V: if ctrl then begin
      if not FShowInput then exit;
      // every pasted line but the last goes out as if typed
      var parts := Clipboard.AsText.Replace(#13#10, #10).Split([#10]);
      for var i := 0 to length(parts)-1 do begin
        insertInput(parts[i]);
        if i < length(parts)-1 then submitInput;
      end;
    end else exit;
    VK_RETURN: if FShowInput then submitInput else exit;
    VK_BACK: if FShowInput and (FInputCaret > 0) then begin
      FInput := UTF8Copy(FInput, 1, FInputCaret-1)+UTF8Copy(FInput, FInputCaret+1, MaxInt);
      dec(FInputCaret);
    end;
    VK_DELETE: if FShowInput and (FInputCaret < len) then FInput := UTF8Copy(FInput, 1, FInputCaret)+UTF8Copy(FInput, FInputCaret+2, MaxInt);
    VK_LEFT: if FInputCaret > 0 then dec(FInputCaret);
    VK_RIGHT: if FInputCaret < len then inc(FInputCaret);
    VK_HOME: if ctrl then VertScrollBar.Position := 0 else FInputCaret := 0;
    VK_END: if ctrl then ScrollToEnd else FInputCaret := len;
    VK_UP, VK_DOWN: if FHistory.Count > 0 then begin
      // the history from the newest line back
      if Key = VK_UP then
        FHistoryIndex := if FHistoryIndex < 0 then FHistory.Count-1 else Max(FHistoryIndex-1, 0)
      else if FHistoryIndex >= 0 then begin
        inc(FHistoryIndex);
        if FHistoryIndex >= FHistory.Count then FHistoryIndex := -1;
      end;
      FInput := if FHistoryIndex >= 0 then FHistory[FHistoryIndex] else '';
      FInputCaret := UTF8Length(FInput);
    end;
    VK_PRIOR: VertScrollBar.Position := VertScrollBar.Position-Max(ClientHeight-rowHeight, rowHeight);
    VK_NEXT: VertScrollBar.Position := VertScrollBar.Position+Max(ClientHeight-rowHeight, rowHeight);
    VK_ESCAPE: if FInput <> '' then begin
      FInput := '';
      FInputCaret := 0;
    end else exit;
  else
    exit;
  end;
  showInputCaret;
  Invalidate;
  Key := 0;
end;

procedure TTerminalView.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited UTF8KeyPress(UTF8Key);
  if (UTF8Key = '') or (UTF8Key[1] < ' ') or not FShowInput then exit;
  insertInput(UTF8Key);
  UTF8Key := '';
end;

procedure TTerminalView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanSetFocus and not Focused then SetFocus;
  if Button <> mbLeft then exit;
  if FShowInput and (Y >= ClientHeight-inputHeight) then begin
    // a click in the input line moves its caret
    setupFont(Canvas);
    var offset := X-scaled(self, FPadding)-(if Running then 0 else Canvas.TextWidth(FPrompt));
    var caret := FInputShift;
    while (caret < UTF8Length(FInput)) and (Canvas.TextWidth(UTF8Copy(FInput, FInputShift+1, caret-FInputShift+1))-cellWidth div 2 < offset) do inc(caret);
    FInputCaret := caret;
    Invalidate;
    exit;
  end;
  var p := hit(X, Y);
  if ssShift in Shift then FSelCaret := p
  else begin
    FSelAnchor := p;
    FSelCaret := p;
  end;
  FSelecting := true;
  MouseCapture := true;
  Invalidate;
end;

procedure TTerminalView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not FSelecting then exit;
  // dragging past an edge scrolls the view
  if Y < 0 then VertScrollBar.Position := VertScrollBar.Position-rowHeight
  else if Y > ClientHeight-inputHeight then VertScrollBar.Position := VertScrollBar.Position+rowHeight;
  var p := hit(X, EnsureRange(Y, 0, ClientHeight-inputHeight-1));
  if (p.X <> FSelCaret.X) or (p.Y <> FSelCaret.Y) then begin
    FSelCaret := p;
    Invalidate;
  end;
end;

procedure TTerminalView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FSelecting then begin
    FSelecting := false;
    MouseCapture := false;
  end;
end;

procedure TTerminalView.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TTerminalView.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

function TTerminalView.getMetric(index: integer): integer;
begin
  result := if index = 0 then FMaxLines else FPadding;
end;

procedure TTerminalView.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then begin
    FMaxLines := value;
    trimLines;
  end else FPadding := value;
  FCols := 0;
  fitColumns;
  Invalidate;
end;

function TTerminalView.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FRunInShell;
    1: FAutoScroll;
    2: FShowInput;
    3: FEchoInput;
    4: FMonospace;
  else
    FShowExitCode
  end;
end;

procedure TTerminalView.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FRunInShell := value;
    1: FAutoScroll := value;
    2: FShowInput := value;
    3: FEchoInput := value;
    4: FMonospace := value;
  else
    FShowExitCode := value;
  end;
  if index in [2, 4] then begin
    FCols := 0;
    fitColumns;
  end;
  Invalidate;
end;

function TTerminalView.getText(index: integer): string;
begin
  result := match index of
    0: FCommand;
    1: FWorkingDirectory;
    2: FPrompt;
  else
    FInput
  end;
end;

procedure TTerminalView.setText(index: integer; const value: string);
begin
  match index of
    0: FCommand := value;
    1: FWorkingDirectory := value;
    2: FPrompt := value;
  else
    begin
      FInput := value;
      FInputCaret := UTF8Length(value);
      FInputShift := 0;
      showInputCaret;
    end;
  end;
  Invalidate;
end;

function TTerminalView.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FTextColor else FInputColor;
end;

procedure TTerminalView.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FTextColor := value else FInputColor := value;
  Invalidate;
end;

end.
