{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Accordion;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExpanderPanel, ControlPaint;

type
  TAccordionPanelEvent = procedure(Sender: TObject; panel: TExpanderPanel) of object;

  { TAccordion }

  // stacks the expander panels dropped on it and, unless MultiOpen is set,
  // keeps one of them open: opening a panel folds the others
  TAccordion = class(TCustomControl)
  private
    FSpacing, FPadding, FHeaderHeight, FCornerRadius, FAnimationTime: integer;
    FMultiOpen, FFillWidth, FStylePanels, FAnimated, FShowBorders: boolean;
    FChevronSide: TChevronSide;
    FHeaderColor, FBorderColor, FTitleColor: TColor;
    FOnPanelOpened, FOnPanelClosed: TAccordionPanelEvent;
    FOpen: TList; // the panels open at the last look
    FLaying: boolean;
    FOnChange: TNotifyEvent;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    function panels: TList;
    procedure enforce(list: TList);
    procedure stylePanel(p: TExpanderPanel);
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setChevronSide(value: TChevronSide);
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure Paint; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the panel that is open; with MultiOpen the first one
    function OpenPanel: TExpanderPanel;
    procedure OpenAll;
    procedure CloseAll;
  published
    property Spacing: integer index 0 read getMetric write setMetric default 4;
    property Padding: integer index 1 read getMetric write setMetric default 0;
    // several panels may be open at once
    property MultiOpen: boolean index 0 read getFlag write setFlag default false;
    // the panels take the full width
    property FillWidth: boolean index 1 read getFlag write setFlag default true;
    // the panels take their look from the accordion: the header height, the
    // corners, the animation, the borders, the chevron and the colors below
    property StylePanels: boolean index 2 read getFlag write setFlag default true;
    property Animated: boolean index 3 read getFlag write setFlag default true;
    property ShowBorders: boolean index 4 read getFlag write setFlag default true;
    // 0 takes it from the font
    property HeaderHeight: integer index 2 read getMetric write setMetric default 0;
    property CornerRadius: integer index 3 read getMetric write setMetric default 4;
    property AnimationTime: integer index 4 read getMetric write setMetric default 150;
    property ChevronSide: TChevronSide read FChevronSide write setChevronSide default csLeft;
    // clDefault takes the colors of the theme
    property HeaderColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property OnPanelOpened: TAccordionPanelEvent read FOnPanelOpened write FOnPanelOpened;
    property OnPanelClosed: TAccordionPanelEvent read FOnPanelClosed write FOnPanelClosed;
    // a panel opened or closed
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
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

constructor TAccordion.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  FSpacing := 4;
  FFillWidth := true;
  FStylePanels := true;
  FAnimated := true;
  FShowBorders := true;
  FCornerRadius := 4;
  FAnimationTime := 150;
  FHeaderColor := clDefault;
  FBorderColor := clDefault;
  FTitleColor := clDefault;
  FOpen := TList.Create;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TAccordion.Destroy;
begin
  FOpen.Free;
  inherited Destroy;
end;

class function TAccordion.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 300;
end;

function byTop(a, b: Pointer): integer;
begin
  result := TControl(a).Top-TControl(b).Top;
end;

// the expander panels, top to bottom; other children are left alone
function TAccordion.panels: TList;
begin
  result := TList.Create;
  for var i := 0 to ControlCount-1 do if (Controls[i] is TExpanderPanel) and (Controls[i].Visible or (csDesigning in ComponentState)) then result.Add(Controls[i]);
  result.Sort(@byTop);
end;

// a panel that opened since the last look closes the others
// the panel takes the look of the accordion
procedure TAccordion.stylePanel(p: TExpanderPanel);
begin
  if not FStylePanels then exit;
  p.HeaderHeight := FHeaderHeight;
  p.CornerRadius := FCornerRadius;
  p.Animated := FAnimated;
  p.AnimationTime := FAnimationTime;
  p.ShowBorder := FShowBorders;
  p.ChevronSide := FChevronSide;
  p.HeaderColor := FHeaderColor;
  p.BorderColor := FBorderColor;
  p.TitleColor := FTitleColor;
end;

procedure TAccordion.enforce(list: TList);
begin
  var changed := false;
  var opened: TExpanderPanel := nil;
  var closedOne: TExpanderPanel := nil;
  for var i := 0 to list.Count-1 do begin
    var p := TExpanderPanel(list[i]);
    stylePanel(p);
    var wasOpen := FOpen.IndexOf(p) >= 0;
    if p.Expanded <> wasOpen then changed := true;
    if p.Expanded and not wasOpen then opened := p;
    if wasOpen and not p.Expanded then closedOne := p;
  end;
  if (opened <> nil) and not FMultiOpen then
    for var i := 0 to list.Count-1 do if (TExpanderPanel(list[i]) <> opened) and TExpanderPanel(list[i]).Expanded then TExpanderPanel(list[i]).Expanded := false;
  FOpen.Clear;
  for var i := 0 to list.Count-1 do if TExpanderPanel(list[i]).Expanded then FOpen.Add(list[i]);
  if changed and not (csLoading in ComponentState) then begin
    if (opened <> nil) and Assigned(FOnPanelOpened) then FOnPanelOpened(self, opened);
    if (closedOne <> nil) and Assigned(FOnPanelClosed) then FOnPanelClosed(self, closedOne);
    if Assigned(FOnChange) then FOnChange(self);
  end;
end;

procedure TAccordion.AlignControls(AControl: TControl; var ARect: TRect);
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  var list := panels;
  try
    enforce(list);
    var pad := scaled(self, FPadding);
    var gap := scaled(self, FSpacing);
    var y := pad;
    for var i := 0 to list.Count-1 do begin
      var p := TExpanderPanel(list[i]);
      var w := if FFillWidth then ClientWidth-pad*2 else p.Width;
      // a placement only goes through when it changes something, since even
      // an unchanged one asks for another pass
      var r := Rect((if FFillWidth then pad else p.Left), y, (if FFillWidth then pad else p.Left)+w, y+p.Height);
      if p.BoundsRect <> r then p.BoundsRect := r;
      y += p.Height+gap;
    end;
  finally
    list.Free;
    FLaying := false;
  end;
end;

procedure TAccordion.Paint;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := GetRGBColorResolvingParent;
  Canvas.FillRect(ClientRect);
  if csDesigning in ComponentState then begin
    Canvas.Pen.Style := psDash;
    Canvas.Pen.Color := ColorToRGB(clGrayText);
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(ClientRect);
    Canvas.Pen.Style := psSolid;
    Canvas.Brush.Style := bsSolid;
  end;
end;

function TAccordion.OpenPanel: TExpanderPanel;
begin
  result := nil;
  var list := panels;
  try
    for var i := 0 to list.Count-1 do if TExpanderPanel(list[i]).Expanded then exit(TExpanderPanel(list[i]));
  finally
    list.Free;
  end;
end;

procedure TAccordion.OpenAll;
begin
  var list := panels;
  try
    for var i := 0 to list.Count-1 do begin
      TExpanderPanel(list[i]).Expanded := true;
      if not FMultiOpen then break;
    end;
  finally
    list.Free;
  end;
end;

procedure TAccordion.CloseAll;
begin
  var list := panels;
  try
    for var i := 0 to list.Count-1 do TExpanderPanel(list[i]).Expanded := false;
  finally
    list.Free;
  end;
end;

// -- properties ----------------------

function TAccordion.getMetric(index: integer): integer;
begin
  result := match index of
    0: FSpacing;
    1: FPadding;
    2: FHeaderHeight;
    3: FCornerRadius;
  else
    FAnimationTime
  end;
end;

procedure TAccordion.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FSpacing := value;
    1: FPadding := value;
    2: FHeaderHeight := value;
    3: FCornerRadius := value;
  else
    FAnimationTime := value;
  end;
  ReAlign;
end;

function TAccordion.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FHeaderColor;
    1: FBorderColor;
  else
    FTitleColor
  end;
end;

procedure TAccordion.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FHeaderColor := value;
    1: FBorderColor := value;
  else
    FTitleColor := value;
  end;
  ReAlign;
end;

procedure TAccordion.setChevronSide(value: TChevronSide);
begin
  if FChevronSide = value then exit;
  FChevronSide := value;
  ReAlign;
end;

function TAccordion.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FMultiOpen;
    1: FFillWidth;
    2: FStylePanels;
    3: FAnimated;
  else
    FShowBorders
  end;
end;

procedure TAccordion.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    1: FFillWidth := value;
    2: FStylePanels := value;
    3: FAnimated := value;
    4: FShowBorders := value;
  end;
  if index = 0 then begin
    FMultiOpen := value;
    // back to one: the first open panel stays
    if not value then begin
      var keep := OpenPanel;
      var list := panels;
      try
        for var i := 0 to list.Count-1 do if TExpanderPanel(list[i]) <> keep then TExpanderPanel(list[i]).Expanded := false;
      finally
        list.Free;
      end;
    end;
  end;
  ReAlign;
end;

end.
