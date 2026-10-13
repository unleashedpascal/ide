{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit CheckGroupBox;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  // what an unchecked box does with what it holds
  TUncheckedAction = (uaDisable, uaCollapse, uaNothing);

  { TCheckGroupBox }

  // a group box with a check box in its caption: unchecked, the controls in
  // it turn off, or the box folds down to its caption line. A click on the
  // check box or the caption, or Space, flips it
  TCheckGroupBox = class(TCustomControl)
  private
    FChecked, FHot: boolean;
    FAction: TUncheckedAction;
    FCornerRadius, FExpandedHeight, FInnerPadding: integer;
    FBorderColor, FCaptionColor, FCheckColor: TColor;
    FTurnedOff: TFPList; // the controls the box disabled, to enable them again
    FAntialiasing: TAntialiasSetting;
    FOnChange: TNotifyEvent;
    procedure setChecked(value: boolean);
    procedure setAction(value: TUncheckedAction);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function headerPx: integer;
    function checkSize: integer;
    function headerRect: TRect;
    function collapsed: boolean;
    procedure apply;
    procedure turnOff;
    procedure turnOn;
  protected
    procedure Paint; override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoOnResize; override;
    procedure Loaded; override;
    procedure CreateWnd; override;
    procedure TextChanged; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Toggle;
  published
    property Caption;
    property Checked: boolean read FChecked write setChecked default true;
    property UncheckedAction: TUncheckedAction read FAction write setAction default uaDisable;
    // the height while checked; the box keeps it up to date itself
    property ExpandedHeight: integer index 0 read getMetric write setMetric default 140;
    property CornerRadius: integer index 1 read getMetric write setMetric default 4;
    // between the frame and the controls in it
    property InnerPadding: integer index 2 read getMetric write setMetric default 6;
    // clDefault takes the colors of the theme
    property BorderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property CaptionColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property CheckColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // after Checked changed and the box did what it does
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Align;
    property Anchors;
    property BorderSpacing;
    property ChildSizing;
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
    property OnResize;
  end;

implementation

uses
  Math;

constructor TCheckGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csSetCaption, csOpaque];
  FChecked := true;
  FCornerRadius := 4;
  FExpandedHeight := 140;
  FInnerPadding := 6;
  FBorderColor := clDefault;
  FCaptionColor := clDefault;
  FCheckColor := clDefault;
  FTurnedOff := TFPList.Create;
  TabStop := true;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TCheckGroupBox.Destroy;
begin
  FTurnedOff.Free;
  inherited Destroy;
end;

class function TCheckGroupBox.GetControlClassDefaultSize: TSize;
begin
  result.cx := 220;
  result.cy := 140;
end;

procedure TCheckGroupBox.Toggle;
begin
  Checked := not Checked;
end;

// -- layout ----------------------

function TCheckGroupBox.checkSize: integer;
begin
  result := Max(lineHeightOf(Font)-scaled(self, 2), 10);
end;

function TCheckGroupBox.headerPx: integer;
begin
  result := Max(lineHeightOf(Font), checkSize)+scaled(self, 6);
end;

// the check box and the caption, over the top line of the frame
function TCheckGroupBox.headerRect: TRect;
begin
  var w := checkSize+scaled(self, 6)+(if Caption <> '' then textWidthOf(Font, Caption)+scaled(self, 4) else 0);
  var left := scaled(self, 8);
  result := Rect(left, 0, Min(left+w, ClientWidth), headerPx);
end;

function TCheckGroupBox.collapsed: boolean;
begin
  result := not FChecked and (FAction = uaCollapse);
end;

procedure TCheckGroupBox.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  var inset := 1+scaled(self, FInnerPadding);
  ARect := Rect(ARect.Left+inset, ARect.Top+headerPx+scaled(self, FInnerPadding) div 2, ARect.Right-inset, ARect.Bottom-inset);
end;

// -- checking ----------------------

// the enabled controls in the box go off, and only those come back on
procedure TCheckGroupBox.turnOff;
begin
  for var i := 0 to ControlCount-1 do begin
    var c := Controls[i];
    if c.Enabled then begin
      c.Enabled := false;
      FTurnedOff.Add(c);
      c.FreeNotification(self);
    end;
  end;
end;

procedure TCheckGroupBox.turnOn;
begin
  for var i := 0 to FTurnedOff.Count-1 do begin
    var c := TControl(FTurnedOff[i]);
    if c.Parent = self then c.Enabled := true;
    c.RemoveFreeNotification(self);
  end;
  FTurnedOff.Clear;
end;

procedure TCheckGroupBox.apply;
begin
  if csLoading in ComponentState then exit;
  if FChecked then turnOn
  // in the designer the controls keep their state, so the form stores it
  else if (FAction = uaDisable) and not (csDesigning in ComponentState) then turnOff;
  // the caption height needs the handle; CreateWnd catches up without one
  if HandleAllocated then begin
    var target := if collapsed then headerPx else FExpandedHeight;
    if Height <> target then Height := target;
  end;
  Invalidate;
end;

procedure TCheckGroupBox.CreateWnd;
begin
  inherited CreateWnd;
  if collapsed and not (csLoading in ComponentState) then apply;
end;

procedure TCheckGroupBox.Loaded;
begin
  inherited Loaded;
  apply;
end;

procedure TCheckGroupBox.DoOnResize;
begin
  inherited DoOnResize;
  // a resize by hand while open is the new open height
  if not collapsed and not (csLoading in ComponentState) then FExpandedHeight := Height;
  Invalidate;
end;

procedure TCheckGroupBox.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (FTurnedOff <> nil) then FTurnedOff.Remove(AComponent);
end;

// -- painting ----------------------

procedure TCheckGroupBox.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var border := pick(FBorderColor, blend(clBtnFace, clBtnShadow, 50));
  var text := pick(FCaptionColor, clWindowText);
  var accent := pick(FCheckColor, clHighlight);
  if not Enabled then begin
    text := ColorToRGB(clGrayText);
    accent := blend(accent, back, 55);
  end;
  var h := headerRect;
  var mid := h.Top+h.Height div 2;
  var radius := scaled(self, FCornerRadius);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  if collapsed then begin
    // folded, the frame is a line through the caption
    paintLine(sp, 0, mid, h.Left-scaled(self, 2), mid, border, 1);
    paintLine(sp, h.Right+scaled(self, 2), mid, ClientWidth, mid, border, 1);
  end else begin
    paintRoundRect(sp, Rect(0, mid, ClientWidth, ClientHeight), radius, clNone, border);
    // the caption cuts the top line
    paintRoundRect(sp, Rect(h.Left-scaled(self, 2), mid-1, h.Right+scaled(self, 2), mid+2), 0, back, clNone);
  end;
  var size := checkSize;
  var box := Rect(h.Left+scaled(self, 2), mid-size div 2, h.Left+scaled(self, 2)+size, mid-size div 2+size);
  var cr := Max(size div 5, 2);
  if FChecked then begin
    var fill := if FHot and Enabled and hoverEnabled then blend(accent, clWhite, 14) else accent;
    paintRoundRect(sp, box, cr, fill, (if Focused and ringEnabled then ringColor else clNone));
    paintCheck(sp, box, size*7 div 10, contrastText(accent), Max(size div 7, 2));
  end else begin
    var fill := if FHot and Enabled and hoverEnabled then hoverColor(back) else back;
    paintRoundRect(sp, box, cr, fill, (if Focused and ringEnabled then ringColor else if FHot and Enabled then hoverShade(border, accent) else border), Max(scaled(self, 1), 1));
  end;
  sp.Flush;
  if Caption <> '' then begin
    applyTextQuality(Canvas);
    var r := Rect(box.Right+scaled(self, 6), h.Top, h.Right, h.Bottom);
    var style := Canvas.TextStyle;
    style.Alignment := taLeftJustify;
    style.Layout := tlCenter;
    style.SingleLine := true;
    style.Clipping := true;
    style.Opaque := false;
    style.ShowPrefix := false;
    style.EndEllipsis := true;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := text;
    Canvas.TextRect(r, r.Left, r.Top, Caption, style);
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- input ----------------------

procedure TCheckGroupBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled or not headerRect.Contains(Point(X, Y)) then exit;
  if TabStop and CanSetFocus and not Focused then SetFocus;
  Toggle;
end;

procedure TCheckGroupBox.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := headerRect.Contains(Point(X, Y));
  if hot <> FHot then begin
    FHot := hot;
    Invalidate;
  end;
end;

procedure TCheckGroupBox.MouseLeave;
begin
  inherited MouseLeave;
  if FHot then begin
    FHot := false;
    Invalidate;
  end;
end;

procedure TCheckGroupBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = VK_SPACE) and Enabled then begin
    Toggle;
    Key := 0;
  end;
end;

procedure TCheckGroupBox.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TCheckGroupBox.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TCheckGroupBox.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TCheckGroupBox.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  ReAlign;
  if collapsed then apply;
  Invalidate;
end;

// -- properties ----------------------

procedure TCheckGroupBox.setChecked(value: boolean);
begin
  if FChecked = value then exit;
  FChecked := value;
  apply;
  if not (csLoading in ComponentState) and Assigned(FOnChange) then FOnChange(self);
end;

procedure TCheckGroupBox.setAction(value: TUncheckedAction);
begin
  if FAction = value then exit;
  // the old action is undone before the new one applies
  if not FChecked then begin
    turnOn;
    if (FAction = uaCollapse) and not (csLoading in ComponentState) then Height := FExpandedHeight;
  end;
  FAction := value;
  apply;
end;

function TCheckGroupBox.getMetric(index: integer): integer;
begin
  result := match index of
    0: FExpandedHeight;
    1: FCornerRadius;
  else
    FInnerPadding
  end;
end;

procedure TCheckGroupBox.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: begin
      FExpandedHeight := value;
      if not collapsed and not (csLoading in ComponentState) then Height := value;
    end;
    1: FCornerRadius := value;
  else
    begin
      FInnerPadding := value;
      ReAlign;
    end;
  end;
  Invalidate;
end;

function TCheckGroupBox.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBorderColor;
    1: FCaptionColor;
  else
    FCheckColor
  end;
end;

procedure TCheckGroupBox.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBorderColor := value;
    1: FCaptionColor := value;
  else
    FCheckColor := value;
  end;
  Invalidate;
end;

procedure TCheckGroupBox.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
