import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:path/path.dart' as path;

const String vmName = 'AndroidSDKVm';
const String langName = 'AndroidSDK';
const String vmActivate = 'AndroidSDKVmActivate';
const String vmDeactivate = 'AndroidSDKVmDeactivate';

String getEnvDirectory() {
  String appDir = anyvm_util.getApplicationDirectory();
  String anyvmDir = Directory(appDir).parent.path;
  anyvm_util.logger.d(path.join(anyvmDir, 'envs', 'AndroidSDK'));
  return path.join(anyvmDir, 'envs', 'AndroidSDK');
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
      RegExp pattern = RegExp(r'^\d+$');
      if (pattern.hasMatch(path.basename(entity.path))) {
        versionDir.add(path.basename(entity.path));
      }
    }
  }
  anyvm_util.logger.d(versionDir);
  return versionDir;
}

String getAndroidSDKUpHomePath() {
  return path.join(getEnvDirectory(), '.rustup');
}

String getCargoHomePath() {
  return path.join(getEnvDirectory(), '.cargo');
}

Future<void> setVersion(String version) async {
  await unSetVersion();
  var androidSDKCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(androidSDKCurrentDirPath);
  var androidSDKCurrentDir = Directory(androidSDKCurrentDirPath);

  var androidSDKVersionDirPath = path.join(getEnvDirectory(), version);
  anyvm_util.logger.d(androidSDKVersionDirPath);
  var androidSDKVersionDir = Directory(androidSDKVersionDirPath);

  if (!await androidSDKVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await androidSDKCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', androidSDKCurrentDirPath];
    anyvm_util.logger.d('cmd.exe');
    for (var arg in args) {
      anyvm_util.logger.d(arg);
    }
    ProcessResult result = await Process.run('cmd.exe', args);
    if (result.exitCode != 0) {
      anyvm_util.logger.e('Failed to delete junction: ${result.stderr}');
      return;
    } else {
      anyvm_util.logger.i('Derectory deleted: $androidSDKCurrentDirPath');
    }
  }
  var args = [
    '/C',
    'MKLINK',
    '/J',
    androidSDKCurrentDirPath,
    androidSDKVersionDirPath
  ];
  anyvm_util.logger.d('cmd.exe');
  for (var arg in args) {
    anyvm_util.logger.d(arg);
  }
  final result = await Process.run('cmd.exe', args);
  if (result.exitCode != 0) {
    anyvm_util.logger.e('${result.stderr}');
    return;
  } else {
    anyvm_util.logger.i(
        'Junction created: $androidSDKCurrentDirPath -> $androidSDKVersionDirPath');
  }

  var platformPath = path.join(androidSDKCurrentDirPath, 'platform-tools');
  var cmdlinePath =
      path.join(androidSDKCurrentDirPath, 'cmdline-tools', 'latest', 'bin');
  var emulatorPath = path.join(androidSDKCurrentDirPath, 'emulator');

  var setPath = '$platformPath;$cmdlinePath;$emulatorPath;';
  anyvm_util.logger.d(setPath);

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;

  var activateScriptBat = path.join(scriptsDir, '$vmActivate.bat');
  scriptText = '';
  scriptText += '@ECHO OFF\n';
  scriptText += 'IF DEFINED _${vmName}_ENV_VAL GOTO END_SET_ENV_VAL\n';
  scriptText += 'SET _${vmName}_ENV_VAL="yes"\n';
  scriptText += 'SET PATH=$setPath%PATH%\n';
  scriptText += 'SET _OLD_ANDROID_SDK_ROOT=%ANDROID_SDK_ROOT%\n';
  scriptText += 'SET ANDROID_SDK_ROOT=$androidSDKCurrentDirPath\n';
  scriptText += 'SET _OLD_ANDROID_HOME=%ANDROID_HOME%\n';
  scriptText += 'SET ANDROID_HOME=$androidSDKCurrentDirPath\n';
  scriptText += ':END_SET_ENV_VAL\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(activateScriptBat, scriptText);
  anyvm_util.logger.i('$activateScriptBat creatred');

  var activateScriptPs1 = path.join(scriptsDir, '$vmActivate.ps1');
  scriptText = '';
  scriptText += 'if([string]::IsNullOrEmpty(\$env:_${vmName}_ENV_VAL)) {\n';
  scriptText += '    \$env:_${vmName}_ENV_VAL = "yes";\n';
  scriptText += '    \$env:Path = "$setPath" + \$env:Path;\n';
  scriptText += '    \$env:_OLD_ANDROID_SDK_ROOT = \$env:ANDROID_SDK_ROOT;\n';
  scriptText += '    \$env:ANDROID_SDK_ROOT = "$androidSDKCurrentDirPath";\n';
  scriptText += '    \$env:_OLD_ANDROID_HOME = \$env:ANDROID_HOME;\n';
  scriptText += '    \$env:ANDROID_HOME = "$androidSDKCurrentDirPath";\n';
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
  scriptText += 'SET ANDROID_SDK_ROOT=%_OLD_ANDROID_SDK_ROOT%\n';
  scriptText += 'SET _OLD_ANDROID_SDK_ROOT=\n';
  scriptText += 'SET ANDROID_HOME=%_OLD_ANDROID_HOME%\n';
  scriptText += 'SET _OLD_ANDROID_HOME=\n';
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
  scriptText += '    \$env:ANDROID_SDK_ROOT = \$env:_OLD_ANDROID_SDK_ROOT;\n';
  scriptText += '    \$env:_OLD_ANDROID_SDK_ROOT = "";\n';
  scriptText += '    \$env:ANDROID_HOME = \$env:_OLD_ANDROID_HOME;\n';
  scriptText += '    \$env:_OLD_ANDROID_HOME = "";\n';
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
  var androidSDKCurrentDirPath = path.join(getEnvDirectory(), 'current');
  anyvm_util.logger.d(androidSDKCurrentDirPath);
  var androidSDKCurrentDir = Directory(androidSDKCurrentDirPath);

  var androidSDKVersionDirPath = path.join(getEnvDirectory(), currentVersion);
  anyvm_util.logger.d(androidSDKVersionDirPath);
  var androidSDKVersionDir = Directory(androidSDKVersionDirPath);

  if (!await androidSDKVersionDir.exists()) {
    anyvm_util.logger.w('version does not exist');
    return;
  }
  if (await androidSDKCurrentDir.exists()) {
    var args = ['/C', 'RMDIR', androidSDKCurrentDirPath];
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
        .i('Directory renamed/moved successfully.:$androidSDKCurrentDirPath');
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

class AndroidSDKVm extends Command {
  @override
  final name = vmName;
  @override
  final description = 'AndroidSDK tool package version manager.';

  AndroidSDKVm() {
    addSubcommand(AndroidSDKVmInstall());
    addSubcommand(AndroidSDKVmVersions());
    addSubcommand(AndroidSDKVmVersion());
    addSubcommand(AndroidSDKVmSet());
    addSubcommand(AndroidSDKVmUnset());
    addSubcommand(AndroidSDKVmUnInstall());
  }
  @override
  void run() {
    anyvm_util.logger.d('run $vmName Commnad');
  }
}

class AndroidSDKVmInstall extends Command {
  @override
  final name = 'install';
  @override
  final description = 'Install AndroidSDK tool package';

  AndroidSDKVmInstall();

  @override
  Future<void> run() async {
    try {
      await install();
    } catch (e) {
      anyvm_util.logger.i('AndroidSDK tool package is already installed');
    }
  }

  Future<void> install() async {
    final url = 'https://developer.android.com/studio';
    String? toolName;
    String? toolVersion;
    // HTTP GETリクエストを送信
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // ページ内のすべてのテキストを取得
      var bodyText = response.body;

      // 正規表現を使用して特定の形式の文字列を検索
      RegExp regex = RegExp(r'(commandlinetools-win-(\d+)_latest\.zip)');
      var matches = regex.allMatches(bodyText);

      if (matches.isNotEmpty) {
        for (var match in matches) {
          toolName = match.group(1);
          toolVersion = match.group(2);
        }
      } else {
        print('No matching text found');
        anyvm_util.logger.e('No matching text found: commandlinetools-win');
        return;
      }
    } else {
      anyvm_util.logger.e('Failed to load page: ${response.statusCode}');
      return;
    }
    var envCacheDirPath = getEnvCacheDirectory();
    anyvm_util.logger.d(envCacheDirPath);
    var envCacheDir = Directory(envCacheDirPath);

    if (!(await envCacheDir.exists())) {
      await envCacheDir.create(recursive: true);
      anyvm_util.logger.i('$envCacheDirPath creatred');
    }

    var envVerDirPath = path.join(getEnvDirectory(), toolVersion);
    anyvm_util.logger.d(envVerDirPath);
    var envVerDir = Directory(envVerDirPath);
    if (await envVerDir.exists()) {
      anyvm_util.logger.i('Already installed');
      return;
    }

    var filePath = path.join(envCacheDirPath, toolName);
    var file = File(filePath);
    if (!await file.exists()) {
      try {
        await anyvm_util.downloadFileWithProgress(
            'https://dl.google.com/android/repository/$toolName', filePath);
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
    var androidSDKDirPath = path.join(getEnvCacheDirectory(), 'cmdline-tools');
    var androidSDKDir = Directory(androidSDKDirPath);

    var toolDirPath = path.join(envVerDirPath, 'cmdline-tools');
    anyvm_util.logger.d(toolDirPath);
    var toolDir = Directory(toolDirPath);
    if (!(await toolDir.exists())) {
      await toolDir.create(recursive: true);
      anyvm_util.logger.i('$toolDir creatred');
    }

    var commmandlineDirPath = path.join(toolDirPath, 'latest');
    anyvm_util.logger.d(commmandlineDirPath);

    if (await androidSDKDir.exists()) {
      await androidSDKDir.rename(commmandlineDirPath);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: $commmandlineDirPath');
    }
    if (await file.exists()) {
      await file.delete();
      anyvm_util.logger.i('File deleted successfully.: $filePath');
    }
  }
}

class AndroidSDKVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  AndroidSDKVmVersions();

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

class AndroidSDKVmVersion extends Command {
  @override
  final name = 'version';
  @override
  final description = 'Show the current $langName version';

  AndroidSDKVmVersion();

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

class AndroidSDKVmSet extends Command {
  @override
  final name = 'set';
  @override
  final description = 'see $vmName set -h';

  AndroidSDKVmSet() {
    argParser.addOption('version', abbr: 'v', help: 'Version to set.');
  }

  @override
  Future<void> run() async {
    final version = argResults?['version'];
    if (version != null) {
      RegExp pattern = RegExp(r'^\d+$');
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

class AndroidSDKVmUnset extends Command {
  @override
  final name = 'unset';
  @override
  final description = 'Unset the $langName version';

  AndroidSDKVmUnset();

  @override
  Future<void> run() async {
    await unSetVersion();
  }
}

class AndroidSDKVmUnInstall extends Command {
  @override
  final name = 'uninstall';
  @override
  final description = 'see $vmName uninstall -h';

  AndroidSDKVmUnInstall() {
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
