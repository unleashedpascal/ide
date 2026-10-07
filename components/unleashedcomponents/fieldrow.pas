{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit FieldRow;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  // where the caption sits against the controls
  TFieldCaptionPosition = (fcLeft, fcRight, fcTop);
  // how the caption lines up with the controls beside it
  TFieldCaptionAlignment = (faTop, faCenter, faBottom);

  { TFieldRow }

  // a caption and the controls it names in one row: the caption, measured
  // with the real font, on the left, the right or above the controls, the
  // controls side by side in the order of their position. The row sizes
  // itself to its content, so the caption never runs into the controls on
  // any widgetset. A click on the caption focuses the first control
  TFieldRow = class(TCustomControl)
  private
    FCaptionPosition: TFieldCaptionPosition;
    FCaptionAlignment: TFieldCaptionAlignment;
    FCaptionWidth, FSpacing, FChildSpacing, FPadding: integer;
    FCaptionColor: TColor;
    FLaying: boolean;
    FCaptionRect: TRect;
    procedure setCaptionPosition(value: TFieldCaptionPosition);
    procedure setCaptionAlignment(value: TFieldCaptionAlignment);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setCaptionColor(value: TColor);
    function ordered: TList;
    procedure layout(apply: boolean; out width, height: integer);
    procedure changed;
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure CreateWnd; override;
    procedure Paint; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the rectangle the caption takes, in client coordinates
    property CaptionRect: TRect read FCaptionRect;
  published
    property Caption;
    property CaptionPosition: TFieldCaptionPosition read FCaptionPosition write setCaptionPosition default fcLeft;
    property CaptionAlignment: TFieldCaptionAlignment read FCaptionAlignment write setCaptionAlignment default faCenter;
    // the caption column; 0 fits the text
    property CaptionWidth: integer index 0 read getMetric write setMetric default 0;
    // between the caption and the controls
    property Spacing: integer index 1 read getMetric write setMetric default 6;
    // between the controls
    property ChildSpacing: integer index 2 read getMetric write setMetric default 6;
    property Padding: integer index 3 read getMetric write setMetric default 0;
    // clDefault takes the color of the theme
    property CaptionColor: TColor read FCaptionColor write setCaptionColor default clDefault;
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
    property Visible;
    property OnClick;
    property OnContextPopup;
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

constructor TFieldRow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // the row places the children; the auto size must not move them
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csSetCaption, csAutoSizeKeepChildLeft, csAutoSizeKeepChildTop];
  FCaptionAlignment := faCenter;
  FSpacing := 6;
  FChildSpacing := 6;
  FCaptionColor := clDefault;
  ParentColor := true;
  AutoSize := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TFieldRow.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 23;
end;

// the children in the order of their position, left to right
function TFieldRow.ordered: TList;
begin
  result := TList.Create;
  for var i := 0 to ControlCount-1 do begin
    var c := Controls[i];
    if not c.Visible and not (csDesigning in ComponentState) then continue;
    var at := result.Count;
    while (at > 0) and (TControl(result[at-1]).Left > c.Left) do dec(at);
    result.Insert(at, c);
  end;
end;

// the caption and the children placed; apply moves the children, without it
// the result is the size the content wants
procedure TFieldRow.layout(apply: boolean; out width, height: integer);
begin
  width := 0;
  height := 0;
  if not HandleAllocated then exit;
  var list := ordered;
  try
    var pad := scaled(self, FPadding);
    var gap := if Caption <> '' then scaled(self, FSpacing) else 0;
    var childGap := scaled(self, FChildSpacing);
    var th := if Caption <> '' then lineHeightOf(Font) else 0;
    var cw := if Caption = '' then 0 else if FCaptionWidth > 0 then scaled(self, FCaptionWidth) else textWidthOf(Font, Caption);
    var childrenW := 0;
    var childrenH := 0;
    for var i := 0 to list.Count-1 do begin
      var c := TControl(list[i]);
      childrenW += c.Width+(if i > 0 then childGap else 0);
      childrenH := Max(childrenH, c.Height);
    end;
    // the band the controls sit in, and the caption beside or above it
    var bandTop := pad;
    var band := childrenH;
    if FCaptionPosition = fcTop then begin
      bandTop := pad+th+gap;
      width := pad+Max(cw, childrenW)+pad;
      height := bandTop+band+pad;
    end else begin
      band := Max(childrenH, th);
      width := pad+cw+gap+childrenW+pad;
      height := pad+band+pad;
    end;
    var x := if FCaptionPosition = fcLeft then pad+cw+gap else pad;
    for var i := 0 to list.Count-1 do begin
      var c := TControl(list[i]);
      var target := Rect(x, bandTop+(band-c.Height) div 2, x+c.Width, bandTop+(band-c.Height) div 2+c.Height);
      if apply and (c.BoundsRect <> target) then c.BoundsRect := target;
      x += c.Width+childGap;
    end;
    var captionTop := match FCaptionPosition of
      fcTop: pad;
    else
      match FCaptionAlignment of
        faTop: bandTop;
        faBottom: bandTop+band-th;
      else
        bandTop+(band-th) div 2
      end
    end;
    FCaptionRect := match FCaptionPosition of
      fcLeft: Rect(pad, captionTop, pad+cw, captionTop+th);
      fcRight: Rect(pad+childrenW+gap, captionTop, pad+childrenW+gap+cw, captionTop+th);
    else
      Rect(pad, captionTop, pad+Max(cw, childrenW), captionTop+th)
    end;
  finally
    list.Free;
  end;
end;

procedure TFieldRow.AlignControls(AControl: TControl; var ARect: TRect);
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  var before := FCaptionRect;
  try
    var w, h: integer;
    layout(true, w, h);
  finally
    FLaying := false;
  end;
  if before <> FCaptionRect then Invalidate;
end;

procedure TFieldRow.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  layout(false, PreferredWidth, PreferredHeight);
end;

procedure TFieldRow.changed;
begin
  if csDestroying in ComponentState then exit;
  InvalidatePreferredSize;
  AdjustSize;
  ReAlign;
  Invalidate;
end;

procedure TFieldRow.CreateWnd;
begin
  inherited CreateWnd;
  changed;
end;

procedure TFieldRow.TextChanged;
begin
  inherited TextChanged;
  changed;
end;

procedure TFieldRow.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  changed;
end;

// -- painting ----------------------

procedure TFieldRow.Paint;
begin
  var back := GetRGBColorResolvingParent;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := back;
  Canvas.FillRect(ClientRect);
  if csDesigning in ComponentState then begin
    // the outline shows where the row ends in the designer
    Canvas.Pen.Color := blend(back, clWindowText, 25);
    Canvas.Pen.Style := psDot;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
    Canvas.Pen.Style := psSolid;
  end;
  if Caption = '' then exit;
  applyTextQuality(Canvas);
  Canvas.Font := Font;
  Canvas.Font.Color := if Enabled then pick(FCaptionColor, clWindowText) else ColorToRGB(clGrayText);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlTop;
  style.SingleLine := true;
  style.EndEllipsis := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  Canvas.Brush.Style := bsClear;
  Canvas.TextRect(FCaptionRect, FCaptionRect.Left, FCaptionRect.Top, Caption, style);
  Canvas.Brush.Style := bsSolid;
end;

// a click on the caption focuses the first control that takes the focus
procedure TFieldRow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FCaptionRect.Contains(Point(X, Y)) or (csDesigning in ComponentState) then exit;
  var list := ordered;
  try
    for var i := 0 to list.Count-1 do
      if (TControl(list[i]) is TWinControl) and TWinControl(list[i]).CanFocus then begin
        TWinControl(list[i]).SetFocus;
        exit;
      end;
  finally
    list.Free;
  end;
end;

// -- properties ----------------------

procedure TFieldRow.setCaptionPosition(value: TFieldCaptionPosition);
begin
  if FCaptionPosition = value then exit;
  FCaptionPosition := value;
  changed;
end;

procedure TFieldRow.setCaptionAlignment(value: TFieldCaptionAlignment);
begin
  if FCaptionAlignment = value then exit;
  FCaptionAlignment := value;
  changed;
end;

function TFieldRow.getMetric(index: integer): integer;
begin
  match index of
    0: result := FCaptionWidth;
    1: result := FSpacing;
    2: result := FChildSpacing;
    _: result := FPadding;
  end;
end;

procedure TFieldRow.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FCaptionWidth := value;
    1: FSpacing := value;
    2: FChildSpacing := value;
    _: FPadding := value;
  end;
  changed;
end;

procedure TFieldRow.setCaptionColor(value: TColor);
begin
  if FCaptionColor = value then exit;
  FCaptionColor := value;
  Invalidate;
end;

end.
