import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:path/path.dart' as path;

const String versionCacheJsonName = 'winlibs_vm_version_cache.json';
const String vmName = 'WinLibsVm';
const String langName = 'WinLibs';
const String vmActivate = 'WinLibsVmActivate';
const String vmDeactivate = 'WinLibsVmDeactivate';
const String sevenZipConsoleURL = 'https://www.7-zip.org/a/7zr.exe';
const String sevenZipConsoleName = '7zr.exe';
const String sevenZipURL = 'https://www.7-zip.org/download.html';
const String sevenZipLinkURL = 'https://www.7-zip.org/a/';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'winlibs'));
  return path.join(anyvmDir, 'envs', 'winlibs');
}

String getEnvCacheDirectory() {
  String envDir = getEnvDirectory();
  anyvm_util.logger.d(path.join(envDir, 'install-cache'));
  return path.join(envDir, 'install-cache');
}

String get7ZipPath() {
  return path.join(getEnvCacheDirectory(), '7z', '7z.exe');
}

List<String> getVersionDirectory() {
  List<String> versionDir = <String>[];
  var directory = Directory(getEnvDirectory());
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  List<FileSystemEntity> entities = directory.listSync();
  for (var entity in entities) {
    if (entity is Directory) {
      RegExp pattern = RegExp(r'^\d+\.\d+\.\d+.*$');
      if (pattern.hasMatch(path.basename(entity.path))) {
        versionDir.add(path.basename(entity.path));
      }
    }
  }
  anyvm_util.logger.d(versionDir);
  return versionDir;
}

Future<void> setVersion(String version) async {
  await unSetVersion();

  var winlibsCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(winlibsCurrentDirPath);
  var winlibsCurrentDir = Directory(winlibsCurrentDirPath);

  if (!await winlibsCurrentDir.exists()) {
    await winlibsCurrentDir.create(recursive: true);
    anyvm_util.logger.i('$winlibsCurrentDirPath creatred');
  }

  var winlibsVersionDirPath = path.join(getEnvDirectory(), version);
  anyvm_util.logger.d(winlibsVersionDirPath);
  var winlibsVersionDir = Directory(winlibsVersionDirPath);

  if (!await winlibsVersionDir.exists()) {
    anyvm_util.logger.w('winlibs version does not exist');
    return;
  }

  List<String> args = [];
  if (await winlibsCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', winlibsCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $winlibsCurrentDirPath');
    }
  }

  args = ['/C', 'MKLINK', '/J', winlibsCurrentDirPath, winlibsVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  var result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger.i(
        'Junction created: $winlibsCurrentDirPath -> $winlibsVersionDirPath');
  }
  var winlibsBinPath = path.join(winlibsCurrentDirPath, 'bin');
  var mingw32BinPath = path.join(winlibsBinPath, 'x86_64-w64-mingw32', 'bin');

  var setPath = '$winlibsBinPath;$mingw32BinPath;';

  anyvm_util.logger.d(setPath);

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;
  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL={"yes"}\n';
  scriptText += 'SET PATH=$setPath%PATH%\n';
  scriptText += 'SET _OLD_LIBCLANG_PATH=%LIBCLANG_PATH%\n';
  scriptText += 'SET LIBCLANG_PATH=$winlibsBinPath\n';
  scriptText += ':END_SET_ENV_VAL\n';

  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "yes";\n';
  scriptText += '    \$env:Path = "$setPath" + \$env:Path;\n';
  scriptText += '    \$env:LIBCLANG_PATH = "$winlibsBinPath";\n';
  scriptText += '} else {\n';
  scriptText += '}\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptPs1, scriptText);
  anyvm_util.logger.i('$activateScriptPs1 creatred');

  var deActivateScriptBat = path.join(scriptsDir, '$vmDeactivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF NOT DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL=\n';
  scriptText += 'SET PATH=%PATH:$setPath=%\n';
  scriptText += 'SET LIBCLANG_PATH=%_OLD_LIBCLANG_PATH%\n';
  scriptText += 'SET _OLD_LIBCLANG_PATH=\n';
  scriptText += ':END_SET_ENV_VAL\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(deActivateScriptBat, scriptText);
  anyvm_util.logger.i('$deActivateScriptBat creatred');

  var deActivateScriptPs1 = path.join(scriptsDir, '$vmDeactivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '} else {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "";\n';
  scriptText += '    Set-Item ENV:Path \$env:Path.Replace("$setPath", "");\n';
  scriptText += '    \$env:LIBCLANG_PATH = \$env:_OLD_LIBCLANG_PATH;\n';
  scriptText += '    \$env:_OLD_LIBCLANG_PATH = "";\n';
  scriptText += '}\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(deActivateScriptPs1, scriptText);
  anyvm_util.logger.i('$deActivateScriptPs1 creatred');

  anyvm_util.setVmVersion(vmName, version);
}

Future<void> unSetVersion() async {
  var currentVersion = await anyvm_util.getVmVersion(vmName);
  if (currentVersion == null) {
    return;
  }

  var winlibsCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(winlibsCurrentDirPath);
  var winlibsCurrentDir = Directory(winlibsCurrentDirPath);

  if (await winlibsCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', winlibsCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    }
    anyvm_util.logger
        .i('Directory renamed/moved successfully.:$winlibsCurrentDirPath');
  }

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;

  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  anyvm_util.logger.d(activateScriptBat);

  scriptText = '';
  scriptText += '@ECHO OFF\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += '\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptPs1, scriptText);
  anyvm_util.logger.i('$activateScriptPs1 creatred');

  anyvm_util.clearVmVersion(vmName);
}

int compareVersion(String version1, String version2) {
  List<String> aParts = version1.split('-');
  List<String> bParts = version2.split('-');

  int length = aParts.length < bParts.length ? aParts.length : bParts.length;

  for (int i = 0; i < length; i++) {
    List<int> aNums = aParts[i].split('.').map(int.parse).toList();
    List<int> bNums = bParts[i].split('.').map(int.parse).toList();

    int subLength = aNums.length < bNums.length ? aNums.length : bNums.length;

    for (int j = 0; j < subLength; j++) {
      if (aNums[j] != bNums[j]) {
        return aNums[j].compareTo(bNums[j]);
      }
    }

    // サブバージョンの長さが異なる場合
    if (aNums.length != bNums.length) {
      return aNums.length.compareTo(bNums.length);
    }
  }

  // バージョン部分の長さが異なる場合
  if (aParts.length != bParts.length) {
    return aParts.length.compareTo(bParts.length);
  }

  // すべての部分が等しい場合
  return 0;
}

class WinLibsVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'WinLibs version manager.';

  WinLibsVm() {
    addSubcommand(WinLibsVmInstall());
    addSubcommand(WinLibsVmUpdate());
    addSubcommand(WinLibsVmVersions());
    addSubcommand(WinLibsVmVersion());
    addSubcommand(WinLibsVmSet());
    addSubcommand(WinLibsVmUnset());
    addSubcommand(WinLibsVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class WinLibsVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  WinLibsVmInstall() {
    argParser.addFlag('list', abbr: 'l', help: 'List all available versions.');
    argParser.addFlag('latest', help: 'latest version to install.');
    argParser.addOption('version', abbr: 'v', help: 'Version to install.');
  }

  @override
  Future<void> run() async {
    var jsonPath =
        path.join(anyvm_util.getApplicationDirectory(), versionCacheJsonName);
    File file = File(jsonPath);
    String jsonString = await file.readAsString();
    List<Map<String, dynamic>> versionList = (jsonDecode(jsonString) as List)
        .map((item) => item as Map<String, dynamic>)
        .toList();

    final isList = argResults?['list'] ?? false;
    if (isList) {
      if (argResults?.rest.isNotEmpty == true) {
        printUsage();
        return;
      }
      for (var item in versionList) {
        anyvm_util.logger.i(item['version']);
      }
      return;
    }
    final isLast = argResults?['latest'] ?? false;
    if (isLast) {
      if (argResults?.rest.isNotEmpty == true) {
        printUsage();
        return;
      }
      await install(versionList.last);
      return;
    }

    final version = argResults?['version'];
    if (version != null) {
      try {
        Map<String, dynamic> foundMap =
            versionList.firstWhere((map) => map['version'] == version);
        await install(foundMap);
      } catch (e) {
        anyvm_util.logger.i('No version found');
      }
      return;
    }
  }

  Future<void> install(Map<String, dynamic> item) async {
    await install7z();
    await installWinLibs(item);
  }

  Future<void> install7z() async {
    var envCacheDirPath = getEnvCacheDirectory();
    anyvm_util.logger.d(envCacheDirPath);
    var envCacheDir = Directory(envCacheDirPath);

    if (!(await envCacheDir.exists())) {
      await envCacheDir.create(recursive: true);
      anyvm_util.logger.i('$envCacheDirPath creatred');
    }

    var sevenZipDirPath = path.join(envCacheDirPath, '7z');
    anyvm_util.logger.d(sevenZipDirPath);
    var sevenZipDir = Directory(sevenZipDirPath);
    if (await sevenZipDir.exists()) {
      anyvm_util.logger.i('7Zip already installed');
      return;
    }

    var sevenZipConsolePath = path.join(envCacheDirPath, sevenZipConsoleName);
    anyvm_util.logger.d(envCacheDirPath);
    var sevenZipConsole = File(sevenZipConsolePath);
    if (!await sevenZipConsole.exists()) {
      try {
        await anyvm_util.downloadFileWithProgress(
            sevenZipConsoleURL, sevenZipConsolePath);
      } catch (e) {
        anyvm_util.logger.e('Error during downloading: $e');
        return;
      }
    }
    String? fileName;
    String? href;
    bool isFound = false;
    final response = await http.get(Uri.parse(sevenZipURL));
    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      // ディレクトリリストを含むaタグを取得
      var links = document.querySelectorAll('a');
      for (final link in links) {
        href = link.attributes['href'];
        if (href != null) {
          fileName = href.replaceAll(sevenZipLinkURL, '').replaceAll('a/', '');
          if (fileName.endsWith('-x64.exe')) {
            isFound = true;
            break;
          }
        }
      }
    }
    if (!isFound || fileName == null) {
      anyvm_util.logger.e('Error not found 7zip');
      return;
    }

    var filePath = path.join(envCacheDirPath, fileName);
    var file = File(filePath);
    if (!await file.exists()) {
      try {
        var baseUrl = Uri.parse(sevenZipLinkURL);
        var fullUrl = baseUrl.resolve(fileName);
        await anyvm_util.downloadFileWithProgress(fullUrl.toString(), filePath);
      } catch (e) {
        anyvm_util.logger.e('Error during downloading: $e');
        return;
      }
    }

    try {
      var result = await Process.start(
          sevenZipConsolePath, ['x', filePath, '-o$sevenZipDirPath', '-y']);
      if (await result.exitCode != 0) {
        anyvm_util.logger.e('Failed to delete 7z extract: ${result.stderr}');
      }
    } catch (e) {
      anyvm_util.logger.e('Failed to delete 7z extract: $e');
    }
    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }

  Future<void> installWinLibs(Map<String, dynamic> item) async {
    var envVerDirPath = path.join(getEnvDirectory(), item['version']);
    anyvm_util.logger.d(envVerDirPath);
    var envVerDir = Directory(envVerDirPath);

    if (await envVerDir.exists()) {
      anyvm_util.logger.i('Already installed');
      return;
    }

    var envCacheDirPath = getEnvCacheDirectory();
    anyvm_util.logger.d(envCacheDirPath);
    var envCacheDir = Directory(envCacheDirPath);

    if (!(await envCacheDir.exists())) {
      await envCacheDir.create(recursive: true);
      anyvm_util.logger.i('$envCacheDirPath creatred');
    }

    var filePath = path.join(envCacheDirPath, item['file']);
    var file = File(filePath);
    if (!await file.exists()) {
      try {
        await anyvm_util.downloadFileWithProgress(item['url'], filePath);
      } catch (e) {
        anyvm_util.logger.e('Error during downloading: $e');
        return;
      }
    }
    var winlibsExtractDirPath = path.join(envCacheDirPath, 'mingw64');
    var winlibsExtractDir = Directory(winlibsExtractDirPath);
    try {
      var result = await Process.start(
          get7ZipPath(), ['x', filePath, '-o$envCacheDirPath', '-y']);
      if (await result.exitCode != 0) {
        anyvm_util.logger.e('Failed to delete 7z extract: ${result.stderr}');
      }
    } catch (e) {
      anyvm_util.logger.e('Failed to delete 7z extract: $e');
    }

    if (await winlibsExtractDir.exists()) {
      await winlibsExtractDir.rename(envVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $envVerDirPath');
    }

    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class WinLibsVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  WinLibsVmUpdate();

  @override
  Future<void> run() async {
    final exe = 'git';
    var args = <String>[];

    args.clear();
    args.add('ls-remote');
    args.add('--tags');
    args.add('https://github.com/brechtsanders/winlibs_mingw');

    anyvm_util.logger.d(exe);
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    var result = await Process.run(exe, args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to git: ${result.stderr}');
      return;
    } else {
      var versions = <String>[];
      var tags = result.stdout.split('\n');
      anyvm_util.logger.d(tags);
      for (var tag in tags) {
        var tagInfo = tag.split('\t');
        if (tagInfo.length > 1) {
          var version = tagInfo[1].replaceAll('refs/tags/', '');
          RegExp pattern = RegExp(
              r'^(\d+\.\d+\.\d+)(posix|win32|mcf)-(\d+\.\d+\.\d+)-(\d+\.\d+\.\d+)-(ucrt|msvcrt)-r(\d+)$');
          var match = pattern.firstMatch(version);
          if (match != null) {
            var gccVersion = match.group(1)!;
            var buildType = match.group(2)!; // posix, win32, mcf
            var llvmVersion = match.group(3)!;
            var mingwVersion = match.group(4)!;
            var crtType = match.group(5)!; // ucrt, msvcrt
            var revision = match.group(6)!;
            if (buildType == 'posix' && crtType == 'ucrt') {
              version = '$gccVersion-$llvmVersion-$mingwVersion-$revision';
              versions.add(version);
            }
          }
        }
      }
      versions.sort(compareVersion);
      List<Map<String, dynamic>> versionList = <Map<String, dynamic>>[];
      for (var version in versions) {
        List<String> parts = version.split('-');
        if (parts.length != 4) {
          continue;
        }
        var dir = '${parts[0]}posix-${parts[1]}-${parts[2]}-ucrt-r${parts[3]}';
        var file =
            'winlibs-x86_64-posix-seh-gcc-${parts[0]}-llvm-${parts[1]}-mingw-w64ucrt-${parts[2]}-r${parts[3]}.7z';
        Map<String, dynamic> versionMap = {
          'version': version,
          'url':
              'https://github.com/brechtsanders/winlibs_mingw/releases/download/$dir/$file',
          'file': file
        };
        versionList.add(versionMap);
      }
      String jsonString =
          const JsonEncoder.withIndent('  ').convert(versionList);
      anyvm_util.logger.d(jsonString);

      var jsonPath =
          path.join(anyvm_util.getApplicationDirectory(), versionCacheJsonName);
      anyvm_util.logger.d(jsonPath);

      File file = File(jsonPath);
      await file.writeAsString(jsonString);
      anyvm_util.logger.i('$jsonPath creatred');
    }
  }
}

class WinLibsVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  WinLibsVmVersions();

  @override
  Future<void> run() async {
    var currentVersion = await anyvm_util.getVmVersion(vmName);
    var versionDirs = getVersionDirectory();
    if (versionDirs.isNotEmpty) {
      for (var dir in versionDirs) {
        if (currentVersion == dir) {
          anyvm_util.logger.i('*$dir');
        } else {
          anyvm_util.logger.i(' $dir');
        }
      }
    } else {
      anyvm_util.logger.i('No versions found');
    }
  }
}

class WinLibsVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  WinLibsVmVersion();

  @override
  Future<void> run() async {
    var currentVersion = await anyvm_util.getVmVersion(vmName);
    if (currentVersion == null) {
      anyvm_util.logger.i('No version found');
    } else {
      anyvm_util.logger.i(currentVersion);
    }
  }
}

class WinLibsVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  WinLibsVmSet() {
    argParser.addOption('version', abbr: 'v', help: 'Version to set.');
  }

  @override
  Future<void> run() async {
    final version = argResults?['version'];
    if (version != null) {
      var versionDirs = getVersionDirectory();
      var hasVesion = versionDirs.where((w) => w == version).firstOrNull;
      if (hasVesion == null) {
        anyvm_util.logger.i('version does not exist');
      } else {
        await setVersion(version);
      }
    } else {
      anyvm_util.logger.i('version does not exist');
    }
  }
}

class WinLibsVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  WinLibsVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class WinLibsVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  WinLibsVmUnInstall() {
    argParser.addOption('version', abbr: 'v', help: 'Version to uninstall.');
  }

  @override
  Future<void> run() async {
    final version = argResults?['version'];
    if (version != null) {
      try {
        await uninstall(version);
      } catch (e) {
        anyvm_util.logger.i('No version found');
      }
      return;
    }
  }

  Future<void> uninstall(String version) async {
    var envVerDirPath = path.join(getEnvDirectory(), version);
    var envVerDir = Directory(envVerDirPath);

    if (!await envVerDir.exists()) {
      anyvm_util.logger.i('No version found');
      return;
    }
    await envVerDir.delete(recursive: true);
    anyvm_util.logger
        .i('Directory renamed/moved successfully.: $envVerDirPath');
  }
}
