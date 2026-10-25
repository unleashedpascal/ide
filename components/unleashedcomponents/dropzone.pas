{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit DropZone;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, Dialogs, LCLType, LMessages, ControlPaint;

type
  TFilesEvent = procedure(Sender: TObject; files: TStrings) of object;

  { TDropZone }

  // a target for files dragged from the desktop: a dashed frame with a hint,
  // lit while a drop is possible. A click opens a file dialog instead.
  // The files arrive in OnFilesDropped, filtered by Extensions
  TDropZone = class(TCustomControl)
  private
    FExtensions: string;
    FMultiple, FClickToBrowse, FShowIcon, FFolders, FShowFiles: boolean;
    FFiles: TStringList;
    FDialogTitle, FDialogFilter: string;
    FCornerRadius, FDashLength, FIconSize: integer;
    FFrameColor, FHoverFrameColor, FFillColor, FTextColor: TColor;
    FHot, FDropping, FHooked: boolean;
    FAntialiasing: TAntialiasSetting;
    FOnFilesDropped: TFilesEvent;
    FOnFileRejected: TFilesEvent;
    procedure setExtensions(const value: string);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function getFiles: TStrings;
    function accepts(const fileName: string): boolean;
    procedure takeFiles(const names: array of string);
    procedure formFilesDropped(Sender: TObject; const names: array of string);
    procedure hookForm;
  protected
    procedure Paint; override;
    procedure Click; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // opens the file dialog, as a click does
    procedure Browse;
    // forgets the files taken last
    procedure Clear;
    // the files taken last, by a drop or the dialog
    property Files: TStrings read getFiles;
  published
    // the hint in the zone
    property Caption;
    // extensions taken, like '.png;.jpg'; empty takes everything
    property Extensions: string read FExtensions write setExtensions;
    property Multiple: boolean index 0 read getFlag write setFlag default true;
    property ClickToBrowse: boolean index 1 read getFlag write setFlag default true;
    property ShowIcon: boolean index 2 read getFlag write setFlag default true;
    // folders dropped are taken too; without it they are rejected
    property Folders: boolean index 3 read getFlag write setFlag default false;
    // the names of the files taken last, under the hint
    property ShowFiles: boolean index 4 read getFlag write setFlag default false;
    property DialogTitle: string read FDialogTitle write FDialogTitle;
    // the filter of the dialog; empty derives one from Extensions
    property DialogFilter: string read FDialogFilter write FDialogFilter;
    property CornerRadius: integer index 0 read getMetric write setMetric default 8;
    property DashLength: integer index 1 read getMetric write setMetric default 6;
    property IconSize: integer index 2 read getMetric write setMetric default 32;
    // clDefault takes the colors of the theme
    property FrameColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property HoverFrameColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property FillColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnFilesDropped: TFilesEvent read FOnFilesDropped write FOnFilesDropped;
    // files whose extension was not in Extensions
    property OnFileRejected: TFilesEvent read FOnFileRejected write FOnFileRejected;
    property Align;
    property Anchors;
    property BorderSpacing;
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
  Math{$ifdef WINDOWS}, ShellAPI{$endif};

constructor TDropZone.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csSetCaption];
  FFiles := TStringList.Create;
  FMultiple := true;
  FClickToBrowse := true;
  FShowIcon := true;
  FCornerRadius := 8;
  FDashLength := 6;
  FIconSize := 32;
  FFrameColor := clDefault;
  FHoverFrameColor := clDefault;
  FFillColor := clDefault;
  FTextColor := clDefault;
  ParentColor := true;
  Cursor := crHandPoint;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TDropZone.Destroy;
begin
  Application.RemoveOnDropFilesHandler(@formFilesDropped);
  FFiles.Free;
  inherited Destroy;
end;

function TDropZone.getFiles: TStrings;
begin
  result := FFiles;
end;

procedure TDropZone.Clear;
begin
  FFiles.Clear;
  Invalidate;
end;

class function TDropZone.GetControlClassDefaultSize: TSize;
begin
  result.cx := 240;
  result.cy := 120;
end;

// -- files ----------------------

function TDropZone.accepts(const fileName: string): boolean;
begin
  result := true;
  if DirectoryExists(fileName) then exit(FFolders);
  if FExtensions = '' then exit;
  var ext := LowerCase(ExtractFileExt(fileName));
  for var e in FExtensions.Split([';', ',', ' '], TStringSplitOptions.ExcludeEmpty) do begin
    var want := LowerCase(Trim(e));
    if (want <> '') and (want[1] <> '.') then want := '.'+want;
    if want = ext then exit;
  end;
  result := false;
end;

procedure TDropZone.takeFiles(const names: array of string);
begin
  var taken := TStringList.Create;
  var rejected := TStringList.Create;
  try
    for var n in names do if accepts(n) then taken.Add(n) else rejected.Add(n);
    if not FMultiple and (taken.Count > 1) then begin
      for var i := 1 to taken.Count-1 do rejected.Add(taken[i]);
      while taken.Count > 1 do taken.Delete(1);
    end;
    if taken.Count > 0 then begin
      FFiles.Assign(taken);
      Invalidate;
    end;
    if (rejected.Count > 0) and Assigned(FOnFileRejected) then FOnFileRejected(self, rejected);
    if (taken.Count > 0) and Assigned(FOnFilesDropped) then FOnFilesDropped(self, taken);
  finally
    taken.Free;
    rejected.Free;
  end;
end;

// the drops come through the application: the LCL takes WM_DROPFILES on
// Windows before the control sees it, and the form takes them elsewhere
procedure TDropZone.CreateWnd;
begin
  inherited CreateWnd;
  if csDesigning in ComponentState then exit;
  {$ifdef WINDOWS}
  DragAcceptFiles(Handle, true);
  {$else}
  var form := GetParentForm(self);
  if form <> nil then form.AllowDropFiles := true;
  {$endif}
  hookForm;
end;

procedure TDropZone.DestroyWnd;
begin
  {$ifdef WINDOWS}
  if HandleAllocated and not (csDesigning in ComponentState) then DragAcceptFiles(Handle, false);
  {$endif}
  inherited DestroyWnd;
end;

procedure TDropZone.hookForm;
begin
  if FHooked then exit;
  FHooked := true;
  Application.AddOnDropFilesHandler(@formFilesDropped);
end;

// every drop in the application comes here; the zone takes the ones over it
procedure TDropZone.formFilesDropped(Sender: TObject; const names: array of string);
begin
  if not HandleAllocated or not IsVisible then exit;
  var p := ScreenToClient(Mouse.CursorPos);
  if not ClientRect.Contains(p) then exit;
  takeFiles(names);
  FDropping := false;
  Invalidate;
end;

procedure TDropZone.Browse;
begin
  var dlg := TOpenDialog.Create(nil);
  try
    dlg.Title := if FDialogTitle = '' then 'Choose files' else FDialogTitle;
    if FDialogFilter <> '' then dlg.Filter := FDialogFilter
    else if FExtensions <> '' then begin
      var masks := '';
      for var e in FExtensions.Split([';', ',', ' '], TStringSplitOptions.ExcludeEmpty) do begin
        var want := Trim(e);
        if (want <> '') and (want[1] <> '.') then want := '.'+want;
        if masks <> '' then masks += ';';
        masks += '*'+want;
      end;
      dlg.Filter := 'Accepted files ('+masks+')|'+masks+'|All files|*';
    end;
    if FMultiple then dlg.Options := dlg.Options+[ofAllowMultiSelect];
    if FFolders then dlg.Options := dlg.Options+[ofPathMustExist];
    if dlg.Execute then begin
      var names: array of string;
      SetLength(names, dlg.Files.Count);
      for var i := 0 to dlg.Files.Count-1 do names[i] := dlg.Files[i];
      takeFiles(names);
    end;
  finally
    dlg.Free;
  end;
end;

procedure TDropZone.Click;
begin
  inherited Click;
  if FClickToBrowse and Enabled and not (csDesigning in ComponentState) then Browse;
end;

// -- painting ----------------------

procedure TDropZone.Paint;
begin
  var frame := pick(FFrameColor, clBtnShadow);
  var hotFrame := pick(FHoverFrameColor, clHighlight);
  var fill := pick(FFillColor, blend(GetRGBColorResolvingParent, clWindow, 40));
  var textColor := pick(FTextColor, clGrayText);
  var lit := Enabled and hoverEnabled and (FHot or FDropping);
  if lit then begin
    frame := hotFrame;
    fill := blend(fill, hotFrame, 10);
    textColor := ColorToRGB(clWindowText);
  end;
  var sp := autofree beginShapes(Canvas, ClientRect, GetRGBColorResolvingParent, FAntialiasing);
  var r := ClientRect;
  r.Inflate(-1, -1);
  var radius := scaled(self, FCornerRadius);
  paintRoundRect(sp, r, radius, fill, clNone);
  sp.DashRoundRect(r.Left, r.Top, r.Right, r.Bottom, radius, (if lit then 2 else 1), scaled(self, 6), scaled(self, 4), frame);
  var icon := scaled(self, FIconSize);
  var th := Canvas.TextHeight('Hg');
  var hasText := Caption <> '';
  var total := (if FShowIcon then icon else 0)+(if FShowIcon and hasText then scaled(self, 8) else 0)+(if hasText then th else 0);
  // the names of the files taken, as many as fit under the hint
  var shown := if FShowFiles then Min(FFiles.Count, Max((ClientHeight-total-scaled(self, 20)) div th, 0)) else 0;
  if shown > 0 then total += shown*th+scaled(self, 6);
  var top := (ClientHeight-total) div 2;
  if FShowIcon then begin
    // an arrow into a tray
    var cx := ClientWidth div 2;
    var arrowColor := if lit then hotFrame else frame;
    paintLine(sp, cx, top, cx, top+icon*5 div 8, arrowColor, Max(icon div 10, 2));
    var head := icon div 4;
    // the head through the middles of the pixels, as the lines go
    sp.StrokePolyline([PointF(cx-head+0.5, top+icon*5 div 8-head+0.5), PointF(cx+0.5, top+icon*5 div 8+0.5), PointF(cx+head+0.5, top+icon*5 div 8-head+0.5)], Max(icon div 10, 2), arrowColor);
    paintLine(sp, cx-icon div 2, top+icon-icon div 6, cx-icon div 2, top+icon, arrowColor, 2);
    paintLine(sp, cx-icon div 2, top+icon, cx+icon div 2, top+icon, arrowColor, 2);
    paintLine(sp, cx+icon div 2, top+icon-icon div 6, cx+icon div 2, top+icon, arrowColor, 2);
  end;
  sp.Flush;
  var y := top+(if FShowIcon then icon+scaled(self, 8) else 0);
  if hasText then begin
    paintCenteredText(Canvas, Types.Rect(scaled(self, 8), y, ClientWidth-scaled(self, 8), y+th), Caption, textColor);
    y += th;
  end;
  if shown > 0 then begin
    y += scaled(self, 6);
    var nameColor := ColorToRGB(clWindowText);
    for var i := 0 to shown-1 do begin
      // the last line stands for the rest when they do not all fit
      var s := if (i = shown-1) and (FFiles.Count > shown) then Format('+%d more', [FFiles.Count-shown+1]) else ExtractFileName(FFiles[i]);
      paintCenteredText(Canvas, Types.Rect(scaled(self, 8), y, ClientWidth-scaled(self, 8), y+th), s, nameColor);
      y += th;
    end;
  end;
end;

procedure TDropZone.MouseEnter;
begin
  inherited MouseEnter;
  FHot := true;
  Invalidate;
end;

procedure TDropZone.MouseLeave;
begin
  inherited MouseLeave;
  FHot := false;
  Invalidate;
end;

// -- properties ----------------------

procedure TDropZone.setExtensions(const value: string);
begin
  FExtensions := value;
end;

function TDropZone.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FMultiple;
    1: result := FClickToBrowse;
    2: result := FShowIcon;
    3: result := FFolders;
    _: result := FShowFiles;
  end;
end;

procedure TDropZone.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FMultiple := value;
    1: FClickToBrowse := value;
    2: FShowIcon := value;
    3: FFolders := value;
    _: FShowFiles := value;
  end;
  Cursor := if FClickToBrowse then crHandPoint else crDefault;
  Invalidate;
end;

function TDropZone.getMetric(index: integer): integer;
begin
  match index of
    0: result := FCornerRadius;
    1: result := FDashLength;
    _: result := FIconSize;
  end;
end;

procedure TDropZone.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FCornerRadius := value;
    1: FDashLength := value;
    _: FIconSize := value;
  end;
  Invalidate;
end;

function TDropZone.getPartColor(index: integer): TColor;
begin
  match index of
    0: result := FFrameColor;
    1: result := FHoverFrameColor;
    2: result := FFillColor;
    _: result := FTextColor;
  end;
end;

procedure TDropZone.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FFrameColor := value;
    1: FHoverFrameColor := value;
    2: FFillColor := value;
    _: FTextColor := value;
  end;
  Invalidate;
end;

procedure TDropZone.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
