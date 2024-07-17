import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:path/path.dart' as path;

const String versionCacheJsonName = 'python_vm_version_cache.json';
const String vmName = 'PythonVm';
const String langName = 'PythonLang';
const String vmActivate = 'PythonVmActivate';
const String vmDeactivate = 'PythonVmDeactivate';
const String pythonWindowsURL = 'https://www.python.org/downloads/windows/';
const String pythonURL = 'https://www.python.org/ftp/python/';
const String wixURL =
    'https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip';

const String wixFileName = 'wix311-binaries.zip';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'python'));
  return path.join(anyvmDir, 'envs', 'python');
}

String getEnvCacheDirectory() {
  String envDir = getEnvDirectory();
  anyvm_util.logger.d(path.join(envDir, 'install-cache'));
  return path.join(envDir, 'install-cache');
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
  var pythonCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(pythonCurrentDirPath);
  var pythonCurrentDir = Directory(pythonCurrentDirPath);

  var pythonVersionDirPath = path.join(getEnvDirectory(), version);
  anyvm_util.logger.d(pythonVersionDirPath);
  var pythonVersionDir = Directory(pythonVersionDirPath);

  if (!await pythonVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await pythonCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', pythonCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $pythonCurrentDirPath');
    }
  }
  var args = ['/C', 'MKLINK', '/J', pythonCurrentDirPath, pythonVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  final result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger
        .i('Junction created: $pythonCurrentDirPath -> $pythonVersionDirPath');
  }

  var pythonScriptsPath = path.join(pythonVersionDirPath, 'Scripts');

  var setPath = '$pythonCurrentDirPath;$pythonScriptsPath;';
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
  scriptText += '    Set-Item ENV:Path \$env:Path.Replace("$setPath", "");\n';
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
  var pythonCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(pythonCurrentDirPath);
  var pythonCurrentDir = Directory(pythonCurrentDirPath);

  var pythonVersionDirPath = path.join(getEnvDirectory(), currentVersion);
  anyvm_util.logger.d(pythonVersionDirPath);
  var pythonVersionDir = Directory(pythonVersionDirPath);

  if (!await pythonVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await pythonCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', pythonCurrentDirPath];
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
        .i('Directory renamed/moved successfully.:$pythonCurrentDirPath');
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

class PythonVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'Python version manager.';

  PythonVm() {
    addSubcommand(PythonVmInstall());
    addSubcommand(PythonVmUpdate());
    addSubcommand(PythonVmVersions());
    addSubcommand(PythonVmVersion());
    addSubcommand(PythonVmSet());
    addSubcommand(PythonVmUnset());
    addSubcommand(PythonVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class PythonVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  PythonVmInstall() {
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

    var wixDirPath = path.join(envCacheDirPath, 'Wix');
    anyvm_util.logger.d(wixDirPath);
    var wixDir = Directory(wixDirPath);

    var wixFilePath = path.join(envCacheDirPath, wixFileName);
    var wixFile = File(wixFilePath);

    if (!await wixDir.exists()) {
      if (!await wixFile.exists()) {
        try {
          await anyvm_util.downloadFileWithProgress(wixURL, wixFilePath);
        } catch (e) {
          anyvm_util.logger.e('Error during downloading: $e');
          return;
        }
      }
      try {
        await anyvm_util.unzipWithProgress(wixFilePath, wixDirPath);
      } catch (e) {
        anyvm_util.logger.e('Error during unzipping: $e');
      }
      if (await wixFile.exists()) {
        await wixFile.delete();
        anyvm_util.logger.i('File deleted successfully.: $wixFilePath');
      }
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

    var extractDirPath = path.join(envCacheDirPath, item['version']);
    var extractDir = Directory(extractDirPath);
    if (!await extractDir.exists()) {
      final exe = path.join(wixDirPath, 'dark.exe');
      var args = <String>[];
      args.add(filePath);
      args.add('-x');
      args.add(extractDirPath);

      anyvm_util.logger.d(exe);
      for (var arg in args) {
        anyvm_util.logger.d(arg);
      }
      ProcessResult result = await Process.run(exe, args);
      if (result.exitCode != 0) {
        anyvm_util.logger.e('Failed to extract $wixDirPath: ${result.stderr}');
        return;
      }
    }

    var msiDirPath = path.join(extractDirPath, 'AttachedContainer');
    var msiDir = Directory(msiDirPath);
    if (await msiDir.exists()) {
      await for (var entity
          in msiDir.list(recursive: true, followLinks: false)) {
        List<String> excludeFiles = [
          'appendpath.msi',
          'launcher.msi',
          'path.msi',
          'pip.msi'
        ];
        if (entity is File && entity.path.endsWith('.msi')) {
          bool exclude = false;
          for (var fileName in excludeFiles) {
            if (entity.path.endsWith(fileName)) {
              exclude = true;
              break;
            }
          }
          if (!exclude) {
            try {
              var msiFilePath = entity.path;
              var msiFile = await File(msiFilePath).resolveSymbolicLinks();

              if (!await envVerDir.exists()) {
                await envVerDir.create(recursive: true);
                anyvm_util.logger.i('$envVerDirPath creatred');
              }
              var dirPath =
                  await Directory(envVerDirPath).resolveSymbolicLinks();
              final exe =
                  'msiexec.exe /quiet /a "$msiFile" targetdir="$dirPath"';
              var args = <String>[];
              anyvm_util.logger.d(exe);
              ProcessResult result = await Process.run(exe, args);
              if (result.exitCode != 0) {
                anyvm_util.logger
                    .e('Failed to extract $wixDirPath: ${result.stderr}');
                throw Exception('Failed to extract $wixDirPath');
              }
            } catch (e) {
              if (await envVerDir.exists()) {
                await envVerDir.delete(recursive: true);
                anyvm_util.logger
                    .i('Directory deleted successfully.: $envVerDirPath');
              }
            }
          }
        }
      }
    } else {
      anyvm_util.logger.e('Failed to extract $msiDirPath');
    }

    if (await extractDir.exists()) {
      extractDir.delete(recursive: true);
      anyvm_util.logger.i('Directory renamed/moved successfully.:$extractDir');
    }

    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
    var pythonExePath = path.join(envVerDirPath, 'python.exe');
    var pythonExe = File(pythonExePath);
    if (await pythonExe.exists()) {
      final exe = pythonExePath;
      var args = <String>[];
      args.add('-E');
      args.add('-s');
      args.add('-m');
      args.add('ensurepip');
      args.add('-U');
      args.add('--default-pip');
      anyvm_util.logger.d(exe);
      for (var arg in args) {
        anyvm_util.logger.d(arg);
      }
      ProcessResult result = await Process.run(exe, args);
      if (result.exitCode != 0) {
        anyvm_util.logger.e('Failed to pip update: ${result.stderr}');
        return;
      }
    }
  }
}

class PythonVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  PythonVmUpdate();

  @override
  Future<void> run() async {
    final response = await http.get(Uri.parse(pythonWindowsURL));
    if (response.statusCode == 200) {
      var versions = <String>[];
      var document = parser.parse(response.body);
      // ディレクトリリストを含むaタグを取得
      var links = document.querySelectorAll('a');

      for (final link in links) {
        final text = link.text;
        if (text == 'Windows installer (64-bit)') {
          final href = link.attributes['href'];
          if (href != null) {
            final versionPath = href.replaceAll(pythonURL, '');
            var version = versionPath.split('/').first;
            var baseUrl = Uri.parse(pythonURL);
            var fullUrl = baseUrl.resolve('$version/python-$version-amd64.exe');
            if (fullUrl.toString() == href) {
              versions.add(version);
            }
          }
        }
      }
      versions.sort(anyvm_util.compareVersion);
      List<Map<String, dynamic>> versionList = <Map<String, dynamic>>[];
      for (var version in versions) {
        var baseUrl = Uri.parse(pythonURL);
        var fullUrl = baseUrl.resolve('$version/python-$version-amd64.exe');
        Map<String, dynamic> versionMap = {
          'version': version,
          'url': fullUrl.toString(),
          'file': 'python-$version-amd64.exe'
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
    } else {
      throw Exception('Failed to get python web site');
    }
  }
}

class PythonVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  PythonVmVersions();

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

class PythonVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  PythonVmVersion();

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

class PythonVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  PythonVmSet() {
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

class PythonVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  PythonVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class PythonVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  PythonVmUnInstall() {
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
