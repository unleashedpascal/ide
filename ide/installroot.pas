{ Part of the Unleashed Pascal IDE
  Copyright (c) 2026 Unleashed Pascal Contributors <https://unleashedpascal.org>
  License: MPL-2.0

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file, You can
  obtain one at https://mozilla.org/MPL/2.0/.

  These notices must be kept in copies and modified versions (MPL-2.0 sec. 3.1);
  add yours below. }

unit InstallRoot;

{$mode unleashed}

interface

uses
  Classes, SysUtils, StrUtils, LazFileUtils, FileUtil, LazConf, IDECmdLine,
  LazarusIDEStrConsts;

type
  TRelocateLogKind = (rlkFile, rlkDetail, rlkError);
  TRelocateLogProc = procedure(const msg: string; kind: TRelocateLogKind) of object;

// the directory holding config_lazarus, lazarus and fpc side by side
function CurrentInstallRoot: string;
// true when the install was moved since its root was last recorded;
// a missing record is written now and counts as unchanged
function InstallRootChanged(out oldRoot, newRoot: string): boolean;
// rewrites every stored path under oldRoot to newRoot and records newRoot;
// false when a file could not be updated
function RelocateInstallRoot(const oldRoot, newRoot: string; log: TRelocateLogProc): boolean;

implementation

function rootPathFileName: string;
begin
  result := AppendPathDelim(GetPrimaryConfigPath) + RootPathFile;
end;

function CurrentInstallRoot: string;
begin
  result := ExtractFilePath(ChompPathDelim(GetPrimaryConfigPath));
end;

function saveText(const fileName, text: string): boolean;
begin
  result := false;
  var attr := FileGetAttrUTF8(fileName);
  if (attr <> -1) and (attr and faReadOnly <> 0) then
    FileSetAttrUTF8(fileName, attr and not faReadOnly);
  try
    var stream := autofree TFileStream.Create(fileName, fmCreate);
    if text <> '' then
      stream.WriteBuffer(text[1], length(text));
    result := true;
  except
  end;
end;

function InstallRootChanged(out oldRoot, newRoot: string): boolean;
begin
  result := false;
  newRoot := CurrentInstallRoot;
  oldRoot := '';
  if FileExistsUTF8(rootPathFileName) then
    oldRoot := Trim(ReadFileToString(rootPathFileName));
  if oldRoot = '' then begin
    saveText(rootPathFileName, newRoot);
    exit;
  end;
  oldRoot := AppendPathDelim(oldRoot);
  if CompareFilenames(oldRoot, newRoot) = 0 then exit;
  // only a moved install carries lazarus and fpc next to the config
  result := DirPathExists(newRoot + 'lazarus') and DirPathExists(newRoot + 'fpc');
end;

// a root match must end where a path element ends, so `laz` cannot hit `laz2`
function pathBoundary(const text: string; i: integer): boolean;
begin
  result := (i > length(text)) or
    (text[i] in ['\', '/', '"', '''', ';', ',', '<', '>', ' ', #9, #13, #10]);
end;

function replaceRoot(const text, oldRoot, newRoot: string; out count: integer): string;
begin
  count := 0;
  var oldDir := ChompPathDelim(oldRoot);
  var newDir := ChompPathDelim(newRoot);
  {$ifdef windows}
  var haystack := LowerCase(text);
  var needle := LowerCase(oldDir);
  {$else}
  var haystack := text;
  var needle := oldDir;
  {$endif}
  result := '';
  var last := 1;
  var p := PosEx(needle, haystack, 1);
  while p > 0 do begin
    if pathBoundary(text, p + length(oldDir)) then begin
      result += copy(text, last, p - last) + newDir;
      last := p + length(oldDir);
      inc(count);
    end;
    p := PosEx(needle, haystack, p + length(oldDir));
  end;
  result += copy(text, last, length(text) - last + 1);
end;

function relocateFile(const fileName, oldRoot, newRoot: string; log: TRelocateLogProc): boolean;
begin
  result := true;
  if not FileExistsUTF8(fileName) then exit;
  var count: integer;
  var text := replaceRoot(ReadFileToString(fileName), oldRoot, newRoot, count);
  if count = 0 then exit;
  log(fileName, rlkFile);
  if not saveText(fileName, text) then begin
    log(Format(lisInstallRootCannotWrite, [fileName]), rlkError);
    exit(false);
  end;
  log(Format(lisInstallRootPathsUpdated, [count]), rlkDetail);
end;

// every file that may hold an absolute path under the root; recent files
// and project sessions are history and stay as they are
function relocatableFiles(const root: string): TStringList;
const
  compilerDirs: array[0..1] of string = ('bin', 'lib' + PathDelim + 'fpc');
begin
  var pcp := AppendPathDelim(GetPrimaryConfigPath);
  result := FindAllFiles(pcp, '*.xml;*.cfg;*.txt', false);
  var i := result.IndexOf(pcp + 'inputhistory.xml');
  if i >= 0 then result.Delete(i);
  result.Add(pcp + 'onlinepackagemanager' + PathDelim + 'config' + PathDelim + 'options.xml');
  result.Add(root + 'lazarus' + PathDelim + 'lazarus.cfg');
  result.Add(root + 'installer.ini');
  result.Add(root + 'fpcupdeluxe.ini');
  result.Add(root + 'fpcpkgconfig' + PathDelim + 'fppkg.cfg');
  result.Add(root + 'fpc' + PathDelim + 'etc' + PathDelim + 'fpc.cfg');
  // fpc.cfg sits next to the compiler: fpc\bin\<target>\ or fpc/lib/fpc/<version>/
  for var binDir in compilerDirs do begin
    var dirs := autofree FindAllDirectories(root + 'fpc' + PathDelim + binDir, false);
    for var dir in dirs do
      result.Add(AppendPathDelim(dir) + 'fpc.cfg');
  end;
end;

function RelocateInstallRoot(const oldRoot, newRoot: string; log: TRelocateLogProc): boolean;
begin
  result := true;
  var files := autofree relocatableFiles(newRoot);
  for var fileName in files do
    if not relocateFile(fileName, oldRoot, newRoot, log) then
      result := false;
  if result and not saveText(rootPathFileName, newRoot) then begin
    log(Format(lisInstallRootCannotWrite, [rootPathFileName]), rlkError);
    result := false;
  end;
end;

end.
