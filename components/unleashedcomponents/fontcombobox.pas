{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit FontComboBox;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, LCLType, ControlPaint, PopupWindow;

type
  TFontFilter = (ffAll, ffMonospace, ffProportional);

  TFontComboBox = class;

  { TFontList }

  // the rows of the drop down: the recent fonts, a line, then all of them,
  // each name in its own face
  TFontList = class(TCustomControl)
  private
    FBox: TFontComboBox;
    FTop, FHot: integer;
    FDraggingThumb: boolean;
    FDragOffset: integer;
    function rowHeight: integer;
    function visibleRows: integer;
    function scrollRect: TRect;
    function thumbRect: TRect;
    function rowAt(y: integer): integer;
    procedure setTop(value: integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(box: TFontComboBox); reintroduce;
    procedure ShowRow(index: integer);
  end;

  { TFontComboBox }

  // a font picked from a list that shows every name in its own face, with
  // the fonts used last on top. Typing jumps to the first name that starts
  // with the letters typed; Up, Down, Page Up and Page Down walk the list
  TFontComboBox = class(TCustomControl)
  private
    FFontName, FPreviewText, FTyped: string;
    FFonts: TStringList; // the names on offer, after the filter
    FRecent: TStringList;
    FRows: TStringList; // the rows of the list; an empty one is the line
    FFilter: TFontFilter;
    FShowPreview, FShowInField, FShowRecent: boolean;
    FMaxRecent, FDropDownCount, FCornerRadius, FPadding: integer;
    FBorderColor, FFocusBorderColor, FFieldColor: TColor;
    FCursorRow: integer;
    FPopup: TDropPopup;
    FList: TFontList;
    FTypeTimer: TTimer;
    FFixedPitch: TStringList; // name=1 for monospace, name=0 otherwise
    FHotArrow: boolean;
    FAntialiasing: TAntialiasSetting;
    FOnChange, FOnDropDown, FOnCloseUp: TNotifyEvent;
    procedure setFontName(const value: string);
    procedure setPreviewText(const value: string);
    procedure setFilter(value: TFontFilter);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function getRecent: TStrings;
    procedure setRecent(value: TStrings);
    function isMonospace(const name: string): boolean;
    procedure loadFonts;
    procedure buildRows;
    function rowOf(const name: string): integer;
    procedure moveCursor(delta: integer);
    procedure stepFont(delta: integer);
    function findTyped(list: TStrings; first: integer): integer;
    procedure pickRow(row: integer);
    procedure typeTimeout(Sender: TObject);
    procedure popupDismiss(Sender: TObject);
    function arrowRect: TRect;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key: TUTF8Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DropDown;
    procedure CloseUp;
    function DroppedDown: boolean;
    // the fonts on offer now, after the filter
    function FontCount: integer;
    function Fonts(index: integer): string;
    // reads the fonts of the system again
    procedure RefreshFonts;
  published
    // the picked font; a name the system lacks shows in the field all the same
    property FontName: string read FFontName write setFontName;
    // the text the list shows in each face; empty shows the names
    property PreviewText: string read FPreviewText write setPreviewText;
    property Filter: TFontFilter read FFilter write setFilter default ffAll;
    // the names in their own faces in the list
    property ShowPreview: boolean index 0 read getFlag write setFlag default true;
    // the field shows the picked name in its face
    property ShowInField: boolean index 1 read getFlag write setFlag default false;
    property ShowRecent: boolean index 2 read getFlag write setFlag default true;
    // the fonts picked last, newest first; the list keeps MaxRecent of them
    property RecentFonts: TStrings read getRecent write setRecent;
    property MaxRecent: integer index 0 read getMetric write setMetric default 5;
    // the rows the drop down shows before it scrolls
    property DropDownCount: integer index 1 read getMetric write setMetric default 12;
    property CornerRadius: integer index 2 read getMetric write setMetric default 4;
    property Padding: integer index 3 read getMetric write setMetric default 6;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property FocusBorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FieldColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property Align;
    property Anchors;
    property AutoSize default true;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default true;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnResize;
  end;

implementation

uses
  Math;

{ TFontList }

constructor TFontList.Create(box: TFontComboBox);
begin
  inherited Create(box);
  FBox := box;
  FHot := -1;
  ControlStyle := ControlStyle+[csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
end;

function TFontList.rowHeight: integer;
begin
  result := Canvas.TextHeight('Hg')+scaled(self, 10);
end;

function TFontList.visibleRows: integer;
begin
  result := Max(ClientHeight div Max(rowHeight, 1), 1);
end;

function TFontList.scrollRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if FBox.FRows.Count <= visibleRows then exit;
  var w := scaled(self, 6);
  result := Rect(ClientWidth-w-scaled(self, 2), scaled(self, 2), ClientWidth-scaled(self, 2), ClientHeight-scaled(self, 2));
end;

function TFontList.thumbRect: TRect;
begin
  var track := scrollRect;
  if track.Width = 0 then exit(track);
  var total := FBox.FRows.Count;
  var size := Max(track.Height*visibleRows div total, scaled(self, 16));
  var travel := track.Height-size;
  var top := track.Top+(if total > visibleRows then travel*FTop div (total-visibleRows) else 0);
  result := Rect(track.Left, top, track.Right, top+size);
end;

function TFontList.rowAt(y: integer): integer;
begin
  result := FTop+y div Max(rowHeight, 1);
  if (result < 0) or (result >= FBox.FRows.Count) or (FBox.FRows[result] = '') then result := -1;
end;

procedure TFontList.setTop(value: integer);
begin
  value := EnsureRange(value, 0, Max(FBox.FRows.Count-visibleRows, 0));
  if FTop = value then exit;
  FTop := value;
  Invalidate;
end;

procedure TFontList.ShowRow(index: integer);
begin
  if index < FTop then setTop(index)
  else if index >= FTop+visibleRows then setTop(index-visibleRows+1);
  Invalidate;
end;

procedure TFontList.Paint;
begin
  var back := ColorToRGB(clWindow);
  var text := ColorToRGB(clWindowText);
  var accent := ColorToRGB(clHighlight);
  var h := rowHeight;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FBox.FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  var right := if scrollRect.Width > 0 then scrollRect.Left-scaled(self, 2) else ClientWidth;
  for var i := FTop to Min(FTop+visibleRows, FBox.FRows.Count-1) do begin
    var y := (i-FTop)*h;
    var r := Rect(scaled(self, 3), y+1, right-scaled(self, 3), y+h-1);
    if FBox.FRows[i] = '' then begin
      paintLine(sp, r.Left+scaled(self, 6), y+h div 2, r.Right-scaled(self, 6), y+h div 2, blend(back, text, 20), 1);
      continue;
    end;
    if i = FBox.FCursorRow then paintRoundRect(sp, r, scaled(self, 4), accent, clNone)
    else if (i = FHot) and hoverEnabled then paintRoundRect(sp, r, scaled(self, 4), hoverColor(back), clNone);
  end;
  if scrollRect.Width > 0 then begin
    paintPill(sp, scrollRect, blend(back, text, 6), clNone);
    paintPill(sp, thumbRect, blend(back, text, (if FDraggingThumb then 45 else 30)), clNone);
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  for var i := FTop to Min(FTop+visibleRows, FBox.FRows.Count-1) do begin
    var name := FBox.FRows[i];
    if name = '' then continue;
    var y := (i-FTop)*h;
    var r := Rect(scaled(self, 12), y, right-scaled(self, 8), y+h);
    Canvas.Font := FBox.Font;
    if FBox.FShowPreview then Canvas.Font.Name := name;
    Canvas.Font.Color := if i = FBox.FCursorRow then contrastText(accent) else text;
    Canvas.TextRect(r, r.Left, r.Top, (if FBox.FPreviewText <> '' then FBox.FPreviewText else name), style);
  end;
  Canvas.Font := FBox.Font;
  Canvas.Brush.Style := bsSolid;
end;

procedure TFontList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if scrollRect.Contains(Point(X, Y)) then begin
    var thumb := thumbRect;
    if thumb.Contains(Point(X, Y)) then begin
      FDraggingThumb := true;
      FDragOffset := Y-thumb.Top;
    end else setTop(FTop+(if Y < thumb.Top then -visibleRows else visibleRows));
    Invalidate;
    exit;
  end;
  var row := rowAt(Y);
  if row >= 0 then FBox.pickRow(row);
end;

procedure TFontList.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDraggingThumb then begin
    var track := scrollRect;
    var thumb := thumbRect;
    var travel := Max(track.Height-thumb.Height, 1);
    setTop(Round((Y-FDragOffset-track.Top)/travel*(FBox.FRows.Count-visibleRows)));
    exit;
  end;
  var row := if scrollRect.Contains(Point(X, Y)) then -1 else rowAt(Y);
  if row <> FHot then begin
    FHot := row;
    Invalidate;
  end;
end;

procedure TFontList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FDraggingThumb then begin
    FDraggingThumb := false;
    Invalidate;
  end;
end;

procedure TFontList.MouseLeave;
begin
  inherited MouseLeave;
  if FHot >= 0 then begin
    FHot := -1;
    Invalidate;
  end;
end;

function TFontList.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result then exit;
  setTop(FTop-Sign(WheelDelta)*3);
  result := true;
end;

{ TFontComboBox }

constructor TFontComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FFonts := TStringList.Create;
  FRecent := TStringList.Create;
  FRows := TStringList.Create;
  FFixedPitch := TStringList.Create;
  FFixedPitch.Sorted := true;
  FShowPreview := true;
  FShowRecent := true;
  FMaxRecent := 5;
  FDropDownCount := 12;
  FCornerRadius := 4;
  FPadding := 6;
  FBorderColor := clDefault;
  FFocusBorderColor := clDefault;
  FFieldColor := clDefault;
  FCursorRow := -1;
  FTypeTimer := TTimer.Create(self);
  FTypeTimer.Enabled := false;
  FTypeTimer.Interval := 900;
  FTypeTimer.OnTimer := @typeTimeout;
  TabStop := true;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TFontComboBox.Destroy;
begin
  FreeAndNil(FPopup);
  FFixedPitch.Free;
  FRows.Free;
  FRecent.Free;
  FFonts.Free;
  inherited Destroy;
end;

class function TFontComboBox.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 27;
end;

procedure TFontComboBox.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  PreferredWidth := 0;
  PreferredHeight := Canvas.TextHeight('Hg')+scaled(self, FPadding)*2-scaled(self, 2);
end;

// -- fonts ----------------------

// the width of narrow and wide letters tells a fixed pitch; the answers stay
function TFontComboBox.isMonospace(const name: string): boolean;
begin
  var i := FFixedPitch.IndexOfName(name);
  if i >= 0 then exit(FFixedPitch.ValueFromIndex[i] = '1');
  var probe := autofree TBitmap.Create;
  probe.Canvas.Font.Name := name;
  probe.Canvas.Font.Size := 12;
  result := probe.Canvas.TextWidth('iiiiiiiiii') = probe.Canvas.TextWidth('WWWWWWWWWW');
  FFixedPitch.Add(name+'='+(if result then '1' else '0'));
end;

procedure TFontComboBox.loadFonts;
begin
  FFonts.Clear;
  FFonts.Sorted := true;
  FFonts.Duplicates := dupIgnore;
  FFonts.CaseSensitive := false;
  for var name in Screen.Fonts do begin
    // the vertical twins of the East Asian fonts carry an @ in front
    if (name = '') or (name[1] = '@') then continue;
    if (FFilter = ffMonospace) and not isMonospace(name) then continue;
    if (FFilter = ffProportional) and isMonospace(name) then continue;
    FFonts.Add(name);
  end;
end;

procedure TFontComboBox.RefreshFonts;
begin
  FFixedPitch.Clear;
  loadFonts;
  buildRows;
  Invalidate;
end;

function TFontComboBox.FontCount: integer;
begin
  if FFonts.Count = 0 then loadFonts;
  result := FFonts.Count;
end;

function TFontComboBox.Fonts(index: integer): string;
begin
  if FFonts.Count = 0 then loadFonts;
  result := FFonts[index];
end;

procedure TFontComboBox.buildRows;
begin
  if FFonts.Count = 0 then loadFonts;
  FRows.Clear;
  if FShowRecent then begin
    for var name in FRecent do
      if FFonts.IndexOf(name) >= 0 then FRows.Add(name);
    if FRows.Count > 0 then FRows.Add('');
  end;
  FRows.AddStrings(FFonts);
end;

function TFontComboBox.rowOf(const name: string): integer;
begin
  result := -1;
  for var i := 0 to FRows.Count-1 do
    if SameText(FRows[i], name) then exit(i);
end;

procedure TFontComboBox.moveCursor(delta: integer);
begin
  if FRows.Count = 0 then exit;
  var row := FCursorRow;
  if row < 0 then row := if delta > 0 then -1 else FRows.Count;
  row := EnsureRange(row+delta, 0, FRows.Count-1);
  // the line between the recent fonts and the others takes no cursor
  if FRows[row] = '' then row := EnsureRange(row+Sign(delta), 0, FRows.Count-1);
  FCursorRow := row;
  FList.ShowRow(row);
end;

// the closed field steps through the whole list, without the recent fonts
procedure TFontComboBox.stepFont(delta: integer);
begin
  if FFonts.Count = 0 then loadFonts;
  if FFonts.Count = 0 then exit;
  var i := FFonts.IndexOf(FFontName);
  i := if i < 0 then (if delta > 0 then 0 else FFonts.Count-1) else EnsureRange(i+delta, 0, FFonts.Count-1);
  FontName := FFonts[i];
end;

// the first name from first on that starts with the letters typed; one
// letter typed again and again walks the names that start with it
function TFontComboBox.findTyped(list: TStrings; first: integer): integer;
begin
  for var i := first to list.Count-1 do
    if SameText(Copy(list[i], 1, length(FTyped)), FTyped) then exit(i);
  result := -1;
  if (length(FTyped) < 2) or (FTyped <> StringOfChar(FTyped[1], length(FTyped))) then exit;
  var current := if DroppedDown then FCursorRow else list.IndexOf(FFontName);
  for var pass := 0 to 1 do
    for var i := (if pass = 0 then Max(current+1, first) else first) to list.Count-1 do
      if SameText(Copy(list[i], 1, 1), FTyped[1]) then exit(i);
end;

procedure TFontComboBox.pickRow(row: integer);
begin
  if (row < 0) or (row >= FRows.Count) or (FRows[row] = '') then exit;
  FontName := FRows[row];
  CloseUp;
end;

procedure TFontComboBox.typeTimeout(Sender: TObject);
begin
  FTypeTimer.Enabled := false;
  FTyped := '';
end;

// -- drop down ----------------------

procedure TFontComboBox.DropDown;
begin
  if csDesigning in ComponentState then exit;
  if FPopup = nil then begin
    FPopup := TDropPopup.Create(self);
    FPopup.OnDismiss := @popupDismiss;
    FList := TFontList.Create(self);
    FList.Parent := FPopup;
  end;
  buildRows;
  FTyped := '';
  FList.Font := Font;
  FCursorRow := rowOf(FFontName);
  var rows := Min(Max(FRows.Count, 1), Max(FDropDownCount, 1));
  var h := rows*(Canvas.TextHeight('Hg')+scaled(self, 10));
  var w := Max(Width, scaled(self, 220));
  FList.BoundsRect := Rect(1, 1, w-1, h+1);
  FPopup.Drop(self, w, h+2);
  // the picked font in the middle, or on top among the recent ones
  FList.FTop := 0;
  if FCursorRow >= 0 then FList.setTop(FCursorRow-FList.visibleRows div 2);
  Invalidate;
  if Assigned(FOnDropDown) then FOnDropDown(self);
end;

procedure TFontComboBox.CloseUp;
begin
  if not DroppedDown then exit;
  FPopup.Close;
  Invalidate;
  if Assigned(FOnCloseUp) then FOnCloseUp(self);
end;

function TFontComboBox.DroppedDown: boolean;
begin
  result := (FPopup <> nil) and FPopup.Visible;
end;

procedure TFontComboBox.popupDismiss(Sender: TObject);
begin
  CloseUp;
end;

// -- painting ----------------------

function TFontComboBox.arrowRect: TRect;
begin
  var size := Canvas.TextHeight('Hg');
  var pad := scaled(self, FPadding);
  result := Rect(ClientWidth-pad-size, (ClientHeight-size) div 2, ClientWidth-pad, (ClientHeight-size) div 2+size);
end;

procedure TFontComboBox.Paint;
begin
  var border := pick(FBorderColor, clBtnShadow);
  if (Focused or DroppedDown) and ringEnabled then border := pick(FFocusBorderColor, ringColor);
  var field := pick(FFieldColor, clWindow);
  if not Enabled then field := ColorToRGB(clBtnFace);
  var glyph := ColorToRGB(if Enabled then clGrayText else clBtnShadow);
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  paintRoundRect(sp, ClientRect, scaled(self, FCornerRadius), field, border);
  var a := arrowRect;
  if (FHotArrow or DroppedDown) and hoverEnabled and Enabled then paintCircle(sp, (a.Left+a.Right) div 2, (a.Top+a.Bottom) div 2, a.Width div 2, hoverColor(field), clNone);
  paintChevron(sp, a, (if DroppedDown then cdUp else cdDown), Max(scaled(self, 8), 6), glyph);
  sp.Flush;
  applyTextQuality(Canvas);
  var pad := scaled(self, FPadding);
  var box := Rect(pad, 0, a.Left-pad div 2, ClientHeight);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  Canvas.Brush.Style := bsClear;
  Canvas.Font := Font;
  if FShowInField and (FFontName <> '') then Canvas.Font.Name := FFontName;
  Canvas.Font.Color := ColorToRGB(if Enabled then clWindowText else clGrayText);
  Canvas.TextRect(box, box.Left, box.Top, FFontName, style);
  Canvas.Font := Font;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TFontComboBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = 0 then exit;
  var dropped := DroppedDown;
  var page := if dropped then FList.visibleRows-1 else Max(FDropDownCount-1, 1);
  var count := Max(FRows.Count, FFonts.Count);
  match Key of
    VK_DOWN, VK_UP:
      if ssAlt in Shift then begin
        if dropped then CloseUp else DropDown;
      end else if dropped then moveCursor(if Key = VK_DOWN then 1 else -1)
      else stepFont(if Key = VK_DOWN then 1 else -1);
    VK_NEXT, VK_PRIOR, VK_HOME, VK_END: begin
      var delta := match Key of
        VK_NEXT: page;
        VK_PRIOR: -page;
        VK_HOME: -count;
      else
        count
      end;
      if dropped then moveCursor(delta) else stepFont(delta);
    end;
    VK_F4: if dropped then CloseUp else DropDown;
    VK_RETURN: if DroppedDown then pickRow(FCursorRow) else exit;
    VK_ESCAPE: if DroppedDown then CloseUp else exit;
    VK_TAB: begin
      CloseUp;
      exit;
    end;
  else
    exit;
  end;
  Key := 0;
end;

// the letters typed in a row jump to the first font that starts with them
procedure TFontComboBox.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited UTF8KeyPress(UTF8Key);
  if (UTF8Key = '') or (UTF8Key[1] < ' ') then exit;
  FTyped += UTF8Key;
  FTypeTimer.Enabled := false;
  FTypeTimer.Enabled := true;
  if DroppedDown then begin
    // the full list under the recent fonts, so the order is alphabetic
    var row := findTyped(FRows, FRows.IndexOf('')+1);
    if row >= 0 then begin
      FCursorRow := row;
      FList.ShowRow(row);
    end;
  end else begin
    if FFonts.Count = 0 then loadFonts;
    var i := findTyped(FFonts, 0);
    if i >= 0 then FontName := FFonts[i];
  end;
  UTF8Key := '';
end;

procedure TFontComboBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then exit;
  if TabStop and CanSetFocus and not Focused then SetFocus;
  if DroppedDown then CloseUp else DropDown;
end;

procedure TFontComboBox.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := arrowRect.Contains(Point(X, Y));
  if hot <> FHotArrow then begin
    FHotArrow := hot;
    Invalidate;
  end;
end;

procedure TFontComboBox.MouseLeave;
begin
  inherited MouseLeave;
  if FHotArrow then begin
    FHotArrow := false;
    Invalidate;
  end;
end;

function TFontComboBox.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or not Focused or DroppedDown then exit;
  stepFont(-Sign(WheelDelta));
  result := true;
end;

procedure TFontComboBox.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TFontComboBox.DoExit;
begin
  inherited DoExit;
  CloseUp;
  Invalidate;
end;

procedure TFontComboBox.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

// -- properties ----------------------

procedure TFontComboBox.setFontName(const value: string);
begin
  if FFontName = value then exit;
  FFontName := value;
  if (value <> '') and not (csLoading in ComponentState) and not (csDesigning in ComponentState) then begin
    // the pick goes to the top of the recent fonts
    var i := FRecent.IndexOf(value);
    if i >= 0 then FRecent.Delete(i);
    FRecent.Insert(0, value);
    while FRecent.Count > FMaxRecent do FRecent.Delete(FRecent.Count-1);
    if not DroppedDown then FRows.Clear;
  end;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TFontComboBox.setPreviewText(const value: string);
begin
  FPreviewText := value;
  if DroppedDown then FList.Invalidate;
end;

procedure TFontComboBox.setFilter(value: TFontFilter);
begin
  if FFilter = value then exit;
  FFilter := value;
  loadFonts;
  FRows.Clear;
  Invalidate;
end;

function TFontComboBox.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowPreview;
    1: FShowInField;
  else
    FShowRecent
  end;
end;

procedure TFontComboBox.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowPreview := value;
    1: FShowInField := value;
  else
    begin
      FShowRecent := value;
      FRows.Clear;
    end;
  end;
  Invalidate;
end;

function TFontComboBox.getMetric(index: integer): integer;
begin
  result := match index of
    0: FMaxRecent;
    1: FDropDownCount;
    2: FCornerRadius;
  else
    FPadding
  end;
end;

procedure TFontComboBox.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: begin
      FMaxRecent := value;
      while FRecent.Count > FMaxRecent do FRecent.Delete(FRecent.Count-1);
    end;
    1: FDropDownCount := Max(value, 1);
    2: FCornerRadius := value;
  else
    FPadding := value;
  end;
  InvalidatePreferredSize;
  AdjustSize;
  Invalidate;
end;

function TFontComboBox.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBorderColor;
    1: FFocusBorderColor;
  else
    FFieldColor
  end;
end;

procedure TFontComboBox.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FFocusBorderColor := value;
  else
    FFieldColor := value;
  end;
  Invalidate;
end;

procedure TFontComboBox.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

function TFontComboBox.getRecent: TStrings;
begin
  result := FRecent;
end;

procedure TFontComboBox.setRecent(value: TStrings);
begin
  FRecent.Assign(value);
  FRows.Clear;
end;

end.
