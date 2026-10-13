{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PopupWindow;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LMessages, LCLType;

type
  { TDropPopup }

  // a window that drops from a control and never takes the activation, so
  // the control keeps the keyboard and its form keeps its look. A click
  // anywhere else, a switch to another application or the form of the
  // anchor moving fire OnDismiss; without a handler the popup just closes
  TDropPopup = class(THintWindow)
  private
    FAnchor: TControl;
    FAnchorForm: TCustomForm;
    FWatching, FFramed: boolean;
    FBorderColor: TColor;
    FOnDismiss: TNotifyEvent;
    procedure userInput(Sender: TObject; var Msg: TLMessage);
    procedure appDeactivate(Sender: TObject);
    procedure formMoved(Sender: TObject);
    procedure watch(active: boolean);
    function belongs(control: TControl): boolean;
    procedure dismiss;
  protected
    procedure Paint; override;
    procedure DoShowWindow; override;
    procedure CreateWnd; override;
    procedure VisibleChanged; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure WMNCHitTest(var Message: TLMessage); message LM_NCHITTEST;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // shows the popup under the anchor, or over it when the screen ends
    // first, kept inside the work area of the monitor
    procedure Drop(anchor: TControl; aWidth, aHeight: integer);
    // shows the popup at a screen rectangle; the anchor still counts as inside
    procedure ShowAt(anchor: TControl; const bounds: TRect);
    procedure Close;
    // the space for the content: the client area inside the frame
    function ContentRect: TRect;
    property Anchor: TControl read FAnchor;
    // a one pixel frame around the content
    property Framed: boolean read FFramed write FFramed;
    // clDefault takes the color of the theme
    property BorderColor: TColor read FBorderColor write FBorderColor;
    property OnDismiss: TNotifyEvent read FOnDismiss write FOnDismiss;
  end;

implementation

uses
  Math, ControlPaint;

constructor TDropPopup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csNoFocus];
  Color := clWindow;
  FFramed := true;
  FBorderColor := clDefault;
end;

destructor TDropPopup.Destroy;
begin
  watch(false);
  inherited Destroy;
end;

procedure TDropPopup.CreateWnd;
begin
  inherited CreateWnd;
  // a click into the popup must not take the activation from the form
  keepInactive(Handle);
end;

// the stock version focuses the first child, which drags the keyboard and
// the activation into the popup
procedure TDropPopup.DoShowWindow;
begin
end;

// a hint window lets the mouse through to what is under it; the popup
// takes its clicks
procedure TDropPopup.WMNCHitTest(var Message: TLMessage);
begin
  Message.Result := HTCLIENT;
end;

procedure TDropPopup.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ColorToRGB(Color);
  Canvas.FillRect(ClientRect);
  if not FFramed then exit;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := pick(FBorderColor, blend(clWindow, clWindowText, 30));
  Canvas.Rectangle(ClientRect);
  Canvas.Brush.Style := bsSolid;
end;

function TDropPopup.ContentRect: TRect;
begin
  result := ClientRect;
  if FFramed then result.Inflate(-1, -1);
end;

// -- showing ----------------------

procedure TDropPopup.Drop(anchor: TControl; aWidth, aHeight: integer);
begin
  var below := anchor.ClientToScreen(Point(0, anchor.Height));
  var area := Screen.MonitorFromPoint(below).WorkareaRect;
  var y := below.Y;
  if (y+aHeight > area.Bottom) and (anchor.ClientToScreen(Point(0, 0)).Y-aHeight >= area.Top) then y := anchor.ClientToScreen(Point(0, 0)).Y-aHeight;
  y := Max(y, area.Top);
  var x := Max(Min(below.X, area.Right-aWidth), area.Left);
  ShowAt(anchor, Rect(x, y, x+aWidth, y+aHeight));
end;

procedure TDropPopup.ShowAt(anchor: TControl; const bounds: TRect);
begin
  if FAnchor <> anchor then begin
    if FAnchor <> nil then FAnchor.RemoveFreeNotification(self);
    FAnchor := anchor;
    if FAnchor <> nil then FAnchor.FreeNotification(self);
  end;
  SetBounds(bounds.Left, bounds.Top, bounds.Width, bounds.Height);
  // not Show: that ends in a ShowWindow that activates the window
  if not Visible then Visible := true;
  watch(true);
end;

procedure TDropPopup.Close;
begin
  if Visible then Visible := false;
end;

procedure TDropPopup.VisibleChanged;
begin
  inherited VisibleChanged;
  if not Visible then watch(false);
end;

// -- dismissing ----------------------

procedure TDropPopup.watch(active: boolean);
begin
  if active = FWatching then exit;
  FWatching := active;
  if active then begin
    Application.AddOnUserInputHandler(@userInput);
    Application.AddOnDeactivateHandler(@appDeactivate);
    FAnchorForm := if FAnchor <> nil then GetParentForm(FAnchor) else nil;
    if FAnchorForm <> nil then FAnchorForm.AddHandlerOnChangeBounds(@formMoved);
  end else begin
    Application.RemoveOnUserInputHandler(@userInput);
    Application.RemoveOnDeactivateHandler(@appDeactivate);
    if FAnchorForm <> nil then FAnchorForm.RemoveHandlerOnChangeBounds(@formMoved);
    FAnchorForm := nil;
  end;
end;

// the popup itself, what it holds, and the anchor the owner listens to
function TDropPopup.belongs(control: TControl): boolean;
begin
  var c := control;
  while c <> nil do begin
    if (c = self) or (c = FAnchor) then exit(true);
    c := c.Parent;
  end;
  result := false;
end;

procedure TDropPopup.userInput(Sender: TObject; var Msg: TLMessage);
begin
  if not Visible then exit;
  match Msg.Msg of
    LM_LBUTTONDOWN, LM_RBUTTONDOWN, LM_MBUTTONDOWN, LM_LBUTTONDBLCLK, LM_RBUTTONDBLCLK:
      if not ((Sender is TControl) and belongs(TControl(Sender))) then dismiss;
  else
    ;
  end;
end;

procedure TDropPopup.appDeactivate(Sender: TObject);
begin
  if Visible then dismiss;
end;

procedure TDropPopup.formMoved(Sender: TObject);
begin
  if Visible then dismiss;
end;

procedure TDropPopup.dismiss;
begin
  if Assigned(FOnDismiss) then FOnDismiss(self) else Close;
end;

procedure TDropPopup.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FAnchor) then begin
    watch(false);
    FAnchor := nil;
  end;
end;

end.
