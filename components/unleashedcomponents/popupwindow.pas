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
  // anchor moving fire OnDismiss; without a handler the popup just closes.
  // With OnAnchorMoved set, the form moving fires that one instead
  TDropPopup = class(THintWindow)
  private
    FAnchor: TControl;
    FAnchorForm: TCustomForm;
    FWatching, FFramed: boolean;
    FBorderColor: TColor;
    FOnDismiss, FOnAnchorMoved: TNotifyEvent;
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
    // the form of the anchor moved or changed its size; a popup that follows
    // its anchor places itself again here instead of closing
    property OnAnchorMoved: TNotifyEvent read FOnAnchorMoved write FOnAnchorMoved;
  end;

// `handler` runs inside the message that moved or resized `form`, so what
// follows the form stays on it at every step of a drag; the handlers of
// OnChangeBounds come only once the layout of the form has settled
procedure watchFormBounds(form: TCustomForm; handler: TNotifyEvent);
procedure unwatchFormBounds(form: TCustomForm; handler: TNotifyEvent);

implementation

uses
  Math, LazMethodList, ControlPaint;

type
  // sits in front of the window procedure of its form for as long as the
  // form lives, and tells the listeners of every move and resize
  TFormBoundsWatch = class(TComponent)
  private
    FForm: TCustomForm;
    FNext: TWndMethod;
    FHandlers: TMethodList;
    procedure proc(var msg: TLMessage);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

constructor TFormBoundsWatch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FForm := AOwner as TCustomForm;
  FHandlers := TMethodList.Create;
  FNext := FForm.WindowProc;
  FForm.WindowProc := @proc;
end;

destructor TFormBoundsWatch.Destroy;
begin
  // components go in the reverse order of their creation, so whoever stepped
  // in front later has stepped back by now
  if TMethod(FForm.WindowProc).Data = pointer(self) then FForm.WindowProc := FNext;
  FHandlers.Free;
  inherited Destroy;
end;

procedure TFormBoundsWatch.proc(var msg: TLMessage);
begin
  FNext(msg);
  if (msg.Msg = LM_MOVE) or (msg.Msg = LM_SIZE) then FHandlers.CallNotifyEvents(FForm);
end;

function watchOf(form: TCustomForm; make: boolean): TFormBoundsWatch;
begin
  for var i := 0 to form.ComponentCount-1 do
    if form.Components[i] is TFormBoundsWatch then exit(TFormBoundsWatch(form.Components[i]));
  result := if make then TFormBoundsWatch.Create(form) else nil;
end;

procedure watchFormBounds(form: TCustomForm; handler: TNotifyEvent);
begin
  if (form = nil) or (csDestroying in form.ComponentState) then exit;
  var watch := watchOf(form, true);
  watch.FHandlers.Remove(TMethod(handler));
  watch.FHandlers.Add(TMethod(handler));
end;

procedure unwatchFormBounds(form: TCustomForm; handler: TNotifyEvent);
begin
  if form = nil then exit;
  var watch := watchOf(form, false);
  if watch <> nil then watch.FHandlers.Remove(TMethod(handler));
end;

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
  // a repaint of the popup would wipe the controls on it otherwise
  clipChildren(Handle);
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
    watchFormBounds(FAnchorForm, @formMoved);
  end else begin
    Application.RemoveOnUserInputHandler(@userInput);
    Application.RemoveOnDeactivateHandler(@appDeactivate);
    unwatchFormBounds(FAnchorForm, @formMoved);
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
  if not Visible then exit;
  if Assigned(FOnAnchorMoved) then FOnAnchorMoved(self) else dismiss;
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
