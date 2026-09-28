unit EditorToolBarOptions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LazUtils
  Laz2_XMLCfg, LazConfigStorage, LazLoggerBase,
  // BuildIntf
  BaseIDEIntf,
  // IdeConfig
  ToolBarOptionsBase;

type

  { TEditorToolBarOptions }

  TEditorToolBarOptions = class(TIDEToolBarOptionsBase)
  private
    FVisible: Boolean;
    FPosition: string;
  public
    const
      cDefaultVisible = true;
      cDefaultPosition = 'Top';
  public
    constructor Create;
    //destructor Destroy; override;
    procedure Clear;
    function Equals(Opts: TEditorToolBarOptions): boolean; overload;
    procedure Assign(Source: TEditorToolBarOptions);
    procedure CreateDefaults;
    procedure Load(XMLConfig: TXMLConfig; Path: String);
    procedure Save(XMLConfig: TXMLConfig; Path: String);
  published
    property Visible: Boolean read FVisible write FVisible;
    property Position: string read FPosition write FPosition;
  end;


implementation

const
  BasePath = 'EditorToolBarOptions/';
  cSettingsFile = 'editortoolbar.xml';


{ TEditorToolBarOptions }

constructor TEditorToolBarOptions.Create;
begin
  inherited Create;
  FVisible := cDefaultVisible;
  FPosition := cDefaultPosition;
  CreateDefaults;
end;

procedure TEditorToolBarOptions.Clear;
begin
  inherited Clear;
  FVisible := cDefaultVisible;
  FPosition := cDefaultPosition;
end;

function TEditorToolBarOptions.Equals(Opts: TEditorToolBarOptions): boolean;
begin
  Result := inherited Equals(Opts)
      and (FVisible = Opts.FVisible) and (FPosition = Opts.FPosition);
end;

procedure TEditorToolBarOptions.Assign(Source: TEditorToolBarOptions);
begin
  inherited Assign(Source);
  FVisible := Source.FVisible;
  FPosition := Source.FPosition;
end;

procedure TEditorToolBarOptions.CreateDefaults;
begin
  ButtonNames.Clear;
  ButtonNames.Add('View Units');
  ButtonNames.Add('View Forms');
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add('NewUnit');
  ButtonNames.Add('NewForm');
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add('Jump back');
  ButtonNames.Add('Jump forward');
  ButtonNames.Add('Jump to Implementation');
  ButtonNames.Add('Find procedure definiton');
  ButtonNames.Add('Find identifier references');
  ButtonNames.Add('Uppercase selection');
  ButtonNames.Add('Lowercase selection');
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add('Compile project/program');
  ButtonNames.Add('Clean up and build');
  ButtonNames.Add('Run without debugging');
  ButtonNames.Add('Run program');
  ButtonNames.Add('Pause program');
  ButtonNames.Add('Stop program');
  ButtonNames.Add('Step over');
  ButtonNames.Add('Step into');
  ButtonNames.Add('Step out');
  ButtonNames.Add('Run to cursor line');
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add('Set free Bookmark');
  ButtonNames.Add('Go to marker 0');
  ButtonNames.Add('Go to marker 1');
  ButtonNames.Add('Go to marker 2');
  ButtonNames.Add('Go to marker 3');
  ButtonNames.Add('Go to marker 4');
  ButtonNames.Add('Clear all Bookmarks');
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add(cIDEToolbarDivider);
  ButtonNames.Add('Procedure List ...');
  ButtonNames.Add('Leaks and Traces');
end;

procedure TEditorToolBarOptions.Load(XMLConfig: TXMLConfig; Path: String);
var
  ButtonCount: Integer;
  ButtonName: string;
  I: Integer;
  cfg: TConfigStorage;
begin
  Path := Path + BasePath;
  if XMLConfig.HasPath(Path + 'Count', True) then
  begin
    FVisible := XMLConfig.GetValue(Path + 'Visible', cDefaultVisible);
    FPosition := XMLConfig.GetValue(Path + 'Position', cDefaultPosition);
    LoadButtonNames(XMLConfig, Path);
    // Save drops the Count of an empty list, so a zero written by another
    // tool means the same as no list at all
    if ButtonNames.Count = 0 then
      CreateDefaults;
  end
  else begin
    // Plan B: Load the old configuration. User settings are not lost.
    cfg := GetIDEConfigStorage(cSettingsFile, True);
    try
      FVisible := cfg.GetValue('Visible',True);
      FPosition := cfg.GetValue('Position','Top');
      ButtonCount := cfg.GetValue('Count', 0);
      if ButtonCount > 0 then
      begin
        DebugLn('TEditorToolBarOptions.Load: Using old configuration in editortoolbar.xml.');
        // This used to be hard-coded in old version, add it now.
        ButtonNames.Add('IDEMainMenu/Search/itmJumpings/itmJumpToSection/itmJumpToImplementation');
        for I := 1 to ButtonCount do
        begin
          ButtonName := Trim(cfg.GetValue('Button' + Format('%2.2d', [I]) + '/Value', ''));
          if ButtonName <> '' then
            ButtonNames.Add(ButtonName);
        end;
      end
      else   // No old configuration, use defaults.
        CreateDefaults;
    finally
      cfg.Free;
    end;
  end;
end;

procedure TEditorToolBarOptions.Save(XMLConfig: TXMLConfig; Path: String);
begin
  Path := Path + BasePath;
  XMLConfig.SetDeleteValue(Path + 'Visible', FVisible, cDefaultVisible);
  XMLConfig.SetDeleteValue(Path + 'Position', FPosition, cDefaultPosition);
  SaveButtonNames(XMLConfig, Path);
end;

end.

