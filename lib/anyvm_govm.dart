import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:path/path.dart' as path;

const String versionCacheJsonName = 'go_vm_version_cache.json';
const String vmName = 'GoVm';
const String langName = 'GoLang';
const String vmActivate = 'GoVmActivate';
const String vmDeactivate = 'GoVmDeactivate';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'go'));
  return path.join(anyvmDir, 'envs', 'go');
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
  var goCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(goCurrentDirPath);
  var goCurrentDir = Directory(goCurrentDirPath);

  var goVersionDirPath = path.join(getEnvDirectory(), version);
  anyvm_util.logger.d(goVersionDirPath);
  var goVersionDir = Directory(goVersionDirPath);

  var goPathPath = path.join(getEnvDirectory(), 'go');
  anyvm_util.logger.d(goPathPath);

  if (!await goVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await goCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', goCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $goCurrentDirPath');
    }
  }
  var args = ['/C', 'MKLINK', '/J', goCurrentDirPath, goVersionDirPath];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  final result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
  } else {
    anyvm_util.logger
        .i('Junction created: $goCurrentDirPath -> $goVersionDirPath');
  }

  var goBinPath = path.join(goCurrentDirPath, 'bin');
  var goPathBinPath = path.join(goPathPath, 'bin');

  var setPath = '$goBinPath;$goPathBinPath;';
  anyvm_util.logger.d(setPath);

  var goEnvPath = path.join(goCurrentDirPath, 'env');
  var goPkgPath = path.join(goCurrentDirPath, 'pkg');
  var goPkgModPath = path.join(goPkgPath, 'mod');
  var goCacheDir = path.join(goCurrentDirPath, 'go-build');

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;

  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL={"yes"}\n';
  scriptText += 'SET PATH=$setPath%PATH%\n';
  scriptText += 'SET _OLD_GOROOT=%GOROOT%\n';
  scriptText += 'SET GOROOT=$goCurrentDirPath\n';
  scriptText += 'SET _OLD_GOPATH=%GOPATH%\n';
  scriptText += 'SET GOPATH=$goPathPath\n';
  scriptText += 'SET _OLD_GOBIN=%GOBIN%\n';
  scriptText += 'SET GOBIN=$goPathBinPath\n';
  scriptText += 'SET _OLD_GOCACHE=%GOCACHE%\n';
  scriptText += 'SET GOCACHE=$goCacheDir\n';
  scriptText += 'SET _OLD_GOENV=%GOENV%\n';
  scriptText += 'SET GOENV=$goEnvPath\n';
  scriptText += 'SET _OLD_GO111MODULE=%GO111MODULE%\n';
  scriptText += 'SET GO111MODULE=on\n';
  scriptText += 'SET _OLD_GOMODCACHE=%GOMODCACHE%\n';
  scriptText += 'SET GOMODCACHE=$goPkgModPath\n';
  scriptText += ':END_SET_ENV_VAL\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "yes";\n';
  scriptText += '    \$env:Path = "$setPath" + \$env:Path;\n';
  scriptText += '    \$env:_OLD_GOROOT = \$env:GOROOT;\n';
  scriptText += '    \$env:GOROOT = "$goCurrentDirPath";\n';
  scriptText += '    \$env:_OLD_GOPATH = \$env:GOPATH;\n';
  scriptText += '    \$env:GOPATH = "$goPathPath";\n';
  scriptText += '    \$env:_OLD_GOBIN = \$env:GOBIN;\n';
  scriptText += '    \$env:GOBIN = "$goPathBinPath";\n';
  scriptText += '    \$env:_OLD_GOCACHE = \$env:GOCACHE;\n';
  scriptText += '    \$env:GOCACHE = "$goCacheDir";\n';
  scriptText += '    \$env:_OLD_GOENV = \$env:GOENV;\n';
  scriptText += '    \$env:GOENV = "$goEnvPath";\n';
  scriptText += '    \$env:_OLD_GO111MODULE = \$env:GO111MODULE;\n';
  scriptText += '    \$env:GO111MODULE = "on";\n';
  scriptText += '    \$env:_OLD_GOMODCACHE = \$env:GOMODCACHE;\n';
  scriptText += '    \$env:GOMODCACHE = "$goPkgModPath";\n';
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
  scriptText += 'SET GOROOT=%_OLD_GOROOT%\n';
  scriptText += 'SET _OLD_GOROOT=';
  scriptText += 'SET GOPATH=%_OLD_GOPATH%\n';
  scriptText += 'SET _OLD_GOPATH=';
  scriptText += 'SET GOBIN=%_OLD_GOBIN%\n';
  scriptText += 'SET _OLD_GOBIN=\n';
  scriptText += 'SET GOCACHE=%_OLD_GOCACHE%\n';
  scriptText += 'SET _OLD_GOCACHE=\n';
  scriptText += 'SET GOENV=%_OLD_GOENV%\n';
  scriptText += 'SET _OLD_GOENV=\n';
  scriptText += 'SET GO111MODULE=%_OLD_GO111MODULE%\n';
  scriptText += 'SET _OLD_GO111MODULE=\n';
  scriptText += 'SET GOMODCACHE=%_OLD_GOMODCACHE%\n';
  scriptText += 'SET _OLD_GOMODCACHE=\n';
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
  scriptText += '    \$env:GOROOT = \$env:_OLD_GOROOT;\n';
  scriptText += '    \$env:_OLD_GOROOT = "";\n';
  scriptText += '    \$env:GOPATH = \$env:_OLD_GOPATH;\n';
  scriptText += '    \$env:_OLD_GOPATH = "";\n';
  scriptText += '    \$env:GOBIN = \$env:_OLD_GOBIN;\n';
  scriptText += '    \$env:_OLD_GOBIN = ""\n';
  scriptText += '    \$env:GOCACHE = \$env:_OLD_GOCACHE;\n';
  scriptText += '    \$env:_OLD_GOCACHE = "";\n';
  scriptText += '    \$env:GOENV = \$env:_OLD_GOENV;\n';
  scriptText += '    \$env:_OLD_GOENV = "";\n';
  scriptText += '    \$env:GO111MODULE = \$env:_OLD_GO111MODULE;\n';
  scriptText += '    \$env:_OLD_GO111MODULE = "";\n';
  scriptText += '    \$env:GOMODCACHE = \$env:_OLD_GOMODCACHE;\n';
  scriptText += '    \$env:_OLD_GOMODCACHE = "";\n';
  scriptText += '}\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(deActivateScriptPs1, scriptText);
  anyvm_util.logger.i('$deActivateScriptPs1 creatred');

  anyvm_util.setVmVersion(vmName, version);
}

Future<void> unSetVersion() async {
  var currentVersion = await anyvm_util.getVmVersion(vmName);
  if (currentVersion == null) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  var goCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(goCurrentDirPath);
  var goCurrentDir = Directory(goCurrentDirPath);

  var goVersionDirPath = path.join(getEnvDirectory(), currentVersion);
  anyvm_util.logger.d(goVersionDirPath);
  var goVersionDir = Directory(goVersionDirPath);

  if (!await goVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await goCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', goCurrentDirPath];
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
        .i('Directory renamed/moved successfully.:$goCurrentDirPath');
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

class GoVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'Go version manager.';

  GoVm() {
    addSubcommand(GoVmInstall());
    addSubcommand(GoVmUpdate());
    addSubcommand(GoVmVersions());
    addSubcommand(GoVmVersion());
    addSubcommand(GoVmSet());
    addSubcommand(GoVmUnset());
    addSubcommand(GoVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class GoVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'see $vmName install -h';

  GoVmInstall() {
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
    var goSDKDirPath = path.join(getEnvCacheDirectory(), 'go');
    var goSDKDir = Directory(goSDKDirPath);
    if (await goSDKDir.exists()) {
      await goSDKDir.rename(envVerDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $goSDKDirPath');
    }
    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class GoVmUpdate extends Command {
  @override
  final name = 'update';
  @override
  final description = 'Update the list of installable $langName versions';

  GoVmUpdate();

  @override
  Future<void> run() async {
    final exe = 'git';
    var args = <String>[];
    args.add('ls-remote');
    args.add('--tags');
    args.add('https://github.com/golang/go');

    anyvm_util.logger.d(exe);
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run(exe, args);
    // コマンドが成功したかどうかを確認
    if (result.exitCode == 0) {
      var versions = <String>[];
      var tags = result.stdout.split('\n');
      anyvm_util.logger.d(tags);
      for (var tag in tags) {
        var tagInfo = tag.split('\t');
        if (tagInfo.length > 1) {
          var version = tagInfo[1].replaceAll('refs/tags/go', '');
          RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
          if (pattern.hasMatch(version)) {
            if (anyvm_util.compareVersion(version, '1.13.0') >= 0) {
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
          'url': 'https://go.dev/dl/go$version.windows-amd64.zip',
          'file': 'go$version.windows-amd64.zip'
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
      anyvm_util.logger.e('Command failed');
    }
  }
}

class GoVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  GoVmVersions();

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

class GoVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  GoVmVersion();

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

class GoVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  GoVmSet() {
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

class GoVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  GoVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class GoVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  GoVmUnInstall() {
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
