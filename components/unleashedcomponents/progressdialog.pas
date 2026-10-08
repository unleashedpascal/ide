{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit ProgressDialog;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, StdCtrls, ExtCtrls, ControlPaint;

type
  TProgressDialog = class;

  { TProgressView }

  // the message, the bar and the line with the time
  TProgressView = class(TCustomControl)
  private
    FDialog: TProgressDialog;
  protected
    procedure Paint; override;
  public
    constructor CreateFor(dialog: TProgressDialog; aOwner: TComponent);
  end;

  { TProgressDialog }

  // a window with a bar for work that takes a while, driven by the code
  // doing it: Start, then Position or Step as the work goes, then Finish.
  // Each update repaints the window and lets Cancel be clicked, so a loop
  // checks Cancelled. Work done before ShowDelay passes never shows a window
  TProgressDialog = class(TComponent)
  private
    FTitle, FMessage, FCancelCaption: string;
    FMax, FPosition, FShowDelay, FWidth: integer;
    FIndeterminate, FShowCancel, FShowTime, FShowPercent, FDisableForms: boolean;
    FAccentColor: TColor;
    FActive, FCancelled: boolean;
    FStarted, FLastPump: QWord;
    FForm: TForm;
    FView: TProgressView;
    FCancel: TButton;
    FPulse: TTimer;
    FPhase: integer;
    FDisabled: TList;
    FAntialiasing: TAntialiasSetting;
    FOnCancel: TNotifyEvent;
    procedure setMessage(const value: string);
    procedure setPosition(value: integer);
    procedure setIndeterminate(value: boolean);
    procedure cancelClick(Sender: TObject);
    procedure formCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure pulseTick(Sender: TObject);
    procedure update(force: boolean);
    procedure showWindow;
    function timeText: string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start(const message: string = '');
    procedure Step(delta: integer = 1);
    procedure Finish;
    // what the Cancel button does
    procedure Cancel;
    property Active: boolean read FActive;
    property Cancelled: boolean read FCancelled;
  published
    property Title: string read FTitle write FTitle;
    property Message: string read FMessage write setMessage;
    property Max: integer read FMax write FMax default 100;
    property Position: integer read FPosition write setPosition default 0;
    // a bar without an end, for work of an unknown length
    property Indeterminate: boolean read FIndeterminate write setIndeterminate default false;
    property ShowCancel: boolean read FShowCancel write FShowCancel default true;
    property CancelCaption: string read FCancelCaption write FCancelCaption;
    // the time gone and the time left, from the pace so far
    property ShowTime: boolean read FShowTime write FShowTime default true;
    property ShowPercent: boolean read FShowPercent write FShowPercent default true;
    // the other windows of the application wait while the dialog shows
    property DisableForms: boolean read FDisableForms write FDisableForms default true;
    // milliseconds of work before the window shows
    property ShowDelay: integer read FShowDelay write FShowDelay default 400;
    property Width: integer read FWidth write FWidth default 420;
    // clDefault takes the color of the theme
    property AccentColor: TColor read FAccentColor write FAccentColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write FAntialiasing default asTheme;
    property OnCancel: TNotifyEvent read FOnCancel write FOnCancel;
  end;

implementation

uses
  Math;

{ TProgressView }

constructor TProgressView.CreateFor(dialog: TProgressDialog; aOwner: TComponent);
begin
  inherited Create(aOwner);
  FDialog := dialog;
  ControlStyle := ControlStyle+[csOpaque];
end;

procedure TProgressView.Paint;
begin
  var d := FDialog;
  var back := ColorToRGB(clBtnFace);
  var text := ColorToRGB(clWindowText);
  var accent := pick(d.FAccentColor, clHighlight);
  var pad := scaled(self, 16);
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  var barTop := pad+th+scaled(self, 10);
  var barH := scaled(self, 8);
  var track := Rect(pad, barTop, ClientWidth-pad, barTop+barH);
  var sp := autofree beginShapes(Canvas, ClientRect, back, d.FAntialiasing);
  paintRoundRect(sp, track, barH div 2, blend(back, text, 14), clNone);
  if d.FIndeterminate then begin
    // a block runs along the track without an end
    var w := track.Width div 4;
    var x := track.Left+(d.FPhase*track.Width div 50) mod (track.Width+w)-w;
    var block := Rect(Max(x, track.Left), track.Top, Min(x+w, track.Right), track.Bottom);
    if block.Width > 0 then paintRoundRect(sp, block, barH div 2, accent, clNone);
  end else if d.FMax > 0 then begin
    var done := Rect(track.Left, track.Top, track.Left+track.Width*EnsureRange(d.FPosition, 0, d.FMax) div d.FMax, track.Bottom);
    if done.Width > 0 then paintRoundRect(sp, done, barH div 2, accent, clNone);
  end;
  sp.Flush;
  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlTop;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  Canvas.Font.Color := text;
  var r := Rect(pad, pad, ClientWidth-pad, pad+th);
  Canvas.TextRect(r, r.Left, r.Top, d.FMessage, style);
  // the percent at the right, the time at the left under the bar
  var lineTop := track.Bottom+scaled(self, 8);
  Canvas.Font.Color := blend(back, text, 65);
  if d.FShowTime then begin
    r := Rect(pad, lineTop, ClientWidth-pad, lineTop+th);
    Canvas.TextRect(r, r.Left, r.Top, d.timeText, style);
  end;
  if d.FShowPercent and not d.FIndeterminate and (d.FMax > 0) then begin
    style.Alignment := taRightJustify;
    r := Rect(pad, lineTop, ClientWidth-pad, lineTop+th);
    Canvas.TextRect(r, r.Left, r.Top, Format('%d%%', [EnsureRange(d.FPosition, 0, d.FMax)*100 div d.FMax]), style);
  end;
  Canvas.Brush.Style := bsSolid;
end;

{ TProgressDialog }

constructor TProgressDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTitle := 'Working';
  FCancelCaption := 'Cancel';
  FMax := 100;
  FShowCancel := true;
  FShowTime := true;
  FShowPercent := true;
  FDisableForms := true;
  FShowDelay := 400;
  FWidth := 420;
  FAccentColor := clDefault;
end;

destructor TProgressDialog.Destroy;
begin
  Finish;
  FreeAndNil(FForm);
  inherited Destroy;
end;

function duration(ms: QWord): string;
begin
  var s := ms div 1000;
  result := if s >= 3600 then Format('%d:%.2d:%.2d', [s div 3600, s div 60 mod 60, s mod 60]) else Format('%d:%.2d', [s div 60, s mod 60]);
end;

function TProgressDialog.timeText: string;
begin
  var gone := GetTickCount64-FStarted;
  result := duration(gone)+' elapsed';
  // the estimate waits for a second of work and a first step
  if not FIndeterminate and (FPosition > 0) and (FPosition < FMax) and (gone >= 1000) then
    result += ', about '+duration(gone*QWord(FMax-FPosition) div QWord(FPosition))+' left';
end;

procedure TProgressDialog.Start(const message: string);
begin
  if csDesigning in ComponentState then exit;
  if message <> '' then FMessage := message;
  FPosition := 0;
  FCancelled := false;
  FActive := true;
  FStarted := GetTickCount64;
  FLastPump := 0;
  if FShowDelay <= 0 then showWindow;
  update(true);
end;

procedure TProgressDialog.showWindow;
begin
  if FForm = nil then begin
    FForm := TForm.CreateNew(nil);
    FForm.BorderStyle := bsDialog;
    FForm.BorderIcons := [biSystemMenu];
    FForm.OnCloseQuery := @formCloseQuery;
    FView := TProgressView.CreateFor(self, FForm);
    FView.Parent := FForm;
    FView.Align := alClient;
    FCancel := TButton.Create(FForm);
    FCancel.Parent := FForm;
    FCancel.OnClick := @cancelClick;
    FCancel.Cancel := true;
    FPulse := TTimer.Create(FForm);
    FPulse.Enabled := false;
    FPulse.Interval := 30;
    FPulse.OnTimer := @pulseTick;
  end;
  FForm.Caption := FTitle;
  FCancel.Caption := FCancelCaption;
  FCancel.Visible := FShowCancel;
  FCancel.Enabled := true;
  var host := if Owner is TControl then GetParentForm(TControl(Owner)) else Screen.ActiveCustomForm;
  if host <> nil then begin
    FForm.PopupMode := pmExplicit;
    FForm.PopupParent := host;
    FForm.Position := poOwnerFormCenter;
  end else FForm.Position := poScreenCenter;
  FView.Canvas.Font := FView.Font;
  var th := FView.Canvas.TextHeight('Hg');
  var pad := ControlPaint.scaled(FForm, 16);
  var buttonH := if FShowCancel then FCancel.Height+pad else 0;
  FForm.ClientWidth := ControlPaint.scaled(FForm, FWidth);
  FForm.ClientHeight := pad+th+ControlPaint.scaled(FForm, 18)+ControlPaint.scaled(FForm, 8)+(if FShowTime or FShowPercent then th else 0)+pad+buttonH;
  if FShowCancel then FCancel.SetBounds(FForm.ClientWidth-pad-FCancel.Width, FForm.ClientHeight-pad-FCancel.Height, FCancel.Width, FCancel.Height);
  FCancel.BringToFront;
  FForm.Show;
  if FDisableForms then FDisabled := Screen.DisableForms(FForm);
  FPulse.Enabled := FIndeterminate;
end;

// a repaint and a turn of the messages, at most every 30 ms unless forced
procedure TProgressDialog.update(force: boolean);
begin
  if not FActive then exit;
  var now := GetTickCount64;
  if not force and (now-FLastPump < 30) then exit;
  FLastPump := now;
  if ((FForm = nil) or not FForm.Visible) and (now-FStarted >= QWord(Math.Max(FShowDelay, 0))) then showWindow;
  if (FForm <> nil) and FForm.Visible then begin
    FView.Repaint;
    Application.ProcessMessages;
  end;
end;

procedure TProgressDialog.Step(delta: integer);
begin
  setPosition(FPosition+delta);
end;

procedure TProgressDialog.setPosition(value: integer);
begin
  FPosition := value;
  update(false);
end;

procedure TProgressDialog.setMessage(const value: string);
begin
  FMessage := value;
  update(true);
end;

procedure TProgressDialog.setIndeterminate(value: boolean);
begin
  FIndeterminate := value;
  if FPulse <> nil then FPulse.Enabled := value and FActive;
  update(true);
end;

procedure TProgressDialog.pulseTick(Sender: TObject);
begin
  inc(FPhase);
  if FView <> nil then FView.Invalidate;
end;

procedure TProgressDialog.Cancel;
begin
  if not FActive or FCancelled then exit;
  FCancelled := true;
  if FCancel <> nil then FCancel.Enabled := false;
  if Assigned(FOnCancel) then FOnCancel(self);
end;

procedure TProgressDialog.cancelClick(Sender: TObject);
begin
  Cancel;
end;

// the close button of the window cancels; the code doing the work closes it
procedure TProgressDialog.formCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if FActive then begin
    Cancel;
    CanClose := false;
  end;
end;

procedure TProgressDialog.Finish;
begin
  if not FActive then exit;
  FActive := false;
  if FPulse <> nil then FPulse.Enabled := false;
  if FDisabled <> nil then Screen.EnableForms(FDisabled);
  if (FForm <> nil) and FForm.Visible then FForm.Hide;
end;

end.
