{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit CheckComboBox;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint, PopupWindow;

type
  TCheckComboBox = class;
  TCheckSummary = (csList, csCount, csCaption);
  TCheckItemEvent = procedure(Sender: TObject; index: integer; checked: boolean) of object;

  { TCheckList }

  // the rows of the drop-down: a check box and a caption each
  TCheckList = class(TCustomControl)
  private
    FOwner: TCheckComboBox;
    FHot: integer;
    function rowAt(y: integer): integer;
    function rowPx: integer;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  end;

  { TCheckComboBox }

  // a combo box that takes more than one choice: the drop-down lists the
  // items with a check box each, the box shows the chosen ones as a list,
  // a count or a caption of its own
  TCheckComboBox = class(TCustomControl)
  private
    FItems: TStrings;
    FChecked: array of boolean;
    FPopup: TDropPopup;
    FList: TCheckList;
    FSummary: TCheckSummary;
    FDelimiter, FEmptyText, FCountFormat: string;
    FShowSelectAll, FDown, FHot, FReadOnly: boolean;
    FCornerRadius, FBorderWidth, FMaxDropRows, FFocusRow: integer;
    FBorderColor, FTextColor, FBackColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnChange: TNotifyEvent;
    FOnItemCheck: TCheckItemEvent;
    FOnDropDown, FOnCloseUp: TNotifyEvent;
    procedure setItems(value: TStrings);
    procedure itemsChanged(Sender: TObject);
    function getChecked(index: integer): boolean;
    procedure setChecked(index: integer; value: boolean);
    function getCheckedText: string;
    procedure setCheckedText(const value: string);
    procedure setSummary(value: TCheckSummary);
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure popupDismiss(Sender: TObject);
    procedure buildPopup;
    procedure toggle(index: integer);
    function summaryText: string;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DropDown;
    procedure CloseUp;
    function DroppedDown: boolean;
    procedure CheckAll(value: boolean);
    function CheckedCount: integer;
    // the indices of the checked items
    procedure GetChecked(list: TList);
    property Checked[index: integer]: boolean read getChecked write setChecked;
  published
    property Items: TStrings read FItems write setItems;
    // the checked items by name, separated by the delimiter; streams with the form
    property CheckedText: string read getCheckedText write setCheckedText;
    property Summary: TCheckSummary read FSummary write setSummary default csList;
    // between the names in the box and in CheckedText
    property Delimiter: string index 0 read getText write setText;
    // the box with nothing checked
    property EmptyText: string index 1 read getText write setText;
    // a Format pattern with the count, for csCount
    property CountFormat: string index 2 read getText write setText;
    // the caption of the box in csCaption
    property Caption;
    // a first row that checks or clears every item
    property ShowSelectAll: boolean index 0 read getFlag write setFlag default true;
    property ReadOnly: boolean index 1 read getFlag write setFlag default false;
    property CornerRadius: integer index 0 read getMetric write setMetric default 4;
    property BorderWidth: integer index 1 read getMetric write setMetric default 1;
    // the drop-down scrolls past this many rows
    property MaxDropRows: integer index 2 read getMetric write setMetric default 10;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnItemCheck: TCheckItemEvent read FOnItemCheck write FOnItemCheck;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
    property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
    property Align;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
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
    property OnResize;
  end;

implementation

uses
  Math;

{ TCheckList }

function TCheckList.rowPx: integer;
begin
  result := lineHeightOf(Font)+scaled(self, 8);
end;

function TCheckList.rowAt(y: integer): integer;
begin
  // row 0 is the select-all row when it shows; items follow
  result := y div rowPx;
  var n := FOwner.FItems.Count+(if FOwner.FShowSelectAll then 1 else 0);
  if (result < 0) or (result >= n) then result := -1;
end;

procedure TCheckList.Paint;
begin
  var back := ColorToRGB(clWindow);
  var text := ColorToRGB(clWindowText);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FOwner.FAntialiasing);
  var rh := rowPx;
  var size := lineHeightOf(Font);
  var pad := scaled(self, 8);
  var radius := scaled(self, 3);
  var accent := ColorToRGB(clHighlight);
  var offset := if FOwner.FShowSelectAll then 1 else 0;
  var n := FOwner.FItems.Count+offset;
  for var i := 0 to n-1 do begin
    var top := i*rh;
    if (i = FHot) and hoverEnabled then sp.FillRect(Rect(0, top, ClientWidth, top+rh), hoverColor(back));
    if (i = FOwner.FFocusRow) then sp.FillRect(Rect(0, top, ClientWidth, top+rh), blend(back, accent, 20));
    var box := Rect(pad, top+(rh-size) div 2, pad+size, top+(rh+size) div 2);
    var on: boolean;
    var partial := false;
    if i < offset then begin
      var count := FOwner.CheckedCount;
      on := (count = FOwner.FItems.Count) and (count > 0);
      partial := (count > 0) and not on;
    end else on := FOwner.getChecked(i-offset);
    if on or partial then paintRoundRect(sp, box, radius, accent, accent)
    else paintRoundRect(sp, box, radius, back, blend(back, text, 40));
    if on then paintCheck(sp, box, size*7 div 10, contrastText(accent), Max(size div 7, 2))
    else if partial then sp.FillRect(Rect(box.Left+size div 4, (box.Top+box.Bottom) div 2-1, box.Right-size div 4, (box.Top+box.Bottom) div 2+1), contrastText(accent));
    if (i = offset-1) and (n > offset) then sp.FillRect(Rect(0, top+rh-1, ClientWidth, top+rh), blend(back, text, 15));
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := text;
  for var i := 0 to n-1 do begin
    var top := i*rh;
    var caption := if i < offset then '(All)' else FOwner.FItems[i-offset];
    Canvas.Font.Style := if i < offset then Font.Style+[fsItalic] else Font.Style;
    Canvas.TextOut(pad*2+size, top+(rh-lineHeightOf(Font)) div 2, caption);
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
end;

procedure TCheckList.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := rowAt(Y);
  if hot = FHot then exit;
  FHot := hot;
  Invalidate;
end;

procedure TCheckList.MouseLeave;
begin
  inherited MouseLeave;
  if FHot < 0 then exit;
  FHot := -1;
  Invalidate;
end;

procedure TCheckList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var row := rowAt(Y);
  if row < 0 then exit;
  FOwner.FFocusRow := row;
  FOwner.toggle(row);
end;

{ TCheckComboBox }

constructor TCheckComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csAcceptsControls, csSetCaption];
  FItems := TStringList.Create;
  TStringList(FItems).OnChange := @itemsChanged;
  FDelimiter := ', ';
  FEmptyText := '';
  FCountFormat := '%d selected';
  FShowSelectAll := true;
  FCornerRadius := 4;
  FBorderWidth := 1;
  FMaxDropRows := 10;
  FFocusRow := -1;
  FBorderColor := clDefault;
  FTextColor := clDefault;
  FBackColor := clDefault;
  FAntialiasing := asTheme;
  TabStop := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TCheckComboBox.Destroy;
begin
  FreeAndNil(FPopup);
  FItems.Free;
  inherited Destroy;
end;

class function TCheckComboBox.GetControlClassDefaultSize: TSize;
begin
  result.cx := 160;
  result.cy := 26;
end;

// -- the items ----------------------

procedure TCheckComboBox.itemsChanged(Sender: TObject);
begin
  // the checks follow the items by position; new items start clear
  var old := FChecked;
  SetLength(FChecked, FItems.Count);
  for var i := 0 to high(FChecked) do FChecked[i] := (i < length(old)) and old[i];
  if (FList <> nil) and FList.Visible then CloseUp;
  Invalidate;
end;

function TCheckComboBox.getChecked(index: integer): boolean;
begin
  result := (index >= 0) and (index < length(FChecked)) and FChecked[index];
end;

procedure TCheckComboBox.setChecked(index: integer; value: boolean);
begin
  if (index < 0) or (index >= FItems.Count) then exit;
  if length(FChecked) <> FItems.Count then SetLength(FChecked, FItems.Count);
  if FChecked[index] = value then exit;
  FChecked[index] := value;
  Invalidate;
  if FList <> nil then FList.Invalidate;
  if csLoading in ComponentState then exit;
  if Assigned(FOnItemCheck) then FOnItemCheck(self, index, value);
  if Assigned(FOnChange) then FOnChange(self);
end;

procedure TCheckComboBox.toggle(index: integer);
begin
  if FReadOnly then exit;
  if FShowSelectAll then begin
    if index = 0 then begin
      CheckAll(CheckedCount < FItems.Count);
      exit;
    end;
    dec(index);
  end;
  Checked[index] := not Checked[index];
end;

procedure TCheckComboBox.CheckAll(value: boolean);
begin
  var changed := false;
  SetLength(FChecked, FItems.Count);
  for var i := 0 to high(FChecked) do if FChecked[i] <> value then begin
    FChecked[i] := value;
    changed := true;
    if Assigned(FOnItemCheck) and not (csLoading in ComponentState) then FOnItemCheck(self, i, value);
  end;
  if not changed then exit;
  Invalidate;
  if FList <> nil then FList.Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

function TCheckComboBox.CheckedCount: integer;
begin
  result := 0;
  for var i := 0 to Min(high(FChecked), FItems.Count-1) do if FChecked[i] then inc(result);
end;

procedure TCheckComboBox.GetChecked(list: TList);
begin
  for var i := 0 to Min(high(FChecked), FItems.Count-1) do if FChecked[i] then list.Add(Pointer(PtrInt(i)));
end;

function TCheckComboBox.getCheckedText: string;
begin
  result := '';
  for var i := 0 to Min(high(FChecked), FItems.Count-1) do if FChecked[i] then begin
    if result <> '' then result += FDelimiter;
    result += FItems[i];
  end;
end;

procedure TCheckComboBox.setCheckedText(const value: string);
begin
  SetLength(FChecked, FItems.Count);
  for var i := 0 to high(FChecked) do FChecked[i] := false;
  var names := autofree TStringList.Create;
  names.Delimiter := if FDelimiter <> '' then FDelimiter[1] else ',';
  names.StrictDelimiter := true;
  names.DelimitedText := value;
  for var i := 0 to names.Count-1 do begin
    var index := FItems.IndexOf(Trim(names[i]));
    if index >= 0 then FChecked[index] := true;
  end;
  Invalidate;
end;

function TCheckComboBox.summaryText: string;
begin
  var count := CheckedCount;
  if count = 0 then exit(FEmptyText);
  result := match FSummary of
    csCount: Format(FCountFormat, [count]);
    csCaption: Caption;
  else
    getCheckedText
  end;
end;

// -- drop down ----------------------

procedure TCheckComboBox.buildPopup;
begin
  if FPopup <> nil then exit;
  FPopup := TDropPopup.Create(self);
  FPopup.OnDismiss := @popupDismiss;
  FList := TCheckList.Create(FPopup);
  FList.FOwner := self;
  FList.FHot := -1;
  FList.Parent := FPopup;
end;

procedure TCheckComboBox.DropDown;
begin
  if (csDesigning in ComponentState) or not Enabled or DroppedDown then exit;
  buildPopup;
  FList.Font := Font;
  var rows := FItems.Count+(if FShowSelectAll then 1 else 0);
  if rows = 0 then exit;
  var h := Min(rows, Max(FMaxDropRows, 1))*FList.rowPx;
  FList.SetBounds(1, 1, Width-2, rows*FList.rowPx);
  FFocusRow := -1;
  FPopup.Drop(self, Width, h+2);
  FDown := true;
  Invalidate;
  if Assigned(FOnDropDown) then FOnDropDown(self);
end;

procedure TCheckComboBox.CloseUp;
begin
  if not DroppedDown then exit;
  FPopup.Close;
  FDown := false;
  Invalidate;
  if Assigned(FOnCloseUp) then FOnCloseUp(self);
end;

function TCheckComboBox.DroppedDown: boolean;
begin
  result := (FPopup <> nil) and FPopup.Visible;
end;

procedure TCheckComboBox.popupDismiss(Sender: TObject);
begin
  FPopup.Close;
  FDown := false;
  Invalidate;
  if Assigned(FOnCloseUp) then FOnCloseUp(self);
end;

// -- painting ----------------------

procedure TCheckComboBox.Paint;
begin
  var back := pick(FBackColor, clWindow);
  var border := pick(FBorderColor, blend(back, clWindowText, 35));
  if FHot and Enabled then border := hoverShade(border, blend(back, clWindowText, 60));
  if (Focused or FDown) and ringEnabled then border := ringColor;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var radius := scaled(self, FCornerRadius);
  var r := ClientRect;
  paintRoundRect(sp, r, radius, (if Enabled then back else blend(back, clBtnFace, 50)), border, Max(scaled(self, FBorderWidth), 1));
  var pad := scaled(self, 6);
  var chevron := Rect(r.Right-pad-scaled(self, 12), r.Top, r.Right-pad, r.Bottom);
  paintChevron(sp, chevron, cdDown, scaled(self, 8), (if Enabled then pick(FTextColor, clWindowText) else ColorToRGB(clGrayText)));
  sp.Flush;
  applyTextQuality(Canvas);
  var text := Rect(r.Left+pad, r.Top, chevron.Left-pad, r.Bottom);
  var shown := summaryText;
  Canvas.Font.Color := if not Enabled then ColorToRGB(clGrayText) else if (CheckedCount = 0) then blend(pick(FTextColor, clWindowText), back, 45) else pick(FTextColor, clWindowText);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.EndEllipsis := true;
  style.ShowPrefix := false;
  style.Opaque := false;
  if (text.Right > text.Left) and (shown <> '') then Canvas.TextRect(text, text.Left, text.Top, shown, style);
  Canvas.Brush.Style := bsSolid;
end;

procedure TCheckComboBox.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  applyTextQuality(Canvas);
  PreferredHeight := Max(Canvas.TextHeight('Hg')+scaled(self, 10), scaled(self, 24));
  PreferredWidth := 0;
end;

// -- input ----------------------

procedure TCheckComboBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if TabStop and CanSetFocus then SetFocus;
  if DroppedDown then CloseUp else DropDown;
end;

procedure TCheckComboBox.MouseEnter;
begin
  inherited MouseEnter;
  FHot := true;
  Invalidate;
end;

procedure TCheckComboBox.MouseLeave;
begin
  inherited MouseLeave;
  FHot := false;
  Invalidate;
end;

procedure TCheckComboBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var rows := FItems.Count+(if FShowSelectAll then 1 else 0);
  match Key of
    VK_F4: begin if DroppedDown then CloseUp else DropDown; Key := 0; end;
    VK_DOWN: begin
      if ssAlt in Shift then DropDown
      else if DroppedDown then begin
        FFocusRow := Min(FFocusRow+1, rows-1);
        FList.Invalidate;
      end else DropDown;
      Key := 0;
    end;
    VK_UP: if DroppedDown then begin
      FFocusRow := Max(FFocusRow-1, 0);
      FList.Invalidate;
      Key := 0;
    end;
    VK_SPACE, VK_RETURN: begin
      if DroppedDown and (FFocusRow >= 0) then toggle(FFocusRow)
      else if not DroppedDown then DropDown;
      Key := 0;
    end;
    VK_ESCAPE: if DroppedDown then begin CloseUp; Key := 0; end;
  end;
end;

procedure TCheckComboBox.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TCheckComboBox.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

procedure TCheckComboBox.setItems(value: TStrings);
begin
  FItems.Assign(value);
end;

procedure TCheckComboBox.setSummary(value: TCheckSummary);
begin
  if FSummary = value then exit;
  FSummary := value;
  Invalidate;
end;

function TCheckComboBox.getText(index: integer): string;
begin
  result := match index of
    0: FDelimiter;
    1: FEmptyText;
  else
    FCountFormat
  end;
end;

procedure TCheckComboBox.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FDelimiter := value;
    1: FEmptyText := value;
  else
    FCountFormat := value;
  end;
  Invalidate;
end;

function TCheckComboBox.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FShowSelectAll else FReadOnly;
end;

procedure TCheckComboBox.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FShowSelectAll := value else FReadOnly := value;
  if DroppedDown then CloseUp;
  Invalidate;
end;

function TCheckComboBox.getMetric(index: integer): integer;
begin
  result := match index of
    0: FCornerRadius;
    1: FBorderWidth;
  else
    FMaxDropRows
  end;
end;

procedure TCheckComboBox.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 2 then value := Max(value, 1);
  if getMetric(index) = value then exit;
  match index of
    0: FCornerRadius := value;
    1: FBorderWidth := value;
  else
    FMaxDropRows := value;
  end;
  Invalidate;
end;

function TCheckComboBox.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBorderColor;
    1: FTextColor;
  else
    FBackColor
  end;
end;

procedure TCheckComboBox.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FTextColor := value;
  else
    FBackColor := value;
  end;
  Invalidate;
end;

procedure TCheckComboBox.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
