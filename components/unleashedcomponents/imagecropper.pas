{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ImageCropper;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  TCropHandle = (chNone, chInside, chLeft, chTop, chRight, chBottom, chTopLeft, chTopRight, chBottomLeft, chBottomRight);
  // the frame: a rectangle or an ellipse
  TCropShape = (csRectangle, csEllipse);
  TCropChangeEvent = procedure(Sender: TObject; const cropRect: TRect) of object;

  { TImageCropper }

  // a picture with a crop frame over it: the frame moves and resizes by
  // its edges and corners, keeps a ratio when asked, the rest is dimmed.
  // Rotate and flip turn the picture itself; Crop hands back the cut
  TImageCropper = class(TCustomControl)
  private
    FPicture: TPicture;
    FBitmap: TBitmap; // the picture as shown, after rotation and flips
    FCrop: TRect; // in picture pixels
    FScale: double;
    FOrigin: TPoint; // where the picture starts on the control
    FRatio: double; // width to height, 0 free
    FShape: TCropShape;
    FHandleSize, FMinCrop, FPadding, FGridLines, FBorderWidth: integer;
    FShowGrid, FShowSize, FDimOutside, FDarkCheckers: boolean;
    FFrameColor, FDimColor, FHandleColor, FBackColor, FTextColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FCropSmoothing: TShapeAntialiasing;
    FDrag: TCropHandle;
    FDragStart: TPoint;
    FDragCrop: TRect;
    FHot: TCropHandle;
    FOnChange: TCropChangeEvent;
    procedure setPicture(value: TPicture);
    procedure pictureChanged(Sender: TObject);
    procedure setCropRect(const value: TRect);
    procedure setRatio(value: double);
    procedure setShape(value: TCropShape);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setCropSmoothing(value: TShapeAntialiasing);
    procedure rebuild;
    procedure fit;
    function toControl(const r: TRect): TRect;
    function toPicture(p: TPoint): TPoint;
    function handleAt(x, y: integer): TCropHandle;
    function handleRect(h: TCropHandle; const frame: TRect): TRect;
    procedure clampCrop(var r: TRect; fixed: TCropHandle);
    procedure changed;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Resize; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const fileName: string);
    // the cut as a new bitmap the caller owns
    function Crop: TBitmap;
    // the cut drawn into a bitmap of a size, scaled to fill it
    procedure CropTo(target: TBitmap; width, height: integer);
    procedure RotateRight;
    procedure RotateLeft;
    procedure FlipHorizontal;
    procedure FlipVertical;
    // the frame back to the whole picture
    procedure Reset;
    // the frame centered at a size
    procedure SetCropSize(width, height: integer);
    // the crop in picture pixels
    property CropRect: TRect read FCrop write setCropRect;
    property Bitmap: TBitmap read FBitmap;
  published
    property Picture: TPicture read FPicture write setPicture;
    // width to height of the frame, 0 for free; 1 is a square
    property Ratio: double read FRatio write setRatio;
    property Shape: TCropShape read FShape write setShape default csRectangle;
    property HandleSize: integer index 0 read getMetric write setMetric default 8;
    property MinCrop: integer index 1 read getMetric write setMetric default 16;
    property Padding: integer index 2 read getMetric write setMetric default 12;
    // the thirds inside the frame; 0 for none
    property GridLines: integer index 3 read getMetric write setMetric default 2;
    property BorderWidth: integer index 4 read getMetric write setMetric default 1;
    property ShowGrid: boolean index 0 read getFlag write setFlag default true;
    // the size of the crop in a corner of the frame
    property ShowSize: boolean index 1 read getFlag write setFlag default true;
    property DimOutside: boolean index 2 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property FrameColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property DimColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property HandleColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // how the edge of an elliptic cut blends into transparency: not at all,
    // or by the share of each pixel inside the ellipse in 4, 9 or 64 steps
    property CropSmoothing: TShapeAntialiasing read FCropSmoothing write setCropSmoothing default aaHigh;
    property OnChange: TCropChangeEvent read FOnChange write FOnChange;
    property Align;
    property Anchors;
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
  Math, IntfGraphics, FPImage;

constructor TImageCropper.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FPicture := TPicture.Create;
  FPicture.OnChange := @pictureChanged;
  FBitmap := TBitmap.Create;
  FHandleSize := 8;
  FMinCrop := 16;
  FPadding := 12;
  FGridLines := 2;
  FBorderWidth := 1;
  FShowGrid := true;
  FShowSize := true;
  FDimOutside := true;
  FFrameColor := clDefault;
  FDimColor := clDefault;
  FHandleColor := clDefault;
  FBackColor := clDefault;
  FTextColor := clDefault;
  FAntialiasing := asTheme;
  FScale := 1;
  TabStop := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TImageCropper.Destroy;
begin
  FPicture.Free;
  FBitmap.Free;
  inherited Destroy;
end;

class function TImageCropper.GetControlClassDefaultSize: TSize;
begin
  result.cx := 320;
  result.cy := 240;
end;

// -- the picture ----------------------

procedure TImageCropper.LoadFromFile(const fileName: string);
begin
  FPicture.LoadFromFile(fileName);
end;

procedure TImageCropper.pictureChanged(Sender: TObject);
begin
  FBitmap.PixelFormat := pf32bit;
  FBitmap.SetSize(FPicture.Width, FPicture.Height);
  if (FPicture.Width > 0) and (FPicture.Height > 0) then begin
    FBitmap.Canvas.Brush.Color := clWhite;
    FBitmap.Canvas.FillRect(0, 0, FBitmap.Width, FBitmap.Height);
    FBitmap.Canvas.Draw(0, 0, FPicture.Graphic);
  end;
  Reset;
end;

procedure TImageCropper.rebuild;
begin
  fit;
  Invalidate;
end;

procedure TImageCropper.Reset;
begin
  FCrop := Rect(0, 0, FBitmap.Width, FBitmap.Height);
  if FRatio > 0 then clampCrop(FCrop, chNone);
  rebuild;
  changed;
end;

procedure TImageCropper.SetCropSize(width, height: integer);
begin
  width := EnsureRange(width, 1, Max(FBitmap.Width, 1));
  height := EnsureRange(height, 1, Max(FBitmap.Height, 1));
  var r := Rect((FBitmap.Width-width) div 2, (FBitmap.Height-height) div 2, 0, 0);
  r.Right := r.Left+width;
  r.Bottom := r.Top+height;
  setCropRect(r);
end;

// the picture scaled to fit inside the padding, centered
procedure TImageCropper.fit;
begin
  var pad := scaled(self, FPadding);
  var w := Max(ClientWidth-2*pad, 1);
  var h := Max(ClientHeight-2*pad, 1);
  if (FBitmap.Width = 0) or (FBitmap.Height = 0) then begin
    FScale := 1;
    FOrigin := Point(pad, pad);
    exit;
  end;
  FScale := Min(w/FBitmap.Width, h/FBitmap.Height);
  FOrigin := Point(pad+Round((w-FBitmap.Width*FScale)/2), pad+Round((h-FBitmap.Height*FScale)/2));
end;

function TImageCropper.toControl(const r: TRect): TRect;
begin
  result.Left := FOrigin.X+Round(r.Left*FScale);
  result.Top := FOrigin.Y+Round(r.Top*FScale);
  result.Right := FOrigin.X+Round(r.Right*FScale);
  result.Bottom := FOrigin.Y+Round(r.Bottom*FScale);
end;

function TImageCropper.toPicture(p: TPoint): TPoint;
begin
  result.X := Round((p.X-FOrigin.X)/FScale);
  result.Y := Round((p.Y-FOrigin.Y)/FScale);
end;

// -- the crop ----------------------

// keeps the frame inside the picture, above the minimum and on the ratio;
// `fixed` names the handle that moved, so the opposite side stays put
procedure TImageCropper.clampCrop(var r: TRect; fixed: TCropHandle);
begin
  var pw := Max(FBitmap.Width, 1);
  var ph := Max(FBitmap.Height, 1);
  var minPx := Min(FMinCrop, Min(pw, ph));
  if r.Width < minPx then begin
    if fixed in [chLeft, chTopLeft, chBottomLeft] then r.Left := r.Right-minPx else r.Right := r.Left+minPx;
  end;
  if r.Height < minPx then begin
    if fixed in [chTop, chTopLeft, chTopRight] then r.Top := r.Bottom-minPx else r.Bottom := r.Top+minPx;
  end;
  if FRatio > 0 then begin
    // the side that was dragged leads, the other follows the ratio
    if fixed in [chLeft, chRight, chNone, chInside] then begin
      var h := Round(r.Width/FRatio);
      if fixed in [chNone, chInside] then begin
        if h > ph then begin h := ph; r.Right := r.Left+Round(h*FRatio); end;
        r.Top := Max(0, (r.Top+r.Bottom-h) div 2);
      end;
      r.Bottom := r.Top+h;
    end else if fixed in [chTop, chBottom] then begin
      var w := Round(r.Height*FRatio);
      r.Right := r.Left+w;
    end else begin
      // a corner: the larger change wins
      var w := r.Width;
      var h := Round(w/FRatio);
      if h > r.Height then begin h := r.Height; w := Round(h*FRatio); end;
      if fixed in [chTopLeft, chBottomLeft] then r.Left := r.Right-w else r.Right := r.Left+w;
      if fixed in [chTopLeft, chTopRight] then r.Top := r.Bottom-h else r.Bottom := r.Top+h;
    end;
  end;
  // inside the picture: a move slides, a resize shrinks
  if fixed = chInside then begin
    if r.Left < 0 then r.Offset(-r.Left, 0);
    if r.Top < 0 then r.Offset(0, -r.Top);
    if r.Right > pw then r.Offset(pw-r.Right, 0);
    if r.Bottom > ph then r.Offset(0, ph-r.Bottom);
  end else begin
    if r.Left < 0 then r.Left := 0;
    if r.Top < 0 then r.Top := 0;
    if r.Right > pw then r.Right := pw;
    if r.Bottom > ph then r.Bottom := ph;
    if FRatio > 0 then begin
      // the clip may have broken the ratio: shrink to it again
      var w := r.Width;
      var h := Round(w/FRatio);
      if h > r.Height then begin h := r.Height; w := Round(h*FRatio); end;
      if fixed in [chLeft, chTopLeft, chBottomLeft] then r.Left := r.Right-w else r.Right := r.Left+w;
      if fixed in [chTop, chTopLeft, chTopRight] then r.Top := r.Bottom-h else r.Bottom := r.Top+h;
    end;
  end;
end;

procedure TImageCropper.setCropRect(const value: TRect);
begin
  var r := value;
  clampCrop(r, chNone);
  if r = FCrop then exit;
  FCrop := r;
  Invalidate;
  changed;
end;

procedure TImageCropper.changed;
begin
  if Assigned(FOnChange) and not (csLoading in ComponentState) then FOnChange(self, FCrop);
end;

function TImageCropper.Crop: TBitmap;
begin
  result := TBitmap.Create;
  result.PixelFormat := pf32bit;
  result.SetSize(Max(FCrop.Width, 1), Max(FCrop.Height, 1));
  if (FBitmap.Width = 0) or (FBitmap.Height = 0) then exit;
  result.Canvas.CopyRect(Rect(0, 0, result.Width, result.Height), FBitmap.Canvas, FCrop);
  if FShape = csEllipse then begin
    // the corners outside the ellipse turn transparent; a pixel on the edge
    // keeps the share of its area inside the ellipse as its alpha
    var img := TLazIntfImage.Create(0, 0);
    try
      img.LoadFromBitmap(result.Handle, result.MaskHandle);
      var cx := result.Width/2;
      var cy := result.Height/2;
      var steps := match FCropSmoothing of
        aaOff: 1;
        aaLow: 2;
        aaMedium: 3;
      else
        8
      end;
      var clear := FPColor(0, 0, 0, 0);
      for var y := 0 to result.Height-1 do
        for var x := 0 to result.Width-1 do begin
          // the pixel is wholly in or out when its nearest and farthest
          // corners agree; only the rest is sampled
          var dx := Max(Abs(x+0.5-cx)-0.5, 0)/cx;
          var dy := Max(Abs(y+0.5-cy)-0.5, 0)/cy;
          if dx*dx+dy*dy >= 1 then begin
            img.Colors[x, y] := clear;
            continue;
          end;
          dx := (Abs(x+0.5-cx)+0.5)/cx;
          dy := (Abs(y+0.5-cy)+0.5)/cy;
          if dx*dx+dy*dy <= 1 then continue;
          var inside := 0;
          for var sy := 0 to steps-1 do
            for var sx := 0 to steps-1 do
              if Sqr((x+(sx+0.5)/steps-cx)/cx)+Sqr((y+(sy+0.5)/steps-cy)/cy) <= 1 then inc(inside);
          if inside = 0 then img.Colors[x, y] := clear
          else if inside < steps*steps then begin
            var c := img.Colors[x, y];
            c.Alpha := Round(c.Alpha*inside/(steps*steps));
            img.Colors[x, y] := c;
          end;
        end;
      result.LoadFromIntfImage(img);
    finally
      img.Free;
    end;
  end;
end;

procedure TImageCropper.CropTo(target: TBitmap; width, height: integer);
begin
  var cut := autofree Crop;
  target.PixelFormat := pf32bit;
  target.SetSize(width, height);
  target.Canvas.StretchDraw(Rect(0, 0, width, height), cut);
end;

// -- turning ----------------------

procedure turn(bitmap: TBitmap; quarterTurns: integer; flipX, flipY: boolean);
begin
  if (bitmap.Width = 0) or (bitmap.Height = 0) then exit;
  var src := TLazIntfImage.Create(0, 0);
  var dst := TLazIntfImage.Create(0, 0);
  try
    src.LoadFromBitmap(bitmap.Handle, bitmap.MaskHandle);
    var w := src.Width;
    var h := src.Height;
    var swap := quarterTurns mod 2 = 1;
    dst.DataDescription := src.DataDescription;
    dst.SetSize(if swap then h else w, if swap then w else h);
    for var y := 0 to h-1 do
      for var x := 0 to w-1 do begin
        var sx := if flipX then w-1-x else x;
        var sy := if flipY then h-1-y else y;
        var tx, ty: integer;
        match quarterTurns mod 4 of
          1: begin tx := h-1-sy; ty := sx; end;
          2: begin tx := w-1-sx; ty := h-1-sy; end;
          3: begin tx := sy; ty := w-1-sx; end;
        else
          begin tx := sx; ty := sy; end;
        end;
        dst.Colors[tx, ty] := src.Colors[x, y];
      end;
    bitmap.LoadFromIntfImage(dst);
  finally
    src.Free;
    dst.Free;
  end;
end;

procedure TImageCropper.RotateRight;
begin
  turn(FBitmap, 1, false, false);
  Reset;
end;

procedure TImageCropper.RotateLeft;
begin
  turn(FBitmap, 3, false, false);
  Reset;
end;

procedure TImageCropper.FlipHorizontal;
begin
  turn(FBitmap, 0, true, false);
  var r := FCrop;
  r.Left := FBitmap.Width-FCrop.Right;
  r.Right := FBitmap.Width-FCrop.Left;
  FCrop := r;
  rebuild;
  changed;
end;

procedure TImageCropper.FlipVertical;
begin
  turn(FBitmap, 0, false, true);
  var r := FCrop;
  r.Top := FBitmap.Height-FCrop.Bottom;
  r.Bottom := FBitmap.Height-FCrop.Top;
  FCrop := r;
  rebuild;
  changed;
end;

// -- handles ----------------------

function TImageCropper.handleRect(h: TCropHandle; const frame: TRect): TRect;
begin
  var s := scaled(self, FHandleSize);
  var cx := (frame.Left+frame.Right) div 2;
  var cy := (frame.Top+frame.Bottom) div 2;
  var p: TPoint;
  match h of
    chTopLeft: p := frame.TopLeft;
    chTopRight: p := Point(frame.Right, frame.Top);
    chBottomLeft: p := Point(frame.Left, frame.Bottom);
    chBottomRight: p := frame.BottomRight;
    chLeft: p := Point(frame.Left, cy);
    chRight: p := Point(frame.Right, cy);
    chTop: p := Point(cx, frame.Top);
    chBottom: p := Point(cx, frame.Bottom);
  else
    p := Point(cx, cy);
  end;
  result := Rect(p.X-s div 2, p.Y-s div 2, p.X+s div 2+1, p.Y+s div 2+1);
end;

function TImageCropper.handleAt(x, y: integer): TCropHandle;
begin
  var frame := toControl(FCrop);
  var p := Point(x, y);
  for var h in [chTopLeft, chTopRight, chBottomLeft, chBottomRight, chLeft, chRight, chTop, chBottom] do begin
    var r := handleRect(h, frame);
    r.Inflate(2, 2);
    if PtInRect(r, p) then exit(h);
  end;
  result := if PtInRect(frame, p) then chInside else chNone;
end;

// -- painting ----------------------

// the pixels of a rectangle moved halfway to a color, in the memory of the painter
procedure veil(sp: TSmoothPaint; const r: TRect; color: TColor);
begin
  var area := sp.Area;
  var x0 := Max(r.Left, area.Left);
  var x1 := Min(r.Right, area.Right);
  if x1 <= x0 then exit;
  var tone := TSmoothPaint.PackColor(color);
  var vr := (tone shr 16) and $FF;
  var vg := (tone shr 8) and $FF;
  var vb := tone and $FF;
  for var y := Max(r.Top, area.Top) to Min(r.Bottom, area.Bottom)-1 do begin
    var row := sp.Row(y);
    if row = nil then begin
      // a direct painter has no memory: a plain fill stands in
      sp.FillRect(Rect(x0, y, x1, y+1), color);
      continue;
    end;
    for var x := x0 to x1-1 do begin
      var px := row[x-area.Left];
      var pr := (px shr 16) and $FF;
      var pg := (px shr 8) and $FF;
      var pb := px and $FF;
      row[x-area.Left] := $FF000000 or (((pr+vr) shr 1) shl 16) or (((pg+vg) shr 1) shl 8) or ((pb+vb) shr 1);
    end;
  end;
end;

procedure TImageCropper.Paint;
begin
  var back := pick(FBackColor, blend(clBtnFace, clBlack, 20));
  var frameColor := pick(FFrameColor, clWhite);
  var dim := pick(FDimColor, clBlack);
  var handleColor := pick(FHandleColor, clWhite);
  var text := pick(FTextColor, clWhite);
  fit;
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  var hasPicture := (FBitmap.Width > 0) and (FBitmap.Height > 0);
  var pic := toControl(Rect(0, 0, FBitmap.Width, FBitmap.Height));
  if hasPicture then sp.DrawImage(FBitmap, Rect(0, 0, FBitmap.Width, FBitmap.Height), pic);
  var frame := toControl(FCrop);
  if hasPicture then begin
    if FDimOutside then begin
      // the picture outside the frame under a veil, blended pixel by pixel
      veil(sp, Rect(pic.Left, pic.Top, pic.Right, frame.Top), dim);
      veil(sp, Rect(pic.Left, frame.Bottom, pic.Right, pic.Bottom), dim);
      veil(sp, Rect(pic.Left, frame.Top, frame.Left, frame.Bottom), dim);
      veil(sp, Rect(frame.Right, frame.Top, pic.Right, frame.Bottom), dim);
      if FShape = csEllipse then begin
        // inside the frame the corners outside the ellipse are veiled too
        var cx := (frame.Left+frame.Right)/2;
        var cy := (frame.Top+frame.Bottom)/2;
        var rx := frame.Width/2;
        var ry := frame.Height/2;
        for var y := frame.Top to frame.Bottom-1 do begin
          var dy := (y+0.5-cy)/Max(ry, 0.5);
          var inside := 1-dy*dy;
          var half := if inside > 0 then Sqrt(inside)*rx else 0;
          veil(sp, Rect(frame.Left, y, Round(cx-half), y+1), dim);
          veil(sp, Rect(Round(cx+half), y, frame.Right, y+1), dim);
        end;
      end;
    end;
    var bw := Max(scaled(self, FBorderWidth), 1);
    if FShape = csEllipse then sp.FrameEllipse((frame.Left+frame.Right)/2, (frame.Top+frame.Bottom)/2, frame.Width/2, frame.Height/2, bw, frameColor)
    else sp.FrameRoundRect(frame.Left, frame.Top, frame.Right, frame.Bottom, 0, bw, frameColor);
    if FShowGrid and (FGridLines > 0) then
      for var k := 1 to FGridLines do begin
        var gx := frame.Left+Round(frame.Width*k/(FGridLines+1));
        var gy := frame.Top+Round(frame.Height*k/(FGridLines+1));
        sp.FillRect(Rect(gx, frame.Top, gx+1, frame.Bottom), blend(frameColor, dim, 50));
        sp.FillRect(Rect(frame.Left, gy, frame.Right, gy+1), blend(frameColor, dim, 50));
      end;
    for var h in [chTopLeft, chTopRight, chBottomLeft, chBottomRight, chLeft, chRight, chTop, chBottom] do begin
      var r := handleRect(h, frame);
      paintRoundRect(sp, r, 1, (if h = FHot then ColorToRGB(clHighlight) else handleColor), dim, 1);
    end;
  end;
  sp.Flush;
  if hasPicture and FShowSize then begin
    applyTextQuality(Canvas);
    var s := Format('%d x %d', [FCrop.Width, FCrop.Height]);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := blend(dim, back, 30);
    var w := Canvas.TextWidth(s)+scaled(self, 8);
    var h := Canvas.TextHeight(s)+scaled(self, 4);
    var x := Min(frame.Left+scaled(self, 4), ClientWidth-w);
    var y := frame.Bottom+scaled(self, 4);
    if y+h > ClientHeight then y := frame.Top-h-scaled(self, 4);
    Canvas.FillRect(x, y, x+w, y+h);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := text;
    Canvas.TextOut(x+scaled(self, 4), y+scaled(self, 2), s);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TImageCropper.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if (Button <> mbLeft) or (FBitmap.Width = 0) then exit;
  FDrag := handleAt(X, Y);
  if FDrag = chNone then begin
    // a drag outside starts a new frame from that point
    var p := toPicture(Point(X, Y));
    if (p.X < 0) or (p.Y < 0) or (p.X > FBitmap.Width) or (p.Y > FBitmap.Height) then exit;
    FCrop := Rect(p.X, p.Y, p.X, p.Y);
    FDrag := chBottomRight;
  end;
  FDragStart := Point(X, Y);
  FDragCrop := FCrop;
end;

procedure TImageCropper.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDrag = chNone then begin
    var hot := handleAt(X, Y);
    if hot <> FHot then begin
      FHot := hot;
      Cursor := match hot of
        chInside: crSizeAll;
        chLeft, chRight: crSizeWE;
        chTop, chBottom: crSizeNS;
        chTopLeft, chBottomRight: crSizeNWSE;
        chTopRight, chBottomLeft: crSizeNESW;
      else
        crCross
      end;
      Invalidate;
    end;
    exit;
  end;
  var dx := Round((X-FDragStart.X)/FScale);
  var dy := Round((Y-FDragStart.Y)/FScale);
  var r := FDragCrop;
  match FDrag of
    chInside: r.Offset(dx, dy);
    chLeft: r.Left += dx;
    chRight: r.Right += dx;
    chTop: r.Top += dy;
    chBottom: r.Bottom += dy;
    chTopLeft: begin r.Left += dx; r.Top += dy; end;
    chTopRight: begin r.Right += dx; r.Top += dy; end;
    chBottomLeft: begin r.Left += dx; r.Bottom += dy; end;
    chBottomRight: begin r.Right += dx; r.Bottom += dy; end;
  end;
  // a side dragged past the other flips the handle
  if r.Right < r.Left then begin var t := r.Left; r.Left := r.Right; r.Right := t; end;
  if r.Bottom < r.Top then begin var t := r.Top; r.Top := r.Bottom; r.Bottom := t; end;
  clampCrop(r, FDrag);
  if r = FCrop then exit;
  FCrop := r;
  Invalidate;
  changed;
end;

procedure TImageCropper.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDrag := chNone;
end;

procedure TImageCropper.MouseLeave;
begin
  inherited MouseLeave;
  if FHot = chNone then exit;
  FHot := chNone;
  Invalidate;
end;

procedure TImageCropper.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var step := if ssShift in Shift then 10 else 1;
  var r := FCrop;
  match Key of
    VK_LEFT: r.Offset(-step, 0);
    VK_RIGHT: r.Offset(step, 0);
    VK_UP: r.Offset(0, -step);
    VK_DOWN: r.Offset(0, step);
    VK_ADD, VK_OEM_PLUS: r.Inflate(step, step);
    VK_SUBTRACT, VK_OEM_MINUS: r.Inflate(-step, -step);
    VK_R: if ssCtrl in Shift then begin RotateRight; Key := 0; exit; end else exit;
    VK_HOME: begin Reset; Key := 0; exit; end;
  else
    exit;
  end;
  Key := 0;
  clampCrop(r, (if Key = 0 then chInside else chNone));
  setCropRect(r);
end;

procedure TImageCropper.Resize;
begin
  inherited Resize;
  fit;
  Invalidate;
end;

// -- properties ----------------------

procedure TImageCropper.setPicture(value: TPicture);
begin
  FPicture.Assign(value);
end;

procedure TImageCropper.setRatio(value: double);
begin
  if value < 0 then value := 0;
  if FRatio = value then exit;
  FRatio := value;
  var r := FCrop;
  clampCrop(r, chNone);
  FCrop := r;
  Invalidate;
  changed;
end;

procedure TImageCropper.setShape(value: TCropShape);
begin
  if FShape = value then exit;
  FShape := value;
  Invalidate;
end;

function TImageCropper.getMetric(index: integer): integer;
begin
  result := match index of
    0: FHandleSize;
    1: FMinCrop;
    2: FPadding;
    3: FGridLines;
  else
    FBorderWidth
  end;
end;

procedure TImageCropper.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index in [0, 1] then value := Max(value, 1);
  if getMetric(index) = value then exit;
  match index of
    0: FHandleSize := value;
    1: FMinCrop := value;
    2: FPadding := value;
    3: FGridLines := value;
  else
    FBorderWidth := value;
  end;
  rebuild;
end;

function TImageCropper.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowGrid;
    1: FShowSize;
  else
    FDimOutside
  end;
end;

procedure TImageCropper.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowGrid := value;
    1: FShowSize := value;
  else
    FDimOutside := value;
  end;
  Invalidate;
end;

function TImageCropper.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FFrameColor;
    1: FDimColor;
    2: FHandleColor;
    3: FBackColor;
  else
    FTextColor
  end;
end;

procedure TImageCropper.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FFrameColor := value;
    1: FDimColor := value;
    2: FHandleColor := value;
    3: FBackColor := value;
  else
    FTextColor := value;
  end;
  Invalidate;
end;

procedure TImageCropper.setCropSmoothing(value: TShapeAntialiasing);
begin
  FCropSmoothing := value;
end;

procedure TImageCropper.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
