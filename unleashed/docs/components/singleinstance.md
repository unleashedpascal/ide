# TSingleInstance

Keeps the application to one running copy: a second start hands its command line to the first one through OnOtherInstance and leaves. Check runs on load; a call before Application.Run works as well.

- Palette page: Unleashed: System
- Unit: `appinstance.pas`
- Ancestor: `TComponent`

![TSingleInstance](img/singleinstance.png)

## Usage

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  var single := TSingleInstance.Create(Self);
  single.Id := 'unleashed-editor';
  single.OnOtherInstance := @otherInstance;
  single.OnAlreadyRunning := @alreadyRunning;
  single.Active := true;
end;

procedure TForm1.otherInstance(Sender: TObject; params: TStrings);
begin
  // the second copy passed its command line here and left
  if params.Count > 0 then Caption := params[0];
end;

procedure TForm1.alreadyRunning(Sender: TObject);
begin
  Application.Terminate;
end;
```

## Properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `Id` | `string` |  | the name the copies know each other by; empty takes the executable |
| `Active` | `boolean` | `true` | on; off stops it |
| `AllowOnlyOne` | `boolean` | `true` | a second copy hands its parameters over and leaves; off, it keeps running after the hand-over |
| `Global` | `boolean` | `false` | one copy for every user of the machine; off, one per session |

## Events

| Event | Handler | Notes |
|---|---|---|
| `OnOtherInstance` | `procedure(Sender: TObject; params: TStrings)` | the first copy got the command line of a second one |
| `OnStarted` | `procedure(Sender: TObject)` | this copy is the one |
| `OnAlreadyRunning` | `procedure(Sender: TObject)` | this copy found another one running: its parameters went there |

## Runtime

Available in code, not in the Object Inspector.

| Property | Type | Notes |
|---|---|---|
| `OtherRunning` | `boolean` | another copy was running at the check |

| Method | Notes |
|---|---|
| `Check: boolean` | looks for a running copy; true when this is the only one. Otherwise the parameters went to the other copy, OnAlreadyRunning fired and, with AllowOnlyOne, the application leaves |
