{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit HexEditor;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint;

type
  THexPane = (hpHex, hpText);
  THexSelectEvent = procedure(Sender: TObject; start, count: int64) of object;

  { THexEditor }

  // bytes in hex and as text side by side: an offset column, a cursor
  // that types nibbles or characters over the bytes, a selection, insert
  // and delete, a search. The data lives in a stream of its own; load a
  // file or hand it bytes, then save what came out
  THexEditor = class(TScrollingWinControl)
  private
    FData: TMemoryStream;
    FBytesPerRow, FGroupSize, FAddressDigits, FPadding: integer;
    FCaret, FAnchor: int64; // the byte under the cursor and the other end of the selection
    FNibble: integer; // 0 the high half of the byte, 1 the low
    FPane: THexPane;
    FReadOnly, FShowAddress, FShowText, FUpperCase, FInsertMode, FModified, FShowHeader: boolean;
    FAddressColor, FHexColor, FTextColor, FSelectionColor, FCursorColor, FZeroColor, FBackColor, FGridColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FCharWidth, FLineHeight: integer;
    FDragging: boolean;
    FOnChange, FOnCursorMove: TNotifyEvent;
    FOnSelect: THexSelectEvent;
    procedure setBytesPerRow(value: integer);
    procedure setGroupSize(value: integer);
    procedure setAddressDigits(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setCaret(value: int64);
    function getByte(index: int64): byte;
    procedure setByte(index: int64; value: byte);
    function getSize: int64;
    procedure measure;
    function rowCount: int64;
    function headerPx: integer;
    function hexLeft: integer;
    function contentWidth: integer;
    function textLeft: integer;
    function rowOf(offset: int64): int64;
    function byteAt(x, y: integer; out pane: THexPane; out nibble: integer): int64;
    procedure updateRange;
    procedure ensureVisible;
    procedure moveCursor(offset: int64; extend: boolean);
    procedure changed;
    procedure typeNibble(value: byte);
    procedure typeChar(c: char);
  protected
    procedure Paint; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const fileName: string);
    procedure SaveToFile(const fileName: string);
    procedure LoadFromStream(stream: TStream);
    procedure SaveToStream(stream: TStream);
    // the bytes of a string, as they are
    procedure SetBytes(const bytes: string);
    function GetBytes: string;
    procedure Clear;
    // the selection as a range; none when count is 0
    procedure SelectRange(start, count: int64);
    procedure SelectAll;
    function SelectionStart: int64;
    function SelectionLength: int64;
    // the selected bytes as text
    function SelectedBytes: string;
    procedure DeleteSelection;
    // bytes put in at the cursor
    procedure InsertBytes(const bytes: string);
    // the next place the bytes occur after the cursor, -1 for none; found bytes get selected
    function Find(const bytes: string; fromStart: boolean = false): int64;
    // the next place the text occurs after the cursor
    function FindText(const text: string; fromStart: boolean = false): int64;
    property Data: TMemoryStream read FData;
    property Bytes[index: int64]: byte read getByte write setByte;
    property Size: int64 read getSize;
    property Caret: int64 read FCaret write setCaret;
    property Modified: boolean read FModified write FModified;
    // the pane the cursor is in: hex or text
    property Pane: THexPane read FPane write FPane;
  published
    property BytesPerRow: integer read FBytesPerRow write setBytesPerRow default 16;
    // a wider gap after every this many bytes, 0 for none
    property GroupSize: integer read FGroupSize write setGroupSize default 4;
    property AddressDigits: integer read FAddressDigits write setAddressDigits default 8;
    property ReadOnly: boolean index 0 read getFlag write setFlag default false;
    property ShowAddress: boolean index 1 read getFlag write setFlag default true;
    property ShowText: boolean index 2 read getFlag write setFlag default true;
    property UpperCase: boolean index 3 read getFlag write setFlag default true;
    // typing puts bytes in instead of over; Insert toggles it too
    property InsertMode: boolean index 4 read getFlag write setFlag default false;
    // the column numbers above the bytes
    property ShowHeader: boolean index 5 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property AddressColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property HexColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property SelectionColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property CursorColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    // zero bytes shown dimmer
    property ZeroColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCursorMove: TNotifyEvent read FOnCursorMove write FOnCursorMove;
    property OnSelect: THexSelectEvent read FOnSelect write FOnSelect;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsSingle;
    property Color default clWindow;
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
  Math, LCLIntf;

constructor THexEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FData := TMemoryStream.Create;
  FBytesPerRow := 16;
  FGroupSize := 4;
  FAddressDigits := 8;
  FPadding := 6;
  FShowAddress := true;
  FShowText := true;
  FUpperCase := true;
  FShowHeader := true;
  FAddressColor := clDefault;
  FHexColor := clDefault;
  FTextColor := clDefault;
  FSelectionColor := clDefault;
  FCursorColor := clDefault;
  FZeroColor := clDefault;
  FBackColor := clDefault;
  FGridColor := clDefault;
  FAntialiasing := asTheme;
  Color := clWindow;
  BorderStyle := bsSingle;
  TabStop := true;
  Font.Name := monospaceFontName;
  Font.Pitch := fpFixed;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Tracking := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor THexEditor.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

class function THexEditor.GetControlClassDefaultSize: TSize;
begin
  result.cx := 560;
  result.cy := 240;
end;

// -- data ----------------------

function THexEditor.getSize: int64;
begin
  result := FData.Size;
end;

function THexEditor.getByte(index: int64): byte;
begin
  result := 0;
  if (index < 0) or (index >= FData.Size) then exit;
  result := PByte(FData.Memory)[index];
end;

procedure THexEditor.setByte(index: int64; value: byte);
begin
  if (index < 0) or (index >= FData.Size) then exit;
  if PByte(FData.Memory)[index] = value then exit;
  PByte(FData.Memory)[index] := value;
  changed;
end;

procedure THexEditor.LoadFromFile(const fileName: string);
begin
  FData.LoadFromFile(fileName);
  FCaret := 0;
  FAnchor := 0;
  FNibble := 0;
  FModified := false;
  updateRange;
  Invalidate;
end;

procedure THexEditor.SaveToFile(const fileName: string);
begin
  FData.SaveToFile(fileName);
  FModified := false;
end;

procedure THexEditor.LoadFromStream(stream: TStream);
begin
  FData.Clear;
  FData.CopyFrom(stream, stream.Size-stream.Position);
  FCaret := 0;
  FAnchor := 0;
  FNibble := 0;
  FModified := false;
  updateRange;
  Invalidate;
end;

procedure THexEditor.SaveToStream(stream: TStream);
begin
  stream.CopyFrom(FData, 0);
  FModified := false;
end;

procedure THexEditor.SetBytes(const bytes: string);
begin
  FData.Clear;
  if bytes <> '' then FData.Write(bytes[1], length(bytes));
  FCaret := 0;
  FAnchor := 0;
  FNibble := 0;
  FModified := false;
  updateRange;
  Invalidate;
end;

function THexEditor.GetBytes: string;
begin
  SetLength(result, FData.Size);
  if FData.Size > 0 then Move(FData.Memory^, result[1], FData.Size);
end;

procedure THexEditor.Clear;
begin
  SetBytes('');
end;

procedure THexEditor.changed;
begin
  FModified := true;
  Invalidate;
  if Assigned(FOnChange) then FOnChange(self);
end;

// -- selection ----------------------

function THexEditor.SelectionStart: int64;
begin
  result := Min(FCaret, FAnchor);
end;

function THexEditor.SelectionLength: int64;
begin
  result := Abs(FCaret-FAnchor);
  if result > 0 then result := Min(result+1, FData.Size-SelectionStart);
end;

procedure THexEditor.SelectRange(start, count: int64);
begin
  if count <= 0 then begin
    setCursor(start);
    exit;
  end;
  FAnchor := EnsureRange(start, 0, Max(FData.Size-1, 0));
  FCaret := EnsureRange(start+count-1, 0, Max(FData.Size-1, 0));
  FNibble := 0;
  ensureVisible;
  Invalidate;
  if Assigned(FOnSelect) then FOnSelect(self, SelectionStart, SelectionLength);
end;

procedure THexEditor.SelectAll;
begin
  SelectRange(0, FData.Size);
end;

function THexEditor.SelectedBytes: string;
begin
  var n := SelectionLength;
  SetLength(result, n);
  if n > 0 then Move(PByte(FData.Memory)[SelectionStart], result[1], n);
end;

procedure THexEditor.DeleteSelection;
begin
  if FReadOnly then exit;
  var n := SelectionLength;
  if n = 0 then exit;
  var start := SelectionStart;
  var tail := FData.Size-start-n;
  if tail > 0 then Move(PByte(FData.Memory)[start+n], PByte(FData.Memory)[start], tail);
  FData.SetSize(FData.Size-n);
  FCaret := Min(start, Max(FData.Size-1, 0));
  FAnchor := FCaret;
  FNibble := 0;
  updateRange;
  changed;
end;

procedure THexEditor.InsertBytes(const bytes: string);
begin
  if FReadOnly or (bytes = '') then exit;
  if SelectionLength > 0 then DeleteSelection;
  var at := Min(FCaret, FData.Size);
  var n := length(bytes);
  FData.SetSize(FData.Size+n);
  var tail := FData.Size-n-at;
  if tail > 0 then Move(PByte(FData.Memory)[at], PByte(FData.Memory)[at+n], tail);
  Move(bytes[1], PByte(FData.Memory)[at], n);
  FCaret := at+n;
  if FCaret >= FData.Size then FCaret := FData.Size-1;
  FAnchor := FCaret;
  FNibble := 0;
  updateRange;
  changed;
end;

function THexEditor.Find(const bytes: string; fromStart: boolean): int64;
begin
  result := -1;
  var n := length(bytes);
  if (n = 0) or (FData.Size < n) then exit;
  var from := if fromStart then 0 else SelectionStart+1;
  var p := PByte(FData.Memory);
  for var i := from to FData.Size-n do
    if CompareByte(p[i], bytes[1], n) = 0 then begin
      SelectRange(i, n);
      exit(i);
    end;
end;

function THexEditor.FindText(const text: string; fromStart: boolean): int64;
begin
  result := Find(text, fromStart);
end;

// -- geometry ----------------------

procedure THexEditor.measure;
begin
  if not HandleAllocated then exit;
  Canvas.Font := Font;
  applyTextQuality(Canvas);
  FCharWidth := Max(Canvas.TextWidth('0'), 1);
  FLineHeight := Canvas.TextHeight('0')+scaled(self, 2);
end;

function THexEditor.headerPx: integer;
begin
  result := if FShowHeader then FLineHeight+scaled(self, 4) else 0;
end;

function THexEditor.rowCount: int64;
begin
  result := (FData.Size+FBytesPerRow-1) div FBytesPerRow;
  if FData.Size mod FBytesPerRow = 0 then inc(result); // the row after the end takes the cursor
end;

function THexEditor.hexLeft: integer;
begin
  result := scaled(self, FPadding);
  if FShowAddress then result += (FAddressDigits+2)*FCharWidth;
end;

function THexEditor.textLeft: integer;
begin
  var groups := if FGroupSize > 0 then (FBytesPerRow-1) div FGroupSize else 0;
  result := hexLeft+(FBytesPerRow*3+groups)*FCharWidth+FCharWidth;
end;

// the width of a row with the padding on both sides
function THexEditor.contentWidth: integer;
begin
  result := textLeft+(if FShowText then FBytesPerRow*FCharWidth else 0)+scaled(self, FPadding);
end;

function THexEditor.rowOf(offset: int64): int64;
begin
  result := offset div FBytesPerRow;
end;

// the x of the hex pair of the byte in its row
function hexX(editor: THexEditor; column: integer): integer;
begin
  var groups := if editor.FGroupSize > 0 then column div editor.FGroupSize else 0;
  result := editor.hexLeft+(column*3+groups)*editor.FCharWidth;
end;

function THexEditor.byteAt(x, y: integer; out pane: THexPane; out nibble: integer): int64;
begin
  result := -1;
  pane := hpHex;
  nibble := 0;
  if FLineHeight = 0 then exit;
  inc(x, HorzScrollBar.Position);
  var row := (y+VertScrollBar.Position-scaled(self, FPadding)-headerPx) div FLineHeight;
  if row < 0 then row := 0;
  var column := -1;
  if FShowText and (x >= textLeft) then begin
    pane := hpText;
    column := (x-textLeft) div FCharWidth;
  end else if x >= hexLeft then begin
    for var c := FBytesPerRow-1 downto 0 do
      if x >= hexX(self, c) then begin
        column := c;
        nibble := if x >= hexX(self, c)+FCharWidth then 1 else 0;
        break;
      end;
  end else column := 0;
  if column < 0 then column := 0;
  if column >= FBytesPerRow then column := FBytesPerRow-1;
  result := row*FBytesPerRow+column;
  if result > FData.Size then result := FData.Size;
  if (result = FData.Size) and (FData.Size > 0) and (row < rowOf(FData.Size)) then result := FData.Size-1;
end;

procedure THexEditor.updateRange;
begin
  if not HandleAllocated then exit;
  measure;
  VertScrollBar.Increment := FLineHeight;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := headerPx+rowCount*FLineHeight+scaled(self, FPadding)*2;
  HorzScrollBar.Increment := FCharWidth;
  HorzScrollBar.Page := Max(ClientWidth, 1);
  HorzScrollBar.Range := contentWidth;
end;

procedure THexEditor.ensureVisible;
begin
  if not HandleAllocated or (FLineHeight = 0) then exit;
  var y := headerPx+rowOf(FCaret)*FLineHeight+scaled(self, FPadding);
  if y-headerPx < VertScrollBar.Position then VertScrollBar.Position := y-headerPx
  else if y+FLineHeight > VertScrollBar.Position+ClientHeight then VertScrollBar.Position := y+FLineHeight-ClientHeight;
  var column := integer(FCaret mod FBytesPerRow);
  var x := if FPane = hpText then textLeft+column*FCharWidth else hexX(self, column);
  var w := if FPane = hpText then FCharWidth else FCharWidth*2;
  if x < HorzScrollBar.Position then HorzScrollBar.Position := x-scaled(self, FPadding)
  else if x+w > HorzScrollBar.Position+ClientWidth then HorzScrollBar.Position := x+w-ClientWidth;
end;

procedure THexEditor.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure THexEditor.Resize;
begin
  inherited Resize;
  updateRange;
  Invalidate;
end;

procedure THexEditor.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

// -- painting ----------------------

procedure THexEditor.Paint;
begin
  measure;
  var back := pick(FBackColor, Color);
  var address := pick(FAddressColor, blend(clWindowText, back, 45));
  var hex := pick(FHexColor, clWindowText);
  var text := pick(FTextColor, clWindowText);
  var zero := pick(FZeroColor, blend(clWindowText, back, 60));
  var selection := pick(FSelectionColor, blend(back, clHighlight, 40));
  // the other pane shows the selection in a muted tone
  var mirror := blend(back, clHighlight, 18);
  var caretColor := pick(FCursorColor, clHighlight);
  var grid := pick(FGridColor, blend(back, clWindowText, 12));
  var header := blend(back, clWindowText, 7);
  var view := ClientRect;
  OffsetRect(view, HorzScrollBar.Position, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var pad := scaled(self, FPadding);
  var hh := headerPx;
  var cw := FCharWidth;
  var lh := FLineHeight;
  var first := Max((VertScrollBar.Position-pad-hh) div lh, 0);
  var last := Min((VertScrollBar.Position+ClientHeight-pad-hh) div lh, rowCount-1);
  var selStart := SelectionStart;
  var selEnd := selStart+SelectionLength-1;
  var hasSel := SelectionLength > 0;
  // the lines between the columns
  if FShowAddress then sp.FillRect(Rect(hexLeft-cw, view.Top, hexLeft-cw+1, view.Bottom), grid);
  if FShowText then sp.FillRect(Rect(textLeft-cw div 2, view.Top, textLeft-cw div 2+1, view.Bottom), grid);
  for var row := first to last do begin
    var y := pad+hh+row*lh;
    for var c := 0 to FBytesPerRow-1 do begin
      var offset := row*FBytesPerRow+c;
      if offset > FData.Size then break;
      var hx := hexX(self, c);
      var tx := textLeft+c*cw;
      var hexCell := Rect(hx, y, hx+2*cw, y+lh);
      var textCell := Rect(tx, y, tx+cw, y+lh);
      if hasSel and (offset >= selStart) and (offset <= selEnd) then begin
        var hexFill := if FPane = hpHex then selection else mirror;
        var textFill := if FPane = hpText then selection else mirror;
        // the gap after the pair joins the selection so a run reads as one block
        sp.FillRect(Rect(hx, y, hx+2*cw+(if (c < FBytesPerRow-1) and (offset < selEnd) then cw else 0), y+lh), hexFill);
        if FShowText then sp.FillRect(textCell, textFill);
      end;
      if offset = FCaret then begin
        // the active pane carries a block, the other pane frames the same byte
        if Focused then begin
          if FPane = hpHex then begin
            sp.FillRect(Rect(hx+FNibble*cw, y, hx+(FNibble+1)*cw, y+lh), caretColor);
            if FShowText then sp.FrameRoundRect(textCell.Left, textCell.Top, textCell.Right, textCell.Bottom, 0, 1, caretColor);
          end else begin
            sp.FillRect(textCell, caretColor);
            sp.FrameRoundRect(hexCell.Left, hexCell.Top, hexCell.Right, hexCell.Bottom, 0, 1, caretColor);
          end;
        end else begin
          sp.FrameRoundRect(hexCell.Left, hexCell.Top, hexCell.Right, hexCell.Bottom, 0, 1, blend(caretColor, back, 40));
          if FShowText then sp.FrameRoundRect(textCell.Left, textCell.Top, textCell.Right, textCell.Bottom, 0, 1, blend(caretColor, back, 40));
        end;
      end;
    end;
  end;
  // the header stays on top
  if hh > 0 then begin
    sp.FillRect(Rect(view.Left, view.Top, view.Right, view.Top+hh), header);
    sp.FillRect(Rect(view.Left, view.Top+hh-1, view.Right, view.Top+hh), grid);
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Font := Font;
  Canvas.Brush.Style := bsClear;
  var digits := if FUpperCase then '0123456789ABCDEF' else '0123456789abcdef';
  Canvas.Clipping := true;
  Canvas.ClipRect := Rect(view.Left, view.Top+hh, view.Right, view.Bottom);
  for var row := first to last do begin
    var y := pad+hh+row*lh;
    if FShowAddress then begin
      Canvas.Font.Color := address;
      Canvas.TextOut(pad, y, IntToHex(row*FBytesPerRow, FAddressDigits));
    end;
    for var c := 0 to FBytesPerRow-1 do begin
      var offset := row*FBytesPerRow+c;
      if offset >= FData.Size then break;
      var b := PByte(FData.Memory)[offset];
      var onCaret := (offset = FCaret) and Focused;
      Canvas.Font.Color := if b = 0 then zero else hex;
      var pair := digits[b shr 4+1]+digits[b and 15+1];
      var hx := hexX(self, c);
      if onCaret and (FPane = hpHex) then begin
        Canvas.TextOut(hx, y, pair[1]);
        Canvas.TextOut(hx+cw, y, pair[2]);
        Canvas.Font.Color := contrastText(caretColor);
        Canvas.TextOut(hx+FNibble*cw, y, pair[FNibble+1]);
      end else Canvas.TextOut(hx, y, pair);
      if FShowText then begin
        var ch := if (b >= 32) and (b < 127) then chr(b) else '.';
        Canvas.Font.Color := if onCaret and (FPane = hpText) then contrastText(caretColor) else if b = 0 then zero else text;
        Canvas.TextOut(textLeft+c*cw, y, ch);
      end;
    end;
  end;
  Canvas.Clipping := false;
  if hh > 0 then begin
    // the column numbers over the bytes, the names of the panes
    Canvas.Font.Color := address;
    var hy := view.Top+scaled(self, 2);
    if FShowAddress then Canvas.TextOut(pad, hy, 'Offset');
    for var c := 0 to FBytesPerRow-1 do Canvas.TextOut(hexX(self, c), hy, digits[c shr 4+1]+digits[c and 15+1]);
    if FShowText then Canvas.TextOut(textLeft, hy, 'Text');
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure THexEditor.setCaret(value: int64);
begin
  moveCursor(value, false);
end;

procedure THexEditor.moveCursor(offset: int64; extend: boolean);
begin
  offset := EnsureRange(offset, 0, FData.Size);
  if (offset = FData.Size) and (FData.Size > 0) and not FInsertMode then offset := FData.Size-1;
  var hadSel := SelectionLength > 0;
  FCaret := offset;
  if not extend then FAnchor := offset;
  FNibble := 0;
  ensureVisible;
  Invalidate;
  if Assigned(FOnCursorMove) then FOnCursorMove(self);
  if (hadSel or extend) and Assigned(FOnSelect) then FOnSelect(self, SelectionStart, SelectionLength);
end;

procedure THexEditor.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  var pane: THexPane;
  var nibble: integer;
  var offset := byteAt(X, Y, pane, nibble);
  if offset < 0 then exit;
  if FShowText or (pane = hpHex) then FPane := pane;
  moveCursor(offset, ssShift in Shift);
  if (FPane = hpHex) and (offset < FData.Size) then FNibble := nibble;
  FDragging := true;
  Invalidate;
end;

procedure THexEditor.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging or not (ssLeft in Shift) then exit;
  var pane: THexPane;
  var nibble: integer;
  var offset := byteAt(X, Y, pane, nibble);
  if (offset >= 0) and (offset <> FCaret) then moveCursor(offset, true);
end;

procedure THexEditor.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragging := false;
end;

procedure THexEditor.typeNibble(value: byte);
begin
  if FReadOnly then exit;
  if (FCaret >= FData.Size) or (FInsertMode and (FNibble = 0)) then begin
    // a new byte comes in
    if FCaret >= FData.Size then begin
      FData.SetSize(FData.Size+1);
      PByte(FData.Memory)[FData.Size-1] := value shl 4;
      FCaret := FData.Size-1;
    end else begin
      var at := FCaret;
      FData.SetSize(FData.Size+1);
      Move(PByte(FData.Memory)[at], PByte(FData.Memory)[at+1], FData.Size-1-at);
      PByte(FData.Memory)[at] := value shl 4;
    end;
    FAnchor := FCaret;
    FNibble := 1;
    updateRange;
    changed;
    exit;
  end;
  var b := PByte(FData.Memory)[FCaret];
  if FNibble = 0 then b := (b and $0F) or (value shl 4) else b := (b and $F0) or value;
  PByte(FData.Memory)[FCaret] := b;
  if FNibble = 0 then FNibble := 1
  else begin
    FNibble := 0;
    FCaret := Min(FCaret+1, FData.Size);
    if (FCaret = FData.Size) and not FInsertMode then FCaret := FData.Size-1;
  end;
  FAnchor := FCaret;
  ensureVisible;
  changed;
end;

procedure THexEditor.typeChar(c: char);
begin
  if FReadOnly then exit;
  if FInsertMode or (FCaret >= FData.Size) then begin
    InsertBytes(c);
    exit;
  end;
  PByte(FData.Memory)[FCaret] := ord(c);
  FCaret := Min(FCaret+1, FData.Size-1);
  FAnchor := FCaret;
  ensureVisible;
  changed;
end;

procedure THexEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var extend := ssShift in Shift;
  var rowsPage := Max(ClientHeight div Max(FLineHeight, 1), 1);
  match Key of
    VK_LEFT: if (FPane = hpHex) and (FNibble = 1) and not extend then begin FNibble := 0; Invalidate; end else moveCursor(FCaret-1, extend);
    VK_RIGHT: moveCursor(FCaret+1, extend);
    VK_UP: moveCursor(FCaret-FBytesPerRow, extend);
    VK_DOWN: moveCursor(FCaret+FBytesPerRow, extend);
    VK_HOME: if ssCtrl in Shift then moveCursor(0, extend) else moveCursor(FCaret-FCaret mod FBytesPerRow, extend);
    VK_END: if ssCtrl in Shift then moveCursor(FData.Size, extend) else moveCursor(FCaret-FCaret mod FBytesPerRow+FBytesPerRow-1, extend);
    VK_PRIOR: moveCursor(FCaret-rowsPage*FBytesPerRow, extend);
    VK_NEXT: moveCursor(FCaret+rowsPage*FBytesPerRow, extend);
    VK_TAB: begin
      if FShowText then FPane := if FPane = hpHex then hpText else hpHex;
      FNibble := 0;
      Invalidate;
    end;
    VK_INSERT: begin FInsertMode := not FInsertMode; Invalidate; end;
    VK_DELETE: begin
      if SelectionLength > 0 then DeleteSelection
      else if not FReadOnly and (FCaret < FData.Size) then begin FAnchor := FCaret; SelectRange(FCaret, 1); DeleteSelection; end;
    end;
    VK_BACK: begin
      if SelectionLength > 0 then DeleteSelection
      else if not FReadOnly and (FCaret > 0) then begin SelectRange(FCaret-1, 1); DeleteSelection; end;
    end;
    VK_A: if ssCtrl in Shift then SelectAll else exit;
  else
    exit;
  end;
  Key := 0;
end;

procedure THexEditor.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited UTF8KeyPress(UTF8Key);
  if (length(UTF8Key) <> 1) or (UTF8Key[1] < ' ') then exit;
  var c := UTF8Key[1];
  if FPane = hpHex then begin
    var v := Pos(LowerCase(c), '0123456789abcdef')-1;
    if v < 0 then exit;
    typeNibble(v);
  end else typeChar(c);
  UTF8Key := '';
end;

procedure THexEditor.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure THexEditor.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

procedure THexEditor.setBytesPerRow(value: integer);
begin
  value := EnsureRange(value, 1, 64);
  if FBytesPerRow = value then exit;
  FBytesPerRow := value;
  updateRange;
  Invalidate;
end;

procedure THexEditor.setGroupSize(value: integer);
begin
  value := Max(value, 0);
  if FGroupSize = value then exit;
  FGroupSize := value;
  Invalidate;
end;

procedure THexEditor.setAddressDigits(value: integer);
begin
  value := EnsureRange(value, 2, 16);
  if FAddressDigits = value then exit;
  FAddressDigits := value;
  Invalidate;
end;

function THexEditor.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FReadOnly;
    1: FShowAddress;
    2: FShowText;
    3: FUpperCase;
    4: FInsertMode;
  else
    FShowHeader
  end;
end;

procedure THexEditor.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FReadOnly := value;
    1: FShowAddress := value;
    2: FShowText := value;
    3: FUpperCase := value;
    4: FInsertMode := value;
  else
    FShowHeader := value;
  end;
  updateRange;
  if not FShowText then FPane := hpHex;
  Invalidate;
end;

function THexEditor.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FAddressColor;
    1: FHexColor;
    2: FTextColor;
    3: FSelectionColor;
    4: FCursorColor;
    5: FZeroColor;
    6: FBackColor;
  else
    FGridColor
  end;
end;

procedure THexEditor.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FAddressColor := value;
    1: FHexColor := value;
    2: FTextColor := value;
    3: FSelectionColor := value;
    4: FCursorColor := value;
    5: FZeroColor := value;
    6: FBackColor := value;
  else
    FGridColor := value;
  end;
  Invalidate;
end;

procedure THexEditor.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
