import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:path/path.dart' as path;

const String versionCacheJsonName = 'llvm_vm_version_cache.json';
const String vmName = 'LLVMVm';
const String langName = 'LLVM';
const String vmActivate = 'LLVMVmActivate';
const String vmDeactivate = 'LLVMVmDeactivate';
const String sevenZipConsoleURL = 'https://www.7-zip.org/a/7zr.exe';
const String sevenZipConsoleName = '7zr.exe';
const String sevenZipURL = 'https://www.7-zip.org/download.html';
const String sevenZipLinkURL = 'https://www.7-zip.org/a/';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'llvm'));
  return path.join(anyvmDir, 'envs', 'llvm');
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

  var llvmCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(llvmCurrentDirPath);
  var llvmCurrentDir = Directory(llvmCurrentDirPath);

  if (!await llvmCurrentDir.exists()) {
    await llvmCurrentDir.create(recursive: true);
    anyvm_util.logger.i('$llvmCurrentDirPath creatred');
  }

  var llvmVersionDirPath = path.join(getEnvDirectory(), version);
  anyvm_util.logger.d(llvmVersionDirPath);
  var llvmVersionDir = Directory(llvmVersionDirPath);

  if (!await llvmVersionDir.exists()) {
    anyvm_util.logger.w('llvm version does not exist');
    return;
  }

  List<String> args = [];
  if (await llvmCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', llvmCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $llvmCurrentDirPath');
    }
  }

  args = ['/C', 'MKLINK', '/J', llvmCurrentDirPath, llvmVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  var result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger
        .i('Junction created: $llvmCurrentDirPath -> $llvmVersionDirPath');
  }
  var llvmBinPath = path.join(llvmCurrentDirPath, 'bin');

  var setPath = '$llvmBinPath;';
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
  scriptText += 'SET LIBCLANG_PATH=$llvmBinPath\n';
  scriptText += ':END_SET_ENV_VAL\n';

  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "yes";\n';
  scriptText += '    \$env:Path = "$setPath" + \$env:Path;\n';
  scriptText += '    \$env:LIBCLANG_PATH = "$llvmBinPath";\n';
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

  var llvmCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(llvmCurrentDirPath);
  var llvmCurrentDir = Directory(llvmCurrentDirPath);

  if (await llvmCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', llvmCurrentDirPath];
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
        .i('Directory renamed/moved successfully.:$llvmCurrentDirPath');
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
  version1 = version1.split('-').first;
  version2 = version2.split('-').first;
  List<int> nums1 = version1.split('.').map((e) => int.parse(e)).toList();
  List<int> nums2 = version2.split('.').map((e) => int.parse(e)).toList();

  int n1 = nums1.length, n2 = nums2.length;

  for (int i = 0; i < n1 || i < n2; i++) {
    int num1 = i < n1 ? nums1[i] : 0;
    int num2 = i < n2 ? nums2[i] : 0;

    if (num1 < num2) {
      return -1;
    } else if (num1 > num2) {
      return 1;
    }
  }
  return 0; // versions are equal
}

class LLVMVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'LLVM version manager.';

  LLVMVm() {
    addSubcommand(LLVMVmInstall());
    addSubcommand(LLVMVmUpdate());
    addSubcommand(LLVMVmVersions());
    addSubcommand(LLVMVmVersion());
    addSubcommand(LLVMVmSet());
    addSubcommand(LLVMVmUnset());
    addSubcommand(LLVMVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class LLVMVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  LLVMVmInstall() {
    argParser.addFlag('list', abbr: 'l', help: 'List all available versions.');
    argParser.addFlag('lastest', help: 'Lastest version to install.');
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
    final isLast = argResults?['lastest'] ?? false;
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
    await installLLVM(item);
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

  Future<void> installLLVM(Map<String, dynamic> item) async {
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
    var llvmExtractDirPath = path.join(envCacheDirPath, 'llvm');
    var llvmExtractDir = Directory(llvmExtractDirPath);
    try {
      var result = await Process.start(
          get7ZipPath(), ['x', filePath, '-o$llvmExtractDirPath', '-y']);
      if (await result.exitCode != 0) {
        anyvm_util.logger.e('Failed to delete 7z extract: ${result.stderr}');
      }
    } catch (e) {
      anyvm_util.logger.e('Failed to delete 7z extract: $e');
    }

    if (await llvmExtractDir.exists()) {
      await llvmExtractDir.rename(envVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $envVerDirPath');
    }

    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class LLVMVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  LLVMVmUpdate();

  @override
  Future<void> run() async {
    final exe = 'git';
    var args = <String>[];

    args.clear();
    args.add('ls-remote');
    args.add('--tags');
    args.add('https://github.com/llvm/llvm-project.git');

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
          var version = tagInfo[1].replaceAll('refs/tags/llvmorg-', '');
          RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
          if (pattern.hasMatch(version)) {
            if (anyvm_util.compareVersion(version, '14.0.0') >= 0) {
              versions.add(version);
            }
          }
        }
      }
      versions.sort(compareVersion);
      List<Map<String, dynamic>> versionList = <Map<String, dynamic>>[];
      for (var version in versions) {
        Map<String, dynamic> versionMap = {
          'version': version,
          'url':
              'https://github.com/llvm/llvm-project/releases/download/llvmorg-$version/LLVM-$version-win64.exe',
          'file': 'LLVM-$version-win64.exe'
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

class LLVMVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  LLVMVmVersions();

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

class LLVMVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  LLVMVmVersion();

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

class LLVMVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  LLVMVmSet() {
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

class LLVMVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  LLVMVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class LLVMVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  LLVMVmUnInstall() {
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
