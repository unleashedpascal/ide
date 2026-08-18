{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit MiniMapView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Math,
  // LCL
  Controls, ExtCtrls, Graphics, StdCtrls, LCLIntf,
  // SynEdit
  SynEdit, SynEditTypes, SynEditMiscClasses, SynEditMarkup,
  SynEditMarkupBracket, SynEditMarkupSpecialLine, SynEditMarkupHighAll,
  SynEditMarkupFoldColoring, SynEditMarkupCtrlMouseLink,
  SynEditMarkupWordGroup, SynGutterBase,
  // LazEdit
  LazEditTextAttributes,
  // IdeIntf
  SrcEditorIntf, EditorOptionsIntf,
  MiniMapConfig;

type

  { TMiniMapView

    Code map living inside one source editor. A narrow read-only SynEdit
    shares the text buffer of the editor and paints it with a tiny font,
    no scrollbars and no gutters. The control sits over a blank right
    gutter part that reserves the band left of the vertical scrollbar.
    The lines visible in the editor are tinted by a viewport band of
    constant height; clicking jumps, dragging and the wheel scroll the
    editor. The map itself is passive: no caret, no selection, no hover
    effects. }

  TMiniMapView = class(TPanel)
  private
    fMapEdit: TSynEdit;
    fEditor: TSourceEditorInterface;
    fEdit: TCustomSynEdit;
    fBandColor: TColor;
    fBandTint: integer;
    fFontSize: integer;
    fGutterPart: TSynGutterPartBase;
    fInitTimer: TTimer;
    fInitRetries: integer;
    fDragging: boolean;
    fGrabOffset: integer;
    fDragTimer: TTimer;
    fDragY: integer;
    fDragPending: boolean;
    fBandFirst: integer;
    fBandLast: integer;
    procedure configMapEdit;
    procedure invalidateBand(first, last: integer);
    procedure applyDrag(y: integer);
    procedure dragTimerTick(Sender: TObject);
    function effectiveBandColor: TColor;
    function sourceMaxTopLine: integer;
    procedure scrollRanges(out s, m: integer);
    function bandTopPixel: integer;
    function mapPixelToSourceTop(px: integer): integer;
    procedure syncMapProps;
    procedure syncBand;
    procedure paintPastEofBand(aCanvas: TCanvas);
    procedure lineMarkup(Sender: TObject; const Info: TSpecialLineMarkupExInfo; var Special: boolean; Markup: TLazEditTextAttributeModifier);
    procedure statusChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure sourceResized(Sender: TObject);
    procedure initTimerTick(Sender: TObject);
    procedure mapMouseDown(y: integer);
    procedure mapMouseMove(y: integer);
    procedure mapMouseUp;
    procedure mapMouseWheel(wheelDelta: integer);
    procedure setEditor(aValue: TSourceEditorInterface);
    procedure setBandColor(aValue: TColor);
    procedure setBandTint(aValue: integer);
    procedure setFontSize(aValue: integer);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    // re-pulls color, font and highlighter from the source editor
    procedure reconfigure;
    // detaches from the source editor; safe to call more than once
    procedure unhook;
    // places the control over the reserved right-gutter band
    procedure updateLayout;
    property editor: TSourceEditorInterface read fEditor write setEditor;
    property bandColor: TColor read fBandColor write setBandColor;
    property bandTint: integer read fBandTint write setBandTint;
    property fontSize: integer read fFontSize write setFontSize;
  end;

implementation

type

  // blank part appended to the right gutter of the source editor; it
  // reserves the horizontal space so text, wrapping and the right edge
  // stay clear of the map laid over it
  TMiniMapGutterPart = class(TSynGutterPartBase)
  public
    procedure Paint(Canvas: TCanvas; AClip: TRect; {%H-}FirstLine, {%H-}LastLine: integer); override;
  end;

  // the embedded map editor; all mouse input goes to the owning view so
  // the built-in SynEdit actions (caret, selection, focus) never run
  TMapSynEdit = class(TSynEdit)
  private
    fMap: TMiniMapView;
  protected
    procedure MouseDown(Button: TMouseButton; {%H-}Shift: TShiftState; {%H-}X, Y: Integer); override;
    procedure MouseMove({%H-}Shift: TShiftState; {%H-}X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; {%H-}Shift: TShiftState; {%H-}X, {%H-}Y: Integer); override;
    function DoMouseWheel({%H-}Shift: TShiftState; WheelDelta: Integer; {%H-}MousePos: TPoint): Boolean; override;
    procedure Paint; override;
  end;

{ TMiniMapGutterPart }

procedure TMiniMapGutterPart.Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
begin
  // only visible for the moments before the map control covers the band
  Canvas.Brush.Color := TCustomSynEdit(SynEdit).Color;
  Canvas.FillRect(AClip);
end;

{ TMapSynEdit }

procedure TMapSynEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // swallow the built-in handling; the map acts as a scrollbar, not an editor
  if Button = mbLeft then fMap.mapMouseDown(Y);
end;

procedure TMapSynEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  fMap.mapMouseMove(Y);
end;

procedure TMapSynEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then fMap.mapMouseUp;
end;

function TMapSynEdit.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  fMap.mapMouseWheel(WheelDelta);
  result := True;
end;

procedure TMapSynEdit.Paint;
begin
  inherited Paint;
  fMap.paintPastEofBand(Canvas);
end;

{ TMiniMapView }

constructor TMiniMapView.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  BevelInner := bvNone;
  BevelOuter := bvNone;
  var def := defaultMapSettings;
  fBandColor := def.bandColor;
  fBandTint := def.bandTint;
  fFontSize := def.fontSize;
  fBandLast := -1; // no band painted yet
  fMapEdit := TMapSynEdit.Create(self);
  TMapSynEdit(fMapEdit).fMap := self;
  fMapEdit.Parent := self;
  fInitTimer := TTimer.Create(self);
  fInitTimer.Enabled := False;
  fInitTimer.Interval := 250;
  fInitTimer.OnTimer := @initTimerTick;
  fDragTimer := TTimer.Create(self);
  fDragTimer.Enabled := False;
  fDragTimer.Interval := 15; // one scroll step per tick, roughly a frame
  fDragTimer.OnTimer := @dragTimerTick;
  configMapEdit;
end;

destructor TMiniMapView.Destroy;
begin
  unhook;
  inherited Destroy;
end;

procedure TMiniMapView.configMapEdit;
begin
  // start from the user's editor settings, then neutralize everything a
  // passive map must not show; the order matters, GetSynEditorSettings
  // would re-enable the caret and word markups if it ran last
  IDEEditorOptions.GetSynEditorSettings(fMapEdit);
  with fMapEdit do begin
    Left := 0;
    Top := 0;
    Align := alClient;
    ParentColor := False;
    ParentFont := False;
    Font.Name := SynDefaultFontName;
    Font.Pitch := fpFixed;
    Font.Quality := fqNonAntialiased;
    Font.Size := fFontSize;
    ScrollBars := ssNone;
    BorderStyle := bsNone;
    Cursor := crArrow;
    ReadOnly := True;
    Gutter.Visible := False;
    Gutter.Width := 57;
    RightGutter.Width := 0;
    VisibleSpecialChars := [vscSpace, vscTabAtLast];
    Keystrokes.Clear;
    MouseActions.Clear;
    // eoScrollPastEof gives the map empty space below the last line, so
    // the viewport band stays whole when the editor overscrolls past eof
    Options := [eoNoCaret, eoNoSelection, eoScrollPastEof];
    Options2 := [];
    BookMarkOptions.EnableKeys := False;
    BookMarkOptions.GlyphsVisible := False;
    BookMarkOptions.DrawBookmarksFirst := False;
    // no highlight bands besides the viewport overlay
    BracketHighlightStyle := sbhsBoth;
    BracketMatchColor.Background := clNone;
    BracketMatchColor.Foreground := clNone;
    BracketMatchColor.Style := [fsBold];
    FoldedCodeColor.Background := clNone;
    FoldedCodeColor.Foreground := clGray;
    FoldedCodeColor.FrameColor := clGray;
    MouseLinkColor.Background := clNone;
    MouseLinkColor.Foreground := clBlue;
    LineHighlightColor.Background := clNone;
    LineHighlightColor.Foreground := clNone;
    HighlightAllColor.Background := clNone;
    HighlightAllColor.Foreground := clNone;
    HighlightAllColor.FrameColor := clNone;
  end;
  // kill every markup that reacts to the caret, selection, folds or
  // searches; the resting caret at 1,1 would flag matches of the first
  // word and the outline markup would frame every block keyword
  var markup := fMapEdit.MarkupByClass[TSynEditMarkupHighlightAllCaret];
  if markup <> nil then markup.Enabled := False;
  markup := fMapEdit.MarkupByClass[TSynEditMarkupHighlightAll];
  if markup <> nil then markup.Enabled := False;
  markup := fMapEdit.MarkupByClass[TSynEditMarkupFoldColors];
  if markup <> nil then markup.Enabled := False;
  markup := fMapEdit.MarkupByClass[TSynEditMarkupCtrlMouseLink];
  if markup <> nil then markup.Enabled := False;
  markup := fMapEdit.MarkupByClass[TSynEditMarkupWordGroup];
  if markup <> nil then markup.Enabled := False;
  fMapEdit.OnSpecialLineMarkupEx := @lineMarkup;
  for var i := 0 to fMapEdit.Gutter.Parts.Count-1 do fMapEdit.Gutter.Parts[i].Visible := True;
end;

procedure TMiniMapView.setEditor(aValue: TSourceEditorInterface);
begin
  if fEditor = aValue then exit;
  fEditor := aValue;
  fEdit := TCustomSynEdit(fEditor.EditorControl);
  if fEdit = nil then exit;
  syncMapProps;
  syncBand;
  // live inside the editor, over a right-gutter band reserved for the map
  Parent := fEdit;
  fGutterPart := TMiniMapGutterPart.Create(fEdit.RightGutter.Parts);
  fGutterPart.FreeNotification(self);
  fGutterPart.AutoSize := False;
  fEdit.AddHandlerOnResize(@sourceResized);
  updateLayout;
  // editor color, font, highlighter and layout may still be defaults
  // while the IDE starts; resync shortly after
  fInitRetries := 0;
  fInitTimer.Enabled := True;
end;

procedure TMiniMapView.syncMapProps;
begin
  fMapEdit.Font := fEdit.Font;
  fMapEdit.Font.Size := fFontSize;
  fMapEdit.ShareTextBufferFrom(fEdit);
  fMapEdit.Highlighter := fEdit.Highlighter;
  fMapEdit.RightEdge := fEdit.RightEdge;
  fMapEdit.Color := fEdit.Color;
  // the right-edge color doubles as the divider color (clDefault dividers
  // resolve to it at paint time); the background color hides both on the map
  fMapEdit.RightEdgeColor := fMapEdit.Color;
  fEdit.RegisterStatusChangedHandler(@statusChanged, [scTopLine, scLinesInWindow, scHandleCreated, scFontOrStyleChanged]);
end;

procedure TMiniMapView.unhook;
begin
  if fEdit = nil then exit;
  fMapEdit.UnShareTextBuffer;
  fEdit.UnRegisterStatusChangedHandler(@statusChanged);
  fEdit.RemoveHandlerOnResize(@sourceResized);
  FreeAndNil(fGutterPart);
  // detach before the editor goes away
  Parent := nil;
  fEdit := nil;
  fEditor := nil;
end;

procedure TMiniMapView.reconfigure;
begin
  if fEdit = nil then exit;
  fMapEdit.Color := fEdit.Color;
  fMapEdit.RightEdgeColor := fMapEdit.Color; // keeps dividers hidden
  fMapEdit.Font := fEdit.Font;
  fMapEdit.Font.Size := fFontSize;
  // drop and reassign so SynEdit rebuilds its markup for the new scheme
  fMapEdit.Highlighter := nil;
  fMapEdit.Highlighter := fEdit.Highlighter;
  fMapEdit.Invalidate;
end;

procedure TMiniMapView.updateLayout;
begin
  if (fEdit = nil) or (fGutterPart = nil) then exit;
  fGutterPart.Width := Width;
  // rightmost band of the client area, directly left of the vertical scrollbar
  SetBounds(fEdit.ClientWidth-Width, 0, Width, fEdit.ClientHeight);
end;

procedure TMiniMapView.sourceResized(Sender: TObject);
begin
  updateLayout;
end;

procedure TMiniMapView.statusChanged(Sender: TObject; Changes: TSynStatusChanges);
begin
  // a late handle or font/style change means the visuals copied at bind
  // time were defaults; pull them again
  if (fEdit <> nil) and ((scHandleCreated in Changes) or (scFontOrStyleChanged in Changes)) then reconfigure;
  updateLayout;
  syncBand;
end;

procedure TMiniMapView.initTimerTick(Sender: TObject);
begin
  fInitTimer.Enabled := False;
  if fEdit = nil then exit;
  inc(fInitRetries);
  // both handles must exist before colors and layout mean anything
  if not (fEdit.HandleAllocated and fMapEdit.HandleAllocated) then begin
    if fInitRetries < 40 then fInitTimer.Enabled := True;
    exit;
  end;
  reconfigure;
  updateLayout;
  syncBand;
  // a TopLine round trip makes SynEdit rebuild its markup and repaint;
  // a plain Invalidate can keep showing stale content after startup
  if fMapEdit.TopLine > 1 then begin
    fMapEdit.TopLine := fMapEdit.TopLine-1;
    fMapEdit.TopLine := fMapEdit.TopLine+1;
  end else begin
    fMapEdit.TopLine := fMapEdit.TopLine+1;
    fMapEdit.TopLine := fMapEdit.TopLine-1;
  end;
  fMapEdit.Invalidate;
  // the IDE keeps restyling editors while it starts; resync a few times
  if fInitRetries < 8 then fInitTimer.Enabled := True;
end;

procedure TMiniMapView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = fGutterPart) then fGutterPart := nil;
end;

function TMiniMapView.effectiveBandColor: TColor;

  function mix(base, tint: integer): integer;
  begin
    result := base+((tint-base)*fBandTint) div 100;
  end;

begin
  // tint blended into the editor background at bandTint percent; the
  // source editor color is authoritative but arrives late at startup
  var baseColor: TColor := clNone;
  if fEdit <> nil then baseColor := fEdit.Color;
  if (baseColor = clNone) or (baseColor = clDefault) then baseColor := fMapEdit.Color;
  if (baseColor = clNone) or (baseColor = clDefault) then baseColor := clWindow;
  var base := ColorToRGB(baseColor);
  var tint := if fBandColor = clDefault then $FFFFFF else ColorToRGB(fBandColor);
  result := TColor(mix(base and $FF, tint and $FF) or (mix((base shr 8) and $FF, (tint shr 8) and $FF) shl 8) or (mix((base shr 16) and $FF, (tint shr 16) and $FF) shl 16));
end;

procedure TMiniMapView.lineMarkup(Sender: TObject; const Info: TSpecialLineMarkupExInfo; var Special: boolean; Markup: TLazEditTextAttributeModifier);
begin
  if fEdit = nil then exit;
  // an editor that has not been laid out yet reports a window as tall as
  // the whole buffer; tinting that would flood the map
  var lineHeight := fEdit.LineHeight;
  if lineHeight <= 0 then exit;
  if fEdit.LinesInWindow > (fEdit.ClientHeight div lineHeight)+1 then exit;
  // the band is LinesInWindow lines tall; the part hanging past the end
  // of the file is painted by paintPastEofBand instead
  if (Info.Line >= fEdit.TopLine) and (Info.Line < fEdit.TopLine+fEdit.LinesInWindow) then begin
    Markup.Background := effectiveBandColor;
    Markup.Foreground := clNone; // keep the syntax colors
    Special := True;
  end;
end;

procedure TMiniMapView.paintPastEofBand(aCanvas: TCanvas);
begin
  if fEdit = nil then exit;
  var lh := fMapEdit.LineHeight;
  if (lh <= 0) or (fEdit.LineHeight <= 0) then exit;
  if fEdit.LinesInWindow > (fEdit.ClientHeight div fEdit.LineHeight)+1 then exit;
  var bandFirst := fEdit.TopLine;
  var bandLast := bandFirst+fEdit.LinesInWindow-1;
  if bandLast <= fEdit.Lines.Count then exit;
  var startLine := Max(bandFirst, fEdit.Lines.Count+1);
  var y1 := (startLine-fMapEdit.TopLine)*lh;
  var y2 := (bandLast+1-fMapEdit.TopLine)*lh;
  if (y2 <= 0) or (y1 >= fMapEdit.ClientHeight) then exit;
  aCanvas.Brush.Color := effectiveBandColor;
  aCanvas.FillRect(0, Max(y1, 0), fMapEdit.ClientWidth, Min(y2, fMapEdit.ClientHeight));
end;

// the map scrolls proportionally to the source: with S = source scroll
// range and M = map scroll range (M <= S), source position s puts the
// map at line 1+s*M/S and the band top at pixel s*(S-M)*LH/S, which is
// easy to invert for dragging; M is picked so the band bottom meets the
// map bottom exactly at maximum scroll, keeping the band on the map for
// the whole ride

function TMiniMapView.sourceMaxTopLine: integer;
begin
  result := fEdit.Lines.Count;
  if not (eoScrollPastEof in fEdit.Options) then result := result-fEdit.LinesInWindow+1;
  if result < 1 then result := 1;
end;

procedure TMiniMapView.scrollRanges(out s, m: integer);
begin
  s := sourceMaxTopLine-1;
  // at full scroll the band spans maxTop..maxTop+LinesInWindow-1; this m
  // lands its last line on the last map row
  m := sourceMaxTopLine+fEdit.LinesInWindow-1-fMapEdit.LinesInWindow;
  if m < 0 then m := 0;
  if m > s then m := s;
end;

function TMiniMapView.bandTopPixel: integer;
begin
  result := 0;
  if fEdit = nil then exit;
  scrollRanges(var s, var m);
  if s <= 0 then exit;
  result := ((fEdit.TopLine-1)*(s-m)*fMapEdit.LineHeight) div s;
end;

function TMiniMapView.mapPixelToSourceTop(px: integer): integer;
begin
  result := 1;
  if fEdit = nil then exit;
  scrollRanges(var s, var m);
  var denom := (s-m)*fMapEdit.LineHeight;
  if (s <= 0) or (denom <= 0) then exit;
  result := 1+(px*s+denom div 2) div denom;
  if result < 1 then result := 1;
  if result > s+1 then result := s+1;
end;

// invalidates the map rows of source lines first..last, including the
// stretch past eof that paintPastEofBand covers
procedure TMiniMapView.invalidateBand(first, last: integer);
begin
  var cnt := fEdit.Lines.Count;
  if first <= cnt then fMapEdit.InvalidateLines(first, Min(last, cnt));
  if (last <= cnt) or (not fMapEdit.HandleAllocated) then exit;
  var lh := fMapEdit.LineHeight;
  if lh <= 0 then exit;
  var r := Rect(0, Max(0, (Max(first, cnt+1)-fMapEdit.TopLine)*lh), fMapEdit.ClientWidth, Min(fMapEdit.ClientHeight, (last+1-fMapEdit.TopLine)*lh));
  if r.Bottom > r.Top then InvalidateRect(fMapEdit.Handle, @r, False);
end;

procedure TMiniMapView.syncBand;
begin
  if fEdit = nil then exit;
  scrollRanges(var s, var m);
  fMapEdit.TopLine := if (s <= 0) or (m <= 0) then 1 else 1+((fEdit.TopLine-1)*m) div s;
  // repaint only the rows whose band membership changed; a full
  // Invalidate per scroll step repaints a few hundred tiny lines and
  // stutters on widgetsets without a backing store
  var first := fEdit.TopLine;
  var last := first+fEdit.LinesInWindow-1;
  if (first = fBandFirst) and (last = fBandLast) then exit;
  if (fBandLast < fBandFirst) or (last < fBandFirst) or (first > fBandLast) then begin
    // disjoint or no previous band: repaint both ranges whole
    if fBandLast >= fBandFirst then invalidateBand(fBandFirst, fBandLast);
    invalidateBand(first, last);
  end else begin
    // overlapping move: repaint only the edges that shifted
    if first <> fBandFirst then invalidateBand(Min(first, fBandFirst), Max(first, fBandFirst)-1);
    if last <> fBandLast then invalidateBand(Min(last, fBandLast)+1, Max(last, fBandLast));
  end;
  fBandFirst := first;
  fBandLast := last;
end;

procedure TMiniMapView.mapMouseDown(y: integer);
begin
  if fEdit = nil then exit;
  var bandTop := bandTopPixel;
  var bandHeight := fEdit.LinesInWindow*fMapEdit.LineHeight;
  if (y < bandTop) or (y >= bandTop+bandHeight) then begin
    // jump: center the band on the click, then keep dragging
    fGrabOffset := bandHeight div 2;
    fEdit.TopLine := mapPixelToSourceTop(y-fGrabOffset);
  end else
    fGrabOffset := y-bandTop;
  fDragging := True;
  // the click must not steal the caret from the editor
  if fEdit.CanSetFocus then fEdit.SetFocus;
end;

procedure TMiniMapView.applyDrag(y: integer);
begin
  fEdit.TopLine := mapPixelToSourceTop(y-fGrabOffset);
end;

procedure TMiniMapView.mapMouseMove(y: integer);
begin
  if (not fDragging) or (fEdit = nil) then exit;
  // coalesce the mouse-move flood to one scroll per timer tick; widgetsets
  // deliver every move and a high-polling mouse outruns the repaints
  if fDragTimer.Enabled then begin
    fDragY := y;
    fDragPending := True;
    exit;
  end;
  applyDrag(y);
  fDragTimer.Enabled := True;
end;

procedure TMiniMapView.dragTimerTick(Sender: TObject);
begin
  fDragTimer.Enabled := False;
  if (not fDragPending) or (fEdit = nil) then exit;
  fDragPending := False;
  applyDrag(fDragY);
  // keep the window rolling while moves keep coming
  fDragTimer.Enabled := fDragging;
end;

procedure TMiniMapView.mapMouseUp;
begin
  // land exactly where the mouse was released
  if fDragPending and (fEdit <> nil) then applyDrag(fDragY);
  fDragPending := False;
  fDragTimer.Enabled := False;
  fDragging := False;
end;

procedure TMiniMapView.mapMouseWheel(wheelDelta: integer);
begin
  if fEdit = nil then exit;
  var lines := Mouse.WheelScrollLines;
  if lines <= 0 then lines := 3;
  fEdit.TopLine := fEdit.TopLine-(wheelDelta*lines) div 120;
end;

procedure TMiniMapView.setBandColor(aValue: TColor);
begin
  if fBandColor = aValue then exit;
  fBandColor := aValue;
  fMapEdit.Invalidate;
end;

procedure TMiniMapView.setBandTint(aValue: integer);
begin
  if aValue < BAND_TINT_MIN then aValue := BAND_TINT_MIN;
  if aValue > BAND_TINT_MAX then aValue := BAND_TINT_MAX;
  if fBandTint = aValue then exit;
  fBandTint := aValue;
  fMapEdit.Invalidate;
end;

procedure TMiniMapView.setFontSize(aValue: integer);
begin
  if fFontSize = aValue then exit;
  fFontSize := aValue;
  fMapEdit.Font.Size := fFontSize;
end;

end.
