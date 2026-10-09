{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit TourGuide;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, LCLType, LMessages, ControlPaint;

type
  TTourGuide = class;
  TTourSide = (tsAuto, tsBelow, tsAbove, tsRight, tsLeft);
  TTourStepEvent = procedure(Sender: TObject; step: integer) of object;
  // a step is about to show; skip true leaves it out
  TTourBeforeStepEvent = procedure(Sender: TObject; step: integer; var skip: boolean) of object;

  { TTourStep }

  TTourStep = class(TCollectionItem)
  private
    FTarget: TControl;
    FTitle, FText: string;
    FSide: TTourSide;
    FTag: PtrInt;
    procedure setTarget(value: TControl);
  protected
    function GetDisplayName: string; override;
  public
    procedure Assign(Source: TPersistent); override;
  published
    // the control the callout points at; none centers it on the form
    property Target: TControl read FTarget write setTarget;
    property Title: string read FTitle write FTitle;
    property Text: string read FText write FText;
    // where the callout goes, relative to the target
    property Side: TTourSide read FSide write FSide default tsAuto;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TTourSteps }

  TTourSteps = class(TOwnedCollection)
  private
    function getItem(index: integer): TTourStep;
    procedure setItem(index: integer; value: TTourStep);
  public
    function Add: TTourStep;
    property Items[index: integer]: TTourStep read getItem write setItem; default;
  end;

  { TTourWindow }

  // the callout: a card with an arrow at the target, the step text, the
  // step count and the buttons, all painted and hit by hand
  TTourWindow = class(THintWindow)
  private
    FGuide: TTourGuide;
    FSide: TTourSide;
    FArrowAt: integer; // along the edge facing the target, in pixels
    FHot: integer; // the button under the mouse, -1 none
    FButtons: array[0..2] of TRect; // back, next, skip
    FTitleColor, FTextColor: TColor;
  protected
    procedure Paint; override;
    procedure DoShowWindow; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure WMNCHitTest(var Message: TLMessage); message LM_NCHITTEST;
  end;

  { TTourGuide }

  // a guided tour of a form: one callout per step, each pointing at a
  // control, with Next, Back and Skip. Start opens the first step, the
  // callout follows the form around, the keyboard pages too
  TTourGuide = class(TComponent)
  private
    FSteps: TTourSteps;
    FWindow: TTourWindow;
    FTimer: TTimer;
    FCurrent: integer;
    FWidth, FCornerRadius, FArrowSize, FPadding: integer;
    FNextCaption, FBackCaption, FSkipCaption, FFinishCaption: string;
    FShowStepNumber, FShowSkip, FShowBack, FKeyboard, FDimOthers: boolean;
    FSurfaceColor, FBorderColor, FAccentColor, FTitleColor, FTextColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FLastAnchor: TRect;
    FOnStep: TTourStepEvent;
    FOnBeforeStep: TTourBeforeStepEvent;
    FOnFinish, FOnSkip: TNotifyEvent;
    procedure setSteps(value: TTourSteps);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    function stepShown(index: integer; forward: boolean): integer;
    procedure showStep(index: integer);
    procedure place;
    procedure tick(Sender: TObject);
    procedure keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure buttonPressed(index: integer);
    function targetRect(step: TTourStep): TRect;
    function hostForm: TCustomForm;
    procedure measure(step: TTourStep; out w, h: integer);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddStep(target: TControl; const title, text: string; side: TTourSide = tsAuto): TTourStep;
    // opens the first step; a step index starts there
    procedure Start(fromStep: integer = 0);
    procedure Next;
    procedure Back;
    // closes the tour as finished
    procedure Finish;
    // closes the tour as skipped
    procedure Skip;
    function Active: boolean;
    // the step shown, -1 while the tour is off
    property Current: integer read FCurrent;
  published
    property Steps: TTourSteps read FSteps write setSteps;
    // the callout
    property Width: integer index 0 read getMetric write setMetric default 280;
    property CornerRadius: integer index 1 read getMetric write setMetric default 8;
    property ArrowSize: integer index 2 read getMetric write setMetric default 10;
    property Padding: integer index 3 read getMetric write setMetric default 14;
    property NextCaption: string read FNextCaption write FNextCaption;
    property BackCaption: string read FBackCaption write FBackCaption;
    property SkipCaption: string read FSkipCaption write FSkipCaption;
    // the Next button on the last step
    property FinishCaption: string read FFinishCaption write FFinishCaption;
    // "2 of 5" in the corner
    property ShowStepNumber: boolean read FShowStepNumber write FShowStepNumber default true;
    property ShowSkip: boolean read FShowSkip write FShowSkip default true;
    property ShowBack: boolean read FShowBack write FShowBack default true;
    // Right and Enter page forward, Left back, Escape skips
    property Keyboard: boolean read FKeyboard write FKeyboard default true;
    // clDefault takes the colors of the theme
    property SurfaceColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    // the Next button and the step dots
    property AccentColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TitleColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write FAntialiasing default asTheme;
    property OnStep: TTourStepEvent read FOnStep write FOnStep;
    property OnBeforeStep: TTourBeforeStepEvent read FOnBeforeStep write FOnBeforeStep;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
    property OnSkip: TNotifyEvent read FOnSkip write FOnSkip;
  end;

implementation

uses
  Math;

{ TTourStep }

procedure TTourStep.Assign(Source: TPersistent);
begin
  if Source is TTourStep then begin
    FTarget := TTourStep(Source).FTarget;
    FTitle := TTourStep(Source).FTitle;
    FText := TTourStep(Source).FText;
    FSide := TTourStep(Source).FSide;
    FTag := TTourStep(Source).FTag;
  end else inherited Assign(Source);
end;

function TTourStep.GetDisplayName: string;
begin
  result := if FTitle <> '' then FTitle else inherited GetDisplayName;
end;

procedure TTourStep.setTarget(value: TControl);
begin
  if FTarget = value then exit;
  var guide := Collection.Owner as TTourGuide;
  if FTarget <> nil then FTarget.RemoveFreeNotification(guide);
  FTarget := value;
  if FTarget <> nil then FTarget.FreeNotification(guide);
end;

{ TTourSteps }

function TTourSteps.getItem(index: integer): TTourStep;
begin
  result := TTourStep(inherited Items[index]);
end;

procedure TTourSteps.setItem(index: integer; value: TTourStep);
begin
  inherited Items[index] := value;
end;

function TTourSteps.Add: TTourStep;
begin
  result := TTourStep(inherited Add);
end;

{ TTourWindow }

procedure TTourWindow.DoShowWindow;
begin
  // the hint window would activate itself; the form keeps the focus
end;

procedure TTourWindow.WMNCHitTest(var Message: TLMessage);
begin
  Message.Result := HTCLIENT;
end;

procedure TTourWindow.Paint;
begin
  var g := FGuide;
  var surface := pick(g.FSurfaceColor, clWindow);
  var border := pick(g.FBorderColor, blend(surface, clWindowText, 25));
  var accent := pick(g.FAccentColor, clHighlight);
  var title := pick(g.FTitleColor, clWindowText);
  var text := pick(g.FTextColor, blend(clWindowText, clWindow, 25));
  var radius := ControlPaint.scaled(self, g.FCornerRadius);
  var arrow := ControlPaint.scaled(self, g.FArrowSize);
  var pad := ControlPaint.scaled(self, g.FPadding);
  var sp := autofree beginShapes(Canvas, ClientRect, surface, g.FAntialiasing);
  // the card leaves room for the arrow on the side facing the target
  var card := ClientRect;
  match FSide of
    tsBelow: card.Top += arrow;
    tsAbove: card.Bottom -= arrow;
    tsRight: card.Left += arrow;
    tsLeft: card.Right -= arrow;
  end;
  paintRoundRect(sp, card, radius, surface, border, 1);
  var tri: array of TPointF := [];
  var a := EnsureRange(FArrowAt, radius+arrow, (if FSide in [tsBelow, tsAbove] then card.Width else card.Height)-radius-arrow);
  if FSide = tsBelow then tri := [PointF(card.Left+a-arrow, card.Top+1), PointF(card.Left+a, 0), PointF(card.Left+a+arrow, card.Top+1)]
  else if FSide = tsAbove then tri := [PointF(card.Left+a-arrow, card.Bottom-1), PointF(card.Left+a, ClientHeight), PointF(card.Left+a+arrow, card.Bottom-1)]
  else if FSide = tsRight then tri := [PointF(card.Left+1, card.Top+a-arrow), PointF(0, card.Top+a), PointF(card.Left+1, card.Top+a+arrow)]
  else if FSide = tsLeft then tri := [PointF(card.Right-1, card.Top+a-arrow), PointF(ClientWidth, card.Top+a), PointF(card.Right-1, card.Top+a+arrow)];
  if length(tri) > 0 then begin
    // the border of the arrow, then its fill a pixel inside
    sp.FillPolygon(tri, border);
    var inner: array of TPointF;
    SetLength(inner, 3);
    for var i := 0 to 2 do inner[i] := tri[i];
    match FSide of
      tsBelow: begin inner[0].y += 1.5; inner[2].y += 1.5; inner[1].y += 1.5; inner[0].x += 1; inner[2].x -= 1; end;
      tsAbove: begin inner[0].y -= 1.5; inner[2].y -= 1.5; inner[1].y -= 1.5; inner[0].x += 1; inner[2].x -= 1; end;
      tsRight: begin inner[0].x += 1.5; inner[2].x += 1.5; inner[1].x += 1.5; inner[0].y += 1; inner[2].y -= 1; end;
      tsLeft: begin inner[0].x -= 1.5; inner[2].x -= 1.5; inner[1].x -= 1.5; inner[0].y += 1; inner[2].y -= 1; end;
    end;
    sp.FillPolygon(inner, surface);
  end;
  // the buttons along the bottom
  var lh := lineHeightOf(Font);
  var bh := lh+ControlPaint.scaled(self, 10);
  var by := card.Bottom-pad-bh;
  var last := g.FCurrent >= g.stepShown(g.FCurrent, true);
  var nextText := if last then g.FFinishCaption else g.FNextCaption;
  var nextW := textWidthOf(Font, nextText)+ControlPaint.scaled(self, 24);
  FButtons[1] := Rect(card.Right-pad-nextW, by, card.Right-pad, by+bh);
  paintRoundRect(sp, FButtons[1], ControlPaint.scaled(self, 4), (if FHot = 1 then blend(accent, clWhite, 15) else accent), clNone);
  var x := FButtons[1].Left-ControlPaint.scaled(self, 6);
  if g.FShowBack and (g.stepShown(g.FCurrent, false) >= 0) then begin
    var backW := textWidthOf(Font, g.FBackCaption)+ControlPaint.scaled(self, 20);
    FButtons[0] := Rect(x-backW, by, x, by+bh);
    paintRoundRect(sp, FButtons[0], ControlPaint.scaled(self, 4), (if FHot = 0 then hoverColor(surface) else surface), border, 1);
  end else FButtons[0] := Rect(0, 0, 0, 0);
  if g.FShowSkip and not last then begin
    var skipW := textWidthOf(Font, g.FSkipCaption)+ControlPaint.scaled(self, 8);
    FButtons[2] := Rect(card.Left+pad, by, card.Left+pad+skipW, by+bh);
  end else FButtons[2] := Rect(0, 0, 0, 0);
  // the dots of the steps
  if g.FShowStepNumber and (g.FSteps.Count > 1) and (g.FSteps.Count <= 12) then begin
    var dot := ControlPaint.scaled(self, 6);
    var gap := ControlPaint.scaled(self, 4);
    var total := g.FSteps.Count*dot+(g.FSteps.Count-1)*gap;
    var dx := card.Left+(card.Width-total) div 2;
    for var i := 0 to g.FSteps.Count-1 do begin
      paintCircle(sp, dx+dot div 2, by-ControlPaint.scaled(self, 10), dot div 2, (if i = g.FCurrent then accent else blend(surface, clWindowText, 25)), clNone);
      dx += dot+gap;
    end;
  end;
  sp.Flush;
  // the text
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var step := g.FSteps[g.FCurrent];
  var y := card.Top+pad;
  if g.FShowStepNumber then begin
    Canvas.Font.Style := Font.Style;
    Canvas.Font.Color := blend(text, surface, 40);
    var counter := Format('%d / %d', [g.FCurrent+1, g.FSteps.Count]);
    Canvas.TextOut(card.Right-pad-Canvas.TextWidth(counter), y, counter);
  end;
  if step.Title <> '' then begin
    Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.Font.Color := title;
    Canvas.TextOut(card.Left+pad, y, step.Title);
    y += lh+ControlPaint.scaled(self, 6);
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Font.Color := text;
  var style := Canvas.TextStyle;
  style.Wordbreak := true;
  style.SingleLine := false;
  style.Layout := tlTop;
  style.Alignment := taLeftJustify;
  style.Clipping := true;
  style.ShowPrefix := false;
  style.Opaque := false;
  var tr := Rect(card.Left+pad, y, card.Right-pad, by-ControlPaint.scaled(self, 8));
  Canvas.TextRect(tr, tr.Left, tr.Top, step.Text, style);
  // the button captions
  Canvas.Font.Color := contrastText(accent);
  paintCenteredText(Canvas, FButtons[1], nextText, contrastText(accent));
  if not FButtons[0].IsEmpty then paintCenteredText(Canvas, FButtons[0], g.FBackCaption, title);
  if not FButtons[2].IsEmpty then begin
    Canvas.Font.Style := if FHot = 2 then Font.Style+[fsUnderline] else Font.Style;
    paintCenteredText(Canvas, FButtons[2], g.FSkipCaption, blend(text, surface, 20));
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Brush.Style := bsSolid;
end;

procedure TTourWindow.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  var hot := -1;
  for var i := 0 to 2 do if not FButtons[i].IsEmpty and PtInRect(FButtons[i], Point(X, Y)) then hot := i;
  if hot = FHot then exit;
  FHot := hot;
  Cursor := if hot >= 0 then crHandPoint else crDefault;
  Invalidate;
end;

procedure TTourWindow.MouseLeave;
begin
  inherited MouseLeave;
  if FHot < 0 then exit;
  FHot := -1;
  Invalidate;
end;

procedure TTourWindow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  for var i := 0 to 2 do if not FButtons[i].IsEmpty and PtInRect(FButtons[i], Point(X, Y)) then begin
    FGuide.buttonPressed(i);
    exit;
  end;
end;

{ TTourGuide }

constructor TTourGuide.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSteps := TTourSteps.Create(self, TTourStep);
  FCurrent := -1;
  FWidth := 280;
  FCornerRadius := 8;
  FArrowSize := 10;
  FPadding := 14;
  FNextCaption := 'Next';
  FBackCaption := 'Back';
  FSkipCaption := 'Skip tour';
  FFinishCaption := 'Done';
  FShowStepNumber := true;
  FShowSkip := true;
  FShowBack := true;
  FKeyboard := true;
  FSurfaceColor := clDefault;
  FBorderColor := clDefault;
  FAccentColor := clDefault;
  FTitleColor := clDefault;
  FTextColor := clDefault;
  FAntialiasing := asTheme;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 80;
  FTimer.OnTimer := @tick;
end;

destructor TTourGuide.Destroy;
begin
  if Active then begin
    FCurrent := -1;
    Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
  end;
  FreeAndNil(FWindow);
  FSteps.Free;
  inherited Destroy;
end;

procedure TTourGuide.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  for var i := 0 to FSteps.Count-1 do if FSteps[i].FTarget = AComponent then FSteps[i].FTarget := nil;
end;

function TTourGuide.AddStep(target: TControl; const title, text: string; side: TTourSide): TTourStep;
begin
  result := FSteps.Add;
  result.Target := target;
  result.Title := title;
  result.Text := text;
  result.Side := side;
end;

function TTourGuide.Active: boolean;
begin
  result := FCurrent >= 0;
end;

function TTourGuide.hostForm: TCustomForm;
begin
  result := nil;
  if (FCurrent >= 0) and (FSteps[FCurrent].Target <> nil) then result := GetParentForm(FSteps[FCurrent].Target);
  if result = nil then begin
    var o := Owner;
    while (o <> nil) and not (o is TCustomForm) do o := o.Owner;
    result := TCustomForm(o);
  end;
  if result = nil then result := Screen.ActiveCustomForm;
end;

// the index of the next step to show from `index` in a direction, -1 for none
function TTourGuide.stepShown(index: integer; forward: boolean): integer;
begin
  result := index;
  repeat
    result += if forward then 1 else -1;
    if (result < 0) or (result >= FSteps.Count) then exit(-1);
    var skip := false;
    if Assigned(FOnBeforeStep) then FOnBeforeStep(self, result, skip);
    if not skip then exit;
  until false;
end;

procedure TTourGuide.Start(fromStep: integer);
begin
  if (csDesigning in ComponentState) or (FSteps.Count = 0) then exit;
  if not Active then Application.AddOnKeyDownBeforeHandler(@keyBefore);
  var first := EnsureRange(fromStep, 0, FSteps.Count-1);
  var skip := false;
  if Assigned(FOnBeforeStep) then FOnBeforeStep(self, first, skip);
  if skip then first := stepShown(first, true);
  if first < 0 then begin
    Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
    exit;
  end;
  showStep(first);
end;

procedure TTourGuide.Next;
begin
  if not Active then exit;
  var n := stepShown(FCurrent, true);
  if n < 0 then Finish else showStep(n);
end;

procedure TTourGuide.Back;
begin
  if not Active then exit;
  var n := stepShown(FCurrent, false);
  if n >= 0 then showStep(n);
end;

procedure TTourGuide.Finish;
begin
  if not Active then exit;
  FCurrent := -1;
  FTimer.Enabled := false;
  Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
  if FWindow <> nil then FWindow.Visible := false;
  if Assigned(FOnFinish) then FOnFinish(self);
end;

procedure TTourGuide.Skip;
begin
  if not Active then exit;
  FCurrent := -1;
  FTimer.Enabled := false;
  Application.RemoveOnKeyDownBeforeHandler(@keyBefore);
  if FWindow <> nil then FWindow.Visible := false;
  if Assigned(FOnSkip) then FOnSkip(self);
end;

procedure TTourGuide.buttonPressed(index: integer);
begin
  match index of
    0: Back;
    1: Next;
    2: Skip;
  end;
end;

procedure TTourGuide.keyBefore(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if not FKeyboard or not Active or (Shift*[ssCtrl, ssAlt] <> []) then exit;
  match Key of
    VK_RIGHT, VK_RETURN, VK_SPACE: begin Next; Key := 0; end;
    VK_LEFT: begin Back; Key := 0; end;
    VK_ESCAPE: begin Skip; Key := 0; end;
  end;
end;

// -- the callout ----------------------

function TTourGuide.targetRect(step: TTourStep): TRect;
begin
  if (step.Target <> nil) and step.Target.IsVisible then begin
    var p := step.Target.ClientToScreen(Point(0, 0));
    if step.Target is TWinControl then exit(Rect(p.X, p.Y, p.X+step.Target.Width, p.Y+step.Target.Height));
    // a graphic control has no client of its own; its parent places it
    p := step.Target.Parent.ClientToScreen(step.Target.BoundsRect.TopLeft);
    exit(Rect(p.X, p.Y, p.X+step.Target.Width, p.Y+step.Target.Height));
  end;
  var form := hostForm;
  if form = nil then begin
    var m := Screen.PrimaryMonitor.WorkareaRect;
    exit(Rect((m.Left+m.Right) div 2, (m.Top+m.Bottom) div 2, (m.Left+m.Right) div 2, (m.Top+m.Bottom) div 2));
  end;
  var c := form.ClientToScreen(Point(form.ClientWidth div 2, form.ClientHeight div 2));
  result := Rect(c.X, c.Y, c.X, c.Y);
end;

procedure TTourGuide.measure(step: TTourStep; out w, h: integer);
begin
  var wnd := FWindow;
  var pad := scaled(wnd, FPadding);
  var lh := lineHeightOf(wnd.Font);
  w := scaled(wnd, FWidth);
  wnd.Canvas.Font := wnd.Font;
  applyTextQuality(wnd.Canvas);
  var style := wnd.Canvas.TextStyle;
  style.Wordbreak := true;
  style.SingleLine := false;
  var r := Rect(0, 0, w-2*pad, 0);
  var textH := 0;
  if step.Text <> '' then begin
    // the height of the wrapped text
    var lines := 1;
    var words := step.Text.Split([' ']);
    var lineW := 0;
    var spaceW := wnd.Canvas.TextWidth(' ');
    for var word in words do begin
      var ww := wnd.Canvas.TextWidth(word);
      if (lineW > 0) and (lineW+spaceW+ww > r.Width) then begin
        inc(lines);
        lineW := ww;
      end else lineW += (if lineW > 0 then spaceW else 0)+ww;
      // explicit line breaks inside a word
      for var ch in word do if ch = #10 then inc(lines);
    end;
    textH := lines*lh;
  end;
  h := pad*2;
  if step.Title <> '' then h += lh+scaled(wnd, 6);
  h += textH+scaled(wnd, 8);
  h += lh+scaled(wnd, 10); // the buttons
  if FShowStepNumber and (FSteps.Count > 1) and (FSteps.Count <= 12) then h += scaled(wnd, 14);
end;

procedure TTourGuide.place;
begin
  if (FWindow = nil) or not Active then exit;
  var step := FSteps[FCurrent];
  var target := targetRect(step);
  var w, h: integer;
  measure(step, w, h);
  var arrow := scaled(FWindow, FArrowSize);
  var m := Screen.MonitorFromRect(target);
  var work := if m <> nil then m.WorkareaRect else Screen.PrimaryMonitor.WorkareaRect;
  var side := step.Side;
  var pointed := step.Target <> nil;
  if not pointed then side := tsAuto;
  if side = tsAuto then begin
    if not pointed then side := tsAuto
    else if target.Bottom+arrow+h <= work.Bottom then side := tsBelow
    else if target.Top-arrow-h >= work.Top then side := tsAbove
    else if target.Right+arrow+w <= work.Right then side := tsRight
    else side := tsLeft;
  end;
  var r: TRect;
  var gap := scaled(FWindow, 2);
  var cx := (target.Left+target.Right) div 2;
  var cy := (target.Top+target.Bottom) div 2;
  match side of
    tsBelow: r := Rect(cx-w div 2, target.Bottom+gap, cx+w div 2, target.Bottom+gap+h+arrow);
    tsAbove: r := Rect(cx-w div 2, target.Top-gap-h-arrow, cx+w div 2, target.Top-gap);
    tsRight: r := Rect(target.Right+gap, cy-h div 2, target.Right+gap+w+arrow, cy+h div 2);
    tsLeft: r := Rect(target.Left-gap-w-arrow, cy-h div 2, target.Left-gap, cy+h div 2);
  else
    r := Rect(cx-w div 2, cy-h div 2, cx+w div 2, cy+h div 2);
  end;
  // inside the work area, the arrow still at the target
  if r.Right > work.Right then r.Offset(work.Right-r.Right, 0);
  if r.Left < work.Left then r.Offset(work.Left-r.Left, 0);
  if r.Bottom > work.Bottom then r.Offset(0, work.Bottom-r.Bottom);
  if r.Top < work.Top then r.Offset(0, work.Top-r.Top);
  FWindow.FSide := side;
  FWindow.FArrowAt := if side in [tsBelow, tsAbove] then cx-r.Left else cy-r.Top;
  if (FWindow.BoundsRect <> r) or not FWindow.Visible then begin
    FWindow.SetBounds(r.Left, r.Top, r.Width, r.Height);
    // the window takes the shape of the card and the arrow, so the corners
    // show what lies under them
    var mask := autofree TBitmap.Create;
    mask.Monochrome := true;
    mask.SetSize(r.Width, r.Height);
    mask.Canvas.Brush.Color := clBlack;
    mask.Canvas.FillRect(0, 0, r.Width, r.Height);
    mask.Canvas.Brush.Color := clWhite;
    mask.Canvas.Pen.Color := clWhite;
    var card := Rect(0, 0, r.Width, r.Height);
    var radius := scaled(FWindow, FCornerRadius);
    match side of
      tsBelow: card.Top += arrow;
      tsAbove: card.Bottom -= arrow;
      tsRight: card.Left += arrow;
      tsLeft: card.Right -= arrow;
    end;
    mask.Canvas.RoundRect(card.Left, card.Top, card.Right, card.Bottom, radius*2, radius*2);
    var a := EnsureRange(FWindow.FArrowAt, radius+arrow, (if side in [tsBelow, tsAbove] then card.Width else card.Height)-radius-arrow);
    if side = tsBelow then mask.Canvas.Polygon([Point(card.Left+a-arrow, card.Top), Point(card.Left+a, 0), Point(card.Left+a+arrow, card.Top)])
    else if side = tsAbove then mask.Canvas.Polygon([Point(card.Left+a-arrow, card.Bottom-1), Point(card.Left+a, r.Height-1), Point(card.Left+a+arrow, card.Bottom-1)])
    else if side = tsRight then mask.Canvas.Polygon([Point(card.Left, card.Top+a-arrow), Point(0, card.Top+a), Point(card.Left, card.Top+a+arrow)])
    else if side = tsLeft then mask.Canvas.Polygon([Point(card.Right-1, card.Top+a-arrow), Point(r.Width-1, card.Top+a), Point(card.Right-1, card.Top+a+arrow)]);
    FWindow.SetShape(mask);
    FWindow.Invalidate;
  end;
  FLastAnchor := target;
end;

procedure TTourGuide.showStep(index: integer);
begin
  FCurrent := index;
  if FWindow = nil then begin
    FWindow := TTourWindow.Create(self);
    FWindow.FGuide := self;
    FWindow.FHot := -1;
    FWindow.Color := clWindow;
  end;
  var form := hostForm;
  if form <> nil then FWindow.Font := form.Font;
  place;
  if not FWindow.Visible then FWindow.Visible := true;
  FWindow.Invalidate;
  FTimer.Enabled := true;
  if Assigned(FOnStep) then FOnStep(self, index);
end;

// the callout follows its target: the form may move or resize
procedure TTourGuide.tick(Sender: TObject);
begin
  if not Active then begin
    FTimer.Enabled := false;
    exit;
  end;
  var step := FSteps[FCurrent];
  var form := hostForm;
  // the form went away or hid: the tour ends
  if (form = nil) or not form.Visible or ((step.Target <> nil) and not step.Target.IsVisible) then begin
    Skip;
    exit;
  end;
  if targetRect(step) <> FLastAnchor then place;
end;

// -- properties ----------------------

procedure TTourGuide.setSteps(value: TTourSteps);
begin
  FSteps.Assign(value);
end;

function TTourGuide.getMetric(index: integer): integer;
begin
  result := match index of
    0: FWidth;
    1: FCornerRadius;
    2: FArrowSize;
  else
    FPadding
  end;
end;

procedure TTourGuide.setMetric(index: integer; value: integer);
begin
  if index = 0 then value := Max(value, 120) else value := Max(value, 0);
  if getMetric(index) = value then exit;
  match index of
    0: FWidth := value;
    1: FCornerRadius := value;
    2: FArrowSize := value;
  else
    FPadding := value;
  end;
  if Active then place;
end;

function TTourGuide.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FSurfaceColor;
    1: FBorderColor;
    2: FAccentColor;
    3: FTitleColor;
  else
    FTextColor
  end;
end;

procedure TTourGuide.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FSurfaceColor := value;
    1: FBorderColor := value;
    2: FAccentColor := value;
    3: FTitleColor := value;
  else
    FTextColor := value;
  end;
  if FWindow <> nil then FWindow.Invalidate;
end;

end.
