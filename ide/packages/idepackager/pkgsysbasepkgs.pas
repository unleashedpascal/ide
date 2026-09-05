unit PkgSysBasePkgs;

{$mode ObjFPC}{$H+}

interface

type
  // the base packages needed by the minimal IDE
  TLazarusIDEBasePkg = (
    libpFCL,
    libpLazUtils,
    libpFreeTypeLaz,
    libpBuildIntf,
    libpCodeTools,
    libpLazEdit,
    libpLCLBase,
    libpLCL,
    libpIDEIntf,
    libpSynEdit,
    libpLazDebuggerIntf,
    libpDebuggerIntf,
    libpCmdLineDebuggerBase,
    libpfpdebug,
    libpLazDebuggerGdbmi,
    libpLazDebuggerFp,
    libpLazDebuggerLldb,
    libpLazDebuggerFpLldb,
    libpLazControls,
    libpLazControlDsgn,
    libpLCLExtensions_package,
    libpLazVirtualtreeview_package,
    libpIdeUtilsPkg,
    libpIdeConfig,
    libpIdePackager,
    libpIdeProject,
    libpIdeDebugger,
    libpUnleashedFormplacer
    );
const
  LazarusIDEBasePkgNames: array[TLazarusIDEBasePkg] of string = (
    'FCL',
    'LazUtils',
    'FreeTypeLaz',
    'BuildIntf',
    'CodeTools',
    'LazEdit',
    'LCLBase',
    'LCL',
    'IDEIntf',
    'SynEdit',
    'LazDebuggerIntf',
    'DebuggerIntf',
    'CmdLineDebuggerBase',
    'fpdebug',
    'LazDebuggerGdbmi',
    'LazDebuggerFp',
    'LazDebuggerLldb',
    'LazDebuggerFpLldb',
    'LazControls',
    'LazControlDsgn',
    'LCLExtensions_Package',
    'laz.virtualtreeview_package',
    'IdeUtilsPkg',
    'IdeConfig',
    'IdePackager',
    'IdeProject',
    'IdeDebugger',
    'UnleashedFormplacer'
    );

  // extra packages for the release, alias "bigide"
  LazarusIDEReleasePkgNames: array[0..32] of string = (
	  'SyneditDsgn',
    'DockedFormEditor',
    'OnlinePackageManager',
    'cairocanvas_pkg',
    'RunTimeTypeInfoControls',
    'Printer4Lazarus',
    'Printers4LazIDE',
    'LeakView',
    'MemDSLaz',
    'SDFLaz',
    'InstantFPCLaz',
    'ExternHelp',
    'TurboPowerIPro',
    'TurboPowerIProDsgn',
    'JCFIDELazarus',
    'ChmHelpPkg',
    'FPCUnitTestRunner',
    'FPCUnitIDE',
    'LazTestInsight',
    'ProjTemplates',
    'TAChartLazarusPkg',
    'TodoListLaz',
    'DateTimeCtrls',
    'SQLDBLaz',
    'DBFLaz',
    'PascalScript',
    'EditorMacroScript',
    'ExampleProjects',
    'SimpleWebServerGUI',
    'LazProjectGroups',
    'Pas2jsDsgn',
    'Charactermap_ide_pkg',
    'AnchorDockingDsgn'
    );

implementation

end.

