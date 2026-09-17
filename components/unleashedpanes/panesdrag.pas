{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PanesDrag;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, LCLType, LCLIntf, {$ifdef WINDOWS}Windows,{$endif}
  {$ifdef LCLGtk3}LazCairo1, LazGtk3, LazGdk3, LazGLib2, LazGObject2, Gtk3Widgets, Gtk3Objects, Gtk3Procs,{$endif} PanesLayout;

const
  OVERLAY_ALPHA = 120;
  SHADOW_ALPHA = 110;

type
  TDragSession = class;

  { TDragOverlay }

  // translucent cover over one host while a pane is dragged: the window edges
  // always, the zones of the leaf under the cursor, and where the pane lands
  TDragOverlay = class(THintWindow)
  private
    fSession: TDragSession;
    fHost: TPaneHost;
    procedure applyColorKey;
    procedure draw(target: TCanvas; mask: boolean);
    procedure paintZones(target: TCanvas; const zones: TDropZones; blocked, mask: boolean);
    {$if not defined(WINDOWS) and not defined(LCLGtk3)}
    procedure updateShape;
    {$endif}
  protected
    procedure Paint; override;
    procedure UpdateRegion; override;
  public
    constructor Create(AOwner: TComponent); override;
    // covers the host and shows without taking the focus
    procedure follow;
    // repaints after the drop target changed
    procedure refresh;
    property host: TPaneHost read fHost write fHost;
    property session: TDragSession read fSession write fSession;
  end;

  { TDragShadow }

  // pale copy of the dragged pane under the cursor
  TDragShadow = class(THintWindow)
  protected
    procedure Paint; override;
    procedure UpdateRegion; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { TDragSession }

  // one drag from the press on the move button to the release
  TDragSession = class
  private
    fFrame: TPaneFrame;
    fForm: TCustomForm;
    fOverlays: TFPList;
    fShadow: TDragShadow;
    fGrab: TPoint;
    fHost: TPaneHost;
    fZone: TDropZone;
    fHasZone: boolean;
    function overlayOf(host: TPaneHost): TDragOverlay;
  public
    constructor Create(frame: TPaneFrame; hosts: TFPList);
    destructor Destroy; override;
    // cursor moved; host is the window under it, zone the drop zone there if any
    procedure moveTo(const screenPos: TPoint; host: TPaneHost; const zone: TDropZone; hasZone: boolean);
    // the leaf whose own zones stay closed: the frame, or none when one form
    // of it travels and may land beside it
    function dragged: TControl;
    // a window that already shows the pane takes no drop
    function blockedIn(aHost: TPaneHost): boolean;
    property frame: TPaneFrame read fFrame;
    // the one form of the frame on the move; nil moves the whole frame
    property form: TCustomForm read fForm write fForm;
    property host: TPaneHost read fHost;
    property zone: TDropZone read fZone;
    property hasZone: boolean read fHasZone;
  end;

implementation

const
  // painted where the overlay must stay see-through
  KEY_COLOR = TColor($00FF00FF);
  GREEN_PALE = TColor($0090D890);
  GREEN_HOT = TColor($0040C040);
  GREEN_PANE = TColor($0060C860);
  // a window that already shows the dragged pane takes nothing
  RED_PALE = TColor($008080E0);
  RED_HOT = TColor($004040C0);

{$ifdef LCLGtk3}
// the theme sheet gives every container a background, which gtk paints under
// the LCL buffer; the provider takes it off the widget and all below it
procedure clearBackground(widget: PGtkWidget; css: PGtkCssProvider);
begin
  gtk_style_context_add_provider(gtk_widget_get_style_context(widget), PGtkStyleProvider(css), GTK_STYLE_PROVIDER_PRIORITY_USER);
  if not Gtk3IsContainer(PGObject(widget)) then exit;
  var children := gtk_container_get_children(PGtkContainer(widget));
  var item := children;
  while item <> nil do begin
    clearBackground(PGtkWidget(item^.data), css);
    item := item^.next;
  end;
  g_list_free(children);
end;

// an alpha visual before the first show: the window then carries its own
// transparency and needs neither the opacity hint nor a shape from the window
// manager, which a nested X server such as Xwayland does not honor
procedure alphaWindow(window: TWinControl);
begin
  window.HandleNeeded;
  var widget := TGtk3Widget(window.Handle).Widget;
  // the LCL realizes a top level as it creates it, and a visual only takes
  // on an unrealized widget; the show realizes it again
  if gtk_widget_get_realized(widget) then gtk_widget_unrealize(widget);
  gtk_widget_set_app_paintable(widget, True);
  gtk_widget_set_visual(widget, gdk_screen_get_rgba_visual(gdk_screen_get_default));
  var css := gtk_css_provider_new;
  gtk_css_provider_load_from_data(css, '* { background-color: transparent; background-image: none; }', -1, nil);
  clearBackground(widget, css);
  g_object_unref(css);
end;
{$endif}

// -- TDragOverlay --------------------------------------------------------------

constructor TDragOverlay.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := KEY_COLOR;
  {$ifndef LCLGtk3}
  AlphaBlend := true;
  AlphaBlendValue := OVERLAY_ALPHA;
  {$endif}
end;

procedure TDragOverlay.UpdateRegion;
begin
  // the hint region would round the corners
end;

{$if not defined(WINDOWS) and not defined(LCLGtk3)}
// the window shape cuts the key color away: white in the mask is where it paints
procedure TDragOverlay.updateShape;
begin
  if not HandleAllocated then exit;
  var mask := TBitmap.Create;
  try
    mask.SetSize(Width, Height);
    draw(mask.Canvas, true);
    SetShape(mask);
  finally
    mask.Free;
  end;
end;
{$endif}

// the key color becomes fully transparent, the rest keeps the alpha
procedure TDragOverlay.applyColorKey;
begin
  {$if defined(WINDOWS)}
  if HandleAllocated then SetLayeredWindowAttributes(Handle, ColorToRGB(KEY_COLOR), OVERLAY_ALPHA, LWA_ALPHA or LWA_COLORKEY);
  {$elseif not defined(LCLGtk3)}
  updateShape;
  {$endif}
end;

procedure TDragOverlay.refresh;
begin
  {$if not defined(WINDOWS) and not defined(LCLGtk3)}
  updateShape;
  {$endif}
  Invalidate;
end;

// the hint window shows topmost, so it goes right above the window of its
// host instead: whatever covers that window keeps covering the overlay too
procedure TDragOverlay.follow;
begin
  if fHost = nil then exit;
  var origin := fHost.ClientToScreen(Classes.Point(0, 0));
  SetBounds(origin.X, origin.Y, fHost.ClientWidth, fHost.ClientHeight);
  {$ifdef LCLGtk3}
  alphaWindow(Self);
  {$endif}
  Visible := true;
  applyColorKey;
  {$ifdef WINDOWS}
  var window := GetParentForm(fHost);
  if (window = nil) or not window.HandleAllocated then exit;
  var above := GetWindow(window.Handle, GW_HWNDPREV);
  // a slot behind a topmost window would make the overlay topmost again
  if (above <> 0) and (GetWindowLong(above, GWL_EXSTYLE) and WS_EX_TOPMOST <> 0) then above := 0;
  SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  SetWindowPos(Handle, if above = 0 then HWND_TOP else above, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  {$endif}
end;

procedure TDragOverlay.paintZones(target: TCanvas; const zones: TDropZones; blocked, mask: boolean);
begin
  for var i := 0 to High(zones) do begin
    var hot := (fSession.host = fHost) and fSession.hasZone and sameZone(zones[i], fSession.zone);
    target.Brush.Color := if mask then clWhite else if blocked then RED_PALE else if hot then GREEN_HOT else GREEN_PALE;
    target.FillRect(zones[i].rect);
    if mask then continue;
    target.Pen.Color := if blocked then RED_HOT else GREEN_HOT;
    target.Pen.Style := psDash;
    target.Brush.Style := bsClear;
    target.Rectangle(zones[i].rect.Left+1, zones[i].rect.Top+1, zones[i].rect.Right-1, zones[i].rect.Bottom-1);
    target.Pen.Style := psSolid;
    target.Brush.Style := bsSolid;
  end;
end;

// the overlay picture; as a mask it is white wherever something is painted
procedure TDragOverlay.draw(target: TCanvas; mask: boolean);
begin
  // gtk3 paints into a transparent group instead, see Paint
  {$ifndef LCLGtk3}
  target.Brush.Style := bsSolid;
  target.Brush.Color := if mask then clBlack else KEY_COLOR;
  target.FillRect(ClientRect);
  {$endif}
  if (fHost = nil) or (fSession = nil) then exit;
  var here := (fSession.host = fHost) and fSession.hasZone;
  // the landing place goes under the zones, so the hot zone stays readable
  if here then begin
    target.Brush.Color := if mask then clWhite else GREEN_PANE;
    target.FillRect(fSession.zone.landing);
  end;
  var blocked := fSession.blockedIn(fHost);
  paintZones(target, fHost.outerZones, blocked, mask);
  if here and (fSession.zone.kind in [dzSplit, dzTab]) then paintZones(target, fHost.zonesOf(fSession.zone.target, fSession.dragged), blocked, mask);
end;

procedure TDragOverlay.Paint;
begin
  {$ifdef LCLGtk3}
  // the zones go into a transparent group, which lands on the window with the
  // overlay alpha; whatever the erase painted before goes away with it
  var cr := TGtk3DeviceContext(Canvas.Handle).pcr;
  cairo_push_group(cr);
  draw(Canvas, false);
  cairo_pop_group_to_source(cr);
  // a plain clear first: a masked SOURCE paint would blend with the erase
  cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
  cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
  cairo_paint_with_alpha(cr, OVERLAY_ALPHA/255);
  {$else}
  draw(Canvas, false);
  {$endif}
end;

// -- TDragShadow ---------------------------------------------------------------

constructor TDragShadow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := clWhite;
  {$ifndef LCLGtk3}
  AlphaBlend := true;
  AlphaBlendValue := SHADOW_ALPHA;
  {$endif}
end;

procedure TDragShadow.UpdateRegion;
begin
end;

procedure TDragShadow.Paint;
begin
  {$ifdef LCLGtk3}
  var cr := TGtk3DeviceContext(Canvas.Handle).pcr;
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
  cairo_set_source_rgba(cr, 1, 1, 1, SHADOW_ALPHA/255);
  cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
  {$else}
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(ClientRect);
  {$endif}
end;

// -- TDragSession --------------------------------------------------------------

constructor TDragSession.Create(frame: TPaneFrame; hosts: TFPList);
begin
  inherited Create;
  fFrame := frame;
  fOverlays := TFPList.Create;
  fGrab := frame.ScreenToClient(Mouse.CursorPos);
  for var i := 0 to hosts.Count-1 do begin
    var overlay := TDragOverlay.Create(nil);
    overlay.host := TPaneHost(hosts[i]);
    overlay.session := Self;
    overlay.follow;
    fOverlays.Add(overlay);
  end;
  fShadow := TDragShadow.Create(nil);
  var origin := Mouse.CursorPos;
  fShadow.SetBounds(origin.X-fGrab.X, origin.Y-fGrab.Y, frame.Width, frame.Height);
  {$ifdef LCLGtk3}
  alphaWindow(fShadow);
  {$endif}
  fShadow.Visible := true;
end;

destructor TDragSession.Destroy;
begin
  fShadow.Free;
  for var i := 0 to fOverlays.Count-1 do TDragOverlay(fOverlays[i]).Free;
  fOverlays.Free;
  inherited Destroy;
end;

function TDragSession.dragged: TControl;
begin
  result := if fForm = nil then fFrame else nil;
end;

function TDragSession.blockedIn(aHost: TPaneHost): boolean;
begin
  result := if fForm = nil then aHost.holdsCopyOf(fFrame) else aHost.holdsCopyOf(fForm, fFrame);
end;

function TDragSession.overlayOf(host: TPaneHost): TDragOverlay;
begin
  result := nil;
  for var i := 0 to fOverlays.Count-1 do if TDragOverlay(fOverlays[i]).host = host then exit(TDragOverlay(fOverlays[i]));
end;

procedure TDragSession.moveTo(const screenPos: TPoint; host: TPaneHost; const zone: TDropZone; hasZone: boolean);

  procedure repaint(aHost: TPaneHost);
  begin
    var overlay := overlayOf(aHost);
    if overlay <> nil then overlay.refresh;
  end;

begin
  fShadow.SetBounds(screenPos.X-fGrab.X, screenPos.Y-fGrab.Y, fShadow.Width, fShadow.Height);
  if (host = fHost) and (hasZone = fHasZone) and (not hasZone or sameZone(zone, fZone)) then exit;
  var previous := fHost;
  fHost := host;
  fZone := zone;
  fHasZone := hasZone;
  if previous <> nil then repaint(previous);
  if (fHost <> nil) and (fHost <> previous) then repaint(fHost);
end;

end.
