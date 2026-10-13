{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit StackPanel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ControlPaint;

type
  TStackOrientation = (soVertical, soHorizontal);
  // how a child sits across the stack: stretched to the full width (or
  // height), or kept at its own size at the start, the middle or the end
  TStackCrossAlign = (saStretch, saStart, saCenter, saEnd);
  // where the run of children sits along the stack when it is shorter than
  // the panel; spaced puts the slack between them
  TStackMainAlign = (smStart, smCenter, smEnd, smSpaced);

  { TStackPanel }

  // lays its children out one after the other, in the order of their
  // position along the stack, with Spacing between them and Padding
  // around. Align and Anchors of the children do not apply
  TStackPanel = class(TCustomControl)
  private
    FOrientation: TStackOrientation;
    FCrossAlign: TStackCrossAlign;
    FMainAlign: TStackMainAlign;
    FSpacing, FPadding: integer;
    FAutoSizeStack, FReverse, FFillLast: boolean;
    FLaying: boolean;
    procedure setOrientation(value: TStackOrientation);
    procedure setCrossAlign(value: TStackCrossAlign);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setAutoSizeStack(value: boolean);
    procedure setMainAlign(value: TStackMainAlign);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    function ordered: TList;
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean); override;
    procedure Paint; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Orientation: TStackOrientation read FOrientation write setOrientation default soVertical;
    property CrossAlign: TStackCrossAlign read FCrossAlign write setCrossAlign default saStretch;
    property MainAlign: TStackMainAlign read FMainAlign write setMainAlign default smStart;
    // the children run the other way: the last one first
    property Reverse: boolean index 0 read getFlag write setFlag default false;
    // the last child takes what is left of the stack
    property FillLast: boolean index 1 read getFlag write setFlag default false;
    property Spacing: integer index 0 read getMetric write setMetric default 6;
    property Padding: integer index 1 read getMetric write setMetric default 6;
    // the panel grows and shrinks along the stack with its children
    property AutoSizeStack: boolean read FAutoSizeStack write setAutoSizeStack default false;
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

constructor TStackPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  FSpacing := 6;
  FPadding := 6;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TStackPanel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 200;
  result.cy := 240;
end;

function byTop(a, b: Pointer): integer;
begin
  result := TControl(a).Top-TControl(b).Top;
  if result = 0 then result := TControl(a).Left-TControl(b).Left;
end;

function byLeft(a, b: Pointer): integer;
begin
  result := TControl(a).Left-TControl(b).Left;
  if result = 0 then result := TControl(a).Top-TControl(b).Top;
end;

// the visible children in the order they follow each other
function TStackPanel.ordered: TList;
begin
  result := TList.Create;
  for var i := 0 to ControlCount-1 do if Controls[i].Visible or (csDesigning in ComponentState) then result.Add(Controls[i]);
  if FOrientation = soVertical then result.Sort(@byTop) else result.Sort(@byLeft);
end;

procedure TStackPanel.AlignControls(AControl: TControl; var ARect: TRect);
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  var list := ordered;
  try
    var pad := scaled(self, FPadding);
    var gap := scaled(self, FSpacing);
    if FReverse then for var k := 0 to list.Count div 2-1 do list.Exchange(k, list.Count-1-k);
    // the run of children, and the slack of the stack around or between them
    var along := if FOrientation = soVertical then ClientHeight else ClientWidth;
    var used := pad*2+Max(list.Count-1, 0)*gap;
    for var i := 0 to list.Count-1 do used += if FOrientation = soVertical then TControl(list[i]).Height else TControl(list[i]).Width;
    var slack := Max(along-used, 0);
    if FFillLast or FAutoSizeStack then slack := 0;
    var pos := pad;
    var between := gap;
    match FMainAlign of
      smCenter: pos += slack div 2;
      smEnd: pos += slack;
      smSpaced: if list.Count > 1 then between += slack div (list.Count-1);
    end;
    for var i := 0 to list.Count-1 do begin
      var c := TControl(list[i]);
      var last := (i = list.Count-1) and FFillLast and not FAutoSizeStack;
      // a child sizing itself keeps its size, or the two would fight; a
      // placement only goes through when it changes something, since even
      // an unchanged one asks for another pass
      var stretch := (FCrossAlign = saStretch) and not c.AutoSize;
      if FOrientation = soVertical then begin
        var w := if stretch then ClientWidth-pad*2 else c.Width;
        var x := match FCrossAlign of
          saCenter: (ClientWidth-w) div 2;
          saEnd: ClientWidth-pad-w;
        else
          pad
        end;
        var h := if last then Max(ClientHeight-pad-pos, 1) else c.Height;
        var r := Rect(x, pos, x+w, pos+h);
        if c.BoundsRect <> r then c.BoundsRect := r;
        pos += h+between;
      end else begin
        var h := if stretch then ClientHeight-pad*2 else c.Height;
        var y := match FCrossAlign of
          saCenter: (ClientHeight-h) div 2;
          saEnd: ClientHeight-pad-h;
        else
          pad
        end;
        var w := if last then Max(ClientWidth-pad-pos, 1) else c.Width;
        var r := Rect(pos, y, pos+w, y+h);
        if c.BoundsRect <> r then c.BoundsRect := r;
        pos += w+between;
      end;
    end;
    if FAutoSizeStack and (list.Count > 0) then begin
      var total := pos-between+pad;
      if FOrientation = soVertical then begin
        if total <> Height then Height := total;
      end else if total <> Width then Width := total;
    end;
  finally
    list.Free;
    FLaying := false;
  end;
end;

procedure TStackPanel.CalculatePreferredSize(var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  var list := ordered;
  try
    var pad := scaled(self, FPadding);
    var gap := scaled(self, FSpacing);
    var along := pad*2+Max(list.Count-1, 0)*gap;
    var across := 0;
    for var i := 0 to list.Count-1 do begin
      var c := TControl(list[i]);
      if FOrientation = soVertical then begin
        along += c.Height;
        across := Max(across, c.Width);
      end else begin
        along += c.Width;
        across := Max(across, c.Height);
      end;
    end;
    across += pad*2;
    if FOrientation = soVertical then begin
      PreferredWidth := across;
      PreferredHeight := along;
    end else begin
      PreferredWidth := along;
      PreferredHeight := across;
    end;
  finally
    list.Free;
  end;
end;

procedure TStackPanel.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := GetRGBColorResolvingParent;
  Canvas.FillRect(ClientRect);
  if csDesigning in ComponentState then begin
    // a dashed frame shows the panel on the form while it is designed
    Canvas.Pen.Style := psDash;
    Canvas.Pen.Color := ColorToRGB(clGrayText);
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Style := bsSolid;
  end;
end;

// -- properties ----------------------

procedure TStackPanel.setOrientation(value: TStackOrientation);
begin
  if FOrientation = value then exit;
  FOrientation := value;
  ReAlign;
end;

procedure TStackPanel.setCrossAlign(value: TStackCrossAlign);
begin
  if FCrossAlign = value then exit;
  FCrossAlign := value;
  ReAlign;
end;

function TStackPanel.getMetric(index: integer): integer;
begin
  result := if index = 0 then FSpacing else FPadding;
end;

procedure TStackPanel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  if index = 0 then FSpacing := value else FPadding := value;
  ReAlign;
end;

procedure TStackPanel.setMainAlign(value: TStackMainAlign);
begin
  if FMainAlign = value then exit;
  FMainAlign := value;
  ReAlign;
end;

function TStackPanel.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FReverse else FFillLast;
end;

procedure TStackPanel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FReverse := value else FFillLast := value;
  ReAlign;
end;

procedure TStackPanel.setAutoSizeStack(value: boolean);
begin
  if FAutoSizeStack = value then exit;
  FAutoSizeStack := value;
  ReAlign;
end;

end.
