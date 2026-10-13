# TFileList

The files of one folder as rows: name, size, modified, type, with a colored mark per extension, a mask, sorting by any column and a double click that opens. Built on TDataTable, so it sorts, filters and selects like one.

- Palette page: Unleashed: Views
- Unit: `filelist.pas`
- Ancestor: `TDataTable`

![TFileList](img/filelist.png)

## Usage

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  var files := TFileList.Create(Self);
  files.Parent := Self;
  files.SetBounds(8, 8, 480, 300);
  files.Mask := '*.pas;*.lpr';
  files.Folder := GetCurrentDir;
  files.OnFileOpen := @fileOpen; // a double click or Enter
end;

procedure TForm1.fileOpen(Sender: TObject; const path: string);
begin
  Caption := path;
end;
```

## Properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `Folder` | `string` |  |  |
| `Mask` | `string` |  | the files shown, like *.pas;*.inc |
| `ShowHidden` | `boolean` | `false` | hidden files and folders are listed |
| `ShowFolders` | `boolean` | `true` |  |
| `ShowSize` | `boolean` | `true` |  |
| `ShowModified` | `boolean` | `true` |  |
| `ShowType` | `boolean` | `true` |  |
| `ShowParent` | `boolean` | `true` | a ".." row that goes up |

## Events

| Event | Handler | Notes |
|---|---|---|
| `OnFileOpen` | `procedure(Sender: TObject; const path: string)` | a double click on a file |
| `OnFolderChange` | `procedure(Sender: TObject; const path: string)` | the list moved into another folder |
| `OnFileColor` | `procedure(Sender: TObject; const path: string; var color: TColor)` | the color of the type mark of a file; comes in from the extension |

## Runtime

Available in code, not in the Object Inspector.

| Method | Notes |
|---|---|
| `Refresh` | reads the content again and repaints |
| `PathOf(row: integer): string` | the path of a shown row |
| `SelectedPath: string` | the path of the focused row, empty for none |
| `SelectedPaths(list: TStrings)` | the selected paths |
| `OpenSelected` | opens the folder or fires OnFileOpen for the focused row |
| `GoUp` | one folder up |
