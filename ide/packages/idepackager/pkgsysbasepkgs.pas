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
    libpDockedFormEditor,
    libpUnleashedFormplacer,
    libpUnleashedThemes,
    libpUnleashedMinimap,
    libpUnleashedPanes
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
    'DockedFormEditor',
    'UnleashedFormplacer',
    'UnleashedThemes',
    'UnleashedMinimap',
    'UnleashedPanes'
    );

  // extra packages for the release, alias "bigide": the set the installer ships
  LazarusIDEReleasePkgNames: array[0..18] of string = (
    'SynEditDsgn',
    'DateTimeCtrls',
    'DateTimeCtrlsDsgn',
    'SDFLaz',
    'Cody',
    'ProjTemplates',
    'SQLDBLaz',
    'MemDSLaz',
    'DBFLaz',
    'FPCUnitIDE',
    'LazTestInsight',
    'lazdaemon',
    'LeakView',
    'TAChartLazarusPkg',
    'JCFIDELazarus',
    'lhelpcontrolpkg',
    'ChmHelpPkg',
    'InstantFPCLaz',
    'ExternHelp'
    );

implementation

end.

