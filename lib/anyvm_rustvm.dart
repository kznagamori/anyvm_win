import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:anyvm_win/anyvm_util.dart' as anyvm_util;
import 'package:path/path.dart' as path;

const String vmName = 'RustVm';
const String langName = 'RustLang';
const String vmActivate = 'RustVmActivate';
const String vmDeactivate = 'RustVmDeactivate';

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

String getRustUpHomePath() {
  return path.join(getEnvDirectory(), '.rustup');
}

String getCargoHomePath() {
  return path.join(getEnvDirectory(), '.cargo');
}

String getCargoTargetPath() {
  return path.join(getEnvDirectory(), 'target');
}

Future<void> setVersion() async {
  await unSetVersion();

  var cargoTargetDir = Directory(getCargoTargetPath());
  if (!await cargoTargetDir.exists()) {
    await cargoTargetDir.create(recursive: true);
    anyvm_util.logger.i('${getCargoTargetPath()} creatred');
  }

  var cargoBinPath = path.join(getCargoHomePath(), 'bin');

  var setPath = '$cargoBinPath;';
  anyvm_util.logger.d(setPath);

  var scriptsDir = anyvm_util.getScriptsDirectory();
  String scriptText;
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
  scriptText += 'SET _OLD_CARGO_TARGET_DIR=%CARGO_TARGET_DIR%\n';
  scriptText += 'SET CARGO_TARGET_DIR=${getCargoTargetPath()}\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_SERVER=%RUSTUP_DIST_SERVER%\n';
  scriptText += 'SET RUSTUP_DIST_SERVER=https://static.rust-lang.org\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_ROOT=%RUSTUP_DIST_ROOT%\n';
  scriptText += 'SET RUSTUP_DIST_ROOT=https://static.rust-lang.org/rustup\n';
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
  scriptText += '    \$env:_OLD_CARGO_TARGET_DIR=\$env:CARGO_TARGET_DIR;\n';
  scriptText += '    \$env:CARGO_TARGET_DIR="${getCargoTargetPath()}"\n';
  scriptText +=
      '    \$env:_OLD_RUSTUP_DIST_SERVER = \$env:RUSTUP_DIST_SERVER;\n';
  scriptText +=
      '    \$env:RUSTUP_DIST_SERVER = "https://static.rust-lang.org";\n';
  scriptText += '    \$env:_OLD_RUSTUP_DIST_ROOT = \$env:RUSTUP_DIST_ROOT;\n';
  scriptText +=
      '    \$env:RUSTUP_DIST_ROOT = "https://static.rust-lang.org/rustup";\n';
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
  scriptText += 'SET CARGO_TARGET_DIR=%_OLD_CARGO_TARGET_DIR%\n';
  scriptText += 'SET _OLD_CARGO_TARGET_DIR=';
  scriptText += 'SET RUSTUP_DIST_SERVER=%_OLD_RUSTUP_DIST_SERVER%\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_SERVER=\n';
  scriptText += 'SET RUSTUP_DIST_ROOT=%_OLD_RUSTUP_DIST_ROOT%\n';
  scriptText += 'SET _OLD_RUSTUP_DIST_ROOT=\n';
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
  scriptText += '    \$env:CARGO_TARGET_DIR = \$env:_OLD_CARGO_TARGET_DIR;\n';
  scriptText += '    \$env:_OLD_CARGO_TARGET_DIR = "";\n';
  scriptText +=
      '    \$env:RUSTUP_DIST_SERVER = \$env:_OLD_RUSTUP_DIST_SERVER;\n';
  scriptText += '    \$env:_OLD_RUSTUP_DIST_SERVER = ""\n';
  scriptText += '    \$env:RUSTUP_DIST_ROOT = \$env:_OLD_RUSTUP_DIST_ROOT;\n';
  scriptText += '    \$env:_OLD_RUSTUP_DIST_ROOT = "";\n';
  scriptText += '}\n';
  anyvm_util.logger.d(scriptText);
  await anyvm_util.writeStringWithSjisEncoding(deActivateScriptPs1, scriptText);
  anyvm_util.logger.i('$deActivateScriptPs1 creatred');

  try {
    var cargoHomePath = getCargoHomePath();
    var rustUpHomePath = getRustUpHomePath();
    var exe = path.join(cargoHomePath, 'bin', 'rustc.exe');
    var args = <String>['--version'];
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
      return;
    } else {
      anyvm_util.logger.i('execute: $exe');
      anyvm_util.setVmVersion(vmName, result.stdout);
    }
  } catch (e) {
    anyvm_util.logger.e('Failed to ecute command: $e');
  }
}

Future<void> unSetVersion() async {
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
  final description = 'Install rust';

  RustVmInstall();

  @override
  Future<void> run() async {
    try {
      await install();
    } catch (e) {
      anyvm_util.logger.i('Rust is already installed');
    }
  }

  Future<void> install() async {
    var cargoHomePath = getCargoHomePath();
    var cargoHome = Directory(cargoHomePath);

    var rustUpHomePath = getRustUpHomePath();
    var rustUpHome = Directory(rustUpHomePath);

    if (await cargoHome.exists() && await rustUpHome.exists()) {
      anyvm_util.logger.i('Rust install failed.');
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

class RustVmVersions extends Command {
  @override
  final name = 'versions';
  @override
  final description = 'Install a $langName version';

  RustVmVersions();

  @override
  Future<void> run() async {
    var cargoHome = getCargoHomePath();
    var rustyHome = getRustUpHomePath();

    var cargoExePath = path.join(cargoHome, 'bin', 'cargo.exe');
    var rustToolChainPath =
        path.join(rustyHome, 'toolchains', 'stable-x86_64-pc-windows-gnu');

    if (!await File(cargoExePath).exists() ||
        !await Directory(rustToolChainPath).exists()) {
      anyvm_util.logger.i('Rust not installed');
    } else {
      anyvm_util.logger.i('Rust installed');
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
    await setVersion();
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

  RustVmUnInstall();
  @override
  Future<void> run() async {
    try {
      await uninstall();
    } catch (e) {
      anyvm_util.logger.i('Rust is not installed');
    }
  }

  Future<void> uninstall() async {
    var cargoHomeDir = Directory(getCargoHomePath());
    if (await cargoHomeDir.exists()) {
      await cargoHomeDir.delete(recursive: true);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: ${getCargoHomePath()} ');
    }
    var cargoTargetDir = Directory(getCargoTargetPath());
    if (await cargoTargetDir.exists()) {
      await cargoTargetDir.delete(recursive: true);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: ${getCargoTargetPath()} ');
    }
    var rustUpHomeDir = Directory(getRustUpHomePath());
    if (await rustUpHomeDir.exists()) {
      await rustUpHomeDir.delete(recursive: true);
      anyvm_util.logger
          .i('Directory renamed/moved successfully.: ${getRustUpHomePath()} ');
    }
  }
}
