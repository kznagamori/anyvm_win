import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:path/path.dart' as path;

const String versionCacheJsonName = 'rust_vm_version_cache.json';
const String vmName = 'RustVm';
const String langName = 'RustLang';
const String vmActivate = 'RustVmActivate';
const String vmDeactivate = 'RustVmDeactivate';
const String sevenZipConsoleURL = 'https://www.7-zip.org/a/7zr.exe';
const String sevenZipConsoleName = '7zr.exe';
const String sevenZipURL = 'https://www.7-zip.org/download.html';
const String sevenZipLinkURL = 'https://www.7-zip.org/a/';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'rust'));
  return path.join(anyvmDir, 'envs', 'rust');
}

String getEnvCacheDirectory() {
  String envDir = getEnvDirectory();
  anyvm_util.logger.d(path.join(envDir, 'install-cache'));
  return path.join(envDir, 'install-cache');
}

String getMingwEnvPath() {
  return path.join(getEnvDirectory(), 'mingw64');
}

String getLLVMEnvPath() {
  return path.join(getEnvDirectory(), 'llvm');
}

String getRustUpHomePath() {
  return path.join(getEnvDirectory(), '.rustup');
}

String getCargoHomePath() {
  return path.join(getEnvDirectory(), '.cargo');
}

String get7ZipPath() {
  return path.join(getEnvCacheDirectory(), '7z', '7z.exe');
}

List<String> getVersionDirectory() {
  List<String> versionDir = <String>[];

  var mingwDirectory = Directory(getMingwEnvPath());
  if (!mingwDirectory.existsSync()) {
    mingwDirectory.createSync(recursive: true);
  }
  List<FileSystemEntity> mingwEntities = mingwDirectory.listSync();
  var llvmDirectory = Directory(getLLVMEnvPath());
  if (!llvmDirectory.existsSync()) {
    llvmDirectory.createSync(recursive: true);
  }
  List<FileSystemEntity> llvmEntities = llvmDirectory.listSync();

  for (var mingwEntity in mingwEntities) {
    if (mingwEntity is Directory) {
      RegExp pattern = RegExp(r'^\d+\.\d+\.\d+');
      if (pattern.hasMatch(path.basename(mingwEntity.path))) {
        for (var llvmEntity in llvmEntities) {
          if (llvmEntity is Directory) {
            if (pattern.hasMatch(path.basename(llvmEntity.path))) {
              versionDir.add(
                  '${path.basename(mingwEntity.path)}:${path.basename(llvmEntity.path)}');
            }
          }
        }
      }
    }
  }
  anyvm_util.logger.d(versionDir);
  return versionDir;
}

Future<void> setVersion(String version) async {
  await unSetVersion();
  var parts = version.split(':');
  var mingwVesion = parts[0];
  var llvmVesion = parts[1];

  var rustCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(rustCurrentDirPath);
  var rustCurrentDir = Directory(rustCurrentDirPath);

  if (!await rustCurrentDir.exists()) {
    await rustCurrentDir.create(recursive: true);
    anyvm_util.logger.i('$rustCurrentDirPath creatred');
  }

  var mingwVersionDirPath = path.join(getMingwEnvPath(), mingwVesion);
  anyvm_util.logger.d(mingwVersionDirPath);
  var mingwVersionDir = Directory(mingwVersionDirPath);

  if (!await mingwVersionDir.exists()) {
    anyvm_util.logger.w('mingw version does not exist');
    return;
  }

  var llvmVersionDirPath = path.join(getLLVMEnvPath(), llvmVesion);
  anyvm_util.logger.d(llvmVersionDirPath);
  var llvmVersionDir = Directory(llvmVersionDirPath);

  if (!await llvmVersionDir.exists()) {
    anyvm_util.logger.w('llvm version does not exist');
    return;
  }

  var mingwCurrentDirPath = path.join(rustCurrentDirPath, 'mingw64');
  var mingwCurrentDir = Directory(mingwCurrentDirPath);

  var llvmCurrentDirPath = path.join(rustCurrentDirPath, 'llvm');
  var llvmCurrentDir = Directory(llvmCurrentDirPath);

  if (await mingwCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', mingwCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $mingwCurrentDirPath');
    }
  }

  List<String> args = [];
  args = ['/C', 'MKLINK', '/J', mingwCurrentDirPath, mingwVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  var result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger
        .i('Junction created: $mingwCurrentDirPath -> $mingwVersionDirPath');
  }

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
  result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger
        .i('Junction created: $mingwCurrentDirPath -> $mingwVersionDirPath');
  }
  var mingwBinPath = path.join(mingwCurrentDirPath, 'bin');
  var mingw32BinPath =
      path.join(mingwCurrentDirPath, 'x86_64-w64-mingw32', 'bin');
  var llvmBinPath = path.join(llvmCurrentDirPath, 'bin');
  var cargoBinPath = path.join(getCargoHomePath(), 'bin');

  var setPath = '$cargoBinPath;$mingwBinPath;$mingw32BinPath;$llvmBinPath;';
  anyvm_util.logger.d(setPath);

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;
  //LIBCLANG_PATH
  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL={"yes"}\n';
  scriptText += 'SET PATH=$setPath%PATH%\n';
  scriptText += 'SET _OLD_RUSTUP_HOME=%RUSTUP_HOME%\n';
  scriptText += 'SET RUSTUP_HOME=${getRustUpHomePath()}\n';
  scriptText += 'SET _OLD_CARGO_HOME=%CARGO_HOME%\n';
  scriptText += 'SET CARGO_HOME=${getCargoHomePath()}\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_SERVER=%RUSTUP_DIST_SERVER%\n';
  scriptText += 'SET RUSTUP_DIST_SERVER=https://static.rust-lang.org\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_ROOT=%RUSTUP_DIST_ROOT%\n';
  scriptText += 'SET RUSTUP_DIST_ROOT=https://static.rust-lang.org/rustup\n';
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
  scriptText += '    \$env:_OLD_RUSTUP_HOME = \$env:RUSTUP_HOME;\n';
  scriptText += '    \$env:RUSTUP_HOME = "${getRustUpHomePath()}";\n';
  scriptText += '    \$env:_OLD_CARGO_HOME = \$env:CARGO_HOME;\n';
  scriptText += '    \$env:CARGO_HOME = "${getCargoHomePath()}";\n';
  scriptText +=
      '    \$env:_OLD_RUSTUP_DIST_SERVER = \$env:RUSTUP_DIST_SERVER;\n';
  scriptText +=
      '    \$env:RUSTUP_DIST_SERVER = "https://static.rust-lang.org";\n';
  scriptText += '    \$env:_OLD_RUSTUP_DIST_ROOT = \$env:RUSTUP_DIST_ROOT;\n';
  scriptText +=
      '    \$env:RUSTUP_DIST_ROOT = "https://static.rust-lang.org/rustup";\n';
  scriptText += '    \$env:_OLD_LIBCLANG_PATH = \$env:LIBCLANG_PATH;\n';
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
  scriptText += 'SET RUSTUP_HOME=%_OLD_RUSTUP_HOME%\n';
  scriptText += 'SET _OLD_RUSTUP_HOME=';
  scriptText += 'SET CARGO_HOME=%_OLD_CARGO_HOME%\n';
  scriptText += 'SET _OLD_CARGO_HOME=';
  scriptText += 'SET RUSTUP_DIST_SERVER=%_OLD_RUSTUP_DIST_SERVER%\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_SERVER=\n';
  scriptText += 'SET RUSTUP_DIST_ROOT=%_OLD_RUSTUP_DIST_ROOT%\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_ROOT=\n';
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
  scriptText += '    \$env:RUSTUP_HOME = \$env:_OLD_RUSTUP_HOME;\n';
  scriptText += '    \$env:_OLD_RUSTUP_HOME = "";\n';
  scriptText += '    \$env:CARGO_HOME = \$env:_OLD_CARGO_HOME;\n';
  scriptText += '    \$env:_OLD_CARGO_HOME = "";\n';
  scriptText +=
      '    \$env:RUSTUP_DIST_SERVER = \$env:_OLD_RUSTUP_DIST_SERVER;\n';
  scriptText += '    \$env:_OLD_RUSTUP_DIST_SERVER = ""\n';
  scriptText += '    \$env:RUSTUP_DIST_ROOT = \$env:_OLD_RUSTUP_DIST_ROOT;\n';
  scriptText += '    \$env:_OLD_RUSTUP_DIST_ROOT = "";\n';
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

  var rustCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(rustCurrentDirPath);

  var mingwCurrentDirPath = path.join(rustCurrentDirPath, 'mingw64');
  var mingwCurrentDir = Directory(mingwCurrentDirPath);

  var llvmCurrentDirPath = path.join(rustCurrentDirPath, 'llvm');
  var llvmCurrentDir = Directory(llvmCurrentDirPath);

  if (await mingwCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', mingwCurrentDirPath];
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
        .i('Directory renamed/moved successfully.:$mingwCurrentDirPath');
  }

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

class RustVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'Rust version manager.';

  RustVm() {
    addSubcommand(RustVmInstall());
    addSubcommand(RustVmUpdate());
    addSubcommand(RustVmVersions());
    addSubcommand(RustVmVersion());
    addSubcommand(RustVmSet());
    addSubcommand(RustVmUnset());
    addSubcommand(RustVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class RustVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  RustVmInstall() {
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
    List<Map<String, dynamic>> rustVersionList =
        (jsonDecode(jsonString) as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();

    var mingwVersionList = rustVersionList[0]['mingw64'];
    var llvmVersionList = rustVersionList[1]['llvm'];

    final isList = argResults?['list'] ?? false;
    if (isList) {
      if (argResults?.rest.isNotEmpty == true) {
        printUsage();
        return;
      }
      anyvm_util.logger.i('<Mingw64Vesion>:<LLVMVesion>');
      for (var mingw in mingwVersionList) {
        for (var llvm in llvmVersionList) {
          anyvm_util.logger.i('${mingw['version']}:${llvm['version']}');
        }
      }
      return;
    }
    final isLast = argResults?['lastest'] ?? false;
    if (isLast) {
      if (argResults?.rest.isNotEmpty == true) {
        printUsage();
        return;
      }

      await install(mingwVersionList.last, llvmVersionList.last);
      return;
    }

    final version = argResults?['version'];
    if (version != null) {
      try {
        var parts = version.split(':');
        Map<String, dynamic> mingw =
            mingwVersionList.firstWhere((map) => map['version'] == parts[0]);
        Map<String, dynamic> llvm =
            llvmVersionList.firstWhere((map) => map['version'] == parts[1]);
        await install(mingw, llvm);
      } catch (e) {
        anyvm_util.logger.i('No version found');
      }
      return;
    }
  }

  Future<void> install(
      Map<String, dynamic> mingw, Map<String, dynamic> llvm) async {
    await install7z();
    await installMingw(mingw);
    await installLLVM(llvm);
    await installRust();
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

  Future<void> installMingw(Map<String, dynamic> item) async {
    var mingwEnvPath = getMingwEnvPath();
    var mingwEnv = Directory(mingwEnvPath);
    if (!await mingwEnv.exists()) {
      await mingwEnv.create(recursive: true);
      anyvm_util.logger.i('$mingwEnvPath creatred');
    }

    var mingwVerDirPath = path.join(mingwEnvPath, item['version']);
    anyvm_util.logger.d(mingwVerDirPath);
    var mingwVerDir = Directory(mingwVerDirPath);

    if (await mingwVerDir.exists()) {
      anyvm_util.logger.i('Mingw64 already installed');
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

    var mingwExtractDirPath = path.join(envCacheDirPath, 'mingw64');
    var mingwExtractDir = Directory(mingwExtractDirPath);
    try {
      var result = await Process.start(
          get7ZipPath(), ['x', filePath, '-o$envCacheDirPath', '-y']);
      if (await result.exitCode != 0) {
        anyvm_util.logger.e('Failed to delete 7z extract: ${result.stderr}');
      }
    } catch (e) {
      anyvm_util.logger.e('Failed to delete 7z extract: $e');
    }

    if (await mingwExtractDir.exists()) {
      await mingwExtractDir.rename(mingwVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $mingwVerDirPath');
    }

    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }

  Future<void> installLLVM(Map<String, dynamic> item) async {
    var llvmEnvPath = getLLVMEnvPath();

    var llvmEnv = Directory(llvmEnvPath);
    if (!await llvmEnv.exists()) {
      await llvmEnv.create(recursive: true);
      anyvm_util.logger.i('$llvmEnvPath creatred');
    }

    var llvmVerDirPath = path.join(llvmEnvPath, item['version']);
    anyvm_util.logger.d(llvmVerDirPath);
    var llvmVerDir = Directory(llvmVerDirPath);

    if (await llvmVerDir.exists()) {
      anyvm_util.logger.i('LLVM already installed');
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
      await llvmExtractDir.rename(llvmVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $llvmVerDirPath');
    }

    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }

  Future<void> installRust() async {
    var cargoHomePath = getCargoHomePath();
    var cargoHome = Directory(cargoHomePath);

    var rustUpHomePath = getRustUpHomePath();
    var rustUpHome = Directory(rustUpHomePath);

    if (await cargoHome.exists() && await rustUpHome.exists()) {
      anyvm_util.logger.i('Rust already installed');
      return;
    }

    var envCacheDirPath = getEnvCacheDirectory();
    anyvm_util.logger.d(envCacheDirPath);
    var envCacheDir = Directory(envCacheDirPath);

    if (!(await envCacheDir.exists())) {
      await envCacheDir.create(recursive: true);
      anyvm_util.logger.i('$envCacheDirPath creatred');
    }

    var filePath = path.join(envCacheDirPath, 'rustup-init.exe');
    var file = File(filePath);
    if (!await file.exists()) {
      try {
        await anyvm_util.downloadFileWithProgress(
            'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe',
            filePath);
      } catch (e) {
        anyvm_util.logger.e('Error during downloading: $e');
        return;
      }
    }
    if (!await cargoHome.exists()) {
      await cargoHome.create(recursive: true);
      anyvm_util.logger.i('$cargoHome creatred');
    }

    if (!await rustUpHome.exists()) {
      await rustUpHome.create(recursive: true);
      anyvm_util.logger.i('$rustUpHome creatred');
    }
    try {
      var exe =
          '"$filePath" -y --no-modify-path --default-host x86_64-pc-windows-gnu --default-toolchain stable';
      var args = <String>[];
      var envVers = {
        'CARGO_HOME': cargoHomePath,
        'RUSTUP_HOME': rustUpHomePath,
        'RUSTUP_DIST_SERVER': 'https://static.rust-lang.org',
        'RUSTUP_DIST_ROOT': 'https://static.rust-lang.org/rustup'
      };
      ProcessResult result;
      anyvm_util.logger.d(exe);
      for (var arg in args) {
        anyvm_util.logger.d(arg);
      }
      result = await Process.run(exe, args, environment: envVers);
      if (result.exitCode != 0) {
        anyvm_util.logger.e('Failed to execute command: ${result.stderr}');
        cargoHome.delete(recursive: true);
        rustUpHome.delete(recursive: true);
        return;
      } else {
        anyvm_util.logger.i('execute: $exe');
      }
    } catch (e) {
      anyvm_util.logger.e('Failed to ecute command: $e');
      cargoHome.delete(recursive: true);
      rustUpHome.delete(recursive: true);
    }

    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class RustVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  RustVmUpdate();

  @override
  Future<void> run() async {
    final exe = 'git';
    var args = <String>[];

    List<Map<String, dynamic>> rustVersionList = <Map<String, dynamic>>[];
    //mingw64
    args.clear();
    args.add('ls-remote');
    args.add('--tags');
    args.add('https://github.com/niXman/mingw-builds-binaries.git');

    anyvm_util.logger.d(exe);
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result;
    result = await Process.run(exe, args);
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
          var longVersion = tagInfo[1].replaceAll('refs/tags/', '');
          var parts = longVersion.split('-');
          // 最初の "-" で分割したいので、最初の2つの要素のみを使用する
          var version = parts.first;
          //var versionInfo = parts.skip(1).join('-');
          RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
          if (pattern.hasMatch(version)) {
            versions.add(longVersion);
          }
        }
      }
      versions.sort(compareVersion);
      List<Map<String, dynamic>> versionList = <Map<String, dynamic>>[];
      for (var longVersion in versions) {
        // 最初の "-" で分割したいので、最初の2つの要素のみを使用する
        var parts = longVersion.split('-');
        var version = parts.first;
        var versionInfo = parts.skip(1).join('-');

        Map<String, dynamic> versionMap = {
          'version': longVersion,
          'url':
              'https://github.com/niXman/mingw-builds-binaries/releases/download/$longVersion/x86_64-$version-release-posix-seh-ucrt-$versionInfo.7z',
          'file': 'x86_64-$version-release-posix-seh-ucrt-$versionInfo.7z'
        };
        versionList.add(versionMap);
      }
      rustVersionList.add({'mingw64': versionList});
    }
    //llvm
    args.clear();
    args.add('ls-remote');
    args.add('--tags');
    args.add('https://github.com/llvm/llvm-project.git');

    anyvm_util.logger.d(exe);
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    result = await Process.run(exe, args);
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
      versions.sort(anyvm_util.compareVersion);
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
      rustVersionList.add({'llvm': versionList});
    }
    String jsonString =
        const JsonEncoder.withIndent('  ').convert(rustVersionList);
    anyvm_util.logger.d(jsonString);

    var jsonPath =
        path.join(anyvm_util.getApplicationDirectory(), versionCacheJsonName);
    anyvm_util.logger.d(jsonPath);

    File file = File(jsonPath);
    await file.writeAsString(jsonString);
    anyvm_util.logger.i('$jsonPath creatred');
  }
}

class RustVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  RustVmVersions();

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

class RustVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  RustVmVersion();

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

class RustVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  RustVmSet() {
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

class RustVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  RustVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class RustVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  RustVmUnInstall() {
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
