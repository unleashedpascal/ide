{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Popover;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint, PopupWindow;

type
  TPopover = class;
  TPopoverPlacement = (ppAuto, ppBelow, ppAbove, ppRight, ppLeft);

  { TPopoverWindow }

  // the bubble: a rounded body with an arrow to the target on one side
  TPopoverWindow = class(TDropPopup)
  private
    FPopover: TPopover;
    FSide: TPopoverPlacement; // where the target is: the arrow points there
    FArrowAt: integer;        // the arrow tip along its side
    FHotClose: boolean;
    function body: TRect;
    function closeRect: TRect;
    procedure applyShape;
  protected
    procedure Paint; override;
    procedure DoOnResize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor CreateFor(popover: TPopover);
  end;

  { TPopover }

  // a bubble with an arrow pointing at a control: a title and text, or a
  // control of the form shown inside it. It never takes the focus from the
  // form; a click elsewhere, Escape or a switch to another application
  // closes it, unless LightDismiss is off
  TPopover = class(TComponent)
  private
    FTitle, FText: string;
    FContent: TControl;
    FContentParent: TWinControl;
    FPlacement: TPopoverPlacement;
    FShowCloseButton, FLightDismiss: boolean;
    FMaxWidth, FPadding, FCornerRadius, FArrowSize, FGap: integer;
    FColor, FBorderColor, FTitleColor, FTextColor: TColor;
    FFont: TFont;
    FWindow: TPopoverWindow;
    FTarget: TControl;
    FAntialiasing: TAntialiasSetting;
    FOnShow, FOnClose: TNotifyEvent;
    procedure setContent(value: TControl);
    procedure setFont(value: TFont);
    procedure keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure windowDismiss(Sender: TObject);
    function wrap(canvas: TCanvas; const text: string; width: integer): TStringArray;
    procedure measure(out w, h: integer);
    procedure restoreContent;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // opens next to the target, on the side Placement picks
    procedure Popup(target: TControl);
    // opens or closes, for a button that shows the bubble
    procedure Toggle(target: TControl);
    procedure Close;
    function IsOpen: boolean;
    property Target: TControl read FTarget;
  published
    property Title: string read FTitle write FTitle;
    // wraps at MaxWidth; line breaks in it stay
    property Text: string read FText write FText;
    // a control of the form shown in the bubble instead of the text; it goes
    // back to its parent, hidden, when the bubble closes
    property Content: TControl read FContent write setContent;
    property Placement: TPopoverPlacement read FPlacement write FPlacement default ppAuto;
    property ShowCloseButton: boolean read FShowCloseButton write FShowCloseButton default false;
    // a click elsewhere, Escape or another application closes the bubble
    property LightDismiss: boolean read FLightDismiss write FLightDismiss default true;
    property MaxWidth: integer read FMaxWidth write FMaxWidth default 280;
    property Padding: integer read FPadding write FPadding default 12;
    property CornerRadius: integer read FCornerRadius write FCornerRadius default 8;
    property ArrowSize: integer read FArrowSize write FArrowSize default 8;
    // between the arrow tip and the target
    property Gap: integer read FGap write FGap default 2;
    property Font: TFont read FFont write setFont;
    // clDefault takes the colors of the theme
    property Color: TColor read FColor write FColor default clDefault;
    property BorderColor: TColor read FBorderColor write FBorderColor default clDefault;
    property TitleColor: TColor read FTitleColor write FTitleColor default clDefault;
    property TextColor: TColor read FTextColor write FTextColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write FAntialiasing default asTheme;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

implementation

uses
  Math;

{ TPopoverWindow }

constructor TPopoverWindow.CreateFor(popover: TPopover);
begin
  inherited Create(popover);
  FPopover := popover;
  Framed := false;
end;

// the bubble without the arrow
function TPopoverWindow.body: TRect;
begin
  var a := ControlPaint.scaled(self, FPopover.FArrowSize);
  result := ClientRect;
  match FSide of
    ppAbove: result.Bottom -= a;
    ppRight: result.Left += a;
    ppLeft: result.Right -= a;
  else
    result.Top += a;
  end;
end;

function TPopoverWindow.closeRect: TRect;
begin
  if not FPopover.FShowCloseButton then exit(Rect(0, 0, 0, 0));
  var b := body;
  var size := ControlPaint.scaled(self, 18);
  var pad := ControlPaint.scaled(self, 6);
  result := Rect(b.Right-pad-size, b.Top+pad, b.Right-pad, b.Top+pad+size);
end;

// the three corners of the arrow, the tip first
procedure arrowPoints(side: TPopoverPlacement; const b: TRect; at, a: integer; out tip, p1, p2: TPoint);
begin
  match side of
    ppAbove: begin
      tip := Point(at, b.Bottom+a);
      p1 := Point(at-a, b.Bottom);
      p2 := Point(at+a, b.Bottom);
    end;
    ppRight: begin
      tip := Point(b.Left-a, at);
      p1 := Point(b.Left, at-a);
      p2 := Point(b.Left, at+a);
    end;
    ppLeft: begin
      tip := Point(b.Right+a, at);
      p1 := Point(b.Right, at-a);
      p2 := Point(b.Right, at+a);
    end;
  else
    begin
      tip := Point(at, b.Top-a);
      p1 := Point(at-a, b.Top);
      p2 := Point(at+a, b.Top);
    end;
  end;
end;

procedure TPopoverWindow.applyShape;
begin
  if not HandleAllocated or (Width <= 0) or (Height <= 0) then exit;
  var mask := autofree TBitmap.Create;
  mask.PixelFormat := pf24bit;
  mask.SetSize(Width, Height);
  mask.Canvas.Brush.Color := clBlack;
  mask.Canvas.FillRect(0, 0, Width, Height);
  mask.Canvas.Brush.Color := clWhite;
  mask.Canvas.Pen.Color := clWhite;
  var b := body;
  var d := ControlPaint.scaled(self, FPopover.FCornerRadius)*2;
  mask.Canvas.RoundRect(b.Left, b.Top, b.Right, b.Bottom, d, d);
  var tip, p1, p2: TPoint;
  arrowPoints(FSide, b, FArrowAt, ControlPaint.scaled(self, FPopover.FArrowSize), tip, p1, p2);
  mask.Canvas.Polygon([tip, p1, p2]);
  SetShape(mask);
end;

procedure TPopoverWindow.DoOnResize;
begin
  inherited DoOnResize;
  applyShape;
end;

procedure TPopoverWindow.Paint;
begin
  var fill := pick(FPopover.FColor, blend(clWindow, clBtnFace, 20));
  var border := pick(FPopover.FBorderColor, blend(clWindow, clWindowText, 28));
  var b := body;
  var radius := ControlPaint.scaled(self, FPopover.FCornerRadius);
  var a := ControlPaint.scaled(self, FPopover.FArrowSize);
  var sp := autofree beginShapes(Canvas, ClientRect, fill, FPopover.FAntialiasing);
  paintRoundRect(sp, Rect(b.Left, b.Top, b.Right-1, b.Bottom-1), radius, fill, border);
  var tip, p1, p2: TPoint;
  arrowPoints(FSide, b, FArrowAt, a, tip, p1, p2);
  // a line 2 pixels wide around the arrow covers the frame of the body
  // under its base
  var arrow: array of TPointF := [PointF(tip.X, tip.Y), PointF(p1.X, p1.Y), PointF(p2.X, p2.Y)];
  sp.FillPolygon(arrow, fill);
  sp.StrokePolyline(arrow, 2, fill, true);
  paintLine(sp, p1.X, p1.Y, tip.X, tip.Y, border, 1);
  paintLine(sp, tip.X, tip.Y, p2.X, p2.Y, border, 1);
  var c := closeRect;
  if c.Width > 0 then begin
    if FHotClose and hoverEnabled then paintRoundRect(sp, c, ControlPaint.scaled(self, 4), hoverColor(fill), clNone);
    paintCross(sp, c, ControlPaint.scaled(self, 8), blend(fill, clWindowText, 65), 1);
  end;
  sp.Flush;
  if FPopover.FContent <> nil then exit;
  // the title and the wrapped text
  applyTextQuality(Canvas);
  var pad := ControlPaint.scaled(self, FPopover.FPadding);
  var inner := b;
  inner.Inflate(-pad, -pad);
  if c.Width > 0 then inner.Right := c.Left-ControlPaint.scaled(self, 4);
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlTop;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  Canvas.Brush.Style := bsClear;
  Canvas.Font := FPopover.FFont;
  var th := Canvas.TextHeight('Hg');
  var y := inner.Top;
  if FPopover.FTitle <> '' then begin
    Canvas.Font.Style := FPopover.FFont.Style+[fsBold];
    Canvas.Font.Color := pick(FPopover.FTitleColor, clWindowText);
    var r := Rect(inner.Left, y, inner.Right, y+th);
    Canvas.TextRect(r, r.Left, r.Top, FPopover.FTitle, style);
    y += th+ControlPaint.scaled(self, 4);
    Canvas.Font.Style := FPopover.FFont.Style;
  end;
  Canvas.Font.Color := pick(FPopover.FTextColor, blend(fill, clWindowText, 80));
  // the text wraps at the width of the body, as measured
  for var line in FPopover.wrap(Canvas, FPopover.FText, b.Width-2*pad) do begin
    var r := Rect(inner.Left, y, b.Right-pad, y+th);
    Canvas.TextRect(r, r.Left, r.Top, line, style);
    y += th;
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TPopoverWindow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and closeRect.Contains(Point(X, Y)) then FPopover.Close;
end;

procedure TPopoverWindow.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := closeRect.Contains(Point(X, Y));
  if hot <> FHotClose then begin
    FHotClose := hot;
    Invalidate;
  end;
end;

procedure TPopoverWindow.MouseLeave;
begin
  inherited MouseLeave;
  if FHotClose then begin
    FHotClose := false;
    Invalidate;
  end;
end;

{ TPopover }

constructor TPopover.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLightDismiss := true;
  FMaxWidth := 280;
  FPadding := 12;
  FCornerRadius := 8;
  FArrowSize := 8;
  FGap := 2;
  FColor := clDefault;
  FBorderColor := clDefault;
  FTitleColor := clDefault;
  FTextColor := clDefault;
  FFont := TFont.Create;
end;

destructor TPopover.Destroy;
begin
  if not (csDesigning in ComponentState) then Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
  restoreContent;
  FFont.Free;
  inherited Destroy;
end;

function TPopover.IsOpen: boolean;
begin
  result := (FWindow <> nil) and FWindow.Visible;
end;

procedure TPopover.Toggle(target: TControl);
begin
  if IsOpen and (FTarget = target) then Close else Popup(target);
end;

function TPopover.wrap(canvas: TCanvas; const text: string; width: integer): TStringArray;
begin
  result := [];
  if text = '' then exit;
  for var paragraph in text.Replace(#13#10, #10).Split([#10]) do begin
    var line := '';
    for var word in paragraph.Split([' '], TStringSplitOptions.ExcludeEmpty) do begin
      var next := if line = '' then word else line+' '+word;
      if (line <> '') and (canvas.TextWidth(next) > width) then begin
        result += [line];
        line := word;
      end else line := next;
    end;
    result += [line];
  end;
end;

// the size of the body: the content and the padding, or the text wrapped
// to MaxWidth
procedure TPopover.measure(out w, h: integer);
begin
  var pad := ControlPaint.scaled(FWindow, FPadding);
  var closeRoom := if FShowCloseButton then ControlPaint.scaled(FWindow, 26) else 0;
  if FContent <> nil then begin
    w := FContent.Width+2*pad;
    h := FContent.Height+2*pad+(if closeRoom > 0 then ControlPaint.scaled(FWindow, 14) else 0);
    exit;
  end;
  var c := FWindow.Canvas;
  c.Font := FFont;
  var th := c.TextHeight('Hg');
  var room := ControlPaint.scaled(FWindow, FMaxWidth)-2*pad;
  var lines := wrap(c, FText, room-closeRoom);
  var textW := 0;
  for var s in lines do textW := Max(textW, c.TextWidth(s));
  var titleW := 0;
  if FTitle <> '' then begin
    c.Font.Style := FFont.Style+[fsBold];
    titleW := c.TextWidth(FTitle)+closeRoom;
    c.Font.Style := FFont.Style;
  end;
  w := Min(Max(textW+closeRoom, titleW), room)+2*pad;
  h := length(lines)*th+(if FTitle <> '' then th+ControlPaint.scaled(FWindow, 4) else 0)+2*pad;
  h := Max(h, ControlPaint.scaled(FWindow, 18)+2*ControlPaint.scaled(FWindow, 6));
end;

procedure TPopover.Popup(target: TControl);
begin
  if (target = nil) or (csDesigning in ComponentState) then exit;
  if FWindow = nil then begin
    FWindow := TPopoverWindow.CreateFor(self);
    FWindow.OnDismiss := @windowDismiss;
  end;
  if FTarget <> target then begin
    if FTarget <> nil then FTarget.RemoveFreeNotification(self);
    FTarget := target;
    FTarget.FreeNotification(self);
  end;
  FWindow.HandleNeeded;
  FWindow.Font := FFont;
  var w, h: integer;
  measure(w, h);
  var a := ControlPaint.scaled(FWindow, FArrowSize);
  var gap := ControlPaint.scaled(FWindow, FGap);
  var origin := target.ClientToScreen(Point(0, 0));
  var tr := Rect(origin.X, origin.Y, origin.X+target.Width, origin.Y+target.Height);
  var area := Screen.MonitorFromPoint(tr.CenterPoint).WorkareaRect;
  // the side with room for the bubble, the asked one first
  var fits := function(side: TPopoverPlacement): boolean
  begin
    result := match side of
      ppAbove: tr.Top-gap-a-h >= area.Top;
      ppRight: tr.Right+gap+a+w <= area.Right;
      ppLeft: tr.Left-gap-a-w >= area.Left;
    else
      tr.Bottom+gap+a+h <= area.Bottom
    end;
  end;
  var side := FPlacement;
  if (side = ppAuto) or not fits(side) then begin
    side := if FPlacement = ppAuto then ppBelow else FPlacement;
    for var s in [ppBelow, ppAbove, ppRight, ppLeft] do
      if fits(s) then begin
        side := s;
        break;
      end;
  end;
  var r: TRect;
  match side of
    ppAbove: r := Rect(tr.CenterPoint.X-w div 2, tr.Top-gap-a-h, 0, 0);
    ppRight: r := Rect(tr.Right+gap, tr.CenterPoint.Y-h div 2, 0, 0);
    ppLeft: r := Rect(tr.Left-gap-a-w, tr.CenterPoint.Y-h div 2, 0, 0);
  else
    r := Rect(tr.CenterPoint.X-w div 2, tr.Bottom+gap, 0, 0);
  end;
  var vertical := side in [ppAuto, ppBelow, ppAbove];
  r.Right := r.Left+w+(if vertical then 0 else a);
  r.Bottom := r.Top+h+(if vertical then a else 0);
  // kept on the monitor; the arrow keeps pointing at the target
  OffsetRect(r, Max(area.Left-r.Left, 0)+Min(area.Right-r.Right, 0), Max(area.Top-r.Top, 0)+Min(area.Bottom-r.Bottom, 0));
  FWindow.FSide := if side = ppAuto then ppBelow else side;
  var radius := ControlPaint.scaled(FWindow, FCornerRadius);
  if vertical then FWindow.FArrowAt := EnsureRange(tr.CenterPoint.X-r.Left, radius+a, r.Width-radius-a)
  else FWindow.FArrowAt := EnsureRange(tr.CenterPoint.Y-r.Top, radius+a, r.Height-radius-a);
  FWindow.Color := pick(FColor, blend(clWindow, clBtnFace, 20));
  FWindow.ShowAt(target, r);
  FWindow.applyShape;
  FWindow.Invalidate;
  if FContent <> nil then begin
    // the content moves into the bubble while it shows
    if FContent.Parent <> FWindow then FContentParent := FContent.Parent;
    var b := FWindow.body;
    var pad := ControlPaint.scaled(FWindow, FPadding);
    FContent.Parent := FWindow;
    FContent.SetBounds(b.Left+pad, b.Top+pad+(if FShowCloseButton then ControlPaint.scaled(FWindow, 14) else 0), FContent.Width, FContent.Height);
    FContent.Visible := true;
  end;
  if FLightDismiss then Application.AddOnKeyDownBeforeHandler(@keyBefore);
  if Assigned(FOnShow) then FOnShow(self);
end;

procedure TPopover.restoreContent;
begin
  if (FContent = nil) or (FWindow = nil) or (FContent.Parent <> FWindow) then exit;
  FContent.Visible := false;
  FContent.Parent := FContentParent;
end;

procedure TPopover.Close;
begin
  if not IsOpen then exit;
  Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
  FWindow.Close;
  restoreContent;
  if Assigned(FOnClose) then FOnClose(self);
end;

// a click elsewhere, a switch away or the form moving
procedure TPopover.windowDismiss(Sender: TObject);
begin
  if FLightDismiss then Close;
end;

procedure TPopover.keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and IsOpen then begin
    Close;
    Key := 0;
  end;
end;

procedure TPopover.setContent(value: TControl);
begin
  if FContent = value then exit;
  restoreContent;
  if FContent <> nil then FContent.RemoveFreeNotification(self);
  FContent := value;
  if FContent <> nil then FContent.FreeNotification(self);
end;

procedure TPopover.setFont(value: TFont);
begin
  FFont.Assign(value);
end;

procedure TPopover.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  if AComponent = FContent then FContent := nil;
  if AComponent = FContentParent then FContentParent := nil;
  if AComponent = FTarget then begin
    FTarget := nil;
    if IsOpen then Close;
  end;
  if AComponent = FWindow then FWindow := nil;
end;

end.
