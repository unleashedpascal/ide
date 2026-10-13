# TQRCode

A QR code of Text, drawn to fill the control. The modules stay square; ModuleSize fixes their size instead of the fit.

- Palette page: Unleashed: Display
- Unit: `qrcode.pas`
- Ancestor: `TGraphicControl`

![TQRCode](img/qrcode.png)

## Usage

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
  var code := TQRCode.Create(Self);
  code.Parent := Self;
  code.SetBounds(8, 8, 160, 160);
  code.Text := 'https://unleashedpascal.org';
  code.ErrorLevel := qrQuartile;
  code.Rounded := true;
  code.SaveToFile('site.png', 8); // 8 pixels per module
end;
```

## Properties

| Property | Type | Default | Notes |
|---|---|---|---|
| `Text` | `string` |  | the text |
| `ErrorLevel` | `TQRErrorLevel` | `qrMedium` | how much of the code may be lost and still read: 7, 15, 25 or 30 percent |
| `ModuleSize` | `integer` | `0` | pixels per module; 0 fits the control |
| `QuietZone` | `integer` | `4` | light modules around the code, as the standard asks |
| `DarkColor` | `TColor` | `clBlack` | the color of the bars or modules |
| `LightColor` | `TColor` | `clWhite` | the color of the background |
| `Rounded` | `boolean` | `false` | the dark modules as dots instead of squares; scanners still read it |
| `TransparentLight` | `boolean` | `false` | the light modules show the parent; off, LightColor fills them |

Also the standard properties of a control, re-published: `Align`, `Anchors`, `AutoSize`, `BorderSpacing`, `Color`, `Constraints`, `Enabled`, `Hint`, `ParentColor`, `ParentShowHint`, `PopupMenu`, `ShowHint`, `Visible`, `OnClick`, `OnContextPopup`, `OnDblClick`, `OnMouseDown`, `OnMouseEnter`, `OnMouseLeave`, `OnMouseMove`, `OnMouseUp`, `OnResize`.

## Runtime

Available in code, not in the Object Inspector.

| Method | Notes |
|---|---|
| `Valid: boolean` | the text fits a code |
| `Size: integer` | modules on a side, 0 without a code |
| `SaveToBitmap(bitmap: TBitmap; scale: integer)` | the code into a bitmap, `scale` pixels per module |
| `SaveToFile(const fileName: string; scale: integer)` | writes the content to a file |

## Types

| Type | Values | Notes |
|---|---|---|
| `TQRErrorLevel` | `qrLow`, `qrMedium`, `qrQuartile`, `qrHigh` | how much of the code may be lost and still read: 7, 15, 25 or 30 percent |
