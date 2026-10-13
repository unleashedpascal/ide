{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit NodeEditor;

{$mode unleashed}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Forms, LCLType, ControlPaint;

type
  TNodeEditor = class;
  TGraphNode = class;
  TGraphLink = class;
  TNodeEvent = procedure(Sender: TObject; node: TGraphNode) of object;
  TLinkEvent = procedure(Sender: TObject; link: TGraphLink) of object;
  // a link is about to be made; allow false refuses it
  TLinkAllowEvent = procedure(Sender: TObject; fromNode: TGraphNode; fromPort: integer; toNode: TGraphNode; toPort: integer; var allow: boolean) of object;

  { TGraphNode }

  TGraphNode = class(TCollectionItem)
  private
    FCaption, FText: string;
    FLeft, FTop, FWidth: integer; // in graph coordinates
    FColor: TColor;
    FInputs, FOutputs: TStrings; // the names of the ports
    FTag: PtrInt;
    FData: TObject;
    FZ: integer; // the last time the node came to the front
    procedure setCaption(const value: string);
    procedure setText(const value: string);
    procedure setPos(index: integer; value: integer);
    function getPos(index: integer): integer;
    procedure setColor(value: TColor);
    procedure setPorts(index: integer; value: TStrings);
    procedure portsChanged(Sender: TObject);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    // an object of the application the node stands for; not owned
    property Data: TObject read FData write FData;
  published
    property Caption: string read FCaption write setCaption;
    // a line under the caption
    property Text: string read FText write setText;
    property Left: integer index 0 read getPos write setPos default 0;
    property Top: integer index 1 read getPos write setPos default 0;
    property Width: integer index 2 read getPos write setPos default 140;
    // the header; clDefault takes a color from the palette
    property Color: TColor read FColor write setColor default clDefault;
    // the ports on the left, one name per line
    property Inputs: TStrings index 0 read FInputs write setPorts;
    // the ports on the right
    property Outputs: TStrings index 1 read FOutputs write setPorts;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TGraphNodes }

  TGraphNodes = class(TOwnedCollection)
  private
    function getItem(index: integer): TGraphNode;
    procedure setItem(index: integer; value: TGraphNode);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TGraphNode;
    property Items[index: integer]: TGraphNode read getItem write setItem; default;
  end;

  { TGraphLink }

  TGraphLink = class(TCollectionItem)
  private
    FFromNode, FFromPort, FToNode, FToPort: integer;
    FColor: TColor;
    FCaption: string;
    FTag: PtrInt;
    procedure setEnd(index: integer; value: integer);
    function getEnd(index: integer): integer;
    procedure setColor(value: TColor);
    procedure setCaption(const value: string);
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    // the index of the node and of its output the link leaves
    property FromNode: integer index 0 read getEnd write setEnd default -1;
    property FromPort: integer index 1 read getEnd write setEnd default 0;
    // the index of the node and of its input the link enters
    property ToNode: integer index 2 read getEnd write setEnd default -1;
    property ToPort: integer index 3 read getEnd write setEnd default 0;
    property Color: TColor read FColor write setColor default clDefault;
    property Caption: string read FCaption write setCaption;
    property Tag: PtrInt read FTag write FTag default 0;
  end;

  { TGraphLinks }

  TGraphLinks = class(TOwnedCollection)
  private
    function getItem(index: integer): TGraphLink;
    procedure setItem(index: integer; value: TGraphLink);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TGraphLink;
    property Items[index: integer]: TGraphLink read getItem write setItem; default;
  end;

  { TNodeEditor }

  // boxes with ports and curves between them, on a canvas that pans with
  // a drag of the background and zooms with the wheel. A node moves by its
  // header, a link starts on an output and ends on an input, the Delete
  // key removes what is selected
  TNodeEditor = class(TCustomControl)
  private
    FNodes: TGraphNodes;
    FLinks: TGraphLinks;
    FZoom: double;
    FPan: TPoint; // the graph point at the top left, in graph units
    FGridSize, FPortRadius, FHeaderHeight, FCornerRadius, FPadding: integer;
    FShowGrid, FSnapToGrid, FAllowLinks, FAllowMove, FReadOnly, FShowPortNames: boolean;
    FBackColor, FGridColor, FNodeColor, FBorderColor, FTextColor, FLinkColor, FPortColor, FSelectColor: TColor;
    FAntialiasing: TAntialiasSetting;
    FSelectedNode: TGraphNode;
    FSelectedLink: TGraphLink;
    FHotNode: TGraphNode;
    FHotPort, FHotPortIsInput: integer; // the port under the mouse
    FDragNode: TGraphNode;
    FDragOffset: TPoint;
    FPanning: boolean;
    FPanStart, FPanOrigin: TPoint;
    FLinking: boolean;
    FLinkFrom: TGraphNode;
    FLinkPort: integer;
    FMouse: TPoint;
    FZCounter: integer;
    FDrawOrder: array of TGraphNode; // the nodes from the back to the front
    FOnNodeClick, FOnNodeDblClick, FOnNodeMoved, FOnSelectNode: TNodeEvent;
    FOnLinkCreated, FOnLinkDeleted, FOnSelectLink: TLinkEvent;
    FOnLinkAllow: TLinkAllowEvent;
    FOnChange: TNotifyEvent;
    procedure setNodes(value: TGraphNodes);
    procedure setLinks(value: TGraphLinks);
    procedure setZoom(value: double);
    procedure setMetric(index: integer; value: integer);
    function getMetric(index: integer): integer;
    procedure setFlag(index: integer; value: boolean);
    function getFlag(index: integer): boolean;
    procedure setPartColor(index: integer; value: TColor);
    function getPartColor(index: integer): TColor;
    procedure setAntialiasing(value: TAntialiasSetting);
    function toScreen(x, y: integer): TPoint;
    function toGraph(x, y: integer): TPoint;
    function nodeRect(node: TGraphNode): TRect; // in graph units
    function nodeHeight(node: TGraphNode): integer;
    function portPoint(node: TGraphNode; index: integer; input: boolean): TPoint; // graph
    function nodeAt(x, y: integer): TGraphNode;
    procedure sortOrder;
    procedure bringToFront(node: TGraphNode);
    function screenRect(node: TGraphNode): TRect;
    procedure paintNodeText(node: TGraphNode; const s: TRect; pr: integer; text, nodeBack: TColor; lh: integer);
    function portAt(x, y: integer; out node: TGraphNode; out index: integer; out input: boolean): boolean;
    function linkAt(x, y: integer): TGraphLink;
    function headerOf(node: TGraphNode): TColor;
    procedure linkCurve(const a, b: TPoint; out pts: array of TPointF; out count: integer);
    procedure changed;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure DblClick; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    class function GetControlClassDefaultSize: TSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddNode(const caption: string; left, top: integer; const inputs: array of string; const outputs: array of string): TGraphNode;
    function AddLink(fromNode, fromPort, toNode, toPort: integer): TGraphLink;
    // the links of a node, as input or output
    procedure LinksOf(node: TGraphNode; list: TList);
    procedure DeleteNode(node: TGraphNode);
    procedure DeleteLink(link: TGraphLink);
    procedure DeleteSelected;
    // the view moved so every node shows
    procedure FitToView;
    procedure CenterOn(node: TGraphNode);
    property Selected: TGraphNode read FSelectedNode;
    property SelectedLink: TGraphLink read FSelectedLink;
    property Pan: TPoint read FPan write FPan;
  published
    property Nodes: TGraphNodes read FNodes write setNodes;
    property Links: TGraphLinks read FLinks write setLinks;
    property Zoom: double read FZoom write setZoom;
    property GridSize: integer index 0 read getMetric write setMetric default 20;
    property PortRadius: integer index 1 read getMetric write setMetric default 5;
    property HeaderHeight: integer index 2 read getMetric write setMetric default 24;
    property CornerRadius: integer index 3 read getMetric write setMetric default 6;
    property Padding: integer index 4 read getMetric write setMetric default 8;
    property ShowGrid: boolean index 0 read getFlag write setFlag default true;
    property SnapToGrid: boolean index 1 read getFlag write setFlag default true;
    property AllowLinks: boolean index 2 read getFlag write setFlag default true;
    property AllowMove: boolean index 3 read getFlag write setFlag default true;
    property ReadOnly: boolean index 4 read getFlag write setFlag default false;
    property ShowPortNames: boolean index 5 read getFlag write setFlag default true;
    // clDefault takes the colors of the theme
    property BackColor: TColor index 0 read getPartColor write setPartColor default clDefault;
    property GridColor: TColor index 1 read getPartColor write setPartColor default clDefault;
    property NodeColor: TColor index 2 read getPartColor write setPartColor default clDefault;
    property BorderColor: TColor index 3 read getPartColor write setPartColor default clDefault;
    property TextColor: TColor index 4 read getPartColor write setPartColor default clDefault;
    property LinkColor: TColor index 5 read getPartColor write setPartColor default clDefault;
    property PortColor: TColor index 6 read getPartColor write setPartColor default clDefault;
    property SelectColor: TColor index 7 read getPartColor write setPartColor default clDefault;
    property Antialiasing: TAntialiasSetting read FAntialiasing write setAntialiasing default asTheme;
    property OnNodeClick: TNodeEvent read FOnNodeClick write FOnNodeClick;
    property OnNodeDblClick: TNodeEvent read FOnNodeDblClick write FOnNodeDblClick;
    property OnNodeMoved: TNodeEvent read FOnNodeMoved write FOnNodeMoved;
    property OnSelectNode: TNodeEvent read FOnSelectNode write FOnSelectNode;
    property OnSelectLink: TLinkEvent read FOnSelectLink write FOnSelectLink;
    property OnLinkCreated: TLinkEvent read FOnLinkCreated write FOnLinkCreated;
    property OnLinkDeleted: TLinkEvent read FOnLinkDeleted write FOnLinkDeleted;
    property OnLinkAllow: TLinkAllowEvent read FOnLinkAllow write FOnLinkAllow;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Align;
    property Anchors;
    property BorderSpacing;
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
    property OnDblClick;
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
  Math;

const
  PALETTE: array[0..5] of TColor = ($D98B3B, $5CB85C, $F0AD4E, $B35CA0, $17A2B8, $D9534F);

{ TGraphNode }

constructor TGraphNode.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FWidth := 140;
  FColor := clDefault;
  FInputs := TStringList.Create;
  FOutputs := TStringList.Create;
  TStringList(FInputs).OnChange := @portsChanged;
  TStringList(FOutputs).OnChange := @portsChanged;
end;

destructor TGraphNode.Destroy;
begin
  FInputs.Free;
  FOutputs.Free;
  inherited Destroy;
end;

procedure TGraphNode.Assign(Source: TPersistent);
begin
  if Source is TGraphNode then begin
    var s := TGraphNode(Source);
    FCaption := s.FCaption;
    FText := s.FText;
    FLeft := s.FLeft;
    FTop := s.FTop;
    FWidth := s.FWidth;
    FColor := s.FColor;
    FInputs.Assign(s.FInputs);
    FOutputs.Assign(s.FOutputs);
    FTag := s.FTag;
    FData := s.FData;
    Changed(false);
  end else inherited Assign(Source);
end;

function TGraphNode.GetDisplayName: string;
begin
  result := if FCaption <> '' then FCaption else inherited GetDisplayName;
end;

procedure TGraphNode.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

procedure TGraphNode.setText(const value: string);
begin
  if FText = value then exit;
  FText := value;
  Changed(false);
end;

function TGraphNode.getPos(index: integer): integer;
begin
  result := match index of
    0: FLeft;
    1: FTop;
  else
    FWidth
  end;
end;

procedure TGraphNode.setPos(index: integer; value: integer);
begin
  if index = 2 then value := Max(value, 60);
  if getPos(index) = value then exit;
  match index of
    0: FLeft := value;
    1: FTop := value;
  else
    FWidth := value;
  end;
  Changed(false);
end;

procedure TGraphNode.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TGraphNode.setPorts(index: integer; value: TStrings);
begin
  if index = 0 then FInputs.Assign(value) else FOutputs.Assign(value);
end;

procedure TGraphNode.portsChanged(Sender: TObject);
begin
  Changed(false);
end;

{ TGraphNodes }

function TGraphNodes.getItem(index: integer): TGraphNode;
begin
  result := TGraphNode(inherited Items[index]);
end;

procedure TGraphNodes.setItem(index: integer; value: TGraphNode);
begin
  inherited Items[index] := value;
end;

function TGraphNodes.Add: TGraphNode;
begin
  result := TGraphNode(inherited Add);
end;

procedure TGraphNodes.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TNodeEditor then TNodeEditor(Owner).Invalidate;
end;

{ TGraphLink }

constructor TGraphLink.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FFromNode := -1;
  FToNode := -1;
  FColor := clDefault;
end;

procedure TGraphLink.Assign(Source: TPersistent);
begin
  if Source is TGraphLink then begin
    var s := TGraphLink(Source);
    FFromNode := s.FFromNode;
    FFromPort := s.FFromPort;
    FToNode := s.FToNode;
    FToPort := s.FToPort;
    FColor := s.FColor;
    FCaption := s.FCaption;
    FTag := s.FTag;
    Changed(false);
  end else inherited Assign(Source);
end;

function TGraphLink.getEnd(index: integer): integer;
begin
  result := match index of
    0: FFromNode;
    1: FFromPort;
    2: FToNode;
  else
    FToPort
  end;
end;

procedure TGraphLink.setEnd(index: integer; value: integer);
begin
  if getEnd(index) = value then exit;
  match index of
    0: FFromNode := value;
    1: FFromPort := value;
    2: FToNode := value;
  else
    FToPort := value;
  end;
  Changed(false);
end;

procedure TGraphLink.setColor(value: TColor);
begin
  if FColor = value then exit;
  FColor := value;
  Changed(false);
end;

procedure TGraphLink.setCaption(const value: string);
begin
  if FCaption = value then exit;
  FCaption := value;
  Changed(false);
end;

{ TGraphLinks }

function TGraphLinks.getItem(index: integer): TGraphLink;
begin
  result := TGraphLink(inherited Items[index]);
end;

procedure TGraphLinks.setItem(index: integer; value: TGraphLink);
begin
  inherited Items[index] := value;
end;

function TGraphLinks.Add: TGraphLink;
begin
  result := TGraphLink(inherited Add);
end;

procedure TGraphLinks.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Owner is TNodeEditor then TNodeEditor(Owner).Invalidate;
end;

{ TNodeEditor }

constructor TNodeEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle+[csOpaque, csDoubleClicks]-[csSetCaption, csAcceptsControls];
  FNodes := TGraphNodes.Create(self, TGraphNode);
  FLinks := TGraphLinks.Create(self, TGraphLink);
  FZoom := 1;
  FGridSize := 20;
  FPortRadius := 5;
  FHeaderHeight := 24;
  FCornerRadius := 6;
  FPadding := 8;
  FShowGrid := true;
  FSnapToGrid := true;
  FAllowLinks := true;
  FAllowMove := true;
  FShowPortNames := true;
  FBackColor := clDefault;
  FGridColor := clDefault;
  FNodeColor := clDefault;
  FBorderColor := clDefault;
  FTextColor := clDefault;
  FLinkColor := clDefault;
  FPortColor := clDefault;
  FSelectColor := clDefault;
  FAntialiasing := asTheme;
  FHotPort := -1;
  TabStop := true;
  with GetControlClassDefaultSize do SetInitialBounds(0, 0, cx, cy);
end;

destructor TNodeEditor.Destroy;
begin
  FLinks.Free;
  FNodes.Free;
  inherited Destroy;
end;

class function TNodeEditor.GetControlClassDefaultSize: TSize;
begin
  result.cx := 480;
  result.cy := 300;
end;

// -- data ----------------------

function TNodeEditor.AddNode(const caption: string; left, top: integer; const inputs: array of string; const outputs: array of string): TGraphNode;
begin
  result := FNodes.Add;
  result.Caption := caption;
  result.Left := left;
  result.Top := top;
  result.Inputs.BeginUpdate;
  result.Outputs.BeginUpdate;
  try
    for var s in inputs do result.Inputs.Add(s);
    for var s in outputs do result.Outputs.Add(s);
  finally
    result.Inputs.EndUpdate;
    result.Outputs.EndUpdate;
  end;
end;

function TNodeEditor.AddLink(fromNode, fromPort, toNode, toPort: integer): TGraphLink;
begin
  result := FLinks.Add;
  result.FromNode := fromNode;
  result.FromPort := fromPort;
  result.ToNode := toNode;
  result.ToPort := toPort;
end;

procedure TNodeEditor.LinksOf(node: TGraphNode; list: TList);
begin
  for var i := 0 to FLinks.Count-1 do
    if (FLinks[i].FromNode = node.Index) or (FLinks[i].ToNode = node.Index) then list.Add(FLinks[i]);
end;

procedure TNodeEditor.DeleteLink(link: TGraphLink);
begin
  if link = nil then exit;
  if FSelectedLink = link then FSelectedLink := nil;
  if Assigned(FOnLinkDeleted) then FOnLinkDeleted(self, link);
  link.Free;
  changed;
end;

procedure TNodeEditor.DeleteNode(node: TGraphNode);
begin
  if node = nil then exit;
  var index := node.Index;
  // its links go, the ones past it move down an index
  for var i := FLinks.Count-1 downto 0 do begin
    var l := FLinks[i];
    if (l.FromNode = index) or (l.ToNode = index) then begin
      if FSelectedLink = l then FSelectedLink := nil;
      l.Free;
    end else begin
      if l.FromNode > index then l.FFromNode -= 1;
      if l.ToNode > index then l.FToNode -= 1;
    end;
  end;
  if FSelectedNode = node then FSelectedNode := nil;
  if FHotNode = node then FHotNode := nil;
  node.Free;
  changed;
end;

procedure TNodeEditor.DeleteSelected;
begin
  if FReadOnly then exit;
  if FSelectedLink <> nil then DeleteLink(FSelectedLink)
  else if FSelectedNode <> nil then DeleteNode(FSelectedNode);
end;

procedure TNodeEditor.changed;
begin
  Invalidate;
  if Assigned(FOnChange) then FOnChange(self);
end;

// -- geometry ----------------------

function TNodeEditor.toScreen(x, y: integer): TPoint;
begin
  result.X := Round((x-FPan.X)*FZoom);
  result.Y := Round((y-FPan.Y)*FZoom);
end;

function TNodeEditor.toGraph(x, y: integer): TPoint;
begin
  result.X := Round(x/FZoom)+FPan.X;
  result.Y := Round(y/FZoom)+FPan.Y;
end;

function TNodeEditor.nodeHeight(node: TGraphNode): integer;
begin
  var rows := Max(node.Inputs.Count, node.Outputs.Count);
  var lh := lineHeightOf(Font)+4;
  result := FHeaderHeight+FPadding+rows*lh+FPadding;
  if node.Text <> '' then result += lh;
end;

function TNodeEditor.nodeRect(node: TGraphNode): TRect;
begin
  result := Rect(node.Left, node.Top, node.Left+node.Width, node.Top+nodeHeight(node));
end;

function TNodeEditor.portPoint(node: TGraphNode; index: integer; input: boolean): TPoint;
begin
  var lh := lineHeightOf(Font)+4;
  var top := node.Top+FHeaderHeight+FPadding+(if node.Text <> '' then lh else 0);
  result.Y := top+index*lh+lh div 2;
  result.X := if input then node.Left else node.Left+node.Width;
end;

// the drawing order: by the time each node last came to the front, the
// collection order for the ones that never did
procedure TNodeEditor.sortOrder;
begin
  SetLength(FDrawOrder, FNodes.Count);
  for var i := 0 to FNodes.Count-1 do FDrawOrder[i] := FNodes[i];
  for var i := 1 to high(FDrawOrder) do begin
    var k := i;
    while (k > 0) and (FDrawOrder[k-1].FZ > FDrawOrder[k].FZ) do begin
      var t := FDrawOrder[k-1];
      FDrawOrder[k-1] := FDrawOrder[k];
      FDrawOrder[k] := t;
      dec(k);
    end;
  end;
end;

function TNodeEditor.screenRect(node: TGraphNode): TRect;
begin
  var r := nodeRect(node);
  result := Rect(toScreen(r.Left, r.Top).X, toScreen(r.Left, r.Top).Y, toScreen(r.Right, r.Bottom).X, toScreen(r.Right, r.Bottom).Y);
end;

// the parts of `r` outside `cut`: up to four rectangles
procedure subtractRect(var pieces: array of TRect; var count: integer; const r, cut: TRect);
begin
  var hit: TRect;
  if not IntersectRect(hit, r, cut) then begin
    pieces[count] := r;
    inc(count);
    exit;
  end;
  if hit.Top > r.Top then begin pieces[count] := Rect(r.Left, r.Top, r.Right, hit.Top); inc(count); end;
  if hit.Bottom < r.Bottom then begin pieces[count] := Rect(r.Left, hit.Bottom, r.Right, r.Bottom); inc(count); end;
  if hit.Left > r.Left then begin pieces[count] := Rect(r.Left, hit.Top, hit.Left, hit.Bottom); inc(count); end;
  if hit.Right < r.Right then begin pieces[count] := Rect(hit.Right, hit.Top, r.Right, hit.Bottom); inc(count); end;
end;

procedure TNodeEditor.bringToFront(node: TGraphNode);
begin
  inc(FZCounter);
  node.FZ := FZCounter;
end;

function TNodeEditor.nodeAt(x, y: integer): TGraphNode;
begin
  var g := toGraph(x, y);
  sortOrder;
  for var i := high(FDrawOrder) downto 0 do if PtInRect(nodeRect(FDrawOrder[i]), g) then exit(FDrawOrder[i]);
  result := nil;
end;

function TNodeEditor.portAt(x, y: integer; out node: TGraphNode; out index: integer; out input: boolean): boolean;
begin
  result := false;
  node := nil;
  index := -1;
  input := false;
  var g := toGraph(x, y);
  var reach := Round((FPortRadius+4)/FZoom)+2;
  for var n := FNodes.Count-1 downto 0 do begin
    var nd := FNodes[n];
    for var i := 0 to nd.Inputs.Count-1 do begin
      var p := portPoint(nd, i, true);
      if (Abs(p.X-g.X) <= reach) and (Abs(p.Y-g.Y) <= reach) then begin node := nd; index := i; input := true; exit(true); end;
    end;
    for var i := 0 to nd.Outputs.Count-1 do begin
      var p := portPoint(nd, i, false);
      if (Abs(p.X-g.X) <= reach) and (Abs(p.Y-g.Y) <= reach) then begin node := nd; index := i; input := false; exit(true); end;
    end;
  end;
end;

// the curve of a link: a cubic from an output to an input, sampled into points
procedure TNodeEditor.linkCurve(const a, b: TPoint; out pts: array of TPointF; out count: integer);
begin
  count := length(pts);
  var dx := Max(Abs(b.X-a.X)/2, 40*FZoom);
  var c1 := PointF(a.X+dx, a.Y);
  var c2 := PointF(b.X-dx, b.Y);
  for var i := 0 to count-1 do begin
    var t := i/(count-1);
    var u := 1-t;
    pts[i].x := u*u*u*a.X+3*u*u*t*c1.x+3*u*t*t*c2.x+t*t*t*b.X;
    pts[i].y := u*u*u*a.Y+3*u*u*t*c1.y+3*u*t*t*c2.y+t*t*t*b.Y;
  end;
end;

function TNodeEditor.linkAt(x, y: integer): TGraphLink;
begin
  result := nil;
  var best := 36.0;
  for var i := 0 to FLinks.Count-1 do begin
    var l := FLinks[i];
    if (l.FromNode < 0) or (l.FromNode >= FNodes.Count) or (l.ToNode < 0) or (l.ToNode >= FNodes.Count) then continue;
    var pa := portPoint(FNodes[l.FromNode], l.FromPort, false);
    var pb := portPoint(FNodes[l.ToNode], l.ToPort, true);
    var a := toScreen(pa.X, pa.Y);
    var b := toScreen(pb.X, pb.Y);
    var pts: array[0..31] of TPointF;
    var n: integer;
    linkCurve(a, b, pts, n);
    for var k := 0 to n-1 do begin
      var d := Sqr(pts[k].x-x)+Sqr(pts[k].y-y);
      if d < best then begin best := d; result := l; end;
    end;
  end;
end;

function TNodeEditor.headerOf(node: TGraphNode): TColor;
begin
  result := node.Color;
  if result = clDefault then result := PALETTE[node.Index mod length(PALETTE)];
  result := ColorToRGB(result);
end;

procedure TNodeEditor.FitToView;
begin
  if FNodes.Count = 0 then exit;
  var bounds := nodeRect(FNodes[0]);
  for var i := 1 to FNodes.Count-1 do UnionRect(bounds, bounds, nodeRect(FNodes[i]));
  bounds.Inflate(40, 40);
  FZoom := EnsureRange(Min(ClientWidth/Max(bounds.Width, 1), ClientHeight/Max(bounds.Height, 1)), 0.2, 2);
  FPan := Point(bounds.Left-Round((ClientWidth/FZoom-bounds.Width)/2), bounds.Top-Round((ClientHeight/FZoom-bounds.Height)/2));
  Invalidate;
end;

procedure TNodeEditor.CenterOn(node: TGraphNode);
begin
  if node = nil then exit;
  var r := nodeRect(node);
  FPan := Point((r.Left+r.Right) div 2-Round(ClientWidth/FZoom/2), (r.Top+r.Bottom) div 2-Round(ClientHeight/FZoom/2));
  Invalidate;
end;

// -- painting ----------------------

procedure TNodeEditor.Paint;
begin
  var back := pick(FBackColor, blend(clBtnFace, clBlack, 12));
  var grid := pick(FGridColor, blend(back, clWindowText, 8));
  var nodeBack := pick(FNodeColor, blend(clBtnFace, clWindow, 20));
  var border := pick(FBorderColor, blend(nodeBack, clWindowText, 30));
  var text := pick(FTextColor, clWindowText);
  var linkColor := pick(FLinkColor, blend(clWindowText, back, 35));
  var portColor := pick(FPortColor, clHighlight);
  var selectColor := pick(FSelectColor, clHighlight);
  var sp := autofree beginShapes(Canvas, ClientRect, back, FAntialiasing);
  if FShowGrid and (FGridSize > 1) then begin
    var step := FGridSize*FZoom;
    if step >= 6 then begin
      var x := -Frac(FPan.X/FGridSize)*step;
      if x < 0 then x += step;
      while x < ClientWidth do begin sp.FillRect(Rect(Round(x), 0, Round(x)+1, ClientHeight), grid); x += step; end;
      var y := -Frac(FPan.Y/FGridSize)*step;
      if y < 0 then y += step;
      while y < ClientHeight do begin sp.FillRect(Rect(0, Round(y), ClientWidth, Round(y)+1), grid); y += step; end;
    end;
  end;
  // the links under the nodes
  var pr := Max(Round(FPortRadius*FZoom), 2);
  for var i := 0 to FLinks.Count-1 do begin
    var l := FLinks[i];
    if (l.FromNode < 0) or (l.FromNode >= FNodes.Count) or (l.ToNode < 0) or (l.ToNode >= FNodes.Count) then continue;
    var pa := portPoint(FNodes[l.FromNode], l.FromPort, false);
    var pb := portPoint(FNodes[l.ToNode], l.ToPort, true);
    var a := toScreen(pa.X, pa.Y);
    var b := toScreen(pb.X, pb.Y);
    var pts: array[0..31] of TPointF;
    var n: integer;
    linkCurve(a, b, pts, n);
    var c := if l.Color = clDefault then linkColor else ColorToRGB(l.Color);
    if l = FSelectedLink then c := selectColor;
    sp.StrokePolyline(pts, Max(2*FZoom, 1.5)+(if l = FSelectedLink then 1 else 0), c);
  end;
  // the link being made follows the mouse
  if FLinking and (FLinkFrom <> nil) then begin
    var pa := portPoint(FLinkFrom, FLinkPort, false);
    var a := toScreen(pa.X, pa.Y);
    var pts: array[0..31] of TPointF;
    var n: integer;
    linkCurve(a, FMouse, pts, n);
    sp.StrokePolyline(pts, Max(2*FZoom, 1.5), selectColor);
  end;
  // the nodes, from the back to the front
  var radius := Round(FCornerRadius*FZoom);
  sortOrder;
  for var i := 0 to high(FDrawOrder) do begin
    var node := FDrawOrder[i];
    var r := nodeRect(node);
    var s := Rect(toScreen(r.Left, r.Top).X, toScreen(r.Left, r.Top).Y, toScreen(r.Right, r.Bottom).X, toScreen(r.Right, r.Bottom).Y);
    if (s.Right < 0) or (s.Bottom < 0) or (s.Left > ClientWidth) or (s.Top > ClientHeight) then continue;
    var edge := if node = FSelectedNode then selectColor else if (node = FHotNode) and hoverEnabled then hoverShade(border, selectColor) else border;
    sp.FillRoundRect(s.Left+2, s.Top+3, s.Right+2, s.Bottom+3, radius, blend(back, clBlack, 25));
    paintRoundRect(sp, s, radius, nodeBack, edge, (if node = FSelectedNode then 2 else 1));
    var hh := Round(FHeaderHeight*FZoom);
    sp.FillRoundRect(s.Left, s.Top, s.Right, s.Top+hh+radius, radius, headerOf(node));
    sp.FillRect(Rect(s.Left, s.Top+hh, s.Right, s.Top+hh+radius), nodeBack);
    paintRoundRect(sp, s, radius, clNone, edge, (if node = FSelectedNode then 2 else 1));
    for var k := 0 to node.Inputs.Count-1 do begin
      var p := portPoint(node, k, true);
      var ps := toScreen(p.X, p.Y);
      var hot := (node = FHotNode) and (FHotPort = k) and (FHotPortIsInput = 1);
      paintCircle(sp, ps.X, ps.Y, pr+(if hot then 1 else 0), (if hot then selectColor else portColor), nodeBack, 1);
    end;
    for var k := 0 to node.Outputs.Count-1 do begin
      var p := portPoint(node, k, false);
      var ps := toScreen(p.X, p.Y);
      var hot := (node = FHotNode) and (FHotPort = k) and (FHotPortIsInput = 0);
      paintCircle(sp, ps.X, ps.Y, pr+(if hot then 1 else 0), (if hot then selectColor else portColor), nodeBack, 1);
    end;
  end;
  sp.Flush;

  applyTextQuality(Canvas);
  Canvas.Brush.Style := bsClear;
  Canvas.Font := Font;
  if FZoom <> 1 then Canvas.Font.Size := Max(Round(Max(Font.Size, 9)*FZoom), 5);
  var lh := Canvas.TextHeight('Hg');
  for var i := 0 to high(FDrawOrder) do begin
    var node := FDrawOrder[i];
    var s := screenRect(node);
    if (s.Right < 0) or (s.Bottom < 0) or (s.Left > ClientWidth) or (s.Top > ClientHeight) then continue;
    // the text shows only where no node above covers it: the rectangle cut
    // by every higher node, the text drawn once per piece that is left
    var pieces: array of TRect := [s];
    for var j := i+1 to high(FDrawOrder) do begin
      var cut := screenRect(FDrawOrder[j]);
      var next: array of TRect;
      SetLength(next, length(pieces)*4+1);
      var count := 0;
      for var p in pieces do subtractRect(next, count, p, cut);
      SetLength(next, count);
      pieces := next;
      if count = 0 then break;
    end;
    for var piece in pieces do begin
      Canvas.ClipRect := piece;
      Canvas.Clipping := true;
      paintNodeText(node, s, pr, text, nodeBack, lh);
      Canvas.Clipping := false;
    end;
  end;
  // the captions of the links at their middle
  for var i := 0 to FLinks.Count-1 do begin
    var l := FLinks[i];
    if (l.Caption = '') or (l.FromNode < 0) or (l.FromNode >= FNodes.Count) or (l.ToNode < 0) or (l.ToNode >= FNodes.Count) then continue;
    var pa := portPoint(FNodes[l.FromNode], l.FromPort, false);
    var pb := portPoint(FNodes[l.ToNode], l.ToPort, true);
    var a := toScreen(pa.X, pa.Y);
    var b := toScreen(pb.X, pb.Y);
    Canvas.Font.Color := blend(text, back, 25);
    Canvas.TextOut((a.X+b.X-Canvas.TextWidth(l.Caption)) div 2, (a.Y+b.Y) div 2-lh-2, l.Caption);
  end;
  Canvas.Font := Font;
  Canvas.Brush.Style := bsSolid;
end;

procedure TNodeEditor.paintNodeText(node: TGraphNode; const s: TRect; pr: integer; text, nodeBack: TColor; lh: integer);
begin
  var hh := Round(FHeaderHeight*FZoom);
  var padS := Round(FPadding*FZoom);
  Canvas.Font.Style := Font.Style+[fsBold];
  Canvas.Font.Color := contrastText(headerOf(node));
  var saved := Canvas.ClipRect;
  var head: TRect;
  if IntersectRect(head, saved, Rect(s.Left, s.Top, s.Right, s.Top+hh)) then begin
    Canvas.ClipRect := head;
    Canvas.TextOut(s.Left+padS, s.Top+(hh-lh) div 2, node.Caption);
    Canvas.ClipRect := saved;
  end;
  Canvas.Font.Style := Font.Style;
  Canvas.Font.Color := text;
  var y := s.Top+hh+padS;
  var rowH := Round((lineHeightOf(Font)+4)*FZoom);
  if node.Text <> '' then begin
    Canvas.Font.Color := blend(text, nodeBack, 35);
    Canvas.TextOut(s.Left+padS, y, node.Text);
    Canvas.Font.Color := text;
    y += rowH;
  end;
  if FShowPortNames and (FZoom >= 0.6) then begin
    for var k := 0 to node.Inputs.Count-1 do Canvas.TextOut(s.Left+padS+pr, y+k*rowH+(rowH-lh) div 2, node.Inputs[k]);
    for var k := 0 to node.Outputs.Count-1 do begin
      var w := Canvas.TextWidth(node.Outputs[k]);
      Canvas.TextOut(s.Right-padS-pr-w, y+k*rowH+(rowH-lh) div 2, node.Outputs[k]);
    end;
  end;
end;

// -- input ----------------------

procedure TNodeEditor.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if TabStop and CanSetFocus then SetFocus;
  FMouse := Point(X, Y);
  if Button = mbMiddle then begin
    FPanning := true;
    FPanStart := Point(X, Y);
    FPanOrigin := FPan;
    exit;
  end;
  if Button <> mbLeft then exit;
  var node: TGraphNode;
  var port: integer;
  var input: boolean;
  if FAllowLinks and not FReadOnly and portAt(X, Y, node, port, input) and not input then begin
    FLinking := true;
    FLinkFrom := node;
    FLinkPort := port;
    Invalidate;
    exit;
  end;
  node := nodeAt(X, Y);
  if node <> nil then begin
    if FSelectedNode <> node then begin
      FSelectedNode := node;
      FSelectedLink := nil;
      if Assigned(FOnSelectNode) then FOnSelectNode(self, node);
    end;
    // the node comes to the front; the indices of the links stay as they are
    bringToFront(node);
    FSelectedNode := node;
    if Assigned(FOnNodeClick) then FOnNodeClick(self, node);
    if FAllowMove and not FReadOnly then begin
      var g := toGraph(X, Y);
      FDragNode := node;
      FDragOffset := Point(g.X-node.Left, g.Y-node.Top);
    end;
    Invalidate;
    exit;
  end;
  var link := linkAt(X, Y);
  if link <> nil then begin
    FSelectedLink := link;
    FSelectedNode := nil;
    if Assigned(FOnSelectLink) then FOnSelectLink(self, link);
    Invalidate;
    exit;
  end;
  // the background: the selection goes, a drag pans
  if (FSelectedNode <> nil) or (FSelectedLink <> nil) then begin
    FSelectedNode := nil;
    FSelectedLink := nil;
    if Assigned(FOnSelectNode) then FOnSelectNode(self, nil);
  end;
  FPanning := true;
  FPanStart := Point(X, Y);
  FPanOrigin := FPan;
  Invalidate;
end;

procedure TNodeEditor.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  FMouse := Point(X, Y);
  if FPanning then begin
    FPan := Point(FPanOrigin.X-Round((X-FPanStart.X)/FZoom), FPanOrigin.Y-Round((Y-FPanStart.Y)/FZoom));
    Invalidate;
    exit;
  end;
  if FDragNode <> nil then begin
    var g := toGraph(X, Y);
    var nx := g.X-FDragOffset.X;
    var ny := g.Y-FDragOffset.Y;
    if FSnapToGrid and (FGridSize > 1) then begin
      nx := Round(nx/FGridSize)*FGridSize;
      ny := Round(ny/FGridSize)*FGridSize;
    end;
    if (nx <> FDragNode.Left) or (ny <> FDragNode.Top) then begin
      FDragNode.FLeft := nx;
      FDragNode.FTop := ny;
      Invalidate;
    end;
    exit;
  end;
  if FLinking then begin
    var node: TGraphNode;
    var port: integer;
    var input: boolean;
    if portAt(X, Y, node, port, input) and input then begin
      FHotNode := node;
      FHotPort := port;
      FHotPortIsInput := 1;
    end else begin
      FHotNode := nil;
      FHotPort := -1;
    end;
    Invalidate;
    exit;
  end;
  var node: TGraphNode;
  var port: integer;
  var input: boolean;
  var hot: TGraphNode := nil;
  var hotPort := -1;
  var hotInput := 0;
  if portAt(X, Y, node, port, input) then begin
    hot := node;
    hotPort := port;
    hotInput := if input then 1 else 0;
  end else hot := nodeAt(X, Y);
  if (hot <> FHotNode) or (hotPort <> FHotPort) or (hotInput <> FHotPortIsInput) then begin
    FHotNode := hot;
    FHotPort := hotPort;
    FHotPortIsInput := hotInput;
    Cursor := if hotPort >= 0 then crCross else if hot <> nil then crSizeAll else crDefault;
    Invalidate;
  end;
end;

procedure TNodeEditor.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FPanning then begin
    FPanning := false;
    exit;
  end;
  if FDragNode <> nil then begin
    var moved := FDragNode;
    FDragNode := nil;
    if Assigned(FOnNodeMoved) then FOnNodeMoved(self, moved);
    changed;
    exit;
  end;
  if FLinking then begin
    FLinking := false;
    var node: TGraphNode;
    var port: integer;
    var input: boolean;
    if portAt(X, Y, node, port, input) and input and (node <> FLinkFrom) then begin
      var allow := true;
      if Assigned(FOnLinkAllow) then FOnLinkAllow(self, FLinkFrom, FLinkPort, node, port, allow);
      // an input takes one link: the old one goes
      if allow then begin
        for var i := FLinks.Count-1 downto 0 do
          if (FLinks[i].ToNode = node.Index) and (FLinks[i].ToPort = port) then FLinks[i].Free;
        var link := AddLink(FLinkFrom.Index, FLinkPort, node.Index, port);
        if Assigned(FOnLinkCreated) then FOnLinkCreated(self, link);
        changed;
      end;
    end;
    FLinkFrom := nil;
    FHotPort := -1;
    Invalidate;
  end;
end;

procedure TNodeEditor.MouseLeave;
begin
  inherited MouseLeave;
  if (FHotNode = nil) and (FHotPort < 0) then exit;
  FHotNode := nil;
  FHotPort := -1;
  Invalidate;
end;

procedure TNodeEditor.DblClick;
begin
  inherited DblClick;
  var p := ScreenToClient(Mouse.CursorPos);
  var node := nodeAt(p.X, p.Y);
  if (node <> nil) and Assigned(FOnNodeDblClick) then FOnNodeDblClick(self, node);
end;

function TNodeEditor.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if result then exit;
  var p := MousePos; // client coordinates
  var before := toGraph(p.X, p.Y);
  var factor := if WheelDelta > 0 then 1.1 else 1/1.1;
  FZoom := EnsureRange(FZoom*factor, 0.2, 3);
  // the point under the mouse stays put
  var after := toGraph(p.X, p.Y);
  FPan := Point(FPan.X+(before.X-after.X), FPan.Y+(before.Y-after.Y));
  Invalidate;
  result := true;
end;

procedure TNodeEditor.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  var step := if ssShift in Shift then FGridSize else 1;
  match Key of
    VK_DELETE: DeleteSelected;
    VK_LEFT: if (FSelectedNode <> nil) and not FReadOnly then begin FSelectedNode.Left := FSelectedNode.Left-step; changed; end;
    VK_RIGHT: if (FSelectedNode <> nil) and not FReadOnly then begin FSelectedNode.Left := FSelectedNode.Left+step; changed; end;
    VK_UP: if (FSelectedNode <> nil) and not FReadOnly then begin FSelectedNode.Top := FSelectedNode.Top-step; changed; end;
    VK_DOWN: if (FSelectedNode <> nil) and not FReadOnly then begin FSelectedNode.Top := FSelectedNode.Top+step; changed; end;
    VK_HOME: FitToView;
    VK_ESCAPE: begin FSelectedNode := nil; FSelectedLink := nil; Invalidate; end;
  else
    exit;
  end;
  Key := 0;
end;

procedure TNodeEditor.DoEnter;
begin
  inherited DoEnter;
  Invalidate;
end;

procedure TNodeEditor.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

// -- properties ----------------------

procedure TNodeEditor.setNodes(value: TGraphNodes);
begin
  FNodes.Assign(value);
  Invalidate;
end;

procedure TNodeEditor.setLinks(value: TGraphLinks);
begin
  FLinks.Assign(value);
  Invalidate;
end;

procedure TNodeEditor.setZoom(value: double);
begin
  value := EnsureRange(value, 0.2, 3);
  if FZoom = value then exit;
  FZoom := value;
  Invalidate;
end;

function TNodeEditor.getMetric(index: integer): integer;
begin
  result := match index of
    0: FGridSize;
    1: FPortRadius;
    2: FHeaderHeight;
    3: FCornerRadius;
  else
    FPadding
  end;
end;

procedure TNodeEditor.setMetric(index: integer; value: integer);
begin
  if value < 0 then value := 0;
  if index in [0, 1, 2] then value := Max(value, 2);
  if getMetric(index) = value then exit;
  match index of
    0: FGridSize := value;
    1: FPortRadius := value;
    2: FHeaderHeight := value;
    3: FCornerRadius := value;
  else
    FPadding := value;
  end;
  Invalidate;
end;

function TNodeEditor.getFlag(index: integer): boolean;
begin
  result := match index of
    0: FShowGrid;
    1: FSnapToGrid;
    2: FAllowLinks;
    3: FAllowMove;
    4: FReadOnly;
  else
    FShowPortNames
  end;
end;

procedure TNodeEditor.setFlag(index: integer; value: boolean);
begin
  if getFlag(index) = value then exit;
  match index of
    0: FShowGrid := value;
    1: FSnapToGrid := value;
    2: FAllowLinks := value;
    3: FAllowMove := value;
    4: FReadOnly := value;
  else
    FShowPortNames := value;
  end;
  Invalidate;
end;

function TNodeEditor.getPartColor(index: integer): TColor;
begin
  result := match index of
    0: FBackColor;
    1: FGridColor;
    2: FNodeColor;
    3: FBorderColor;
    4: FTextColor;
    5: FLinkColor;
    6: FPortColor;
  else
    FSelectColor
  end;
end;

procedure TNodeEditor.setPartColor(index: integer; value: TColor);
begin
  if getPartColor(index) = value then exit;
  match index of
    0: FBackColor := value;
    1: FGridColor := value;
    2: FNodeColor := value;
    3: FBorderColor := value;
    4: FTextColor := value;
    5: FLinkColor := value;
    6: FPortColor := value;
  else
    FSelectColor := value;
  end;
  Invalidate;
end;

procedure TNodeEditor.setAntialiasing(value: TAntialiasSetting);
begin
  if FAntialiasing = value then exit;
  FAntialiasing := value;
  Invalidate;
end;

end.
