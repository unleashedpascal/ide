{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit InstallRootDlg;

{$mode unleashed}

interface

uses
  Classes, SysUtils, LCLType, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Menus, Clipbrd,
  LazUTF8, LazarusIDEStrConsts, InstallRoot;

type

  { TInstallRootForm }

  // summary shown once after the install directory was moved
  TInstallRootForm = class(TForm)
    LabelInfo: TLabel;
    ListLog: TListBox;
    PanelButtons: TPanel;
    ButtonOk: TButton;
    PopupLog: TPopupMenu;
    ItemCopy: TMenuItem;
    ItemCopyAll: TMenuItem;
    ItemSelectAll: TMenuItem;
    TimerCountdown: TTimer;
    procedure FormCreate({%H-}Sender: TObject);
    procedure TimerCountdownTimer({%H-}Sender: TObject);
    procedure ListLogDrawItem({%H-}Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure ItemCopyClick({%H-}Sender: TObject);
    procedure ItemCopyAllClick({%H-}Sender: TObject);
    procedure ItemSelectAllClick({%H-}Sender: TObject);
  private
    fSecondsLeft: integer;
    // the window as settled on screen; moving or scrolling it cancels the countdown.
    // the place is taken on the first timer tick, once the window manager is done with it
    fShownLeft, fShownTop, fShownTopIndex: integer;
    fShownValid: boolean;
    function elideLeft(const s: string; maxWidth: integer): string;
    procedure showCountdown;
  public
    procedure log(const msg: string; kind: TRelocateLogKind);
    // the button clicks itself after ten seconds unless the user touches the window
    procedure startCountdown;
  end;

// updates the stored paths when the install was moved;
// false when the update failed and the IDE must not start
function CheckInstallRoot: boolean;

implementation

{$R *.lfm}

function CheckInstallRoot: boolean;
begin
  result := true;
  var oldRoot, newRoot: string;
  if not InstallRootChanged(oldRoot, newRoot) then exit;
  var form := autofree TInstallRootForm.Create(nil);
  form.log(Format(lisInstallRootPrevious, [oldRoot]), rlkDetail);
  form.log(Format(lisInstallRootCurrent, [newRoot]), rlkDetail);
  result := RelocateInstallRoot(oldRoot, newRoot, @form.log);
  if result then
    form.startCountdown
  else begin
    form.LabelInfo.Caption := lisInstallRootFailed;
    form.ButtonOk.Caption := lisClose;
  end;
  form.ShowModal;
end;

{ TInstallRootForm }

procedure TInstallRootForm.FormCreate(Sender: TObject);
begin
  Caption := lisInstallRootTitle;
  LabelInfo.Caption := lisInstallRootUpdated;
  ButtonOk.Caption := lisInstallRootContinue;
  ItemCopy.Caption := srkmecCopy;
  ItemCopyAll.Caption := lisInstallRootCopyAll;
  ItemSelectAll.Caption := lisMenuSelectAll;
  Width := Scale96ToForm(720);
  Height := Screen.Height * 33 div 100;
end;

procedure TInstallRootForm.startCountdown;
begin
  fSecondsLeft := 10;
  showCountdown;
  TimerCountdown.Enabled := true;
end;

procedure TInstallRootForm.showCountdown;
begin
  ButtonOk.Caption := Format(lisInstallRootContinueIn, [fSecondsLeft]);
end;

procedure TInstallRootForm.TimerCountdownTimer(Sender: TObject);
begin
  if not fShownValid then begin
    fShownLeft := Left;
    fShownTop := Top;
    fShownTopIndex := ListLog.TopIndex;
    fShownValid := true;
  end else if (Left <> fShownLeft) or (Top <> fShownTop) or (ListLog.TopIndex <> fShownTopIndex) then begin
    TimerCountdown.Enabled := false;
    ButtonOk.Caption := lisInstallRootContinue;
    exit;
  end;
  dec(fSecondsLeft);
  if fSecondsLeft > 0 then
    showCountdown
  else begin
    TimerCountdown.Enabled := false;
    ButtonOk.Click;
  end;
end;

procedure TInstallRootForm.log(const msg: string; kind: TRelocateLogKind);
begin
  ListLog.Items.AddObject(msg, TObject(PtrInt(ord(kind))));
end;

function TInstallRootForm.elideLeft(const s: string; maxWidth: integer): string;
const
  ellipsis = '...';
begin
  result := s;
  var len := UTF8Length(s);
  var i := 2;
  while (ListLog.Canvas.TextWidth(result) > maxWidth) and (i <= len) do begin
    result := ellipsis + UTF8Copy(s, i, len);
    inc(i);
  end;
end;

procedure TInstallRootForm.ListLogDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  var c := ListLog.Canvas;
  if odSelected in State then begin
    c.Brush.Color := clHighlight;
    c.Font.Color := clHighlightText;
  end else begin
    c.Brush.Color := ListLog.Color;
    case TRelocateLogKind(PtrInt(ListLog.Items.Objects[Index])) of
      rlkDetail: c.Font.Color := clGrayText;
      rlkError: c.Font.Color := clRed;
    else
      c.Font.Color := clWindowText;
    end;
  end;
  c.FillRect(ARect);
  var s := elideLeft(ListLog.Items[Index], ARect.Width - 8);
  c.TextRect(ARect, ARect.Left + 4, ARect.Top + (ARect.Height - c.TextHeight(s)) div 2, s);
end;

procedure TInstallRootForm.ItemCopyClick(Sender: TObject);
begin
  var lines := autofree TStringList.Create;
  for var i := 0 to ListLog.Count - 1 do
    if ListLog.Selected[i] then
      lines.Add(ListLog.Items[i]);
  Clipboard.AsText := lines.Text;
end;

procedure TInstallRootForm.ItemCopyAllClick(Sender: TObject);
begin
  Clipboard.AsText := ListLog.Items.Text;
end;

procedure TInstallRootForm.ItemSelectAllClick(Sender: TObject);
begin
  ListLog.SelectAll;
end;

end.
