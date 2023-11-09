import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:path/path.dart' as path;

const String versionCacheJsonName = 'nodejs_vm_version_cache.json';
const String vmName = 'NodejsVm';
const String langName = 'NodejsLang';
const String vmActivate = 'NodejsVmActivate';
const String vmDeactivate = 'NodejsVmDeactivate';
const String nodejsURL = 'https://nodejs.org/dist/';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'nodejs'));
  return path.join(anyvmDir, 'envs', 'nodejs');
}

String getEnvCacheDirectory() {
  String envDir = getEnvDirectory();
  anyvm_util.logger.d(path.join(envDir, 'install-cache'));
  return path.join(envDir, 'install-cache');
}

List<String> getVersionDirectory() {
  List<String> versionDir = <String>[];
  var directory = Directory(getEnvDirectory());
  List<FileSystemEntity> entities = directory.listSync();
  for (var entity in entities) {
    if (entity is Directory) {
      RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
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
  var nodejsCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(nodejsCurrentDirPath);
  var nodejsCurrentDir = Directory(nodejsCurrentDirPath);

  var nodejsVersionDirPath = path.join(getEnvDirectory(), version);
  anyvm_util.logger.d(nodejsVersionDirPath);
  var nodejsVersionDir = Directory(nodejsVersionDirPath);

  if (!await nodejsVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await nodejsCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', nodejsCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $nodejsCurrentDirPath');
    }
  }
  var args = ['/C', 'MKLINK', '/J', nodejsCurrentDirPath, nodejsVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  final result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger
        .i('Junction created: $nodejsCurrentDirPath -> $nodejsVersionDirPath');
  }

  var setPath = '$nodejsCurrentDirPath;';
  anyvm_util.logger.d(setPath);

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;

  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL="yes"\n';
  scriptText += 'SET PATH=$setPath%PATH%\n';
  scriptText += ':END_SET_ENV_VAL\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "yes";\n';
  scriptText += '    \$env:Path = "$setPath" + \$env:Path;\n';
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
  scriptText += ':END_SET_ENV_VAL\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(deActivateScriptBat, scriptText);
  anyvm_util.logger.i('$deActivateScriptBat creatred');

  var deActivateScriptPs1 = path.join(scriptsDir, '$vmDeactivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '} else {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "";\n';
  scriptText += '    Set-Item ENV:Path \$ENV:Path.Replace("$setPath", "");\n';
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
  var nodejsCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(nodejsCurrentDirPath);
  var nodejsCurrentDir = Directory(nodejsCurrentDirPath);

  var nodejsVersionDirPath = path.join(getEnvDirectory(), currentVersion);
  anyvm_util.logger.d(nodejsVersionDirPath);
  var nodejsVersionDir = Directory(nodejsVersionDirPath);

  if (!await nodejsVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await nodejsCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', nodejsCurrentDirPath];
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
        .i('Directory renamed/moved successfully.:$nodejsCurrentDirPath');
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

Future<List<String>> getWebDirectory(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    var document = parser.parse(response.body);
    // ディレクトリリストを含むaタグを取得
    var links = document.querySelectorAll('a');

    // href属性が'/'で終わるものがディレクトリです
    var directories = links
        .map((link) => link.attributes['href'])
        .where((href) => href != null && href.endsWith('/'))
        .toList();

    return directories.cast<String>();
  } else {
    throw Exception('Failed to load directory list');
  }
}

String removeVAndTrailingSlash(String input) {
  // 先頭に 'v' があれば削除
  String result = input;
  if (result.startsWith('v')) {
    result = result.substring(1);
  }

  // 終端に '/' があれば削除
  if (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }

  return result;
}

Future<bool> checkURLIfFileExists(String url) async {
  final response = await http.head(Uri.parse(url));

  // ステータスコードが200ならファイルが存在する
  return response.statusCode == 200;
}

class NodejsVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'Nodejs version manager.';

  NodejsVm() {
    addSubcommand(NodejsVmInstall());
    addSubcommand(NodejsVmUpdate());
    addSubcommand(NodejsVmVersions());
    addSubcommand(NodejsVmVersion());
    addSubcommand(NodejsVmSet());
    addSubcommand(NodejsVmUnset());
    addSubcommand(NodejsVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class NodejsVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  NodejsVmInstall() {
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

    var filePath = path.join(getEnvCacheDirectory(), item['file']);
    var file = File(filePath);
    if (!await file.exists()) {
      try {
        await anyvm_util.downloadFileWithProgress(item['url'], filePath);
      } catch (e) {
        anyvm_util.logger.e('Error during downloading: $e');
        return;
      }
    }
    try {
      await anyvm_util.unzipWithProgress(filePath, envCacheDirPath);
    } catch (e) {
      anyvm_util.logger.e('Error during unzipping: $e');
    }
    var nodejsSDKDirPath =
        path.join(getEnvCacheDirectory(), 'node-v${item["version"]}-win-x64');
    var nodejsSDKDir = Directory(nodejsSDKDirPath);
    if (await nodejsSDKDir.exists()) {
      await nodejsSDKDir.rename(envVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $nodejsSDKDirPath');
    }
    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class NodejsVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  NodejsVmUpdate();

  @override
  Future<void> run() async {
    var lastVersion = '13.99.99';
    List<Map<String, dynamic>> versionList;
    var jsonPath =
        path.join(anyvm_util.getApplicationDirectory(), versionCacheJsonName);
    anyvm_util.logger.d(jsonPath);

    File file = File(jsonPath);
    if (await file.exists()) {
      String jsonString = await file.readAsString();
      versionList = (jsonDecode(jsonString) as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } else {
      versionList = <Map<String, dynamic>>[];
    }

    var dirList = await getWebDirectory(nodejsURL);
    anyvm_util.logger.d(dirList);
    var versions = <String>[];

    for (var dir in dirList) {
      var version = removeVAndTrailingSlash(dir);
      RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
      if (pattern.hasMatch(version)) {
        var baseUrl = Uri.parse(nodejsURL);
        var fullUrl = baseUrl.resolve('v$version/node-v$version-win-x64.zip');
        if (anyvm_util.compareVersion(version, lastVersion) > 0) {
          try {
            Map<String, dynamic> foundMap =
                versionList.firstWhere((map) => map['version'] == version);
            anyvm_util.logger.d(foundMap);
            versions.add(version);
          } catch (e) {
            if (await checkURLIfFileExists(fullUrl.toString())) {
              versions.add(version);
            }
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }
    }
    versions.sort(anyvm_util.compareVersion);
    versionList.clear();
    for (var version in versions) {
      var baseUrl = Uri.parse(nodejsURL);
      var fullUrl = baseUrl.resolve('v$version/node-v$version-win-x64.zip');
      Map<String, dynamic> versionMap = {
        'version': version,
        'url': fullUrl.toString(),
        'file': 'node-v$version-win-x64.zip'
      };
      versionList.add(versionMap);
    }
    String jsonString = const JsonEncoder.withIndent('  ').convert(versionList);
    anyvm_util.logger.d(jsonString);

    await file.writeAsString(jsonString);
    anyvm_util.logger.i('$jsonPath creatred');
  }
}

class NodejsVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  NodejsVmVersions();

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

class NodejsVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  NodejsVmVersion();

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

class NodejsVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  NodejsVmSet() {
    argParser.addOption('version', abbr: 'v', help: 'Version to set.');
  }

  @override
  Future<void> run() async {
    final version = argResults?['version'];
    if (version != null) {
      RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
      if (pattern.hasMatch(path.basename(version))) {
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
    } else {
      anyvm_util.logger.i('version does not exist');
    }
  }
}

class NodejsVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  NodejsVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class NodejsVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  NodejsVmUnInstall() {
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
