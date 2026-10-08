{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Validator;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, ExtCtrls, ControlPaint;

type
  TValidator = class;
  TValidationRule = class;
  // what a rule checks: a value present, a pattern, an e-mail address, a
  // number, a whole number, a range, a length, the same text as another
  // control, a handler of its own
  TValidationKind = (vkRequired, vkPattern, vkEmail, vkNumber, vkInteger, vkRange, vkLength, vkSameAs, vkCustom);
  // when the rules run by themselves: on Validate only, when the focus
  // leaves a field, or while the user types
  TValidationMode = (vmOnSubmit, vmOnExit, vmOnChange);
  TValidateEvent = procedure(Sender: TValidationRule; const value: string; var valid: boolean) of object;
  TValidatedEvent = procedure(Sender: TObject; valid: boolean) of object;

  { TValidationRule }

  TValidationRule = class(TCollectionItem)
  private
    FControl, FCompareTo: TControl;
    FKind: TValidationKind;
    FPattern, FMessage: string;
    FMinValue, FMaxValue: double;
    FMinLength, FMaxLength: integer;
    FEnabled: boolean;
    FOnValidate: TValidateEvent;
    procedure setControl(value: TControl);
    procedure setCompareTo(value: TControl);
    function rangeStored: boolean;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    // the value passes the rule
    function Check(const value: string): boolean;
    // the message, or a default one for the kind
    function ErrorText: string;
  published
    property Control: TControl read FControl write setControl;
    property Kind: TValidationKind read FKind write FKind default vkRequired;
    // a regular expression the whole value must match
    property Pattern: string read FPattern write FPattern;
    property MinValue: double read FMinValue write FMinValue stored rangeStored;
    property MaxValue: double read FMaxValue write FMaxValue stored rangeStored;
    property MinLength: integer read FMinLength write FMinLength default 0;
    // 0 sets no limit
    property MaxLength: integer read FMaxLength write FMaxLength default 0;
    // the control whose value this one must repeat, as a password twice
    property CompareTo: TControl read FCompareTo write setCompareTo;
    // shown at the field; empty takes a message for the kind
    property Message: string read FMessage write FMessage;
    property Enabled: boolean read FEnabled write FEnabled default true;
    property OnValidate: TValidateEvent read FOnValidate write FOnValidate;
  end;

  { TValidationRules }

  TValidationRules = class(TOwnedCollection)
  private
    function getItem(index: integer): TValidationRule;
    procedure setItem(index: integer; value: TValidationRule);
  public
    function Add: TValidationRule;
    function AddRule(control: TControl; kind: TValidationKind; const message: string = ''): TValidationRule;
    property Items[index: integer]: TValidationRule read getItem write setItem; default;
  end;

  { TValidationMarker }

  // the sign next to a field that fails, its message as the hint
  TValidationMarker = class(TGraphicControl)
  private
    FValidator: TValidator;
  protected
    procedure Paint; override;
  end;

  { TValidator }

  // checks the fields of a form against rules: required, a pattern, an
  // e-mail address, a number, a range, a length, the same as another field
  // or a check of your own. A field that fails gets a sign next to it with
  // the message as hint; SubmitControl is enabled only while all pass
  TValidator = class(TComponent)
  private
    FRules: TValidationRules;
    FMode: TValidationMode;
    FShowMarkers, FWatching: boolean;
    FErrorColor: TColor;
    FSubmitControl: TControl;
    FMarkers: array of record
      control: TControl;
      marker: TValidationMarker;
    end;
    FSeen: TStringList; // the last value checked per control, for vmOnChange
    FFocused: TControl; // the field with the focus, to know which one it left
    FPoll: TTimer;
    FErrors: TStringList;
    FOnValidated: TValidatedEvent;
    procedure setRules(value: TValidationRules);
    procedure setMode(value: TValidationMode);
    procedure setSubmitControl(value: TControl);
    procedure activeChanged(Sender: TObject; LastControl: TControl);
    procedure poll(Sender: TObject);
    procedure watch(active: boolean);
    function markerOf(control: TControl; create: boolean): TValidationMarker;
    procedure mark(control: TControl; const message: string);
    procedure updateSubmit;
    function checkControl(control: TControl; out message: string): boolean;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the text a rule checks: Checked as True or False, else Text or Caption
    class function ValueOf(control: TControl): string;
    // runs every rule and marks the fields; true when all pass
    function Validate: boolean;
    // runs the rules of one field
    function ValidateControl(control: TControl): boolean;
    // all pass, without marking anything
    function IsValid: boolean;
    // the message of the first rule a field fails, empty when it passes
    function ErrorOf(control: TControl): string;
    // takes the signs away
    procedure ClearMarkers;
    // the messages of the last Validate
    property Errors: TStringList read FErrors;
  published
    property Rules: TValidationRules read FRules write setRules;
    property Mode: TValidationMode read FMode write setMode default vmOnExit;
    property ShowMarkers: boolean read FShowMarkers write FShowMarkers default true;
    // clDefault takes a red that suits the background
    property ErrorColor: TColor read FErrorColor write FErrorColor default clDefault;
    // enabled only while every rule passes, as an OK button
    property SubmitControl: TControl read FSubmitControl write setSubmitControl;
    // after each check, with the result of all rules
    property OnValidated: TValidatedEvent read FOnValidated write FOnValidated;
  end;

implementation

uses
  Math, TypInfo, RegExpr, LazUTF8;

var
  dotFormat: TFormatSettings;

function toNumber(const s: string; out value: double): boolean;
begin
  var t := Trim(s);
  result := TryStrToFloat(t, value) or TryStrToFloat(t.Replace(',', '.'), value, dotFormat);
end;

{ TValidationRule }

constructor TValidationRule.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FEnabled := true;
end;

procedure TValidationRule.Assign(Source: TPersistent);
begin
  if Source is TValidationRule then begin
    var s := TValidationRule(Source);
    setControl(s.FControl);
    setCompareTo(s.FCompareTo);
    FKind := s.FKind;
    FPattern := s.FPattern;
    FMessage := s.FMessage;
    FMinValue := s.FMinValue;
    FMaxValue := s.FMaxValue;
    FMinLength := s.FMinLength;
    FMaxLength := s.FMaxLength;
    FEnabled := s.FEnabled;
    FOnValidate := s.FOnValidate;
  end else inherited Assign(Source);
end;

function TValidationRule.GetDisplayName: string;
begin
  result := GetEnumName(TypeInfo(TValidationKind), ord(FKind));
  if FControl <> nil then result := FControl.Name+': '+result;
end;

function TValidationRule.rangeStored: boolean;
begin
  result := FKind = vkRange;
end;

procedure TValidationRule.setControl(value: TControl);
begin
  if FControl = value then exit;
  var v := TValidationRules(Collection).Owner as TValidator;
  if (FControl <> nil) and (v <> nil) then FControl.RemoveFreeNotification(v);
  FControl := value;
  if (FControl <> nil) and (v <> nil) then FControl.FreeNotification(v);
end;

procedure TValidationRule.setCompareTo(value: TControl);
begin
  if FCompareTo = value then exit;
  var v := TValidationRules(Collection).Owner as TValidator;
  if (FCompareTo <> nil) and (v <> nil) then FCompareTo.RemoveFreeNotification(v);
  FCompareTo := value;
  if (FCompareTo <> nil) and (v <> nil) then FCompareTo.FreeNotification(v);
end;

function TValidationRule.Check(const value: string): boolean;
begin
  var number: double;
  // an empty field passes every rule but Required, so optional fields work
  if (FKind <> vkRequired) and (FKind <> vkCustom) and (FKind <> vkSameAs) and (Trim(value) = '') then exit(true);
  match FKind of
    vkRequired: result := (Trim(value) <> '') and not SameText(value, 'False');
    vkPattern: result := (FPattern = '') or ExecRegExpr('^(?:'+FPattern+')$', value);
    vkEmail: result := ExecRegExpr('^[^@\s]+@[^@\s]+\.[^@\s.]+$', Trim(value));
    vkNumber: result := toNumber(value, number);
    vkInteger: begin
      var whole: Int64;
      result := TryStrToInt64(Trim(value), whole);
    end;
    vkRange: result := toNumber(value, number) and (number >= FMinValue) and (number <= FMaxValue);
    vkLength: begin
      var len := UTF8Length(value);
      result := (len >= FMinLength) and ((FMaxLength <= 0) or (len <= FMaxLength));
    end;
    vkSameAs: result := (FCompareTo = nil) or (value = TValidator.ValueOf(FCompareTo));
  else
    begin
      result := true;
      if Assigned(FOnValidate) then FOnValidate(self, value, result);
    end;
  end;
end;

function TValidationRule.ErrorText: string;
begin
  if FMessage <> '' then exit(FMessage);
  result := match FKind of
    vkRequired: 'This field is required.';
    vkPattern: 'The value has the wrong form.';
    vkEmail: 'Enter an e-mail address.';
    vkNumber: 'Enter a number.';
    vkInteger: 'Enter a whole number.';
    vkRange: Format('Enter a number from %g to %g.', [FMinValue, FMaxValue]);
    vkLength: if FMaxLength > 0 then Format('Use %d to %d characters.', [FMinLength, FMaxLength]) else Format('Use at least %d characters.', [FMinLength]);
    vkSameAs: 'The values do not match.';
  else
    'The value is not valid.'
  end;
end;

{ TValidationRules }

function TValidationRules.getItem(index: integer): TValidationRule;
begin
  result := TValidationRule(inherited Items[index]);
end;

procedure TValidationRules.setItem(index: integer; value: TValidationRule);
begin
  inherited Items[index] := value;
end;

function TValidationRules.Add: TValidationRule;
begin
  result := TValidationRule(inherited Add);
end;

function TValidationRules.AddRule(control: TControl; kind: TValidationKind; const message: string): TValidationRule;
begin
  result := Add;
  result.Control := control;
  result.FKind := kind;
  result.FMessage := message;
end;

{ TValidationMarker }

procedure TValidationMarker.Paint;
begin
  var back := GetRGBColorResolvingParent;
  var red := pick(FValidator.FErrorColor, if isDark(back) then RGBToColor(239, 83, 80) else RGBToColor(198, 40, 40));
  var sp := autofree beginShapes(Canvas, ClientRect, back, asTheme);
  var r := Min(ClientWidth, ClientHeight) div 2;
  paintCircle(sp, ClientWidth div 2, ClientHeight div 2, r-1, red, clNone);
  var lw := Max(r div 4, 1);
  paintLine(sp, ClientWidth div 2, ClientHeight div 2-r*45 div 100, ClientWidth div 2, ClientHeight div 2+r*10 div 100, contrastText(red), lw);
  paintCircle(sp, ClientWidth div 2, ClientHeight div 2+r*45 div 100, Max(lw*2 div 3, 1), contrastText(red), clNone);
  sp.Flush;
end;

{ TValidator }

constructor TValidator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRules := TValidationRules.Create(self, TValidationRule);
  FMode := vmOnExit;
  FShowMarkers := true;
  FErrorColor := clDefault;
  FErrors := TStringList.Create;
  FSeen := TStringList.Create;
  // a validator made in code gets no Loaded
  watch(true);
end;

destructor TValidator.Destroy;
begin
  watch(false);
  FreeAndNil(FRules);
  FErrors.Free;
  FSeen.Free;
  inherited Destroy;
end;

procedure TValidator.Loaded;
begin
  inherited Loaded;
  watch(true);
  updateSubmit;
end;

class function TValidator.ValueOf(control: TControl): string;
begin
  if control = nil then exit('');
  var p := GetPropInfo(control, 'Checked');
  if (p <> nil) and (p^.PropType^.Kind = tkBool) then exit(BoolToStr(GetOrdProp(control, p) <> 0, true));
  p := GetPropInfo(control, 'Text');
  if (p <> nil) and (p^.PropType^.Kind in [tkSString, tkLString, tkAString, tkUString, tkWString]) then exit(GetStrProp(control, p));
  result := control.Caption;
end;

function TValidator.checkControl(control: TControl; out message: string): boolean;
begin
  message := '';
  var value := ValueOf(control);
  for var i := 0 to FRules.Count-1 do begin
    var rule := FRules[i];
    if not rule.FEnabled or (rule.FControl <> control) then continue;
    if not rule.Check(value) then begin
      message := rule.ErrorText;
      exit(false);
    end;
  end;
  result := true;
end;

function TValidator.ErrorOf(control: TControl): string;
begin
  checkControl(control, result);
end;

function TValidator.IsValid: boolean;
begin
  for var i := 0 to FRules.Count-1 do
    if FRules[i].FEnabled and (FRules[i].FControl <> nil) and not FRules[i].Check(ValueOf(FRules[i].FControl)) then exit(false);
  result := true;
end;

function TValidator.ValidateControl(control: TControl): boolean;
begin
  var message: string;
  result := checkControl(control, message);
  mark(control, message);
  updateSubmit;
end;

function TValidator.Validate: boolean;
begin
  FErrors.Clear;
  result := true;
  var done := autofree TList.Create;
  for var i := 0 to FRules.Count-1 do begin
    var c := FRules[i].FControl;
    if (c = nil) or (done.IndexOf(c) >= 0) then continue;
    done.Add(c);
    var message: string;
    if not checkControl(c, message) then begin
      result := false;
      FErrors.Add(message);
    end;
    mark(c, message);
  end;
  updateSubmit;
  if Assigned(FOnValidated) then FOnValidated(self, result);
end;

// -- markers ----------------------

function TValidator.markerOf(control: TControl; create: boolean): TValidationMarker;
begin
  for var m in FMarkers do
    if m.control = control then exit(m.marker);
  result := nil;
  if not create or (control.Parent = nil) then exit;
  result := TValidationMarker.Create(self);
  result.FValidator := self;
  result.ShowHint := true;
  var k := length(FMarkers);
  SetLength(FMarkers, k+1);
  FMarkers[k].control := control;
  FMarkers[k].marker := result;
end;

// a sign next to the field with the message, or none
procedure TValidator.mark(control: TControl; const message: string);
begin
  if control = nil then exit;
  var m := markerOf(control, FShowMarkers and (message <> ''));
  if m = nil then exit;
  if (message = '') or not FShowMarkers then begin
    m.Visible := false;
    exit;
  end;
  var size := ControlPaint.scaled(control, 16);
  m.Parent := control.Parent;
  m.SetBounds(control.Left+control.Width+ControlPaint.scaled(control, 4), control.Top+(control.Height-size) div 2, size, size);
  m.Hint := message;
  m.Visible := true;
  m.BringToFront;
  m.Invalidate;
end;

procedure TValidator.ClearMarkers;
begin
  for var m in FMarkers do m.marker.Visible := false;
end;

procedure TValidator.updateSubmit;
begin
  if (FSubmitControl <> nil) and not (csDesigning in ComponentState) then FSubmitControl.Enabled := IsValid;
end;

// -- watching ----------------------

procedure TValidator.watch(active: boolean);
begin
  if csDesigning in ComponentState then exit;
  if active = FWatching then exit;
  FWatching := active;
  if active then begin
    Screen.AddHandlerActiveControlChanged(@activeChanged);
    FPoll := TTimer.Create(self);
    FPoll.Interval := 200;
    FPoll.OnTimer := @poll;
  end else begin
    Screen.RemoveHandlerActiveControlChanged(@activeChanged);
    FreeAndNil(FPoll);
  end;
end;

// the field the focus left gets checked; the screen passes the control
// that has the focus now, so the one before is kept here
procedure TValidator.activeChanged(Sender: TObject; LastControl: TControl);
begin
  var left := FFocused;
  if FFocused <> nil then FFocused.RemoveFreeNotification(self);
  FFocused := LastControl;
  if FFocused <> nil then FFocused.FreeNotification(self);
  if (FMode = vmOnExit) and (left <> nil) and (left <> LastControl) and (FRules <> nil) then
    for var i := 0 to FRules.Count-1 do
      if FRules[i].FControl = left then begin
        ValidateControl(left);
        if Assigned(FOnValidated) then FOnValidated(self, IsValid);
        break;
      end;
  if (FMode <> vmOnChange) then updateSubmit;
end;

// the fields whose value changed since the last look get checked
procedure TValidator.poll(Sender: TObject);
begin
  if FRules = nil then exit;
  var changed := false;
  for var i := 0 to FRules.Count-1 do begin
    var c := FRules[i].FControl;
    if c = nil then continue;
    var key := IntToHex(PtrUInt(c), 16);
    var value := ValueOf(c);
    var k := FSeen.IndexOfName(key);
    if (k >= 0) and (FSeen.ValueFromIndex[k] = value) then continue;
    if k >= 0 then FSeen.ValueFromIndex[k] := value else FSeen.Add(key+'='+value);
    // the first look only remembers, so untouched fields stay unmarked
    if k < 0 then continue;
    if FMode = vmOnChange then ValidateControl(c);
    changed := true;
  end;
  if changed then begin
    updateSubmit;
    if (FMode = vmOnChange) and Assigned(FOnValidated) then FOnValidated(self, IsValid);
  end;
end;

// -- properties ----------------------

procedure TValidator.setRules(value: TValidationRules);
begin
  FRules.Assign(value);
end;

procedure TValidator.setMode(value: TValidationMode);
begin
  FMode := value;
end;

procedure TValidator.setSubmitControl(value: TControl);
begin
  if FSubmitControl = value then exit;
  if FSubmitControl <> nil then FSubmitControl.RemoveFreeNotification(self);
  FSubmitControl := value;
  if FSubmitControl <> nil then FSubmitControl.FreeNotification(self);
  if not (csLoading in ComponentState) then updateSubmit;
end;

procedure TValidator.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  if AComponent = FSubmitControl then FSubmitControl := nil;
  if AComponent = FFocused then FFocused := nil;
  if FRules <> nil then
    for var i := 0 to FRules.Count-1 do begin
      if FRules[i].FControl = AComponent then FRules[i].FControl := nil;
      if FRules[i].FCompareTo = AComponent then FRules[i].FCompareTo := nil;
    end;
  for var k := length(FMarkers)-1 downto 0 do
    if (FMarkers[k].control = AComponent) or (FMarkers[k].marker = AComponent) then begin
      // the sign of a field that goes, goes with it
      if FMarkers[k].marker <> AComponent then FMarkers[k].marker.Free;
      Delete(FMarkers, k, 1);
    end;
end;

initialization
  dotFormat := DefaultFormatSettings;
  dotFormat.DecimalSeparator := '.';
  dotFormat.ThousandSeparator := #0;
end.
