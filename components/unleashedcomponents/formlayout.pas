{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit FormLayout;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  TFormLayout = class;
  TFormLabelPosition = (flpLeft, flpTop);

  { TFormLayoutRow }

  TFormLayoutRow = class(TCollectionItem)
  private
    FCaption, FHelpText: string;
    FControl: TControl;
    FRequired: boolean;
    procedure setCaption(const value: string);
    procedure setHelpText(const value: string);
    procedure setControl(value: TControl);
    procedure setRequired(value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    procedure Assign(Source: TPersistent); override;
  published
    property Caption: string read FCaption write setCaption;
    // the child of the layout the row holds
    property Control: TControl read FControl write setControl;
    // a mark after the caption
    property Required: boolean read FRequired write setRequired default false;
    // a line under the field
    property HelpText: string read FHelpText write setHelpText;
  end;

  { TFormLayoutRows }

  TFormLayoutRows = class(TOwnedCollection)
  private
    function getItem(index: integer): TFormLayoutRow;
    procedure setItem(index: integer; value: TFormLayoutRow);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TFormLayoutRow;
    function AddRow(const caption: string; control: TControl; required: boolean = false): TFormLayoutRow;
    // the row of a control, nil without one
    function RowOf(control: TControl): TFormLayoutRow;
    property Items[index: integer]: TFormLayoutRow read getItem write setItem; default;
  end;

  { TFormLayout }

  // fields of a form under each other, each with its caption in a column on
  // the left or above it. Rows names the captions and the order; children
  // without a row follow them, captionless, in the order of their position.
  // A click on a caption focuses its field
  TFormLayout = class(TCustomControl)
  private
    FRows: TFormLayoutRows;
    FLabelPosition: TFormLabelPosition;
    FLabelAlignment: TAlignment;
    FLabelWidth, FRowSpacing, FColumnSpacing, FPadding: integer;
    FStretchFields, FShowColons: boolean;
    FCaptionColor, FHelpColor, FRequiredColor: TColor;
    FLaying: boolean;
    FPlaced: array of record
      control: TControl;
      row: TFormLayoutRow;
      caption, help: TRect;
    end;
    procedure setRows(value: TFormLayoutRows);
    procedure setLabelPosition(value: TFormLabelPosition);
    procedure setLabelAlignment(value: TAlignment);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    function captionText(row: TFormLayoutRow): string;
    procedure helpFont(target: TFont);
    function ordered: TList;
    function labelColumn(list: TList): integer;
    procedure layout(apply: boolean; out height: integer);
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure CreateWnd; override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure FontChanged(Sender: TObject); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure rowsChanged;
  published
    property Rows: TFormLayoutRows read FRows write setRows;
    property LabelPosition: TFormLabelPosition read FLabelPosition write setLabelPosition default flpLeft;
    property LabelAlignment: TAlignment read FLabelAlignment write setLabelAlignment default taLeftJustify;
    // the caption column; 0 fits the widest caption
    property LabelWidth: integer index 0 read getMetric write setMetric default 0;
    property RowSpacing: integer index 1 read getMetric write setMetric default 8;
    property ColumnSpacing: integer index 2 read getMetric write setMetric default 10;
    property Padding: integer index 3 read getMetric write setMetric default 8;
    // the fields take the whole width of their column
    property StretchFields: boolean index 0 read getFlag write setFlag default true;
    // a colon after each caption
    property ShowColons: boolean index 1 read getFlag write setFlag default false;
    // clDefault takes the colors of the theme
    property CaptionColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property HelpColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property RequiredColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Align;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
    property ClientHeight;
    property ClientWidth;
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
    property TabStop;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
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

{ TFormLayoutRow }

procedure TFormLayoutRow.Assign(Source: TPersistent);
begin
  if Source is TFormLayoutRow then begin
    FCaption := TFormLayoutRow(Source).FCaption;
    FHelpText := TFormLayoutRow(Source).FHelpText;
    FRequired := TFormLayoutRow(Source).FRequired;
    setControl(TFormLayoutRow(Source).FControl);
    Changed(false);
  end else inherited Assign(Source);
end;

function TFormLayoutRow.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TFormLayoutRow.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TFormLayoutRow.setHelpText(const value: string);
begin
  if FHelpText = value then exit;
  FHelpText := value;
  Changed(false);
end;

procedure TFormLayoutRow.setControl(value: TControl);
begin
  if FControl = value then exit;
  var layout := TFormLayoutRows(Collection).Owner as TFormLayout;
  if (FControl <> nil) and (layout <> nil) then FControl.RemoveFreeNotification(layout);
  FControl := value;
  if (FControl <> nil) and (layout <> nil) then FControl.FreeNotification(layout);
  Changed(false);
end;

procedure TFormLayoutRow.setRequired(value: boolean);
begin
  if FRequired = value then exit;
  FRequired := value;
  Changed(false);
end;

{ TFormLayoutRows }

function TFormLayoutRows.getItem(index: integer): TFormLayoutRow;
begin
  result := TFormLayoutRow(inherited Items[index]);
end;

procedure TFormLayoutRows.setItem(index: integer; value: TFormLayoutRow);
begin
  inherited Items[index] := value;
end;

procedure TFormLayoutRows.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TFormLayout then TFormLayout(Owner).rowsChanged;
end;

function TFormLayoutRows.Add: TFormLayoutRow;
begin
  result := TFormLayoutRow(inherited Add);
end;

function TFormLayoutRows.AddRow(const caption: string; control: TControl; required: boolean): TFormLayoutRow;
begin
  result := Add;
  result.FCaption := caption;
  result.FRequired := required;
  result.setControl(control);
end;

function TFormLayoutRows.RowOf(control: TControl): TFormLayoutRow;
begin
  for var i := 0 to Count-1 do
    if Items[i].FControl = control then exit(Items[i]);
  result := nil;
end;

{ TFormLayout }

constructor TFormLayout.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // the layout places the children; the auto size must not move them
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop]-[csSetCaption];
  FRows := TFormLayoutRows.Create(self, TFormLayoutRow);
  FLabelAlignment := taLeftJustify;
  FRowSpacing := 8;
  FColumnSpacing := 10;
  FPadding := 8;
  FStretchFields := true;
  FCaptionColor := clDefault;
  FHelpColor := clDefault;
  FRequiredColor := clDefault;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TFormLayout.Destroy;
begin
  FreeAndNil(FRows);
  inherited Destroy;
end;

class function TFormLayout.GetControlClassDefaultSize: TSize;
begin
  result.cx := 320;
  result.cy := 200;
end;

procedure TFormLayout.rowsChanged;
begin
  if csDestroying in ComponentState then exit;
  InvalidatePreferredSize;
  AdjustSize;
  ReAlign;
  Invalidate;
end;

procedure TFormLayout.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (FRows <> nil) then
    for var i := 0 to FRows.Count-1 do
      if FRows[i].FControl = AComponent then FRows[i].FControl := nil;
end;

// -- layout ----------------------

function TFormLayout.captionText(row: TFormLayoutRow): string;
begin
  if (row = nil) or (row.FCaption = '') then exit('');
  result := row.FCaption+(if FShowColons then ':' else '');
end;

procedure TFormLayout.helpFont(target: TFont);
begin
  target.Assign(Font);
  target.Height := -Max(Abs(lineHeightOf(Font))*85 div 100, 8);
end;

function byTop(a, b: pointer): integer;
begin
  result := TControl(a).Top-TControl(b).Top;
  if result = 0 then result := TControl(a).Left-TControl(b).Left;
end;

// the rows in the order of the collection, then the other children by position
function TFormLayout.ordered: TList;
begin
  result := TList.Create;
  for var i := 0 to FRows.Count-1 do begin
    var c := FRows[i].FControl;
    if (c <> nil) and (c.Parent = self) and (c.Visible or (csDesigning in ComponentState)) and (result.IndexOf(c) < 0) then result.Add(c);
  end;
  var rest := autofree TList.Create;
  for var i := 0 to ControlCount-1 do begin
    var c := Controls[i];
    if (result.IndexOf(c) < 0) and (c.Visible or (csDesigning in ComponentState)) then rest.Add(c);
  end;
  rest.Sort(@byTop);
  for var i := 0 to rest.Count-1 do result.Add(rest[i]);
end;

function TFormLayout.labelColumn(list: TList): integer;
begin
  if FLabelWidth > 0 then exit(scaled(self, FLabelWidth));
  result := 0;
  for var i := 0 to list.Count-1 do begin
    var row := FRows.RowOf(TControl(list[i]));
    var s := captionText(row);
    if s <> '' then result := Max(result, textWidthOf(Font, s)+(if row.FRequired then textWidthOf(Font, ' *') else 0));
  end;
end;

// walks the rows; `apply` moves the children, and the caption and help
// boxes are kept for the painting either way
procedure TFormLayout.layout(apply: boolean; out height: integer);
begin
  // laid out once the window exists; CreateWnd lays out again
  height := 0;
  if not HandleAllocated then begin
    FPlaced := nil;
    exit;
  end;
  var list := ordered;
  try
    var pad := scaled(self, FPadding);
    var gap := scaled(self, FColumnSpacing);
    var rowGap := scaled(self, FRowSpacing);
    var th := lineHeightOf(Font);
    var small := autofree TFont.Create;
    helpFont(small);
    var hh := lineHeightOf(small);
    var col := labelColumn(list);
    var anyCaption := col > 0;
    var fieldLeft := if (FLabelPosition = flpLeft) and anyCaption then pad+col+gap else pad;
    var fieldRight := ClientWidth-pad;
    SetLength(FPlaced, list.Count);
    var y := pad;
    for var i := 0 to list.Count-1 do begin
      var c := TControl(list[i]);
      var row := FRows.RowOf(c);
      var caption := captionText(row);
      var help := if row <> nil then row.FHelpText else '';
      FPlaced[i].control := c;
      FPlaced[i].row := row;
      // a captionless child spans the whole width when the captions sit left
      var left := if (FLabelPosition = flpLeft) and (caption = '') then pad else fieldLeft;
      if FLabelPosition = flpTop then begin
        FPlaced[i].caption := if caption <> '' then Rect(pad, y, fieldRight, y+th) else Rect(pad, y, pad, y);
        if caption <> '' then y += th+scaled(self, 2);
      end;
      // a child sizing its width keeps it, or the two would fight; edits
      // and combo boxes size only their height
      var stretch := FStretchFields;
      if stretch and c.AutoSize then begin
        var pw, ph: integer;
        c.GetPreferredSize(pw, ph, true);
        stretch := pw <= 0;
      end;
      var w := if stretch then Max(fieldRight-left, 0) else c.Width;
      var h := c.Height;
      var target := Rect(left, y, left+w, y+h);
      if apply and (c.BoundsRect <> target) then c.BoundsRect := target;
      if FLabelPosition = flpLeft then
        // the caption sits level with the first line of the field
        FPlaced[i].caption := Rect(pad, y+Max((Min(h, th+scaled(self, 10))-th) div 2, 0), pad+col, y+Max((Min(h, th+scaled(self, 10))-th) div 2, 0)+th);
      var bottom := y+Max(h, (if FLabelPosition = flpLeft then FPlaced[i].caption.Bottom-y else 0));
      if help <> '' then begin
        FPlaced[i].help := Rect(left, bottom+scaled(self, 2), fieldRight, bottom+scaled(self, 2)+hh);
        bottom := FPlaced[i].help.Bottom;
      end else FPlaced[i].help := Rect(left, bottom, left, bottom);
      y := bottom+rowGap;
    end;
    height := (if list.Count > 0 then y-rowGap else y)+pad;
  finally
    list.Free;
  end;
end;

procedure TFormLayout.AlignControls(AControl: TControl; var ARect: TRect);
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  var before := Copy(FPlaced);
  try
    var h: integer;
    layout(true, h);
  finally
    FLaying := false;
  end;
  // the captions repaint when they move
  var moved := length(before) <> length(FPlaced);
  if not moved then
    for var i := 0 to high(FPlaced) do
      if (before[i].control <> FPlaced[i].control) or (before[i].row <> FPlaced[i].row) or (before[i].caption <> FPlaced[i].caption) or (before[i].help <> FPlaced[i].help) then moved := true;
  if moved then Invalidate;
end;

procedure TFormLayout.CreateWnd;
begin
  inherited CreateWnd;
  rowsChanged;
end;

procedure TFormLayout.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var h: integer;
  layout(false, h);
  PreferredWidth := 0;
  PreferredHeight := h;
end;

// -- painting ----------------------

procedure TFormLayout.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var captionColor := pick(FCaptionColor, clWindowText);
  var helpColor := pick(FHelpColor, blend(back, clWindowText, 55));
  var requiredColor := pick(FRequiredColor, if isDark(back) then RGBToColor(239, 83, 80) else RGBToColor(198, 40, 40));
  if not Enabled then begin
    captionColor := ColorToRGB(clGrayText);
    helpColor := captionColor;
  end;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := back;
  Canvas.FillRect(ClientRect);
  if csDesigning in ComponentState then begin
    // the outline shows where the layout ends in the designer
    Canvas.Pen.Color := blend(back, clWindowText, 25);
    Canvas.Pen.Style := psDot;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
    Canvas.Pen.Style := psSolid;
  end;
  var h: integer;
  layout(false, h);
  applyTextQuality(Canvas);
  var style := Canvas.TextStyle;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  Canvas.Brush.Style := bsClear;
  var small := autofree TFont.Create;
  helpFont(small);
  for var p in FPlaced do begin
    var caption := captionText(p.row);
    if caption <> '' then begin
      Canvas.Font := Font;
      var mark := if p.row.FRequired then ' *' else '';
      var r := p.caption;
      var full := Canvas.TextWidth(caption+mark);
      // the caption and its mark as one piece, aligned in the column
      var x := if (FLabelPosition = flpLeft) and (FLabelAlignment = taRightJustify) then r.Right-full
        else if (FLabelPosition = flpLeft) and (FLabelAlignment = taCenter) then r.Left+(r.Width-full) div 2
        else r.Left;
      style.Alignment := taLeftJustify;
      Canvas.Font.Color := captionColor;
      var cr := Rect(Max(x, r.Left), r.Top, r.Right, r.Bottom);
      Canvas.TextRect(cr, cr.Left, cr.Top, caption, style);
      if mark <> '' then begin
        Canvas.Font.Color := requiredColor;
        var mx := Max(x, r.Left)+Canvas.TextWidth(caption);
        var mr := Rect(mx, r.Top, Max(r.Right, mx+Canvas.TextWidth(mark)), r.Bottom);
        Canvas.TextRect(mr, mr.Left, mr.Top, mark, style);
      end;
    end;
    if (p.row <> nil) and (p.row.FHelpText <> '') then begin
      Canvas.Font := small;
      Canvas.Font.Color := helpColor;
      style.Alignment := taLeftJustify;
      Canvas.TextRect(p.help, p.help.Left, p.help.Top, p.row.FHelpText, style);
    end;
  end;
  Canvas.Font := Font;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TFormLayout.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  var h: integer;
  layout(false, h);
  for var p in FPlaced do
    if (captionText(p.row) <> '') and p.caption.Contains(Point(X, Y)) and (p.control is TWinControl) and TWinControl(p.control).CanSetFocus then begin
      TWinControl(p.control).SetFocus;
      break;
    end;
end;

procedure TFormLayout.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  rowsChanged;
end;

// -- properties ----------------------

procedure TFormLayout.setRows(value: TFormLayoutRows);
begin
  FRows.Assign(value);
end;

procedure TFormLayout.setLabelPosition(value: TFormLabelPosition);
begin
  if FLabelPosition = value then exit;
  FLabelPosition := value;
  rowsChanged;
end;

procedure TFormLayout.setLabelAlignment(value: TAlignment);
begin
  if FLabelAlignment = value then exit;
  FLabelAlignment := value;
  Invalidate;
end;

function TFormLayout.getMetric(index: integer): integer;
begin
  result := match index of
    0: FLabelWidth;
    1: FRowSpacing;
    2: FColumnSpacing;
  else
    FPadding
  end;
end;

procedure TFormLayout.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FLabelWidth := value;
    1: FRowSpacing := value;
    2: FColumnSpacing := value;
  else
    FPadding := value;
  end;
  rowsChanged;
end;

function TFormLayout.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FStretchFields else FShowColons;
end;

procedure TFormLayout.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FStretchFields := value else FShowColons := value;
  rowsChanged;
end;

function TFormLayout.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FCaptionColor;
    1: FHelpColor;
  else
    FRequiredColor
  end;
end;

procedure TFormLayout.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FCaptionColor := value;
    1: FHelpColor := value;
  else
    FRequiredColor := value;
  end;
  Invalidate;
end;

end.
