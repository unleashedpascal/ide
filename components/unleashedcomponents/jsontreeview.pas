{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit JsonTreeView;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Controls, ComCtrls, fpjson, jsonparser;

type
  TJsonNodeKind = (jkNull, jkBoolean, jkNumber, jkString, jkArray, jkObject);
  TJsonFormatEvent = procedure(Sender: TObject; node: TTreeNode; data: TJSONData; var text: string) of object;

  { TJsonTreeView }

  // a tree of a JSON document: an object member per node, "key: value" for
  // the leaves, "key {n}" and "key [n]" for the containers. The JSON stays
  // attached, so a node knows its data and its path
  TJsonTreeView = class(TTreeView)
  private
    FJson: TJSONData;
    FText: string;
    FShowTypes, FSortKeys, FShowCounts, FQuoteStrings: boolean;
    FExpandDepth: integer;
    FImageIndexes: array[TJsonNodeKind] of integer;
    FOnFormatNode: TJsonFormatEvent;
    procedure setText(const value: string);
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setExpandDepth(value: integer);
    procedure setImageIndex(index: integer; value: integer);
    function getImageIndex(index: integer): integer;
    function kindOf(data: TJSONData): TJsonNodeKind;
    function labelOf(const key: string; data: TJSONData): string;
    procedure addChildren(parent: TTreeNode; data: TJSONData);
    procedure rebuild;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const fileName: string);
    procedure LoadFromStream(stream: TStream);
    // takes the ownership of `data`
    procedure SetJson(data: TJSONData);
    // the data behind a node, nil for none
    function DataOf(node: TTreeNode): TJSONData;
    // the JSON pointer of a node, like /items/0/name
    function PathOf(node: TTreeNode): string;
    // the node of a JSON pointer, nil when absent
    function NodeOf(const path: string): TTreeNode;
    procedure ExpandToDepth(depth: integer);
    property Json: TJSONData read FJson;
  published
    // the document; parsed as it is set
    property Text: string read FText write setText;
    // the type of each value after its label
    property ShowTypes: boolean index 0 read getFlag write setFlag default false;
    property SortKeys: boolean index 1 read getFlag write setFlag default false;
    // the member count after an object or an array
    property ShowCounts: boolean index 2 read getFlag write setFlag default true;
    property QuoteStrings: boolean index 3 read getFlag write setFlag default true;
    // levels open after a load; 0 keeps the tree folded, -1 opens it all
    property ExpandDepth: integer read FExpandDepth write setExpandDepth default 1;
    // image indexes per kind of value, -1 for none
    property NullImageIndex: integer index 0 read getImageIndex write setImageIndex default -1;
    property BooleanImageIndex: integer index 1 read getImageIndex write setImageIndex default -1;
    property NumberImageIndex: integer index 2 read getImageIndex write setImageIndex default -1;
    property StringImageIndex: integer index 3 read getImageIndex write setImageIndex default -1;
    property ArrayImageIndex: integer index 4 read getImageIndex write setImageIndex default -1;
    property ObjectImageIndex: integer index 5 read getImageIndex write setImageIndex default -1;
    // replaces the text of a node
    property OnFormatNode: TJsonFormatEvent read FOnFormatNode write FOnFormatNode;
  end;

implementation

constructor TJsonTreeView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FShowCounts := true;
  FQuoteStrings := true;
  FExpandDepth := 1;
  for var k := low(TJsonNodeKind) to high(TJsonNodeKind) do FImageIndexes[k] := -1;
  ReadOnly := true;
end;

destructor TJsonTreeView.Destroy;
begin
  FJson.Free;
  inherited Destroy;
end;

// -- loading ----------------------

procedure TJsonTreeView.LoadFromFile(const fileName: string);
begin
  var f := autofree TFileStream.Create(fileName, fmOpenRead or fmShareDenyWrite);
  LoadFromStream(f);
end;

procedure TJsonTreeView.LoadFromStream(stream: TStream);
begin
  var s := '';
  SetLength(s, stream.Size-stream.Position);
  if s <> '' then stream.ReadBuffer(s[1], length(s));
  setText(s);
end;

procedure TJsonTreeView.SetJson(data: TJSONData);
begin
  FJson.Free;
  FJson := data;
  FText := if data = nil then '' else data.FormatJSON;
  rebuild;
end;

procedure TJsonTreeView.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  FreeAndNil(FJson);
  if Trim(value) <> '' then
    try
      FJson := GetJSON(value);
    except
      FJson := nil;
    end;
  rebuild;
end;

// -- nodes ----------------------

function TJsonTreeView.kindOf(data: TJSONData): TJsonNodeKind;
begin
  if data = nil then exit(jkNull);
  result := match data.JSONType of
    jtBoolean: jkBoolean;
    jtNumber: jkNumber;
    jtString: jkString;
    jtArray: jkArray;
    jtObject: jkObject;
  else
    jkNull
  end;
end;

function TJsonTreeView.labelOf(const key: string; data: TJSONData): string;
begin
  // a float prints the JSON way, dot and no exponent, whatever the locale
  var plainFloat := DefaultFormatSettings;
  plainFloat.DecimalSeparator := '.';
  var value := match kindOf(data) of
    jkNull: 'null';
    jkBoolean: (if data.AsBoolean then 'true' else 'false');
    jkNumber: (if data is TJSONFloatNumber then FloatToStr(data.AsFloat, plainFloat) else data.AsString);
    jkString: (if FQuoteStrings then '"'+data.AsString+'"' else data.AsString);
    jkArray: (if FShowCounts then Format('[%d]', [data.Count]) else '[]');
  else
    (if FShowCounts then Format('{%d}', [data.Count]) else '{}')
  end;
  result := if key = '' then value else key+': '+value;
  if FShowTypes then result += '  ('+JSONTypeName(data.JSONType)+')';
end;

procedure TJsonTreeView.addChildren(parent: TTreeNode; data: TJSONData);
begin
  if data = nil then exit;
  if data.JSONType = jtObject then begin
    var obj := TJSONObject(data);
    var names := TStringList.Create;
    try
      for var i := 0 to obj.Count-1 do names.AddObject(obj.Names[i], TObject(PtrInt(i)));
      if FSortKeys then names.Sort;
      for var i := 0 to names.Count-1 do begin
        var child := obj.Items[PtrInt(names.Objects[i])];
        var text := labelOf(names[i], child);
        var node := Items.AddChildObject(parent, text, child);
        node.ImageIndex := FImageIndexes[kindOf(child)];
        node.SelectedIndex := node.ImageIndex;
        if Assigned(FOnFormatNode) then begin
          FOnFormatNode(self, node, child, text);
          node.Text := text;
        end;
        addChildren(node, child);
      end;
    finally
      names.Free;
    end;
  end else if data.JSONType = jtArray then begin
    for var i := 0 to data.Count-1 do begin
      var child := data.Items[i];
      var text := labelOf(IntToStr(i), child);
      var node := Items.AddChildObject(parent, text, child);
      node.ImageIndex := FImageIndexes[kindOf(child)];
      node.SelectedIndex := node.ImageIndex;
      if Assigned(FOnFormatNode) then begin
        FOnFormatNode(self, node, child, text);
        node.Text := text;
      end;
      addChildren(node, child);
    end;
  end;
end;

procedure TJsonTreeView.rebuild;
begin
  Items.BeginUpdate;
  try
    Items.Clear;
    if FJson <> nil then begin
      var root := Items.AddObject(nil, labelOf('', FJson), FJson);
      root.ImageIndex := FImageIndexes[kindOf(FJson)];
      root.SelectedIndex := root.ImageIndex;
      addChildren(root, FJson);
    end;
    ExpandToDepth(FExpandDepth);
  finally
    Items.EndUpdate;
  end;
end;

procedure TJsonTreeView.ExpandToDepth(depth: integer);
begin
  for var i := 0 to Items.Count-1 do begin
    var node := Items[i];
    node.Expanded := (depth < 0) or (node.Level < depth);
  end;
end;

function TJsonTreeView.DataOf(node: TTreeNode): TJSONData;
begin
  result := if node = nil then nil else TJSONData(node.Data);
end;

function TJsonTreeView.PathOf(node: TTreeNode): string;
begin
  result := '';
  while (node <> nil) and (node.Parent <> nil) do begin
    var parentData := DataOf(node.Parent);
    var key := if parentData.JSONType = jtArray then IntToStr(node.Index) else Copy(node.Text, 1, Pos(': ', node.Text+': ')-1);
    if parentData.JSONType = jtObject then key := TJSONObject(parentData).Names[TJSONObject(parentData).IndexOf(DataOf(node))];
    result := '/'+key+result;
    node := node.Parent;
  end;
end;

function TJsonTreeView.NodeOf(const path: string): TTreeNode;
begin
  result := nil;
  if Items.Count = 0 then exit;
  var node := Items[0];
  var parts := path.Split(['/'], TStringSplitOptions.ExcludeEmpty);
  for var part in parts do begin
    var found: TTreeNode := nil;
    var child := node.GetFirstChild;
    while child <> nil do begin
      var parentData := DataOf(node);
      var key := if parentData.JSONType = jtArray then IntToStr(child.Index) else TJSONObject(parentData).Names[TJSONObject(parentData).IndexOf(DataOf(child))];
      if key = part then begin
        found := child;
        break;
      end;
      child := child.GetNextSibling;
    end;
    if found = nil then exit;
    node := found;
  end;
  result := node;
end;

// -- properties ----------------------

function TJsonTreeView.getFlag(index: integer): boolean;
begin
  match index of
    0: result := FShowTypes;
    1: result := FSortKeys;
    2: result := FShowCounts;
    _: result := FQuoteStrings;
  end;
end;

procedure TJsonTreeView.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowTypes := value;
    1: FSortKeys := value;
    2: FShowCounts := value;
    _: FQuoteStrings := value;
  end;
  rebuild;
end;

procedure TJsonTreeView.setExpandDepth(value: integer);
begin
  if FExpandDepth = value then exit;
  FExpandDepth := value;
  ExpandToDepth(value);
end;

function TJsonTreeView.getImageIndex(index: integer): integer;
begin
  result := FImageIndexes[TJsonNodeKind(index)];
end;

procedure TJsonTreeView.setImageIndex(index: integer; value: integer);
begin
  if FImageIndexes[TJsonNodeKind(index)] = value then exit;
  FImageIndexes[TJsonNodeKind(index)] := value;
  rebuild;
end;

end.
