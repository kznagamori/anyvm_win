import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:path/path.dart' as path;

const String versionCacheJsonName = 'kotlin_vm_version_cache.json';
const String vmName = 'KotlinVm';
const String langName = 'KotlinLang';
const String vmActivate = 'KotlinVmActivate';
const String vmDeactivate = 'KotlinVmDeactivate';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'kotlin'));
  return path.join(anyvmDir, 'envs', 'kotlin');
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
  var kotlinCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(kotlinCurrentDirPath);
  var kotlinCurrentDir = Directory(kotlinCurrentDirPath);

  var kotlinVersionDirPath = path.join(getEnvDirectory(), version);
  anyvm_util.logger.d(kotlinVersionDirPath);
  var kotlinVersionDir = Directory(kotlinVersionDirPath);

  if (!await kotlinVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await kotlinCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', kotlinCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $kotlinCurrentDirPath');
    }
  }
  var args = ['/C', 'MKLINK', '/J', kotlinCurrentDirPath, kotlinVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  final result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
    return;
  } else {
    anyvm_util.logger
        .i('Junction created: $kotlinCurrentDirPath -> $kotlinVersionDirPath');
  }

  var setPath = '${path.join(kotlinCurrentDirPath, 'bin')};';
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
  var kotlinCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(kotlinCurrentDirPath);
  var kotlinCurrentDir = Directory(kotlinCurrentDirPath);

  var kotlinVersionDirPath = path.join(getEnvDirectory(), currentVersion);
  anyvm_util.logger.d(kotlinVersionDirPath);
  var kotlinVersionDir = Directory(kotlinVersionDirPath);

  if (!await kotlinVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await kotlinCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', kotlinCurrentDirPath];
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
        .i('Directory renamed/moved successfully.:$kotlinCurrentDirPath');
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

class KotlinVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'Kotlin version manager.';

  KotlinVm() {
    addSubcommand(KotlinVmInstall());
    addSubcommand(KotlinVmUpdate());
    addSubcommand(KotlinVmVersions());
    addSubcommand(KotlinVmVersion());
    addSubcommand(KotlinVmSet());
    addSubcommand(KotlinVmUnset());
    addSubcommand(KotlinVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class KotlinVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  KotlinVmInstall() {
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
    var kotlinDirPath = path.join(getEnvCacheDirectory(), 'kotlinc');

    var kotlinDir = Directory(kotlinDirPath);
    if (await kotlinDir.exists()) {
      await kotlinDir.rename(envVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $kotlinDirPath');
    }
    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class KotlinVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  KotlinVmUpdate();

  @override
  Future<void> run() async {
    final exe = 'git';
    var args = <String>[];
    args.add('ls-remote');
    args.add('--tags');
    args.add('https://github.com/JetBrains/kotlin');

    anyvm_util.logger.d(exe);
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run(exe, args);
    // コマンドが成功したかどうかを確認
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
          var version = tagInfo[1].replaceAll('refs/tags/v', '');
          RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
          if (pattern.hasMatch(version)) {
            if (anyvm_util.compareVersion(version, '1.0.0') >= 0) {
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
              'https://github.com/JetBrains/kotlin/releases/download/v$version/kotlin-compiler-$version.zip',
          'file': 'kotlin-compiler-$version.zip'
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

class KotlinVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  KotlinVmVersions();

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

class KotlinVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  KotlinVmVersion();

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

class KotlinVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  KotlinVmSet() {
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

class KotlinVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  KotlinVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class KotlinVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  KotlinVmUnInstall() {
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
