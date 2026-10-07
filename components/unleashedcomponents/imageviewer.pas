{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ImageViewer;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType;

type
  // fmNone shows the picture at Zoom; the others pick the zoom from the box
  TImageFitMode = (fmNone, fmFit, fmFitWidth, fmFitHeight, fmFill);
  TZoomEvent = procedure(Sender: TObject; zoom: double) of object;

  { TImageViewer }

  // a picture with zoom and pan: the wheel zooms around the mouse, a drag
  // moves the picture, a double click fits it again. The picture may be
  // loaded from a file, a stream or assigned
  TImageViewer = class(TCustomControl)
  private
    FPicture: TPicture;
    FZoom: double; // 1 is the natural size
    FOffset: TPoint; // the picture origin against the centered position
    FFitMode: TImageFitMode;
    FMinZoom, FMaxZoom, FZoomStep: double;
    FCheckerboard, FWheelZooms, FDragPans, FSmooth, FShowBorder: boolean;
    FBackColor, FBorderColor: TColor;
    FDragging: boolean;
    FDragStart, FDragOrigin: TPoint;
    FOnZoomChanged: TZoomEvent;
    FOnPictureChanged: TNotifyEvent;
    procedure setPicture(value: TPicture);
    procedure setZoom(value: double);
    procedure setFitMode(value: TImageFitMode);
    procedure setLimit(index: integer; value: double);
    function getLimit(index: integer): double;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure pictureChanged(Sender: TObject);
    function hasPicture: boolean;
    function fitZoom(mode: TImageFitMode): double;
    function effectiveZoom: double;
    function pictureRect: TRect;
    procedure clampOffset;
    function limitStored(index: integer): boolean;
  protected
    procedure Paint; override;
    procedure DoOnResize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const fileName: string);
    procedure LoadFromStream(stream: TStream);
    procedure Clear;
    procedure ZoomIn;
    procedure ZoomOut;
    // the natural size, centered
    procedure ActualSize;
    // the whole picture in the box
    procedure FitToWindow;
    // zooms around a client point
    procedure ZoomAt(factor: double; const at: TPoint);
    // the picture point under a client point, or (-1,-1) outside the picture
    function PicturePointAt(const client: TPoint): TPoint;
    // the zoom on screen, the fit included
    property CurrentZoom: double read effectiveZoom;
  published
    property Picture: TPicture read FPicture write setPicture;
    // the zoom with FitMode fmNone; 1 is the natural size
    property Zoom: double read FZoom write setZoom;
    property FitMode: TImageFitMode read FFitMode write setFitMode default fmFit;
    property MinZoom: double index 0 read getLimit write setLimit stored limitStored;
    property MaxZoom: double index 1 read getLimit write setLimit stored limitStored;
    // the factor of a zoom step
    property ZoomStep: double index 2 read getLimit write setLimit stored limitStored;
    // a checkerboard behind a picture with transparency
    property Checkerboard: boolean index 0 read getFlag write setFlag default true;
    property WheelZooms: boolean index 1 read getFlag write setFlag default true;
    property DragPans: boolean index 2 read getFlag write setFlag default true;
    // the picture resamples when scaled; off, the pixels stay sharp
    property Smooth: boolean index 3 read getFlag write setFlag default true;
    property ShowBorder: boolean index 4 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property BackColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property OnZoomChanged: TZoomEvent read FOnZoomChanged write FOnZoomChanged;
    property OnPictureChanged: TNotifyEvent read FOnPictureChanged write FOnPictureChanged;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Enabled;
    property Hint;
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
    property OnMouseWheel;
    property OnResize;
  end;

implementation

uses
  Math, IntfGraphics, FPImage, FPCanvas, ControlPaint;

constructor TImageViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption];
  FPicture := TPicture.Create;
  FPicture.OnChange := @pictureChanged;
  FZoom := 1;
  FFitMode := fmFit;
  FMinZoom := 0.05;
  FMaxZoom := 32;
  FZoomStep := 1.25;
  FCheckerboard := true;
  FWheelZooms := true;
  FDragPans := true;
  FSmooth := true;
  FShowBorder := true;
  FBackColor := clDefault;
  FBorderColor := clDefault;
  TabStop := true;
  DoubleBuffered := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TImageViewer.Destroy;
begin
  FPicture.Free;
  inherited Destroy;
end;

class function TImageViewer.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 180;
end;

function TImageViewer.limitStored(index: integer): boolean;
begin
  result := true;
end;

// -- picture ----------------------

function TImageViewer.hasPicture: boolean;
begin
  result := (FPicture.Graphic <> nil) and not FPicture.Graphic.Empty and (FPicture.Width > 0) and (FPicture.Height > 0);
end;

procedure TImageViewer.pictureChanged(Sender: TObject);
begin
  FOffset := Point(0, 0);
  Invalidate;
  if Assigned(FOnPictureChanged) then FOnPictureChanged(self);
end;

procedure TImageViewer.LoadFromFile(const fileName: string);
begin
  FPicture.LoadFromFile(fileName);
end;

procedure TImageViewer.LoadFromStream(stream: TStream);
begin
  FPicture.LoadFromStream(stream);
end;

procedure TImageViewer.Clear;
begin
  FPicture.Clear;
end;

// -- zoom ----------------------

function TImageViewer.fitZoom(mode: TImageFitMode): double;
begin
  result := 1;
  if not hasPicture or (ClientWidth < 2) or (ClientHeight < 2) then exit;
  var zx := ClientWidth/FPicture.Width;
  var zy := ClientHeight/FPicture.Height;
  result := match mode of
    fmFit: Min(zx, zy);
    fmFitWidth: zx;
    fmFitHeight: zy;
    fmFill: Max(zx, zy);
  else
    FZoom
  end;
end;

function TImageViewer.effectiveZoom: double;
begin
  result := if FFitMode = fmNone then FZoom else fitZoom(FFitMode);
end;

function TImageViewer.pictureRect: TRect;
begin
  result := Rect(0, 0, 0, 0);
  if not hasPicture then exit;
  var z := effectiveZoom;
  var w := Max(Round(FPicture.Width*z), 1);
  var h := Max(Round(FPicture.Height*z), 1);
  var left := (ClientWidth-w) div 2+FOffset.X;
  var top := (ClientHeight-h) div 2+FOffset.Y;
  result := Rect(left, top, left+w, top+h);
end;

// the picture never leaves the box entirely; a picture smaller than the box
// stays centered
procedure TImageViewer.clampOffset;
begin
  if not hasPicture then exit;
  var z := effectiveZoom;
  var w := Round(FPicture.Width*z);
  var h := Round(FPicture.Height*z);
  var slackX := Max((w-ClientWidth) div 2, 0);
  var slackY := Max((h-ClientHeight) div 2, 0);
  FOffset.X := EnsureRange(FOffset.X, -slackX, slackX);
  FOffset.Y := EnsureRange(FOffset.Y, -slackY, slackY);
end;

procedure TImageViewer.ZoomAt(factor: double; const at: TPoint);
begin
  if not hasPicture then exit;
  var oldZoom := effectiveZoom;
  var newZoom := EnsureRange(oldZoom*factor, FMinZoom, FMaxZoom);
  if SameValue(oldZoom, newZoom) then exit;
  // the picture point under the mouse stays under it
  var r := pictureRect;
  var px := (at.X-r.Left)/oldZoom;
  var py := (at.Y-r.Top)/oldZoom;
  FFitMode := fmNone;
  FZoom := newZoom;
  var w := Round(FPicture.Width*newZoom);
  var h := Round(FPicture.Height*newZoom);
  FOffset.X := Round(at.X-px*newZoom)-(ClientWidth-w) div 2;
  FOffset.Y := Round(at.Y-py*newZoom)-(ClientHeight-h) div 2;
  clampOffset;
  Invalidate;
  if Assigned(FOnZoomChanged) then FOnZoomChanged(self, FZoom);
end;

procedure TImageViewer.ZoomIn;
begin
  ZoomAt(FZoomStep, Point(ClientWidth div 2, ClientHeight div 2));
end;

procedure TImageViewer.ZoomOut;
begin
  ZoomAt(1/FZoomStep, Point(ClientWidth div 2, ClientHeight div 2));
end;

procedure TImageViewer.ActualSize;
begin
  FFitMode := fmNone;
  FZoom := 1;
  FOffset := Point(0, 0);
  Invalidate;
  if Assigned(FOnZoomChanged) then FOnZoomChanged(self, FZoom);
end;

procedure TImageViewer.FitToWindow;
begin
  setFitMode(fmFit);
end;

function TImageViewer.PicturePointAt(const client: TPoint): TPoint;
begin
  result := Point(-1, -1);
  if not hasPicture then exit;
  var r := pictureRect;
  if not r.Contains(client) then exit;
  var z := effectiveZoom;
  result := Point(Trunc((client.X-r.Left)/z), Trunc((client.Y-r.Top)/z));
end;

// -- painting ----------------------

procedure TImageViewer.Paint;
begin
  var back := pick(FBackColor, clWindow);
  var border := pick(FBorderColor, clBtnShadow);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := back;
  Canvas.FillRect(ClientRect);
  if hasPicture then begin
    var r := pictureRect;
    if FCheckerboard then begin
      // the board only where the picture lies
      var cell := Max(scaled(self, 8), 4);
      var light := blend(back, clWindowText, 8);
      var dark := blend(back, clWindowText, 16);
      var visible := r;
      visible.Intersect(ClientRect);
      var y := visible.Top;
      while y < visible.Bottom do begin
        var x := visible.Left;
        while x < visible.Right do begin
          var odd := (((x-r.Left) div cell)+((y-r.Top) div cell)) mod 2 = 1;
          Canvas.Brush.Color := if odd then dark else light;
          Canvas.FillRect(Rect(x, y, Min(x+cell-(x-r.Left) mod cell, visible.Right), Min(y+cell-(y-r.Top) mod cell, visible.Bottom)));
          x += cell-(x-r.Left) mod cell;
        end;
        y += cell-(y-r.Top) mod cell;
      end;
    end;
    if (r.Width = FPicture.Width) and (r.Height = FPicture.Height) then Canvas.Draw(r.Left, r.Top, FPicture.Graphic)
    else begin
      Canvas.AntialiasingMode := if FSmooth then amOn else amOff;
      Canvas.StretchDraw(r, FPicture.Graphic);
      Canvas.AntialiasingMode := amDontCare;
    end;
    if FShowBorder then begin
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := if Focused and ringEnabled then ringColor else border;
      Canvas.Rectangle(r.Left-1, r.Top-1, r.Right+1, r.Bottom+1);
      Canvas.Brush.Style := bsSolid;
    end;
  end;
end;

procedure TImageViewer.DoOnResize;
begin
  inherited DoOnResize;
  clampOffset;
  Invalidate;
end;

// -- input ----------------------

procedure TImageViewer.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if TabStop and CanSetFocus then SetFocus;
  if not FDragPans or not hasPicture then exit;
  FDragging := true;
  FDragStart := Point(X, Y);
  FDragOrigin := FOffset;
  Cursor := crSizeAll;
end;

procedure TImageViewer.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging then exit;
  FOffset := Point(FDragOrigin.X+X-FDragStart.X, FDragOrigin.Y+Y-FDragStart.Y);
  clampOffset;
  Invalidate;
end;

procedure TImageViewer.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FDragging then exit;
  FDragging := false;
  Cursor := crDefault;
end;

procedure TImageViewer.DblClick;
begin
  inherited DblClick;
  if FFitMode = fmFit then ActualSize else FitToWindow;
end;

function TImageViewer.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result or not FWheelZooms then exit;
  var local := MousePos; // the wheel position comes in client coordinates
  ZoomAt((if WheelDelta > 0 then FZoomStep else 1/FZoomStep), local);
  result := true;
end;

procedure TImageViewer.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var step := scaled(self, 20);
  match Key of
    VK_ADD, VK_OEM_PLUS: ZoomIn;
    VK_SUBTRACT, VK_OEM_MINUS: ZoomOut;
    VK_0, VK_NUMPAD0: ActualSize;
    VK_F, VK_MULTIPLY: FitToWindow;
    VK_LEFT: begin FOffset.X += step; clampOffset; Invalidate; end;
    VK_RIGHT: begin FOffset.X -= step; clampOffset; Invalidate; end;
    VK_UP: begin FOffset.Y += step; clampOffset; Invalidate; end;
    VK_DOWN: begin FOffset.Y -= step; clampOffset; Invalidate; end;
  else
    exit;
  end;
  Key := 0;
end;

// -- properties ----------------------

procedure TImageViewer.setPicture(value: TPicture);
begin
  FPicture.Assign(value);
end;

procedure TImageViewer.setZoom(value: double);
begin
  value := EnsureRange(value, FMinZoom, FMaxZoom);
  if SameValue(FZoom, value) and (FFitMode = fmNone) then exit;
  FZoom := value;
  FFitMode := fmNone;
  clampOffset;
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnZoomChanged) then FOnZoomChanged(self, FZoom);
end;

procedure TImageViewer.setFitMode(value: TImageFitMode);
begin
  if FFitMode = value then exit;
  FFitMode := value;
  FOffset := Point(0, 0);
  Invalidate;
  if not (csLoading in ComponentState) and Assigned(FOnZoomChanged) then FOnZoomChanged(self, effectiveZoom);
end;

function TImageViewer.getLimit(index: integer): double;
begin
  match index of
    0: result := FMinZoom;
    1: result := FMaxZoom;
    _: result := FZoomStep;
  end;
end;

procedure TImageViewer.setLimit(index: integer; value: double);
begin
  match index of
    0: FMinZoom := Max(value, 0.01);
    1: FMaxZoom := Max(value, FMinZoom);
    _: FZoomStep := Max(value, 1.01);
  end;
  if FFitMode = fmNone then setZoom(FZoom);
end;

function TImageViewer.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FCheckerboard;
    1: result := FWheelZooms;
    2: result := FDragPans;
    3: result := FSmooth;
    _: result := FShowBorder;
  end;
end;

procedure TImageViewer.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FCheckerboard := value;
    1: FWheelZooms := value;
    2: FDragPans := value;
    3: FSmooth := value;
    _: FShowBorder := value;
  end;
  Invalidate;
end;

function TImageViewer.getPartColor(index: integer): TColor;
begin
  result := if index = 0 then FBackColor else FBorderColor;
end;

procedure TImageViewer.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  if index = 0 then FBackColor := value else FBorderColor := value;
  Invalidate;
end;

end.
