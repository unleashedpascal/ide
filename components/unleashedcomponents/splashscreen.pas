{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit SplashScreen;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, ControlPaint;

type
  TSplashScreen = class;

  { TSplashView }

  // what the splash window shows: the picture, the texts and the bar
  TSplashView = class(TCustomControl)
  private
    FSplash: TSplashScreen;
    FBackdrop: TBitmap; // the picture fit to the view, darker at the bottom
    procedure buildBackdrop(back: TColor);
  protected
    procedure Paint; override;
  public
    constructor CreateFor(splash: TSplashScreen; aOwner: TComponent);
    destructor Destroy; override;
    procedure DropBackdrop;
  end;

  { TSplashScreen }

  // a borderless window in the middle of the screen while the application
  // starts: a picture, the name, a version line, a status line and a bar.
  // AutoShow opens it as the form holding it loads and closes it once the
  // application is idle and MinDisplayTime passed; Show and Close do it by hand
  TSplashScreen = class(TComponent)
  private
    FPicture: TPicture;
    FTitle, FSubtitle, FStatus: string;
    FProgress: integer;
    FShowProgress, FAutoShow, FFadeOut, FStayOnTop: boolean;
    FWidth, FHeight, FCornerRadius, FMinDisplayTime: integer;
    FBackColor, FTextColor, FAccentColor: TColor;
    FForm: TForm;
    FView: TSplashView;
    FShownAt: QWord;
    FFade, FPulse: TTimer;
    FPhase: integer;
    FWaitingIdle: boolean;
    FAntialiasing: TAntialiasSetting;
    FOnClose: TNotifyEvent;
    procedure setPicture(value: TPicture);
    procedure pictureChanged(Sender: TObject);
    procedure setStatus(const value: string);
    procedure setProgress(value: integer);
    procedure appIdle(Sender: TObject; var Done: boolean);
    procedure fadeTick(Sender: TObject);
    procedure pulseTick(Sender: TObject);
    procedure finish;
    procedure refresh;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Show;
    // closes now, with the fade when FadeOut is on
    procedure Close;
    // closes once the application is idle and MinDisplayTime passed
    procedure CloseWhenReady;
    function Showing: boolean;
  published
    // fills the window behind the texts, cut to fill it
    property Picture: TPicture read FPicture write setPicture;
    property Title: string read FTitle write FTitle;
    property Subtitle: string read FSubtitle write FSubtitle;
    // the line at the bottom; a change paints at once, also in busy code
    property Status: string read FStatus write setStatus;
    property ShowProgress: boolean read FShowProgress write FShowProgress default true;
    // 0 to 100; below 0 the bar runs without an end
    property Progress: integer read FProgress write setProgress default -1;
    property AutoShow: boolean read FAutoShow write FAutoShow default false;
    property FadeOut: boolean read FFadeOut write FFadeOut default true;
    property StayOnTop: boolean read FStayOnTop write FStayOnTop default true;
    property Width: integer read FWidth write FWidth default 480;
    property Height: integer read FHeight write FHeight default 280;
    property CornerRadius: integer read FCornerRadius write FCornerRadius default 10;
    // the window stays at least this many milliseconds
    property MinDisplayTime: integer read FMinDisplayTime write FMinDisplayTime default 1200;
    // clDefault takes the colors of the theme
    property BackColor: TColor read FBackColor write FBackColor default clDefault;
    property TextColor: TColor read FTextColor write FTextColor default clDefault;
    property AccentColor: TColor read FAccentColor write FAccentColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write FAntialiasing default asTheme;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
  end;

implementation

uses
  Math, IntfGraphics, FPImage;

{ TSplashView }

constructor TSplashView.CreateFor(splash: TSplashScreen; aOwner: TComponent);
begin
  inherited Create(aOwner);
  FSplash := splash;
  ControlStyle := ControlStyle+[csOpaque];
end;

destructor TSplashView.Destroy;
begin
  FBackdrop.Free;
  inherited Destroy;
end;

procedure TSplashView.DropBackdrop;
begin
  FreeAndNil(FBackdrop);
end;

// the middle of the picture in the proportions of the view, darkened toward
// the bottom so the texts read over any picture
procedure TSplashView.buildBackdrop(back: TColor);
begin
  var g := FSplash.FPicture.Graphic;
  var src := autofree TBitmap.Create;
  src.SetSize(Max(g.Width, 1), Max(g.Height, 1));
  src.Canvas.Brush.Color := back;
  src.Canvas.FillRect(0, 0, src.Width, src.Height);
  src.Canvas.Draw(0, 0, g);
  var part := Rect(0, 0, src.Width, src.Height);
  if src.Width*ClientHeight > src.Height*ClientWidth then begin
    var w := src.Height*ClientWidth div Max(ClientHeight, 1);
    part := Rect((src.Width-w) div 2, 0, (src.Width-w) div 2+w, src.Height);
  end else begin
    var h := src.Width*ClientHeight div Max(ClientWidth, 1);
    part := Rect(0, (src.Height-h) div 2, src.Width, (src.Height-h) div 2+h);
  end;
  FBackdrop := TBitmap.Create;
  FBackdrop.PixelFormat := pf24bit;
  FBackdrop.SetSize(ClientWidth, ClientHeight);
  FBackdrop.Canvas.CopyRect(Rect(0, 0, ClientWidth, ClientHeight), src.Canvas, part);
  var img := autofree FBackdrop.CreateIntfImage;
  var shadeH := Min(scaled(self, 110), ClientHeight);
  var top := ClientHeight-shadeH;
  for var y := top to ClientHeight-1 do begin
    var keep := 65535-(y-top)*40000 div Max(shadeH, 1);
    for var x := 0 to ClientWidth-1 do begin
      var c := img.Colors[x, y];
      c.Red := c.Red*keep div 65535;
      c.Green := c.Green*keep div 65535;
      c.Blue := c.Blue*keep div 65535;
      img.Colors[x, y] := c;
    end;
  end;
  FBackdrop.LoadFromIntfImage(img);
end;

procedure TSplashView.Paint;
begin
  var s := FSplash;
  var back := pick(s.FBackColor, clWindow);
  var text := pick(s.FTextColor, clWindowText);
  var accent := pick(s.FAccentColor, clHighlight);
  var hasPicture := (s.FPicture.Graphic <> nil) and not s.FPicture.Graphic.Empty;
  Canvas.Brush.Color := back;
  Canvas.FillRect(ClientRect);
  if hasPicture then begin
    if (FBackdrop = nil) or (FBackdrop.Width <> ClientWidth) or (FBackdrop.Height <> ClientHeight) then begin
      DropBackdrop;
      buildBackdrop(back);
    end;
    Canvas.Draw(0, 0, FBackdrop);
    text := clWhite;
  end;
  var pad := scaled(self, 24);
  var barH := scaled(self, 4);
  if s.FShowProgress then begin
    var track := Rect(0, ClientHeight-barH, ClientWidth, ClientHeight);
    Canvas.Brush.Color := blend(back, text, 12);
    Canvas.FillRect(track);
    Canvas.Brush.Color := accent;
    if s.FProgress >= 0 then
      Canvas.FillRect(0, track.Top, ClientWidth*Min(s.FProgress, 100) div 100, track.Bottom)
    else begin
      // a block runs along the track without an end
      var w := ClientWidth div 4;
      var x := (s.FPhase*ClientWidth div 60) mod (ClientWidth+w)-w;
      Canvas.FillRect(Max(x, 0), track.Top, Min(x+w, ClientWidth), track.Bottom);
    end;
  end;
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
  Canvas.Font := Font;
  var th := Canvas.TextHeight('Hg');
  var bottom := ClientHeight-pad-(if s.FShowProgress then barH else 0);
  if s.FStatus <> '' then begin
    Canvas.Font.Color := blend(if hasPicture then clBlack else back, text, 70);
    var r := Rect(pad, bottom-th, ClientWidth-pad, bottom);
    Canvas.TextRect(r, r.Left, r.Top, s.FStatus, style);
    bottom -= th+scaled(self, 10);
  end;
  if s.FSubtitle <> '' then begin
    Canvas.Font.Color := blend(if hasPicture then clBlack else back, text, 75);
    var r := Rect(pad, bottom-th, ClientWidth-pad, bottom);
    Canvas.TextRect(r, r.Left, r.Top, s.FSubtitle, style);
    bottom -= th+scaled(self, 2);
  end;
  if s.FTitle <> '' then begin
    Canvas.Font.Style := Font.Style+[fsBold];
    Canvas.Font.Height := -Round(th*1.8);
    Canvas.Font.Color := text;
    var tth := Canvas.TextHeight('Hg');
    var r := Rect(pad, bottom-tth, ClientWidth-pad, bottom);
    Canvas.TextRect(r, r.Left, r.Top, s.FTitle, style);
  end;
  Canvas.Font := Font;
  Canvas.Brush.Style := bsSolid;
end;

{ TSplashScreen }

constructor TSplashScreen.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPicture := TPicture.Create;
  FPicture.OnChange := @pictureChanged;
  FProgress := -1;
  FShowProgress := true;
  FFadeOut := true;
  FStayOnTop := true;
  FWidth := 480;
  FHeight := 280;
  FCornerRadius := 10;
  FMinDisplayTime := 1200;
  FBackColor := clDefault;
  FTextColor := clDefault;
  FAccentColor := clDefault;
  FTitle := Application.Title;
end;

destructor TSplashScreen.Destroy;
begin
  if FWaitingIdle then Application.RemoveOnIdleHandler(@appIdle);
  FreeAndNil(FForm);
  FPicture.Free;
  inherited Destroy;
end;

procedure TSplashScreen.Loaded;
begin
  inherited Loaded;
  if FAutoShow and not (csDesigning in ComponentState) then begin
    Show;
    CloseWhenReady;
  end;
end;

function TSplashScreen.Showing: boolean;
begin
  result := (FForm <> nil) and FForm.Visible;
end;

procedure TSplashScreen.Show;
begin
  if csDesigning in ComponentState then exit;
  if FForm = nil then begin
    FForm := TForm.CreateNew(nil);
    FForm.BorderStyle := bsNone;
    FForm.Position := poScreenCenter;
    FForm.ShowInTaskBar := stNever;
    FView := TSplashView.CreateFor(self, FForm);
    FView.Parent := FForm;
    FView.Align := alClient;
    FFade := TTimer.Create(FForm);
    FFade.Enabled := false;
    FFade.Interval := 16;
    FFade.OnTimer := @fadeTick;
    FPulse := TTimer.Create(FForm);
    FPulse.Enabled := false;
    FPulse.Interval := 30;
    FPulse.OnTimer := @pulseTick;
  end;
  FForm.FormStyle := if FStayOnTop then fsSystemStayOnTop else fsNormal;
  FForm.SetBounds(FForm.Left, FForm.Top, ControlPaint.scaled(FForm, FWidth), ControlPaint.scaled(FForm, FHeight));
  FForm.AlphaBlend := false;
  FForm.AlphaBlendValue := 255;
  FForm.Show;
  if FCornerRadius > 0 then begin
    var mask := autofree TBitmap.Create;
    mask.PixelFormat := pf24bit;
    mask.SetSize(FForm.Width, FForm.Height);
    mask.Canvas.Brush.Color := clBlack;
    mask.Canvas.FillRect(0, 0, mask.Width, mask.Height);
    mask.Canvas.Brush.Color := clWhite;
    mask.Canvas.Pen.Color := clWhite;
    var d := ControlPaint.scaled(FForm, FCornerRadius)*2;
    mask.Canvas.RoundRect(0, 0, mask.Width, mask.Height, d, d);
    FForm.SetShape(mask);
  end;
  FShownAt := GetTickCount64;
  FPulse.Enabled := FShowProgress and (FProgress < 0);
  refresh;
end;

// a change shows at once, as the code that starts the application seldom
// lets the messages run; the messages still have to run for the window
// systems that paint from their own loop only
procedure TSplashScreen.refresh;
begin
  if not Showing then exit;
  FView.Repaint;
  Application.ProcessMessages;
end;

procedure TSplashScreen.setPicture(value: TPicture);
begin
  FPicture.Assign(value);
end;

procedure TSplashScreen.pictureChanged(Sender: TObject);
begin
  if FView <> nil then FView.DropBackdrop;
  refresh;
end;

procedure TSplashScreen.setStatus(const value: string);
begin
  FStatus := value;
  refresh;
end;

procedure TSplashScreen.setProgress(value: integer);
begin
  FProgress := Min(value, 100);
  if FPulse <> nil then FPulse.Enabled := Showing and FShowProgress and (FProgress < 0);
  refresh;
end;

procedure TSplashScreen.pulseTick(Sender: TObject);
begin
  inc(FPhase);
  refresh;
end;

procedure TSplashScreen.CloseWhenReady;
begin
  if FWaitingIdle or not Showing then exit;
  FWaitingIdle := true;
  Application.AddOnIdleHandler(@appIdle);
end;

procedure TSplashScreen.appIdle(Sender: TObject; var Done: boolean);
begin
  if GetTickCount64-FShownAt < QWord(Max(FMinDisplayTime, 0)) then begin
    // the idle handler runs again only after a message; this keeps it coming
    Done := false;
    Sleep(10);
    exit;
  end;
  Application.RemoveOnIdleHandler(@appIdle);
  FWaitingIdle := false;
  Close;
end;

procedure TSplashScreen.Close;
begin
  if not Showing then exit;
  FPulse.Enabled := false;
  if FFadeOut then begin
    FForm.AlphaBlend := true;
    FFade.Enabled := true;
  end else finish;
end;

procedure TSplashScreen.fadeTick(Sender: TObject);
begin
  var value := FForm.AlphaBlendValue-24;
  if value <= 0 then begin
    FFade.Enabled := false;
    finish;
  end else FForm.AlphaBlendValue := value;
end;

procedure TSplashScreen.finish;
begin
  FForm.Hide;
  FForm.AlphaBlend := false;
  FForm.AlphaBlendValue := 255;
  if Assigned(FOnClose) then FOnClose(self);
end;

end.
