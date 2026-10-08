{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit OverlayPanel;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ExtCtrls, ControlPaint;

type
  { TOverlayPanel }

  // a veil over its parent while something runs: Active covers the whole
  // parent, dims it, shows a spinner and the caption, and keeps the mouse
  // from what is underneath. Inactive, it is out of the way
  TOverlayPanel = class(TCustomControl)
  private
    FActive, FShowSpinner, FDimmed: boolean;
    FDimPercent, FSpinnerSize, FThickness, FSpacing, FSpeed: integer;
    FPhase: integer;
    FTimer: TTimer;
    FVeilColor, FSpinnerColor, FTextColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FOnActivate, FOnDeactivate: TNotifyEvent;
    procedure setActive(value: boolean);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure tick(Sender: TObject);
    procedure cover;
    procedure syncTimer;
  protected
    procedure Paint; override;
    procedure Loaded; override;
    procedure SetParent(NewParent: TWinControl); override;
    procedure TextChanged; override;
    procedure VisibleChanged; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the veil up with this text
    procedure Show(const text: string = '');
    procedure Hide;
  published
    property Caption;
    property Active: boolean read FActive write setActive default false;
    property ShowSpinner: boolean index 0 read getFlag write setFlag default true;
    // the veil darkens what it covers; off, it only takes the mouse
    property Dimmed: boolean index 1 read getFlag write setFlag default true;
    // the share of the veil color laid over the parent color
    property DimPercent: integer index 0 read getMetric write setMetric default 55;
    property SpinnerSize: integer index 1 read getMetric write setMetric default 40;
    property Thickness: integer index 2 read getMetric write setMetric default 4;
    // between the spinner and the caption
    property Spacing: integer index 3 read getMetric write setMetric default 12;
    // steps of a turn of the spinner; fewer steps turn faster
    property Speed: integer index 4 read getMetric write setMetric default 24;
    // clDefault takes the colors of the theme
    property VeilColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property SpinnerColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write FOnDeactivate;
    property Font;
    property ParentFont;
    property OnClick;
    property OnMouseDown;
    property OnMouseUp;
  end;

implementation

uses
  Math;

constructor TOverlayPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csSetCaption, csNoFocus]-[csAcceptsControls];
  TabStop := false;
  FShowSpinner := true;
  FDimmed := true;
  FDimPercent := 55;
  FSpinnerSize := 40;
  FThickness := 4;
  FSpacing := 12;
  FSpeed := 24;
  FVeilColor := clDefault;
  FSpinnerColor := clDefault;
  FTextColor := clDefault;
  FAntialiasing := asTheme;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 40;
  FTimer.OnTimer := @tick;
  // the control stays visible at design time, with its own bounds
  Visible := false;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TOverlayPanel.GetControlClassDefaultSize: TSize;
begin
  result.cx := 120;
  result.cy := 80;
end;

// -- the veil ----------------------

procedure TOverlayPanel.Show(const text: string);
begin
  if text <> '' then Caption := text;
  Active := true;
end;

procedure TOverlayPanel.Hide;
begin
  Active := false;
end;

procedure TOverlayPanel.setActive(value: boolean);
begin
  if FActive = value then exit;
  FActive := value;
  cover;
  if csLoading in ComponentState then exit;
  if FActive then begin
    if Assigned(FOnActivate) then FOnActivate(self);
  end else if Assigned(FOnDeactivate) then FOnDeactivate(self);
end;

// active, the panel fills its parent on top of everything
procedure TOverlayPanel.cover;
begin
  if csDesigning in ComponentState then begin
    Visible := true;
    exit;
  end;
  if FActive then begin
    Align := alClient;
    Visible := true;
    BringToFront;
  end else begin
    Visible := false;
    Align := alNone;
  end;
  syncTimer;
  Invalidate;
end;

procedure TOverlayPanel.syncTimer;
begin
  FTimer.Enabled := FActive and FShowSpinner and Visible and not (csDesigning in ComponentState) and not (csLoading in ComponentState);
end;

procedure TOverlayPanel.tick(Sender: TObject);
begin
  inc(FPhase);
  if FPhase >= 100000 then FPhase := 0;
  Invalidate;
end;

procedure TOverlayPanel.Loaded;
begin
  inherited Loaded;
  cover;
end;

procedure TOverlayPanel.SetParent(NewParent: TWinControl);
begin
  inherited SetParent(NewParent);
  if (NewParent <> nil) and not (csLoading in ComponentState) then cover;
end;

procedure TOverlayPanel.VisibleChanged;
begin
  inherited VisibleChanged;
  syncTimer;
end;

procedure TOverlayPanel.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

// -- painting ----------------------

procedure TOverlayPanel.Paint;
begin
  var under := GetRGBColorResolvingParent;
  var veil := pick(FVeilColor, (if isDark(under) then clBlack else clWhite));
  var back := if FDimmed then blend(under, veil, FDimPercent) else under;
  var accent := pick(FSpinnerColor, clHighlight);
  var text := pick(FTextColor, (if isDark(back) then clWhite else clBlack));
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  paintRoundRect(sp, ClientRect, 0, back, clNone);
  var size := scaled(self, FSpinnerSize);
  var textH := if Caption <> '' then Canvas.TextHeight('Hg') else 0;
  var gap := if (Caption <> '') and FShowSpinner then scaled(self, FSpacing) else 0;
  var total := (if FShowSpinner then size else 0)+gap+textH;
  var top := (ClientHeight-total) div 2;
  if FShowSpinner then begin
    var box := Rect((ClientWidth-size) div 2, top, (ClientWidth+size) div 2, top+size);
    var thick := Max(scaled(self, FThickness), 1);
    paintArc(sp, box, 0, 360, blend(back, accent, 25), thick, true);
    var steps := Max(FSpeed, 4);
    var start := 90-Round((FPhase mod steps)/steps*360);
    paintArc(sp, box, start, -100, accent, thick, true);
    top += size+gap;
  end;
  sp.Flush;
  if Caption <> '' then begin
    applyTextQuality(Canvas);
    paintCenteredText(Canvas, Rect(0, top, ClientWidth, top+textH), Caption, text);
  end;
end;

// -- properties ----------------------

function TOverlayPanel.getFlag(index: integer): boolean;
begin
  result := if index = 0 then FShowSpinner else FDimmed;
end;

procedure TOverlayPanel.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  if index = 0 then FShowSpinner := value else FDimmed := value;
  syncTimer;
  Invalidate;
end;

function TOverlayPanel.getMetric(index: integer): integer;
begin
  result := match index of
    0: FDimPercent;
    1: FSpinnerSize;
    2: FThickness;
    3: FSpacing;
  else
    FSpeed
  end;
end;

procedure TOverlayPanel.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index = 0 then value := Min(value, 100);
  if getMetric(index) = value then exit;
  match index of
    0: FDimPercent := value;
    1: FSpinnerSize := value;
    2: FThickness := value;
    3: FSpacing := value;
  else
    FSpeed := value;
  end;
  Invalidate;
end;

function TOverlayPanel.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FVeilColor;
    1: FSpinnerColor;
  else
    FTextColor
  end;
end;

procedure TOverlayPanel.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FVeilColor := value;
    1: FSpinnerColor := value;
  else
    FTextColor := value;
  end;
  Invalidate;
end;

procedure TOverlayPanel.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
