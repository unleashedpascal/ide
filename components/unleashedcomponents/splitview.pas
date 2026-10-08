{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SplitView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  TPaneSide = (psLeft, psRight);
  // dmInline: the pane pushes the content aside; dmOverlay: it slides over it
  TPaneDisplayMode = (dmInline, dmOverlay);

  { TSplitView }

  // a host for a side pane and the content beside it: drop two containers
  // on it and name one as the PaneControl, the other one fills the rest.
  // The pane opens and closes with a slide and its edge can be dragged
  TSplitView = class(TCustomControl)
  private
    FPaneControl, FContentControl: TControl;
    FPaneSide: TPaneSide;
    FDisplayMode: TPaneDisplayMode;
    FPaneWidth, FMinPaneWidth, FMaxPaneWidth, FCompactWidth, FSplitterWidth, FAnimationTime: integer;
    FPaneOpen, FAnimated, FResizable: boolean;
    FSplitterColor: TColor;
    FShown: integer; // the pixels of the pane on screen now
    FTimer: TTimer;
    FFrom, FTo: integer;
    FStarted: QWord;
    FDragging, FHotSplitter, FLaying: boolean;
    FDragStart, FDragWidth: integer;
    FPainted: TRect; // the splitter as the last paint drew it
    FOnPaneOpened, FOnPaneClosed, FOnPaneResized: TNotifyEvent;
    procedure setPaneControl(value: TControl);
    procedure setContentControl(value: TControl);
    procedure setPaneSide(value: TPaneSide);
    procedure setDisplayMode(value: TPaneDisplayMode);
    procedure setPaneOpen(value: boolean);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setSplitterColor(value: TColor);
    function targetWidth: integer;
    function splitterRect: TRect;
    procedure settle(animate: boolean);
    procedure tick(Sender: TObject);
    procedure layout;
    procedure moveTo(shown: integer);
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure TogglePane;
  published
    // the child that is the pane; every other child fills the content area
    property PaneControl: TControl read FPaneControl write setPaneControl;
    // set, only this child takes the content area
    property ContentControl: TControl read FContentControl write setContentControl;
    property PaneSide: TPaneSide read FPaneSide write setPaneSide default psLeft;
    property DisplayMode: TPaneDisplayMode read FDisplayMode write setDisplayMode default dmInline;
    property PaneOpen: boolean index 0 read getFlag write setFlag default true;
    property Animated: boolean index 1 read getFlag write setFlag default true;
    // the edge of the pane can be dragged
    property Resizable: boolean index 2 read getFlag write setFlag default true;
    property PaneWidth: integer index 0 read getMetric write setMetric default 240;
    property MinPaneWidth: integer index 1 read getMetric write setMetric default 120;
    // 0 for no limit
    property MaxPaneWidth: integer index 2 read getMetric write setMetric default 0;
    // the strip of the pane that stays while it is closed; 0 hides it fully
    property CompactWidth: integer index 3 read getMetric write setMetric default 0;
    property SplitterWidth: integer index 4 read getMetric write setMetric default 4;
    property AnimationTime: integer index 5 read getMetric write setMetric default 200;
    // clDefault takes the color of the theme
    property SplitterColor: TColor read FSplitterColor write setSplitterColor default clDefault;
    property OnPaneOpened: TNotifyEvent read FOnPaneOpened write FOnPaneOpened;
    property OnPaneClosed: TNotifyEvent read FOnPaneClosed write FOnPaneClosed;
    property OnPaneResized: TNotifyEvent read FOnPaneResized write FOnPaneResized;
    property Align;
    property Anchors;
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

constructor TSplitView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  FPaneWidth := 240;
  FMinPaneWidth := 120;
  FSplitterWidth := 4;
  FAnimationTime := 200;
  FPaneOpen := true;
  FAnimated := true;
  FResizable := true;
  FSplitterColor := clDefault;
  FShown := FPaneWidth;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 16;
  FTimer.OnTimer := @tick;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TSplitView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 480;
  result.cy := 320;
end;

// -- layout ----------------------

function TSplitView.targetWidth: integer;
begin
  result := scaled(self, if FPaneOpen then FPaneWidth else FCompactWidth);
end;

function TSplitView.splitterRect: TRect;
begin
  var w := scaled(self, FSplitterWidth);
  if FPaneSide = psLeft then result := Rect(FShown, 0, FShown+w, ClientHeight)
  else result := Rect(ClientWidth-FShown-w, 0, ClientWidth-FShown, ClientHeight);
end;

procedure TSplitView.layout;
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  var w := Max(FShown, 0);
  var gap := scaled(self, FSplitterWidth);
  var paneRect := if FPaneSide = psLeft then Rect(0, 0, w, ClientHeight) else Rect(ClientWidth-w, 0, ClientWidth, ClientHeight);
  var contentRect := ClientRect;
  if FDisplayMode = dmInline then begin
    if FPaneSide = psLeft then contentRect.Left := w+gap else contentRect.Right := ClientWidth-w-gap;
  end;
  try
    for var i := 0 to ControlCount-1 do begin
      var c := Controls[i];
      // a placement only goes through when it changes something, since even
      // an unchanged one asks for another pass
      if c = FPaneControl then begin
        if c.BoundsRect <> paneRect then c.BoundsRect := paneRect;
      end else if ((FContentControl = nil) or (c = FContentControl)) and (c.BoundsRect <> contentRect) then c.BoundsRect := contentRect;
    end;
    // over the content, the pane has to be the topmost child
    if (FDisplayMode = dmOverlay) and (FPaneControl <> nil) then FPaneControl.BringToFront;
  finally
    FLaying := false;
  end;
  // the children repaint what they uncover; the view repaints when its
  // splitter moves
  if splitterRect <> FPainted then Invalidate;
end;

// the pane at `shown` pixels, the children placed in one pass
procedure TSplitView.moveTo(shown: integer);
begin
  FShown := shown;
  DisableAutoSizing;
  try
    layout;
  finally
    EnableAutoSizing;
  end;
end;

procedure TSplitView.AlignControls(AControl: TControl; var ARect: TRect);
begin
  // the view places its children itself, Align and Anchors do not apply
  layout;
end;

// -- folding ----------------------

procedure TSplitView.TogglePane;
begin
  PaneOpen := not FPaneOpen;
end;

procedure TSplitView.setPaneOpen(value: boolean);
begin
  if FPaneOpen = value then exit;
  FPaneOpen := value;
  settle(FAnimated and not (csDesigning in ComponentState) and not (csLoading in ComponentState));
  if csLoading in ComponentState then exit;
  if FPaneOpen then begin
    if Assigned(FOnPaneOpened) then FOnPaneOpened(self);
  end else if Assigned(FOnPaneClosed) then FOnPaneClosed(self);
end;

procedure TSplitView.settle(animate: boolean);
begin
  FTimer.Enabled := false;
  if animate and HandleAllocated and (FAnimationTime > 0) then begin
    FFrom := FShown;
    FTo := targetWidth;
    FStarted := GetTickCount64;
    FTimer.Enabled := true;
  end else begin
    FShown := targetWidth;
    layout;
  end;
end;

procedure TSplitView.tick(Sender: TObject);
begin
  var elapsed := GetTickCount64-FStarted;
  if elapsed >= QWord(FAnimationTime) then begin
    FTimer.Enabled := false;
    FShown := FTo;
  end else begin
    var t := elapsed/FAnimationTime;
    t := 1-(1-t)*(1-t);
    FShown := FFrom+Round((FTo-FFrom)*t);
  end;
  moveTo(FShown);
end;

procedure TSplitView.Loaded;
begin
  inherited Loaded;
  settle(false);
end;

// -- painting ----------------------

procedure TSplitView.Paint;
begin
  var back := GetRGBColorResolvingParent;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := back;
  Canvas.FillRect(ClientRect);
  var s := splitterRect;
  FPainted := s;
  if (FShown <= 0) or (FSplitterWidth <= 0) then exit;
  var line := pick(FSplitterColor, blend(clBtnFace, clBtnShadow, 40));
  if (FHotSplitter or FDragging) and FResizable and hoverEnabled then line := ColorToRGB(clHighlight);
  Canvas.Brush.Color := line;
  Canvas.FillRect(s);
end;

// -- input ----------------------

procedure TSplitView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FResizable or not FPaneOpen or not splitterRect.Contains(Point(X, Y)) then exit;
  FDragging := true;
  FDragStart := X;
  FDragWidth := FShown;
end;

procedure TSplitView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging then begin
    var delta := if FPaneSide = psLeft then X-FDragStart else FDragStart-X;
    var w := FDragWidth+delta;
    w := Max(w, scaled(self, FMinPaneWidth));
    if FMaxPaneWidth > 0 then w := Min(w, scaled(self, FMaxPaneWidth));
    w := Min(w, ClientWidth-scaled(self, FSplitterWidth));
    if w <> FShown then begin
      moveTo(w);
      // the moved panes show before the next move
      paintNow(self);
    end;
    exit;
  end;
  var hot := FResizable and FPaneOpen and splitterRect.Contains(Point(X, Y));
  Cursor := if hot then crHSplit else crDefault;
  if hot <> FHotSplitter then begin
    FHotSplitter := hot;
    Invalidate;
  end;
end;

procedure TSplitView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FDragging then exit;
  FDragging := false;
  // the dragged size is the new width in unscaled pixels
  FPaneWidth := Round(FShown*96/Font.PixelsPerInch);
  if scaled(self, FPaneWidth) <> FShown then FPaneWidth := FShown;
  Invalidate;
  if Assigned(FOnPaneResized) then FOnPaneResized(self);
end;

procedure TSplitView.MouseLeave;
begin
  inherited MouseLeave;
  if FHotSplitter then begin
    FHotSplitter := false;
    Invalidate;
  end;
end;

procedure TSplitView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  if AComponent = FPaneControl then FPaneControl := nil;
  if AComponent = FContentControl then FContentControl := nil;
end;

// -- properties ----------------------

procedure TSplitView.setPaneControl(value: TControl);
begin
  if FPaneControl = value then exit;
  if (value <> nil) and (value.Parent <> self) then exit;
  if FPaneControl <> nil then FPaneControl.RemoveFreeNotification(self);
  FPaneControl := value;
  if FPaneControl <> nil then FPaneControl.FreeNotification(self);
  layout;
end;

procedure TSplitView.setContentControl(value: TControl);
begin
  if FContentControl = value then exit;
  if (value <> nil) and (value.Parent <> self) then exit;
  if FContentControl <> nil then FContentControl.RemoveFreeNotification(self);
  FContentControl := value;
  if FContentControl <> nil then FContentControl.FreeNotification(self);
  layout;
end;

procedure TSplitView.setPaneSide(value: TPaneSide);
begin
  if FPaneSide = value then exit;
  FPaneSide := value;
  layout;
end;

procedure TSplitView.setDisplayMode(value: TPaneDisplayMode);
begin
  if FDisplayMode = value then exit;
  FDisplayMode := value;
  layout;
end;

function TSplitView.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FPaneOpen;
    1: FAnimated;
  else
    FResizable
  end;
end;

procedure TSplitView.setFlag(index: integer; value: boolean);
begin
  match index of
    0: setPaneOpen(value);
    1: FAnimated := value;
  else
    begin
      FResizable := value;
      Invalidate;
    end;
  end;
end;

function TSplitView.getMetric(index: integer): integer;
begin
  result := match index of
    0: FPaneWidth;
    1: FMinPaneWidth;
    2: FMaxPaneWidth;
    3: FCompactWidth;
    4: FSplitterWidth;
  else
    FAnimationTime
  end;
end;

procedure TSplitView.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FPaneWidth := value;
    1: FMinPaneWidth := value;
    2: FMaxPaneWidth := value;
    3: FCompactWidth := value;
    4: FSplitterWidth := value;
  else
    FAnimationTime := value;
  end;
  if not (csLoading in ComponentState) then settle(false);
end;

procedure TSplitView.setSplitterColor(value: TColor);
begin
  if FSplitterColor = value then exit;
  FSplitterColor := value;
  Invalidate;
end;

end.
