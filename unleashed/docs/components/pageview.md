# TPageView

Shows one of its children at a time, filling its whole area: the page PageIndex names. The others stay hidden, in the designer too, where selecting a page in the Object Inspector brings it up. There are no tabs: code, a TTabStrip, a TSegmentedControl or a timer picks the page.

- Palette page: Unleashed: Layout
- Unit: `pageview.pas`
- Ancestor: `TCustomControl`

## Usage

In the designer, a right click on the view (on the form or in the Object Inspector) offers Add Page, Delete Page, Next Page and Previous Page. Add Page drops a `TPageSheet` into the view and selects it; the controls of that page go on it as on any panel. A click on a page in the Object Inspector shows that page in the designer, so the pages never have to be stacked by hand. A `TTabStrip`, a `TSegmentedControl` or any other control switches the pages from its change event with `PageIndex := TabIndex`.

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  var pages := TPageView.Create(Self);
  pages.Parent := Self;
  pages.Align := alClient;
  for var i := 1 to 3 do begin
    var page := TPageSheet.Create(Self);
    page.Parent := pages; // each child is a page
    var title := TLabel.Create(Self);
    title.Parent := page;
    title.Caption := Format('Page %d', [i]);
  end;
  pages.OnPageChange := @pagesChange;
  pages.PageIndex := 1;
end;

procedure TForm1.pagesChange(Sender: TObject);
begin
  Caption := Format('page %d of %d', [TPageView(Sender).PageIndex + 1, TPageView(Sender).PageCount]);
end;
```

## Properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `PageIndex` | `integer` | `0` | the page shown, from 0; -1 shows none |

Also the standard properties of a control, re-published: `Align`, `Anchors`, `BorderSpacing`, `ClientHeight`, `ClientWidth`, `Color`, `Constraints`, `Enabled`, `Font`, `Hint`, `ParentColor`, `ParentFont`, `ParentShowHint`, `PopupMenu`, `ShowHint`, `TabOrder`, `Visible`, `OnClick`, `OnContextPopup`, `OnEnter`, `OnExit`, `OnMouseDown`, `OnMouseEnter`, `OnMouseLeave`, `OnMouseMove`, `OnMouseUp`, `OnMouseWheel`, `OnResize`.

## Events

| Event | Handler | Notes |
|---|---|---|
| `OnPageChange` | `procedure(Sender: TObject)` | the page shown changed |

## Runtime

Available in code, not in the Object Inspector.

| Property | Type | Notes |
|---|---|---|
| `ActivePage` | `TControl` | the page shown; nil while there is none |
| `Pages[index: integer]` | `TControl` | the children in their order |

| Method | Notes |
|---|---|
| `PageCount: integer` |  |
| `NextPage` | past the last page comes the first |
| `PreviousPage` |  |
| `ShowControl(AControl: TControl)` | the page holding AControl comes up; the designer calls it for a selection |

Every child of the view is a page, in the order of the children: a `TPageSheet` from the designer menu, or any panel dropped or reparented into the view. The view keeps each page at its client area and shows it only while it is the page of PageIndex; the designer neither moves a page nor shows a hidden one.

## Companion classes

### `TPageSheet`

A page of a TPageView: a plain panel the view keeps at its client area. The published properties of a panel without the position, the size and the alignment, which the view owns.

| Property | Type | Default | Notes |
|---|---|---|---|
| `BevelColor` | `TColor` | `clDefault` |  |
| `BevelInner` | `TPanelBevel` | `bvNone` |  |
| `BevelOuter` | `TPanelBevel` | `bvNone` |  |
| `BevelWidth` | `TBevelWidth` | `1` |  |
| `BorderWidth` | `TBorderWidth` | `0` |  |
| `Color` | `TColor` | `clDefault` | clDefault takes the color of the theme |
| `ParentBackground` | `boolean` | `true` |  |

Also re-published: `ChildSizing`, `ClientHeight`, `ClientWidth`, `Enabled`, `Font`, `ParentColor`, `ParentFont`, `ParentShowHint`, `PopupMenu`, `ShowHint`, `TabOrder`, `OnClick`, `OnContextPopup`, `OnDblClick`, `OnEnter`, `OnExit`, `OnMouseDown`, `OnMouseEnter`, `OnMouseLeave`, `OnMouseMove`, `OnMouseUp`, `OnMouseWheel`, `OnPaint`, `OnResize`.
