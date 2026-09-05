{ SPDX-FileCopyrightText: 2026 Unleashed Pascal Team <https://unleashedpascal.org>
  SPDX-License-Identifier: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below.

  Unleashed Form Placer: desktop map control.

  A small owner-drawn miniature of the desktop, shown in the corner of the
  docked form designer. It draws every monitor and the designed form as
  scaled rectangles; dragging the form rectangle (or nudging it with the
  arrow keys) updates the real Left/Top of the designed form. }

unit FormPlacerMap;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF Windows}Windows,{$ENDIF}
  Classes, SysUtils, Math, fgl, TypInfo,
  // LCL
  LCLType, LCLIntf, Controls, Forms, Graphics, Menus,
  // IdeIntf
  FormEditingIntf, PropEdits,
  // DockedFormEditor
  DockedDesignForm, DockedResizer,
  // UnleashedFormplacer
  FormPlacerConfig, FormPlacerStrings;

type

  { TFormPlacerMap }

  TFormPlacerMap = class(TCustomControl)
  private
    FDesignForm: TDesignForm;
    FTrackedForm: TCustomForm;
    FDragging: Boolean;
    FDragOffset: TPoint;     // map px: cursor to form rect top left
    FPendingPos: TPoint;     // desktop px: position while dragging
    FApplying: Boolean;
    FShownPosition: TPosition; // Position the map was last painted for
    FMenu: TPopupMenu;
    FMenuPosition: TMenuItem;
    FMenuCenter: TMenuItem;
    FOnOpenOptions: TNotifyEvent;
    function  DesktopArea: TRect;
    function  MapScale: Double;
    function  DesktopToMap(const P: TPoint): TPoint;
    function  MapToDesktop(const P: TPoint): TPoint;
    function  FormDesktopPos: TPoint;
    function  FormRectOnMap: TRect;
    function  CanPlace: Boolean;
    function  CenteredPos: TPoint;
    procedure SetDesignedPosition;
    procedure ApplyPosition(ALeft, ATop: Integer);
    procedure MarkModified;
    procedure ClampToDesktop(var P: TPoint);
    procedure TrackForm(AForm: TCustomForm);
    procedure FormBoundsChanged(Sender: TObject);
    procedure MenuPopup(Sender: TObject);
    procedure MenuPositionClick(Sender: TObject);
    procedure MenuCenterClick(Sender: TObject);
    procedure MenuHideClick(Sender: TObject);
    procedure MenuOptionsClick(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BindDesignForm(ADesignForm: TDesignForm);
    procedure ApplyOptions;
    property OnOpenOptions: TNotifyEvent read FOnOpenOptions write FOnOpenOptions;
  end;

  TFormPlacerMaps = specialize TFPGList<TFormPlacerMap>;

var
  PlacerMaps: TFormPlacerMaps = nil;

procedure ApplyOptionsToAllMaps;

implementation

procedure ApplyOptionsToAllMaps;
var
  LMap: TFormPlacerMap;
begin
  if PlacerMaps = nil then Exit;
  for LMap in PlacerMaps do
    LMap.ApplyOptions;
end;

{ TFormPlacerMap }

constructor TFormPlacerMap.Create(AOwner: TComponent);

  function AddItem(const ACaption: String; AHandler: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(FMenu);
    Result.Caption := ACaption;
    Result.OnClick := AHandler;
    FMenu.Items.Add(Result);
  end;

  // one radio item per TPosition value, captioned like the Object Inspector
  procedure AddPositionItems;
  var
    LPos: TPosition;
    LItem: TMenuItem;
  begin
    for LPos := Low(TPosition) to High(TPosition) do
    begin
      LItem := TMenuItem.Create(FMenu);
      LItem.Caption := GetEnumName(TypeInfo(TPosition), Ord(LPos));
      LItem.Tag := Ord(LPos);
      LItem.RadioItem := True;
      LItem.GroupIndex := 1;
      LItem.OnClick := @MenuPositionClick;
      FMenuPosition.Add(LItem);
    end;
  end;

begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  TabStop := True;
  ShowHint := True;
  Hint := SPlacerMapHint;

  FMenu := TPopupMenu.Create(Self);
  FMenu.OnPopup := @MenuPopup;
  FMenuPosition := AddItem(SPlacerMenuPosition, nil);
  AddPositionItems;
  FMenuCenter := AddItem(SPlacerMenuCenter, @MenuCenterClick);
  AddItem('-', nil);
  AddItem(SPlacerMenuHide, @MenuHideClick);
  AddItem(SPlacerMenuOptions, @MenuOptionsClick);
  PopupMenu := FMenu;

  PlacerMaps.Add(Self);
  ApplyOptions;
end;

destructor TFormPlacerMap.Destroy;
begin
  TrackForm(nil);
  if Assigned(PlacerMaps) then
    PlacerMaps.Remove(Self);
  inherited Destroy;
end;

function TFormPlacerMap.DesktopArea: TRect;
var
  i: Integer;
begin
  Result := Screen.Monitors[0].BoundsRect;
  for i := 1 to Screen.MonitorCount - 1 do
    UnionRect(Result, Result, Screen.Monitors[i].BoundsRect);
  if (Result.Width <= 0) or (Result.Height <= 0) then
    Result := Rect(0, 0, Screen.Width, Screen.Height);
end;

function TFormPlacerMap.MapScale: Double;
var
  LArea: TRect;
begin
  LArea := DesktopArea;
  Result := (ClientWidth - 2) / Max(LArea.Width, 1);
end;

function TFormPlacerMap.DesktopToMap(const P: TPoint): TPoint;
var
  LArea: TRect;
  LScale: Double;
begin
  LArea := DesktopArea;
  LScale := MapScale;
  Result.X := 1 + Round((P.X - LArea.Left) * LScale);
  Result.Y := 1 + Round((P.Y - LArea.Top) * LScale);
end;

function TFormPlacerMap.MapToDesktop(const P: TPoint): TPoint;
var
  LArea: TRect;
  LScale: Double;
begin
  LArea := DesktopArea;
  LScale := MapScale;
  Result.X := LArea.Left + Round((P.X - 1) / LScale);
  Result.Y := LArea.Top + Round((P.Y - 1) / LScale);
end;

function TFormPlacerMap.CanPlace: Boolean;
begin
  Result := Assigned(FDesignForm) and Assigned(FTrackedForm)
        and not (FTrackedForm is TNonFormProxyDesignerForm);
end;

const
  // Position values that center the window at run time; the map previews
  // them centered instead of at Left/Top
  CenteredPositions = [poScreenCenter, poDesktopCenter, poMainFormCenter,
                       poOwnerFormCenter, poWorkAreaCenter];

function TFormPlacerMap.CenteredPos: TPoint;
var
  LArea: TRect;
begin
  case FTrackedForm.Position of
    poDesktopCenter:  LArea := DesktopArea;
    poWorkAreaCenter: LArea := Screen.PrimaryMonitor.WorkareaRect;
  else
    LArea := Screen.PrimaryMonitor.BoundsRect;
  end;
  Result.X := LArea.Left + (LArea.Width - FTrackedForm.Width) div 2;
  Result.Y := LArea.Top + (LArea.Height - FTrackedForm.Height) div 2;
end;

function TFormPlacerMap.FormDesktopPos: TPoint;
begin
  if FDragging then
    Result := FPendingPos
  else if not Assigned(FTrackedForm) then
    Result := Point(0, 0)
  else if FTrackedForm.Position in CenteredPositions then
    Result := CenteredPos
  else
    Result := Point(FTrackedForm.Left, FTrackedForm.Top);
end;

// Placing the form by hand only makes sense with an explicit position
procedure TFormPlacerMap.SetDesignedPosition;
begin
  if not CanPlace then Exit;
  if FTrackedForm.Position = poDesigned then Exit;
  FTrackedForm.Position := poDesigned;
  Invalidate;
end;

function TFormPlacerMap.FormRectOnMap: TRect;
var
  LPos, LTopLeft: TPoint;
  LScale: Double;
begin
  LPos := FormDesktopPos;
  LTopLeft := DesktopToMap(LPos);
  LScale := MapScale;
  Result.Left := LTopLeft.X;
  Result.Top := LTopLeft.Y;
  Result.Right := LTopLeft.X + Max(4, Round(FTrackedForm.Width * LScale));
  Result.Bottom := LTopLeft.Y + Max(4, Round(FTrackedForm.Height * LScale));
end;

procedure TFormPlacerMap.ClampToDesktop(var P: TPoint);
var
  LArea: TRect;
begin
  LArea := DesktopArea;
  P.X := EnsureRange(P.X, LArea.Left, Max(LArea.Left, LArea.Right - 50));
  P.Y := EnsureRange(P.Y, LArea.Top, Max(LArea.Top, LArea.Bottom - 50));
end;

procedure TFormPlacerMap.ApplyPosition(ALeft, ATop: Integer);
var
  LResizer: TResizer;
  LLockHandle: HWND;
begin
  if not CanPlace then Exit;
  if FApplying then Exit;
  SetDesignedPosition;
  if (FTrackedForm.Left = ALeft) and (FTrackedForm.Top = ATop) then Exit;
  if Owner is TResizer then
    LResizer := TResizer(Owner)
  else
    LResizer := nil;

  // The docked editor hosts the form in a container that compensates the
  // form's Left/Top, and realigns that container from a timer. The form
  // must not move on screen at all: hold the editor's deferred handling,
  // realign right away and keep the whole resizer from painting until
  // both windows have been moved.
  LLockHandle := 0;
  {$IFDEF Windows}
  if Assigned(LResizer) and LResizer.HandleAllocated then
  begin
    LLockHandle := LResizer.Handle;
    Windows.SendMessage(LLockHandle, WM_SETREDRAW, 0, 0);
  end;
  {$ENDIF}
  FApplying := True;
  try
    FDesignForm.BeginUpdate;
    try
      FTrackedForm.SetBounds(ALeft, ATop, FTrackedForm.Width, FTrackedForm.Height);
    finally
      FDesignForm.EndUpdate;
    end;
    if Assigned(LResizer) then
      LResizer.AdjustResizer(nil);
  finally
    FApplying := False;
    {$IFDEF Windows}
    if LLockHandle <> 0 then
    begin
      Windows.SendMessage(LLockHandle, WM_SETREDRAW, 1, 0);
      LCLIntf.RedrawWindow(LLockHandle, nil, 0,
        RDW_INVALIDATE or RDW_ALLCHILDREN or RDW_NOERASE or RDW_UPDATENOW);
    end;
    {$ENDIF}
  end;
  Invalidate;
end;

procedure TFormPlacerMap.MarkModified;
begin
  if not CanPlace then Exit;
  if Assigned(FTrackedForm.Designer) then
    FTrackedForm.Designer.Modified;
  GlobalDesignHook.RefreshPropertyValues;
end;

procedure TFormPlacerMap.TrackForm(AForm: TCustomForm);
begin
  if FTrackedForm = AForm then Exit;
  if Assigned(FTrackedForm) then
  begin
    FTrackedForm.RemoveHandlerOnChangeBounds(@FormBoundsChanged);
    FTrackedForm.RemoveFreeNotification(Self);
  end;
  FTrackedForm := AForm;
  if Assigned(FTrackedForm) then
  begin
    FTrackedForm.AddHandlerOnChangeBounds(@FormBoundsChanged);
    FTrackedForm.FreeNotification(Self);
  end;
end;

procedure TFormPlacerMap.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FTrackedForm) then
  begin
    FTrackedForm := nil;
    FDesignForm := nil;
    FDragging := False;
    if not (csDestroying in ComponentState) then
      ApplyOptions;
  end;
end;

procedure TFormPlacerMap.BindDesignForm(ADesignForm: TDesignForm);
begin
  // called from an idle handler: leave early when nothing changed
  if (ADesignForm = FDesignForm)
  and ((ADesignForm = nil) or (ADesignForm.Form = FTrackedForm)) then
  begin
    if Assigned(FTrackedForm) and (FTrackedForm.Position <> FShownPosition) then
      Invalidate;
    Exit;
  end;
  FDesignForm := ADesignForm;
  if Assigned(ADesignForm) then
    TrackForm(ADesignForm.Form)
  else
    TrackForm(nil);
  FDragging := False;
  ApplyOptions;
end;

procedure TFormPlacerMap.ApplyOptions;
var
  LArea: TRect;
  LWidth: Integer;
begin
  if FormPlacerOptions = nil then Exit;
  Visible := FormPlacerOptions.ShowMap and CanPlace;
  LArea := DesktopArea;
  LWidth := MulDiv(FormPlacerOptions.MapWidth, Screen.PixelsPerInch, 96);
  SetBounds(Left, Top, LWidth, 2 + Round((LWidth - 2) * LArea.Height / Max(LArea.Width, 1)));
  Invalidate;
end;

procedure TFormPlacerMap.FormBoundsChanged(Sender: TObject);
begin
  if not FDragging then
    Invalidate;
end;

procedure TFormPlacerMap.Paint;
var
  LOpts: TFormPlacerOptions;
  LRect, LTitle: TRect;
  LPos: TPoint;
  LText: String;
  i: Integer;

  function MonitorRectOnMap(const R: TRect): TRect;
  begin
    Result.TopLeft := DesktopToMap(R.TopLeft);
    Result.BottomRight := DesktopToMap(R.BottomRight);
  end;

begin
  LOpts := FormPlacerOptions;
  if LOpts = nil then Exit;

  Canvas.Brush.Color := LOpts.MapBackColor;
  Canvas.FillRect(ClientRect);

  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := LOpts.MonitorEdgeColor;
  for i := 0 to Screen.MonitorCount - 1 do
    Canvas.Rectangle(MonitorRectOnMap(Screen.Monitors[i].BoundsRect));
  Canvas.Brush.Style := bsSolid;

  if not CanPlace then Exit;
  FShownPosition := FTrackedForm.Position;

  LRect := FormRectOnMap;
  Canvas.Brush.Color := LOpts.FormFillColor;
  Canvas.Pen.Color := LOpts.FormEdgeColor;
  Canvas.Rectangle(LRect);

  LTitle := LRect;
  Inc(LTitle.Left);
  Inc(LTitle.Top);
  Dec(LTitle.Right);
  LTitle.Bottom := LTitle.Top + Max(2, (LRect.Bottom - LRect.Top) div 6);
  Canvas.Brush.Color := LOpts.TitleBarColor;
  Canvas.FillRect(LTitle);

  if FDragging then
  begin
    LPos := FormDesktopPos;
    LText := Format('%d, %d', [LPos.X, LPos.Y]);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := LOpts.MonitorEdgeColor;
    Canvas.TextOut(3, 2, LText);
    Canvas.Brush.Style := bsSolid;
  end;
end;

procedure TFormPlacerMap.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LRect: TRect;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus then
    SetFocus;
  if (Button <> mbLeft) or not CanPlace then Exit;
  LRect := FormRectOnMap;
  if not PtInRect(LRect, Point(X, Y)) then Exit;
  FPendingPos := FormDesktopPos;
  FDragging := True;
  FDragOffset := Point(X - LRect.Left, Y - LRect.Top);
  MouseCapture := True;
end;

procedure TFormPlacerMap.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  LPos: TPoint;
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging then Exit;
  LPos := MapToDesktop(Point(X - FDragOffset.X, Y - FDragOffset.Y));
  ClampToDesktop(LPos);
  FPendingPos := LPos;
  if FormPlacerOptions.LiveUpdate then
    ApplyPosition(LPos.X, LPos.Y);
  Invalidate;
end;

procedure TFormPlacerMap.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FDragging then Exit;
  MouseCapture := False;
  FDragging := False;
  ApplyPosition(FPendingPos.X, FPendingPos.Y);
  MarkModified;
  Invalidate;
end;

procedure TFormPlacerMap.DblClick;
begin
  inherited DblClick;
  MenuCenterClick(nil);
end;

procedure TFormPlacerMap.KeyDown(var Key: Word; Shift: TShiftState);
var
  LStep: Integer;
  LPos: TPoint;
begin
  if CanPlace and (Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN]) then
  begin
    if ssShift in Shift then
      LStep := 1
    else
      LStep := FormPlacerOptions.NudgeStep;
    LPos := FormDesktopPos;
    case Key of
      VK_LEFT:  Dec(LPos.X, LStep);
      VK_RIGHT: Inc(LPos.X, LStep);
      VK_UP:    Dec(LPos.Y, LStep);
      VK_DOWN:  Inc(LPos.Y, LStep);
    end;
    ClampToDesktop(LPos);
    ApplyPosition(LPos.X, LPos.Y);
    MarkModified;
    Key := 0;
    Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TFormPlacerMap.MenuPopup(Sender: TObject);
var
  LCan: Boolean;
  LPos: TPosition;
  i: Integer;
begin
  // Position can also be changed in the Object Inspector: read it from the
  // form every time the menu opens.
  LCan := CanPlace;
  if LCan then
    LPos := FTrackedForm.Position
  else
    LPos := poDesigned;
  FMenuPosition.Enabled := LCan;
  for i := 0 to FMenuPosition.Count - 1 do
    FMenuPosition.Items[i].Checked := LCan and (FMenuPosition.Items[i].Tag = Ord(LPos));
  FMenuCenter.Enabled := LCan;
end;

procedure TFormPlacerMap.MenuPositionClick(Sender: TObject);
var
  LPos: TPosition;
begin
  if not CanPlace then Exit;
  LPos := TPosition(TMenuItem(Sender).Tag);
  if FTrackedForm.Position = LPos then Exit;
  FTrackedForm.Position := LPos;
  TMenuItem(Sender).Checked := True;
  Invalidate;
  MarkModified;
end;

procedure TFormPlacerMap.MenuCenterClick(Sender: TObject);
var
  LMon: TMonitor;
  LWork: TRect;
begin
  if not CanPlace then Exit;
  LMon := Screen.MonitorFromPoint(FormDesktopPos);
  if LMon = nil then
    LMon := Screen.PrimaryMonitor;
  LWork := LMon.WorkareaRect;
  ApplyPosition(LWork.Left + (LWork.Width - FTrackedForm.Width) div 2,
                LWork.Top + (LWork.Height - FTrackedForm.Height) div 2);
  MarkModified;
end;

procedure TFormPlacerMap.MenuHideClick(Sender: TObject);
begin
  FormPlacerOptions.ShowMap := False;
  FormPlacerOptions.SaveSafe;
  ApplyOptionsToAllMaps;
end;

procedure TFormPlacerMap.MenuOptionsClick(Sender: TObject);
begin
  if Assigned(FOnOpenOptions) then
    FOnOpenOptions(Self);
end;

initialization
  PlacerMaps := TFormPlacerMaps.Create;

finalization
  FreeAndNil(PlacerMaps);

end.
