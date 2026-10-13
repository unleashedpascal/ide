{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit Animator;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Graphics, ExtCtrls, TypInfo;

type
  TAnimationEasing = (aeLinear, aeEaseIn, aeEaseOut, aeEaseInOut, aeBack, aeElastic, aeBounce);
  TAnimationLoop = (alNone, alRepeat, alPingPong);
  TAnimationStepEvent = procedure(Sender: TObject; progress: double) of object;
  EAnimatorError = class(Exception);

  { TAnimator }

  // moves a published property of a component from one value to another
  // over time: numbers, sizes, positions and colors glide, an enumeration
  // or a boolean switches at the end. The property can sit deeper, as
  // Font.Size. Next starts once this one ends, so animators chain
  TAnimator = class(TComponent)
  private
    FTarget: TComponent;
    FPropertyName, FStartValue, FEndValue: string;
    FDuration, FDelay, FLoopCount: integer;
    FEasing: TAnimationEasing;
    FLoop: TAnimationLoop;
    FAutoStart: boolean;
    FNext: TAnimator;
    FTimer: TTimer;
    FStarted, FPausedAt: QWord;
    FRunning, FPaused, FBackwards: boolean;
    FCycle: integer;
    FProgress: double;
    // what the run animates, resolved at the start
    FObject: TObject;
    FProp: PPropInfo;
    FKind: (vkNumber, vkColor, vkSwitch);
    FFrom, FTo: double;
    FFromColor, FToColor: TColor;
    FSwitchTo: string;
    FOnStart, FOnFinish: TNotifyEvent;
    FOnStep: TAnimationStepEvent;
    procedure setTarget(value: TComponent);
    procedure setNext(value: TAnimator);
    procedure tick(Sender: TObject);
    procedure resolve;
    procedure prepare;
    procedure launch;
    procedure apply(t: double);
    function readValue: string;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // the eased share for a share of the time, both 0 to 1
    class function Ease(easing: TAnimationEasing; t: double): double;
    procedure Start;
    // stops where it is, or puts the end value first
    procedure Stop(jumpToEnd: boolean = false);
    procedure Pause;
    procedure Resume;
    // turns the run where it is; after a run ended, goes over its values
    // the other way
    procedure Reverse;
    property Running: boolean read FRunning;
    property Paused: boolean read FPaused;
    // the share of the time gone, 0 to 1
    property Progress: double read FProgress;
  published
    property Target: TComponent read FTarget write setTarget;
    // a published property of Target, or one deeper, as Font.Size
    property PropertyName: string read FPropertyName write FPropertyName;
    // empty starts from the value the property has
    property StartValue: string read FStartValue write FStartValue;
    // a number with a `.` decimal point, a color as clRed or $00RRGGBB in
    // BGR, or the name of an enumeration value
    property EndValue: string read FEndValue write FEndValue;
    // milliseconds
    property Duration: integer read FDuration write FDuration default 300;
    property Delay: integer read FDelay write FDelay default 0;
    property Easing: TAnimationEasing read FEasing write FEasing default aeEaseInOut;
    property Loop: TAnimationLoop read FLoop write FLoop default alNone;
    // the runs of a loop; 0 runs on until Stop
    property LoopCount: integer read FLoopCount write FLoopCount default 0;
    // starts once the form holding it has loaded
    property AutoStart: boolean read FAutoStart write FAutoStart default false;
    property Next: TAnimator read FNext write setNext;
    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;
    property OnStep: TAnimationStepEvent read FOnStep write FOnStep;
  end;

implementation

uses
  Math;

var
  dotFormat: TFormatSettings;

constructor TAnimator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDuration := 300;
  FEasing := aeEaseInOut;
  FTimer := TTimer.Create(self);
  FTimer.Enabled := false;
  FTimer.Interval := 16;
  FTimer.OnTimer := @tick;
end;

destructor TAnimator.Destroy;
begin
  FTimer.Enabled := false;
  inherited Destroy;
end;

procedure TAnimator.Loaded;
begin
  inherited Loaded;
  if FAutoStart and not (csDesigning in ComponentState) then Start;
end;

procedure TAnimator.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then exit;
  if AComponent = FTarget then begin
    FTimer.Enabled := false;
    FRunning := false;
    FTarget := nil;
    FObject := nil;
  end;
  if AComponent = FNext then FNext := nil;
end;

procedure TAnimator.setTarget(value: TComponent);
begin
  if FTarget = value then exit;
  if FTarget <> nil then FTarget.RemoveFreeNotification(self);
  FTarget := value;
  FObject := nil;
  if FTarget <> nil then FTarget.FreeNotification(self);
end;

procedure TAnimator.setNext(value: TAnimator);
begin
  if FNext = value then exit;
  if FNext <> nil then FNext.RemoveFreeNotification(self);
  FNext := value;
  if FNext <> nil then FNext.FreeNotification(self);
end;

class function TAnimator.Ease(easing: TAnimationEasing; t: double): double;
begin
  t := EnsureRange(t, 0, 1);
  match easing of
    aeEaseIn: result := t*t*t;
    aeEaseOut: result := 1-Power(1-t, 3);
    aeEaseInOut: result := if t < 0.5 then 4*t*t*t else 1-Power(-2*t+2, 3)/2;
    aeBack: begin
      // goes a little past the end and comes back
      var c1 := 1.70158;
      var c3 := c1+1;
      result := 1+c3*Power(t-1, 3)+c1*Power(t-1, 2);
    end;
    aeElastic: result := if (t = 0) or (t = 1) then t else Power(2, -10*t)*Sin((t*10-0.75)*(2*Pi/3))+1;
    aeBounce: begin
      var n1 := 7.5625;
      var d1 := 2.75;
      if t < 1/d1 then result := n1*t*t
      else if t < 2/d1 then begin
        t -= 1.5/d1;
        result := n1*t*t+0.75;
      end else if t < 2.5/d1 then begin
        t -= 2.25/d1;
        result := n1*t*t+0.9375;
      end else begin
        t -= 2.625/d1;
        result := n1*t*t+0.984375;
      end;
    end;
  else
    result := t;
  end;
end;

// -- the property ----------------------

// the object that holds the last part of the path and its property
procedure TAnimator.resolve;
begin
  if FTarget = nil then raise EAnimatorError.Create('TAnimator has no Target');
  var parts := FPropertyName.Split(['.']);
  if length(parts) = 0 then raise EAnimatorError.Create('TAnimator has no PropertyName');
  var obj: TObject := FTarget;
  for var i := 0 to length(parts)-2 do begin
    var p := GetPropInfo(obj, parts[i]);
    if (p = nil) or (p^.PropType^.Kind <> tkClass) then raise EAnimatorError.CreateFmt('%s has no object property %s', [obj.ClassName, parts[i]]);
    obj := GetObjectProp(obj, p);
    if obj = nil then raise EAnimatorError.CreateFmt('%s of %s is nil', [parts[i], FTarget.Name]);
  end;
  FObject := obj;
  FProp := GetPropInfo(obj, parts[length(parts)-1]);
  if FProp = nil then raise EAnimatorError.CreateFmt('%s has no property %s', [obj.ClassName, parts[length(parts)-1]]);
  var typeName := FProp^.PropType^.Name;
  match FProp^.PropType^.Kind of
    tkInteger, tkInt64, tkFloat:
      FKind := if SameText(typeName, 'TColor') or SameText(typeName, 'TGraphicsColor') then vkColor else vkNumber;
    tkEnumeration, tkBool, tkSString, tkLString, tkAString, tkUString, tkWString:
      FKind := vkSwitch;
  else
    raise EAnimatorError.CreateFmt('%s cannot animate a %s', [ClassName, typeName]);
  end;
end;

function TAnimator.readValue: string;
begin
  match FProp^.PropType^.Kind of
    tkFloat: result := FloatToStr(GetFloatProp(FObject, FProp), dotFormat);
    tkInt64: result := IntToStr(GetInt64Prop(FObject, FProp));
    tkInteger: result := IntToStr(GetOrdProp(FObject, FProp));
    tkEnumeration, tkBool: result := GetEnumProp(FObject, FProp);
  else
    result := GetStrProp(FObject, FProp);
  end;
end;

procedure TAnimator.apply(t: double);
begin
  if FObject = nil then exit;
  match FKind of
    vkColor: begin
      var a := ColorToRGB(FFromColor);
      var b := ColorToRGB(FToColor);
      var mix := function(shift: integer): integer
      begin
        var x := (a shr shift) and $FF;
        var y := (b shr shift) and $FF;
        result := EnsureRange(Round(x+(y-x)*t), 0, 255) shl shift;
      end;
      SetOrdProp(FObject, FProp, mix(0) or mix(8) or mix(16));
    end;
    vkNumber: begin
      var v := FFrom+(FTo-FFrom)*t;
      match FProp^.PropType^.Kind of
        tkFloat: SetFloatProp(FObject, FProp, v);
        tkInt64: SetInt64Prop(FObject, FProp, Round(v));
      else
        SetOrdProp(FObject, FProp, Round(v));
      end;
    end;
  else
    // a switch has no steps between, it takes the end value at the end
    if t >= 1 then
      match FProp^.PropType^.Kind of
        tkEnumeration, tkBool: SetEnumProp(FObject, FProp, FSwitchTo);
      else
        SetStrProp(FObject, FProp, FSwitchTo);
      end;
  end;
end;

// -- running ----------------------

// the object, the property and the two values of a run
procedure TAnimator.prepare;
begin
  resolve;
  var startText := if FStartValue <> '' then FStartValue else readValue;
  match FKind of
    vkColor: begin
      FFromColor := StringToColor(startText);
      FToColor := StringToColor(FEndValue);
    end;
    vkNumber: begin
      FFrom := StrToFloat(startText, dotFormat);
      FTo := StrToFloat(FEndValue, dotFormat);
    end;
  else
    FSwitchTo := FEndValue;
  end;
end;

// a run over the prepared values from the start of its time
procedure TAnimator.launch;
begin
  FCycle := 0;
  FProgress := 0;
  FPaused := false;
  FRunning := true;
  FStarted := GetTickCount64;
  FTimer.Enabled := true;
  if Assigned(FOnStart) then FOnStart(self);
end;

procedure TAnimator.Start;
begin
  if csDesigning in ComponentState then exit;
  prepare;
  FBackwards := false;
  if FStartValue <> '' then apply(0);
  launch;
end;

procedure TAnimator.Stop(jumpToEnd: boolean);
begin
  if not FRunning then exit;
  FTimer.Enabled := false;
  FRunning := false;
  FPaused := false;
  if jumpToEnd then begin
    FProgress := 1;
    apply(1);
  end;
end;

procedure TAnimator.Pause;
begin
  if not FRunning or FPaused then exit;
  FPaused := true;
  FPausedAt := GetTickCount64;
  FTimer.Enabled := false;
end;

procedure TAnimator.Resume;
begin
  if not FPaused then exit;
  FPaused := false;
  FStarted += GetTickCount64-FPausedAt;
  FTimer.Enabled := true;
end;

procedure TAnimator.Reverse;
begin
  if csDesigning in ComponentState then exit;
  if not FRunning then begin
    // the values of the last run from its end; read again, the start would
    // be where the last run left the property
    if FObject = nil then begin
      prepare;
      FBackwards := false;
    end;
    launch;
    FProgress := 1;
  end;
  // the time left becomes the time gone, so the run turns where it is
  var gone := Round((1-FProgress)*Max(FDuration, 1));
  FStarted := GetTickCount64-QWord(Max(FDelay, 0)+gone);
  FBackwards := not FBackwards;
end;

procedure TAnimator.tick(Sender: TObject);
begin
  if not FRunning then exit;
  var elapsed := Int64(GetTickCount64-FStarted)-Max(FDelay, 0);
  if elapsed < 0 then exit;
  FProgress := Min(elapsed/Max(FDuration, 1), 1);
  var t := Ease(FEasing, if FBackwards then 1-FProgress else FProgress);
  try
    apply(t);
  except
    // a target that refuses the value stops the run instead of ticking on
    Stop;
    raise;
  end;
  if Assigned(FOnStep) then FOnStep(self, FProgress);
  if FProgress < 1 then exit;
  inc(FCycle);
  if (FLoop <> alNone) and ((FLoopCount = 0) or (FCycle < FLoopCount)) then begin
    if FLoop = alPingPong then FBackwards := not FBackwards;
    FStarted := GetTickCount64-QWord(Max(FDelay, 0));
    FProgress := 0;
    exit;
  end;
  FTimer.Enabled := false;
  FRunning := false;
  if Assigned(FOnFinish) then FOnFinish(self);
  if FNext <> nil then FNext.Start;
end;

initialization
  dotFormat := DefaultFormatSettings;
  dotFormat.DecimalSeparator := '.';
  dotFormat.ThousandSeparator := #0;
end.
