{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit WizardControl;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, StdCtrls, ControlPaint;

type
  // the row of steps: numbered circles joined by lines, a bar filling up with
  // small marks, chevron bands, or tabs with an underline for the current step
  TWizardHeaderStyle = (whCircles, whBar, whChevrons, whTabs);
  TWizardControl = class;

  { TWizardStep }

  TWizardStep = class(TCollectionItem)
  private
    FCaption, FDescription: string;
    FPage: TControl;
    FTag: PtrInt;
    FEnabled: boolean;
    procedure setCaption(const value: string);
    procedure setPage(value: TControl);
    procedure setEnabled(value: boolean);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Caption: string read FCaption write setCaption;
    // a line under the caption in the header
    property Description: string read FDescription write FDescription;
    // the child of the wizard shown while this is the step
    property Page: TControl read FPage write setPage;
    property Tag: PtrInt read FTag write FTag default 0;
    property Enabled: boolean read FEnabled write setEnabled default true;
  end;

  { TWizardSteps }

  TWizardSteps = class(TOwnedCollection)
  private
    function getItem(index: integer): TWizardStep;
    procedure setItem(index: integer; value: TWizardStep);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TWizardStep;
    function AddStep(const caption: string; page: TControl = nil): TWizardStep;
    property Items[index: integer]: TWizardStep read getItem write setItem; default;
  end;

  TWizardStepEvent = procedure(Sender: TObject; fromStep, toStep: integer; var allow: boolean) of object;

  { TWizardControl }

  // steps along the top, the page of the step in the middle, Back, Next
  // and Finish along the bottom. Each step names the child it shows; the
  // other children stay hidden
  TWizardControl = class(TCustomControl)
  private
    FSteps: TWizardSteps;
    FStepIndex, FHot: integer;
    FHeaderHeight, FFooterHeight, FPadding, FCircleSize: integer;
    FShowHeader, FShowFooter, FShowCancel, FClickableSteps, FShowDescriptions: boolean;
    FLaying: boolean;
    FBackCaption, FNextCaption, FFinishCaption, FCancelCaption: string;
    FBack, FNext, FCancel: TButton;
    FAccentColor, FDoneColor, FLineColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnDrawStep: TCustomDrawEvent;
    FHeaderStyle: TWizardHeaderStyle;
    FOnStepChanging: TWizardStepEvent;
    FOnStepChanged, FOnFinish, FOnCancel: TNotifyEvent;
    procedure setSteps(value: TWizardSteps);
    procedure setStepIndex(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setText(index: integer; const value: string);
    function getText(index: integer): string;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setHeaderStyle(value: TWizardHeaderStyle);
    function headerPx: integer;
    function footerPx: integer;
    function stepRect(index: integer): TRect;
    function stepAt(x, y: integer): integer;
    procedure showPage;
    procedure placeButtons;
    procedure backClick(Sender: TObject);
    procedure nextClick(Sender: TObject);
    procedure cancelClick(Sender: TObject);
    procedure stepsChanged;
    function go(toStep: integer): boolean;
  protected
    procedure Paint; override;
    procedure AdjustClientRect(var ARect: TRect); override;
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure FontChanged(Sender: TObject); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // false when the step refused, OnStepChanging said no, or there is no step
    function Next: boolean;
    function Back: boolean;
    function IsFirst: boolean;
    function IsLast: boolean;
    function CurrentStep: TWizardStep;
  published
    property Steps: TWizardSteps read FSteps write setSteps;
    property StepIndex: integer read FStepIndex write setStepIndex default 0;
    property ShowHeader: boolean index 0 read getFlag write setFlag default true;
    property ShowFooter: boolean index 1 read getFlag write setFlag default true;
    property ShowCancel: boolean index 2 read getFlag write setFlag default true;
    // a click on a step in the header goes there, backwards only
    property ClickableSteps: boolean index 3 read getFlag write setFlag default true;
    property ShowDescriptions: boolean index 4 read getFlag write setFlag default true;
    // 0 takes it from the font
    property HeaderHeight: integer index 0 read getMetric write setMetric default 0;
    property FooterHeight: integer index 1 read getMetric write setMetric default 0;
    property Padding: integer index 2 read getMetric write setMetric default 12;
    property CircleSize: integer index 3 read getMetric write setMetric default 26;
    property BackCaption: string index 0 read getText write setText;
    property NextCaption: string index 1 read getText write setText;
    property FinishCaption: string index 2 read getText write setText;
    property CancelCaption: string index 3 read getText write setText;
    // clDefault takes the colors of the theme
    property AccentColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property DoneColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property LineColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // paints over the mark of a step, in the box of CircleSize: dsChecked for
    // a step done, dsSelected for the current one; `handled` true leaves the
    // number out
    property OnDrawStep: TCustomDrawEvent read FOnDrawStep write FOnDrawStep;
    property HeaderStyle: TWizardHeaderStyle read FHeaderStyle write setHeaderStyle default whCircles;
    // before the move; allow false keeps the step
    property OnStepChanging: TWizardStepEvent read FOnStepChanging write FOnStepChanging;
    property OnStepChanged: TNotifyEvent read FOnStepChanged write FOnStepChanged;
    // Next on the last step
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
    property OnCancel: TNotifyEvent read FOnCancel write FOnCancel;
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

{ TWizardStep }

constructor TWizardStep.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FEnabled := true;
end;

procedure TWizardStep.Assign(Source: TPersistent);
begin
  if Source is TWizardStep then begin
    FCaption := TWizardStep(Source).FCaption;
    FDescription := TWizardStep(Source).FDescription;
    FPage := TWizardStep(Source).FPage;
    FTag := TWizardStep(Source).FTag;
    FEnabled := TWizardStep(Source).FEnabled;
    Changed(false);
  end else inherited Assign(Source);
end;

function TWizardStep.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TWizardStep.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TWizardStep.setPage(value: TControl);
begin
  if FPage = value then exit;
  FPage := value;
  Changed(false);
end;

procedure TWizardStep.setEnabled(value: boolean);
begin
  if FEnabled = value then exit;
  FEnabled := value;
  Changed(false);
end;

{ TWizardSteps }

function TWizardSteps.getItem(index: integer): TWizardStep;
begin
  result := TWizardStep(inherited Items[index]);
end;

procedure TWizardSteps.setItem(index: integer; value: TWizardStep);
begin
  inherited Items[index] := value;
end;

procedure TWizardSteps.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TWizardControl then TWizardControl(Owner).stepsChanged;
end;

function TWizardSteps.Add: TWizardStep;
begin
  result := TWizardStep(inherited Add);
end;

function TWizardSteps.AddStep(const caption: string; page: TControl): TWizardStep;
begin
  result := Add;
  result.FCaption := caption;
  result.FPage := page;
  result.Changed(false);
end;

{ TWizardControl }

constructor TWizardControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  FSteps := TWizardSteps.Create(self, TWizardStep);
  FHot := -1;
  FShowHeader := true;
  FShowFooter := true;
  FShowCancel := true;
  FClickableSteps := true;
  FShowDescriptions := true;
  FPadding := 12;
  FCircleSize := 26;
  FBackCaption := 'Back';
  FNextCaption := 'Next';
  FFinishCaption := 'Finish';
  FCancelCaption := 'Cancel';
  FAccentColor := clDefault;
  FDoneColor := clDefault;
  FLineColor := clDefault;
  FAntialiasing := asTheme;
  // the buttons belong to the wizard; they are not streamed nor designed
  FBack := TButton.Create(self);
  FBack.SetSubComponent(true);
  FBack.ControlStyle := FBack.ControlStyle+[csNoDesignSelectable];
  FBack.Caption := FBackCaption;
  FBack.OnClick := @backClick;
  FBack.Parent := self;
  FNext := TButton.Create(self);
  FNext.SetSubComponent(true);
  FNext.ControlStyle := FNext.ControlStyle+[csNoDesignSelectable];
  FNext.Caption := FNextCaption;
  FNext.OnClick := @nextClick;
  FNext.Parent := self;
  FCancel := TButton.Create(self);
  FCancel.SetSubComponent(true);
  FCancel.ControlStyle := FCancel.ControlStyle+[csNoDesignSelectable];
  FCancel.Caption := FCancelCaption;
  FCancel.OnClick := @cancelClick;
  FCancel.Parent := self;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TWizardControl.Destroy;
begin
  FSteps.Free;
  inherited Destroy;
end;

class function TWizardControl.GetControlClassDefaultSize: TSize;
begin
  result.cx := 480;
  result.cy := 320;
end;

// -- geometry ----------------------

function TWizardControl.headerPx: integer;
begin
  if not FShowHeader then exit(0);
  if FHeaderHeight > 0 then exit(scaled(self, FHeaderHeight));
  result := scaled(self, FCircleSize)+scaled(self, 8)+lineHeightOf(Font)+scaled(self, FPadding)*2;
  if FShowDescriptions then result += lineHeightOf(Font);
end;

function TWizardControl.footerPx: integer;
begin
  if not FShowFooter then exit(0);
  result := if FFooterHeight > 0 then scaled(self, FFooterHeight) else scaled(self, 28)+scaled(self, FPadding)*2;
end;

function TWizardControl.stepRect(index: integer): TRect;
begin
  var n := Max(FSteps.Count, 1);
  var w := ClientWidth div n;
  result := Rect(index*w, 0, (index+1)*w, headerPx);
end;

function TWizardControl.stepAt(x, y: integer): integer;
begin
  result := -1;
  if (y < 0) or (y >= headerPx) then exit;
  for var i := 0 to FSteps.Count-1 do if stepRect(i).Contains(Point(x, y)) then exit(i);
end;

procedure TWizardControl.AdjustClientRect(var ARect: TRect);
begin
  inherited AdjustClientRect(ARect);
  var pad := scaled(self, FPadding);
  ARect := Rect(ARect.Left+pad, ARect.Top+headerPx, ARect.Right-pad, ARect.Bottom-footerPx);
end;

procedure TWizardControl.placeButtons;
begin
  var pad := scaled(self, FPadding);
  var h := scaled(self, 28);
  var w := scaled(self, 90);
  var y := ClientHeight-footerPx+(footerPx-h) div 2;
  // only a real change goes through: a repeat would ask for another pass
  if FBack.Visible <> FShowFooter then FBack.Visible := FShowFooter;
  if FNext.Visible <> FShowFooter then FNext.Visible := FShowFooter;
  if FCancel.Visible <> (FShowFooter and FShowCancel) then FCancel.Visible := FShowFooter and FShowCancel;
  var nextRect := Rect(ClientWidth-pad-w, y, ClientWidth-pad, y+h);
  var backRect := Rect(ClientWidth-pad*2-w*2, y, ClientWidth-pad*2-w, y+h);
  var cancelRect := Rect(pad, y, pad+w, y+h);
  if FNext.BoundsRect <> nextRect then FNext.BoundsRect := nextRect;
  if FBack.BoundsRect <> backRect then FBack.BoundsRect := backRect;
  if FCancel.BoundsRect <> cancelRect then FCancel.BoundsRect := cancelRect;
  var canBack := Enabled and not IsFirst;
  var canNext := Enabled and (FSteps.Count > 0);
  if FBack.Enabled <> canBack then FBack.Enabled := canBack;
  if FNext.Enabled <> canNext then FNext.Enabled := canNext;
  var nextText := if IsLast then FFinishCaption else FNextCaption;
  if FNext.Caption <> nextText then FNext.Caption := nextText;
  if FBack.Caption <> FBackCaption then FBack.Caption := FBackCaption;
  if FCancel.Caption <> FCancelCaption then FCancel.Caption := FCancelCaption;
end;

// the page of the step fills the middle, the other pages hide
procedure TWizardControl.showPage;
begin
  var inner := ClientRect;
  AdjustClientRect(inner);
  var current := CurrentStep;
  for var i := 0 to FSteps.Count-1 do begin
    var page := FSteps[i].Page;
    if (page = nil) or (page.Parent <> self) then continue;
    var shown := FSteps[i] = current;
    if page.Visible <> shown then page.Visible := shown;
    if shown and (page.BoundsRect <> inner) then page.BoundsRect := inner;
  end;
end;

procedure TWizardControl.AlignControls(AControl: TControl; var ARect: TRect);
begin
  if FLaying or (csDestroying in ComponentState) then exit;
  FLaying := true;
  try
    placeButtons;
    showPage;
  finally
    FLaying := false;
  end;
end;

// -- moving ----------------------

function TWizardControl.go(toStep: integer): boolean;
begin
  result := false;
  if (toStep < 0) or (toStep >= FSteps.Count) or (toStep = FStepIndex) then exit;
  if not FSteps[toStep].Enabled then exit;
  var allow := true;
  if Assigned(FOnStepChanging) then FOnStepChanging(self, FStepIndex, toStep, allow);
  if not allow then exit;
  FStepIndex := toStep;
  ReAlign;
  Invalidate;
  if Assigned(FOnStepChanged) then FOnStepChanged(self);
  result := true;
end;

function TWizardControl.Next: boolean;
begin
  if IsLast then begin
    var allow := true;
    if Assigned(FOnStepChanging) then FOnStepChanging(self, FStepIndex, FSteps.Count, allow);
    if allow and Assigned(FOnFinish) then FOnFinish(self);
    exit(allow);
  end;
  // the disabled steps are skipped
  var target := FStepIndex+1;
  while (target < FSteps.Count) and not FSteps[target].Enabled do inc(target);
  result := go(target);
end;

function TWizardControl.Back: boolean;
begin
  var target := FStepIndex-1;
  while (target >= 0) and not FSteps[target].Enabled do dec(target);
  result := go(target);
end;

function TWizardControl.IsFirst: boolean;
begin
  result := FStepIndex <= 0;
end;

function TWizardControl.IsLast: boolean;
begin
  result := FStepIndex >= FSteps.Count-1;
end;

function TWizardControl.CurrentStep: TWizardStep;
begin
  result := if (FStepIndex >= 0) and (FStepIndex < FSteps.Count) then FSteps[FStepIndex] else nil;
end;

procedure TWizardControl.backClick(Sender: TObject);
begin
  Back;
end;

procedure TWizardControl.nextClick(Sender: TObject);
begin
  Next;
end;

procedure TWizardControl.cancelClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then FOnCancel(self);
end;

// -- painting ----------------------

procedure TWizardControl.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var accent := pick(FAccentColor, clHighlight);
  var done := pick(FDoneColor, clHighlight);
  var line := pick(FLineColor, blend(clBtnFace, clBtnShadow, 50));
  var text := ColorToRGB(if Enabled then clWindowText else clGrayText);
  var dim := ColorToRGB(clGrayText);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  var h := headerPx;
  var circle := scaled(self, FCircleSize);
  var pad := scaled(self, FPadding);
  var cy := pad+circle div 2;
  if h > 0 then begin
    for var i := 0 to FSteps.Count-1 do begin
      var r := stepRect(i);
      var cx := (r.Left+r.Right) div 2;
      // the line to the next step shows the progress
      if (i < FSteps.Count-1) and (FHeaderStyle = whCircles) then begin
        var nx := (stepRect(i+1).Left+stepRect(i+1).Right) div 2;
        paintLine(sp, cx+circle div 2+scaled(self, 4), cy, nx-circle div 2-scaled(self, 4), cy, (if i < FStepIndex then done else line), 2);
      end;
      var isDone := i < FStepIndex;
      var isCurrent := i = FStepIndex;
      var hot := (i = FHot) and FClickableSteps and hoverEnabled and isDone;
      var fill := if isDone then done else if isCurrent then accent else back;
      var ring := if isDone or isCurrent then clNone else (if FSteps[i].Enabled then line else blend(line, back, 50));
      if hot then fill := blend(fill, clWhite, 20);
      match FHeaderStyle of
        // a thick bar with a small mark per step, filled up to the current one
        whBar: begin
          var bh := Max(circle div 4, 4);
          paintRoundRect(sp, Rect(r.Left, cy-bh div 2, r.Right, cy+bh div 2), bh div 2, (if isDone or isCurrent then done else line), clNone);
          paintCircle(sp, cx, cy, bh, fill, (if isDone or isCurrent then clNone else line));
        end;
        // a band with a point on the right, cut to take the point of the one before
        whChevrons: begin
          var k := circle div 2;
          var pts: array of TPointF := [PointF(r.Left, cy-circle div 2), PointF(r.Right-k, cy-circle div 2), PointF(r.Right, cy), PointF(r.Right-k, cy+circle div 2), PointF(r.Left, cy+circle div 2)];
          if i > 0 then pts += [PointF(r.Left+k, cy)];
          sp.FillPolygon(pts, (if isDone or isCurrent then fill else blend(line, back, 50)));
        end;
        // a box per step, the current one underlined in the accent
        whTabs: begin
          paintRoundRect(sp, Rect(r.Left+2, cy-circle div 2, r.Right-2, cy+circle div 2), scaled(self, 4), (if isDone then blend(back, done, 25) else if isCurrent then blend(back, accent, 25) else blend(line, back, 70)), clNone);
          if isCurrent then paintRoundRect(sp, Rect(r.Left+2, cy+circle div 2-scaled(self, 3), r.Right-2, cy+circle div 2), 1, accent, clNone);
        end;
      else
        paintCircle(sp, cx, cy, circle div 2, fill, ring);
        if isDone then paintCheck(sp, Rect(cx-circle div 2, cy-circle div 2, cx+circle div 2, cy+circle div 2), circle div 2, contrastText(done), 2);
      end;
    end;
    if FShowFooter then paintLine(sp, 0, ClientHeight-footerPx, ClientWidth, ClientHeight-footerPx, line, 1);
    paintLine(sp, 0, h-1, ClientWidth, h-1, line, 1);
  end;
  sp.Flush;
  if h = 0 then exit;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var lineH := Canvas.TextHeight('Hg');
  for var i := 0 to FSteps.Count-1 do begin
    var r := stepRect(i);
    var cx := (r.Left+r.Right) div 2;
    var isDone := i < FStepIndex;
    var isCurrent := i = FStepIndex;
    var handled := false;
    if Assigned(FOnDrawStep) then begin
      var state: TDrawState := [];
      if isDone then state += [dsChecked];
      if isCurrent then state += [dsSelected];
      if (i = FHot) and hoverEnabled then state += [dsHover];
      if not FSteps[i].Enabled then state += [dsDisabled];
      FOnDrawStep(self, Canvas, Rect(cx-circle div 2, cy-circle div 2, cx+circle div 2, cy+circle div 2), i, state, handled);
    end;
    // the number sits in the circle, in the chevron band and in the tab; the bar has no room for it
    if not handled and (not isDone or (FHeaderStyle in [whChevrons, whTabs])) and (FHeaderStyle <> whBar) then begin
      Canvas.Font.Style := Font.Style+[fsBold];
      var numberColor := if isCurrent then contrastText(accent) else if isDone then contrastText(done) else if FSteps[i].Enabled then text else dim;
      if FHeaderStyle = whTabs then numberColor := if FSteps[i].Enabled then text else dim;
      var box := if FHeaderStyle in [whChevrons, whTabs] then Rect(r.Left, cy-circle div 2, r.Right, cy+circle div 2) else Rect(cx-circle div 2, cy-circle div 2, cx+circle div 2, cy+circle div 2);
      paintCenteredText(Canvas, box, IntToStr(i+1), numberColor);
    end;
    Canvas.Font.Style := if isCurrent then Font.Style+[fsBold] else Font.Style;
    var y := pad+circle+scaled(self, 8);
    paintCenteredText(Canvas, Rect(r.Left, y, r.Right, y+lineH), FSteps[i].Caption, (if isCurrent then text else if FSteps[i].Enabled then blend(text, back, 25) else dim));
    if FShowDescriptions and (FSteps[i].Description <> '') then begin
      Canvas.Font.Style := Font.Style;
      paintCenteredText(Canvas, Rect(r.Left, y+lineH, r.Right, y+lineH*2), FSteps[i].Description, dim);
    end;
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TWizardControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FClickableSteps or not Enabled then exit;
  var hit := stepAt(X, Y);
  if (hit >= 0) and (hit < FStepIndex) then go(hit);
end;

procedure TWizardControl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hit := stepAt(X, Y);
  if hit <> FHot then begin
    FHot := hit;
    Cursor := if FClickableSteps and (hit >= 0) and (hit < FStepIndex) then crHandPoint else crDefault;
    Invalidate;
  end;
end;

procedure TWizardControl.MouseLeave;
begin
  inherited MouseLeave;
  if FHot >= 0 then begin
    FHot := -1;
    Invalidate;
  end;
end;

procedure TWizardControl.Loaded;
begin
  inherited Loaded;
  ReAlign;
end;

procedure TWizardControl.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (FSteps <> nil) then
    for var i := 0 to FSteps.Count-1 do if FSteps[i].FPage = AComponent then FSteps[i].FPage := nil;
end;

procedure TWizardControl.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  ReAlign;
end;

procedure TWizardControl.stepsChanged;
begin
  if FStepIndex >= FSteps.Count then FStepIndex := Max(FSteps.Count-1, 0);
  ReAlign;
  Invalidate;
end;

// -- properties ----------------------

procedure TWizardControl.setSteps(value: TWizardSteps);
begin
  FSteps.Assign(value);
end;

procedure TWizardControl.setStepIndex(value: integer);
begin
  if csLoading in ComponentState then begin
    FStepIndex := value;
    exit;
  end;
  value := EnsureRange(value, 0, Max(FSteps.Count-1, 0));
  if FStepIndex = value then exit;
  FStepIndex := value;
  ReAlign;
  Invalidate;
  if Assigned(FOnStepChanged) then FOnStepChanged(self);
end;

function TWizardControl.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowHeader;
    1: FShowFooter;
    2: FShowCancel;
    3: FClickableSteps;
  else
    FShowDescriptions
  end;
end;

procedure TWizardControl.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowHeader := value;
    1: FShowFooter := value;
    2: FShowCancel := value;
    3: FClickableSteps := value;
  else
    FShowDescriptions := value;
  end;
  ReAlign;
  Invalidate;
end;

function TWizardControl.getMetric(index: integer): integer;
begin
  result := match index of
    0: FHeaderHeight;
    1: FFooterHeight;
    2: FPadding;
  else
    FCircleSize
  end;
end;

procedure TWizardControl.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FHeaderHeight := value;
    1: FFooterHeight := value;
    2: FPadding := value;
  else
    FCircleSize := value;
  end;
  ReAlign;
  Invalidate;
end;

function TWizardControl.getText(index: integer): string;
begin
  result := match index of
    0: FBackCaption;
    1: FNextCaption;
    2: FFinishCaption;
  else
    FCancelCaption
  end;
end;

procedure TWizardControl.setText(index: integer; const value: string);
begin
  if getText(index) = value then exit;
  match index of
    0: FBackCaption := value;
    1: FNextCaption := value;
    2: FFinishCaption := value;
  else
    FCancelCaption := value;
  end;
  placeButtons;
end;

function TWizardControl.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FAccentColor;
    1: FDoneColor;
  else
    FLineColor
  end;
end;

procedure TWizardControl.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FAccentColor := value;
    1: FDoneColor := value;
  else
    FLineColor := value;
  end;
  Invalidate;
end;

procedure TWizardControl.setHeaderStyle(value: TWizardHeaderStyle);
begin
  if FHeaderStyle = value then exit;
  FHeaderStyle := value;
  Invalidate;
end;

procedure TWizardControl.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
