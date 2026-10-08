{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Avatar;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  // the outline of the picture: a circle, a square rounded by CornerRadius,
  // a square, a hexagon, a diamond, a squircle, a shield
  TAvatarShape = (asCircle, asRounded, asSquare, asHexagon, asDiamond, asSquircle, asShield);
  TAvatarStatus = (stNone, stOnline, stAway, stBusy, stOffline);

  { TAvatar }

  // a picture of a person cut to a circle or a rounded square, or the
  // initials of the name on a color the name picks, with a dot for the
  // presence
  TAvatar = class(TGraphicControl)
  private
    FUserName, FInitials: string;
    FPicture: TPicture;
    FShape: TAvatarShape;
    FStatus: TAvatarStatus;
    FCornerRadius, FBorderWidth: integer;
    FAvatarColor, FTextColor, FBorderColor, FStatusColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnDraw: TCustomDrawEvent;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setPicture(value: TPicture);
    procedure pictureChanged(Sender: TObject);
    procedure setShape(value: TAvatarShape);
    procedure setStatus(value: TAvatarStatus);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function hasPicture: boolean;
  protected
    procedure Paint; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the letters shown without a picture: Initials, or the first letters
    // of the first and the last word of the name
    function ShownInitials: string;
    // the color a name picks from the palette; the same name, the same color
    class function ColorOfName(const name: string): TColor;
  published
    property UserName: string index 0 read getText write setText;
    // the letters instead of the ones the name gives
    property Initials: string index 1 read getText write setText;
    // fills the shape, cut to it; without one the initials show
    property Picture: TPicture read FPicture write setPicture;
    property Shape: TAvatarShape read FShape write setShape default asCircle;
    property Status: TAvatarStatus read FStatus write setStatus default stNone;
    property CornerRadius: integer index 0 read getMetric write setMetric default 8;
    // a ring around the avatar
    property BorderWidth: integer index 1 read getMetric write setMetric default 0;
    // clDefault takes the color the name picks, the contrasting text and the
    // colors of the presence
    property AvatarColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property StatusColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints the whole avatar by itself, in the square it fills
    property OnDraw: TCustomDrawEvent read FOnDraw write FOnDraw;
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Constraints;
    property Cursor;
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
  Math, LazUTF8;

const
  PALETTE: array[0..11] of TColor = ($7373E5, $9262F0, $C868BA, $CD7595, $CB8679, $F6B564, $F7C34F, $E1D04D, $ACB64D, $84C781, $4DB7FF, $7F88A1);

constructor TAvatar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque];
  FPicture := TPicture.Create;
  FPicture.OnChange := @pictureChanged;
  FCornerRadius := 8;
  FAvatarColor := clDefault;
  FTextColor := clDefault;
  FBorderColor := clDefault;
  FStatusColor := clDefault;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TAvatar.Destroy;
begin
  FPicture.Free;
  inherited Destroy;
end;

class function TAvatar.GetControlClassDefaultSize: TSize;
begin
  result.cx := 40;
  result.cy := 40;
end;

function TAvatar.ShownInitials: string;
begin
  if FInitials <> '' then exit(FInitials);
  var words := FUserName.Split([' ', '.', '-', '_', #9], TStringSplitOptions.ExcludeEmpty);
  if length(words) = 0 then exit('');
  result := UTF8Copy(words[0], 1, 1);
  if length(words) > 1 then result += UTF8Copy(words[length(words)-1], 1, 1);
  result := UTF8UpperCase(result);
end;

class function TAvatar.ColorOfName(const name: string): TColor;
begin
  var hash: cardinal := 0;
  for var ch in UTF8LowerCase(name) do hash := (hash*31+ord(ch)) and $FFFFFF;
  result := PALETTE[hash mod length(PALETTE)];
end;

function TAvatar.hasPicture: boolean;
begin
  result := (FPicture.Graphic <> nil) and not FPicture.Graphic.Empty;
end;

// -- painting ----------------------

procedure TAvatar.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var fill := pick(FAvatarColor, ColorOfName(FUserName));
  if not Enabled then fill := blend(fill, clBtnFace, 60);
  var size := Min(ClientWidth, ClientHeight);
  if size < 4 then exit;
  var box := Rect((ClientWidth-size) div 2, (ClientHeight-size) div 2, (ClientWidth-size) div 2+size, (ClientHeight-size) div 2+size);
  var ring := scaled(self, FBorderWidth);
  var face := box;
  face.Inflate(-ring, -ring);
  var radius := match FShape of
    asCircle: face.Width div 2;
    asRounded: Min(scaled(self, FCornerRadius), face.Width div 2);
  else
    0
  end;
  if customDraw(self, Canvas, FOnDraw, box, 0, (if Enabled then [] else [dsDisabled]), back, FAntialiasing) then exit;
  // the outline of a shape that is no rectangle, in a box
  var outlineOf := function(const b: TRect; reverse: boolean): TOutline
  begin
    var cx := (b.Left+b.Right)/2;
    var cy := (b.Top+b.Bottom)/2;
    var rad := b.Width/2;
    match FShape of
      asHexagon: result := polygonOutline(cx, cy, rad, 6, 30);
      asDiamond: result := polygonOutline(cx, cy, rad, 4, 90);
      asSquircle: begin
        // a superellipse: the corners of a square, rounded off softly
        SetLength(result, 64);
        for var i := 0 to 63 do begin
          var a := i*2*pi/64;
          result[i] := PointF(cx+rad*Sign(cos(a))*power(Abs(cos(a)), 0.5), cy+rad*Sign(sin(a))*power(Abs(sin(a)), 0.5));
        end;
      end;
    else
      // a shield: flat shoulders, a point at the bottom
      result := [PointF(b.Left, b.Top), PointF(b.Right, b.Top), PointF(b.Right, cy), PointF(cx, b.Bottom), PointF(b.Left, cy)];
    end;
    if reverse then
      for var i := 0 to length(result) div 2-1 do begin
        var p := result[i];
        result[i] := result[high(result)-i];
        result[high(result)-i] := p;
      end;
  end;
  var polygonal := FShape in [asHexagon, asDiamond, asSquircle, asShield];
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  if ring > 0 then
    if polygonal then sp.FillPolygon(outlineOf(box, false), pick(FBorderColor, clHighlight))
    else paintRoundRect(sp, box, (if radius > 0 then radius+ring else 0), pick(FBorderColor, clHighlight), clNone);
  if hasPicture then begin
    // the middle of the picture in the proportions of the face covers it,
    // then the corners outside the shape take the ring or the background
    var g := FPicture.Graphic;
    var src := autofree TBitmap.Create;
    src.SetSize(Max(g.Width, 1), Max(g.Height, 1));
    src.Canvas.Brush.Color := fill;
    src.Canvas.FillRect(0, 0, src.Width, src.Height);
    src.Canvas.Draw(0, 0, g);
    var part := Rect(0, 0, src.Width, src.Height);
    if src.Width*face.Height > src.Height*face.Width then begin
      var w := src.Height*face.Width div Max(face.Height, 1);
      part := Rect((src.Width-w) div 2, 0, (src.Width-w) div 2+w, src.Height);
    end else begin
      var h := src.Width*face.Height div Max(face.Width, 1);
      part := Rect(0, (src.Height-h) div 2, src.Width, (src.Height-h) div 2+h);
    end;
    sp.DrawImage(src, part, face);
    if (radius > 0) or polygonal then begin
      var frame: TOutline := [PointF(face.Left, face.Top), PointF(face.Right, face.Top), PointF(face.Right, face.Bottom), PointF(face.Left, face.Bottom)];
      // the shape runs the other way, so it cuts a hole in the frame
      var shape := if polygonal then outlineOf(face, true)
        else if FShape = asCircle then ellipseOutline((face.Left+face.Right)/2, (face.Top+face.Bottom)/2, face.Width/2, face.Height/2, true)
        else roundRectOutline(face.Left, face.Top, face.Right, face.Bottom, radius, true);
      sp.FillOutlines([frame, shape], if ring > 0 then pick(FBorderColor, clHighlight) else back);
    end;
  end else if polygonal then sp.FillPolygon(outlineOf(face, false), fill)
  else paintRoundRect(sp, face, radius, fill, clNone);

  // the presence dot sits on the edge at the bottom right, in a ring of
  // the background
  if FStatus <> stNone then begin
    var dot := pick(FStatusColor, match FStatus of
      stOnline: RGBToColor(67, 160, 71);
      stAway: RGBToColor(255, 179, 0);
      stBusy: RGBToColor(229, 57, 53);
    else
      RGBToColor(158, 158, 158)
    end);
    var dr := Max(size*14 div 100, 3);
    var cx, cy: integer;
    if FShape = asCircle then begin
      var off := Round((size/2)*0.7071);
      cx := box.Left+size div 2+off;
      cy := box.Top+size div 2+off;
    end else begin
      cx := box.Right-dr;
      cy := box.Bottom-dr;
    end;
    cx := Min(cx, ClientWidth-dr-1);
    cy := Min(cy, ClientHeight-dr-1);
    paintCircle(sp, cx, cy, dr+Max(size div 20, 2), back, clNone);
    paintCircle(sp, cx, cy, dr, dot, clNone);
    // away shows a moon cut, busy a bar, offline a hollow middle
    match FStatus of
      stBusy: paintLine(sp, cx-dr div 2, cy, cx+dr div 2, cy, back, Max(dr div 3, 1));
      stOffline: paintCircle(sp, cx, cy, dr div 2, back, clNone);
    else
      ;
    end;
  end;
  sp.Flush;

  if not hasPicture then begin
    var letters := ShownInitials;
    if letters <> '' then begin
      applyTextQuality(Canvas);
      Canvas.Font := Font;
      Canvas.Font.Style := Font.Style+[fsBold];
      Canvas.Font.Height := -Max(face.Height*40 div 100, 6);
      paintCenteredText(Canvas, face, letters, pick(FTextColor, contrastText(fill)));
      Canvas.Font := Font;
    end;
  end;
end;

// -- properties ----------------------

function TAvatar.getText(index: integer): string;
begin
  result := if index = 0 then FUserName else FInitials;
end;

procedure TAvatar.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  if index = 0 then FUserName := value else FInitials := value;
  Invalidate;
end;

procedure TAvatar.setPicture(value: TPicture);
begin
  FPicture.Assign(value);
end;

procedure TAvatar.pictureChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TAvatar.setShape(value: TAvatarShape);
begin
  if FShape = value then exit;
  FShape := value;
  Invalidate;
end;

procedure TAvatar.setStatus(value: TAvatarStatus);
begin
  if FStatus = value then exit;
  FStatus := value;
  Invalidate;
end;

function TAvatar.getMetric(index: integer): integer;
begin
  result := if index = 0 then FCornerRadius else FBorderWidth;
end;

procedure TAvatar.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FCornerRadius := value else FBorderWidth := value;
  Invalidate;
end;

function TAvatar.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FAvatarColor;
    1: FTextColor;
    2: FBorderColor;
  else
    FStatusColor
  end;
end;

procedure TAvatar.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FAvatarColor := value;
    1: FTextColor := value;
    2: FBorderColor := value;
  else
    FStatusColor := value;
  end;
  Invalidate;
end;

procedure TAvatar.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
