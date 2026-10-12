# TRecentFiles

The files opened last, newest first, as entries of a menu and as a list kept in a file between the runs.

- Palette page: Unleashed: System
- Unit: `recentfiles.pas`
- Ancestor: `TComponent`

![TRecentFiles](img/recentfiles.png)

## Usage

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  var menu := TMainMenu.Create(Self);
  var fileMenu := TMenuItem.Create(menu);
  fileMenu.Caption := 'File';
  menu.Items.Add(fileMenu);
  var recentRoot := TMenuItem.Create(menu);
  recentRoot.Caption := 'Recent';
  fileMenu.Add(recentRoot);
  var recent := TRecentFiles.Create(Self);
  recent.MenuItem := recentRoot; // the entries appear under it
  recent.StorageFile := GetAppConfigDir(false) + 'recent.txt';
  recent.OnOpen := @recentOpen;
  recent.Load;
  recent.Add('notes.txt'); // after every open or save
end;

procedure TForm1.recentOpen(Sender: TObject; const fileName: string);
begin
  Caption := fileName;
end;
```

## Properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `MaxItems` | `integer` | `10` | the oldest entries drop out above this count, 0 for no limit |
| `MaxLength` | `integer` | `60` | longer paths show their start and their end; 0 shows them whole |
| `MenuItem` | `TMenuItem` |  | the menu entry whose submenu lists the files |
| `StorageFile` | `string` |  | the list goes to this file; empty keeps it in memory only |
| `ShowNumbers` | `boolean` | `true` |  |
| `ShowClearItem` | `boolean` | `true` |  |
| `AutoSave` | `boolean` | `true` | every change goes to the storage file at once |
| `DropMissing` | `boolean` | `true` | files that no longer exist leave the list when it is loaded |
| `ClearCaption` | `string` |  | the caption of the clear entry |

## Events

| Event | Handler | Notes |
|---|---|---|
| `OnOpen` | `procedure(Sender: TObject; const fileName: string)` |  |
| `OnChange` | `procedure(Sender: TObject)` | after the value changed |

## Runtime

Available in code, not in the Object Inspector.

| Property | Type | Notes |
|---|---|---|
| `Items` | `TStringList` | the entries |

| Method | Notes |
|---|---|
| `Add(const fileName: string)` | puts the file first |
| `Remove(const fileName: string)` |  |
| `Clear` | removes everything |
| `Load` | reads the file |
| `Save` | writes the file |
| `Count: integer` | the number of entries |
