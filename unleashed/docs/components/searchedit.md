# TSearchEdit

A search field: a magnifier, the text, a cross that clears it. The search fires on Enter and, after a pause in the typing, by itself.

- Palette page: Unleashed: Input
- Unit: `searchedit.pas`
- Ancestor: `TCustomControl`

![TSearchEdit](img/searchedit.png)

## Usage

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  var search := TSearchEdit.Create(Self);
  search.Parent := Self;
  search.Width := 240;
  search.TextHint := 'Search files';
  search.SearchDelay := 400;
  search.OnSearch := @searchSearch;
end;

procedure TForm1.searchSearch(Sender: TObject; const text: string);
begin
  Caption := 'looking for ' + text;
end;
```

## Properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` |  | the text |
| `TextHint` | `string` |  | the gray prompt in the empty field |
| `MaxLength` | `integer` | `0` | 0 for no limit |
| `CharCase` | `TEditCharCase` | `ecNormal` |  |
| `ReadOnly` | `boolean` | `false` | the mouse and the keyboard change nothing |
| `AutoSearch` | `boolean` | `true` | a search runs by itself SearchDelay milliseconds after the typing stops |
| `SearchDelay` | `integer` | `300` |  |
| `SearchOnEnter` | `boolean` | `true` |  |
| `ClearOnEscape` | `boolean` | `true` |  |
| `IconPosition` | `TSearchIconPosition` | `ipLeft` |  |
| `ClearButton` | `TClearButtonMode` | `cbWhenText` |  |
| `CornerRadius` | `integer` | `4` | the rounding of the corners, in pixels |
| `Padding` | `integer` | `6` | between the frame and the text |
| `IconSize` | `integer` | `0` | the glyphs; 0 takes the size from the font |
| `IconColor` | `TColor` | `clDefault` | clDefault takes the colors of the theme |
| `BorderColor` | `TColor` | `clDefault` | clDefault takes the color of the theme |
| `FocusBorderColor` | `TColor` | `clDefault` | the border while focused; clDefault takes the accent of the theme |
| `Antialiasing` | `TAntialiasSetting` | `asTheme` | the smoothing of the shapes: after the theme, or its own choice |

Also the standard properties of a control, re-published: `Align`, `Anchors`, `AutoSize`, `BorderSpacing`, `Color`, `Constraints`, `Enabled`, `Font`, `Hint`, `ParentColor`, `ParentFont`, `ParentShowHint`, `PopupMenu`, `ShowHint`, `TabOrder`, `TabStop`, `Visible`, `OnClick`, `OnContextPopup`, `OnEnter`, `OnExit`, `OnKeyDown`, `OnKeyPress`, `OnKeyUp`, `OnMouseEnter`, `OnMouseLeave`, `OnResize`.

## Events

| Event | Handler | Notes |
|---|---|---|
| `OnSearch` | `procedure(Sender: TObject; const text: string)` | the text to search for; fires on Enter, after a typing pause and after a clear |
| `OnClear` | `procedure(Sender: TObject)` |  |
| `OnChange` | `procedure(Sender: TObject)` | after the value changed |

## Runtime

Available in code, not in the Object Inspector.

| Property | Type | Notes |
|---|---|---|
| `Edit` | `TEdit` | the field inside |

| Method | Notes |
|---|---|
| `SetFocus` | moves the keyboard focus into the field |
| `Focused: Boolean` | the field has the keyboard focus |
| `Clear` | empties the field; fires OnClear and, with AutoSearch, a search for '' |
| `Search` | fires OnSearch with the text now, whatever the timing says |
| `SelectAll` | selects everything |

## Types

| Type | Values | Notes |
|---|---|---|
| `TClearButtonMode` | `cbWhenText`, `cbAlways`, `cbNever` |  |
| `TSearchIconPosition` | `ipLeft`, `ipRight`, `ipNone` |  |
