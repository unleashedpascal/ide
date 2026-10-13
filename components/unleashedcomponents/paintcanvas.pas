{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PaintCanvas;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, LCLType, ControlPaint;

type
  TPaintTool = (ptPen, ptLine, ptArrow, ptRectangle, ptEllipse, ptText, ptHighlighter, ptEraser);
  TPaintStrokeEvent = procedure(Sender: TObject; index: integer) of object;

  { TPaintCanvas }

  // a surface to draw on: a pen, lines, arrows, rectangles, ellipses,
  // text and a highlighter, each stroke kept as a shape so undo takes it
  // back and the picture renders at any size. Over a background image it
  // annotates; on its own it sketches
  TPaintCanvas = class(TCustomControl)
  private
    type
      TStroke = record
        tool: TPaintTool;
        color: TColor;
        width: integer;
        points: array of TPoint;
        text: string;
      end;
    var
    FStrokes: array of TStroke;
    FUndone: array of TStroke;
    FTool: TPaintTool;
    FPenColor, FFillColor, FBackColor, FGridColor: TColor;
    FPenWidth, FGridSize: integer;
    FFilled, FShowGrid, FDrawing, FReadOnly, FAntialias: boolean;
    FCurrent: TStroke;
    FBackground: TPicture;
    FAntialiasing: TAntialiasSetting;
    FOnStroke: TPaintStrokeEvent;
    FOnChange: TNotifyEvent;
    FOnTextWanted: TPaintStrokeEvent;
    procedure setTool(value: TPaintTool);
    procedure setPenWidth(value: integer);
    procedure setGridSize(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setBackground(value: TPicture);
    procedure backgroundChanged(Sender: TObject);
    procedure paintStroke(sp: TSmoothPaint; const s: TStroke);
    procedure paintTexts(const strokes: array of TStroke);
    procedure changed;
    function getStrokeCount: integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Undo;
    procedure Redo;
    function CanUndo: boolean;
    function CanRedo: boolean;
    procedure Clear;
    // the last stroke goes
    procedure DeleteLast;
    // a text placed at a point, with the pen color and size
    procedure AddText(x, y: integer; const text: string);
    // the picture with every stroke, the background included, as a bitmap the caller owns
    function Render: TBitmap;
    procedure SaveToFile(const fileName: string);
    // the strokes as lines of "tool;color;width;x,y x,y ...;text", for a file
    procedure SaveStrokes(lines: TStrings);
    procedure LoadStrokes(lines: TStrings);
    property StrokeCount: integer read getStrokeCount;
  published
    property Tool: TPaintTool read FTool write setTool default ptPen;
    property PenColor: TColor index 0 read getPartColor write setPartColor default clRed;
    // the inside of rectangles and ellipses when Filled
    property FillColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property PenWidth: integer read FPenWidth write setPenWidth default 3;
    property GridSize: integer read FGridSize write setGridSize default 20;
    property Filled: boolean index 0 read getFlag write setFlag default false;
    property ShowGrid: boolean index 1 read getFlag write setFlag default false;
    property ReadOnly: boolean index 2 read getFlag write setFlag default false;
    // the picture under the strokes
    property Background: TPicture read FBackground write setBackground;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // a stroke ended
    property OnStroke: TPaintStrokeEvent read FOnStroke write FOnStroke;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    // the text tool clicked: the handler calls AddText with what to put there
    property OnTextWanted: TPaintStrokeEvent read FOnTextWanted write FOnTextWanted;
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
  Math;

constructor TPaintCanvas.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque]-[csSetCaption, csAcceptsControls];
  FPenColor := clRed;
  FFillColor := clDefault;
  FBackColor := clDefault;
  FGridColor := clDefault;
  FPenWidth := 3;
  FGridSize := 20;
  FAntialiasing := asTheme;
  FBackground := TPicture.Create;
  FBackground.OnChange := @backgroundChanged;
  TabStop := true;
  Cursor := crCross;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TPaintCanvas.Destroy;
begin
  FBackground.Free;
  inherited Destroy;
end;

class function TPaintCanvas.GetControlClassDefaultSize: TSize;
begin
  result.cx := 320;
  result.cy := 220;
end;

// -- strokes ----------------------

function TPaintCanvas.getStrokeCount: integer;
begin
  result := length(FStrokes);
end;

procedure TPaintCanvas.changed;
begin
  Invalidate;
  if Assigned(FOnChange) then FOnChange(self);
end;

procedure TPaintCanvas.Undo;
begin
  if length(FStrokes) = 0 then exit;
  FUndone := FUndone+[FStrokes[high(FStrokes)]];
  SetLength(FStrokes, length(FStrokes)-1);
  changed;
end;

procedure TPaintCanvas.Redo;
begin
  if length(FUndone) = 0 then exit;
  FStrokes := FStrokes+[FUndone[high(FUndone)]];
  SetLength(FUndone, length(FUndone)-1);
  changed;
end;

function TPaintCanvas.CanUndo: boolean;
begin
  result := length(FStrokes) > 0;
end;

function TPaintCanvas.CanRedo: boolean;
begin
  result := length(FUndone) > 0;
end;

procedure TPaintCanvas.Clear;
begin
  FStrokes := nil;
  FUndone := nil;
  changed;
end;

procedure TPaintCanvas.DeleteLast;
begin
  if length(FStrokes) = 0 then exit;
  SetLength(FStrokes, length(FStrokes)-1);
  changed;
end;

procedure TPaintCanvas.AddText(x, y: integer; const text: string);
begin
  if text = '' then exit;
  var s := Default(TStroke);
  s.tool := ptText;
  s.color := FPenColor;
  s.width := FPenWidth;
  s.points := [Point(x, y)];
  s.text := text;
  FStrokes := FStrokes+[s];
  FUndone := nil;
  changed;
  if Assigned(FOnStroke) then FOnStroke(self, high(FStrokes));
end;

procedure TPaintCanvas.SaveStrokes(lines: TStrings);
begin
  for var s in FStrokes do begin
    var pts := '';
    for var p in s.points do pts += Format('%d,%d ', [p.X, p.Y]);
    lines.Add(Format('%d;%s;%d;%s;%s', [ord(s.tool), ColorToString(s.color), s.width, Trim(pts), s.text]));
  end;
end;

procedure TPaintCanvas.LoadStrokes(lines: TStrings);
begin
  FStrokes := nil;
  FUndone := nil;
  for var i := 0 to lines.Count-1 do begin
    var parts := lines[i].Split([';'], 5);
    if length(parts) < 4 then continue;
    var s := Default(TStroke);
    s.tool := TPaintTool(EnsureRange(StrToIntDef(parts[0], 0), 0, ord(high(TPaintTool))));
    s.color := StringToColor(parts[1]);
    s.width := StrToIntDef(parts[2], 1);
    for var pair in parts[3].Split([' ']) do begin
      var comma := Pos(',', pair);
      if comma = 0 then continue;
      s.points := s.points+[Point(StrToIntDef(Copy(pair, 1, comma-1), 0), StrToIntDef(Copy(pair, comma+1, MaxInt), 0))];
    end;
    if length(parts) > 4 then s.text := parts[4];
    FStrokes := FStrokes+[s];
  end;
  changed;
end;

// -- painting ----------------------

procedure TPaintCanvas.paintStroke(sp: TSmoothPaint; const s: TStroke);
begin
  var n := length(s.points);
  if n = 0 then exit;
  var w := Max(s.width, 1);
  var color := ColorToRGB(s.color);
  var fill := pick(FFillColor, blend(color, pick(FBackColor, clWindow), 70));
  match s.tool of
    ptPen, ptEraser, ptHighlighter: begin
      var pts: array of TPointF;
      SetLength(pts, n);
      for var i := 0 to n-1 do pts[i] := PointF(s.points[i].X+0.5, s.points[i].Y+0.5);
      if s.tool = ptEraser then color := pick(FBackColor, clWindow)
      else if s.tool = ptHighlighter then begin
        color := blend(color, pick(FBackColor, clWindow), 55);
        w := w*4;
      end;
      if n = 1 then paintCircle(sp, s.points[0].X, s.points[0].Y, Max(w div 2, 1), color, clNone)
      else sp.StrokePolyline(pts, w, color, false, s.tool <> ptHighlighter);
    end;
    ptLine, ptArrow: begin
      var a := s.points[0];
      var b := s.points[n-1];
      paintLine(sp, a.X, a.Y, b.X, b.Y, color, w);
      if s.tool = ptArrow then begin
        // the head: two short strokes back from the tip
        var ang := ArcTan2(b.Y-a.Y, b.X-a.X);
        var len := Max(w*4, 10);
        var tip: array of TPointF := [
          PointF(b.X+0.5, b.Y+0.5),
          PointF(b.X-len*Cos(ang-0.5)+0.5, b.Y-len*Sin(ang-0.5)+0.5),
          PointF(b.X-len*0.6*Cos(ang)+0.5, b.Y-len*0.6*Sin(ang)+0.5),
          PointF(b.X-len*Cos(ang+0.5)+0.5, b.Y-len*Sin(ang+0.5)+0.5)];
        sp.FillPolygon(tip, color);
      end;
    end;
    ptRectangle: begin
      var r := Rect(Min(s.points[0].X, s.points[n-1].X), Min(s.points[0].Y, s.points[n-1].Y), Max(s.points[0].X, s.points[n-1].X), Max(s.points[0].Y, s.points[n-1].Y));
      paintRoundRect(sp, r, 2, (if FFilled then fill else clNone), color, w);
    end;
    ptEllipse: begin
      var cx := (s.points[0].X+s.points[n-1].X)/2;
      var cy := (s.points[0].Y+s.points[n-1].Y)/2;
      var rx := Abs(s.points[n-1].X-s.points[0].X)/2;
      var ry := Abs(s.points[n-1].Y-s.points[0].Y)/2;
      if FFilled then sp.FillEllipse(cx, cy, rx, ry, fill);
      sp.FrameEllipse(cx, cy, rx, ry, w, color);
    end;
    ptText: ;
  end;
end;

procedure TPaintCanvas.paintTexts(const strokes: array of TStroke);
begin
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  for var s in strokes do begin
    if (s.tool <> ptText) or (length(s.points) = 0) then continue;
    Canvas.Font := Font;
    Canvas.Font.Size := Max(Font.Size, 8)+Max(s.width-1, 0)*2;
    Canvas.Font.Color := s.color;
    Canvas.TextOut(s.points[0].X, s.points[0].Y, s.text);
  end;
  Canvas.Font := Font;
  Canvas.Brush.Style := bsSolid;
end;

procedure TPaintCanvas.Paint;
begin
  var back := pick(FBackColor, clWindow);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  if (FBackground.Width > 0) and (FBackground.Height > 0) and (FBackground.Graphic is TRasterImage) then
    sp.DrawImage(TRasterImage(FBackground.Graphic), Rect(0, 0, FBackground.Width, FBackground.Height), Rect(0, 0, FBackground.Width, FBackground.Height));
  if FShowGrid and (FGridSize > 1) then begin
    var grid := pick(FGridColor, blend(back, clWindowText, 10));
    var step := scaled(self, FGridSize);
    var x := step;
    while x < ClientWidth do begin sp.FillRect(Rect(x, 0, x+1, ClientHeight), grid); x += step; end;
    var y := step;
    while y < ClientHeight do begin sp.FillRect(Rect(0, y, ClientWidth, y+1), grid); y += step; end;
  end;
  for var s in FStrokes do paintStroke(sp, s);
  if FDrawing then paintStroke(sp, FCurrent);
  sp.Flush;
  paintTexts(FStrokes);
end;

function TPaintCanvas.Render: TBitmap;
begin
  result := TBitmap.Create;
  result.PixelFormat := pf32bit;
  result.SetSize(Max(ClientWidth, 1), Max(ClientHeight, 1));
  var back := pick(FBackColor, clWindow);
  var sp := autofree beginShapes(result.Canvas, Rect(0, 0, result.Width, result.Height), back, asOn);
  if (FBackground.Width > 0) and (FBackground.Graphic is TRasterImage) then
    sp.DrawImage(TRasterImage(FBackground.Graphic), Rect(0, 0, FBackground.Width, FBackground.Height), Rect(0, 0, FBackground.Width, FBackground.Height));
  for var s in FStrokes do paintStroke(sp, s);
  sp.Flush;
  result.Canvas.Font := Font;
  result.Canvas.Brush.Style := bsClear;
  for var s in FStrokes do begin
    if (s.tool <> ptText) or (length(s.points) = 0) then continue;
    result.Canvas.Font.Size := Max(Font.Size, 8)+Max(s.width-1, 0)*2;
    result.Canvas.Font.Color := s.color;
    result.Canvas.TextOut(s.points[0].X, s.points[0].Y, s.text);
  end;
end;

procedure TPaintCanvas.SaveToFile(const fileName: string);
begin
  var bmp := autofree Render;
  var png := autofree TPortableNetworkGraphic.Create;
  png.Assign(bmp);
  png.SaveToFile(fileName);
end;

// -- input ----------------------

procedure TPaintCanvas.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  if (Button <> mbLeft) or FReadOnly then exit;
  if FTool = ptText then begin
    FCurrent := Default(TStroke);
    FCurrent.points := [Point(X, Y)];
    if Assigned(FOnTextWanted) then FOnTextWanted(self, -1);
    exit;
  end;
  FCurrent := Default(TStroke);
  FCurrent.tool := FTool;
  FCurrent.color := FPenColor;
  FCurrent.width := FPenWidth;
  FCurrent.points := [Point(X, Y)];
  FDrawing := true;
  Invalidate;
end;

procedure TPaintCanvas.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if not FDrawing then exit;
  if FTool in [ptPen, ptHighlighter, ptEraser] then begin
    var last := FCurrent.points[high(FCurrent.points)];
    if (Abs(last.X-X) < 2) and (Abs(last.Y-Y) < 2) then exit;
    FCurrent.points := FCurrent.points+[Point(X, Y)];
  end else begin
    var p := Point(X, Y);
    if ssShift in Shift then begin
      // a square, a circle or a straight line on the nearest axis
      var a := FCurrent.points[0];
      if FTool in [ptLine, ptArrow] then begin
        if Abs(X-a.X) > Abs(Y-a.Y) then p.Y := a.Y else p.X := a.X;
      end else begin
        var d := Max(Abs(X-a.X), Abs(Y-a.Y));
        p := Point(a.X+d*Sign(X-a.X), a.Y+d*Sign(Y-a.Y));
      end;
    end;
    if length(FCurrent.points) = 1 then FCurrent.points := FCurrent.points+[p] else FCurrent.points[1] := p;
  end;
  Invalidate;
end;

procedure TPaintCanvas.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not FDrawing then exit;
  FDrawing := false;
  FStrokes := FStrokes+[FCurrent];
  FUndone := nil;
  changed;
  if Assigned(FOnStroke) then FOnStroke(self, high(FStrokes));
end;

procedure TPaintCanvas.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if ssCtrl in Shift then
    match Key of
      VK_Z: begin if ssShift in Shift then Redo else Undo; Key := 0; end;
      VK_Y: begin Redo; Key := 0; end;
    end;
end;

// -- properties ----------------------

procedure TPaintCanvas.setTool(value: TPaintTool);
begin
  if FTool = value then exit;
  FTool := value;
  Cursor := if value = ptText then crIBeam else crCross;
end;

procedure TPaintCanvas.setPenWidth(value: integer);
begin
  FPenWidth := EnsureRange(value, 1, 64);
end;

procedure TPaintCanvas.setGridSize(value: integer);
begin
  value := Max(value, 2);
  if FGridSize = value then exit;
  FGridSize := value;
  Invalidate;
end;

function TPaintCanvas.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FFilled;
    1: FShowGrid;
  else
    FReadOnly
  end;
end;

procedure TPaintCanvas.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FFilled := value;
    1: FShowGrid := value;
  else
    FReadOnly := value;
  end;
  Invalidate;
end;

function TPaintCanvas.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FPenColor;
    1: FFillColor;
    2: FBackColor;
  else
    FGridColor
  end;
end;

procedure TPaintCanvas.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FPenColor := value;
    1: FFillColor := value;
    2: FBackColor := value;
  else
    FGridColor := value;
  end;
  Invalidate;
end;

procedure TPaintCanvas.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

procedure TPaintCanvas.setBackground(value: TPicture);
begin
  FBackground.Assign(value);
end;

procedure TPaintCanvas.backgroundChanged(Sender: TObject);
begin
  Invalidate;
end;

end.
