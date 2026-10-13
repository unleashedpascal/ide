{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit DiffView;

{$mode unleashed}
{$pointermath on}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint;

type
  TDiffKind = (dkSame, dkAdded, dkRemoved, dkChanged);
  // two panes with the change map between them, or one pane the way a
  // patch reads with the map on the right
  TDiffLayout = (dlSideBySide, dlUnified);
  TDiffLineEvent = procedure(Sender: TObject; row: integer; kind: TDiffKind) of object;

  // a stretch of a line that differs from its pair: dkChanged where the
  // other line has a counterpart, dkRemoved or dkAdded where it has none
  TDiffSpan = record
    start, length: integer; // characters, from 1
    kind: TDiffKind;
  end;
  TDiffSpans = array of TDiffSpan;

  // one aligned span of a sequence comparison
  TDiffSeqOp = record
    kind: TDiffKind;
    aPos, aLen, bPos, bLen: integer;
  end;
  PDiffSeqOp = ^TDiffSeqOp;
  TDiffSeqOps = array of TDiffSeqOp;

  { TDiffView }

  // two texts compared line by line, the lines aligned by patience and
  // Myers, the words that differ inside a changed pair marked on their
  // own: side by side with the change map between the panes, or as one
  // unified listing with the map at the edge. The unchanged lines can fold
  // away to a few of context, a hunk is a run of differences
  TDiffView = class(TScrollingWinControl)
  private
    type
      TRow = record
        kind: TDiffKind;
        leftIndex, rightIndex: integer; // the line of each side, -1 for a gap
        leftSpans, rightSpans: TDiffSpans;
        spansDone: boolean;
      end;
      // what one display line shows: a row on one or both sides, or a fold
      TShown = record
        row: integer;
        side: integer; // 0 the left line, 1 the right line, 2 both
        folded: integer; // the number of rows hidden behind a fold marker, 0 otherwise
      end;
    var
    FLeft, FRight: TStrings;
    FRows: array of TRow;
    FShown: array of TShown;
    FHunks: array of integer; // the first shown line of every hunk
    FLayout: TDiffLayout;
    FShowLineNumbers, FIgnoreWhitespace, FIgnoreCase, FWordDiff, FShowGutter, FHideSame, FShowChangeMap, FShowHeader: boolean;
    FContextLines, FPadding, FTabWidth, FMapWidth: integer;
    FAddedColor, FRemovedColor, FChangedColor, FBackColor, FTextColor, FNumberColor, FMarkColor, FGutterColor, FHeaderColor, FFoldColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FHot, FActive, FCurrentHunk: integer;
    FLineHeight, FCharWidth, FNumberWidth: integer;
    FMapDrag, FRangeDirty: boolean;
    FOnRowClick: TDiffLineEvent;
    FOnChange: TNotifyEvent;
    procedure setSide(index: integer; value: TStrings);
    procedure sideChanged(Sender: TObject);
    procedure setLayout(value: TDiffLayout);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function hashLine(const s: string): QWord;
    procedure compare;
    procedure buildShown;
    procedure ensureSpans(var row: TRow);
    function expanded(const s: string): string;
    function kindColor(kind: TDiffKind): TColor;
    function strongColor(kind: TDiffKind): TColor;
    function headerPx: integer;
    function mapPx: integer;
    function mapRect: TRect;
    function lineAt(y: integer): integer;
    procedure measure;
    procedure updateRange;
    procedure scrollMap(y: integer);
    procedure showLine(index: integer);
    procedure panes(out leftX, leftRight, rightX, rightRight: integer);
  protected
    procedure Paint; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetTexts(const leftText, rightText: string);
    procedure LoadFromFiles(const leftFile, rightFile: string);
    // the aligned rows, the hunks and the rows of each kind
    function RowCount: integer;
    function HunkCount: integer;
    function CountOf(kind: TDiffKind): integer;
    // the kind and the lines of an aligned row; -1 for a side without a line
    procedure RowInfo(row: integer; out kind: TDiffKind; out leftLine, rightLine: integer);
    procedure NextHunk;
    procedure PreviousHunk;
    procedure GoToHunk(index: integer);
    // the diff as a patch
    procedure SaveToStrings(lines: TStrings; context: integer = 3);
    // the words that differ in a changed row, for either side
    function SpansOf(row: integer; leftSide: boolean): TDiffSpans;
    property CurrentHunk: integer read FCurrentHunk;
  published
    property LeftText: TStrings index 0 read FLeft write setSide;
    property RightText: TStrings index 1 read FRight write setSide;
    property Layout: TDiffLayout read FLayout write setLayout default dlSideBySide;
    property ShowLineNumbers: boolean index 0 read getFlag write setFlag default true;
    property IgnoreWhitespace: boolean index 1 read getFlag write setFlag default false;
    property IgnoreCase: boolean index 2 read getFlag write setFlag default false;
    // the words that differ inside a changed pair get their own mark
    property WordDiff: boolean index 3 read getFlag write setFlag default true;
    // the strip on the left with a mark per kind
    property ShowGutter: boolean index 4 read getFlag write setFlag default false;
    // unchanged lines beyond the context of a hunk fold away
    property HideSame: boolean index 5 read getFlag write setFlag default false;
    // the change map: between the panes, or at the edge of the single pane
    property ShowChangeMap: boolean index 6 read getFlag write setFlag default true;
    property ShowHeader: boolean index 7 read getFlag write setFlag default true;
    property ContextLines: integer index 0 read getMetric write setMetric default 3;
    property Padding: integer index 1 read getMetric write setMetric default 4;
    property TabWidth: integer index 2 read getMetric write setMetric default 4;
    property MapWidth: integer index 3 read getMetric write setMetric default 24;
    // clDefault takes the colors of the theme
    property AddedColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property RemovedColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property ChangedColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property NumberColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    // the words that differ, when MarkColor is set; clDefault takes a stronger tone of the kind
    property MarkColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property GutterColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property HeaderColor: TColor index 8 read getPartColor write setPartColor default clDefault;
    property FoldColor: TColor index 9 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnRowClick: TDiffLineEvent read FOnRowClick write FOnRowClick;
    // the texts changed and the comparison ran again
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
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
  Math;

const
  FNV_OFFSET = QWord($CBF29CE484222325);
  FNV_PRIME = QWord($100000001B3);
  MYERS_MAX_D = 2000;
  // the share of a line the changed words may take before the whole line
  // is marked instead
  MAX_CHANGED_RATIO = 0.7;

// -- the sequence diff: patience anchors on keys unique to both sides, Myers between them ----------------------

type

  TStep = record
    kind: TDiffKind;
    ax, by, len: integer;
  end;

  TSeqDiffer = record
    a, b: PQWord;
    ops: TDiffSeqOps;
    count: integer;
    procedure emit(kind: TDiffKind; aPos, aCount, bPos, bCount: integer);
    procedure emitGap(aPos, aCount, bPos, bCount: integer);
    procedure diffRange(aLo, aHi, bLo, bHi: integer);
    function patience(aLo, aHi, bLo, bHi: integer): boolean;
    function myers(aLo, aHi, bLo, bHi: integer): boolean;
    function finish: TDiffSeqOps;
  end;

procedure TSeqDiffer.emit(kind: TDiffKind; aPos, aCount, bPos, bCount: integer);
begin
  if (aCount = 0) and (bCount = 0) then exit;
  if count > 0 then begin
    var last: PDiffSeqOp := @ops[count-1];
    if (last^.kind = kind) and (last^.aPos+last^.aLen = aPos) and (last^.bPos+last^.bLen = bPos) then begin
      last^.aLen += aCount;
      last^.bLen += bCount;
      exit;
    end;
  end;
  if count = length(ops) then SetLength(ops, count*2+64);
  ops[count].kind := kind;
  ops[count].aPos := aPos;
  ops[count].aLen := aCount;
  ops[count].bPos := bPos;
  ops[count].bLen := bCount;
  inc(count);
end;

procedure TSeqDiffer.emitGap(aPos, aCount, bPos, bCount: integer);
begin
  if (aCount = 0) and (bCount = 0) then exit;
  if aCount = 0 then emit(dkAdded, aPos, 0, bPos, bCount)
  else if bCount = 0 then emit(dkRemoved, aPos, aCount, bPos, 0)
  else emit(dkChanged, aPos, aCount, bPos, bCount);
end;

procedure TSeqDiffer.diffRange(aLo, aHi, bLo, bHi: integer);
begin
  var pre := 0;
  while (aLo+pre < aHi) and (bLo+pre < bHi) and (a[aLo+pre] = b[bLo+pre]) do inc(pre);
  emit(dkSame, aLo, pre, bLo, pre);
  aLo += pre;
  bLo += pre;
  var suf := 0;
  while (aHi-suf > aLo) and (bHi-suf > bLo) and (a[aHi-suf-1] = b[bHi-suf-1]) do inc(suf);
  aHi -= suf;
  bHi -= suf;
  if (aHi > aLo) and (bHi > bLo) then begin
    if not patience(aLo, aHi, bLo, bHi) then if not myers(aLo, aHi, bLo, bHi) then emitGap(aLo, aHi-aLo, bLo, bHi-bLo);
  end else emitGap(aLo, aHi-aLo, bLo, bHi-bLo);
  emit(dkSame, aHi, suf, bHi, suf);
end;

function TSeqDiffer.patience(aLo, aHi, bLo, bHi: integer): boolean;
var
  keys: array of QWord;
  countA, countB, idxA, idxB: array of integer;
  bits, mask: integer;

  // the multiplication wraps around on purpose
  {$push}{$Q-}{$R-}
  function slotOf(key: QWord): integer;
  begin
    result := integer((key*QWord($9E3779B97F4A7C15)) shr (64-bits));
    while ((countA[result] <> 0) or (countB[result] <> 0)) and (keys[result] <> key) do result := (result+1) and mask;
    keys[result] := key;
  end;
  {$pop}

begin
  result := false;
  var n := (aHi-aLo)+(bHi-bLo);
  bits := 4;
  while (1 shl bits) < n*2 do inc(bits);
  mask := (1 shl bits)-1;
  SetLength(keys, mask+1);
  SetLength(countA, mask+1);
  SetLength(countB, mask+1);
  SetLength(idxA, mask+1);
  SetLength(idxB, mask+1);
  for var i := aLo to aHi-1 do begin
    var s := slotOf(a[i]);
    inc(countA[s]);
    idxA[s] := i;
  end;
  for var j := bLo to bHi-1 do begin
    var s := slotOf(b[j]);
    inc(countB[s]);
    idxB[s] := j;
  end;
  // the pairs unique on both sides, in a-order
  var pairA, pairB: array of integer;
  var np := 0;
  for var i := aLo to aHi-1 do begin
    var s := slotOf(a[i]);
    if (countA[s] <> 1) or (countB[s] <> 1) then continue;
    if np = length(pairA) then begin
      SetLength(pairA, np*2+16);
      SetLength(pairB, np*2+16);
    end;
    pairA[np] := i;
    pairB[np] := idxB[s];
    inc(np);
  end;
  if np = 0 then exit;
  // the longest increasing run of the b positions
  var tails, tailIdx, prev: array of integer;
  SetLength(tails, np);
  SetLength(tailIdx, np);
  SetLength(prev, np);
  var lisLen := 0;
  for var p := 0 to np-1 do begin
    var lo := 0;
    var hi := lisLen;
    while lo < hi do begin
      var mid := (lo+hi) div 2;
      if tails[mid] < pairB[p] then lo := mid+1 else hi := mid;
    end;
    tails[lo] := pairB[p];
    tailIdx[lo] := p;
    prev[p] := if lo > 0 then tailIdx[lo-1] else -1;
    if lo = lisLen then inc(lisLen);
  end;
  var anchors: array of integer;
  SetLength(anchors, lisLen);
  var p := tailIdx[lisLen-1];
  for var i := lisLen-1 downto 0 do begin
    anchors[i] := p;
    p := prev[p];
  end;
  var pa := aLo;
  var pb := bLo;
  for var i := 0 to lisLen-1 do begin
    var ai := pairA[anchors[i]];
    var bi := pairB[anchors[i]];
    diffRange(pa, ai, pb, bi);
    emit(dkSame, ai, 1, bi, 1);
    pa := ai+1;
    pb := bi+1;
  end;
  diffRange(pa, aHi, pb, bHi);
  result := true;
end;

function TSeqDiffer.myers(aLo, aHi, bLo, bHi: integer): boolean;
var
  steps: array of TStep;
  ns: integer;

  procedure push(kind: TDiffKind; ax, by, len: integer);
  begin
    if ns = length(steps) then SetLength(steps, ns*2+16);
    steps[ns].kind := kind;
    steps[ns].ax := ax;
    steps[ns].by := by;
    steps[ns].len := len;
    inc(ns);
  end;

begin
  result := false;
  ns := 0;
  var n := aHi-aLo;
  var m := bHi-bLo;
  var maxD := n+m;
  if maxD > MYERS_MAX_D then maxD := MYERS_MAX_D;
  var offset := maxD+1;
  var v: array of integer;
  SetLength(v, 2*maxD+3);
  var trace: array of array of integer;
  SetLength(trace, maxD+1);
  v[offset+1] := 0;
  var found := false;
  var dFound := 0;
  for var d := 0 to maxD do begin
    var k := -d;
    while k <= d do begin
      var x: integer;
      if (k = -d) or ((k <> d) and (v[offset+k-1] < v[offset+k+1])) then x := v[offset+k+1] else x := v[offset+k-1]+1;
      var y := x-k;
      while (x < n) and (y < m) and (a[aLo+x] = b[bLo+y]) do begin
        inc(x);
        inc(y);
      end;
      v[offset+k] := x;
      if (x >= n) and (y >= m) then begin
        found := true;
        dFound := d;
        break;
      end;
      k += 2;
    end;
    trace[d] := Copy(v, offset-d-1, 2*d+3);
    if found then break;
  end;
  if not found then exit;
  var x := n;
  var y := m;
  for var d := dFound downto 1 do begin
    var tv := trace[d-1];
    var k := x-y;
    var prevK := if (k = -d) or ((k <> d) and (tv[k-1+d] < tv[k+1+d])) then k+1 else k-1;
    var prevX := tv[prevK+d];
    var prevY := prevX-prevK;
    if prevK = k+1 then begin
      push(dkSame, prevX, prevY+1, x-prevX);
      push(dkAdded, prevX, prevY, 1);
    end else begin
      push(dkSame, prevX+1, prevY, x-prevX-1);
      push(dkRemoved, prevX, prevY, 1);
    end;
    x := prevX;
    y := prevY;
  end;
  push(dkSame, 0, 0, x);
  for var i := ns-1 downto 0 do begin
    var st := steps[i];
    if st.kind = dkSame then emit(dkSame, aLo+st.ax, st.len, bLo+st.by, st.len)
    else if st.kind = dkRemoved then emitGap(aLo+st.ax, 1, bLo+st.by, 0)
    else emitGap(aLo+st.ax, 0, bLo+st.by, 1);
  end;
  result := true;
end;

// trims the list and folds a removal next to an addition into one change
function TSeqDiffer.finish: TDiffSeqOps;
begin
  var n := 0;
  for var i := 0 to count-1 do begin
    var op := ops[i];
    if (n > 0) and (ops[n-1].kind in [dkRemoved, dkAdded]) and (op.kind in [dkRemoved, dkAdded]) and (op.kind <> ops[n-1].kind) then begin
      ops[n-1].kind := dkChanged;
      ops[n-1].aLen += op.aLen;
      ops[n-1].bLen += op.bLen;
      continue;
    end;
    ops[n] := op;
    inc(n);
  end;
  SetLength(ops, n);
  result := ops;
end;

function diffSequence(a: PQWord; na: integer; b: PQWord; nb: integer): TDiffSeqOps;
begin
  var d := Default(TSeqDiffer);
  d.a := a;
  d.b := b;
  d.diffRange(0, na, 0, nb);
  result := d.finish;
end;

function hashBytes(p: PByte; len: integer): QWord;
begin
  result := FNV_OFFSET;
  for var i := 0 to len-1 do result := (result xor p[i])*FNV_PRIME;
end;

// words, runs of blanks and single marks, each a token
procedure tokenize(const s: string; out starts: array of integer; out hashes: array of QWord; out count: integer);
begin
  count := 0;
  var i := 1;
  while i <= length(s) do begin
    var j := i;
    var c := s[i];
    if c in [' ', #9] then while (j < length(s)) and (s[j+1] in [' ', #9]) do inc(j)
    else if (c in ['0'..'9', 'A'..'Z', 'a'..'z', '_']) or (ord(c) >= 128) then
      while (j < length(s)) and ((s[j+1] in ['0'..'9', 'A'..'Z', 'a'..'z', '_']) or (ord(s[j+1]) >= 128)) do inc(j);
    starts[count] := i;
    hashes[count] := hashBytes(@s[i], j-i+1);
    inc(count);
    i := j+1;
  end;
  starts[count] := length(s)+1;
end;

function spanOf(const starts: array of integer; first, count: integer; kind: TDiffKind): TDiffSpan;
begin
  result.start := starts[first];
  result.length := starts[first+count]-starts[first];
  result.kind := kind;
end;

// the stretches that differ between two paired lines, token by token;
// false when so much differs that marking the whole line reads better
function diffWithinLine(const la, lb: string; out ra, rb: TDiffSpans): boolean;
begin
  result := false;
  ra := nil;
  rb := nil;
  var startsA, startsB: array of integer;
  var hashesA, hashesB: array of QWord;
  SetLength(startsA, length(la)+1);
  SetLength(startsB, length(lb)+1);
  SetLength(hashesA, length(la)+1);
  SetLength(hashesB, length(lb)+1);
  var na, nb: integer;
  tokenize(la, startsA, hashesA, na);
  tokenize(lb, startsB, hashesB, nb);
  var ops := diffSequence(@hashesA[0], na, @hashesB[0], nb);
  var changedA := 0;
  var changedB := 0;
  for var i := 0 to high(ops) do begin
    var op := ops[i];
    if op.kind = dkSame then continue;
    var paired := Min(op.aLen, op.bLen);
    if paired > 0 then begin
      ra := ra+[spanOf(startsA, op.aPos, paired, dkChanged)];
      rb := rb+[spanOf(startsB, op.bPos, paired, dkChanged)];
    end;
    if op.aLen > paired then ra := ra+[spanOf(startsA, op.aPos+paired, op.aLen-paired, dkRemoved)];
    if op.bLen > paired then rb := rb+[spanOf(startsB, op.bPos+paired, op.bLen-paired, dkAdded)];
    changedA += startsA[op.aPos+op.aLen]-startsA[op.aPos];
    changedB += startsB[op.bPos+op.bLen]-startsB[op.bPos];
  end;
  if (length(la) > 0) and (changedA > MAX_CHANGED_RATIO*length(la)) then exit;
  if (length(lb) > 0) and (changedB > MAX_CHANGED_RATIO*length(lb)) then exit;
  result := true;
end;

{ TDiffView }

constructor TDiffView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FLeft := TStringList.Create;
  FRight := TStringList.Create;
  TStringList(FLeft).OnChange := @sideChanged;
  TStringList(FRight).OnChange := @sideChanged;
  FShowLineNumbers := true;
  FWordDiff := true;
  FShowChangeMap := true;
  FShowHeader := true;
  FContextLines := 3;
  FPadding := 4;
  FTabWidth := 4;
  FMapWidth := 24;
  FAddedColor := clDefault;
  FRemovedColor := clDefault;
  FChangedColor := clDefault;
  FBackColor := clDefault;
  FTextColor := clDefault;
  FNumberColor := clDefault;
  FMarkColor := clDefault;
  FGutterColor := clDefault;
  FHeaderColor := clDefault;
  FFoldColor := clDefault;
  FAntialiasing := asTheme;
  FHot := -1;
  FActive := -1;
  FCurrentHunk := -1;
  Color := clWindow;
  BorderStyle := bsSingle;
  TabStop := true;
  Font.Name := monospaceFontName;
  Font.Pitch := fpFixed;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Visible := false;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TDiffView.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited Destroy;
end;

class function TDiffView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 600;
  result.cy := 240;
end;

// -- the comparison ----------------------

// the hash wraps around on purpose
{$push}{$Q-}{$R-}
function TDiffView.hashLine(const s: string): QWord;
begin
  result := FNV_OFFSET;
  var skipBlank := FIgnoreWhitespace;
  var lower := FIgnoreCase;
  for var i := 1 to length(s) do begin
    var c := ord(s[i]);
    if skipBlank and (c in [9, 32]) then continue;
    if lower and (c in [ord('A')..ord('Z')]) then c += 32;
    result := (result xor c)*FNV_PRIME;
  end;
end;
{$pop}

procedure TDiffView.compare;
begin
  FRows := nil;
  var n := FLeft.Count;
  var m := FRight.Count;
  var ha, hb: array of QWord;
  SetLength(ha, n+1);
  SetLength(hb, m+1);
  for var i := 0 to n-1 do ha[i] := hashLine(FLeft[i]);
  for var j := 0 to m-1 do hb[j] := hashLine(FRight[j]);
  var ops := diffSequence(@ha[0], n, @hb[0], m);
  var total := 0;
  for var i := 0 to high(ops) do total += Max(ops[i].aLen, ops[i].bLen);
  SetLength(FRows, total);
  var r := 0;
  for var i := 0 to high(ops) do begin
    var op := ops[i];
    match op.kind of
      dkSame: for var k := 0 to op.aLen-1 do begin
        FRows[r] := Default(TRow);
        FRows[r].kind := dkSame;
        FRows[r].leftIndex := op.aPos+k;
        FRows[r].rightIndex := op.bPos+k;
        inc(r);
      end;
      dkRemoved: for var k := 0 to op.aLen-1 do begin
        FRows[r] := Default(TRow);
        FRows[r].kind := dkRemoved;
        FRows[r].leftIndex := op.aPos+k;
        FRows[r].rightIndex := -1;
        inc(r);
      end;
      dkAdded: for var k := 0 to op.bLen-1 do begin
        FRows[r] := Default(TRow);
        FRows[r].kind := dkAdded;
        FRows[r].leftIndex := -1;
        FRows[r].rightIndex := op.bPos+k;
        inc(r);
      end;
    else
      begin
        // the first lines of both sides pair up, the longer side's tail stands alone
        var paired := Min(op.aLen, op.bLen);
        for var k := 0 to paired-1 do begin
          FRows[r] := Default(TRow);
          FRows[r].kind := dkChanged;
          FRows[r].leftIndex := op.aPos+k;
          FRows[r].rightIndex := op.bPos+k;
          inc(r);
        end;
        for var k := paired to op.aLen-1 do begin
          FRows[r] := Default(TRow);
          FRows[r].kind := dkRemoved;
          FRows[r].leftIndex := op.aPos+k;
          FRows[r].rightIndex := -1;
          inc(r);
        end;
        for var k := paired to op.bLen-1 do begin
          FRows[r] := Default(TRow);
          FRows[r].kind := dkAdded;
          FRows[r].leftIndex := -1;
          FRows[r].rightIndex := op.bPos+k;
          inc(r);
        end;
      end;
    end;
  end;
  SetLength(FRows, r);
  buildShown;
end;

// the display lines from the rows: a changed row takes two lines in the
// unified listing, unchanged runs fold to the context when asked
procedure TDiffView.buildShown;
begin
  FShown := nil;
  FHunks := nil;
  var keep: array of boolean;
  SetLength(keep, length(FRows));
  for var i := 0 to high(FRows) do keep[i] := not FHideSame or (FRows[i].kind <> dkSame);
  if FHideSame then
    for var i := 0 to high(FRows) do if FRows[i].kind <> dkSame then
      for var k := Max(i-FContextLines, 0) to Min(i+FContextLines, high(FRows)) do keep[k] := true;
  var i := 0;
  while i < length(FRows) do begin
    if not keep[i] then begin
      var j := i;
      while (j < length(FRows)) and not keep[j] do inc(j);
      SetLength(FShown, length(FShown)+1);
      FShown[high(FShown)].row := i;
      FShown[high(FShown)].side := 2;
      FShown[high(FShown)].folded := j-i;
      i := j;
      continue;
    end;
    var row := FRows[i];
    if (FLayout = dlUnified) and (row.kind = dkChanged) then begin
      SetLength(FShown, length(FShown)+2);
      FShown[high(FShown)-1].row := i;
      FShown[high(FShown)-1].side := 0;
      FShown[high(FShown)].row := i;
      FShown[high(FShown)].side := 1;
    end else begin
      SetLength(FShown, length(FShown)+1);
      FShown[high(FShown)].row := i;
      FShown[high(FShown)].side := if FLayout = dlUnified then (if row.kind = dkAdded then 1 else 0) else 2;
    end;
    inc(i);
  end;
  // the hunks: every run of lines that differ
  var inHunk := false;
  for var k := 0 to high(FShown) do begin
    var differs := (FShown[k].folded = 0) and (FRows[FShown[k].row].kind <> dkSame);
    if differs and not inHunk then FHunks := FHunks+[k];
    inHunk := differs;
  end;
  if FCurrentHunk >= length(FHunks) then FCurrentHunk := length(FHunks)-1;
  if FActive >= length(FShown) then FActive := -1;
  FHot := -1;
  updateRange;
  Invalidate;
end;

procedure TDiffView.ensureSpans(var row: TRow);
begin
  if row.spansDone then exit;
  row.spansDone := true;
  if (row.kind <> dkChanged) or not FWordDiff then exit;
  diffWithinLine(expanded(FLeft[row.leftIndex]), expanded(FRight[row.rightIndex]), row.leftSpans, row.rightSpans);
end;

function TDiffView.SpansOf(row: integer; leftSide: boolean): TDiffSpans;
begin
  result := nil;
  if (row < 0) or (row >= length(FRows)) then exit;
  ensureSpans(FRows[row]);
  result := if leftSide then FRows[row].leftSpans else FRows[row].rightSpans;
end;

procedure TDiffView.sideChanged(Sender: TObject);
begin
  compare;
  if Assigned(FOnChange) then FOnChange(self);
end;

procedure TDiffView.SetTexts(const leftText, rightText: string);
begin
  TStringList(FLeft).OnChange := nil;
  TStringList(FRight).OnChange := nil;
  try
    FLeft.Text := leftText;
    FRight.Text := rightText;
  finally
    TStringList(FLeft).OnChange := @sideChanged;
    TStringList(FRight).OnChange := @sideChanged;
  end;
  sideChanged(self);
end;

procedure TDiffView.LoadFromFiles(const leftFile, rightFile: string);
begin
  TStringList(FLeft).OnChange := nil;
  TStringList(FRight).OnChange := nil;
  try
    FLeft.LoadFromFile(leftFile);
    FRight.LoadFromFile(rightFile);
  finally
    TStringList(FLeft).OnChange := @sideChanged;
    TStringList(FRight).OnChange := @sideChanged;
  end;
  sideChanged(self);
end;

function TDiffView.RowCount: integer;
begin
  result := length(FRows);
end;

function TDiffView.HunkCount: integer;
begin
  result := length(FHunks);
end;

function TDiffView.CountOf(kind: TDiffKind): integer;
begin
  result := 0;
  for var r in FRows do if r.kind = kind then inc(result);
end;

procedure TDiffView.RowInfo(row: integer; out kind: TDiffKind; out leftLine, rightLine: integer);
begin
  kind := dkSame;
  leftLine := -1;
  rightLine := -1;
  if (row < 0) or (row >= length(FRows)) then exit;
  kind := FRows[row].kind;
  leftLine := FRows[row].leftIndex;
  rightLine := FRows[row].rightIndex;
end;

procedure TDiffView.showLine(index: integer);
begin
  if (index < 0) or not HandleAllocated then exit;
  var y := scaled(self, FPadding)+index*FLineHeight;
  if y < VertScrollBar.Position then VertScrollBar.Position := y
  else if y+FLineHeight > VertScrollBar.Position+ClientHeight-headerPx then VertScrollBar.Position := y+FLineHeight-ClientHeight+headerPx;
end;

procedure TDiffView.GoToHunk(index: integer);
begin
  if (index < 0) or (index >= length(FHunks)) then exit;
  FCurrentHunk := index;
  FActive := FHunks[index];
  var y := scaled(self, FPadding)+FActive*FLineHeight;
  VertScrollBar.Position := Max(y-FLineHeight*2, 0);
  Invalidate;
end;

procedure TDiffView.NextHunk;
begin
  GoToHunk(Min(FCurrentHunk+1, length(FHunks)-1));
end;

procedure TDiffView.PreviousHunk;
begin
  GoToHunk(Max(FCurrentHunk-1, 0));
end;

procedure TDiffView.SaveToStrings(lines: TStrings; context: integer);
begin
  lines.Add('--- left');
  lines.Add('+++ right');
  var k := 0;
  while k < length(FRows) do begin
    if FRows[k].kind = dkSame then begin inc(k); continue; end;
    var start := Max(k-context, 0);
    var stop := k;
    while stop < length(FRows) do begin
      if FRows[stop].kind <> dkSame then begin inc(stop); continue; end;
      // unchanged lines inside twice the context still belong to the hunk
      var gapEnd := stop;
      while (gapEnd < length(FRows)) and (FRows[gapEnd].kind = dkSame) do inc(gapEnd);
      if (gapEnd < length(FRows)) and (gapEnd-stop <= context*2) then stop := gapEnd else break;
    end;
    stop := Min(stop+context, length(FRows));
    var leftStart := 0;
    var rightStart := 0;
    var leftCount := 0;
    var rightCount := 0;
    for var r := start to stop-1 do begin
      if FRows[r].leftIndex >= 0 then begin if leftCount = 0 then leftStart := FRows[r].leftIndex+1; inc(leftCount); end;
      if FRows[r].rightIndex >= 0 then begin if rightCount = 0 then rightStart := FRows[r].rightIndex+1; inc(rightCount); end;
    end;
    lines.Add(Format('@@ -%d,%d +%d,%d @@', [leftStart, leftCount, rightStart, rightCount]));
    for var r := start to stop-1 do
      match FRows[r].kind of
        dkSame: lines.Add(' '+FLeft[FRows[r].leftIndex]);
        dkRemoved: lines.Add('-'+FLeft[FRows[r].leftIndex]);
        dkAdded: lines.Add('+'+FRight[FRows[r].rightIndex]);
        dkChanged: begin
          lines.Add('-'+FLeft[FRows[r].leftIndex]);
          lines.Add('+'+FRight[FRows[r].rightIndex]);
        end;
      end;
    k := stop;
  end;
end;

// -- geometry ----------------------

procedure TDiffView.measure;
begin
  if not HandleAllocated then exit;
  Canvas.Font := Font;
  applyTextQuality(Canvas);
  FCharWidth := Max(Canvas.TextWidth('0'), 1);
  FLineHeight := Canvas.TextHeight('Hg')+scaled(self, 2);
  var digits := length(IntToStr(Max(FLeft.Count, FRight.Count)))+1;
  FNumberWidth := if FShowLineNumbers then FCharWidth*digits+scaled(self, 8) else 0;
end;

function TDiffView.headerPx: integer;
begin
  result := if FShowHeader then FLineHeight+scaled(self, 4) else 0;
end;

function TDiffView.mapPx: integer;
begin
  result := if FShowChangeMap then scaled(self, FMapWidth) else 0;
end;

// the panes in client coordinates: the map sits between them, or at the right of the one
procedure TDiffView.panes(out leftX, leftRight, rightX, rightRight: integer);
begin
  var gutter := if FShowGutter then scaled(self, 10) else 0;
  var mapW := mapPx;
  if FLayout = dlSideBySide then begin
    var half := (ClientWidth-gutter-mapW) div 2;
    leftX := gutter;
    leftRight := gutter+half;
    rightX := leftRight+mapW;
    rightRight := ClientWidth;
  end else begin
    leftX := gutter;
    leftRight := ClientWidth-mapW;
    rightX := leftRight;
    rightRight := leftRight;
  end;
end;

function TDiffView.mapRect: TRect;
begin
  var leftX, leftRight, rightX, rightRight: integer;
  panes(leftX, leftRight, rightX, rightRight);
  var mapW := mapPx;
  if mapW = 0 then exit(Rect(0, 0, 0, 0));
  result := if FLayout = dlSideBySide then Rect(leftRight, headerPx, rightX, ClientHeight) else Rect(leftRight, headerPx, leftRight+mapW, ClientHeight);
end;

function TDiffView.lineAt(y: integer): integer;
begin
  if (FLineHeight = 0) or (y < headerPx) then exit(-1);
  result := (y+VertScrollBar.Position-scaled(self, FPadding)-headerPx) div FLineHeight;
  if (result < 0) or (result >= length(FShown)) then result := -1;
end;

procedure TDiffView.updateRange;
begin
  if not HandleAllocated then exit;
  measure;
  var range := headerPx+length(FShown)*FLineHeight+scaled(self, FPadding)*2;
  if VertScrollBar.Increment <> FLineHeight then VertScrollBar.Increment := FLineHeight;
  if VertScrollBar.Page <> Max(ClientHeight, 1) then VertScrollBar.Page := Max(ClientHeight, 1);
  if VertScrollBar.Range <> range then VertScrollBar.Range := range;
end;

procedure TDiffView.ScrollBy(DeltaX, DeltaY: Integer);
begin
  Invalidate;
end;

procedure TDiffView.Resize;
begin
  inherited Resize;
  // the scroll bar waits for the paint: set while the bounds change it keeps the control in place
  FRangeDirty := true;
  Invalidate;
end;

procedure TDiffView.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  FRangeDirty := true;
  Invalidate;
end;

function TDiffView.expanded(const s: string): string;
begin
  if Pos(#9, s) = 0 then exit(s);
  result := '';
  var col := 0;
  var width := Max(FTabWidth, 1);
  for var i := 1 to length(s) do begin
    if s[i] = #9 then begin
      var padW := width-col mod width;
      result += StringOfChar(' ', padW);
      col += padW;
    end else begin
      result += s[i];
      if (ord(s[i]) and $C0) <> $80 then inc(col);
    end;
  end;
end;

function TDiffView.kindColor(kind: TDiffKind): TColor;
begin
  var back := pick(FBackColor, Color);
  result := match kind of
    dkAdded: pick(FAddedColor, blend(back, $50C050, 22));
    dkRemoved: pick(FRemovedColor, blend(back, $5050E0, 22));
    dkChanged: pick(FChangedColor, blend(back, $40A0E8, 20));
  else
    back
  end;
end;

// the tone of the words that differ, stronger than their line
function TDiffView.strongColor(kind: TDiffKind): TColor;
begin
  if FMarkColor <> clDefault then exit(ColorToRGB(FMarkColor));
  var back := pick(FBackColor, Color);
  result := match kind of
    dkAdded: blend(back, $50C050, 55);
    dkRemoved: blend(back, $5050E0, 55);
  else
    blend(back, $40A0E8, 55)
  end;
end;

// -- painting ----------------------

procedure TDiffView.Paint;
begin
  if FRangeDirty then begin
    FRangeDirty := false;
    updateRange;
  end;
  measure;
  var back := pick(FBackColor, Color);
  var text := pick(FTextColor, clWindowText);
  var numbers := pick(FNumberColor, blend(clWindowText, back, 50));
  var gutterBack := pick(FGutterColor, blend(back, clWindowText, 6));
  var header := pick(FHeaderColor, blend(back, clWindowText, 7));
  var foldColor := pick(FFoldColor, blend(back, clWindowText, 35));
  var grid := blend(back, clWindowText, 15);
  var caretColor := ColorToRGB(clHighlight);
  var gap := blend(back, clWindowText, 4);
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var pad := scaled(self, FPadding);
  var hh := headerPx;
  var lh := FLineHeight;
  var cw := FCharWidth;
  var gutter := if FShowGutter then scaled(self, 10) else 0;
  var leftX, leftRight, rightX, rightRight: integer;
  panes(leftX, leftRight, rightX, rightRight);
  var split := FLayout = dlSideBySide;
  var first := Max((VertScrollBar.Position-pad) div lh, 0);
  var last := Min((VertScrollBar.Position+ClientHeight-pad-hh) div lh+1, high(FShown));
  if FShowGutter then sp.FillRect(Rect(0, view.Top, gutter, view.Bottom), gutterBack);

  // the backgrounds of the lines and the marks of the words that differ
  for var i := first to last do begin
    var shown := FShown[i];
    var y := pad+hh+i*lh;
    if shown.folded > 0 then begin
      sp.FillRect(Rect(leftX, y, rightRight, y+lh), blend(back, clWindowText, 3));
      sp.FillRect(Rect(leftX, y+lh div 2, rightRight, y+lh div 2+1), blend(back, clWindowText, 12));
      continue;
    end;
    var row := FRows[shown.row];
    var lineFill := kindColor(row.kind);
    if (i = FHot) and hoverEnabled and (row.kind = dkSame) then lineFill := hoverColor(back);
    ensureSpans(FRows[shown.row]);
    row := FRows[shown.row];
    if split then begin
      // the left pane
      if row.leftIndex >= 0 then sp.FillRect(Rect(leftX, y, leftRight, y+lh), (if row.kind = dkAdded then back else lineFill))
      else sp.FillRect(Rect(leftX, y, leftRight, y+lh), gap);
      if row.rightIndex >= 0 then sp.FillRect(Rect(rightX, y, rightRight, y+lh), (if row.kind = dkRemoved then back else lineFill))
      else sp.FillRect(Rect(rightX, y, rightRight, y+lh), gap);
      if row.kind = dkChanged then begin
        for var s in row.leftSpans do sp.FillRect(Rect(leftX+FNumberWidth+pad+(s.start-1)*cw, y, Min(leftX+FNumberWidth+pad+(s.start-1+s.length)*cw, leftRight), y+lh), strongColor(s.kind));
        for var s in row.rightSpans do sp.FillRect(Rect(rightX+FNumberWidth+pad+(s.start-1)*cw, y, Min(rightX+FNumberWidth+pad+(s.start-1+s.length)*cw, rightRight), y+lh), strongColor(s.kind));
      end;
    end else begin
      // one pane: a changed row shows its two lines one under the other
      var fill := lineFill;
      if row.kind = dkChanged then fill := kindColor(if shown.side = 0 then dkRemoved else dkAdded);
      if fill <> back then sp.FillRect(Rect(leftX, y, leftRight, y+lh), fill);
      if row.kind = dkChanged then begin
        var spans := if shown.side = 0 then row.leftSpans else row.rightSpans;
        for var s in spans do sp.FillRect(Rect(leftX+FNumberWidth*2+pad+cw+(s.start-1)*cw, y, Min(leftX+FNumberWidth*2+pad+cw+(s.start-1+s.length)*cw, leftRight), y+lh), strongColor(if s.kind = dkChanged then (if shown.side = 0 then dkRemoved else dkAdded) else s.kind));
      end;
    end;
    if FShowGutter and (row.kind <> dkSame) then sp.FillRect(Rect(0, y, gutter, y+lh), strongColor(row.kind));
    // the active line framed on both sides, so the eye finds its pair
    if i = FActive then begin
      if split then begin
        sp.FrameRoundRect(leftX+FNumberWidth, y, leftRight, y+lh, 0, 1, caretColor);
        sp.FrameRoundRect(rightX+FNumberWidth, y, rightRight, y+lh, 0, 1, caretColor);
      end else sp.FrameRoundRect(leftX+FNumberWidth*2, y, leftRight, y+lh, 0, 1, caretColor);
    end;
  end;
  // the lines between the numbers and the text
  if FShowLineNumbers then begin
    if split then begin
      sp.FillRect(Rect(leftX+FNumberWidth-1, view.Top+hh, leftX+FNumberWidth, view.Bottom), grid);
      sp.FillRect(Rect(rightX+FNumberWidth-1, view.Top+hh, rightX+FNumberWidth, view.Bottom), grid);
    end else sp.FillRect(Rect(leftX+FNumberWidth*2-1, view.Top+hh, leftX+FNumberWidth*2, view.Bottom), grid);
  end;
  // the header stays on top
  if hh > 0 then begin
    sp.FillRect(Rect(view.Left, view.Top, view.Right, view.Top+hh), header);
    sp.FillRect(Rect(view.Left, view.Top+hh-1, view.Right, view.Top+hh), grid);
  end;
  // the change map: a mark per line that differs, a frame around the lines shown
  var map := mapRect;
  if not map.IsEmpty then begin
    OffsetRect(map, 0, VertScrollBar.Position);
    sp.FillRect(map, gutterBack);
    var n := Max(length(FShown), 1);
    var h := Max(map.Height, 1);
    var inset := scaled(self, 3);
    var i := 0;
    while i < length(FShown) do begin
      if (FShown[i].folded > 0) or (FRows[FShown[i].row].kind = dkSame) then begin inc(i); continue; end;
      var kind := FRows[FShown[i].row].kind;
      var j := i;
      while (j+1 < length(FShown)) and (FShown[j+1].folded = 0) and (FRows[FShown[j+1].row].kind = kind) do inc(j);
      var y0 := map.Top+i*h div n;
      var y1 := map.Top+(j+1)*h div n;
      if y1 <= y0 then y1 := y0+1;
      sp.FillRect(Rect(map.Left+inset, y0, map.Right-inset, y1), strongColor(kind));
      i := j+1;
    end;
    var vy0 := map.Top+first*h div n;
    var vy1 := map.Top+Min(last+1, n)*h div n;
    if vy1 <= vy0+1 then vy1 := vy0+2;
    sp.FrameRoundRect(map.Left+1, vy0, map.Right-1, vy1, 0, 1, caretColor);
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Font := Font;
  Canvas.Brush.Style := bsClear;
  Canvas.Clipping := true;
  var numberRight := function(paneX: integer; line: integer): integer
  begin
    result := paneX+FNumberWidth-scaled(self, 4)-Canvas.TextWidth(IntToStr(line+1));
  end;
  for var i := first to last do begin
    var shown := FShown[i];
    var y := pad+hh+i*lh;
    if shown.folded > 0 then begin
      Canvas.ClipRect := Rect(leftX, view.Top+hh, rightRight, view.Bottom);
      Canvas.Font.Color := foldColor;
      var s := Format('%d unchanged lines', [shown.folded]);
      var w := Canvas.TextWidth(s)+scaled(self, 12);
      var x := leftX+(rightRight-leftX-w) div 2;
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := blend(back, clWindowText, 3);
      Canvas.FillRect(x, y, x+w, y+lh);
      Canvas.Brush.Style := bsClear;
      Canvas.TextOut(x+scaled(self, 6), y, s);
      continue;
    end;
    var row := FRows[shown.row];
    if split then begin
      Canvas.ClipRect := Rect(leftX, view.Top+hh, leftRight, view.Bottom);
      if row.leftIndex >= 0 then begin
        if FShowLineNumbers then begin
          Canvas.Font.Color := numbers;
          Canvas.TextOut(numberRight(leftX, row.leftIndex), y, IntToStr(row.leftIndex+1));
        end;
        Canvas.Font.Color := text;
        Canvas.TextOut(leftX+FNumberWidth+pad, y, expanded(FLeft[row.leftIndex]));
      end;
      Canvas.ClipRect := Rect(rightX, view.Top+hh, rightRight, view.Bottom);
      if row.rightIndex >= 0 then begin
        if FShowLineNumbers then begin
          Canvas.Font.Color := numbers;
          Canvas.TextOut(numberRight(rightX, row.rightIndex), y, IntToStr(row.rightIndex+1));
        end;
        Canvas.Font.Color := text;
        Canvas.TextOut(rightX+FNumberWidth+pad, y, expanded(FRight[row.rightIndex]));
      end;
    end else begin
      Canvas.ClipRect := Rect(leftX, view.Top+hh, leftRight, view.Bottom);
      var leftSide := (shown.side = 0) and (row.leftIndex >= 0);
      var line := if leftSide then FLeft[row.leftIndex] else FRight[row.rightIndex];
      if FShowLineNumbers then begin
        Canvas.Font.Color := numbers;
        if row.leftIndex >= 0 then Canvas.TextOut(numberRight(leftX, row.leftIndex), y, IntToStr(row.leftIndex+1));
        if (row.rightIndex >= 0) and ((row.kind <> dkChanged) or (shown.side = 1)) then Canvas.TextOut(numberRight(leftX+FNumberWidth, row.rightIndex), y, IntToStr(row.rightIndex+1));
      end;
      var prefix := match row.kind of
        dkAdded: '+';
        dkRemoved: '-';
        dkChanged: (if shown.side = 0 then '-' else '+');
      else
        ' '
      end;
      Canvas.Font.Color := if row.kind = dkSame then text else blend(text, strongColor(if row.kind = dkChanged then (if shown.side = 0 then dkRemoved else dkAdded) else row.kind), 0);
      // the sign takes a column of its own in front of the text
      Canvas.TextOut(leftX+FNumberWidth*2+pad div 2, y, prefix);
      Canvas.Font.Color := text;
      Canvas.TextOut(leftX+FNumberWidth*2+pad+cw, y, expanded(line));
    end;
  end;
  Canvas.Clipping := false;
  if hh > 0 then begin
    Canvas.Font.Color := numbers;
    var hy := view.Top+scaled(self, 2);
    if split then begin
      Canvas.TextOut(leftX+scaled(self, 4), hy, 'Left');
      Canvas.TextOut(rightX+scaled(self, 4), hy, 'Right');
    end else Canvas.TextOut(leftX+scaled(self, 4), hy, Format('%d changed, %d added, %d removed', [CountOf(dkChanged), CountOf(dkAdded), CountOf(dkRemoved)]));
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TDiffView.scrollMap(y: integer);
begin
  var map := mapRect;
  if map.IsEmpty or (length(FShown) = 0) then exit;
  var target := (y-map.Top)*length(FShown) div Max(map.Height, 1);
  VertScrollBar.Position := Max(scaled(self, FPadding)+target*FLineHeight-ClientHeight div 2, 0);
end;

procedure TDiffView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FMapDrag and (ssLeft in Shift) then begin
    scrollMap(Y);
    exit;
  end;
  var hot := if PtInRect(mapRect, Point(X, Y)) then -1 else lineAt(Y);
  if hot = FHot then exit;
  FHot := hot;
  Invalidate;
end;

procedure TDiffView.MouseLeave;
begin
  inherited MouseLeave;
  if FHot < 0 then exit;
  FHot := -1;
  Invalidate;
end;

procedure TDiffView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if Button <> mbLeft then exit;
  if PtInRect(mapRect, Point(X, Y)) then begin
    FMapDrag := true;
    scrollMap(Y);
    exit;
  end;
  var index := lineAt(Y);
  if (index < 0) or (FShown[index].folded > 0) then exit;
  FActive := index;
  for var h := 0 to high(FHunks) do if FHunks[h] <= index then FCurrentHunk := h;
  Invalidate;
  if Assigned(FOnRowClick) then FOnRowClick(self, FShown[index].row, FRows[FShown[index].row].kind);
end;

procedure TDiffView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FMapDrag := false;
end;

procedure TDiffView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  match Key of
    VK_DOWN: if ssCtrl in Shift then NextHunk else begin FActive := Min(FActive+1, high(FShown)); showLine(FActive); Invalidate; end;
    VK_UP: if ssCtrl in Shift then PreviousHunk else begin FActive := Max(FActive-1, 0); showLine(FActive); Invalidate; end;
    VK_NEXT: NextHunk;
    VK_PRIOR: PreviousHunk;
    VK_HOME: GoToHunk(0);
    VK_END: GoToHunk(length(FHunks)-1);
  else
    exit;
  end;
  Key := 0;
end;

procedure TDiffView.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TDiffView.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

procedure TDiffView.setSide(index: integer; value: TStrings);
begin
  if index = 0 then FLeft.Assign(value) else FRight.Assign(value);
end;

procedure TDiffView.setLayout(value: TDiffLayout);
begin
  if FLayout = value then exit;
  FLayout := value;
  buildShown;
end;

function TDiffView.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowLineNumbers;
    1: FIgnoreWhitespace;
    2: FIgnoreCase;
    3: FWordDiff;
    4: FShowGutter;
    5: FHideSame;
    6: FShowChangeMap;
  else
    FShowHeader
  end;
end;

procedure TDiffView.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowLineNumbers := value;
    1: FIgnoreWhitespace := value;
    2: FIgnoreCase := value;
    3: FWordDiff := value;
    4: FShowGutter := value;
    5: FHideSame := value;
    6: FShowChangeMap := value;
  else
    FShowHeader := value;
  end;
  match index of
    1, 2: compare;
    3: begin
      for var i := 0 to high(FRows) do FRows[i].spansDone := false;
      Invalidate;
    end;
    5: buildShown;
  else
    begin
      FRangeDirty := true;
      Invalidate;
    end;
  end;
end;

function TDiffView.getMetric(index: integer): integer;
begin
  result := match index of
    0: FContextLines;
    1: FPadding;
    2: FTabWidth;
  else
    FMapWidth
  end;
end;

procedure TDiffView.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FContextLines := value;
    1: FPadding := value;
    2: FTabWidth := value;
  else
    FMapWidth := value;
  end;
  if index = 0 then buildShown
  else if index = 2 then begin
    for var i := 0 to high(FRows) do FRows[i].spansDone := false;
    Invalidate;
  end else begin
    FRangeDirty := true;
    Invalidate;
  end;
end;

function TDiffView.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FAddedColor;
    1: FRemovedColor;
    2: FChangedColor;
    3: FBackColor;
    4: FTextColor;
    5: FNumberColor;
    6: FMarkColor;
    7: FGutterColor;
    8: FHeaderColor;
  else
    FFoldColor
  end;
end;

procedure TDiffView.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FAddedColor := value;
    1: FRemovedColor := value;
    2: FChangedColor := value;
    3: FBackColor := value;
    4: FTextColor := value;
    5: FNumberColor := value;
    6: FMarkColor := value;
    7: FGutterColor := value;
    8: FHeaderColor := value;
  else
    FFoldColor := value;
  end;
  Invalidate;
end;

procedure TDiffView.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
