{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PageView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, ControlPaint;

type
  { TPageSheet }

  // a page of a TPageView: a plain panel the view keeps at its client area,
  // shown only while it is the page of the view, in the designer too
  TPageSheet = class(TCustomPanel)
  public
    constructor Create(AOwner: TComponent); override;
  published
    property BevelColor;
    property BevelInner;
    property BevelOuter default bvNone;
    property BevelWidth;
    property BorderWidth;
    property ChildSizing;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Enabled;
    property Font;
    property Height stored false;
    property Left stored false;
    property ParentBackground;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property Top stored false;
    property Width stored false;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnPaint;
    property OnResize;
  end;

  { TPageView }

  // shows one of its children at a time, filling its whole area: the page
  // PageIndex names. The others stay hidden, in the designer too, where
  // selecting a page in the Object Inspector brings it up. There are no tabs:
  // code, a TTabStrip, a TSegmentedControl or a timer picks the page
  TPageView = class(TCustomControl)
  private
    FPageIndex: integer;
    FLaying: boolean;
    FOnPageChange: TNotifyEvent;
    procedure setPageIndex(value: integer);
    function getPage(index: integer): TControl;
    function getActivePage: TControl;
    procedure setActivePage(value: TControl);
    procedure layout;
  protected
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    procedure Paint; override;
    procedure Loaded; override;
    procedure InsertControl(AControl: TControl; Index: integer); override;
    procedure RemoveControl(AControl: TControl); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // the page holding AControl comes up; the designer calls it for a selection
    procedure ShowControl(AControl: TControl); override;
    function PageCount: integer;
    // past the last page comes the first
    procedure NextPage;
    procedure PreviousPage;
    // the page shown; nil while there is none
    property ActivePage: TControl read getActivePage write setActivePage;
    // the children in their order
    property Pages[index: integer]: TControl read getPage;
  published
    // the page shown, from 0; -1 shows none
    property PageIndex: integer read FPageIndex write setPageIndex default 0;
    property OnPageChange: TNotifyEvent read FOnPageChange write FOnPageChange;
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
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnResize;
  end;

implementation

uses
  Math;

{ TPageSheet }

constructor TPageSheet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // the view places it, the designer neither moves it nor shows it hidden;
  // no caption, so nothing is painted over the children
  ControlStyle := ControlStyle+[csNoDesignVisible, csDesignFixedBounds]-[csSetCaption];
  BevelOuter := bvNone;
end;

{ TPageView }

constructor TPageView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csAcceptsControls, csOpaque, csNoFocus]-[csSetCaption];
  TabStop := false;
  ParentColor := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

class function TPageView.GetControlClassDefaultSize: TSize;
begin
  result.cx := 320;
  result.cy := 200;
end;

function TPageView.PageCount: integer;
begin
  result := ControlCount;
end;

function TPageView.getPage(index: integer): TControl;
begin
  result := Controls[index];
end;

function TPageView.getActivePage: TControl;
begin
  result := if (FPageIndex >= 0) and (FPageIndex < ControlCount) then Controls[FPageIndex] else nil;
end;

procedure TPageView.setActivePage(value: TControl);
begin
  var i := GetControlIndex(value);
  if i >= 0 then PageIndex := i;
end;

procedure TPageView.setPageIndex(value: integer);
begin
  if csLoading in ComponentState then begin
    FPageIndex := value;
    exit;
  end;
  value := EnsureRange(value, -1, ControlCount-1);
  if value = FPageIndex then exit;
  FPageIndex := value;
  layout;
  if Assigned(FOnPageChange) then FOnPageChange(self);
end;

procedure TPageView.NextPage;
begin
  if ControlCount > 0 then PageIndex := (FPageIndex+1) mod ControlCount;
end;

procedure TPageView.PreviousPage;
begin
  if ControlCount = 0 then exit;
  PageIndex := if FPageIndex <= 0 then ControlCount-1 else FPageIndex-1;
end;

procedure TPageView.ShowControl(AControl: TControl);
begin
  setActivePage(AControl);
  inherited ShowControl(AControl);
end;

// -- the pages ----------------------

// the page of PageIndex at the client area and shown, the others hidden
procedure TPageView.layout;
begin
  if FLaying or (csLoading in ComponentState) or (csDestroying in ComponentState) then exit;
  FLaying := true;
  try
    var r := ClientRect;
    for var i := 0 to ControlCount-1 do begin
      var c := Controls[i];
      var shown := i = FPageIndex;
      // only a real change goes through, a repeat would realign forever
      if shown and (c.BoundsRect <> r) then c.BoundsRect := r;
      if c.Visible <> shown then c.Visible := shown;
    end;
  finally
    FLaying := false;
  end;
end;

procedure TPageView.AlignControls(AControl: TControl; var ARect: TRect);
begin
  layout;
end;

procedure TPageView.Loaded;
begin
  inherited Loaded;
  layout;
end;

procedure TPageView.InsertControl(AControl: TControl; Index: integer);
begin
  // any child is a page: hidden while not shown, in the designer too, and
  // not moved there by hand
  AControl.ControlStyle := AControl.ControlStyle+[csNoDesignVisible, csDesignFixedBounds];
  inherited InsertControl(AControl, Index);
  if csLoading in ComponentState then exit;
  // the first page comes up by itself
  if (FPageIndex < 0) and (ControlCount = 1) then FPageIndex := 0;
  layout;
end;

procedure TPageView.RemoveControl(AControl: TControl);
begin
  var i := GetControlIndex(AControl);
  inherited RemoveControl(AControl);
  if not (AControl is TPageSheet) then AControl.ControlStyle := AControl.ControlStyle-[csNoDesignVisible, csDesignFixedBounds];
  if (i < 0) or (csDestroying in ComponentState) then exit;
  // the pages after the one gone move up: the same page stays shown, or the
  // one now at its index when it was the page shown
  if i < FPageIndex then dec(FPageIndex)
  else if i = FPageIndex then begin
    FPageIndex := Min(FPageIndex, ControlCount-1);
    layout;
    if Assigned(FOnPageChange) then FOnPageChange(self);
    exit;
  end;
  layout;
end;

// -- painting ----------------------

procedure TPageView.Paint;
begin
  var back := GetRGBColorResolvingParent;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := back;
  Canvas.FillRect(ClientRect);
  if not (csDesigning in ComponentState) or (ControlCount > 0) then exit;
  // an empty view shows where it is and how a page comes
  Canvas.Pen.Color := blend(back, clWindowText, 25);
  Canvas.Pen.Style := psDot;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(ClientRect);
  Canvas.Pen.Style := psSolid;
  applyTextQuality(Canvas);
  Canvas.Font := Font;
  paintCenteredText(Canvas, ClientRect, 'No pages yet: right-click, Add Page', blend(back, clWindowText, 55));
end;

end.
