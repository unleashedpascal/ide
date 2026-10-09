{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit PropertyGrid;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, StdCtrls, Dialogs, TypInfo, LCLType, LMessages, ControlPaint;

type
  TPropertyGrid = class;
  TPropertyKind = (pkText, pkNumber, pkFloat, pkBool, pkEnum, pkSet, pkColor, pkObject, pkReadOnly);
  // a property is about to show; hide false leaves it out, name shows in place of its own
  TPropertyFilterEvent = procedure(Sender: TObject; const propName: string; var show: boolean; var displayName: string) of object;
  TPropertyChangeEvent = procedure(Sender: TObject; const propName: string) of object;

  { TPropertyGrid }

  // the published properties of an object, one per row, with the value
  // editable in place: text and numbers in a box, booleans and enums from
  // a list, colors from a dialog, sets as yes or no per element under the
  // set. Object properties open as a group of their own rows
  TPropertyGrid = class(TScrollingWinControl)
  private
    type
      TRow = record
        name, display, value: string;
        kind: TPropertyKind;
        info: PPropInfo;
        owner: TObject; // the object the property belongs to
        level: integer; // the depth inside object properties
        expanded, expandable: boolean;
        setElement: integer; // the element of a set row, -1 otherwise
        parentRow: integer;
      end;
    var
    FTarget: TPersistent;
    FRows: array of TRow;
    FActive, FHot: integer;
    FSplit: integer; // the share of the width the names take, in percent
    FRowHeight, FPadding, FIndent: integer;
    FShowReadOnly, FSortProperties, FShowObjects, FShowGridLines: boolean;
    FEdit: TEdit;
    FCombo: TComboBox;
    FEditing: integer; // the row the editor sits on, -1 none
    FDragSplit: boolean;
    FNameColor, FValueColor, FGridColor, FBackColor, FActiveColor, FGroupColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FLanguage: TFormatLanguage;
    FExcluded: TStrings;
    FOnFilter: TPropertyFilterEvent;
    FOnChange: TPropertyChangeEvent;
    FOnSelect: TPropertyChangeEvent;
    procedure setTarget(value: TPersistent);
    procedure setSplit(value: integer);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setExcluded(value: TStrings);
    procedure setAntialiasing(value: TAntialiasSetting);
    procedure setLanguage(value: TFormatLanguage);
    function rowPx: integer;
    function splitPx: integer;
    function rowAt(y: integer): integer;
    function rowTop(index: integer): integer;
    function kindOf(info: PPropInfo): TPropertyKind;
    function valueOf(const row: TRow): string;
    procedure collect(owner: TObject; level, parentRow: integer; insertAt: integer);
    procedure rebuild;
    procedure refreshValues;
    procedure updateRange;
    procedure beginEdit(index: integer);
    procedure endEdit(apply: boolean);
    procedure applyText(index: integer; const text: string);
    procedure toggleRow(index: integer);
    procedure editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure editExit(Sender: TObject);
    procedure comboChange(Sender: TObject);
    procedure comboKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure changed(const name: string);
    procedure ensureVisible(index: integer);
  protected
    procedure Paint; override;
    procedure ScrollBy(DeltaX, DeltaY: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Resize; override;
    procedure FontChanged(Sender: TObject); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // reads the values of the target again, after they changed elsewhere
    procedure Refresh;
    // the name of the property on the active row, empty for none
    function ActiveProperty: string;
    procedure ExpandAll;
    procedure CollapseAll;
  published
    // the object whose properties show; a control, a font, anything published
    property Target: TPersistent read FTarget write setTarget;
    // the share of the width the names take, in percent
    property Split: integer read FSplit write setSplit default 45;
    property ShowReadOnly: boolean index 0 read getFlag write setFlag default false;
    property SortProperties: boolean index 1 read getFlag write setFlag default true;
    // object properties such as Font open into their own rows
    property ShowObjects: boolean index 2 read getFlag write setFlag default true;
    property ShowGridLines: boolean index 3 read getFlag write setFlag default true;
    // 0 takes it from the font
    property RowHeight: integer index 0 read getMetric write setMetric default 0;
    property Padding: integer index 1 read getMetric write setMetric default 6;
    property Indent: integer index 2 read getMetric write setMetric default 14;
    // property names never shown, one per line
    property Excluded: TStrings read FExcluded write setExcluded;
    // clDefault takes the colors of the theme
    property NameColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property ValueColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BackColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property ActiveColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property GroupColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    // the names and separators of dates, times and numbers: those of the
    // locale of the system, or English
    property Language: TFormatLanguage read FLanguage write setLanguage default flSystem;
    property OnFilter: TPropertyFilterEvent read FOnFilter write FOnFilter;
    // a value went into the target
    property OnChange: TPropertyChangeEvent read FOnChange write FOnChange;
    property OnSelect: TPropertyChangeEvent read FOnSelect write FOnSelect;
    property Align;
    property Anchors;
    property BorderSpacing;
    property BorderStyle default bsSingle;
    property Color default clWindow;
    property Constraints;
    property Enabled;
    property Font;
    property Hint;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default true;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
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
  Math, LCLIntf;

constructor TPropertyGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FSplit := 45;
  FPadding := 6;
  FIndent := 14;
  FSortProperties := true;
  FShowObjects := true;
  FShowGridLines := true;
  FActive := -1;
  FHot := -1;
  FEditing := -1;
  FNameColor := clDefault;
  FValueColor := clDefault;
  FGridColor := clDefault;
  FBackColor := clDefault;
  FActiveColor := clDefault;
  FGroupColor := clDefault;
  FAntialiasing := asTheme;
  FExcluded := TStringList.Create;
  TStringList(FExcluded).Text := 'Name'#10'Tag'#10'Left'#10'Top'#10'Width'#10'Height'#10'HelpContext'#10'HelpKeyword'#10'HelpType';
  TabStop := true;
  Color := clWindow;
  BorderStyle := bsSingle;
  VertScrollBar.Tracking := true;
  HorzScrollBar.Visible := false;
  // the editors come up on the active row and go away after the edit
  FEdit := TEdit.Create(self);
  FEdit.Visible := false;
  FEdit.BorderStyle := bsNone;
  FEdit.OnKeyDown := @editKeyDown;
  FEdit.OnExit := @editExit;
  FEdit.Parent := self;
  FCombo := TComboBox.Create(self);
  FCombo.Visible := false;
  FCombo.Style := csDropDownList;
  FCombo.OnChange := @comboChange;
  FCombo.OnKeyDown := @comboKeyDown;
  FCombo.OnExit := @editExit;
  FCombo.Parent := self;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TPropertyGrid.Destroy;
begin
  FExcluded.Free;
  inherited Destroy;
end;

class function TPropertyGrid.GetControlClassDefaultSize: TSize;
begin
  result.cx := 260;
  result.cy := 300;
end;

// -- the rows ----------------------

function TPropertyGrid.kindOf(info: PPropInfo): TPropertyKind;
begin
  if info^.SetProc = nil then exit(pkReadOnly);
  var name := info^.PropType^.Name;
  result := match info^.PropType^.Kind of
    tkInteger, tkInt64, tkQWord: (if (name = 'TColor') or (name = 'TGraphicsColor') then pkColor else pkNumber);
    tkFloat: pkFloat;
    tkBool: pkBool;
    tkEnumeration: (if name = 'Boolean' then pkBool else pkEnum);
    tkSet: pkSet;
    tkSString, tkLString, tkAString, tkWString, tkUString, tkChar, tkWChar: pkText;
    tkClass: pkObject;
  else
    pkReadOnly
  end;
end;

function TPropertyGrid.valueOf(const row: TRow): string;
begin
  result := '';
  if row.info = nil then exit;
  try
    match row.kind of
      pkText: result := GetStrProp(row.owner, row.info);
      pkNumber: result := IntToStr(GetOrdProp(row.owner, row.info));
      pkFloat: result := FloatToStr(GetFloatProp(row.owner, row.info), formatSettingsOf(FLanguage));
      pkBool: result := if GetOrdProp(row.owner, row.info) <> 0 then 'True' else 'False';
      pkEnum: result := GetEnumName(row.info^.PropType, GetOrdProp(row.owner, row.info));
      pkSet: begin
        if row.setElement >= 0 then begin
          var bits := GetOrdProp(row.owner, row.info);
          result := if (bits and (1 shl row.setElement)) <> 0 then 'True' else 'False';
        end else result := GetSetProp(row.owner, row.info, true);
      end;
      pkColor: result := ColorToString(TColor(GetOrdProp(row.owner, row.info)));
      pkObject: begin
        var o := GetObjectProp(row.owner, row.info);
        result := if o = nil then '(nil)' else '('+o.ClassName+')';
      end;
    else
      match row.info^.PropType^.Kind of
        tkInteger, tkInt64, tkEnumeration, tkBool, tkChar: result := GetEnumProp(row.owner, row.info);
        tkFloat: result := FloatToStr(GetFloatProp(row.owner, row.info), formatSettingsOf(FLanguage));
        tkSString, tkLString, tkAString, tkWString, tkUString: result := GetStrProp(row.owner, row.info);
        tkClass: result := '(object)';
      end;
    end;
  except
    result := '?';
  end;
end;

// the published properties of `owner` as rows after `insertAt`
procedure TPropertyGrid.collect(owner: TObject; level, parentRow: integer; insertAt: integer);
begin
  if owner = nil then exit;
  var count := GetPropList(owner.ClassInfo, tkProperties, nil, FSortProperties);
  if count <= 0 then exit;
  var list: PPropList;
  GetMem(list, count*SizeOf(PPropInfo));
  try
    GetPropList(owner.ClassInfo, tkProperties, list, FSortProperties);
    var at := insertAt;
    for var i := 0 to count-1 do begin
      var info := list^[i];
      var kind := kindOf(info);
      if (kind = pkReadOnly) and not FShowReadOnly then continue;
      if (kind = pkObject) and not FShowObjects then continue;
      if FExcluded.IndexOf(info^.Name) >= 0 then continue;
      // events are not values
      if info^.PropType^.Kind = tkMethod then continue;
      var show := true;
      var display: string := info^.Name;
      if Assigned(FOnFilter) then FOnFilter(self, info^.Name, show, display);
      if not show then continue;
      SetLength(FRows, length(FRows)+1);
      for var k := high(FRows) downto at+1 do FRows[k] := FRows[k-1];
      FRows[at] := Default(TRow);
      FRows[at].name := info^.Name;
      FRows[at].display := display;
      FRows[at].kind := kind;
      FRows[at].info := info;
      FRows[at].owner := owner;
      FRows[at].level := level;
      FRows[at].setElement := -1;
      FRows[at].parentRow := parentRow;
      FRows[at].expandable := (kind = pkObject) or (kind = pkSet);
      FRows[at].value := valueOf(FRows[at]);
      inc(at);
    end;
  finally
    FreeMem(list);
  end;
end;

procedure TPropertyGrid.rebuild;
begin
  endEdit(false);
  FRows := nil;
  FActive := -1;
  FHot := -1;
  collect(FTarget, 0, -1, 0);
  updateRange;
  Invalidate;
end;

procedure TPropertyGrid.refreshValues;
begin
  for var i := 0 to high(FRows) do FRows[i].value := valueOf(FRows[i]);
  Invalidate;
end;

procedure TPropertyGrid.Refresh;
begin
  if FEditing >= 0 then exit;
  refreshValues;
end;

// opens the object or the set under a row into rows of its own, or folds them
procedure TPropertyGrid.toggleRow(index: integer);
begin
  if (index < 0) or (index >= length(FRows)) or not FRows[index].expandable then exit;
  endEdit(true);
  if FRows[index].expanded then begin
    // every row below with a deeper level belongs to the fold
    var last := index;
    while (last+1 < length(FRows)) and (FRows[last+1].level > FRows[index].level) do inc(last);
    for var k := index+1 to high(FRows)-(last-index) do FRows[k] := FRows[k+last-index];
    SetLength(FRows, length(FRows)-(last-index));
    FRows[index].expanded := false;
  end else begin
    FRows[index].expanded := true;
    if FRows[index].kind = pkObject then collect(GetObjectProp(FRows[index].owner, FRows[index].info), FRows[index].level+1, index, index+1)
    else begin
      // a row per element of the set, each a yes or no
      var elementType := GetTypeData(FRows[index].info^.PropType)^.CompType;
      var data := GetTypeData(elementType);
      var at := index+1;
      for var e := data^.MinValue to data^.MaxValue do begin
        SetLength(FRows, length(FRows)+1);
        for var k := high(FRows) downto at+1 do FRows[k] := FRows[k-1];
        FRows[at] := FRows[index];
        FRows[at].display := GetEnumName(elementType, e);
        FRows[at].name := FRows[index].name+'.'+FRows[at].display;
        FRows[at].level := FRows[index].level+1;
        FRows[at].expandable := false;
        FRows[at].expanded := false;
        FRows[at].setElement := e;
        FRows[at].parentRow := index;
        FRows[at].value := valueOf(FRows[at]);
        inc(at);
      end;
    end;
  end;
  updateRange;
  Invalidate;
end;

procedure TPropertyGrid.ExpandAll;
begin
  var i := 0;
  while i < length(FRows) do begin
    if FRows[i].expandable and not FRows[i].expanded and (FRows[i].level = 0) then toggleRow(i);
    inc(i);
  end;
end;

procedure TPropertyGrid.CollapseAll;
begin
  for var i := high(FRows) downto 0 do if (i < length(FRows)) and FRows[i].expanded then toggleRow(i);
end;

function TPropertyGrid.ActiveProperty: string;
begin
  result := if (FActive >= 0) and (FActive < length(FRows)) then FRows[FActive].name else '';
end;

// -- editing ----------------------

procedure TPropertyGrid.applyText(index: integer; const text: string);
begin
  var row := FRows[index];
  if row.info = nil then exit;
  try
    match row.kind of
      pkText: SetStrProp(row.owner, row.info, text);
      pkNumber: SetOrdProp(row.owner, row.info, StrToInt64(Trim(text)));
      pkFloat: SetFloatProp(row.owner, row.info, StrToFloat(Trim(text), formatSettingsOf(FLanguage)));
      pkBool: SetOrdProp(row.owner, row.info, ord(SameText(Trim(text), 'True')));
      pkEnum: SetEnumProp(row.owner, row.info, text);
      pkSet: begin
        if row.setElement >= 0 then begin
          var bits := GetOrdProp(row.owner, row.info);
          if SameText(Trim(text), 'True') then bits := bits or (1 shl row.setElement) else bits := bits and not (1 shl row.setElement);
          SetOrdProp(row.owner, row.info, bits);
        end else SetSetProp(row.owner, row.info, text);
      end;
      pkColor: SetOrdProp(row.owner, row.info, StringToColor(Trim(text)));
    end;
  except
    on E: Exception do begin
      // a value the property refuses stays out; the row shows the old one
      refreshValues;
      exit;
    end;
  end;
  // a change of a set element or a parent shows in the rows around it
  refreshValues;
  changed(row.name);
end;

procedure TPropertyGrid.changed(const name: string);
begin
  if Assigned(FOnChange) then FOnChange(self, name);
end;

procedure TPropertyGrid.beginEdit(index: integer);
begin
  if (index < 0) or (index >= length(FRows)) then exit;
  endEdit(true);
  var row := FRows[index];
  if row.kind in [pkReadOnly, pkObject] then exit;
  if (row.kind = pkSet) and (row.setElement < 0) then exit;
  if (row.kind = pkBool) or (row.kind = pkSet) then begin
    // a check box: the click toggles, there is nothing to type
    applyText(index, (if row.value = 'True' then 'False' else 'True'));
    exit;
  end;
  var r := Rect(splitPx+1, rowTop(index)-VertScrollBar.Position+1, ClientWidth-1, rowTop(index)-VertScrollBar.Position+rowPx-1);
  FEditing := index;
  if row.kind = pkColor then begin
    // the dialog picks the color, the row takes it at once
    var dialog := TColorDialog.Create(self);
    try
      dialog.Color := TColor(GetOrdProp(row.owner, row.info));
      FEditing := -1;
      if dialog.Execute then applyText(index, ColorToString(dialog.Color));
    finally
      dialog.Free;
    end;
    exit;
  end;
  if row.kind = pkEnum then begin
    FCombo.Items.BeginUpdate;
    try
      FCombo.Items.Clear;
      var data := GetTypeData(row.info^.PropType);
      for var e := data^.MinValue to data^.MaxValue do FCombo.Items.Add(GetEnumName(row.info^.PropType, e));
    finally
      FCombo.Items.EndUpdate;
    end;
    FCombo.ItemIndex := FCombo.Items.IndexOf(row.value);
    FCombo.BoundsRect := r;
    FCombo.Visible := true;
    FCombo.SetFocus;
    FCombo.DroppedDown := true;
  end else begin
    FEdit.Text := row.value;
    FEdit.BoundsRect := r;
    FEdit.Visible := true;
    FEdit.SetFocus;
    FEdit.SelectAll;
  end;
end;

procedure TPropertyGrid.endEdit(apply: boolean);
begin
  if FEditing < 0 then exit;
  var index := FEditing;
  FEditing := -1;
  if FEdit.Visible then begin
    var text := FEdit.Text;
    FEdit.Visible := false;
    if apply and (index < length(FRows)) and (text <> FRows[index].value) then applyText(index, text);
  end;
  if FCombo.Visible then begin
    var text := FCombo.Text;
    FCombo.Visible := false;
    if apply and (index < length(FRows)) and (text <> '') and (text <> FRows[index].value) then applyText(index, text);
  end;
  if CanSetFocus and not Focused and (Screen.ActiveControl <> nil) and (Screen.ActiveControl.Parent = self) then SetFocus;
  Invalidate;
end;

procedure TPropertyGrid.editKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  match Key of
    VK_RETURN: begin endEdit(true); Key := 0; end;
    VK_ESCAPE: begin endEdit(false); Key := 0; end;
    VK_TAB: begin
      // the next row takes the edit
      var next := FEditing+1;
      endEdit(true);
      if next < length(FRows) then begin
        FActive := next;
        ensureVisible(next);
        beginEdit(next);
      end;
      Key := 0;
    end;
  end;
end;

procedure TPropertyGrid.editExit(Sender: TObject);
begin
  endEdit(true);
end;

procedure TPropertyGrid.comboChange(Sender: TObject);
begin
  if (FEditing < 0) or (FEditing >= length(FRows)) then exit;
  if FCombo.Text <> FRows[FEditing].value then applyText(FEditing, FCombo.Text);
end;

procedure TPropertyGrid.comboKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key in [VK_RETURN, VK_ESCAPE] then begin
    endEdit(Key = VK_RETURN);
    Key := 0;
  end;
end;

// -- geometry ----------------------

function TPropertyGrid.rowPx: integer;
begin
  result := if FRowHeight > 0 then scaled(self, FRowHeight) else lineHeightOf(Font)+scaled(self, 8);
end;

function TPropertyGrid.splitPx: integer;
begin
  result := ClientWidth*FSplit div 100;
end;

function TPropertyGrid.rowTop(index: integer): integer;
begin
  result := index*rowPx;
end;

function TPropertyGrid.rowAt(y: integer): integer;
begin
  result := (y+VertScrollBar.Position) div rowPx;
  if (result < 0) or (result >= length(FRows)) then result := -1;
end;

procedure TPropertyGrid.updateRange;
begin
  if not HandleAllocated then exit;
  VertScrollBar.Increment := rowPx;
  VertScrollBar.Page := Max(ClientHeight, 1);
  VertScrollBar.Range := length(FRows)*rowPx;
end;

procedure TPropertyGrid.ensureVisible(index: integer);
begin
  if (index < 0) or not HandleAllocated then exit;
  var top := rowTop(index);
  if top < VertScrollBar.Position then VertScrollBar.Position := top
  else if top+rowPx > VertScrollBar.Position+ClientHeight then VertScrollBar.Position := top+rowPx-ClientHeight;
end;

procedure TPropertyGrid.ScrollBy(DeltaX, DeltaY: Integer);
begin
  endEdit(true);
  Invalidate;
end;

procedure TPropertyGrid.Resize;
begin
  inherited Resize;
  updateRange;
  Invalidate;
end;

procedure TPropertyGrid.FontChanged(Sender: TObject);
begin
  inherited FontChanged(Sender);
  updateRange;
  Invalidate;
end;

// -- painting ----------------------

procedure TPropertyGrid.Paint;
begin
  var back := pick(FBackColor, Color);
  var names := pick(FNameColor, clWindowText);
  var values := pick(FValueColor, clWindowText);
  var grid := pick(FGridColor, blend(back, clWindowText, 12));
  var active := pick(FActiveColor, blend(back, clHighlight, 25));
  var group := pick(FGroupColor, blend(back, clWindowText, 6));
  var view := ClientRect;
  OffsetRect(view, 0, VertScrollBar.Position);
  var sp := autofree beginShapes(Canvas, view, back, FAntialiasing);
  var rh := rowPx;
  var split := splitPx;
  var pad := scaled(self, FPadding);
  var first := Max(VertScrollBar.Position div rh, 0);
  var last := Min((VertScrollBar.Position+ClientHeight) div rh, high(FRows));
  for var i := first to last do begin
    var row := FRows[i];
    var top := rowTop(i);
    if row.expandable then sp.FillRect(Rect(0, top, ClientWidth, top+rh), group);
    if (i = FActive) then sp.FillRect(Rect(0, top, ClientWidth, top+rh), (if Focused and ringEnabled then blend(active, clHighlight, 20) else active))
    else if (i = FHot) and hoverEnabled then sp.FillRect(Rect(0, top, ClientWidth, top+rh), hoverColor(back));
    if FShowGridLines then sp.FillRect(Rect(0, top+rh-1, ClientWidth, top+rh), grid);
    if row.expandable then begin
      var cx := scaled(self, 8)+row.level*scaled(self, FIndent);
      paintChevron(sp, Rect(cx-scaled(self, 5), top, cx+scaled(self, 5), top+rh), (if row.expanded then cdDown else cdRight), scaled(self, 7), names);
    end;
    if row.kind = pkColor then begin
      var size := rh-scaled(self, 8);
      var box := Rect(split+pad, top+scaled(self, 4), split+pad+size, top+scaled(self, 4)+size);
      var c := StringToColor(row.value);
      paintRoundRect(sp, box, scaled(self, 2), ColorToRGB(c), blend(back, clWindowText, 40));
    end else if (row.kind = pkBool) or ((row.kind = pkSet) and (row.setElement >= 0)) then begin
      var size := rh-scaled(self, 10);
      var box := Rect(split+pad, top+scaled(self, 5), split+pad+size, top+scaled(self, 5)+size);
      var on := row.value = 'True';
      paintRoundRect(sp, box, scaled(self, 2), (if on then ColorToRGB(clHighlight) else back), (if on then ColorToRGB(clHighlight) else blend(back, clWindowText, 40)));
      if on then paintCheck(sp, box, size*7 div 10, contrastText(clHighlight), Max(size div 7, 2));
    end;
  end;
  if FShowGridLines then sp.FillRect(Rect(split, view.Top, split+1, view.Bottom), grid);
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  var style := Canvas.TextStyle;
  style.Alignment := taLeftJustify;
  style.Layout := tlCenter;
  style.SingleLine := true;
  style.Clipping := true;
  style.Opaque := false;
  style.ShowPrefix := false;
  style.EndEllipsis := true;
  for var i := first to last do begin
    var row := FRows[i];
    var top := rowTop(i);
    var x := pad+scaled(self, 12)+row.level*scaled(self, FIndent);
    Canvas.Font.Style := if row.expandable then Font.Style+[fsBold] else Font.Style;
    Canvas.Font.Color := if row.kind = pkReadOnly then ColorToRGB(clGrayText) else names;
    var nr := Rect(x, top, split-pad, top+rh);
    if nr.Right > nr.Left then Canvas.TextRect(nr, nr.Left, nr.Top, row.display, style);
    if i = FEditing then continue;
    Canvas.Font.Style := Font.Style;
    Canvas.Font.Color := if row.kind = pkReadOnly then ColorToRGB(clGrayText) else values;
    var vx := split+pad;
    if row.kind = pkColor then vx += rh-scaled(self, 8)+pad;
    if (row.kind = pkBool) or ((row.kind = pkSet) and (row.setElement >= 0)) then vx += rh-scaled(self, 10)+pad;
    var vr := Rect(vx, top, ClientWidth-pad, top+rh);
    if vr.Right > vr.Left then Canvas.TextRect(vr, vr.Left, vr.Top, row.value, style);
  end;
  Canvas.Brush.Style := bsSolid;
end;

// -- input ----------------------

procedure TPropertyGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then exit;
  if Abs(X-splitPx) <= scaled(self, 3) then begin
    endEdit(true);
    FDragSplit := true;
    exit;
  end;
  var index := rowAt(Y);
  if index < 0 then begin
    endEdit(true);
    if TabStop and CanSetFocus then SetFocus;
    exit;
  end;
  if index <> FActive then begin
    endEdit(true);
    FActive := index;
    Invalidate;
    if Assigned(FOnSelect) then FOnSelect(self, FRows[index].name);
  end;
  var chevron := scaled(self, 8)+FRows[index].level*scaled(self, FIndent);
  if FRows[index].expandable and (X < chevron+scaled(self, 8)) then begin
    toggleRow(index);
    exit;
  end;
  if X >= splitPx then beginEdit(index)
  else if TabStop and CanSetFocus then SetFocus;
end;

procedure TPropertyGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FDragSplit then begin
    Split := EnsureRange(X*100 div Max(ClientWidth, 1), 10, 90);
    exit;
  end;
  Cursor := if Abs(X-splitPx) <= scaled(self, 3) then crHSplit else crDefault;
  var hot := rowAt(Y);
  if hot <> FHot then begin
    FHot := hot;
    Invalidate;
  end;
end;

procedure TPropertyGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragSplit := false;
end;

procedure TPropertyGrid.MouseLeave;
begin
  inherited MouseLeave;
  if FHot >= 0 then begin
    FHot := -1;
    Invalidate;
  end;
end;

procedure TPropertyGrid.DblClick;
begin
  inherited DblClick;
  var p := ScreenToClient(Mouse.CursorPos);
  var index := rowAt(p.Y);
  if (index >= 0) and FRows[index].expandable then toggleRow(index)
  else if (index >= 0) and (FRows[index].kind = pkBool) then applyText(index, (if FRows[index].value = 'True' then 'False' else 'True'));
end;

procedure TPropertyGrid.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var n := length(FRows);
  if n = 0 then exit;
  match Key of
    VK_UP: FActive := Max(FActive-1, 0);
    VK_DOWN: FActive := Min(FActive+1, n-1);
    VK_HOME: FActive := 0;
    VK_END: FActive := n-1;
    VK_RETURN, VK_F2: begin
      beginEdit(FActive);
      Key := 0;
      exit;
    end;
    VK_RIGHT, VK_ADD: begin
      if (FActive >= 0) and FRows[FActive].expandable and not FRows[FActive].expanded then toggleRow(FActive);
      Key := 0;
      exit;
    end;
    VK_LEFT, VK_SUBTRACT: begin
      if (FActive >= 0) and FRows[FActive].expanded then toggleRow(FActive)
      else if (FActive >= 0) and (FRows[FActive].parentRow >= 0) then FActive := FRows[FActive].parentRow;
      Invalidate;
      Key := 0;
      exit;
    end;
    VK_SPACE: begin
      if (FActive >= 0) and (FRows[FActive].kind = pkBool) then applyText(FActive, (if FRows[FActive].value = 'True' then 'False' else 'True'));
      Key := 0;
      exit;
    end;
  else
    exit;
  end;
  Key := 0;
  ensureVisible(FActive);
  Invalidate;
  if Assigned(FOnSelect) and (FActive >= 0) then FOnSelect(self, FRows[FActive].name);
end;

procedure TPropertyGrid.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TPropertyGrid.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TPropertyGrid.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FTarget) then begin
    FTarget := nil;
    rebuild;
  end;
end;

// -- properties ----------------------

procedure TPropertyGrid.setTarget(value: TPersistent);
begin
  if FTarget = value then exit;
  if FTarget is TComponent then TComponent(FTarget).RemoveFreeNotification(self);
  FTarget := value;
  if FTarget is TComponent then TComponent(FTarget).FreeNotification(self);
  rebuild;
end;

procedure TPropertyGrid.setSplit(value: integer);
begin
  value := EnsureRange(value, 10, 90);
  if FSplit = value then exit;
  FSplit := value;
  Invalidate;
end;

function TPropertyGrid.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowReadOnly;
    1: FSortProperties;
    2: FShowObjects;
  else
    FShowGridLines
  end;
end;

procedure TPropertyGrid.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowReadOnly := value;
    1: FSortProperties := value;
    2: FShowObjects := value;
  else
    FShowGridLines := value;
  end;
  if index < 3 then rebuild else Invalidate;
end;

function TPropertyGrid.getMetric(index: integer): integer;
begin
  result := match index of
    0: FRowHeight;
    1: FPadding;
  else
    FIndent
  end;
end;

procedure TPropertyGrid.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if getMetric(index) = value then exit;
  match index of
    0: FRowHeight := value;
    1: FPadding := value;
  else
    FIndent := value;
  end;
  updateRange;
  Invalidate;
end;

function TPropertyGrid.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FNameColor;
    1: FValueColor;
    2: FGridColor;
    3: FBackColor;
    4: FActiveColor;
  else
    FGroupColor
  end;
end;

procedure TPropertyGrid.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FNameColor := value;
    1: FValueColor := value;
    2: FGridColor := value;
    3: FBackColor := value;
    4: FActiveColor := value;
  else
    FGroupColor := value;
  end;
  Invalidate;
end;

procedure TPropertyGrid.setExcluded(value: TStrings);
begin
  FExcluded.Assign(value);
  rebuild;
end;

procedure TPropertyGrid.setLanguage(value: TFormatLanguage);
begin
  if value = FLanguage then exit;
  FLanguage := value;
  Invalidate;
end;

procedure TPropertyGrid.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
